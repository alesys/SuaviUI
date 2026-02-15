# Resource Bars System Audit - January 29, 2026 (Updated February 14, 2026)

## Critical Issues Found

### 1. **Secondary and Tertiary Bars Not Visible**

**Root Cause**: Bars are created but likely hidden due to:
- Default `enabled: true` setting may not be working
- Bars may be positioned off-screen (default y: -220, -236)
- `GetSecondaryResource()` might return nil for Warlock (Soul Shards detection issue)
- Visibility conditions in UpdatePower() hiding bars

**Check Required**:
- Verify secondary bar is enabled in Edit Mode settings
- Check if bar position is on screen
- Debug `GetSecondaryResource()` for Warlock class

### 2. **Duplicate/Overlapping Settings**

#### Settings Panel (SUI) vs Edit Mode (LibEQOL)

| Setting | SUI Panel | Edit Mode | Status | Recommendation |
|---------|-----------|-----------|--------|----------------|
| **Position (X/Y)** | ❌ Removed | ✅ Drag | Fixed | Keep in Edit Mode only |
| **Enabled** | ✅ Old toggle | ✅ Visibility | Duplicate | **REMOVE from SUI** |
| **Width** | ✅ Slider | ✅ Slider | Duplicate | **CONSOLIDATE to Edit Mode** |
| **Height** | ✅ Slider | ✅ Slider | Duplicate | **CONSOLIDATE to Edit Mode** |
| **Relative Frame** | ❌ Not in SUI | ✅ Dropdown | Missing | **Already in Edit Mode** |
| **Align To** | ✅ Dropdown | ❌ Not in EM | Unique | **MOVE to Edit Mode or REMOVE** |
| **Width Sync** | ✅ Dropdown | ❌ Not in EM | Unique | **MOVE to Edit Mode** |
| **Orientation** | ✅ Dropdown | ❌ Not in EM | Unique | **MOVE to Edit Mode** |
| **Textures** | ✅ Dropdown | ✅ Dropdown | Duplicate | **Keep in Edit Mode** |
| **Colors** | ✅ Pickers | ✅ Pickers | Duplicate | **Keep in Edit Mode** |
| **Border Size** | ✅ Slider | ✅ Slider | Duplicate | **Keep in Edit Mode** |
| **Show Text** | ✅ Checkbox | ✅ Toggle | Duplicate | **Keep in Edit Mode** |
| **Text Settings** | ✅ Sliders | ✅ Sliders | Duplicate | **Keep in Edit Mode** |

### 3. **Settings Not Working**

**Why SUI Panel Settings Don't Apply**:
1. Old panel modifies `db.resourceBars.primaryPowerBar["Default"]`
2. Edit Mode settings registered in `init.lua` lines 75-320 override these
3. `RefreshPowerBars()` calls `UpdatePower()` but `ApplyLayout()` isn't called
4. Edit Mode re-applies settings on layout change, overwriting SUI panel changes

