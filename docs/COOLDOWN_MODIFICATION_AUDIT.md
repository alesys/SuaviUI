# Cooldown Manager Modification Audit

## Executive Summary

SuaviUI modifies Blizzard's cooldown viewers (EssentialCooldownViewer, UtilityCooldownViewer) in **multiple places** with **different systems** that can conflict with each other and with Blizzard's native behavior.

**The Fighting Issue:** Multiple systems trying to control the same properties:
1. **sui_ncdm.lua** - Legacy per-row layout system
2. **cooldownmanager.lua** - New centering/alignment system
3. **Blizzard's RefreshLayout()** - Native viewer updates

---

## System 1: NCDM (New Cooldown Display Manager)
**File:** `utils/sui_ncdm.lua`

### What It Modifies
- **Icon dimensions** via `SetSize()` per-row settings
- **Icon positioning** via `SetPoint("CENTER")` with calculated X/Y offsets
- **Viewer size** via `SetSize(maxRowWidth, totalHeight)`
- **Layout direction** (HORIZONTAL/VERTICAL) from settings

### How It Works
```lua
-- Applies per-row configuration
function LayoutViewer(viewerName, trackerKey)
    -- For each row (row1, row2, row3):
    --   - Get iconCount, iconSize, padding, etc.
    --   - Position icons using CENTER anchor
    --   - Resize viewer to fit all rows
    
    -- Example for row 1:
    icon:SetSize(width, height)  -- Based on iconSize + aspectRatio
    icon:SetPoint("CENTER", viewer, "CENTER", x, y)
    
    -- Resize viewer:
    viewer:SetSize(maxRowWidth, totalHeight)
end
```

### When It Runs
- **OnUpdate hook** (every frame!) checking for settings changes
- **After Blizzard's RefreshLayout()** via hooksecurefunc
- **On settings changes** from options panel

### Default Settings
```lua
ncdm = {
    essential = {
        enabled = true,
        layoutDirection = "HORIZONTAL",  -- THIS IS THE ISSUE!
        row1 = { iconCount = 8, iconSize = 39, ... }
        row2 = { iconCount = 6, iconSize = 39, ... }
        row3 = { iconCount = 6, iconSize = 39, ... }
    },
    utility = {
        enabled = true,
        layoutDirection = "HORIZONTAL",  -- THIS TOO!
        row1 = { iconCount = 6, iconSize = 42, ... }
        ...
    }
}
```

**Problem:** NCDM doesn't respect Blizzard's `isHorizontal` flag - it forces its own layout based on `layoutDirection` setting.

---

## System 2: Cooldown Manager (CMC Port)
**File:** `utils/cooldownmanager.lua`

### What It Modifies
- **Icon positioning** via centering algorithm
- **Growth direction** (TOP/BOTTOM for rows, START/CENTER/END for columns)
- **Square icon styling** via StyledIcons module
- **Font customization** via CooldownFonts module

### How It Works
```lua
function ViewerAdapters.CenterAllRows(viewer, fromDirection)
    -- Read Blizzard's isHorizontal flag
    local isHorizontal = viewer.isHorizontal ~= false
    
    -- Group icons into rows
    local rows = LayoutEngine.BuildRows(iconLimit, children)
    
    -- Position each row with centered offsets
    if isHorizontal then
        -- Rows stack vertically (TOP or BOTTOM)
        PositionRowHorizontal(viewer, row, yOffset, ...)
    else
        -- Rows stack horizontally (LEFT or RIGHT)
        PositionRowVertical(viewer, row, xOffset, ...)
    end
end
```

### When It Runs
- **On Blizzard's RefreshLayout()** via hooksecurefunc
- **On aura changes** (UNIT_AURA events)
- **On settings changes** from Edit Mode
- **After NCDM layout** (if NCDM is enabled)

### Interaction with NCDM
**Cooldownmanager.lua reads Blizzard's `isHorizontal`**, but **NCDM overwrites viewer size** which triggers Blizzard's `OnSizeChanged` which calls `RefreshLayout()` which triggers cooldownmanager again → **FIGHT!**

---

## The Fighting Sequence

1. **User sets Essential to VERTICAL in Edit Mode**
   - Blizzard sets `EssentialCooldownViewer.isHorizontal = false`
   - Blizzard calls `RefreshLayout()`

2. **NCDM's OnUpdate hook runs**
   - Reads `settings.layoutDirection = "HORIZONTAL"` (from defaults!)
   - Ignores `isHorizontal` flag
   - Resizes viewer to horizontal dimensions
   - `viewer:SetSize(maxRowWidth, totalHeight)` triggers `OnSizeChanged`

3. **Blizzard's OnSizeChanged fires**
   - Calls `RefreshLayout()`
   - Blizzard sees `isHorizontal = false` (still VERTICAL)
   - Tries to layout vertically

4. **Cooldownmanager.lua runs**
   - Reads `isHorizontal = false`
   - Centers icons vertically
   - But NCDM already positioned them horizontally!

5. **NCDM runs again** (triggered by RefreshLayout)
   - Re-applies horizontal layout
   - Viewer flips back to horizontal

6. **Loop continues...**

---

## The Size Fighting Issue

**Symptoms:** Viewers resize for a few seconds then settle

