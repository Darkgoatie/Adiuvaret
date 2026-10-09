import Foundation
import Observation
import os
import FoundationModels
import ModelLibrary
import Diagnostics

/// Which models are downloaded, which one is active, and the download controls behind the Models screen.
@MainActor @Observable
final class ModelSettings {
    static let shared = ModelSettings()

    enum DownloadState: Equatable {
        case idle
        case downloading(Double)
        /// Stopped part-way, with every byte kept on disk. `reason` says why when it was not the user.
        case paused(Double, reason: String?)
        case failed(String)
    }

    /// Whether a model is ready for chat. Apple's model has no loading step, so its state follows availability.
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case unavailable(String)
    }

    private(set) var installed: Set<String>
    private(set) var loadStates: [String: LoadState] = [:]
    private(set) var states: [String: DownloadState] = [:]
    private(set) var activeID: String

    @ObservationIgnored private var tasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        let saved = Set(UserDefaults.standard.stringArray(forKey: "models.installed") ?? [])
        installed = saved
        activeID = ModelCatalog.resolve(active: UserDefaults.standard.string(forKey: "models.active"), installed: saved)
        // Downloads that were stopped by the system or by closing the app come back as paused, not lost.
        for model in ModelCatalog.all where !saved.contains(model.id) {
            if let fraction = ModelStore.pendingFraction(model.id) { states[model.id] = .paused(fraction, reason: nil) }
        }
    }

    var choices: [ModelChoice] { ModelCatalog.choices(installed: installed) }

    /// Memory this app can still use, as reported by iOS. Models larger than this cannot run.
    var memoryBudget: Int64 { Int64(os_proc_available_memory()) }

    func state(_ id: String) -> DownloadState { states[id] ?? .idle }

    func loadState(_ id: String) -> LoadState {
        if id == ModelCatalog.appleID {
            switch SystemLanguageModel.default.availability {
            case .available: return .loaded
            case .unavailable: return .unavailable(String(localized: "Apple Intelligence isn't available."))
            }
        }
        return loadStates[id] ?? .idle
    }

    /// Loads a downloaded model into memory now, so the first message does not wait. Safe to call repeatedly.
    func preload(_ id: String) {
        guard id != ModelCatalog.appleID else { return }
        switch loadStates[id] {
        case .loading, .loaded: return
        default: break
        }
        guard installed.contains(id), let model = ModelCatalog.model(id) else {
            loadStates[id] = .unavailable(String(localized: "Not downloaded."))
            return
        }
        // A model that cannot fit would be stopped by iOS, and a saved chat would then crash the app at every launch.
        guard fit(model) != .tooBig else {
            loadStates[id] = .unavailable(String(localized: "Too large for this iPhone's memory."))
            DiagnosticsLog.shared.record("model load", "skipped, too large: \(id)")
            return
        }
        loadStates[id] = .loading
        let started = ContinuousClock.now
        Task { [weak self] in
            if let problem = ModelStore.verify(id) {
                // Files are missing, so the model cannot work. Take it off the installed list so it can be downloaded again.
                guard let self else { return }
                self.installed.remove(id)
                self.defaults.set(Array(self.installed), forKey: "models.installed")
                self.loadStates[id] = nil
                self.states[id] = .failed(problem + " " + String(localized: "Download it again."))
                DiagnosticsLog.shared.record("model repair", "\(id): \(problem)")
                ModelStore.remove(id)
                await MLXRuntime.shared.forget(id)
                if self.activeID == id { self.select(ModelCatalog.appleID) }
                return
            }
            do {
                try await MLXRuntime.shared.load(id)
                guard let self, self.loadStates[id] == .loading else { return }
                for (other, state) in self.loadStates where other != id && state == .loaded { self.loadStates[other] = .idle }
                self.loadStates[id] = .loaded
                DiagnosticsLog.shared.record("model preload", "\((ContinuousClock.now - started).milliseconds) ms, model=\(id)")
            } catch {
                guard let self, self.loadStates[id] == .loading else { return }
                let text = String(String(describing: error).prefix(120))
                self.loadStates[id] = .unavailable(text)
                DiagnosticsLog.shared.record("model preload", "failed \(id): \(text)")
            }
        }
    }

    func fit(_ model: LocalModel) -> ModelFit { ModelFit.evaluate(weightsBytes: model.sizeBytes, budgetBytes: memoryBudget) }

    /// Makes `id` the model for new chats. Unknown or missing models fall back to Apple.
    func select(_ id: String) {
        activeID = ModelCatalog.resolve(active: id, installed: installed)
        defaults.set(activeID, forKey: "models.active")
        DiagnosticsLog.shared.record("model select", activeID)
        if activeID == ModelCatalog.appleID {
            for (id, state) in loadStates where state == .loaded || state == .loading { loadStates[id] = .idle }
            Task { await MLXRuntime.shared.unload() }
        } else {
            preload(activeID)
        }
    }

    /// A chat service for `modelID` (default: the active model), seeded with earlier messages.
    func makeService(modelID: String? = nil, items: [ThreadItem] = [], title: String? = nil) -> any ChatService {
        let id = ModelCatalog.resolve(active: modelID ?? activeID, installed: installed)
        #if canImport(MLXLLM)
        if id != ModelCatalog.appleID { preload(id); return MLXChatService(restoring: items, title: title, modelID: id) }
        #endif
        return LiveChatService(restoring: items, title: title)
    }

    /// Starts a download, or continues one that was paused. Finished files and half-written files are kept.
    func download(_ model: LocalModel) {
        guard tasks[model.id] == nil, !installed.contains(model.id) else { return }
        let resumeFrom = ModelStore.pendingFraction(model.id) ?? 0
        let needed = Int64(Double(model.sizeBytes) * (1 - resumeFrom))
        if let free = Self.freeBytes(), free < needed + needed / 5 {
            states[model.id] = .failed(String(localized: "Not enough free storage."))
            return
        }
        states[model.id] = .downloading(resumeFrom)
        DiagnosticsLog.shared.record("model download", "\(resumeFrom > 0 ? "resume" : "start") \(model.id) at \(Int(resumeFrom * 100))%")
        DownloadActivity.shared.start(model, fraction: resumeFrom)
        let id = model.id
        tasks[id] = Task { [weak self] in
            do {
                try await ModelDownloader.shared.download(id) { fraction in
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

    /// Stops a download and keeps everything downloaded so far. The Pause button and the Live Activity's cancel both end here.
    func pause(_ id: String) { tasks[id]?.cancel() }

    /// The system ended the background task, or the person cancelled it from the Live Activity.
    func systemPaused(_ id: String) {
        DiagnosticsLog.shared.record("download activity", "ended by the system \(id)")
        pause(id)
    }

    func delete(_ id: String) {
        tasks[id]?.cancel()
        tasks[id] = nil
        installed.remove(id)
        states[id] = .idle
        loadStates[id] = nil
        defaults.set(Array(installed), forKey: "models.installed")
        if activeID == id { select(ModelCatalog.appleID) }
        DiagnosticsLog.shared.record("model delete", id)
        if let model = ModelCatalog.model(id) { DownloadActivity.shared.finish(model, success: false) }
        Task {
            await MLXRuntime.shared.forget(id)
            // A cancelled download task may still be writing; give it a moment to stop before the folder goes.
            try? await Task.sleep(for: .milliseconds(400))
            ModelStore.remove(id)
        }
    }

    private func progress(_ id: String, _ fraction: Double) {
        guard case .downloading(let old) = states[id], fraction - old >= 0.005 || fraction >= 1 else { return }
        states[id] = .downloading(min(fraction, 1))
        if let model = ModelCatalog.model(id) { DownloadActivity.shared.update(model, fraction: fraction) }
    }

    private func finishDownload(_ id: String, error: Error?, cancelled: Bool = false) {
        tasks[id] = nil
        guard let model = ModelCatalog.model(id) else { return }
        let kept = ModelStore.pendingFraction(id) ?? 0
        if cancelled {
            states[id] = .paused(kept, reason: nil)
            DownloadActivity.shared.finish(model, success: false)
            DiagnosticsLog.shared.record("model download", "paused \(id) at \(Int(kept * 100))%")
            return
        }
        if let error {
            let text = String(String(describing: error).prefix(120))
            states[id] = .paused(kept, reason: text)
            DownloadActivity.shared.finish(model, success: false)
            DiagnosticsLog.shared.record("model download", "stopped \(id) at \(Int(kept * 100))%: \(text)")
            return
        }
        if let problem = ModelStore.verify(id) {
            // Every file arrived but the weights are not right. Only this case discards the files, because resuming cannot fix it.
            ModelStore.remove(id)
            states[id] = .failed(problem + " " + String(localized: "Download it again."))
            DownloadActivity.shared.finish(model, success: false)
            DiagnosticsLog.shared.record("model download", "failed check \(id): \(problem)")
            return
        }
        installed.insert(id)
        states[id] = .idle
        defaults.set(Array(installed), forKey: "models.installed")
        DownloadActivity.shared.finish(model, success: true)
        DiagnosticsLog.shared.record("model download", "done \(id)")
    }

    private static func freeBytes() -> Int64? {
        let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
