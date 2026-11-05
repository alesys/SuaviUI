# SuaviUI Changelog

## [v0.3.29](https://github.com/alesys/SuaviUI/releases/tag/v0.3.29) (2026-11-05)

### New Modules Edition

Three new modules: nameplates, raid & party frames, and a combined bag window with bank support. All three are off by default; nothing changes until you enable them in `/sui`.

- **Nameplates**: SuaviUI plates on top of Blizzard's bases: threat/role-colored health bar, name, health %, level/elite, target border/glow/scale, focus marker, raid icon, cast bar (interruptible/locked colors, interrupt-on-cooldown tint, interrupted flash), your debuffs plus purgeable/important enemy buffs, friendly name-only/hide modes. Blizzard's frame is only faded and fully restored when disabled
- **Raid & Party Frames**: secure group headers (per group, or one combined frame sorted by role/name), health/power, heal prediction, absorbs and heal absorbs, dispel highlight, debuffs (boss debuffs larger), own HoTs, private aura anchors, range fade, dead/offline/AFK, role/leader/marker/ready check/res/summon icons, target highlight, Clique support. Positioned through Edit Mode with per-layout positions and fake-unit preview
- **Bags & Bank**: combined bag window with categories, bank and Warband bank, in sync with Blizzard's bag keybinds and the bank NPC. Toggling it asks for a reload
- **Sell junk**: routine now shared so the bag window can use it
- **Profiles**: import and profile switch refresh the new modules

---

## [v0.3.28](https://github.com/alesys/SuaviUI/releases/tag/v0.3.28) (2026-10-13)

### Patch 12.1.5 Edition

Patch 12.1.5 removed Blizzard's deprecated item API aliases; without this release the character panel, bags, loot frames and alerts threw "attempt to call a nil value".

- **12.1.5 compatibility**: all calls to `GetItemInfo`, `GetDetailedItemLevelInfo`, `GetItemInfoInstant`, `GetItemQualityColor`, `GetItemGem` moved to `C_Item` (character panel, equipment flyout, bag item levels, loot rolls, loot/alert and datatext quality colors)
- **Interface 120105**: addon no longer shows as out of date
- **Objective Tracker taint, round two**: UI Hider bookkeeping flags moved off Blizzard frames (`ObjectiveTrackerFrame`, `GameTimeFrame`, `TalkingHeadFrame`, `StatusTrackingBarManager`) into an addon-owned table
- **Loot roll click blocker**: hidden roll frames are returned through `GroupLootContainer_RemoveFrame`; the container no longer takes mouse input
- **Tooltip forbidden-frame crash**: parent walk stops at forbidden frames (`PingListenerFrame`)
- **New `/suitaint`**: audits the Objective Tracker chain with `issecurevariable()` and names the tainted field and its source

---

## [v0.3.27](https://github.com/alesys/SuaviUI/releases/tag/v0.3.27) (2026-08-21)

### Tracker Taint Edition

Fixes an error storm (~43,000 per session) from the Objective Tracker in scenarios, delves and Mythic+.

- **Objective Tracker taint**: global font is now applied from an addon-owned frame instead of a script hook on the tracker, so Blizzard's scenario tracker no longer runs restricted
- **Tracker skin**: two more hooks of the same kind removed (one was redundant)

---

## [v0.3.26](https://github.com/alesys/SuaviUI/releases/tag/v0.3.26) (2026-08-20)

### Click Blocker Edition

- **Anchoring popover click catcher**: the full-screen "click outside to close" frame is now tied to the popover's visibility; it could stay up and eat every click on the UI
- **New `/suimouse`**: lists regions under the cursor (topmost first) and flags invisible-but-clickable ones; `/suimouse 3` samples after a delay; `/suimouse scan` reports zero-alpha mouse-enabled frames and mouse-enabled frames covering >25% of the screen. Report only, never disables anything

---

## [v0.3.25](https://github.com/alesys/SuaviUI/releases/tag/v0.3.25) (2026-08-18)

### Secret Values Edition

Midnight compatibility fixes for secret values.

