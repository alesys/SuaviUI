# Cross-Project Addon Knowledge Playbook

This guide packages the hard-won implementation and debugging knowledge from SuaviUI into a reusable format for other WoW addon projects.

## 1) What To Reuse First

When starting a new addon, port these practices before adding features:

1. **Session-based error triage** (not counter-based)
2. **Taint-safe coding patterns** for secret values and protected APIs
3. **Edit Mode persistence patterns** (save-by-center + callback normalization)
4. **Structured release workflow** (version/tag/zip/release verification)

## 2) BugSack/BugGrabber Triage Model

Use session IDs as the source of truth.

- Analyze newest session block(s), not historical aggregate noise.
- Compare:
  - unique error signatures
  - top stack source
  - whether signature is new/regressed/resolved
- Ignore raw `counter` as a quality metric across sessions.

Reference: [BUGSACKER_ANALYSIS_GUIDE.md](../BUGSACKER_ANALYSIS_GUIDE.md)

## 3) Taint-Safe Engineering Rules (WoW 12.x)

### 3.1 Secret Value Handling

- Never directly compare/arithmetically combine values that may be secret.
- Guard risky API reads with `pcall`, then sanitize into safe primitives before use.
- Do not assume `pcall` alone makes downstream values safe.

### 3.2 Protected/Forbidden Objects

- Avoid method replacement on Blizzard viewer/system objects.
- Avoid writes to secure frame fields from insecure context.
- Avoid forcing protected flows (`TargetUnit`, Edit Mode internals, forbidden mixin tables).

### 3.3 High-Risk Triggers

- `OnUpdate` loops touching Blizzard frame internals
- event wrappers around secure viewers (`RefreshData`, `OnEvent`, `SetIsActive` chains)
- direct Show/Hide mutation on Blizzard unit/resource frames during Edit Mode

## 4) Edit Mode Integration Patterns That Hold Up

### 4.1 Position Save Callback

- Support both 4-arg and 5-arg callback signatures.
- Prefer saving from `frame:GetCenter()` relative to `UIParent:GetCenter()`.
- Only fallback to callback offsets when center is unavailable.

### 4.2 Drag Lifecycle

- During drag-end callback: save DB values only.
- Avoid full refresh calls that can reset/mutate drag state.
- If sidepanel values must update, use the framework’s safe refresh API only.

### 4.3 Exit Behavior

- On Edit Mode exit, apply stored offsets once.
- Ensure no secondary module reapplies stale defaults.

## 5) Castbar/Event Race Patterns

For cast systems under queue/spam load:

- Use active-cast identity tracking where safe.
- Revalidate real cast/channel state before hide on end events.
- Handle delayed/channel update events for timeline correction.
- Avoid direct secret-value comparisons (`castGUID`-style taint paths).

## 6) Regression-Hunt Workflow

When errors reappear after a fix:

1. Confirm clean repro path (single scenario).
2. Capture newest session ID only.
3. Group by signature and stack top.
4. Map each signature to one code path.
5. Patch root cause, not symptom suppression.
6. Re-test with same scenario and compare signatures.

## 7) Release Discipline (Portable)

For every release:

1. bump version metadata
2. add concise changelog entry with root cause + fix
3. commit + annotated tag
4. push branch + tag
5. build clean zip (exclude docs/dev/backup/test files)
6. publish GitHub release with addon zip asset
7. verify release page + asset + size + tag

Reference: [RELEASE_PROCESS.md](../RELEASE_PROCESS.md)

## 8) Cross-Project Adoption Checklist

Copy this checklist into the new addon repo:

- [ ] Add BugSack session-based analysis procedure
- [ ] Add taint-safe coding rules for secret values
- [ ] Add Edit Mode callback normalization pattern
- [ ] Add release checklist with asset verification
- [ ] Add triage template (signature/source/verdict)
- [ ] Add “known anti-patterns” list (forbidden writes/method replacement)

## 9) Anti-Patterns To Avoid

- Using BugGrabber `counter` as the KPI for fix success.
- Calling protected Edit Mode internals directly from addon slash commands.
- Comparing potential secret values directly in hot paths.
- Refreshing or re-layouting secure Blizzard viewers inside unstable frame states.

## 10) Recommended Docs Bundle For New Repo

If you want the same documentation shape in a new project, copy:

- this guide
- [BUGSACKER_ANALYSIS_GUIDE.md](../BUGSACKER_ANALYSIS_GUIDE.md)
- [DEVELOPMENT_PRINCIPLES.md](../DEVELOPMENT_PRINCIPLES.md)
- [RELEASE_PROCESS.md](../RELEASE_PROCESS.md)
