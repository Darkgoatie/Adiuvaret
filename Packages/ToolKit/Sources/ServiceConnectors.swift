import Foundation

/// Where each token connector may send requests. A token is only ever attached to its own host.
public enum ServiceHost {
    private static let builtIn: [String: String] = ["github": "api.github.com", "notion": "api.notion.com"]

    /// Hand-wired connectors plus every manifest in the registry.
    public static let hosts: [String: String] = builtIn.merging(ConnectorRegistry.manifests.map { ($0.id, $0.host) }) { a, _ in a }

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

    public static func githubSearch(query: String) -> URLRequest? {
        var parts = URLComponents(string: "https://api.github.com/search/issues")
        parts?.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "per_page", value: "10"),
                             URLQueryItem(name: "sort", value: "updated"), URLQueryItem(name: "order", value: "desc")]
        return make(parts?.url, headers: ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"])
    }

    public static func githubRepos(perPage: Int = 15) -> URLRequest? {
        var parts = URLComponents(string: "https://api.github.com/user/repos")
        parts?.queryItems = [URLQueryItem(name: "sort", value: "pushed"), URLQueryItem(name: "per_page", value: String(max(1, min(perPage, 100)))),
                             URLQueryItem(name: "affiliation", value: "owner,collaborator,organization_member")]
        return make(parts?.url, headers: ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"])
    }

    /// The newest commits of one repository. `fullName` must look like owner/name.
    public static func githubCommits(fullName: String, count: Int) -> URLRequest? {
        let parts = fullName.split(separator: "/", omittingEmptySubsequences: false)
        let ok: (Substring) -> Bool = { !$0.isEmpty && $0.count <= 100 && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." } && !$0.hasPrefix(".") }
        guard parts.count == 2, ok(parts[0]), ok(parts[1]) else { return nil }
        var c = URLComponents(string: "https://api.github.com/repos/\(fullName)/commits")
        c?.queryItems = [URLQueryItem(name: "per_page", value: String(max(1, min(count, 10))))]
        return make(c?.url, headers: ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"])
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
    /// "abc1234 Fix the build (Halit, 2026-10-10)" for each commit, newest first as GitHub returns them.
    public static func commits(_ data: Data) -> [String] {
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return list.compactMap { c in
            guard let sha = c["sha"] as? String, let commit = c["commit"] as? [String: Any], let message = commit["message"] as? String else { return nil }
            let first = message.split(whereSeparator: \.isNewline).first.map(String.init) ?? message
            let author = (commit["author"] as? [String: Any]).flatMap { $0["name"] as? String } ?? ((c["author"] as? [String: Any])?["login"] as? String) ?? ""
            let date = String((((commit["author"] as? [String: Any])?["date"] as? String) ?? "").prefix(10))
            let who = [author, date].filter { !$0.isEmpty }.joined(separator: ", ")
            let text = first.count > 90 ? String(first.prefix(89)) + "…" : first
            return "\(sha.prefix(7)) \(text)" + (who.isEmpty ? "" : " (\(who))")
        }
    }

    /// Full names of the repositories in a repository list.
    public static func repoNames(_ data: Data) -> [String] {
        ((try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []).compactMap { $0["full_name"] as? String }
    }

    /// The repository a user meant by a short name such as "adiuvaret". An exact match on the repository part wins, then a match inside it.
    public static func pickRepo(_ asked: String, from names: [String]) -> String? {
        func flat(_ s: String) -> String { String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }) }
        let wanted = flat(asked.split(separator: "/").last.map(String.init) ?? asked)
        guard !wanted.isEmpty else { return nil }
        func part(_ n: String) -> String { flat(n.split(separator: "/").last.map(String.init) ?? n) }
        if let exact = names.first(where: { part($0) == wanted }) { return exact }
        return names.first { part($0).contains(wanted) || (wanted.count >= 4 && wanted.contains(part($0)) && part($0).count >= 4) }
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