**Settings That Don't Work**:
- ❌ Align To (calculates offsetX/Y but doesn't call ApplyLayout)
- ❌ Width Sync (same issue)
- ❌ Orientation (not refreshed)
- ❌ Width/Height from SUI (Edit Mode values override)
- ❌ Any position-related setting

### 4. **Health Bar Implementation**

**Status**: ✅ Health bar IS created (line 650-652 in init.lua)

**Check Required**:
- Verify it matches Sensei's implementation
- Check if it's visible by default
- Verify Edit Mode integration

**Files**:
- `utils/resourcebars/bars/HealthBar.lua` - Implementation
- Should have same Edit Mode settings as other bars

### 5. **Relative Frames Not Working**

**Issue**: Some relative frames in dropdown don't exist

**Check Required in `helpers.lua`**:
```lua
resolveRelativeFrame(frameName)
```

Frames that might not exist:
- Essential Cooldowns (if addon not enabled)
- Utility Cooldowns (if addon not enabled)
- Tracked Buffs (if addon not enabled)
- Secondary/Tertiary Power Bars (if not created yet)

## Recommended Solution

### **Option 1: Complete Edit Mode Migration (RECOMMENDED)**

**Move ALL settings to Edit Mode panels**, remove SUI "Class Resource Bars" page entirely.

**Benefits**:
- ✅ Single source of truth
- ✅ No duplicate settings
- ✅ Settings apply immediately
- ✅ Consistent UX with Blizzard Edit Mode
- ✅ Per-layout settings work correctly

**Edit Mode Setting Structure**:
```lua
-- Position & Anchoring (lines 128-192)
- Relative Frame dropdown
- [Drag to position]

-- Size & Appearance (lines 193-320)
- Bar Size (scale)
- Width Mode (Manual/Auto)
- Width slider
- Height slider
- Orientation (Horizontal/Vertical/Auto)

-- CDM Integration (NEW - add these)
- Align To (None/Essential CDs/Utility CDs/Primary Bar)
- Width Sync (None/Essential CDs/Utility CDs/Primary Bar)
- Snap Gap slider

-- Style
- Texture dropdown
- Background Color picker
- Border Size slider

-- Bar Color
- Use Resource Type Color (checkbox)
- Use Class Color (checkbox)
- Custom Color Override (checkbox)
- Custom Color picker

-- Text
- Show Number (checkbox)
- Show as Percent (checkbox)
- Text Size slider
- Text X/Y Offset sliders
- Text Color settings

-- Fragmented Power (for secondary bar)
- Show Tick Marks
- Tick Thickness
- Tick Color

-- Visibility
- Enabled (checkbox)
- Hide in Combat
- Hide Out of Combat
- Fade When Not In Use
```

### **Option 2: Hybrid Approach**

Keep SUI panel for **appearance only**, Edit Mode for **positioning/layout**.

**SUI Panel**:
- Resource Colors section (global power type colors)
- Advanced fragmented power settings

**Edit Mode**:
- Everything else

## Implementation Plan

### Phase 1: Fix Immediate Issues (Today)

1. **Fix Secondary Bar Visibility**
   - Debug why secondary bar not showing for Warlock
   - Check `GetSecondaryResource()` returns `Enum.PowerType.SoulShards`
   - Verify bar enabled in database
   - Check bar position is on-screen

2. **Remove SUI Panel Entirely**
   - Delete "Class Resource Bars" page from sui_options.lua
   - Keep only Resource Colors section as separate page

3. **Move Missing Settings to Edit Mode**
   - Add Orientation dropdown to Edit Mode (line ~250)
   - Add Align To dropdown to Edit Mode (line ~260)
   - Add Width Sync dropdown to Edit Mode (line ~270)
   - Add Snap Gap slider to Edit Mode (line ~280)

### Phase 2: Polish (Tomorrow)

1. **Add Setting Categories in Edit Mode**
   - Use collapsible sections for organization
   - Group related settings together

2. **Fix Relative Frame Dropdown**
   - Check which frames actually exist before adding to list
   - Show "(Not Available)" for missing frames

3. **Test All Bars**
   - Health bar visibility and settings
   - Secondary bar for all classes
   - Tertiary bar for Evoker
   - All Edit Mode settings apply correctly

### Phase 3: Documentation (Later)

1. Update .copilot-instructions.md
2. Update user guide
3. Create changelog entry

## Files to Modify

### Delete/Gut
- `utils/sui_options.lua` lines 5727-6800 (Class Resource Bars page)

### Keep (move to separate page)
- `utils/sui_options.lua` lines 6800+ (Resource Colors section)

### Modify
- `utils/resourcebars/init.lua` lines 75-320 (Edit Mode settings registration)
  - Add: Orientation, Align To, Width Sync, Snap Gap
  - Reorganize: Group into logical collapsible sections

### Debug
- `utils/resourcebars/resources/detection.lua` line 107 (GetSecondaryResource)
- `utils/resourcebars/bars/SecondaryPowerBar.lua` line 27 (UpdatePower visibility logic)

## Testing Checklist

- [ ] Health bar visible
- [ ] Primary bar visible and working
- [ ] Secondary bar visible for Warlock (Soul Shards)
- [ ] Tertiary bar visible for Evoker (Essence)
- [ ] All Edit Mode settings apply immediately
- [ ] Orientation changes work
- [ ] Align To works (snaps to CDM frames)
- [ ] Width Sync works (matches CDM width)
- [ ] Relative Frame works (anchors to other frames)
- [ ] Dragging works and persists
- [ ] Layout switching works
- [ ] Layout duplication works
- [ ] No duplicate settings between SUI panel and Edit Mode
- [ ] RefreshPowerBars() removed (not needed if ApplyLayout called)

## Database Migration

Current structure works, no changes needed:
```lua
db.profile.resourceBars = {
    healthBar = {
        ["Default"] = { enabled = true, width = 326, ... },
        ["Custom Layout"] = { ... }
    },
    primaryPowerBar = { ["Default"] = { ... } },
    secondaryPowerBar = { ["Default"] = { ... } },
    tertiaryPowerBar = { ["Default"] = { ... } }
}
```

## Questions for User

1. **Remove SUI panel entirely** or keep Resource Colors section?
2. **Move Align To / Width Sync to Edit Mode** or remove completely?
3. **Keep Orientation dropdown** or remove (most users use horizontal)?
4. **How should we handle missing relative frames** (Essential CDs not installed)?
