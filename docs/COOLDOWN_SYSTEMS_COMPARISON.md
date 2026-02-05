# Cooldown Systems Feature Comparison

## Overview

SuaviUI currently has **TWO separate cooldown systems running simultaneously**, both hooked to the same Blizzard frames:

1. **sui_ncdm.lua** - Legacy system (1991 lines) - Per-row layout management
2. **cooldownmanager.lua** - Modern system (838 lines) - CMC-ported centering logic

Both load in utils/utils.xml:
- Line 7: `cooldownmanager.lua` + 4 supporting modules  
- Line 42: `sui_ncdm.lua`

---

## System 1: sui_ncdm.lua (Legacy Per-Row Layout Manager)

### Core Purpose
Per-row cooldown layout system that organizes icons into rows with configurable sizing and aspect ratios.

### Features Implemented ✓

#### Layout & Positioning
- **Per-row configuration** (row1, row2, row3) with:
  - `iconCount` - number of icons per row
  - `iconSize` - pixel size of each icon
  - `padding` - spacing between icons  
  - `aspectRatioCrop` - height/width ratio (1.0 = square, 1.33 = 4:3 rectangle)
- **TexCoord cropping** based on aspect ratio for rectangular icons
- **Per-row anchoring** (TOPLEFT, CENTER, etc.)
- **Layout direction control** (`layoutDirection` setting) - ignores Blizzard's `isHorizontal` flag entirely
- **OnSizeChanged hook** to re-layout when viewer size changes

#### Icon Styling
- **Border customization** - size and color per row
- **Icon size constraints** based on row capacity
- **Aspect ratio cropping** - mathematically adjusts TexCoord for flat/wide icons
- **CooldownFlash suppression** - hides the ready flash for cleaner visuals
- **Mask texture removal** - strips Blizzard's mask layers
- **Overlay texture removal** - strips Blizzard's UI-HUD-CoolDownManager-IconOverlay

#### Text Customization  
- **Duration text** - font size, color, anchor point, offset (X/Y)
- **Stack text** - font size, color, anchor point, offset (X/Y)
- **Font selection from general settings** - uses LSM (LibSharedMedia)
- **Font outline** - control per tracker (essential/utility)

#### Viewer Management
- **Essential viewer layout** (EssentialCooldownViewer)
- **Utility viewer layout** (UtilityCooldownViewer)
- **Viewer enable/disable toggle** per tracker
- **CVar control** - manages `cooldownViewerEnabled` based on enabled state

#### Combat & Performance
- **Pending icon queue** - defers icon skinning during combat
- **Post-combat processing** - applies pending skins after PLAYER_REGEN_ENABLED  
- **Ticker system** - self-canceling timer when queue empty (CPU efficient)
- **OnUpdate rescan** - continuously checks for settings changes

#### Visibility Management
- **Mouseover detection** - fades frames in/out on mouse hover
- **CDM visibility control** - show/hide based on group/instance/PvP state
- **Unitframes visibility control** - separate visibility system for unitframes
- **Fade animations** - configurable alpha transitions
- **Combat protection** - skips layouts during combat (CPU efficiency)

#### Edit Mode Integration
- **GetScaledRect hook** - custom sizing for Edit Mode
- **GetScaledSelectionSides hook** - prevents crash with EncounterWarnings
- **Anchoring persistence** - OnShow/OnHide hooks to re-apply anchor positions

#### Database Structure
- Stored in `SUICore.db.profile.ncdm`
- `ncdm.essential` - Essential viewer config
- `ncdm.utility` - Utility viewer config
- Each has `row1`, `row2`, `row3` sub-tables

#### Known Limitati ons / Issues
- **IGNORES `isHorizontal` flag** - Always forces own `layoutDirection` setting
- **OnUpdate rescan** creates CPU load - runs continuously checking for changes
- **Tight coupling** with text positioning - complex margin/offset calculations
- **Blizzard overlay fighting** - repeatedly strips textures that Blizzard tries to reapply
- **Settings version tracking** - tries to optimize but still causes re-layouts

---

## System 2: cooldownmanager.lua + Modules (Modern CMC Port)

### Core Purpose
Centered alignment system ported from CooldownManagerCentered addon with modular architecture.

### Main Module: cooldownmanager.lua (838 lines)

