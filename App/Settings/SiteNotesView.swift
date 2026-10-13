import SwiftUI
import DesignSystem
import ToolKit

/// Settings, Site notes: the click paths the browser remembers per site. Labels only, never typed text or page content.
struct SiteNotesView: View {
    @State private var notes: [SiteNote] = SiteNoteStore.shared.all()
    @State private var confirmClear = false

    var body: some View {
        List {
            if notes.isEmpty {
                Section {
                    Text("Nothing saved yet. After I click through a website for you, the names of the links I used are kept here so the next visit is faster.")
                        .font(DS.Typography.body).foregroundStyle(DS.Colors.textSecondary)
                }
            } else {
                ForEach(notes, id: \.host) { note in
                    Section {
                        ForEach(Array(note.routes.enumerated()), id: \.offset) { _, route in
                            Text(verbatim: route.steps.joined(separator: " > "))
                                .font(DS.Typography.body).frame(minHeight: 44, alignment: .leading)
                        }
                        .onDelete { offsets in
                            for i in offsets.sorted(by: >) { SiteNoteStore.shared.removeRoute(host: note.host, at: i) }
                            reload()
                        }
                        Button(role: .destructive) { SiteNoteStore.shared.remove(host: note.host); reload() } label: {
                            Text("Forget \(note.host)").font(DS.Typography.body)
                        }
                        .frame(minHeight: 44)
                    } header: { Text(verbatim: note.host) }
                }
                Section {
                    Button(role: .destructive) { confirmClear = true } label: { Text("Forget all sites").font(DS.Typography.body) }
                        .frame(minHeight: 44).accessibilityIdentifier("sitenotes.clear")
                } footer: {
                    Text("These notes stay on this iPhone. They hold the labels of links I clicked, nothing you typed and nothing from the pages.").font(DS.Typography.caption)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.Colors.background)
        .navigationTitle(String(localized: "Site notes"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .confirmationDialog(String(localized: "Forget every site?"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button(String(localized: "Forget all"), role: .destructive) { SiteNoteStore.shared.clear(); reload() }
        }
    }

    private func reload() { notes = SiteNoteStore.shared.all() }
}
