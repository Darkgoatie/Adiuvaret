import SwiftUI
import EventKit
import DesignSystem
import ToolKit

/// Notes and Tasks: what the assistant kept for the user and what the user wrote by hand. A task can be sent to Reminders.
struct NotesView: View {
    @State private var items: [SavedItem] = SavedItemStore.shared.all()
    @State private var filter: Filter = .all
    @State private var editing: SavedItem?
    @State private var adding = false
    @State private var message: String?

    private enum Filter: String, CaseIterable, Identifiable {
        case all, notes, tasks
        var id: String { rawValue }
        var title: String {
            switch self { case .all: String(localized: "All"); case .notes: String(localized: "Notes"); case .tasks: String(localized: "Tasks") }
        }
    }

    private var shown: [SavedItem] {
        switch filter {
        case .all: items
        case .notes: items.filter { $0.kind == .note }
        case .tasks: items.filter { $0.kind == .task }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { f in Text(verbatim: f.title).tag(f) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }
            if shown.isEmpty {
                Section {
                    Text(items.isEmpty
                         ? "Nothing here yet. Ask me to keep a note or a task, or tap Add. I keep these on this iPhone only."
                         : "Nothing in this view.")
                        .font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                }
            } else {
                Section {
                    ForEach(shown) { item in row(item) }
                        .onDelete { offsets in
                            for i in offsets { SavedItemStore.shared.remove(shown[i].id) }
                            reload()
                        }
                } footer: {
                    Text("\(items.count) of \(SavedItemRules.maxItems). Swipe to delete. Notes and tasks made from a chat say so.").font(DS.Typography.caption)
                }
            }
            if let message {
                Section { Text(verbatim: message).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Notes and Tasks"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: { Label(String(localized: "Add"), systemImage: "plus").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityIdentifier("notes.add")
            }
        }
        .onAppear(perform: reload)
        .sheet(item: $editing) { item in
            ItemEditor(item: item, isNew: false) { reload() }
        }
        .sheet(isPresented: $adding) {
            ItemEditor(item: SavedItem(kind: filter == .tasks ? .task : .note, title: "", text: "", source: .you), isNew: true) { reload() }
        }
    }

    private func row(_ item: SavedItem) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            if item.kind == .task {
                Button {
                    SavedItemStore.shared.setDone(item.id, !item.done); reload()
                } label: {
                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle").imageScale(.large)
                        .foregroundStyle(item.done ? DS.Colors.accentText : DS.Colors.textSecondary).frame(width: 44, height: 44)
                }
                .accessibilityLabel(Text(item.done ? "Mark as not done" : "Mark as done"))
                .buttonStyle(.plain)
            } else {
                Image(systemName: "note.text").foregroundStyle(DS.Colors.textSecondary).frame(width: 44, height: 44).accessibilityHidden(true)
            }
            Button { editing = item } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: item.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary).strikethrough(item.done)
                    if !item.text.isEmpty && item.text != item.title {
                        Text(verbatim: item.text).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary).lineLimit(2)
                    }
                    Text(verbatim: caption(item)).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .leading) {
            if item.kind == .task && item.reminderID == nil {
                Button { Task { await sendToReminders(item) } } label: { Label(String(localized: "To Reminders"), systemImage: "checklist") }
                    .tint(DS.Colors.accent)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func caption(_ item: SavedItem) -> String {
        var parts = [item.source == .assistant ? String(localized: "Kept from a chat") : String(localized: "Written by you")]
        parts.append(item.created.formatted(date: .abbreviated, time: .omitted))
        if item.reminderID != nil { parts.append(String(localized: "In Reminders")) }
        return parts.joined(separator: " · ")
    }

    private func sendToReminders(_ item: SavedItem) async {
        let store = EKEventStore()
        guard (try? await store.requestFullAccessToReminders()) == true else {
            message = String(localized: "Reminders access is off. You can allow it in the iPhone Settings."); return
        }
        let r = EKReminder(eventStore: store)
        r.title = item.title
        if !item.text.isEmpty && item.text != item.title { r.notes = item.text }
        r.calendar = store.defaultCalendarForNewReminders()
        do {
            try store.save(r, commit: true)
            SavedItemStore.shared.setReminder(item.id, reminderID: r.calendarItemIdentifier)
            message = String(localized: "Sent \(item.title) to Reminders.")
        } catch {
            message = String(localized: "Reminders could not save it.")
        }
        reload()
    }

    private func reload() { items = SavedItemStore.shared.all() }
}

private struct ItemEditor: View {
    let item: SavedItem
    let isNew: Bool
    let saved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind: SavedItem.Kind
    @State private var title: String
    @State private var text: String

    init(item: SavedItem, isNew: Bool, saved: @escaping () -> Void) {
        self.item = item; self.isNew = isNew; self.saved = saved
        _kind = State(initialValue: item.kind); _title = State(initialValue: item.title); _text = State(initialValue: item.text)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    Picker("Kind", selection: $kind) {
                        Text("Note").tag(SavedItem.Kind.note)
                        Text("Task").tag(SavedItem.Kind.task)
                    }
                    .pickerStyle(.segmented)
                }
                TextField("Title", text: $title).font(DS.Typography.body).frame(minHeight: 44)
                TextField("Text", text: $text, axis: .vertical).font(DS.Typography.body).lineLimit(3...12)
            }
            .scrollContentBackground(.hidden)
            .background(DS.Colors.background)
            .navigationTitle(isNew ? String(localized: "New item") : String(localized: "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) {
                        if isNew { _ = SavedItemStore.shared.add(kind: kind, title: title, text: text, source: .you) }
                        else { SavedItemStore.shared.update(item.id, title: title, text: text) }
                        saved(); dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
