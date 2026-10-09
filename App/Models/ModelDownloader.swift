import Foundation
import ModelLibrary
import Diagnostics

enum DownloadError: LocalizedError {
    case invalidRepository
    case badListing
    case http(Int)
    case short(Int64, Int64)
    case restart

    var errorDescription: String? {
        switch self {
        case .invalidRepository: "Invalid model name."
        case .badListing: "The model's file list is not what was expected."
        case .http(let code): "The server answered \(code)."
        case .short(let got, let want): "The connection ended early (\(got / 1_000_000) of \(want / 1_000_000) MB)."
        case .restart: "The partial file did not match and was discarded."
        }
    }
}

/// Downloads a model's files one at a time into its folder. Stopping it for any reason keeps the partial file;
/// starting it again continues from the last byte. Needs no third-party package.
actor ModelDownloader {
    static let shared = ModelDownloader()

    /// Runs until every file is complete. Throws CancellationError when stopped, with all progress kept on disk.
    func download(_ id: String, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard DownloadPlan.isValidRepository(id) else { throw DownloadError.invalidRepository }
        let fm = FileManager.default
        let folder = ModelStore.folder(for: id)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        var manifest = ModelStore.loadManifest(id)
        if manifest == nil || manifest?.files.isEmpty == true {
            manifest = try await retrying { try await self.fetchManifest(id) }
            if let manifest { ModelStore.saveManifest(manifest) }
        }
        guard var plan = manifest else { throw DownloadError.badListing }
        // A finished file that was deleted since is not finished.
        for path in plan.done where !fm.fileExists(atPath: folder.appendingPathComponent(path).path) { plan.done.remove(path) }
        progress(ModelStore.pendingFraction(id) ?? plan.fraction())

        for file in plan.remaining {
            try Task.checkCancellation()
            let snapshot = plan
            try await retrying {
                try await self.fetchFile(id: id, file: file, folder: folder) { bytes in
                    progress(snapshot.fraction(inFlight: [file.path: bytes]))
                }
            }
            plan.markDone(file.path)
            ModelStore.saveManifest(plan)
            progress(plan.fraction())
        }
        DiagnosticsLog.shared.record("model download", "files complete \(id)")
    }

    private func fetchManifest(_ id: String) async throws -> DownloadManifest {
        guard let url = DownloadPlan.treeURL(id) else { throw DownloadError.invalidRepository }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw DownloadError.http(http.statusCode) }
        let files = try DownloadPlan.files(fromTreeJSON: data)
        guard files.contains(where: { $0.path == "config.json" }), files.contains(where: { $0.path.hasSuffix(".safetensors") }) else {
            throw DownloadError.badListing
        }
        return DownloadManifest(id: id, files: files)
    }

    private func fetchFile(id: String, file: RemoteFile, folder: URL, bytes: @escaping @Sendable (Int64) -> Void) async throws {
        let fm = FileManager.default
        let target = folder.appendingPathComponent(file.path)
        if let size = Self.size(target), file.size == 0 || size == file.size { return }
        let part = folder.appendingPathComponent(file.path + ".part")
        var offset = Self.size(part) ?? 0
        if file.size > 0, offset > file.size { try? fm.removeItem(at: part); offset = 0 }
        if !(file.size > 0 && offset == file.size) {
            guard let url = DownloadPlan.fileURL(id, path: file.path) else { throw DownloadError.invalidRepository }
            var request = URLRequest(url: url)
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            if offset > 0 { request.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range") }
            try await FileFetch(part: part, offset: offset, report: bytes).run(request)
        }
        let got = Self.size(part) ?? 0
        if file.size > 0, got < file.size { throw DownloadError.short(got, file.size) }
        if file.size > 0, got > file.size { try? fm.removeItem(at: part); throw DownloadError.restart }
        try? fm.removeItem(at: target)
        try fm.moveItem(at: part, to: target)
    }

    /// Tries again with growing pauses when the failure is the kind a bad connection causes.
    private func retrying<T>(_ work: @Sendable () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do { return try await work() }
            catch is CancellationError { throw CancellationError() }
            catch {
                attempt += 1
                guard Self.isTransient(error), attempt <= 6 else { throw error }
                DiagnosticsLog.shared.record("model download", "retry \(attempt): \(String(String(describing: error).prefix(100)))")
                try await Task.sleep(for: .seconds(min(30, 2 << attempt)))
            }
        }
    }

    private static func isTransient(_ error: Error) -> Bool {
        if let e = error as? DownloadError {
            switch e {
            case .short, .restart: return true
            case .http(let code): return code >= 500 || code == 429
            default: return false
            }
        }
        guard let u = error as? URLError else { return false }
        switch u.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
             .internationalRoamingOff, .dataNotAllowed, .secureConnectionFailed, .resourceUnavailable: return true
        default: return false
        }
    }

    private static func size(_ url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
    }
}

