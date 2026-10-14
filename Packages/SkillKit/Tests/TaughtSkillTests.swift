import Testing
import Foundation
@testable import SkillKit

@Suite struct TaughtSkillTests {
    private func store() -> TaughtSkillStore {
        TaughtSkillStore(knownTools: { ["callAPI", "searchWeb", "runScript"] },
                         visibleTools: { ["callAPI", "searchWeb"] },
                         normalizeHost: { h in h.contains(" ") || h.contains(":") || !h.contains(".") ? nil : h.lowercased() })
    }
    private func hetzner() -> TaughtSkill {
        TaughtSkill(id: "hetzner-servers", name: "Hetzner servers", description: "List and restart servers on Hetzner Cloud",
                    keywords: ["hetzner", "server", "restart"], instructions: "Base https://api.hetzner.cloud/v1, bearer token. GET /servers lists. POST /servers/{id}/actions/reboot restarts.",
                    tools: ["callAPI"], hosts: ["API.Hetzner.cloud"])
    }

    @Test func registersCleansHostsAndFinds() throws {
        let s = store()
        let saved = try s.register(hetzner())
        #expect(saved.hosts == ["api.hetzner.cloud"])
        #expect(s.find("restart my hetzner server").first?.id == "hetzner-servers")
        #expect(s.find("what is on my calendar").isEmpty)
        #expect(s.find("hetzner").first?.id == "hetzner-servers")
    }

    @Test func refusesBadInput() {
        let s = store()
        func fails(_ t: TaughtSkill, _ e: TaughtError) { #expect(throws: e) { try s.register(t) } }
        var t = hetzner(); t = TaughtSkill(id: "x", name: "n", description: "d", instructions: "i")
        fails(t, .invalidID)
        fails(TaughtSkill(id: "ok-id", name: "", description: "d", instructions: "i"), .emptyName)
        fails(TaughtSkill(id: "ok-id", name: "n", description: "d", instructions: "  "), .emptyInstructions)
        fails(TaughtSkill(id: "ok-id", name: "n", description: "d", instructions: "i", tools: ["nope"]), .unknownTool("nope"))
        fails(TaughtSkill(id: "ok-id", name: "n", description: "d", instructions: "i", hosts: ["localhost"]), .badHost("localhost"))
    }

    @Test func credentialsAreNeverStored() {
        let s = store()
        for text in ["Use header Authorization: Bearer abcdefghijklmnopqrstuvwxyz123456", "api_key = sk_live_abcdefghijklmnop1234", "token: ghp_abcdefghijklmnopqrstuvwxyz0123456789", "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abcdefghijklmnopqrstu"] {
            let t = TaughtSkill(id: "leak-test", name: "Leak", description: "d", instructions: text)
            #expect(throws: TaughtError.secretInText, Comment(rawValue: text)) { try s.register(t) }
        }
        #expect(!SecretGuard.containsSecret("Bearer token from the user's Keychain, header Authorization, GET /v1/servers"))
        #expect(!SecretGuard.containsSecret("Base https://api.example.com/v1 and the page size is 50"))
    }

    @Test func importedIsAlwaysUntrustedAndTaughtDefaultsToIt() {
        #expect(TaughtSkill(id: "ab", name: "n", description: "d", instructions: "i", source: .imported, untrusted: false).untrusted)
        #expect(TaughtSkill(id: "ab", name: "n", description: "d", instructions: "i").untrusted)
    }

    @Test func useHidesToolsThatAreNotVisibleAndDisabledSkillsVanish() throws {
        let s = store()
        var t = hetzner(); t.tools = ["callAPI", "runScript"]
        try s.register(t)
        let u = try s.use("hetzner-servers")
        #expect(u.tools == ["callAPI"] && u.hosts == ["api.hetzner.cloud"])
        s.setEnabled("hetzner-servers", false)
        #expect(s.find("hetzner server").isEmpty)
        #expect(throws: TaughtError.notFound) { try s.use("hetzner-servers") }
    }

    @Test func aFollowUpIsReadTogetherWithTheMessageBefore() throws {
        let s = store()
        try s.register(hetzner())
        #expect(s.find("do it again").isEmpty)
        #expect(s.find("do it again", previous: "restart my hetzner server").first?.id == "hetzner-servers")
        #expect(s.find("hetzner").first?.id == "hetzner-servers")
        #expect(s.find("what is the weather", previous: "tell me a joke").isEmpty)
    }

    @Test func theIndexListsEnabledSkillsOnly() throws {
        let s = store()
        try s.register(hetzner())
        #expect(s.index() == "- hetzner-servers: List and restart servers on Hetzner Cloud")
        s.setEnabled("hetzner-servers", false)
        #expect(s.index().isEmpty)
    }

    @Test func savingTheSameIDAgainBumpsTheVersion() throws {
        let s = store()
        try s.register(hetzner())
        let again = try s.register(hetzner())
        #expect(again.version == 2 && s.all().count == 1)
    }

    @Test func idsAreMadeFromTheNameAndStayUnique() {
        #expect(TaughtSkill.makeID(from: "Restart a Hetzner server", taken: []) == "restart-hetzner-server")
        #expect(TaughtSkill.makeID(from: "Restart a Hetzner server", taken: ["restart-hetzner-server"]) == "restart-hetzner-server-2")
        #expect(TaughtSkill.makeID(from: "!!", taken: []) == "skill")
    }

    @Test func removeAndPersist() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("taught-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let a = TaughtSkillStore(url: url, knownTools: { ["callAPI"] }, normalizeHost: { $0 })
        try a.register(TaughtSkill(id: "one-skill", name: "One", description: "d", instructions: "i", tools: ["callAPI"]))
        let b = TaughtSkillStore(url: url, knownTools: { ["callAPI"] }, normalizeHost: { $0 })
        #expect(b.all().map(\.id) == ["one-skill"])
        #expect(b.remove("one-skill") && b.all().isEmpty)
        #expect(!b.remove("one-skill"))
    }
}
