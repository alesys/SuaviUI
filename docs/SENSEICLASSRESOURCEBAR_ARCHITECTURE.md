# SenseiClassResourceBar Architecture Analysis

**Addon Version:** 1.4.7  
**Analysis Date:** January 28, 2026  
**Purpose:** Comprehensive architectural overview for porting/adoption planning

---

## Table of Contents

1. [Overview](#overview)
2. [File Structure & Loading Order](#file-structure--loading-order)
3. [Core Architecture Patterns](#core-architecture-patterns)
4. [Mixin Inheritance Hierarchy](#mixin-inheritance-hierarchy)
5. [Database Structure (SenseiClassResourceBarDB)](#database-structure-senseiclassresourcebardb)
6. [Bar Registration System](#bar-registration-system)
7. [LibEQOLEditMode Integration](#libeqoleditmode-integration)
8. [Settings & Configuration System](#settings--configuration-system)
9. [Event Handling Patterns](#event-handling-patterns)
10. [UI Creation Patterns](#ui-creation-patterns)
11. [Notable Design Decisions](#notable-design-decisions)
12. [Key Takeaways for Porting](#key-takeaways-for-porting)

---

## Overview

SenseiClassResourceBar (SCRB) is a modular addon that provides customizable resource bars (Health, Primary, Secondary, Tertiary) for all WoW classes. It uses a sophisticated mixin-based architecture with deep integration into Blizzard's Edit Mode via `LibEQOLEditMode-1.0`.

### Key Features
- **Health Bar** - Player health display
- **Primary Resource Bar** - Main power (Mana, Rage, Energy, Focus, etc.)
- **Secondary Resource Bar** - Class-specific secondary (Combo Points, Runes, Chi, etc.)
- **Tertiary Resource Bar** - Specialized (Ebon Might for Augmentation Evoker)
- **Fragmented Power Display** - Individual segments for resources like Runes, Essence
- **Full Edit Mode integration** - Drag/drop positioning, settings panels
- **Import/Export system** - Profile sharing with compression

---

## File Structure & Loading Order

### TOC File
```
## SavedVariables: SenseiClassResourceBarDB

# Lib
embeds.xml                    # External libraries

SenseiClassResourceBar.xml    # Main load orchestrator
```

### embeds.xml (Libraries)
```
1. LibStub                    # Library version management
2. CallbackHandler-1.0        # Event callback system
3. LibEQOL (full package)     # Edit Mode integration library
4. LibSharedMedia-3.0         # Font/texture/statusbar media
5. LibSerialize               # Data serialization
6. LibDeflate                 # Compression for import/export
```

### SenseiClassResourceBar.xml (Main Load Order)
```
1. Locales/embeds.xml         # Localization
   ├── Loader.lua             # Locale registration system
   ├── enUS.lua               # English (base)
   └── zhCN.lua, koKR.lua     # Other locales

2. Constants.lua              # Global constants, defaults, dropdown options

3. Dialogs.lua                # StaticPopup dialogs for import/export

4. Helpers/embeds.xml
   ├── API.lua                # Public API, import/export functions
   ├── Color.lua              # Resource color resolution
   ├── LEMSettingsLoader.lua  # Edit Mode settings builder (992 lines!)
   ├── TipOfTheSpear.lua      # Hunter-specific resource tracker
   └── Whirlwind.lua          # Warrior-specific resource tracker

5. Bars/embeds.xml
   ├── Abstract/embeds.xml
   │   ├── Bar.lua            # Base BarMixin (1350 lines - core logic)
   │   └── PowerBar.lua       # PowerBarMixin extends BarMixin
   ├── PrimaryResourceBar.lua
   ├── SecondaryResourceBar.lua
   ├── TertiaryResourceBar.lua
   └── HealthBar.lua

6. Settings/embeds.xml
   ├── HealthAndPowerColorSettings.lua
   └── ImportExportSettings.lua

7. SenseiClassResourceBarSettings.lua   # Settings registrar

8. SenseiClassResourceBar.lua           # Main entry point, bar factory
```

---

## Core Architecture Patterns

### 1. Addon Table Pattern
```lua
local addonName, addonTable = ...

-- All shared data stored on addonTable:
addonTable.LSM = LibStub("LibSharedMedia-3.0")
addonTable.LEM = LibStub("LibEQOLEditMode-1.0")
addonTable.L = {}  -- Locales
addonTable.RegisteredBar = {}  -- Bar configurations
addonTable.barInstances = {}   -- Runtime bar instances
```

### 2. Mixin-Based OOP
Uses Blizzard's `Mixin()` and `CreateFromMixins()` for inheritance:
```lua
-- Base mixin
local BarMixin = {}
function BarMixin:Init(config, parent, frameLevel) ... end
function BarMixin:OnLoad() ... end

-- Derived mixin extending base
local PowerBarMixin = Mixin({}, addonTable.BarMixin)
function PowerBarMixin:OnLoad()
    -- Call parent
    self.Frame:RegisterEvent(...)
end

-- Final concrete mixin
local PrimaryResourceBarMixin = Mixin({}, addonTable.PowerBarMixin)
```

### 3. Factory Pattern for Bar Creation
```lua
local function CreateBarInstance(config, parent, frameLevel)
    -- Initialize database
    if not SenseiClassResourceBarDB[config.dbName] then
        SenseiClassResourceBarDB[config.dbName] = {}
    end

    -- Create from mixin
    local bar = CreateFromMixins(config.mixin or addonTable.BarMixin)
    bar:Init(config, parent, frameLevel)

    -- Copy defaults per-layout
    local curLayout = addonTable.LEM.GetActiveLayoutName() or "Default"
    if not SenseiClassResourceBarDB[config.dbName][curLayout] then
        SenseiClassResourceBarDB[config.dbName][curLayout] = CopyTable(bar.defaults)
    end

    bar:OnLoad()
    bar:GetFrame():SetScript("OnEvent", function(_, ...)
        bar:OnEvent(...)
    end)

    return bar
end
```

---

## Mixin Inheritance Hierarchy

```
BarMixin (Abstract Base - Bar.lua)
├── Properties: Frame, StatusBar, Background, Border, Mask, TextValue
├── Methods: Init, OnLoad, Show/Hide, GetData, GetPoint, GetSize
├── Layout: ApplyLayout, ApplyFontSettings, ApplyFillDirection, etc.
├── Display: UpdateDisplay, ApplyVisibilitySettings
└── Fragmented: CreateFragmentedPowerBars, UpdateFragmentedPowerDisplay

    └── PowerBarMixin (Power-specific - PowerBar.lua)
        ├── Extends: BarMixin
        ├── Overrides: GetBarColor, OnLoad, OnEvent, GetTagValues
        └── Events: PLAYER_ENTERING_WORLD, UNIT_MAXPOWER, combat/target changes
        
            ├── PrimaryResourceBarMixin
            │   ├── Class/spec-based resource detection
            │   └── Druid form-based resource switching
            
            ├── SecondaryResourceBarMixin
            │   ├── Complex resource types (Runes, Stagger, Soul Fragments)
            │   └── Custom resource helpers (TipOfTheSpear, Whirlwind)
            
            └── TertiaryResourceBarMixin
                └── Ebon Might tracking for Augmentation Evoker

    └── HealthBarMixin (Health-specific - HealthBar.lua)
        ├── Extends: BarMixin directly
        └── Special: Position fallback to other bars when hidden
```

---

## Database Structure (SenseiClassResourceBarDB)

### Top-Level Structure
```lua
SenseiClassResourceBarDB = {
    -- Bar settings per Edit Mode layout
    ["PrimaryResourceBarDB"] = {
        ["Default"] = { ... settings ... },
        ["Raid Layout"] = { ... settings ... },
    },
    ["secondaryResourceBarDB"] = { ... },  -- Note: lowercase naming inconsistency
    ["tertiaryResourceBarDB"] = { ... },
    ["healthBarDB"] = { ... },
    
    -- Global settings (not per-layout)
    ["_Settings"] = {
        ["PowerColors"] = {
            [Enum.PowerType.Mana] = { r = 0.3, g = 0.3, b = 1, a = 1 },
            ["STAGGER_LOW"] = { r = 0.5, g = 1, b = 0.5, a = 1 },
            ...
        },
        ["HealthColors"] = {
            ["HEALTH"] = { r = 0, g = 1, b = 0, a = 1 },
        },
    },
}
```

### Per-Layout Settings Structure
```lua
["Default"] = {
    -- Position (shared with LEM)
    point = "CENTER",
    x = 0,
    y = 0,
    relativeFrame = "UIParent",
    relativePoint = "CENTER",
    
    -- Visibility
    barVisible = "Always Visible",  -- "In Combat", "Has Target Selected", "Hidden"
    barStrata = "MEDIUM",
    hideWhileMountedOrVehicule = false,
    
    -- Size
    scale = 1,
    width = 200,
    height = 15,
    widthMode = "Manual",  -- or "Sync With Essential Cooldowns"
    minWidth = 0,
    
    -- Bar behavior
    fillDirection = "Left to Right",
    smoothProgress = true,
    fasterUpdates = true,
    
    -- Text
    showText = true,
    textFormat = "Current",  -- "Percent", "Current / Maximum"
    textPrecision = "12",
    textColor = { r = 1, g = 1, b = 1, a = 1 },
    font = "...",
    fontSize = 12,
    fontOutline = "OUTLINE",
    textAlign = "CENTER",
    
    -- Style
    maskAndBorderStyle = "Thin",
    borderColor = { r = 0, g = 0, b = 0, a = 1 },
    backgroundStyle = "SCRB Semi-transparent",
    backgroundColor = { r = 1, g = 1, b = 1, a = 1 },
    foregroundStyle = "SCRB FG Fade Left",
    useResourceAtlas = false,
    
    -- Bar-specific (varies by bar type)
    hideManaOnRole = {},  -- PrimaryResourceBar
    hideHealthOnRole = {},  -- HealthBar
    positionMode = "Self",  -- HealthBar: "Use Primary Resource Bar Position If Hidden"
    hideBlizzardPlayerContainerUi = false,  -- HealthBar
    hideBlizzardSecondaryResourceUi = false,  -- SecondaryResourceBar
}
```

---

## Bar Registration System

Bars are registered via a declarative configuration table:

```lua
addonTable.RegisteredBar = addonTable.RegisteredBar or {}
addonTable.RegisteredBar.PrimaryResourceBar = {
    -- Mixin to use
    mixin = addonTable.PrimaryResourceBarMixin,
    
    -- Database key for SavedVariables
    dbName = "PrimaryResourceBarDB",
    
    -- Display name in Edit Mode
    editModeName = L["PRIMARY_POWER_BAR_EDIT_MODE_NAME"],
    
    -- Frame name (also used as key in barInstances)
    frameName = "PrimaryResourceBar",
    
    -- Z-ordering
    frameLevel = 3,
    
    -- Default values merged with commonDefaults
    defaultValues = {
        point = "CENTER",
        x = 0,
        y = 0,
        hideManaOnRole = {},
        showManaAsPercent = false,
        useResourceAtlas = false,
    },
    
    -- Predicates for conditional loading
    loadPredicate = function()
        return true  -- Always load
    end,
    allowEditPredicate = function()
        return true  -- Always show in Edit Mode
    end,
    
    -- Additional LEM settings specific to this bar
    lemSettings = function(bar, defaults)
        return {
            {
                parentId = L["CATEGORY_BAR_VISIBILITY"],
                order = 103,
                name = L["HIDE_MANA_ON_ROLE"],
                kind = LEM.SettingType.MultiDropdown,
                ...
            },
        }
    end,
}
```

### Initialization Flow
```
ADDON_LOADED event
  └── For each registered bar config:
       └── Check loadPredicate (if exists)
            └── InitializeBar(config)
                 └── CreateBarInstance(config)
                      ├── Create mixin instance
                      ├── bar:Init() - creates Frame, StatusBar, etc.
                      ├── Initialize DB entry for current layout
                      ├── bar:OnLoad() - register events
                      ├── bar:ApplyVisibilitySettings()
                      ├── bar:ApplyLayout()
                      └── bar:UpdateDisplay()
                 └── Create LEMSettingsLoader
                      └── LoadSettings() - register with Edit Mode

  └── addonTable.SettingsRegistrar() - register ESC menu settings
```

---

## LibEQOLEditMode Integration

### LEMSettingsLoader Pattern
Each bar gets its own settings panel in Edit Mode:

```lua
local LEMSettingsLoaderMixin = {}

function LEMSettingsLoaderMixin:Init(bar, defaults)
    self.bar = bar
    self.defaults = defaults
end

function LEMSettingsLoaderMixin:LoadSettings()
    local bar = self.bar
    local config = bar:GetConfig()
    local defaults = self.defaults
    
    -- Build settings array
    local settings = BuildLemSettings(bar, defaults)
    
    -- Merge bar-specific settings
    if config.lemSettings then
        local extraSettings = config.lemSettings(bar, defaults)
        for _, setting in ipairs(extraSettings) do
            table.insert(settings, setting)
        end
    end
    
    -- Register with LEM
    addonTable.LEM:RegisterFrame(bar.Frame, config.editModeName, settings)
end
```

### Settings Definition Format
```lua
{
    -- Category header (collapsible)
    {
        order = 100,
        name = L["CATEGORY_BAR_VISIBILITY"],
        kind = LEM.SettingType.Collapsible,
        id = L["CATEGORY_BAR_VISIBILITY"],  -- Used for parentId
    },
    
    -- Dropdown setting
    {
        parentId = L["CATEGORY_BAR_VISIBILITY"],
        order = 101,
        name = L["BAR_VISIBLE"],
        kind = LEM.SettingType.Dropdown,
        default = defaults.barVisible,
        useOldStyle = true,
        values = addonTable.availableBarVisibilityOptions,
        get = function(layoutName)
            return SenseiClassResourceBarDB[dbName][layoutName].barVisible
        end,
        set = function(layoutName, value)
            SenseiClassResourceBarDB[dbName][layoutName].barVisible = value
            bar:ApplyVisibilitySettings()
        end,
    },
    
    -- Slider setting
    {
        parentId = L["CATEGORY_POSITION_AND_SIZE"],
        order = 202,
        name = L["X_POSITION"],
        kind = LEM.SettingType.Slider,
        default = defaults.x,
        minValue = -uiWidth,
        maxValue = uiWidth,
        valueStep = 1,
        allowInput = true,
        get = function(layoutName) ... end,
        set = function(layoutName, value)
            SenseiClassResourceBarDB[dbName][layoutName].x = value
            bar:ApplyLayout(layoutName)
        end,
    },
    
    -- Checkbox setting
    {
        kind = LEM.SettingType.Checkbox,
        name = L["SMOOTH_PROGRESS"],
        get = function(layoutName) ... end,
        set = function(layoutName, value) ... end,
        isEnabled = function(layoutName)  -- Conditional enablement
            return data.showText
        end,
    },
    
    -- Dropdown with color picker
    {
        kind = LEM.SettingType.DropdownColor,
        name = L["BORDER"],
        get = function(layoutName) ... end,
        colorGet = function(layoutName) ... end,
        set = function(layoutName, value) ... end,
        colorSet = function(layoutName, value) ... end,
    },
}
```

### Edit Mode Position Sync
```lua
-- Bar position is stored in DB and synced with LEM
function BarMixin:GetPoint(layoutName)
    local data = self:GetData(layoutName)
    return data.point, 
           addonTable.resolveRelativeFrames(data.relativeFrame),
           data.relativePoint,
           data.x,
           data.y
end

-- LEM handles drag-and-drop, updates DB via set callbacks
-- Drag disabled when anchored to non-UIParent frames
LEM:SetFrameDragEnabled(self.Frame, relativeTo == UIParent)
```

---

## Settings & Configuration System

### Game Options Panel (ESC Menu)
Uses `LibEQOLSettingsMode-1.0` for ESC menu settings:

```lua
-- SenseiClassResourceBarSettings.lua
local function Register()
    local rootCategory = SettingsLib:CreateRootCategory(addonName)
    
    for _, feature in pairs(addonTable.AvailableFeatures or {}) do
        local metadata = addonTable.FeaturesMetadata[feature]
        local initializer = addonTable.SettingsPanelInitializers[feature]
        
        local category = SettingsLib:CreateCategory(rootCategory, metadata.category)
        initializer(category)
    end
end

addonTable.SettingsRegistrar = Register
```

### Feature Registration Pattern
```lua
-- ImportExportSettings.lua
local featureId = "SCRB_IMPORT_EXPORT"

addonTable.AvailableFeatures = addonTable.AvailableFeatures or {}
table.insert(addonTable.AvailableFeatures, featureId)

addonTable.FeaturesMetadata = addonTable.FeaturesMetadata or {}
addonTable.FeaturesMetadata[featureId] = {
    category = L["SETTINGS_CATEGORY_IMPORT_EXPORT"],
}

addonTable.SettingsPanelInitializers = addonTable.SettingsPanelInitializers or {}
addonTable.SettingsPanelInitializers[featureId] = function(category)
    SettingsLib:CreateText(category, L["DESCRIPTION"])
    SettingsLib:CreateButton(category, {
        text = L["EXPORT"],
        func = function() ... end,
    })
end
```

---

## Event Handling Patterns

### Base Pattern (BarMixin)
```lua
-- Events are registered in OnLoad
function PowerBarMixin:OnLoad()
    self.Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.Frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    self.Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.Frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.Frame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    self.Frame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    self.Frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    self.Frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    self.Frame:RegisterEvent("PET_BATTLE_OPENING_START")
    self.Frame:RegisterEvent("PET_BATTLE_CLOSE")
end

-- OnEvent handler set during factory creation
bar:GetFrame():SetScript("OnEvent", function(_, ...)
    bar:OnEvent(...)
end)

-- Event handling
function PowerBarMixin:OnEvent(event, ...)
    local unit = ...
    
    if event == "PLAYER_ENTERING_WORLD" then
        self:ApplyVisibilitySettings()
        self:ApplyLayout(nil, true)
        
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        self:ApplyVisibilitySettings(nil, event == "PLAYER_REGEN_DISABLED")
        self:UpdateDisplay()
    end
end
```

### Extending Event Handling (Secondary Bar)
```lua
function SecondaryResourceBarMixin:OnLoad()
    addonTable.PowerBarMixin.OnLoad(self)  -- Call parent
    
    -- Add specialized modules
    addonTable.TipOfTheSpear:OnLoad(self)
    addonTable.Whirlwind:OnLoad(self)
end

function SecondaryResourceBarMixin:OnEvent(event, ...)
    addonTable.PowerBarMixin.OnEvent(self, event, ...)  -- Call parent
    
    -- Forward to modules
    addonTable.TipOfTheSpear:OnEvent(self, event, ...)
    addonTable.Whirlwind:OnEvent(self, event, ...)
end
```

### OnUpdate for Continuous Updates
```lua
function BarMixin:EnableFasterUpdates()
    self.fasterUpdates = true
    if not self._OnUpdateFast then
        self._OnUpdateFast = function(frame, delta)
            frame.elapsed = (frame.elapsed or 0) + delta
            if frame.elapsed >= 0.1 then  -- 10 FPS
                frame.elapsed = 0
                self:UpdateDisplay()
            end
        end
    end
    self.Frame:SetScript("OnUpdate", self._OnUpdateFast)
end

function BarMixin:DisableFasterUpdates()
    self.fasterUpdates = false
    -- Slower update rate (0.25s = 4 FPS)
    self.Frame:SetScript("OnUpdate", self._OnUpdateSlow)
end
```

---

## UI Creation Patterns

### Frame Hierarchy (per Bar)
```
Frame (main container)
├── Background (Texture, BACKGROUND layer)
├── StatusBar (status bar frame)
│   ├── StatusBarTexture (foreground fill)
│   └── Mask (MaskTexture - for rounded corners, etc.)
├── Border (Texture, OVERLAY layer)
├── TextFrame (Frame - text container)
│   └── TextValue (FontString)
├── FixedThicknessBorders (optional - for fixed-width borders)
│   ├── top, bottom, left, right (Textures)
└── FragmentedPowerBars[] (StatusBars for segmented resources)
    └── FragmentedPowerBarTexts[] (FontStrings)
```

### Frame Creation Pattern
```lua
function BarMixin:Init(config, parent, frameLevel)
    local Frame = CreateFrame("Frame", config.frameName or "", parent or UIParent)
    Frame:SetFrameLevel(frameLevel)
    
    -- BACKGROUND
    self.Background = Frame:CreateTexture(nil, "BACKGROUND")
    self.Background:SetAllPoints()
    self.Background:SetColorTexture(0, 0, 0, 0.5)

    -- STATUS BAR
    self.StatusBar = CreateFrame("StatusBar", nil, Frame)
    self.StatusBar:SetAllPoints()
    self.StatusBar:SetStatusBarTexture(...)
    self.StatusBar:SetFrameLevel(Frame:GetFrameLevel())

    -- MASK (for rounded corners)
    self.Mask = self.StatusBar:CreateMaskTexture()
    self.Mask:SetAllPoints()
    self.Mask:SetTexture([[path/to/mask.png]])
    self.StatusBar:GetStatusBarTexture():AddMaskTexture(self.Mask)
    self.Background:AddMaskTexture(self.Mask)

    -- BORDER
    self.Border = Frame:CreateTexture(nil, "OVERLAY")
    self.Border:SetAllPoints()

    -- TEXT FRAME (separate for z-ordering)
    self.TextFrame = CreateFrame("Frame", nil, Frame)
    self.TextFrame:SetAllPoints(Frame)
    
    self.TextValue = self.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.TextValue:SetPoint("CENTER", self.TextFrame, "CENTER", 0, 0)

    self.Frame = Frame
end
```

### Fragmented Power Bars (Runes, Combo Points)
```lua
function BarMixin:CreateFragmentedPowerBars(layoutName, data)
    local max = UnitPowerMax("player", resource)
    
    for i = 1, max do
        if not self.FragmentedPowerBars[i] then
            local bar = CreateFrame("StatusBar", nil, self.Frame)
            bar:SetStatusBarTexture(...)
            bar:SetMinMaxValues(0, 1)
            self.FragmentedPowerBars[i] = bar
            
            local text = bar:CreateFontString(nil, "OVERLAY")
            self.FragmentedPowerBarTexts[i] = text
        end
    end
end

function BarMixin:UpdateFragmentedPowerDisplay(layoutName, data, max)
    local width, height = self:GetSize(layoutName, data)
    local segmentWidth = width / max
    
    for i = 1, max do
        local bar = self.FragmentedPowerBars[i]
        bar:SetSize(segmentWidth - 2, height)  -- Gap between segments
        bar:ClearAllPoints()
        bar:SetPoint("LEFT", self.Frame, "LEFT", (i - 1) * segmentWidth, 0)
        
        -- Update fill based on resource state
        if runeReady then
            bar:SetValue(1)
        else
            bar:SetValue(cooldownProgress)
        end
    end
end
```

---

## Notable Design Decisions

### 1. Layout-Based Settings
Settings are stored **per Edit Mode layout**, allowing different configurations for Raid vs Solo vs PvP layouts.

### 2. Global vs Per-Layout Settings
- **Per-Layout:** Position, visibility, style (in `SenseiClassResourceBarDB[dbName][layoutName]`)
- **Global:** Power colors (in `SenseiClassResourceBarDB["_Settings"]`)

### 3. Relative Frame Anchoring
Bars can anchor to other bars or UI elements:
```lua
addonTable.resolveRelativeFrames = function(relativeFrame)
    return {
        ["UIParent"] = UIParent,
        ["Health Bar"] = addonTable.barInstances["HealthBar"].Frame,
        ["Primary Resource Bar"] = addonTable.barInstances["PrimaryResourceBar"].Frame,
        ["PlayerFrame"] = PlayerFrame,
        ["Action Bar"] = _G["MainActionBar"],
        ...
    }[relativeFrame] or UIParent
end
```

### 4. Position Fallback System (HealthBar)
```lua
-- If Health bar is set to use another bar's position when hidden
function HealthBarMixin:GetPoint(layoutName, ignorePositionMode)
    if data.positionMode == "Use Primary Resource Bar Position If Hidden" then
        local primaryResource = addonTable.barInstances["PrimaryResourceBar"]
        if not primaryResource:IsShown() then
            return primaryResource:GetPoint(layoutName, true)  -- Use its position
        end
    end
    return addonTable.PowerBarMixin.GetPoint(self, layoutName)
end
```

### 5. Conditional Loading
```lua
-- Tertiary bar only loads for Evokers
addonTable.RegisteredBar.TertiaryResourceBar = {
    loadPredicate = function()
        return select(2, UnitClass("player")) == "EVOKER"
    end,
    allowEditPredicate = function()
        return C_SpecializationInfo.GetSpecializationInfo(...) == 1473  -- Augmentation
    end,
}
```

### 6. Resource Color Override System
Two-layer color resolution:
```lua
function addonTable:GetOverrideResourceColor(resource)
    local color = self:GetResourceColor(resource)  -- Get default
    
    -- Check for user override
    local overrideColor = SenseiClassResourceBarDB["_Settings"]["PowerColors"][resource]
    if overrideColor then
        -- Merge override into default
        if overrideColor.r then color.r = overrideColor.r end
        if overrideColor.g then color.g = overrideColor.g end
        if overrideColor.b then color.b = overrideColor.b end
    end
    
    return color
end
```

### 7. Performance Optimizations
```lua
-- Pre-allocated tables to avoid GC pressure
self._displayOrder = {}
self._cachedTextFormat = nil
self._cachedTextPattern = nil
self._runeReadyList = {}
self._runeCdList = {}
self._runeInfoPool = {}
for i = 1, 6 do
    self._runeInfoPool[i] = { index = 0, remaining = 0, frac = 0 }
end

-- Cached text format compilation
if self._cachedTextFormat ~= textFormat then
    self._cachedTextFormat = textFormat
    self._cachedTextPattern = {}
    for tag in textFormat:gmatch('%[..-%]+') do
        self._cachedTextPattern[#self._cachedTextPattern + 1] = tag
    end
    self._cachedFormat, self._cachedNum = textFormat:gsub('%%', '%%%%'):gsub('%[..-%]+', '%%s')
end
```

---

## Key Takeaways for Porting

### Strengths to Adopt

1. **Mixin Hierarchy**
   - Clean separation: Base → Power → Specific
   - Easy to override specific methods
   - Shared code in base class

2. **Bar Registration Pattern**
   - Declarative configuration
   - Easy to add new bar types
   - loadPredicate/allowEditPredicate for conditional logic

3. **Settings Abstraction**
   - Generic settings builder (LEMSettingsLoader)
   - Per-layout storage for Edit Mode integration
   - Clear get/set callback pattern

4. **Modular Event Handling**
   - Base events in parent mixin
   - Child mixins extend via parent calls
   - Separate modules for complex tracking (TipOfTheSpear)

### Things to Consider

1. **Database Naming Inconsistency**
   - `PrimaryResourceBarDB` vs `secondaryResourceBarDB` (case difference)
   - Recommend consistent naming convention

2. **Large File Sizes**
   - Bar.lua is 1350 lines
   - LEMSettingsLoader.lua is 992 lines
   - Consider splitting if adding more features

3. **LibEQOL Dependency**
   - Heavy reliance on external library for Edit Mode
   - Ensure library compatibility with your use case

4. **Complex Resource Detection**
   - Class/spec/form-based resource tables can be hard to maintain
   - Consider data-driven approach for easier updates

### Recommended Porting Strategy

1. **Start with Bar.lua Base Mixin** - Core frame creation and layout logic
2. **Implement PowerBar for your primary use case** - Event handling template
3. **Add LEMSettingsLoader equivalent** - For Edit Mode integration
4. **Create registration system** - Declarative bar configs
5. **Add specialized bars** - Extend as needed

---

## Quick Reference: Key Functions

| Function | Purpose |
|----------|---------|
| `BarMixin:Init()` | Create frame hierarchy |
| `BarMixin:OnLoad()` | Register events |
| `BarMixin:GetData(layoutName)` | Get settings for current layout |
| `BarMixin:GetResource()` | Return current resource type |
| `BarMixin:GetResourceValue(resource)` | Return max, current values |
| `BarMixin:ApplyLayout()` | Apply all visual settings |
| `BarMixin:ApplyVisibilitySettings()` | Show/hide based on conditions |
| `BarMixin:UpdateDisplay()` | Update status bar value and text |
| `BarMixin:GetBarColor(resource)` | Get color for resource type |
| `LEMSettingsLoaderMixin:LoadSettings()` | Register with Edit Mode |
| `CreateBarInstance()` | Factory function for bars |
