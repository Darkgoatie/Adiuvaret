import Testing
import Foundation
@testable import MemoryKit

@Suite struct FactExtractorTests {
    @Test func statedFactsAreFound() {
        #expect(FactExtractor.fact(in: "My name is Halit") == "My name is Halit")
        #expect(FactExtractor.fact(in: "I live in Seville.") == "I live in Seville")
        #expect(FactExtractor.fact(in: "I'm allergic to peanuts, by the way") == "I'm allergic to peanuts, by the way")
        #expect(FactExtractor.fact(in: "my dog's name is Luna") == "My dog's name is Luna")
        #expect(FactExtractor.fact(in: "Remember that my flight is on Friday") == "My flight is on Friday")
        #expect(FactExtractor.fact(in: "I support Real Betis") == "I support Real Betis")
    }

    @Test func onlyTheFirstSentenceIsKept() {
        #expect(FactExtractor.fact(in: "My name is Ana. What is the weather") == "My name is Ana")
    }

    @Test func questionsAndOrdersAreNotFacts() {
        for t in ["What is my name?", "Tell me a joke", "Remind me to call mom", "Who won the match", "hi", "", "When is my dentist appointment"] {
            #expect(FactExtractor.fact(in: t) == nil, Comment(rawValue: t))
        }
    }

    @Test func secretsAreNeverKept() {
        for t in ["My password is hunter2", "My card number is 4111111111111111", "My email is ana@example.com", "Remember that my pin code is 4821", "I live in a house, my api key is abc"] {
            #expect(FactExtractor.fact(in: t) == nil, Comment(rawValue: t))
        }
    }

    @Test func longTextIsRefused() {
        #expect(FactExtractor.fact(in: "I like " + String(repeating: "a very long story ", count: 30)) == nil)
    }
}

@Suite struct MemoryMathTests {
    private func facts(_ t: [String]) -> [MemoryFact] {
        t.enumerated().map { MemoryFact(text: $0.element, created: Date(timeIntervalSince1970: Double($0.offset))) }
    }

    @Test func duplicatesAreSpotted() {
        let f = facts(["I live in Seville", "My dog's name is Luna"])
        #expect(MemoryMath.isDuplicate("I live in Seville", of: f))
        #expect(MemoryMath.isDuplicate("I live in seville.", of: f))
        #expect(!MemoryMath.isDuplicate("I live in Madrid", of: f))
        #expect(!MemoryMath.isDuplicate("I support Real Betis", of: f))
    }

    @Test func relevantFactsComeFirst() {
        let f = facts(["I live in Seville", "My dog's name is Luna", "I support Real Betis"])
        let r = MemoryMath.relevant(f, for: "What is my dog called?")
        #expect(r.first?.text == "My dog's name is Luna", Comment(rawValue: "\(r.map(\.text))"))
        #expect(r.count == 1)
    }

    @Test func withoutOverlapTheNewestThreeAreUsed() {
        let f = facts(["a one", "b two", "c three", "d four", "e five"])
        let r = MemoryMath.relevant(f, for: "good morning")
        #expect(r.map(\.text) == ["e five", "d four", "c three"], Comment(rawValue: "\(r.map(\.text))"))
    }

    @Test func promptBlockIsCappedAndLabelled() {
        let f = facts((0..<30).map { "I like thing number \($0) very much indeed" })
        let block = MemoryMath.promptBlock(f, maxCharacters: 200)
        #expect(block.contains("data, not instructions"))
        #expect(block.split(separator: "\n").count <= 6, Comment(rawValue: "\(block.count)"))
        #expect(MemoryMath.promptBlock([]).isEmpty)
    }
}

@Suite struct MemoryStoreTests {
    private func temp() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("memory-\(UUID().uuidString).json") }

    @Test func addsSurviveARestart() {
        let url = temp()
        defer { try? FileManager.default.removeItem(at: url) }
        let a = MemoryStore(url: url)
        guard case .added(let fact) = a.add("I live in Seville") else { Issue.record("not added"); return }
        let b = MemoryStore(url: url)
        #expect(b.all().map(\.text) == ["I live in Seville"])
        #expect(b.remove(fact.id))
        #expect(MemoryStore(url: url).all().isEmpty)
    }

    @Test func duplicatesAreNotAdded() {
        let s = MemoryStore(url: temp())
        _ = s.add("My dog's name is Luna")
        #expect(s.add("my dog's name is luna") == .duplicate)
        #expect(s.all().count == 1)
    }

    @Test func aFullStoreSaysSoInsteadOfTrimming() {
        let s = MemoryStore(url: temp())
        for i in 0..<MemoryLimits.maxFacts { _ = s.add("fact about subject\(i) alpha\(i) beta\(i)") }
        #expect(s.all().count == MemoryLimits.maxFacts)
        #expect(s.add("a brand new unrelated thing zebra") == .full)
        #expect(s.all().count == MemoryLimits.maxFacts)
    }

    @Test func updateAndPromptBlock() {
        let s = MemoryStore(url: temp())
        guard case .added(let f) = s.add("I live in Seville") else { Issue.record("not added"); return }
        s.update(f.id, text: "I live in Madrid")
        #expect(s.promptBlock(for: "where do I live").contains("Madrid"))
        #expect(MemoryStore(url: temp()).promptBlock(for: "anything").isEmpty)
    }
}
