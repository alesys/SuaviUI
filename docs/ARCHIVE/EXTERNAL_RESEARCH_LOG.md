# External Research Log

## 2026-02-28 — CooldownManagerCentered + wow-ui-source

### Scope
- Read-only review only.
- No file changes were made inside:
  - `CooldownManagerCentered/`
  - `wow-ui-source/`

---

## 1) CooldownManagerCentered (workspace copy)

### What appears new
- `CHANGELOG.md` top entry:
  - `v2.1.5 disable gcd on tracker & fix keybind "-"`

### Relevant code observations
- Addon version is `2.1.5` in `CooldownManagerCentered.toc`.
- Tracker visual cooldown logic skips GCD-only states by checking `C_Spell.GetSpellCooldown(spellID).isOnGCD` before applying swipe updates:
  - `modules/Tracker/TrackerItemVisuals.lua`
- Utility dimming logic also special-cases GCD and uses cached cooldown duration objects:
  - `modules/cooldownManager.lua`
  - `modules/onCooldownTracker.lua`
- Keybind formatter explicitly handles minus variants (`NUMPAD MINUS` -> `N-`) and key normalization:
  - `modules/keybinds.lua`

### Practical takeaway for SuaviUI
- If tracker/cooldown visuals must avoid GCD noise, guard with `isOnGCD` before deciding display state.
- Keybind formatting should normalize minus keys explicitly (including numpad) to avoid display regressions.

---

## 2) wow-ui-source (git repo, updated to 12.0.1)

### Repo state checked
- Branch head: `12.0.1 (66192)`
- Diff inspected: `12.0.0..HEAD`

### Blizzard files changed (relevant)
- `Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua`
- `Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerItemData.lua`
- `Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerAlert.lua`
- `Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerSettingsAlerts.lua`
- `Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerSettingsDataStoreSerialization.lua`
- `Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua`

### High-signal behavior deltas
- CooldownViewer now routes aura-added updates through full aura payload and filters by source unit (`player`) in `NeedsAddedAuraUpdate` path.
- Totem handling was refactored:
  - Preferred totem slot tracking.
  - Shared totem cache (`GetCurrentPlayerTotemCache`) with dirty-mark helper.
  - `RefreshTotemData` invoked in more refresh paths.
- Aura alert triggers expanded:
  - Added explicit aura applied/removed alert trigger checks.
- `SetIsActive` logic simplified to only mutate when state actually changes.
- EditMode templates got broader system-setting handling updates (especially Encounter Events and Damage Meter paths).

### Practical takeaway for SuaviUI
- CDM internals are still evolving in 12.0.1; assumptions based on older event payloads are fragile.
- Prefer C APIs and transient local variables over writing custom state onto Blizzard CDM item frames.
- Keep EditMode exit handling resilient (deferred refresh / event fallback) because upstream setting pipelines changed and trigger additional layout churn.

---

## 3) Suggested rules for future SuaviUI CDM work

1. Do not add custom fields on Blizzard CDM item frames or textures.
2. Avoid frame layout mutations on Blizzard-managed CDM pool items where possible.
3. Treat GCD-only cooldown states as optional display (feature toggle), not as normal active cooldowns.
4. If custom replacements are empty, fail safe to Blizzard viewer with mouse behavior preserved.
5. After each CDM/EditMode change, validate with:
   - enter Edit Mode
   - reorder/drag CDM entries
   - exit Edit Mode
   - target swap
   - leave/enter combat

---

## 2026-03-01 — Latest log triage (session 4848)

### High-signal error
- `[ADDON_ACTION_BLOCKED] AddOn 'SuaviUI' tried to call protected function 'UIParentRightManagedFrameContainer:ClearAllPoints()'`
- Stack path includes:
  - `UIParentManageRightFrameContainer`
  - `UIParentManageFramePositions`
  - `EditModeManager:UpdateActionBarLayout`
  - `StanceBar:UpdateState`

### Related historical signal
- Earlier blocked-call stack in same troubleshooting window showed:
  - `SUI_extraActionButtonHolder:Show()`
  - from `utils/sui_actionbars.lua` line around deferred `OnShow` mirror logic
  - triggered via Blizzard Extra Ability container action-bar update path.

### Mitigation applied in SuaviUI
- `utils/sui_actionbars.lua`
  - Added a hard safety gate to disable extra action/zone ability holder customization code paths that reparent/reposition Blizzard frames and hook SetPoint/Show flows.
