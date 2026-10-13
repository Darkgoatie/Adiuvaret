import Foundation
import ToolKit

/// The hosts the user lets the assistant call, with how each one wants its token. The token itself is in the Keychain under `api:<host>`.
struct APIHostEntry: Codable, Equatable, Identifiable {
    let host: String
    let auth: String
    var id: String { host }
    var style: APIAuth { APIAuth.parse(auth) ?? .none }
}

final class APIHostStore: @unchecked Sendable {
    static let shared = APIHostStore()
    private let key = "api.hosts.v1"
    private let lock = NSLock()
    static let limit = 30

    private func load() -> [APIHostEntry] {
        guard let data = UserDefaults.standard.data(forKey: key), let list = try? JSONDecoder().decode([APIHostEntry].self, from: data) else { return [] }
        return list
    }

    private func save(_ list: [APIHostEntry]) {
        if let data = try? JSONEncoder().encode(list) { UserDefaults.standard.set(data, forKey: key) }
    }

    func all() -> [APIHostEntry] { lock.lock(); defer { lock.unlock() }; return load() }

    func entry(_ host: String) -> APIHostEntry? { all().first { $0.host == host } }

    static func secretID(_ host: String) -> String { "api:" + host }

    func hasToken(_ host: String) -> Bool { SecretStore.has(Self.secretID(host)) }

    /// Adds or replaces a host. False when the host or style is not valid or the list is full.
    @discardableResult
    func add(host: String, auth: APIAuth, token: String?) -> Bool {
        guard let h = APIHost.normalize(host) else { return false }
        lock.lock(); defer { lock.unlock() }
        var list = load()
        if !list.contains(where: { $0.host == h }), list.count >= Self.limit { return false }
        if auth.needsToken, let token, !token.isEmpty {
            guard APIToken.isPlausible(token), SecretStore.save(token, for: Self.secretID(h)) else { return false }
        }
        list.removeAll { $0.host == h }
        list.append(APIHostEntry(host: h, auth: auth.label))
        save(list)
        if !auth.needsToken { SecretStore.delete(Self.secretID(h)) }
        return true
    }

    func remove(_ host: String) {
        lock.lock(); defer { lock.unlock() }
        save(load().filter { $0.host != host })
        SecretStore.delete(Self.secretID(host))
    }

    func removeAll() { for e in all() { remove(e.host) } }
}
