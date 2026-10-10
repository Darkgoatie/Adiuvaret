import Foundation

public enum MemorySave: Sendable, Equatable {
    case added(MemoryFact)
    case duplicate
    case full
}

/// The facts, kept in one JSON file on the phone. Never trims by itself: when it is full the caller asks the user what to forget.
public final class MemoryStore: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()
    private var facts: [MemoryFact]

    public init(url: URL) {
        self.url = url
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        facts = (try? Data(contentsOf: url)).flatMap { try? decoder.decode([MemoryFact].self, from: $0) } ?? []
    }

    public static func standard() -> MemoryStore {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return MemoryStore(url: dir.appendingPathComponent("memory.json"))
    }

    public func all() -> [MemoryFact] { lock.lock(); defer { lock.unlock() }; return facts }

    public func add(_ text: String) -> MemorySave {
        lock.lock(); defer { lock.unlock() }
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(MemoryLimits.maxFactLength))
        guard !clean.isEmpty, !MemoryMath.isDuplicate(clean, of: facts) else { return .duplicate }
        guard facts.count < MemoryLimits.maxFacts else { return .full }
        let fact = MemoryFact(text: clean)
        facts.append(fact)
        persist()
        return .added(fact)
    }

    @discardableResult public func remove(_ id: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let i = facts.firstIndex(where: { $0.id == id }) else { return false }
        facts.remove(at: i)
        persist()
        return true
    }

    public func update(_ id: UUID, text: String) {
        lock.lock(); defer { lock.unlock() }
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(MemoryLimits.maxFactLength))
        guard !clean.isEmpty, let i = facts.firstIndex(where: { $0.id == id }) else { return }
        facts[i].text = clean
        persist()
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        facts = []
        persist()
    }

    /// The prompt block for a message, or an empty string when nothing is stored.
    public func promptBlock(for message: String) -> String {
        MemoryMath.promptBlock(MemoryMath.relevant(all(), for: message))
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(facts) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
