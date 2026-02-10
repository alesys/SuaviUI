# SuaviUI Session Handoff — February 2026 (Updated)

## CRITICAL: Read This First
This document captures the full state of an ongoing debugging and refactoring session for the SuaviUI WoW addon. Use it as context when resuming in a new conversation. The assistant should read the relevant source files referenced below to re-establish working context.

---

## 1. Project Overview
- **Addon:** SuaviUI — a World of Warcraft retail (12.x) UI customization addon
- **Path:** `e:\Games\World of Warcraft\_retail_\Interface\AddOns\SuaviUI\`
- **Related addons in workspace:** SenseiClassResourceBar, AccWideUILayoutSelection, CooldownManagerCentered
- **Core problem:** SuaviUI hooks into Blizzard frames in ways that propagate **taint**, causing "secret value" crashes in Blizzard's protected code

## 2. WoW Taint/Secret Value Model (Essential Background)
- WoW 12.x introduced **secret values** — values from secure code that cannot be read/compared in insecure (addon) code
- `hooksecurefunc()` + insecure `:Hide()` on protected frames contaminates the frame's environment
- Once tainted, downstream secure code (e.g. `CompactUnitFrame_UpdateInRange`) reads `outOfRange` which is now a "secret value" and crashes
- `secureexecuterange` is a C-level dispatch that bypasses Lua global replacements — pcall on Lua globals doesn't help
- `issecretvalue(val)` can detect secret values without crashing
- `RegisterStateDriver(frame, "visibility", "hide")` is a taint-free alternative to hooksecurefunc+Hide
- **CRITICAL LESSON:** Replacing secure global functions (`CompactUnitFrame_UpdateHealPrediction`, `CompactUnitFrame_GetRangeAlpha`, `C_NamePlateManager.SetNamePlateHitTestFrame`) with insecure Lua wrappers TAINTS the global environment, causing cascading failures (5793+ TextStatusBar crashes, 9+ nameplate errors). These guards were REMOVED.

## 3. Strategy: Option B + Option C

### Option B: Eliminate Taint Sources (ALL IMPLEMENTED, VERIFIED CLEAN)
1. **CompactRaidFrameManager** (`utils/uihider.lua`): Replaced `hooksecurefunc(CompactRaidFrameManager, "Show")` + insecure Hide with `RegisterStateDriver(CompactRaidFrameManager, "visibility", "hide")`. This was THE primary taint source.
2. **outOfRange pre-clear** (`init.lua` ~L96-135): Named `ClearTaintedOutOfRange()`. Clears `outOfRange = false` on `CompactPartyFrameMember1-5` AND `CompactArenaFrameMember1-5` using `issecretvalue()` with pcall fallback. Hooks: `EditModeManagerFrame:EnterEditMode`, `GROUP_ROSTER_UPDATE`, `PLAYER_ENTERING_WORLD`, `ARENA_OPPONENT_UPDATE`.
3. **REMOVED guards (critical):** Three global function replacements were removed because they tainted the global environment:
   - `CompactUnitFrame_UpdateHealPrediction` wrapper — REMOVED
   - `CompactUnitFrame_GetRangeAlpha` wrapper — REMOVED
   - `C_NamePlateManager.SetNamePlateHitTestFrame` wrapper — REMOVED (caused 5793x TextStatusBar crashes)

### Option C Phase 1: Custom BuffBar Container (IMPLEMENTED)
- Feature flag: `USE_CUSTOM_BARS = true` in sui_buffbar.lua
- Custom bars parented to UIParent, anchored to BuffBarCooldownViewer
- Data pipeline: `C_CooldownViewer.GetCooldownInfoByCooldownID()` -> `C_UnitAuras.GetPlayerAuraBySpellID()` -> custom Frame pool
- Viewer hidden (alpha=0, mouse disabled); shown during Edit Mode for positioning
- Container OnUpdate: 20 FPS animation + 2 FPS data refresh
- UNIT_AURA event: immediate data reconciliation with debounce

### Option C Phase 2: Custom BuffIcon Container (IMPLEMENTED)
- Feature flag: `USE_CUSTOM_ICONS = true` in sui_buffbar.lua
- Same pattern as BuffBar: custom icon frames parented to UIParent, anchored to BuffIconCooldownViewer
- Data pipeline: Same as bars (C_CooldownViewer + C_UnitAuras)
- Icon frames compatible with `ApplyIconStyle()` (have `.Icon`, `.Cooldown`, `.Applications`)
- `_buffSetup = true` to skip Blizzard-specific mask/overlay removal
- Cooldown swipe handled natively by `CooldownFrameTemplate`
- Stack count via Applications FontString
- Container OnUpdate: 2 FPS data refresh (no animation needed)
- UNIT_AURA: immediate data reconciliation
- Edit Mode: same show/hide pattern as bars
- Legacy icon hooks (OnUpdate polling, OnSizeChanged, OnShow, Layout, UNIT_AURA) wrapped in `if not USE_CUSTOM_ICONS`

### Option C Phase 3: Essential + Utility Viewers — DEFERRED
- **Not implemented because:** No errors from these viewers in recent logs. Root cause (RegisterStateDriver) eliminated taint. CDM crash recovery in init.lua still active as safety net.
- **If needed later:** Follow same custom container pattern but in cooldownmanager.lua. More complex due to multi-row layouts, square icon styling, font styling, dim-when-not-on-CD.

## 4. Current Error Status (Latest Post-Fix Testing)

### RESOLVED:
- checkedRange secret value on Party frames — outOfRange pre-clear
- checkedRange secret value on Arena frames — extended to CompactArenaFrameMember1-5
- TextStatusBar attempt to compare a secret value (5793x) — caused by our global wrappers, REMOVED
- SetNamePlateHitTestFrame bad argument (9x from our wrapper) — wrapper REMOVED

### REMAINING (NOT OUR BUGS):
- Platynator `GetImportantAuras` (15x) — Platynator addon bug
- Blizzard `SetNamePlateHitTestFrame` bad argument (4x) — Blizzard login race, harmless

### NEEDS IN-GAME VERIFICATION:
- Custom BuffBar rendering (Phase 1) — bars actually display?
- Custom BuffIcon rendering (Phase 2) — icons actually display?
- Does `C_CooldownViewer.GetCooldownViewerCooldownInfo()` return data when viewer is alpha=0?
- Edit Mode positioning for both viewers

## 5. Key Files and Their Current State

### `init.lua` (~509 lines)
- L1-79: Addon init, namespace, slash commands, EncounterWarnings fix
- L80-95: REMOVED guards comment (explains why HealPrediction/RangeAlpha/NamePlate wrappers were removed)
- L96-135: `ClearTaintedOutOfRange()` — covers both Party + Arena frames
- L137+: CDM crash recovery system (SanitizeFrame, RecoverViewer, HookViewer*, combat recovery ticker)

### `utils/uihider.lua` (~605 lines)
- CompactRaidFrameManager section: RegisterStateDriver approach (root fix)

### `utils/sui_buffbar.lua` (~2400+ lines)
- L1-158: Header, helpers, DB access, GetTrackedBarSettings
- L159-403: Custom BuffBar infrastructure (USE_CUSTOM_BARS flag, container, pool, data pipeline, progress animation, viewer hiding)
- L404-590: Custom BuffIcon infrastructure (USE_CUSTOM_ICONS flag, container, pool, data pipeline, cooldown overlay, stack count, icon viewer hiding)
- L591-700: Frame collection (GetBuffIconFrames, GetBuffBarFrames — both return custom frames when flags are on)
- L700-1185: Icon/bar styling (ApplyIconStyle, ApplyBarStyle — work for both custom and legacy frames)
- L1186-1360: LayoutBuffIcons — custom path at top, legacy path below
- L1360-1540: LayoutBuffBars — custom path at top, legacy path below
- L1540-1830: Change detection (CheckIconChanges, CheckBarChanges — both handle custom paths)
- L1830+: Initialize — custom bar init, custom icon init, legacy hooks wrapped in `if not USE_CUSTOM_*`
- Public API, Refresh, feature flag exposure at bottom

### `utils/cooldownmanager.lua` (~931 lines)
- `ViewerAdapters.GetBuffBarFrames()`: Returns `{}` when `ns.BuffBar.USE_CUSTOM_BARS`
- `ViewerAdapters.UpdateBuffBarsIfNeeded()`: Early returns when custom bars active
- `ViewerAdapters.GetBuffIconFrames()`: Returns `{}` when `ns.BuffBar.USE_CUSTOM_ICONS`
- `ViewerAdapters.UpdateBuffIcons()`: Early returns when custom icons active

## 6. Feature Flags (Instant Rollback)
```lua
-- In sui_buffbar.lua:
local USE_CUSTOM_BARS = true    -- Set false to revert BuffBar to legacy
local USE_CUSTOM_ICONS = true   -- Set false to revert BuffIcon to legacy

