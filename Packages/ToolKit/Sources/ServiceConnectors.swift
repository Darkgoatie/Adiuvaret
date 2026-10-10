import Foundation

/// Where each token connector may send requests. A token is only ever attached to its own host.
public enum ServiceHost {
    public static let hosts: [String: String] = ["todoist": "api.todoist.com", "github": "api.github.com", "notion": "api.notion.com"]

    public static func isAllowed(_ url: URL, for connector: String) -> Bool {
        guard let host = hosts[connector], url.scheme == "https", url.host?.lowercased() == host, url.port == nil, url.user == nil, url.password == nil else { return false }
        return true
    }
}

public enum ServiceToken {
    /// Rejects pasted text that cannot be a token, including anything that could break a header.
    public static func isPlausible(_ token: String) -> Bool {
        (16...400).contains(token.count) && !token.unicodeScalars.contains { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }
    }

    public static func clean(_ pasted: String) -> String {
        var t = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("bearer ") { t = String(t.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
        return t
    }
}

/// Requests without the token. The app adds the Authorization header at send time.
public enum ServiceRequest {
    private static func make(_ url: URL?, method: String = "GET", body: [String: Any]? = nil, headers: [String: String] = [:]) -> URLRequest? {
        guard let url else { return nil }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue("Adiuvaret", forHTTPHeaderField: "User-Agent")
        for (k, v) in headers { r.setValue(v, forHTTPHeaderField: k) }
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    public static func todoistTasks() -> URLRequest? {
        make(URL(string: "https://api.todoist.com/api/v1/tasks?limit=100"))
    }

    public static func todoistAdd(content: String, due: String) -> URLRequest? {
        let c = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty, c.count <= 300 else { return nil }
        var body: [String: Any] = ["content": c]
        let d = due.trimmingCharacters(in: .whitespacesAndNewlines)
        if !d.isEmpty { body["due_string"] = String(d.prefix(60)) }
        return make(URL(string: "https://api.todoist.com/api/v1/tasks"), method: "POST", body: body)
    }

    public static func todoistDelete(id: String) -> URLRequest? {
        guard !id.isEmpty, id.count <= 40, id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) else { return nil }
        return make(URL(string: "https://api.todoist.com/api/v1/tasks/" + id), method: "DELETE")
    }

    public static func githubSearch(query: String) -> URLRequest? {
        var parts = URLComponents(string: "https://api.github.com/search/issues")
        parts?.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "per_page", value: "10"),
                             URLQueryItem(name: "sort", value: "updated"), URLQueryItem(name: "order", value: "desc")]
        return make(parts?.url, headers: ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"])
    }

    public static func githubRepos() -> URLRequest? {
        var parts = URLComponents(string: "https://api.github.com/user/repos")
        parts?.queryItems = [URLQueryItem(name: "sort", value: "pushed"), URLQueryItem(name: "per_page", value: "15"),
                             URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member")]
        return make(parts?.url, headers: ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"])
    }

    public static func notionSearch(query: String) -> URLRequest? {
        make(URL(string: "https://api.notion.com/v1/search"), method: "POST",
             body: ["query": String(query.prefix(100)), "page_size": 8], headers: ["Notion-Version": "2022-06-28"])
    }
}

public enum GitHubQuery {
    /// "assigned", "review" or "created" pick what to list. Extra words are reduced to plain words so they cannot add search qualifiers.
    public static func build(what: String, words: String) -> String {
        let base: String
        switch what.lowercased() {
        case let w where w.contains("review"): base = "is:open is:pr review-requested:@me"
        case let w where w.contains("creat") || w.contains("mine") || w.contains("my pr") || w.contains("author"): base = "is:open author:@me"
        case let w where w.contains("assign"): base = "is:open assignee:@me"
        default: base = "is:open involves:@me"
        }
        let plain = String(String.UnicodeScalarView(words.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-" || $0 == "_" ? $0 : " " }))
        let extra = plain.split(separator: " ").prefix(6).joined(separator: " ")
        return extra.isEmpty ? base : base + " " + String(extra.prefix(60))
    }
}

private func objects(_ data: Data, key: String) -> [[String: Any]] {
    guard let o = try? JSONSerialization.jsonObject(with: data) else { return [] }
    if let a = o as? [[String: Any]] { return a }
    return ((o as? [String: Any])?[key] as? [[String: Any]]) ?? []
}

private func clip(_ s: String, _ n: Int) -> String {
    let flat = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return flat.count <= n ? flat : String(flat.prefix(n - 1)) + "…"
}

public enum TodoistParse {
    public static func tasks(_ data: Data, search: String = "", limit: Int = 25) -> [String] {
        let words = search.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 2 }
        var lines: [String] = []
        for t in objects(data, key: "results") {
            guard let content = t["content"] as? String, !content.isEmpty else { continue }
            if !words.isEmpty, !words.contains(where: { content.lowercased().contains($0) }) { continue }
            let due = (t["due"] as? [String: Any]).flatMap { ($0["string"] as? String) ?? ($0["date"] as? String) } ?? ""
            var line = clip(content, 100)
            if !due.isEmpty { line += " (due \(clip(due, 30)))" }
            if (t["priority"] as? Int) == 4 { line += " [urgent]" }
            lines.append(line)
            if lines.count == limit { break }
        }
        return lines
    }

    public static func createdID(_ data: Data) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let s = o["id"] as? String { return s }
        if let n = o["id"] as? Int { return String(n) }
        return nil
    }
}

public enum GitHubParse {
    public static func issues(_ data: Data) -> [String] {
        objects(data, key: "items").compactMap { i in
            guard let title = i["title"] as? String, let number = i["number"] as? Int else { return nil }
            let repo = ((i["repository_url"] as? String) ?? "").split(separator: "/").suffix(2).joined(separator: "/")
            let kind = i["pull_request"] != nil ? "PR" : "issue"
            let updated = String(((i["updated_at"] as? String) ?? "").prefix(10))
            return "\(repo)#\(number) \(kind): \(clip(title, 90)) (\((i["state"] as? String) ?? "open")\(updated.isEmpty ? "" : ", updated " + updated))"
        }
    }
}

extension GitHubParse {
    public static func repos(_ data: Data) -> [String] {
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return list.compactMap { r in
            guard let name = r["full_name"] as? String else { return nil }
            var tags: [String] = []
            tags.append((r["private"] as? Bool) == true ? "private" : "public")
            if (r["fork"] as? Bool) == true { tags.append("fork") }
            if (r["archived"] as? Bool) == true { tags.append("archived") }
            if let lang = r["language"] as? String, !lang.isEmpty { tags.append(lang) }
            let pushed = String(((r["pushed_at"] as? String) ?? "").prefix(10))
            if !pushed.isEmpty { tags.append("pushed " + pushed) }
            return name + " (" + tags.joined(separator: ", ") + ")"
        }
    }
}

public enum NotionParse {
    public static func results(_ data: Data) -> [String] {
        objects(data, key: "results").compactMap { r in
            let kind = (r["object"] as? String) ?? "page"
            var title = ""
            if let props = r["properties"] as? [String: Any] {
                for (_, v) in props.sorted(by: { $0.key < $1.key }) {
                    if let p = v as? [String: Any], (p["type"] as? String) == "title", let parts = p["title"] as? [[String: Any]] {
                        title = parts.compactMap { $0["plain_text"] as? String }.joined(); break
                    }
                }
            } else if let parts = r["title"] as? [[String: Any]] {
                title = parts.compactMap { $0["plain_text"] as? String }.joined()
            }
            guard !title.isEmpty || r["id"] != nil else { return nil }
            let edited = String(((r["last_edited_time"] as? String) ?? "").prefix(10))
            return "\(clip(title.isEmpty ? "Untitled" : title, 90)) (\(kind)\(edited.isEmpty ? "" : ", edited " + edited))"
        }
    }
}
