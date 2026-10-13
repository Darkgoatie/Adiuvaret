import Foundation
import FoundationModels

/// Whether this iPhone can run Apple's on-device model. FoundationModels needs iOS 26 and a device with Apple Intelligence turned on,
/// so on anything older, or when it is off, the app works through downloaded and online models and never touches the framework.
enum AppleModel {
    enum Status: Equatable {
        case available
        /// iOS is older than 26, so the framework does not exist here.
        case unsupportedOS
        /// iOS 26 or later, but the model cannot run: unsupported hardware, Apple Intelligence off, or the model is still downloading.
        case unavailable(String)
    }

    static var status: Status {
        guard #available(iOS 26.0, *) else { return .unsupportedOS }
        switch SystemLanguageModel.default.availability {
        case .available: return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return .unavailable(String(localized: "This iPhone does not support Apple Intelligence."))
            case .appleIntelligenceNotEnabled: return .unavailable(String(localized: "Apple Intelligence is turned off in Settings."))
            case .modelNotReady: return .unavailable(String(localized: "The model is still downloading. Try again later."))
            @unknown default: return .unavailable(String(localized: "Apple Intelligence isn't available."))
            }
        }
    }

    static var isAvailable: Bool { status == .available }

    /// Shown in diagnostics and the Models screen.
    static var statusText: String {
        switch status {
        case .available: "available"
        case .unsupportedOS: "needs iOS 26"
        case .unavailable(let why): "unavailable: \(why)"
        }
    }

    /// The reasoning level exists from iOS 27 and is compiled only when the build sets REASONING_API (the Xcode 27 pipeline).
    static var reasoningCompiled: Bool {
        #if REASONING_API
        if #available(iOS 27, *) { return true }
        #endif
        return false
    }
}
