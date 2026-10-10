import SwiftUI
import DesignSystem

/// The Settings screen: safety switch first, then sub-screens.
struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $settings.actionsOff) {
                    Label { Text("Switch off actions").font(DS.Typography.body) } icon: { Image(systemName: "hand.raised") }
                }
                .tint(DS.Colors.accent)
                .frame(minHeight: 44)
                .accessibilityIdentifier("settings.actionsOff")
            } footer: {
                Text("When this is on, I can still talk, but I won't use your calendar, reminders or any other tool until you turn it back off.")
                    .font(DS.Typography.caption)
            }
            Section {
                ForEach(SubItem.settings) { item in
                    NavigationLink(value: item.route) {
                        Label { Text(verbatim: item.title).font(DS.Typography.body) } icon: { Image(systemName: item.symbol) }
                            .frame(minHeight: 44)
                    }
                }
            }
            Section {
                Button(role: .destructive) { confirmClear = true } label: { Text("Clear browsing data").font(DS.Typography.body) }
                    .frame(minHeight: 44).accessibilityIdentifier("settings.clearWeb")
            } header: { Text("Browser") } footer: {
                Text("Signs you out of every website the assistant opened and removes cookies and saved site data.").font(DS.Typography.caption)
            }
            Section {
                Toggle(isOn: Binding(get: { AppSettings.shared.strictWeb }, set: { AppSettings.shared.strictWeb = $0 })) {
                    Text("Ask before opening new sites").font(DS.Typography.body)
                }
                .frame(minHeight: 44).accessibilityIdentifier("settings.strictWeb")
            } footer: {
                Text("Searching stays automatic. With this on, the assistant asks before it opens a website it has not visited in that chat.").font(DS.Typography.caption)
            }
            Section("Testing") {
                NavigationLink("Diagnostics") { DiagnosticsView() }
                NavigationLink("Spike") { SpikeView() }
                NavigationLink("Design") { DesignGallery() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Clear browsing data?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { Task { await WebSession.shared.clearWebsiteData() } }
        } message: { Text("You will be signed out of websites.") }
    }
}

#Preview("Settings") { NavigationStack { SettingsView() } }
