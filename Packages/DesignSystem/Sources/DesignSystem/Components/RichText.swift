import SwiftUI

/// Renders the light Markdown the on-device model writes: bold, italic, code, bullets, numbers, headings, code blocks.
public struct RichText: View {
    nonisolated enum Block: Equatable {
        case table(DataTable)
        case chart(ChartSpec)
        case paragraph(String)
        case heading(String)
        case bullet(String)
        case subBullet(String)
        case numbered(Int, String)
        case code(String)
    }

    let text: String

    public init(_ text: String) { self.text = text }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(Array(Self.blocks(from: text).enumerated()), id: \.offset) { _, block in
                row(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func row(_ block: Block) -> some View {
        switch block {
        case .table(let t):
            DataTableView(table: t)
        case .chart(let c):
            ChartBlockView(spec: c)
        case .paragraph(let s):
            Text(Self.inline(s)).font(DS.Typography.body)
        case .heading(let s):
            Text(Self.inline(s)).font(DS.Typography.heading)
        case .bullet(let s):
            marker("•", s, indent: 0)
        case .subBullet(let s):
            marker("–", s, indent: Spacing.l)
        case .numbered(let n, let s):
            marker("\(n).", s, indent: 0)
        case .code(let s):
            Text(verbatim: s)
                .font(.system(.callout, design: .monospaced))
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.l))
        }
    }

    private func marker(_ mark: String, _ s: String, indent: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(verbatim: mark).font(DS.Typography.body).monospacedDigit().accessibilityHidden(true)
            Text(Self.inline(s)).font(DS.Typography.body)
        }
        .padding(.leading, indent)
    }

    nonisolated static func inline(_ s: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: closeDangling(s), options: options)) ?? AttributedString(s)
    }

    /// While a reply streams, a bold marker may be open. Drop the last unmatched `**` so no asterisks flash on screen.
    nonisolated static func closeDangling(_ s: String) -> String {
        guard s.components(separatedBy: "**").count % 2 == 0, let r = s.range(of: "**", options: .backwards) else { return s }
        var out = s
        out.removeSubrange(r)
        return out
    }

    /// A line made only of -, *, _ or bullet characters: a horizontal rule or a marker with no text yet.
    nonisolated static func isRuleOrLoneMarker(_ line: String) -> Bool {
        let marks: Set<Character> = ["-", "*", "_", "•"]
        return !line.isEmpty && line.allSatisfy { marks.contains($0) || $0 == " " }
    }

    nonisolated static func blocks(from text: String) -> [Block] {
        var out: [Block] = []
        var paragraph: [String] = []
        var fence: [String]?
        var fenceLanguage = ""
        var pipes: [String] = []
        func flush() {
            flushPipes()
            if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
        }
        func flushPipes() {
            guard !pipes.isEmpty else { return }
            if let t = RichData.markdownTable(pipes) { out.append(.table(t)) }
            else { paragraph.append(contentsOf: pipes) }
            pipes = []
        }
        func closeFence(_ lines: [String]) {
            let body = lines.joined(separator: "\n")
            switch fenceLanguage {
            case "csv": if let t = RichData.csv(body) { out.append(.table(t)) } else { out.append(.code(body)) }
            case "chart": if let c = RichData.chart(body) { out.append(.chart(c)) } else { out.append(.code(body)) }
            default: out.append(.code(body))
            }
        }
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if let open = fence { closeFence(open); fence = nil }
                else { flush(); fence = []; fenceLanguage = line.dropFirst(3).trimmingCharacters(in: .whitespaces).lowercased() }
                continue
            }
            if fence != nil { fence?.append(String(raw)); continue }
            let indented = raw.prefix(while: { $0 == " " || $0 == "\t" }).count >= 2
            if line.contains("|"), line.hasPrefix("|") || line.hasSuffix("|") {
                if pipes.isEmpty, !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
                pipes.append(line)
                continue
            } else if !pipes.isEmpty { flushPipes() }
            if line.isEmpty { flush(); continue }
            if Self.isRuleOrLoneMarker(line) { flush(); continue }
            if let h = line.firstMatch(of: /^#{1,6}\s+(.+)$/) {
                flush(); out.append(.heading(String(h.1)))
            } else if let b = line.firstMatch(of: /^[-*•]\s+(.+)$/) {
                flush(); out.append(indented ? .subBullet(String(b.1)) : .bullet(String(b.1)))
            } else if let n = line.firstMatch(of: /^(\d{1,3})[.)]\s+(.+)$/) {
                flush(); out.append(.numbered(Int(n.1) ?? 1, String(n.2)))
            } else {
                paragraph.append(line)
            }
        }
        if let open = fence { closeFence(open) }
        flush()
        return out
    }
}

#Preview("Rich text") {
    RichText("Here is your day:\n\n- **9:00** Standup\n- *13:00* Lunch with Ana\n  - bring slides\n\n1. First thing\n2. Second thing\n\n## Notes\nAll `clear` after 5.\nNext line stays on its own line.\n\n```\nlet x = 1\n```")
        .padding().background(DS.Colors.background)
}
