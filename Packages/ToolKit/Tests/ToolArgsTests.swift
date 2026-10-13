import Testing
import Foundation
@testable import ToolKit

@Suite struct ToolArgsTests {
    @Test func jsonValuesAreReadAsTextNumbersAndFlags() throws {
        let a = try #require(ToolArgs(json: #"{"query":"seville hotel","days":7,"ratio":2.5,"readText":true,"off":false,"count":"3"}"#))
        #expect(a.string("query") == "seville hotel")
        #expect(a.int("days") == 7 && a.int("count") == 3)
        #expect(a.int("ratio") == 2)
        #expect(a.bool("readText") && !a.bool("off") && !a.bool("missing"))
        #expect(a.string("missing") == "" && a.int("missing") == 0)
    }

    @Test func numbersAndTextCrossOver() throws {
        let a = try #require(ToolArgs(json: #"{"id":42,"flag":"true","n":"  5 "}"#))
        #expect(a.string("id") == "42")
        #expect(a.bool("flag"))
        #expect(a.int("n") == 5)
    }

    @Test func badJsonAndNestedValuesAreHandled() {
        #expect(ToolArgs(json: "not json") == nil)
        #expect(ToolArgs(json: "[1,2]") == nil)
        #expect(ToolArgs(json: "{}")?.asDictionary == [:])
        #expect(ToolArgs(json: #"{"a":{"b":1},"c":"x"}"#)?.asDictionary == ["c": "x"])
    }

    @Test func schemaListsEveryParameterAsRequired() throws {
        let json = ToolSchema.json([.string("query", "Words to look for"), .int("days", "How many days"), .bool("readText"), .choice("action", "What to do", ["click", "type"])])
        let o = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(o["type"] as? String == "object" && o["additionalProperties"] as? Bool == false)
        #expect(Set(o["required"] as? [String] ?? []) == ["query", "days", "readText", "action"])
        let p = try #require(o["properties"] as? [String: [String: Any]])
        #expect(p["query"]?["type"] as? String == "string" && p["query"]?["description"] as? String == "Words to look for")
        #expect(p["days"]?["type"] as? String == "integer")
        #expect(p["readText"]?["type"] as? String == "boolean" && p["readText"]?["description"] == nil)
        #expect(p["action"]?["enum"] as? [String] == ["click", "type"])
    }

    @Test func aToolWithoutParametersStillHasAnObjectSchema() throws {
        let o = try #require(JSONSerialization.jsonObject(with: Data(ToolSchema.json([]).utf8)) as? [String: Any])
        #expect(o["type"] as? String == "object" && (o["properties"] as? [String: Any])?.isEmpty == true)
    }

    @Test func everyManifestToolHasAUsableSchema() throws {
        for m in ConnectorRegistry.manifests {
            for t in m.tools {
                let params = t.toolParams
                #expect(!params.isEmpty, Comment(rawValue: t.name))
                let o = try #require(JSONSerialization.jsonObject(with: Data(ToolSchema.json(params).utf8)) as? [String: Any], Comment(rawValue: t.name))
                #expect((o["properties"] as? [String: Any])?.count == params.count, Comment(rawValue: t.name))
                if !t.arguments.isEmpty { #expect(!params.contains { $0.name == "unused" }, Comment(rawValue: t.name)) }
            }
        }
    }
}
