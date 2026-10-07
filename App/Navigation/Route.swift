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
    case advanced
}

/// Rows of the Advanced and Settings sub-screens. Each opens its own screen.
enum SubItem: Identifiable {
    case integrations, models, activity, memory, privacy
    var id: Self { self }

    var title: String {
        switch self {
        case .integrations: String(localized: "Integrations")
        case .models: String(localized: "Models")
        case .activity: String(localized: "Activity log")
        case .memory: String(localized: "What I know about you")
        case .privacy: String(localized: "Privacy")
        }
    }

    var symbol: String {
        switch self {
        case .integrations: "puzzlepiece.extension"
        case .models: "cpu"
        case .activity: "list.bullet.rectangle"
        case .memory: "brain.head.profile"
        case .privacy: "lock.shield"
        }
    }

    var route: Route {
        switch self {
        case .integrations: .integrations
        case .models: .models
        case .activity: .activity
        case .memory: .memory
        case .privacy: .privacy
        }
    }

    static let advanced: [SubItem] = [.integrations, .models, .activity, .memory]
    static let settings: [SubItem] = [.privacy]
}
