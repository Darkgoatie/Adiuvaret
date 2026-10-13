import Foundation

/// One model the user can download and chat with. `id` is the Hugging Face repository.
public struct LocalModel: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let family: String
    public let sizeBytes: Int64
    public let license: String
    public let licenseURL: URL
    /// Gemma and Llama licenses carry terms the user should see before downloading.
    public let needsLicenseNotice: Bool
    public let note: String

    public init(id: String, name: String, family: String, sizeBytes: Int64, license: String, licenseURL: String, needsLicenseNotice: Bool, note: String = "") {
        self.id = id; self.name = name; self.family = family; self.sizeBytes = sizeBytes
        self.license = license; self.licenseURL = URL(string: licenseURL)!
        self.needsLicenseNotice = needsLicenseNotice; self.note = note
    }

    public var repositoryURL: URL { URL(string: "https://huggingface.co/\(id)")! }
}

/// A model the chat can use, built in or downloaded.
public struct ModelChoice: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

public enum ModelCatalog {
    public static let appleID = "apple"
    public static let apple = ModelChoice(id: appleID, name: "Apple")
    /// The id of a chat that has no usable model yet: no Apple Intelligence, nothing downloaded, no online provider.
    public static let noModelID = "none"

    private static let apache = "https://www.apache.org/licenses/LICENSE-2.0"
    private static let gemma = "https://ai.google.dev/gemma/terms"
    private static let llama = "https://www.llama.com/llama3_2/license/"

    /// Smallest first. Sizes are the weight files on Hugging Face.
    public static let all: [LocalModel] = [
        LocalModel(id: "mlx-community/gemma-3-1b-it-4bit", name: "Gemma 3 1B", family: "Gemma", sizeBytes: 730_000_000,
                   license: "Gemma terms", licenseURL: gemma, needsLicenseNotice: true, note: "Smallest and fastest"),
        LocalModel(id: "mlx-community/Qwen3-1.7B-4bit", name: "Qwen3 1.7B", family: "Qwen", sizeBytes: 970_000_000,
                   license: "Apache 2.0", licenseURL: apache, needsLicenseNotice: false),
        LocalModel(id: "mlx-community/SmolLM3-3B-4bit", name: "SmolLM3 3B", family: "SmolLM", sizeBytes: 1_730_000_000,
                   license: "Apache 2.0", licenseURL: apache, needsLicenseNotice: false),
        LocalModel(id: "mlx-community/Llama-3.2-3B-Instruct-4bit", name: "Llama 3.2 3B", family: "Llama", sizeBytes: 1_810_000_000,
                   license: "Llama 3.2 license", licenseURL: llama, needsLicenseNotice: true),
        LocalModel(id: "mlx-community/Qwen3-4B-Instruct-2507-4bit", name: "Qwen3 4B Instruct", family: "Qwen", sizeBytes: 2_260_000_000,
                   license: "Apache 2.0", licenseURL: apache, needsLicenseNotice: false, note: "Best all-round pick here"),
        LocalModel(id: "mlx-community/gemma-3-4b-it-4bit", name: "Gemma 3 4B", family: "Gemma", sizeBytes: 3_400_000_000,
                   license: "Gemma terms", licenseURL: gemma, needsLicenseNotice: true),
        LocalModel(id: "mlx-community/gemma-4-e2b-it-4bit", name: "Gemma 4 E2B", family: "Gemma", sizeBytes: 3_550_000_000,
                   license: "Gemma terms", licenseURL: gemma, needsLicenseNotice: true),
        LocalModel(id: "mlx-community/gemma-4-e4b-it-4bit", name: "Gemma 4 E4B", family: "Gemma", sizeBytes: 5_150_000_000,
                   license: "Gemma terms", licenseURL: gemma, needsLicenseNotice: true, note: "Needs a lot of memory"),
    ]

    public static func model(_ id: String) -> LocalModel? { all.first { $0.id == id } }

    /// Apple's model first when this iPhone has it, then the downloaded ones in catalog order.
    public static func choices(installed: Set<String>, appleAvailable: Bool = true) -> [ModelChoice] {
        (appleAvailable ? [apple] : []) + all.filter { installed.contains($0.id) }.map { ModelChoice(id: $0.id, name: $0.name) }
    }

    /// The model to use: the saved one if it can still be used, otherwise Apple's when this iPhone has it, otherwise the
    /// smallest downloaded one, otherwise `noModelID`. The app adds an online model on top of that when one is connected.
    public static func resolve(active: String?, installed: Set<String>, connected: Set<String> = [], appleAvailable: Bool = true) -> String {
        func usable(_ id: String) -> Bool {
            if id == appleID { return appleAvailable }
            if let (p, _) = Providers.parseModelID(id) { return connected.contains(p.id) }
            return installed.contains(id) && model(id) != nil
        }
        if let active, usable(active) { return active }
        if appleAvailable { return appleID }
        return all.first { installed.contains($0.id) }?.id ?? noModelID
    }
}

/// Whether a model is likely to fit in the memory the app is allowed to use.
public enum ModelFit: Sendable, Equatable {
    case fits, tight, tooBig

    /// Weights plus 15% for the cache and a fixed 500 MB for the app and runtime.
    public static func required(forWeights bytes: Int64) -> Int64 { bytes + bytes * 15 / 100 + 500_000_000 }

    public static func evaluate(weightsBytes: Int64, budgetBytes: Int64) -> ModelFit {
        let need = required(forWeights: weightsBytes)
        if need > budgetBytes { return .tooBig }
        if need * 100 > budgetBytes * 80 { return .tight }
        return .fits
    }
}

/// Some models write their reasoning between think tags first. The chat shows only the answer.
public enum ThinkFilter {
    private static let open = "<think>"
    private static let close = "</think>"

    public static func visible(_ text: String) -> String {
        var out = text
        while let start = out.range(of: open) {
            if let end = out.range(of: close, range: start.upperBound..<out.endIndex) {
                out.removeSubrange(start.lowerBound..<end.upperBound)
            } else {
                out.removeSubrange(start.lowerBound..<out.endIndex)
            }
        }
        // A closing tag with no opening one: the opening tag came with the chat template, so everything before it is reasoning.
        if let end = out.range(of: close) { out.removeSubrange(out.startIndex..<end.upperBound) }
        // A tag still being written, like "<thi", must not flash on screen.
        for length in stride(from: open.count - 1, through: 1, by: -1) where out.hasSuffix(String(open.prefix(length))) {
            out.removeLast(length); break
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
