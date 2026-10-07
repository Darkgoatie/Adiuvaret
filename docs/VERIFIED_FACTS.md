# Verified facts

| Fact | Value | Source | Date |
|---|---|---|---|
| Xcode 26.6 iOS SDK 26.5 ships FoundationModels.framework | present | `ls $(xcrun --sdk iphoneos --show-sdk-path)/System/Library/Frameworks` on VM | 2026-10-07 |
| FoundationModels on x86_64 macOS 26.7.1 VM | availability = unavailable(deviceNotEligible); respond() throws assetsUnavailable "This device does not support Apple Intelligence." | swift script on VM | 2026-10-07 |
| iOS 26.5 simulator on that x86 VM | availability reports .available; real generation not yet tried there, treat as untrusted | app launch screenshot | 2026-10-07 |
| iPhone 18 Pro, TestFlight build 0.1.0 (1) | SystemLanguageModel.default.availability == .available | user report from device | 2026-10-07 |
| Min iOS for FoundationModels | 26.0 (framework APIs marked @available(iOS 26.0); some marked 26.4) | Xcode 26.6 iOS SDK 26.5 FoundationModels.swiftinterface | 2026-10-07 |
| Three on-device model versions | iOS 26.0-26.3, 26.4, 27.0; Apple updates the model in OS updates, so prompts need re-testing per version | https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel | 2026-10-07 |
| Availability reasons | .unavailable(.deviceNotEligible / .appleIntelligenceNotEnabled / .modelNotReady) plus an unknown-reason catch-all | Xcode 26.6 iOS SDK 26.5 FoundationModels.swiftinterface; https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel | 2026-10-07 |
| Context size API | SystemLanguageModel.contextSize (tokens, read at runtime); tokenCount(for:) exists for prompt, instructions, tools, schema, transcript entries | Xcode 26.6 iOS SDK 26.5 FoundationModels.swiftinterface | 2026-10-07 |
| Context window | 4096 tokens per session, shared by prompts, instructions, tool definitions, tool inputs and outputs, Generable schemas and responses. Exceeding it ends the session; start a new one seeded from a summary or first+last transcript entries | docs/apple/managing-the-context-window.md | 2026-10-07 |
| Tool budget | Apple advises 3 to 5 tools per request, short descriptions and @Guide text; for heavy workflows split across sessions | docs/apple/managing-the-context-window.md | 2026-10-07 |
| Tool calling modes | GenerationOptions(toolCallingMode:) .allowed (default), .required (needs an exit condition or it loops), .disallowed; tools may be called concurrently and in parallel; errors surface as ToolCallError | docs/apple/expanding-generation-with-tool-calling.md | 2026-10-07 |
| contextSize on iPhone 18 Pro (TestFlight build 2) | 8192 tokens, not the 4096 in Apple's article; read it at runtime and never hardcode | device report 2026-10-07 | 2026-10-07 |
| Tool definition cost | about 45 tokens per tool (1 tool 91, 8 tools 406 via tokenCount(for:)); all 8 dummy tools responded fine, so the limit is token budget and tool-choice quality, not a hard count | device report | 2026-10-07 |
| Latency on device | TTFT 0.9-1.6 s for plain chat; 4.9-10.2 s when a tool is called (two outliers at 5.3 s); respond with 1-8 dummy tools 0.3-0.75 s | device report | 2026-10-07 |
| Tool calling on device | model chose readCalendar for 'Next event on my calendar?' and createReminder for 'Remind me to call my mom in 30 mins'; both ran through PolicyGate | device report | 2026-10-07 |
| Session API | LanguageModelSession: respond, streamResponse (String, Generable, schema), prewarm(promptPrefix:), isResponding, transcript | Xcode 26.6 iOS SDK 26.5 FoundationModels.swiftinterface | 2026-10-07 |
| Errors | GenerationError cases include exceededContextWindowSize, unsupportedLanguageOrLocale, rateLimited, assetsUnavailable | Xcode 26.6 iOS SDK 26.5 FoundationModels.swiftinterface | 2026-10-07 |
| Tool protocol | public protocol Tool<Arguments, Output>: Sendable; the session runs the tool loop itself, so every Tool.call must route through PolicyGate | Xcode 26.6 iOS SDK 26.5 FoundationModels.swiftinterface; https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling | 2026-10-07 |
| Model use limits | Apple says the model is weak at basic math, code generation and logical reasoning; suited to summarize, extract, classify, rewrite | https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models | 2026-10-07 |
| Background execution of FM, BGTaskScheduler limits | UNVERIFIED: Apple page blocked for fetch; measure in task 9 | - | open |
| MLX Swift package names, iPhone memory entitlement | deferred with MLX (decision 003) | - | deferred |
