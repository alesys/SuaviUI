# CooldownManagerCentered Integration Architecture

## Overview
This document outlines the plan for integrating CooldownManagerCentered (CMC) functionality into SuaviUI, following the principle: **COPY PROVEN PATTERNS, DON'T REINVENT**

## Core Principle
CMC is a **proven, working solution** that has been refined and tested. We will copy its exact algorithms and approach rather than attempting to improve or reinvent them.

## Architecture Decision: Settings Organization

### **EditMode Settings** (Layout/Structure - Affects Frame Geometry)
Settings that change how icons are positioned, arranged, or sized within the viewer containers. These affect the actual layout structure and belong in Blizzard's EditMode system.

#### **Per-Viewer Growth Direction** (Essential/Utility)
```lua
-- Setting: growFromDirection
-- Values: "TOP", "BOTTOM", "Disable"
-- Default: "TOP"
-- Purpose: Controls how new rows stack (upward or downward)
-- Adaptive labels based on isHorizontal:
--   Horizontal: "New Rows Below" / "New Rows on Top"
--   Vertical: "New Columns to the Right" / "New Columns to the Left"
```

#### **Buff Icon Alignment** (Buff Icons viewer)
```lua
-- Setting: alignBuffIcons_growFromDirection
-- Values: "START", "CENTER", "END", "Disable"
-- Default: "START"
-- Purpose: Controls horizontal alignment of buff icons
-- Labels: "Icons grow from Left/Center/Right"
```

#### **Buff Bar Alignment** (Buff Bars viewer)
```lua
-- Setting: alignBuffBars_growFromDirection
-- Values: "TOP", "BOTTOM", "Disable"
-- Default: "BOTTOM"
-- Purpose: Controls vertical stacking of buff bars
-- Labels: "Bars grow from Bottom/Top"
```

**Note from CMC:** These settings show red asterisk (*) in CMC's panel with message:
*"To change Padding or columns/rows - Go to Edit Mode and change Icon Padding & Orientation"*

This confirms CMC expects layout-related settings to be in EditMode, while their panel handles appearance.

---

### **SuaviUI Options Panel** (Appearance - Pure Styling)
Settings that only affect visual appearance without changing layout structure. These go in SuaviUI's standard options panel.

#### **Square Icon Styling** (3 viewers × 4 settings = 12 total)
```lua
-- Per viewer: Essential, Utility, BuffIcons

cooldownManager_squareIcons_[Viewer] = false           -- Enable square styling
cooldownManager_squareIconsBorder_[Viewer] = 4         -- Border thickness (1-6px)
cooldownManager_squareIconsZoom_[Viewer] = 0           -- Icon zoom level (0-0.5)

-- Example implementation:
-- Essential: Border 4px, Zoom 0
-- Utility:   Border 4px, Zoom 0
-- BuffIcons: Border 4px, Zoom 0
```

**UI Organization:** Collapsible section "Square Icons Styling" with subsections per viewer

#### **Utility Icon Dimming**
```lua
cooldownManager_utility_dimWhenNotOnCD = false         -- Enable dimming
cooldownManager_utility_dimOpacity = 0.3               -- Dim opacity (0-0.9, displays as %)
```

**UI:** Checkbox with embedded slider (CheckboxSlider widget)

#### **Cooldown Number Font** (Global + Per-Viewer Overrides)
```lua
-- Global settings:
cooldownManager_cooldownFontName = "Friz Quadrata TT"
cooldownManager_cooldownFontFlags = {OUTLINE=true}    -- Multi-select: OUTLINE, THICKOUTLINE, MONOCHROME

-- Per-viewer size overrides (Essential, Utility, BuffIcons):
cooldownManager_cooldownFontSize[Viewer]_enabled = false
cooldownManager_cooldownFontSize[Viewer] = "NIL"       -- Values: "NIL"(default), "0"(hide), 10-38
```

**UI:** Expandable section "Cooldown Settings" with:
- Font dropdown (SharedMedia integration)
- Font flags multi-dropdown
- Per-viewer checkbox+dropdown combos

