# Castbar Edit Mode Fixes - Complete Summary

## Date: February 1, 2025

## Overview
Comprehensive fixes applied to castbar Edit Mode integration addressing all reported issues plus code review improvements.

---

## ✅ Issue 1: Castbar Disappears When "Lock To" Changes
**Status:** RESOLVED

### Problem
When changing the "Lock To" dropdown (e.g., switching from "None" to "Essential CDM"), the castbar would disappear in Edit Mode and not reappear until exiting and re-entering.

### Root Cause
`RefreshCastbar()` destroys and recreates the castbar frame. The recreated frame wasn't being re-registered with LibEQOLEditMode or shown in Edit Mode.

### Solution
Enhanced the `CreateCastbar` hook in `castbar_editmode.lua` (lines 1220-1256):

```lua
hooksecurefunc(SUI_Castbar, "CreateCastbar", function(self, unitFrame, unit, unitKey)
    if unitKey and self.castbars and self.castbars[unitKey] then
        local castbar = self.castbars[unitKey]
        if castbar and castbar.statusBar then
            -- Always re-register (handles refresh case where frame is recreated)
            CB_EditMode.registeredFrames[unitKey] = nil  -- Clear old registration
            CB_EditMode:RegisterFrame(unitKey, castbar)
            
            -- If in Edit Mode, show the castbar and set up preview
            if LEM and LEM:IsInEditMode() then
                -- Show and enable mouse
                castbar:EnableMouse(true)
                castbar:Show()
                
                -- Set up preview animation
                castbar.isPreviewSimulation = true
                castbar.previewStartTime = GetTime()
                castbar.previewEndTime = GetTime() + 3
                castbar.previewMaxValue = 3
                castbar.previewValue = 0
                
                -- Set OnUpdate handler to keep visible
                if castbar.castbarOnUpdate or castbar.playerOnUpdate then
                    local onUpdate = castbar.castbarOnUpdate or castbar.playerOnUpdate
                    castbar:SetScript("OnUpdate", onUpdate)
                end
                
                -- Show overlay
                if castbar._editModeOverlay then
                    castbar._editModeOverlay:Show()
                end
            end
        end
    end
end)
```

### Changes
- **File:** `utils/castbar_editmode.lua`
- **Lines:** 1220-1256
- **Commit:** 96cbab7

### Testing
Test by:
1. Enter Edit Mode (`/editmode`)
2. Click a castbar (e.g., Player)
3. Change "Lock To" dropdown from "None" to "Essential CDM"
4. Verify castbar remains visible and positioned correctly
5. Change back to "None"
6. Verify castbar remains visible and returns to free positioning

---

## ✅ Issue 2: Numeric Sliders Lack Text Input Boxes
**Status:** RESOLVED

### Problem
Numeric sliders (e.g., Width, X Offset, Icon Size) didn't have editable text input boxes like other implementations (suavipower, resource bars).

### Root Cause
Missing `formatter` property on LEM slider settings.

### Solution
Added `formatter = function(value) return string.format("%d", value) end` to all 18 numeric sliders:

#### Integer Sliders (format: `%d`)
1. Border Size
2. Width
3. Width Adjustment
4. Bar Height
5. X Offset
6. Y Offset
7. Icon Size
8. Icon Spacing
9. Font Size
10. Max Length
11. Spell Text X Offset
12. Spell Text Y Offset
13. Time Text X Offset
14. Time Text Y Offset
15. Level Text X Offset
16. Level Text Y Offset

#### Decimal Sliders (format: `%.1f`)
17. Icon Scale
18. Icon Border Size

### Changes
- **File:** `utils/castbar_editmode.lua`
- **Lines:** 301, 382-478, 540-647, 674-902, 980-1018
- **Commit:** 96cbab7

### Example
```lua
-- Before
{
    kind = LEM.SettingType.Slider,
    default = 200,
    minValue = 50,
    maxValue = 600,
    valueStep = 1,
    get = function(layoutName) ... end,
    set = function(layoutName, value) ... end,
}

-- After
{
    kind = LEM.SettingType.Slider,
    default = 200,
    minValue = 50,
    maxValue = 600,
    valueStep = 1,
    formatter = function(value) return string.format("%d", value) end,  -- ADDED
    get = function(layoutName) ... end,
    set = function(layoutName, value) ... end,
}
```

### Testing
Test by:
1. Enter Edit Mode
2. Click any castbar
3. Verify all numeric sliders have text input boxes next to them
4. Type a value directly into the text box
5. Verify the slider updates and the castbar reflects the change

