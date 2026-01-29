# SenseiClassResourceBar - Complete Technical Architecture

## Overview
Sensei is a class resource bar addon that integrates with LibEQOL (Edit Mode Library) to provide fully customizable resource bars for player health and power resources. It manages multiple bar instances (HealthBar, PrimaryResourceBar, SecondaryResourceBar, TertiaryResourceBar) through a unified mixin-based architecture.

---

## 1. Bar Registration System

### How Bars Are Registered

Bars are **NOT** registered with LibEQOL directly. Instead, they use a custom registration pattern through the **`addonTable.RegisteredBar`** table.

Each bar file (e.g., `HealthBar.lua`, `PrimaryResourceBar.lua`) registers itself by adding a configuration object:

```lua
addonTable.RegisteredBar = addonTable.RegisteredBar or {}
addonTable.RegisteredBar.HealthBar = {
    mixin = addonTable.HealthBarMixin,
    dbName = "healthBarDB",
    editModeName = L["HEALTH_BAR_EDIT_MODE_NAME"],
    frameName = "HealthBar",
    frameLevel = 0,
    defaultValues = { /* configuration defaults */ },
    lemSettings = function(bar, defaults) /* LEM-specific settings */ end,
    loadPredicate = nil,  -- Optional: function to determine if bar should load
}
```

### Registration Properties

| Property | Type | Purpose |
|----------|------|---------|
| `mixin` | table | The mixin class (e.g., `addonTable.HealthBarMixin`) that provides bar behavior |
| `dbName` | string | Database key where bar settings are saved (e.g., `"healthBarDB"`) |
| `editModeName` | string | Display name in Edit Mode UI (localized) |
| `frameName` | string | Frame name and instance key (e.g., `"HealthBar"`) |
| `frameLevel` | number | Stacking order (0 = HealthBar, 2 = SecondaryResourceBar, 3 = PrimaryResourceBar) |
| `defaultValues` | table | Default settings for bar (position, size, colors, etc.) |
| `lemSettings` | function | Callback returning LEM setting descriptors for the bar |
| `loadPredicate` | function | Optional condition to determine if bar should be created |

### Initialization Flow (ADDON_LOADED)

**File:** `SenseiClassResourceBar.lua` - Lines 48-72

```lua
SCRB:RegisterEvent("ADDON_LOADED")
SCRB:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- 1. Initialize global database if needed
        if not SenseiClassResourceBarDB then
            SenseiClassResourceBarDB = {}
        end

        -- 2. Create instances table
        addonTable.barInstances = addonTable.barInstances or {}

        -- 3. Iterate through all registered bars
        for _, config in pairs(addonTable.RegisteredBar or {}) do
            -- 4. Check load predicate
            if config.loadPredicate == nil or 
               (type(config.loadPredicate) == "function" and config.loadPredicate(config) == true) then
                
                -- 5. Initialize bar and store by frameName
                local frame = InitializeBar(config, config.frameLevel or 1)
                addonTable.barInstances[config.frameName] = frame
            end
        end

        -- 6. Register settings UI
        addonTable.SettingsRegistrar()
    end
end)
```

### Bar Instance Creation

**File:** `SenseiClassResourceBar.lua` - Lines 8-31

```lua
local function CreateBarInstance(config, parent, frameLevel)
    -- Initialize database for this bar if needed
    if not SenseiClassResourceBarDB[config.dbName] then
        SenseiClassResourceBarDB[config.dbName] = {}
    end

    -- Create frame using mixin
    local bar = CreateFromMixins(config.mixin or addonTable.BarMixin)
    bar:Init(config, parent, frameLevel)

    -- Copy defaults for current layout
    local curLayout = addonTable.LEM.GetActiveLayoutName() or "Default"
    if not SenseiClassResourceBarDB[config.dbName][curLayout] then
        SenseiClassResourceBarDB[config.dbName][curLayout] = CopyTable(bar.defaults)
    end

    -- Load bar and apply initial settings
    bar:OnLoad()
    bar:GetFrame():SetScript("OnEvent", function(_, ...)
        bar:OnEvent(...)
    end)

    bar:ApplyVisibilitySettings()
    bar:ApplyLayout(true)
    bar:UpdateDisplay(true)

    return bar
end

local function InitializeBar(config, frameLevel)
    local bar = CreateBarInstance(config, UIParent, math.max(0, frameLevel or 0))

    -- Merge defaults
    local defaults = CopyTable(addonTable.commonDefaults)
    for k, v in pairs(config.defaultValues or {}) do
        defaults[k] = v
    end

    -- Initialize settings loader (handles LEM integration)
    local LEMSettingsLoader = CreateFromMixins(addonTable.LEMSettingsLoaderMixin)
    LEMSettingsLoader:Init(bar, defaults)
    LEMSettingsLoader:LoadSettings()

    return bar
end
```

