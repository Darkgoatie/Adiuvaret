import Testing
import Foundation
@testable import ToolKit

@Suite struct ServiceConnectorTests {
    @Test func tokensOnlyGoToTheirOwnHost() throws {
        let todoist = try #require(ServiceRequest.todoistTasks()?.url)
        #expect(ServiceHost.isAllowed(todoist, for: "todoist"))
        #expect(!ServiceHost.isAllowed(todoist, for: "github"))
        #expect(!ServiceHost.isAllowed(URL(string: "https://api.todoist.com.evil.net/api/v1/tasks")!, for: "todoist"))
        #expect(!ServiceHost.isAllowed(URL(string: "http://api.todoist.com/api/v1/tasks")!, for: "todoist"))
        #expect(!ServiceHost.isAllowed(URL(string: "https://api.todoist.com:8443/x")!, for: "todoist"))
        #expect(!ServiceHost.isAllowed(URL(string: "https://user@api.todoist.com/x")!, for: "todoist"))
        #expect(!ServiceHost.isAllowed(todoist, for: "unknown"))
    }

    @Test func everyBuiltRequestStaysOnItsHost() throws {
        let all: [(String, URLRequest?)] = [("todoist", ServiceRequest.todoistTasks()), ("todoist", ServiceRequest.todoistAdd(content: "Milk", due: "tomorrow")),
            ("todoist", ServiceRequest.todoistDelete(id: "abc123")), ("github", ServiceRequest.githubSearch(query: "is:open assignee:@me")), ("notion", ServiceRequest.notionSearch(query: "roadmap"))]
        for (id, r) in all {
            let url = try #require(r?.url, Comment(rawValue: id))
            #expect(ServiceHost.isAllowed(url, for: id), Comment(rawValue: url.absoluteString))
            #expect(r?.value(forHTTPHeaderField: "Authorization") == nil)
        }
    }

    @Test func pastedTokensAreChecked() {
        #expect(ServiceToken.isPlausible("0123456789abcdef0123456789abcdef"))
        #expect(!ServiceToken.isPlausible("short"))
        #expect(!ServiceToken.isPlausible("0123456789abcdef 0123456789abcdef"))
        #expect(!ServiceToken.isPlausible("0123456789abcdef\r\nX-Evil: 1"))
        #expect(ServiceToken.clean("  Bearer abc123def456ghi789 \n") == "abc123def456ghi789")
    }

    @Test func todoistAddBuildsAJsonBody() throws {
        let r = try #require(ServiceRequest.todoistAdd(content: "Buy milk", due: "tomorrow 9am"))
        #expect(r.httpMethod == "POST")
        let raw = try #require(r.httpBody)
        let object = try JSONSerialization.jsonObject(with: raw)
        let body = try #require(object as? [String: String])
        #expect(body == ["content": "Buy milk", "due_string": "tomorrow 9am"])
        #expect(ServiceRequest.todoistAdd(content: "  ", due: "") == nil)
        #expect(ServiceRequest.todoistAdd(content: String(repeating: "a", count: 301), due: "") == nil)
        let noDue = try #require(ServiceRequest.todoistAdd(content: "Milk", due: ""))
        let noDueBody = try #require(noDue.httpBody)
        #expect(!String(decoding: noDueBody, as: UTF8.self).contains("due_string"))
    }

    @Test func todoistDeleteRefusesOddIds() {
        #expect(ServiceRequest.todoistDelete(id: "6X7rM8997g3RQmvh")?.httpMethod == "DELETE")
        #expect(ServiceRequest.todoistDelete(id: "../projects") == nil)
        #expect(ServiceRequest.todoistDelete(id: "") == nil)
    }

