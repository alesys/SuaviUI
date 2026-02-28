# SuaviUI Changelog

## [v0.3.7](https://github.com/alesys/SuaviUI/tree/v0.3.7) (2026-02-28)

### 🔧 Fix — Remaining CDM Taint (Sessions 4823–4824): Layout Methods on Pool Frames

#### Root Cause
- `cooldown_icons.lua: ApplySquareStyle` called `button:SetSize()`, `iconTexture:ClearAllPoints()` / `SetPoint()`, `swipeChild:ClearAllPoints()` / `SetPoint()` / `SetSize()`, and `child.DebuffBorder:SetScale()` on Blizzard CDM pool item frames from addon (insecure) context.
- Calling **any C++ layout method** (`SetSize`, `SetPoint`, `ClearAllPoints`, `SetScale`) on a Blizzard frame from addon context marks that frame **tainted at the C++ engine level**. When `secureexecuterange` (EditMode close, CDM settings drag-reorder, CinematicFrame hide) later accesses those frames, all Lua field reads fail — causing `isActive`, `pandemicEndTime`, `allowAvailableAlert`, `previousCooldownChargesCount`, `charges`, `spellID` to throw "secret value tainted by SuaviUI", and the module-local `wasOnGCDLookup` table to become a **forbidden table** (counter=276 in session 4824).
- Secondary issue: `buttonBorders[button] = CreateFrame("Frame", nil, button, ...)` created an addon-owned child frame inside the Blizzard CDM item frame's child list, also contaminating the frame's C++ child table.
- `SUI_extraActionButtonHolder:Hide()` (session 4823) was blocked because the `OnHide` `C_Timer.After(0)` callback could fire after the player entered combat lockdown.

#### Fix — [utils/cooldown_icons.lua]
- **`ApplySquareStyle`**: Removed all layout method calls on CDM item frames:
  - Removed `button:SetSize()` — icon buttons keep Blizzard's default dimensions.
  - Removed `iconTexture:ClearAllPoints()` and `SetPoint()` — only UV coordinates modified via `SetTexCoord(crop, …)` (safe texture-data op).
  - Removed swipe-child `ClearAllPoints()` and `SetPoint()` — kept `SetSwipeTexture(BASE_SQUARE_MASK)` only.
  - Removed `child.DebuffBorder:SetScale(1.7)` from `ProcessViewer`.
  - Changed `buttonBorders` parent from `button` (CDM item frame) to `UIParent`; anchored via `SetPoint` (safe — setting points on our own frame with a Blizzard anchor is fine).
- **`RestoreOriginalStyle`**: Same removals — `button:SetSize()`, `iconTexture:ClearAllPoints/SetPoint/SetSize`, swipe `ClearAllPoints/SetPoint/SetSize`. Kept `iconTexture:SetTexCoord(0,1,0,1)` and `SetSwipeTexture(6707800)`.
- **`ApplyNormalizedSizeToButton` / `RestoreOriginalSizeToButton`**: Fully disabled (no-ops). "Normalize Utility Size" suspended until a taint-safe approach exists.

#### Fix — [utils/sui_actionbars.lua]
- **`OnHide` deferred callback**: Added `if InCombatLockdown() then return end` guard inside the `C_Timer.After(0)` body. When the timer fires during combat lockdown, `:Hide()` on `SUI_extraActionButtonHolder` raises `ADDON_ACTION_BLOCKED`; the guard causes it to silently skip.

#### Session triage
- Session 4823: `SUI_extraActionButtonHolder:Hide()` ADDON_ACTION_BLOCKED (counter=3) — fixed.
- Session 4823: `pandemicEndTime` secret number `BuffIconCooldownViewer:565` (counter=3) — fixed.
- Session 4823: `EnableSpellRangeCheck bad argument` `CooldownViewer:706` (counter=6) — Blizzard pool edge case; no longer tainted.
- Session 4823: `wasOnGCDLookup = <forbidden table>` `CooldownViewer:877` (counter=272) — fixed.
- Session 4824: `isActive` secret boolean `BuffBarCooldownViewer:353` (counter=84, drag-reorder) — fixed.
- Session 4824: `ShouldBeShown` secret boolean `CooldownViewer:303` (counter=1, HideUIPanel) — fixed.
- Session 4824: `wasOnGCDLookup = <forbidden table>` (counter=276) + `LUA_WARNING` — fixed.

---

## [v0.3.6](https://github.com/alesys/SuaviUI/tree/v0.3.6) (2026-02-28)

### ✨ Feature — Draggable Quest & Dialog Windows

- **[utils/sui_qol.lua]** Quest windows (`QuestFrame`) and NPC dialog windows (`GossipFrame`) are now draggable and remember their last position. Enabled via **General & QoL → General → Quests → Draggable Quest Windows** (off by default).
  - Left-drag repositions the window; position is saved per-profile under `general.questWindowPosition` / `general.gossipWindowPosition`.
  - On each open, `C_Timer.After(0, ...)` restores the saved position after the UIPanel system finishes its own `SetPoint` calls, ensuring the saved position always wins.
  - Both frames remain clamped to screen.
- **[utils/suicore_main.lua]** Added `questWindowDraggable = false` AceDB default.
- **[utils/sui_options.lua]** Added **"Quests"** section header in the General tab (visually groups Auto Accept / Auto Turn-In / Shift Pause / Draggable Quest Windows together). Added **"Draggable Quest Windows"** checkbox with description.

### 🧹 Cleanup — Removed Redundant Lazy-Init Guards in Options

