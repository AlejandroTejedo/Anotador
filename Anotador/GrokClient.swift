import Foundation

/// Grok through the user's logged-in CLI (`grok login`), i.e. their subscription.
enum GrokClient {
    static let jsonSchema = """
    {"type":"object","additionalProperties":false,"required":["title","tldr","summary","key_points","decisions","action_items","open_questions","risks","next_steps","topics"],"properties":{"title":{"type":"string"},"tldr":{"type":"string"},"summary":{"type":"string"},"key_points":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["point"],"properties":{"point":{"type":"string"},"timestamp":{"type":"string"},"quote":{"type":"string"}}}},"decisions":{"type":"array","items":{"type":"string"}},"action_items":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["task"],"properties":{"task":{"type":"string"},"owner":{"type":"string"},"due":{"type":"string"}}}},"open_questions":{"type":"array","items":{"type":"string"}},"risks":{"type":"array","items":{"type":"string"}},"next_steps":{"type":"array","items":{"type":"string"}},"topics":{"type":"array","items":{"type":"string"}}}}
    """

    static let timeout: TimeInterval = 600

    static func resolveBinary() -> URL? {
        let fm = FileManager.default
        if let fromEnv = ProcessInfo.processInfo.environment["GROK_BINARY"],
           fm.isExecutableFile(atPath: fromEnv) {
            return URL(fileURLWithPath: fromEnv)
        }
        let home = fm.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".grok/bin/grok"),
            URL(fileURLWithPath: "/opt/homebrew/bin/grok"),
            URL(fileURLWithPath: "/usr/local/bin/grok")
        ]
        return candidates.first { fm.isExecutableFile(atPath: $0.path) }
    }

    @concurrent
    static func summarize(prompt: String) async throws -> MeetingNotes {
        guard let binary = resolveBinary() else { throw AnotadorError.grokMissing }

        let temp = FileManager.default.temporaryDirectory
        let promptURL = temp.appendingPathComponent("anotador-prompt-\(UUID().uuidString).md")
        let workDir = temp.appendingPathComponent("anotador-grok-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        try prompt.write(to: promptURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: promptURL)
            try? FileManager.default.removeItem(at: workDir)
        }

        let result = try await ProcessRunner.run(
            executable: binary,
            arguments: arguments(promptPath: promptURL.path, workDir: workDir.path),
            workingDirectory: workDir,
            environment: environment(),
            timeout: timeout
        )

        if let notes = try? decodeNotes(from: result.stdout) {
            return notes
        }
        if result.timedOut {
            throw AnotadorError.summaryFailed("Grok tardó demasiado. Pulsa Reintentar; la transcripción ya está guardada.")
        }
        guard result.status == 0 else {
            throw AnotadorError.summaryFailed(failureMessage(stdout: result.stdout, stderr: result.stderr))
        }
        return try decodeNotes(from: result.stdout)
    }

    static let maxTurns = 8

    static func arguments(promptPath: String, workDir: String) -> [String] {
        [
            "--prompt-file", promptPath,
            "--json-schema", jsonSchema,
            "--max-turns", String(maxTurns),
            "--always-approve",
            "--no-subagents",
            "--verbatim",
            "--disallowed-tools",
            "run_terminal_cmd,web_search,web_fetch,search_replace,write,read_file,grep,list_dir,Agent,image_gen,image_edit,todo_write,spawn_subagent",
            "--cwd", workDir,
            "--no-auto-update",
            "--output-format", "json"
        ]
    }

    /// Apps launched from Finder get a bare PATH; the CLI may shell out to node, etc.
    static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", "\(env["HOME"] ?? "")/.grok/bin"]
        let current = (env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin").split(separator: ":").map(String.init)
        env["PATH"] = (current + extra.filter { !current.contains($0) }).joined(separator: ":")
        return env
    }

    static func isAuthFailure(stdout: String, stderr: String) -> Bool {
        let blob = (stdout + "\n" + stderr).lowercased()
        let markers = ["grok login", "not logged in", "log in", "please login", "unauthorized", "unauthenticated", "authentication", "auth expired", "401"]
        return markers.contains { blob.contains($0) }
    }

    static func isMaxTurnsFailure(_ message: String) -> Bool {
        let blob = message.lowercased()
        return blob.contains("max turns")
            || blob.contains("max_turns")
            || blob.contains("error_max_turns")
    }

    static func failureMessage(stdout: String, stderr: String) -> String {
        if isAuthFailure(stdout: stdout, stderr: stderr) {
            return "Grok no tiene sesión. En el terminal: `grok login`. O elige otro proveedor en Ajustes."
        }
        let detail = (stderr.isEmpty ? stdout : stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        if isMaxTurnsFailure(detail) {
            return "Grok se quedó a medias redactando. Pulsa Reintentar; la transcripción ya está guardada."
        }
        return detail.isEmpty ? "Grok no pudo redactar las notas." : String(detail.prefix(600))
    }

    static func decodeNotes(from raw: String) throws -> MeetingNotes {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let envelope = try? JSONDecoder().decode(GrokEnvelope.self, from: data) {
            return try NotesPrompt.decodePayload(envelope.text, providerName: "Grok")
        }
        return try NotesPrompt.decodePayload(trimmed, providerName: "Grok")
    }
}

private struct GrokEnvelope: Decodable {
    var text: String
}

/// Runs a subprocess without blocking a cooperative thread, drains both pipes
/// concurrently (no deadlock when stderr is chatty), honours a timeout and
/// Task cancellation.
enum ProcessRunner {
    struct Result: Sendable {
        var status: Int32
        var stdout: String
        var stderr: String
        var timedOut: Bool
    }

    static func run(
        executable: URL,
        arguments: [String],
        workingDirectory: URL?,
        environment: [String: String],
        timeout: TimeInterval
    ) async throws -> Result {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.environment = environment
        process.standardInput = FileHandle.nullDevice

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let timedOut = Flag()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result, Error>) in
                let group = DispatchGroup()
                let outBox = DataBox()
                let errBox = DataBox()

                group.enter()
                DispatchQueue.global().async {
                    outBox.data = stdout.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                group.enter()
                DispatchQueue.global().async {
                    errBox.data = stderr.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                process.terminationHandler = { finished in
                    group.notify(queue: .global()) {
                        continuation.resume(returning: Result(
                            status: finished.terminationStatus,
                            stdout: String(decoding: outBox.data, as: UTF8.self),
                            stderr: String(decoding: errBox.data, as: UTF8.self),
                            timedOut: timedOut.value
                        ))
                    }
                }

                do {
                    try process.run()
                } catch {
                    // Close our write ends so the readers above return.
                    try? stdout.fileHandleForWriting.close()
                    try? stderr.fileHandleForWriting.close()
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                    return
                }

                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if process.isRunning {
                        timedOut.value = true
                        process.terminate()
                    }
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }

    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }

    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = false
        var value: Bool {
            get { lock.withLock { _value } }
            set { lock.withLock { _value = newValue } }
        }
    }
}