#### **Stack Number Font & Positioning** (3 viewers × 6 settings = 18 total)
```lua
-- Global stack font:
cooldownManager_stackFontName = "Friz Quadrata TT"
cooldownManager_stackFontFlags = {OUTLINE=true}

-- Per viewer (Essential, Utility, BuffIcons):
cooldownManager_stackAnchor[Viewer]_enabled = false
cooldownManager_stackAnchor[Viewer]_point = "BOTTOMRIGHT"  -- TOPLEFT, TOP, TOPRIGHT, etc.
cooldownManager_stackFontSize[Viewer] = "NIL"              -- "NIL" or 10-38
cooldownManager_stackAnchor[Viewer]_offsetX = 0            -- -40 to 40
cooldownManager_stackAnchor[Viewer]_offsetY = 0            -- -40 to 40
```

**UI:** Expandable section "Ability Stacks Number Settings" with:
- Global font/flags dropdowns
- Per-viewer subsections with enable+anchor, font size, X/Y offset sliders

**CMC Note:** Red asterisk (*) on anchor settings: *"Some changes require Reload to return to default positions and fonts"*

#### **Keybind Display** (2 viewers × 6 settings = 12 total)
```lua
-- Global keybind font:
cooldownManager_keybindFontName = "Friz Quadrata TT"
cooldownManager_keybindFontFlags = {OUTLINE=true}

-- Per viewer (Essential, Utility):
cooldownManager_showKeybinds_[Viewer] = false
cooldownManager_keybindAnchor_[Viewer] = "TOPRIGHT"    -- All 9 anchor points including CENTER
cooldownManager_keybindFontSize_[Viewer] = 14          -- 6-32 (Essential default: 14, Utility default: 10)
cooldownManager_keybindOffsetX_[Viewer] = -3           -- -40 to 40
cooldownManager_keybindOffsetY_[Viewer] = -3           -- -40 to 40
```

**UI:** Expandable section "Keybind Text Display" with:
- Global font/flags dropdowns
- Per-viewer subsections with enable+anchor, font size, X/Y offset sliders

#### **Cooldown Swipe Colors**
```lua
cooldownManager_customSwipeColor_enabled = false

-- Active aura color (when buff/ability active):
cooldownManager_customActiveColor_r/g/b/a = 1, 0.95, 0.57, 0.69

-- Cooldown swipe color (when on cooldown):
cooldownManager_customCDSwipeColor_r/g/b/a = 0, 0, 0, 0.69
```

**UI:** Expandable section "Cooldown Settings" with:
- Enable checkbox
- Color pickers with opacity sliders
- Reset to defaults button

#### **Size Controls**
```lua
cooldownManager_limitUtilitySizeToEssential = false
cooldownManager_normalizeUtilitySize = false
```

**Note:** These settings exist in CMC but may not be necessary if SuaviUI handles viewer sizing differently

#### **Rotation Highlight** (Assisted Combat)
```lua
cooldownManager_showHighlight_Essential = false
cooldownManager_showHighlight_Utility = false
```

**UI:** Checkboxes to enable rotation assist highlighting per viewer

---

## Implementation Plan

### Phase 1: Core Centering Logic (PRIORITY 1)
**Goal:** Get icons centering properly within viewers

**Files to create:**
- `utils/cooldown_centering.lua` - Copy CMC's layout engine

**Code to copy from CMC:**
```lua
-- From modules/cooldownManager.lua:

-- LayoutEngine namespace:
LayoutEngine.CenteredRowXOffsets(count, itemWidth, padding, directionModifier)
LayoutEngine.CenteredColYOffsets(count, itemHeight, padding, directionModifier)
LayoutEngine.StartRowXOffsets(...)  -- For START alignment
LayoutEngine.EndRowXOffsets(...)    -- For END alignment
LayoutEngine.BuildRows(iconLimit, children)

-- ViewerAdapters namespace:
ViewerAdapters.CollectViewerChildren(viewer, includeInactive)
ViewerAdapters.PositionRowHorizontal(icons, yOffset, xOffsets)
ViewerAdapters.PositionRowVertical(icons, xOffset, yOffsets)
ViewerAdapters.CenterAllRows(viewer, growDirection)  -- MAIN FUNCTION
ViewerAdapters.UpdateEssentialIfNeeded(immediate)
ViewerAdapters.UpdateUtilityIfNeeded(immediate)
ViewerAdapters.UpdateBuffIcons(growDirection)
ViewerAdapters.UpdateBuffBars(growDirection)

-- StateTracker namespace (for invalidation):
StateTracker.MarkViewersDirty(essential, utility)
StateTracker.MarkBuffIconsDirty()
StateTracker.MarkBuffBarsDirty()

-- EventHandler (hooking):
-- Hook OnActiveStateChanged on each icon child
-- Hook OnUnitAuraAddedEvent, OnUnitAuraRemovedEvent
-- These trigger StateTracker marking → calls Update*IfNeeded
```

