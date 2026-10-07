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
| Context size value on device | not yet measured | task 6 on iPhone | open |
| Session API | LanguageModelSession: respond, streamResponse (String, Generable, schema), prewarm(promptPrefix:), isResponding, transcript | Xcode 26.6 iOS SDK 26.5 FoundationModels.swiftinterface | 2026-10-07 |
| Errors | GenerationError cases include exceededContextWindowSize, unsupportedLanguageOrLocale, rateLimited, assetsUnavailable | Xcode 26.6 iOS SDK 26.5 FoundationModels.swiftinterface | 2026-10-07 |
| Tool protocol | public protocol Tool<Arguments, Output>: Sendable; the session runs the tool loop itself, so every Tool.call must route through PolicyGate | Xcode 26.6 iOS SDK 26.5 FoundationModels.swiftinterface; https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling | 2026-10-07 |
| Model use limits | Apple says the model is weak at basic math, code generation and logical reasoning; suited to summarize, extract, classify, rewrite | https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models | 2026-10-07 |
| Background execution of FM, BGTaskScheduler limits | UNVERIFIED: Apple page blocked for fetch; measure in task 9 | - | open |
| MLX Swift package names, iPhone memory entitlement | deferred with MLX (decision 003) | - | deferred |
