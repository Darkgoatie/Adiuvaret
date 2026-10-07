# 007 SwiftData for on-device storage

All in-app data is stored with SwiftData, Apple's native framework, behind the Persistence package. No third-party database. Reference: docs/apple/swiftdata.md.

Chats and their thread items are saved: after each turn, when the drawer opens, on chat switch and when the app leaves the foreground. Demo launches (-demo flags) never write. Running tool rows and pending approvals are settled to failed and timed out on save, since nothing runs after a relaunch.

Later data (memory, notes, activity log) adds models to the same container and relies on SwiftData's automatic migration for additive changes.