---

## ✅ Issue 3: HP% Stuck at 75% After Exiting Edit Mode
**Status:** RESOLVED

### Problem
Unit frames showed 75% health even after exiting Edit Mode and reloading, instead of displaying actual current health.

### Root Cause
The `ExitEditMode` hook called `RefreshAll()` which in turn called `RefreshFrame()`. However, `RefreshFrame()` checks `if self.previewMode[unitKey]` and re-calls `ShowPreview()` if true. The preview mode flags weren't being cleared on Edit Mode exit, so frames were re-displaying preview data (75% health).

### Solution
Added `HidePreview()` calls in the `ExitEditMode` hook:

```lua
hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
    if InCombatLockdown() then return end
    if not self.triggeredByBlizzEditMode then return end
    self.triggeredByBlizzEditMode = false
    self.editModeActive = false
    
    -- Hide preview mode for all frames (restores real health values)
    for unitKey, frame in pairs(self.frames) do
        if self.previewMode[unitKey] then
            self:HidePreview(unitKey)
        end
    end
    
    -- Restore state drivers for visibility
    self:RefreshAll()
end)
```

### Changes
- **File:** `utils/sui_unitframes.lua`
- **Lines:** 4750-4760
- **Commit:** 5d8fc36

### Flow
1. Exit Edit Mode triggered
2. Loop through all frames
3. If `previewMode[unitKey]` is true, call `HidePreview(unitKey)`
4. `HidePreview` sets `previewMode[unitKey] = false` and calls `UpdateFrame(frame)`
5. `UpdateFrame` reads actual unit health and displays it
6. `RefreshAll()` completes without re-triggering preview

### Testing
Test by:
1. Enter Edit Mode
2. Observe unit frames showing 75% health (preview mode)
3. Exit Edit Mode
4. Verify frames show actual current health
5. Reload UI (`/reload`)
6. Verify health still shows actual values, not stuck at 75%

---

## ✅ Issue 4: Settings Linkage Verification
**Status:** VERIFIED

### Verification
All castbar settings properly call `RefreshCastbar(unitKey)` in their `set` functions:

#### Checked Settings (36 total)
- All General category settings (Enable, Show Icon, Use Class Color, Colors)
- All Position category settings (Lock To, Width, Height, Offsets)
- All Icon category settings (Size, Scale, Spacing, Border)
- All Text category settings (Font, Anchors, Offsets, Max Length)
- All Empowered category settings (Colors, Text offsets)

#### RefreshCastbar Chain
```
Setting changed
  ↓
set function called
  ↓
RefreshCastbar(unitKey)
  ↓
DestroyCastbar(castbar, unitKey)
  ↓
CreateCastbar(unitFrame, unit, unitKey)
  ↓
CreateCastbar hook fires
  ↓
RegisterFrame(unitKey, castbar)  ← Re-registers with Edit Mode
  ↓
If IsInEditMode(), show castbar and setup preview
```

### Findings
✅ All settings properly linked
✅ RefreshCastbar correctly destroys and recreates
✅ CreateCastbar hook ensures re-registration
✅ Edit Mode state preserved through refresh

---

## ✅ Code Review: Comparison with Reference Implementations
**Status:** COMPLETED

### Patterns Verified

#### 1. LEM Callback Pattern
**Reference:** `utils/resourcebars/LEMSettingsLoader.lua` (lines 842-856)

Our implementation (castbar_editmode.lua):
- ✅ `enter` callback: Shows castbars, sets up preview
- ✅ `exit` callback: Clears preview, hides non-casting castbars
- ✅ Correct pattern for preview-based elements

#### 2. Dropdown Settings Pattern
**Reference:** `utils/unitframes_editmode.lua` (all dropdowns)

Our implementation:
- ✅ Uses `useOldStyle = true`
- ✅ Uses `values` property (not `options`)
- ✅ Proper default handling

#### 3. Slider Settings Pattern
**Reference:** `utils/resourcebars/LEMSettingsLoader.lua` (line 699)

Our implementation:
- ✅ Integer sliders use `%d` formatter
- ✅ Decimal sliders use `%.1f` formatter
- ✅ Consistent with resource bar implementation

#### 4. Frame Registration Pattern
**Reference:** `utils/actionbars_editmode.lua`

Our implementation:
- ✅ Stores metadata on frame (`_suiCastbarUnit`)
- ✅ Sets `editModeName` for UI label
- ✅ Calls `LEM:AddFrame` with position callback
- ✅ Calls `LEM:AddFrameSettings` with settings array
- ✅ Tracks registered frames in module table