**Settings integration:**
- Add growth direction dropdowns to EditMode via LibEQOL-1.0
- Hook viewer Show/Hide/SetSize events (ALREADY EXISTS in Bar.lua lines 93-130)
- Call centering functions on invalidation

**Testing:**
1. Enable centering for Essential viewer
2. Verify icons center symmetrically
3. Test growth direction changes (TOP vs BOTTOM)
4. Verify works with different icon limits (2, 3, 4 icons)

---

### Phase 2: Square Icon Styling (PRIORITY 2)
**Goal:** Apply square masks, borders, and zoom to icons

**Files to create:**
- `utils/cooldown_icons.lua` - Copy CMC's StyledIcons module

**Code to copy from CMC:**
```lua
-- From modules/styledIcons.lua (estimate - need to read this file):

-- Constants:
BASE_SQUARE_MASK = "Interface\\AddOns\\CooldownManagerCentered\\Media\\Art\\Square"

-- Functions:
StyledIcons:ApplySquareStyle(icon, viewer)
  -- Set icon:GetNormalTexture():SetMask(maskPath)
  -- Apply border via SetTexCoord zoom
  -- Calculate zoom based on settings
  
StyledIcons:RemoveSquareStyle(icon)
  -- Reset mask
  -- Reset texCoords

StyledIcons:OnSettingChanged()
  -- Refresh all icons when settings change
  
-- Hook icon creation to apply styling
-- Hook viewer icon updates
```

**Settings integration:**
- Add square icon section to SuaviUI options panel
- Collapsible section with 3 subsections (Essential, Utility, BuffIcons)
- Each subsection: Enable checkbox, Border slider (1-6px), Zoom slider (0-0.5)

**Media files needed:**
- Copy square mask texture from CMC's Media folder
- Add to SuaviUI's assets folder

**Testing:**
1. Enable square icons for Essential viewer
2. Verify border thickness changes work
3. Verify zoom level changes work
4. Test disabling returns to circular icons

---

### Phase 3: Font Customization (PRIORITY 3)
**Goal:** Customize cooldown/stack/keybind fonts

**Files to create:**
- `utils/cooldown_fonts.lua` - Copy CMC's font handling modules

**Code to copy from CMC:**
```lua
-- From modules/cooldownFont.lua:
CooldownFont:RefreshAll()
CooldownFont:ApplyFontToViewer(viewer)
-- Hook cooldown text creation
-- Apply font/size/flags from settings

-- From modules/stacks.lua:
Stacks:OnSettingChanged()
Stacks:ApplyStackFonts(viewerType)  -- "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer"
-- Hook stack text creation
-- Apply anchor, font, size, offsets

-- From modules/keybinds.lua:
Keybinds:OnSettingChanged(viewerType)
Keybinds:ApplyKeybindSettings(viewerType)
-- Create keybind text fontstrings
-- Position based on anchor + offsets
-- Get keybind text from action bar slots
```

**Settings integration:**
- Add font sections to SuaviUI options panel
- SharedMedia integration for font dropdowns
- Multi-dropdown for font flags (OUTLINE, THICKOUTLINE, MONOCHROME)
- Per-viewer enable+override controls

**Dependencies:**
- LibSharedMedia-3.0 (ALREADY EXISTS in libs/)

**Testing:**
1. Change cooldown font, verify applies to all viewers
2. Override font size for Essential, verify only Essential changes
3. Test stack anchor positioning with offsets
4. Test keybind display on/off per viewer

---

### Phase 4: Advanced Features (PRIORITY 4)
**Goal:** Dimming, swipe colors, size controls, highlights

**Code to copy from CMC:**
```lua
-- Utility dimming:
-- Apply alpha to icons based on cooldown state
-- Monitor cooldown changes, update alpha

-- Swipe colors:
-- Hook Cooldown:SetSwipeColor
-- Apply custom colors from settings

-- Size controls:
-- Monitor Essential viewer width
-- Constrain Utility viewer width if enabled

-- Rotation highlight:
-- Integration with rotation assist addon
-- Apply glow/highlight to next ability in rotation
```

