# CDM (Cooldown Display Manager) Settings Reference

This document catalogs all settings from the CDM Setup UI panel before deletion.
These settings may be reimplemented in the future using a different architecture.

## Database Structure

Location: `SUICore.db.profile.ncdm`

### Essential Cooldowns (`ncdm.essential`)

**Top Level Settings:**
- `enabled` (boolean) - Enable/disable Essential Cooldowns display
- `layoutDirection` (string) - "HORIZONTAL" or "VERTICAL"

**Per-Row Settings (`row1`, `row2`, `row3`):**
- `iconCount` (number, 0-20) - Number of icons in row
- `iconSize` (number, 5-80) - Size of each icon in pixels
- `borderSize` (number, 0-5) - Border thickness in pixels
- `borderColorTable` (table) - Border color {r, g, b, a}
- `zoom` (number, 0-0.2) - Icon zoom level (0.01 steps)
- `padding` (number, -20 to 20) - Space between icons
- `yOffset` (number, -500 to 500) - Row vertical offset
- `xOffset` (number, -500 to 500) - Row horizontal offset
- `opacity` (number, 0-1.0) - Row opacity (0.05 steps)
- `aspectRatioCrop` (number, 1.0-2.0) - Icon shape (1.0=square, higher=flatter)
- `durationSize` (number, 8-50) - Duration text font size
- `durationAnchor` (string) - Duration text anchor point (TOPLEFT, TOP, TOPRIGHT, LEFT, CENTER, RIGHT, BOTTOMLEFT, BOTTOM, BOTTOMRIGHT)
- `durationOffsetX` (number, -80 to 80) - Duration text X offset
- `durationOffsetY` (number, -80 to 80) - Duration text Y offset
- `durationTextColor` (table) - Duration text color {r, g, b, a}
- `stackSize` (number, 8-50) - Stack count font size
- `stackAnchor` (string) - Stack text anchor point (same options as duration)
- `stackOffsetX` (number, -80 to 80) - Stack text X offset
- `stackOffsetY` (number, -80 to 80) - Stack text Y offset
- `stackTextColor` (table) - Stack count text color {r, g, b, a}
- `shape` (string) - DEPRECATED - migrated to aspectRatioCrop

**Default Row Settings:**
```lua
{
    iconCount = 4,
    iconSize = 50,
    borderSize = 2,
    zoom = 0,
    padding = -8,
    yOffset = 0,
    xOffset = 0,
    opacity = 1.0,
    aspectRatioCrop = 1.0,
    durationSize = 14,
    durationOffsetX = 0,
    durationOffsetY = 0,
    durationAnchor = "CENTER",
    durationTextColor = {1, 1, 1, 1},
    stackSize = 14,
    stackOffsetX = 0,
    stackOffsetY = 0,
    stackAnchor = "BOTTOMRIGHT",
    stackTextColor = {1, 1, 1, 1}
}
```

### Utility Cooldowns (`ncdm.utility`)

**Top Level Settings:**
- `enabled` (boolean) - Enable/disable Utility Cooldowns display
- `layoutDirection` (string) - "HORIZONTAL" or "VERTICAL"
- `anchorBelowEssential` (boolean) - Anchor utility viewer below essential viewer
- `anchorGap` (number, -200 to 200) - Gap between utility and essential when anchored

**Per-Row Settings (`row1`, `row2`, `row3`):**
Same as Essential Cooldowns (see above)

**Default Row Settings:**
```lua
{
    iconCount = 6,
    iconSize = 42,
    borderSize = 2,
    zoom = 0.08,
    padding = -8,
    yOffset = 0,
    xOffset = 0,
    opacity = 1.0,
    -- ... (rest same as Essential defaults)
}
```

### Buff Icons (`ncdm.buff`)

**Settings:**
- `enabled` (boolean) - Enable buff icon styling
- `iconSize` (number, 20-80) - Buff icon size in pixels
- `borderSize` (number, 0-8) - Border thickness
- `zoom` (number, 0-0.2) - Icon zoom level
- `padding` (number, -20 to 20) - Space between buff icons
- `opacity` (number, 0-1.0) - Buff opacity
- `aspectRatioCrop` (number, 1.0-2.0) - Icon shape
- `growthDirection` (string) - DEPRECATED - "CENTERED_HORIZONTAL" or other growth directions
- `durationSize` (number, 8-50) - Duration text size
- `stackSize` (number, 8-50) - Stack count size
- `shape` (string) - DEPRECATED - migrated to aspectRatioCrop

**Default Buff Settings:**
```lua
{
    enabled = false,  -- Disabled by default
    iconSize = 42,
    borderSize = 2,
    zoom = 0,
    padding = 0,
    opacity = 1.0,
    aspectRatioCrop = 1.0,
    durationSize = 12,
    stackSize = 12
}
```

## UI Features

### Copy Settings Between Rows
- Each row had a "Copy Settings From" dropdown
- Copied all settings from source row to target row
- Deep copied color tables to avoid reference issues

### UI Hints
- "Tip: Set Icon Size to 100% in Edit Mode for best results"
- "Higher values imply flatter icons" (for aspect ratio slider)

### Refresh Callbacks
- `RefreshNCDM()` - Triggered layout engine via `_G.SuaviUI_RefreshNCDM()`
- `RefreshBuff()` - Triggered buff bar refresh via `_G.SuaviUI_RefreshBuffBar()`
- Utility anchor changes also called `_G.SuaviUI_ApplyUtilityAnchor()`

## Migration Notes

### Aspect Ratio Migration
Old `shape` setting migrated to `aspectRatioCrop`:
- `"rectangle"` or `"flat"` → 1.33 (4:3 aspect ratio)
- `"square"` → 1.0 (1:1 aspect ratio)

Function: `MigrateRowAspect(rowData)`

### Integration Points
- CVar: `cooldownViewerEnabled` (set to 1 when CDM enabled)
- Global refresh functions called from options UI
- Settings persisted in AceDB profile

## Files Involved
- `utils/sui_ncdm.lua` - Core CDM implementation
- `utils/sui_ncdm_editmode.lua` - EditMode integration (disabled)
- `utils/sui_options.lua` - UI panel (lines 4867-5400+)
- Database: `SUICore.db.profile.ncdm`

## Removal Plan
1. Delete `sui_ncdm.lua`
2. Delete `sui_ncdm_editmode.lua`  
3. Remove CDM Setup page from `sui_options.lua`
4. Remove CDM visibility toggle from main UI settings
5. Clean up any global callbacks (`_G.SuaviUI_RefreshNCDM`, etc.)
6. Remove database migration code for `ncdm` table
