import SwiftUI
import FoundationModels

struct RootView: View {
    @State private var status: LocalizedStringKey = "checking"

    var body: some View {
        VStack(spacing: 12) {
            Text("Adiuvaret").font(.largeTitle)
            Text(status).font(.body).foregroundStyle(.secondary)
        }
        .padding()
        .task { status = Self.describe(SystemLanguageModel.default.availability) }
    }

    static func describe(_ a: SystemLanguageModel.Availability) -> LocalizedStringKey {
        switch a {
        case .available: "apple_intelligence_ready"
        case .unavailable(.deviceNotEligible): "apple_intelligence_device_not_eligible"
        case .unavailable(.appleIntelligenceNotEnabled): "apple_intelligence_not_enabled"
        case .unavailable(.modelNotReady): "apple_intelligence_model_not_ready"
        case .unavailable: "apple_intelligence_unavailable"
        }
    }
}
