import Foundation

enum LinkEncoding {
    private static let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

    static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}

/// The link that runs a shortcut by name in the Shortcuts app.
public enum ShortcutLink {
    public static let maxName = 80

    public static func url(for name: String) -> URL? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, n.count <= maxName, !n.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return URL(string: "shortcuts://run-shortcut?name=" + LinkEncoding.encode(n))
    }
}

/// A mail link that opens a draft. The user reads it and presses send; nothing is sent from here.
public enum MailDraft {
    public static let maxRecipients = 5
    public static let maxBody = 2000
    public static let maxSubject = 200

    public static func isAddress(_ text: String) -> Bool {
        text.wholeMatch(of: /[^\s@,;<>]+@[^\s@,;<>]+\.[A-Za-z]{2,}/) != nil
    }

    /// Splits "a@x.com, b@y.com" into clean addresses. Nil when any of them is not an address.
    public static func recipients(_ text: String) -> [String]? {
        let parts = text.split(whereSeparator: { ",; ".contains($0) }).map(String.init)
        guard parts.count <= maxRecipients, parts.allSatisfy(isAddress) else { return nil }
        return parts
    }

    public static func url(to: [String], subject: String, body: String) -> URL? {
        guard to.count <= maxRecipients, to.allSatisfy(isAddress) else { return nil }
        let s = String(subject.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxSubject))
        let b = String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxBody))
        var query: [String] = []
        if !s.isEmpty { query.append("subject=" + LinkEncoding.encode(s)) }
        if !b.isEmpty { query.append("body=" + LinkEncoding.encode(b)) }
        return URL(string: "mailto:" + to.joined(separator: ",") + (query.isEmpty ? "" : "?" + query.joined(separator: "&")))
    }
}
