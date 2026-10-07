# 008 Reasoning level: deep

Source: developer.apple.com FoundationModels, ContextOptions.ReasoningLevel (light, moderate, deep, custom), iOS 27.0+. Passed per request: `session.streamResponse(to:contextOptions: ContextOptions(reasoningLevel: .deep))`.

The app sets .deep for every chat request. The code is behind `#if REASONING_API` plus `#available(iOS 27, *)`: the GitHub Xcode 27 pipeline sets the flag, the local VM (Xcode 26.6, SDK 26.5) does not and compiles the plain call. On iOS 26 nothing changes. Reasoning tokens count against the 8192-token context, so long chats may hit the limit sooner. Not yet known: whether the on-device model honours the level on iOS 27 (device check).