- **[utils/sui_options.lua]** Removed 18 `if db.general.key == nil then ... end` guards that were duplicating AceDB default values already defined in `suicore_main.lua`. AceDB guarantees defaults are applied before the options page opens, so the guards were dead code. Affected keys: `quickSalvage`, `mplusTeleportEnabled`, `keyTrackerEnabled`, `keyTrackerFontSize`, `skinBagIcons`, `bagIconBorderThickness`, `bagIconUseQualityBorderColor`, `bagIconBorderColor`, `showBagItemLevel`, `bagItemLevelFontSize/Font/FontOutline`, `bagItemLevelUseQualityColor`, `bagItemLevelTextColor`, `showBagItemLevelGlow`, `bagItemLevelGlowSize/Alpha/UseQualityColor/Color`, `debugMode`.

### 🔧 Fix — CDM Tracking Bars / Buff Icons Not Showing (USE_CUSTOM_BARS path)

#### Root Cause
- `USE_CUSTOM_BARS = true` (introduced v0.3.5) sets `BuffBarCooldownViewer:SetAlpha(0)` and drives bar display via a custom data pipeline: `UpdateCustomBarData() → FetchBuffBarData() → GetViewerCooldownIDs()`.
- `GetViewerCooldownIDs()` calls `CooldownViewerSettings:GetDataProvider():GetOrderedCooldownIDsForCategory(TrackedBar, true)`. Internally, `GetOrderedCooldownIDsForCategory` calls `self:GetOrderedCooldownIDs()` which first runs `CheckBuildDisplayData()`. If that function hasn't yet populated `self.displayData` (timing issue at addon load, or if `GetOrderedCooldownIDs()` returns `nil` unexpectedly), `ipairs(nil)` throws; the surrounding `pcall` in `GetViewerCooldownIDs` catches it silently and returns `{}`. The early-exit guard `if #cooldownIDs == 0 then return {} end` then causes all bars to be suppressed every 0.5s tick with no visible error.
- Secondary cause: even when IDs were returned, `FetchBuffBarData` only checked `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` — missing all target debuffs (DoTs like Moonfire). The phase-2 partial fix (target aura check + `linkedSpellID`) was added but the ID-list root cause remained.

#### Fix
- **[utils/sui_buffbar.lua] `FetchBuffBarData()`**: Replaced `GetViewerCooldownIDs()` as primary source with `viewer.itemFramePool:EnumerateActive()`. `BuffBarCooldownViewer` still runs while invisible (only `SetAlpha(0)`, not `Hide()`), so its item pool is live and already reflects exactly what Blizzard considers active — including DoTs on target, linked spell IDs, cooldown-based tracking, etc. Only falls back to `GetViewerCooldownIDs()` if the pool is unavailable or returns zero entries.
- **[utils/sui_buffbar.lua] `FetchBuffIconData()`**: Same fix for `BuffIconCooldownViewer` (TrackedBuff category / buff icon panel).
- Both functions retain the target-debuff aura pre-fetch (`C_UnitAuras.GetUnitAuras("target", "HARMFUL|PLAYER")`) and `linkedSpellID` matching from the phase-2 fix, as those are still needed to retrieve aura display data (duration, name, texture) for spells where the applied aura ID differs from the cast ID.



#### Root Cause (session 4796)
- `cooldown_icons.lua: ApplySquareStyle` iterated over the `GetRegions()` list of each Blizzard CDM icon item frame (children of `EssentialCooldownViewer`, `BuffIconCooldownViewer`, etc.) and, whenever it replaced the circular mask texture with the addon's square mask, it wrote a tracking flag directly onto the Blizzard region object: `region.__sui_set6707800 = true`.
- `RestoreOriginalStyle` read and cleared the same field: `if region.__sui_set6707800 then ... region.__sui_set6707800 = nil`.
- Writing **any** field from addon context onto a Blizzard-owned frame/region object taints that object. The tainted region is a child of the CDM item frame. When Blizzard's secure `CooldownViewerMixin:OnUpdate → RefreshData → SetPandemicAlertTriggerTime` chain later iterates over children of that item frame, it executes in contaminated context, causing:
  - `self.pandemicEndTime = pandemicEndTime` (CooldownViewer.lua:516) → field becomes a **secret number** on `BuffIconCooldownViewer` item frames (counter=1).
  - `self.pandemicStartTime = pandemicStartTime` (CooldownViewer.lua:515) → same result.
  - `wasOnGCDLookup[spellID]` (local `{}` table in CooldownViewer.lua:871) becomes a **forbidden table** in BugGrabber's error capture on `EssentialCooldownViewer` items (counter=202, fires every frame).
- Errors appeared post-cinematic because `CinematicFrame:OnHide → HideUIPanel → viewers:Show() → OnShow → RefreshLayout` was the trigger that caused `ProcessViewer` / `ApplySquareStyle` to re-run on freshly shown CDM viewers.

#### Fix
- **[cooldown_icons.lua]** Replaced both `region.__sui_set6707800` field writes with entries in a new module-level weak table `markedRegions = setmetatable({}, { __mode = "k" })` declared alongside `styledButtons` / `buttonBorders`.
  - `ApplySquareStyle`: `region.__sui_set6707800 = true` → `markedRegions[region] = true`
  - `RestoreOriginalStyle`: `if region.__sui_set6707800 ...` → `if markedRegions[region] ...`; `region.__sui_set6707800 = nil` → `markedRegions[region] = nil`
  - No Blizzard frame/region objects are written to; taint source eliminated.
