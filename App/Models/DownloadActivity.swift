import Foundation
import BackgroundTasks
import ModelLibrary
import Diagnostics

/// Keeps a model download running when the app is in the background. iOS shows a continuous background task as a Live Activity
/// with its title, subtitle and progress bar, and the person can cancel it there. Cancelling or running out of time pauses the
/// download, it never deletes it.
@available(iOS 26.0, *)
@MainActor
final class DownloadActivity {
    static let shared = DownloadActivity()

    private final class TaskBox: @unchecked Sendable {
        let task: BGContinuedProcessingTask
        init(_ task: BGContinuedProcessingTask) { self.task = task }
    }

    private var running: [String: BGContinuedProcessingTask] = [:]
    private var waiting: [String: (fraction: Double, text: String)] = [:]
    private var finished: Set<String> = []
    private static let scale: Int64 = 1000

    /// Must run while the app is launching, before it finishes, for every identifier listed in Info.plist.
    nonisolated static func registerAll() {
        for model in ModelCatalog.all {
            let id = model.id
            _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: DownloadPlan.taskIdentifier(for: id), using: nil) { task in
                guard let continued = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: false); return }
                let box = TaskBox(continued)
                Task { @MainActor in DownloadActivity.shared.attach(box.task, modelID: id) }
            }
        }
    }

    /// Asks the system to keep this download alive. Call when the user taps Download or Resume.
    func start(_ model: LocalModel, fraction: Double) {
        finished.remove(model.id)
        let text = DownloadText.summary(fraction: fraction, totalBytes: model.sizeBytes)
        waiting[model.id] = (fraction, text)
        let request = BGContinuedProcessingTaskRequest(
            identifier: DownloadPlan.taskIdentifier(for: model.id),
            title: String(localized: "Downloading \(model.name)"),
            subtitle: text)
        do {
            try BGTaskScheduler.shared.submit(request)
            DiagnosticsLog.shared.record("download activity", "requested \(model.id)")
        } catch {
            // The download still runs while the app is open, it just cannot continue in the background.
            DiagnosticsLog.shared.record("download activity", "not started: \(String(String(describing: error).prefix(120)))")
        }
    }

    func update(_ model: LocalModel, fraction: Double) {
        let text = DownloadText.summary(fraction: fraction, totalBytes: model.sizeBytes)
        waiting[model.id] = (fraction, text)
        guard let task = running[model.id] else { return }
        task.progress.completedUnitCount = Int64(min(max(fraction, 0), 1) * Double(Self.scale))
        task.updateTitle(String(localized: "Downloading \(model.name)"), subtitle: text)
    }

    /// Ends the Live Activity. `success` is false for a pause so the system does not report a finished job.
    func finish(_ model: LocalModel, success: Bool) {
        finished.insert(model.id)
        waiting[model.id] = nil
        if let task = running.removeValue(forKey: model.id) {
            if success { task.progress.completedUnitCount = Self.scale }
            task.setTaskCompleted(success: success)
        }
    }

    private func attach(_ task: BGContinuedProcessingTask, modelID: String) {
        guard let model = ModelCatalog.model(modelID), !finished.contains(modelID) else {
            task.setTaskCompleted(success: false)
            return
        }
        running[modelID] = task
        task.progress.totalUnitCount = Self.scale
        task.expirationHandler = {
            // The person cancelled it in the Live Activity, or the system needs the resources back.
            Task { @MainActor in ModelSettings.shared.systemPaused(modelID) }
        }
        let known = waiting[modelID]?.fraction ?? 0
        task.progress.completedUnitCount = Int64(known * Double(Self.scale))
        task.updateTitle(String(localized: "Downloading \(model.name)"), subtitle: DownloadText.summary(fraction: known, totalBytes: model.sizeBytes))
        DiagnosticsLog.shared.record("download activity", "running \(modelID)")
    }
}

/// The download keep-alive exists from iOS 26. Before that a download runs while the app is open and pauses when it is closed,
/// and the person resumes it from the Models screen; nothing is lost either way.
enum DownloadKeepAlive {
    nonisolated static func registerAll() {
        if #available(iOS 26.0, *) { DownloadActivity.registerAll() }
    }

    @MainActor static func start(_ model: LocalModel, fraction: Double) {
        if #available(iOS 26.0, *) { DownloadActivity.shared.start(model, fraction: fraction) }
    }

    @MainActor static func update(_ model: LocalModel, fraction: Double) {
        if #available(iOS 26.0, *) { DownloadActivity.shared.update(model, fraction: fraction) }
    }

    @MainActor static func finish(_ model: LocalModel, success: Bool) {
        if #available(iOS 26.0, *) { DownloadActivity.shared.finish(model, success: success) }
    }
}
