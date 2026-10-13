import Foundation
import AdiuvaretCore

/// One tool call as the activity log shows it. It names the tool and what happened; it never holds the arguments or the result,
/// because those carry the user's events, reminders and messages.
public struct ActivityEntry: Codable, Sendable, Equatable, Identifiable {
    public enum Outcome: String, Codable, Sendable { case done, failed, declined, blocked }

    public let id: UUID
    public let time: Date
    public let tool: String
    public let outcome: Outcome
    /// Why a call was blocked, for example "killSwitch" or "rateLimited". Empty otherwise.
    public let reason: String
    /// True when an approval card was shown for this call.
    public let asked: Bool
    public let milliseconds: Int

    public init(id: UUID = UUID(), time: Date = Date(), tool: String, outcome: Outcome, reason: String = "", asked: Bool, milliseconds: Int) {
        self.id = id; self.time = time; self.tool = tool; self.outcome = outcome
        self.reason = reason; self.asked = asked; self.milliseconds = milliseconds
    }

    /// Tool results that start like this are failures the executor reported in words.
    public static func looksFailed(_ output: String) -> Bool {
        output.hasPrefix("Not done") || output.hasPrefix("Failed") || output.hasPrefix("No website is open")
    }

    public static func make(_ call: ToolCall, _ result: GateOutcome, asked: Bool, milliseconds: Int, time: Date = Date()) -> ActivityEntry {
        switch result {
        case .executed(let output):
            return ActivityEntry(time: time, tool: call.toolName, outcome: looksFailed(output) ? .failed : .done, asked: asked, milliseconds: milliseconds)
        case .failed:
            return ActivityEntry(time: time, tool: call.toolName, outcome: .failed, asked: asked, milliseconds: milliseconds)
        case .blocked(let reason):
            if reason == .userDenied { return ActivityEntry(time: time, tool: call.toolName, outcome: .declined, asked: true, milliseconds: 0) }
            return ActivityEntry(time: time, tool: call.toolName, outcome: .blocked, reason: String(describing: reason), asked: asked, milliseconds: 0)
        }
    }
}

/// The newest entries, kept in one JSON file on the phone.
public final class ActivityStore: @unchecked Sendable {
    public static let limit = 300

    private let url: URL
    private let lock = NSLock()
    private var entries: [ActivityEntry]

    public init(url: URL) {
        self.url = url
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        entries = (try? Data(contentsOf: url)).flatMap { try? decoder.decode([ActivityEntry].self, from: $0) } ?? []
    }

    public static let shared: ActivityStore = {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return ActivityStore(url: dir.appendingPathComponent("activity.json"))
    }()

    /// Newest first.
    public func all() -> [ActivityEntry] { lock.lock(); defer { lock.unlock() }; return entries }

    public func record(_ entry: ActivityEntry) {
        lock.lock(); defer { lock.unlock() }
        entries.insert(entry, at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
        persist()
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        entries = []
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
