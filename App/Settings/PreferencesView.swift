import SwiftUI
import DesignSystem
import ToolKit

/// Preferences: for each kind of information, which built-in source the assistant asks first. The others stay as fallbacks.
struct PreferencesView: View {
    @Bindable private var sources = SourceSettings.shared
    @State private var confirmReset = false

    var body: some View {
        List {
            Section {
                Text("I ask these sources directly, so I don't have to search the web for every question. Pick the one you trust most. If it fails, I try the next one in the same group.")
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(InfoCategory.allCases) { category in
                NavigationLink {
                    SourcePickerView(category: category)
                } label: {
                    row(category)
                }
                .accessibilityIdentifier("preferences.\(category.rawValue)")
            }
            Section {
                Button(String(localized: "Reset all to the defaults"), role: .destructive) { confirmReset = true }
                    .disabled(sources.preferences.isDefault).frame(minHeight: 44)
                    .accessibilityIdentifier("preferences.reset")
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Preferences"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(String(localized: "Reset every choice?"), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(String(localized: "Reset"), role: .destructive) { sources.resetAll() }
        }
    }

    private func row(_ category: InfoCategory) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: category.symbol).frame(width: 28).foregroundStyle(DS.Colors.textSecondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: category.title).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Text(verbatim: sources.selected(category).name).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .frame(minHeight: 44)
    }
}

/// One category: the sources with what each covers and what it sends, and a check mark on the chosen one.
struct SourcePickerView: View {
    let category: InfoCategory
    @Bindable private var sources = SourceSettings.shared

    var body: some View {
        List {
            Section {
                ForEach(InfoSources.sources(category)) { source in
                    Button { sources.choose(source.id, for: category) } label: { row(source) }
                        .accessibilityIdentifier("source.\(source.id)")
                        .accessibilityAddTraits(isSelected(source) ? .isSelected : [])
                }
            } header: {
                Text(verbatim: category.blurb)
                    .font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary).textCase(nil)
            } footer: {
                Text("The first choice is asked first. The rest are tried in order if it can't answer. Nothing is sent except what is listed under each source.")
                    .font(DS.Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isSelected(_ s: InfoSource) -> Bool { sources.selected(category).id == s.id }

    private func row(_ s: InfoSource) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: s.name).font(DS.Typography.body).foregroundStyle(DS.Colors.textPrimary)
                Text(verbatim: s.coverage).font(DS.Typography.footnote).foregroundStyle(DS.Colors.textSecondary)
                Text(verbatim: String(localized: "Sends: \(s.sends)")).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary)
                if !s.note.isEmpty { Text(verbatim: s.note).font(DS.Typography.caption).foregroundStyle(DS.Colors.textSecondary) }
            }
            Spacer(minLength: 0)
            if isSelected(s) {
                Image(systemName: "checkmark").foregroundStyle(DS.Colors.accentText).accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 44, alignment: .leading)
    }
}

#Preview("Preferences") { NavigationStack { PreferencesView() } }
