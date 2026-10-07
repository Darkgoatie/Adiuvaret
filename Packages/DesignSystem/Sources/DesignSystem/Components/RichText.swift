import SwiftUI

/// Renders the light Markdown the on-device model writes: bold, italic, code, bullets, numbers, headings.
public struct RichText: View {
    enum Block: Equatable {
        case paragraph(String)
        case heading(String)
        case bullet(String)
        case numbered(Int, String)
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
        case .paragraph(let s):
            Text(Self.inline(s)).font(DS.Typography.body)
        case .heading(let s):
            Text(Self.inline(s)).font(DS.Typography.heading)
        case .bullet(let s):
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(verbatim: "•").font(DS.Typography.body).accessibilityHidden(true)
                Text(Self.inline(s)).font(DS.Typography.body)
            }
        case .numbered(let n, let s):
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(verbatim: "\(n).").font(DS.Typography.body).monospacedDigit().accessibilityHidden(true)
                Text(Self.inline(s)).font(DS.Typography.body)
            }
        }
    }

    static func inline(_ s: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: s, options: options)) ?? AttributedString(s)
    }

    static func blocks(from text: String) -> [Block] {
        var out: [Block] = []
        var paragraph: [String] = []
        func flush() {
            if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
        }
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { flush(); continue }
            if let h = line.firstMatch(of: /^#{1,6}\s+(.+)$/) {
                flush(); out.append(.heading(String(h.1)))
            } else if let b = line.firstMatch(of: /^[-*•]\s+(.+)$/) {
                flush(); out.append(.bullet(String(b.1)))
            } else if let n = line.firstMatch(of: /^(\d{1,3})[.)]\s+(.+)$/) {
                flush(); out.append(.numbered(Int(n.1) ?? 1, String(n.2)))
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return out
    }
}

#Preview("Rich text") {
    RichText("Here is your day:\n\n- **9:00** Standup\n- *13:00* Lunch with Ana\n\n1. First thing\n2. Second thing\n\n## Notes\nAll `clear` after 5.")
        .padding().background(DS.Colors.background)
}
