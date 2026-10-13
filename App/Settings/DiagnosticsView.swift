import SwiftUI
import DesignSystem
import Diagnostics
import UIKit

/// Settings, then Diagnostics: shows what the app recorded and lets the user share it. Never holds message text.
struct DiagnosticsView: View {
    @State private var report = ""

    var body: some View {
        List {
            Section {
                Text("This log holds timings, tool names and error types. It never holds your messages, event titles or reminders.")
                    .font(DS.Typography.caption)
            }
            Section {
                ShareLink(item: report) { Label { Text("Share log").font(DS.Typography.body) } icon: { Image(systemName: "square.and.arrow.up") } }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("diagnostics.share")
                Button(role: .destructive) { DiagnosticsLog.shared.clear(); refresh() } label: { Text("Clear log").font(DS.Typography.body) }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("diagnostics.clear")
            }
            Section("Log") {
                Text(verbatim: report).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Diagnostics"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
        .refreshable { refresh() }
    }

    private func refresh() { report = DiagnosticsLog.shared.report(header: Self.header()) }

    static func header() -> [String: String] {
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        var h = ["App": version, "iOS": UIDevice.current.systemVersion, "Device": machine(),
                 "Reasoning API in build": AppleModel.reasoningCompiled ? "yes" : "no (needs iOS 27)",
                 "Actions switched off": AppSettings.shared.actionsOff ? "yes" : "no"]
        h["Apple Intelligence"] = AppleModel.statusText
        return h
    }

    private static func machine() -> String {
        var sys = utsname(); uname(&sys)
        return withUnsafePointer(to: &sys.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) } }
    }
}

#Preview("Diagnostics") { NavigationStack { DiagnosticsView() } }