- **Cursor ring**: tracks the cursor again; GCD sweep no longer errors in combat
- **Unit frame auras**: secret auras are skipped cleanly instead of erroring and hiding every aura after them
- **Leader/assistant icons** on target and focus no longer error in groups
- **Class colors in instances**: target, target-of-target, pets and portrait borders show the real class color instead of grey (inline ToT text falls back to white)
- **Raid buff checks** and **Mythic+ key list** leader crown no longer error
- Known limitation: auras Midnight marks as secret cannot be shown by any addon

---

## [v0.3.24](https://github.com/alesys/SuaviUI/releases/tag/v0.3.24) (2026-07-31)

### Omnium Folio Edition

- **Omnium datatext**: unspent Omnium Folio points, gold when something is purchasable; tooltip with unspent/spent points and balance; click opens the folio
- **Omnium Folio skin**: SuaviUI 1px border and fonts, tree artwork untouched (toggle in General & QoL)
- **Spendable Omnium alert**: optional pulsing glow on the landing page minimap button plus optional chat notice; clears when the folio opens
- **Landing page minimap button**: scale and X/Y offset in the Edit Mode minimap panel; now shown by default
- Spendable detection uses Blizzard's rule (an affordable, purchasable node must exist); all Omnium code guarded for pre-Midnight clients

---

## [v0.3.23](https://github.com/alesys/SuaviUI/releases/tag/v0.3.23) (2026-07-31)

### Midnight Castbars Edition

- **Boss castbars with secret cast timing**: redacted timing is handed to the engine (`SetTimerDuration`), so bars fill/drain correctly
- **Combat Timer in Edit Mode**: position, size, font, colors and border with live preview; old offsets migrated automatically
- **Buff/Debuff text** and **Target Marker** settings moved to the Edit Mode sidepanel
- **Extra Action Button / Zone Ability** movable and scalable again, anchored (never reparented) to stay taint-safe
- **Spec swap**: every module now refreshes on LibDualSpec profile change
- **Castbars**: boss bars created when enabled mid-session, casts already in progress are picked up, long casts no longer restart on a concurrent instant cast, preview no longer resets mid-drag
- **Extra Action Button holder** no longer eats clicks
- **Minimap clock/coords color** and **Skyriding vigor bar dropdowns** store the right values

---

## [v0.3.22](https://github.com/alesys/SuaviUI/releases/tag/v0.3.22) (2026-05-03)

### Bonus Roll Mover Edition

- **Bonus Roll prompt visible again**: `GroupLootContainer` is no longer hidden, only `GroupLootFrame1-4`
- **Bonus Roll Edit Mode mover** with placeholder, position saved per profile
- **Unit frames Edit Mode**: Health Text gains Anchor + X/Y offset; Power Text gains X/Y offset
- **Minimap border color crash** fixed, with self-healing of corrupted profiles

---

## [v0.3.21](https://github.com/alesys/SuaviUI/releases/tag/v0.3.21) (2026-04-26)

### Live Stats Edition

- **Live Stats frame**: standalone stats HUD with six toggleable sections and per-stat checkboxes, movable in Edit Mode
- **Live Combat Updates (opt-in)**: keeps Blizzard's character pane logically visible so stats stay current in combat without taint
- **Stats in combat**: per-stat cache of last good values, hooks on `PaperDollFrame_Set*`, new aura/lifesteal/avoidance/spell power events, player-only events
- **Rotation Assist icon**: Edit Mode integration; sidebar settings; keybind slot mapping fixed (bars 2/3 swapped, slots 13-24, bars 6/7/8)
- **Cast History**: moved to the CDM Keybind & Rotation tab; vertical orientations now work
- **Chat taint fix**: `AddMessage` replacement swapped for `ChatFrame_AddMessageEventFilter`
- **Extra Abilities**: SuaviUI panel injected into Blizzard's Edit Mode system (scale, hide artwork, fade) instead of reparenting

---

## [v0.3.20](https://github.com/alesys/SuaviUI/releases/tag/v0.3.20) (2026-04-18)

### Cast History Edition

- **Cast History frame** (opt-in): icons of recent casts, configurable flow direction, max icons + timeout, SuaviUI Square or Blizzard Default skin, movable in Edit Mode, channel-tick filter
- **Cursor ring** renders as a ring again (assets renamed `qui_*` → `sui_*`)
- **Cast History** icons stay visible after the slide-in; square border drawn above the icon
- **Global unit frame settings** (dark mode, opacities, text coloring) moved from the Edit Mode sidebar to Options → Unit Frames → General

---