---

## 2. LibEQOL (LEM) Integration

### What LEM Actually Does

LibEQOL provides:
- Edit Mode frame dragging/resizing interface
- Layout switching/duplication/deletion
- Settings UI integration
- Callbacks for layout changes

### LEM Registration Calls

**File:** `Helpers/LEMSettingsLoader.lua` - Lines 828-885

```lua
function LEMSettingsLoaderMixin:Init(bar, defaults)
    self.bar = bar
    self.defaults = CopyTable(defaults)

    local frame = bar:GetFrame()
    local config = bar:GetConfig()

    -- CRITICAL: Position change callback
    local function OnPositionChanged(frame, layoutName, point, x, y)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].point = point
        SenseiClassResourceBarDB[config.dbName][layoutName].relativePoint = point
        SenseiClassResourceBarDB[config.dbName][layoutName].x = x
        SenseiClassResourceBarDB[config.dbName][layoutName].y = y
        bar:ApplyLayout(layoutName)
        LEM.internal:RefreshSettingValues({L["X_POSITION"], L["Y_POSITION"]})
    end

    -- Register frame with LEM (enables drag/drop in edit mode)
    LEM:AddFrame(frame, OnPositionChanged, defaults)
end
```

### LEM Callback Registration

**File:** `Helpers/LEMSettingsLoader.lua` - Lines 843-882

```lua
-- ENTER Edit Mode
LEM:RegisterCallback("enter", function()
    bar:ApplyVisibilitySettings()
    bar:ApplyLayout()
    bar:UpdateDisplay()
end)

-- EXIT Edit Mode
LEM:RegisterCallback("exit", function()
    bar:ApplyVisibilitySettings()
    bar:ApplyLayout()
    bar:UpdateDisplay()
end)

-- LAYOUT SWITCHED (e.g., from "Default" to "Raid")
LEM:RegisterCallback("layout", function(layoutName)
    SenseiClassResourceBarDB[config.dbName][layoutName] = 
        SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
    bar:OnLayoutChange(layoutName)
    bar:InitCooldownManagerWidthHook(layoutName)
    bar:ApplyVisibilitySettings(layoutName)
    bar:ApplyLayout(layoutName, true)
    bar:UpdateDisplay(layoutName, true)
end)

-- LAYOUT DUPLICATED
LEM:RegisterCallback("layoutduplicate", function(_, duplicateIndices, _, _, layoutName)
    local original = LEM:GetLayouts()[duplicateIndices[1]].name
    SenseiClassResourceBarDB[config.dbName][layoutName] = 
        SenseiClassResourceBarDB[config.dbName][original] and 
        CopyTable(SenseiClassResourceBarDB[config.dbName][original]) or 
        CopyTable(defaults)
    bar:ApplyLayout(layoutName, true)
    bar:UpdateDisplay(layoutName, true)
end)

-- LAYOUT RENAMED
LEM:RegisterCallback("layoutrenamed", function(oldLayoutName, newLayoutName)
    SenseiClassResourceBarDB[config.dbName][newLayoutName] = 
        SenseiClassResourceBarDB[config.dbName][oldLayoutName] and 
        CopyTable(SenseiClassResourceBarDB[config.dbName][oldLayoutName]) or 
        CopyTable(defaults)
    SenseiClassResourceBarDB[config.dbName][oldLayoutName] = nil
    bar:ApplyLayout()
    bar:UpdateDisplay()
end)

-- LAYOUT DELETED
LEM:RegisterCallback("layoutdeleted", function(_, layoutName)
    SenseiClassResourceBarDB[config.dbName][layoutName] = nil
    bar:ApplyLayout()
    bar:UpdateDisplay()
end)
```

