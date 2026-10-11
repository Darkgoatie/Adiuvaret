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

    @Test func tableUnderAnIntroLineBecomesATable() {
        let b = RichText.blocks(from: "Here are the standings:\n| Team | Points |\n|---|---|\n| Betis | 61 |\n| Sevilla | 52 |\n\nThat is all.")
        #expect(b.count == 3, Comment(rawValue: "\(b)"))
        #expect(b.first == .paragraph("Here are the standings:"))
        if case .table(let t) = b[1] { #expect(t.rows.count == 2 && t.headers == ["Team", "Points"]) } else { Issue.record("second block is not a table") }
        #expect(b.last == .paragraph("That is all."))
    }

    @Test func halfWrittenTablesStayAsText() {
        let b = RichText.blocks(from: "| Team | Points |")
        #expect(b == [.paragraph("| Team | Points |")], Comment(rawValue: "\(b)"))
    }

    @Test func csvFenceBecomesATable() {
        let b = RichText.blocks(from: "```csv\nname,score\nAna,3\nBo,5\n```")
        if case .table(let t)? = b.first { #expect(t.rows == [["Ana", "3"], ["Bo", "5"]]) } else { Issue.record("not a table: \(b)") }
        #expect(b.count == 1)
    }

    @Test func chartFenceBecomesAChart() {
        let b = RichText.blocks(from: "```chart\ntype: bar\ntitle: Scores\nname,score\nAna,3\nBo,5\n```")
        if case .chart(let c)? = b.first { #expect(c.points.count == 2 && c.title == "Scores") } else { Issue.record("not a chart: \(b)") }
    }

    @Test func brokenDataFencesFallBackToCode() {
        let b = RichText.blocks(from: "```chart\nname,score\nAna,many\nBo,few\n```")
        #expect(b == [.code("name,score\nAna,many\nBo,few")], Comment(rawValue: "\(b)"))
        #expect(RichText.blocks(from: "```swift\nlet x = 1\n```") == [.code("let x = 1")])
    }
}