- **[sui_actionbars.lua]** `OnShow` hook on the Blizzard extra-action / zone-ability frame (`blizzFrame:HookScript("OnShow", ...)`) was calling `holder:Show()` and `blizzFrame:Show()` directly inside the hook. When the show event fires from a secure call chain (`ExtraAbilityContainer:AddFrame → UpdateShownState → EditModeSystemTemplates:SetShown`), any direct named-frame method call from addon context is blocked. Wrapped both the show-content and no-content branches in `C_Timer.After(0, ...)`, mirroring the existing `OnHide` deferral fix.

#### Session triage
- Session 4796: `pandemicEndTime` secret number on `BuffIconCooldownViewer` (counter=1) — fixed above.
- Session 4796: `pandemicStartTime` secret number on `BuffIconCooldownViewer` (counter=1) — fixed above.
- Session 4796: `wasOnGCDLookup = <forbidden table>` on `EssentialCooldownViewer` (counter=202) — fixed above.
- Session 4797: `wasOnGCDLookup = <forbidden table>` on `EssentialCooldownViewer` (counter=204, triggered via `/toggleui`) — same root cause, fixed above.
- Session 4797: `CooldownViewer.lua:706 EnableSpellRangeCheck bad argument` (nil rangeCheckSpellID on UtilityCooldownViewer) — Blizzard pool lifecycle edge case; no SuaviUI in stack; no fix needed.
- Session 4803: `[ADDON_ACTION_BLOCKED] SUI_extraActionButtonHolder:Show()` (triggered by boss extra-action button appearing) — fixed above.
- Session 4809: `allowAvailableAlert` secret boolean on `EssentialCooldownViewer` (Edit Mode slider, counter=1) — same region taint root cause, fixed above.
- Session 4810: `[ADDON_ACTION_FORBIDDEN] TargetUnit()` and `CompactUnitFrame oldR/maxHealth` secret numbers (Edit Mode exit) — execution-context taint propagated from CDM icon region writes; fixed above.
- Session 4811: `DamageMeterSessionWindow.lua:871 durationSeconds secret number` + `DamageMeterEntry.lua:86 text secret string` (counter=175) — `Blizzard_DamageMeter` reached by secondary taint; same root cause (`region.__sui_set6707800`), fixed above. Session was played before v0.3.6 deployed.
- Session 4811: `CooldownViewerItemData.lua:122/200 spellID`, `TableUtil.lua:82 item`, `CooldownViewer.lua:415/986 spellID/charges`, `CooldownViewerItemData.lua:419 hasTotem` — new CDM code paths (totem cache, aura tracking, charge cache, linked spell lookup) contaminated by same taint source; fixed above.
- Session 4796: `isActive` secret boolean on `BuffBarCooldownViewer` (counter=63) — residual counter, root cause eliminated in v0.3.5 (`USE_CUSTOM_BARS = true`); counter will reset on next log.
- Sessions 4782/4783: `AutoTurnIn IsArtifactRelicItem` nil — third-party addon using removed API; not SuaviUI.
- Sessions 4759: Baganator/Syndicator missing — third-party addon install issue; not SuaviUI.
- Sessions 4805: QuestTools errors — third-party addon; not SuaviUI.

## [v0.3.5](https://github.com/alesys/SuaviUI/tree/v0.3.5) (2026-02-26)

### 🛡️ Execution-Context Taint Fix — GetScaledRect & Mouseover Hook Guards

#### Root Cause (sessions 4761–4766)
- `sui_ncdm.lua: ApplyGetScaledRectHook` replaced `viewer.GetScaledRect` with an addon-owned closure (`viewer.GetScaledRect = function(self) ... originalGetScaledRect(self) ... end`).
- Assigning an addon closure to a Blizzard frame method field taints that field. When Blizzard's EditMode/CDM layout machinery calls `viewer:GetScaledRect()` it executes the addon closure in **tainted execution context**. The closure then calls `originalGetScaledRect(self)` (Blizzard secure code) **from inside that tainted context**, which propagates execution taint into the full `CooldownViewer.RefreshData → RefreshLayout` chain.
- This caused: `hasTotem`, `isActive`, `charges`, `previousCooldownChargesCount` secret values + `attempted to index a forbidden table` in sessions 4761–4766.

#### Root Cause (sessions 4767–4768)
- Three hook-guard flags were still written directly to Blizzard frame/texture objects:
  - `frame._quiMouseoverHooked = true` — written to `BuffBarCooldownViewer`, `BuffIconCooldownViewer`, `EssentialCooldownViewer`, `UtilityCooldownViewer` and **all collected icon/item child frames** via `HookFrameForMouseover`.
  - `region.__SUI_OverlayShowHooked = true` — written to overlay texture regions on CDM icon frames.
  - `texture.__quiAtlasBlocked = true` — written to border textures on CDM icon frames.
- Writing `_quiMouseoverHooked` directly to CDM item frames taints those frame tables. When Blizzard reads `frame.isActive` on a tainted item frame it gets "secret boolean tainted by SuaviUI" — session 4767–4768 `CooldownViewer.lua:353`.

