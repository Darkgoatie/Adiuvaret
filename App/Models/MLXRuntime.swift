import Foundation

#if canImport(MLXLLM)
import MLXLLM
import MLXVLM
import MLXLMCommon
import HuggingFace
import Tokenizers

/// Downloads and loads the MLX models, one at a time. Files live in Application Support, which iOS does not purge.
actor MLXRuntime {
    static let shared = MLXRuntime()

    private var loaded: (id: String, container: ModelContainer)?
    private let cache: HubCache
    private let hub: HubClient

    init() {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        var dir = base.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        cache = HubCache(cacheDirectory: dir)
        hub = HubClient(cache: cache)
        // Keep both model factories linked so the loader can find text and vision models.
        _ = LLMModelFactory.shared
        _ = VLMModelFactory.shared
    }

    func download(_ id: String, progress: @escaping @Sendable (Double) -> Void) async throws {
        _ = try await HubBridge(upstream: hub).download(
            id: id, revision: nil, matching: ["*.safetensors", "*.json", "*.jinja"], useLatest: false,
            progressHandler: { progress($0.fractionCompleted) })
    }

    func container(for id: String) async throws -> ModelContainer {
        if let loaded, loaded.id == id { return loaded.container }
        loaded = nil
        let container = try await loadModelContainer(from: HubBridge(upstream: hub), using: TransformersLoader(), id: id)
        loaded = (id, container)
        return container
    }

    func unload() { loaded = nil }

    func remove(_ id: String) {
        if loaded?.id == id { loaded = nil }
        guard let repo = HuggingFace.Repo.ID(rawValue: id) else { return }
        try? FileManager.default.removeItem(at: cache.repoDirectory(repo: repo, kind: .model))
    }
}

private enum MLXRuntimeError: LocalizedError {
    case badRepository(String)
    var errorDescription: String? {
        switch self { case .badRepository(let id): "Invalid model name \(id)." }
    }
}

private struct HubBridge: MLXLMCommon.Downloader {
    let upstream: HubClient

    func download(
        id: String, revision: String?, matching patterns: [String], useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repo = HuggingFace.Repo.ID(rawValue: id) else { throw MLXRuntimeError.badRepository(id) }
        return try await upstream.downloadSnapshot(
            of: repo, revision: revision ?? "main", matching: patterns,
            progressHandler: { @MainActor progress in progressHandler(progress) })
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    let upstream: any Tokenizers.Tokenizer

    func encode(text: String, addSpecialTokens: Bool) -> [Int] { upstream.encode(text: text, addSpecialTokens: addSpecialTokens) }
    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String { upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens) }
    func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }
    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]], tools: [[String: any Sendable]]?, additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

private struct TransformersLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        TokenizerBridge(upstream: try await Tokenizers.AutoTokenizer.from(modelFolder: directory))
    }
}

#else

/// Builds without MLX (the simulator check on the Intel VM) have no models to download.
actor MLXRuntime {
    static let shared = MLXRuntime()
    func download(_ id: String, progress: @escaping @Sendable (Double) -> Void) async throws {
        throw NSError(domain: "Adiuvaret", code: 1, userInfo: [NSLocalizedDescriptionKey: "This build has no MLX support."])
    }
    func unload() {}
    func remove(_ id: String) {}
}

#endif