    @Test func todoistTasksAreListedAndFiltered() {
        let json = Data(#"{"results":[{"id":"1","content":"Buy milk","priority":1,"due":{"date":"2026-10-12","string":"tomorrow"}},{"id":"2","content":"Call the bank","priority":4,"due":null},{"id":"3","content":"Renew passport","due":{"date":"2026-11-01"}}],"next_cursor":null}"#.utf8)
        #expect(TodoistParse.tasks(json) == ["Buy milk (due tomorrow)", "Call the bank [urgent]", "Renew passport (due 2026-11-01)"], Comment(rawValue: "\(TodoistParse.tasks(json))"))
        #expect(TodoistParse.tasks(json, search: "bank") == ["Call the bank [urgent]"])
        #expect(TodoistParse.tasks(json, search: "zebra").isEmpty)
        #expect(TodoistParse.tasks(json, limit: 1).count == 1)
        let plain = Data(#"[{"id":"9","content":"Plain array"}]"#.utf8)
        #expect(TodoistParse.tasks(plain) == ["Plain array"])
        #expect(TodoistParse.tasks(Data("not json".utf8)).isEmpty)
    }

    @Test func todoistCreatedIdsAreRead() {
        #expect(TodoistParse.createdID(Data(#"{"id":"abc","content":"x"}"#.utf8)) == "abc")
        #expect(TodoistParse.createdID(Data(#"{"id":42}"#.utf8)) == "42")
        #expect(TodoistParse.createdID(Data("[]".utf8)) == nil)
    }

    @Test func githubQueriesCannotCarryQualifiers() {
        #expect(GitHubQuery.build(what: "assigned", words: "") == "is:open assignee:@me")
        #expect(GitHubQuery.build(what: "review requested", words: "") == "is:open is:pr review-requested:@me")
        #expect(GitHubQuery.build(what: "created", words: "") == "is:open author:@me")
        #expect(GitHubQuery.build(what: "anything", words: "") == "is:open involves:@me")
        let q = GitHubQuery.build(what: "assigned", words: "repo:secret/private user:bob crash")
        #expect(!q.contains("repo:") && !q.contains("user:") && q.hasSuffix("crash"), Comment(rawValue: q))
    }

    @Test func githubRequestsCarryTheQuery() throws {
        let r = try #require(ServiceRequest.githubSearch(query: "is:open assignee:@me"))
        #expect(r.url?.absoluteString.contains("search/issues?q=is:open") == true, Comment(rawValue: r.url?.absoluteString ?? ""))
        #expect(r.value(forHTTPHeaderField: "X-GitHub-Api-Version") == "2022-11-28")
        #expect(r.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
    }

    @Test func githubIssuesAreListed() {
        let json = Data(#"{"total_count":2,"items":[{"number":12,"title":"Crash on launch","state":"open","repository_url":"https://api.github.com/repos/Darkgoatie/Adiuvaret","updated_at":"2026-10-09T10:00:00Z"},{"number":7,"title":"Add widgets","state":"open","repository_url":"https://api.github.com/repos/Darkgoatie/Keply","pull_request":{"url":"x"},"updated_at":"2026-10-08T09:00:00Z"}]}"#.utf8)
        let lines = GitHubParse.issues(json)
        #expect(lines == ["Darkgoatie/Adiuvaret#12 issue: Crash on launch (open, updated 2026-10-09)", "Darkgoatie/Keply#7 PR: Add widgets (open, updated 2026-10-08)"], Comment(rawValue: "\(lines)"))
        #expect(GitHubParse.issues(Data("{}".utf8)).isEmpty)
    }

    @Test func githubReposAreListed() throws {
        let url = try #require(ServiceRequest.githubRepos()?.url)
        #expect(ServiceHost.isAllowed(url, for: "github"))
        #expect(url.absoluteString.contains("/user/repos"), Comment(rawValue: url.absoluteString))
        let json = Data(#"[{"full_name":"Darkgoatie/Adiuvaret","private":false,"fork":false,"archived":false,"language":"Swift","pushed_at":"2026-10-10T08:00:00Z"},{"full_name":"Darkgoatie/Old","private":true,"fork":true,"archived":true,"language":null,"pushed_at":"2025-01-02T08:00:00Z"}]"#.utf8)
        let lines = GitHubParse.repos(json)
        #expect(lines == ["Darkgoatie/Adiuvaret (public, Swift, pushed 2026-10-10)", "Darkgoatie/Old (private, fork, archived, pushed 2025-01-02)"], Comment(rawValue: "\(lines)"))
        #expect(GitHubParse.repos(Data("{}".utf8)).isEmpty)
    }

    @Test func notionResultsAreListed() {
        let json = Data(#"{"results":[{"object":"page","id":"a","last_edited_time":"2026-10-01T08:00:00.000Z","properties":{"Name":{"type":"title","title":[{"plain_text":"Product "},{"plain_text":"roadmap"}]},"Tags":{"type":"multi_select"}}},{"object":"database","id":"b","title":[{"plain_text":"Tasks"}]}]}"#.utf8)
        let lines = NotionParse.results(json)
        #expect(lines == ["Product roadmap (page, edited 2026-10-01)", "Tasks (database)"], Comment(rawValue: "\(lines)"))
        #expect(NotionParse.results(Data("{}".utf8)).isEmpty)
    }

    @Test func serviceConnectorsAreOffUntilTurnedOn() {
        for id in ["todoist", "github", "notion"] {
            let c = ConnectorCatalog.connector(id)
            #expect(c != nil && c?.defaultOn == false, Comment(rawValue: id))
            #expect(c?.network.contains(ServiceHost.hosts[id] ?? "?") == true, Comment(rawValue: id))
        }
    }
}
