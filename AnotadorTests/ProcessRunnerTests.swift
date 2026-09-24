import Foundation
import Testing
@testable import Anotador

struct ProcessRunnerTests {
    private let shell = URL(fileURLWithPath: "/bin/sh")

    @Test func drainsLargeStderrWithoutDeadlock() async throws {
        // >64 KB on stderr used to block the child while we waited on stdout.
        let result = try await ProcessRunner.run(
            executable: shell,
            arguments: ["-c", "head -c 300000 /dev/zero | tr '\\\\0' x >&2; echo ok"],
            workingDirectory: nil,
            environment: [:],
            timeout: 20
        )
        #expect(result.status == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "ok")
        #expect(result.stderr.count >= 300_000)
    }

    @Test func killsOnTimeout() async throws {
        let start = Date()
        let result = try await ProcessRunner.run(
            executable: shell,
            arguments: ["-c", "sleep 30"],
            workingDirectory: nil,
            environment: [:],
            timeout: 1
        )
        #expect(result.timedOut)
        #expect(Date().timeIntervalSince(start) < 10)
    }

    @Test func reportsMissingExecutable() async {
        await #expect(throws: (any Error).self) {
            _ = try await ProcessRunner.run(
                executable: URL(fileURLWithPath: "/nonexistent/grok"),
                arguments: [],
                workingDirectory: nil,
                environment: [:],
                timeout: 5
            )
        }
    }
}