### LEM Settings Registration

**File:** `Helpers/LEMSettingsLoader.lua` - Lines 888-892

```lua
function LEMSettingsLoaderMixin:LoadSettings()
    local frame = self.bar:GetFrame()

    -- Register ALL settings with LEM (generates Edit Mode UI)
    LEM:AddFrameSettings(frame, BuildLemSettings(self.bar, self.defaults))

    -- Add custom buttons (Export/Import/Color Settings)
    if LEM.AddFrameSettingsButtons then
        LEM:AddFrameSettingsButtons(frame, buttonSettings)
    else
        for _, buttonSetting in ipairs(buttonSettings) do
            LEM:AddFrameSettingsButton(frame, buttonSetting)
        end
    end
end
```

---

## 3. Edit Mode Position Handling

### The Drag & Drop Flow

1. **User drags bar in Edit Mode**
   - LEM detects drag event on frame
   - LEM calls `OnPositionChanged` callback

2. **OnPositionChanged Callback** (see above)
   - Saves new position to `SenseiClassResourceBarDB[dbName][layoutName]`
   - Calls `bar:ApplyLayout(layoutName)` to apply changes
   - Refreshes LEM UI with new position values

3. **ApplyLayout Method** (applies all position-related settings)

**File:** `Bars/Abstract/Bar.lua` - Lines 520-608

```lua
function BarMixin:ApplyLayout(layoutName, force)
    if not self:IsShown() and not force then return end

    local data = self:GetData(layoutName)
    if not data then return end

    -- Get size (width × height × scale)
    local width, height = self:GetSize(layoutName, data)
    self.Frame:SetSize(
        max(LEM:IsInEditMode() and 2 or 1, width), 
        max(LEM:IsInEditMode() and 2 or 1, height)
    )

    -- Get anchoring point and relative frame
    local point, relativeTo, relativePoint, x, y = self:GetPoint(layoutName)
    
    -- Clear and re-anchor frame
    self.Frame:ClearAllPoints()
    self.Frame:SetPoint(point, relativeTo, relativePoint, x, y)

    -- Disable dragging if not anchored to UIParent (LEM limitation)
    LEM:SetFrameDragEnabled(self.Frame, relativeTo == UIParent)

    -- Apply all visual settings
    self:SetFrameStrata(data.barStrata or defaults.barStrata)
    self:ApplyFontSettings(layoutName, data)
    self:ApplyFillDirectionSettings(layoutName, data)
    self:ApplyMaskAndBorderSettings(layoutName, data)
    self:ApplyForegroundSettings(layoutName, data)
    self:ApplyBackgroundSettings(layoutName, data)
    self:UpdateTicksLayout(layoutName, data)

    -- Enable/disable faster updates
    if data.fasterUpdates then
        self:EnableFasterUpdates()
    else
        self:DisableFasterUpdates()
    end
end
```

### GetPoint Method (Position Resolution)

**File:** `Bars/Abstract/Bar.lua` - Lines 465-490

```lua
function BarMixin:GetPoint(layoutName)
    local defaults = self.defaults or {}
    local data = self:GetData(layoutName)
    
    if not data then
        return defaults.point or "CENTER",
            addonTable.resolveRelativeFrames(defaults.relativeFrame or "UIParent"),
            defaults.relativePoint or "CENTER",
            defaults.x or 0,
            defaults.y or 0
    end

    local x = data.x or defaults.x
    local y = data.y or defaults.y
    local point = data.point or defaults.point
    local relativePoint = data.relativePoint or defaults.relativePoint
    local relativeFrame = data.relativeFrame or defaults.relativeFrame
    local resolvedRelativeFrame = addonTable.resolveRelativeFrames(relativeFrame) or UIParent
    
    -- Prevent circular anchoring
    if self.Frame == resolvedRelativeFrame or 
       self.Frame == select(2, resolvedRelativeFrame:GetPoint(1)) then
        resolvedRelativeFrame = UIParent
        data.relativeFrame = "UIParent"
        LEM.internal:RefreshSettingValues({L["RELATIVE_FRAME"]})
        addonTable.prettyPrint(L["RELATIVE_FRAME_CYCLIC_WARNING"])
    end

    local uiWidth, uiHeight = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
    return point, resolvedRelativeFrame, relativePoint, 
           addonTable.clamp(x, uiWidth * -1, uiWidth), 
           addonTable.clamp(y, uiHeight * -1, uiHeight)
end
```

