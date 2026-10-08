import Foundation
import Observation
import os
import ModelLibrary
import Diagnostics

/// Which models are downloaded, which one is active, and the download controls behind the Models screen.
@MainActor @Observable
final class ModelSettings {
    static let shared = ModelSettings()

    enum DownloadState: Equatable {
        case idle
        case downloading(Double)
        case failed(String)
    }

    private(set) var installed: Set<String>
    private(set) var states: [String: DownloadState] = [:]
    private(set) var activeID: String

    @ObservationIgnored private var tasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        let saved = Set(UserDefaults.standard.stringArray(forKey: "models.installed") ?? [])
        installed = saved
        activeID = ModelCatalog.resolve(active: UserDefaults.standard.string(forKey: "models.active"), installed: saved)
    }

    var choices: [ModelChoice] { ModelCatalog.choices(installed: installed) }

    /// Memory this app can still use, as reported by iOS. Models larger than this cannot run.
    var memoryBudget: Int64 { Int64(os_proc_available_memory()) }

    func state(_ id: String) -> DownloadState { states[id] ?? .idle }

    func fit(_ model: LocalModel) -> ModelFit { ModelFit.evaluate(weightsBytes: model.sizeBytes, budgetBytes: memoryBudget) }

    /// Makes `id` the model for new chats. Unknown or missing models fall back to Apple.
    func select(_ id: String) {
        activeID = ModelCatalog.resolve(active: id, installed: installed)
        defaults.set(activeID, forKey: "models.active")
        DiagnosticsLog.shared.record("model select", activeID)
        if activeID == ModelCatalog.appleID { Task { await MLXRuntime.shared.unload() } }
    }

    /// A chat service for `modelID` (default: the active model), seeded with earlier messages.
    func makeService(modelID: String? = nil, items: [ThreadItem] = [], title: String? = nil) -> any ChatService {
        let id = ModelCatalog.resolve(active: modelID ?? activeID, installed: installed)
        #if canImport(MLXLLM)
        if id != ModelCatalog.appleID { return MLXChatService(restoring: items, title: title, modelID: id) }
        #endif
        return LiveChatService(restoring: items, title: title)
    }

    func download(_ model: LocalModel) {
        guard tasks[model.id] == nil, !installed.contains(model.id) else { return }
        if let free = Self.freeBytes(), free < model.sizeBytes + model.sizeBytes / 5 {
            states[model.id] = .failed(String(localized: "Not enough free storage."))
            return
        }
        states[model.id] = .downloading(0)
        DiagnosticsLog.shared.record("model download", "start \(model.id)")
        let id = model.id
        tasks[id] = Task { [weak self] in
            do {
                try await MLXRuntime.shared.download(id) { fraction in
                    Task { @MainActor in self?.progress(id, fraction) }
                }
                self?.finishDownload(id, error: nil)
            } catch is CancellationError {
                self?.finishDownload(id, error: nil, cancelled: true)
            } catch {
                self?.finishDownload(id, error: error)
            }
        }
    }

    func cancel(_ id: String) { tasks[id]?.cancel() }

    func delete(_ id: String) {
        tasks[id]?.cancel()
        installed.remove(id)
        states[id] = .idle
        defaults.set(Array(installed), forKey: "models.installed")
        if activeID == id { select(ModelCatalog.appleID) }
        DiagnosticsLog.shared.record("model delete", id)
        Task { await MLXRuntime.shared.remove(id) }
    }

    private func progress(_ id: String, _ fraction: Double) {
        guard case .downloading(let old) = states[id], fraction - old >= 0.005 || fraction >= 1 else { return }
        states[id] = .downloading(min(fraction, 1))
    }

    private func finishDownload(_ id: String, error: Error?, cancelled: Bool = false) {
        tasks[id] = nil
        if cancelled { states[id] = .idle; return }
        if let error {
            let text = String(String(describing: error).prefix(120))
            states[id] = .failed(text)
            DiagnosticsLog.shared.record("model download", "failed \(id): \(text)")
            return
        }
        installed.insert(id)
        states[id] = .idle
        defaults.set(Array(installed), forKey: "models.installed")
        DiagnosticsLog.shared.record("model download", "done \(id)")
    }

    private static func freeBytes() -> Int64? {
        let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
