import SwiftUI
import DesignSystem
import Diagnostics
import Evals

/// Settings, Testing, Evals: runs the fixed checks of the code around the model on this device and shows the pass rate against the target.
/// The checks use made-up messages only; nothing from the user's chats, calendar or notes is read.
struct EvalView: View {
    @State private var report: EvalReport?
    @State private var running = false

    var body: some View {
        List {
            Section {
                Text("\(EvalSuite.cases.count) fixed checks of the parts that surround the model: which tool a message finds, how dates and names are read, what asks for approval, what stops a web page from steering me, and what memory refuses to keep. They use made-up messages and never touch your data.")
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    .listRowBackground(Color.clear)
            }
            Section {
                Button { Task { await run() } } label: {
                    HStack {
                        Text(running ? String(localized: "Running…") : String(localized: "Run the checks")).font(DS.Typography.body.weight(.semibold))
                        if running { ProgressView() }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(DSButtonStyle(.primary))
                .disabled(running)
                .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))
                .accessibilityIdentifier("evals.run")
            }
            if let report {
                Section {
                    Label {
                        Text(verbatim: report.headline).font(DS.Typography.body)
                    } icon: {
                        Image(systemName: report.meetsTarget ? "checkmark.circle" : "exclamationmark.triangle")
                            .foregroundStyle(report.meetsTarget ? DS.Colors.accentText : DS.Colors.warning)
                    }
                    .frame(minHeight: 44)
                    ForEach(EvalCategory.allCases, id: \.self) { category in
                        let c = report.counts(for: category)
                        HStack {
                            Text(verbatim: category.rawValue).font(DS.Typography.body)
                            Spacer(minLength: 0)
                            Text(verbatim: "\(c.passed) / \(c.total)").font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                        }
                        .frame(minHeight: 44)
                    }
                } header: { Text("Result") }
                if !report.failures.isEmpty {
                    Section {
                        ForEach(report.failures) { f in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: f.summary).font(DS.Typography.body)
                                Text(verbatim: f.failure ?? "").font(DS.Typography.footnote).foregroundStyle(DS.Colors.danger)
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                    } header: { Text("Failed") }
                }
                Section {
                    ShareLink(item: text(report)) { Label { Text("Share the result").font(DS.Typography.body) } icon: { Image(systemName: "square.and.arrow.up") } }
                        .frame(minHeight: 44)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Evals"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func run() async {
        running = true
        let result = await EvalSuite.run()
        report = result
        running = false
        DiagnosticsLog.shared.record("evals", result.headline)
    }

    private func text(_ report: EvalReport) -> String {
        var lines = ["Adiuvaret evals", report.headline, ""]
        for c in EvalCategory.allCases { let n = report.counts(for: c); lines.append("\(c.rawValue): \(n.passed) / \(n.total)") }
        if !report.failures.isEmpty { lines.append(""); lines += report.failures.map { "FAILED \($0.id): \($0.failure ?? "")" } }
        return lines.joined(separator: "\n")
    }
}
