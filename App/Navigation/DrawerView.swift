import SwiftUI
import DesignSystem

struct DrawerView: View {
    let chats: [ChatSummary]
    let pendingApprovals: Int
    let select: (Route) -> Void
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Button { select(.newChat) } label: { Label("New chat", systemImage: "square.and.pencil").frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(DSButtonStyle(.primary))
                    .accessibilityIdentifier("drawer.newChat")
                HStack(spacing: Spacing.s) {
                    Image(systemName: "magnifyingglass").foregroundStyle(DS.Colors.textSecondary)
                    TextField("Search", text: $query).font(DS.Typography.body)
                }
                .padding(.horizontal, Spacing.m).frame(minHeight: 44)
                .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m))
            }
            .padding(Spacing.l)

            List {
                ForEach(filtered) { section in
                    Section {
                        ForEach(section.chats) { c in
                            Button { select(.chat(c.id)) } label: { Text(verbatim: c.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary).frame(minHeight: 44, alignment: .leading) }
                                .swipeActions { Button("Delete", systemImage: "trash", role: .destructive) {} }
                                .swipeActions(edge: .leading) { Button("Pin", systemImage: "pin") {}.tint(DS.Colors.accent) }
                                .listRowBackground(Color.clear)
                        }
                    } header: { Text(verbatim: section.title).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
                }
                Section {
                    ForEach(DrawerDestination.allCases) { d in
                        Button { select(d.route) } label: {
                            Label { Text(verbatim: d.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary) } icon: { Image(systemName: d.symbol).foregroundStyle(DS.Colors.textSecondary) }
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain).scrollContentBackground(.hidden).environment(\.defaultMinListRowHeight, 44)

            footer
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Divider()
            if pendingApprovals > 0 {
                Button { select(.approvalsInbox) } label: {
                    Label { Text(verbatim: String(localized: "\(pendingApprovals) waiting for your approval")).font(DS.Typography.subheadline) } icon: { Image(systemName: "checkmark.seal") }
                        .frame(minHeight: 44, alignment: .leading)
                }.foregroundStyle(DS.Colors.accentText)
            }
            ModelPrivacyChip(model: String(localized: "Local only"), kind: .onDevice)
        }
        .padding(Spacing.l)
    }

    private struct Section_: Identifiable { let id: Int; let title: String; let chats: [ChatSummary] }
    private var filtered: [Section_] {
        let titles = [ChatSummary.Group.pinned: String(localized: "Pinned"), .today: String(localized: "Today"), .yesterday: String(localized: "Yesterday"), .week: String(localized: "Previous 7 days"), .older: String(localized: "Older")]
        return ChatSummary.Group.allCases.compactMap { g in
            let cs = chats.filter { $0.group == g && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)) }
            return cs.isEmpty ? nil : Section_(id: g.rawValue, title: titles[g] ?? "", chats: cs)
        }
    }
}
