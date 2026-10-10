import Foundation
import ToolKit

/// The notes folder the user picked once. The app keeps a security-scoped bookmark and only ever reads and writes Markdown files inside it.
final class NoteVault: @unchecked Sendable {
    static let shared = NoteVault()
    private let key = "connector.notes.bookmark"
    private let nameKey = "connector.notes.name"
    private let maxFiles = 800
    private let maxBytes = 400_000

    var folderName: String? { UserDefaults.standard.string(forKey: nameKey) }
    var isConnected: Bool { UserDefaults.standard.data(forKey: key) != nil }

    /// Called with the folder the user chose in the file picker.
    func connect(_ url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.set(url.lastPathComponent, forKey: nameKey)
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: nameKey)
    }

    /// Runs `body` with the folder open. Nil when no folder is connected or the bookmark went stale.
    func withFolder<T>(_ body: (URL) throws -> T) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: key)
        }
        return try? body(url)
    }

    /// Every Markdown file with its text, hidden folders skipped, size and count capped.
    func allNotes() -> [(path: String, text: String)]? {
        withFolder { root in
            var out: [(String, String)] = []
            let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return out }
            for case let file as URL in walker {
                guard out.count < maxFiles, ["md", "markdown"].contains(file.pathExtension.lowercased()) else { continue }
                let values = try? file.resourceValues(forKeys: Set(keys))
                guard values?.isRegularFile == true, (values?.fileSize ?? 0) <= maxBytes else { continue }
                let relative = String(file.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
                guard NoteName.isSafeRelative(relative), let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                out.append((relative, text))
            }
            return out
        }
    }

    func read(_ relative: String) -> String? {
        guard NoteName.isSafeRelative(relative) else { return nil }
        return withFolder { root in
            let file = root.appendingPathComponent(relative).standardizedFileURL
            guard file.path.hasPrefix(root.standardizedFileURL.path + "/") else { throw CocoaError(.fileReadNoPermission) }
            return try String(contentsOf: file, encoding: .utf8)
        }
    }

    enum WriteResult { case created(String), appended(String), exists, failed, notConnected }

    /// Creates a new note, or adds to an existing one. Never overwrites and never leaves the folder.
    func write(title: String, text: String, appendTo path: String?) -> WriteResult {
        guard isConnected else { return .notConnected }
        let result: WriteResult? = withFolder { root in
            if let path {
                guard NoteName.isSafeRelative(path) else { return .failed }
                let file = root.appendingPathComponent(path).standardizedFileURL
                guard file.path.hasPrefix(root.standardizedFileURL.path + "/"), FileManager.default.fileExists(atPath: file.path) else { return .failed }
                let old = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
                try NoteFormat.appended(existing: old, text: text).write(to: file, atomically: true, encoding: .utf8)
                return .appended(path)
            }
            guard let name = NoteName.fileName(for: title) else { return .failed }
            let file = root.appendingPathComponent(name).standardizedFileURL
            guard file.path.hasPrefix(root.standardizedFileURL.path + "/") else { return .failed }
            if FileManager.default.fileExists(atPath: file.path) { return .exists }
            try NoteFormat.newNote(text).write(to: file, atomically: true, encoding: .utf8)
            return .created(name)
        }
        return result ?? .failed
    }
}
