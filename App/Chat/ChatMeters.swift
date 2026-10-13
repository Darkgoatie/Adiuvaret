import SwiftUI
import DesignSystem
import ModelLibrary

/// Reply speeds measured this session, shown under a reply when the setting is on. Not saved with the chat.
@MainActor @Observable
final class ReplyStats {
    static let shared = ReplyStats()
    private(set) var rates: [UUID: Double] = [:]

    func record(_ id: UUID, text: String, since start: ContinuousClock.Instant?) {
        guard let start else { return }
        let d = ContinuousClock.now - start
        let seconds = Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
        if let rate = ContextMeter.tokensPerSecond(characters: text.count, seconds: seconds) { rates[id] = rate }
    }

    func text(for id: UUID) -> String? {
        rates[id].map { String(localized: "\(ContextMeter.rateText($0)) tok/s") }
    }
}

/// A small ring that fills clockwise as the chat uses up the model's context window.
struct ContextRing: View {
    let fraction: Double
    let used: Int
    let window: Int
    @State private var showing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color { fraction >= 0.9 ? DS.Colors.danger : fraction >= 0.75 ? DS.Colors.warning : DS.Colors.accent }

    var body: some View {
        Button { showing = true } label: {
            ZStack {
                Circle().stroke(DS.Colors.separator, lineWidth: 3)
                Circle().trim(from: 0, to: max(fraction, fraction > 0 ? 0.02 : 0))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: fraction)
            }
            .frame(width: 20, height: 20)
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel(Text("Context used"))
        .accessibilityValue(Text(verbatim: ContextMeter.percentText(fraction)))
        .accessibilityIdentifier("chat.context")
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(verbatim: String(localized: "Context \(ContextMeter.percentText(fraction)) full")).font(DS.Typography.headline)
                Text(verbatim: String(localized: "About \(used) of \(window) tokens. An estimate from the text in this chat.")).font(DS.Typography.footnote)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(Spacing.l)
            .frame(minWidth: 240)
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// The speed line under a reply.
struct SpeedLabel: View {
    let text: String
    var body: some View {
        Text(verbatim: text).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("chat.speed")
    }
}
