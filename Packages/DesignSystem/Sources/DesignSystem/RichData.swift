import Foundation

/// A table read from a reply. Cells stay as text; `numbers` says which columns hold only numbers.
public struct DataTable: Sendable, Equatable {
    public let headers: [String]
    public let rows: [[String]]

    public init(headers: [String], rows: [[String]]) { self.headers = headers; self.rows = rows }

    public var columnCount: Int { headers.count }

    /// The number in a cell, accepting thousands separators, a percent sign and a leading currency symbol.
    public static func number(_ cell: String) -> Double? {
        var t = cell.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if t.hasSuffix("%") { t.removeLast() }
        while let f = t.first, "$€£₺".contains(f) { t.removeFirst() }
        t = t.replacingOccurrences(of: " ", with: "")
        if t.contains(",") && t.contains(".") {
            t = t.lastIndex(of: ",")! > t.lastIndex(of: ".")! ? t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") : t.replacingOccurrences(of: ",", with: "")
        } else if t.contains(",") {
            let parts = t.split(separator: ",", omittingEmptySubsequences: false)
            t = parts.count == 2 && parts[1].count != 3 ? t.replacingOccurrences(of: ",", with: ".") : t.replacingOccurrences(of: ",", with: "")
        }
        return Double(t)
    }

    /// Columns where every row has a number.
    public var numericColumns: [Int] {
        guard !rows.isEmpty else { return [] }
        return (0..<columnCount).filter { c in rows.allSatisfy { c < $0.count && Self.number($0[c]) != nil } }
    }

    /// The same table as CSV text, quoting cells that need it.
    public var csv: String {
        func cell(_ s: String) -> String {
            s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
        }
        return ([headers] + rows).map { $0.map(cell).joined(separator: ",") }.joined(separator: "\n")
    }
}

public enum ChartKind: String, Sendable, Equatable { case bar, line }

/// A chart the reply asked for with a fenced `chart` block. Only built from real rows; never guessed.
public struct ChartPoint: Sendable, Equatable, Identifiable {
    public let id: Int
    public let label: String
    public let value: Double
    public init(id: Int, label: String, value: Double) { self.id = id; self.label = label; self.value = value }
}

public struct ChartSpec: Sendable, Equatable {
    public let kind: ChartKind
    public let title: String
    public let labelHeader: String
    public let valueHeader: String
    public let points: [ChartPoint]

    public init(kind: ChartKind, title: String, labelHeader: String, valueHeader: String, points: [ChartPoint]) {
        self.kind = kind; self.title = title; self.labelHeader = labelHeader; self.valueHeader = valueHeader; self.points = points
    }
}

public enum RichData {
    public static let maxRows = 200
    public static let maxColumns = 12
    public static let maxChartPoints = 40

    /// A markdown pipe table: a header line, a separator line of dashes, then rows.
    public static func markdownTable(_ lines: [String]) -> DataTable? {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard cleaned.count >= 2, cleaned.allSatisfy({ $0.contains("|") }) else { return nil }
        func cells(_ l: String) -> [String] {
            var s = l
            if s.hasPrefix("|") { s.removeFirst() }
            if s.hasSuffix("|") { s.removeLast() }
            return s.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        }
        let head = cells(cleaned[0])
        let sep = cells(cleaned[1])
        guard head.count >= 2, sep.count == head.count,
              sep.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0 == "-" || $0 == ":" } && $0.contains("-") }) else { return nil }
        return build(headers: head, rows: cleaned.dropFirst(2).map(cells))
    }

    /// CSV with quotes and commas, or semicolons when the first line has more of those.
    public static func csv(_ text: String) -> DataTable? {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2 else { return nil }
        let delimiter: Character = lines[0].filter({ $0 == ";" }).count > lines[0].filter({ $0 == "," }).count ? ";" : ","
        let parsed = lines.map { split($0, delimiter: delimiter) }
        guard let head = parsed.first, head.count >= 2 else { return nil }
        return build(headers: head, rows: Array(parsed.dropFirst()))
    }

    static func split(_ line: String, delimiter: Character) -> [String] {
        var out: [String] = []; var cur = ""; var quoted = false
        var it = line.makeIterator(); var pending: Character? = it.next()
        while let ch = pending {
            pending = it.next()
            if quoted {
                if ch == "\"" { if pending == "\"" { cur.append("\""); pending = it.next() } else { quoted = false } } else { cur.append(ch) }
            } else if ch == "\"" && cur.isEmpty { quoted = true }
            else if ch == delimiter { out.append(cur.trimmingCharacters(in: .whitespaces)); cur = "" }
            else { cur.append(ch) }
        }
        out.append(cur.trimmingCharacters(in: .whitespaces))
        return out
    }

    /// Rows must match the header width. A ragged table is refused so the reply stays plain text.
    private static func build(headers: [String], rows: [[String]]) -> DataTable? {
        guard !headers.isEmpty, headers.count <= maxColumns, !rows.isEmpty, rows.count <= maxRows else { return nil }
        guard rows.allSatisfy({ $0.count == headers.count }) else { return nil }
        guard headers.contains(where: { !$0.isEmpty }) else { return nil }
        return DataTable(headers: headers, rows: rows)
    }

    /// The body of a `chart` block: `type: bar`, `title: ...`, then CSV with a label column and a value column.
    public static func chart(_ body: String) -> ChartSpec? {
        var kind = ChartKind.bar; var title = ""; var data: [String] = []
        for raw in body.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.lowercased().hasPrefix("type:") { kind = line.dropFirst(5).trimmingCharacters(in: .whitespaces).lowercased() == "line" ? .line : .bar }
            else if line.lowercased().hasPrefix("title:") { title = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
            else if !line.isEmpty { data.append(line) }
        }
        guard let table = csv(data.joined(separator: "\n")), table.columnCount >= 2 else { return nil }
        guard let value = table.numericColumns.first(where: { $0 != 0 }) else { return nil }
        var points: [ChartPoint] = []
        for (i, r) in table.rows.enumerated() {
            guard let v = DataTable.number(r[value]), v.isFinite else { return nil }
            points.append(ChartPoint(id: i, label: r[0], value: v))
        }
        guard points.count >= 2, points.count <= maxChartPoints else { return nil }
        return ChartSpec(kind: kind, title: String(title.prefix(80)), labelHeader: table.headers[0], valueHeader: table.headers[value], points: points)
    }
}
