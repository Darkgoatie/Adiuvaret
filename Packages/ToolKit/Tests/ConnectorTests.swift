import Testing
import Foundation
@testable import ToolKit

@Suite struct NoteNameTests {
    @Test func titlesBecomeSafeFileNames() {
        #expect(NoteName.fileName(for: "Packing list") == "Packing list.md")
        #expect(NoteName.fileName(for: "Ideas.md") == "Ideas.md")
        #expect(NoteName.fileName(for: "Notes: Trip #1?") == "Notes Trip 1.md")
        #expect(NoteName.fileName(for: ".hidden") == "hidden.md")
    }

    @Test func climbingOutOfTheFolderIsImpossible() {
        let name = NoteName.fileName(for: "../../etc/passwd")
        #expect(name == "etc passwd.md", Comment(rawValue: "\(name ?? "nil")"))
        #expect(!(name ?? "").contains("/"))
    }

    @Test func emptyTitlesAreRefused() {
        for t in ["", "   ", "///", "..."] { #expect(NoteName.fileName(for: t) == nil, Comment(rawValue: t)) }
    }

    @Test func longTitlesAreCut() {
        #expect(NoteName.fileName(for: String(repeating: "a", count: 200))?.count == NoteName.maxTitle + 3)
    }

    @Test func onlyPlainMarkdownPathsInsideTheFolderPass() {
        for p in ["Trips/Spain.md", "Ideas.md", "Notes.MD", "a/b/c.markdown"] { #expect(NoteName.isSafeRelative(p), Comment(rawValue: p)) }
        for p in ["", "../x.md", "/etc/x.md", "a/../b.md", ".obsidian/app.md", "note.txt", "a\\b.md", "a//b.md", "Trips/.secret.md"] {
            #expect(!NoteName.isSafeRelative(p), Comment(rawValue: p))
        }
    }

    @Test func titlesComeFromPaths() {
        #expect(NoteName.title(of: "Trips/Spain.md") == "Spain")
    }
}

@Suite struct NoteSearchTests {
    static let notes: [(path: String, text: String)] = [
        ("Trips/Spain.md", "Flights to Seville booked for March. Hotel near the cathedral."),
        ("Ideas.md", "Garden project: plant tomatoes and peppers."),
        ("Taxes 2026.md", "File the return before June. Seville rent receipts needed.")]

    @Test func bodyMatchesAreFound() {
        let hits = NoteSearch.rank(Self.notes, query: "seville")
        #expect(Set(hits.map(\.path)) == ["Trips/Spain.md", "Taxes 2026.md"], Comment(rawValue: "\(hits.map(\.path))"))
    }

    @Test func titleMatchesComeFirst() {
        let hits = NoteSearch.rank(Self.notes, query: "taxes")
        #expect(hits.first?.path == "Taxes 2026.md", Comment(rawValue: "\(hits.map(\.path))"))
    }

    @Test func snippetsShowTheMatch() {
        let hits = NoteSearch.rank(Self.notes, query: "tomatoes garden")
        #expect(hits.count == 1 && hits[0].path == "Ideas.md")
        #expect(hits[0].snippet.contains("tomatoes"))
    }

    @Test func commandWordsAreIgnored() {
        #expect(NoteSearch.terms("note about Seville in my Obsidian vault") == ["seville", "in", "my"] || NoteSearch.terms("note about Seville in my Obsidian vault").contains("seville"))
        #expect(NoteSearch.rank(Self.notes, query: "notes about seville").count == 2)
    }

    @Test func nothingMatchingGivesNothing() {
        #expect(NoteSearch.rank(Self.notes, query: "zebra").isEmpty)
        #expect(NoteSearch.rank(Self.notes, query: "").isEmpty)
        #expect(NoteSearch.rank(Self.notes, query: "note").isEmpty)
    }

    @Test func resultsAreLimited() {
        let many = (0..<20).map { (path: "n\($0).md", text: "alpha beta") }
        #expect(NoteSearch.rank(many, query: "alpha", limit: 3).count == 3)
    }

    @Test func longSnippetsAreCutWithDots() {
        let text = String(repeating: "word ", count: 100) + "needle here"
        let s = NoteSearch.snippet(text, terms: ["needle"])
        #expect(s.contains("needle") && s.hasPrefix("…"), Comment(rawValue: s))
        #expect(s.count <= 165)
    }
}

@Suite struct NoteFormatTests {
    @Test func appendingAddsAParagraph() {
        #expect(NoteFormat.appended(existing: "Line one", text: " Two ") == "Line one\n\nTwo\n")
        #expect(NoteFormat.appended(existing: "A\n", text: "B") == "A\n\nB\n")
        #expect(NoteFormat.appended(existing: "", text: "B") == "B\n")
    }

    @Test func newNotesEndWithANewline() {
        #expect(NoteFormat.newNote("  hello  ") == "hello\n")
    }

    @Test func longNotesAreReadInParts() {
        let text = String(repeating: "a", count: 7000)
        let first = NoteFormat.slice(text, part: 1)
        #expect(first.parts == 3 && first.text.count == 3000)
        #expect(NoteFormat.slice(text, part: 3).text.count == 1000)
        #expect(NoteFormat.slice(text, part: 9).text.count == 1000)
        #expect(NoteFormat.slice(text, part: 0).text.count == 3000)
        let empty = NoteFormat.slice("", part: 1)
        #expect(empty.text.isEmpty && empty.parts == 1)
    }
}

@Suite struct AppLinkTests {
    @Test func shortcutLinksAreEncoded() {
        #expect(ShortcutLink.url(for: "Morning routine")?.absoluteString == "shortcuts://run-shortcut?name=Morning%20routine")
        #expect(ShortcutLink.url(for: "Tom & Jerry")?.absoluteString == "shortcuts://run-shortcut?name=Tom%20%26%20Jerry")
    }

    @Test func badShortcutNamesAreRefused() {
        #expect(ShortcutLink.url(for: "") == nil)
        #expect(ShortcutLink.url(for: String(repeating: "a", count: 81)) == nil)
        #expect(ShortcutLink.url(for: "a\nb") == nil)
    }

    @Test func mailDraftsCarryOnlyTextTheUserWillSee() {
        let url = MailDraft.url(to: ["ana@example.com"], subject: "Dinner", body: "Hi Ana,\nSee you at 8")
        #expect(url?.absoluteString == "mailto:ana@example.com?subject=Dinner&body=Hi%20Ana%2C%0ASee%20you%20at%208", Comment(rawValue: url?.absoluteString ?? "nil"))
        #expect(MailDraft.url(to: [], subject: "Hi", body: "")?.absoluteString == "mailto:?subject=Hi")
        #expect(MailDraft.url(to: [], subject: "", body: "")?.absoluteString == "mailto:")
    }

    @Test func addressesAreChecked() {
        #expect(MailDraft.url(to: ["not an address"], subject: "x", body: "y") == nil)
        #expect(MailDraft.url(to: ["a@b"], subject: "x", body: "y") == nil)
        #expect(MailDraft.url(to: Array(repeating: "a@b.com", count: 6), subject: "x", body: "y") == nil)
        #expect(MailDraft.recipients("ana@example.com, bob@example.org") == ["ana@example.com", "bob@example.org"])
        #expect(MailDraft.recipients("ana@example.com, nope") == nil)
        #expect(MailDraft.recipients("") == [])
    }
}

@Suite struct ConnectorTests {
    @Test func everyConnectorExplainsItself() {
        let ids = ConnectorCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for c in ConnectorCatalog.all {
            #expect(!c.title.isEmpty && !c.reads.isEmpty && !c.changes.isEmpty && !c.network.isEmpty && !c.symbol.isEmpty, Comment(rawValue: c.id))
        }
    }

    @Test func switchesDefaultAndPersist() throws {
        let suite = "connector-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(!ConnectorCatalog.isOn("notes", defaults: defaults))
        #expect(!ConnectorCatalog.isOn("contacts", defaults: defaults))
        #expect(ConnectorCatalog.isOn("shortcuts", defaults: defaults))
        ConnectorCatalog.setOn(true, "notes", defaults: defaults)
        ConnectorCatalog.setOn(false, "shortcuts", defaults: defaults)
        #expect(ConnectorCatalog.isOn("notes", defaults: defaults))
        #expect(!ConnectorCatalog.isOn("shortcuts", defaults: defaults))
        #expect(!ConnectorCatalog.isOn("unknown", defaults: defaults))
    }

    @Test func theOffMessageNamesTheConnector() {
        let m = ConnectorCatalog.offMessage("contacts")
        #expect(m.hasPrefix("Not done") && m.contains("Contacts") && m.contains("Integrations"))
    }

    @Test func contactLinesShareOnlyTheListedFields() {
        let line = ContactFormat.line(name: "Ana Ruiz", organization: "Acme", phones: ["+34 600 111 222"], emails: ["ana@example.com"], birthday: "12 Mar")
        #expect(line == "Ana Ruiz (Acme); phone +34 600 111 222; email ana@example.com; birthday 12 Mar", Comment(rawValue: line))
        #expect(ContactFormat.line(name: "Bob", organization: "", phones: [], emails: [], birthday: nil) == "Bob")
    }
}
