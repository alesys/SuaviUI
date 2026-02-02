# SuaviUI Settings Save System - How It Works

## Overview

SuaviUI uses **AceDB-3.0** (from the Ace3 library framework) to manage persistent settings storage. This is the same system used by thousands of WoW addons.

---

## Current Architecture

### 1. **Database Registration** (SuaviUI.toc)

```
## SavedVariables: SuaviUI_DB, SuaviUIDB
```

This declares two saved variable tables that WoW will automatically load/save to the player's SavedVariables file:
- `SuaviUI_DB` - Legacy name (for backwards compatibility)
- `SuaviUIDB` - Current primary database

### 2. **AceDB Initialization** (init.lua)

```lua
function SuaviUI:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SuaviUI_DB", self.defaults, "Default")
end
```

**Parameters:**
- `"SuaviUI_DB"` - SavedVariable name to load/save
- `self.defaults` - Default values if no saved data exists
- `"Default"` - Default profile name

### 3. **Main Database Setup** (suicore_main.lua)

```lua
function SUICore:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SuaviUIDB", defaults, true)
    SUI.db = self.db  -- Make accessible to other modules
end
```

**Structure:**
```
SuaviUIDB (SavedVariable)
├── profiles (auto-managed by AceDB)
│   ├── "Default"
│   └── "ProfileName"
│       ├── profile (user settings)
│       │   ├── general
│       │   ├── powerBar
│       │   ├── secondaryPowerBar
│       │   ├── castBar
│       │   ├── ncdm
│       │   └── ... (all other settings)
│       ├── char (per-character overrides - not used currently)
│       └── global (global settings - not used currently)
└── profileKeys (tracks which profile each character uses)
```

---

## How Settings Are Saved

### 1. **Automatic Saving**

AceDB automatically saves settings to disk whenever you modify them:

```lua
-- This automatically triggers save to disk
SUICore.db.profile.powerBar.enabled = true
SUICore.db.profile.powerBar.height = 12
```

**No explicit save() call needed** - AceDB handles it.

### 2. **Profile Structure**

All settings live under `db.profile` (the current active profile):

```lua
db.profile = {
    general = { ... },
    powerBar = { ... },
    secondaryPowerBar = { ... },
    powerColors = { ... },
    -- ... other settings
}
```

### 3. **Where Files Are Saved**

On Windows:
```
C:\Users\[YourUsername]\AppData\Local\Blizzard\World of Warcraft\_retail_\WTF\Account\[AccountName]\SavedVariables\SuaviUI.lua
```

The file contains:
```lua
SuaviUIDB = {
    ["Default"] = {
        ["profile"] = {
            ["general"] = { uiScale = 0.64, ... },
            ["powerBar"] = { enabled = true, height = 8, ... },
            -- ... all settings
        },
    },
}
```

---

## For the Tertiary Bar: What Needs to Happen

### 1. **Add to Defaults Table** (suicore_main.lua, ~line 960)

```lua
local defaults = {
    profile = {
        -- ... existing settings ...
        
        secondaryPowerBar = {
            -- ... existing secondaryPowerBar config ...
        },
        
        -- NEW: Add this
        tertiaryPowerBar = {
            enabled           = false,
            autoAttach        = false,
            standaloneMode    = false,
            attachTo          = "EssentialCooldownViewer",
            height            = 8,
            borderSize        = 1,
            offsetY           = 8,
            offsetX           = 0,
            width             = 326,
            useRawPixels      = true,
            texture           = "Suavi v5",
            colorMode         = "power",
            usePowerColor     = true,
            useClassColor     = false,
            customColor       = { 0.5, 0.8, 1, 1 },
            showPercent       = false,
            showText          = true,
            textSize          = 14,
            textX             = 0,
            textY             = 2,
            textUseClassColor = false,
            textCustomColor   = { 1, 1, 1, 1 },
            bgColor           = { 0.078, 0.078, 0.078, 0.83 },
            showTicks         = false,
            tickThickness     = 2,
            tickColor         = { 0, 0, 0, 1 },
            lockedToEssential = false,
            lockedToUtility   = false,
            lockedToSecondary = true,
            snapGap           = 5,
            orientation       = "HORIZONTAL",
        },
    }
}
```

### 2. **That's It!**

Once added to the defaults table:

✅ **Automatically saved to disk** when modified  
✅ **Automatically loaded** when addon starts  
✅ **Automatically migrates** for existing users (uses defaults if key missing)  
✅ **Profile-aware** (works with multiple character profiles)  
✅ **Export/Import compatible** (included in profile export strings)  

---

## Migration for Existing Users

