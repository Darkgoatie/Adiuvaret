import Foundation

/// Every external entry point (deep links, App Intents, notifications) resolves to one of these.
enum Route: Hashable {
    case newChat
    case chat(UUID)
    case briefings
    case briefing(UUID)
    case approvalsInbox
    case notes
    case note(UUID)
    case memory
    case activity
    case integrations
    case models
    case privacy
    case settings
}

enum DrawerDestination: String, CaseIterable, Identifiable {
    case briefings, notes, memory, activity, integrations, models, privacy, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .briefings: String(localized: "Briefings and Automations")
        case .notes: String(localized: "Notes and Tasks")
        case .memory: String(localized: "What I know about you")
        case .activity: String(localized: "Activity log")
        case .integrations: String(localized: "Integrations")
        case .models: String(localized: "Models")
        case .privacy: String(localized: "Privacy")
        case .settings: String(localized: "Settings")
        }
    }

    var symbol: String {
        switch self {
        case .briefings: "sun.max"
        case .notes: "note.text"
        case .memory: "brain.head.profile"
        case .activity: "list.bullet.rectangle"
        case .integrations: "puzzlepiece.extension"
        case .models: "cpu"
        case .privacy: "lock.shield"
        case .settings: "gearshape"
        }
    }

    var route: Route {
        switch self {
        case .briefings: .briefings
        case .notes: .notes
        case .memory: .memory
        case .activity: .activity
        case .integrations: .integrations
        case .models: .models
        case .privacy: .privacy
        case .settings: .settings
        }
    }
}
