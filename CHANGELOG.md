# SuaviUI Changelog

## [v0.2.5](https://github.com/alesys/SuaviUI/tree/v0.2.5) (2026-02-14)

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