#### Architecture
- **LayoutEngine** - Pure math functions for positioning (no frame access)
  - `CenteredRowXOffsets()` - Symmetric centering for horizontal rows
  - `CenteredColYOffsets()` - Symmetric centering for vertical columns  
  - `StartRowXOffsets()` - Left-aligned rows
  - `EndRowXOffsets()` - Right-aligned rows
  - `StartColYOffsets()` - Top-aligned columns
  - `EndColYOffsets()` - Bottom-aligned columns
  - `BuildRows()` - Group flat icon list into rows
  
- **StateTracker** - Invalidation/diffing system
  - Marks viewers dirty on settings/aura changes
  - `MarkViewersDirty()`, `MarkBuffIconsDirty()`, `MarkBuffBarsDirty()`

- **ViewerAdapters** - WoW frame interaction
  - `GetBuffIconFrames()` - Collects & sorts visible buff icons
  - `GetBuffBarFrames()` - Collects & sorts active buff bars  
  - `CollectViewerChildren()` - Gathers all icons from a viewer
  - `UpdateBuffIcons()` - Positions icons based on settings
  - `UpdateBuffBarsIfNeeded()` - Aligns buff bar frames
  - `CenterAllRows()` - Main layout application function

- **EventHandler** - Event registration & callbacks
  - Hooks RefreshLayout on all viewers
  - Listens for EditMode enter/exit
  - Listens for settings panel open/close
  - Responds to SETTINGS_LOADED, PLAYER_LOGIN events

#### Layout Features
- **Respects `isHorizontal` flag** - Adapts layout based on Blizzard's orientation
- **Multiple alignment modes**:
  - Centered (symmetric around anchor)
  - Start (left/top aligned)
  - End (right/bottom aligned)
- **Horizontal & vertical support** - Works for both row and column layouts
- **Padding control** - Consistent spacing
- **Direction modifier** - Supports reversed/mirrored layouts
- **RefreshLayout hook** - Integrates seamlessly with Blizzard's layout system

#### BuffIcon Features  
- **Icon positioning** based on `isHorizontal` and `iconDirection`
- **Visible icon filtering** - Only processes shown icons
- **Aura event hooks** - Updates on:
  - OnActiveStateChanged
  - OnUnitAuraAddedEvent
  - OnUnitAuraRemovedEvent
- **layoutIndex sorting** - Maintains order across refreshes
- **Size preservation** - Doesn't modify icon dimensions

#### BuffBar Features
- **Frame collection** with API resilience
  - Tries `GetItemFrames()` first
  - Falls back to `GetChildren()` if API unavailable
- **Vertical alignment** - Stacks buff bars
- **Active frame filtering** - Only processes shown/visible frames
- **Same event hooks as BuffIcons**

#### BuffIcon/BuffBar Settings Map
```lua
"cooldownManager_squareIcons_" .. viewerType
"cooldownManager_squareIconsBorder_" .. viewerType
"cooldownManager_squareIconsBorderOverlap_" .. viewerType
"cooldownManager_alignBuffIcons_growFromDirection"
"cooldownManager_normalizeUtilitySize"
"cooldownManager_limitUtilitySizeToEssential"
```

#### Runtime Tracking
- `Runtime.isInEditMode` - Prevents layout during Edit Mode
- `Runtime.hasSettingsOpened` - Prevents layout when settings panel open
- `Runtime.stop` - Master switch to disable all layouts
- `Runtime:IsReady()` - Validates viewer initialization state

---

## Supporting Modules

### cooldown_icons.lua (568 lines) - Square Icon Styling

#### Features
- **Square icon transformation**:
  - Applies 4:4 aspect ratio
  - Custom border with color control
  - Border overlap settings per viewer
- **Icon styling per viewer**:
  - EssentialCooldownViewer
  - UtilityCooldownViewer  
  - BuffIconCooldownViewer
  - BuffBarCooldownViewer
- **Pandemic alert scaling** - Adjusts PandemicIcon size (1.38x for square)
- **Debuff border scaling** - Scales border to fit square icons (1.7x)
- **Normalized sizing**:
  - Optional uniform icon size for Utility viewer
  - Matches Essential icon dimensions  
  - Separate config per viewer type
