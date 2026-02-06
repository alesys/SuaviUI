# CDM layout + styling disable notes (2026-02-05)

## Why this document exists
We observed that CDM icons were still being repositioned and padded even after earlier styling/visibility changes. A full review showed multiple independent systems touching the same Blizzard cooldown viewer frames. To restore baseline Blizzard spacing, we force-disabled each system. This document records the sources so we can reintroduce them gradually.

## Affected viewers
- EssentialCooldownViewer
- UtilityCooldownViewer
- BuffIconCooldownViewer
- BuffBarCooldownViewer

## Systems that were moving / resizing / padding icons
### 1) SuaviUI CooldownManager (layout + spacing)
File: utils/cooldownmanager.lua
- Positions icons and bars via SetPoint/ClearAllPoints.
- Uses viewer childXPadding/childYPadding and iconScale to compute spacing.
- Hooks RefreshLayout and multiple events to re-run layout.
- This was still moving items even after icon styling was disabled.
Status: forced disabled via FORCE_DISABLE_CDM_LAYOUT.

### 2) SuaviUI BuffIcon/BuffBar manager
File: utils/sui_buffbar.lua
- LayoutBuffIcons/LayoutBuffBars compute sizes and call SetPoint.
- Hooks OnUpdate, OnSizeChanged, OnShow, Layout, UNIT_AURA to re-run layout.
- Also resizes BuffIconCooldownViewer to match icon grid.
Status: forced disabled via FORCE_DISABLE_CDM_BUFFBAR.

### 3) SuaviUI legacy NCDM
File: utils/sui_ncdm.lua
- Hooks Essential/Utility viewer layout and rows.
- Runs early and keeps modifying layout/skins.
Status: forced disabled at file load via FORCE_DISABLE_NCDM (returns early).

### 4) SuaviUI nudge re-anchoring
File: utils/suicore_nudge.lua
- Reanchors BuffIconCooldownViewer/BuffBarCooldownViewer on Edit Mode exit and reload.
- This moves the frames even if layout is otherwise disabled.
Status: forced disabled via FORCE_DISABLE_CDM_NUDGE.

### 5) External addon: CooldownManagerCentered
Files:
- CooldownManagerCentered/modules/cooldownManager.lua
- CooldownManagerCentered/modules/styled.lua
- Moves icons and bars via SetPoint/RefreshLayout.
- Styles/normalizes icon size and swipe textures.
Status: forced disabled via FORCE_DISABLE_CDM_LAYOUT / FORCE_DISABLE_CDM_STYLING in those modules.

## Net effect of the disable pass
- No custom SetPoint/size logic runs for Blizzard CDM viewers.
- Icon padding/spacing returns to Blizzard defaults.
- Styling (square icons, size normalization) is fully off.

## Reimplementation plan (gradual)
1) Decide which system should own layout (pick exactly one):
   - Option A: SuaviUI cooldownmanager.lua (newer integrated system)
   - Option B: sui_buffbar.lua for buffs + cooldownmanager.lua for Essential/Utility
   - Option C: Remove SuaviUI layout entirely and only style
2) Re-enable one system at a time behind explicit settings.
3) Avoid multiple layout engines running at once.
4) Gate layout changes behind feature flags and make them opt-in per viewer.
5) Add a debug toggle that logs any SetPoint calls on the CDM viewers.

## Quick list of disable flags
- utils/cooldownmanager.lua: FORCE_DISABLE_CDM_LAYOUT
- utils/sui_buffbar.lua: FORCE_DISABLE_CDM_BUFFBAR
- utils/sui_ncdm.lua: FORCE_DISABLE_NCDM
- utils/suicore_nudge.lua: FORCE_DISABLE_CDM_NUDGE
- CooldownManagerCentered/modules/cooldownManager.lua: FORCE_DISABLE_CDM_LAYOUT
- CooldownManagerCentered/modules/styled.lua: FORCE_DISABLE_CDM_STYLING
