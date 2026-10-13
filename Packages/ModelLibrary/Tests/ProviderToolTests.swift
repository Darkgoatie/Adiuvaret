import Testing
import Foundation
@testable import ModelLibrary

@Suite struct ProviderToolTests {
    private func provider(_ id: String) throws -> Provider { try #require(Providers.all.first { $0.id == id }) }

    private let schema = #"{"type":"object","properties":{"query":{"type":"string","description":"words"}},"required":["query"],"additionalProperties":false}"#
    private var tool: WireTool { WireTool(name: "searchWeb", description: "Searches the web.", schemaJSON: schema) }

    private func json(_ data: Data?) throws -> [String: Any] {
        let raw = try #require(data)
        return try #require(JSONSerialization.jsonObject(with: raw) as? [String: Any])
    }

    @Test func openAIBodyCarriesToolsAndToolResults() throws {
        let turns: [WireTurn] = [
            .user("weather in Seville", images: []),
            .assistant(text: "", calls: [WireCall(id: "call_1", name: "searchWeb", argumentsJSON: #"{"query":"Seville weather"}"#)]),
            .toolResults([.init(callID: "call_1", name: "searchWeb", output: "Sunny, 31 C")]),
        ]
        let body = try json(ProviderWire.toolBody(try provider("openai"), model: "gpt-4.1", system: "s", turns: turns, tools: [tool]))
        let tools = try #require(body["tools"] as? [[String: Any]])
        #expect(tools.count == 1 && (tools[0]["type"] as? String) == "function")
        let fn = try #require(tools[0]["function"] as? [String: Any])
        #expect((fn["name"] as? String) == "searchWeb" && fn["parameters"] != nil)
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["system", "user", "assistant", "tool"])
        let calls = try #require(messages[2]["tool_calls"] as? [[String: Any]])
        #expect((calls[0]["id"] as? String) == "call_1")
        #expect(((calls[0]["function"] as? [String: Any])?["arguments"] as? String) == #"{"query":"Seville weather"}"#)
        #expect((messages[3]["tool_call_id"] as? String) == "call_1" && (messages[3]["content"] as? String) == "Sunny, 31 C")
    }

    @Test func anthropicBodyUsesToolUseAndToolResultBlocks() throws {
        let turns: [WireTurn] = [
            .user("weather in Seville", images: []),
            .assistant(text: "Checking.", calls: [WireCall(id: "toolu_1", name: "searchWeb", argumentsJSON: #"{"query":"Seville weather"}"#)]),
            .toolResults([.init(callID: "toolu_1", name: "searchWeb", output: "Sunny, 31 C")]),
        ]
        let body = try json(ProviderWire.toolBody(try provider("anthropic"), model: "claude-sonnet-4-5", system: "sys", turns: turns, tools: [tool]))
        #expect((body["system"] as? String) == "sys")
        let tools = try #require(body["tools"] as? [[String: Any]])
        #expect((tools[0]["name"] as? String) == "searchWeb" && tools[0]["input_schema"] != nil)
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.map { $0["role"] as? String } == ["user", "assistant", "user"])
        let blocks = try #require(messages[1]["content"] as? [[String: Any]])
        #expect(blocks.map { $0["type"] as? String } == ["text", "tool_use"])
        #expect(((blocks[1]["input"] as? [String: Any])?["query"] as? String) == "Seville weather")
        let results = try #require(messages[2]["content"] as? [[String: Any]])
        #expect((results[0]["type"] as? String) == "tool_result" && (results[0]["tool_use_id"] as? String) == "toolu_1")
    }

    @Test func bodyNeedsToEndOnAUserOrToolTurn() throws {
        #expect(ProviderWire.toolBody(try provider("openai"), model: "m", system: "s", turns: [.user("hi", images: []), .assistant(text: "yo", calls: [])], tools: [tool]) == nil)
        #expect(ProviderWire.toolBody(try provider("openai"), model: "m", system: "s", turns: [], tools: [tool]) == nil)
    }

    @Test func noToolsMeansNoToolsKey() throws {
        let body = try json(ProviderWire.toolBody(try provider("openai"), model: "m", system: "s", turns: [.user("hi", images: [])], tools: []))
        #expect(body["tools"] == nil)
    }

    @Test func openAIStreamBuildsACompleteCallFromFragments() throws {
        let p = try provider("openai")
        let lines = [
            #"data: {"choices":[{"index":0,"delta":{"role":"assistant","content":null,"tool_calls":[{"index":0,"id":"call_9","type":"function","function":{"name":"searchWeb","arguments":""}}]}}]}"#,
            #"data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{\"que"}}]}}]}"#,
            #"data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"ry\":\"Betis\"}"}}]}}]}"#,
            #"data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}"#,
            "data: [DONE]",
        ]
        var acc = WireAccumulator()
        for l in lines { if let d = ProviderWire.delta(p, line: l) { acc.add(d) } }
        #expect(acc.finishedForTools)
        #expect(acc.calls == [WireCall(id: "call_9", name: "searchWeb", argumentsJSON: #"{"query":"Betis"}"#)])
        #expect(acc.text.isEmpty)
    }

    @Test func openAIStreamKeepsTextAndTwoParallelCalls() throws {
        let p = try provider("openai")
        let lines = [
            #"data: {"choices":[{"delta":{"content":"Let me look."}}]}"#,
            #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"a","function":{"name":"readCalendar","arguments":"{}"}},{"index":1,"id":"b","function":{"name":"listReminders","arguments":"{\"search\":\"\"}"}}]}}]}"#,
            #"data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}"#,
        ]
        var acc = WireAccumulator()
        for l in lines { if let d = ProviderWire.delta(p, line: l) { acc.add(d) } }
        #expect(acc.text == "Let me look.")
        #expect(acc.calls.map(\.name) == ["readCalendar", "listReminders"])
        #expect(acc.calls.map(\.id) == ["a", "b"])
    }

    @Test func anthropicStreamBuildsACallFromBlocks() throws {
        let p = try provider("anthropic")
        let lines = [
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"One moment."}}"#,
            #"data: {"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_7","name":"openWebsite","input":{}}}"#,
            #"data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":"{\"url\": \"apple"}}"#,
            #"data: {"type":"content_block_delta","index":1,"delta":{"type":"input_json_delta","partial_json":".com\"}"}}"#,
            #"data: {"type":"message_delta","delta":{"stop_reason":"tool_use"}}"#,
            #"data: {"type":"message_stop"}"#,
        ]
        var acc = WireAccumulator()
        for l in lines { if let d = ProviderWire.delta(p, line: l) { acc.add(d) } }
        #expect(acc.text == "One moment.")
        #expect(acc.finishedForTools)
        #expect(acc.calls == [WireCall(id: "toolu_7", name: "openWebsite", argumentsJSON: #"{"url": "apple.com"}"#)])
    }

    @Test func aCallWithNoArgumentsGetsAnEmptyObject() throws {
        var acc = WireAccumulator()
        acc.add(ProviderWire.Delta(toolFragments: [.init(index: 0, id: "x", name: "readCalendar")]))
        #expect(acc.calls.first?.argumentsJSON == "{}")
    }

    @Test func plainTextStreamsStillWork() throws {
        let p = try provider("openai")
        let d = try #require(ProviderWire.delta(p, line: #"data: {"choices":[{"delta":{"content":"Hello"}}]}"#))
        #expect(d.text == "Hello" && d.toolFragments.isEmpty && !d.toolStop)
        #expect(ProviderWire.delta(p, line: "data: [DONE]")?.done == true)
        #expect(ProviderWire.delta(p, line: ": keep-alive") == nil)
        let e = try #require(ProviderWire.delta(p, line: #"data: {"error":{"message":"bad key"}}"#))
        #expect(e.error == "bad key" && e.done)
    }

    @Test func turnsFromSavedMessagesStayInOrder() {
        let t = ProviderWire.turns(from: [.init(isUser: true, text: "a"), .init(isUser: true, text: "b"), .init(isUser: false, text: "c"), .init(isUser: true, text: "d")])
        #expect(t.count == 3)
        if case .user(let text, _) = t[0] { #expect(text == "a\nb") } else { Issue.record("first turn is not a user turn") }
    }
}
