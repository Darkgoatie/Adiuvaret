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
    public static let all: [Connector] = [
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
                  network: "None from Adiuvaret.", defaultOn: true)
    ]

    public static func connector(_ id: String) -> Connector? { all.first { $0.id == id } }

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
