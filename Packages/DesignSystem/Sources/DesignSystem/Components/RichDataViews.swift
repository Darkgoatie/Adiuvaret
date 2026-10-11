import SwiftUI
import Charts

/// A table in the chat. Scrolls sideways when it is wider than the screen, keeps the header on top, and can be shared as CSV.
struct DataTableView: View {
    let table: DataTable

    private var numeric: Set<Int> { Set(table.numericColumns) }
    private let maxColumnWidth: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        ForEach(Array(table.headers.enumerated()), id: \.offset) { i, h in
                            cell(h, column: i, header: true)
                        }
                    }
                    Divider().gridCellUnsizedAxes(.horizontal).overlay(DS.Colors.separator)
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { r, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { i, v in cell(v, column: i, header: false) }
                        }
                        .background(r % 2 == 1 ? DS.Colors.surfaceRaised.opacity(0.55) : Color.clear)
                    }
                }
            }
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.m))
            .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(DS.Colors.separator, lineWidth: 1))
            ShareLink(item: table.csv, subject: Text("Table"), preview: SharePreview(String(localized: "Table as CSV"))) {
                Label(String(localized: "Share as CSV"), systemImage: "square.and.arrow.up").font(DS.Typography.footnote)
            }
            .buttonStyle(DSButtonStyle(.quiet))
            .accessibilityIdentifier("table.share")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Table with \(table.rows.count) rows and \(table.columnCount) columns"))
    }

    private func cell(_ text: String, column: Int, header: Bool) -> some View {
        Text(verbatim: text)
            .font(header ? DS.Typography.footnote.weight(.semibold) : DS.Typography.subheadline)
            .monospacedDigit()
            .foregroundStyle(header ? DS.Colors.textSecondary : DS.Colors.textPrimary)
            .multilineTextAlignment(numeric.contains(column) ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: maxColumnWidth, alignment: numeric.contains(column) ? .trailing : .leading)
            .padding(.horizontal, Spacing.s).padding(.vertical, Spacing.s)
    }
}

/// A bar or line chart drawn from a `chart` block. Axis values are real numbers from the reply, with their source labels.
struct ChartBlockView: View {
    let spec: ChartSpec

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if !spec.title.isEmpty { Text(verbatim: spec.title).font(DS.Typography.subheadline.weight(.semibold)).foregroundStyle(DS.Colors.textPrimary) }
            Chart(spec.points) { p in
                switch spec.kind {
                case .bar:
                    BarMark(x: .value(spec.labelHeader, p.label), y: .value(spec.valueHeader, p.value))
                        .foregroundStyle(DS.Colors.accent)
                        .cornerRadius(Radius.s)
                case .line:
                    LineMark(x: .value(spec.labelHeader, p.label), y: .value(spec.valueHeader, p.value))
                        .foregroundStyle(DS.Colors.accent).interpolationMethod(.monotone)
                    PointMark(x: .value(spec.labelHeader, p.label), y: .value(spec.valueHeader, p.value))
                        .foregroundStyle(DS.Colors.accent)
                }
            }
            .chartYAxisLabel(spec.valueHeader, alignment: .leading)
            .chartXAxis { AxisMarks { _ in AxisValueLabel().font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) } }
            .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(DS.Colors.separator); AxisValueLabel().font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) } }
            .frame(height: 200)
            ShareLink(item: csv, subject: Text("Chart data"), preview: SharePreview(String(localized: "Chart data as CSV"))) {
                Label(String(localized: "Share data as CSV"), systemImage: "square.and.arrow.up").font(DS.Typography.footnote)
            }
            .buttonStyle(DSButtonStyle(.quiet))
        }
        .padding(Spacing.m)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Radius.m).stroke(DS.Colors.separator, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: spec.title.isEmpty ? String(localized: "Chart") : spec.title))
        .accessibilityValue(Text(verbatim: spec.points.map { "\($0.label) \($0.value.formatted())" }.joined(separator: ", ")))
    }

    private var csv: String { DataTable(headers: [spec.labelHeader, spec.valueHeader], rows: spec.points.map { [$0.label, "\($0.value)"] }).csv }
}

#Preview("Table and chart") {
    VStack(alignment: .leading, spacing: Spacing.l) {
        DataTableView(table: DataTable(headers: ["Team", "Played", "Points"], rows: [["Real Betis", "8", "17"], ["Sevilla", "8", "13"], ["Getafe", "8", "11"]]))
        ChartBlockView(spec: ChartSpec(kind: .bar, title: "Points", labelHeader: "Team", valueHeader: "Points",
                                       points: [ChartPoint(id: 0, label: "Betis", value: 17), ChartPoint(id: 1, label: "Sevilla", value: 13), ChartPoint(id: 2, label: "Getafe", value: 11)]))
    }
    .padding().background(DS.Colors.background)
}
