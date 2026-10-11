import Foundation
import Observation
import PolicyEngine

/// The one policy engine every chat shares, so the kill switch applies everywhere at once.
enum LiveEngine {
    /// Web tasks take several steps, so the cap is higher than the default of 12. The 8192-token window ends long runs sooner than this.
    static let shared = PolicyEngine(tools: LiveDescriptors.all, limits: PolicyLimits(maxToolCallsPerTask: 15))
}

/// User preferences stored on the device.
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()
    private static let actionsOffKey = "settings.actionsOff"
    private static let strictKey = "settings.strictWeb"
    private static let quickBarKey = "settings.quickBar"
    private static let shortcutsKey = "settings.shortcuts"

    var actionsOff: Bool {
        didSet {
            UserDefaults.standard.set(actionsOff, forKey: Self.actionsOffKey)
            let on = actionsOff
            Task { await LiveEngine.shared.setKillSwitch(on) }
        }
    }

    /// When on, opening a website the chat has not visited yet needs the user's approval.
    var strictWeb: Bool {
        didSet { UserDefaults.standard.set(strictWeb, forKey: Self.strictKey) }
    }

    /// The row of shortcut buttons above the keyboard. Off until the user turns it on.
    var quickBarOn: Bool {
        didSet { UserDefaults.standard.set(quickBarOn, forKey: Self.quickBarKey) }
    }

    /// The user's own shortcuts: a short word on the button and the prompt it puts in the message field.
    var shortcuts: [QuickShortcut] {
        didSet { UserDefaults.standard.set(try? JSONEncoder().encode(shortcuts), forKey: Self.shortcutsKey) }
    }

    private init() {
        quickBarOn = UserDefaults.standard.bool(forKey: Self.quickBarKey)
        if let data = UserDefaults.standard.data(forKey: Self.shortcutsKey),
           let list = try? JSONDecoder().decode([QuickShortcut].self, from: data) {
            shortcuts = list
        } else {
            shortcuts = QuickShortcut.starters
        }
        strictWeb = UserDefaults.standard.bool(forKey: Self.strictKey)
        let stored = UserDefaults.standard.bool(forKey: Self.actionsOffKey)
        actionsOff = stored
        Task { await LiveEngine.shared.setKillSwitch(stored) }
    }
}

struct QuickShortcut: Codable, Identifiable, Hashable {
    var id = UUID()
    var word: String
    var prompt: String

    static var starters: [QuickShortcut] {
        [QuickShortcut(word: String(localized: "Today"), prompt: String(localized: "What's on my calendar today?")),
         QuickShortcut(word: String(localized: "Reminder"), prompt: String(localized: "Remind me to ")),
         QuickShortcut(word: String(localized: "Draft"), prompt: String(localized: "Draft a message to ")),
         QuickShortcut(word: String(localized: "Free time"), prompt: String(localized: "Find a free time for "))]
    }
}
