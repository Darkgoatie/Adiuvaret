import Foundation

/// Chat models mark the end of a turn with a special word. If the app misses it, the model carries on and invents the next turn.
/// This cuts the text at the first such marker, as a second line of defence behind the stop tokens.
public enum TurnMarkers {
    public static let all = ["<end_of_turn>", "<start_of_turn>", "<|im_end|>", "<|im_start|>", "<|eot_id|>", "<|start_header_id|>", "<turn|>", "<|end|>", "<eos>"]

    public static func clean(_ text: String) -> String {
        var out = text
        var cut: String.Index?
        for marker in all {
            if let r = out.range(of: marker), cut == nil || r.lowerBound < cut! { cut = r.lowerBound }
        }
        if let cut { out = String(out[..<cut]) }
        // A marker still being written must not flash on screen.
        for marker in all {
            for length in stride(from: marker.count - 1, through: 2, by: -1) where out.hasSuffix(String(marker.prefix(length))) {
                out.removeLast(length); break
            }
        }
        return out
    }
}
