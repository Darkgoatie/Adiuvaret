import Foundation
import Observation
import ModelLibrary
import Diagnostics

/// The providers the user has connected, the models they picked, and the live model lists. Keys live in the Keychain only.
@MainActor @Observable
final class ProviderStore {
    static let shared = ProviderStore()

    private static let pickedKey = "providers.pickedModels"
    private static let listKey = "providers.cachedModels"

    /// Models the user turned on for the chat menu, as "provider:model".
    private(set) var picked: [String]
    private(set) var cached: [String: [String]]
    /// Provider ids whose key is stored. Kept in memory so views update; the Keychain is the truth.
    private(set) var connected: Set<String>
    private(set) var checking: Set<String> = []

    private init() {
        picked = UserDefaults.standard.stringArray(forKey: Self.pickedKey) ?? []
        cached = (UserDefaults.standard.dictionary(forKey: Self.listKey) as? [String: [String]]) ?? [:]
        connected = Set(Providers.all.map(\.id).filter { SecretStore.has(Self.account($0)) })
        picked = picked.filter { id in Providers.parseModelID(id).map { connected.contains($0.provider.id) } ?? false }
    }

    static func account(_ providerID: String) -> String { "provider." + providerID }

    func isConnected(_ id: String) -> Bool { connected.contains(id) }

    /// Models to show for a provider: the live list when it was fetched, otherwise the suggestions.
    func models(for p: Provider) -> [String] {
        let live = cached[p.id] ?? []
        return live.isEmpty ? p.suggestedModels : live
    }

    func isPicked(_ providerID: String, _ model: String) -> Bool { picked.contains(Providers.modelID(provider: providerID, model: model)) }

    func setPicked(_ on: Bool, provider: String, model: String) {
        let id = Providers.modelID(provider: provider, model: model)
        picked.removeAll { $0 == id }
        if on { picked.append(id) }
        UserDefaults.standard.set(picked, forKey: Self.pickedKey)
    }

    /// The models for the chat menu, in the order the user turned them on.
    var choices: [ModelChoice] {
        picked.compactMap { id in
            guard let (p, m) = Providers.parseModelID(id), connected.contains(p.id) else { return nil }
            return ModelChoice(id: id, name: "\(m) · \(p.name.split(separator: " ").first.map(String.init) ?? p.name)")
        }
    }

    func key(for id: String) -> String? { SecretStore.token(for: Self.account(id)) }

    enum SaveResult: Equatable { case saved, implausible, keychainFailed, rejected(String), unreachable }

    /// Saves the key only after the provider accepted it. The key is checked with a free request (the model list), so nothing is billed.
    func connect(_ p: Provider, pasted: String) async -> SaveResult {
        let key = APIKey.clean(pasted)
        guard APIKey.isPlausible(key) else { return .implausible }
        checking.insert(p.id); defer { checking.remove(p.id) }
        switch await CloudClient.listModels(p, key: key) {
        case .success(let ids):
            guard SecretStore.save(key, for: Self.account(p.id)) else { return .keychainFailed }
            connected.insert(p.id)
            if !ids.isEmpty { cached[p.id] = ids; UserDefaults.standard.set(cached, forKey: Self.listKey) }
            // First connection: turn on the first suggestion so there is something to pick in the chat menu right away.
            if !picked.contains(where: { Providers.parseModelID($0)?.provider.id == p.id }), let first = ids.first(where: { p.suggestedModels.contains($0) }) ?? p.suggestedModels.first {
                setPicked(true, provider: p.id, model: first)
            }
            DiagnosticsLog.shared.record("providers", "\(p.id) connected")
            return .saved
        case .failure(.rejected(let text)): return .rejected(text)
        case .failure(.unreachable): return .unreachable
        }
    }

    func disconnect(_ id: String) {
        SecretStore.delete(Self.account(id))
        connected.remove(id)
        cached[id] = nil
        UserDefaults.standard.set(cached, forKey: Self.listKey)
        picked.removeAll { Providers.parseModelID($0)?.provider.id == id }
        UserDefaults.standard.set(picked, forKey: Self.pickedKey)
        DiagnosticsLog.shared.record("providers", "\(id) disconnected")
    }

    func refreshModels(_ p: Provider) async {
        guard let key = key(for: p.id) else { return }
        checking.insert(p.id); defer { checking.remove(p.id) }
        if case .success(let ids) = await CloudClient.listModels(p, key: key), !ids.isEmpty {
            cached[p.id] = ids
            UserDefaults.standard.set(cached, forKey: Self.listKey)
        }
    }
}

/// Talks to a provider. The key is attached here, at send time, and only to the provider's own host. Redirects are not followed.
enum CloudClient {
    enum Failure: Error, Equatable { case rejected(String), unreachable }

    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    static func session(timeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
    }

    static func request(_ p: Provider, url: URL?, key: String, body: Data? = nil) -> URLRequest? {
        guard let url, Providers.isAllowed(url, for: p) else { return nil }
        var r = URLRequest(url: url)
        for (k, v) in ProviderWire.headers(p, key: key) { r.setValue(v, forHTTPHeaderField: k) }
        if let body { r.httpMethod = "POST"; r.httpBody = body }
        return r
    }

    static func listModels(_ p: Provider, key: String) async -> Result<[String], Failure> {
        guard var r = request(p, url: ProviderWire.modelsURL(p), key: key) else { return .failure(.unreachable) }
        r.timeoutInterval = 15
        let s = session(timeout: 15); defer { s.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await s.data(for: r)
            guard let http = response as? HTTPURLResponse else { return .failure(.unreachable) }
            guard http.statusCode == 200 else {
                // Some providers answer 400 for a bad key. While checking a key, 400 means the key.
                return .failure(.rejected(ProviderWire.problem(status: http.statusCode == 400 ? 401 : http.statusCode, provider: p)))
            }
            return .success(ProviderWire.modelIDs(p, data: data))
        } catch {
            return .failure(.unreachable)
        }
    }

    /// Streams the reply text. Throws a short sentence on failure, never the key or the response body.
    static func stream(_ p: Provider, model: String, key: String, system: String, messages: [ProviderWire.Message]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let work = Task {
                guard let body = ProviderWire.chatBody(p, model: model, system: system, messages: messages), var r = request(p, url: ProviderWire.chatURL(p), key: key, body: body) else {
                    continuation.finish(throwing: ProviderError.text("The request could not be built."))
                    return
                }
                r.timeoutInterval = 60
                let s = session(timeout: 60); defer { s.finishTasksAndInvalidate() }
                do {
                    let (bytes, response) = try await s.bytes(for: r)
                    guard let http = response as? HTTPURLResponse else { throw ProviderError.text("No answer from \(p.name).") }
                    guard http.statusCode == 200 else { throw ProviderError.text(ProviderWire.problem(status: http.statusCode, provider: p)) }
                    for try await line in bytes.lines {
                        guard let chunk = ProviderWire.chunk(p, line: line) else { continue }
                        if let e = chunk.error { throw ProviderError.text(e) }
                        if !chunk.text.isEmpty { continuation.yield(chunk.text) }
                        if chunk.done { break }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let e as ProviderError {
                    continuation.finish(throwing: e)
                } catch {
                    continuation.finish(throwing: ProviderError.text("Could not reach \(p.name). Check the connection."))
                }
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }
}

struct ProviderError: Error, LocalizedError {
    let message: String
    static func text(_ s: String) -> ProviderError { ProviderError(message: s) }
    var errorDescription: String? { message }
}
