import Testing
import Foundation
@testable import ModelLibrary

struct ContextMeterTests {
    @Test func tokensAreAboutAQuarterOfTheCharacters() {
        #expect(ContextMeter.estimateTokens("") == 0)
        #expect(ContextMeter.estimateTokens("abcd") == 1)
        #expect(ContextMeter.estimateTokens("abcde") == 2)
        #expect(ContextMeter.estimateTokens(String(repeating: "a", count: 400)) == 100)
    }

    @Test func fractionIsClamped() {
        #expect(ContextMeter.fraction(used: 0, window: 8192) == 0)
        #expect(ContextMeter.fraction(used: 4096, window: 8192) == 0.5)
        #expect(ContextMeter.fraction(used: 9000, window: 8192) == 1)
        #expect(ContextMeter.fraction(used: -5, window: 8192) == 0)
        #expect(ContextMeter.fraction(used: 10, window: 0) == 0)
        #expect(ContextMeter.percentText(0.256) == "26%")
    }

    @Test func windowDependsOnWhereTheModelRuns() {
        #expect(ContextMeter.window(for: ModelCatalog.appleID) == 8_192)
        #expect(ContextMeter.window(for: "mlx-community/gemma-3-1b-it-4bit") == 8_192)
        let online = Providers.all.first.map { "\($0.id):some-model" } ?? ""
        #expect(ContextMeter.window(for: online) == 128_000)
    }

    @Test func speedNeedsALongEnoughReply() {
        #expect(ContextMeter.tokensPerSecond(characters: 5, seconds: 2) == nil)
        #expect(ContextMeter.tokensPerSecond(characters: 400, seconds: 0.1) == nil)
        #expect(ContextMeter.tokensPerSecond(characters: 400, seconds: 5) == 20)
        #expect(ContextMeter.rateText(20) == "20.0")
        #expect(ContextMeter.rateText(143.7) == "144")
    }
}
