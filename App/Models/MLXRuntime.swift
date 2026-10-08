import Foundation

#if canImport(MLXLLM)
import MLXLLM
import MLXVLM
import MLXLMCommon
import HuggingFace
import Tokenizers
import Diagnostics

/// Downloads and loads the MLX models, one at a time. Files live in Application Support, which iOS does not purge.
actor MLXRuntime {
    static let shared = MLXRuntime()

    private var loaded: (id: String, container: ModelContainer)?
    private var loading: (id: String, task: Task<ModelContainer, Error>)?
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

    /// Loads `id` into memory if it is not already. A second request for the same model waits for the first.
    func load(_ id: String) async throws { _ = try await container(for: id) }

    func container(for id: String) async throws -> ModelContainer {
        if let loaded, loaded.id == id { return loaded.container }
        if let loading, loading.id == id { return try await loading.task.value }
        loaded = nil
        loading?.task.cancel()
        let bridge = HubBridge(upstream: hub)
        // A downloaded model loads straight from its folder. Going through the Hub again with the name "main"
        // makes the library ask the network which files exist, which can stall when the connection is poor.
        let folder = localSnapshot(for: id)
        DiagnosticsLog.shared.record("model load", "start \(id) local=\(folder != nil) \(folder.map(Self.describe) ?? "no local folder")")
        let task = Task { () -> ModelContainer in
            if let folder { return try await loadModelContainer(from: folder, using: TransformersLoader()) }
            return try await loadModelContainer(from: bridge, using: TransformersLoader(), id: id)
        }
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

    /// The downloaded folder for `id`, or nil when the model was never fully downloaded.
    func localSnapshot(for id: String) -> URL? {
        guard let repo = HuggingFace.Repo.ID(rawValue: id),
              let commit = cache.resolveRevision(repo: repo, kind: .model, ref: "main"),
              let folder = try? cache.snapshotPath(repo: repo, kind: .model, commitHash: commit),
              FileManager.default.fileExists(atPath: folder.appendingPathComponent("config.json").path)
        else { return nil }
        return folder
    }

    /// File names and sizes in the folder, for the diagnostics log. Contains no personal data.
    private static func describe(_ folder: URL) -> String {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.sorted().map { name in
            let size = (try? FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent(name).path)[.size] as? Int) ?? 0
            return "\(name):\(size / 1_000_000)MB"
        }.joined(separator: ",")
    }

    func unload() {
        loading?.task.cancel()
        loading = nil
        loaded = nil
    }

    func remove(_ id: String) {
        if loaded?.id == id { loaded = nil }
        if loading?.id == id { loading?.task.cancel(); loading = nil }
        guard let repo = HuggingFace.Repo.ID(rawValue: id) else { return }
        try? FileManager.default.removeItem(at: cache.repoDirectory(repo: repo, kind: .model))
    }
}

private enum MLXRuntimeError: LocalizedError {
    case badRepository(String)
    case timedOut(Int)
    var errorDescription: String? {
        switch self {
        case .badRepository(let id): "Invalid model name \(id)."
        case .timedOut(let s): "Loading took longer than \(s) seconds."
        }
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
    func load(_ id: String) async throws { throw NSError(domain: "Adiuvaret", code: 1, userInfo: [NSLocalizedDescriptionKey: "This build has no MLX support."]) }
    func unload() {}
    func remove(_ id: String) {}
}

#endif
