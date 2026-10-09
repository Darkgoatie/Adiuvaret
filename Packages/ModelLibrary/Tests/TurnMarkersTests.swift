import Testing
@testable import ModelLibrary

@Suite struct TurnMarkersTests {
    @Test func textAfterAnEndMarkerIsDropped() {
        #expect(TurnMarkers.clean("It is at noon.<end_of_turn>\n<start_of_turn>user\nmore") == "It is at noon.")
        #expect(TurnMarkers.clean("a<|im_end|>b<end_of_turn>c") == "a")
    }

    @Test func plainTextAndLoneAngleBracketsStayAsTheyAre() {
        #expect(TurnMarkers.clean("5 < 6 and 7 > 2") == "5 < 6 and 7 > 2")
        #expect(TurnMarkers.clean("") == "")
    }

    @Test func aMarkerStillBeingWrittenIsHidden() {
        #expect(TurnMarkers.clean("Hello <end_of_t") == "Hello ")
        #expect(TurnMarkers.clean("Hello <start") == "Hello ")
    }

    @Test func aMarkerAtTheStartLeavesNothing() {
        #expect(TurnMarkers.clean("<end_of_turn><end_of_turn>").isEmpty)
    }
}
