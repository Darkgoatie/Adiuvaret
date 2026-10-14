import Foundation
import ToolKit

/// The tool an online model calls to load more tools. It only carries the schema; the chat loop answers it,
/// because the answer changes which tools the next request offers.
struct FindToolsTool: AppTool {
    let name = ToolDiscovery.toolName
    let description = "Loads tools you do not have yet. Describe in a few words what you need to do, for example: read calendar events, create a reminder, post a Slack message, search notes, list GitHub issues. The tools it returns can be called in your next step."
    let params: [ToolParam] = [
        .string("query", "A few words about what you need to do, for example: post a message to Slack"),
    ]

    func run(_ args: ToolArgs) async -> String { "Not done: this tool is answered by the chat." }
}
