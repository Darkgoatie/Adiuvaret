import Testing
@testable import ToolKit

@Suite struct ConnectorIntentTests {
    @Test func githubQuestionsAreRecognised() {
        #expect(ConnectorIntent.detect("Which pull requests are waiting for my review?") == .init(connector: "github", tool: "listGitHubIssues", arguments: ["what": "review", "words": ""]))
        #expect(ConnectorIntent.detect("What GitHub issues are assigned to me?")?.arguments["what"] == "assigned")
        #expect(ConnectorIntent.detect("List my open GitHub pull requests")?.tool == "listGitHubIssues")
        #expect(ConnectorIntent.detect("Show my PRs created by me on github")?.arguments["what"] == "created")
        #expect(ConnectorIntent.detect("can you check my github repos")?.connector == "github")
    }

    @Test func repoQuestionsGoToTheRepoList() {
        for t in ["What are my current GitHub repos?", "List my repositories", "show my repos", "Which GitHub repositories do I have?"] {
            #expect(ConnectorIntent.detect(t)?.tool == "listGitHubRepos", Comment(rawValue: t))
        }
    }

    @Test func commitQuestionsNameTheRepoAndCount() {
        #expect(ConnectorIntent.detect("latest 3 commits on adiuvaret") == .init(connector: "github", tool: "listGitHubCommits", arguments: ["repo": "adiuvaret", "count": "3"]))
        #expect(ConnectorIntent.detect("Show me the last five commits in Keply")?.arguments == ["repo": "keply", "count": "5"])
        #expect(ConnectorIntent.detect("what are the recent commits on my arztalep repo")?.arguments["repo"] == "arztalep")
        #expect(ConnectorIntent.detect("list commits")?.arguments == ["repo": "", "count": "3"])
        #expect(ConnectorIntent.detect("last 50 commits on keply")?.arguments["count"] == "10")
        #expect(ConnectorIntent.detect("latest commits on github for adiuvaret")?.tool == "listGitHubCommits")
    }

    @Test func todoistReadsKeepTheirSearchWords() {
        #expect(ConnectorIntent.detect("What is on my Todoist today?") == .init(connector: "todoist", tool: "listTodoistTasks", arguments: ["search": ""]))
        #expect(ConnectorIntent.detect("Do I have a Todoist task about the bank?")?.arguments["search"] == "bank")
    }

    @Test func todoistWritesAreLeftToTheModel() {
        #expect(ConnectorIntent.detect("Add buy milk to my Todoist") == nil)
        #expect(ConnectorIntent.detect("Create a Todoist task to call the bank") == nil)
    }

    @Test func notionSearchesNeedWords() {
        #expect(ConnectorIntent.detect("Find my roadmap page in Notion")?.arguments["query"] == "roadmap")
        #expect(ConnectorIntent.detect("Search Notion for meeting notes")?.arguments["query"] == "meeting notes")
        #expect(ConnectorIntent.detect("open notion") == nil)
    }

    @Test func everythingElseIsIgnored() {
        for t in ["Tell me a joke", "What's the weather in Seville?", "What's on my calendar tomorrow?", "Remind me to call mom", "Who is the CEO of Nvidia?", ""] {
            #expect(ConnectorIntent.detect(t) == nil, Comment(rawValue: t))
        }
    }
}
