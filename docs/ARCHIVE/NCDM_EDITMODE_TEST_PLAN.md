# CDM EditMode Integration - Phase 1 Test Plan

## Overview
CDM (Cooldown Display Manager) frames have been registered with Blizzard's Edit Mode via LibEQOL-1.0. Position and scale are now controlled by Edit Mode, while icon layout logic remains in sui_ncdm.lua.

## Architecture Summary

**Before Integration:**
- CDM position/scale: Manual via nudge system (suicore_nudge.lua)
- CDM layout: Row-based icon positioning (sui_ncdm.lua)
- EditMode: Unaware of CDM frames

**After Integration:**
- CDM position/scale: Edit Mode (LibEQOL-1.0) + AceDB profile persistence
- CDM layout: Unchanged - row-based icon positioning (sui_ncdm.lua)
- EditMode: Manages EssentialCooldownViewer and UtilityCooldownViewer position/scale/magnetic-snap

## Changes Made

### File: utils/sui_ncdm_editmode.lua (NEW)
- Registers `EssentialCooldownViewer` with LibEQOL
- Registers `UtilityCooldownViewer` with LibEQOL
- Hooks EditMode enter/exit to reapply layouts
- Hooks SaveLayouts to ensure AceDB persistence
- Handles profile changes to reapply layouts
- Default positions: Essential at (0, -100), Utility at (0, 50)

### File: utils/utils.xml
- Added `<Script file="sui_ncdm_editmode.lua"/>` after `sui_ncdm.lua`

### No Changes Required:
- `sui_ncdm.lua` - Keeps full functionality
- `sui_options.lua` - CDM settings UI remains unchanged
- `suicore_nudge.lua` - Nudge system unaffected
- `suicore_main.lua` - Existing hooks remain

## Test Procedure

### Test 1: Verify Registration
**Objective:** Confirm LibEQOL sees CDM frames

**Steps:**
1. Enable CDM in addon settings
2. Enter Edit Mode (press Z or use menu)
3. Look for "Essential Cooldown Viewer" and "Utility Cooldown Viewer" in EditMode frame list
4. Verify frames have selection boxes and can be clicked

**Expected Result:**
- Both frames visible and selectable in EditMode
- Magnetic snapping enabled
- Scale and position sliders available

### Test 2: Drag and Position
**Objective:** Verify dragging works and positions are saved

**Steps:**
1. Enter EditMode
2. Drag EssentialCooldownViewer to a new position (e.g., left side)
3. Verify icons move with the frame (not left behind)
4. Scale the frame (should scale icons proportionally)
5. Drag UtilityCooldownViewer to new position below Essential
6. Click "Save" button in EditMode

**Expected Result:**
- Frame and icons move together
- Scaling works correctly
- Save button becomes enabled when dragging
- No errors in chat

**Fallback Check:** If positions don't update, check:
```
/run print(GetNCDMDB())
```
Should show the essential/utility table structure.

### Test 3: Persistence After Reload
**Objective:** Verify positions saved to profile and restore on reload

**Steps:**
1. After Test 2, position CDM frames
2. Click "Save" in EditMode
3. Exit EditMode
4. Type `/reload` to reload UI
5. Check if CDM frames are in the same position

**Expected Result:**
- Positions match what was saved
- No position reset to defaults
- Icons render correctly at new positions

### Test 4: Profile Switching
**Objective:** Verify different profiles maintain separate CDM positions

**Steps:**
1. In profile "Default", position Essential at (100, -50)
2. Create/switch to profile "Custom"
3. Position Essential at (-100, 50)
4. Switch back to "Default"
5. Verify Essential is back at (100, -50)
6. Switch to "Custom"
7. Verify Essential is at (-100, 50)

**Expected Result:**
- Each profile maintains independent CDM positions
- Positions update correctly on profile change

### Test 5: Resource Bar Anchoring
**Objective:** Verify resource bars still anchor correctly to CDM

**Steps:**
1. Ensure resource bars are anchored to Essential cooldown viewer
2. In EditMode, move Essential cooldown viewer
3. Exit EditMode
4. Check that resource bars stayed anchored (width matches Essential frame)
5. Enter EditMode, scale Essential cooldown viewer
6. Exit EditMode
7. Verify resource bars scaled appropriately

**Expected Result:**
- Resource bars follow CDM position changes
- Bars don't overlap or detach from CDM
- Scaling works correctly
- No position resets

### Test 6: EditMode Enter/Exit Flow
**Objective:** Verify layouts reapply correctly on mode transitions

