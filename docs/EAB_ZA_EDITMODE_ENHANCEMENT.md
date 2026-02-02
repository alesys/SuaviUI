# ExtraActionButton & ZoneAbility Edit Mode Enhancement

## Problem Statement

1. **ExtraAbilityContainer Clutter**: Blizzard's default `ExtraAbilityContainer` frame was appearing in Edit Mode, but it was empty/useless since SuaviUI manages these buttons separately in holder frames.

2. **Incomplete Edit Mode Integration**: While EAB/ZA were registered with Edit Mode, they lacked the full feature set of modern implementations (castbars, unitframes):
   - No drag predicates (couldn't drag when disabled)
   - No reset button visibility control
   - No visual overlay feedback
   - Dragging was always allowed, even when customization was disabled

## Solution Implemented

### 1. Hide ExtraAbilityContainer in Edit Mode
- **File**: [actionbars_editmode.lua](../utils/actionbars_editmode.lua)
- **Change**: Updated `Initialize()` LEM callbacks
  - On Edit Mode `enter`: Hide `ExtraAbilityContainer` (prevents clutter)
  - On Edit Mode `exit`: Show `ExtraAbilityContainer` (restore normal state)

### 2. Add Drag Predicates
- **File**: [actionbars_editmode.lua](../utils/actionbars_editmode.lua#L333)
- **Change**: Added `LEM:SetFrameDragEnabled()` in `RegisterFrame()`
  ```lua
  LEM:SetFrameDragEnabled(holderFrame, function(layoutName)
      local st = GetButtonSettings(buttonType)
      return st and st.enabled or false
  end)
  ```
- **Effect**: Dragging only allowed when "Enable Customization" is checked

### 3. Add Reset Visibility Control
- **File**: [actionbars_editmode.lua](../utils/actionbars_editmode.lua#L338)
- **Change**: Added `LEM:SetFrameResetVisible()` in `RegisterFrame()`
  ```lua
  LEM:SetFrameResetVisible(holderFrame, function(layoutName)
      local st = GetButtonSettings(buttonType)
      return st and st.enabled or false
  end)
  ```
- **Effect**: Reset button only shown when customization is enabled

### 4. Add Visual Overlay
- **File**: [actionbars_editmode.lua](../utils/actionbars_editmode.lua#L346)
- **Change**: Added visual feedback overlay identical to castbar implementation
  ```lua
  local overlay = CreateFrame("Frame", nil, holderFrame, "BackdropTemplate")
  overlay:SetBackdropBorderColor(0.3, 0.8, 1, 0.6)  -- Light blue border
  ```
- **Effect**: When dragging, blue border shows frame boundaries

## Architecture Comparison

### Before (Basic Integration)
```
LEM:AddFrame()              ✓ Basic frame registration
LEM:AddFrameSettings()      ✓ Settings panel UI
LEM:SetFrameDragEnabled()   ✗ Missing
LEM:SetFrameResetVisible()  ✗ Missing
Visual overlay              ✗ Missing
ExtraAbilityContainer       ✗ Visible (clutter)
```

### After (Modern Integration)
```
LEM:AddFrame()              ✓ Frame registration
LEM:AddFrameSettings()      ✓ Settings panel UI
LEM:SetFrameDragEnabled()   ✓ Drag predicate (enabled only)
LEM:SetFrameResetVisible()  ✓ Reset button predicate
Visual overlay              ✓ Blue border on drag
ExtraAbilityContainer       ✓ Hidden in Edit Mode
```

## Behavior Changes

| Aspect | Before | After |
|--------|--------|-------|
| **Dragging** | Always allowed | Only when "Enable Customization" checked |
| **Reset Button** | Always visible | Only when "Enable Customization" checked |
| **Visual Feedback** | None | Blue border when dragging |
| **ExtraAbilityContainer** | Visible (empty) | Hidden in Edit Mode |

## Code References

### Modified File
- [actionbars_editmode.lua](../utils/actionbars_editmode.lua) (lines 302-359, 407-449)

### Related Files
- [sui_actionbars.lua](../utils/sui_actionbars.lua) - Holder frame creation
- [castbar_editmode.lua](../utils/castbar_editmode.lua) - Reference implementation

## Testing

### In-Game Validation
1. ✅ Enter Edit Mode
   - Verify ExtraAbilityContainer is hidden
   - Extra Action Button and Zone Ability Button appear as draggable panels
2. ✅ Disable "Enable Customization" checkbox
   - Verify dragging is disabled (frames locked)
   - Verify reset button is hidden
3. ✅ Enable "Enable Customization" checkbox
   - Verify dragging is enabled
   - Verify reset button appears
4. ✅ Drag frames with customization enabled
   - Verify blue visual overlay appears while dragging
   - Verify position updates correctly

## Impact

- **User Experience**: EAB/ZA now have full Edit Mode feature parity with castbars and unitframes
- **Consistency**: All SuaviUI frames use identical drag predicate patterns
- **Cleanup**: Blizzard's empty ExtraAbilityContainer no longer clutters Edit Mode interface
- **Functionality**: Drag lockout prevents accidental repositioning when not intended
