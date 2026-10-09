import Foundation
import ModelLibrary

/// Where downloaded models live on disk, and what state they are in. Pure file work, no network.
/// Each model has its own folder. A download in progress keeps its finished files, its half-written `.part` file and a manifest,
/// so stopping it for any reason leaves everything in place to resume.
enum ModelStore {
    static let root: URL = {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        var dir = base.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }()

    static func folder(for id: String) -> URL { root.appendingPathComponent(DownloadPlan.folderName(for: id), isDirectory: true) }
    static func manifestURL(for id: String) -> URL { folder(for: id).appendingPathComponent("download.json") }

    static func loadManifest(_ id: String) -> DownloadManifest? {
        guard let data = try? Data(contentsOf: manifestURL(for: id)) else { return nil }
        return try? JSONDecoder().decode(DownloadManifest.self, from: data)
    }

    static func saveManifest(_ manifest: DownloadManifest) {
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? FileManager.default.createDirectory(at: folder(for: manifest.id), withIntermediateDirectories: true)
        try? data.write(to: manifestURL(for: manifest.id), options: .atomic)
    }

    /// Downloads made by builds 21 to 23 (swift-huggingface cache layout). Still loadable, so nobody has to download again.
    private static func legacyFolder(for id: String) -> URL? {
        let name = "models--" + DownloadPlan.folderName(for: id)
        let snapshots = root.appendingPathComponent(name).appendingPathComponent("snapshots")
        let commits = (try? FileManager.default.contentsOfDirectory(atPath: snapshots.path)) ?? []
        for commit in commits.sorted() {
            let dir = snapshots.appendingPathComponent(commit)
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("config.json").path) { return dir }
        }
        return nil
    }

    /// The folder to load a model from, or nil while it is missing or only partly downloaded.
    static func completeFolder(for id: String) -> URL? {
        let dir = folder(for: id)
        if let manifest = loadManifest(id), manifest.isComplete,
           FileManager.default.fileExists(atPath: dir.appendingPathComponent("config.json").path) {
            return dir
        }
        return legacyFolder(for: id)
    }

    private static func size(_ url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
    }

    /// 0 to 1 for a download that was started and not finished, or nil when there is nothing to resume.
    static func pendingFraction(_ id: String) -> Double? {
        guard let manifest = loadManifest(id), !manifest.isComplete else { return nil }
        let dir = folder(for: id)
        var inFlight: [String: Int64] = [:]
        for file in manifest.remaining {
            if let part = size(dir.appendingPathComponent(file.path + ".part")) { inFlight[file.path] = part }
        }
        return manifest.fraction(inFlight: inFlight)
    }

    /// Checks that every weight file is there at about the expected size. Returns what is wrong, or nil.
    static func verify(_ id: String) -> String? {
        guard let folder = completeFolder(for: id) else { return "The model folder is missing." }
        let fm = FileManager.default
        var weightFiles = Set<String>()
        if let data = try? Data(contentsOf: folder.appendingPathComponent("model.safetensors.index.json")),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let map = object["weight_map"] as? [String: String] {
            weightFiles = Set(map.values)
        }
        if weightFiles.isEmpty {
            weightFiles = Set(((try? fm.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".safetensors") })
        }
        if weightFiles.isEmpty { weightFiles = ["model.safetensors"] }
        var total: Int64 = 0
        for name in weightFiles.sorted() {
            let real = folder.appendingPathComponent(name).resolvingSymlinksInPath()
            guard let bytes = size(real), bytes > 0 else { return "The weight file \(name) is missing." }
            total += bytes
        }
        let expected = ModelCatalog.model(id)?.sizeBytes ?? 0
        if expected > 0, total < expected * 9 / 10 { return "The download is incomplete (\(total / 1_000_000) of \(expected / 1_000_000) MB)." }
        return nil
    }

    /// File names and sizes in a model folder, for the diagnostics log. Contains no personal data.
    static func describe(_ folder: URL) -> String {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.sorted().map { name in
            let real = folder.appendingPathComponent(name).resolvingSymlinksInPath()
            return "\(name):\((size(real) ?? 0) / 1_000_000)MB"
        }.joined(separator: ",")
    }

    /// Deletes everything stored for a model, including a half-finished download.
    static func remove(_ id: String) {
        try? FileManager.default.removeItem(at: folder(for: id))
        try? FileManager.default.removeItem(at: root.appendingPathComponent("models--" + DownloadPlan.folderName(for: id)))
    }
}
