import Testing
@testable import DesignSystem

@Suite struct RichDataTests {
    @Test func numbersAcceptCommonFormats() {
        #expect(DataTable.number("42") == 42)
        #expect(DataTable.number(" 3.5 ") == 3.5)
        #expect(DataTable.number("1,234") == 1234)
        #expect(DataTable.number("1,234.56") == 1234.56)
        #expect(DataTable.number("1.234,56") == 1234.56)
        #expect(DataTable.number("12,5") == 12.5)
        #expect(DataTable.number("45%") == 45)
        #expect(DataTable.number("$9.99") == 9.99)
        #expect(DataTable.number("₺1,500") == 1500)
        #expect(DataTable.number("-7") == -7)
        #expect(DataTable.number("abc") == nil)
        #expect(DataTable.number("") == nil)
        #expect(DataTable.number("12 apples") == nil)
    }

    @Test func markdownTablesAreRead() {
        let t = RichData.markdownTable(["| Team | Points |", "| --- | ---: |", "| Betis | 61 |", "| Sevilla | 52 |"])
        #expect(t == DataTable(headers: ["Team", "Points"], rows: [["Betis", "61"], ["Sevilla", "52"]]))
        #expect(t?.numericColumns == [1])
    }

    @Test func tablesWithoutASeparatorLineAreRefused() {
        #expect(RichData.markdownTable(["| a | b |", "| 1 | 2 |"]) == nil)
        #expect(RichData.markdownTable(["just text", "more text"]) == nil)
        #expect(RichData.markdownTable(["| a | b |"]) == nil)
    }

    @Test func raggedTablesAreRefused() {
        #expect(RichData.markdownTable(["| a | b |", "|---|---|", "| 1 | 2 | 3 |"]) == nil)
        #expect(RichData.csv("a,b\n1,2,3") == nil)
    }

    @Test func csvHandlesQuotesAndSemicolons() {
        let t = RichData.csv("name,note\n\"Smith, Ann\",\"said \"\"hi\"\"\"\nBob,ok")
        #expect(t?.rows == [["Smith, Ann", "said \"hi\""], ["Bob", "ok"]], Comment(rawValue: "\(String(describing: t))"))
        #expect(RichData.csv("a;b\n1;2")?.rows == [["1", "2"]])
        #expect(RichData.csv("only one line") == nil)
        #expect(RichData.csv("a\n1") == nil)
    }

    @Test func csvOutputQuotesWhatNeedsIt() {
        let t = DataTable(headers: ["name", "note"], rows: [["Smith, Ann", "said \"hi\""], ["Bob", "ok"]])
        #expect(t.csv == "name,note\n\"Smith, Ann\",\"said \"\"hi\"\"\"\nBob,ok", Comment(rawValue: t.csv))
        #expect(RichData.csv(t.csv) == t)
    }

    @Test func sizeLimitsApply() {
        let wide = (0..<(RichData.maxColumns + 1)).map { "c\($0)" }.joined(separator: ",")
        #expect(RichData.csv(wide + "\n" + wide) == nil)
        let tall = "a,b\n" + (0..<(RichData.maxRows + 1)).map { "\($0),\($0)" }.joined(separator: "\n")
        #expect(RichData.csv(tall) == nil)
    }

    @Test func chartsNeedRealNumbers() {
        let c = RichData.chart("type: line\ntitle: Points\nteam,points\nBetis,61\nSevilla,52\nGetafe,44")
        #expect(c?.kind == .line)
        #expect(c?.title == "Points")
        #expect(c?.valueHeader == "points")
        #expect(c?.points.map(\.value) == [61, 52, 44])
        #expect(c?.points.map(\.label) == ["Betis", "Sevilla", "Getafe"])
    }

    @Test func chartsDefaultToBars() {
        #expect(RichData.chart("x,y\na,1\nb,2")?.kind == .bar)
    }

    @Test func chartsFallBackWhenDataIsNotNumeric() {
        #expect(RichData.chart("team,city\nBetis,Seville\nSevilla,Seville") == nil)
        #expect(RichData.chart("team,points\nBetis,61") == nil)
        #expect(RichData.chart("team,points\nBetis,61\nSevilla,many") == nil)
        #expect(RichData.chart("") == nil)
    }

    @Test func chartsUseTheFirstNumberColumnAfterTheLabel() {
        let c = RichData.chart("team,city,points,goals\nBetis,Seville,61,50\nSevilla,Seville,52,40")
        #expect(c?.valueHeader == "points")
        #expect(c?.points.map(\.value) == [61, 52])
    }

    @Test func chartsAreCapped() {
        let rows = (0..<(RichData.maxChartPoints + 1)).map { "r\($0),\($0)" }.joined(separator: "\n")
        #expect(RichData.chart("x,y\n" + rows) == nil)
    }
}
