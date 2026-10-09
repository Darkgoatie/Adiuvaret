import Testing
@testable import ModelLibrary

@Suite struct ChatAlternationTests {
    private func u(_ t: String) -> ChatAlternation.Turn { .init(isUser: true, text: t) }
    private func a(_ t: String) -> ChatAlternation.Turn { .init(isUser: false, text: t) }

    @Test func alreadyAlternatingHistoryIsKept() {
        let h = [u("hi"), a("hello"), u("time?"), a("noon")]
        #expect(ChatAlternation.normalize(h) == h)
    }

    @Test func aFailedReplyDoesNotBreakTheNextTurn() {
        let r = ChatAlternation.normalize([u("one"), a("ok"), u("two failed"), u("three")])
        #expect(r == [u("one"), a("ok")])
        #expect(ChatAlternation.alternates(r))
    }

    @Test func neighbouringUserMessagesAreMergedWhenAnAnswerFollows() {
        let r = ChatAlternation.normalize([u("a"), u("b"), a("answer")])
        #expect(r == [u("a\nb"), a("answer")])
    }

    @Test func neighbouringAssistantMessagesKeepTheLast() {
        #expect(ChatAlternation.normalize([u("a"), a("x"), a("y")]) == [u("a"), a("y")])
    }

    @Test func leadingAssistantAndEmptyMessagesAreDropped() {
        #expect(ChatAlternation.normalize([a("stray"), u(" "), u("a"), a("b")]) == [u("a"), a("b")])
        #expect(ChatAlternation.normalize([]).isEmpty)
        #expect(ChatAlternation.normalize([u("only")]).isEmpty)
    }

    @Test func resultAlwaysAlternatesForAnyMix() {
        var seed: UInt64 = 7
        for _ in 0..<200 {
            var turns: [ChatAlternation.Turn] = []
            for _ in 0..<Int.random(in: 0...12) {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                turns.append(.init(isUser: (seed >> 33) % 2 == 0, text: (seed >> 40) % 5 == 0 ? "" : "m\(seed % 100)"))
            }
            let r = ChatAlternation.normalize(turns)
            #expect(ChatAlternation.alternates(r))
            #expect(r.isEmpty || !r.last!.isUser)
        }
    }
}
