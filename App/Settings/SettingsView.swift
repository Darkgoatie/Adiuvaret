import SwiftUI
import DesignSystem

/// The Settings screen: safety switch first, then sub-screens.
struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    PreferencesView()
                } label: {
                    Label { Text("Preferences").font(DS.Typography.body) } icon: { Image(systemName: "slider.horizontal.3") }
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("settings.preferences")
                NavigationLink {
                    ProvidersView()
                } label: {
                    Label { Text("Providers").font(DS.Typography.body) } icon: { Image(systemName: "cloud") }
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("settings.providers")
                NavigationLink {
                    ShortcutsView()
                } label: {
                    Label { Text("Shortcuts").font(DS.Typography.body) } icon: { Image(systemName: "keyboard") }
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("settings.shortcuts")
            } footer: {
                Text("Preferences: which source I ask first for weather, sports, news, prices and facts. Providers: connect an online model like Claude, ChatGPT or Gemini with your own key.").font(DS.Typography.caption)
            }
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
                Toggle(isOn: $settings.contextRing) { Text("Context ring").font(DS.Typography.body) }
                    .tint(DS.Colors.accent).frame(minHeight: 44).accessibilityIdentifier("settings.contextRing")
                Toggle(isOn: $settings.tokMeter) { Text("Speed under replies").font(DS.Typography.body) }
                    .tint(DS.Colors.accent).frame(minHeight: 44).accessibilityIdentifier("settings.tokMeter")
            } header: { Text("Chat") } footer: {
                Text("The ring at the top right fills as the chat uses up the model's memory for one conversation. Speed shows tokens per second below each reply; it is an estimate.").font(DS.Typography.caption)
            }
            if AppleModel.reasoningCompiled {
                Section {
                    Toggle(isOn: $settings.deepReasoning) { Text("Think before answering").font(DS.Typography.body) }
                        .tint(DS.Colors.accent).frame(minHeight: 44).accessibilityIdentifier("settings.reasoning")
                } footer: {
                    Text("Lets the on-device model reason before it replies. Answers can take a little longer. Needs iOS 27.").font(DS.Typography.caption)
                }
            }
            Section {
                NavigationLink { SiteNotesView() } label: { Text("Site notes").font(DS.Typography.body).frame(minHeight: 44) }
                    .accessibilityIdentifier("settings.siteNotes")
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
                NavigationLink("Evals") { EvalView() }
                if #available(iOS 26.0, *) { NavigationLink("Spike") { SpikeView() } }
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
