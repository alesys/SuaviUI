# Blizzard Edit Mode Integration Guide

**Last Updated**: January 29, 2026  
**Target**: SuaviUI CDM Migration to Edit Mode

---

## Table of Contents
1. [Overview](#overview)
2. [Frame Registration](#frame-registration)
3. [Layout Storage](#layout-storage)
4. [Callbacks & Events](#callbacks--events)
5. [Settings System](#settings-system)
6. [Scale System](#scale-system)
7. [Selection & Magnetism](#selection--magnetism)
8. [LibEQOL vs Native](#libeqol-vs-native)
9. [CDM Integration Plan](#cdm-integration-plan)

---

## Overview

**Edit Mode** is Blizzard's UI customization system introduced in Dragonflight. It allows dragging/scaling frames and persisting layouts per character.

### Key Components
- **EditModeManagerFrame**: Main controller (`/run EditModeManagerFrame:Show()`)
- **EditModeSystemMixin**: Mixin for Blizzard frames (limited addon access)
- **LibEQOL**: Third-party library providing full Edit Mode API for addons
- **Layout System**: Named layouts (Modern, Classic, Custom) per character

### What Edit Mode Provides
✅ Drag-to-position with magnetic snapping  
✅ Scale slider (25% to 200%)  
✅ Multi-layout support  
✅ Save/Revert/Reset infrastructure  
✅ Settings panels per frame  
✅ Visual selection overlay  

### What Edit Mode Does NOT Provide
❌ Pixel-perfect sizing (only % scale)  
❌ Custom layout logic (row patterns, etc.)  
❌ Text overlays (keybinds, durations)  
❌ Icon-level customization  

---

## Frame Registration

### LibEQOL Method (Recommended)

```lua
local LEM = LibStub("LibEQOL-1.0")

-- Simple registration
LEM:AddFrame(
    frameRef,                    -- Frame object
    onPositionChangedCallback,   -- function(frame, layoutName, point, x, y)
    defaults                     -- Default values table
)

-- Full example
local function OnPositionChanged(frame, layoutName, point, x, y)
    -- Save to profile
    SuaviUI_DB[layoutName] = SuaviUI_DB[layoutName] or {}
    SuaviUI_DB[layoutName].point = point
    SuaviUI_DB[layoutName].x = x
    SuaviUI_DB[layoutName].y = y
    
    -- Reapply layout
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
end

local defaults = {
    point = "CENTER",
    relativeFrame = "UIParent",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
    scale = 1.0,
    enableOverlayToggle = true,  -- Show/hide frame in Edit Mode
    settingsMaxHeight = 600,     -- Settings panel max height
}

LEM:AddFrame(EssentialCooldownViewer, OnPositionChanged, defaults)
```

### Advanced Frame Options

```lua
-- Disable dragging conditionally
LEM:SetFrameDragEnabled(frame, false)  -- Lock frame position

-- Force refresh settings UI
LEM.internal:RefreshSettingValues({ "Setting Name 1", "Setting Name 2" })
```

### Native Blizzard Method (Limited)

Blizzard's `EditModeManagerFrame:RegisterSystemFrame()` is designed for internal frames only. **Use LibEQOL instead.**

---

## Layout Storage

### Layout System

Edit Mode supports multiple named layouts per character:
- **Modern** (default)
- **Classic**
- **Custom 1-5**

Layouts store:
- Frame positions (point, x, y, relativeFrame)
- Scale values
- Custom settings (checkboxes, sliders, etc.)

### Database Structure Pattern

```lua
-- Per-layout storage
MyAddon_DB = {
    ["Modern"] = {
        EssentialCooldownViewer = {
            point = "CENTER",
            relativePoint = "CENTER",
            relativeFrame = "UIParent",
            x = 0,
            y = 100,
            -- Custom settings NOT handled by Edit Mode
            iconSize = 50,
            spacing = 4,
            useRowPattern = true,
        },
    },
    ["Classic"] = { ... },
}
```

### Layout API

```lua
-- Get active layout name
local layoutName = LEM.GetActiveLayoutName()  -- "Modern", "Classic", etc.

-- Get all layouts
local layouts = LEM:GetLayouts()
-- Returns: { {name="Modern", isActive=true}, {name="Classic"}, ... }
```

---

## Callbacks & Events

### LibEQOL Callbacks

```lua
-- Layout switched
LEM:RegisterCallback("layout", function(layoutName)
    -- Apply new layout settings
    ApplyLayoutForCDM(layoutName)
end)

-- Layout duplicated
LEM:RegisterCallback("layoutduplicate", function(_, duplicateIndices, _, _, newLayoutName)
    local sourceLayout = LEM:GetLayouts()[duplicateIndices[1]].name
    -- Copy settings from source to new
    MyAddon_DB[newLayoutName] = CopyTable(MyAddon_DB[sourceLayout])
end)

-- Layout renamed
LEM:RegisterCallback("layoutrenamed", function(oldName, newName)
    MyAddon_DB[newName] = MyAddon_DB[oldName]
    MyAddon_DB[oldName] = nil
end)

-- Layout deleted
LEM:RegisterCallback("layoutdeleted", function(_, layoutName)
    MyAddon_DB[layoutName] = nil
end)

-- Edit Mode entered
LEM:RegisterCallback("enter", function()
    -- Show preview icons, enable dragging, etc.
    frame:Show()
    frame:SetAlpha(1.0)
end)

-- Edit Mode exited
LEM:RegisterCallback("exit", function()
    -- Apply visibility rules, hide preview
    ApplyVisibilitySettings()
end)
```

### EditModeManagerFrame Hooks

```lua
-- Hook save button
hooksecurefunc(EditModeManagerFrame, "SaveLayouts", function()
    -- User clicked "Save" - persist to SavedVariables
    SuaviUI:SaveSettingsToProfile()
end)

-- Hook exit
hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
    -- Clean up edit overlays
    HideCustomOverlays()
end)

-- Check if in Edit Mode
local isInEditMode = LEM:IsInEditMode()
```

---

## Settings System

### Setting Types

LibEQOL supports these setting types:

```lua
LEM.SettingType = {
    Checkbox = 1,
    Slider = 2,
    Dropdown = 3,
    ColorPicker = 4,
    MultiDropdown = 5,
    Button = 6,
}
```

### Settings Structure

```lua
local function BuildSettings()
    return {
        -- Category header
        {
            kind = LEM.SettingType.Checkbox,
            parentId = nil,  -- Top-level category
            order = 1,
            name = "Position & Size",
            isCategoryHeader = true,
        },
        
        -- Checkbox
        {
            kind = LEM.SettingType.Checkbox,
            parentId = "Position & Size",
            order = 2,
            name = "Lock Position",
            tooltip = "Prevent accidental dragging",
            default = false,
            get = function(layoutName)
                return MyAddon_DB[layoutName].locked or false
            end,
            set = function(layoutName, value)
                MyAddon_DB[layoutName].locked = value
                LEM:SetFrameDragEnabled(frame, not value)
            end,
        },
        
        -- Slider
        {
            kind = LEM.SettingType.Slider,
            parentId = "Position & Size",
            order = 3,
            name = "Icon Size",
            tooltip = "Size in pixels (25-100)",
            default = 50,
            minValue = 25,
            maxValue = 100,
            valueStep = 1,
            allowInput = true,  -- Allow typing value
            get = function(layoutName)
                return MyAddon_DB[layoutName].iconSize or 50
            end,
            set = function(layoutName, value)
                MyAddon_DB[layoutName].iconSize = value
                ApplyIconSizes(frame)
                -- Mark Edit Mode dirty
                if LEM:IsInEditMode() then
                    EditModeManagerFrame.hasActiveChanges = true
                    EditModeManagerFrame:UpdateSaveButton()
                end
            end,
        },
        
        -- Dropdown
        {
            kind = LEM.SettingType.Dropdown,
            parentId = "Position & Size",
            order = 4,
            name = "Row Alignment",
            default = "CENTER",
            options = {
                { value = "LEFT", text = "Left" },
                { value = "CENTER", text = "Center" },
                { value = "RIGHT", text = "Right" },
            },
            get = function(layoutName)
                return MyAddon_DB[layoutName].rowAlignment or "CENTER"
            end,
            set = function(layoutName, value)
                MyAddon_DB[layoutName].rowAlignment = value
                ApplyLayout(frame)
            end,
        },
        
        -- Action Button
        {
            kind = LEM.SettingType.Button,
            parentId = "Position & Size",
            order = 5,
            name = "Reset to Defaults",
            tooltip = "Reset all settings for this frame",
            callback = function()
                local layoutName = LEM.GetActiveLayoutName()
                MyAddon_DB[layoutName] = CopyTable(defaults)
                ApplyLayout(frame)
                LEM.internal:RefreshSettingValues()
            end,
        },
    }
end

-- Register settings
LEM:AddFrameSettings(frame, BuildSettings())
```

### Dynamic Texture Dropdowns

```lua
-- Dropdown with texture previews (like Resource Bars)
local LSM = LibStub("LibSharedMedia-3.0")

{
    kind = LEM.SettingType.Dropdown,
    name = "Bar Texture",
    default = "Blizzard",
    options = function()
        local textures = LSM:List(LSM.MediaType.STATUSBAR)
        local options = {}
        for _, name in ipairs(textures) do
            table.insert(options, { value = name, text = name })
        end
        return options
    end,
    get = function(layoutName)
        return MyAddon_DB[layoutName].texture or "Blizzard"
    end,
    set = function(layoutName, value)
        MyAddon_DB[layoutName].texture = value
        ApplyTexture(frame, LSM:Fetch(LSM.MediaType.STATUSBAR, value))
    end,
}
```

---

## Scale System

### How Scale Works

Edit Mode scale is a **percentage multiplier** applied to the entire frame:
- Range: 25% to 200% (0.25 to 2.0)
- Affects: Width, height, font sizes, positions
- Does NOT affect: Texture resolution

```lua
-- Get current scale
local scale = frame:GetScale()  -- 1.0 = 100%

-- Set scale (done by Edit Mode automatically)
frame:SetScale(1.5)  -- 150%
```

### Scale vs Absolute Size

**Problem**: Blizzard uses scale %, but we want pixel-perfect icon sizes.

**Solution**: Separate base size from scale:

```lua
-- Base icon size (in settings)
local baseIconSize = 50  -- pixels

-- Edit Mode scale (from layout)
local editModeScale = 1.2  -- 120%

-- Actual render size
local actualSize = baseIconSize * editModeScale  -- 60 pixels

-- Apply to icon
icon:SetSize(baseIconSize, baseIconSize)  -- Set base size
frame:SetScale(editModeScale)  -- Let Edit Mode scale the frame
```

### Converting Coordinates

When frame is scaled, coordinates must be adjusted:

```lua
-- Frame at 150% scale
local scale = frame:GetScale()  -- 1.5
local x, y = frame:GetPoint()

-- Unscaled coordinates (for storage)
local unscaledX = x / scale
local unscaledY = y / scale

-- Scaled coordinates (for display)
local scaledX = unscaledX * scale
```

---

## Selection & Magnetism

### Selection Overlay

Edit Mode shows a selection box around the dragged frame:

```lua
-- Frame must have a Selection child frame
if not frame.Selection then
    frame.Selection = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
end

-- Selection covers the entire frame
frame.Selection:SetAllPoints(frame)
```

### GetScaledSelectionSides

**Critical Bug**: Blizzard's `GetScaledSelectionSides` crashes if `GetRect()` returns nil.

**Fix** (already in sui_ncdm.lua):

```lua
hooksecurefunc(EditModeSystemMixin, "GetScaledSelectionSides", function(self)
    local left = self:GetLeft()
    if not left then
        return 0, 0, 0, 0  -- Prevent crash
    end
    -- Original code continues...
end)
```

### Magnetic Snapping

Frames snap to each other when dragged close:

```lua
-- Check if frame can snap to others
local canSnap = LEM:CanFrameSnap(frame)

-- Temporarily disable snapping
frame.isEligibleForMagnetism = function() return false end

-- Re-enable snapping
frame.isEligibleForMagnetism = nil  -- Use default behavior
```

**Circular Anchor Detection**: Edit Mode prevents frames from anchoring to themselves or creating loops.

---

## LibEQOL vs Native

### Why Use LibEQOL?

| Feature | LibEQOL | Native Edit Mode |
|---------|---------|------------------|
| Addon frame support | ✅ Full | ❌ Limited |
| Position callbacks | ✅ Yes | ❌ No |
| Custom settings | ✅ Full API | ⚠️ Complex |
| Layout management | ✅ Built-in | ⚠️ Manual |
| Magnetic snapping | ✅ Automatic | ⚠️ Manual |
| Selection overlay | ✅ Automatic | ⚠️ Manual |
| Drag control | ✅ API | ❌ No |
| Multi-layout | ✅ Built-in | ⚠️ Manual |

**Recommendation**: Use LibEQOL for addon frames.

### Current SuaviUI Usage

**Already using LibEQOL**:
- ✅ Resource Bars (HealthBar, PrimaryResourceBar, etc.)

**Not using Edit Mode**:
- ❌ Essential/Utility Cooldowns (custom nudge system)
- ❌ Unit Frames (custom drag system)
- ❌ Buff Bar (custom positioning)

---

## CDM Integration Plan

### Goals
1. ✅ Remove duplicate position/scale code
2. ✅ Use Edit Mode for CDM dragging
3. ✅ Keep custom layout logic (row patterns, iconSize)
4. ✅ Hook Blizzard's Save button
5. ✅ Remove custom "Save & Exit" button
6. ✅ Store everything in SuaviUI profile

### Architecture

```
┌─────────────────────────────────────────┐
│  Edit Mode (Position, Scale, Layout)   │
│  - Handles: x, y, dragging, snapping   │
│  - Storage: Per layout in profile      │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  SuaviUI CDM (Icon Layout, Styling)    │
│  - Handles: iconSize, spacing, rows    │
│  - Storage: Profile settings           │
└─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────┐
│  ApplyViewerLayout() (Render Icons)    │
│  - Reads: iconSize, rowPattern         │
│  - Calculates: Icon positions          │
│  - Applies: Layout within frame        │
└─────────────────────────────────────────┘
```

### Database Structure

```lua
-- NEW: Store CDM in profile with Edit Mode layouts
SuaviUI_DB = {
    profile = {
        viewers = {
            EssentialCooldownViewer = {
                -- Edit Mode handles these automatically
                -- (don't store in profile, read from LEM)
                -- position, scale → managed by Edit Mode
                
                -- SUI-specific settings
                iconSize = 50,         -- Base size before scale
                spacing = -11,
                useRowPattern = true,
                row1Icons = 6,
                row2Icons = 6,
                rowAlignment = "CENTER",
                -- ... etc
            },
        },
    },
}

-- Edit Mode stores position/scale per layout internally
-- Access via: LEM.GetActiveLayoutName()
```

### Implementation Steps

**Step 1**: Register CDM with LibEQOL
```lua
local function OnPositionChanged(frame, layoutName, point, x, y)
    -- Edit Mode handles position automatically
    -- Just reapply layout to ensure icons are positioned
    ApplyViewerLayout(frame)
end

LEM:AddFrame(EssentialCooldownViewer, OnPositionChanged, {
    point = "CENTER",
    relativeFrame = "UIParent",
    relativePoint = "CENTER",
    x = 0,
    y = -200,
})
```

**Step 2**: Build Settings Panel
```lua
local function BuildCDMSettings()
    return {
        {
            kind = LEM.SettingType.Slider,
            name = "Icon Size",
            default = 50,
            minValue = 25,
            maxValue = 100,
            get = function(layoutName)
                return SUICore.db.profile.viewers.EssentialCooldownViewer.iconSize
            end,
            set = function(layoutName, value)
                SUICore.db.profile.viewers.EssentialCooldownViewer.iconSize = value
                ApplyViewerLayout(EssentialCooldownViewer)
                MarkEditModeDirty()
            end,
        },
        -- ... more settings
    }
end

LEM:AddFrameSettings(EssentialCooldownViewer, BuildCDMSettings())
```

**Step 3**: Hook Save Button
```lua
hooksecurefunc(EditModeManagerFrame, "SaveLayouts", function()
    -- Settings already saved by individual set() callbacks
    -- Just ensure database is marked for write
    SuaviUI_DB._lastSaved = time()
end)
```

**Step 4**: Remove Old System
- Delete custom nudge arrows for CDM
- Remove "Save & Exit" button
- Remove manual position storage code

### Testing Plan
1. Enter Edit Mode → CDM appears with selection box
2. Drag CDM → snaps to other frames
3. Change iconSize slider → icons resize, Save button enables
4. Click Save → settings persist
5. Reload → position and settings restored
6. Switch layout → CDM moves to layout-specific position
7. Exit without save → reverts correctly

---

## Best Practices

### ✅ DO
- Use LibEQOL for addon frames
- Store custom settings in profile
- Mark Edit Mode dirty when settings change
- Hook `SaveLayouts` for persistence
- Test with multiple layouts
- Handle nil returns from `GetRect()`

### ❌ DON'T
- Try to register with native `EditModeManagerFrame:RegisterSystemFrame()`
- Store position/scale in profile (Edit Mode handles this)
- Modify frames during combat
- Assume `GetScaledSelectionSides` won't crash
- Forget to enable/disable drag when needed

---

## Common Issues

**Q: Icons disappear when switching layouts**  
A: Register callback for `"layout"` event and reapply settings.

**Q: Frame size changes break Edit Mode**  
A: Use fixed-size container, position icons within it.

**Q: Settings don't persist**  
A: Hook `SaveLayouts` and ensure database writes.

**Q: Crash in Edit Mode**  
A: Check `GetScaledSelectionSides` hook is applied.

**Q: Can't drag frame**  
A: Ensure `LEM:SetFrameDragEnabled(frame, true)`.

---

## Reference Code

**Resource Bars Example**: `utils/resourcebars/LEMSettingsLoader.lua`
- Full LibEQOL integration
- Position callbacks
- Settings registration
- Layout management

**Edit Mode Hooks**: `utils/suicore_main.lua:4488`
- ExitEditMode hook
- ForceReskinAllViewers

**NCDM Current**: `utils/sui_ncdm.lua`
- Custom layout logic to preserve
- Icon sizing and positioning
- Row pattern calculations

---

**END OF DOCUMENTATION**
