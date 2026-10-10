import Foundation

/// One saved message, reduced to what a search needs.
public struct PastMessage: Sendable, Equatable {
    public let chatTitle: String
    public let date: Date
    public let isUser: Bool
    public let text: String
    public init(chatTitle: String, date: Date, isUser: Bool, text: String) {
        self.chatTitle = chatTitle; self.date = date; self.isUser = isUser; self.text = text
    }
}

/// Finds earlier conversations by words. Runs on the phone over the saved chats; nothing is sent anywhere.
public enum ChatSearch {
    public struct Hit: Sendable, Equatable {
        public let chatTitle: String
        public let date: Date
        public let speaker: String
        public let snippet: String
        public let score: Int
    }

    private static let extraStop: Set<String> = ["talk", "talked", "chat", "chats", "conversation", "conversations", "discuss", "discussed", "said", "say",
                                                  "earlier", "before", "last", "ago", "remember", "told", "tell", "ask", "asked", "yesterday", "week", "month", "our", "we", "us"]

    public static func terms(_ query: String) -> [String] {
        NoteSearch.terms(query).filter { !extraStop.contains($0) }
    }

    /// Best matches first. Recent messages win ties. `now` is a parameter so tests do not depend on the clock.
    public static func rank(_ messages: [PastMessage], query: String, now: Date = Date(), limit: Int = 5) -> [Hit] {
        let wanted = terms(query)
        guard !wanted.isEmpty else { return [] }
        var hits: [Hit] = []
        for m in messages {
            let body = m.text.lowercased()
            let title = m.chatTitle.lowercased()
            var score = 0
            var matched = 0
            for term in wanted {
                let count = min(body.components(separatedBy: term).count - 1, 3)
                let inTitle = title.contains(term)
                if count > 0 || inTitle { matched += 1 }
                score += count * 2 + (inTitle ? 1 : 0)
            }
            guard matched > 0 else { continue }
            if matched == wanted.count { score += 8 }
            let ageDays = max(0, now.timeIntervalSince(m.date) / 86_400)
            if ageDays < 7 { score += 2 } else if ageDays < 30 { score += 1 }
            hits.append(Hit(chatTitle: m.chatTitle, date: m.date, speaker: m.isUser ? "user" : "assistant",
                            snippet: NoteSearch.snippet(m.text, terms: wanted), score: score))
        }
        let ordered = hits.sorted { $0.score != $1.score ? $0.score > $1.score : $0.date > $1.date }
        return Array(ordered.prefix(max(1, limit)))
    }

    public static func format(_ hits: [Hit], searched: Int, calendar: Calendar = .current) -> [String] {
        let f = DateFormatter()
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return hits.enumerated().map { "\($0.offset + 1). \(f.string(from: $0.element.date)) in chat '\($0.element.chatTitle)' (\($0.element.speaker)): \($0.element.snippet)" }
    }
}