- `utils/uihider.lua`
  - Objective tracker + status tracking hide-on-show hooks now defer `Hide()` via `C_Timer.After(0)` and skip forced hides while Edit Mode is currently shown.
- `utils/sui_unitframes.lua`
  - Removed direct `EditModeManagerFrame:SaveLayoutChanges()` call from custom exit button flow; now exits Edit Mode via deferred slash command call.

### Why this direction
- All three changes reduce addon participation in sensitive Edit Mode / managed-frame layout call chains where protected `SetAttribute`-driven layout updates occur.
- Chosen intentionally as a stability-first patch set (feature-risk reduction over behavior expansion).

---

## 2026-03-02 — Follow-up on tracked bars/buff bar still empty

### New finding (wow-ui-source aligned)
- In updated Blizzard CDM data provider flow, category-set reads are built around:
  - `C_CooldownViewer.GetCooldownViewerCategorySet(...)`
  - `CooldownViewerSettingsDataProviderMixin:CheckBuildDisplayData()`
- SuaviUI fallback path in `sui_buffbar.lua` was still using legacy `GetCooldownIDsForCategory(...)` only.
- Result: when provider read failed/timed out early, fallback could return `{}` and custom tracked bars/icons stayed empty.

### Patch applied
- Updated both ID readers in `utils/sui_buffbar.lua`:
  - `GetViewerCooldownIDs()` (TrackedBar)
  - `GetIconViewerCooldownIDs()` (TrackedBuff)
- Behavior now:
  1. Call provider `CheckBuildDisplayData()` before provider reads.
  2. Keep provider ordered-ID path as primary.
  3. Fallback to `C_CooldownViewer.GetCooldownViewerCategorySet(...)` (new API).
  4. Keep legacy `GetCooldownIDsForCategory(...)` as compatibility fallback only.

### Expected impact
- Prevents empty-ID fallback on current client builds and restores custom tracked bar / buff icon data population when provider timing is inconsistent.

---

## 2026-03-03 - Cross-check refresh against local wow-ui-source + CMC

### Scope
- Read-only review only.
- Paths reviewed:
  - `C:\Users\rolf\Documents\WOWLibs\wow-ui-source`
  - `E:\Games\World of Warcraft\_retail_\Interface\AddOns\CooldownManagerCentered`

### Version state observed
- `wow-ui-source/version.txt`: `12.0.1.66220`
- `CooldownManagerCentered.toc`: `Version: 2.1.7`

### High-signal findings

1. `CooldownManagerCentered` still contains taint-prone frame/region writes on Blizzard CDM objects:
   - `modules/styled.lua:147` writes `region.__wt_set6707800 = true`
   - `modules/styled.lua:209` reads that field back
   - `modules/cooldownManager.lua:181,224` writes `child._wt_isHooked = true` / `frame._wt_isHooked = true`
   These are the same anti-pattern class that previously caused SuaviUI CDM taint regressions.

2. Blizzard CDM internals in `wow-ui-source` still match the known taint blast points:
   - `CooldownViewer.lua:352-355` (`SetIsActive`)
   - `CooldownViewer.lua:513-516` (`pandemicStartTime` / `pandemicEndTime` writes)
   - `CooldownViewer.lua:871-880` (`wasOnGCDLookup` path)
   - `CooldownViewerItemData.lua:418-419` (`GetTotemInfo` -> `hasTotem`)
   - `CooldownViewer.lua:1766+` (`RefreshLayout`, including `itemContainerFrame.isHorizontal` and layout flags)

3. This validates SuaviUI's current "no field writes on Blizzard CDM frames/regions" direction and the move away from provider-driven ID building in custom buff/icon data paths.

### Documentation correction from previous note (2026-03-02)
- The previous recommendation to call provider `CheckBuildDisplayData()`/ordered-provider paths should now be treated as superseded for SuaviUI's custom buff/icon data flow.
- Current SuaviUI policy (implemented in `utils/sui_buffbar.lua`) is:
  - Prefer C APIs (`C_CooldownViewer.GetCooldownViewerCategorySet` / legacy fallback),
  - Avoid provider mutation/build calls from addon context in this path.

### Practical takeaway for SuaviUI
- Keep CMC as an algorithm reference only (layout math), not as a taint-safety reference for CDM object state tagging.
- Continue treating these as hard rules:
  1. No custom fields on Blizzard CDM frames.
  2. No custom fields on Blizzard CDM regions/textures.
  3. No addon closure assignment to Blizzard frame methods (e.g., `viewer.GetScaledRect = function ... end`).

