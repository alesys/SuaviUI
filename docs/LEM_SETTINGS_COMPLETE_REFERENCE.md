# LibEQOL Settings Implementation - Complete Reference

## Overview
This document provides the EXACT implementation details of how SenseiClassResourceBar uses LibEQOL (LibEQOLEditMode-1.0) for Edit Mode settings integration.

## Key Files
- **Settings Builder**: `SenseiClassResourceBar/Helpers/LEMSettingsLoader.lua` (992 lines)
- **Constants**: `SenseiClassResourceBar/Constants.lua`
- **Per-Bar Custom Settings**: Each bar file has a `lemSettings` function in its config

## API Call Structure

### 1. LEM:AddFrame()
**Called in**: `LEMSettingsLoaderMixin:Init()`  
**Location**: Line 790 of LEMSettingsLoader.lua

```lua
LEM:AddFrame(frame, OnPositionChanged, defaults)
```

**Parameters**:
- `frame`: The UI frame to register
- `OnPositionChanged`: Callback function when position changes
- `defaults`: Table of default values

**OnPositionChanged Callback**:
```lua
local function OnPositionChanged(frame, layoutName, point, x, y)
    SenseiClassResourceBarDB[config.dbName][layoutName] = SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
    SenseiClassResourceBarDB[config.dbName][layoutName].point = point
    SenseiClassResourceBarDB[config.dbName][layoutName].relativePoint = point
    SenseiClassResourceBarDB[config.dbName][layoutName].x = x
    SenseiClassResourceBarDB[config.dbName][layoutName].y = y
    bar:ApplyLayout(layoutName)
    LEM.internal:RefreshSettingValues({L["X_POSITION"], L["Y_POSITION"]})
end
```

### 2. LEM:AddFrameSettings()
**Called in**: `LEMSettingsLoaderMixin:LoadSettings()`  
**Location**: Line 868 of LEMSettingsLoader.lua

```lua
LEM:AddFrameSettings(frame, BuildLemSettings(self.bar, self.defaults))
```

**Parameters**:
- `frame`: The UI frame
- `settings`: Array of setting objects (see complete structure below)

### 3. LEM:AddFrameSettingsButton() / LEM:AddFrameSettingsButtons()
**Called in**: `LEMSettingsLoaderMixin:LoadSettings()`  
**Location**: Lines 911-942 of LEMSettingsLoader.lua

```lua
-- Newer API (batch add)
if LEM.AddFrameSettingsButtons then
    LEM:AddFrameSettingsButtons(frame, buttonSettings)
else
    -- Older API (one at a time)
    for _, buttonSetting in ipairs(buttonSettings) do
        LEM:AddFrameSettingsButton(frame, buttonSetting)
    end
end
```

**Button Structure**:
```lua
{
    text = "Button Label",
    click = function() 
        -- Handler function
    end
}
```

## Complete Settings Array Structure

### Setting Object Properties

Every setting object can have these properties:

#### Required Properties
- **`order`** (number): Sort order for the setting
- **`name`** (string): Display name (usually from localization)
- **`kind`** (LEM.SettingType.*): Type of setting control

#### Category/Collapsible Properties
- **`id`** (string): Unique identifier for category (used as parentId by children)
- **`defaultCollapsed`** (boolean): Whether category starts collapsed

#### Child Settings Properties
- **`parentId`** (string): ID of parent category

#### Common Setting Properties
- **`default`**: Default value (type depends on setting kind)
- **`get`** (function): `function(layoutName) return value end`
- **`set`** (function): `function(layoutName, value) ... end`
- **`tooltip`** (string): Optional tooltip text
- **`isEnabled`** (function): `function(layoutName) return boolean end` - whether setting is enabled

#### Checkbox Settings
- **`kind`** = `LEM.SettingType.Checkbox`
- **`default`** (boolean)
- **`get`** returns boolean
- **`set`** receives boolean

