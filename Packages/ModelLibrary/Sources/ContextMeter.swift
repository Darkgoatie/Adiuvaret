import Foundation

/// Estimates for the context ring and the speed label. There is no tokenizer on the phone, so text is counted at about four characters per token.
public enum ContextMeter {
    /// What the standing instructions and tool descriptions take before any message.
    public static let overheadTokens = 700

    public static func estimateTokens(_ text: String) -> Int { text.isEmpty ? 0 : (text.count + 3) / 4 }

    /// The window the ring is measured against: 8192 for the Apple model and downloaded models (the app seeds them with a short history), a large window for online models.
    public static func window(for modelID: String) -> Int {
        Providers.parseModelID(modelID) != nil ? 128_000 : 8_192
    }

    /// 0 to 1, clamped.
    public static func fraction(used: Int, window: Int) -> Double {
        guard window > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(window)))
    }

    public static func percentText(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

    /// Tokens per second for a reply, or nil when it was too short or too quick to mean anything.
    public static func tokensPerSecond(characters: Int, seconds: Double) -> Double? {
        guard characters >= 20, seconds >= 0.3 else { return nil }
        return Double(estimateTokens(String(repeating: "x", count: characters))) / seconds
    }

    public static func rateText(_ rate: Double) -> String { rate >= 100 ? String(format: "%.0f", rate) : String(format: "%.1f", rate) }
}
