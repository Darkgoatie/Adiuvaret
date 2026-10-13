import Foundation

/// Builds requests for a provider and reads its answers. Pure logic: the app sends the requests and attaches the key.
public enum ProviderWire {
    /// An image sent with a user message, already resized and encoded.
    public struct Image: Sendable, Equatable {
        public let mediaType: String
        public let base64: String
        public init(mediaType: String, base64: String) { self.mediaType = mediaType; self.base64 = base64 }
    }

    public struct Message: Sendable, Equatable {
        public let isUser: Bool
        public let text: String
        public let images: [Image]
        public init(isUser: Bool, text: String, images: [Image] = []) { self.isUser = isUser; self.text = text; self.images = images }
    }

    public static func url(_ provider: Provider, path: String) -> URL? {
        URL(string: "https://\(provider.host)\(provider.basePath)\(path)")
    }

    /// Headers for a provider. The key is passed in here, at send time, and never stored in a request that is kept.
    public static func headers(_ provider: Provider, key: String) -> [String: String] {
        switch provider.api {
        case .openAICompatible: ["Authorization": "Bearer " + key, "Content-Type": "application/json", "Accept": "application/json"]
        case .anthropic: ["x-api-key": key, "anthropic-version": "2023-06-01", "Content-Type": "application/json", "Accept": "application/json"]
        }
    }

    /// A streaming chat request body. History must alternate user, assistant and end with the new user message.
    public static func chatBody(_ provider: Provider, model: String, system: String, messages: [Message], maxTokens: Int = 2048) -> Data? {
        let turns = alternating(messages)
        guard turns.last?.isUser == true else { return nil }
        let list: [[String: Any]] = turns.map { m in
            let role = m.isUser ? "user" : "assistant"
            guard m.isUser, !m.images.isEmpty else { return ["role": role, "content": m.text] }
            switch provider.api {
            case .openAICompatible:
                var parts: [[String: Any]] = [["type": "text", "text": m.text]]
                for i in m.images { parts.append(["type": "image_url", "image_url": ["url": "data:\(i.mediaType);base64,\(i.base64)"]]) }
                return ["role": role, "content": parts]
            case .anthropic:
                var parts: [[String: Any]] = m.images.map { ["type": "image", "source": ["type": "base64", "media_type": $0.mediaType, "data": $0.base64]] }
                parts.append(["type": "text", "text": m.text])
                return ["role": role, "content": parts]
            }
        }
        var body: [String: Any]
        switch provider.api {
        case .openAICompatible:
            body = ["model": model, "stream": true, "messages": [["role": "system", "content": system] as [String: Any]] + list]
            body["max_tokens"] = maxTokens
        case .anthropic:
            body = ["model": model, "stream": true, "max_tokens": maxTokens, "system": system, "messages": list]
        }
        return try? JSONSerialization.data(withJSONObject: body)
    }

    public static func chatURL(_ provider: Provider) -> URL? {
        url(provider, path: provider.api == .anthropic ? "/messages" : "/chat/completions")
    }

    public static func modelsURL(_ provider: Provider) -> URL? { url(provider, path: "/models") }

    /// Every provider needs a strict user, assistant, user order. Neighbours from the same side are merged and a leading assistant message is dropped.
    static func alternating(_ messages: [Message]) -> [Message] {
        var out: [Message] = []
        for m in messages where !m.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !m.images.isEmpty {
            if out.isEmpty && !m.isUser { continue }
            if let last = out.last, last.isUser == m.isUser { out[out.count - 1] = Message(isUser: m.isUser, text: last.text + "\n" + m.text, images: last.images + m.images) } else { out.append(m) }
        }
        return out
    }

    // MARK: streaming

    /// The text added by one server-sent-events line, or nil when the line carries none. `done` is true at the end of the stream.
    public struct Chunk: Sendable, Equatable {
        public var text: String
        public var done: Bool
        public var error: String?
        public init(text: String = "", done: Bool = false, error: String? = nil) { self.text = text; self.done = done; self.error = error }
    }

