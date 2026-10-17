import SwiftUI

public struct ModelPrivacyChip: View {
    public enum Kind: Sendable, Equatable {
        case onDevice, localModel, cloud(provider: String), offlineFallback
    }

    public let model: String
    public let kind: Kind
    public let prominent: Bool
    /// The chat header turns this on so the name follows the chosen theme and button effect.
    public let themed: Bool

    public init(model: String, kind: Kind, prominent: Bool = true, themed: Bool = false) {
        self.model = model; self.kind = kind; self.prominent = prominent; self.themed = themed
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon).imageScale(.small)
            Text(verbatim: label.isEmpty ? model : "\(model) · \(label)").lineLimit(2)
        }
        .font(DS.Typography.caption)
        .modifier(ChipTint(themed: themed, plain: tint, themedFlat: themedFlat))
        .padding(.horizontal, prominent ? Spacing.s : 0)
        .padding(.vertical, prominent ? Spacing.xs : 0)
        .background(prominent ? DS.Colors.surfaceRaised : .clear, in: RoundedRectangle(cornerRadius: Radius.s))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label.isEmpty ? model : "\(model), \(label)"))
    }

    private var icon: String {
        switch kind {
        case .onDevice, .localModel: "iphone"
        case .cloud: "cloud"
        case .offlineFallback: "wifi.slash"
        }
    }

    private var label: String {
        switch kind {
        case .onDevice, .localModel: L("Stays on your iPhone")
        case .cloud: ""
        case .offlineFallback: L("Offline, on your iPhone")
        }
    }

    /// With a flat button effect the on-device name takes the theme colour; an online model keeps its own colour so the two stay apart.
    private var themedFlat: Color {
        if case .cloud = kind { return DS.Colors.privacyCloud }
        return DS.Colors.accentText
    }

    private var tint: Color {
        if case .cloud = kind { return DS.Colors.privacyCloud }
        return DS.Colors.privacyLocal
    }
}

private struct ChipTint: ViewModifier {
    let themed: Bool
    let plain: Color
    let themedFlat: Color
    func body(content: Content) -> some View {
        if !themed {
            content.foregroundStyle(plain)
        } else if ButtonEffectStore.shared.effect == .flat {
            content.foregroundStyle(themedFlat)
        } else {
            content.effectForeground(flat: themedFlat)
        }
    }
}

#Preview("Chips") {
    VStack(alignment: .leading, spacing: 12) {
        ModelPrivacyChip(model: "Apple", kind: .onDevice)
        ModelPrivacyChip(model: "Qwen 3 4B", kind: .localModel)
        ModelPrivacyChip(model: "Claude", kind: .cloud(provider: "Anthropic"))
        ModelPrivacyChip(model: "Apple", kind: .offlineFallback)
        ModelPrivacyChip(model: "Apple", kind: .onDevice, prominent: false)
    }
    .padding().background(DS.Colors.background)
}
