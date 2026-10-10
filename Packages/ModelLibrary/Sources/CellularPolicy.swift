import Foundation

/// When a download should ask first. Cellular and Personal Hotspot both report as expensive; Low Data Mode reports as constrained.
public enum CellularPolicy {
    public static func needsWarning(isExpensive: Bool, isConstrained: Bool, remainingBytes: Int64) -> Bool {
        (isExpensive || isConstrained) && remainingBytes > 0
    }

    /// Bytes still to fetch for a model of `sizeBytes` that is `fraction` done.
    public static func remainingBytes(sizeBytes: Int64, fraction: Double) -> Int64 {
        let done = min(max(fraction, 0), 1)
        return Int64(Double(sizeBytes) * (1 - done))
    }
}
