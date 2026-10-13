import Foundation

public enum AirtableManifest {
    public static let manifest = ConnectorManifest(
        id: "airtable",
        title: "Airtable",
        category: "Airtable",
        symbol: "tablecells",
        brandAsset: "brand-airtable",
        brandRGB: [0.11, 0.73, 0.48],
        reads: "Airtable bases visible to your token, plus record IDs and created timestamps from one table.",
        changes: "Nothing. This connector is read-only.",
        networkNote: "Calls Airtable Web API over api.airtable.com with your own personal access token.",
        host: "api.airtable.com",
        auth: .bearer,
        tokenHelp: "Create a personal access token at airtable.com/create/tokens with schema.bases:read and data.records:read scopes, then grant base access in the token settings.",
        tools: [
            ConnectorToolSpec(
                name: "listAirtableBases",
                title: "List Airtable bases",
                description: "Lists Airtable bases visible to the token with ID, name and permission level. Requires schema.bases:read.",
                request: ConnectorRequestSpec(path: "/v0/meta/bases"),
                list: ConnectorListSpec(
                    itemsKey: "bases",
                    line: "{name,id|80} ({id})[[ — {permissionLevel}]]",
                    requiredField: "id",
                    limit: 25,
                    header: "Airtable bases visible to this token",
                    empty: "No Airtable bases were returned for this token."),
                keywords: ["airtable bases", "airtable base list", "airtable visible bases", "airtable accessible bases", "airtable token bases"],
                examples: [
                    "List Airtable bases this token can access",
                    "What Airtable bases are visible to my token?",
                    "Show me Airtable base IDs",
                ],
                briefing: true),
            ConnectorToolSpec(
                name: "listAirtableRecords",
                title: "List Airtable records",
                description: "Lists up to 10 records from one Airtable table and returns only record id and createdTime (field values are dynamic and not listed). Requires data.records:read.",
                arguments: [
                    ConnectorArg("base", guide: "Airtable base ID, for example appLkNDICXNqxSDhG.", rule: .identifier, maxLength: 40, required: true),
                    ConnectorArg("table", guide: "Airtable table ID, for example tbltp8DGLhqbUmjK1.", rule: .identifier, maxLength: 60, required: true),
                ],
                request: ConnectorRequestSpec(
                    path: "/v0/{base}/{table}",
                    query: [ConnectorSlot("maxRecords", "10")]),
                list: ConnectorListSpec(
                    itemsKey: "records",
                    line: "{id}[[ (created {createdTime})]]",
                    requiredField: "id",
                    limit: 10,
                    header: "Airtable records (id and created time only)",
                    empty: "No Airtable records were returned for that base and table."),
                keywords: ["airtable records", "airtable table records", "airtable list records", "airtable record ids", "airtable created time"],
                examples: [
                    "List Airtable records for base appLkNDICXNqxSDhG table tbltp8DGLhqbUmjK1",
                    "Show Airtable record IDs for base appSW9R5uCNmRmfl6 table tblA1B2C3D4E5F6G7",
                    "Read Airtable records in base appLkNDICXNqxSDhG table tblQwerty123456789",
                ],
                requires: ["listAirtableBases"],
                briefing: true),
        ])
}