#### CheckboxColor Settings
- **`kind`** = `LEM.SettingType.CheckboxColor`
- **`default`** (boolean): For checkbox state
- **`colorDefault`** (table): `{r = 1, g = 1, b = 1, a = 1}`
- **`get`** (function): Returns boolean
- **`colorGet`** (function): Returns color table
- **`set`** (function): Receives boolean
- **`colorSet`** (function): Receives color table

#### Slider Settings
- **`kind`** = `LEM.SettingType.Slider`
- **`default`** (number)
- **`minValue`** (number)
- **`maxValue`** (number)
- **`valueStep`** (number): Step increment
- **`allowInput`** (boolean): Whether to allow direct text input
- **`formatter`** (function): Optional - `function(value) return string end`

#### Dropdown Settings
- **`kind`** = `LEM.SettingType.Dropdown`
- **`default`** (string): Default selected value
- **`useOldStyle`** (boolean): Use old-style dropdown (set to true)
- **`values`** (table): Array of `{text = "Display Text", value = "optional_value"}`
- **`height`** (number): Optional - dropdown height for long lists
- **`generator`** (function): Optional - custom dropdown generator function

**Generator Function Signature**:
```lua
generator = function(dropdown, rootDescription, settingObject)
    -- Custom dropdown menu construction
    -- See examples for Font, Background, Bar Texture
end
```

#### DropdownColor Settings
- **`kind`** = `LEM.SettingType.DropdownColor`
- **`default`** (string): Default selected value
- **`colorDefault`** (table): `{r = 1, g = 1, b = 1, a = 1}`
- **`useOldStyle`** (boolean)
- **`values`** (table): Array of `{text = "Display Text"}`
- **`get`** (function): Returns dropdown value
- **`colorGet`** (function): Returns color table
- **`set`** (function): Receives dropdown value
- **`colorSet`** (function): Receives color table
- **`height`** (number): Optional
- **`generator`** (function): Optional

#### MultiDropdown Settings
- **`kind`** = `LEM.SettingType.MultiDropdown`
- **`default`** (table): Array of selected values
- **`values`** (table): Array of `{text = "Display", value = "VALUE"}`
- **`hideSummary`** (boolean): Hide summary of selections
- **`useOldStyle`** (boolean)

#### Divider
- **`kind`** = `LEM.SettingType.Divider`
- **`order`** (number)
- **`parentId`** (string)

#### Collapsible (Category Header)
- **`kind`** = `LEM.SettingType.Collapsible`
- **`order`** (number)
- **`name`** (string): Category name
- **`id`** (string): Unique ID for this category
- **`defaultCollapsed`** (boolean): Optional

## Complete Settings List from SenseiClassResourceBar

### Category: Bar Visibility (100-199)

```lua
{
    order = 100,
    name = L["CATEGORY_BAR_VISIBILITY"],
    kind = LEM.SettingType.Collapsible,
    id = L["CATEGORY_BAR_VISIBILITY"],
}
```

#### Bar Visible (101)
```lua
{
    parentId = L["CATEGORY_BAR_VISIBILITY"],
    order = 101,
    name = L["BAR_VISIBLE"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.barVisible,
    useOldStyle = true,
    values = addonTable.availableBarVisibilityOptions,
    -- Values: "Always Visible", "In Combat", "Has Target Selected", 
    --         "Has Target Selected OR In Combat", "Hidden"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].barVisible) or 
               defaults.barVisible
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].barVisible = value
    end,
}
```

#### Bar Strata (102)
```lua
{
    parentId = L["CATEGORY_BAR_VISIBILITY"],
    order = 102,
    name = L["BAR_STRATA"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.barStrata,
    useOldStyle = true,
    values = addonTable.availableBarStrataOptions,
    -- Values: "TOOLTIP", "DIALOG", "HIGH", "MEDIUM", "LOW", "BACKGROUND"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].barStrata) or 
               defaults.barStrata
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].barStrata = value
        bar:ApplyLayout(layoutName)
    end,
    tooltip = L["BAR_STRATA_TOOLTIP"],
}
```

