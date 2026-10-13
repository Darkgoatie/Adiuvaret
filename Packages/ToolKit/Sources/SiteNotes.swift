import Foundation

/// One way through a site: the labels of the links and buttons that were clicked, in order.
public struct SiteRoute: Codable, Equatable, Sendable {
    public var steps: [String]
    public var date: Date
    public init(steps: [String], date: Date) { self.steps = steps; self.date = date }
}

public struct SiteNote: Codable, Equatable, Sendable {
    public var host: String
    public var routes: [SiteRoute]
    public init(host: String, routes: [SiteRoute]) { self.host = host; self.routes = routes }
}

/// Rules for what a site note may hold. Only click labels are kept, never typed text, page text or addresses.
public enum SiteNoteRules {
    public static let maxHosts = 30
    public static let maxRoutes = 3
    public static let maxSteps = 8
    public static let maxLabel = 40

    /// A label that is safe to keep, or nil. Labels that look personal (an address, a long number) are dropped.
    public static func cleanLabel(_ raw: String) -> String? {
        let label = raw.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard !label.isEmpty, !label.contains("@"), !label.contains("://") else { return nil }
        var run = 0
        for ch in label {
            run = ch.isNumber ? run + 1 : 0
            if run >= 5 { return nil }
        }
        return String(label.prefix(maxLabel))
    }

    /// Adds a route to a host's note. A shorter route that the new one extends is replaced, a repeat moves to the front.
    public static func merge(_ notes: [SiteNote], host: String, steps: [String], now: Date) -> [SiteNote] {
        let host = host.lowercased()
        var clean: [String] = []
        for step in steps {
            guard let label = cleanLabel(step), clean.last != label else { continue }
            clean.append(label)
        }
        clean = Array(clean.suffix(maxSteps))
        guard !host.isEmpty, !clean.isEmpty else { return notes }
        var all = notes
        var note = all.first(where: { $0.host == host }) ?? SiteNote(host: host, routes: [])
        all.removeAll { $0.host == host }
        note.routes.removeAll { $0.steps == clean || (clean.count > $0.steps.count && Array(clean.prefix($0.steps.count)) == $0.steps) }
        note.routes.insert(SiteRoute(steps: clean, date: now), at: 0)
        note.routes = Array(note.routes.prefix(maxRoutes))
        all.insert(note, at: 0)
        return Array(all.prefix(maxHosts))
    }

    /// The text handed to the model when it opens a site it has visited before.
    public static func render(_ note: SiteNote?) -> String {
        guard let note, !note.routes.isEmpty else { return "" }
        let lines = note.routes.enumerated().map { "\($0.offset + 1). " + $0.element.steps.joined(separator: " > ") }
        return "Notes from earlier visits to \(note.host), the labels that were clicked (the page may have changed, so read it first and use a note only if its labels are there):\n" + lines.joined(separator: "\n")
    }
}

/// The site notes, kept in one JSON file on the phone.
public final class SiteNoteStore: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var notes: [SiteNote]

    public init(url: URL) {
        self.url = url
        notes = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([SiteNote].self, from: $0) } ?? []
    }

    public static func standard() -> SiteNoteStore {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return SiteNoteStore(url: dir.appendingPathComponent("sitenotes.json"))
    }

    public func all() -> [SiteNote] { lock.lock(); defer { lock.unlock() }; return notes }

    public func note(for host: String) -> SiteNote? {
        lock.lock(); defer { lock.unlock() }
        return notes.first { $0.host == host.lowercased() }
    }

    public func record(host: String, steps: [String]) {
        lock.lock(); defer { lock.unlock() }
        notes = SiteNoteRules.merge(notes, host: host, steps: steps, now: Date())
        persist()
    }

    public func remove(host: String) {
        lock.lock(); defer { lock.unlock() }
        notes.removeAll { $0.host == host.lowercased() }
        persist()
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        notes = []
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
