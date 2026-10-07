import Foundation
import Observation
import PolicyEngine

/// The one policy engine every chat shares, so the kill switch applies everywhere at once.
enum LiveEngine {
    static let shared = PolicyEngine(tools: LiveDescriptors.all)
}

/// User preferences stored on the device.
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()
    private static let actionsOffKey = "settings.actionsOff"

    var actionsOff: Bool {
        didSet {
            UserDefaults.standard.set(actionsOff, forKey: Self.actionsOffKey)
            let on = actionsOff
            Task { await LiveEngine.shared.setKillSwitch(on) }
        }
    }

    private init() {
        let stored = UserDefaults.standard.bool(forKey: Self.actionsOffKey)
        actionsOff = stored
        Task { await LiveEngine.shared.setKillSwitch(stored) }
    }
}
