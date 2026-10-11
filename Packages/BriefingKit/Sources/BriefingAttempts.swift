import Foundation

/// One record of what the background refresh did. The spike question is how often iOS runs it over several days, so every scheduling and every run is written down.
public struct BriefingAttempt: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case scheduled, ran, expired, notificationsRefreshed }
    public let date: Date
    public let kind: Kind
    public let detail: String
    public init(date: Date = Date(), kind: Kind, detail: String = "") { self.date = date; self.kind = kind; self.detail = detail }
}

public final class BriefingAttemptLog: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var entries: [BriefingAttempt]
    public static let cap = 200

    public init(url: URL) {
        self.url = url
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        entries = (try? Data(contentsOf: url)).flatMap { try? d.decode([BriefingAttempt].self, from: $0) } ?? []
    }

    public static func standard() -> BriefingAttemptLog {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return BriefingAttemptLog(url: dir.appendingPathComponent("briefing-attempts.json"))
    }

    public func record(_ kind: BriefingAttempt.Kind, _ detail: String = "", at date: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        entries.append(BriefingAttempt(date: date, kind: kind, detail: detail))
        if entries.count > Self.cap { entries.removeFirst(entries.count - Self.cap) }
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        if let data = try? e.encode(entries) { try? data.write(to: url, options: .atomic) }
    }

    public func all() -> [BriefingAttempt] { lock.lock(); defer { lock.unlock() }; return entries }

    public struct Summary: Equatable, Sendable {
        public var scheduled = 0, ran = 0, expired = 0, refreshed = 0
        public var firstRun: Date?
        public var lastRun: Date?
    }

    public func summary() -> Summary {
        var s = Summary()
        for e in all() {
            switch e.kind {
            case .scheduled: s.scheduled += 1
            case .ran: s.ran += 1; s.firstRun = s.firstRun ?? e.date; s.lastRun = e.date
            case .expired: s.expired += 1
            case .notificationsRefreshed: s.refreshed += 1
            }
        }
        return s
    }
}