When existing users load the addon with the new tertiary bar settings:

1. AceDB checks if `db.profile.tertiaryPowerBar` exists
2. If **NOT found** → Uses defaults from the `defaults` table
3. If **found** → Uses their saved values
4. User sees: Tertiary bar disabled by default (safe, non-breaking)

**No migration code needed** - AceDB handles this automatically!

---

## How Profile Switching Works

### Current System
```lua
-- User selects "MyProfile" in options
self.db:SetProfile("MyProfile")

-- Result: All reads/writes now target a different profile
self.db.profile.powerBar.enabled = true  -- Saves to MyProfile.profile.powerBar
```

### For Tertiary Bar
**Automatically included** - No special handling needed:

```lua
-- When switching profiles:
-- Profile 1 (Main): tertiaryPowerBar.enabled = false
-- Profile 2 (Alt): tertiaryPowerBar.enabled = true
-- 
-- Settings per profile are completely separate
```

---

## Import/Export System

### Export
```lua
local exported = SUICore:ExportProfileToString()
-- Returns: "SUI1:<compressed-serialized-profile>"
-- Includes ALL settings from db.profile, including tertiaryPowerBar
```

### Import
```lua
local ok, msg = SUICore:ImportProfileFromString(exportString)
-- Restores ALL profile settings including tertiaryPowerBar
```

**Tertiary bar settings are automatically included** - the export/import system serializes the entire `db.profile` table.

---

## Database Versioning & Migration Strategy

### Current Migration Pattern in SUICore

SuaviUI handles legacy settings migrations in `OnInitialize()`:

```lua
-- Example: Migrate old QUI prefix to SUI
if profile.quiUnitFrames and not profile.suiUnitFrames then
    profile.suiUnitFrames = profile.quiUnitFrames
    profile.quiUnitFrames = nil
end
```

### For Tertiary Bar: No Migration Needed

Since it's a new feature:
- Old users won't have `tertiaryPowerBar` in their saved data
- AceDB uses default value automatically
- No migration code required

---

## Testing the Save System

### Test 1: Basic Save/Load
```lua
-- Run in console (F12):
SUICore.db.profile.tertiaryPowerBar.height = 12
ReloadUI()
-- After reload, check: Should still be 12 (saved!)
```

### Test 2: Profile Switching
```lua
-- Create new profile "TestProfile"
SUICore.db:SetProfile("TestProfile")
SUICore.db.profile.tertiaryPowerBar.height = 20

-- Switch back to Default
SUICore.db:SetProfile("Default")
-- tertiaryPowerBar.height should be 8 again
```

### Test 3: Export/Import
```lua
local exported = SUICore:ExportProfileToString()
print(exported)  -- Should include tertiaryPowerBar data
```

---

## Important: No Manual Changes Needed to Save System

### What to DO:
✅ Add `tertiaryPowerBar` to `defaults` table  
✅ Read settings via `self.db.profile.tertiaryPowerBar`  
✅ Write settings via `self.db.profile.tertiaryPowerBar.xxx = value`  
✅ Everything else happens automatically  

### What NOT to do:
❌ Don't create custom save functions  
❌ Don't manually call `Save()` or `WriteSavedVariables()`  
❌ Don't modify the defaults outside initialization  
❌ Don't manually manage profile switching  

---

## Debugging Settings Issues

### View Current Saved Data
```lua
-- In-game console (F12):
print(SUICore.db.profile.tertiaryPowerBar)
```

### Reset to Defaults
```lua
-- Reset entire profile
SUICore.db:ResetProfile()
-- or just tertiaryPowerBar:
SUICore.db.profile.tertiaryPowerBar = CopyTable(defaults.profile.tertiaryPowerBar)
```

### View Raw SavedVariables File
```
C:\Users\[User]\AppData\Local\Blizzard\World of Warcraft\_retail_\WTF\Account\[Account]\SavedVariables\SuaviUI.lua
```

Edit directly (when WoW is closed):
```lua
SuaviUIDB = {
    ["Default"] = {
        ["profile"] = {
            ["tertiaryPowerBar"] = {
                ["enabled"] = false,
                -- ... modify values here
            },
        },
    },
}
```

---

## Summary: For Tertiary Bar Implementation

**Only 1 thing to do:**
1. Add `tertiaryPowerBar` table to `defaults.profile` in suicore_main.lua (~line 960)

**Everything else is automatic:**
- ✅ Saving to disk
- ✅ Loading from disk
- ✅ Profile switching
- ✅ Export/Import
- ✅ Migration (defaults for new users)
- ✅ Per-character storage (via profiles)

**That's it!** AceDB handles all persistence.

