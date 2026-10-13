import SwiftUI
import DesignSystem
import ModelLibrary

/// Settings, Advanced, Models: built-in model, downloadable local models, and which one chats.
struct ModelsView: View {
    let settings = ModelSettings.shared
    let use: (String) -> Void
    @State private var confirming: LocalModel?
    @State private var onCellular: LocalModel?

    var body: some View {
        List {
            Section {
                appleRow
            } header: {
                Text("Built in")
            } footer: {
                if !AppleModel.isAvailable { Text("Choose a downloaded model below, or connect an online model in Settings, Providers.").font(DS.Typography.caption) }
            }
            Section {
                ForEach(ModelCatalog.all) { row($0) }
            } header: {
                Text("Download")
            } footer: {
                Text("Models come from Hugging Face (mlx-community) and run only on this iPhone. Only the download uses the network, and it keeps going in the background and can be paused and resumed. Your chats never leave the phone. Downloaded models chat only; calendar and reminder tools stay on the Apple model.")
                    .font(DS.Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Models"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $confirming) { model in
            LicenseSheet(model: model) { confirming = nil; begin(model) } cancel: { confirming = nil }
                .presentationDetents([.medium])
        }
        .confirmationDialog(String(localized: "Download over cellular?"), isPresented: Binding(get: { onCellular != nil }, set: { if !$0 { onCellular = nil } }), titleVisibility: .visible, presenting: onCellular) { model in
            Button("Download anyway") { settings.download(model) }
            Button("Cancel", role: .cancel) {}
        } message: { model in
            Text("You are not on Wi-Fi. This will use about \(sizeText(model)) of mobile data.")
        }
    }

    /// Starts or resumes a download, asking first when the connection is cellular, a hotspot or in Low Data Mode.
    private func begin(_ model: LocalModel) {
        Task {
            let net = await NetworkCheck.current()
            let left = remaining(model)
            if CellularPolicy.needsWarning(isExpensive: net.isExpensive, isConstrained: net.isConstrained, remainingBytes: left) {
                onCellular = model
            } else {
                settings.download(model)
            }
        }
    }

    private var appleNote: String {
        switch AppleModel.status {
        case .available: String(localized: "Built in. Supports calendar and reminder tools.")
        case .unsupportedOS: String(localized: "Needs iOS 26 or later on an iPhone that supports Apple Intelligence. The downloaded and online models below work on this iPhone.")
        case .unavailable(let why): why + " " + String(localized: "The downloaded and online models work without it.")
        }
    }

    private func remaining(_ model: LocalModel) -> Int64 {
        CellularPolicy.remainingBytes(sizeBytes: model.sizeBytes, fraction: ModelStore.pendingFraction(model.id) ?? 0)
    }

    private func sizeText(_ model: LocalModel) -> String {
        ByteCountFormatter.string(fromByteCount: remaining(model), countStyle: .file)
    }

    private var appleRow: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Intelligence").font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Text(verbatim: appleNote).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer(minLength: Spacing.s)
            if AppleModel.isAvailable { trailingUse(id: ModelCatalog.appleID) }
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("models.apple")
    }

    private func row(_ model: LocalModel) -> some View {
        let installed = settings.installed.contains(model.id)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top, spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: model.name).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                    Text(verbatim: "\(Self.size(model.sizeBytes)) · \(model.license)\(model.note.isEmpty ? "" : " · " + model.note)")
                        .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer(minLength: Spacing.s)
                control(model, installed: installed)
            }
            fitNote(model)
            if case .downloading(let p) = settings.state(model.id) {
                ProgressView(value: p).tint(DS.Colors.accent)
                    .accessibilityLabel(Text("Downloading \(model.name)")).accessibilityValue(Text("\(Int(p * 100)) percent"))
                Text(verbatim: DownloadText.summary(fraction: p, totalBytes: model.sizeBytes)).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            if case .paused(let p, let reason) = settings.state(model.id) {
                ProgressView(value: p).tint(DS.Colors.textSecondary)
                    .accessibilityLabel(Text("Paused \(model.name)")).accessibilityValue(Text("\(Int(p * 100)) percent"))
                Text(verbatim: String(localized: "Paused") + " · " + DownloadText.summary(fraction: p, totalBytes: model.sizeBytes))
                    .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                if let reason { Text(verbatim: reason).font(DS.Typography.caption).foregroundStyle(DS.Colors.warning) }
            }
            if case .failed(let why) = settings.state(model.id) {
                Text(verbatim: why).font(DS.Typography.caption).foregroundStyle(DS.Colors.danger)
            }
        }
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 44)
        .swipeActions { if installed || isPaused(model) { Button("Delete", systemImage: "trash", role: .destructive) { settings.delete(model.id) } } }
        .contextMenu { if installed || isPaused(model) { Button("Delete download", systemImage: "trash", role: .destructive) { settings.delete(model.id) } } }
        .accessibilityIdentifier("models.\(model.id)")
    }

    @ViewBuilder private func control(_ model: LocalModel, installed: Bool) -> some View {
        switch settings.state(model.id) {
        case .downloading:
            Button("Pause") { settings.pause(model.id) }.foregroundStyle(DS.Colors.accentText).frame(minHeight: 44)
        case .paused:
            Button("Resume") { begin(model) }.foregroundStyle(DS.Colors.accentText).frame(minHeight: 44)
        case .idle, .failed:
            if installed { trailingUse(id: model.id) }
            else {
                Button(settings.state(model.id) == .idle ? "Download" : "Retry") {
                    if model.needsLicenseNotice { confirming = model } else { begin(model) }
                }
                .foregroundStyle(DS.Colors.accentText).frame(minHeight: 44)
            }
        }
    }

    @ViewBuilder private func trailingUse(id: String) -> some View {
        if settings.activeID == id {
            Label("In use", systemImage: "checkmark").font(DS.Typography.caption).foregroundStyle(DS.Colors.accentText).frame(minHeight: 44)
        } else {
            Button("Use") { use(id) }.foregroundStyle(DS.Colors.accentText).frame(minHeight: 44)
        }
    }

    @ViewBuilder private func fitNote(_ model: LocalModel) -> some View {
        switch settings.fit(model) {
        case .fits: EmptyView()
        case .tight: Text("Close to this iPhone's memory limit. It may be slow or stop.").font(DS.Typography.caption).foregroundStyle(DS.Colors.warning)
        case .tooBig: Text("Too large for this iPhone's memory. It will probably not run.").font(DS.Typography.caption).foregroundStyle(DS.Colors.warning)
        }
    }

    private func isPaused(_ model: LocalModel) -> Bool {
        if case .paused = settings.state(model.id) { return true }
        return false
    }

    private static func size(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}

private struct LicenseSheet: View {
    let model: LocalModel
    let accept: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text(verbatim: model.name).font(DS.Typography.heading)
            Text("This model is released under the \(model.license). By downloading it you agree to those terms.")
                .font(DS.Typography.body)
            Link(destination: model.licenseURL) { Label("Read the terms", systemImage: "arrow.up.right") }
                .font(DS.Typography.body).foregroundStyle(DS.Colors.accentText).frame(minHeight: 44)
            Text("It is \(ByteCountFormatter.string(fromByteCount: model.sizeBytes, countStyle: .file)) and comes from huggingface.co.")
                .font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            Spacer(minLength: 0)
            Button(action: accept) { Text("Agree and download").frame(maxWidth: .infinity) }
                .buttonStyle(DSButtonStyle(.primary)).accessibilityIdentifier("models.accept")
            Button("Not now", action: cancel).frame(maxWidth: .infinity, minHeight: 44).foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(Spacing.xl)
        .background(DS.Colors.background)
    }
}

#Preview("Models") { NavigationStack { ModelsView(use: { _ in }) } }