**Root Cause:** Size oscillation between systems:

```lua
// NCDM calculates size based on row settings:
maxRowWidth = 320px (8 icons × 40px)
totalHeight = 42px (1 row)
viewer:SetSize(320, 42)  → Triggers OnSizeChanged

// Blizzard's OnSizeChanged:
RefreshLayout() → Re-positions icons

// Cooldownmanager.lua runs:
// Reads new positions, applies centering
// May adjust viewer size based on actual icon positions

// NCDM detects size change:
if needsResize then
    viewer:SetSize(maxRowWidth, totalHeight)  → Triggers again!
end
```

**Oscillation Prevention:**
NCDM has `__cdmLayoutSuppressed` flag to prevent recursion, but it only prevents **same-frame** recursion, not **cross-system** fights.

```lua
-- In sui_ncdm.lua line 899:
if needsResize then
    viewer.__cdmLayoutSuppressed = (viewer.__cdmLayoutSuppressed or 0) + 1
    viewer:SetSize(maxRowWidth, totalHeight)
    viewer.__cdmLayoutSuppressed = viewer.__cdmLayoutSuppressed - 1
end
```

This only prevents NCDM from calling itself during `SetSize`, but doesn't prevent cooldownmanager.lua from running after.

---

## Reset to Defaults Issue

**Problem:** `ResetProfile()` uses AceDB's built-in reset which resets **profile data**, but:

1. **EditMode settings are NOT in profile** - they're stored in Blizzard's `Edit_Layouts` CVar
2. **LibEQOLEditMode-1.0 settings** are stored separately
3. **Some frame positions** are saved in frame-specific saved variables

**What Gets Reset:**
```lua
-- ✅ Gets reset (in SuaviUI.db.profile):
ncdm.*
viewers.*
unitFrames.*
actionBars.*
general.*
powerBar.*

-- ❌ Does NOT get reset:
Edit_Layouts CVar (Blizzard EditMode)
LibEQOLEditMode-1.0 frame positions
Frame-specific __cdm* properties on runtime frames
```

**Solution Needed:**
Add a comprehensive reset function that clears:
- Profile data (current behavior)
- Edit Mode layouts via CVar
- LibEQOL frame registrations
- Runtime frame properties

---

## Recommendations

### 1. Unify the Systems (Choose One)

**Option A:** Disable NCDM, use only Cooldownmanager.lua
- Remove/disable sui_ncdm.lua
- Move all settings to Edit Mode
- Simpler architecture, less conflicts

**Option B:** Disable Cooldownmanager, use only NCDM
- Remove cooldownmanager.lua
- Make NCDM respect Blizzard's `isHorizontal` flag
- Sync `layoutDirection` with Edit Mode

**Option C:** Make them cooperate
- NCDM handles icon styling/sizing ONLY
- Cooldownmanager handles positioning ONLY
- Clear ownership boundaries

### 2. Fix NCDM to Respect isHorizontal

```lua
-- In sui_ncdm.lua, replace:
local settings = GetTrackerSettings(trackerKey)
local isVertical = settings.layoutDirection == "VERTICAL"

-- With:
local blizzHorizontal = viewer.isHorizontal ~= false
local isVertical = not blizzHorizontal
```

### 3. Add Proper Reset Function

```lua
function SUICore:ResetProfileCompletely()
    -- Reset profile data
    self.db:ResetProfile()
    
    -- Clear Edit Mode layouts
    SetCVar("Edit_Layouts", "")
    
    -- Clear LibEQOL registrations
    if _G.LibStub then
        local LEM = LibStub("LibEQOLEditMode-1.0", true)
        if LEM then
            LEM:UnregisterAllFrames()
        end
    end
    
    -- Clear runtime properties
    local viewers = {
        _G.EssentialCooldownViewer,
        _G.UtilityCooldownViewer,
    }
    for _, viewer in ipairs(viewers) do
        if viewer then
            -- Clear all __cdm* properties
            for k in pairs(viewer) do
                if string.match(k, "^__cdm") then
                    viewer[k] = nil
                end
            end
        end
    end
    
    ReloadUI()
end
```

### 4. Prevent Size Oscillation

Add cross-system coordination:

```lua
-- Global flag to prevent cascading layouts
_G.SuaviUI_LayoutInProgress = _G.SuaviUI_LayoutInProgress or {}

function LayoutViewer(viewerName, trackerKey)
    if _G.SuaviUI_LayoutInProgress[viewerName] then
        return  -- Another system is already laying out
    end
    
    _G.SuaviUI_LayoutInProgress[viewerName] = true
    
    -- Do layout work...
    
    C_Timer.After(0.1, function()
        _G.SuaviUI_LayoutInProgress[viewerName] = nil
    end)
end
```

---

## Current State Assessment

**Severity:** HIGH
- Multiple systems fighting for control
- Orientation constantly flipping
- Size changes oscillating
- Reset doesn't actually reset everything

**Impact:**
- Confusing UX (settings don't stick)
- Performance (constant re-layouts)
- Bugs (positions jumping around)

**Immediate Actions:**
1. Document which system should be primary
2. Disable the secondary system OR make them cooperate
3. Fix Reset to actually reset
4. Add oscillation prevention
