import Foundation
import Diagnostics

#if canImport(MLXLLM)
import MLXLLM
import MLXVLM
import MLXLMCommon
import Tokenizers

/// Loads the downloaded MLX models, one at a time. Downloading is done by ModelDownloader.
actor MLXRuntime {
    static let shared = MLXRuntime()

    private var loaded: (id: String, container: ModelContainer)?
    private var loading: (id: String, task: Task<ModelContainer, Error>)?

    init() {
        // Keep both model factories linked so the loader can find text and vision models.
        _ = LLMModelFactory.shared
        _ = VLMModelFactory.shared
    }

    /// Loads `id` into memory if it is not already. A second request for the same model waits for the first.
    func load(_ id: String) async throws { _ = try await container(for: id) }

    func container(for id: String) async throws -> ModelContainer {
        if let loaded, loaded.id == id { return loaded.container }
        if let loading, loading.id == id { return try await loading.task.value }
        loaded = nil
        loading?.task.cancel()
        guard let folder = ModelStore.completeFolder(for: id) else { throw MLXRuntimeError.incomplete("The model is not fully downloaded.") }
        DiagnosticsLog.shared.record("model load", "start \(id) \(ModelStore.describe(folder))")
        let task = Task { try await loadModelContainer(from: folder, using: TransformersLoader()) }
        loading = (id, task)
        do {
            let container = try await Self.withTimeout(seconds: Self.loadTimeout, task: task)
            if loading?.id == id { loading = nil; loaded = (id, container) }
            return container
        } catch {
            task.cancel()
            if loading?.id == id { loading = nil }
            throw error
        }
    }

    /// Longest a model may take to load before the app gives up and shows it as unavailable.
    static let loadTimeout = 150

    private static func withTimeout(seconds: Int, task: Task<ModelContainer, Error>) async throws -> ModelContainer {
        try await withThrowingTaskGroup(of: ModelContainer.self) { group in
            group.addTask { try await task.value }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw MLXRuntimeError.timedOut(seconds)
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw MLXRuntimeError.timedOut(seconds) }
            return first
        }
    }

    func unload() {
        loading?.task.cancel()
        loading = nil
        loaded = nil
    }

    func forget(_ id: String) {
        if loaded?.id == id { loaded = nil }
        if loading?.id == id { loading?.task.cancel(); loading = nil }
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

/// Builds without MLX have no models to load.
actor MLXRuntime {
    static let shared = MLXRuntime()
    func load(_ id: String) async throws { throw MLXRuntimeError.incomplete("This build has no MLX support.") }
    func unload() {}
    func forget(_ id: String) {}
}

#endif

enum MLXRuntimeError: LocalizedError {
    case timedOut(Int)
    case incomplete(String)
    var errorDescription: String? {
        switch self {
        case .timedOut(let s): "Loading took longer than \(s) seconds."
        case .incomplete(let why): why
        }
    }
}
