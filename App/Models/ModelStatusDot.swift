import SwiftUI
import DesignSystem

/// A small circle beside the model name: yellow while loading, green when ready, red when the model cannot be used.
struct ModelStatusDot: View {
    let state: ModelSettings.LoadState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: label))
            .accessibilityIdentifier("chat.modelStatus")
    }

    private var color: Color {
        switch state {
        case .idle, .loading: Color(red: 0.96, green: 0.76, blue: 0.10)
        case .loaded: DS.Colors.accent
        case .unavailable: DS.Colors.danger
        }
    }

    private var label: String {
        switch state {
        case .idle, .loading: String(localized: "Model loading")
        case .loaded: String(localized: "Model ready")
        case .unavailable(let why): String(localized: "Model unavailable. \(why)")
        }
    }
}

#Preview("Dots") {
    HStack(spacing: 12) {
        ModelStatusDot(state: .loading); ModelStatusDot(state: .loaded); ModelStatusDot(state: .unavailable("Too large"))
    }.padding()
}
