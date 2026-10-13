import Foundation

public enum DiscordManifest {
    public static let manifest = ConnectorManifest(
        id: "discord", title: "Discord", category: "Discord", symbol: "message.fill",
        brandAsset: "brand-discord", brandRGB: [0.35, 0.40, 0.95],
        reads: "Servers, channels, and recent messages visible to your bot.",
        changes: "No changes. Read-only.",
        networkNote: "The bot can only access servers it was invited to.",
        host: "discord.com",
        auth: .scheme("Bot"),
        tokenHelp: "Use a Discord bot token from the Discord Developer Portal. Never use a user token: automating a user account breaks Discord's terms.",
        tools: [
            ConnectorToolSpec(
                name: "listDiscordServers", title: "List Discord servers",
                description: "Lists Discord servers (guilds) this bot can access. A bot only sees servers it was invited to.",
                request: ConnectorRequestSpec(path: "/api/v10/users/@me/guilds"),
                list: ConnectorListSpec(
                    line: "{name|100} (id {id})[[ — members ~{approximate_member_count}, online ~{approximate_presence_count}]]",
                    requiredField: "id",
                    limit: 50,
                    header: "Discord servers the bot can access",
                    empty: "No Discord servers were returned. A bot only sees servers it was invited to."),
                keywords: ["discord servers", "discord guilds", "discord bot servers", "discord server list", "discord guild list"],
                examples: ["List my Discord servers", "What Discord servers can this bot see?", "Show Discord guilds for my bot"],
                briefing: true),
            ConnectorToolSpec(
                name: "listDiscordChannels", title: "List Discord channels",
                description: "Lists channels in one Discord server. Bots only see servers they were invited to and channels they can view.",
                arguments: [
                    ConnectorArg("guild", guide: "Server (guild) ID.", rule: .identifier, maxLength: 32, required: true)
                ],
                request: ConnectorRequestSpec(path: "/api/v10/guilds/{guild}/channels"),
                list: ConnectorListSpec(
                    line: "{name|100} (id {id}, type {type})[[ — topic: {topic|80}]]",
                    requiredField: "id",
                    limit: 100,
                    header: "Discord channels",
                    empty: "No Discord channels were returned for that server."),
                keywords: ["discord channels", "discord guild channels", "discord channel list", "discord text channels", "discord voice channels"],
                examples: ["List Discord channels in guild 41771983423143937", "Show Discord channels for guild 80351110224678912", "What channels are in Discord guild 80351110224678912?"],
                requires: ["listDiscordServers"],
                briefing: true),
            ConnectorToolSpec(
                name: "readDiscordMessages", title: "Read Discord messages",
                description: "Reads recent messages in one Discord channel the bot can access. A bot only sees servers it was invited to, and it needs the Message Content intent to reliably read message text.",
                arguments: [
                    ConnectorArg("channel", guide: "Channel ID.", rule: .identifier, maxLength: 32, required: true),
                    ConnectorArg("limit", guide: "How many messages to fetch (1-100). Empty uses Discord's default.", rule: .number, maxLength: 100)
                ],
                request: ConnectorRequestSpec(
                    path: "/api/v10/channels/{channel}/messages",
                    query: [ConnectorSlot("limit", "{limit}", omitIfEmpty: true)]),
                list: ConnectorListSpec(
                    line: "{author.global_name,author.username|30}: {content|180} (id {id})",
                    requiredField: "id",
                    limit: 50,
                    header: "recent Discord messages",
                    empty: "No Discord messages were returned. The bot needs channel access and the Message Content intent to read text."),
                keywords: ["discord messages", "discord channel messages", "discord recent messages", "discord message history", "discord read messages"],
                examples: ["Read recent Discord messages in channel 290926798999357250", "Show the last 10 Discord messages from channel 290926798999357250", "Fetch Discord channel messages for 290926798999357250"],
                requires: ["listDiscordChannels"],
                briefing: true),
        ])
}