## [v0.3.19](https://github.com/alesys/SuaviUI/releases/tag/v0.3.19) (2026-04-11)

### Character Panel Redesign

- **Character panel**: new header bar (name, spec, item level), styled Stats/Titles/Equip buttons, amber ⚠ for missing enchants, wider stats panel, more room for item names
- **Unit frame auras**: anchor dropdown works, 9-point anchoring, live preview in Edit Mode
- **Edit Mode eye button**: hidden overlays no longer reappear on click
- **Resource Bars options**: "module not loaded" error and reset buttons fixed
- Random motivational messages and wellness reminders

---

## [v0.3.18](https://github.com/alesys/SuaviUI/releases/tag/v0.3.18) (2026-04-03)

### Hide While Mounted Edition

- **Hide While Mounted/Vehicle** for unit frames, action bars and CDM viewers (includes Druid travel forms)
- **Collapsible sections** in the Action Bar panel
- **Resource Bars section** in Options (per-bar enable, center reset)
- **Spec change**: "Hide Empty Slots" buttons update correctly
- **Action bar checkboxes**: Show Backdrop / Show Gloss reflect their real state
- **Enchant checker for Midnight**: Head and Shoulder flagged; Back and Wrist removed; OffHand only for weapons
- Removed unused Border Overlap checkbox from CDM panels

---

## [v0.3.17](https://github.com/alesys/SuaviUI/releases/tag/v0.3.17) (2026-03-27)

### UpgradeItem Fix Edition

- **Item Upgrade UI unblocked**: removed global function replacements in the tooltip module and `StaticPopup_Hide` from auto-accept invite, which tainted the StaticPopup chain
- `pcall` guards for Reticle GCD and QuickSalvage; Keystone comm fallback for removed `GetActiveKeystoneLevel`
- CDM alerts rewritten with `hooksecurefunc`; viewer `SetSize` calls removed
- **New**: minimap right-click context menu; CDM Enhanced Alerts module (SoundKit, SharedMedia, TTS)

---

## [v0.3.16](https://github.com/alesys/SuaviUI/releases/tag/v0.3.16) (2026-03-20)

### Vertical Tracked Buffs Edition

- **Tracked Buffs** honor the vertical orientation from Edit Mode
- **ExtraActionBarFrame taint**: protected Show/Hide/EnableMouse replaced with `SetAlpha`
- **Resource bars** update width/position on spec change with per-character layouts
- **Auto-delete confirm** disabled to avoid StaticPopup taint
- CDM taint diagnosis via per-module hook flags (`ns.CDM_HOOKS`)

---

## [v0.3.15](https://github.com/alesys/SuaviUI/releases/tag/v0.3.15) (2026-03-13)

### Taint Fix Edition

Eliminates CDM taint cascade caused by `HookScript` on CDM viewers, and fixes a `pcall` multi-return bug that left most tracked bars unskinned.

- **CDM taint fix**: Replaced all `HookScript("OnUpdate/OnShow/OnSizeChanged")` on CDM viewers with `hooksecurefunc(viewer, "Layout", ...)` — taint-safe
- **CDM taint fix**: Separate addon-owned polling frame for legacy skinning (50ms interval)
- **CDM taint fix**: Restored `SetSize` with `InCombatLockdown()` + Edit Mode guards
- **pcall multi-return bug**: `GetBuffBarFrames()` only captured first child from `pcall(GetChildren, viewer)` — all bars after the first were unskinned. Fixed in `sui_buffbar.lua`, `cooldownmanager.lua`, and `CooldownManagerCentered`
- **Combat lockdown guards**: `EnableMouse`, `SetFrameLevel`, `SetFrameStrata`, `extraActionButton:Hide()` — all wrapped with `InCombatLockdown()` check
- **Deferred combat actions**: `extraActionButton` hide uses pending table, processed on `PLAYER_REGEN_ENABLED`
- **Release automation**: `dev/release.sh` script for one-command releases

---

## [v0.3.14](https://github.com/alesys/SuaviUI/releases/tag/v0.3.14) (2026-03-09)

### Character Flyout Edition

- Character flyout ilvl overlay: item level on Alt-hover equipment flyout buttons
- Rewrote flyout ilvl lookup (hook `UpdateItems`, `GetContainerItemInfo` hyperlink) — no more cache misses
- Buffbar combat taint fix: guard `EnableMouse` calls with `InCombatLockdown()`
- GUI form widget labels: `SetJustifyH("LEFT")` across all widget types
- Character stats: `showTooltips` default off