### GetSize Method (Dimension Resolution)

**File:** `Bars/Abstract/Bar.lua` - Lines 492-519

```lua
function BarMixin:GetSize(layoutName, data)
    local defaults = self.defaults or {}
    data = data or self:GetData(layoutName)
    
    if not data then 
        return defaults.width or 200, defaults.height or 15 
    end

    -- Width can be manual or synced with other UI elements
    local width = nil
    if data.widthMode ~= nil and data.widthMode ~= "Manual" then
        width = self:GetCooldownManagerWidth(layoutName) or data.width or defaults.width
        if data.minWidth and data.minWidth > 0 then
            width = max(width, data.minWidth)
        end
    else
        width = data.width or defaults.width
    end

    local height = data.height or defaults.height
    local scale = addonTable.rounded(data.scale or defaults.scale or 1, 2)

    return width * scale, height * scale
end
```

---

## 4. Settings Persistence (Database Structure)

### Database Layout

```lua
SenseiClassResourceBarDB = {
    -- Layout-specific data for each bar
    ["healthBarDB"] = {
        ["Default"] = {
            point = "CENTER",
            relativePoint = "CENTER",
            relativeFrame = "UIParent",
            x = 0,
            y = 40,
            scale = 1,
            width = 200,
            height = 15,
            barVisible = "Hidden",
            barStrata = "MEDIUM",
            positionMode = "Self",
            hideHealthOnRole = {},
            useClassColor = true,
            -- ... all other settings
        },
        ["Raid"] = { /* same structure */ },
        ["Dungeon"] = { /* same structure */ },
    },
    ["PrimaryResourceBarDB"] = {
        ["Default"] = { /* ... */ },
        ["Raid"] = { /* ... */ },
    },
    ["SecondaryResourceBarDB"] = {
        ["Default"] = { /* ... */ },
        ["Raid"] = { /* ... */ },
    },
    ["_Settings"] = {
        -- Global addon settings (not layout-specific)
        globalSetting1 = value,
        globalSetting2 = value,
    }
}
```

### How Settings Are Saved When Dragging

1. User drags bar in Edit Mode
2. LEM calls `OnPositionChanged(frame, layoutName, point, x, y)`
3. `OnPositionChanged` updates database:
   ```lua
   SenseiClassResourceBarDB[config.dbName][layoutName].point = point
   SenseiClassResourceBarDB[config.dbName][layoutName].relativePoint = point
   SenseiClassResourceBarDB[config.dbName][layoutName].x = x
   SenseiClassResourceBarDB[config.dbName][layoutName].y = y
   ```
4. Database is automatically saved by WoW (uses SavedVariables)

### Layout-Specific Data Retrieval

**File:** `Bars/Abstract/Bar.lua` - Lines 232-238

```lua
function BarMixin:GetData(layoutName)
    layoutName = layoutName or LEM.GetActiveLayoutName() or "Default"
    return SenseiClassResourceBarDB[self.config.dbName][layoutName]
end
```

---

## 5. Bar Mixin Architecture

### Base BarMixin Methods

All bars inherit from `addonTable.BarMixin`. The mixin provides:

#### Frame Management
```lua
function BarMixin:Init(config, parent, frameLevel)
    -- Creates frame structure with StatusBar, Mask, Border, TextFrame
    -- Initializes defaults and display properties
end

function BarMixin:Show() / Hide() / IsShown()
    -- Frame visibility controls
end

function BarMixin:GetFrame()
    return self.Frame
end
```

