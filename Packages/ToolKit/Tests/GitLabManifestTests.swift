import Testing
import Foundation
@testable import ToolKit

@Suite struct GitLabManifestTests {
    private let mergeAssignedJSON = Data(#"""
    [
      {
        "id": 701,
        "iid": 42,
        "title": "Harden OAuth callback validation",
        "state": "opened",
        "updated_at": "2026-10-12T14:52:00.000Z",
        "web_url": "https://gitlab.com/adiuvaret/mobile/-/merge_requests/42",
        "references": { "short": "!42", "relative": "!42", "full": "adiuvaret/mobile!42" }
      },
      {
        "id": 702,
        "iid": 41,
        "title": "Fix release notes rendering",
        "state": "opened",
        "updated_at": "2026-10-11T09:04:00.000Z",
        "web_url": "https://gitlab.com/adiuvaret/mobile/-/merge_requests/41",
        "references": { "short": "!41", "relative": "!41", "full": "adiuvaret/mobile!41" }
      }
    ]
    """#.utf8)

    private let mergeReviewJSON = Data(#"""
    [
      {
        "id": 810,
        "iid": 105,
        "title": "Refactor notification scheduler",
        "state": "opened",
        "updated_at": "2026-10-10T11:35:00.000Z",
        "web_url": "https://gitlab.com/adiuvaret/core/-/merge_requests/105",
        "references": { "short": "!105", "relative": "!105", "full": "adiuvaret/core!105" }
      }
    ]
    """#.utf8)

    private let issuesJSON = Data(#"""
    [
      {
        "id": 9901,
        "iid": 28,
        "title": "Crash when offline cache is empty",
        "state": "opened",
        "updated_at": "2026-10-09T07:20:00.000Z",
        "web_url": "https://gitlab.com/adiuvaret/mobile/-/issues/28",
        "references": { "short": "#28", "relative": "#28", "full": "adiuvaret/mobile#28" }
      }
    ]
    """#.utf8)

    private let projectsJSON = Data(#"""
    [
      {
        "id": 551,
        "name": "mobile",
        "path_with_namespace": "adiuvaret/mobile",
        "name_with_namespace": "Adiuvaret / mobile",
        "visibility": "private",
        "last_activity_at": "2026-10-13T16:29:17.802Z"
      },
      {
        "id": 552,
        "name": "core",
        "path_with_namespace": "adiuvaret/core",
        "name_with_namespace": "Adiuvaret / core",
        "visibility": "private",
        "last_activity_at": "2026-10-11T08:01:44.000Z"
      }
    ]
    """#.utf8)

    @Test func gitlabManifestPassesValidator() {
        let m = GitLabManifest.manifest
        let problems = ConnectorValidator.problems(m)
        #expect(problems.isEmpty, Comment(rawValue: "\(problems)"))
    }

    @Test func gitlabToolsParseFixtures() throws {
        let m = GitLabManifest.manifest

        let assigned = try #require(m.tool("listGitLabMergeRequests")?.list)
        #expect(ConnectorEngine.lines(assigned, data: mergeAssignedJSON, args: [:]) == [
            "adiuvaret/mobile!42 Harden OAuth callback validation (opened, updated 2026-10-12T14:52:00.000Z)",
            "adiuvaret/mobile!41 Fix release notes rendering (opened, updated 2026-10-11T09:04:00.000Z)",
        ])

        let review = try #require(m.tool("listGitLabMergeRequestsToReview")?.list)
        #expect(ConnectorEngine.lines(review, data: mergeReviewJSON, args: [:]) == [
            "adiuvaret/core!105 Refactor notification scheduler (opened, updated 2026-10-10T11:35:00.000Z)",
        ])

        let issues = try #require(m.tool("listGitLabIssues")?.list)
        #expect(ConnectorEngine.lines(issues, data: issuesJSON, args: [:]) == [
            "adiuvaret/mobile#28 Crash when offline cache is empty (opened, updated 2026-10-09T07:20:00.000Z)",
        ])

        let projects = try #require(m.tool("listGitLabProjects")?.list)
        #expect(ConnectorEngine.lines(projects, data: projectsJSON, args: [:]) == [
            "adiuvaret/mobile (private, last activity 2026-10-13T16:29:17.802Z)",
            "adiuvaret/core (private, last activity 2026-10-11T08:01:44.000Z)",
        ])
    }

    @Test func hostileArgumentsCannotEscapeGitLabHost() throws {
        let m = GitLabManifest.manifest
        let hostile = ["../../x", "@evil.com", "?q=1&admin=true", "a/b", "evil.com/../..", "%2e%2e", "ü\u{0}"]
        for t in m.tools {
            for h in hostile {
                let r = try #require(ConnectorEngine.request(m, t, ["unused": h]))
                let url = try #require(r.url)
                #expect(url.host == "gitlab.com", Comment(rawValue: "\(t.name) -> \(url.absoluteString)"))
                #expect(url.scheme == "https" && url.port == nil && url.user == nil)
                #expect(!(url.query ?? "").contains(h), Comment(rawValue: "\(t.name) leaked \(h)"))
            }
        }
    }

    @Test func tokenAuthUsesPrivateTokenHeader() {
        #expect(GitLabManifest.manifest.auth == .header("PRIVATE-TOKEN"))

        var direct = URLRequest(url: URL(string: "https://gitlab.com/api/v4/issues")!)
        ConnectorAuth.header("PRIVATE-TOKEN").apply("abc123", to: &direct)
        #expect(direct.value(forHTTPHeaderField: "PRIVATE-TOKEN") == "abc123")
        #expect(direct.value(forHTTPHeaderField: "Authorization") == nil)

        var throughManifest = URLRequest(url: URL(string: "https://gitlab.com/api/v4/projects")!)
        GitLabManifest.manifest.auth.apply("tok_456", to: &throughManifest)
        #expect(throughManifest.value(forHTTPHeaderField: "PRIVATE-TOKEN") == "tok_456")
        #expect(throughManifest.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
