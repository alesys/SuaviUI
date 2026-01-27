# SuaviUI vs Sensei Class Resource Bar - Comparison

## Overview

Both addons provide **customizable resource bar systems** for World of Warcraft, but with different approaches and scopes.

---

## Bar Types Comparison

### SuaviUI Resource Bars
Located in: `utils/suicore_resourcebars.lua` + config in `utils/suicore_main.lua`

**Bars Included:**
1. **Primary Power Bar** - Main resource (Mana, Rage, Energy, etc.)
2. **Secondary Power Bar** - Class-specific resources (Combo Points, Holy Power, Chi, Soul Shards, etc.)
3. **Player Castbar** - Casting progress indicator
4. **Target Castbar** - Target's casting progress
5. **Focus Castbar** - Focus target's casting progress

**Total: 5 bars (2 resource + 3 cast)**

### Sensei Class Resource Bar
Located in: `Bars/` directory with modular architecture

**Bars Included:**
1. **Health Bar** - Player health
2. **Primary Resource Bar** - Main power resource
3. **Secondary Resource Bar** - Secondary class power
4. **Tertiary Resource Bar** - Tertiary class power

**Total: 4 bars (all resource-focused, no cast bars)**

---

## Feature Comparison

| Feature | SuaviUI | Sensei |
|---------|---------|--------|
| **Health Bar** | Via Unit Frames | ✅ Dedicated Bar |
| **Primary Power** | ✅ | ✅ |
| **Secondary Power** | ✅ | ✅ |
| **Tertiary Power** | ❌ | ✅ |
| **Castbars (Player/Target/Focus)** | ✅ 3 bars | ❌ |
| **Fragmented Power Display** | ✅ Tick marks | ✅ Tick marks |
| **Edit Mode Integration** | ✅ LibEQOLEditMode | ✅ LibEQOLEditMode |
| **Position Management** | Manual (offsetX/Y) | Edit Mode UI |
| **Import/Export Settings** | ✅ Via SUI string format | ✅ LibSerialize + LibDeflate |
| **Layout Switching** | Via Edit Buttons | LibEQOLEditMode |
| **Architecture** | Monolithic (single file) | Modular (separate bar classes) |

---

## Configuration Approach

### SuaviUI
- **Simple table-based config** in `suicore_main.lua`
- Direct settings: width, height, offsetX/Y, colors, etc.
- **Atomic settings** for each bar type
- Position relative to other UI elements (attachTo: "EssentialCooldownViewer")

```lua
powerBar = {
    enabled = true,
    height = 8,
    offsetY = -204,
    offsetX = 0,
    width = 326,
    texture = "Suavi v5",
    colorMode = "power",
    usePowerColor = true,
    -- ... more settings
}
```

### Sensei
- **Database-driven** via `SenseiClassResourceBarDB`
- Settings per layout (supports multiple layouts)
- **Mixin-based architecture** with inheritance:
  - `BarMixin` (base)
  - `PowerBarMixin` (extends BarMixin)
  - `HealthBarMixin`, `PrimaryResourceBar`, etc.
- Event-driven updates with lib integration

```lua
-- Registered via:
addonTable.RegisteredBar.HealthBar = {
    mixin = addonTable.HealthBarMixin,
    dbName = "healthBarDB",
    editModeName = L["HEALTH_BAR_EDIT_MODE_NAME"],
    frameName = "HealthBar",
    -- ... config
}
```

---

## Color System

### SuaviUI
**Comprehensive power color mapping** (25+ colors defined):
- Core Resources: Rage, Energy, Mana, Focus, Runic Power, Fury, Insanity, Maelstrom, Lunar Power
- Builder Resources: Holy Power, Chi, Combo Points, Soul Shards, Arcane Charges, Essence
- Specialized: Stagger (with level-based colors), Soul Fragments, Runes, Blood/Frost/Unholy Runes

```lua
powerColors = {
    rage = { 1.00, 0.00, 0.00, 1 },
    energy = { 1.00, 1.00, 0.00, 1 },
    mana = { 0.00, 0.00, 1.00, 1 },
    -- ... 25+ more
}
```

### Sensei
**Similar but separate management**:
- Color settings in `Settings/HealthAndPowerColorSettings.lua`
- Stored in `SenseiClassResourceBarDB["_Settings"]["PowerColors"]`
- Per-class, per-layout customization
- Less predefined, more user-driven

---

## Text Display