- **Icon refresh on aura changes** - Maintains styling consistency
- **Module enable/disable** - Can be toggled on/off
- **Settings tracked**:
  - `cooldownManager_squareIcons_*` - Enable per viewer
  - `cooldownManager_squareIconsBorder_*` - Border size
  - `cooldownManager_normalizeUtilitySize` - Uniform sizing

### cooldown_fonts.lua (294 lines) - Font Customization

#### Features
- **Cooldown number fonts**:
  - Per-viewer font size override
  - Global font selection (LSM)
  - Font flags (OUTLINE, THICKOUTLINE, MONOCHROME)
  - Can hide duration text per viewer
  
- **Stack number fonts**:
  - Per-viewer positioning (anchor point)
  - Custom offsets (X/Y)
  - Global font selection
  - Keybind text support
  
- **Font string creation** with flag support

- **Settings tracked**:
  - `cooldownManager_cooldownFontName`
  - `cooldownManager_cooldownFontSize*`
  - `cooldownManager_cooldownFontFlags`
  - `cooldownManager_stackFontName`
  - `cooldownManager_stackAnchor*`
  - `cooldownManager_stackFontSize*`

### cooldown_advanced.lua (320 lines) - Advanced Features

#### Features
- **Swipe color customization**:
  - Separate colors for active aura vs cooldown
  - Detects aura state dynamically
  - Applies to all icons in viewer
  
- **Size controls**:
  - Limit Utility width to Essential width
  - Normalize both viewers to same size
  
- **Utility dimming**:
  - Reduces opacity when not on cooldown
  - Configurable dim opacity
  - GCD detection (ignores < 1.5s cooldowns)
  
- **Rotation highlight** (placeholder framework)
  - Prepared for rotation addon integration

- **Settings tracked**:
  - `cooldownManager_customSwipeColor_*`
  - `cooldownManager_limitUtilitySizeToEssential`
  - `cooldownManager_normalizeUtilitySize`
  - `cooldownManager_utility_dimWhenNotOnCD`
  - `cooldownManager_utility_dimOpacity`

### cooldown_editmode.lua (DISABLED)

Currently EMPTY/DISABLED - Was supposed to add Edit Mode UI but triggers a Blizzard bug with EncounterWarnings secret value comparison.

Settings are available in SuaviUI Options panel instead.

---

## Feature Overlap Matrix

| Feature | NCDM | Cooldownmanager | Notes |
|---------|------|-----------------|-------|
| **Per-row layout** | ✓ | ✓ (via BuildRows) | Both group icons into rows |
| **Horizontal/vertical** | ✓ (forces own) | ✓ (respects `isHorizontal`) | **CONFLICT**: NCDM ignores flag |
| **Icon sizing** | ✓ | ✓ (BuffIcons) | NCDM per-row; CMC via styles |
| **Border styling** | ✓ | ✓ (icons.lua) | Different implementation |
| **Aspect ratio cropping** | ✓ (TexCoord) | ✗ | Only NCDM does this |
| **Text customization** | ✓ (extensive) | ✓ (fonts.lua) | NCDM has more offset control |
| **Font control** | ✓ | ✓ | Both use LSM |
| **Mouseover detection** | ✓ | ✗ | Only NCDM has this feature |
| **Visibility control** | ✓ (extensive) | ✗ | Only NCDM manages show/hide |
| **CVar management** | ✓ | ✗ | Only NCDM sets `cooldownViewerEnabled` |
| **Edit Mode integration** | ✓ | ✓ (disabled) | cooldown_editmode.lua is empty |
| **Combat deferral** | ✓ | ✗ | Only NCDM queues pending icons |
| **Buffer bars** | ✗ | ✓ | Only CMC handles BuffBar viewers |
| **Swipe colors** | ✗ | ✓ (advanced.lua) | Only CMC customizes cooldown swipe |
| **Dimming effects** | ✗ | ✓ (advanced.lua) | Only CMC dims icons |
| **Settings per tracker** | ✓ | ✓ | Both track essential vs utility |
| **OnUpdate scanning** | ✓ | ✗ | Only NCDM continuously polls |
| **RefreshLayout hook** | ✓ | ✓ | **CONFLICT**: Both hook same event |

---

## Conflicts & Fighting Points

### 1. **Layout Direction Control** (CRITICAL)
- **NCDM**: Ignores Blizzard's `isHorizontal` flag, forces own `layoutDirection` setting
- **CMC**: Respects `isHorizontal` flag and adapts layout accordingly
- **Result**: When layout direction changed in UI, NCDM reverts it to stored preference
- **Impact**: Users see orientation flipping, can't change via Blizzard UI