**Settings integration:**
- Dimming: Checkbox with opacity slider (CheckboxSlider widget)
- Swipe colors: Expandable section with color pickers
- Size controls: Simple checkboxes
- Highlights: Enable checkboxes per viewer

---

## File Structure

```
utils/
  cooldown_centering.lua      -- Phase 1: LayoutEngine, ViewerAdapters, StateTracker
  cooldown_icons.lua          -- Phase 2: Square styling, masks, borders
  cooldown_fonts.lua          -- Phase 3: Font customization (CD/Stack/Keybind)
  cooldown_advanced.lua       -- Phase 4: Dimming, colors, size, highlights
  
  utils.xml                   -- Add new script loads

assets/
  cooldown/
    square_mask.tga           -- Copy from CMC's Media/Art/Square

utils/resourcebars/
  Bars/Abstract/Bar.lua       -- Already has CMC width sync hooks (lines 93-130)
  
utils/
  sui_options.lua             -- Add cooldown styling options panel
```

---

## Settings Panel Structure (SuaviUI Options)

```lua
-- Main category: "Cooldown Viewers"

├─ [Text] "Layout settings (growth direction, padding, orientation) are in Edit Mode"
│
├─ [Checkbox+Slider] Dim Utility Icons When Not On CD
│   └─ Slider: Opacity (0-90%, default 30%)
│
├─ [Expandable] Square Icons Styling
│   ├─ [Text] "Padding controlled via Edit Mode"
│   │
│   ├─ [Header] Buff Icons
│   │   ├─ [Checkbox] Enable Square Buff Icons
│   │   ├─ [Slider] Border Thickness (1-6px, default 4)
│   │   └─ [Slider] Icon Zoom (0-0.5, default 0)
│   │
│   ├─ [Header] Essential Cooldowns
│   │   ├─ [Checkbox] Enable Square Essential Icons
│   │   ├─ [Slider] Border Thickness (1-6px, default 4)
│   │   └─ [Slider] Icon Zoom (0-0.5, default 0)
│   │
│   └─ [Header] Utility Cooldowns
│       ├─ [Checkbox] Enable Square Utility Icons
│       ├─ [Slider] Border Thickness (1-6px, default 4)
│       └─ [Slider] Icon Zoom (0-0.5, default 0)
│
├─ [Expandable] Cooldown Settings
│   ├─ [Checkbox] Enable Custom Swipe Colors
│   ├─ [ColorPicker] Active Aura Color (with opacity)
│   ├─ [ColorPicker] Cooldown Swipe Color (with opacity)
│   ├─ [Button] Reset to Defaults
│   │
│   ├─ [Header] Cooldown Number Font
│   ├─ [FontDropdown] Font (SharedMedia)
│   ├─ [MultiDropdown] Font Flags (Outline, Thick, Mono)
│   │
│   ├─ [Checkbox+Dropdown] Essential Font Size Override
│   ├─ [Checkbox+Dropdown] Utility Font Size Override
│   └─ [Checkbox+Dropdown] Buff Icons Font Size Override
│
├─ [Expandable] Ability Stacks Number Settings
│   ├─ [Text] "Some changes require Reload"
│   ├─ [FontDropdown] Stack Font
│   ├─ [MultiDropdown] Font Flags
│   │
│   ├─ [Header] Tracked Buff Icons
│   │   ├─ [Checkbox+Dropdown] Enable & Anchor Point
│   │   ├─ [Dropdown] Font Size (10-38 or "Don't change")
│   │   ├─ [Slider] X Offset (-40 to 40)
│   │   └─ [Slider] Y Offset (-40 to 40)
│   │
│   ├─ [Header] Essential Cooldowns
│   │   ├─ [Checkbox+Dropdown] Enable & Anchor Point
│   │   ├─ [Dropdown] Font Size
│   │   ├─ [Slider] X Offset
│   │   └─ [Slider] Y Offset
│   │
│   └─ [Header] Utility Cooldowns
│       ├─ [Checkbox+Dropdown] Enable & Anchor Point
│       ├─ [Dropdown] Font Size
│       ├─ [Slider] X Offset
│       └─ [Slider] Y Offset
│
├─ [Expandable] Keybind Text Display
│   ├─ [FontDropdown] Keybind Font
│   ├─ [MultiDropdown] Font Flags
│   │
│   ├─ [Header] Essential Cooldowns
│   │   ├─ [Checkbox+Dropdown] Enable & Anchor Point (9 positions incl. CENTER)
│   │   ├─ [Dropdown] Font Size (6-32, default 14)
│   │   ├─ [Slider] X Offset (-40 to 40, default -3)
│   │   └─ [Slider] Y Offset (-40 to 40, default -3)
│   │
│   └─ [Header] Utility Cooldowns
│       ├─ [Checkbox+Dropdown] Enable & Anchor Point
│       ├─ [Dropdown] Font Size (6-32, default 10)
│       ├─ [Slider] X Offset (-40 to 40, default -3)
│       └─ [Slider] Y Offset (-40 to 40, default -3)
│
└─ [Section] Advanced
    ├─ [Checkbox] Limit Utility Size to Essential Width
    ├─ [Checkbox] Normalize Utility Size
    ├─ [Checkbox] Show Rotation Highlight - Essential
    └─ [Checkbox] Show Rotation Highlight - Utility
```