    public static func chunk(_ provider: Provider, line: String) -> Chunk? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return Chunk(done: true) }
        guard let data = payload.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = o["error"] as? [String: Any] { return Chunk(done: true, error: (err["message"] as? String).map { String($0.prefix(160)) } ?? "The provider reported an error.") }
        switch provider.api {
        case .openAICompatible:
            guard let choice = (o["choices"] as? [[String: Any]])?.first else { return nil }
            let delta = choice["delta"] as? [String: Any]
            let text = (delta?["content"] as? String) ?? ""
            let finished = (choice["finish_reason"] as? String).map { !$0.isEmpty } ?? false
            return Chunk(text: text, done: finished && text.isEmpty)
        case .anthropic:
            switch o["type"] as? String {
            case "content_block_delta":
                if let d = o["delta"] as? [String: Any], (d["type"] as? String) == "text_delta", let t = d["text"] as? String { return Chunk(text: t) }
                return nil
            case "message_stop": return Chunk(done: true)
            case "error": return Chunk(done: true, error: ((o["error"] as? [String: Any])?["message"] as? String).map { String($0.prefix(160)) } ?? "The provider reported an error.")
            default: return nil
            }
        }
    }

    // MARK: models

    /// Model ids from a provider's model list, chat models first. Filters out embeddings, audio, image and moderation models.
    public static func modelIDs(_ provider: Provider, data: Data) -> [String] {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let raw: [String] = ((o["data"] as? [[String: Any]]) ?? (o["models"] as? [[String: Any]]) ?? []).compactMap { m in
            guard var id = (m["id"] as? String) ?? (m["name"] as? String) else { return nil }
            if id.hasPrefix("models/") { id = String(id.dropFirst(7)) }
            return id
        }
        let skip = ["embed", "whisper", "tts", "dall-e", "image", "moderation", "audio", "transcribe", "realtime", "search-preview", "vision-preview", "imagen", "veo", "rerank", "ocr", "guard", "babbage", "davinci", "robotics", "live", "aqa"]
        let chat = raw.filter { id in !skip.contains(where: { id.lowercased().contains($0) }) }
        var seen = Set<String>()
        return chat.filter { seen.insert($0).inserted }.sorted { $0 > $1 }.prefix(60).map { $0 }
    }

    // MARK: errors

    /// A sentence for the user. Never includes the key or the response body.
    public static func problem(status: Int, provider: Provider) -> String {
        switch status {
        case 401, 403: "\(provider.name) did not accept this key. Check that it is copied completely and still active."
        case 402: "\(provider.name) says the account has no credit. Add credit on the provider's page."
        case 404: "\(provider.name) does not know this model. Pick another one."
        case 429: "\(provider.name) says there are too many requests, or the quota is used up. Try again later."
        case 400: "\(provider.name) refused the request. The model name may be wrong."
        case 500...599: "\(provider.name) is having trouble. Try again in a moment."
        default: "\(provider.name) answered with status \(status)."
        }
    }

    // MARK: tool calling

    /// A streamed piece with tool-call fragments. The plain `chunk` keeps working for chats without tools.
    public struct Delta: Sendable, Equatable {
        public struct Fragment: Sendable, Equatable {
            public let index: Int
            public let id: String?
            public let name: String?
            public let arguments: String?
            public init(index: Int, id: String? = nil, name: String? = nil, arguments: String? = nil) { self.index = index; self.id = id; self.name = name; self.arguments = arguments }
        }
        public var text: String
        public var toolFragments: [Fragment]
        public var toolStop: Bool
        public var done: Bool
        public var error: String?
        public init(text: String = "", toolFragments: [Fragment] = [], toolStop: Bool = false, done: Bool = false, error: String? = nil) {
            self.text = text; self.toolFragments = toolFragments; self.toolStop = toolStop; self.done = done; self.error = error
        }
    }

    public static func delta(_ provider: Provider, line: String) -> Delta? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return Delta(done: true) }
        guard let data = payload.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let err = o["error"] as? [String: Any] { return Delta(done: true, error: (err["message"] as? String).map { String($0.prefix(160)) } ?? "The provider reported an error.") }
        switch provider.api {
        case .openAICompatible:
            guard let choice = (o["choices"] as? [[String: Any]])?.first else { return nil }
            let d = choice["delta"] as? [String: Any]
            var out = Delta(text: (d?["content"] as? String) ?? "")
            for (n, t) in ((d?["tool_calls"] as? [[String: Any]]) ?? []).enumerated() {
                let fn = t["function"] as? [String: Any]
                out.toolFragments.append(.init(index: (t["index"] as? Int) ?? n, id: t["id"] as? String, name: fn?["name"] as? String, arguments: fn?["arguments"] as? String))
            }
            let reason = (choice["finish_reason"] as? String) ?? ""
            if reason == "tool_calls" || reason == "function_call" { out.toolStop = true }
            if !reason.isEmpty && out.text.isEmpty && out.toolFragments.isEmpty { out.done = true }
            return out
        case .anthropic:
            switch o["type"] as? String {
            case "content_block_start":
                if let b = o["content_block"] as? [String: Any], (b["type"] as? String) == "tool_use" {
                    return Delta(toolFragments: [.init(index: (o["index"] as? Int) ?? 0, id: b["id"] as? String, name: b["name"] as? String)])
                }
                return nil
            case "content_block_delta":
                guard let d = o["delta"] as? [String: Any] else { return nil }
                switch d["type"] as? String {
                case "text_delta": return Delta(text: (d["text"] as? String) ?? "")
                case "input_json_delta": return Delta(toolFragments: [.init(index: (o["index"] as? Int) ?? 0, arguments: d["partial_json"] as? String)])
                default: return nil
                }
            case "message_delta":
                if let d = o["delta"] as? [String: Any], (d["stop_reason"] as? String) == "tool_use" { return Delta(toolStop: true) }
                return nil
            case "message_stop": return Delta(done: true)
            case "error": return Delta(done: true, error: ((o["error"] as? [String: Any])?["message"] as? String).map { String($0.prefix(160)) } ?? "The provider reported an error.")
            default: return nil
            }
        }
    }

    /// A streaming request with tools. Turns carry tool calls and results in the provider's own shape.
    public static func toolBody(_ provider: Provider, model: String, system: String, turns: [WireTurn], tools: [WireTool], maxTokens: Int = 2048) -> Data? {
        switch turns.last {
        case .user?, .toolResults?: break
        default: return nil
        }
        let schemas: [[String: Any]] = tools.compactMap { t in
            guard let d = t.schemaJSON.data(using: .utf8), let schema = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
            switch provider.api {
            case .openAICompatible: return ["type": "function", "function": ["name": t.name, "description": t.description, "parameters": schema] as [String: Any]]
            case .anthropic: return ["name": t.name, "description": t.description, "input_schema": schema]
            }
        }
        var list: [[String: Any]] = []
        for turn in turns {
            switch (turn, provider.api) {
            case (.user(let text, let images), .openAICompatible):
                if images.isEmpty { list.append(["role": "user", "content": text]) } else {
                    var parts: [[String: Any]] = [["type": "text", "text": text]]
                    for i in images { parts.append(["type": "image_url", "image_url": ["url": "data:\(i.mediaType);base64,\(i.base64)"]]) }
                    list.append(["role": "user", "content": parts])
                }
            case (.user(let text, let images), .anthropic):
                if images.isEmpty { list.append(["role": "user", "content": text]) } else {
                    var parts: [[String: Any]] = images.map { ["type": "image", "source": ["type": "base64", "media_type": $0.mediaType, "data": $0.base64]] }
                    parts.append(["type": "text", "text": text])
                    list.append(["role": "user", "content": parts])
                }
            case (.assistant(let text, let calls), .openAICompatible):
                var m: [String: Any] = ["role": "assistant", "content": text.isEmpty ? NSNull() : text]
                if !calls.isEmpty { m["tool_calls"] = calls.map { ["id": $0.id, "type": "function", "function": ["name": $0.name, "arguments": $0.argumentsJSON]] as [String: Any] } }
                list.append(m)
            case (.assistant(let text, let calls), .anthropic):
                var parts: [[String: Any]] = text.isEmpty ? [] : [["type": "text", "text": text]]
                for c in calls {
                    let input = (c.argumentsJSON.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) }) ?? [String: Any]()
                    parts.append(["type": "tool_use", "id": c.id, "name": c.name, "input": input])
                }
                list.append(["role": "assistant", "content": parts])
            case (.toolResults(let results), .openAICompatible):
                for r in results { list.append(["role": "tool", "tool_call_id": r.callID, "content": r.output]) }
            case (.toolResults(let results), .anthropic):
                list.append(["role": "user", "content": results.map { ["type": "tool_result", "tool_use_id": $0.callID, "content": $0.output] as [String: Any] }])
            }
        }
        var body: [String: Any]
        switch provider.api {
        case .openAICompatible:
            body = ["model": model, "stream": true, "max_tokens": maxTokens, "messages": [["role": "system", "content": system] as [String: Any]] + list]
        case .anthropic:
            body = ["model": model, "stream": true, "max_tokens": maxTokens, "system": system, "messages": list]
        }
        if !schemas.isEmpty { body["tools"] = schemas }
        return try? JSONSerialization.data(withJSONObject: body)
    }

    /// Turns the app's saved messages into wire turns: strict user/assistant order, as the plain path requires.
    public static func turns(from messages: [Message]) -> [WireTurn] {
        alternating(messages).map { $0.isUser ? .user($0.text, images: $0.images) : .assistant(text: $0.text, calls: []) }
    }
}
