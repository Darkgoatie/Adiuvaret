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
