import Foundation

/// Every external entry point (deep links, App Intents, notifications) resolves to one of these.
enum Route: Hashable {
    case newChat
    case chat(UUID)
    case briefings
    case briefing(UUID)
    case notes
    case note(UUID)
    case memory
    case activity
    case integrations
    case apiAccess
    case taughtSkills
    case models
    case privacy
    case settings
    case advanced
}

/// Rows of the Advanced and Settings sub-screens. Each opens its own screen.
enum SubItem: Identifiable {
    case integrations, apiAccess, taughtSkills, models, activity, memory, privacy, briefings, notes
    var id: Self { self }

    var title: String {
        switch self {
        case .integrations: String(localized: "Integrations")
        case .apiAccess: String(localized: "API access")
        case .taughtSkills: String(localized: "Skills")
        case .models: String(localized: "Models")
        case .activity: String(localized: "Activity log")
        case .memory: String(localized: "What I know about you")
        case .privacy: String(localized: "Privacy")
        case .briefings: String(localized: "Briefings")
        case .notes: String(localized: "Notes and Tasks")
        }
    }

    var symbol: String {
        switch self {
        case .integrations: "puzzlepiece.extension"
        case .apiAccess: "network"
        case .taughtSkills: "graduationcap"
        case .models: "cpu"
        case .activity: "list.bullet.rectangle"
        case .memory: "brain.head.profile"
        case .privacy: "lock.shield"
        case .briefings: "sun.max"
        case .notes: "note.text"
        }
    }

    var route: Route {
        switch self {
        case .integrations: .integrations
        case .apiAccess: .apiAccess
        case .taughtSkills: .taughtSkills
        case .models: .models
        case .activity: .activity
        case .memory: .memory
        case .privacy: .privacy
        case .briefings: .briefings
        case .notes: .notes
        }
    }

    static let advanced: [SubItem] = [.notes, .briefings, .integrations, .apiAccess, .taughtSkills, .models, .activity, .memory]
    static let settings: [SubItem] = [.privacy]
}
