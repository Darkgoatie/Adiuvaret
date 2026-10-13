import Foundation

public enum MondayManifest {
    private static let boardsQuery = #"query { boards(limit: 25) { id name state } }"#
    private static let boardItemsQuery = #"query { boards(ids: {boardID}) { items_page(limit: 50) { items { id name } } } }"#

    public static let manifest = ConnectorManifest(
        id: "monday", title: "Monday", category: "Monday", symbol: "tablecells",
        brandAsset: "brand-monday", brandRGB: [0.97, 0.57, 0.12],
        reads: "Your monday boards and board items.",
        changes: "No writes.",
        networkNote: "Only board and item listing queries are sent.",
        host: "api.monday.com",
        headers: ["API-Version": "2026-07"],
        auth: .rawAuthorization,
        tokenHelp: "Create a personal API token in monday.com Admin > API.",
        tools: [
            ConnectorToolSpec(
                name: "listMondayBoards", title: "List monday boards",
                description: "Lists the user's monday boards with IDs and state. It does not list board items.",
                request: ConnectorRequestSpec(method: "POST", path: "/v2", body: [ConnectorSlot("query", boardsQuery)]),
                list: ConnectorListSpec(itemsKey: "data.boards", line: "{name|90} (id {id}[[, {state}]])",
                                        requiredField: "id", limit: 25,
                                        header: "monday boards", empty: "No monday boards found."),
                keywords: ["monday", "monday boards", "board list", "monday workspace"],
                examples: ["List my monday boards", "Show my boards in monday", "What boards do I have in monday?"],
                briefing: true),
            ConnectorToolSpec(
                name: "listMondayItems", title: "List monday board items",
                description: "Lists items from one monday board ID using boards(...){ items_page { items } }. It does not search across all boards.",
                arguments: [ConnectorArg("boardID", guide: "The monday board ID, digits only.", rule: .number, maxLength: 999_999_999_999_999, required: true)],
                request: ConnectorRequestSpec(method: "POST", path: "/v2", body: [ConnectorSlot("query", boardItemsQuery)]),
                list: ConnectorListSpec(itemsKey: "data.boards.0.items_page.items", line: "{name|100} (id {id})",
                                        requiredField: "id", limit: 50,
                                        header: "monday items", empty: "No items found on this monday board."),
                keywords: ["monday", "monday items", "board items", "tasks on monday board"],
                examples: ["List items on monday board 1234567890", "Show monday board 987654321 items", "What items are on monday board 555?"],
                requires: ["listMondayBoards"],
                briefing: true),
        ])
}
