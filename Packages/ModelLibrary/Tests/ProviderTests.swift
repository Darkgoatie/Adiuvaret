import Testing
import Foundation
@testable import ModelLibrary

@Suite struct ProviderTests {
    @Test func everyProviderIsWellFormed() {
        let ids = Providers.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for p in Providers.all {
            #expect(!p.id.contains(":") && !p.id.isEmpty, Comment(rawValue: p.id))
            #expect(!p.host.isEmpty && !p.host.contains("/") && !p.host.contains(":"), Comment(rawValue: p.id))
            #expect(p.basePath.isEmpty || p.basePath.hasPrefix("/"), Comment(rawValue: p.id))
            #expect(p.keyPage.scheme == "https" && !p.suggestedModels.isEmpty, Comment(rawValue: p.id))
            #expect(ProviderWire.chatURL(p)?.host == p.host, Comment(rawValue: p.id))
            #expect(ProviderWire.modelsURL(p)?.host == p.host, Comment(rawValue: p.id))
        }
    }

    @Test func keyPagesAndEndpointsMatchWhatWasChecked() throws {
        func p(_ id: String) throws -> Provider { try #require(Providers.provider(id)) }
        #expect(try p("google").keyPage.absoluteString == "https://aistudio.google.com/api-keys")
        #expect(try p("zai").keyPage.absoluteString == "https://z.ai/manage-apikey/apikey-list")
        #expect(ProviderWire.chatURL(try p("openai"))?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(ProviderWire.chatURL(try p("anthropic"))?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(ProviderWire.chatURL(try p("google"))?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")
        #expect(ProviderWire.chatURL(try p("zai"))?.absoluteString == "https://api.z.ai/api/paas/v4/chat/completions")
        #expect(ProviderWire.chatURL(try p("deepseek"))?.absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(ProviderWire.modelsURL(try p("groq"))?.absoluteString == "https://api.groq.com/openai/v1/models")
    }

    @Test func modelIdsRoundTrip() throws {
        let id = Providers.modelID(provider: "openrouter", model: "anthropic/claude-sonnet-4.5")
        #expect(id == "openrouter:anthropic/claude-sonnet-4.5")
        let parsed = try #require(Providers.parseModelID(id))
        #expect(parsed.provider.id == "openrouter" && parsed.model == "anthropic/claude-sonnet-4.5")
        #expect(Providers.parseModelID("apple") == nil)
        #expect(Providers.parseModelID("mlx-community/gemma-3-1b-it-4bit") == nil)
        #expect(Providers.parseModelID("nope:model") == nil)
        #expect(Providers.parseModelID("openai:") == nil)
    }

    @Test func requestsMayOnlyGoToTheProviderHost() throws {
        let openai = try #require(Providers.provider("openai"))
        #expect(Providers.isAllowed(try #require(ProviderWire.chatURL(openai)), for: openai))
        #expect(!Providers.isAllowed(URL(string: "https://api.openai.com.evil.net/v1/chat/completions")!, for: openai))
        #expect(!Providers.isAllowed(URL(string: "http://api.openai.com/v1/x")!, for: openai))
        #expect(!Providers.isAllowed(URL(string: "https://u@api.openai.com/v1/x")!, for: openai))
        #expect(!Providers.isAllowed(URL(string: "https://api.anthropic.com/v1/messages")!, for: openai))
    }

    @Test func pastedKeysAreCleaned() {
        #expect(APIKey.clean("  sk-abc123def456ghi  \n") == "sk-abc123def456ghi")
        #expect(APIKey.clean("Bearer sk-abc123def456ghi") == "sk-abc123def456ghi")
        #expect(APIKey.clean("Authorization: Bearer sk-abc123def456ghi") == "sk-abc123def456ghi")
        #expect(APIKey.clean("x-api-key: sk-ant-abc123def456") == "sk-ant-abc123def456")
        #expect(APIKey.clean("\"sk-abc123def456ghi\"") == "sk-abc123def456ghi")
        #expect(APIKey.clean("'sk-abc123def456ghi'") == "sk-abc123def456ghi")
    }

    @Test func implausibleKeysAreRefused() {
        #expect(APIKey.isPlausible("sk-abc123def456ghi"))
        #expect(APIKey.isPlausible("0123456789abcdef.0123456789abcdef"))
        #expect(!APIKey.isPlausible("short"))
        #expect(!APIKey.isPlausible("sk-abc 123def456ghi"))
        #expect(!APIKey.isPlausible("sk-abc123def456ghi\r\nX-Evil: 1"))
        #expect(!APIKey.isPlausible("sk-abc123def456ghié"))
        #expect(!APIKey.isPlausible(String(repeating: "a", count: 401)))
    }

    @Test func maskingShowsOnlyTheEnds() {
        #expect(APIKey.masked("sk-abc123def456ghi789") == "sk-a••••i789")
        #expect(APIKey.masked("short") == "••••")
        #expect(!APIKey.masked("sk-abc123def456ghi789").contains("123def"))
    }
}

@Suite struct ProviderWireTests {
    private func provider(_ id: String) throws -> Provider { try #require(Providers.provider(id)) }

    @Test func headersCarryTheKeyTheRightWay() throws {
        let o = ProviderWire.headers(try provider("openai"), key: "sk-test")
        #expect(o["Authorization"] == "Bearer sk-test" && o["x-api-key"] == nil)
        let a = ProviderWire.headers(try provider("anthropic"), key: "sk-ant-test")
        #expect(a["x-api-key"] == "sk-ant-test" && a["anthropic-version"] == "2023-06-01" && a["Authorization"] == nil)
    }

    @Test func openAIBodiesPutTheSystemMessageFirst() throws {
        let body = try #require(ProviderWire.chatBody(try provider("openai"), model: "gpt-4.1", system: "Be brief.",
                                                      messages: [.init(isUser: true, text: "Hi"), .init(isUser: false, text: "Hello"), .init(isUser: true, text: "Weather?")]))
        let o = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(o["model"] as? String == "gpt-4.1" && o["stream"] as? Bool == true)
        let msgs = try #require(o["messages"] as? [[String: String]])
        #expect(msgs.map { $0["role"] ?? "" } == ["system", "user", "assistant", "user"])
        #expect(msgs.first?["content"] == "Be brief.")
    }