#### Fix
- **[sui_ncdm.lua]** Removed the `viewer.GetScaledRect = function(self) ... end` method body from `ApplyGetScaledRectHook`. Now a no-op; the nil-rect crash it guarded was eliminated in v0.3.3 by the `Runtime.isInEditMode` guard in `IsReady()`.
- **[sui_ncdm.lua]** Replaced all three direct frame/texture field writes with module-level weak tables: `mouseoverHookedFrames`, `overlayShowHookedRegions`, `atlasBlockedTextures` — declared at the top of the file alongside `scaledRectHookedViewers`.
- **[sui_buffbar.lua]** Set `USE_CUSTOM_BARS = true`. The legacy `false` path wrote `BuffBarCooldownViewer.isHorizontal` / `.layoutFramesGoingRight` / `.layoutFramesGoingUp` directly to the Blizzard viewer frame, and called `ApplyBarStyle` on Blizzard's pool item frames from addon context. Writing those fields taints the viewer object; when Blizzard's `RefreshLayout → ReleaseAll → resetFunc → SetIsActive` subsequently runs, it executes in tainted context and `frame.isActive` becomes a "secret boolean tainted by SuaviUI" (session 4772). Custom bars (`SuaviBuffBar*`) are owned by SuaviUI — no Blizzard frame field writes. Blizzard's viewer is hidden via `SetAlpha(0)` only.

#### Session triage
- Sessions 4761, 4765, 4766: GetScaledRect execution-context taint — fixed by method removal above.
- Sessions 4767–4768: `isActive` secret boolean on `BuffBarCooldownViewer` items (first vector) — fixed by `mouseoverHookedFrames` table above.
- Session 4772: `isActive` secret boolean on `BuffBarCooldownViewer` items (second, persistent vector) — fixed by `USE_CUSTOM_BARS = true` above.
- Sessions 4740, 4749: `RegisterCallback` errors in `sui_bag_itemlevel.lua` — fixed in a prior edit.
- Session 4766 `ADDON_ACTION_BLOCKED` on `SUI_extraActionButtonHolder:Hide()` — fixed in `sui_actionbars.lua` via `C_Timer.After(0, …)` deferral.

## [v0.3.3](https://github.com/alesys/SuaviUI/tree/v0.3.3) (2026-02-26)

### 🛡️ Taint Elimination, EditMode Drag Fix & Bag Item Level

#### ✨ New Features
- **[sui_bag_itemlevel.lua]** New module: item level overlays on equippable bag and bank items.
  - Displays scaled/upgraded item level using `GetDetailedItemLevelInfo` (accurate for crafted, upgraded, and mythic items).
  - Filters to equippable slot types only (armor, weapons, trinkets, rings, cloaks) — cosmetics and consumables ignored.
  - **Square icon skin**: removes icon masks, crops icons, adds black background texture and quality-colored border. Covers main bags, bank slots, and bank bag slots.
  - **Border controls**: thickness slider (1–5 px), quality-color sync toggle, custom border color picker.
  - **Text glow**: 8-direction halo using offset FontStrings at ARTWORK layer; supports size, opacity %, quality color sync, and custom color.
  - Full enable/disable toggle with clean reversal.
  - All options exposed under General → Bags & Items in the settings panel.

#### Fixed
- **[init.lua]** Hook guard flags (`_SUI_RefreshDataHooked`, `_SUI_OnEventHooked`, `_SUI_ItemEventsHooked`, `_SUI_OnUpdateHooked`) were written directly onto Blizzard's CooldownViewer frame tables. Any field write from addon context taints the entire frame table in WoW 12.x, causing Blizzard secure code to read all subsequent fields as "secret values tainted by SuaviUI". Replaced all four flags with module-level local tables.
- **[sui_ncdm.lua]** Same problem in `ApplyGetScaledRectHook`: `_SUI_GetScaledRectHooked` and `_SUI_lastRect` written directly to viewer frames. Replaced with `scaledRectHookedViewers` and `viewerLastRect` weak-keyed module-level tables.
- **[sui_ncdm.lua]** `NCDM.editModeHooked = true` was set before checking whether `EditModeSystemMixin` was available, silently blocking the PLAYER_LOGIN retry when the mixin wasn't loaded at file-load time. The hook then never installed, leaving the nil-rect crash path unprotected. Fixed by moving the flag assignment to inside the successful hook block.
- **[cooldownmanager.lua]** `Runtime.isInEditMode` was tracked but never consulted by `Runtime:IsReady()`. This allowed `ClearAllPoints()` to fire on CooldownViewer children while a frame was being dragged in EditMode, causing `UtilityCooldownViewer.Selection:GetRect()` to return nil and crashing `EditModeSystemTemplates.lua:603` (`GetScaledSelectionSides`). Added `if Runtime.isInEditMode then return false end` as the first check in `IsReady()`.

#### Session triage
- Session 4731: 1 error (`EditModeSystemTemplates.lua:603` nil arithmetic during EditMode drag) — fixed by #3 and #4 above.
- Sessions 4729, 4730, 4732: zero errors.
- Sessions 4727–4728 taint regressions traced to hook guard writes on viewer frames — fixed by #1 and #2 above.

## [v0.3.2](https://github.com/alesys/SuaviUI/tree/v0.3.2) (2026-02-16)

### 🛠️ Edit Mode + Stability Fixes

#### Fixed
- Fixed `/em` slash handling to avoid calling deprecated Edit Mode enter paths that could trigger protected-call/taint cascades.
- Fixed Skyriding Vigor Bar Edit Mode drag persistence (position now saves reliably after exiting Edit Mode).
- Fixed castbar secret-value taint caused by direct `castGUID` equality comparisons in cast-end handlers.
- Fixed aura refresh typo in Unit Frames options (`sui_UF` → `SUI_UF`) causing nil-index errors in settings UI.
- Reduced Blizzard UnitFrame taint risk by avoiding Player/secondary resource frame show/hide mutations while in Edit Mode.

#### Notes
- This release targets post-0.3.1 regressions found during Edit Mode and BugSack session triage (sessions 4691-4700).

## [v0.3.1](https://github.com/alesys/SuaviUI/tree/v0.3.1) (2026-02-15)

### 🎯 Castbar Queue/Spam Stability

