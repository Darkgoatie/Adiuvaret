import SwiftUI
import DesignSystem
import ModelLibrary

/// Settings, Advanced, Models: built-in model, downloadable local models, and which one chats.
struct ModelsView: View {
    let settings = ModelSettings.shared
    let use: (String) -> Void
    @State private var confirming: LocalModel?

    var body: some View {
        List {
            Section {
                appleRow
            } header: {
                Text("Built in")
            }
            Section {
                ForEach(ModelCatalog.all) { row($0) }
            } header: {
                Text("Download")
            } footer: {
                Text("Models come from Hugging Face (mlx-community) and run only on this iPhone. Only the download uses the network. Your chats never leave the phone. Downloaded models chat only; calendar and reminder tools stay on the Apple model.")
                    .font(DS.Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Models"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $confirming) { model in
            LicenseSheet(model: model) { settings.download(model); confirming = nil } cancel: { confirming = nil }
                .presentationDetents([.medium])
        }
    }

    private var appleRow: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Intelligence").font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Text("Built in. Supports calendar and reminder tools.").font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer(minLength: Spacing.s)
            trailingUse(id: ModelCatalog.appleID)
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
            }
            if case .failed(let why) = settings.state(model.id) {
                Text(verbatim: why).font(DS.Typography.caption).foregroundStyle(DS.Colors.danger)
            }
        }
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 44)
        .swipeActions { if installed { Button("Delete", systemImage: "trash", role: .destructive) { settings.delete(model.id) } } }
        .contextMenu { if installed { Button("Delete download", systemImage: "trash", role: .destructive) { settings.delete(model.id) } } }
        .accessibilityIdentifier("models.\(model.id)")
    }

    @ViewBuilder private func control(_ model: LocalModel, installed: Bool) -> some View {
        switch settings.state(model.id) {
        case .downloading:
            Button("Cancel") { settings.cancel(model.id) }.foregroundStyle(DS.Colors.accentText).frame(minHeight: 44)
        case .idle, .failed:
            if installed { trailingUse(id: model.id) }
            else {
                Button(settings.state(model.id) == .idle ? "Download" : "Retry") {
                    if model.needsLicenseNotice { confirming = model } else { settings.download(model) }
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
