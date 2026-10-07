# PolicyEngine

Responsibility: the only authority on whether a tool call runs, asks, or is denied; PolicyGate is the only path from a model's tool call to an executor. Non-responsibility: UI, model providers, tool implementations.
Public interface: PolicyEngine actor (evaluate, grant/revoke with scope chat|always, setKillSwitch, endTask), PolicyDecision (allow, requireApproval(reason), deny(reason)), PolicyGate.run(call, in:) -> GateOutcome (executed, blocked, failed), protocols ApprovalPresenter and ToolExecutor, PolicyLimits.
Errors: none thrown; every refusal is a typed DenyReason (killSwitch, unknownTool, rateLimited, scheduledRunWrite, userDenied).
Invariants:
1. irreversible always requires approval, even with a grant.
2. reversible write requires approval unless granted for that chat or always.
3. untrusted context forces approval for any write, overriding grants.
4. scheduled runs never write.
5. kill switch denies everything and is rechecked after an approval.
6. rate limit counts executions per task.
7. a denied approval never reaches the executor.
Dependencies: AdiuvaretCore only.
Owned files: Packages/PolicyEngine/.
Test method: 13 Swift Testing cases via `swift test` (scripts/smoke.sh); on device, Deny created nothing and Approve created the reminder (build 2).
Known gap: untrusted flag is set by the caller (SpikeContext marks it after a read tool); the real runtime must set it from tool output provenance.
