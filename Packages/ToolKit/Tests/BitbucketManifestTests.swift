import Testing
import Foundation
@testable import ToolKit

@Suite struct BitbucketManifestTests {
    private let manifest = BitbucketManifest.manifest

    /// Real fixture from curl --compressed https://api.bitbucket.org/2.0/repositories?pagelen=1
    /// (as of 2026-10-13 this unauthenticated probe returns a 404 error object).
    private let reposFixture = Data(#"""
    {
      "type": "error",
      "error": {
        "message": "Resource not found",
        "detail": "There is no API hosted at this URL.\n\nFor information about our API's, please refer to the documentation at: https://developer.atlassian.com/bitbucket/api/2/reference/"
      }
    }
    """#.utf8)

    /// Doc-derived fixture from Atlassian pullrequests endpoint examples.
    private let pullRequestsFixture = Data(#"""
    {
      "pagelen": 2,
      "page": 1,
      "size": 2,
      "values": [
        {
          "id": 108,
          "title": "Fix crash on launch",
          "state": "OPEN",
          "author": {
            "display_name": "Ada Lovelace"
          },
          "source": {
            "branch": {
              "name": "feature/crash-fix"
            }
          },
          "destination": {
            "branch": {
              "name": "main"
            }
          },
          "updated_on": "2026-10-11T09:00:00+00:00"
        },
        {
          "id": 109,
          "title": "Add telemetry toggle",
          "state": "OPEN",
          "author": {
            "nickname": "gracehopper"
          },
          "source": {
            "branch": {
              "name": "feature/telemetry-toggle"
            }
          },
          "destination": {
            "branch": {
              "name": "develop"
            }
          },
          "updated_on": "2026-10-10T08:00:00+00:00"
        }
      ]
    }
    """#.utf8)

    @Test func manifestPassesValidator() {
        let problems = ConnectorValidator.problems(manifest)
        #expect(problems.isEmpty, Comment(rawValue: "\(problems)"))
    }

    @Test func requestShapesAreCorrect() throws {
        let reposTool = try #require(manifest.tool("listBitbucketRepos"))
        let repos = try #require(ConnectorEngine.request(manifest, reposTool, [:]))
        #expect(repos.url?.absoluteString == "https://api.bitbucket.org/2.0/repositories?role=member&sort=-updated_on&pagelen=15",
                Comment(rawValue: repos.url?.absoluteString ?? ""))

        let prsTool = try #require(manifest.tool("listBitbucketPullRequests"))
        #expect(prsTool.requires == ["listBitbucketRepos"])
        let prs = try #require(ConnectorEngine.request(manifest, prsTool, ["workspace": "atlassian", "repo": "atlaskit-mk-2"]))
        #expect(prs.url?.absoluteString == "https://api.bitbucket.org/2.0/repositories/atlassian/atlaskit-mk-2/pullrequests?state=OPEN",
                Comment(rawValue: prs.url?.absoluteString ?? ""))
    }

    @Test func fixturesParseWithEmbeddedJSON() throws {
        let reposSpec = try #require(manifest.tool("listBitbucketRepos")?.list)
        let reposResult = ConnectorEngine.result(reposSpec, data: reposFixture, args: [:])
        #expect(reposResult == "No Bitbucket repositories were returned for this token.")

        let prsSpec = try #require(manifest.tool("listBitbucketPullRequests")?.list)
        let lines = ConnectorEngine.lines(prsSpec, data: pullRequestsFixture, args: ["workspace": "atlassian", "repo": "atlaskit-mk-2"])
        #expect(lines == [
            "#108 Fix crash on launch by Ada Lovelace (feature/crash-fix → main) updated 2026-10-11T09:00:00+00:00",
            "#109 Add telemetry toggle by gracehopper (feature/telemetry-toggle → develop) updated 2026-10-10T08:00:00+00:00",
        ], Comment(rawValue: "\(lines)"))
    }

    @Test func hostileArgumentsNeverLeaveBitbucketHost() throws {
        let prsTool = try #require(manifest.tool("listBitbucketPullRequests"))
        let hostile = ["../../x", "@evil.com", "?q=1", "a/b", "evil.com/../..", String(repeating: "x", count: 10_000), "%2e%2e", "ü\u{0}"]
        for h in hostile {
            let r = ConnectorEngine.request(manifest, prsTool, ["workspace": h, "repo": h])
            guard let r else { continue }
            let u = try #require(r.url)
            #expect(u.host == "api.bitbucket.org", Comment(rawValue: "\(h) -> \(u.absoluteString)"))
            #expect(u.scheme == "https" && u.port == nil && u.user == nil)
            #expect(r.value(forHTTPHeaderField: "Authorization") == nil)
        }
    }
}
