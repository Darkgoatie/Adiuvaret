import SwiftUI

public struct ActionCard: View {
    public enum Phase: Sendable, Equatable { case done, undone, undoExpired }

    let phase: Phase
    let title: String
    let detail: String
    let openTitle: String?
    let onUndo: () -> Void
    let onEdit: () -> Void
    let onOpen: () -> Void

    public init(phase: Phase, title: String, detail: String, openTitle: String? = nil,
                onUndo: @escaping () -> Void = {}, onEdit: @escaping () -> Void = {}, onOpen: @escaping () -> Void = {}) {
        self.phase = phase; self.title = title; self.detail = detail; self.openTitle = openTitle
        self.onUndo = onUndo; self.onEdit = onEdit; self.onOpen = onOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Image(systemName: phase == .undone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(phase == .undone ? DS.Colors.textSecondary : DS.Colors.success)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(verbatim: title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
                    Text(verbatim: detail).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                }
            }
            switch phase {
            case .done:
                AdaptiveButtonRow {
                    Button(L("Undo"), action: onUndo).buttonStyle(DSButtonStyle(.primary))
                    Button(L("Edit"), action: onEdit).buttonStyle(DSButtonStyle(.secondary))
                    if let openTitle { Button(openTitle, action: onOpen).buttonStyle(DSButtonStyle(.quiet)) }
                }
            case .undone:
                Text(verbatim: L("Undone")).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            case .undoExpired:
                Text(verbatim: L("Undo expired")).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .cardSurface()
        .sensoryFeedback(.success, trigger: phase == .done)
        .accessibilityElement(children: .contain)
    }
}

public struct ApprovalCard: View {
    public enum Phase: Sendable, Equatable { case pending, approved, denied, timedOut }

    let phase: Phase
    let title: String
    let rows: [DetailRow]
    let actionsEnabled: Bool
    let onApprove: () -> Void
    let onEdit: () -> Void
    let onDeny: () -> Void

    public init(phase: Phase, title: String, rows: [DetailRow], actionsEnabled: Bool = true,
                onApprove: @escaping () -> Void = {}, onEdit: @escaping () -> Void = {}, onDeny: @escaping () -> Void = {}) {
        self.phase = phase; self.title = title; self.rows = rows; self.actionsEnabled = actionsEnabled
        self.onApprove = onApprove; self.onEdit = onEdit; self.onDeny = onDeny
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(verbatim: title).font(DS.Typography.headline).foregroundStyle(DS.Colors.textPrimary)
            DetailRows(rows: rows)
            switch phase {
            case .pending:
                AdaptiveButtonRow {
                    Button(L("Deny"), action: onDeny).buttonStyle(DSButtonStyle(.secondary)).accessibilityIdentifier("approval.deny")
                    Button(L("Edit"), action: onEdit).buttonStyle(DSButtonStyle(.secondary)).accessibilityIdentifier("approval.edit")
                    Button(L("Approve"), action: onApprove).buttonStyle(DSButtonStyle(.primary)).accessibilityIdentifier("approval.approve")
                }
                .disabled(!actionsEnabled)
                if !actionsEnabled {
                    Text(verbatim: L("Actions are switched off.")).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                }
            case .approved: status("checkmark.circle.fill", L("Approved"), DS.Colors.success)
            case .denied: status("xmark.circle.fill", L("Denied"), DS.Colors.textSecondary)
            case .timedOut: status("clock.badge.exclamationmark", L("Timed out, nothing was done"), DS.Colors.warning)
            }
        }
        .cardSurface()
        .sensoryFeedback(.warning, trigger: phase == .pending)
        .accessibilityElement(children: .contain)
    }

    private func status(_ icon: String, _ text: String, _ tint: Color) -> some View {
        Label { Text(verbatim: text).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
            icon: { Image(systemName: icon).foregroundStyle(tint) }
    }
}

struct DetailRows: View {
    let rows: [DetailRow]
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(rows) { r in
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: r.label).foregroundStyle(DS.Colors.textSecondary)
                        Spacer(minLength: Spacing.s)
                        Text(verbatim: r.value).foregroundStyle(DS.Colors.textPrimary).multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: r.label).foregroundStyle(DS.Colors.textSecondary)
                        Text(verbatim: r.value).foregroundStyle(DS.Colors.textPrimary)
                    }
                }
                .font(DS.Typography.subheadline)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Full-screen confirmation for irreversible or external actions.
public struct ApprovalSheet: View {
    let title: String
    let warning: String
    let rows: [DetailRow]
    let confirmTitle: String
    let onApprove: () -> Void
    let onDeny: () -> Void

    public init(title: String, warning: String, rows: [DetailRow], confirmTitle: String,
                onApprove: @escaping () -> Void, onDeny: @escaping () -> Void) {
        self.title = title; self.warning = warning; self.rows = rows; self.confirmTitle = confirmTitle
        self.onApprove = onApprove; self.onDeny = onDeny
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(verbatim: title).font(DS.Typography.title).foregroundStyle(DS.Colors.textPrimary)
            Label { Text(verbatim: warning).font(DS.Typography.body) } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(DS.Colors.warning)
            }
            .foregroundStyle(DS.Colors.textPrimary)
            DetailRows(rows: rows).cardSurface()
            Spacer(minLength: 0)
            Button(confirmTitle, action: onApprove).buttonStyle(DSButtonStyle(.primary)).frame(maxWidth: .infinity)
            Button(L("Deny"), action: onDeny).buttonStyle(DSButtonStyle(.secondary)).frame(maxWidth: .infinity)
        }
        .padding(Spacing.l)
        .background(DS.Colors.background)
    }
}

#Preview("Cards") {
    ScrollView {
        VStack(spacing: 16) {
            ActionCard(phase: .done, title: "Added 'Call mom' to Reminders", detail: "Tomorrow, 6 PM", openTitle: "Open in Reminders")
            ActionCard(phase: .undone, title: "Added 'Call mom' to Reminders", detail: "Tomorrow, 6 PM")
            ActionCard(phase: .undoExpired, title: "Added 'Call mom' to Reminders", detail: "Tomorrow, 6 PM")
            ApprovalCard(phase: .pending, title: "Create event?", rows: [DetailRow("Title", "Dentist"), DetailRow("When", "Tue 3:00-4:00 PM"), DetailRow("Calendar", "Personal")])
            ApprovalCard(phase: .timedOut, title: "Create event?", rows: [DetailRow("Title", "Dentist")])
        }.padding()
    }.background(DS.Colors.background)
}