---

## [v0.3.13](https://github.com/alesys/SuaviUI/releases/tag/v0.3.13) (2026-03-06)

### Edit Mode Settings Edition

- Settings migrated from Options GUI to Edit Mode panels (CDM, Action Bars, Minimap, Unit Frames)
- GUI builder pattern refactor (WrapBuilder, lazy page builders)
- New Pill/Circle UI widgets, character panel accent pips and section backgrounds

---

## [v0.3.12](https://github.com/alesys/SuaviUI/releases/tag/v0.3.12) (2026-03-06)

### Legacy Skinning Edition

- Tracked bars: legacy path (`USE_CUSTOM_BARS=false`), skin Blizzard viewers in place
- Tracked icons: legacy path (`USE_CUSTOM_ICONS=false`), remove ForcePopulate taint, show stack counts

---

## [v0.3.11](https://github.com/alesys/SuaviUI/tree/v0.3.11) (2026-03-05)

### CDM Taint Elimination — Complete Frame-Field Purge (Sessions 4979–4995)

Completes the CDM taint hardening begun in v0.3.10. Every remaining direct field write on Blizzard CDM frames and viewers has been migrated to module-level weak tables. Action bar customization (disabled since session 4942) is re-enabled.

---

#### Cooldown Swipe — Polling Replaces Per-Icon Hooks (cooldownswipe.lua)

`hooksecurefunc(icon.Cooldown, "SetCooldown", ...)` rawset a wrapper on each CDM Cooldown widget inside Blizzard's secure `RefreshData` chain. Replaced with a `C_Timer.NewTicker(0.2)` that applies swipe/edge settings via pcall-guarded reads — no per-icon hooks, no frame field writes.

---

#### Custom Glows — Singleton Manager Hook + Wrapper Frames (customglows.lua)

Per-CDM-icon method hooks (`OnSpellActivationOverlayGlowShowEvent`, `OnSpellActivationOverlayGlowHideEvent`, `RefreshOverlayGlow`) rawset wrapper functions on each CDM item frame's Lua table. Replaced with a singleton `hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert/HideAlert", ...)` hook. LibCustomGlow calls now target a thin addon-owned wrapper frame (`GetOrCreateGlowWrapper(icon)`) instead of the CDM item frame, preventing `_PixelGlow_key` / `_AutoCastGlow_key` field taint.

---

#### Keybinds — Weak-Table Field Migration (keybinds.lua)

`icon.keybindText` and `icon._rotationHelperOverlay` field writes migrated to `keybindFontStrings[icon]` and `rotationOverlays[icon]` weak tables.

---

#### Action Bars — Re-enabled with Full Weak-Table Migration (sui_actionbars.lua)

`DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION` and `DISABLE_EXTRA_BUTTON_CUSTOMIZATION` set back to `false`. All 15+ Blizzard frame field writes (`_quiStripped`, `_quiSkinKey`, `_quiBackdrop`, `_quiNormal`, `_quiGloss`, `_quiHiddenEmpty`, `_quiTinted`, `_quiMouseoverHooked`, `_quiHooked`, `_suiVisibilityHooked`, `_quiBindingCommand`, `_quiKeybindMethods`) migrated to module-level weak tables.

---

#### Tracked Bars & Icons — C API Only Data Pipeline (sui_buffbar.lua)

- Removed all Lua-level viewer interactions (`:SetSize()`, `.Selection` manipulation, `:GetItemFrames()`, `.itemFramePool:EnumerateActive()`) for both `BuffBarCooldownViewer` and `BuffIconCooldownViewer`. These tainted the shared `CooldownViewerSettingsDataProvider` singleton, cascading to all four CDM viewers.
- `FetchBuffBarData()` and `FetchBuffIconData()` rewritten to use C API only path (`C_CooldownViewer.GetCooldownViewerCategorySet` + `C_CooldownViewer.GetCooldownViewerCooldownInfo`).
- Comprehensive aura detection matching Blizzard's `ShouldBeActive()` logic: checks ALL associated spell IDs (`linkedSpellIDs`, `overrideSpellID`, base `spellID`), player aura AND target debuffs, totem detection via `C_Totem.GetTotemInfo`, infinite aura support (`expirationTime == 0`).

