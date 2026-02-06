# Minimap Edit Mode Implementation

## Overview
The minimap is registered with LibEQOLEditMode-1.0 (LEM) for positioning, dragging, and sidepanel settings inside Blizzard's Edit Mode. This replaces the old nudge-overlay system that had arrow buttons for pixel-nudging.

## Architecture

### File: `utils/minimap_editmode.lua`
- Registers the **actual `Minimap` frame** directly with LEM
- Provides a sidepanel with all minimap settings (position, appearance, hide elements, clock, coords, zone text, dungeon eye)
- Manages Edit Mode enter/exit lifecycle (strata, movable, MinimapCluster)

### File: `utils/suicore_minimap.lua` (modified)
- Core minimap module (shape, backdrop, coords, datatext, etc.)
- `Refresh()` and `SetupMinimapDragging()` now guard `SetMovable(false)` and position-restore with `LEM:IsInEditMode()` to avoid breaking LEM drag state

### File: `utils/suicore_nudge.lua` (modified)
- Old minimap overlay (`ShowMinimapOverlay` / `EnableMinimapEditMode`) disabled — now handled by LEM

## Key Design Decision: Register Minimap Directly (Not a Holder Frame)

### The Problem with Holder Frames
Previous implementation created a hidden `SUI_MinimapEditModeFrame` holder, showed it only in the `"enter"` callback, and registered it with LEM. This failed because:

1. **Timing**: LEM's `onEditModeEnter()` calls `resetSelectionIndicators()` **before** firing addon callbacks. This function iterates all registered frames and calls `selection:ShowHighlighted()`. If the parent frame (holder) is hidden at that point, the selection overlay (a child) won't render — even though `.Show()` was called on it.

2. **Drag target mismatch**: LEM's `beginSelectionDrag` calls `self.parent:StartMoving()` on the registered frame. With a holder, this moves the invisible holder — not the Minimap itself.

3. **Click proxy didn't work**: A click-forwarding proxy button was tried, but WoW's native drag system (`StartMoving`/`StopMovingOrSizing`) cannot work through manual `OnMouseDown` forwarding. The `EditModeSystemSelectionTemplate` must be the direct receiver of mouse events.

### The Solution
Register the actual `Minimap` frame (always visible) with LEM. This is consistent with:
- **castbar_editmode.lua** — registers the actual castbar frames
- **SenseiClassResourceBar** — registers the actual resource bar frame
- **actionbars_editmode.lua** — registers holder frames that are already visible

### FixedFrameStrata Handling
`suicore_minimap.lua` sets `Minimap:SetFixedFrameStrata(true)` and `SetFixedFrameLevel(true)` at `LOW` strata. During Edit Mode, we temporarily disable these so LEM can manage strata for drag operations, then restore them on exit.

### Refresh() Guard
`Minimap_Module:Refresh()` calls `SetMovable(false)` and repositions the minimap from DB. Both are now wrapped in `if not LEM:IsInEditMode()` to prevent fighting with LEM during active drag or sidepanel setting changes.

## LEM Settings API Format
Settings use the `kind = LEM.SettingType.*` format with `order` numbering:
- `LEM.SettingType.Collapsible` — category headers
- `LEM.SettingType.Checkbox` — boolean toggles (get/set receive `layoutName`)
- `LEM.SettingType.Slider` — numeric values (`minValue`, `maxValue`, `valueStep`)
- `LEM.SettingType.Dropdown` — selection lists (`values`, `useOldStyle`)
- `LEM.SettingType.Color` — color pickers (get returns r,g,b,a; set receives layoutName,r,g,b,a)

**Important**: The older `type = "checkbox"` / `min`/`max`/`step` format does NOT work. Must use `kind` + `order` pattern as used by castbar_editmode.lua and SenseiClassResourceBar.

## Sidepanel Settings Categories
1. **Position & Size** — Lock, Size, Scale
2. **Appearance** — Shape, Border Size, Border Color, Class Color Border
3. **Hide Elements** — Mail, Tracking, Difficulty, Progress Report, Zoom Buttons, Crafting Orders, Addon Compartment, Calendar, Addon Buttons
4. **Clock** — Enable, Time Format, Font Size, Offset, Color, Class Color
5. **Coordinates** — Enable, Precision, Update Interval, Font Size, Offset, Color, Class Color
6. **Zone Text** — Enable, Font Size, Offset, Uppercase, Class Color
7. **Dungeon Eye** — Enable, Corner, Scale, Offset

## Old System (Disabled)
The nudge overlay system in `suicore_nudge.lua` created a cyan overlay with arrow buttons as a child of Minimap at TOOLTIP strata. It was triggered via `SUICore:ShowMinimapOverlay()` / `SUICore:EnableMinimapEditMode()` on `EditModeManagerFrame:EnterEditMode`. These calls are now commented out.

## Bugs Found & Fixed

### Bug: RefreshMinimap() was a silent no-op
**Symptom**: Changing any setting in the Edit Mode sidepanel wrote to DB but had no visible effect until `/reload`.

**Root cause**: `RefreshMinimap()` in `minimap_editmode.lua` referenced `_G.SUICore` — a global that **does not exist**. `SUICore` is an Ace3 module exposed at `_G.SuaviUI.SUICore` (set in `suicore_main.lua` line 15 as `SUI.SUICore = SUICore`). The `if _G.SUICore` guard silently failed, so `Refresh()` was never called. On `/reload`, the initialization code re-read the already-persisted DB values, making it look like the settings "worked".

**Irony**: The `GetDB()` function 5 lines above already used the correct path (`_G.SuaviUI and _G.SuaviUI.SUICore`).

**Fix**: Changed `RefreshMinimap()` to resolve via the correct global path:
```lua
local function RefreshMinimap()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.Minimap and SUICore.Minimap.Refresh then
        SUICore.Minimap:Refresh()
    end
end
```

**Lesson**: In this codebase, `SUICore` is **never** a direct global. Always access it via `_G.SuaviUI.SUICore`. The namespace `ns.Addon` also points to SUICore for files loaded within the addon's namespace.

### Bug: Settings used wrong LEM API format
**Symptom**: Sidepanel showed title and reset buttons but no settings controls.

**Root cause**: Settings used `type = "checkbox"`, `min`/`max`/`step` format instead of the correct `kind = LEM.SettingType.Checkbox`, `minValue`/`maxValue`/`valueStep`, `get(layoutName)`/`set(layoutName, value)` format.

**Fix**: Complete rewrite of `BuildMinimapSettings()` using the correct API pattern (matching `castbar_editmode.lua`).
