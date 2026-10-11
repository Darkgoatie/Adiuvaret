import SwiftUI
import DesignSystem
import BriefingKit

/// Briefings and automations: the list, a switch per briefing, and the background-refresh record from the spike.
struct BriefingsView: View {
    let open: (UUID) -> Void
    @Bindable private var hub = BriefingHub.shared
    @State private var editing: Briefing?
    @State private var isNew = false

    var body: some View {
        List {
            if hub.permission == .denied {
                Section {
                    Text("Notifications are off for Adiuvaret, so a briefing cannot wake you. Turn them on in iOS Settings, or open a briefing from this list.")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
            }
            Section {
                ForEach(hub.briefings) { b in
                    HStack(spacing: Spacing.m) {
                        Button { open(b.id) } label: {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(verbatim: b.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                                Text(verbatim: BriefingSchedule.summary(b, weekdayNames: Calendar.current.shortWeekdaySymbols, every: String(localized: "Every day")))
                                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .accessibilityHint(Text("Runs this briefing now"))
                        Button { isNew = false; editing = b } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                            .accessibilityLabel(Text("Edit \(b.title)"))
                        Toggle("", isOn: Binding(get: { b.enabled }, set: { var c = b; c.enabled = $0; hub.save(c); Task { await ensurePermission() } }))
                            .labelsHidden().tint(DS.Colors.accent)
                            .accessibilityLabel(Text("\(b.title) on"))
                    }
                }
                Button { isNew = true; editing = Briefing(title: String(localized: "Morning")) } label: {
                    Label("New briefing", systemImage: "plus").font(DS.Typography.body)
                }
                .frame(minHeight: 44)
                .disabled(hub.briefings.count >= BriefingLimits.maxBriefings)
                .accessibilityIdentifier("briefings.new")
            } footer: {
                Text("At the chosen time you get a short notice with counts and times. Tap it and I read your calendar and reminders and write the briefing. A briefing can only read, it never creates or changes anything.")
                    .font(DS.Typography.caption)
            }
            Section("Background refresh") {
                let s = hub.attempts.summary()
                row(String(localized: "Requested"), "\(s.scheduled)")
                row(String(localized: "Ran"), "\(s.ran)")
                row(String(localized: "Expired"), "\(s.expired)")
                row(String(localized: "Last run"), s.lastRun?.formatted(date: .abbreviated, time: .shortened) ?? String(localized: "never"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Briefings"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await hub.refreshPermission() }
        .sheet(item: $editing) { b in
            NavigationStack { BriefingEditor(briefing: b, isNew: isNew) { saved in
                hub.save(saved); editing = nil; Task { await ensurePermission() }
            } delete: { hub.delete(b.id); editing = nil } }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title).font(DS.Typography.body); Spacer(); Text(verbatim: value).font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary) }
            .frame(minHeight: 44)
            .accessibilityElement(children: .combine)
    }

    private func ensurePermission() async {
        await hub.refreshPermission()
        if hub.permission == .notDetermined, hub.briefings.contains(where: \.enabled) { await hub.requestPermission() }
    }
}

private struct BriefingEditor: View {
    @State var briefing: Briefing
    let isNew: Bool
    let save: (Briefing) -> Void
    let delete: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var time: Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: briefing.hour, minute: briefing.minute, second: 0, of: Date()) ?? Date() },
                set: { let c = Calendar.current.dateComponents([.hour, .minute], from: $0); briefing.hour = c.hour ?? 8; briefing.minute = c.minute ?? 0 })
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $briefing.title).font(DS.Typography.body)
                DatePicker("Time", selection: time, displayedComponents: .hourAndMinute).font(DS.Typography.body)
            }
            Section("Days") {
                HStack(spacing: Spacing.xs) {
                    ForEach(1...7, id: \.self) { d in
                        let on = briefing.weekdays.contains(d)
                        Button {
                            if on { briefing.weekdays.removeAll { $0 == d } } else { briefing.weekdays = (briefing.weekdays + [d]).sorted() }
                        } label: {
                            Text(verbatim: String(Calendar.current.veryShortWeekdaySymbols[d - 1]))
                                .font(DS.Typography.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(on ? DS.Colors.onAccent : DS.Colors.textPrimary)
                                .background(on ? DS.Colors.accent : DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.s))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: Calendar.current.weekdaySymbols[d - 1]))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            Section {
                Toggle("Calendar", isOn: $briefing.includeCalendar).tint(DS.Colors.accent)
                Toggle("Reminders", isOn: $briefing.includeReminders).tint(DS.Colors.accent)
                TextField("Anything else, such as a team result", text: $briefing.extra, axis: .vertical).font(DS.Typography.body)
            } header: { Text("Include") } footer: {
                Text("Extra words are searched on the web when you open the briefing.").font(DS.Typography.caption)
            }
            Section {
                Toggle("Show event titles on the lock screen", isOn: $briefing.titlesOnLockScreen).tint(DS.Colors.accent)
            } footer: {
                Text("Off by default. The notice then shows only how many events there are and when the first one starts.").font(DS.Typography.caption)
            }
            if !isNew {
                Section { Button("Delete briefing", role: .destructive, action: delete).frame(minHeight: 44) }
            }
        }
        .navigationTitle(isNew ? String(localized: "New briefing") : String(localized: "Edit briefing"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(Briefing(id: briefing.id, title: briefing.title.isEmpty ? String(localized: "Briefing") : briefing.title, hour: briefing.hour, minute: briefing.minute, weekdays: briefing.weekdays, enabled: briefing.enabled, includeCalendar: briefing.includeCalendar, includeReminders: briefing.includeReminders, extra: briefing.extra, titlesOnLockScreen: briefing.titlesOnLockScreen)) }
                    .disabled(briefing.weekdays.isEmpty || (!briefing.includeCalendar && !briefing.includeReminders && briefing.extra.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
    }
}