### SuaviUI
**Primary Bar:**
- `showPercent`: true/false - Show % of resource
- `showText`: true/false - Show current/max values
- `textSize`: 16 (font size)
- `textX`, `textY`: offset positioning
- `textUseClassColor`: Use class color for text
- `textCustomColor`: Custom text color

**Configurable per bar**, can show different formats for Primary vs Secondary

### Sensei
- Text format tags: `[current]`, `[percent]`, `[max]`
- Via `GetTagValues()` method in each bar mixin
- More flexible but requires understanding tag system
- Can create custom format strings

---

## Positioning & Anchoring

### SuaviUI
**Built-in anchor system:**
- Manual positioning: `offsetX`, `offsetY`
- Attachment points: `attachTo` (e.g., "EssentialCooldownViewer")
- Lock to elements: `lockedToEssential`, `lockedToUtility`, `lockedToPrimary`
- Snap gaps: `snapGap` for spacing

```lua
powerBar = {
    attachTo = "EssentialCooldownViewer",
    offsetY = -204,
    lockedToEssential = false,
    snapGap = 5,
}
```

### Sensei
**Edit Mode driven:**
- Position via LibEQOLEditMode UI (drag & drop)
- Stores position in database per-layout
- More user-friendly for in-game editing
- Settings stored: `point`, `x`, `y` relative to reference frame

---

## Modularity & Extensibility

### SuaviUI
❌ **Monolithic**
- All bars in single file (`suicore_resourcebars.lua`)
- ~2600 lines handling everything
- More difficult to add new bar types
- Tightly coupled to SuaviUI ecosystem

### Sensei
✅ **Highly modular**
- Each bar type in separate file:
  - `Bars/HealthBar.lua`
  - `Bars/PrimaryResourceBar.lua`
  - `Bars/SecondaryResourceBar.lua`
  - `Bars/TertiaryResourceBar.lua`
- Common base: `Bars/Abstract/Bar.lua`
- Power-specific: `Bars/Abstract/PowerBar.lua`
- **Much easier to add new bar types**

---

## Event Handling

### SuaviUI
- Integrated with global update loops
- Power update events handled per-configuration
- Text updates tied to value changes

### Sensei
- Each bar registers its own events via mixin
- Example (HealthBar):
  - `PLAYER_ENTERING_WORLD`
  - `PLAYER_SPECIALIZATION_CHANGED`
  - `PLAYER_REGEN_ENABLED/DISABLED`
  - `PLAYER_TARGET_CHANGED`
  - `UNIT_ENTERED_VEHICLE/EXITED_VEHICLE`
  - `PLAYER_MOUNT_DISPLAY_CHANGED`
  - `PET_BATTLE_OPENING_START/CLOSE`

---

## Library Dependencies

### SuaviUI
- LibSharedMedia-3.0 (textures, fonts)
- LibSerialize + LibDeflate (export/import)
- Ace3 libraries (if importing)

### Sensei
- LibSharedMedia-3.0 (textures, fonts)
- LibSerialize + LibDeflate (import/export)
- LibEQOLEditMode-1.0 (settings UI)
- LibEQOLSettingsMode-1.0 (settings management)

---

## Key Differences Summary

| Aspect | SuaviUI | Sensei |
|--------|---------|--------|
| **Scope** | Full UI (cast bars included) | Resource bars only |
| **Architecture** | Monolithic file | Modular (mixin-based) |
| **Positioning** | Code-driven (offsets) | UI-driven (Edit Mode) |
| **Health Bar** | Via Unit Frames | Dedicated bar |
| **Castbars** | 3 built-in | None |
| **Layout Switching** | Multiple profiles | LibEQOL layouts |
| **Customization** | High for power colors | High for positioning |
| **UI Settings** | Options panel | Edit Mode + dedicated UI |
| **Code Size** | ~2600 lines (resource bar) | Modular (smaller per-file) |
| **Ease of Extension** | Difficult (monolithic) | Easy (add new mixin) |

---

## Recommendations

### For SuaviUI:
✅ **Keep current approach** - Integrated casting + resources makes sense as part of full UI
✅ **Could benefit from:** Dedicated Health Bar like Sensei (currently via Unit Frames)
✅ **Consider:** Splitting `suicore_resourcebars.lua` into modular mixins for maintainability

### For adding Tertiary Resource Bar to SuaviUI:
1. Create configuration in `suicore_main.lua`:
   ```lua
   tertiaryPowerBar = {
       enabled = false,
       -- ... similar to secondaryPowerBar
   }
   ```
2. Add initialization in `suicore_resourcebars.lua`
3. Handle Tertiary power resource (varies by class/spec)
4. Add options UI integration