#### Data Access
```lua
function BarMixin:GetData(layoutName)
    -- Returns settings for current/specified layout
end

function BarMixin:GetConfig()
    return self.config
end
```

#### Resource-Specific Methods (overridden by subclasses)
```lua
function BarMixin:GetResource()
    -- MUST OVERRIDE: Returns resource type (e.g., Enum.PowerType.Health, "STAGGER")
    return nil
end

function BarMixin:GetResourceValue(resource)
    -- MUST OVERRIDE: Returns (max, current) for the resource
    return nil, nil
end

function BarMixin:GetBarColor(resource)
    -- OVERRIDE: Returns color table {r, g, b, a}
    return { r = 1, g = 1, b = 1, a = 1 }
end

function BarMixin:GetTagValues(resource, max, current, precision)
    -- OVERRIDE: Returns table of tag functions for text display
    return {}
end
```

#### Event Handling
```lua
function BarMixin:OnLoad()
    -- Register events needed for this bar type
    self.Frame:RegisterEvent("EVENT_NAME")
end

function BarMixin:OnEvent(event, ...)
    -- Handle events and update display
end

function BarMixin:OnShow() / OnHide()
    -- Called when bar visibility changes
end

function BarMixin:OnLayoutChange(layoutName)
    -- Called when layout is switched
end
```

#### Display Updates
```lua
function BarMixin:UpdateDisplay(layoutName, force)
    -- Updates StatusBar value, text, and fragmented power bars
    -- Only updates if shown or force=true
end

function BarMixin:ApplyVisibilitySettings(layoutName, inCombat)
    -- Determines if bar should be shown based on role, spec, combat status, etc.
end

function BarMixin:ApplyLayout(layoutName, force)
    -- Applies position, size, colors, fonts, borders, fills
end
```

#### Font/Style Application
```lua
function BarMixin:ApplyFontSettings(layoutName, data)
function BarMixin:ApplyFillDirectionSettings(layoutName, data)
function BarMixin:ApplyMaskAndBorderSettings(layoutName, data)
function BarMixin:ApplyForegroundSettings(layoutName, data)
function BarMixin:ApplyBackgroundSettings(layoutName, data)
```

#### Update Frequency Control
```lua
function BarMixin:EnableFasterUpdates()
    -- Sets OnUpdate to 0.1 second intervals
end

function BarMixin:DisableFasterUpdates()
    -- Sets OnUpdate to 0.25 second intervals
end
```

### Concrete Bar Mixins

#### HealthBarMixin
- **Database:** `healthBarDB`
- **Resource:** `"HEALTH"`
- **Events:** `UNIT_HEALTH`, `PLAYER_REGEN_ENABLED/DISABLED`, `PLAYER_TARGET_CHANGED`, `PLAYER_MOUNT_DISPLAY_CHANGED`, `PET_BATTLE_*`
- **Special:** Can position relative to PrimaryResourceBar or SecondaryResourceBar if hidden (positionMode)

#### PrimaryResourceBarMixin
- **Database:** `PrimaryResourceBarDB`
- **Resources:** Class-specific (Rage, Focus, Mana, Lunar Power, RunicPower, Fury, etc.)
- **Inherits from:** `PowerBarMixin` (which extends BarMixin)
- **Events:** `UNIT_POWER_UPDATE`, `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_REGEN_*`
- **Special:** Uses spec-based and form-based resource selection for Druids

#### SecondaryResourceBarMixin
- **Database:** `SecondaryResourceBarDB`
- **Resources:** Class-specific secondary resources (ComboPoints, Runes, HolyPower, Chi, ArcaneCharges, SoulShards, etc.)
- **Inherits from:** `PowerBarMixin`
- **Special Modules:** 
  - `addonTable.TipOfTheSpear` for Hunters (Survival)
  - `addonTable.Whirlwind` for Warriors (Improved Whirlwind)

#### TertiaryResourceBarMixin
- **Database:** `TertiaryResourceBarDB`
- **Resources:** Spec-specific tertiary resources
- **Inherits from:** Similar structure as others

---

## 6. Event Wiring Pattern

### Standard Event Registration Pattern

