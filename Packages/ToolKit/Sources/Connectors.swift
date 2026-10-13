import Foundation

/// One outside app the assistant can reach, with what it reads, what it changes and where data goes. Shown on the Integrations screen.
public struct Connector: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let symbol: String
    public let reads: String
    public let changes: String
    public let network: String
    public let defaultOn: Bool
}

public enum ConnectorCatalog {
    private static let native: [Connector] = [
        Connector(id: "notes", title: "Notes folder (Obsidian)", symbol: "doc.text",
                  reads: "Note names and text in the folder you choose.",
                  changes: "Creates notes and adds text to notes, after you approve.",
                  network: "None. Your notes never leave this iPhone.", defaultOn: false),
        Connector(id: "contacts", title: "Contacts", symbol: "person.crop.circle",
                  reads: "Names, phone numbers, emails and birthdays of the people you ask about.",
                  changes: "Nothing. Read only.",
                  network: "None.", defaultOn: false),
        Connector(id: "shortcuts", title: "Shortcuts", symbol: "bolt",
                  reads: "Nothing. A shortcut's result cannot be read back.",
                  changes: "Runs a shortcut you name, after you approve. What it does depends on the shortcut.",
                  network: "None from Adiuvaret. The shortcut itself may use the network.", defaultOn: true),
        Connector(id: "mail", title: "Email drafts", symbol: "envelope",
                  reads: "Nothing.",
                  changes: "Opens a draft in Mail. You press send.",
                  network: "None from Adiuvaret.", defaultOn: true),
        Connector(id: "github", title: "GitHub", symbol: "chevron.left.forwardslash.chevron.right",
                  reads: "Issues and pull requests assigned to you, created by you, or waiting for your review.",
                  changes: "Nothing. Read only.",
                  network: "Requests go to api.github.com with your own token. Only the kind of list you asked for leaves the iPhone.", defaultOn: false),
        Connector(id: "notion", title: "Notion", symbol: "doc.richtext",
                  reads: "Titles of pages and databases your integration was shared with.",
                  changes: "Nothing. Read only.",
                  network: "Requests go to api.notion.com with your own token. Only your search words leave the iPhone.", defaultOn: false)
    ]

    /// Hand-wired connectors first, then every manifest in the registry.
    public static let all: [Connector] = native + ConnectorRegistry.manifests.map(\.connector)

    public static func connector(_ id: String) -> Connector? { all.first { $0.id == id } }

    /// Which connector owns a catalog category. Categories not listed here (Calendar, Reminders, Web, Chats) belong to the app itself and are always offered.
    public static let categoryOwner: [String: String] = nativeOwners.merging(ConnectorRegistry.manifests.map { ($0.category, $0.id) }) { a, _ in a }

    private static let nativeOwners: [String: String] = [
        "Notes": "notes", "Contacts": "contacts", "Shortcuts": "shortcuts", "Email": "mail", "GitHub": "github", "Notion": "notion",
    ]

    /// The catalog with every tool of a switched-off connector removed, so the router can neither pick nor describe it.
    public static func visible(_ catalog: ToolCatalog, defaults: UserDefaults = .standard) -> ToolCatalog {
        ToolCatalog(entries: catalog.entries.filter { e in
            guard let owner = categoryOwner[e.category] else { return true }
            return isOn(owner, defaults: defaults)
        })
    }

    private static func key(_ id: String) -> String { "connector.on.\(id)" }

    public static func isOn(_ id: String, defaults: UserDefaults = .standard) -> Bool {
        guard let c = connector(id) else { return false }
        return defaults.object(forKey: key(id)) as? Bool ?? c.defaultOn
    }

    public static func setOn(_ on: Bool, _ id: String, defaults: UserDefaults = .standard) {
        defaults.set(on, forKey: key(id))
    }

    /// What the model is told when it reaches for a connector the user has not switched on.
    public static func offMessage(_ id: String) -> String {
        let name = connector(id)?.title ?? id
        return "Not done: the \(name) connector is switched off. Tell the user they can turn it on in Advanced, Integrations."
    }
}

/// One line per contact, with the fields the assistant is allowed to share in chat.
public enum ContactFormat {
    public static func line(name: String, organization: String, phones: [String], emails: [String], birthday: String?) -> String {
        var head = String(name.prefix(60))
        if !organization.isEmpty { head += " (\(organization.prefix(40)))" }
        var parts = [head]
        if !phones.isEmpty { parts.append("phone " + phones.prefix(3).joined(separator: ", ")) }
        if !emails.isEmpty { parts.append("email " + emails.prefix(3).joined(separator: ", ")) }
        if let birthday, !birthday.isEmpty { parts.append("birthday " + birthday) }
        return parts.joined(separator: "; ")
    }
}
