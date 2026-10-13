import Testing
import Foundation
@testable import ToolKit

@Suite struct WebPolicyTests {
    private func allowed(_ s: String) -> String? {
        if case .allowed(let u) = WebPolicy.normalize(s) { return u.absoluteString }
        return nil
    }

    @Test func plainDomainsGetHttps() {
        #expect(allowed("apple.com") == "https://apple.com")
        #expect(allowed("  www.bbc.com/news?x=1  ") == "https://www.bbc.com/news?x=1")
        #expect(allowed("HTTPS://Example.COM/Path") == "https://example.com/Path")
        #expect(allowed("//example.com/a") == "https://example.com/a")
    }

    @Test func httpIsUpgraded() {
        #expect(allowed("http://example.com/a") == "https://example.com/a")
        #expect(allowed("http://example.com:80/a") == "https://example.com/a")
    }

    @Test func otherSchemesAreRefused() {
        for s in ["javascript:alert(1)", "mailto:a@b.com", "file:///etc/passwd", "ftp://example.com", "data:text/html,hi", "tel:123", "sms:5"] {
            #expect(allowed(s) == nil, "\(s) should be refused")
        }
    }

    @Test func privateAndLocalAddressesAreRefused() {
        for s in ["localhost", "localhost:3000/x", "http://127.0.0.1", "192.168.0.1/admin", "10.0.0.5", "https://[::1]/", "printer.local", "nas.lan/files",
                  "intranet", "0x7f.0.0.1", "2130706433", "169.254.169.254/latest/meta-data", "a.b.localhost"] {
            #expect(allowed(s) == nil, "\(s) should be refused")
        }
    }

    @Test func oddAddressesAreRefused() {
        #expect(allowed("") == nil)
        #expect(allowed("   ") == nil)
        #expect(allowed("hello world") == nil)
        #expect(allowed("https://user:pass@example.com") == nil)
        #expect(allowed("https://example.com:8443") == nil)
        #expect(allowed("https://" + String(repeating: "a", count: 2100) + ".com") == nil)
    }

    @Test func sameSiteAllowsSubdomainsOnly() {
        #expect(WebPolicy.isSameSite("shop.example.com", as: "example.com"))
        #expect(WebPolicy.isSameSite("www.example.com", as: "example.com"))
        #expect(WebPolicy.isSameSite("example.com", as: "www.example.com"))
        #expect(!WebPolicy.isSameSite("example.com.evil.net", as: "example.com"))
        #expect(!WebPolicy.isSameSite("notexample.com", as: "example.com"))
        #expect(!WebPolicy.isSameSite("other.com", as: ""))
        #expect(WebPolicy.isAllowed("a.example.com", in: ["x.org", "example.com"]))
        #expect(!WebPolicy.isAllowed("a.example.com", in: []))
    }

    @Test func riskyClicksNeedApproval() {
        for label in ["Place order", "Pay now", "Buy", "Send message", "Delete account", "Submit", "Check out", "Confirm booking", "Book now", "Subscribe", "Cancel subscription"] {
            #expect(WebPolicy.clickNeedsApproval(label: label), "\(label) should need approval")
        }
    }

    @Test func ordinaryClicksDoNot() {
        for label in ["Search", "Next page", "Show more", "Add to cart", "Books", "Accept all cookies", "Menu", "Home", "Sports", "Reorder list", "Log in", "Sign in", "Login"] {
            #expect(!WebPolicy.clickNeedsApproval(label: label), "\(label) should not need approval")
        }
    }

    @Test func sensitiveFieldsAreNeverFilled() {
        #expect(WebPolicy.isSensitiveField(type: "password", auto: nil))
        #expect(WebPolicy.isSensitiveField(type: "text", auto: "cc-number"))
        #expect(WebPolicy.isSensitiveField(type: "text", auto: "one-time-code"))
        #expect(WebPolicy.isSensitiveField(type: "text", auto: "current-password"))
        #expect(!WebPolicy.isSensitiveField(type: "text", auto: "email"))
        #expect(!WebPolicy.isSensitiveField(type: nil, auto: nil))
    }
}