#### Issue
- While spamming abilities (especially Single-Button Assistant), castbars could appear late or disappear mid-cast even when the cast completed successfully.

#### Root Cause
- Cast end events from a previous cast could arrive while a queued next cast was already active.
- Event handling lacked cast-level identity checks, allowing stale STOP/FAILED/INTERRUPTED events to hide the active bar.

#### Fix
- Added active cast GUID tracking in castbar runtime.
- Added stale-event guards for cast end events (`STOP`, `CHANNEL_STOP`, `FAILED`, `INTERRUPTED`, `EMPOWER_STOP`).
- Added pre-hide revalidation (`UnitCastingInfo` / `UnitChannelInfo`) to refresh instead of hiding when a new cast is already active.
- Added support for `UNIT_SPELLCAST_DELAYED` and `UNIT_SPELLCAST_CHANNEL_UPDATE` for better timing updates under queue pressure.

#### Result
- Castbar remains stable during normal spell queue behavior and high-frequency input spam.

## [v0.3.0](https://github.com/alesys/SuaviUI/tree/v0.3.0) (2026-02-15)

### 🔥 Critical Taint Resolution - CooldownViewer hasTotem

#### What Happened
- In combat, Blizzard CooldownViewer raised repeated `hasTotem` secret-value taint errors (`CooldownViewerItemData.lua:419`), attributed to SuaviUI execution context.
- During audit isolation, the issue reproduced in the CDM runtime subset and disappeared when a specific SuaviUI relayout path was removed.

#### Root Cause
- SuaviUI had a divergence from upstream CMC behavior in `cooldownmanager.lua`: when centered styling was disabled, `CooldownManager.ForceRefresh` called Blizzard viewer `RefreshLayout()` directly.
- That relayout invocation placed SuaviUI into a protected CooldownViewer update chain where secret-value taint could propagate (`hasTotem`).

#### Fix Applied
- Removed direct Blizzard `RefreshLayout` fallback from `CooldownManager.ForceRefresh`.
- Preserved CDM centering behavior while making centered-styling-off path a safe no-op in the CMC layer.
- Restored normal `utils.xml` load order after audit to avoid dependency-order regressions.

#### Validation
- Clean in single-file isolation (`cooldownmanager.lua` only).
- Clean in Group 1A1 (`cooldownmanager + cooldown_coordinator`).
- Clean in full Group 1 cooldown surface.
- Clean with full addon loadout enabled.

## [v0.2.9](https://github.com/alesys/SuaviUI/tree/v0.2.9) (2026-02-14 - DEVELOPMENT)

### 🔥 BREAKING CHANGE: LibOpenRaid Completely Removed

#### Architecture Change - Keystone System Redesigned
- **Removed:** Entire LibOpenRaid library (19,000+ lines of code)
- **Created:** New lightweight `sui_keystone_comm.lua` module (~280 lines)
- **Communication:** Now uses AceComm-3.0 (already embedded)
- **APIs Used:** Native Blizzard C_MythicPlus API instead of LibOpenRaid's complex querying
- **Backup:** LibOpenRaid kept in `libs/LibOpenRaid_BACKUP_v173_MODIFIED/` folder for reference

#### What Changed
- **Before:** Loaded entire OpenRaid library → Used `GetPlayerInformation.lua` → Called `HasPetSpells()` → Generated taint errors
- **After:** Lightweight keystone comm module → Direct Blizzard API calls → No taint source from library

#### Features Preserved
✅ Party keystone sharing  
✅ Keystone tracker display  
✅ M+ score fetching  
✅ All UI functionality identical  

#### Root Cause Eliminated
- **Source:** LibOpenRaid's `HasPetSpells()` calls during UNIT_AURA events  
- **Solution:** Custom module uses only safe Blizzard APIs (C_MythicPlus, C_PlayerInfo)
- **Result:** No more tainted data generated from library internals

#### Technical Details
- New module exports same interface as `openRaidLib`:
  - `GetKeystoneInfo(unitId)`
  - `GetAllKeystonesInfo()`
  - `RequestKeystoneDataFromParty()`
  - `RegisterCallback(module, event, callback)`
- Seamless drop-in replacement for `sui_key_tracker.lua`

#### Dependencies Audit
- Removed: LibOpenRaid (19,000 lines) + its internal event hooks
- Now using: AceComm-3.0 (already embedded in SuaviUI)
- Libary count: 19 → 18

#### Post-v0.2.9 Hotfixes: Critical Taint Source Elimination

#### CooldownViewer hasTotem Taint (Audit Matrix Resolution)
- **Symptom:** Repeated `CooldownViewerItemData.lua:419` (`hasTotem` secret boolean tainted by SuaviUI)
- **Isolation Result:** Reproduced in Group 1A1; disappeared when removing CDM `RefreshLayout` fallback invocation
- **Root Cause:** SuaviUI-only relayout path in `cooldownmanager.lua` (`v:RefreshLayout()` when centered styling is disabled), not present in upstream CMC flow
- **Fix:** Removed direct Blizzard `RefreshLayout` fallback from `CooldownManager.ForceRefresh`; module now no-ops when centered styling is off
- **Validation:** Clean in Group 1A1 (`cooldownmanager + coordinator`) and promoted to Group 1 full-surface retest

**ROOT CAUSE IDENTIFIED:**
1. **Reload/Crash Taint** - unprotected arithmetic/comparisons with secret-valued aura data ✅ FIXED
2. **Combat-Only Taint (hasTotem)** - unprotected unit API calls (UnitExists, UnitIsUnit, UnitGUID, UnitHasVehicleUI, UnitCanAttack) ✅ FIXED

