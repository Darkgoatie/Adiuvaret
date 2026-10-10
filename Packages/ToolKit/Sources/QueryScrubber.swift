import Foundation

/// Last check on search words before they leave the phone. Removes contact details and long numbers, and any word that came from the user's calendar or reminders instead of from the user's own message.
public enum QueryScrubber {
    public struct Result: Equatable, Sendable {
        public let query: String
        public let removed: [String]
        public var changed: Bool { !removed.isEmpty }
    }

    private static let patterns: [String] = [
        #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#,
        #"https?://\S*[:@]\S*"#,
        #"\+?\d[\d\s().\-]{7,}\d"#,
        #"\b\d{9,}\b"#,
        #"\b[A-Za-z]{2}\d{2}[A-Za-z0-9]{11,30}\b"#
    ]

    private static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    public static func scrub(query: String, userMessage: String, privateText: String = "") -> Result {
        var text = query
        var removed: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for m in regex.matches(in: text, range: range).reversed() {
                if let r = Range(m.range, in: text) { removed.append(String(text[r])); text.replaceSubrange(r, with: "") }
            }
        }
        let own = Set(words(userMessage))
        let secret = Set(words(privateText).filter { $0.count >= 4 })
        var kept: [String] = []
        for word in text.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
            let parts = words(word)
            if !parts.isEmpty, parts.allSatisfy({ secret.contains($0) && !own.contains($0) }) { removed.append(word) } else { kept.append(word) }
        }
        return Result(query: kept.joined(separator: " "), removed: removed)
    }
}