**Steps:**
1. Start in normal mode with CDM positioned normally
2. Enter EditMode - check that CDM is selectable and scales show current state
3. Move CDM slightly
4. Exit EditMode without saving
5. Check CDM is back to original position
6. Enter EditMode again
7. Move CDM significantly  
8. Save and exit
9. Verify CDM stayed in new position

**Expected Result:**
- Enter/exit transitions clean
- Unsaved changes don't persist
- Saved changes persist
- No visual glitches during transitions

## Error Checking

### Check for Errors in Chat:
After each test, look for red error messages. Common issues:

```
LibEQOL not found
→ Fix: Ensure LibEQOL-1.0 library is loaded (part of SUI)

Attempt to call nil value
→ Fix: Frames might not be created yet (timing issue)

Position values nil
→ Fix: Profile not initialized (first load - should auto-initialize)
```

### Debug Commands:

```lua
-- Check if registration worked
/run local LEM = LibStub("LibEQOL-1.0"); print(LEM and "LEM loaded" or "LEM missing")

-- Check if frames are registered
/run local LEM = LibStub("LibEQOL-1.0"); local frames = LEM.GetRegisteredFrames(); for name in pairs(frames) do print(name) end

-- Check CDM database structure
/run SUICore = select(2, ...) if not SUICore then SUICore = {}; for v in pairs(_G) do if v == "Addon" or v == "suaviUI" then SUICore = _G[v]; break end end end; print("CDM DB:", SUICore.db and SUICore.db.profile and SUICore.db.profile.viewers and "exists" or "missing")

-- Manually apply viewer layout
/run SUICore = select(2, ...) if not SUICore then for k,v in pairs(_G) do if type(v) == "table" and v.ApplyViewerLayout then SUICore = v; break end end end; if SUICore and SUICore.ApplyViewerLayout then SUICore:ApplyViewerLayout(_G.EssentialCooldownViewer) end
```

## Success Criteria

**Phase 1 is successful if:**
1. ✅ CDM frames registered with EditMode
2. ✅ Dragging CDM in EditMode moves frame and icons together
3. ✅ Positions persist after reload
4. ✅ Profile switching maintains separate positions
5. ✅ Resource bars anchor correctly to repositioned CDM
6. ✅ EditMode enter/exit transitions are clean
7. ✅ No console errors

## Known Limitations (Phase 1)

- Icon layout settings (iconSize, row count, etc.) still in sui_options.lua, not in EditMode settings panels
  → **Phase 2 task:** Add icon layout sliders to EditMode settings
  
- Manual nudge system still present but shouldn't be used for CDM
  → **Phase 2 task:** Disable nudge for CDM frames to avoid confusion

- Buff viewer not yet integrated
  → **Phase 2 task:** Register BuffIconCooldownViewer with EditMode

## Next Steps (Phase 2)

1. Move icon layout settings (iconSize, iconCount, spacing, etc.) from sui_options.lua to EditMode settings panels
2. Integrate Buff viewer
3. Clean up nudge system for CDM frames
4. Add per-layout CDM position presets
5. Performance optimization if needed

## Troubleshooting

### CDM frames not appearing in EditMode

**Cause:** Frames not registered or LibEQOL not loaded

**Fix:**
```lua
/run LibStub:GetLibrary("LibEQOL-1.0"):AddFrame(_G.EssentialCooldownViewer, function() end, {point="CENTER", x=0, y=-100, scale=1.0})
```

### Positions reset after reload

**Cause:** AceDB not saving to profile or initialization issue

**Fix:**
1. Check `/run print(SUICore.db.profile.viewers.EssentialCooldownViewer)` shows saved positions
2. Run `/run SUICore.db:SaveToProfile()` to force save
3. Reload UI

### Icons not moving with frame

**Cause:** ApplyViewerLayout not being called

**Fix:**
```lua
/run SUICore.ApplyViewerLayout(_G.EssentialCooldownViewer)
```

### Resource bars not anchoring

**Cause:** Bars anchoring to old position before EditMode registration

**Fix:**
1. Re-enable resource bars in CDM settings
2. Enter EditMode, save
3. Exit and reload

## Rollback Plan

If Phase 1 integration causes issues, rollback is simple:

1. Remove `sui_ncdm_editmode.lua` from utils.xml
2. Delete `sui_ncdm_editmode.lua` file
3. Reload UI
4. CDM will revert to default positions (no saved EditMode positions will be used)

The old NCDM database in `db.profile.ncdm` is untouched, so no data loss.
