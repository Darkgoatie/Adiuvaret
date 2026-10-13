import Foundation

/// Rules for what the web tools may open and which actions need the user's approval. Pure logic, no web view.
public enum WebPolicy {
    public enum Verdict: Equatable, Sendable {
        case allowed(URL)
        case rejected(String)

        /// The site name for an approval card, or the reason it was refused.
        public var hostText: String {
            switch self {
            case .allowed(let url): WebPolicy.host(of: url)
            case .rejected(let why): why
            }
        }
    }

    public static let maxURLLength = 2000

    /// Turns what the model or user wrote into a safe https address, or says why not.
    /// Adds https when missing, upgrades http, and refuses other schemes, user names in the address,
    /// custom ports, and anything that points at the user's own network (localhost, IP addresses, .local names).
    public static func normalize(_ input: String) -> Verdict {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .rejected("No web address was given.") }
        guard text.count <= maxURLLength else { return .rejected("That web address is too long.") }
        if text.hasPrefix("//") { text = "https:" + text }
        if !text.contains("://") {
            if text.firstMatch(of: /^[a-zA-Z][a-zA-Z0-9+\-]*:(?!\d)/) != nil {
                return .rejected("Only web addresses (https) can be opened.")
            }
            text = "https://" + text
        }
        guard var parts = URLComponents(string: text), let scheme = parts.scheme?.lowercased() else {
            return .rejected("That is not a valid web address.")
        }
        guard scheme == "https" || scheme == "http" else { return .rejected("Only web addresses (https) can be opened.") }
        guard parts.user == nil, parts.password == nil else { return .rejected("Addresses with a user name or password are not allowed.") }
        guard let rawHost = parts.host, !rawHost.isEmpty else { return .rejected("That is not a valid web address.") }
        let host = canonicalHost(rawHost)
        if isBlockedHost(host) { return .rejected("That address is private or not a normal website.") }
        if let port = parts.port, port != 443, port != 80 { return .rejected("Addresses with a custom port are not allowed.") }
        parts.scheme = "https"
        parts.port = nil
        parts.host = host
        guard let url = parts.url else { return .rejected("That is not a valid web address.") }
        return .allowed(url)
    }

    public static func canonicalHost(_ host: String) -> String {
        var h = host.lowercased()
        while h.hasSuffix(".") { h.removeLast() }
        return h
    }

    public static func host(of url: URL) -> String { canonicalHost(url.host ?? "") }

    /// Hosts that are not public websites: no dot, local suffixes, IPv6 and every IP address form.
    public static func isBlockedHost(_ host: String) -> Bool {
        let h = canonicalHost(host)
        if h.isEmpty || !h.contains(".") || h.contains(":") || h.hasPrefix("[") { return true }
        for suffix in [".localhost", ".local", ".internal", ".localdomain", ".lan", ".home", ".corp", ".intranet"] where h.hasSuffix(suffix) { return true }
        if h == "localhost" { return true }
        if h.allSatisfy({ $0.isNumber || $0 == "." }) { return true }
        if let last = h.split(separator: ".").last, last.allSatisfy(\.isNumber) { return true }
        return false
    }

    private static func siteKey(_ host: String) -> String {
        let h = canonicalHost(host)
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }

    /// Same site means the same name or a sub-domain of it: `shop.example.com` belongs to `example.com`, `example.com.evil.net` does not.
    public static func isSameSite(_ host: String, as allowed: String) -> Bool {
        let h = siteKey(host), a = siteKey(allowed)
        return !a.isEmpty && (h == a || h.hasSuffix("." + a))
    }

    public static func isAllowed(_ host: String, in allowed: [String]) -> Bool {
        allowed.contains { isSameSite(host, as: $0) }
    }

    /// Sites whose sign-in lives on a sibling host of the same organisation. Opening the first allows the whole organisation's domain for the chat.
    public static func relatedSites(of host: String) -> [String] {
        ["tum.de"].filter { isSameSite(host, as: $0) }
    }

    private static let riskyWords: Set<String> = [
        "pay", "payment", "paypal", "buy", "purchase", "order", "checkout", "submit", "send", "post", "publish",
        "delete", "remove", "confirm", "subscribe", "unsubscribe", "donate", "transfer", "withdraw", "login", "signin",
        "register", "book", "reserve", "upgrade", "apply"
    ]
    private static let riskyPhrases = ["check out", "sign in", "log in", "sign up", "place order", "cancel order", "cancel subscription", "close account"]

    /// Clicks that could buy, send, delete or sign in. The label is page text, so the rule is in code and the model cannot talk its way past it.
    public static func clickNeedsApproval(label: String) -> Bool {
        let lower = label.lowercased()
        if riskyPhrases.contains(where: { lower.contains($0) }) { return true }
        let words = lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        return words.contains { riskyWords.contains($0) }
    }

    private static let loginWords: Set<String> = ["login", "log", "in", "signin", "sign", "anmelden", "einloggen", "anmeldung", "giris", "oturum", "ac", "my", "to", "account", "user", "tumonline", "tum"]

    /// A link that only leads to a sign-in page. Opening it changes nothing, so it needs no approval; pressing a submit button on that page still does.
    public static func isLoginLink(role: String, label: String) -> Bool {
        guard role == "link" else { return false }
        let words = label.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        guard !words.isEmpty, words.count <= 4, words.allSatisfy({ loginWords.contains($0) }) else { return false }
        return words.contains { ["login", "signin", "anmelden", "einloggen", "anmeldung", "giris", "oturum"].contains($0) } || (words.contains("log") && words.contains("in")) || (words.contains("sign") && words.contains("in"))
    }

    /// Fields the assistant never fills: passwords, card details and one-time codes. The user types these.
    public static func isSensitiveField(type: String?, auto: String?) -> Bool {
        if type?.lowercased() == "password" { return true }
        let a = (auto ?? "").lowercased()
        return a.contains("password") || a.contains("cc-") || a.contains("one-time-code")
    }
}