    @Test func anthropicBodiesUseATopLevelSystemField() throws {
        let body = try #require(ProviderWire.chatBody(try provider("anthropic"), model: "claude-sonnet-4-5", system: "Be brief.", messages: [.init(isUser: true, text: "Hi")]))
        let o = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(o["system"] as? String == "Be brief." && o["max_tokens"] as? Int == 2048)
        let msgs = try #require(o["messages"] as? [[String: String]])
        #expect(msgs.map { $0["role"] ?? "" } == ["user"])
    }

    @Test func historyIsMadeToAlternate() throws {
        let body = try #require(ProviderWire.chatBody(try provider("openai"), model: "m", system: "s",
            messages: [.init(isUser: false, text: "stray reply"), .init(isUser: true, text: "one"), .init(isUser: true, text: "two"), .init(isUser: false, text: "ok"), .init(isUser: true, text: "three")]))
        let o = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let msgs = try #require(o["messages"] as? [[String: String]])
        #expect(msgs.map { $0["role"] ?? "" } == ["system", "user", "assistant", "user"], Comment(rawValue: "\(msgs)"))
        #expect(msgs[1]["content"] == "one\ntwo")
    }

    @Test func aBodyNeedsAFinalUserMessage() throws {
        #expect(ProviderWire.chatBody(try provider("openai"), model: "m", system: "s", messages: []) == nil)
        #expect(ProviderWire.chatBody(try provider("openai"), model: "m", system: "s", messages: [.init(isUser: true, text: "a"), .init(isUser: false, text: "b")]) == nil)
    }

    @Test func openAIStreamChunksAreRead() throws {
        let p = try provider("openai")
        #expect(ProviderWire.chunk(p, line: #"data: {"choices":[{"delta":{"content":"Hel"},"finish_reason":null}]}"#) == .init(text: "Hel"))
        #expect(ProviderWire.chunk(p, line: #"data: {"choices":[{"delta":{"role":"assistant"},"finish_reason":null}]}"#) == .init(text: ""))
        #expect(ProviderWire.chunk(p, line: #"data: {"choices":[{"delta":{},"finish_reason":"stop"}]}"#)?.done == true)
        #expect(ProviderWire.chunk(p, line: "data: [DONE]") == .init(done: true))
        #expect(ProviderWire.chunk(p, line: ": keep-alive") == nil)
        #expect(ProviderWire.chunk(p, line: "data: not json") == nil)
        #expect(ProviderWire.chunk(p, line: #"data: {"choices":[]}"#) == nil)
    }

    @Test func anthropicStreamChunksAreRead() throws {
        let p = try provider("anthropic")
        #expect(ProviderWire.chunk(p, line: #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}"#) == .init(text: "Hi"))
        #expect(ProviderWire.chunk(p, line: #"data: {"type":"message_stop"}"#) == .init(done: true))
        #expect(ProviderWire.chunk(p, line: #"data: {"type":"message_start","message":{}}"#) == nil)
        #expect(ProviderWire.chunk(p, line: #"data: {"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"{"}}"#) == nil)
        #expect(ProviderWire.chunk(p, line: "event: message_stop") == nil)
    }

    @Test func providerErrorsInTheStreamAreShortAndKeyFree() throws {
        let c = try #require(ProviderWire.chunk(try provider("openai"), line: #"data: {"error":{"message":"Incorrect API key provided: sk-abc","type":"invalid_request_error"}}"#))
        #expect(c.done && c.error?.hasPrefix("Incorrect API key") == true)
        let a = try #require(ProviderWire.chunk(try provider("anthropic"), line: #"data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}"#))
        #expect(a.done && a.error == "Overloaded")
    }

    @Test func modelListsKeepChatModelsOnly() throws {
        let data = Data(#"{"data":[{"id":"gpt-4.1"},{"id":"text-embedding-3-small"},{"id":"whisper-1"},{"id":"gpt-4o"},{"id":"dall-e-3"},{"id":"gpt-4.1"},{"id":"omni-moderation-latest"}]}"#.utf8)
        let ids = ProviderWire.modelIDs(try provider("openai"), data: data)
        #expect(ids == ["gpt-4o", "gpt-4.1"], Comment(rawValue: "\(ids)"))
        let google = Data(#"{"models":[{"name":"models/gemini-2.5-flash"},{"name":"models/text-embedding-004"}]}"#.utf8)
        #expect(ProviderWire.modelIDs(try provider("google"), data: google) == ["gemini-2.5-flash"])
        #expect(ProviderWire.modelIDs(try provider("openai"), data: Data("nope".utf8)).isEmpty)
    }

    @Test func problemsAreSentencesWithoutSecrets() throws {
        let p = try provider("openai")
        #expect(ProviderWire.problem(status: 401, provider: p).contains("did not accept this key"))
        #expect(ProviderWire.problem(status: 402, provider: p).contains("no credit"))
        #expect(ProviderWire.problem(status: 429, provider: p).contains("too many requests"))
        #expect(ProviderWire.problem(status: 503, provider: p).contains("trouble"))
        #expect(ProviderWire.problem(status: 418, provider: p) == "OpenAI (ChatGPT) answered with status 418.")
    }
}
