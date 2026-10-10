import SwiftUI
import EventKit
import DesignSystem

/// Section in Integrations: choose where new events are created.
struct CalendarChoiceSection: View {
    @State private var options: [(id: String, label: String)] = []
    @State private var selected = CalendarChoice.identifier ?? ""
    @State private var needsAccess = false

    var body: some View {
        Section {
            if needsAccess {
                Button(String(localized: "Allow calendar access")) { Task { await load(ask: true) } }
                    .font(DS.Typography.body).foregroundStyle(DS.Colors.accentText).frame(minHeight: 44)
                    .accessibilityIdentifier("integration.calendar.allow")
            } else {
                Picker(String(localized: "New events go to"), selection: $selected) {
                    Text("Calendar default").tag("")
                    ForEach(options, id: \.id) { Text(verbatim: $0.label).tag($0.id) }
                }
                .frame(minHeight: 44).accessibilityIdentifier("integration.calendar.pick")
                .onChange(of: selected) { _, new in CalendarChoice.identifier = new.isEmpty ? nil : new }
            }
        } header: {
            Text("Calendar")
        } footer: {
            Text("Events keep the account they come from, for example Google or iCloud. This only decides where new ones are saved.")
        }
        .task { await load(ask: false) }
    }

    private func load(ask: Bool) async {
        let store = EKEventStore()
        var status = EKEventStore.authorizationStatus(for: .event)
        if ask, status == .notDetermined { _ = try? await store.requestFullAccessToEvents(); status = EKEventStore.authorizationStatus(for: .event) }
        needsAccess = status != .fullAccess
        guard !needsAccess else { return }
        options = CalendarChoice.writable(in: store).map { ($0.calendarIdentifier, CalendarStore.label($0)) }
        if !options.contains(where: { $0.id == selected }) { selected = "" }
    }
}

#Preview { List { CalendarChoiceSection() } }
