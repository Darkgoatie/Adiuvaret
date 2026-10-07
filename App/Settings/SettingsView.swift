import SwiftUI
import DesignSystem

/// The Settings screen: safety switch first, then sub-screens.
struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

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
                Text("When this is on, I can still talk and read what you share, but I won't create or change anything until you turn it back off.")
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
            Section("Testing") {
                NavigationLink("Spike") { SpikeView() }
                NavigationLink("Design") { DesignGallery() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Settings") { NavigationStack { SettingsView() } }
