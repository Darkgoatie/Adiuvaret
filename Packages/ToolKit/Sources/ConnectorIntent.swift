import Foundation

/// Spots questions that belong to a connected app, so they reach the right tool even when the model does not pick one.
public enum ConnectorIntent {
    public struct Match: Sendable, Equatable {
        public let connector: String
        public let tool: String
        public let arguments: [String: String]
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    private static let writeVerbs: Set<String> = ["add", "create", "put", "new"]

    /// The read tool that answers this message, or nil. Only read tools are matched here: writes stay with the model and the approval card.
    public static func detect(_ text: String) -> Match? {
        let w = words(text)
        guard !w.isEmpty else { return nil }
        let set = Set(w)
        if set.contains("commit") || set.contains("commits") {
            let numberWords: [String: Int] = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10]
            let count = w.compactMap { Int($0) ?? numberWords[$0] }.first.map { max(1, min($0, 10)) } ?? 3
            let skip: Set<String> = ["latest", "last", "recent", "newest", "show", "list", "get", "give", "me", "my", "the", "a", "an", "what", "whats", "are", "is", "were", "was",
                                     "commit", "commits", "on", "in", "of", "for", "from", "to", "at", "github", "repo", "repos", "repository", "repositories", "and", "can", "you",
                                     "please", "did", "i", "do", "have", "made", "make", "pushed", "push", "new", "all", "about", "history", "log", "changes"]
            let name = w.filter { !skip.contains($0) && Int($0) == nil && numberWords[$0] == nil }.last ?? ""
            return Match(connector: "github", tool: "listGitHubCommits", arguments: ["repo": name, "count": String(count)])
        }
        let repoWords: Set<String> = ["repo", "repos", "repository", "repositories"]
        if !set.isDisjoint(with: repoWords), set.isDisjoint(with: ["todoist", "notion"]), !set.isDisjoint(with: ["my", "mine", "current", "github", "list", "show", "i"]) {
            return Match(connector: "github", tool: "listGitHubRepos", arguments: [:])
        }
        if set.contains("github") || (set.contains("pull") && (set.contains("request") || set.contains("requests"))) || set.contains("pr") || set.contains("prs") {
            let what: String
            if set.contains("review") || set.contains("reviews") { what = "review" }
            else if set.contains("created") || set.contains("mine") || set.contains("opened") || set.contains("author") { what = "created" }
            else { what = "assigned" }
            return Match(connector: "github", tool: "listGitHubIssues", arguments: ["what": what, "words": ""])
        }
        if set.contains("todoist") && set.isDisjoint(with: writeVerbs) {
            let skip: Set<String> = ["todoist", "tasks", "task", "list", "what", "whats", "is", "on", "my", "the", "show", "do", "i", "have", "any", "in", "a", "about", "for", "me", "open", "today"]
            let search = w.filter { !skip.contains($0) }.prefix(3).joined(separator: " ")
            return Match(connector: "todoist", tool: "listTodoistTasks", arguments: ["search": search])
        }
        if set.contains("notion") {
            let skip: Set<String> = ["notion", "find", "search", "my", "the", "in", "for", "page", "pages", "a", "is", "there", "about", "on", "look", "up", "me", "workspace", "open", "go", "to", "check", "show", "get", "what", "whats", "do", "i", "have", "any"]
            let query = w.filter { !skip.contains($0) }.prefix(4).joined(separator: " ")
            guard !query.isEmpty else { return nil }
            return Match(connector: "notion", tool: "searchNotion", arguments: ["query": query])
        }
        return nil
    }
}