---

## EditMode Integration Structure

```lua
-- In resource bar LEMSettingsLoader.lua (or new file: cooldown_editmode.lua)

-- Add to each viewer's EditMode settings:

Settings:AddInitializer({
    name = "Growth Direction",
    type = "dropdown",
    options = function()
        local viewer = [get current viewer]
        return {
            {
                value = "TOP",
                label = viewer.isHorizontal and "New Rows Below" or "New Columns to the Right"
            },
            {
                value = "BOTTOM",
                label = viewer.isHorizontal and "New Rows on Top" or "New Columns to the Left"
            },
            {
                value = "Disable",
                label = "Disable dynamic layout"
            }
        }
    end,
    get = function()
        return SuaviDB.profile.cooldown_growDirection_Essential or "TOP"
    end,
    set = function(value)
        SuaviDB.profile.cooldown_growDirection_Essential = value
        -- Trigger centering refresh
        SuaviUI.Cooldown.RefreshCentering("Essential")
    end
})

-- Similar for Utility viewer

-- For Buff Icons viewer:
Settings:AddInitializer({
    name = "Icon Alignment",
    type = "dropdown",
    options = {
        {value = "START", label = "Icons grow from Left"},
        {value = "CENTER", label = "Icons grow from Center"},
        {value = "END", label = "Icons grow from Right"},
        {value = "Disable", label = "Disable dynamic layout"}
    },
    get = function()
        return SuaviDB.profile.cooldown_alignBuffIcons or "START"
    end,
    set = function(value)
        SuaviDB.profile.cooldown_alignBuffIcons = value
        SuaviUI.Cooldown.RefreshBuffIcons()
    end
})

-- For Buff Bars viewer:
Settings:AddInitializer({
    name = "Bar Alignment",
    type = "dropdown",
    options = {
        {value = "BOTTOM", label = "Bars grow from Bottom"},
        {value = "TOP", label = "Bars grow from Top"},
        {value = "Disable", label = "Disable dynamic layout"}
    },
    get = function()
        return SuaviDB.profile.cooldown_alignBuffBars or "BOTTOM"
    end,
    set = function(value)
        SuaviDB.profile.cooldown_alignBuffBars = value
        SuaviUI.Cooldown.RefreshBuffBars()
    end
})
```

---

## Database Defaults