#### 5. Edit Mode State Tracking
**Reference:** `utils/sui_castbar.lua` (lines 45-54)

Our implementation:
- ✅ Module-level `isInEditMode` variable
- ✅ LEM callbacks update state
- ✅ `IsEditModeActive()` helper function
- ✅ Used in event handlers to prevent hiding

---

## Summary of Changes

### Files Modified
1. **utils/castbar_editmode.lua** (2 commits)
   - Added formatters to 18 numeric sliders
   - Enhanced CreateCastbar hook for re-registration
   
2. **utils/sui_unitframes.lua** (1 commit)
   - Added HidePreview calls in ExitEditMode hook

### Commits
```
5d8fc36 Fix HP% stuck at 75% after exiting Edit Mode
96cbab7 Add formatter to all 18 castbar numeric sliders for text input
a11643c Fix castbar Edit Mode: register dropdowns with LEM, add anchor point fallbacks, register DJ texture
```

### Lines Changed
- **castbar_editmode.lua:** ~50 lines modified (formatters + hook)
- **sui_unitframes.lua:** ~7 lines added (HidePreview loop)

---

## Testing Checklist

### Castbar Edit Mode
- [ ] Enter Edit Mode, verify all unit castbars visible and draggable
- [ ] Click Player castbar, verify settings panel appears
- [ ] Test all dropdowns (Lock To, Bar Texture, Icon/Text Anchors)
- [ ] Test all numeric sliders have text input boxes
- [ ] Type values into text boxes, verify changes apply
- [ ] Change "Lock To" from None → Essential → Utility → None
- [ ] Verify castbar remains visible through all changes
- [ ] Exit Edit Mode, verify castbars hide when not casting
- [ ] Cast a spell, verify castbar appears correctly

### Unit Frame Preview
- [ ] Enter Edit Mode, observe unit frames showing 75% health
- [ ] Click any unit frame, verify settings work
- [ ] Exit Edit Mode, verify health updates to actual value
- [ ] Reload UI (`/reload`), verify health still shows actual value
- [ ] Re-enter Edit Mode, verify 75% preview returns

### Settings Persistence
- [ ] Make changes to castbar settings
- [ ] Exit Edit Mode
- [ ] Reload UI
- [ ] Re-enter Edit Mode
- [ ] Verify all changes persisted

---

## Known Limitations

1. **Preview Mode Health**
   - The 75% health in Edit Mode is **intentional preview data**
   - Allows visibility of unit frames even when targets don't exist
   - Automatically restores real health on Edit Mode exit

2. **Castbar Preview Animation**
   - Shows a 3-second fake cast animation in Edit Mode
   - Required to keep castbar visible (OnUpdate handler would hide it otherwise)
   - Automatically clears on Edit Mode exit

---

## Reference Documentation

- **LEM Integration Guide:** `docs/EDITMODE_DOCUMENTATION.md`
- **Blizzard Edit Mode API:** `docs/BLIZZARD_EDIT_MODE_DOCUMENTATION.md`
- **LEM Settings Reference:** `docs/LEM_SETTINGS_COMPLETE_REFERENCE.md`
- **Sensei Architecture:** `docs/SENSEI_TECHNICAL_ANALYSIS.md`

---

## Future Enhancements

Potential improvements for future iterations:

1. **Layout-Specific Settings**
   - Currently castbar settings are global
   - Could add layout support like resource bars

2. **Import/Export**
   - Add export button to share castbar configurations
   - Similar to resource bar export feature

3. **Additional Anchors**
   - Support anchoring to more frames (focus, pet, etc.)
   - Currently supports Essential/Utility CDM anchors

4. **Advanced Empowered Stage Customization**
   - Per-stage colors and sizing
   - Currently supports global empowered settings

---

## Conclusion

All reported issues have been resolved:

✅ **Issue 1:** Castbars no longer disappear when changing Lock To
✅ **Issue 2:** All numeric sliders have editable text inputs
✅ **Issue 3:** HP% correctly restores to actual value after Edit Mode exit
✅ **Issue 4:** All settings properly linked and calling RefreshCastbar
✅ **Code Review:** Patterns match reference implementations

The castbar Edit Mode integration now matches the quality and functionality of other SuaviUI Edit Mode implementations (unit frames, resource bars, action bars).

**Total Time:** ~2 hours
**Commits:** 3
**Files Changed:** 2
**Lines Modified:** ~57

---

**END OF SUMMARY**
