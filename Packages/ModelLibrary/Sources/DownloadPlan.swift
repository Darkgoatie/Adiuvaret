import Foundation

/// One file of a model repository.
public struct RemoteFile: Codable, Sendable, Equatable, Hashable {
    public let path: String
    public let size: Int64
    public init(path: String, size: Int64) { self.path = path; self.size = size }
}

/// Which files make up a downloadable model and where they come from. Pure logic, no network.
public enum DownloadPlan {
    /// Weights, configuration and tokenizer files. Nothing else is fetched.
    public static let suffixes = [".safetensors", ".json", ".jinja"]
    public static let bundlePrefix = "com.halit.adiuvaret"

    public static func isValidRepository(_ id: String) -> Bool {
        id.wholeMatch(of: /[A-Za-z0-9][A-Za-z0-9._-]*\/[A-Za-z0-9][A-Za-z0-9._-]*/) != nil
    }

    /// Flat files only, with plain names, so a repository can never write outside the model folder.
    public static func isSafe(_ path: String) -> Bool {
        !path.isEmpty && !path.contains("/") && !path.contains("\\") && !path.hasPrefix(".") && path != ".." && !path.contains("\0")
    }

    public static func wanted(_ path: String) -> Bool { isSafe(path) && suffixes.contains { path.hasSuffix($0) } }

    private struct TreeEntry: Decodable {
        struct LFS: Decodable { let size: Int64? }
        let type: String
        let path: String
        let size: Int64?
        let lfs: LFS?
    }

    /// Parses the Hugging Face file listing (`/api/models/<id>/tree/main`) into the files to download.
    public static func files(fromTreeJSON data: Data) throws -> [RemoteFile] {
        let entries = try JSONDecoder().decode([TreeEntry].self, from: data)
        return entries
            .filter { $0.type == "file" && wanted($0.path) }
            .map { RemoteFile(path: $0.path, size: $0.lfs?.size ?? $0.size ?? 0) }
            .sorted { $0.path < $1.path }
    }

    public static func treeURL(_ id: String) -> URL? {
        isValidRepository(id) ? URL(string: "https://huggingface.co/api/models/\(id)/tree/main") : nil
    }

    public static func fileURL(_ id: String, path: String) -> URL? {
        guard isValidRepository(id), isSafe(path), let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://huggingface.co/\(id)/resolve/main/\(encoded)")
    }

    public static func folderName(for id: String) -> String { id.replacingOccurrences(of: "/", with: "--") }

    /// Identifier of the system's background task for this model. Each one must also be listed in Info.plist.
    public static func taskIdentifier(for id: String, bundleID: String = bundlePrefix) -> String {
        let name = id.split(separator: "/").last.map(String.init) ?? id
        let slug = String(name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" })
        return "\(bundleID).download.\(slug)"
    }
}

/// What has been downloaded so far for one model. Saved next to the files, so a download survives restarts.
public struct DownloadManifest: Codable, Sendable, Equatable {
    public let id: String
    public var files: [RemoteFile]
    public var done: Set<String>

    public init(id: String, files: [RemoteFile], done: Set<String> = []) {
        self.id = id; self.files = files; self.done = done
    }

    public var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }
    public var doneBytes: Int64 { files.filter { done.contains($0.path) }.reduce(0) { $0 + $1.size } }
    public var remaining: [RemoteFile] { files.filter { !done.contains($0.path) } }
    public var isComplete: Bool { !files.isEmpty && remaining.isEmpty }

    public mutating func markDone(_ path: String) { if files.contains(where: { $0.path == path }) { done.insert(path) } }

    /// 0 to 1, counting finished files plus the bytes already written for files still downloading.
    public func fraction(inFlight: [String: Int64] = [:]) -> Double {
        let total = totalBytes
        guard total > 0 else { return 0 }
        var partial: Int64 = 0
        for file in files where !done.contains(file.path) {
            partial += min(max(inFlight[file.path] ?? 0, 0), file.size)
        }
        return min(1, Double(doneBytes + partial) / Double(total))
    }

    /// Keeps finished files from an older listing when their name and size are unchanged.
    public func updated(with newFiles: [RemoteFile]) -> DownloadManifest {
        let keep = Set(files.map(\.self)).intersection(newFiles).filter { done.contains($0.path) }.map(\.path)
        return DownloadManifest(id: id, files: newFiles, done: Set(keep))
    }
}

/// Short text for the progress display, for example "42% · 310 MB of 730 MB".
public enum DownloadText {
    public static func summary(fraction: Double, totalBytes: Int64) -> String {
        let pct = Int((min(max(fraction, 0), 1) * 100).rounded(.down))
        let done = Int64(Double(totalBytes) * min(max(fraction, 0), 1))
        let f = ByteCountFormatter()
        f.countStyle = .file
        return "\(pct)% · \(f.string(fromByteCount: done)) of \(f.string(fromByteCount: totalBytes))"
    }
}