### 2. **RefreshLayout Hook** (CRITICAL)
- **NCDM**: Hooks `RefreshLayout` event on both viewers (line ~1068+)
- **CMC**: Hooks same event via `HookViewerRefreshLayout()` (cooldownmanager.lua line 804)
- **Result**: Both run on same trigger → cascading layout calls → frame oscillation

### 3. **Icon Size Setting** (HIGH)
- **NCDM**: Via `row1/2/3.iconSize` settings
- **CMC**: Via `icons.lua` square icon styling
- **Result**: Size changes trigger conflicting SetSize calls
- **Impact**: Icons size flickers/oscillates for several seconds

### 4. **CVar Management** (MEDIUM)
- **NCDM**: Controls `cooldownViewerEnabled` CVar based on enabled state
- **CMC**: Doesn't manage CVars, assumes CVar is already set
- **Result**: If NCDM disables CVar, CMC can't display viewers

### 5. **Edit Mode Integration** (MEDIUM)
- **NCDM**: Has complete Edit Mode support (GetScaledRect, GetScaledSelectionSides hooks)
- **CMC**: cooldown_editmode.lua is empty/disabled (triggers Blizzard bug)
- **Result**: Edit Mode for BuffIcon/BuffBar doesn't work via CMC path

### 6. **Pending Icon Queue** (LOW)
- **NCDM**: Defers icon styling during combat
- **CMC**: Applies updates immediately
- **Result**: Minimal visible impact but different performance profiles

### 7. **Mouseover Visibility** (FEATURE LOSS)
- **NCDM**: Has extensive mouseover-based visibility (fade in/out)
- **CMC**: No visibility control at all
- **Result**: If NCDM removed, mouseover fading feature is lost

---

## Critical Functionalities to Preserve

### Must Keep (Used & Working):
1. ✅ **Per-row icon layout** - Core to user's layout preferences
2. ✅ **Text customization** - Duration/stack size, position, color  
3. ✅ **Font control** - Font selection, sizes, flags
4. ✅ **Border styling** - Custom borders per row/icon
5. ✅ **Mouseover visibility** - Fade in/out on mouse hover (NCDM-only)
6. ✅ **CVar management** - Enable/disable cooldown viewers
7. ✅ **Edit Mode support** - Resizable/moveable frames
8. ✅ **Combat deferral** - Don't skin during combat (performance)
9. ✅ **Essential + Utility layout** - Both viewer types supported
10. ✅ **BuffIcon styling** - Square icons, borders, sizing

### Nice to Have (Advanced):
- Swipe color customization
- Utility dimming effects
- Size normalization between viewers
- Rotation highlight framework

### Can Lose:
- BuffBar integration (rarely used)
- Deprecated shape/rectangle settings (migrated to aspectRatioCrop)

---

## Recommendation Summary

The two systems fundamentally conflict on **layout direction philosophy**:

- **NCDM** = "Store user's preferred direction, force it regardless of Blizzard changes"
- **CMC** = "Respect Blizzard's current layout mode, adapt to it"

### Option A: Keep NCDM, Remove CMC
- Pro: All current features work, mouseover visibility preserved
- Con: CMC's swipe colors & dimming lost
- Risk: Lower - NCDM is battle-tested

### Option B: Keep CMC, Remove NCDM  
- Pro: Cleaner architecture, smaller codebase, respects Blizzard's UI
- Con: Lose mouseover visibility, CVar control, text customization sophistication
- Risk: Higher - need to rebuild missing features

### Option C: Make Them Cooperate
- Pro: Preserve all features, best of both worlds
- Con: Complex coordination logic needed
- Risk: Highest - requires careful design

**Recommended**: **Option C** with careful boundaries:
- NCDM handles: Text customization, mouseover visibility, CVar management
- CMC handles: Layout calculation, BuffBar, advanced effects
- Coordination: Don't fight on RefreshLayout, use debounced timer

---

## Next Steps

1. **Choose consolidation strategy** (A, B, or C)
2. **Implement feature analysis** for chosen strategy
3. **Create compatibility layer** if Option C chosen
4. **Test for regressions** on all viewer types
5. **Document final architecture** for maintenance