```lua
-- Add to SuaviDB defaults (wherever profile defaults are defined):

profile = {
    -- ... existing defaults ...
    
    -- LAYOUT (EditMode controls)
    cooldown_growDirection_Essential = "TOP",
    cooldown_growDirection_Utility = "TOP",
    cooldown_alignBuffIcons = "START",
    cooldown_alignBuffBars = "BOTTOM",
    
    -- APPEARANCE (Options panel controls)
    
    -- Dimming:
    cooldown_utility_dimWhenNotOnCD = false,
    cooldown_utility_dimOpacity = 0.3,
    
    -- Square icons:
    cooldown_squareIcons_Essential = false,
    cooldown_squareIconsBorder_Essential = 4,
    cooldown_squareIconsZoom_Essential = 0,
    
    cooldown_squareIcons_Utility = false,
    cooldown_squareIconsBorder_Utility = 4,
    cooldown_squareIconsZoom_Utility = 0,
    
    cooldown_squareIcons_BuffIcons = false,
    cooldown_squareIconsBorder_BuffIcons = 4,
    cooldown_squareIconsZoom_BuffIcons = 0,
    
    -- Swipe colors:
    cooldown_customSwipeColor_enabled = false,
    cooldown_customActiveColor_r = 1,
    cooldown_customActiveColor_g = 0.95,
    cooldown_customActiveColor_b = 0.57,
    cooldown_customActiveColor_a = 0.69,
    cooldown_customCDSwipeColor_r = 0,
    cooldown_customCDSwipeColor_g = 0,
    cooldown_customCDSwipeColor_b = 0,
    cooldown_customCDSwipeColor_a = 0.69,
    
    -- Cooldown font:
    cooldown_fontName = "Friz Quadrata TT",
    cooldown_fontFlags = {OUTLINE = true},
    cooldown_fontSizeEssential_enabled = false,
    cooldown_fontSizeEssential = "NIL",
    cooldown_fontSizeUtility_enabled = false,
    cooldown_fontSizeUtility = "NIL",
    cooldown_fontSizeBuffIcons_enabled = false,
    cooldown_fontSizeBuffIcons = "NIL",
    
    -- Stack font:
    cooldown_stackFontName = "Friz Quadrata TT",
    cooldown_stackFontFlags = {OUTLINE = true},
    
    cooldown_stackAnchorEssential_enabled = false,
    cooldown_stackAnchorEssential_point = "BOTTOMRIGHT",
    cooldown_stackFontSizeEssential = "NIL",
    cooldown_stackAnchorEssential_offsetX = 0,
    cooldown_stackAnchorEssential_offsetY = 0,
    
    cooldown_stackAnchorUtility_enabled = false,
    cooldown_stackAnchorUtility_point = "BOTTOMRIGHT",
    cooldown_stackFontSizeUtility = "NIL",
    cooldown_stackAnchorUtility_offsetX = 0,
    cooldown_stackAnchorUtility_offsetY = 0,
    
    cooldown_stackAnchorBuffIcons_enabled = false,
    cooldown_stackAnchorBuffIcons_point = "BOTTOMRIGHT",
    cooldown_stackFontSizeBuffIcons = "NIL",
    cooldown_stackAnchorBuffIcons_offsetX = 0,
    cooldown_stackAnchorBuffIcons_offsetY = 0,
    
    -- Keybinds:
    cooldown_keybindFontName = "Friz Quadrata TT",
    cooldown_keybindFontFlags = {OUTLINE = true},
    
    cooldown_showKeybinds_Essential = false,
    cooldown_keybindAnchor_Essential = "TOPRIGHT",
    cooldown_keybindFontSize_Essential = 14,
    cooldown_keybindOffsetX_Essential = -3,
    cooldown_keybindOffsetY_Essential = -3,
    
    cooldown_showKeybinds_Utility = false,
    cooldown_keybindAnchor_Utility = "TOPRIGHT",
    cooldown_keybindFontSize_Utility = 10,
    cooldown_keybindOffsetX_Utility = -3,
    cooldown_keybindOffsetY_Utility = -3,
    
    -- Size controls:
    cooldown_limitUtilitySizeToEssential = false,
    cooldown_normalizeUtilitySize = false,
    
    -- Rotation highlight:
    cooldown_showHighlight_Essential = false,
    cooldown_showHighlight_Utility = false,
}
```

---

## Critical Implementation Notes

### 1. Copy Algorithms EXACTLY
From DEVELOPMENT_PRINCIPLES.md: **When in doubt, copy Sensei exactly.**

CMC is our "Sensei" for cooldown centering. Do NOT attempt to:
- "Improve" the offset calculations
- "Optimize" the centering algorithm  
- "Simplify" the row building logic
- Change variable names to match SuaviUI conventions (can rename in comments but keep exact logic)

### 2. Hook Points
CMC hooks these events - we must do the same:
- `OnActiveStateChanged` on each icon
- `OnUnitAuraAddedEvent` on viewers
- `OnUnitAuraRemovedEvent` on viewers
- Viewer `Show`, `Hide`, `SetSize` (ALREADY HOOKED in Bar.lua)