#### Hide While Mounted or Vehicle (104)
```lua
{
    parentId = L["CATEGORY_BAR_VISIBILITY"],
    order = 104,
    name = L["HIDE_WHILE_MOUNTED_OR_VEHICULE"],
    kind = LEM.SettingType.Checkbox,
    default = defaults.hideWhileMountedOrVehicule,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        if data and data.hideWhileMountedOrVehicule ~= nil then
            return data.hideWhileMountedOrVehicule
        else
            return defaults.hideWhileMountedOrVehicule
        end
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].hideWhileMountedOrVehicule = value
    end,
    tooltip = L["HIDE_WHILE_MOUNTED_OR_VEHICULE_TOOLTIP"],
}
```

### Category: Position and Size (200-299)

```lua
{
    order = 200,
    name = L["CATEGORY_POSITION_AND_SIZE"],
    kind = LEM.SettingType.Collapsible,
    id = L["CATEGORY_POSITION_AND_SIZE"],
}
```

#### X Position (202)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 202,
    name = L["X_POSITION"],
    kind = LEM.SettingType.Slider,
    default = defaults.x,
    minValue = uiWidth * -1,  -- where uiWidth = GetPhysicalScreenSize() / 2
    maxValue = uiWidth,
    valueStep = 1,
    allowInput = true,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and addonTable.rounded(data.x) or defaults.x
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].x = addonTable.rounded(value)
        bar:ApplyLayout(layoutName)
    end,
}
```

#### Y Position (203)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 203,
    name = L["Y_POSITION"],
    kind = LEM.SettingType.Slider,
    default = defaults.y,
    minValue = uiHeight * -1,  -- where uiHeight = GetPhysicalScreenSize() / 2
    maxValue = uiHeight,
    valueStep = 1,
    allowInput = true,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and addonTable.rounded(data.y) or defaults.y
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].y = addonTable.rounded(value)
        bar:ApplyLayout(layoutName)
    end,
}
```

#### Relative Frame (204)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 204,
    name = L["RELATIVE_FRAME"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.relativeFrame,
    useOldStyle = true,
    values = addonTable.availableRelativeFrames(config),
    -- Values: "UIParent", "Primary Resource Bar", "Secondary Resource Bar", 
    --         "Health Bar", "PlayerFrame", "TargetFrame", etc.
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].relativeFrame) or 
               defaults.relativeFrame
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].relativeFrame = value
        -- Reset position when relative frame changes
        SenseiClassResourceBarDB[config.dbName][layoutName].x = defaults.x
        SenseiClassResourceBarDB[config.dbName][layoutName].y = defaults.y
        SenseiClassResourceBarDB[config.dbName][layoutName].point = defaults.point
        SenseiClassResourceBarDB[config.dbName][layoutName].relativePoint = defaults.relativePoint
        bar:ApplyLayout(layoutName)
        LEM.internal:RefreshSettingValues({L["X_POSITION"], L["Y_POSITION"], 
                                           L["ANCHOR_POINT"], L["RELATIVE_POINT"]})
    end,
    tooltip = L["RELATIVE_FRAME_TOOLTIP"],
}
```

#### Anchor Point (205)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 205,
    name = L["ANCHOR_POINT"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.point,
    useOldStyle = true,
    values = addonTable.availableAnchorPoints,
    -- Values: "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", 
    --         "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].point) or 
               defaults.point
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].point = value
        bar:ApplyLayout(layoutName)
    end,
}
```

#### Relative Point (206)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 206,
    name = L["RELATIVE_POINT"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.relativePoint,
    useOldStyle = true,
    values = addonTable.availableRelativePoints,
    -- Values: Same as anchor points
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].relativePoint) or 
               defaults.relativePoint
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].relativePoint = value
        bar:ApplyLayout(layoutName)
    end,
}
```

#### Divider (210)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 210,
    kind = LEM.SettingType.Divider,
}
```