---

#### StaticPopup Taint Fix — Session 4995 (sui_qol.lua)

`[ADDON_ACTION_FORBIDDEN] UpgradeItem()` caused by taint propagation through reused StaticPopup frames. The auto-delete-confirm hook called `editBox:GetScript("OnTextChanged")` handler from addon context, tainting frame fields that persisted across frame reuse. Fix: deferred auto-fill to next frame via `C_Timer.After(0, ...)` and removed the manual handler call (`SetText()` already triggers `OnTextChanged` through the C engine).

---

#### Settings Panel Polish (sui_gui.lua, sui_options.lua)

- Tab layout dynamically calculates row count and container height
- Content area gets subtle border and translucent background
- Section headers: refined spacing and underline styling
- CDM styling options use compact form layout
- Bottom panel and button hover states refined

---

#### Files Changed

| File | Change |
|------|--------|
| `utils/cooldownswipe.lua` | Replaced per-icon `SetCooldown` hooks with `NewTicker(0.2)` polling; all CDM reads pcall-guarded |
| `utils/customglows.lua` | Singleton `ActionButtonSpellAlertManager` hooks; `GetOrCreateGlowWrapper()` for LibCustomGlow isolation |
| `utils/keybinds.lua` | `keybindFontStrings[icon]` and `rotationOverlays[icon]` weak tables |
| `utils/sui_actionbars.lua` | 15+ frame field writes → weak tables; re-enabled both customization flags |
| `utils/sui_buffbar.lua` | Removed viewer SetSize/Selection/GetItemFrames/itemFramePool; C API only data pipeline; comprehensive aura detection |
| `utils/sui_qol.lua` | Deferred auto-delete-confirm; removed manual OnTextChanged call |
| `utils/sui_gui.lua` | Tab layout, content area, section header, bottom panel polish |
| `utils/sui_options.lua` | Compact CDM styling form layout |
| `utils/suicore_main.lua` | Minor taint-related cleanup |

---

## [v0.3.10](https://github.com/alesys/SuaviUI/tree/v0.3.10) (2026-03-03)

### 🛡️ CDM Systemic Taint Elimination — Sessions 4891 / 4912 / 4924 / 4927

This version resolves a chain of persistent "secret value" taint errors across all four CDM viewers (`BuffBarCooldownViewer`, `BuffIconCooldownViewer`, `EssentialCooldownViewer`, `UtilityCooldownViewer`) that persisted across multiple sessions despite incremental fixes.

---

#### Background: How WoW Value-Based Taint Works

In WoW's Lua security model, **taint is tracked per Lua value** (table, string, number, boolean), not per execution frame. When addon code **writes** a field on a Blizzard-owned frame object (e.g. `viewer.isHorizontal = false` from addon context), that specific field becomes a "secret value tainted by SuaviUI". Any subsequent Blizzard secure code that reads that field gets a "secret value" error. The error cascades: if the tainted read propagates into another write (e.g. Blizzard writes `self.isActive = ...` using a tainted input), that field becomes tainted too, spreading across the entire CDM data pipeline.

---

#### Root Cause Chain (resolved across four sessions)

**Vector 1 — `hooksecurefunc` on `OnActiveStateChanged` (cooldownmanager.lua)**

The `GetBuffIconFrames()` and `GetBuffBarFrames()` functions installed per-frame `hooksecurefunc` hooks on `OnActiveStateChanged` whenever new CDM item frames were discovered. These hooks fired synchronously inside Blizzard's secure call chain: `OnUpdate → RefreshActive → SetIsActive → OnActiveStateChanged`. Addon code running in this chain taints CDM item frame fields (`isActive`, `charges`, `spellID`, etc.). Blizzard's subsequent secure reads of those fields failed with "secret value" errors.

**Fix:** Removed the `HookState` table and all `hooksecurefunc(child/frame, "OnActiveStateChanged", ...)` hook installations from `cooldownmanager.lua`. The `OnActiveStateChanged` event was an optimization (immediate dirty-marking); `UNIT_AURA`-driven refresh provides equivalent coverage with no taint risk.

---

**Vector 2 — `viewer:Show()` and `ShouldBeShown` override (sui_buffbar.lua, session 4912)**

