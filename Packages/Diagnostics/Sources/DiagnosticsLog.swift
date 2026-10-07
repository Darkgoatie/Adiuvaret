import Foundation

/// One line in the diagnostics log. Holds timings, tool names and error types, never message text.
public struct DiagEvent: Codable, Sendable, Equatable {
    public let time: Date
    public let kind: String
    public let detail: String
}

/// A small rolling log kept on the phone and shared by the user on request. It keeps the newest `capacity` events.
public final class DiagnosticsLog: @unchecked Sendable {
    public static let shared = DiagnosticsLog(fileURL: DiagnosticsLog.defaultURL)

    public static let maxDetail = 240
    private let lock = NSLock()
    private var events: [DiagEvent] = []
    private let capacity: Int
    private let fileURL: URL?

    public init(capacity: Int = 50, fileURL: URL? = nil) {
        self.capacity = capacity
        self.fileURL = fileURL
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder.iso.decode([DiagEvent].self, from: data) {
            events = Array(saved.suffix(capacity))
        }
    }

    static var defaultURL: URL? {
        guard let dir = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        return dir.appendingPathComponent("diagnostics.json")
    }

    public func record(_ kind: String, _ detail: String = "", at time: Date = Date()) {
        let clean = String(detail.replacingOccurrences(of: "\n", with: " ").prefix(Self.maxDetail))
        lock.lock(); defer { lock.unlock() }
        events.append(DiagEvent(time: time, kind: kind, detail: clean))
        if events.count > capacity { events.removeFirst(events.count - capacity) }
        if let fileURL, let data = try? JSONEncoder.iso.encode(events) { try? data.write(to: fileURL, options: .atomic) }
    }

    public var snapshot: [DiagEvent] {
        lock.lock(); defer { lock.unlock() }
        return events
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        events = []
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
    }

    /// The text the user shares: a header with device facts, then the events oldest first.
    public func report(header: [String: String]) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let head = header.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
        let lines = snapshot.map { e in
            "\(f.string(from: e.time))  \(e.kind)" + (e.detail.isEmpty ? "" : "  \(e.detail)")
        }
        return (["Adiuvaret diagnostics", "No message text, event titles or personal data are recorded.", ""] + head + ["", "Events (\(lines.count))"] + lines)
            .joined(separator: "\n")
    }
}

private extension JSONEncoder {
    static var iso: JSONEncoder { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}
private extension JSONDecoder {
    static var iso: JSONDecoder { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }
}

public extension Duration {
    /// Whole milliseconds, for timing lines.
    var milliseconds: Int { Int(components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000) }
}