**File:** `Bars/HealthBar.lua` - Lines 47-61

```lua
function HealthBarMixin:OnLoad()
    -- Register unit events (tied to specific units)
    self.Frame:RegisterUnitEvent("UNIT_HEALTH", "player")
    self.Frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    
    -- Register global events
    self.Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.Frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.Frame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    self.Frame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    self.Frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    self.Frame:RegisterEvent("PET_BATTLE_OPENING_START")
    self.Frame:RegisterEvent("PET_BATTLE_CLOSE")
end

function HealthBarMixin:OnEvent(event, ...)
    local unit = ...

    if event == "PLAYER_ENTERING_WORLD" or 
       (event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player") then
        self:ApplyVisibilitySettings()
        self:ApplyLayout()
        self:UpdateDisplay()
    elseif event == "PLAYER_REGEN_ENABLED" or 
           event == "PLAYER_REGEN_DISABLED" or
           event == "PLAYER_TARGET_CHANGED" or
           event == "UNIT_ENTERED_VEHICLE" or 
           event == "UNIT_EXITED_VEHICLE" or
           event == "PLAYER_MOUNT_DISPLAY_CHANGED" or
           event == "PET_BATTLE_OPENING_START" or 
           event == "PET_BATTLE_CLOSE" then
        self:ApplyVisibilitySettings(nil, event == "PLAYER_REGEN_DISABLED")
        self:UpdateDisplay()
    end
end
```

### Event Handler Setup (Auto-wired in Init)

**File:** `SenseiClassResourceBar.lua` - Lines 21-25

```lua
bar:OnLoad()
bar:GetFrame():SetScript("OnEvent", function(_, ...)
    bar:OnEvent(...)
end)
```

This setup means:
- `OnLoad()` registers the events
- WoW fires events to the frame
- Frame's `OnEvent` script calls `bar:OnEvent(event, ...)`

### Event Handlers for Fragmented Powers

**File:** `Helpers/TipOfTheSpear.lua` (Hunter Survival)

```lua
function TipOfTheSpear:OnLoad(powerBar)
    local playerClass = select(2, UnitClass("player"))
    if playerClass == "HUNTER" then
        powerBar.Frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        powerBar.Frame:RegisterEvent("PLAYER_DEAD")
        powerBar.Frame:RegisterEvent("PLAYER_ALIVE")
    end
end

function TipOfTheSpear:OnEvent(_, event, ...)
    -- Handle death/resurrection reset
    if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" then
        tipStacks = 0
        tipExpiresAt = nil
        return
    end

    local unit, castGUID, spellID = ...
    if unit ~= "player" then return end

    -- Track Tip of the Spear stack generation and consumption
    -- Update stack counter based on ability use
end
```

---

## 7. Update Display Flow

### Complete Display Update Chain

**File:** `Bars/Abstract/Bar.lua` - Lines 263-368

