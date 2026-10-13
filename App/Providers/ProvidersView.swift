import SwiftUI
import UIKit
import DesignSystem
import ModelLibrary

/// Settings, Providers: connect an online model with your own API key. Chats with these models are sent to the provider.
struct ProvidersView: View {
    @Bindable private var store = ProviderStore.shared

    var body: some View {
        List {
            Section {
                Text("Connect a model from another company with your own key. When you chat with it, your messages are sent to that company. The models on this iPhone never send anything.")
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(Providers.all) { p in
                    NavigationLink {
                        ProviderDetailView(provider: p)
                    } label: {
                        row(p)
                    }
                    .accessibilityIdentifier("provider.\(p.id)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Providers"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ p: Provider) -> some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: p.name).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Text(verbatim: store.isConnected(p.id) ? String(localized: "Connected") : String(localized: "Not connected"))
                    .font(DS.Typography.footnote).foregroundStyle(store.isConnected(p.id) ? DS.Colors.accentText : DS.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            if store.isConnected(p.id) { Image(systemName: "checkmark.circle").foregroundStyle(DS.Colors.accentText).accessibilityHidden(true) }
        }
        .frame(minHeight: 44)
    }
}

/// One provider. Not connected: a paste field first, and a button to the page where the key is made. Connected: its models and a disconnect button.
struct ProviderDetailView: View {
    let provider: Provider
    @Bindable private var store = ProviderStore.shared
    @Environment(\.openURL) private var openURL
    @State private var pasted = ""
    @State private var message: String?
    @State private var confirmRemove = false
    @State private var showDataNotice = false
    @FocusState private var focused: Bool

    private var connected: Bool { store.isConnected(provider.id) }

    var body: some View {
        List {
            if connected { connectedSections } else { connectSections }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(provider.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(String(localized: "Remove this key?"), isPresented: $confirmRemove, titleVisibility: .visible) {
            Button(String(localized: "Remove key"), role: .destructive) { store.disconnect(provider.id) }
        } message: { Text("The key is deleted from this iPhone. The provider's account is not changed.") }
        .alert(String(localized: "Your chats go to the provider"), isPresented: $showDataNotice) {
            Button(String(localized: "Cancel"), role: .cancel) {}
            Button(String(localized: "Continue")) {
                store.markDataNoticeSeen()
                Task { await connect() }
            }
        } message: {
            Text("When you chat with an online model, your messages and anything its tools read for it are sent to that company. The models on this iPhone never send anything.")
        }
    }

    /// The first connection of any provider shows the notice once; after that, Connect goes straight through.
    private func tryConnect() {
        if store.needsDataNotice { showDataNotice = true } else { Task { await connect() } }
    }

    // MARK: not connected

    @ViewBuilder private var connectSections: some View {
        Section {
            SecureField(provider.keyHint, text: $pasted)
                .textContentType(.password).autocorrectionDisabled().textInputAutocapitalization(.never)
                .font(DS.Typography.body).frame(minHeight: 44).focused($focused)
                .accessibilityIdentifier("provider.key")
                .onSubmit { tryConnect() }
            Button { pasteFromClipboard() } label: {
                Label(String(localized: "Paste from clipboard"), systemImage: "doc.on.clipboard").font(DS.Typography.body)
                    .foregroundStyle(DS.Colors.accentText).frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("provider.paste")
            Button { tryConnect() } label: {
                HStack {
                    Text(store.checking.contains(provider.id) ? String(localized: "Checking the key…") : String(localized: "Connect"))
                        .font(DS.Typography.body.weight(.semibold))
                    if store.checking.contains(provider.id) { ProgressView() }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(DSButtonStyle(.primary))
            .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.checking.contains(provider.id))
            .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))
            .accessibilityIdentifier("provider.connect")
            if let message {
                Text(verbatim: message).font(DS.Typography.footnote).foregroundStyle(DS.Colors.danger)
            }
        } header: {
            Text("I already have a key")
        } footer: {
            Text("Paste it here. It is checked with \(provider.name) first, then kept in this iPhone's Keychain. It is never shown again or sent anywhere else.")
        }
        Section {
            Button { openURL(provider.keyPage) } label: {
                HStack {
                    Text("Get a key from \(provider.name)").font(DS.Typography.body).foregroundStyle(DS.Colors.accentText)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").foregroundStyle(DS.Colors.accentText).accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
            .accessibilityIdentifier("provider.getKey")
        } header: {
            Text("I don't have a key")
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("This opens \(provider.keyPage.host ?? "the provider's site") in your browser. Sign in, create a key, copy it, then come back and tap Paste from clipboard.")
                if !provider.note.isEmpty { Text(verbatim: provider.note) }
            }
        }
    }

    // MARK: connected

    @ViewBuilder private var connectedSections: some View {
        Section {
            HStack {
                Label(String(localized: "Key saved"), systemImage: "checkmark.circle").font(DS.Typography.body).foregroundStyle(DS.Colors.accentText)
                Spacer(minLength: 0)
                if let key = store.key(for: provider.id) { Text(verbatim: APIKey.masked(key)).font(DS.Typography.footnote).monospaced().foregroundStyle(DS.Colors.textSecondary) }
            }
            .frame(minHeight: 44)
        } footer: {
            Text("Chats with these models are sent to \(provider.name). These models can use the same tools as the on-device one, so anything a tool reads for them, such as calendar events, reminders, notes or a web page, is sent to \(provider.name) to answer you. Writes still ask you first.")
        }
        Section {
            ForEach(store.models(for: provider), id: \.self) { model in
                Toggle(isOn: Binding(get: { store.isPicked(provider.id, model) }, set: { store.setPicked($0, provider: provider.id, model: model) })) {
                    Text(verbatim: model).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                }
                .tint(DS.Colors.accent).frame(minHeight: 44)
                .accessibilityIdentifier("model.\(provider.id).\(model)")
            }
            Button { Task { await store.refreshModels(provider) } } label: {
                Text(store.checking.contains(provider.id) ? String(localized: "Updating…") : String(localized: "Refresh the list")).font(DS.Typography.body).foregroundStyle(DS.Colors.accentText).frame(minHeight: 44, alignment: .leading)
            }
            .disabled(store.checking.contains(provider.id))
        } header: {
            Text("Show in the chat menu")
        } footer: {
            Text("Turned-on models appear in the model menu at the top of a chat.")
        }
        Section {
            Button { pasted = ""; message = nil; confirmRemove = true } label: {
                Text("Remove key").font(DS.Typography.body).foregroundStyle(DS.Colors.danger).frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("provider.remove")
        }
    }

    // MARK: actions

    private func pasteFromClipboard() {
        if let text = UIPasteboard.general.string { pasted = text; message = nil; Task { await connect() } }
        else { message = String(localized: "The clipboard is empty. Copy your key first.") }
    }

    private func connect() async {
        message = nil
        switch await store.connect(provider, pasted: pasted) {
        case .saved: pasted = ""; focused = false
        case .implausible: message = String(localized: "That doesn't look like a key. Copy the whole key, with no spaces.")
        case .keychainFailed: message = String(localized: "Couldn't save the key on this iPhone. Try again.")
        case .rejected(let text): message = text
        case .unreachable: message = String(localized: "Couldn't reach \(provider.name). Check the connection and try again.")
        }
    }
}

#Preview("Providers") { NavigationStack { ProvidersView() } }
