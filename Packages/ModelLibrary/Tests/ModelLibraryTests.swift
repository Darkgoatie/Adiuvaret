import Testing
import Foundation
@testable import ModelLibrary

@Suite struct ModelLibraryTests {
    @Test func catalogHasTheEightRequestedModels() {
        let ids = Set(ModelCatalog.all.map(\.id))
        #expect(ids.count == 8 && ModelCatalog.all.count == 8)
        for id in ["mlx-community/Qwen3-4B-Instruct-2507-4bit", "mlx-community/Qwen3-1.7B-4bit", "mlx-community/gemma-3-4b-it-4bit",
                   "mlx-community/gemma-3-1b-it-4bit", "mlx-community/Llama-3.2-3B-Instruct-4bit", "mlx-community/SmolLM3-3B-4bit",
                   "mlx-community/gemma-4-e2b-it-4bit", "mlx-community/gemma-4-e4b-it-4bit"] {
            #expect(ids.contains(id), "\(id) missing")
        }
        #expect(ModelCatalog.all.allSatisfy { $0.id.hasPrefix("mlx-community/") && $0.sizeBytes > 0 })
    }

    @Test func catalogIsSortedSmallestFirst() {
        let sizes = ModelCatalog.all.map(\.sizeBytes)
        #expect(sizes == sizes.sorted())
    }

    @Test func gemmaAndLlamaShowALicenseNotice() {
        for m in ModelCatalog.all {
            #expect(m.needsLicenseNotice == (m.family == "Gemma" || m.family == "Llama"), "\(m.name)")
        }
    }

    @Test func choicesListBuiltInFirstThenInstalledInCatalogOrder() {
        let installed: Set = ["mlx-community/Qwen3-4B-Instruct-2507-4bit", "mlx-community/gemma-3-1b-it-4bit", "mlx-community/not-in-catalog"]
        #expect(ModelCatalog.choices(installed: installed).map(\.name) == ["Apple", "Gemma 3 1B", "Qwen3 4B Instruct"])
        #expect(ModelCatalog.choices(installed: []).map(\.id) == ["apple"])
    }

    @Test func withoutAppleIntelligenceTheMenuAndFallbackSkipIt() {
        let a = "mlx-community/Qwen3-1.7B-4bit", b = "mlx-community/gemma-3-1b-it-4bit"
        #expect(ModelCatalog.choices(installed: [], appleAvailable: false).isEmpty)
        #expect(ModelCatalog.choices(installed: [a, b], appleAvailable: false).map(\.id) == [b, a])
        #expect(ModelCatalog.resolve(active: nil, installed: [], appleAvailable: false) == ModelCatalog.noModelID)
        #expect(ModelCatalog.resolve(active: "apple", installed: [], appleAvailable: false) == ModelCatalog.noModelID)
        #expect(ModelCatalog.resolve(active: "apple", installed: [a, b], appleAvailable: false) == b)
        #expect(ModelCatalog.resolve(active: a, installed: [a, b], appleAvailable: false) == a)
        #expect(ModelCatalog.resolve(active: "openai:gpt-4.1", installed: [], connected: ["openai"], appleAvailable: false) == "openai:gpt-4.1")
        #expect(ModelCatalog.resolve(active: "openai:gpt-4.1", installed: [], connected: [], appleAvailable: false) == ModelCatalog.noModelID)
        #expect(ModelCatalog.resolve(active: "apple", installed: [], appleAvailable: true) == "apple")
    }

    @Test func resolveFallsBackToAppleWhenTheModelIsGone() {
        let q = "mlx-community/Qwen3-1.7B-4bit"
        #expect(ModelCatalog.resolve(active: q, installed: [q]) == q)
        #expect(ModelCatalog.resolve(active: q, installed: []) == "apple")
        #expect(ModelCatalog.resolve(active: nil, installed: [q]) == "apple")
        #expect(ModelCatalog.resolve(active: "mlx-community/unknown", installed: ["mlx-community/unknown"]) == "apple")
        #expect(ModelCatalog.resolve(active: "apple", installed: [q]) == "apple")
        #expect(ModelCatalog.resolve(active: "openai:gpt-4.1", installed: [], connected: ["openai"]) == "openai:gpt-4.1")
        #expect(ModelCatalog.resolve(active: "openai:gpt-4.1", installed: [], connected: []) == "apple")
        #expect(ModelCatalog.resolve(active: "openai:gpt-4.1", installed: [], connected: ["anthropic"]) == "apple")
        #expect(ModelCatalog.resolve(active: "nope:gpt-4.1", installed: [], connected: ["nope"]) == "apple")
    }

    @Test func fitGrowsWithModelSize() {
        let budget: Int64 = 6_000_000_000
        #expect(ModelFit.evaluate(weightsBytes: 730_000_000, budgetBytes: budget) == .fits)
        #expect(ModelFit.evaluate(weightsBytes: 3_550_000_000, budgetBytes: budget) == .fits)
        #expect(ModelFit.evaluate(weightsBytes: 4_200_000_000, budgetBytes: budget) == .tight)
        #expect(ModelFit.evaluate(weightsBytes: 5_150_000_000, budgetBytes: budget) == .tooBig)
        #expect(ModelFit.required(forWeights: 1_000_000_000) == 1_650_000_000)
    }

    @Test func thinkFilterRemovesReasoningBlocks() {
        #expect(ThinkFilter.visible("<think>let me see</think>\n\nTuesday is free.") == "Tuesday is free.")
        #expect(ThinkFilter.visible("Before <think>x</think>after") == "Before after")
        #expect(ThinkFilter.visible("<think>\n\n</think>\n\nHi") == "Hi")
    }

    @Test func thinkFilterHidesUnfinishedAndPartialTags() {
        #expect(ThinkFilter.visible("<think>still thinking") == "")
        #expect(ThinkFilter.visible("Answer: <th") == "Answer:")
        #expect(ThinkFilter.visible("Answer <") == "Answer")
        #expect(ThinkFilter.visible("a < b is true") == "a < b is true")
    }

    @Test func thinkFilterHandlesAClosingTagWithoutAnOpeningOne() {
        #expect(ThinkFilter.visible("I should check the date.</think>It is Friday.") == "It is Friday.")
    }

    @Test func plainTextPassesThrough() {
        #expect(ThinkFilter.visible("  Hello there  ") == "Hello there")
    }
}