#### Bar Size / Scale (211)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 211,
    name = L["BAR_SIZE"],
    kind = LEM.SettingType.Slider,
    default = defaults.scale,
    minValue = 0.25,
    maxValue = 2,
    valueStep = 0.01,
    formatter = function(value)
        return string.format("%d%%", addonTable.rounded(value, 2) * 100)
    end,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and addonTable.rounded(data.scale, 2) or defaults.scale
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].scale = addonTable.rounded(value, 2)
        bar:ApplyLayout(layoutName)
    end,
}
```

#### Width Mode (212)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 212,
    name = L["WIDTH_MODE"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.widthMode,
    useOldStyle = true,
    values = addonTable.availableWidthModes,
    -- Values: "Manual", "Sync With Essential Cooldowns", 
    --         "Sync With Utility Cooldowns", "Sync With Tracked Buffs"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].widthMode) or 
               defaults.widthMode
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].widthMode = value
        bar:ApplyLayout(layoutName)
    end,
}
```

#### Width (213)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 213,
    name = L["WIDTH"],
    kind = LEM.SettingType.Slider,
    default = defaults.width,
    minValue = 1,
    maxValue = 500,
    valueStep = 1,
    allowInput = true,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and addonTable.rounded(data.width) or defaults.width
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].width = addonTable.rounded(value)
        bar:ApplyLayout(layoutName)
    end,
    isEnabled = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data.widthMode == "Manual"
    end,
}
```

#### Minimum Width (214)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 214,
    name = L["MINIMUM_WIDTH"],
    kind = LEM.SettingType.Slider,
    default = defaults.minWidth,
    minValue = 0,
    maxValue = 500,
    valueStep = 1,
    allowInput = true,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and addonTable.rounded(data.minWidth) or defaults.minWidth
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].minWidth = addonTable.rounded(value)
        bar:ApplyLayout(layoutName)
    end,
    tooltip = L["MINIMUM_WIDTH_TOOLTIP"],
    isEnabled = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data ~= nil and data ~= "Manual"
    end,
}
```

