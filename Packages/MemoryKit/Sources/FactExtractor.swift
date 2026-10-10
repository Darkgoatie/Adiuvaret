import Foundation

/// Finds a personal fact in what the user typed. Only the user's own message is read: calendar, reminders and web text never get here.
public enum FactExtractor {
    private static let openers: [String] = [
        "my name is ", "call me ", "i live in ", "i'm from ", "i am from ", "i was born in ", "i work as ", "i work at ", "i work for ", "i study ",
        "i'm allergic to ", "i am allergic to ", "i'm a ", "i am a ", "i'm an ", "i am an ", "i'm vegetarian", "i am vegetarian", "i'm vegan", "i am vegan",
        "i prefer ", "i like ", "i love ", "i hate ", "i don't like ", "i do not like ", "i usually ", "i always ", "i drive ", "i have a ", "i have two ", "i have three ",
        "i support ", "i speak ", "i play "]
    private static let possessive = #"^my [a-z' ]{2,24} (?:is|are) .+"#
    private static let secrets: [String] = ["password", "passcode", "pin code", "card number", "cvv", "iban", "social security", "secret", "token", "api key"]
    private static let rememberPrefixes = ["please remember that ", "remember that ", "remember "]

    /// The fact to remember, cleaned, or nil when the message holds none.
    public static func fact(in message: String) -> String? {
        var text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 300, !text.contains("?"), !text.contains("\n") else { return nil }
        let lower = text.lowercased()
        if secrets.contains(where: { lower.contains($0) }) { return nil }
        if text.range(of: #"\d{6,}"#, options: .regularExpression) != nil { return nil }
        if text.range(of: #"[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, options: .regularExpression) != nil { return nil }
        if let prefix = rememberPrefixes.first(where: { lower.hasPrefix($0) }) {
            text = String(text.dropFirst(prefix.count))
        } else {
            let startsWithFact = openers.contains { lower.hasPrefix($0) } || lower.range(of: possessive, options: .regularExpression) != nil
            guard startsWithFact else { return nil }
        }
        // Keep only the first sentence, so "My name is Ana. What's the weather" does not store the rest.
        let first = text.split(whereSeparator: { ".!;".contains($0) }).first.map(String.init) ?? text
        let cleaned = first.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
        guard cleaned.count >= 6 else { return nil }
        let clipped = String(cleaned.prefix(MemoryLimits.maxFactLength))
        return clipped.prefix(1).uppercased() + clipped.dropFirst()
    }
}
