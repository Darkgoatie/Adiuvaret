import Foundation

/// What the model is told about tables, CSV and charts. Kept short because the Apple model has an 8192-token window.
enum RichReplyRules {
        static let text = " You can show tables, CSV and charts in this chat, so never say you cannot. When asked for a table, write a markdown table. When asked for a CSV, write a fenced csv block. When asked for a chart or graph, write a fenced chart block: a first line type: bar or type: line, an optional title: line, then CSV rows with a label column and a number column. If the message or a tool result already contains a table or a chart block, show it unchanged. Use only numbers you were given or fetched. If you have no numbers, say what data is missing and offer to look it up."
}
