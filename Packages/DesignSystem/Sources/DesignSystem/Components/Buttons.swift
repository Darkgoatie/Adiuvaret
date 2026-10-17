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

        @ViewBuilder private var backgroundView: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.m)
            if kind == .primary && enabled {
                GrainyShimmer(base: DS.Colors.accent).clipShape(shape)
            } else {
                shape.fill(background)
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

/// A button background with a soft highlight that sweeps across it and a fixed film grain on top. Still when Reduce Motion is on.
struct GrainyShimmer: View {
    let base: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let period = 3.6

    var body: some View {
        ZStack {
            base
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let phase = reduceMotion ? 0.35 : (t.truncatingRemainder(dividingBy: Self.period)) / Self.period
                LinearGradient(
                    stops: [.init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.32), location: 0.5),
                            .init(color: .clear, location: 1)],
                    startPoint: UnitPoint(x: phase * 2.4 - 1.2, y: 0.2),
                    endPoint: UnitPoint(x: phase * 2.4 - 0.2, y: 0.8))
            }
            Grain().blendMode(.overlay).opacity(0.55)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Random specks from a fixed seed, so the grain is the same on every draw and does not flicker.
    private struct Grain: View {
        var body: some View {
            Canvas { context, size in
                var state: UInt64 = 0x9E37_79B9_7F4A_7C15
                func next() -> Double {
                    state = state &* 6364136223846793005 &+ 1442695040888963407
                    return Double(state >> 33) / Double(1 << 31)
                }
                let count = Int(size.width * size.height / 5)
                for _ in 0..<count {
                    let x = next() * size.width, y = next() * size.height
                    let light = next() > 0.5
                    context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)),
                                 with: .color((light ? Color.white : Color.black).opacity(0.25 + next() * 0.5)))
                }
            }
        }
    }
}
