import Testing
import Foundation
@testable import ToolKit

@Suite struct DiscordManifestTests {
    private let manifest = DiscordManifest.manifest

    // Doc-derived fixtures from official Discord docs examples:
    // - Get Current User Guilds (partial guild object)
    // - Channel Object examples used by Get Guild Channels
    // - Message Object examples used by Get Channel Messages
    private let serversFixture = Data(#"""
    [
      {
        "id": "80351110224678912",
        "name": "1337 Krew",
        "icon": "8342729096ea3675442027381ff50dfe",
        "banner": "bb42bdc37653b7cf58c4c8cc622e76cb",
        "owner": true,
        "permissions": "36953089",
        "features": ["COMMUNITY", "NEWS", "ANIMATED_ICON", "INVITE_SPLASH", "BANNER", "ROLE_ICONS"],
        "approximate_member_count": 3268,
        "approximate_presence_count": 784
      },
      {
        "id": "197038439483310086",
        "name": "Discord Testers",
        "icon": "f64c482b807da4f539cff778d174971c",
        "features": ["COMMUNITY", "NEWS", "BANNER"],
        "approximate_member_count": 60814,
        "approximate_presence_count": 20034
      }
    ]
    """#.utf8)

    private let channelsFixture = Data(#"""
    [
      {
        "id": "41771983423143937",
        "guild_id": "41771983423143937",
        "name": "general",
        "type": 0,
        "position": 6,
        "permission_overwrites": [],
        "rate_limit_per_user": 2,
        "nsfw": true,
        "topic": "24/7 chat about how to gank Mike #2",
        "last_message_id": "155117677105512449",
        "parent_id": "399942396007890945",
        "default_auto_archive_duration": 60
      },
      {
        "id": "155101607195836416",
        "guild_id": "41771983423143937",
        "name": "ROCKET CHEESE",
        "type": 2,
        "position": 5,
        "permission_overwrites": [],
        "bitrate": 64000,
        "user_limit": 0,
        "rate_limit_per_user": 0,
        "nsfw": false,
        "last_message_id": "174629835082649376",
        "parent_id": null
      }
    ]
    """#.utf8)

    private let messagesFixture = Data(#"""
    [
      {
        "id": "334385199974967042",
        "channel_id": "290926798999357250",
        "author": {
          "id": "53908099506183680",
          "username": "Mason",
          "discriminator": "9999",
          "avatar": "a_bab14f271d565501444b2ca3be944b25"
        },
        "content": "Supa Hot",
        "timestamp": "2017-07-11T17:27:07.299000+00:00",
        "edited_timestamp": null,
        "tts": false,
        "mention_everyone": false,
        "mentions": [],
        "mention_roles": [],
        "attachments": [],
        "embeds": [],
        "pinned": false,
        "type": 0
      },
      {
        "id": "334385199974967043",
        "channel_id": "290926798999357250",
        "author": {
          "id": "53908099506183680",
          "username": "Mason",
          "global_name": "Mason",
          "discriminator": "9999",
          "avatar": "a_bab14f271d565501444b2ca3be944b25"
        },
        "content": "Big news! In this <#278325129692446722> channel!",
        "timestamp": "2017-07-11T17:28:07.299000+00:00",
        "edited_timestamp": null,
        "tts": false,
        "mention_everyone": false,
        "mentions": [],
        "mention_roles": [],
        "mention_channels": [
          {
            "id": "278325129692446722",
            "guild_id": "278325129692446720",
            "name": "big-news",
            "type": 5
          }
        ],
        "attachments": [],
        "embeds": [],
        "pinned": false,
        "type": 0,
        "flags": 2,
        "message_reference": {
          "type": 0,
          "channel_id": "278325129692446722",
          "guild_id": "278325129692446720",
          "message_id": "306588351130107906"
        }
      }
    ]
    """#.utf8)

    @Test func discordManifestPassesValidator() {
        #expect(ConnectorValidator.problems(manifest).isEmpty, Comment(rawValue: "\(ConnectorValidator.problems(manifest))"))
    }

    @Test func discordToolsUseExpectedEndpointsAndRequires() throws {
        let servers = try #require(manifest.tool("listDiscordServers"))
        let channels = try #require(manifest.tool("listDiscordChannels"))
        let messages = try #require(manifest.tool("readDiscordMessages"))

        #expect(servers.request.method == "GET" && servers.request.path == "/api/v10/users/@me/guilds")
        #expect(channels.request.method == "GET" && channels.request.path == "/api/v10/guilds/{guild}/channels")
        #expect(messages.request.method == "GET" && messages.request.path == "/api/v10/channels/{channel}/messages")

        #expect(channels.requires == ["listDiscordServers"])
        #expect(messages.requires == ["listDiscordChannels"])
    }

    @Test func everyKeywordMentionsDiscord() {
        for tool in manifest.tools {
            #expect(tool.keywords.allSatisfy { $0.localizedCaseInsensitiveContains("discord") }, Comment(rawValue: tool.name))
        }
    }

    @Test func docDerivedFixturesRenderWithManifestTemplates() throws {
        let servers = try #require(manifest.tool("listDiscordServers")?.list)
        let channels = try #require(manifest.tool("listDiscordChannels")?.list)
        let messages = try #require(manifest.tool("readDiscordMessages")?.list)

        let serverLines = ConnectorEngine.lines(servers, data: serversFixture, args: [:])
        #expect(serverLines.count == 2, Comment(rawValue: "\(serverLines)"))
        #expect(serverLines[0].contains("1337 Krew") && serverLines[0].contains("80351110224678912"))

        let channelLines = ConnectorEngine.lines(channels, data: channelsFixture, args: ["guild": "41771983423143937"])
        #expect(channelLines.count == 2, Comment(rawValue: "\(channelLines)"))
        #expect(channelLines[0].contains("general") && channelLines[0].contains("type 0"))

        let messageLines = ConnectorEngine.lines(messages, data: messagesFixture, args: ["channel": "290926798999357250", "limit": "2"])
        #expect(messageLines.count == 2, Comment(rawValue: "\(messageLines)"))
        #expect(messageLines[0].contains("Mason") && messageLines[0].contains("Supa Hot"))
    }

    @Test func hostileArgumentsStayOnDiscordDotCom() throws {
        let hostile = ["../../x", "@evil.com", "?q=1&admin=true", "a/b", "evil.com/../..", String(repeating: "x", count: 10_000), "%2e%2e", "ü\u{0}"]
        for tool in manifest.tools where !tool.arguments.isEmpty {
            for value in hostile {
                var raw: [String: String] = [:]
                for arg in tool.arguments { raw[arg.name] = value }
                guard let request = ConnectorEngine.request(manifest, tool, raw), let url = request.url else { continue }
                #expect(url.host == "discord.com", Comment(rawValue: "\(tool.name) \(url.absoluteString)"))
                #expect(url.scheme == "https" && url.port == nil && url.user == nil)
                #expect(url.path.hasPrefix("/api/v10/"), Comment(rawValue: url.path))
                #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            }
        }
    }

    @Test func botAuthSchemeSetsAuthorizationHeader() throws {
        #expect(manifest.auth == .scheme("Bot"))

        let url = try #require(URL(string: "https://discord.com/api/v10/users/@me/guilds"))
        var fromManifest = URLRequest(url: url)
        manifest.auth.apply("my-token", to: &fromManifest)
        #expect(fromManifest.value(forHTTPHeaderField: "Authorization") == "Bot my-token")

        var direct = URLRequest(url: url)
        ConnectorAuth.scheme("Bot").apply("abc123", to: &direct)
        #expect(direct.value(forHTTPHeaderField: "Authorization") == "Bot abc123")
    }
}
