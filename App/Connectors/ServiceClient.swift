import Foundation
import Security
import ToolKit

/// Tokens for the connected services. They live in the Keychain, only on this device, and are never written to logs, settings or chats.
enum SecretStore {
    private static let service = "com.halit.adiuvaretapp.connectors"

    private static func query(_ id: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: id]
    }

    static func save(_ token: String, for id: String) -> Bool {
        delete(id)
        var q = query(id)
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func token(for id: String) -> String? {
        var q = query(id)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func has(_ id: String) -> Bool { token(for: id) != nil }

    static func delete(_ id: String) { SecItemDelete(query(id) as CFDictionary) }
}

/// Sends one request to one service. The token is attached here and only when the address belongs to that service.
enum ServiceClient {
    enum Failure: Error { case notConnected, wrongHost, rejected(Int), unreachable }

    static func send(_ request: URLRequest?, to connector: String) async throws -> Data {
        guard var request, let url = request.url else { throw Failure.wrongHost }
        guard ServiceHost.isAllowed(url, for: connector) else { throw Failure.wrongHost }
        guard let token = SecretStore.token(for: connector) else { throw Failure.notConnected }
        (ConnectorRegistry.manifest(connector)?.auth ?? .bearer).apply(token, to: &request)
        request.timeoutInterval = 15
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw Failure.unreachable }
            guard (200..<300).contains(http.statusCode) else { throw Failure.rejected(http.statusCode) }
            guard data.count < 1_500_000 else { throw Failure.unreachable }
            return data
        } catch let f as Failure {
            throw f
        } catch {
            throw Failure.unreachable
        }
    }

    /// What to tell the model when a call fails. Never includes the token or the response body.
    static func message(_ error: Error, service: String) -> String {
        guard let f = error as? Failure else { return "Not done: \(service) could not be reached. Tell the user." }
        switch f {
        case .notConnected: return "Not done: \(service) has no token yet. Tell the user to paste one in Advanced, Integrations."
        case .wrongHost: return "Not done: that request is not allowed."
        case .rejected(let code) where code == 401 || code == 403: return "Not done: \(service) refused the token. Tell the user to check it in Advanced, Integrations."
        case .rejected(let code) where code == 429: return "Not done: \(service) says too many requests. Tell the user to try again later."
        case .rejected(let code): return "Not done: \(service) answered with status \(code)."
        case .unreachable: return "Not done: \(service) could not be reached. Tell the user they may be offline."
        }
    }
}

/// A token must never follow a redirect to another address.
final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
