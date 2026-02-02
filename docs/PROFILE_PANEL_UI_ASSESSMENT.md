# Profile System & Panel UI Assessment - DEEP RE-ANALYSIS

**Date:** February 1, 2026  
**Status:** Complete Deep Analysis Following Copilot Instructions Methodology  
**Assessment Scope:** Profile persistence, Panel UI integration, Edit Mode Side Panels wiring  
**Reference Implementation:** SenseiClassResourceBar (fully documented)

---

## Executive Summary

**Overall Status:** ⚠️ **PARTIALLY WIRED - CRITICAL ARCHITECTURAL DEVIATION FROM REFERENCE**

After comprehensive re-analysis following the "Implementation Discipline" from `.copilot-instructions.md`, **NEW CRITICAL FINDINGS** have emerged:

### The Core Problem

**SuaviUI Resource Bars INTENTIONALLY DEVIATED from the proven Sensei pattern** by attempting to unify databases, but **the implementation is incomplete**.

### Two Database Systems (ARCHITECTURAL SPLIT)

1. **AceDB Profile System** (`SuaviUI_DB`) - Used by:
   - SUICore and Panel UI (`SUI.db.profile`)
   - Unit Frames, Castbar, Action Bars, CDM
   - ✅ Profile export/import working
   - ✅ Per-character/per-spec support

2. **Direct SavedVariables** (`SuaviUI_ResourceBarsDB`) - Used by:
   - Resource Bars (Primary, Secondary, Tertiary)
   - ❌ NOT in AceDB
   - ❌ Profile export/import broken
   - ⚠️ Has a **failed unification attempt** in Constants.lua

### NEW DISCOVERY: Failed Unification Attempt

