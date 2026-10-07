import Testing
@testable import DesignSystem

@Suite struct RichTextTests {
    @Test func bulletsAndBold() {
        let b = RichText.blocks(from: "Intro\n- **a** one\n* two\n\nEnd")
        #expect(b == [.paragraph("Intro"), .bullet("**a** one"), .bullet("two"), .paragraph("End")])
    }

    @Test func numberedAndHeading() {
        let b = RichText.blocks(from: "## Plan\n1. x\n2) y")
        #expect(b == [.heading("Plan"), .numbered(1, "x"), .numbered(2, "y")])
    }

    @Test func inlineStripsMarkers() {
        #expect(String(RichText.inline("**bold** and *it*").characters) == "bold and it")
    }

    @Test func unfinishedMarkerStaysReadable() {
        #expect(String(RichText.inline("so **bol").characters).contains("bol"))
    }

    @Test func plainLinesKeepTheirBreaks() {
        #expect(RichText.blocks(from: "Fri 09:00 Standup\nFri 13:00 Lunch\nSat 10:00 Gym") == [.paragraph("Fri 09:00 Standup\nFri 13:00 Lunch\nSat 10:00 Gym")])
    }

    @Test func codeFenceBecomesOneBlock() {
        #expect(RichText.blocks(from: "Before\n```swift\nlet x = 1\n  let y = 2\n```\nAfter") ==
                [.paragraph("Before"), .code("let x = 1\n  let y = 2"), .paragraph("After")])
    }

    @Test func openFenceWhileStreamingStillShowsCode() {
        #expect(RichText.blocks(from: "```\nlet x") == [.code("let x")])
    }

    @Test func nestedBulletsKeepLevel() {
        #expect(RichText.blocks(from: "* one\n  * nested\n* two") == [.bullet("one"), .subBullet("nested"), .bullet("two")])
    }

    @Test func rulesAndLoneMarkersAreDropped() {
        #expect(RichText.blocks(from: "---\nText\n-\n***") == [.paragraph("Text")])
    }

    @Test func danglingBoldMarkerIsHidden() {
        #expect(String(RichText.inline("so **bol").characters) == "so bol")
        #expect(String(RichText.inline("**done** and **ok").characters) == "done and ok")
        #expect(String(RichText.inline("**a** b").characters) == "a b")
    }
}
