import SwiftUI

public struct MessageBubble: View {
    public enum Role: Sendable { case user, assistant }

    let role: Role
    let text: String
    let isStreaming: Bool
    let model: ModelPrivacyChip?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(role: Role, text: String, isStreaming: Bool = false, model: ModelPrivacyChip? = nil) {
        self.role = role; self.text = text; self.isStreaming = isStreaming; self.model = model
    }

    public var body: some View {
        switch role {
        case .user: userBubble
        case .assistant: assistantText
        }
    }

    private var userBubble: some View {
        HStack(spacing: 0) {
            Spacer(minLength: Spacing.xl * 2)
            Text(verbatim: text)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
                .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.l))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: L("You said: \(text)")))
    }

    private var assistantText: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                Text(verbatim: text)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .textSelection(.enabled)
                if isStreaming {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(DS.Colors.textSecondary)
                        .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
                        .accessibilityHidden(true)
                }
            }
            if let model, !isStreaming { model }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: isStreaming ? L("Adiuvaret is writing: \(text)") : L("Adiuvaret said: \(text)")))
    }
}

public struct ErrorMessageRow: View {
    let message: String
    let onRetry: () -> Void
    let onTryOther: (() -> Void)?

    public init(message: String, onRetry: @escaping () -> Void, onTryOther: (() -> Void)? = nil) {
        self.message = message; self.onRetry = onRetry; self.onTryOther = onTryOther
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Label { Text(verbatim: message).font(DS.Typography.body) } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(DS.Colors.danger)
            }
            .foregroundStyle(DS.Colors.textPrimary)
            AdaptiveButtonRow {
                Button(L("Retry"), action: onRetry).buttonStyle(DSButtonStyle(.secondary))
                if let onTryOther { Button(L("Try a different model"), action: onTryOther).buttonStyle(DSButtonStyle(.quiet)) }
            }
        }
        .cardSurface()
    }
}

#Preview("Messages") {
    VStack(alignment: .leading, spacing: 16) {
        MessageBubble(role: .user, text: "Book me a dentist slot Tuesday")
        MessageBubble(role: .assistant, text: "Tuesday 3:00 PM is free.", model: ModelPrivacyChip(model: "Apple", kind: .onDevice, prominent: false))
        MessageBubble(role: .assistant, text: "Let me check", isStreaming: true)
        ErrorMessageRow(message: "I couldn't finish that.", onRetry: {}, onTryOther: {})
    }
    .padding().background(DS.Colors.background)
}
