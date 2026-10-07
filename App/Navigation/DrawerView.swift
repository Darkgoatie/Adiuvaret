import SwiftUI
import DesignSystem

struct DrawerView: View {
    let chats: [ChatSummary]
    let pendingApprovals: Int
    let select: (Route) -> Void
    let pin: (UUID) -> Void
    let delete: (UUID) -> Void
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
                                .swipeActions { Button("Delete", systemImage: "trash", role: .destructive) { delete(c.id) } }
                                .swipeActions(edge: .leading) { Button(section.id == ChatSummary.Group.pinned.rawValue ? "Unpin" : "Pin", systemImage: "pin") { pin(c.id) }.tint(DS.Colors.accent) }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } header: { Text(verbatim: section.title).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
                }
            }
            .listStyle(.plain).listSectionSeparator(.hidden).scrollContentBackground(.hidden).environment(\.defaultMinListRowHeight, 44)

            footer
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            if pendingApprovals > 0 {
                Button { select(.approvalsInbox) } label: {
                    Label { Text(verbatim: String(localized: "\(pendingApprovals) waiting for your approval")).font(DS.Typography.subheadline) } icon: { Image(systemName: "checkmark.seal") }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .foregroundStyle(DS.Colors.accentText)
                .padding(.horizontal, Spacing.l)
            }
            bottomRow(String(localized: "Advanced"), symbol: "slider.horizontal.3", route: .advanced, id: "drawer.advanced")
            bottomRow(String(localized: "Settings"), symbol: "gearshape", route: .settings, id: "drawer.settings")
        }
        .padding(.bottom, Spacing.s)
    }

    private func bottomRow(_ title: String, symbol: String, route: Route, id: String) -> some View {
        Button { select(route) } label: {
            Label { Text(verbatim: title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary) }
                icon: { Image(systemName: symbol).foregroundStyle(DS.Colors.textSecondary).frame(width: 28) }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .padding(.horizontal, Spacing.l)
        .accessibilityIdentifier(id)
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
