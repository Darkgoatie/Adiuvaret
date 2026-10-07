import SwiftUI

public struct ModelPrivacyChip: View {
    public enum Kind: Sendable, Equatable {
        case onDevice, localModel, cloud(provider: String), offlineFallback
    }

    public let model: String
    public let kind: Kind
    public let prominent: Bool

    public init(model: String, kind: Kind, prominent: Bool = true) {
        self.model = model; self.kind = kind; self.prominent = prominent
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon).imageScale(.small)
            Text(verbatim: "\(model) · \(label)").lineLimit(2)
        }
        .font(DS.Typography.caption)
        .foregroundStyle(tint)
        .padding(.horizontal, prominent ? Spacing.s : 0)
        .padding(.vertical, prominent ? Spacing.xs : 0)
        .background(prominent ? DS.Colors.surfaceRaised : .clear, in: RoundedRectangle(cornerRadius: Radius.s))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(model), \(label)"))
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
        case .cloud(let p): L("Sent to \(p)")
        case .offlineFallback: L("Offline, on your iPhone")
        }
    }

    private var tint: Color {
        if case .cloud = kind { return DS.Colors.privacyCloud }
        return DS.Colors.privacyLocal
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