```lua
function BarMixin:UpdateDisplay(layoutName, force)
    if not self:IsShown() and not force then return end

    local data = self:GetData(layoutName)
    if not data then return end
    
    -- Get the resource (e.g., Enum.PowerType.Health)
    local resource = self:GetResource()
    if not resource then
        if LEM:IsInEditMode() then
            -- Show placeholder in edit mode
            self.StatusBar:SetMinMaxValues(0, 5)
            self.TextValue:SetFormattedText("4")
            self.StatusBar:SetValue(4)
        end
        return
    end

    -- Get current and max values
    local max, current = self:GetResourceValue(resource)
    if not max then
        if not LEM:IsInEditMode() then
            self:Hide()
        end
        return
    end

    -- Set bar min/max and value with optional smooth animation
    self.StatusBar:SetMinMaxValues(0, max, 
        data.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)
    self.StatusBar:SetValue(current, 
        data.smoothProgress and Enum.StatusBarInterpolation.ExponentialEaseOut or nil)

    -- Update text display if enabled
    if data.showText == true then
        local precision = data.textPrecision and 
            math.max(0, string.len(data.textPrecision) - 3) or 0
        local tagValues = self:GetTagValues(resource, max, current, precision)

        -- Build text format from settings
        local textFormat = ""
        if (data.showManaAsPercent and resource == Enum.PowerType.Mana) or 
           data.textFormat == "Percent" or data.textFormat == "Percent%" then
            textFormat = "[percent]" .. (data.textFormat == "Percent%" and "%" or "")
        elseif data.textFormat == nil or data.textFormat == "Current" then
            textFormat = "[current]"
        elseif data.textFormat == "Current / Maximum" then
            textFormat = "[current] / [max]"
        elseif data.textFormat == "Current - Percent" or 
               data.textFormat == "Current - Percent%" then
            textFormat = "[current] - [percent]" .. 
                (data.textFormat == "Current - Percent%" and "%" or "")
        end

        -- Cache compiled format for performance
        if self._cachedTextFormat ~= textFormat then
            self._cachedTextFormat = textFormat
            self._cachedTextPattern = {}
            for tag in textFormat:gmatch('%[..-%]+') do
                self._cachedTextPattern[#self._cachedTextPattern + 1] = tag
            end
            self._cachedFormat, self._cachedNum = textFormat:gsub('%%', '%%%%')
                :gsub('%[..-%]+', '%%s')
        end

        -- Collect values for each tag
        local valuesToDisplay = {}
        for i = 1, #self._cachedTextPattern do
            local tag = self._cachedTextPattern[i]
            if tagValues and tagValues[tag] then
                valuesToDisplay[i] = tagValues[tag]()
            else
                valuesToDisplay[i] = ''
            end
        end

        -- Set formatted text
        self.TextValue:SetFormattedText(self._cachedFormat, 
            unpack(valuesToDisplay, 1, self._cachedNum))
    end

    -- Update fragmented power display if needed (Runes, Stagger, etc.)
    if addonTable.fragmentedPowerTypes[resource] then
        self:UpdateFragmentedPowerDisplay(layoutName, data, max)
    end
end
```

### Continuous Updates (OnUpdate Scripts)

```lua
function BarMixin:EnableFasterUpdates()
    self.fasterUpdates = true
    if not self._OnUpdateFast then
        self._OnUpdateFast = function(frame, delta)
            frame.elapsed = (frame.elapsed or 0) + delta
            if frame.elapsed >= 0.1 then  -- Every 100ms
                frame.elapsed = 0
                self:UpdateDisplay()
            end
        end
    end
    self.Frame:SetScript("OnUpdate", self._OnUpdateFast)
end

function BarMixin:DisableFasterUpdates()
    self.fasterUpdates = false
    if not self._OnUpdateSlow then
        self._OnUpdateSlow = function(frame, delta)
            frame.elapsed = (frame.elapsed or 0) + delta
            if frame.elapsed >= 0.25 then  -- Every 250ms
                frame.elapsed = 0
                self:UpdateDisplay()
            end
        end
    end
    self.Frame:SetScript("OnUpdate", self._OnUpdateSlow)
end
```

---

## 8. LEM Settings Definition

### Settings Structure

Each bar returns a table of setting descriptors through `lemSettings` function. Each descriptor has:

```lua
{
    order = 101,                          -- Display order
    name = L["SETTING_NAME"],            -- Localized name
    kind = LEM.SettingType.Slider,       -- Type: Slider, Dropdown, Checkbox, etc.
    default = defaults.someValue,        -- Default value
    parentId = L["CATEGORY_NAME"],       -- Belongs to this category
    get = function(layoutName)           -- Read value from DB
        return SenseiClassResourceBarDB[dbName][layoutName].someValue or default
    end,
    set = function(layoutName, value)    -- Write value to DB
        SenseiClassResourceBarDB[dbName][layoutName].someValue = value
        bar:ApplyLayout(layoutName)      -- Apply changes
    end,
    values = {...},                      -- For Dropdowns: list of options
    minValue = 0, maxValue = 500,        -- For Sliders: range
    valueStep = 1,                       -- For Sliders: increment
}
```

### Setting Categories

Settings are organized hierarchically:

