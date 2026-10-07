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
}
