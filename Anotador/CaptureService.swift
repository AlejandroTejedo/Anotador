import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

final class CaptureService: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    var onMicBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    var onSystemBuffer: (@Sendable (AVAudioPCMBuffer) -> Void)?
    var onError: (@Sendable (Error) -> Void)?

    private let engine = AVAudioEngine()
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "local.anotador.audio")
    private let lock = NSLock()
    private var capturingSystem = false
    private var capturingMic = false
    private var configObserver: NSObjectProtocol?

    func start(mode: CaptureMode) async throws {
        stop()

        guard await Permissions.requestMicrophone() else {
            throw AnotadorError.microphoneDenied
        }

        try startMicrophone()

        if mode.capturesSystemAudio {
            do {
                try await startSystemAudio()
            } catch {
                stop()
                throw AnotadorError.screenDenied
            }
        }
    }

    func stop() {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
        configObserver = nil
        lock.withLock {
            capturingMic = false
            capturingSystem = false
        }
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning {
            engine.stop()
        }
        if let stream {
            Task {
                try? await stream.stopCapture()
            }
        }
        stream = nil
    }

    private func startMicrophone() throws {
        installMicTap()
        engine.prepare()
        try engine.start()
        lock.withLock { capturingMic = true }

        // Plugging in AirPods or changing the input device stops the engine
        // silently. Reinstall the tap with the new format and keep going.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            self?.restartMicrophone()
        }
    }

    private func installMicTap() {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, self.lock.withLock({ self.capturingMic }) else { return }
            self.onMicBuffer?(buffer)
        }
    }

    private func restartMicrophone() {
        guard lock.withLock({ capturingMic }) else { return }
        engine.stop()
        installMicTap()
        engine.prepare()
        do {
            try engine.start()
        } catch {
            onError?(error)
        }
    }

    private func startSystemAudio() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw AnotadorError.screenDenied
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 1
        config.showsCursor = false

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await stream.startCapture()
        self.stream = stream
        lock.withLock { capturingSystem = true }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, lock.withLock({ capturingSystem }) else { return }
        guard let buffer = AudioSupport.pcmBuffer(from: sampleBuffer) else { return }
        onSystemBuffer?(buffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        let wasCapturing = lock.withLock {
            let value = capturingSystem
            capturingSystem = false
            return value
        }
        if wasCapturing { onError?(error) }
    }
}
