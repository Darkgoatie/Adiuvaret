import SwiftUI
import UIKit
import DesignSystem
import ModelLibrary

/// Long-press menu for a message: copy, edit, answer again, delete. Items that do not apply right now are left out.
struct MessageActions: ViewModifier {
    let item: ThreadItem
    let service: any ChatService
    @Binding var editing: EditTarget?
    let saved: () -> Void
    @State private var confirmDelete = false

    private var roles: [ThreadEditing.Role] { service.items.map(\.editingRole) }
    private var index: Int? { service.items.firstIndex { $0.id == item.id } }
    private var text: String { item.messageText ?? "" }

    func body(content: Content) -> some View {
        if let i = index, item.messageText != nil, !text.isEmpty {
            content
                .contextMenu {
                    Button(String(localized: "Copy"), systemImage: "doc.on.doc") { UIPasteboard.general.string = text }
                    if ThreadEditing.canEdit(roles, at: i, generating: service.isGenerating) {
                        Button(String(localized: "Edit"), systemImage: "pencil") { editing = EditTarget(id: item.id, text: text) }
                    }
                    if ThreadEditing.canRegenerate(roles, at: i, generating: service.isGenerating) {
                        Button(String(localized: "Answer again"), systemImage: "arrow.clockwise") { Task { await service.regenerate(item.id); saved() } }
                    }
                    if ThreadEditing.canDelete(roles, at: i, generating: service.isGenerating) {
                        Button(String(localized: "Delete"), systemImage: "trash", role: .destructive) { confirmDelete = true }
                    }
                }
                .confirmationDialog(String(localized: "Delete this message?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button(String(localized: "Delete"), role: .destructive) { service.deleteMessage(item.id); saved() }
                } message: {
                    Text("Only this message is removed. Anything I did because of it stays done.")
                }
        } else {
            content
        }
    }
}

struct EditTarget: Identifiable, Equatable {
    let id: UUID
    let text: String
}

/// Edit one of your messages. Saving answers the edited text again and removes the messages that came after it.
struct EditMessageSheet: View {
    let target: EditTarget
    let hasLater: Bool
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @FocusState private var focused: Bool

    init(target: EditTarget, hasLater: Bool, onSave: @escaping (String) -> Void) {
        self.target = target; self.hasLater = hasLater; self.onSave = onSave
        _draft = State(initialValue: target.text)
    }

    private var changed: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft != target.text }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.m) {
                TextEditor(text: $draft)
                    .font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.s)
                    .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m))
                    .frame(minHeight: 120, maxHeight: 260)
                    .focused($focused)
                    .accessibilityIdentifier("edit.field")
                if hasLater {
                    Text("Saving removes the replies and messages after this one, then answers again. Reminders or events I already made stay as they are.")
                        .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.l)
            .background(DS.Colors.background)
            .navigationTitle(String(localized: "Edit message"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save and answer")) { onSave(draft); dismiss() }.disabled(!changed).accessibilityIdentifier("edit.save")
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

extension View {
    func messageActions(_ item: ThreadItem, service: any ChatService, editing: Binding<EditTarget?>, saved: @escaping () -> Void) -> some View {
        modifier(MessageActions(item: item, service: service, editing: editing, saved: saved))
    }
}
