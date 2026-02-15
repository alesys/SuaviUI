# Blizzard Edit Mode System - Comprehensive Documentation

*Generated: 2026-01-29*

This document provides a complete reference for integrating custom frames with Blizzard's Edit Mode system in World of Warcraft, based on research from SuaviUI and SenseiClassResourceBar codebases.

---

## Table of Contents

1. [Frame Registration](#1-frame-registration)
2. [System Frames vs Custom Frames](#2-system-frames-vs-custom-frames)
3. [Layout Storage](#3-layout-storage)
4. [Callbacks](#4-callbacks)
5. [Settings System](#5-settings-system)
6. [Scale vs Size](#6-scale-vs-size)
7. [Selection Overlay](#7-selection-overlay)
8. [Magnetic Snapping](#8-magnetic-snapping)
9. [LibEQOL Integration](#9-libeqol-integration)
10. [Real Examples](#10-real-examples)

---

## 1. Frame Registration

### Native Blizzard Edit Mode Registration

Blizzard frames register with `EditModeManagerFrame` but the exact API is not directly exposed for addons. The system uses:

- **EditModeManagerFrame**: The main manager frame
- **EditModeSystemMixin**: A mixin that Blizzard frames inherit from
- **System Registration**: Frames register as "systems" with the manager

**Key Issue**: The native registration API is designed for Blizzard frames only and is not easily accessible to addon developers.

### LibEQOL Registration (Recommended for Addons)

LibEQOL provides a clean wrapper API for custom frame registration:

```lua
-- Basic Frame Registration
LibEQOL:AddFrame(frame, callback, defaults)

-- Parameters:
-- frame: Your UI frame to make draggable/configurable
-- callback: function(frame, layoutName, point, x, y) - called when position changes
-- defaults: table with default positioning/sizing options
```

#### Full Registration Example

```lua
local LEM = LibStub("LibEQOLEditMode-1.0")

local function OnPositionChanged(frame, layoutName, point, x, y)
    -- Save new position to your database
    MyAddonDB[layoutName] = MyAddonDB[layoutName] or {}
    MyAddonDB[layoutName].point = point
    MyAddonDB[layoutName].x = x
    MyAddonDB[layoutName].y = y
    
    -- Reapply layout
    frame:ClearAllPoints()
    frame:SetPoint(point, x, y)
end

local defaults = {
    point = "CENTER",
    x = 0,
    y = 40,
    scale = 1.0,
    -- UI customization options
    settingsSpacing = 2,
    settingsMaxHeight = 400,
    sliderHeight = 32,
    checkboxHeight = 24,
    dropdownHeight = 32,
    -- More specific height overrides
    multiDropdownHeight = 48,
    multiDropdownSummaryHeight = 48,
    colorHeight = 32,
    checkboxColorHeight = 32,
    dropdownColorHeight = 48,
    dividerHeight = 16,
    collapsibleHeight = 24,
}

LEM:AddFrame(myFrame, OnPositionChanged, defaults)
```

#### Advanced Frame Options

```lua
-- Disable position reset button
LEM:SetFrameResetVisible(myFrame, false)

-- Disable settings reset button
LEM:SetFrameSettingsResetVisible(myFrame, false)

-- Constrain dialog height
LEM:SetFrameSettingsMaxHeight(myFrame, 600)

-- Disable dragging programmatically
LEM:SetFrameDragEnabled(myFrame, false)

-- Or use a predicate function
LEM:SetFrameDragEnabled(myFrame, function(layoutName, layoutIndex)
    return layoutName ~= "Classic" -- Can't drag in Classic layout
end)

-- Enable exclusive collapse groups (only one open at a time)
LEM:SetFrameCollapseExclusive(myFrame, true)

-- Enable eye icon to toggle label/overlay visibility
LEM:SetFrameOverlayToggleEnabled(myFrame, true)
```

---

## 2. System Frames vs Custom Frames

### Blizzard System Frames

**EditModeSystemMixin** is a mixin that Blizzard frames use internally. It provides:

- `GetScaledSelectionSides()` - Returns left, right, bottom, top coordinates
- `GetScaledSelectionCenter()` - Returns center X, Y coordinates  
- `GetScaledCenter()` - Returns frame center (scaled)
- Magnetic snapping helper methods
- Selection box management

**Native Blizzard frames that use Edit Mode:**
```lua
-- Player/Unit frames
PlayerFrame, TargetFrame, FocusFrame, PartyFrame, PetFrame

-- Action bars
MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight
MultiBarLeft, MultiBar5, MultiBar6, MultiBar7, MultiBar8

-- UI elements
MinimapCluster, ObjectiveTrackerFrame, BagsBar, MicroMenuContainer
ChatFrame1, BuffFrame, DebuffFrame, DurabilityFrame

-- Raid/Arena
CompactRaidFrameContainer, BossTargetFrameContainer, ArenaEnemyFramesContainer

-- The War Within (Midnight) specific
PersonalResourceDisplayFrame, EncounterTimeline, DamageMeter
CriticalEncounterWarnings, MirrorTimerContainer, ExternalDefensivesFrame
```

### Custom Addon Frames

LibEQOL automatically injects the necessary magnetism API methods when you register:

```lua
-- These are automatically added to your frame after registration:
frame:GetScaledSelectionSides()
frame:GetScaledSelectionCenter()
frame:GetScaledCenter()
frame:GetSnapOffsets(frameInfo)
frame:SnapToFrame(frameInfo)
frame:IsFrameAnchoredToMe(otherFrame)
frame:IsToTheLeftOfFrame(otherFrame)
frame:IsToTheRightOfFrame(otherFrame)
frame:IsAboveFrame(otherFrame)
frame:IsBelowFrame(otherFrame)
frame:IsVerticallyAlignedWithFrame(otherFrame)
frame:IsHorizontallyAlignedWithFrame(otherFrame)
frame:GetFrameMagneticEligibility(systemFrame)
```

---

## 3. Layout Storage

### Layout System Overview

WoW Edit Mode supports **multiple layouts**:
- **Layout 1**: "Modern" (default)
- **Layout 2**: "Classic" 
- **Layout 3+**: Custom user-created layouts

Each layout stores independent configurations for all UI elements.

### Data Structure

Layouts are stored in a **per-layout database structure**:

```lua
-- Typical database structure
MyAddonDB = {
    layoutName1 = {
        point = "CENTER",
        relativePoint = "CENTER", 
        x = 0,
        y = 100,
        scale = 1.2,
        width = 200,
        height = 30,
        -- Custom settings
        barVisible = "Always",
        foregroundStyle = "Blizzard",
        font = "Fonts\\FRIZQT__.TTF",
        -- etc.
    },
    layoutName2 = {
        -- Different settings for another layout
    }
}
```

### Layout Management

```lua
-- Get active layout
local layoutName = LEM:GetActiveLayoutName()  -- e.g., "Modern", "Classic", "PvP Layout"
local layoutIndex = LEM:GetActiveLayoutIndex() -- e.g., 1, 2, 3, 4...

-- Get all layouts
local layouts = LEM:GetLayouts()
-- Returns: { 
--   { index = 1, name = "Modern", layoutType = 1, isActive = 1 },
--   { index = 2, name = "Classic", layoutType = 2, isActive = 0 },
--   { index = 3, name = "PvP Layout", layoutType = nil, isActive = 0 },
-- }

-- Check if in edit mode
if LEM:IsInEditMode() then
    -- Edit mode specific logic
end

-- Get default position for frame
local defaultPos = LEM:GetFrameDefaultPosition(myFrame)
-- Returns: { point = "CENTER", x = 0, y = 0 }
```

### Position Storage Format

```lua
-- Standard position format expected by callbacks
{
    point = "TOPLEFT",       -- Anchor point on frame
    relativePoint = "CENTER", -- Anchor point on parent
    relativeFrame = "UIParent", -- Parent frame (default UIParent)
    x = 100,                 -- X offset
    y = -50,                 -- Y offset
}
```

---

## 4. Callbacks

### Event Registration

```lua
local LEM = LibStub("LibEQOLEditMode-1.0")

-- Callback events:
-- "enter"          - Edit mode entered
-- "exit"           - Edit mode exited
-- "layout"         - Layout changed/switched
-- "layoutadded"    - New layout created
-- "layoutdeleted"  - Layout deleted
-- "layoutrenamed"  - Layout renamed
-- "spec"           - Player specialization changed
-- "layoutduplicate" - Layout duplicated

LEM:RegisterCallback("enter", function()
    print("Edit mode entered")
    -- Show test elements, update visibility
    myFrame:ApplyVisibilitySettings()
    myFrame:UpdateDisplay()
end)

LEM:RegisterCallback("exit", function()
    print("Edit mode exited")
    -- Hide test elements, apply final state
    myFrame:ApplyVisibilitySettings()
end)

LEM:RegisterCallback("layout", function(layoutName, layoutIndex)
    print("Switched to layout:", layoutName, "index:", layoutIndex)
    -- Load layout-specific settings
    myFrame:ApplyLayout(layoutName)
    myFrame:UpdateDisplay(layoutName)
end)

LEM:RegisterCallback("layoutadded", function(layoutIndex, activateNewLayout, isImported, layoutType, layoutName)
    print("New layout added:", layoutName)
    -- Initialize default settings for new layout
    MyAddonDB[layoutName] = CopyTable(defaults)
end)

LEM:RegisterCallback("layoutdeleted", function(layoutIndex, layoutName)
    print("Layout deleted:", layoutName)
    -- Clean up database
    MyAddonDB[layoutName] = nil
end)

LEM:RegisterCallback("layoutrenamed", function(oldName, newName, layoutIndex)
    print("Layout renamed from", oldName, "to", newName)
    -- Migrate database
    MyAddonDB[newName] = MyAddonDB[oldName]
    MyAddonDB[oldName] = nil
end)

LEM:RegisterCallback("layoutduplicate", function(newLayoutIndex, duplicateIndices, isImported, layoutType, layoutName)
    print("Layout duplicated:", layoutName, "from index:", duplicateIndices[1])
    -- Copy settings from original
    local layouts = LEM:GetLayouts()
    local originalName = layouts[duplicateIndices[1]].name
    MyAddonDB[layoutName] = CopyTable(MyAddonDB[originalName])
end)

LEM:RegisterCallback("spec", function(specID)
    print("Spec changed to:", specID)
    -- Update class-specific elements
end)
```

### EditModeManagerFrame Hooks

If you need to hook Blizzard's native Edit Mode:

```lua
-- Hook edit mode enter
hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
    print("Native Edit Mode entered")
    -- Your enter logic
end)

-- Hook edit mode exit  
hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
    print("Native Edit Mode exited")
    -- Your exit logic
end)

-- Hook layout save
hooksecurefunc(EditModeManagerFrame, "SaveLayoutChanges", function()
    print("Layout saved")
end)
```

### Critical GetScaledSelectionSides Bug Fix

**Common crash**: `GetScaledSelectionSides` can crash when `GetRect()` returns `nil`:

```lua
-- Workaround from SuaviUI
if BossTargetFrameContainer and BossTargetFrameContainer.GetScaledSelectionSides then
    local original = BossTargetFrameContainer.GetScaledSelectionSides
    BossTargetFrameContainer.GetScaledSelectionSides = function(frame)
        local left = frame:GetLeft()
        if left == nil then
            -- Return off-screen fallback (left, right, bottom, top)
            return -10000, -9999, 10000, 10001
        end
        return original(frame)
    end
end
```

---

## 5. Settings System

### Settings Configuration

LibEQOL provides a comprehensive settings UI system. Each setting is a table with specific properties:

```lua
-- Add settings to your frame
LEM:AddFrameSettings(myFrame, {
    -- Collapsible category header
    {
        order = 100,
        name = "Position and Size",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_POSITION",
        defaultCollapsed = false, -- Optional: start collapsed
    },
    
    -- Slider setting
    {
        parentId = "CATEGORY_POSITION", -- Nested under category
        order = 101,
        name = "X Position",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -1920,
        maxValue = 1920,
        valueStep = 1,
        allowInput = true, -- Allow manual text input
        formatter = function(value)
            return string.format("%d px", value)
        end,
        get = function(layoutName, layoutIndex)
            return MyAddonDB[layoutName].x
        end,
        set = function(layoutName, value, layoutIndex)
            MyAddonDB[layoutName].x = value
            myFrame:ApplyLayout(layoutName)
        end,
        tooltip = "Horizontal position offset",
        isEnabled = function(layoutName, layoutIndex)
            return true -- Dynamic enable/disable
        end,
    },
    
    -- Checkbox setting
    {
        parentId = "CATEGORY_POSITION",
        order = 102,
        name = "Lock Position",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            return MyAddonDB[layoutName].locked
        end,
        set = function(layoutName, value)
            MyAddonDB[layoutName].locked = value
            LEM:SetFrameDragEnabled(myFrame, not value)
        end,
    },
    
    -- Dropdown setting
    {
        parentId = "CATEGORY_POSITION",
        order = 103,
        name = "Anchor Point",
        kind = LEM.SettingType.Dropdown,
        default = "CENTER",
        useOldStyle = true, -- Use WoW 10.x style dropdown
        values = {
            { text = "Top Left", value = "TOPLEFT" },
            { text = "Top", value = "TOP" },
            { text = "Top Right", value = "TOPRIGHT" },
            { text = "Left", value = "LEFT" },
            { text = "Center", value = "CENTER" },
            { text = "Right", value = "RIGHT" },
            { text = "Bottom Left", value = "BOTTOMLEFT" },
            { text = "Bottom", value = "BOTTOM" },
            { text = "Bottom Right", value = "BOTTOMRIGHT" },
        },
        get = function(layoutName)
            return MyAddonDB[layoutName].point
        end,
        set = function(layoutName, value)
            MyAddonDB[layoutName].point = value
            myFrame:ApplyLayout(layoutName)
        end,
    },
    
    -- Multi-select dropdown
    {
        parentId = "CATEGORY_POSITION",
        order = 104,
        name = "Hide on Roles",
        kind = LEM.SettingType.MultiDropdown,
        default = {},
        hideSummary = false, -- Show selection summary below
        useOldStyle = true,
        values = {
            { text = "Tank", value = "TANK" },
            { text = "Healer", value = "HEALER" },
            { text = "DPS", value = "DAMAGER" },
        },
        get = function(layoutName)
            return MyAddonDB[layoutName].hideOnRoles or {}
        end,
        set = function(layoutName, value)
            -- value is a table like { TANK = true, HEALER = true }
            MyAddonDB[layoutName].hideOnRoles = value
        end,
        height = 150, -- Dropdown scroll height
    },
    
    -- Color picker
    {
        parentId = "CATEGORY_STYLE",
        order = 201,
        name = "Bar Color",
        kind = LEM.SettingType.Color,
        default = { r = 1, g = 0, b = 0, a = 1 },
        hasOpacity = true,
        get = function(layoutName)
            return MyAddonDB[layoutName].barColor
        end,
        set = function(layoutName, value)
            -- value = { r, g, b, a }
            MyAddonDB[layoutName].barColor = value
            myFrame.StatusBar:SetStatusBarColor(value.r, value.g, value.b, value.a)
        end,
    },
    
    -- Checkbox + Color combo
    {
        parentId = "CATEGORY_STYLE",
        order = 202,
        name = "Use Custom Color",
        kind = LEM.SettingType.CheckboxColor,
        default = false,
        colorDefault = { r = 1, g = 1, b = 1, a = 1 },
        hasOpacity = true,
        get = function(layoutName)
            return MyAddonDB[layoutName].useCustomColor
        end,
        set = function(layoutName, value)
            MyAddonDB[layoutName].useCustomColor = value
        end,
        colorGet = function(layoutName)
            return MyAddonDB[layoutName].customColor
        end,
        colorSet = function(layoutName, value)
            MyAddonDB[layoutName].customColor = value
        end,
    },
    
    -- Divider line
    {
        order = 300,
        kind = LEM.SettingType.Divider,
    },
})
```

### Setting Types Reference

```lua
LEM.SettingType = {
    -- Blizzard standard types
    Checkbox = "Checkbox",
    Dropdown = "Dropdown",
    Slider = "Slider",
    
    -- LibEQOL extended types
    Color = "Color",
    CheckboxColor = "CheckboxColor",
    DropdownColor = "DropdownColor",
    MultiDropdown = "MultiDropdown",
    Divider = "Divider",
    Collapsible = "Collapsible",
}
```

### Advanced Settings: Custom Dropdown Generator

For dynamic or complex dropdowns (like texture/font pickers):

```lua
{
    name = "Bar Texture",
    kind = LEM.SettingType.Dropdown,
    default = "Blizzard",
    useOldStyle = true,
    height = 200, -- Scrollable dropdown
    generator = function(dropdown, rootDescription, settingObject)
        local LSM = LibStub("LibSharedMedia-3.0")
        local textures = LSM:HashTable(LSM.MediaType.STATUSBAR)
        
        -- Create texture preview pool
        dropdown.texturePool = dropdown.texturePool or {}
        
        -- Hook cleanup
        if not dropdown._cleanupHooked then
            hooksecurefunc(dropdown, "OnMenuClosed", function()
                for _, tex in pairs(dropdown.texturePool) do
                    tex:Hide()
                end
            end)
            dropdown._cleanupHooked = true
        end
        
        -- Sort texture names
        local sortedNames = {}
        for name in pairs(textures) do
            table.insert(sortedNames, name)
        end
        table.sort(sortedNames)
        
        -- Add each texture as radio button with preview
        for index, name in ipairs(sortedNames) do
            local texturePath = textures[name]
            
            local button = rootDescription:CreateRadio(name, 
                function(d) return d.get(layoutName) == d.value end,
                function(d) d.set(layoutName, d.value) end,
                { get = settingObject.get, set = settingObject.set, value = texturePath }
            )
            
            -- Add texture preview
            button:AddInitializer(function(buttonFrame)
                local preview = dropdown.texturePool[index]
                if not preview then
                    preview = buttonFrame:CreateTexture(nil, "ARTWORK")
                    preview:SetSize(100, 16)
                    dropdown.texturePool[index] = preview
                end
                
                preview:SetParent(buttonFrame)
                preview:SetPoint("RIGHT", buttonFrame, "RIGHT", -4, 0)
                preview:SetTexture(texturePath)
                preview:Show()
            end)
        end
    end,
    get = function(layoutName)
        return MyAddonDB[layoutName].texture
    end,
    set = function(layoutName, value)
        MyAddonDB[layoutName].texture = value
        myFrame.StatusBar:SetStatusBarTexture(value)
    end,
},
```

### Custom Action Buttons

Add custom buttons below settings:

```lua
-- Single button
LEM:AddFrameSettingsButton(myFrame, {
    text = "Reset to Defaults",
    click = function()
        MyAddonDB[layoutName] = CopyTable(defaults)
        myFrame:ApplyLayout(layoutName)
        LEM.internal:RefreshSettingValues() -- Refresh UI
    end,
})

-- Multiple buttons (newer API)
if LEM.AddFrameSettingsButtons then
    LEM:AddFrameSettingsButtons(myFrame, {
        { text = "Export", click = function() ExportSettings() end },
        { text = "Import", click = function() ImportSettings() end },
    })
end
```

### Dynamic Setting Visibility

```lua
{
    name = "Advanced Mode",
    kind = LEM.SettingType.Checkbox,
    get = function(layoutName) return MyAddonDB[layoutName].advanced end,
    set = function(layoutName, value)
        MyAddonDB[layoutName].advanced = value
        -- Refresh settings to show/hide dependent settings
        LEM.internal:RefreshSettings()
    end,
},
{
    name = "Expert Options",
    kind = LEM.SettingType.Slider,
    -- Only shown when advanced mode is enabled
    isShown = function(layoutName, layoutIndex)
        return MyAddonDB[layoutName].advanced == true
    end,
    -- Or use 'hidden' predicate
    hidden = function(layoutName, layoutIndex)
        return MyAddonDB[layoutName].advanced ~= true
    end,
},
```

---

## 6. Scale vs Size

### Scale System

Edit Mode uses **scale** (percentage) rather than absolute pixel sizes:

```lua
-- Scale is typically 0.25 to 2.0 (25% to 200%)
frame:SetScale(1.2) -- 120% scale

-- Display as percentage in UI
formatter = function(value)
    return string.format("%d%%", math.floor(value * 100))
end
```

### Size vs Scale Difference

- **Scale**: Multiplier applied to frame (0.5 = 50%, 1.0 = 100%, 2.0 = 200%)
- **Size**: Absolute pixel dimensions (width/height)

```lua
-- Setting size (absolute pixels)
frame:SetSize(200, 30) -- 200px wide, 30px tall

-- Setting scale (percentage)
frame:SetScale(1.5) -- 150% of original size

-- Combining both
frame:SetSize(200, 30)  -- Base size
frame:SetScale(1.2)     -- Effective size: 240px x 36px
```

### Scaled Coordinates

When working with Edit Mode magnetism, coordinates must be scaled:

```lua
function frame:GetScaledSelectionSides()
    local scale = self:GetScale() or 1
    local left, bottom, width, height = self:GetRect()
    
    return left * scale,           -- scaled left
           (left + width) * scale, -- scaled right
           bottom * scale,         -- scaled bottom
           (bottom + height) * scale -- scaled top
end
```

---

## 7. Selection Overlay

### Selection Box System

When a frame is selected in Edit Mode, a selection overlay appears. This is managed by LibEQOL:

```lua
-- Selection is automatically created and registered
-- State.selectionRegistry[frame] = selectionFrame
```

### Selection Visual Components

```lua
-- Selection frame has:
selection.parent = yourFrame           -- Reference to actual frame
selection.isSelected = true/false      -- Selection state
selection.overlayHidden = true/false   -- Visibility toggle
selection.Label = fontString           -- Label showing frame name

-- Show/hide selection
selection:ShowSelected(true)  -- Show selection box
selection:ShowSelected(false) -- Hide selection box
```

### GetScaledSelectionSides Implementation

This critical method returns the scaled boundaries of the selection box:

```lua
function frame:GetScaledSelectionSides()
    local scale = self:GetScale() or 1
    
    -- Try to get selection rect first
    if self.Selection and self.Selection.GetRect then
        local left, bottom, width, height = self.Selection:GetRect()
        if left then
            return left * scale,
                   (left + width) * scale,
                   bottom * scale,
                   (bottom + height) * scale
        end
    end
    
    -- Fallback to frame rect
    local left, bottom, width, height = self:GetRect()
    return (left or 0) * scale,
           ((left or 0) + (width or 0)) * scale,
           (bottom or 0) * scale,
           ((bottom or 0) + (height or 0)) * scale
end
```

### Selection Label and Overlay Toggle

```lua
-- Enable eye icon to toggle overlay visibility
LEM:SetFrameOverlayToggleEnabled(myFrame, true)

-- Manually control overlay visibility
local selection = LEM.selectionRegistry[myFrame]
if selection then
    selection.overlayHidden = true
    -- Update visual state
    updateSelectionVisuals(selection, true)
end
```

### Selection Padding

Selection boxes have 2px padding by default:

```lua
local SELECTION_PADDING = 2

function frame:GetLeftOffset()
    if self.Selection and self.Selection.GetPoint then
        return select(4, self.Selection:GetPoint(1)) - SELECTION_PADDING
    end
    return 0
end
```

---

## 8. Magnetic Snapping

### Magnetism Overview

Edit Mode provides **magnetic snapping** to help align frames. LibEQOL injects the necessary API methods automatically.

### Core Magnetism Methods

```lua
-- Check if frames can snap
local horizontalEligible, verticalEligible = frame:GetFrameMagneticEligibility(otherFrame)

-- Positional checks
if frame:IsToTheLeftOfFrame(otherFrame) then
    -- Frame is to the left of otherFrame
end

if frame:IsAboveFrame(otherFrame) then
    -- Frame is above otherFrame
end

-- Alignment checks
if frame:IsVerticallyAlignedWithFrame(otherFrame) then
    -- Frames overlap vertically (can snap horizontally)
end

if frame:IsHorizontallyAlignedWithFrame(otherFrame) then
    -- Frames overlap horizontally (can snap vertically)
end
```

### Snapping Logic

```lua
function frame:GetFrameMagneticEligibility(systemFrame)
    if systemFrame == self then
        return nil -- Can't snap to self
    end
    
    if self:IsFrameAnchoredToMe(systemFrame) then
        return nil -- Avoid circular anchoring
    end
    
    local myLeft, myRight, myBottom, myTop = self:GetScaledSelectionSides()
    local otherLeft, otherRight, otherBottom, otherTop = systemFrame:GetScaledSelectionSides()
    
    -- Can snap horizontally if vertically overlapping
    local horizontalEligible = (myTop >= otherBottom)
        and (myBottom <= otherTop)
        and (myRight < otherLeft or myLeft > otherRight)
    
    -- Can snap vertically if horizontally overlapping
    local verticalEligible = (myRight >= otherLeft)
        and (myLeft <= otherRight)
        and (myBottom > otherTop or myTop < otherBottom)
    
    return horizontalEligible, verticalEligible
end
```

### Snap to Frame

```lua
function frame:SnapToFrame(frameInfo)
    local offsetX, offsetY = self:GetSnapOffsets(frameInfo)
    self:ClearAllPoints()
    self:SetPoint(frameInfo.point, frameInfo.frame, frameInfo.relativePoint, offsetX, offsetY)
end
```

### Magnetism Manager Integration

Blizzard's **EditModeMagnetismManager** handles the actual snapping:

```lua
-- The manager detects nearby frames and shows snap guides
-- LibEQOL ensures your frames have all required methods
-- so the manager treats them like native Blizzard frames
```

### Anchor Cycle Detection

```lua
function frame:IsFrameAnchoredToMe(otherFrame)
    if not (otherFrame and otherFrame.GetNumPoints) then
        return false
    end
    
    local visited = {}
    local function checkAnchor(checkFrame)
        if visited[checkFrame] then return false end
        visited[checkFrame] = true
        
        for i = 1, checkFrame:GetNumPoints() do
            local _, relativeTo = checkFrame:GetPoint(i)
            if relativeTo then
                if relativeTo == self then return true end
                if checkAnchor(relativeTo) then return true end
            end
        end
        return false
    end
    
    return checkAnchor(otherFrame)
end
```

---

## 9. LibEQOL Integration

### Why Use LibEQOL?

LibEQOL (Edit Quality-of-Life) provides a complete wrapper around Blizzard's Edit Mode:

✅ **Clean registration API** - Simple frame registration without Blizzard boilerplate  
✅ **Automatic magnetism injection** - All snap methods added automatically  
✅ **Settings UI framework** - Rich settings panels with minimal code  
✅ **Layout management** - Automatic layout switching, rename, delete handling  
✅ **Callback system** - Clean event system for Edit Mode events  
✅ **Selection overlay management** - Handles selection boxes automatically  
✅ **Bug workarounds** - Fixes `GetScaledSelectionSides` crash and other issues  

### LibEQOL vs Native Edit Mode

| Feature | LibEQOL | Native Edit Mode |
|---------|---------|------------------|
| Frame Registration | `LEM:AddFrame()` | Complex mixin inheritance |
| Settings UI | Declarative tables | Manual UI construction |
| Layout Callbacks | `RegisterCallback("layout")` | Manual hooks |
| Magnetism API | Auto-injected | Manual implementation |
| Multi-layout Support | Built-in | Manual database management |
| Selection Overlay | Auto-managed | Manual creation |

### Complete LibEQOL Setup Example

```lua
local addonName, addon = ...
local LEM = LibStub("LibEQOLEditMode-1.0")

-- Create your frame
local myFrame = CreateFrame("Frame", "MyAddonFrame", UIParent)
myFrame:SetSize(200, 30)
myFrame.editModeName = "My Addon Frame" -- Name shown in Edit Mode

-- Defaults
local defaults = {
    point = "CENTER",
    x = 0,
    y = 0,
    scale = 1.0,
    color = { r = 1, g = 0, b = 0, a = 1 },
}

-- Database
MyAddonDB = MyAddonDB or {}

-- Position callback
local function OnPositionChanged(frame, layoutName, point, x, y)
    MyAddonDB[layoutName] = MyAddonDB[layoutName] or CopyTable(defaults)
    MyAddonDB[layoutName].point = point
    MyAddonDB[layoutName].x = x
    MyAddonDB[layoutName].y = y
    
    frame:ClearAllPoints()
    frame:SetPoint(point, x, y)
end

-- Register frame
LEM:AddFrame(myFrame, OnPositionChanged, defaults)

-- Add settings
LEM:AddFrameSettings(myFrame, {
    {
        order = 1,
        name = "Frame Color",
        kind = LEM.SettingType.Color,
        default = defaults.color,
        hasOpacity = true,
        get = function(layoutName)
            return MyAddonDB[layoutName].color
        end,
        set = function(layoutName, value)
            MyAddonDB[layoutName].color = value
            myFrame:SetBackdropColor(value.r, value.g, value.b, value.a)
        end,
    },
})

-- Register callbacks
LEM:RegisterCallback("layout", function(layoutName)
    MyAddonDB[layoutName] = MyAddonDB[layoutName] or CopyTable(defaults)
    myFrame:ApplyLayout(layoutName)
end)

LEM:RegisterCallback("enter", function()
    myFrame:Show() -- Always show in edit mode
end)

LEM:RegisterCallback("exit", function()
    -- Apply final visibility rules
end)
```

---

### LibEQOL Addon - Detailed Analysis (Bundled Version)

This section documents the SuaviUI-bundled LibEQOL addon in detail, based on the source in libs/LibEQOL/.

#### 1) Package Layout & Load Order

LibEQOL is a multi-module library that loads in this order:

- LibEQOL.toc
    - Registers the library with WoW, declares metadata, and loads LibStub.
- LibEQOL.xml
    - Loads SettingsMode and its controls first, then EditMode, then the umbrella LibEQOL.lua.
- LibEQOL.lua (umbrella entry)
    - Creates a global LibEQOL table and exposes module getters.

Load order matters: SettingsMode controls and templates must be present before EditMode builds its settings panels.

#### 2) Umbrella Module (LibEQOL.lua)

Purpose:

- Binds submodules to a single global LibEQOL table.
- Exposes GetModule("EditMode") and GetModule("SettingsMode").

Key behavior:

- Uses LibStub to fetch LibEQOLEditMode-1.0 and LibEQOLSettingsMode-1.0.
- Ensures a consistent API surface regardless of which module is requested first.

#### 3) Edit Mode Module (LibEQOLEditMode.lua)

Primary responsibility: Provide a lightweight wrapper around Blizzard Edit Mode with custom frame registration, selection overlays, magnetism integration, and settings UI management.

##### Core State

The module maintains a centralized State table that tracks:

- selectionRegistry: Frame → selection overlay frame.
- frameHandlers: Frame → position callback.
- defaultPositions: Frame → defaults table.
- settingSheets: Frame → settings definition table.
- buttonSpecs: Frame → settings button definitions.
- resetToggles / settingsResetToggles: per-frame reset visibility controls.
- dragPredicates: per-frame drag predicate or boolean.
- overlayToggleFlags: per-frame overlay toggle state.
- layout snapshots and per-frame sizing overrides for settings rows.

##### Frame Registration Flow (AddFrame)

When LEM:AddFrame(frame, callback, defaults) is called:

1. Creates a selection overlay using EditModeSystemSelectionTemplate.
2. Wires input handlers:
     - OnMouseDown for selection handling and overlap menu.
     - OnDragStart/OnDragStop to move frames with magnetism.
     - OnKeyDown/OnKeyUp for keyboard nudging (arrows, with Shift for larger steps).
3. Injects magnetism helpers into the frame (ensureMagnetismAPI).
4. Applies defaults (overlay toggle, drag enable, collapse exclusivity, reset visibility, settings layout overrides).
5. Stores callback and defaults in State.
6. Lazily creates the settings dialog and hooks EditModeManagerFrame:
     - OnShow: enter Edit Mode callback chain.
     - OnHide: exit Edit Mode callback chain.
     - Hooks layout add/delete events via C_EditMode.

##### Selection & Overlap Handling

- Tracks the active selection and provides an overlap menu when multiple frames occupy the cursor position.
- Provides a global click handler to dismiss the overlap menu cleanly.
- Keeps selection visuals in sync with edit mode state and overlay toggles.

##### Callback System

RegisterCallback(event, fn) supports:

- enter, exit
- layout, layoutadded, layoutdeleted, layoutrenamed, layoutduplicate
- spec

These callbacks are triggered by Edit Mode lifecycle events and layout updates.

##### Settings Management API

- AddFrameSettings(frame, settings): attaches a settings sheet to the frame.
- AddFrameSettingsButton(frame, data): adds custom buttons to the settings UI.
- SetFrameResetVisible / SetFrameSettingsResetVisible: control reset button visibility.
- SetFrameSettingsMaxHeight: clamp settings panel height per frame.
- SetFrameDragEnabled: set a predicate or boolean for draggable state.
- SetFrameCollapseExclusive: enforce exclusive collapsible sections.
- SetFrameOverlayToggleEnabled: enable or disable overlay toggle logic.

##### Layout Queries

- GetActiveLayoutName / GetActiveLayoutIndex: returns current Edit Mode layout.
- GetLayouts: returns merged list of default and custom layouts.
- GetFrameDefaultPosition: returns defaults stored during AddFrame.

##### Internal UI Refresh

The internal dialog refreshers update visibility, enable state, and layout for settings controls. It supports:

- isEnabled predicates per control.
- collapsed section visibility rules.
- forced layout recalculation and scrollbar updates.

#### 4) Settings Mode Module (LibEQOLSettingsMode.lua)

Primary responsibility: Provide a structured API on top of Blizzard’s Settings UI, including categories, layout, and control creation with robust tagging and search support.

Key capabilities:

- Category registration and caching with fuzzy lookup helpers.
- Control creation helpers (headers, text blocks, buttons, keybinds, and more).
- Search tagging for SettingsPanel search integration.
- New Feature tag injection based on prefix rules.
- Notify hooks that propagate Settings.NotifyUpdate for dynamic refresh.
- Prefix-based variable scoping for large configuration trees.

Selected public helpers include:

- CreateHeader, CreateText, CreateButton, CreateKeybind
- GetCategory, GetCategoryByName, GetCategoryByID, FindCategory
- SetVariablePrefix, AttachNotify, SetNewTagResolverForPrefix

#### 5) Custom Settings Controls

LibEQOL extends Settings UI with additional controls and templates:

- MultiDropdown (LibEQOLSettingsMultiDropdown.lua)
    - Multi-select dropdown with summary text and selection normalization.
    - Supports array or map selections, ordered options, and custom get/set callbacks.
    - Optional scroll mode to avoid menu re-init jitter.

- ScrollDropdown (LibEQOLSettingsScrollDropdown.lua)
    - Virtualized dropdown list with scrollbox support.
    - Avoids full menu rebuild when selection changes in scroll mode.

- SoundDropdown (LibEQOLSettingsSoundDropdown.lua)
    - Dropdown with preview button for sound samples.
    - Supports LibSharedMedia sound lists and custom preview callbacks.
    - Configurable anchors, sizing, and playback channels.

- ColorOverrides (LibEQOLSettingsColorOverrides.lua)
    - Renders a list of color swatches with per-entry color picker.
    - Supports opacity, default resets, and label colorization.
    - Respects Settings.Defaulted and Settings.CategoryDefaulted events.

Templates are defined in LibEQOLSettingsTemplates.xml and include:

- LibEQOLa0dc638_MultiDropdownTemplate
- LibEQOLa0dc638_ScrollDropdownTemplate
- LibEQOLa0dc638_SoundDropdownTemplate
- LibEQOLa0dc638_ColorOverridesPanel (+ no-header variant)

#### 6) How SuaviUI Uses LibEQOL

- Custom frames are registered via LEM:AddFrame and LEM:AddFrameSettings.
- Drag and reset behavior is managed through LEM:SetFrameDragEnabled and LEM:SetFrameResetVisible.
- Edit Mode lifecycle (enter/exit/layout) is handled via LEM:RegisterCallback.
- The settings framework is used to build rich, searchable panels with minimal boilerplate.

---

## 10. Real Examples

### Example 1: SuaviUI Resource Bars

From [SuaviUI/utils/resourcebars/LEMSettingsLoader.lua](LEMSettingsLoader.lua:909):

```lua
-- Registration
LEM:AddFrame(frame, OnPositionChanged, defaults)

-- Position callback with database save
local function OnPositionChanged(frame, layoutName, point, x, y)
    SuaviUI_ResourceBarsDB[config.dbName][layoutName] = 
        SuaviUI_ResourceBarsDB[config.dbName][layoutName] or CopyTable(defaults)
    
    SuaviUI_ResourceBarsDB[config.dbName][layoutName].point = point
    SuaviUI_ResourceBarsDB[config.dbName][layoutName].relativePoint = point
    SuaviUI_ResourceBarsDB[config.dbName][layoutName].x = x
    SuaviUI_ResourceBarsDB[config.dbName][layoutName].y = y
    
    bar:ApplyLayout(layoutName)
    LEM.internal:RefreshSettingValues({ L["X_POSITION"], L["Y_POSITION"] })
end

-- Layout callbacks
LEM:RegisterCallback("layout", function(layoutName)
    SuaviUI_ResourceBarsDB[config.dbName][layoutName] = 
        SuaviUI_ResourceBarsDB[config.dbName][layoutName] or CopyTable(defaults)
    bar:OnLayoutChange(layoutName)
    bar:ApplyVisibilitySettings(layoutName)
    bar:ApplyLayout(layoutName, true)
    bar:UpdateDisplay(layoutName, true)
end)

-- Duplicate callback
LEM:RegisterCallback("layoutduplicate", function(_, duplicateIndices, _, _, layoutName)
    local original = LEM:GetLayouts()[duplicateIndices[1]].name
    SuaviUI_ResourceBarsDB[config.dbName][layoutName] = 
        CopyTable(SuaviUI_ResourceBarsDB[config.dbName][original])
    bar:ApplyLayout(layoutName, true)
end)

-- Rename callback
LEM:RegisterCallback("layoutrenamed", function(oldLayoutName, newLayoutName)
    SuaviUI_ResourceBarsDB[config.dbName][newLayoutName] = 
        CopyTable(SuaviUI_ResourceBarsDB[config.dbName][oldLayoutName])
    SuaviUI_ResourceBarsDB[config.dbName][oldLayoutName] = nil
end)
```

### Example 2: SuaviUI Edit Mode Hooks

From [SuaviUI/utils/suicore_main.lua](suicore_main.lua:4457):

```lua
function SUICore:HookEditMode()
    if self.__editModeHooked then return end
    self.__editModeHooked = true
    
    if EditModeManagerFrame then
        -- Enter edit mode
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
            C_Timer.After(0.1, function()
                self:ForceReskinAllViewers()
            end)
            
            -- Fix BossTargetFrameContainer crash
            if BossTargetFrameContainer and 
               BossTargetFrameContainer.GetScaledSelectionSides then
                local original = BossTargetFrameContainer.GetScaledSelectionSides
                BossTargetFrameContainer.GetScaledSelectionSides = function(frame)
                    local left = frame:GetLeft()
                    if left == nil then
                        -- Return off-screen fallback
                        return -10000, -9999, 10000, 10001
                    end
                    return original(frame)
                end
            end
        end)
        
        -- Exit edit mode
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
            C_Timer.After(0.1, function()
                self:ForceReskinAllViewers()
                
                -- Hide persistent overlays
                C_Timer.After(0.15, function()
                    for _, barName in ipairs({
                        "SuaviUIPrimaryPowerBar",
                        "SuaviUISecondaryPowerBar"
                    }) do
                        local bar = _G[barName]
                        if bar and bar.editOverlay then
                            bar.editOverlay:Hide()
                        end
                    end
                end)
            end)
        end)
    end
end
```

### Example 3: Complex Settings with Texture Preview

From [SuaviUI/utils/resourcebars/LEMSettingsLoader.lua](LEMSettingsLoader.lua:400):

```lua
{
    parentId = L["CATEGORY_BAR_STYLE"],
    order = 402,
    name = L["BAR_TEXTURE"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.foregroundStyle,
    useOldStyle = true,
    height = 200, -- Scrollable dropdown
    
    generator = function(dropdown, rootDescription, settingObject)
        local LSM = LibStub("LibSharedMedia-3.0")
        local layoutName = LEM.GetActiveLayoutName() or "Default"
        
        -- Create texture pool for previews
        dropdown.texturePool = {}
        
        -- Hook cleanup on close
        if not dropdown._SUI_Foreground_Dropdown_OnMenuClosed_hooked then
            hooksecurefunc(dropdown, "OnMenuClosed", function()
                for _, texture in pairs(dropdown.texturePool) do
                    texture:Hide()
                end
            end)
            dropdown._SUI_Foreground_Dropdown_OnMenuClosed_hooked = true
        end
        
        -- Get and sort textures
        local textures = LSM:HashTable(LSM.MediaType.STATUSBAR)
        local sortedTextures = {}
        for textureName in pairs(textures) do
            table.insert(sortedTextures, textureName)
        end
        table.sort(sortedTextures)
        
        -- Add each texture as option with preview
        for index, textureName in ipairs(sortedTextures) do
            local texturePath = textures[textureName]
            
            local button = rootDescription:CreateRadio(
                textureName,
                function(d) return d.get(layoutName) == d.value end,
                function(d) d.set(layoutName, d.value) end,
                { get = settingObject.get, set = settingObject.set, value = texturePath }
            )
            
            -- Add texture preview
            button:AddInitializer(function(buttonFrame)
                local preview = dropdown.texturePool[index]
                if not preview then
                    preview = buttonFrame:CreateTexture(nil, "ARTWORK")
                    preview:SetSize(100, 16)
                    dropdown.texturePool[index] = preview
                end
                
                preview:SetParent(buttonFrame)
                preview:SetPoint("RIGHT", buttonFrame, "RIGHT", -4, 0)
                preview:SetTexture(texturePath)
                preview:Show()
            end)
        end
    end,
    
    get = function(layoutName)
        return (SuaviUI_ResourceBarsDB[config.dbName][layoutName] 
            and SuaviUI_ResourceBarsDB[config.dbName][layoutName].foregroundStyle) 
            or defaults.foregroundStyle
    end,
    set = function(layoutName, value)
        SuaviUI_ResourceBarsDB[config.dbName][layoutName] = 
            SuaviUI_ResourceBarsDB[config.dbName][layoutName] or CopyTable(defaults)
        SuaviUI_ResourceBarsDB[config.dbName][layoutName].foregroundStyle = value
        bar:ApplyLayout(layoutName)
    end,
},
```

### Example 4: SenseiClassResourceBar Health Bar

From [SenseiClassResourceBar/Bars/HealthBar.lua](HealthBar.lua:1):

```lua
-- Bar configuration
addonTable.RegisteredBar.HealthBar = {
    mixin = addonTable.HealthBarMixin,
    dbName = "healthBarDB",
    editModeName = L["HEALTH_BAR_EDIT_MODE_NAME"],
    frameName = "HealthBar",
    frameLevel = 0,
    defaultValues = {
        point = "CENTER",
        x = 0,
        y = 40,
        positionMode = "Self",
        barVisible = "Hidden",
        hideHealthOnRole = {},
        hideBlizzardPlayerContainerUi = false,
        useClassColor = true,
    },
    
    -- Custom settings specific to health bar
    lemSettings = function(bar, defaults)
        local config = bar:GetConfig()
        local dbName = config.dbName
        
        return {
            {
                parentId = L["CATEGORY_BAR_VISIBILITY"],
                order = 103,
                name = L["HIDE_HEALTH_ON_ROLE"],
                kind = LEM.SettingType.MultiDropdown,
                default = defaults.hideHealthOnRole,
                values = addonTable.availableRoleOptions,
                hideSummary = true,
                useOldStyle = true,
                get = function(layoutName)
                    return (SenseiClassResourceBarDB[dbName][layoutName] 
                        and SenseiClassResourceBarDB[dbName][layoutName].hideHealthOnRole) 
                        or defaults.hideHealthOnRole
                end,
                set = function(layoutName, value)
                    SenseiClassResourceBarDB[dbName][layoutName] = 
                        SenseiClassResourceBarDB[dbName][layoutName] or CopyTable(defaults)
                    SenseiClassResourceBarDB[dbName][layoutName].hideHealthOnRole = value
                end,
            },
            {
                parentId = L["CATEGORY_BAR_STYLE"],
                order = 401,
                name = L["USE_CLASS_COLOR"],
                kind = LEM.SettingType.Checkbox,
                default = defaults.useClassColor,
                get = function(layoutName)
                    local data = SenseiClassResourceBarDB[dbName][layoutName]
                    if data and data.useClassColor ~= nil then
                        return data.useClassColor
                    else
                        return defaults.useClassColor
                    end
                end,
                set = function(layoutName, value)
                    SenseiClassResourceBarDB[dbName][layoutName] = 
                        SenseiClassResourceBarDB[dbName][layoutName] or CopyTable(defaults)
                    SenseiClassResourceBarDB[dbName][layoutName].useClassColor = value
                    bar:ApplyLayout(layoutName)
                end,
            },
        }
    end,
}
```

---

## API Reference Summary

### LibEQOL Core Functions

```lua
-- Frame Management
LEM:AddFrame(frame, callback, defaults)
LEM:AddFrameSettings(frame, settingsTable)
LEM:AddFrameSettingsButton(frame, buttonData)
LEM:AddFrameSettingsButtons(frame, buttonsTable) -- Batch add

-- Frame Options
LEM:SetFrameResetVisible(frame, showReset)
LEM:SetFrameSettingsResetVisible(frame, showReset)
LEM:SetFrameSettingsMaxHeight(frame, height)
LEM:SetFrameDragEnabled(frame, enabledOrPredicate)
LEM:SetFrameCollapseExclusive(frame, enabled)
LEM:SetFrameOverlayToggleEnabled(frame, enabled)

-- Callbacks
LEM:RegisterCallback(event, callback)
-- Events: "enter", "exit", "layout", "layoutadded", "layoutdeleted",
--         "layoutrenamed", "spec", "layoutduplicate"

-- Layout Info
LEM:GetActiveLayoutName() -> string
LEM:GetActiveLayoutIndex() -> number
LEM:IsInEditMode() -> boolean
LEM:GetLayouts() -> table
LEM:GetFrameDefaultPosition(frame) -> table

-- Internal (Advanced)
LEM.internal:RefreshSettings()
LEM.internal:RefreshSettingValues(settingsTable)
LEM.internal:TriggerCallback(frame, ...)
```

### Injected Frame Methods (After Registration)

```lua
-- Magnetism
frame:GetScaledSelectionSides() -> left, right, bottom, top
frame:GetScaledSelectionCenter() -> x, y
frame:GetScaledCenter() -> x, y
frame:GetSnapOffsets(frameInfo) -> offsetX, offsetY
frame:SnapToFrame(frameInfo)
frame:IsFrameAnchoredToMe(otherFrame) -> boolean
frame:GetFrameMagneticEligibility(systemFrame) -> horizontalEligible, verticalEligible

-- Positional Checks
frame:IsToTheLeftOfFrame(otherFrame) -> boolean
frame:IsToTheRightOfFrame(otherFrame) -> boolean
frame:IsAboveFrame(otherFrame) -> boolean
frame:IsBelowFrame(otherFrame) -> boolean
frame:IsVerticallyAlignedWithFrame(otherFrame) -> boolean
frame:IsHorizontallyAlignedWithFrame(otherFrame) -> boolean

-- Offset Helpers
frame:GetLeftOffset() -> number
frame:GetRightOffset() -> number
frame:GetTopOffset() -> number
frame:GetBottomOffset() -> number
frame:GetSelectionOffset(point, forYOffset) -> number
frame:GetCombinedSelectionOffset(frameInfo, forYOffset) -> number
frame:GetCombinedCenterOffset(otherFrame) -> offsetX, offsetY
```

### Blizzard Edit Mode Hooks

```lua
-- Manager Frame
EditModeManagerFrame:EnterEditMode()
EditModeManagerFrame:ExitEditMode()
EditModeManagerFrame:SaveLayoutChanges()
EditModeManagerFrame:SelectSystem()
EditModeManagerFrame:ClearSelectedSystem()

-- Layout API
C_EditMode.GetLayouts() -> layoutInfo
C_EditMode.ConvertLayoutInfoToString(layout) -> string
C_EditMode.OnLayoutDeleted(layoutIndex)
C_EditMode.OnLayoutAdded(layoutIndex, activate, imported)

-- Events
EventRegistry:RegisterFrameEventAndCallback("EDIT_MODE_LAYOUTS_UPDATED", callback)
EventRegistry:RegisterCallback("EditMode.SavedLayouts", callback)
```

---

## Common Pitfalls

### 1. Nil Rect Crashes
Always check for nil before using `GetRect()` or `GetLeft()`:
```lua
local left = frame:GetLeft()
if not left then
    return -10000, -9999, 10000, 10001 -- Offscreen fallback
end
```

### 2. Layout Not Initialized
Always initialize layout on first access:
```lua
MyAddonDB[layoutName] = MyAddonDB[layoutName] or CopyTable(defaults)
```

### 3. Forgetting to Refresh Settings
After programmatic changes, refresh the UI:
```lua
LEM.internal:RefreshSettingValues()
```

### 4. Scale Applied Twice
Don't scale already-scaled coordinates:
```lua
-- Wrong:
local x = (self:GetLeft() * scale) * scale

-- Right:
local x = self:GetLeft() * scale
```

### 5. Circular Anchoring
Check for anchoring loops before snapping:
```lua
if self:IsFrameAnchoredToMe(targetFrame) then
    return -- Don't create circular reference
end
```

---

## Conclusion

This documentation covers the complete Blizzard Edit Mode system integration, with emphasis on the LibEQOL wrapper which greatly simplifies custom frame registration. Key takeaways:

- **Use LibEQOL** for addon frames - it handles all the complex boilerplate
- **Always initialize layouts** - Never assume layout data exists
- **Implement GetScaledSelectionSides carefully** - This is a common crash point
- **Use callbacks** - Let LibEQOL manage layout switching, renaming, deletion
- **Leverage the settings framework** - Declarative tables are easier than manual UI
- **Test magnetism** - Ensure your frames snap properly to Blizzard frames

For further reference, see the complete implementations in:
- `SuaviUI/utils/resourcebars/` - Full resource bar system with Edit Mode
- `SenseiClassResourceBar/Bars/` - Individual bar implementations
- `LibEQOL/LibEQOLEditMode.lua` - Core library source

*This documentation is maintained as part of the SuaviUI project. For updates or corrections, submit issues to the SuaviUI repository.*
