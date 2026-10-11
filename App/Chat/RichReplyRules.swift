import Foundation

/// What the model is told about tables, CSV and charts. Kept short because the Apple model has an 8192-token window.
enum RichReplyRules {
    static let text = " When asked for a table, write a markdown table. When asked for a CSV, write a fenced csv block. When asked for a chart or graph, write a fenced chart block: a first line type: bar or type: line, an optional title: line, then CSV rows with a label column and a number column. Use only numbers you were given or fetched. Never invent data."
}