```lua
-- Category header (Collapsible)
{
    order = 100,
    name = L["CATEGORY_BAR_VISIBILITY"],
    kind = LEM.SettingType.Collapsible,
    id = L["CATEGORY_BAR_VISIBILITY"],
}

-- Settings under category
{
    parentId = L["CATEGORY_BAR_VISIBILITY"],
    order = 101,
    name = L["BAR_VISIBLE"],
    kind = LEM.SettingType.Dropdown,
    -- ...
}
```

### Auto-Updating on LEM Apply

When Edit Mode calls `LEM.internal:RefreshSettingValues()`, all `get()` functions are re-called to update the UI.

---

## 9. Visibility Logic

### ApplyVisibilitySettings Method

**File:** `Bars/Abstract/Bar.lua` - Lines 369-459

Controls whether bar is shown based on:

1. **Edit Mode Override:** Always show in edit mode (unless `allowEditPredicate` returns false)
2. **Resource Check:** Hide if resource doesn't exist for this class/spec
3. **Role-Based Hiding:** Hide if role is in `hideManaOnRole` or `hideHealthOnRole`
4. **Mount/Vehicle:** Hide if mounted and `hideWhileMountedOrVehicule` is true
5. **Pet Battle:** Always hide in pet battles
6. **Visibility Mode Setting:**
   - `"Always Visible"` → Always show
   - `"Hidden"` → Always hide
   - `"In Combat"` → Show only in combat
   - `"Has Target Selected"` → Show only if target exists
   - `"Has Target Selected OR In Combat"` → Show if target OR combat

---

## Summary: Complete Initialization to Display

```
1. ADDON_LOADED event fires
   ↓
2. Loop through addonTable.RegisteredBar configurations
   ↓
3. For each bar config:
   a. CreateBarInstance()
      - Create frame with BarMixin
      - Call bar:Init() → creates visual elements
      - Initialize database for bar
      - Call bar:OnLoad() → register events
      - Apply initial visibility/layout
   
   b. InitializeBar()
      - Merge defaults
      - Create LEMSettingsLoader
      - Call LEMSettingsLoader:Init()
        - Register frame with LEM via LEM:AddFrame()
        - Register LEM callbacks (enter, exit, layout, etc.)
      - Call LEMSettingsLoader:LoadSettings()
        - LEM:AddFrameSettings() → generates Edit Mode UI
   
   c. Store in addonTable.barInstances[frameName]
   ↓
4. addonTable.SettingsRegistrar() → Register settings UI categories
   ↓
5. At runtime:
   a. Events fire → bar:OnEvent()
   b. Calls bar:UpdateDisplay() → updates StatusBar/Text
   c. Calls bar:ApplyVisibilitySettings() → show/hide bar
   ↓
6. In Edit Mode:
   a. User drags bar
   b. LEM calls OnPositionChanged(frame, layoutName, point, x, y)
   c. Saves to SenseiClassResourceBarDB[dbName][layoutName]
   d. Calls bar:ApplyLayout()
   e. Database auto-saved by WoW
```

---

## Key Design Patterns

### 1. Mixin-Based Inheritance
All bars use `CreateFromMixins()` to extend `BarMixin`, enabling code reuse and override capability.

### 2. Layout-Aware Database
All settings are stored per-layout: `DB[barName][layoutName]`
This allows different configurations for different layouts (Default, Raid, etc.)

### 3. Callback-Driven Updates
- Events trigger `OnEvent()` → calls `UpdateDisplay()` and `ApplyVisibilitySettings()`
- Position changes trigger `OnPositionChanged()` → calls `ApplyLayout()`
- Layout switches trigger LEM callback → calls various apply methods

### 4. LEM Integration Pattern
1. Register frame: `LEM:AddFrame(frame, positionCallback, defaults)`
2. Register settings: `LEM:AddFrameSettings(frame, settings)`
3. Register callbacks: `LEM:RegisterCallback("event", callback)`
4. Always use `LEM.GetActiveLayoutName()` for current layout

### 5. Performance Optimization
- Cached text formatting patterns to avoid repeated string matching
- Pre-allocated tables for rune tracking
- OnUpdate scripts with tunable intervals (0.1s or 0.25s)
- Conditional updates (only if shown unless force=true)

