# Handoff

Updated: 2026-10-07, after task 1

## State
Repo skeleton and spec only. No code. Brief copied to docs/BRIEF.md.

## Blocked
- VM reachable from Windows (ssh -p 2222 halit@localhost): macOS 26.7.1 x86_64, Xcode 26.6, iOS SDK 26.5 with FoundationModels, sim runtime iOS 26.5, 16 CPU/16GB. No signing identities in keychain; devicectl sees no device.
- FM spikes (4-6, 9) need the iPhone reachable from the x86 VM over USB passthrough; unverified.

## Built
- Packages/: AdiuvaretCore (tiers, ToolDescriptor, ToolCall, CallContext), PolicyEngine (actor + PolicyGate). 13 tests pass.
- App shell (XcodeGen project.yml) builds and launches in the iOS 26.5 sim on the VM, shows Apple Intelligence status.
- Sync: `git archive HEAD | ssh -p 2222 halit@localhost 'cd ~/development/Adiuvaret && tar x'`, then `../xcodegen/bin/xcodegen generate && ./scripts/smoke.sh`.
- VM sim boot is slow (first boot exceeded 7 min).

## Next
- task 2 (after user confirms spec), task 3 can run in parallel (docs only).
