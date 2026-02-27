# BugGrabber Error Log Analysis Guide

## ⚠️ CRITICAL UNDERSTANDING: Counter Does NOT Mean Total

**Location:** `e:\Games\World of Warcraft\_retail_\WTF\Account\SYSELA\SavedVariables\!BugGrabber.lua`

### What the Counter Really Means

```lua
["counter"] = 9912  -- This is NOT the total error occurrences
```

**The `counter` field shows HOW MANY TIMES that SPECIFIC error message appeared SINCE IT WAS FIRST SEEN.**

### Key Points

- **Counter increments CONTINUOUSLY** as the game runs
- **Each unique error message gets its own counter**
- **Running the game for hours will cause counters to increase dramatically**
- **Comparing counters across sessions is MEANINGLESS**
- **The counter NEVER resets** unless you manually delete the BugGrabber log

### How to Properly Evaluate Improvements

❌ **WRONG:** "We went from 9,912 errors to 61 errors - 99% improvement!"
- This is comparing counter values from different sessions
- Both sessions may have been running different amounts of time
- Counters accumulate indefinitely

✅ **RIGHT:** "Session 4612 has ONLY THIS ERROR appearing, no other error types"
- Check error TYPE diversity, not counter values
- Look for completely ELIMINATED error types
- Observe which unique errors exist in current session

### What Changed Between v0.2.8 → v0.2.9

**Before (with LibOpenRaid):**
- Multiple error types: "hasTotem", "spellID", "charges"
- Many unique Blizzard files throwing errors

**After (LibOpenRaid removed):**
- Only ONE error type remaining: "hasTotem" 
- Single source: CooldownViewerItemData.lua:419
- All other error categories eliminated

### Proper Analysis Method

1. **Count unique error TYPES** (not counters)
   - Session 4604-4609: 3+ error types
   - Session 4612: 1 error type ✓

2. **Identify error SOURCE files** (not counter values)
   - Session 4604-4609: Multiple Blizzard files throwing errors
   - Session 4612: Only CooldownViewerItemData.lua ✓

3. **Check time since session started**
   - Don't compare raw counter values across sessions
   - A 24-hour session will have much higher counters than a 1-hour session

### Resume Analysis

The 61-error session 4612 is actually **EXCELLENT** because:
- ✅ "spellID" errors GONE
- ✅ "charges" errors GONE  
- ✅ Multiple error sources ELIMINATED
- ✅ Only ONE error type remaining from ONE source
- ⚠️ Single hasTotem error source still exists (investigating further)

---

### Sessions 4761–4766 — Execution-Context Taint Regression

**Observed (2026-02-26, sessions 4761–4766):**
- `CooldownViewerItemData.lua:419` — `hasTotem` secret boolean tainted by SuaviUI
- `CooldownViewer.lua:353` — `isActive` secret boolean tainted by SuaviUI
- `CooldownViewer.lua:877` — `attempted to index a forbidden table`
- `CooldownViewer.lua:880` — secret number comparison
- `CooldownViewer.lua:968` — `previousCooldownChargesCount` secret number tainted
- `CooldownViewer.lua:986` — `charges` secret number tainted

**Root cause identified:**
`sui_ncdm.lua: ApplyGetScaledRectHook` was replacing `viewer.GetScaledRect` with an addon-owned closure. Assigning any addon closure to a Blizzard frame method field taints that field. When Blizzard's layout machinery calls `viewer:GetScaledRect()`, it runs the addon closure in **tainted execution context**, which then calls `originalGetScaledRect(self)` (Blizzard secure code) from inside that tainted context — propagating execution taint through the entire `RefreshData → RefreshLayout` chain.

**Fix applied (v0.3.4):**
Removed the `viewer.GetScaledRect = function(self) ... end` method body from `ApplyGetScaledRectHook`. The nil-rect crash scenario this guarded was already eliminated in v0.3.3.

---

### Sessions 4767–4768 — BuffBarCooldownViewer item isActive taint

**Observed (2026-02-26, sessions 4767–4768):**
- `CooldownViewer.lua:353` — `isActive` secret boolean tainted by SuaviUI (counter 45+)
- Stack: `SetIsActive ← RefreshActive ← RefreshData ← ClearCooldownID ← Pools.Release ← resetFunc ← CooldownViewer:OnShow`
- Frame: `BuffBarCooldownViewer` item

**Root cause identified:**
`HookFrameForMouseover` wrote `frame._quiMouseoverHooked = true` directly onto `BuffBarCooldownViewer`, its item children (via `CollectIcons`), and the other viewer frames. Also `region.__SUI_OverlayShowHooked` and `texture.__quiAtlasBlocked` written to child textures. Any field write from addon context to a Blizzard CDM frame object taints that frame's table — subsequent reads of `frame.isActive` return a "secret boolean tainted by SuaviUI".

**Fix applied (v0.3.4):**
Replaced all three direct field writes with module-level weak tables: `mouseoverHookedFrames`, `overlayShowHookedRegions`, `atlasBlockedTextures`.

**Expected next session:** Zero CooldownViewer taint errors from these two sources.

---

### Session 4772 — BuffBarCooldownViewer isActive persistent taint (second vector)

