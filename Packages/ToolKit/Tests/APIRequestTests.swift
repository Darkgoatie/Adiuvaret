import Testing
import Foundation
@testable import ToolKit

@Suite struct APIRequestTests {
    @Test func hostsAreBareDomains() {
        #expect(APIHost.normalize("api.hetzner.cloud") == "api.hetzner.cloud")
        #expect(APIHost.normalize("https://API.Example.com/v1/x?y=1") == "api.example.com")
        for bad in ["", "localhost", "192.168.0.1", "10.0.0.5", "api.example.com:8080", "user@api.example.com", "printer.local", "nas.lan", "a b.com", "[::1]", "-x.com", "http://127.0.0.1"] {
            #expect(APIHost.normalize(bad) == nil, Comment(rawValue: bad))
        }
    }

    @Test func authLabelsRoundTrip() {
        for text in ["none", "bearer", "header:X-API-Key", "query:api_key"] {
            #expect(APIAuth.parse(text)?.label == text, Comment(rawValue: text))
        }
        #expect(APIAuth.parse("") == APIAuth.none)
        for bad in ["basic", "header:", "header:Host", "header:Cookie", "header:a b", "query:", "token"] {
            #expect(APIAuth.parse(bad) == nil, Comment(rawValue: bad))
        }
    }

    @Test func requestStaysOnTheApprovedHost() throws {
        let r = try APIRequestBuilder.build(host: "api.example.com", method: "get", path: "v1/servers?limit=5", query: "page=2", body: "", auth: .bearer, token: "tok123456789").get()
        #expect(r.url?.host == "api.example.com" && r.url?.scheme == "https")
        #expect(r.url?.path == "/v1/servers")
        #expect(r.url?.query == "page=2&limit=5" || r.url?.query == "limit=5&page=2" || r.url?.query == "page=2")
        #expect(r.httpMethod == "GET")
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer tok123456789")
        for hostile in ["//evil.com/x", "/a/../b", "https://evil.com/x", "/x\\y"] {
            let r2 = APIRequestBuilder.build(host: "api.example.com", method: "GET", path: hostile, query: "", body: "", auth: .none, token: nil)
            if case .success(let req) = r2 { #expect(req.url?.host == "api.example.com", Comment(rawValue: hostile)) }
        }
        if case .success = APIRequestBuilder.build(host: "api.example.com", method: "GET", path: "https://evil.com/x", query: "", body: "", auth: .none, token: nil) { Issue.record("scheme in path accepted") }
        if case .success = APIRequestBuilder.build(host: "api.example.com", method: "GET", path: "/a/../b", query: "", body: "", auth: .none, token: nil) { Issue.record("dotdot accepted") }
    }

    @Test func tokenGoesWhereTheAuthStyleSays() throws {
        let h = try APIRequestBuilder.build(host: "api.example.com", method: "POST", path: "/v1/x", query: "", body: #"{"a":1}"#, auth: .header("X-API-Key"), token: "secret-value-1").get()
        #expect(h.value(forHTTPHeaderField: "X-API-Key") == "secret-value-1")
        #expect(h.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(h.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(h.httpBody == Data(#"{"a":1}"#.utf8))
        let q = try APIRequestBuilder.build(host: "api.example.com", method: "GET", path: "/v1/x", query: "", body: "", auth: .query("key"), token: "secret-value-1").get()
        #expect(q.url?.query == "key=secret-value-1")
        let none = try APIRequestBuilder.build(host: "api.example.com", method: "GET", path: "/v1/x", query: "", body: "", auth: .bearer, token: nil).get()
        #expect(none.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func badInputIsRefused() {
        func fails(_ method: String, body: String = "", host: String = "api.example.com") -> Bool {
            if case .failure = APIRequestBuilder.build(host: host, method: method, path: "/x", query: "", body: body, auth: .none, token: nil) { return true }
            return false
        }
        #expect(fails("TRACE") && fails("") && fails("GET", body: "{}") && fails("POST", body: "not json") && fails("POST", host: "localhost"))
        #expect(fails("POST", body: String(repeating: "a", count: 30_000)))
        #expect(!fails("DELETE") && !fails("PUT", body: "{}"))
    }

    @Test func writesAreEveryMethodButGet() {
        #expect(!APIMethod.isWrite("get") && !APIMethod.isWrite("GET"))
        for m in ["POST", "put", "PATCH", "DELETE"] { #expect(APIMethod.isWrite(m)) }
    }

    @Test func responseIsMarkedCutAndScrubbed() {
        let long = String(repeating: "x", count: 9000)
        let t = APIResponse.text(status: 200, data: Data(long.utf8), host: "api.example.com", token: nil)
        #expect(t.hasPrefix("API response from api.example.com, status 200") && t.contains("Cut after"))
        #expect(t.count < 6400)
        let echoed = APIResponse.text(status: 200, data: Data(#"{"auth":"secret-value-1"}"#.utf8), host: "h.example.com", token: "secret-value-1")
        #expect(!echoed.contains("secret-value-1") && echoed.contains("[token]"))
        let fail = APIResponse.text(status: 404, data: Data("nope".utf8), host: "h.example.com", token: nil)
        #expect(fail.hasPrefix("Not done:") && fail.contains("404"))
        #expect(APIResponse.text(status: 204, data: Data(), host: "h.example.com", token: nil).contains("(empty body)"))
    }

    @Test func apiRequestsAreRecognised() {
        for t in ["Use the Hetzner API to list my servers", "call this endpoint for me", "Here is the API documentation, send a message", "curl https://api.example.com/v1/me", "post it to the slack webhook", "GET api.github.com/user"] {
            #expect(APIIntent.looksLikeAPIRequest(t), Comment(rawValue: t))
        }
        for t in ["What's on my calendar?", "tell me a joke", "I am happy with the result", "restart my therapy appointment", "apixaban dose"] {
            #expect(!APIIntent.looksLikeAPIRequest(t), Comment(rawValue: t))
        }
    }
}
