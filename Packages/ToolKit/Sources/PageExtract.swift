import Foundation

/// Pulls the few sentences out of a web page that answer a question: the page description, structured facts such as events and
/// prices, and the paragraphs that use the question's words. Pure logic, the app does the download.
public enum PageExtract {
    public static let maxHTML = 600_000
    private static let stop: Set<String> = [
        "the", "and", "for", "that", "this", "with", "what", "when", "where", "which", "who", "how", "are", "was", "were", "does", "did", "has", "have",
        "not", "you", "your", "from", "about", "into", "than", "then", "them", "they", "their", "can", "will", "would", "could", "should", "there", "here",
        "any", "all", "get", "got", "give", "tell", "show", "find", "search", "look", "latest", "current", "today", "now", "please"]

    public static func terms(_ query: String) -> [String] {
        var out: [String] = []
        for raw in query.lowercased().split(whereSeparator: { !($0.isLetter || $0.isNumber) }) {
            var w = String(raw)
            if w.count < 3 || stop.contains(w) { continue }
            if w.count > 4, w.hasSuffix("s") { w.removeLast() }
            if !out.contains(w) { out.append(w) }
            if out.count == 8 { break }
        }
        return out
    }

    public static func excerpt(html rawHTML: String, query: String, limit: Int = 520) -> String {
        let html = String(rawHTML.prefix(maxHTML))
        var parts: [String] = []
        if let meta = metaDescription(html) { parts.append(meta) }
        parts += facts(html)
        let words = terms(query)
        let found = passages(html, terms: words)
        parts += found
        if found.count < 2 { parts += embedded(html, terms: words) }
        var seen = Set<String>()
        let unique = parts.filter { seen.insert(String($0.lowercased().prefix(40))).inserted }
        return SnapshotFormat.clip(unique.joined(separator: " | "), limit)
    }

    private static func groups(_ pattern: String, in text: String) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { i in m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i)) }
        }
    }

    static func metaDescription(_ html: String) -> String? {
        for tag in groups(#"<meta\s[^>]*>"#, in: html).map({ $0[0] }) {
            let low = tag.lowercased()
            guard low.contains("og:description") || low.contains("name=\"description\"") || low.contains("name='description'") else { continue }
            guard let c = groups(#"content=(?:"([^"]*)"|'([^']*)')"#, in: tag).first else { continue }
            let text = WebSearch.clean(c[1].isEmpty ? c[2] : c[1])
            if text.count >= 20 { return text }
        }
        return nil
    }

    static func facts(_ html: String) -> [String] {
        var out: [String] = []
        for m in groups(#"<script[^>]*application/ld\+json[^>]*>(.*?)</script>"#, in: html) {
            guard let data = m[1].data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            collect(json, depth: 0, into: &out)
            if out.count >= 3 { break }
        }
        return Array(out.prefix(3))
    }

    private static func collect(_ node: Any, depth: Int, into out: inout [String]) {
        guard depth < 6, out.count < 3 else { return }
        if let list = node as? [Any] {
            for item in list { collect(item, depth: depth + 1, into: &out) }
            return
        }
        guard let dict = node as? [String: Any] else { return }
        let types: [String] = (dict["@type"] as? String).map { [$0] } ?? (dict["@type"] as? [String]) ?? []
        if types.contains(where: { $0.hasSuffix("Event") }), let name = dict["name"] as? String {
            var line = "Event: " + name
            if let start = dict["startDate"] as? String { line += ", " + start }
            if let place = (dict["location"] as? [String: Any])?["name"] as? String { line += ", at " + place }
            out.append(WebSearch.clean(line))
        } else if types.contains("Product"), let name = dict["name"] as? String {
            var line = "Product: " + name
            let offer = (dict["offers"] as? [String: Any]) ?? (dict["offers"] as? [[String: Any]])?.first
            if let price = offer?["price"] { line += ", price \(price) " + ((offer?["priceCurrency"] as? String) ?? "") }
            out.append(WebSearch.clean(line))
        }
        for key in ["@graph", "mainEntity", "itemListElement", "item"] {
            if let child = dict[key] { collect(child, depth: depth + 1, into: &out) }
        }
    }

    /// Text held in a page's data blocks (such as __NEXT_DATA__), for sites that fill their pages in with JavaScript.
    static func embedded(_ html: String, terms: [String]) -> [String] {
        guard !terms.isEmpty else { return [] }
        var out: [String] = []
        for m in groups(#"<script[^>]*(?:id="__NEXT_DATA__"|type="application/json")[^>]*>(.*?)</script>"#, in: html) {
            guard let data = m[1].data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            var budget = 6000
            walk(json, terms, &out, &budget)
            if out.count >= 2 { break }
        }
        return Array(out.prefix(2).map { SnapshotFormat.clip($0, 220) })
    }

    private static func walk(_ node: Any, _ terms: [String], _ out: inout [String], _ budget: inout Int) {
        guard budget > 0, out.count < 4 else { return }
        budget -= 1
        if let s = node as? String {
            let t = WebSearch.clean(s)
            guard t.count >= 20, t.count <= 300 else { return }
            let lower = t.lowercased()
            if terms.filter({ lower.contains($0) }).count >= min(2, terms.count) { out.append(t) }
        } else if let list = node as? [Any] {
            for item in list { walk(item, terms, &out, &budget) }
        } else if let dict = node as? [String: Any] {
            for key in dict.keys.sorted() { if let v = dict[key] { walk(v, terms, &out, &budget) } }
        }
    }

    static func passages(_ html: String, terms: [String]) -> [String] {
        let body = html.replacingOccurrences(of: #"<(script|style|noscript|svg|nav|footer|header|form|aside)\b.*?</\1>"#, with: " ",
                                             options: [.regularExpression, .caseInsensitive])
        var rows: [(index: Int, text: String, score: Int)] = []
        for (i, m) in groups(#"<(p|li|tr|h2|h3|dd)(?:\s[^>]*)?>(.*?)</\1>"#, in: body).enumerated() {
            let inner = m[2].replacingOccurrences(of: #"</t[dh]>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            let text = WebSearch.clean(inner)
            guard text.count >= (m[1].lowercased() == "p" ? 50 : 25), text.count <= 1500 else { continue }
            let lower = text.lowercased()
            if lower.contains("cookie") || lower.contains("privacy policy") || lower.contains("all rights reserved") { continue }
            rows.append((i, text, terms.filter { lower.contains($0) }.count))
        }
        let pool = terms.isEmpty ? Array(rows.prefix(2)) : rows.filter { $0.score > 0 }
        let best = pool.sorted { ($0.score, -$0.index) > ($1.score, -$1.index) }.prefix(3).sorted { $0.index < $1.index }
        return best.map { SnapshotFormat.clip($0.text, 220) }
    }
}