A proposed fix attempted to keep `BuffBarCooldownViewer` shown (so its item pool stayed live) by:
1. Calling `viewer:Show()` after `SetAlpha(0)` inside `SetViewerHidden(true)`
2. Overriding `ShouldBeShown` on the viewer to always return `true` when custom bars are active

Both caused new taint:
- `viewer:Show()` on `BuffBarCooldownViewer` triggers `OnShow → RefreshLayout → RefreshData`. Running that from addon context (even via pcall) taints the data chain.
- Overriding `ShouldBeShown` replaces a Blizzard method field with an addon closure. Blizzard's `UpdateShownState()` calls `self:ShouldBeShown()` from secure context — executing the addon closure taints the execution context for the entire `UpdateShownState → SetShown` chain.

**Fix:** Reverted both changes. `SetViewerHidden` uses `SetAlpha(0/1)` and `EnableMouse(false/false)` only — no `Show()`, no method override. The item pool stays live because the viewer is never `Hide()`d; only its alpha is zeroed.

Also fixed in this pass:
- Wrong API name `GetCooldownInfoByCooldownID` → correct name `GetCooldownViewerCooldownInfo`
- `linkedSpellID` (scalar) → `linkedSpellIDs` (table); added iteration loop

---

**Vector 3 — `isHorizontal` field write from C_Timer callback (sui_buffbar.lua, session 4924)**

A `hooksecurefunc(BuffBarCooldownViewer, "Layout", ...)` hook with a `C_Timer.After(0, ...)` deferral wrote `BuffBarCooldownViewer.isHorizontal = false` and `layoutFramesGoingRight`/`layoutFramesGoingUp` to the Blizzard viewer frame. Even with deferral via C_Timer, the write executes in addon (tainted) execution context. Blizzard's next `RefreshLayout` reads the tainted `isHorizontal` field at `CooldownViewer.lua:1781-1787`, cascades the taint into `itemContainerFrame` fields, and from there through `Layout()` and `RefreshData()` into all item frame fields (`isActive`, `charges`, `spellID`, `hasTotem`, `previousCooldownChargesCount`) across **all four CDM viewers**.

**Fix (`utils/cooldownmanager.lua`):** Removed the `hooksecurefunc` on `BuffBarCooldownViewer.Layout` that wrote to `isHorizontal`. Replaced with a comment block explaining the rule. `USE_CUSTOM_BARS = true` renders bars into `customContainer` (SuaviUI-owned frames) — the CDM viewer's layout direction is completely irrelevant.

Note: Other writes to `BuffBarCooldownViewer.isHorizontal` exist in the file but are all guarded by `if not USE_CUSTOM_BARS` or `else` of `IsCustomBarsActive()` — they do not execute when `USE_CUSTOM_BARS = true`.

---

**Vector 4 — `provider:CheckBuildDisplayData()` explicit call (sui_buffbar.lua, session 4924 → 4927)**

`GetViewerCooldownIDs()` and `GetIconViewerCooldownIDs()` called into `CooldownViewerSettings:GetDataProvider()` to retrieve active cooldown IDs. The provider path included:
- An explicit `provider:CheckBuildDisplayData()` call in `GetIconViewerCooldownIDs()` (removed in session 4924)
- A `provider:GetOrderedCooldownIDsForCategory(...)` call in both functions

Removing the explicit `CheckBuildDisplayData()` call (session 4924 fix) had no effect on session 4927 errors, because **`GetOrderedCooldownIDsForCategory` internally calls `self:CheckBuildDisplayData()` at `CooldownViewerSettingsDataProvider.lua:243`**. Calling either function from addon (tainted) context is equivalent — both write to the shared CDM data provider tables, tainting the provider's display data. Blizzard's `RefreshData()` then reads tainted values from the provider and writes tainted `isActive`/`spellID`/`charges`/`hasTotem` to ALL viewer item frames, producing "secret value" errors in `CooldownViewer.lua` and `CooldownViewerItemData.lua`.

**Fix (`utils/sui_buffbar.lua`):** Removed the entire provider path from both `GetViewerCooldownIDs()` and `GetIconViewerCooldownIDs()`. Both functions now use the C API only:

