import SwiftUI
import DesignSystem

/// Turn the shortcut bar above the keyboard on and edit its words and prompts.
struct ShortcutsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        List {
            Section {
                Toggle(isOn: $settings.quickBarOn) { Text("Show shortcut bar").font(DS.Typography.body) }
                    .tint(DS.Colors.accent).frame(minHeight: 44)
                    .accessibilityIdentifier("shortcuts.toggle")
            } footer: {
                Text("A row of buttons above the keyboard. Tapping one puts its prompt in the message field.").font(DS.Typography.caption)
            }
            Section("Shortcuts") {
                ForEach($settings.shortcuts) { $item in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        TextField("Word on the button", text: $item.word).font(DS.Typography.body)
                        TextField("Prompt it writes", text: $item.prompt, axis: .vertical).font(DS.Typography.footnote)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .onDelete { settings.shortcuts.remove(atOffsets: $0) }
                .onMove { settings.shortcuts.move(fromOffsets: $0, toOffset: $1) }
                Button { settings.shortcuts.append(QuickShortcut(word: "", prompt: "")) } label: {
                    Label("Add shortcut", systemImage: "plus").font(DS.Typography.body)
                }
                .frame(minHeight: 44)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Shortcuts"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }
}
