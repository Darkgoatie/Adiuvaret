import SwiftUI
import DesignSystem
import PolicyEngine
import ToolKit

/// Advanced, Activity log: every tool call the assistant made, newest first. It lists names and outcomes only,
/// never what a tool was asked or what it returned.
struct ActivityView: View {
    @State private var entries: [ActivityEntry] = ActivityStore.shared.all()
    @State private var confirmClear = false

    private static let names: [String: String] = [
        "openOtherSite": String(localized: "Open a new site"),
        "saveSkill": String(localized: "Save a skill"),
        "callAPIWrite": String(localized: "API call that changes data"),
        "approveAPIHost": String(localized: "Allow a new API host"),
        "runShellWrite": String(localized: "Shell command that changes files"),
        "runShellNetwork": String(localized: "Shell command that uses the internet"),
        "runShellDelete": String(localized: "Shell command that deletes files"),
        "actOnPageRisky": String(localized: "Page action that needed approval"),
    ]

    var body: some View {
        List {
            if entries.isEmpty {
                Section {
                    Text("Nothing yet. When I use a tool for you, such as your calendar, a website or a note, a line appears here.")
                        .font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                }
            } else {
                Section {
                    ForEach(entries) { entry in row(entry) }
                } footer: {
                    Text("The last \(ActivityStore.limit) tool calls. This list shows which tool ran and how it went, never your messages, event titles or what a tool returned. Undo stays on the card in the chat.")
                        .font(DS.Typography.caption)
                }
                Section {
                    Button(role: .destructive) { confirmClear = true } label: { Text("Clear the list").font(DS.Typography.body) }
                        .frame(minHeight: 44).accessibilityIdentifier("activity.clear")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Activity log"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { entries = ActivityStore.shared.all() }
        .refreshable { entries = ActivityStore.shared.all() }
        .confirmationDialog(String(localized: "Clear the activity log?"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button(String(localized: "Clear"), role: .destructive) { ActivityStore.shared.clear(); entries = [] }
        }
    }

    private func row(_ e: ActivityEntry) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: symbol(e)).foregroundStyle(tint(e)).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: Self.names[e.tool] ?? ToolCatalog.standard.entry(e.tool)?.title ?? e.tool).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Text(verbatim: detail(e)).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    private func detail(_ e: ActivityEntry) -> String {
        let when = e.time.formatted(date: .abbreviated, time: .shortened)
        let what: String
        switch e.outcome {
        case .done: what = e.asked ? String(localized: "Done after you approved") : String(localized: "Done")
        case .failed: what = String(localized: "Did not work")
        case .declined: what = String(localized: "You said no")
        case .blocked: what = e.reason == "killSwitch" ? String(localized: "Blocked, actions were switched off") : String(localized: "Blocked")
        }
        return what + " · " + when
    }

    private func symbol(_ e: ActivityEntry) -> String {
        switch e.outcome {
        case .done: "checkmark.circle"
        case .failed: "exclamationmark.triangle"
        case .declined: "xmark.circle"
        case .blocked: "hand.raised"
        }
    }

    private func tint(_ e: ActivityEntry) -> Color {
        switch e.outcome {
        case .done: DS.Colors.accentText
        case .failed: DS.Colors.warning
        case .declined, .blocked: DS.Colors.textSecondary
        }
    }
}