### 3. StateTracker Pattern
CMC uses invalidation/dirty marking instead of immediate updates:
```lua
-- Mark dirty:
StateTracker.MarkViewersDirty(essential, utility)

-- Later (on next frame or event):
ViewerAdapters.UpdateEssentialIfNeeded()
ViewerAdapters.UpdateUtilityIfNeeded()
```

This prevents redundant centering calculations. Copy this pattern.

### 4. Adaptive Labels
Growth direction labels change based on viewer orientation:
```lua
local label = viewer.isHorizontal 
    and "New Rows Below"           -- Horizontal growth = vertical stacking
    or "New Columns to the Right"  -- Vertical growth = horizontal stacking
```

EditMode dropdowns must implement this adaptive labeling.

### 5. Reload Requirements
CMC notes some settings require `/reload` to fully apply (especially stack anchoring returning to defaults). Document this clearly in our UI.

### 6. SharedMedia Integration
All font dropdowns use LibSharedMedia-3.0 (already in our libs/). Must:
- Query `LSM:HashTable(LSM.MediaType.FONT)` for font list
- Sort alphabetically
- Display font name IN that font (CMC creates font pool for dropdown items)
- Default to "Friz Quadrata TT"

### 7. Prefix Consistency
CMC prefixes all settings with `cooldownManager_` in their saved variables. We can use `cooldown_` since we're integrating into SuaviUI's namespace.

---

## Testing Checklist

### Phase 1 (Centering):
- [ ] Essential viewer icons center horizontally
- [ ] Growth direction TOP stacks rows downward
- [ ] Growth direction BOTTOM stacks rows upward
- [ ] Works with 2, 3, 4, 5+ icons
- [ ] Buff icons align START/CENTER/END correctly
- [ ] Buff bars stack TOP/BOTTOM correctly
- [ ] "Disable" option removes centering
- [ ] No performance issues (invalidation works)

### Phase 2 (Square Icons):
- [ ] Square mask applies correctly
- [ ] Border thickness changes visible
- [ ] Zoom level changes icon texture size
- [ ] Enable/disable toggles work per viewer
- [ ] Essential, Utility, BuffIcons independent
- [ ] Returns to circular when disabled

### Phase 3 (Fonts):
- [ ] Cooldown font changes apply globally
- [ ] Per-viewer size override works
- [ ] Font flags (OUTLINE, etc.) apply
- [ ] Stack anchor positioning works
- [ ] Stack font size changes visible
- [ ] Keybind text displays correctly
- [ ] Keybind anchor positions work
- [ ] SharedMedia fonts load properly

### Phase 4 (Advanced):
- [ ] Utility dimming applies correct opacity
- [ ] Dim only when NOT on cooldown
- [ ] Swipe colors customize correctly
- [ ] Size constraints work (utility matches essential)
- [ ] Rotation highlights show on correct icons

---

## Migration from CMC (User Experience)

Users who have CooldownManagerCentered installed will need to:

1. **Disable CMC addon** before enabling SuaviUI's cooldown features
2. **Settings will NOT auto-migrate** (CMC uses `cooldownManager_*` prefix, we use `cooldown_*`)
3. **Reconfigure settings** in SuaviUI's panels:
   - EditMode: Growth directions (same concept, new location)
   - Options: All appearance settings (same names, cleaner organization)

We could potentially create a migration function:
```lua
-- Check if CMC settings exist in global SavedVariables
-- Copy to SuaviUI equivalents
-- Prompt user to disable CMC addon
```

This would be a Phase 5 "nice to have" feature.

---

## Summary

**COPY, DON'T INVENT:**
- Phase 1: Copy centering algorithms exactly from CMC
- Phase 2: Copy square icon styling exactly
- Phase 3: Copy font handling exactly
- Phase 4: Copy advanced features exactly

**SETTINGS SPLIT:**
- **EditMode:** Growth direction (layout structure)
- **Options Panel:** Everything else (appearance)

**DOCUMENTATION:**
- Users know where to find settings
- Clear that padding/orientation stay in Blizzard's EditMode
- Note which settings require `/reload`

**TESTING:**
- Systematic per-phase validation
- Compare side-by-side with CMC to verify identical behavior
