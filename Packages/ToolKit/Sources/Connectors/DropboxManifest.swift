import Foundation

public enum DropboxManifest {
    public static let manifest = ConnectorManifest(
        id: "dropbox", title: "Dropbox", category: "Dropbox", symbol: "shippingbox",
        brandAsset: "brand-dropbox", brandRGB: [0.0, 0.38, 0.95],
        reads: "Folder entries and search matches visible to the token.",
        changes: "Nothing. This connector is read-only.",
        networkNote: "App-console generated access tokens are short-lived, so pasted tokens are best for short sessions.",
        host: "api.dropboxapi.com",
        auth: .bearer,
        tokenHelp: "Create a Dropbox access token for your app/user with files.metadata.read. Tokens generated directly in the App Console are short-lived, so this token connector is a weak fit for long-running automation.",
        tools: [
            ConnectorToolSpec(
                name: "listDropboxFolder", title: "List Dropbox folder",
                description: "Lists files and folders in one Dropbox path via /2/files/list_folder. Requires files.metadata.read scope and does not search by keyword.",
                arguments: [
                    ConnectorArg("path", guide: "Folder path in Dropbox, such as '/Homework/math'. Leave empty for root.", rule: .text, maxLength: 200, truncates: true),
                ],
                request: ConnectorRequestSpec(method: "POST", path: "/2/files/list_folder", body: [
                    ConnectorSlot("path", "{path}"),
                    ConnectorSlot("limit", "100", asInt: true),
                ]),
                list: ConnectorListSpec(itemsKey: "entries",
                                        line: "{name|100} ({path_display,path_lower|140})[[ — modified {server_modified|25}]]",
                                        requiredField: "name", limit: 40,
                                        header: "Dropbox folder entries",
                                        empty: "No Dropbox entries were returned for that folder path."),
                intent: ConnectorIntentRule(triggers: ["dropbox"], blockers: ["search", "find", "lookup", "add", "create", "write", "upload", "move", "delete"],
                                            skip: ["dropbox", "folder", "folders", "list", "show", "what", "is", "in", "my", "the", "contents", "content", "at", "path", "for", "files", "file", "root"],
                                            argument: "path", maxWords: 4),
                keywords: ["dropbox", "dropbox folder list", "dropbox folder contents", "dropbox files in folder", "dropbox list path"],
                examples: [
                    "List files in Dropbox folder /Homework/math",
                    "Show Dropbox folder contents at /Reports",
                    "What is in my Dropbox root folder?",
                ],
                briefing: true),
            ConnectorToolSpec(
                name: "searchDropboxFiles", title: "Search Dropbox files",
                description: "Searches Dropbox files and folders with /2/files/search_v2. Requires files.metadata.read and returns search matches, not a complete folder listing.",
                arguments: [
                    ConnectorArg("query", guide: "Search words for Dropbox files and folders.", rule: .text, maxLength: 140, required: true, truncates: true),
                ],
                request: ConnectorRequestSpec(method: "POST", path: "/2/files/search_v2", body: [
                    ConnectorSlot("query", "{query}"),
                ]),
                list: ConnectorListSpec(itemsKey: "matches",
                                        line: "{metadata.metadata.name|100} ({metadata.metadata.path_display,metadata.metadata.path_lower|140})[[ — modified {metadata.metadata.server_modified|25}]]",
                                        requiredField: "metadata.metadata.name", filterArgument: "query", limit: 20,
                                        header: "Dropbox search matches",
                                        empty: "No Dropbox search matches were returned.",
                                        emptyFiltered: "No Dropbox search matches for '{value}'."),
                intent: ConnectorIntentRule(triggers: ["search", "find", "lookup"], blockers: ["add", "create", "write", "upload", "move", "delete"],
                                            skip: ["dropbox", "search", "find", "lookup", "for", "in", "my", "the", "files", "file", "folders", "folder"],
                                            argument: "query", maxWords: 8, needsArgument: true),
                keywords: ["dropbox", "dropbox search", "dropbox find files", "dropbox filename search", "dropbox search documents"],
                examples: [
                    "Search Dropbox for Prime_Numbers",
                    "Find Dropbox files about forecast",
                    "Look up Dropbox folders matching cats",
                ]),
        ])
}