**Observed (2026-02-26, session 4772):**
- `CooldownViewer.lua:353` — `isActive` secret boolean tainted by SuaviUI (counter 61, same error)
- Same stack: `SetIsActive ← RefreshActive ← RefreshData ← ClearCooldownID ← Pools.Release ← resetFunc ← CooldownViewer:OnShow`
- Error persisted even after mouseoverHookedFrames fix — meaning a second taint source was independently writing to the `BuffBarCooldownViewer` object.

**Root cause identified:**
`USE_CUSTOM_BARS = false` in `sui_buffbar.lua`. The legacy path:
1. Writes `BuffBarCooldownViewer.isHorizontal`, `.layoutFramesGoingRight`, `.layoutFramesGoingUp` directly from addon context (at startup and via `hooksecurefunc(BuffBarCooldownViewer, "RefreshLayout", ...)`)
2. Calls `ApplyBarStyle()` on Blizzard's pool item frames (obtained via `BuffBarCooldownViewer:GetItemFrames()`)
Both operations taint the `BuffBarCooldownViewer` frame table. When Blizzard's own `RefreshLayout → ReleaseAll → resetFunc → SetIsActive` chain subsequently runs, it executes in tainted context and every `frame.isActive = value` sets a "secret boolean".

**Taint mechanism:**
> Field-level taint: `frame.x = value` written from addon context marks `frame.x` as tainted.
> Execution-context taint: calling a hooked function that was registered from addon context causes the entire callchain to run in tainted context, marking every `frame.field = value` write as tainted.
> Both were at play here.

**Fix applied (v0.3.4):**
Changed `local USE_CUSTOM_BARS = false` → `true` in `sui_buffbar.lua`. The `USE_CUSTOM_BARS = true` path uses `SuaviBuffBar*` frames (owned by SuaviUI). Blizzard's viewer is hidden via `SetAlpha(0)` only — no Blizzard frame field writes, no taint. This mirrors the already-working `USE_CUSTOM_ICONS = true` path.

**Note:** A full game restart (not just `/reload`) is required to clear pre-fix tainted field values from JIT memory. After the restart, if `isActive` errors no longer appear, the fix was successful.

**Expected next session (post full restart):** Zero `isActive` taint errors on `BuffBarCooldownViewer` items.

---

**Remember:** Counter increments = time passing + game activity. It's NOT a measure of total occurrences.

---

## Audit Matrix (One-Group Isolation)

Use this matrix to enable only one feature group at a time from [utils/utils.xml](utils/utils.xml), then run a short combat scenario and inspect the newest BugSack session.

### Group 0: Baseline Core (always on)
- `media.lua`
- `constants.lua`
- `sui_debug.lua`
- `backwards.lua`

### Group 1: Cooldown/CDM Surface (highest taint risk)
- `cooldown_coordinator.lua`
- `cooldownmanager.lua`
- `cooldown_editmode.lua`
- `cooldown_icons.lua`
- `cooldown_fonts.lua`
- `cooldown_advanced.lua`
- `customglows.lua`
- `cooldowneffects.lua`
- `cooldownswipe.lua`
- `sui_ncdm.lua`
- `sui_spellscanner.lua`

### Group 2: UnitFrames/Castbars
- `buffborders.lua`
- `CastbarMixin.lua`
- `sui_castbar.lua`
- `sui_unitframes.lua`
- `unitframes_editmode.lua`
- `castbar_editmode.lua`

### Group 3: Resource Bars
- `resourcebars/resourcebars.xml` include

### Group 4: Actionbars/Minimap/EditMode Utilities
- `uihider.lua`
- `suicore_main.lua`
- `perfectpixel.lua`
- `sui_actionbars.lua`
- `actionbars_editmode.lua`
- `suicore_minimap.lua`
- `minimap_editmode.lua`
- `suicore_nudge.lua`
- `keybinds.lua`

### Group 5: UI Data/Options Layer
- `sui_dungeon_data.lua`
- `sui_datatexts.lua`
- `sui_datapanels.lua`
- `sui_gui.lua`
- `sui_welcome.lua`
- `sui_options.lua`
- `sui_blizzard_options.lua`

### Group 6: Gameplay Helpers
- `sui_rotationassist.lua`
- `sui_character.lua`
- `sui_inspect.lua`
- `sui_customtrackers.lua`
- `sui_reticle.lua`
- `sui_combattext.lua`
- `sui_combattimer.lua`
- `sui_qol.lua`
- `sui_quicksalvage.lua`
- `sui_crosshair.lua`
- `sui_skyriding.lua`
- `skyriding_editmode.lua`
- `sui_chat.lua`
- `sui_tooltips.lua`

### Group 7: Mythic+/Keystone/Group Tracking
- `sui_keystone.lua`
- `sui_mplus_timer.lua`
- `sui_dungeon_teleport.lua`
- `sui_keystone_comm.lua`
- `sui_key_tracker.lua`
- `sui_raidbuffs.lua`
- `sui_buffbar.lua`

---

## Isolation Procedure

1. Keep Group 0 enabled.
2. Enable only one additional group.
3. Reload UI, enter combat for a reproducible window (same test route each run).
4. Capture newest BugSack session ID.
5. Compare only:
   - unique error type(s)
   - source file(s)
   - stack top function(s)
6. If errors appear, bisect within that group by halving enabled files.
7. If no errors appear, mark group as clean and move to next group.

### Log Template (per run)
- Session ID:
- Enabled groups:
- Unique error types:
- Top stack source:
- Verdict: `clean` / `tainted`

