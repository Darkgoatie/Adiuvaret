import SwiftUI
import DesignSystem

struct DrawerView: View {
    let chats: [ChatSummary]
    var activeID: UUID? = nil
    var isOpen = true
    let select: (Route) -> Void
    let pin: (UUID) -> Void
    let delete: (UUID) -> Void
    let rename: (UUID, String) -> Void
    @State private var query = ""
    @State private var renaming: ChatSummary?
    @State private var newName = ""
    @State private var flash = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Button { select(.newChat) } label: { Label("New chat", systemImage: "square.and.pencil").frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(DSButtonStyle(.primary))
                    .accessibilityIdentifier("drawer.newChat")
                HStack(spacing: Spacing.s) {
                    Image(systemName: "magnifyingglass").foregroundStyle(DS.Colors.textSecondary).accessibilityHidden(true)
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
                            Button { select(.chat(c.id)) } label: { row(c) }
                                .swipeActions { Button("Delete", systemImage: "trash", role: .destructive) { delete(c.id) } }
                                .swipeActions(edge: .leading) { Button(section.id == ChatSummary.Group.pinned.rawValue ? "Unpin" : "Pin", systemImage: "pin") { pin(c.id) }.tint(DS.Colors.accent) }
                                .listRowBackground(Color.clear)
                                .contextMenu {
                                    Button("Rename", systemImage: "pencil") { newName = c.title; renaming = c }
                                    Button(section.id == ChatSummary.Group.pinned.rawValue ? "Unpin" : "Pin", systemImage: "pin") { pin(c.id) }
                                    Button("Delete", systemImage: "trash", role: .destructive) { delete(c.id) }
                                }
                                .listRowSeparator(.hidden)
                        }
                    } header: { Text(verbatim: section.title).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
                }
            }
            .listStyle(.plain).listSectionSeparator(.hidden).scrollContentBackground(.hidden).environment(\.defaultMinListRowHeight, Self.rowHeight)

            footer
        }
        .onChange(of: isOpen) { _, open in
            guard open, activeID != nil else { return }
            withAnimation(.easeIn(duration: 0.15)) { flash = true }
            Task {
                try? await Task.sleep(for: .milliseconds(1200))
                withAnimation(.easeOut(duration: 0.5)) { flash = false }
            }
        }
        .alert("Rename chat", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Save") { if let c = renaming { rename(c.id, newName) } }
        }
    }

    /// History rows are 34 pt, down from 44.
    private static let rowHeight: CGFloat = 34

    /// One history row. The open chat gets a short vertical bar on its left edge, and a soft highlight for a moment after the drawer opens.
    private func row(_ c: ChatSummary) -> some View {
        let active = c.id == activeID
        return HStack(spacing: Spacing.s) {
            Group {
                if active { EffectBackground(cornerRadius: 1.5, flat: DS.Colors.accent) } else { Color.clear }
            }
            .frame(width: 3, height: 18)
            Text(verbatim: c.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary).lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(minHeight: Self.rowHeight, alignment: .leading)
        .background {
            if active && flash { EffectBackground(cornerRadius: Radius.s, flat: DS.Colors.accent).opacity(0.18) }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
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
