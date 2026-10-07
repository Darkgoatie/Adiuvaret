# Verified facts

| Fact | Value | Source | Date |
|---|---|---|---|
| Xcode 26.6 iOS SDK 26.5 ships FoundationModels.framework | present | `ls $(xcrun --sdk iphoneos --show-sdk-path)/System/Library/Frameworks` on VM | 2026-10-07 |
| FoundationModels on x86_64 macOS 26.7.1 VM | availability = unavailable(deviceNotEligible); respond() throws assetsUnavailable "This device does not support Apple Intelligence." | swift script on VM | 2026-10-07 |
| iOS 26.5 simulator on that x86 VM | availability reports .available; real generation not yet tried there, treat as untrusted | app launch screenshot | 2026-10-07 |
| iPhone 18 Pro, TestFlight build 0.1.0 (1) | SystemLanguageModel.default.availability == .available | user report from device | 2026-10-07 |
