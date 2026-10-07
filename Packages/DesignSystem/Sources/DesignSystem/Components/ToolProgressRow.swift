import SwiftUI

public struct ToolProgressRow: View {
    public enum Phase: Sendable, Equatable { case running, finished, failed }

    let phase: Phase
    let title: String
    let details: [String]
    @State private var expanded = false

    public init(phase: Phase, title: String, details: [String] = []) {
        self.phase = phase; self.title = title; self.details = details
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Button { if canExpand { expanded.toggle() } } label: {
                HStack(spacing: Spacing.s) {
                    icon
                    Text(verbatim: title).font(DS.Typography.subheadline).foregroundStyle(DS.Colors.textSecondary)
                    if canExpand {
                        Image(systemName: "chevron.right").imageScale(.small)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(canExpand ? Text(verbatim: expanded ? L("Collapse details") : L("Show details")) : Text(verbatim: ""))
            if expanded {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(details, id: \.self) { Text(verbatim: $0).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary) }
                }
                .padding(.leading, Spacing.xl)
            }
        }
    }

    private var canExpand: Bool { phase != .running && !details.isEmpty }

    @ViewBuilder private var icon: some View {
        switch phase {
        case .running: ProgressView().controlSize(.small)
        case .finished: Image(systemName: "checkmark").foregroundStyle(DS.Colors.success).imageScale(.small)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(DS.Colors.danger).imageScale(.small)
        }
    }
}

#Preview("Tool rows") {
    VStack(alignment: .leading) {
        ToolProgressRow(phase: .running, title: "Checking your calendar…")
        ToolProgressRow(phase: .finished, title: "Looked at calendar · 3 events", details: ["9:00 Standup", "13:00 Lunch", "17:30 Gym"])
        ToolProgressRow(phase: .failed, title: "Couldn't reach Reminders")
    }
    .padding().background(DS.Colors.background)
}