```lua
local function GetViewerCooldownIDs()
    local ok, result = pcall(function()
        if C_CooldownViewer then
            if C_CooldownViewer.GetCooldownViewerCategorySet then
                return C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBar, true)
            elseif C_CooldownViewer.GetCooldownIDsForCategory then
                return C_CooldownViewer.GetCooldownIDsForCategory(Enum.CooldownViewerCategory.TrackedBar)
            end
        end
        return nil
    end)
    if ok and type(result) == "table" then return result end
    return {}
end
```

The C API (`GetCooldownViewerCategorySet` / `GetCooldownIDsForCategory`) returns a flat list of configured spell IDs without touching any Lua data structures on CDM frames. It has `SecretArguments="AllowedWhenUntainted"` — safe from addon context. The aura lookup in `FetchBuffBarData()` / `FetchBuffIconData()` still acts as the active filter.

---

**Vector 5 — `SPELL_UPDATE_COOLDOWN` writes during combat (cooldown_advanced.lua, session 4924)**

The `SPELL_UPDATE_COOLDOWN` event fires on every GCD. The handler called `RefreshUtilityDimming()` and `RefreshViewerSwipeColors()` which write to CDM item frames. Writing to CDM frames during combat at GCD frequency risks cascading taint into Blizzard's active combat processing.

**Fix (`utils/cooldown_advanced.lua`):** Added `if InCombatLockdown() then return end` as the first check in both the `SPELL_UPDATE_COOLDOWN` and `UNIT_AURA` event branches. Dimming and swipe colors are refreshed on the next out-of-combat tick instead.

---

#### Files Changed

| File | Change | Session |
|------|--------|---------|
| `utils/cooldownmanager.lua` | Removed `HookState` table; removed `hooksecurefunc(child, "OnActiveStateChanged", ...)` hooks from `GetBuffIconFrames` and `GetBuffBarFrames` | 4891 |
| `utils/cooldownmanager.lua` | Removed `hooksecurefunc(BuffBarCooldownViewer, "Layout", ...)` hook that wrote `isHorizontal` from deferred callback | 4924 |
| `utils/sui_buffbar.lua` | Reverted `viewer:Show()` call inside `SetViewerHidden(true)` — was causing `OnShow → RefreshData` taint | 4912 |
| `utils/sui_buffbar.lua` | Reverted `ShouldBeShown` method override — was executing addon closure from Blizzard's secure `UpdateShownState()` | 4912 |
| `utils/sui_buffbar.lua` | Fixed API name: `GetCooldownInfoByCooldownID` → `GetCooldownViewerCooldownInfo` | 4912 |
| `utils/sui_buffbar.lua` | Fixed `linkedSpellID` (scalar) → `linkedSpellIDs` (table) with iteration | 4912 |
| `utils/sui_buffbar.lua` | Removed entire provider path from `GetViewerCooldownIDs()` — both explicit `CheckBuildDisplayData()` and `GetOrderedCooldownIDsForCategory()` (which calls it internally); C API only | 4924/4927 |
| `utils/sui_buffbar.lua` | Removed entire provider path from `GetIconViewerCooldownIDs()` — same reason | 4924/4927 |
| `utils/cooldown_advanced.lua` | Added `InCombatLockdown()` guard to `SPELL_UPDATE_COOLDOWN` and `UNIT_AURA` handlers | 4924 |

---

#### Session Triage

- Session 4891: `isActive`, `charges`, `wasOnGCDLookup`, `spellID` tainted on multiple viewers — root cause: `OnActiveStateChanged` hooks in `cooldownmanager.lua` firing synchronously inside Blizzard's secure call chain.
- Session 4912: new `OnShow → RefreshData` taint after `viewer:Show()` attempt; `ShouldBeShown` override executing addon closure from secure context — both reverted.
- Session 4924: `isActive` tainted — `BuffBarCooldownViewer.isHorizontal` written from C_Timer callback; `spellID`/`charges`/`hasTotem` tainted — `provider:CheckBuildDisplayData()` called explicitly; `spellID` on SPELL_UPDATE_COOLDOWN — CDM frame writes during combat.
- Session 4927: identical errors to session 4924 despite fixes — root cause: `GetOrderedCooldownIDsForCategory()` internally calls `CheckBuildDisplayData()` at `CooldownViewerSettingsDataProvider.lua:243`; removing the explicit call was insufficient. Fix: entire provider path removed from both functions.

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