@Suite struct PageSnapshotTests {
    private func snap(_ elements: [PageElement], hasPassword: Bool = false, more: Int = 0) -> PageSnapshot {
        PageSnapshot(url: "https://shop.example.com/a", title: "Shoes", scrollY: 0, scrollHeight: 3000, viewportHeight: 800,
                     above: 0, below: 7, more: more, hasPassword: hasPassword, elements: elements)
    }

    @Test func renderShowsHeaderThenNumberedElements() {
        let text = SnapshotFormat.render(snap([
            PageElement(id: 1, role: "textbox", label: "Search", value: "red shoes"),
            PageElement(id: 2, role: "button", label: "Go"),
            PageElement(id: 3, role: "checkbox", label: "In stock", checked: true),
            PageElement(id: 4, role: "button", label: "Buy", disabled: true),
        ]))
        let lines = text.components(separatedBy: "\n")
        #expect(lines[0].contains("untrusted") && lines[0].contains("shop.example.com") && lines[0].contains("Shoes"))
        #expect(lines[1] == "Showing 0 to 800 of 3000 px. 0 elements above, 7 below.")
        #expect(lines.contains("[1] textbox \"Search\" = \"red shoes\""))
        #expect(lines.contains("[3] checkbox \"In stock\" (checked)"))
        #expect(lines.contains("[4] button \"Buy\" (disabled)"))
    }

    @Test func passwordValuesAreNeverShown() {
        let text = SnapshotFormat.render(snap([
            PageElement(id: 1, role: "textbox", label: "Password", value: "hunter2", type: "password"),
            PageElement(id: 2, role: "textbox", label: "Card", value: "4111", type: "text", auto: "cc-number"),
        ], hasPassword: true))
        #expect(!text.contains("hunter2") && !text.contains("4111"))
        #expect(text.contains("password field") && text.contains("[1] textbox \"Password\""))
    }

    @Test func renderStaysInsideTheBudget() {
        let many = (1...200).map { PageElement(id: $0, role: "link", label: "Product number \($0) with a long name") }
        let text = SnapshotFormat.render(snap(many), budget: 800)
        #expect(text.count <= 900)
        #expect(text.contains("more in view not listed"))
        #expect(text.contains("[1] link"))
        #expect(!text.contains("[200] link"))
    }

    @Test func labelsAreFlattenedAndShortened() {
        let text = SnapshotFormat.render(snap([PageElement(id: 1, role: "link", label: "Line one\n  line \"two\" " + String(repeating: "x", count: 100))]))
        let line = text.components(separatedBy: "\n").first { $0.hasPrefix("[1]") }!
        #expect(!line.contains("\n") && line.contains("line 'two'") && line.hasSuffix("…\""))
    }

    @Test func emptyPageSuggestsReading() {
        #expect(SnapshotFormat.render(snap([])).contains("readPage"))
    }

    @Test func pageTextIsSplitIntoNumberedParts() {
        let raw = (1...80).map { "Paragraph \($0) has some words in it." }.joined(separator: "\n\n")
        let total = SnapshotFormat.partCount(of: raw, size: 500)
        #expect(total > 2)
        let first = SnapshotFormat.page(text: raw, part: 1, size: 500)
        #expect(first.contains("Part 1 of \(total)") && first.contains("part 2"))
        let last = SnapshotFormat.page(text: raw, part: 999, size: 500)
        #expect(last.contains("Part \(total) of \(total)") && !last.contains("Call readPage"))
        #expect(SnapshotFormat.page(text: " \n ", part: 1) == "The page has no readable text.")
    }

    @Test func snapshotsDecodeFromThePageScriptJSON() throws {
        let json = #"{"url":"https://a.com/","title":"T","scrollY":10,"scrollHeight":900,"viewportHeight":700,"above":1,"below":2,"more":0,"hasPassword":false,"elements":[{"id":5,"role":"button","label":"Go","value":null,"type":"submit","auto":"","checked":null,"disabled":false}]}"#
        let s = try JSONDecoder().decode(PageSnapshot.self, from: Data(json.utf8))
        #expect(s.elements.first?.id == 5 && s.elements.first?.type == "submit" && s.scrollY == 10)
    }
}
