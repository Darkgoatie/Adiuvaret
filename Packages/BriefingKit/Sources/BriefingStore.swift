import Foundation

/// The briefings, kept in one JSON file on the phone.
public final class BriefingStore: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var items: [Briefing]

    public init(url: URL) {
        self.url = url
        items = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Briefing].self, from: $0) } ?? []
    }

    public static func standard() -> BriefingStore {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return BriefingStore(url: dir.appendingPathComponent("briefings.json"))
    }

    public func all() -> [Briefing] { lock.lock(); defer { lock.unlock() }; return items }
    public func find(_ id: UUID) -> Briefing? { all().first { $0.id == id } }

    /// Adds a new briefing or replaces the one with the same id. Returns false when the limit is reached.
    @discardableResult public func save(_ b: Briefing) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if let i = items.firstIndex(where: { $0.id == b.id }) { items[i] = b }
        else {
            guard items.count < BriefingLimits.maxBriefings else { return false }
            items.append(b)
        }
        persist()
        return true
    }

    public func remove(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        items.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: url, options: .atomic) }
    }
}
