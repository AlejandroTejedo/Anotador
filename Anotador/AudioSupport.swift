@preconcurrency import AVFoundation
import CoreMedia
import Foundation

enum AudioSupport {
    static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        guard var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else {
            return nil
        }
        guard let format = AVAudioFormat(streamDescription: &asbd) else { return nil }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return nil
        }
        buffer.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frames),
            into: buffer.mutableAudioBufferList
        )
        guard status == noErr else { return nil }
        return buffer
    }

    static func meetingsRoot() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = appSupport.appendingPathComponent("Anotador/Meetings", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func removeFolder(for meetingID: UUID) {
        guard let root = try? meetingsRoot() else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent(meetingID.uuidString, isDirectory: true))
    }

    static func folder(for meetingID: UUID) throws -> URL {
        let folder = try meetingsRoot().appendingPathComponent(meetingID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}

final class BufferConverter {
    private let converter: AVAudioConverter
    let outputFormat: AVAudioFormat

    init?(from inputFormat: AVAudioFormat, to outputFormat: AVAudioFormat) {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return nil }
        self.converter = converter
        self.outputFormat = outputFormat
    }

    func convert(_ input: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        let ratio = outputFormat.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: max(capacity, 1)) else {
            throw AnotadorError.conversionFailed
        }

        var error: NSError?
        let consumed = ConsumedFlag()
        let status = converter.convert(to: output, error: &error) { _, statusPtr in
            if consumed.value {
                statusPtr.pointee = .noDataNow
                return nil
            }
            consumed.value = true
            statusPtr.pointee = .haveData
            return input
        }

        if let error { throw error }
        guard status != .error else { throw AnotadorError.conversionFailed }
        return output
    }
}

private final class ConsumedFlag: @unchecked Sendable {
    var value = false
}

final class CAFWriter {
    private let file: AVAudioFile

    init(url: URL, format: AVAudioFormat) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    func write(_ buffer: AVAudioPCMBuffer) throws {
        guard buffer.frameLength > 0 else { return }
        try file.write(from: buffer)
    }
}
