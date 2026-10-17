import SwiftUI

func L(_ key: String.LocalizationValue) -> String { String(localized: key, bundle: .module) }

public struct DSButtonStyle: ButtonStyle {
    public enum Kind: Sendable { case primary, secondary, quiet, destructive }
    private let kind: Kind

    public init(_ kind: Kind = .secondary) { self.kind = kind }

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, kind: kind)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let kind: Kind
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            configuration.label
                .font(DS.Typography.button)
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: 44)
                .background { backgroundView }
                .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: Radius.m))
        }

        /// Primary buttons follow the chosen effect; the others stay flat. The label colour never changes, so contrast holds.
        @ViewBuilder private var backgroundView: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.m)
            let effect = kind == .primary && enabled ? ButtonEffectStore.shared.effect : ButtonEffect.flat
            switch effect {
            case .flat:
                shape.fill(background)
            case .gradient:
                MovingGradient().clipShape(shape)
            case .glow:
                MovingGradient().clipShape(shape)
                    .background {
                        MovingGradient().clipShape(shape)
                            .blur(radius: 12).opacity(0.8).offset(y: 7)
                    }
            }
        }

        private var foreground: Color {
            switch kind {
            case .primary: DS.Colors.onAccent
            case .secondary: DS.Colors.textPrimary
            case .quiet: DS.Colors.accentText
            case .destructive: DS.Colors.danger
            }
        }

        private var background: Color {
            switch kind {
            case .primary: DS.Colors.accent
            case .secondary, .destructive: DS.Colors.surfaceRaised
            case .quiet: .clear
            }
        }
    }
}

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.l))
            .overlay(RoundedRectangle(cornerRadius: Radius.l).stroke(DS.Colors.separator, lineWidth: 0.5))
    }
}

extension View {
    func cardSurface() -> some View { modifier(CardSurface()) }
}

public struct DetailRow: Identifiable, Sendable, Equatable {
    public let id = UUID()
    public let label: String
    public let value: String
    public init(_ label: String, _ value: String) { self.label = label; self.value = value }
}

/// Lays buttons side by side when they fit, stacked when text is large.
struct AdaptiveButtonRow<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.s) { content }
            VStack(spacing: Spacing.s) { content }
        }
    }
}