#### Height (215)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 215,
    name = L["HEIGHT"],
    kind = LEM.SettingType.Slider,
    default = defaults.height,
    minValue = 1,
    maxValue = 500,
    valueStep = 1,
    allowInput = true,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and addonTable.rounded(data.height) or defaults.height
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].height = addonTable.rounded(value)
        bar:ApplyLayout(layoutName)
    end,
}
```

### Category: Bar Settings (300-399)

```lua
{
    order = 300,
    name = L["CATEGORY_BAR_SETTINGS"],
    kind = LEM.SettingType.Collapsible,
    id = L["CATEGORY_BAR_SETTINGS"],
    defaultCollapsed = true,
}
```

#### Fill Direction (301)
```lua
{
    parentId = L["CATEGORY_BAR_SETTINGS"],
    order = 301,
    name = L["FILL_DIRECTION"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.fillDirection,
    useOldStyle = true,
    values = addonTable.availableFillDirections,
    -- Values: "Left to Right", "Right to Left", "Top to Bottom", "Bottom to Top"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].fillDirection) or 
               defaults.fillDirection
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].fillDirection = value
        bar:ApplyLayout(layoutName)
    end,
}
```

#### Faster Updates (302)
```lua
{
    parentId = L["CATEGORY_BAR_SETTINGS"],
    order = 302,
    name = L["FASTER_UPDATES"],
    kind = LEM.SettingType.Checkbox,
    default = defaults.fasterUpdates,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        if data and data.fasterUpdates ~= nil then
            return data.fasterUpdates
        else
            return defaults.fasterUpdates
        end
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].fasterUpdates = value
        if value then
            bar:EnableFasterUpdates()
        else
            bar:DisableFasterUpdates()
        end
    end,
}
```

#### Smooth Progress (303)
```lua
{
    parentId = L["CATEGORY_BAR_SETTINGS"],
    order = 303,
    name = L["SMOOTH_PROGRESS"],
    kind = LEM.SettingType.Checkbox,
    default = defaults.smoothProgress,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        if data and data.smoothProgress ~= nil then
            return data.smoothProgress
        else
            return defaults.smoothProgress
        end
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].smoothProgress = value
    end,
}
```

### Category: Bar Style (400-499)

```lua
{
    order = 400,
    name = L["CATEGORY_BAR_STYLE"],
    kind = LEM.SettingType.Collapsible,
    id = L["CATEGORY_BAR_STYLE"],
    defaultCollapsed = true,
}
```

#### Bar Texture (402)
```lua
{
    parentId = L["CATEGORY_BAR_STYLE"],
    order = 402,
    name = L["BAR_TEXTURE"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.foregroundStyle,
    useOldStyle = true,
    height = 200,
    generator = function(dropdown, rootDescription, settingObject)
        -- Custom generator that shows texture previews
        -- See full implementation in LEMSettingsLoader.lua lines 505-551
    end,
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].foregroundStyle) or 
               defaults.foregroundStyle
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].foregroundStyle = value
        bar:ApplyLayout(layoutName)
    end,
    isEnabled = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return not data.useResourceAtlas
    end,
}
```

#### Background (403)
```lua
{
    parentId = L["CATEGORY_BAR_STYLE"],
    order = 403,
    name = L["BACKGROUND"],
    kind = LEM.SettingType.DropdownColor,
    default = defaults.backgroundStyle,
    colorDefault = defaults.backgroundColor,
    useOldStyle = true,
    height = 200,
    generator = function(dropdown, rootDescription, settingObject)
        -- Custom generator with texture previews
        -- See full implementation in LEMSettingsLoader.lua lines 407-467
    end,
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].backgroundStyle) or 
               defaults.backgroundStyle
    end,
    colorGet = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and data.backgroundColor or defaults.backgroundColor
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].backgroundStyle = value
        bar:ApplyLayout(layoutName)
    end,
    colorSet = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].backgroundColor = value
        bar:ApplyBackgroundSettings(layoutName)
    end,
}
```

#### Use Bar Color for Background Color (404)
```lua
{
    parentId = L["CATEGORY_BAR_STYLE"],
    order = 404,
    name = L["USE_BAR_COLOR_FOR_BACKGROUND_COLOR"],
    kind = LEM.SettingType.Checkbox,
    default = defaults.useStatusBarColorForBackgroundColor,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        if data and data.useStatusBarColorForBackgroundColor ~= nil then
            return data.useStatusBarColorForBackgroundColor
        else
            return defaults.useStatusBarColorForBackgroundColor
        end
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].useStatusBarColorForBackgroundColor = value
        bar:ApplyBackgroundSettings(layoutName)
    end,
}
```

#### Border (405)
```lua
{
    parentId = L["CATEGORY_BAR_STYLE"],
    order = 405,
    name = L["BORDER"],
    kind = LEM.SettingType.DropdownColor,
    default = defaults.maskAndBorderStyle,
    colorDefault = defaults.borderColor,
    useOldStyle = true,
    values = addonTable.availableMaskAndBorderStyles,
    -- Values: "1 Pixel", "Thin", "Slight", "Bold", 
    --         "Blizzard Classic", "Blizzard Classic Thin", "None"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].maskAndBorderStyle) or 
               defaults.maskAndBorderStyle
    end,
    colorGet = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and data.borderColor or defaults.borderColor
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].maskAndBorderStyle = value
        bar:ApplyMaskAndBorderSettings(layoutName)
    end,
    colorSet = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].borderColor = value
        bar:ApplyMaskAndBorderSettings(layoutName)
    end,
}
```

### Category: Text Settings (500-599)

```lua
{
    order = 500,
    name = L["CATEGORY_TEXT_SETTINGS"],
    kind = LEM.SettingType.Collapsible,
    id = L["CATEGORY_TEXT_SETTINGS"],
    defaultCollapsed = true,
}
```

#### Show Resource Number (501)
```lua
{
    parentId = L["CATEGORY_TEXT_SETTINGS"],
    order = 501,
    name = L["SHOW_RESOURCE_NUMBER"],
    kind = LEM.SettingType.CheckboxColor,
    default = defaults.showText,
    colorDefault = defaults.textColor,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        if data and data.showText ~= nil then
            return data.showText
        else
            return defaults.showText
        end
    end,
    colorGet = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and data.textColor or defaults.textColor
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].showText = value
        bar:ApplyTextVisibilitySettings(layoutName)
    end,
    colorSet = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].textColor = value
        bar:ApplyFontSettings(layoutName)
    end,
}
```

#### Resource Number Format (502)
```lua
{
    parentId = L["CATEGORY_TEXT_SETTINGS"],
    order = 502,
    name = L["RESOURCE_NUMBER_FORMAT"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.textFormat,
    useOldStyle = true,
    values = addonTable.availableTextFormats,
    -- Values: "Current", "Current / Maximum", "Percent", "Percent%", 
    --         "Current - Percent", "Current - Percent%"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].textFormat) or 
               defaults.textFormat
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].textFormat = value
        bar:UpdateDisplay(layoutName)
    end,
    tooltip = L["RESOURCE_NUMBER_FORMAT_TOOLTIP"],
    isEnabled = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data.showText
    end,
}
```

#### Resource Number Precision (503)
```lua
{
    parentId = L["CATEGORY_TEXT_SETTINGS"],
    order = 503,
    name = L["RESOURCE_NUMBER_PRECISION"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.textPrecision,
    useOldStyle = true,
    values = addonTable.availableTextPrecisions,
    -- Values: "12", "12.3", "12.34", "12.345"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].textPrecision) or 
               defaults.textPrecision
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].textPrecision = value
        bar:UpdateDisplay(layoutName)
    end,
    isEnabled = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data.showText and addonTable.textPrecisionAllowedForType[data.textFormat] ~= nil
    end,
}
```

#### Resource Number Alignment (504)
```lua
{
    parentId = L["CATEGORY_TEXT_SETTINGS"],
    order = 504,
    name = L["RESOURCE_NUMBER_ALIGNMENT"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.textAlign,
    useOldStyle = true,
    values = addonTable.availableTextAlignmentStyles,
    -- Values: "TOP", "LEFT", "CENTER", "RIGHT", "BOTTOM"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].textAlign) or 
               defaults.textAlign
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].textAlign = value
        bar:ApplyFontSettings(layoutName)
    end,
    isEnabled = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data.showText
    end,
}
```

### Category: Font (600-699)

```lua
{
    order = 600,
    name = L["CATEGORY_FONT"],
    kind = LEM.SettingType.Collapsible,
    id = L["CATEGORY_FONT"],
    defaultCollapsed = true,
}
```

#### Font (601)
```lua
{
    parentId = L["CATEGORY_FONT"],
    order = 601,
    name = L["FONT"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.font,
    useOldStyle = true,
    height = 200,
    generator = function(dropdown, rootDescription, settingObject)
        -- Custom generator with font previews
        -- See full implementation in LEMSettingsLoader.lua lines 674-717
    end,
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].font) or 
               defaults.font
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].font = value
        bar:ApplyFontSettings(layoutName)
    end,
}
```

#### Font Size (602)
```lua
{
    parentId = L["CATEGORY_FONT"],
    order = 602,
    name = L["FONT_SIZE"],
    kind = LEM.SettingType.Slider,
    default = defaults.fontSize,
    minValue = 5,
    maxValue = 50,
    valueStep = 1,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and addonTable.rounded(data.fontSize) or defaults.fontSize
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].fontSize = addonTable.rounded(value)
        bar:ApplyFontSettings(layoutName)
    end,
}
```

#### Font Outline (603)
```lua
{
    parentId = L["CATEGORY_FONT"],
    order = 603,
    name = L["FONT_OUTLINE"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.fontOutline,
    useOldStyle = true,
    values = addonTable.availableOutlineStyles,
    -- Values: "NONE", "OUTLINE", "THICKOUTLINE"
    get = function(layoutName)
        return (SenseiClassResourceBarDB[config.dbName][layoutName] and 
                SenseiClassResourceBarDB[config.dbName][layoutName].fontOutline) or 
               defaults.fontOutline
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].fontOutline = value
        bar:ApplyFontSettings(layoutName)
    end,
}
```

## Per-Bar Custom Settings

Each bar can add custom settings via the `lemSettings` function in its config. Examples:

### HealthBar Custom Settings

#### Hide Health on Role (103)
```lua
{
    parentId = L["CATEGORY_BAR_VISIBILITY"],
    order = 103,
    name = L["HIDE_HEALTH_ON_ROLE"],
    kind = LEM.SettingType.MultiDropdown,
    default = defaults.hideHealthOnRole,
    values = addonTable.availableRoleOptions,
    -- Values: {text = "Tank", value = "TANK"}, 
    --         {text = "Healer", value = "HEALER"}, 
    --         {text = "DPS", value = "DAMAGER"}
    hideSummary = true,
    useOldStyle = true,
    get = function(layoutName)
        return (SenseiClassResourceBarDB[dbName][layoutName] and 
                SenseiClassResourceBarDB[dbName][layoutName].hideHealthOnRole) or 
               defaults.hideHealthOnRole
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[dbName][layoutName] = 
            SenseiClassResourceBarDB[dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[dbName][layoutName].hideHealthOnRole = value
    end,
}
```

#### Position Mode (201)
```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 201,
    name = L["POSITION"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.positionMode,
    useOldStyle = true,
    values = addonTable.availablePositionModeOptions(config),
    -- Values for HealthBar: "Self", 
    --   "Use Primary Resource Bar Position If Hidden",
    --   "Use Secondary Resource Bar Position If Hidden"
    get = function(layoutName) ... end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[dbName][layoutName] = 
            SenseiClassResourceBarDB[dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[dbName][layoutName].positionMode = value
        bar:ApplyLayout(layoutName)
    end,
}
```

#### Use Class Color (401)
```lua
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
}
```

## LEM Callbacks

Registered in `LEMSettingsLoaderMixin:Init()`:

### enter
```lua
LEM:RegisterCallback("enter", function()
    bar:ApplyVisibilitySettings()
    bar:ApplyLayout()
    bar:UpdateDisplay()
end)
```

### exit
```lua
LEM:RegisterCallback("exit", function()
    bar:ApplyVisibilitySettings()
    bar:ApplyLayout()
    bar:UpdateDisplay()
end)
```

### layout
```lua
LEM:RegisterCallback("layout", function(layoutName)
    SenseiClassResourceBarDB[config.dbName][layoutName] = 
        SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
    bar:OnLayoutChange(layoutName)
    bar:InitCooldownManagerWidthHook(layoutName)
    bar:ApplyVisibilitySettings(layoutName)
    bar:ApplyLayout(layoutName, true)
    bar:UpdateDisplay(layoutName, true)
end)
```

### layoutduplicate
```lua
LEM:RegisterCallback("layoutduplicate", function(_, duplicateIndices, _, _, layoutName)
    local original = LEM:GetLayouts()[duplicateIndices[1]].name
    SenseiClassResourceBarDB[config.dbName][layoutName] = 
        SenseiClassResourceBarDB[config.dbName][original] and 
        CopyTable(SenseiClassResourceBarDB[config.dbName][original]) or 
        CopyTable(defaults)
    bar:InitCooldownManagerWidthHook(layoutName)
    bar:ApplyVisibilitySettings(layoutName)
    bar:ApplyLayout(layoutName, true)
    bar:UpdateDisplay(layoutName, true)
end)
```

### layoutrenamed
```lua
LEM:RegisterCallback("layoutrenamed", function(oldLayoutName, newLayoutName)
    SenseiClassResourceBarDB[config.dbName][newLayoutName] = 
        SenseiClassResourceBarDB[config.dbName][oldLayoutName] and 
        CopyTable(SenseiClassResourceBarDB[config.dbName][oldLayoutName]) or 
        CopyTable(defaults)
    SenseiClassResourceBarDB[config.dbName][oldLayoutName] = nil
    bar:InitCooldownManagerWidthHook(newLayoutName)
    bar:ApplyVisibilitySettings()
    bar:ApplyLayout()
    bar:UpdateDisplay()
end)
```

### layoutdeleted
```lua
LEM:RegisterCallback("layoutdeleted", function(_, layoutName)
    SenseiClassResourceBarDB[config.dbName] = SenseiClassResourceBarDB[config.dbName] or {}
    SenseiClassResourceBarDB[config.dbName][layoutName] = nil
    bar:ApplyVisibilitySettings()
    bar:ApplyLayout()
    bar:UpdateDisplay()
end)
```

## LEM Internal Functions

### Refresh Setting Values
```lua
LEM.internal:RefreshSettingValues({L["X_POSITION"], L["Y_POSITION"]})
-- Pass array of setting names to refresh
```

## Default Values Structure

```lua
addonTable.commonDefaults = {
    -- LEM built-in settings
    enableOverlayToggle = true,
    settingsMaxHeight = select(2, GetPhysicalScreenSize()) * 0.6,
    point = "CENTER",
    x = 0,
    y = 0,
    
    -- SCRB settings
    relativeFrame = "UIParent",
    relativePoint = "CENTER",
    barVisible = "Always Visible",
    hideWhileMountedOrVehicule = false,
    barStrata = "MEDIUM",
    scale = 1,
    width = 200,
    minWidth = 0,
    widthMode = "Manual",
    height = 15,
    fillDirection = "Left to Right",
    smoothProgress = true,
    fasterUpdates = true,
    showText = true,
    textColor = {r = 1, g = 1, b = 1, a = 1},
    textFormat = "Current",
    textPrecision = "12",
    font = LSM:Fetch(LSM.MediaType.FONT, "Friz Quadrata TT"),
    fontSize = 12,
    fontOutline = "OUTLINE",
    textAlign = "CENTER",
    maskAndBorderStyle = "Thin",
    borderColor = {r = 0, g = 0, b = 0, a = 1},
    backgroundStyle = "SCRB Semi-transparent",
    backgroundColor = {r = 1, g = 1, b = 1, a = 1},
    useStatusBarColorForBackgroundColor = false,
    foregroundStyle = "SCRB FG Fade Left",
}
```

## Summary

**Total Base Settings**: ~30+ settings across 6 categories
- Bar Visibility: 3 base settings
- Position and Size: 10 settings
- Bar Settings: 3 settings
- Bar Style: 4 settings
- Text Settings: 4 settings
- Font: 3 settings

**Plus per-bar custom settings** (2-5 per bar depending on type)

**Key Features**:
- All settings are layout-aware (per Edit Mode layout)
- Settings support conditional enabling via `isEnabled` function
- Settings can have custom generators for complex UI
- Settings support callbacks for actions on change
- Color settings use RGBA tables: `{r, g, b, a}`
- Dropdown values use `{text = "Display", value = "optional_value"}` format
