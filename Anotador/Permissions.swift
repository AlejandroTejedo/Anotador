import AVFoundation
import CoreGraphics
import Foundation
import Speech

enum PermissionState: Equatable {
    case granted
    case denied
    case notDetermined
}

enum Permissions {
    static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func requestSpeech() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized || status == .notDetermined)
            }
        }
    }

    static var microphone: PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    static var speech: PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// macOS only tells us granted / not granted, and changes apply after relaunch.
    static var screen: PermissionState {
        CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
    }

    static func requestScreen() {
        _ = CGRequestScreenCaptureAccess()
    }
}