-- Exposed for external access:
SUI_BuffBar.USE_CUSTOM_BARS = USE_CUSTOM_BARS
SUI_BuffBar.USE_CUSTOM_ICONS = USE_CUSTOM_ICONS
```

## 7. Testing Checklist
- [ ] /reload and check error.log — should be clean (only Platynator + Blizzard nameplate race)
- [ ] Enter and exit Edit Mode — no errors
- [ ] Verify custom buff BARS render, animate, update on aura gain/loss
- [ ] Verify custom buff ICONS render, show cooldown swipe, update on aura gain/loss
- [ ] Edit Mode positioning works for both viewers
- [ ] Stack count displays correctly on icons with multiple applications
- [ ] CDM settings changes (bar height, icon size, etc.) still apply via Refresh

## 8. Key Insight: Why Global Function Replacement = Bad
The single most impactful lesson from this debugging:
- `RegisterStateDriver` is the ONLY safe way to hide secure frames
- Replacing ANY secure global function (even with pcall wrapping) taints the global table
- Taint cascades through ANY code that reads from the tainted environment
- This caused 5793+ nameplate health bar crashes from a "harmless" pcall wrapper
- The fix is always: find the root taint source and eliminate it with secure APIs

## 9. Previous Session Fixes (Already Done, For Reference)
- Dropdown menu clipping fixes (sui_gui.lua, sui_options.lua)
- Profile dropdown refresh system (sui_options.lua)
- Tracked bar Edit Mode sizing fix (sui_buffbar.lua)
- Initial guards approach (superseded by Option B)