/// One file transfer that appends to a `.part` file. The server may ignore the byte range; then the file starts over.
private final class FileFetch: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let part: URL
    private let report: @Sendable (Int64) -> Void
    private var written: Int64
    private var continuation: CheckedContinuation<Void, Error>?
    private var task: URLSessionDataTask?
    private var session: URLSession?
    private var handle: FileHandle?
    private var cancelled = false
    private var failure: Error?
    private var lastReport = Date.distantPast

    init(part: URL, offset: Int64, report: @escaping @Sendable (Int64) -> Void) {
        self.part = part; self.written = offset; self.report = report
    }

    func run(_ request: URLRequest) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                lock.lock()
                if cancelled { lock.unlock(); cont.resume(throwing: CancellationError()); return }
                continuation = cont
                let config = URLSessionConfiguration.default
                config.waitsForConnectivity = true
                config.timeoutIntervalForRequest = 60
                config.timeoutIntervalForResource = 60 * 60 * 24
                config.requestCachePolicy = .reloadIgnoringLocalCacheData
                let s = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                let t = s.dataTask(with: request)
                session = s; task = t
                lock.unlock()
                t.resume()
            }
        } onCancel: {
            lock.lock(); cancelled = true; let t = task; lock.unlock()
            t?.cancel()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else { stop(URLError(.badServerResponse), completionHandler); return }
        switch http.statusCode {
        case 206:
            break
        case 200:
            if written > 0 {
                // The server sent the whole file again, so the partial one is useless.
                try? FileManager.default.removeItem(at: part)
                lock.lock(); written = 0; lock.unlock()
            }
        case 416:
            stop(DownloadError.restart, completionHandler); return
        default:
            stop(DownloadError.http(http.statusCode), completionHandler); return
        }
        do {
            if !FileManager.default.fileExists(atPath: part.path) { FileManager.default.createFile(atPath: part.path, contents: nil) }
            let h = try FileHandle(forWritingTo: part)
            try h.seekToEnd()
            lock.lock(); handle = h; lock.unlock()
            completionHandler(.allow)
        } catch {
            stop(error, completionHandler)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard let h = handle else { lock.unlock(); return }
        do {
            try h.write(contentsOf: data)
            written += Int64(data.count)
        } catch {
            failure = error
            lock.unlock()
            dataTask.cancel()
            return
        }
        let total = written
        let due = Date().timeIntervalSince(lastReport) > 0.25
        if due { lastReport = Date() }
        lock.unlock()
        if due { report(total) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        try? handle?.close()
        handle = nil
        let cont = continuation; continuation = nil
        let s = self.session; self.session = nil; self.task = nil
        let wasCancelled = cancelled
        let fail = failure
        let total = written
        lock.unlock()
        s?.finishTasksAndInvalidate()
        guard let cont else { return }
        if let fail { cont.resume(throwing: fail) }
        else if wasCancelled { cont.resume(throwing: CancellationError()) }
        else if let error {
            if (error as? URLError)?.code == .cancelled { cont.resume(throwing: CancellationError()) } else { cont.resume(throwing: error) }
        } else {
            report(total)
            cont.resume()
        }
    }

    private func stop(_ error: Error, _ completionHandler: (URLSession.ResponseDisposition) -> Void) {
        lock.lock(); failure = error; lock.unlock()
        completionHandler(.cancel)
    }
}