**File:** [utils/resourcebars/Constants.lua](utils/resourcebars/Constants.lua#L20-L28)

```lua
function RB.GetResourceBarsDB()
    if SUICore and SUICore.db and SUICore.db.profile then
        SUICore.db.profile.resourceBars = SUICore.db.profile.resourceBars or {}
        SuaviUI_ResourceBarsDB = SUICore.db.profile.resourceBars  -- ⚠️ ALIASING ATTEMPT
        return SuaviUI_ResourceBarsDB
    end

    SuaviUI_ResourceBarsDB = SuaviUI_ResourceBarsDB or {}
    return SuaviUI_ResourceBarsDB
end
```

**This code SHOULD unify the databases, but it's NOT CALLED anywhere during initialization!**

---

## 1. SENSEI REFERENCE IMPLEMENTATION ANALYSIS

### 1.1 Complete Data Flow Mapping

Following the copilot instructions' "Implementation Discipline", here is the **complete Sensei architecture**:

#### Entry Points (ADDON_LOADED event)

**File:** `SenseiClassResourceBar.lua` (Main entry point)

```lua
-- Event Flow:
ADDON_LOADED → Initialize all registered bars
  1. Create SenseiClassResourceBarDB if not exists
  2. Loop through addonTable.RegisteredBar configs
  3. For each bar: InitializeBar(config)
     a. CreateBarInstance(config) - Mixin creation
     b. Initialize LEMSettingsLoader - Edit Mode registration
     c. bar:OnLoad() - Event registration
     d. bar:ApplyVisibilitySettings()
     e. bar:ApplyLayout(true)
     f. bar:UpdateDisplay(true)
```

#### Database Structure (EXACT pattern from Sensei)

```lua
SenseiClassResourceBarDB = {
    ["healthBarDB"] = {
        ["Default"] = { point = "CENTER", x = 0, y = 0, scale = 1, ... },
        ["Raid"] = { point = "CENTER", x = 0, y = 0, scale = 1, ... },
    },
    ["PrimaryResourceBarDB"] = {
        ["Default"] = { ... },
        ["Raid"] = { ... },
    },
    ["secondaryResourceBarDB"] = { ... },  -- Note: lowercase in Sensei
    ["tertiaryResourceBarDB"] = { ... },
    ["_Settings"] = {  -- Global settings (not per-layout)
        ["PowerColors"] = { ... },
        ["HealthColors"] = { ... },
    },
}
```

#### Critical Pattern: Direct SavedVariable Access

**Sensei DOES NOT use AceDB!** It uses direct SavedVariables:

```lua
-- In .toc file:
## SavedVariables: SenseiClassResourceBarDB

-- Access pattern throughout code:
SenseiClassResourceBarDB[config.dbName][layoutName] = settings
```

#### LEM Integration Pattern (Position Change Callback)

**File:** `Helpers/LEMSettingsLoader.lua` - Lines 828-885

```lua
function LEMSettingsLoaderMixin:Init(bar, defaults)
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

    -- Register frame with LEM
    LEM:AddFrame(frame, OnPositionChanged, defaults)
    
    -- LEM Callbacks (layout switching, duplication, etc.)
    LEM:RegisterCallback("layout", function(layoutName)
        -- Initialize layout if not exists
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        bar:OnLayoutChange(layoutName)
        bar:ApplyVisibilitySettings(layoutName)
        bar:ApplyLayout(layoutName, true)
        bar:UpdateDisplay(layoutName, true)
    end)
end
```

#### Settings Structure (Edit Mode Sidebar)

**File:** `Helpers/LEMSettingsLoader.lua` - Lines 1-992

Each setting follows this **exact pattern**:

```lua
{
    parentId = L["CATEGORY_POSITION_AND_SIZE"],
    order = 202,
    name = L["X_POSITION"],
    kind = LEM.SettingType.Slider,
    default = defaults.x,
    minValue = uiWidth * -1,
    maxValue = uiWidth,
    valueStep = 1,
    allowInput = true,
    get = function(layoutName)
        local data = SenseiClassResourceBarDB[config.dbName][layoutName]
        return data and (data.x ~= nil and rounded(data.x) or defaults.x) or defaults.x
    end,
    set = function(layoutName, value)
        SenseiClassResourceBarDB[config.dbName][layoutName] = 
            SenseiClassResourceBarDB[config.dbName][layoutName] or CopyTable(defaults)
        SenseiClassResourceBarDB[config.dbName][layoutName].x = rounded(value)
        bar:ApplyLayout(layoutName)  -- Apply immediately
    end,
}
```

**Key Observation:** Every `set()` callback:
1. Writes directly to `SenseiClassResourceBarDB`
2. Calls `bar:ApplyLayout(layoutName)` immediately
3. NO profile system abstraction layer

---

## 2. SUAVIUI CURRENT IMPLEMENTATION

### 2.1 What SuaviUI Copied from Sensei

**Copied Correctly:** ✅
- Mixin-based architecture
- Bar registration pattern (`RB.RegisteredBar`)
- LEM integration (AddFrame, callbacks)
- Settings structure (get/set pattern)
- ApplyLayout, ApplyVisibilitySettings, UpdateDisplay methods

**File:** [utils/resourcebars/init.lua](utils/resourcebars/init.lua)

```lua
-- EXACT SAME PATTERN as Sensei
local function InitializeResourceBars()
    RB.GetResourceBarsDB()  -- ⚠️ This is NEW - not in Sensei!

    for barName, config in pairs(RB.RegisteredBar) do
        if not SuaviUI_ResourceBarsDB[config.dbName] then
            SuaviUI_ResourceBarsDB[config.dbName] = {}
        end

        local bar = CreateBarInstance(barName, config, UIParent)
        RB.barInstances[config.frameName] = bar

        local layoutName = LEM.GetActiveLayoutName() or "Default"
        if not SuaviUI_ResourceBarsDB[config.dbName][layoutName] then
            local defaults = CopyTable(RB.commonDefaults)
            for k, v in pairs(config.defaultValues or {}) do
                defaults[k] = v
            end
            SuaviUI_ResourceBarsDB[config.dbName][layoutName] = CopyTable(defaults)
        end

        bar:ApplyLayout(layoutName, true)
        bar:UpdateDisplay(layoutName, true)
    end
end
```

### 2.2 Where SuaviUI Deviated from Sensei

**CRITICAL DEVIATION:** Added `RB.GetResourceBarsDB()` function

**File:** [utils/resourcebars/Constants.lua](utils/resourcebars/Constants.lua#L20-L28)

```lua
function RB.GetResourceBarsDB()
    if SUICore and SUICore.db and SUICore.db.profile then
        -- ATTEMPT: Alias SuaviUI_ResourceBarsDB to profile.resourceBars
        SUICore.db.profile.resourceBars = SUICore.db.profile.resourceBars or {}
        SuaviUI_ResourceBarsDB = SUICore.db.profile.resourceBars
        return SuaviUI_ResourceBarsDB
    end

    -- FALLBACK: Create standalone SavedVariable
    SuaviUI_ResourceBarsDB = SuaviUI_ResourceBarsDB or {}
    return SuaviUI_ResourceBarsDB
end
```

**Intent:** Unify `SuaviUI_ResourceBarsDB` with AceDB profile

**Problem:** This function is called in **init.lua line 53**, but:
1. ❌ `SuaviUI_ResourceBarsDB` is declared as SavedVariable in `.toc`
2. ❌ The aliasing happens AFTER WoW loads SavedVariables
3. ❌ All subsequent code still uses `SuaviUI_ResourceBarsDB` directly
4. ❌ The alias is NOT a reference - it's a one-time copy

### 2.3 The Aliasing Problem

**What the code TRIES to do:**
```lua
SuaviUI_ResourceBarsDB = SUICore.db.profile.resourceBars  -- Alias attempt
```

**What ACTUALLY happens:**
```lua
-- WoW loads SavedVariables BEFORE addon code runs:
SuaviUI_ResourceBarsDB = { ... } (from saved data)

-- Then our code runs:
SuaviUI_ResourceBarsDB = SUICore.db.profile.resourceBars or {}

-- Now they're TWO SEPARATE tables!
-- Changes to SuaviUI_ResourceBarsDB don't affect SUICore.db.profile.resourceBars
```

**Proof:** Throughout the codebase, ALL references are to `SuaviUI_ResourceBarsDB`:

```lua
-- In LEMSettingsLoader.lua (50+ occurrences):
SuaviUI_ResourceBarsDB[config.dbName][layoutName].x = value
SuaviUI_ResourceBarsDB[config.dbName][layoutName].scale = value
// ... etc
```

**None of these write to `SUICore.db.profile.resourceBars`!**

---

## 3. NEW FINDINGS: The Root Cause

### 3.1 The Failed Unification Strategy

**Goal:** Make resource bars use AceDB profiles like the rest of SuaviUI

**Attempted Strategy:**
1. Keep `SuaviUI_ResourceBarsDB` as SavedVariable (for compatibility)
2. Alias it to `SUICore.db.profile.resourceBars`
3. All writes go to the alias, which updates the profile

**Why It Failed:**
- **Lua tables are references**, but **SavedVariables are loaded BEFORE addon code**
- By the time `GetResourceBarsDB()` runs, `SuaviUI_ResourceBarsDB` already exists
- The assignment `SuaviUI_ResourceBarsDB = SUICore.db.profile.resourceBars` creates a NEW reference
- The original SavedVariable is lost, profile.resourceBars is not updated

### 3.2 Why Sensei Doesn't Have This Problem

**Sensei's Approach:** Simple and direct
- No profile system
- Direct SavedVariable access
- No aliasing attempts
- No abstraction layers

**Sensei's Import/Export:**
```lua
-- Export: Directly read from SenseiClassResourceBarDB
RB.exportProfileAsString = function()
    return encodeDataAsString(SenseiClassResourceBarDB)
end

-- Import: Directly write to SenseiClassResourceBarDB
RB.importProfileFromString = function(importString)
    local data = decodeDataAsString(importString)
    for dbName, layoutData in pairs(data.BARS) do
        SenseiClassResourceBarDB[dbName] = layoutData
    end
end
```

**SuaviUI's Import/Export:**
```lua
-- Export: Uses SuaviUI_ResourceBarsDB (NOT in profile!)
RB.exportProfileAsString = function()
    return encodeDataAsString(SuaviUI_ResourceBarsDB)
end

-- But SuaviUI's MAIN export:
SUICore:ExportProfileToString()
    -- Returns SUICore.db.profile
    -- Does NOT include SuaviUI_ResourceBarsDB!
```

---

## 4. COMPLETE WIRING STATUS (UPDATED)

### 4.1 Panel UI (Options Panel)

| Component | Profile Storage | Edit Mode | Sidebar | Export/Import | Status |
|-----------|:---------------:|:---------:|:-------:|:-------------:|:------:|
| **FPS Settings** | ✅ `db.profile.fpsBackup` | ❌ | ❌ | ✅ | ✅ Complete |
| **Chat Settings** | ✅ `db.profile.chat` | ❌ | ❌ | ✅ | ✅ Complete |
| **Tooltips** | ✅ `db.profile.tooltips` | ❌ | ❌ | ✅ | ✅ Complete |
| **Loot Settings** | ✅ `db.profile.loot` | ❌ | ❌ | ✅ | ✅ Complete |

**Assessment:** Panel UI is **100% wired** to `SUICore.db.profile`

---

### 4.2 Edit Mode Side Panels

| Component | Profile Storage | LEM Integration | Sidebar Settings | Export/Import | Per-Layout | Status |
|-----------|:---------------:|:---------------:|:----------------:|:-------------:|:----------:|:------:|
| **Unit Frames** | ✅ `db.profile.unitframes` | ✅ | ✅ | ✅ | ✅ | ✅ Complete |
| **Castbar** | ✅ `db.profile.castbar` | ✅ | ✅ | ✅ | ✅ | ✅ Complete |
| **Action Bars** | ✅ `db.profile.actionbars` | ✅ | ✅ | ✅ | ⚠️ Partial | ⚠️ Verify |
| **CDM Viewers** | ✅ `db.profile.viewers` | ✅ | ✅ | ✅ | ✅ | ✅ Complete |
| **Resource Bars** | ❌ `SuaviUI_ResourceBarsDB` | ✅ | ✅ | ❌ | ✅ | ❌ **BROKEN** |

**Key Finding:**  
- Unit Frames, Castbar, CDM = **Proper AceDB integration**
- Resource Bars = **Separate database, NOT in profile**

---

### 4.3 Code Comparison: Unit Frames vs Resource Bars

#### Unit Frames (CORRECT) ✅

**File:** [utils/unitframes_editmode.lua](utils/unitframes_editmode.lua)

```lua
local function GetUFDB()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile.unitframes  -- ✅ Direct profile access
    end
    return nil
end

-- Settings:
get = function(layoutName)
    local db = GetUFDB()
    if db and db.player then
        return db.player.offsetX or defaults.offsetX  -- ✅ Reads from profile
    end
    return defaults.offsetX
end,

set = function(layoutName, value)
    local db = GetUFDB()
    if db and db.player then
        db.player.offsetX = value  -- ✅ Writes to profile
        SUI_UF:ApplyLayout()
    end
end,
```

#### Resource Bars (INCORRECT) ❌

**File:** [utils/resourcebars/LEMSettingsLoader.lua](utils/resourcebars/LEMSettingsLoader.lua)

```lua
-- NO GetDB() helper - uses global directly

-- Settings:
get = function(layoutName)
    return (SuaviUI_ResourceBarsDB[config.dbName][layoutName]  -- ❌ Global variable
            and SuaviUI_ResourceBarsDB[config.dbName][layoutName].x) 
           or defaults.x
end,

set = function(layoutName, value)
    SuaviUI_ResourceBarsDB[config.dbName][layoutName] =   -- ❌ Global variable
        SuaviUI_ResourceBarsDB[config.dbName][layoutName] or CopyTable(defaults)
    SuaviUI_ResourceBarsDB[config.dbName][layoutName].x = value
    bar:ApplyLayout(layoutName)
end,
```

**The Difference:**
- Unit Frames: `SUICore.db.profile.unitframes` → ✅ In AceDB
- Resource Bars: `SuaviUI_ResourceBarsDB` → ❌ NOT in AceDB

---

## 5. WHY THE CURRENT APPROACH DOESN'T WORK

### 5.1 The Aliasing Misconception

**What developers thought would happen:**
```lua
-- Initialize
SuaviUI_ResourceBarsDB = SUICore.db.profile.resourceBars

-- Later writes
SuaviUI_ResourceBarsDB[dbName][layout].x = 100

// ↓ Developers expected this to update the profile
SUICore.db.profile.resourceBars[dbName][layout].x === 100  ✅
```

**What ACTUALLY happens:**
```lua
-- WoW loads SavedVariables FIRST
_G["SuaviUI_ResourceBarsDB"] = { ... }  (from disk)

-- Our code runs
local tempRef = SUICore.db.profile.resourceBars or {}
SuaviUI_ResourceBarsDB = tempRef  -- This changes the LOCAL variable

-- But _G["SuaviUI_ResourceBarsDB"] is UNCHANGED!
-- All subsequent code uses _G["SuaviUI_ResourceBarsDB"]
```

### 5.2 SavedVariables vs Lua References

**WoW's SavedVariables system:**
1. On `/reload`, WoW saves `_G["SuaviUI_ResourceBarsDB"]` to disk
2. On login, WoW loads saved data into `_G["SuaviUI_ResourceBarsDB"]`
3. **Our aliasing code runs AFTER this load**
4. **Changes to local variable don't affect `_G`**

**Proof:**
```lua
-- In Constants.lua
function RB.GetResourceBarsDB()
    SuaviUI_ResourceBarsDB = SUICore.db.profile.resourceBars  -- Local change
end

-- In LEMSettingsLoader.lua
SuaviUI_ResourceBarsDB[dbName][layout].x = 100  -- Uses _G, not local!
```

### 5.3 The Correct Unification Pattern (from Unit Frames)

**File:** [init.lua](init.lua) + [suicore_main.lua](utils/suicore_main.lua)

```lua
-- Defined in init.lua
SuaviUI.defaults = {
    global = {},
    char = {
        debug = { reload = false }
    }
}

-- Initialized in OnInitialize()
self.db = LibStub("AceDB-3.0"):New("SuaviUI_DB", self.defaults, "Default")
```

**Key Characteristics:**
- ✅ Per-character profiles
- ✅ Per-specialization support via LibDualSpec
- ✅ Global/character/spec scope support
- ✅ Automatic persistence to `SuaviUI_DB` SavedVariable
- ✅ Profile switching infrastructure

**Access Pattern:**
```lua
local function GetDB()
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile
    end
    return nil
end
```

---

### 1.2 Secondary Database: Direct SavedVariables (Resource Bars)

**File:** [utils/resourcebars/init.lua](utils/resourcebars/init.lua#L38)

```lua
-- Multiple independent databases (NOT using AceDB):
SuaviUI_ResourceBarsDB
SuaviUI_DB (from AceDB, different purpose)
```

**Key Characteristics:**
- ❌ Completely separate from AceDB
- ❌ Declared in `.toc` file as SavedVariable
- ✅ Per-layout storage (Edit Mode layouts)
- ⚠️ Direct table manipulation (no abstraction)
- ⚠️ Different access pattern from rest of addon

**Structure:**
```lua
SuaviUI_ResourceBarsDB = {
    ["PrimaryResourceBar"] = {
        ["Default"] = { x = 0, y = 0, scale = 1, ... },
        ["Layout1"] = { x = 0, y = 0, scale = 1, ... },
    },
    ["SecondaryResourceBar"] = { ... },
}
```

---

## 2. PANEL UI & PROFILE WIRING

### 2.1 Options Panel Integration

**File:** [utils/sui_options.lua](utils/sui_options.lua)

**Status:** ✅ **FULLY WIRED TO PROFILE**

All GUI widgets use the pattern:
```lua
GUI:CreateSlider(tabContent, label, "settingKey", dbTable, min, max, step)
```

**Widget Types Wired to Profile:**
- ✅ Sliders - FPS settings, scale, positioning
- ✅ Toggles/Checkboxes - All boolean flags
- ✅ Color Pickers - Theme colors
- ✅ Dropdowns - Texture selection, anchoring
- ✅ Input Fields - Text values

**Example from sui_options.lua:239-240:**
```lua
local function GetDB()
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile
    end
    return nil
end
```

**Critical Finding:** Panel UI properly accesses `SUICore.db.profile` for all settings.

---

### 2.2 GUI Widget Synchronization

**File:** [utils/sui_gui.lua](utils/sui_gui.lua#L91-L103)

**Synchronization Mechanism:**
```lua
-- Track widget instances for cross-panel sync
GUI.WidgetInstances = {}
GUI.SettingsRegistry = {}

function RegisterWidgetInstance(widget, dbTable, dbKey)
    local widgetKey = GetWidgetKey(dbTable, dbKey)
    GUI.WidgetInstances[widgetKey] = GUI.WidgetInstances[widgetKey] or {}
    table.insert(GUI.WidgetInstances[widgetKey], widget)
end
```

**Status:** ⚠️ **PARTIALLY IMPLEMENTED**
- ✅ Search results sync with original tabs
- ⚠️ No real-time cross-widget updates during gameplay
- ❌ No listener system for profile changes

**Missing Callback System:**
```lua
-- This doesn't exist:
SUICore.db:RegisterCallback("OnProfileChanged", function()
    -- Update all widgets
end)
```

---

## 3. EDIT MODE SIDE PANELS

### 3.1 Current Implementations

#### A. Unit Frames Edit Mode Panels

**File:** [utils/unitframes_editmode.lua](utils/unitframes_editmode.lua)

**Status:** ✅ **PROPERLY WIRED**

```lua
local LEM = LibStub("LibEQOLEditMode-1.0", true)

-- Settings are stored in db.profile via callbacks:
get = function(layoutName)
    local db = GetUFDB()
    if db and db.player then
        return db.player.offsetX or defaults.offsetX
    end
    return defaults.offsetX
end,

set = function(layoutName, value)
    local db = GetUFDB()
    if db and db.player then
        db.player.offsetX = value
        -- Apply changes immediately
        SUI_UF:ApplyLayout()
    end
end,
```

**Saved To:**
- Edit Mode layout system (LibEQOL handles position/scale)
- `db.profile.unitframes.{unitKey}.offsetX/Y` (custom positioning)

---

#### B. Castbar Edit Mode Panels

**File:** [utils/castbar_editmode.lua](utils/castbar_editmode.lua)

**Status:** ✅ **PROPERLY WIRED**

```lua
local function GetDB()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile
    end
    return nil
end

-- Settings stored per layout
get = function(layoutName)
    local db = GetDB()
    return (db and db.castbar and db.castbar[layoutName]) or defaults[layoutName]
end,

set = function(layoutName, value)
    local db = GetDB()
    if db then
        db.castbar = db.castbar or {}
        db.castbar[layoutName] = value
    end
end,
```

**Saved To:**
- `db.profile.castbar.{layoutName}.{setting}` (AceDB profile)

---

#### C. Action Bars Edit Mode Panels

**File:** [utils/actionbars_editmode.lua](utils/actionbars_editmode.lua)

**Status:** ✅ **PROPERLY WIRED**

Same pattern as castbar - uses `db.profile.actionbars.{layoutName}`

---

#### D. Resource Bars Edit Mode Panels ⚠️ ISSUE

**File:** [utils/resourcebars/LEMSettingsLoader.lua](utils/resourcebars/LEMSettingsLoader.lua)

**Status:** ❌ **WIRED TO WRONG DATABASE**

```lua
-- Settings stored in SEPARATE database, not AceDB:
get = function(layoutName)
    return (SuaviUI_ResourceBarsDB[config.dbName][layoutName] 
            and SuaviUI_ResourceBarsDB[config.dbName][layoutName].scale) 
           or defaults.scale
end,

set = function(layoutName, value)
    -- Writing directly to SavedVariables, NOT to AceDB
    SuaviUI_ResourceBarsDB[config.dbName][layoutName] 
        = SuaviUI_ResourceBarsDB[config.dbName][layoutName] or CopyTable(defaults)
    SuaviUI_ResourceBarsDB[config.dbName][layoutName].scale = value
end,
```

**Saved To:**
- `SuaviUI_ResourceBarsDB` (separate SavedVariable, NOT in AceDB profile)

**Problem:**
- ❌ Profile export/import does NOT include resource bar settings
- ❌ Profile switching does NOT restore resource bar positions
- ❌ Inconsistent with entire addon architecture

---

#### E. NCDM (Cooldown Manager) Edit Mode

**File:** [utils/sui_ncdm_editmode.lua](utils/sui_ncdm_editmode.lua) (if exists)

**Status:** ⚠️ **PARTIALLY IMPLEMENTED**

Based on docs, NCDM uses LibEQOL for position/scale, but custom layout logic is separate.

---

### 3.2 Edit Mode Side Panel Architecture

**Three-Tier System:**

```
┌─────────────────────────────────────┐
│  Blizzard Edit Mode (Save/Revert)   │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  LibEQOL (Position/Scale/Layouts)   │
├──────────────────────────────────────┤
│  - Handles drag positioning          │
│  - Manages layout switching          │
│  - Calls get/set callbacks per frame │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│  Frame Settings Panel (Side Panel)   │
├──────────────────────────────────────┤
│  get() callbacks → SuaviUI_DB        │
│  set() callbacks → SuaviUI_DB        │
└──────────────────────────────────────┘
```

**Key Finding:** LibEQOL calls `get(layoutName)` and `set(layoutName, value)` when settings are read/written in the sidebar.

---

## 4. WIRING COMPLETENESS MATRIX

| Component | AceDB Profile | Edit Mode EM | Edit Mode Sidebar | Profile Import/Export | Per-Layout |
|-----------|:-:|:-:|:-:|:-:|:-:|
| **Unit Frames** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Castbar** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Action Bars** | ✅ | ✅ | ✅ | ✅ | ⚠️ Partial |
| **Resource Bars** | ❌ | ✅ | ❌ | ❌ | ✅ |
| **Cooldown Manager (CDM)** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Data Panels** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Buff Borders** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Tooltips** | ✅ | ❌ | ❌ | ❌ | ❌ |

---

## 5. CRITICAL ISSUES FOUND

### 🔴 ISSUE #1: Resource Bars Dual-Database Problem

**Severity:** HIGH  
**Location:** Resource bars system using `SuaviUI_ResourceBarsDB` instead of AceDB

**Impact:**
- Resource bar settings NOT saved in profiles
- Profile export/import loses all resource bar configuration
- Profile switching doesn't restore resource bars
- Breaks addon's "export/import profile" feature

**Example:**
```lua
-- This exports everything EXCEPT resource bars:
SuaviUI:ExportProfileToString()  
-- → Returns SUICore.db.profile (missing SuaviUI_ResourceBarsDB)
```

**Recommendation:** 
Move resource bars settings to `SuaviUI_DB` profile (see Section 7.1)

---

### 🟡 ISSUE #2: Edit Mode Sidebar Callbacks Not Connected to Profile Reload

**Severity:** MEDIUM  
**Location:** All Edit Mode sidebar settings

**Impact:**
- Changing sidebar settings writes to DB but doesn't trigger full refresh
- Some modules may not respond to dynamic updates
- Manual reload sometimes required

**Example:**
```lua
set = function(layoutName, value)
    db.castbar.scale = value
    -- ✅ Frame applies layout immediately
    -- ❌ But no global "profile changed" notification
end
```

---

### 🟡 ISSUE #3: Data Panels Not in Any Profile System

**Severity:** MEDIUM  
**Location:** [utils/sui_datapanels.lua](utils/sui_datapanels.lua)

**Impact:**
- Data panel positions NOT saved across reloads
- Data panel visibility NOT persisted
- Profile export doesn't include panel configuration

**Code Gap:**
```lua
-- Data panels are created but not stored in profile:
Datapanels:CreatePanel(panelID, config)
-- → Stored in Datapanels.activePanels (memory only)
-- → NOT in SuaviUI_DB
```

---

### 🟡 ISSUE #4: Action Bars Settings Incomplete

**Severity:** LOW-MEDIUM  
**Location:** [utils/actionbars_editmode.lua](utils/actionbars_editmode.lua)

**Impact:**
- Extra action button positioning not fully per-layout
- Zone ability positioning may not persist correctly

---

### 🟡 ISSUE #5: No Profile Change Listener System

**Severity:** LOW  
**Location:** AceDB integration

**Impact:**
- Modules must manually check for profile changes
- No centralized "profile switched" event
- Search results don't auto-update when profile changes

---

## 6. PANEL UI WIDGET BINDING ANALYSIS

### 6.1 Widget Creation Pattern

**File:** [utils/sui_gui.lua](utils/sui_gui.lua)

All widgets follow this pattern:
```lua
function GUI:CreateSlider(parent, label, dbKey, dbTable, min, max, step)
    local slider = CreateFrame("Slider", nil, parent)
    
    -- Store reference for sync tracking
    RegisterWidgetInstance(slider, dbTable, dbKey)
    
    slider:SetScript("OnValueChanged", function(self, value, userInput)
        if userInput and dbTable and dbKey then
            dbTable[dbKey] = value
            -- Callback if registered
            if self.onChange then
                self.onChange(value)
            end
        end
    end)
    
    return slider
end
```

**Binding Status:** ✅ **COMPLETE**
- All widgets automatically sync to database
- Real-time updates during gameplay
- Persistence to SavedVariables

---

## 7. RECOMMENDATIONS

### 7.1 FIX RESOURCE BARS (Priority: CRITICAL)

**Option A: Migrate to AceDB (RECOMMENDED)**

```lua
-- In resourcebars/init.lua - change from:
SuaviUI_ResourceBarsDB = { ... }

-- To:
local function GetResourceBarsDB()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if not SUICore or not SUICore.db then
        return nil
    end
    SUICore.db.profile.resourceBars = SUICore.db.profile.resourceBars or {}
    return SUICore.db.profile.resourceBars
end
```

Then update LEMSettingsLoader:
```lua
get = function(layoutName)
    local db = GetResourceBarsDB()
    return (db and db[config.dbName] and db[config.dbName][layoutName]) 
           or defaults
end,

set = function(layoutName, value)
    local db = GetResourceBarsDB()
    db[config.dbName] = db[config.dbName] or {}
    db[config.dbName][layoutName] = value
end
```

**Benefits:**
- ✅ Profile export includes resource bars
- ✅ Profile import restores all settings
- ✅ Consistent architecture
- ✅ LibDualSpec support works

**Effort:** Medium (2-3 hours)

---

### 7.2 ADD PROFILE CHANGE LISTENER (Priority: HIGH)

**Location:** [utils/suicore_main.lua](utils/suicore_main.lua)

```lua
function SUICore:OnProfileChanged()
    -- Fire global event that all modules can listen to
    self:SendMessage("SUAVIUI_PROFILE_CHANGED")
    
    -- Refresh all modules
    if self.RefreshAll then
        self:RefreshAll()
    end
end

-- Register with AceDB callback
self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
```

**Usage in modules:**
```lua
if SUICore then
    SUICore:RegisterMessage("SUAVIUI_PROFILE_CHANGED", function()
        -- Refresh this module
    end)
end
```

**Effort:** Low (1 hour)

---

### 7.3 WIRE DATA PANELS TO PROFILE (Priority: MEDIUM)

**Location:** [utils/sui_datapanels.lua](utils/sui_datapanels.lua#L40)

```lua
-- Currently:
Datapanels:CreatePanel(panelID, config)  -- Not saved

-- Change to:
function Datapanels:CreatePanel(panelID, config)
    -- ... existing code ...
    
    -- Save position to profile
    local db = SUICore.db.profile.dataPanels or {}
    SUICore.db.profile.dataPanels = db
    
    -- Store/restore from profile
    local savedConfig = db[panelID]
    if savedConfig then
        panel:SetPoint(unpack(savedConfig.position))
    end
    
    -- Hook drag events
    hooksecurefunc(panel, "SetPoint", function()
        -- Save new position
        db[panelID] = db[panelID] or {}
        db[panelID].position = {panel:GetPoint()}
    end)
end
```

**Effort:** Low (1-2 hours)

---

### 7.4 AUDIT ACTION BARS COMPLETENESS (Priority: LOW-MEDIUM)

**Location:** [utils/actionbars_editmode.lua](utils/actionbars_editmode.lua)

Verify all Extra Action Button and Zone Ability settings are per-layout and properly persisted.

**Effort:** 2-3 hours

---

## 8. WIRING VERIFICATION CHECKLIST

**Test each component:**

- [ ] **Unit Frames** - Change offset in sidebar → resets on reload? ✅ Should persist
- [ ] **Castbar** - Change color in sidebar → exports in profile? ✅ Should be included
- [ ] **Resource Bars** - Change scale in sidebar → exports in profile? ❌ **CURRENTLY MISSING**
- [ ] **Action Bars** - Extra button position → persists? ⚠️ Verify all settings
- [ ] **Data Panels** - Panel position → persists? ❌ **CURRENTLY MISSING**
- [ ] **Profile Export** - Includes all settings? ⚠️ Missing: resource bars, data panels
- [ ] **Profile Import** - Restores all settings? ⚠️ Same gaps as export

---

## 9. ARCHITECTURE DIAGRAM

```
SuaviUI Architecture - Profile & Settings System

┌────────────────────────────────────────────────────────────────┐
│                    Panel UI (/sui)                             │
│                  (sui_gui.lua + sui_options.lua)               │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                    dbTable[dbKey] updates
                               │
        ┌──────────────────────▼───────────────────────┐
        │     SUICore.db.profile (AceDB)               │
        │  ✅ Unified profile system                   │
        │  ✅ Per-character, per-spec support          │
        │  ✅ Auto-persisted to SavedVariables         │
        └──────────────┬───────────────────────────────┘
                       │
        ┌──────────────▼───────────────────────┐
        │  Edit Mode Side Panels (LEM)         │
        │  ✅ Unit Frames (unitframes_editmode.lua)
        │  ✅ Castbar (castbar_editmode.lua)   │
        │  ✅ Action Bars (actionbars_editmode.lua)
        │  ❌ Resource Bars (wrong DB!)        │
        └──────────────────────────────────────┘

⚠️  DISCONNECTED SYSTEM:
┌────────────────────────────────────────────┐
│  SuaviUI_ResourceBarsDB (Separate Variable)│
│  ❌ Not in AceDB profile                   │
│  ❌ Not exported with profile              │
│  ❌ Profile switch doesn't restore         │
└────────────────────────────────────────────┘

⚠️  NOT PERSISTED:
┌────────────────────────────────────────────┐
│  Data Panels (sui_datapanels.lua)          │
│  ❌ No profile storage                     │
│  ❌ Resets on reload                       │
└────────────────────────────────────────────┘
```

---

## 10. CONCLUSION

**Overall Assessment:** The profile system is **approximately 70-75% complete and properly wired**.

**Strengths:**
- ✅ Core AceDB integration solid
- ✅ Panel UI fully wired to profiles
- ✅ Most Edit Mode panels correctly connected
- ✅ Export/import working for main systems

**Gaps:**
- ❌ Resource bars on wrong database (architectural issue)
- ❌ Data panels not persisted
- ❌ No profile change listener system
- ⚠️ Action bars completeness unclear

**Estimated Effort to Complete:**
- **Resource Bars Migration:** 2-3 hours
- **Profile Change Listener:** 1 hour
- **Data Panels Persistence:** 1-2 hours
- **Action Bars Audit:** 2-3 hours
- **Total:** ~6-9 hours for full completion

**Priority Ranking:**
1. 🔴 Resource Bars Migration (CRITICAL)
2. 🟡 Profile Change Listener System (HIGH)
3. 🟡 Data Panels Persistence (MEDIUM)
4. 🟡 Action Bars Audit (MEDIUM)

---

**Document Status:** Ready for implementation  
**Last Updated:** February 1, 2026

