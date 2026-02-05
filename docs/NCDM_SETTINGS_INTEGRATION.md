# NCDM Settings Panel Integration Analysis

## Question: What of NCDM is wired to the settings panel?

### Answer: Surprisingly Little - Only 2 Direct Calls + Database Initialization

---

## 1. Direct Integration Points

### A. RefreshCDM() Function (sui_options.lua line 11943-11950)

**Location**: [sui_options.lua](sui_options.lua#L11943-L11950)

```lua
local function RefreshCDM()
    if NCDM and NCDM.ApplySettings then
        NCDM:ApplySettings("essential")
        NCDM:ApplySettings("utility")
    end
    if _G.SuaviUI_RefreshBuffBar then
        _G.SuaviUI_RefreshBuffBar()
    end
end
```

**Calls**:
- `NCDM:ApplySettings("essential")` - Re-apply essential viewer settings
- `NCDM:ApplySettings("utility")` - Re-apply utility viewer settings

**Triggered by**: Currently **NOT CALLED FROM ANYWHERE** in sui_options.lua! (Dead code or legacy)

---

### B. Database Initialization (sui_options.lua lines 5810-5812)

**Location**: [sui_options.lua](sui_options.lua#L5810-L5812)

```lua
if not db.ncdm then db.ncdm = {} end
if not db.ncdm.trackedBar then db.ncdm.trackedBar = {} end
local trackedData = db.ncdm.trackedBar
```

**Purpose**: Ensures `db.ncdm.trackedBar` exists for tracked bar system

**Related**: Used in tracked bar functionality (separate system from cooldown viewers)

---

## 2. NCDM Settings Structure in Database

### Database Location
`SUICore.db.profile.ncdm`

### Structure
```lua
ncdm = {
    essential = {
        enabled = true/false,
        row1 = { iconCount, iconSize, padding, aspectRatioCrop, ... },
        row2 = { ... },
        row3 = { ... },
    },
    utility = {
        enabled = true/false,
        row1 = { ... },
        row2 = { ... },
        row3 = { ... },
    },
    buff = { ... },        -- Buff bar styling
    trackedBar = { ... },  -- Tracked bar settings
}
```

### Initialization
Happens in `suicore_main.lua` lines 662-960, NOT in options panel.

---

## 3. Current Options Panel Coverage

### What IS in Options (All CMC - CooldownManagerCentered)
- ✅ Square icons (per viewer: Essential, Utility, BuffIcons)
- ✅ Icon borders and zoom
- ✅ Utility dimming
- ✅ Cooldown fonts (name, size, flags)
- ✅ Stack number fonts and positioning
- ✅ Keybind fonts and positioning
- ✅ Cooldown swipe effects

**Location**: [sui_options.lua](sui_options.lua#L5229-L5678) CreateCooldownViewersPage()

### What is NOT in Options (All NCDM)
- ❌ Per-row icon count
- ❌ Per-row icon size
- ❌ Per-row padding
- ❌ Per-row aspect ratio (flat vs square)
- ❌ Per-row border customization
- ❌ Per-row text positioning
- ❌ Mouseover visibility control
- ❌ CDM enable/disable toggle
- ❌ Layout direction control

---

## 4. How Users Currently Configure NCDM

**Current Method: BACKUP OPTIONS FILE** 

The old NCDM configuration UI was in `sui_options_backup.lua` (old backup of full options before refactor):

**Location**: [sui_options_backup.lua](sui_options_backup.lua#L4868-L4925)

```lua
-- PAGE: CDM Setup (New Cooldown Display Manager - SUI NCDM)
-- Refresh callback for NCDM changes
local function RefreshNCDM()
    if _G.SuaviUI_RefreshNCDM then
        _G.SuaviUI_RefreshNCDM()
    end
end

-- Initialize NCDM defaults for existing profiles
local function EnsureNCDMDefaults(db)
    -- Ensure ncdm table exists
    if not db.ncdm then
        db.ncdm = {}
    end

    if not db.ncdm.essential then
        db.ncdm.essential = { enabled = true }
    end
    
    for i = 1, 3 do
        local rowKey = "row" .. i
        if not db.ncdm.essential[rowKey] then
            db.ncdm.essential[rowKey] = {}
            -- ... copy defaults ...
        end
    end
    -- ... (similar for utility) ...
end
```

**Status**: This UI code is **DISABLED/REMOVED** from active options panel.

---

## 5. Global Refresh Functions Exported by NCDM

**Location**: [sui_ncdm.lua](sui_ncdm.lua#L1355-L1356)

```lua
_G.SuaviUI_RefreshNCDM = RefreshAll
_G.SuaviUI_IncrementNCDMVersion = IncrementSettingsVersion
```

**Available to Options Panel**:
- `_G.SuaviUI_RefreshNCDM()` - Force re-layout of all viewers
- `_G.SuaviUI_IncrementNCDMVersion()` - Signal settings changed

**Currently Called From**: 
- suicore_main.lua line 3523 (profile switching)
- NOWHERE ELSE (dead code in sui_options.lua)

---

## 6. Integration with Keybinds System

**Location**: [keybinds.lua](keybinds.lua#L1132)

```lua
-- Export for NCDM integration (allows LayoutViewer to trigger keybind updates)
```

NCDM can call this to update keybinds when layout changes.

---

## 7. Integration with Unitframes

**Location**: [sui_unitframes.lua](sui_unitframes.lua#L5081-L5096)

```lua
-- Global callback for NCDM to update castbar anchored to Essential
-- Global callback for NCDM to update castbar anchored to Utility
```

NCDM communicates with unitframes for castbar positioning.

---

## 8. Options Panel Call Chain

### Current Active Flow (ONLY CooldownManagerCentered)

1. User changes **Cooldown Viewers** page settings
2. `CreateCooldownViewersPage()` called (sui_options.lua line 5231)
3. Callbacks trigger:
   - `RefreshIcons()` → calls `SUI.CooldownManager.ForceRefreshAll()`
   - Directly calls `viewer.RefreshLayout()` on all viewers
   - `SUI.CooldownFonts.RefreshAllFonts()`

### **MISSING** Flow (NCDM)

1. User would change row settings, border, text positioning, etc. (in old backup UI)
2. `RefreshNCDM()` would be called
3. `NCDM:ApplySettings()` would re-layout everything
4. `_G.SuaviUI_RefreshNCDM()` would sync with keybinds/unitframes

**Status**: This entire flow is DISABLED - no UI to change NCDM settings.

---

## Integration Strategy Recommendations

### Option C (Recommended): Make Them Cooperate

For clean integration without duplication, suggest:

#### Approach 1: Minimal Integration (Clean Boundary)
```
┌─────────────────────────────────────────────────┐
│         Options Panel Settings                   │
├─────────────────────────────────────────────────┤
│                                                   │
│  ┌──────────────────┐    ┌──────────────────┐   │
│  │  CMC Settings    │    │  NCDM Settings   │   │
│  │  (Modern/New)    │    │  (Legacy/Icon    │   │
│  │                  │    │   styling)       │   │
│  │ • Square icons   │    │                  │   │
│  │ • Borders        │    │ • Row configs    │   │
│  │ • Fonts          │    │ • Text position  │   │
│  │ • Dimming        │    │ • Mouseover      │   │
│  │ • Swipe colors   │    │ • Visibility     │   │
│  └──────────────────┘    └──────────────────┘   │
│                                                   │
├─────────────────────────────────────────────────┤
│  Unified Refresh Trigger (CRITICAL)              │
│  - Called when EITHER system changes             │
│  - Coordinates layout without fighting          │
├─────────────────────────────────────────────────┤
│  Layout Managers                                 │
│  ┌──────────────────────────────────────────┐   │
│  │  NCDM: Icon styling, sizing, text        │   │
│  └──────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────┐   │
│  │  CMC: Centering, alignment, placement    │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

#### Approach 2: NCDM as "Storage + Executor" Only
- NCDM reads row settings from database
- CMC does the actual layout math
- NCDM applies styling (borders, text, fonts)
- Single unified refresh trigger coordinates both
- **Maintainability**: Very High
- **Complexity**: Medium

#### Approach 3: CMC Config Extends to NCDM Features
- Absorb NCDM settings into CMC options panel
- Store in unified location (not split ncdm/cooldownManager)
- Single refresh path
- **Maintainability**: Highest
- **Complexity**: High (substantial refactor)

---

## Assessment: Best Integration Approach

### For **Maintainability** (HIGHEST PRIORITY):

**Best**: Unified Refresh Trigger + Clear Ownership Boundaries

```lua
-- In cooldownmanager.lua or new coordinator module
local CoordinatedRefresh = {
    debounceTimer = nil,
    debounceInterval = 0.05,  -- 50ms debounce
}

function CoordinatedRefresh.RequestRefresh(source)
    -- Cancel existing timer
    if CoordinatedRefresh.debounceTimer then
        CoordinatedRefresh.debounceTimer:Cancel()
    end
    
    -- Debounce: wait for other systems to settle
    CoordinatedRefresh.debounceTimer = C_Timer.After(CoordinatedRefresh.debounceInterval, function()
        -- NCDM applies its styling first
        if NCDM and NCDM.Refresh then
            NCDM:Refresh()
        end
        
        -- Then CMC centers everything
        if SUI.CooldownManager and SUI.CooldownManager.ForceRefreshAll then
            SUI.CooldownManager:ForceRefreshAll()
        end
        
        -- Finally sync with dependent systems
        if _G.SuaviUI_UpdateUnitframes then
            _G.SuaviUI_UpdateUnitframes()
        end
    end)
end

-- Both systems call this instead of refreshing independently
```

### Ownership Boundaries:

| Component | Owner | Can Change | Cannot Change |
|-----------|-------|-----------|-----------------|
| Icon dimensions | NCDM | Size based on row config | Layout placement |
| Borders & styling | NCDM | Color, thickness, zoom | Icon position |
| Text positioning | NCDM | Font, size, offset | Row alignment |
| Layout placement | CMC | Centering, alignment | Icon styling |
| Direction/orientation | CMC | Respects `isHorizontal` | Row count |

### Files Affected:

**No changes needed** to existing code - just add a new coordinator:
- `utils/cooldown_coordinator.lua` (NEW - ~50 lines)
- Call `CoordinatedRefresh.RequestRefresh()` from both systems
- Update options panel to call coordinator instead of individual refreshes

---

## Summary for Option C Integration

### Question: "What would mean to do an integration?"

**Answer**: 
1. **Add a debounced refresh coordinator** (~50 lines, new file)
2. **Clear ownership boundaries** (NCDM = styling/sizing, CMC = layout/placement)
3. **Single unified refresh trigger** called from options panel & both systems
4. **No major rewrites** - both systems keep existing code, just coordinate

### Why This Works Best:

✅ **Maintainability**: No duplicate logic, clear boundaries
✅ **Stability**: Existing code unchanged, minimal risk
✅ **Performance**: Debouncing prevents oscillation
✅ **Extensibility**: Easy to add new systems later
✅ **Outcome**: Best features of both systems working together

### Implementation Effort:

- **Easy**: 30 minutes (coordinator + options updates)
- **Risk**: Low (additive, no deletions)
- **Testing**: Moderate (verify no fighting, no missing features)
