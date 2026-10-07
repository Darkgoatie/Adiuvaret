import SwiftUI

public struct DraftCard: View {
    public enum Kind: Sendable { case message, mail }

    let kind: Kind
    let recipient: String
    let text: String
    let onOpen: () -> Void

    public init(kind: Kind, recipient: String, text: String, onOpen: @escaping () -> Void = {}) {
        self.kind = kind; self.recipient = recipient; self.text = text; self.onOpen = onOpen
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label { Text(verbatim: kind == .message ? L("Message draft to \(recipient)") : L("Mail draft to \(recipient)")).font(DS.Typography.headline) }
                icon: { Image(systemName: kind == .message ? "message" : "envelope").foregroundStyle(DS.Colors.textSecondary) }
                .foregroundStyle(DS.Colors.textPrimary)
            Text(verbatim: text).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                .padding(Spacing.m).frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m))
            Button(kind == .message ? L("Open in Messages") : L("Open in Mail"), action: onOpen)
                .buttonStyle(DSButtonStyle(.primary)).frame(maxWidth: .infinity)
            Text(verbatim: L("You'll tap Send.")).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
        }
        .cardSurface()
    }
}

public struct MemoryChip: View {
    let text: String
    let onUndo: () -> Void
    let onWhy: () -> Void

    public init(text: String, onUndo: @escaping () -> Void = {}, onWhy: @escaping () -> Void = {}) {
        self.text = text; self.onUndo = onUndo; self.onWhy = onWhy
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label { Text(verbatim: L("Remembered: \(text)")).font(DS.Typography.footnote) }
                icon: { Image(systemName: "brain.head.profile").imageScale(.small) }
                .foregroundStyle(DS.Colors.textSecondary)
            HStack(spacing: Spacing.xs) {
                Button(L("Undo"), action: onUndo)
                Button(L("Why?"), action: onWhy)
            }
            .buttonStyle(DSButtonStyle(.quiet))
            .font(DS.Typography.footnote)
        }
    }
}

public struct SystemBanner: View {
    public enum Kind: Sendable { case info, warning, error }

    let kind: Kind
    let message: String
    let actionTitle: String?
    let onAction: () -> Void

    public init(kind: Kind, message: String, actionTitle: String? = nil, onAction: @escaping () -> Void = {}) {
        self.kind = kind; self.message = message; self.actionTitle = actionTitle; self.onAction = onAction
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: icon).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(verbatim: message).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textPrimary)
                if let actionTitle { Button(actionTitle, action: onAction).buttonStyle(DSButtonStyle(.quiet)).padding(.horizontal, -Spacing.m) }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.m))
        .accessibilityElement(children: .contain)
    }

    private var icon: String {
        switch kind { case .info: "info.circle.fill"; case .warning: "exclamationmark.triangle.fill"; case .error: "xmark.octagon.fill" }
    }
    private var tint: Color {
        switch kind { case .info: DS.Colors.textSecondary; case .warning: DS.Colors.warning; case .error: DS.Colors.danger }
    }
}

public struct StatusBadge: View {
    public enum Status: Sendable { case connected, notEnabled, needsPermission, draftOnly, comingSoon }

    let status: Status
    public init(_ status: Status) { self.status = status }

    public var body: some View {
        Label { Text(verbatim: text) } icon: { Image(systemName: icon) }
            .labelStyle(.titleAndIcon)
            .font(DS.Typography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.s).padding(.vertical, Spacing.xs)
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.s))
    }

    private var text: String {
        switch status {
        case .connected: L("Connected")
        case .notEnabled: L("Not enabled")
        case .needsPermission: L("Needs permission")
        case .draftOnly: L("Draft-only")
        case .comingSoon: L("Coming soon")
        }
    }
    private var icon: String {
        switch status {
        case .connected: "checkmark.circle.fill"
        case .notEnabled: "circle"
        case .needsPermission: "exclamationmark.triangle.fill"
        case .draftOnly: "pencil"
        case .comingSoon: "clock"
        }
    }
    private var tint: Color {
        switch status {
        case .connected: DS.Colors.success
        case .needsPermission: DS.Colors.warning
        default: DS.Colors.textSecondary
        }
    }
}

public struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let onAction: () -> Void

    public init(icon: String, title: String, message: String, actionTitle: String? = nil, onAction: @escaping () -> Void = {}) {
        self.icon = icon; self.title = title; self.message = message; self.actionTitle = actionTitle; self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(DS.Colors.textSecondary).accessibilityHidden(true)
            Text(verbatim: title).font(DS.Typography.heading).foregroundStyle(DS.Colors.textPrimary).multilineTextAlignment(.center)
            Text(verbatim: message).font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary).multilineTextAlignment(.center)
            if let actionTitle { Button(actionTitle, action: onAction).buttonStyle(DSButtonStyle(.primary)) }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

public struct SettingsRow<Trailing: View>: View {
    public enum Kind: Sendable { case navigation, value, destructive, plain }

    let title: String
    let subtitle: String?
    let kind: Kind
    let trailing: Trailing

    public init(_ title: String, subtitle: String? = nil, kind: Kind = .plain, @ViewBuilder trailing: () -> Trailing) {
        self.title = title; self.subtitle = subtitle; self.kind = kind; self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(DS.Typography.body)
                    .foregroundStyle(kind == .destructive ? DS.Colors.danger : DS.Colors.textPrimary)
                if let subtitle { Text(verbatim: subtitle).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary) }
            }
            Spacer(minLength: Spacing.s)
            trailing
            if kind == .navigation { Image(systemName: "chevron.right").imageScale(.small).foregroundStyle(DS.Colors.textSecondary) }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

public extension SettingsRow where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, kind: Kind = .plain) {
        self.init(title, subtitle: subtitle, kind: kind) { EmptyView() }
    }
}

#Preview("More") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            DraftCard(kind: .message, recipient: "Mom", text: "Running 10 minutes late, see you soon.")
            MemoryChip(text: "prefers morning meetings")
            SystemBanner(kind: .warning, message: "Your iPhone is warm. I'll answer more slowly.")
            SystemBanner(kind: .error, message: "Apple Intelligence isn't turned on.", actionTitle: "Open Settings")
            HStack { StatusBadge(.connected); StatusBadge(.needsPermission); StatusBadge(.draftOnly); StatusBadge(.comingSoon) }
            EmptyState(icon: "note.text", title: "No notes yet", message: "Ask me to write one down.", actionTitle: "Create a note")
            SettingsRow("Notifications", subtitle: "Needed for briefings", kind: .navigation)
        }.padding()
    }.background(DS.Colors.background)
}
