# AdiuvaretCore

Responsibility: shared value types. Non-responsibility: any decision logic, I/O, UI.
Public interface: ModelTier, PermissionTier (readOnly < reversibleWrite < irreversible), Sensitivity, ToolDescriptor (name, summary, permission, outputSensitivity), ToolCall (id, toolName, argumentsJSON), CallContext (taskID, chatID, isScheduledRun, contextContainsUntrusted). All Sendable, Codable where stored.
Invariants: depends on nothing; PermissionTier ordering is stable (comparisons drive policy); no behaviour beyond ordering.
Dependencies: none.
Owned files: Packages/AdiuvaretCore/.
Test method: compile; ordering covered by PolicyEngine tests.