**Critical Fixes Applied:**

1. **sui_customtrackers.lua** - GetSpellActiveInfo arithmetic protection
   - **Bug:** `local startSec = expiration - buffDuration` (unprotected secret value arithmetic)
   - **Fix:** Wrapped ALL arithmetic operations in pcall to prevent secret value contamination
   
2. **sui_buffbar.lua** - Aura data access protection (2 locations)
   - **Bug:** Comparing `auraData.duration > 0` outside pcall protection
   - **Fix:** Moved all data access operations inside pcall boundary
   
3. **sui_spellscanner.lua** - SpellScanner.IsSpellActive protection  
   - **Bug:** Comparing `auraData.expirationTime` outside pcall
   - **Fix:** Wrapped data access in pcall with safe result extraction
   
4. **resourcebars/* - CRITICAL unprotected secret access (4 locations)**
   - **SecondaryResourceBar.lua**: SOUL_FRAGMENTS and MAELSTROM_WEAPON (zero pcall!)
   - **Color.lua**: Void Meta aura comparison (unprotected)
   - **Abstract/Bar.lua**: MAELSTROM_WEAPON resource handling (unprotected)
   - **Fix:** Added pcall wrappers around ALL secret value access
   
5. **Protect unprotected unit API calls** (sui_rotationassist.lua, sui_unitframes.lua, sui_quicksalvage.lua, sui_inspect.lua)
   - **Root Cause FOUND:** Unit-related protected APIs return secret values during combat that cascade taint through Blizzard systems
   - **Critical Locations Fixed:**
     - sui_rotationassist.lua:349 - `UnitExists("target")` + `UnitCanAttack()` during SPELL_UPDATE_COOLDOWN event (reticle visibility)
     - sui_unitframes.lua:590-591 - `UnitIsUnit(unit, "pet")` + `UnitIsUnit(unit, "playerpet")` during color calculation
     - sui_unitframes.lua:249 - `UnitExists(unit)` in tooltip OnEnter (can trigger during combat mouseovers)
     - sui_quicksalvage.lua:562 - `UnitHasVehicleUI('player')` in tooltip modifier check
     - sui_inspect.lua:533 - `UnitGUID(unit)` during inspect frame updates
   - **Fix:** Wrapped ALL unit API calls in pcall() to prevent secret value taint cascade
   
**Technical Details:**
- pcall() protects the API CALL but NOT the returned data
- Secret values used outside pcall in arithmetic/comparisons = taint introduction
- Unit APIs (UnitExists, UnitIsUnit, UnitGUID, UnitCanAttack, UnitHasVehicleUI) return secret values during combat
- These secret values cascade taint through Blizzard's totem caching system
- Solution: Wrap ALL unit API calls in pcall, extract results safely

**Impact**:
- **Root taint sources eliminated:** 6 critical locations fixed
- **Expected error reduction:** 99%+ (hasTotem → near-zero, spellID → 0, isActive → 0, charges → 0)
- **Data integrity:** Maintained - all queries still functional, just protected

### ✅ Expected Impact
- **Taint Errors:** Virtually eliminated (99%+ reduction)
- **Performance:** Maintained (pcall overhead negligible)
- **Code Size:** Addon size unchanged
- **Compatibility:** 100% feature parity with v0.2.8

---

## [v0.2.8](https://github.com/alesys/SuaviUI/tree/v0.2.8) (2026-02-14 5:18 PM)

### 📦 Library Refresh - All Libraries Updated to Latest Pristine Versions

#### ⚠️ Breaking Change: LibOpenRaid Restored to Pristine v175
- **REMOVED all taint protection patches** from LibOpenRaid
- Restored to 100% upstream version from Details! addon
- Backed up modified v173 to `libs/LibOpenRaid_BACKUP_v173_MODIFIED/`
- **Expected Impact:** Taint errors will likely return (~1,000+ instances)
- **Reason:** Following proper library management - no direct library modifications

#### 📚 Library Updates Applied

**Core Libraries Updated:**
- **LibOpenRaid:** v173 (modified) → v175 (pristine from Details!)
- **LibSharedMedia-3.0:** r151 → r164 (from WeakAuras)
- **LibDualSpec-1.0:** r27 → r28 (from BigWigs)

**Libraries Added:**
- **AceConfig-3.0:** v3 (from AccWideUILayoutSelection)
- **AceDBOptions-3.0:** v15 (from AccWideUILayoutSelection)
- **LibSerialize:** r5 (from SenseiClassResourceBar)

**Already Up-to-Date (Verified):**
- AceAddon-3.0 r13, AceComm-3.0 r14, AceConsole-3.0 r7
- AceDB-3.0 r33, AceEvent-3.0 r4, AceLocale-3.0 r6
- CallbackHandler-1.0 r8, LibStub r2
- LibCustomGlow-1.0 r21, LibDBIcon-1.0 r55
- LibKeyBound-1.0 r126, LibDataBroker-1.1 r4
- LibDeflate 1.0.2-release

#### 📝 Code Policy Updates
- Added **Rule #7** to `.copilot-instructions.md`: **NEVER Modify External Library Code**
- Libraries must remain pristine for easy updates
- Use wrapper/patch files if fixes needed (e.g., `LibraryName_Patches.lua`)
- Document all patches in library folder

#### 🎯 Purpose of This Release
This is a **tester feedback release** to validate:
1. Impact of pristine libraries on real-world gameplay
2. Whether taint errors affect user experience significantly
3. Community feedback on error frequency vs functionality

**Total Libraries:** 19 (was 16)  
**Libraries Updated/Added:** 6

**Documentation:**
- See `docs/LIBRARY_AUDIT.md` for complete library inventory
- See `libs/LibOpenRaid/SUAVIUI_PATCHES.md` for historical patch documentation

### ⚠️ Known Issues - v0.2.8

- **Taint Errors:** 771+ "hasTotem secret value tainted by 'SuaviUI'" errors expected (from pristine LibOpenRaid v175)
  - These are cosmetic errors that appear in BugGrabber but should not affect gameplay
  - **Testers please report:** Error frequency, performance impact, whether they affect gameplay
  - Each error is a failed lua operation on tainted data (not an addon crash)

---

## [v0.2.7](https://github.com/alesys/SuaviUI/tree/v0.2.7) (2026-02-14 4:14 PM)

### 🔧 Critical Bug Fix - sui_key_tracker.lua Taint Source

#### Root Cause (Why v0.2.6 Didn't Work)
- **v0.2.6 Protected:** LibOpenRaid from tainting during combat ✅
- **v0.2.6 Missed:** sui_key_tracker.lua calling `C_Spell.GetSpellCooldown()` OUTSIDE combat
- **Result:** Error count increased 665→771 (+106) because SPELL_UPDATE_COOLDOWN fires constantly after combat ends

#### The Real Taint Path
```
SPELL_UPDATE_COOLDOWN (fires constantly post-combat) →
sui_key_tracker.lua handler (runs when NOT in combat) →
UpdateButtonCooldown() →
C_Spell.GetSpellCooldown(dungeonTeleportSpellID) [UNPROTECTED] →
Blizzard's internal cooldown code triggers →
Blizzard calls HasPetSpells() to refresh spell cache →
HasPetSpells() returns tainted value →
Blizzard stores tainted value in cache →
hasTotem becomes tainted →
ERROR: "hasTotem (a secret boolean value tainted by 'SuaviUI'"
```

#### Fixes Applied

1. **Wrap C_Spell.GetSpellCooldown with pcall()** (sui_key_tracker.lua:300)
   - Prevents triggering Blizzard's spell cache refresh
   - Safe fallback if call fails

2. **Add aggressive throttle to SPELL_UPDATE_COOLDOWN handler** (sui_key_tracker.lua:547-558)
   - Only updates cooldowns every 3 seconds (was: every event)
   - Reduces cache refresh triggers from 100s/minute to ~20/minute
   - Maintains functionality while minimizing taint opportunities

3. **Combat lockdown checks remain in place**
   - LibOpenRaid still blocked during combat (v0.2.6)
   - Key tracker blocks updates during combat
   - Combined protection for all scenarios

### 📊 Summary (Cumulative)
- **15 taint protection fixes** (secret API calls + LibOpenRaid guards + HasPetSpells + C_Spell.GetSpellCooldown)
- **7 low-level safety guards** (empty viewers)
- **6 debounce/throttle improvements** (layout hooks + SPELL_UPDATE_COOLDOWN)
- **1 optimization** (empty tracker bars)
- **Total: 29 targeted fixes**

---

## [v0.2.6](https://github.com/alesys/SuaviUI/tree/v0.2.6) (2026-02-14 4:01 PM)

### 🔧 Critical Bug Fixes - HasPetSpells() Taint Elimination

#### Root Cause Analysis
- **Problem:** `HasPetSpells()` returns secret/tainted values during combat that contaminate Blizzard's CooldownViewer cache
- **Impact:** 665+ "hasTotem secret value tainted" errors in BugGrabber, occurring during UNIT_PET events
- **Why v0.2.5 didn't work:** pcall() prevents errors when reading secret values, but does NOT remove taint from those values. Tainted data stored in LibOpenRaid's cache later causes Blizzard's RefreshTotemData() to fail

#### Implemented Fixes
1. **Guard HasPetSpells() calls with issecretvalue() checks** (LibOpenRaid/GetPlayerInformation.lua)
   - Lines 768-778: Added taint detection to first pet spell scanning loop
   - Lines 1265-1275: Added taint detection to second pet spell scanning loop  
   - Returns `nil` if HasPetSpells() returns a tainted value, preventing loop contamination

2. **Prevent spellbook scanning during combat** (LibOpenRaid/GetPlayerInformation.lua line 797)
   - Added `InCombatLockdown()` guard to `updateCooldownAvailableList()`
   - Prevents tainted values from being stored in `LIB_OPEN_RAID_PLAYERCOOLDOWNS` global table during combat

3. **Prevent cooldown updates during combat** (LibOpenRaid/LibOpenRaid.lua line 2581)
   - Added `InCombatLockdown()` guard to `OnPlayerPetChanged()`
   - Stops UNIT_PET event from triggering spellbook scans during combat

#### Technical Details
**Taint propagation path:**
```
UNIT_PET (combat) → OnPlayerPetChanged() → CheckCooldownChanges() →
GetPlayerCooldownList() → updateCooldownAvailableList() → 
getSpellListAsHashTableFromSpellBook() → HasPetSpells() [TAINTED] →
Loop iteration stores tainted data → Blizzard's cache contaminated →
GetTotemInfo() returns tainted hasTotem → RefreshTotemData() errors
```

**Solution:** Block the taint at source by:
- Detecting tainted HasPetSpells() return values and rejecting them
- Preventing LibOpenRaid from updating cooldown lists during combat
- Allowing cooldown updates only when out of combat (safe context)

### 📊 Summary (Cumulative)
- **7 low-level safety guards** (empty viewers)
- **15 taint protection fixes** (secret API calls + LibOpenRaid guards + HasPetSpells)
- **5 debounce/re-entry improvements** (layout hooks)
- **1 optimization** (empty tracker bars)
- **Total: 28 targeted fixes** for stability

---

## [v0.2.5](https://github.com/alesys/SuaviUI/tree/v0.2.5) (2026-02-14 3:12 PM)

### 🔧 Bug Fixes - Continued Taint Protection

#### LibOpenRaid Pet Query Protection
- **Fixed pet status checks causing "hasTotem secret value tainted" errors**
  - Wrapped `UNIT_PET` event handler in `pcall()` to protect `UnitIsUnit("player")`, `UnitHealth("pet")`, `UnitExists("pet")` calls
  - Wrapped `playerHasPetOfNpcId()` function in `pcall()` to protect `UnitExists("pet")` and `UnitGUID("pet")` calls in `GetPlayerInformation.lua`
  - Prevents LibOpenRaid from propagating tainted pet data to Blizzard's CooldownViewer cache during UNIT_PET combat events
  - Resolves 431+ repeated taint warnings in combat logs

#### Rotation Assist Spell Query Protection
- **Fixed UpdateIconDisplay() secret value taint during combat**
  - Wrapped `C_Spell.GetSpellTexture()`, `C_Spell.IsSpellUsable()`, `C_Spell.SpellHasRange()`, `C_Spell.IsSpellInRange()` calls in `pcall()`
  - Prevents SPELL_UPDATE_COOLDOWN event flooding from tainting spell usability checks
  - Maintains safe fallback behavior when pcall() fails (defaults: no texture, unusable, no range)

### 📊 Summary (Cumulative)
- **7 low-level safety guards** (empty viewers)
- **12 taint protection fixes** (secret API calls + LibOpenRaid + rotation assist)
- **5 debounce/re-entry improvements** (layout hooks)
- **1 optimization** (empty tracker bars)
- **Total: 25+ targeted fixes** for stability on low-level characters

---

## [v0.2.4](https://github.com/alesys/SuaviUI/tree/v0.2.4) (2026-02-14)

### 🔧 Bug Fixes & Performance

#### Low-Level Character Stability
- **Fixed UI freeze on level 11+ characters** with empty viewers (no Essential Cooldowns learned)
  - Added `__cdmEmpty` sentinel to prevent infinite layout loops when viewers have 0 children
  - Set initial tolerance values (`__cdmIconWidth=0`, `__cdmTotalHeight=0`) for OnSizeChanged short-circuit
  - Increased polling interval from 0.5s to 5s when viewer is empty (no work to do)
  - Prevents cascading OnSizeChanged → LayoutViewer → OnSizeChanged cycles

#### Taint Protection (Combat Stability)
- **Fixed Lua taint errors during combat** ("attempt to compare/test secret value tainted by SuaviUI")
  - Wrapped `C_Spell.GetSpellCooldown()` in `pcall()` in `GetSpellCooldownInfo()`
  - Wrapped `C_Spell.GetSpellCharges()` in `pcall()` in `GetSpellChargeCount()`
  - Wrapped `C_Spell.GetSpellInfo()` in `pcall()` in `IsSpellUsable()` and `GetCachedSpellInfo()`
  - Wrapped `C_Spell.GetSpellInfo()` in `pcall()` for keybind display fallback
  - Wrapped `C_UnitAuras.GetAuraDataByIndex()` in `pcall()` in `ScanSpellFromBuffs()`
  - Wrapped `GetShapeshiftFormID()` in `pcall()` in visibility check functions (3 locations)
  - Prevents secret values from contaminating Blizzard's CooldownViewer cache during combat

#### Layout Hook Improvements
- **Added re-entry guard on OnSizeChanged hook** in `suicore_main.lua`
  - Prevents infinite cascades: `OnSizeChanged → ApplyViewerLayout → SetSize → OnSizeChanged`
  - Uses `__cdmLayoutRunning` flag to stop re-entrance

#### Event Handler Optimization
- **Added debounce guards to Layout/RefreshLayout hooks** (5 files)
  - `customglows.lua`: Debounce OnSizeChanged → C_Timer pattern
  - `cooldownswipe.lua`: Debounce Layout → C_Timer pattern
  - `cooldownmanager.lua`: Debounce RefreshLayout → C_Timer pattern with pending flag
  - `cooldown_icons.lua`: Debounce RefreshLayout → C_Timer pattern
  - `cooldowneffects.lua`: Debounce Layout → C_Timer pattern
  - Solves timer flooding when Layout fires rapidly (no-op closures stack up without debounce)

#### Tracker Bar Optimization
- **Added early exit in DoUpdate() for empty tracker bars**
  - Skip per-icon work when `bar.activeIcons` is empty (level-up scenario)
  - Prevents wasted config reads + visibility checks on 0 icons

### 📊 Summary
- **7 low-level safety guards** (empty viewers)
- **9 taint protection fixes** (secret API calls)
- **5 debounce/re-entry improvements** (layout hooks)
- **1 optimization** (empty tracker bars)
- **Total: 22 targeted fixes** for stability on low-level characters

### ✅ Testing Notes
- Verified no Lua errors (`error.log` clean)
- Tested on level 11 Warlock (no freeze, responsive UI)
- Tested on level 80 (no behavior changes from 0.2.3)
- Combat event handling verified (no taint errors on UNIT_AURA, SPELL_UPDATE_COOLDOWN)

---

## [v0.2.3](https://github.com/alesys/SuaviUI/tree/v0.2.3) (2026-02-07)

- Initial Midnight (12.x) support
- CDM visibility controller improvements
- EditMode integration enhancements
