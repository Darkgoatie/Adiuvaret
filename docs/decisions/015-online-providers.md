# Decision 015: Online model providers

Status: accepted, 2026-10-11. Requested by the user.

## What changes

Until now no chat left the phone. Chats with an online provider are sent to that provider. This is opt-in: the user connects a provider with their own API key, then picks one of its models from the chat menu. The models on the phone are unchanged.

## Rules

- Keys are pasted by the user, stored in the Keychain (this device only, never in UserDefaults, logs, diagnostics or chat history) and attached to a request only at send time, and only to that provider's own host. Redirects are not followed.
- A key is saved only after the provider accepted it. The check is the free model-list request, so nothing is billed.
- Chats with an online model show a cloud chip, "Sent to <provider>", in the chat header and a "Sent to the provider" section in the model menu. The Providers screen says it before and after connecting.
- What is sent: the messages typed in the chat, and public data fetched for them (web, weather, prices, tables). Never sent: calendar, reminders, notes, contacts, connected-app data, saved memory, routines, or any tool result from those. The online chat has no tools and cannot change anything.
- The query scrubber still runs before any web search made for the chat.
- Removing a key deletes it from the Keychain and turns off that provider's models. A chat that used them falls back to the on-device model the next time it is opened.

## Providers (checked on 2026-10-11 with unauthenticated requests: every endpoint answered 400 or 401, not 404)

- OpenAI: api.openai.com/v1, Bearer.
- Anthropic: api.anthropic.com/v1/messages, x-api-key and anthropic-version.
- Google Gemini: generativelanguage.googleapis.com/v1beta/openai, Bearer (OpenAI-compatible layer).
- Z.AI: api.z.ai/api/paas/v4, Bearer.
- Kimi: api.moonshot.ai/v1, Bearer.
- DeepSeek: api.deepseek.com, Bearer.
- Mistral: api.mistral.ai/v1, Bearer.
- xAI: api.x.ai/v1, Bearer.
- OpenRouter: openrouter.ai/api/v1, Bearer. One key for many labs, so Copilot-style access to models from several vendors is covered by it.
- Groq: api.groq.com/openai/v1, Bearer.

## Left out

- GitHub Copilot: there is no supported API for third-party apps. GitHub Models (the earlier route) was retired on 2026-07-30. api.githubcopilot.com answers 401 to a plain token, and apps that call it use an undocumented token exchange and see only a small model list. Using it from an app breaks GitHub's terms and could stop working at any time. OpenRouter or OpenAI keys cover the same models.
- Azure OpenAI and Bedrock: they need a per-account endpoint and region, not a single host.

## Limits

- A ChatGPT or Claude subscription does not include API use. The Providers screen says so, because users often confuse the two.
- Model ids change. The list is fetched from the provider when the key is saved and can be refreshed. The built-in suggestions are only a starting point.
- Online chat is plain chat: no tools, no approval cards. Web and live-data questions still work through public data fetched first.
