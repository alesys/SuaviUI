# Blizzard Source Overlap & Interaction Reference

> **Generated**: 2026-02-08  
> **Source**: `wow-ui-source/Interface/AddOns/` (TWW 12.x retail)  
> **Purpose**: Maps every Blizzard UI system that SuaviUI hooks, replaces, or interacts with — with Blizzard internals documented from source.

---

## Table of Contents

1. [Cooldown Viewer System](#1-cooldown-viewer-system)
2. [Edit Mode System](#2-edit-mode-system)
3. [Buff & Aura Frames](#3-buff--aura-frames)
4. [Castbar System](#4-castbar-system)
5. [Unit Frames](#5-unit-frames)
6. [NamePlates](#6-nameplates)
7. [Minimap](#7-minimap)
8. [Action Bars](#8-action-bars)
9. [Status Tracking Bars (XP/Rep/Honor)](#9-status-tracking-bars)
10. [Alert Frames](#10-alert-frames)
11. [Chat Frames](#11-chat-frames)
12. [Tooltips](#12-tooltips)
13. [Objective Tracker](#13-objective-tracker)
14. [Other Blizzard Systems](#14-other-blizzard-systems)
15. [Global Hook Summary](#15-global-hook-summary)

---

## 1. Cooldown Viewer System

### Blizzard Source: `Blizzard_CooldownViewer/`

**20+ files** implementing 4 viewer frames that SuaviUI modifies extensively.

### Frame Hierarchy

```
EssentialCooldownViewer  (CooldownViewerMixin + EditModeCooldownViewerSystemMixin + UIParentManagedFrameMixin)
UtilityCooldownViewer    (CooldownViewerMixin + EditModeCooldownViewerSystemMixin + UIParentManagedFrameMixin)
BuffIconCooldownViewer   (CooldownViewerMixin + EditModeCooldownViewerSystemMixin + UIParentManagedFrameMixin)
BuffBarCooldownViewer    (CooldownViewerBuffBarMixin — does NOT inherit UIParentManagedFrameMixin)
```

Each viewer uses `CreateFramePool("Frame", nil, template, Resetter)` and `GetLayoutChildren()` for items.

### Icon Item Structure (Essential/Utility/BuffIcon)

```
CooldownViewerItemFrame
├── Icon           (Texture)          — spell icon
├── IconBorder     (Texture)          — atlas border, colored by rarity/type
├── IconMask       (MaskTexture)      — mask for icon shape
├── Cooldown       (CooldownFrame)    — swipe overlay
├── Duration       (FontString)       — time remaining text
├── CountText      (FontString)       — stack count
├── PandemicIcon   (Texture)          — pandemic refresh indicator
├── ProcStartFlipbook (Texture)       — proc activation animation
├── Finish         (Frame)            — finish animation container
├── SpellActivationAlert / OverlayGlow — proc glow effects
└── TooltipArea    (Frame)            — hover detection
```

### Bar Item Structure (BuffBarCooldownViewer)

```
CooldownViewerBuffBarItem
├── Bar        (StatusBar)    — the colored bar
├── Icon       (Texture)      — left-side spell icon
├── Name       (FontString)   — spell name
├── Duration   (FontString)   — time remaining
├── Pip        (FontString)   — separator marker
└── TooltipArea (Frame)
```

Key mixin: `CooldownViewerBuffBarItemMixin`
- `SetBarContent(mode)` — `IconAndName` / `IconOnly` / `NameOnly`
- `SetBarWidth(width)` — sets StatusBar width
- `OnUpdate` — refreshes bar value every frame

### Blizzard Edit Mode Settings for CDM

| Setting Enum | Values | Effect |
|---|---|---|
| `Orientation` | Horizontal / Vertical | `isHorizontal` on GridLayout |
| `IconLimit` | Number | Max icons shown |
| `IconDirection` | Left→Right / Right→Left etc. | `layoutFramesGoingRight` / `layoutFramesGoingUp` |
| `IconSize` | Percentage | Scale factor |
| `IconPadding` | Pixels | `childXPadding` / `childYPadding` |
| `BarWidthScale` | Percentage | `SetBarWidth()` on BuffBar items |
| `Opacity` | 0–100 | Frame alpha |
| `VisibleSetting` | Always / InCombat / Hidden | Visibility state |
| `BarContent` | IconAndName / IconOnly / NameOnly | BuffBar display mode |
| `HideWhenInactive` | Boolean | Hide when nothing on cooldown |
| `ShowTimer` | Boolean | Show/hide duration text |
| `ShowTooltips` | Boolean | Enable hover tooltips |

### Layout Engine

Grid layout via `GridLayoutFrameMixin`:
- `stride` = icons per row (from `IconLimit`)
- `childXPadding` / `childYPadding` from `IconPadding`
- Anchor computed from `isHorizontal` + direction booleans

### Events Registered by Blizzard CDM

| Event | Purpose |
|---|---|
| `SPELL_UPDATE_COOLDOWN` | Refresh cooldown states |
| `UNIT_AURA` | Buff/debuff changes |
| `UNIT_TARGET` | Target change (for utility filtering) |
| `PLAYER_TOTEM_UPDATE` | Totem tracking |
| `COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED` | Spell list override |

### EventRegistry Callbacks

```lua
EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", ...)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", ...)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", ...)
```

### SuaviUI Modules That Touch CDM

| SuaviUI Module | What It Does |
|---|---|
| `cooldownmanager.lua` | Centering, layout coordination, icon sizing, row management |
| `cooldown_coordinator.lua` | Serializes refresh calls, prevents race conditions |
| `cooldown_icons.lua` | Aspect-ratio cropping, square borders, tex coords on icons |
| `cooldown_fonts.lua` | Font family/size on Duration/CountText/Name strings |
| `cooldown_advanced.lua` | Custom cooldown text, count overlays |
| `cooldowneffects.lua` | Hides PandemicIcon, ProcStartFlipbook, Finish, OverlayGlow |
| `customglows.lua` | Replaces Blizzard proc glows with LibCustomGlow |
| `cooldownswipe.lua` | Controls SetDrawSwipe/SetDrawEdge per cooldown type |
| `sui_buffbar.lua` | BuffIcon/BuffBar centering, icon styling, bar styling |
| `sui_ncdm.lua` | (Disabled) Alternative icon grid layout |
| `keybinds.lua` | Keybind text overlays on CDM icon items |
| `init.lua` | Crash recovery for RefreshData failures |

### Key Hooks Into CDM

```lua
hooksecurefunc(child, "OnActiveStateChanged")
hooksecurefunc(child, "OnUnitAuraAddedEvent")
hooksecurefunc(child, "OnUnitAuraRemovedEvent")
hooksecurefunc(viewer, "RefreshLayout")
hooksecurefunc(viewer, "Layout")
hooksecurefunc(tex, "SetAtlas")              -- icon border interception
hooksecurefunc(icon, "OnSpellActivationOverlayGlowShowEvent")
hooksecurefunc(icon, "OnSpellActivationOverlayGlowHideEvent")
hooksecurefunc(icon.Cooldown, "SetCooldown")
```

### Risks & Considerations

- `BuffBarCooldownViewer` does **not** inherit `UIParentManagedFrameMixin` — cannot use managed frame positioning
- Icon pool uses `GetLayoutChildren()` not a stable ordered list — iteration order can shift
- `RefreshLayout` fires frequently during combat (every aura change)
- CDM's Edit Mode settings override anything SuaviUI sets if `OnDataChanged` fires after SUI

---

## 2. Edit Mode System

### Blizzard Source: `Blizzard_EditMode/`

The master controller for frame positioning in retail WoW.

### Architecture

```
EditModeManagerFrame (singleton)
├── editModeActive (boolean)
├── registeredSystemFrames[] — all frames that participate
├── layoutInfo — current layout data
├── AccountSettings / CharacterSettings
└── Methods:
    ├── EnterEditMode() → fires EventRegistry "EditMode.Enter"
    ├── ExitEditMode()  → fires EventRegistry "EditMode.Exit"
    ├── OnSystemSettingChange(system, systemIndex, setting, value)
    ├── OnSystemPositionChange(frame)
    └── SaveLayouts() → C_EditMode.SaveLayouts()
```

### System Registration

Frames participate by inheriting `EditModeSystemMixin`:
```lua
self.system = Enum.EditModeSystem.XXX
self.systemIndex = Enum.EditModeXXXSystemIndices.YYY
self.Selection = selectionFrame  -- highlight overlay
```

### Setting Storage

Each system's settings are stored as arrays of `{ setting = enumValue, value = rawValue }` in the layout data structure. Layouts can be Preset, Account, or Character scope.

### System Enums (Enum.EditModeSystem)

| System | Used By SuaviUI |
|---|---|
| `ActionBar` | ✅ actionbars_editmode.lua |
| `CastBar` | ✅ castbar_editmode.lua (replaces) |
| `UnitFrame` | ✅ unitframes_editmode.lua (replaces) |
| `Minimap` | ✅ minimap_editmode.lua |
| `AuraFrame` | ⚠️ buffborders.lua (reads) |
| `CooldownViewer` | ✅ cooldownmanager.lua (interacts) |
| `StatusTrackingBar` | ⚠️ uihider.lua (hides) |
| `ObjectiveTracker` | ⚠️ skinning (styles) |
| `MicroMenu` | ❌ not touched |
| `BagsBar` | ❌ not touched |
| `TalkingHead` | ⚠️ uihider.lua (hides) |
| `EncounterBar` | ❌ not touched |

### CDM-Specific Edit Mode Extension

`EditModeCooldownViewerSystemMixin` inherits `EditModeSystemMixin` and adds:
- Custom settings dialog with CDM-specific UI
- "CDM Settings" and "Options" extra buttons in the sidebar
- Per-viewer settings panels

### Layout Save/Load

```lua
C_EditMode.GetLayouts()  → table of { layoutType, layoutName, systems[] }
C_EditMode.SaveLayouts(layouts)
```

SuaviUI hooks: `hooksecurefunc(EditModeManagerFrame, "EnterEditMode")` / `"ExitEditMode"` in multiple modules.

### SuaviUI's LEM (LibEQOLEditMode) Integration

SuaviUI registers custom frames with `LibEQOLEditMode-1.0` to appear in the Edit Mode sidebar:
- Player/Target/Focus/Pet/ToT/Boss castbars
- Player/Target/Focus/Pet/ToT/Boss unit frames
- ExtraActionBar + ZoneAbilityFrame
- Minimap
- Custom anchoring frames

These are **separate** from Blizzard's `EditModeSystemMixin` registration — they appear in a custom LEM section of the sidebar.

---

## 3. Buff & Aura Frames

### Blizzard Source: `Blizzard_BuffFrame/`

The player's buff/debuff display near the minimap.

### Frame Hierarchy

```
BuffFrame (BaseAuraFrameTemplate + BuffFrameMixin)
├── AuraContainer (AuraContainerMixin)
│   └── [AuraButtonTemplate × 32]
├── CollapseAndExpandButton
└── ConsolidatedBuffs → Tooltip → Auras

DebuffFrame (BaseAuraFrameTemplate + DebuffFrameMixin)
├── AuraContainer
│   └── [AuraButtonTemplate × 16]
└── privateAuraAnchors[1-6]

DeadlyDebuffFrame (DeadlyDebuffFrameMixin)
└── Debuff button (scale=1.25)

ExternalDefensivesFrame (BaseAuraFrameTemplate + ExternalDefensivesFrameMixin)
└── AuraContainer (maxAuras=5)
```

### Template Inheritance

```
AuraFrameMixin
  └─ AuraFrameEventListenerMixin
       └─ AuraFrameEditModeMixin + EditModeAuraFrameSystemTemplate
            └─ BaseAuraFrameMixin
                 ├─ BuffFrameMixin
                 ├─ DebuffFrameMixin
                 └─ ExternalDefensivesFrameMixin
```

### Aura Button Structure

```
AuraButton (30×40 default)
├── Icon        (30×30, TOP)        — spell texture
├── Count       (BOTTOMRIGHT)       — stack count
├── Duration    (below icon)        — time remaining
├── DebuffBorder (40×40, centered)  — color-coded by debuff type
├── TempEnchantBorder (32×32)       — weapon enchant border
└── Symbol      (TOPLEFT)           — dispel type symbol
```

### Population Flow

1. `UNIT_AURA` event → `unitAuraUpdateInfo` (isFullUpdate, addedAuras, removedAuraInstanceIDs, updatedAuraInstanceIDs)
2. `UpdateAuras()` → iterates `AuraUtil.ForEachAura(PlayerFrame.unit, filter, ...)`
3. Each aura → `self.auraInfo[n]` = { auraType, index, texture, count, debuffType, duration, expirationTime, timeMod, hideUnlessExpanded }
4. `UpdateAuraButtons()` → applies to pool

### Grid Layout

`AuraContainerMixin:UpdateGridLayout()`:

| Property | Default | Meaning |
|---|---|---|
| `isHorizontal` | true | Layout direction |
| `iconStride` | 8 | Icons per row |
| `iconPadding` | 5 | Gap between icons |
| `iconScale` | 1 | Scale multiplier |
| `addIconsToRight` | false | X growth direction |
| `addIconsToTop` | false | Y growth direction |

Sizes: Horizontal = 30×40 per icon, Vertical = 60×30.

### Duration & Timers

- `expirationTime > 0` → show Duration text, enable OnUpdate
- `SecondsToTimeAbbrev(timeLeft)` for display
- Warning flash when `timeLeft < 31s` (BUFF_WARNING_TIME) — BOUNCE AnimationGroup with Lerp(0.3, 1.0) over 1.5s
- Color changes at BUFF_DURATION_WARNING_TIME

### Filtering

- `hideUnlessExpanded` — long-duration permanent buffs hidden unless expanded
- CVar `collapseExpandBuffs` — collapse/expand button
- CVar `consolidateBuffs` — consolidated buffs icon
- `ShouldShowAura()` = `IsExpanded() or not aura.hideUnlessExpanded`

### Edit Mode Settings (Enum.EditModeAuraFrameSetting)

| Setting | Effect |
|---|---|
| `Orientation` | Horizontal / Vertical |
| `IconWrap` | Down/Up or Left/Right |
| `IconDirection` | Left/Right or Down/Up |
| `IconLimitBuffFrame` | Icons per row (BuffFrame) |
| `IconLimitDebuffFrame` | Icons per row (DebuffFrame) |
| `IconSize` | Scale percentage |
| `IconPadding` | Pixel padding |
| `VisibleSetting` | Always / InCombat / Hidden |
| `Opacity` | Frame alpha |
| `ShowDispelType` | Show colored borders + symbols |

### SuaviUI Interaction

| SuaviUI Module | What It Does |
|---|---|
| `buffborders.lua` | Adds custom border textures to `BuffFrame` / `DebuffFrame` AuraContainer buttons |
| `uihider.lua` | Can hide the collapse button |

Hooks:
```lua
hooksecurefunc(BuffFrame, "Show")
hooksecurefunc(BuffFrame, "Update")
hooksecurefunc(BuffFrame.AuraContainer, "Update")
hooksecurefunc(DebuffFrame, "Show")
hooksecurefunc(DebuffFrame, "Update")
hooksecurefunc(DebuffFrame.AuraContainer, "Update")
```

### Risks

- Aura button pool is re-used — any cached references to buttons may become stale
- `UpdateGridLayout` re-anchors all children each time — any addon-set anchors will be overwritten
- `UNIT_AURA` fires very frequently in combat — hooks on `Update` must be lightweight

---

## 4. Castbar System

### Blizzard Source: `Blizzard_CastingBar/` + `Blizzard_UnitFrame/`

### CastingBarMixin — The Universal Base

All Blizzard castbars inherit `CastingBarMixin`:

```
CastBar (StatusBar)
├── Spark       — progress marker
├── Flash       — finish flash animation
├── Text        — spell name
├── CastTimeText — cast time remaining
├── Icon        — spell icon (left side)
├── BorderShield — uninterruptible indicator
├── Border      — normal border
└── OnUpdate    — fills bar each frame
```

**State Variables:**
- `self.casting` / `self.channeling` / `self.reverseChanneling`
- `self.barType` — determines texture atlas
- `self.showShield` — uninterruptible display

### Bar Types (CASTING_BAR_TYPES)

| barType | Atlas Key | When |
|---|---|---|
| `standard` | Standard fill | Normal cast |
| `channel` | Channel fill | Channeling |
| `uninterruptable` | Uninterruptable fill | Shield shown |
| `interrupted` | Interrupted fill | Cast was interrupted |
| `empowered` | Empowered fill | Empower spell |
| `applyingcrafting` | ApplyingCrafting fill | Crafting cast |

### Events

```
UNIT_SPELLCAST_START / _STOP / _FAILED / _INTERRUPTED / _DELAYED
UNIT_SPELLCAST_CHANNEL_START / _CHANNEL_UPDATE / _CHANNEL_STOP
UNIT_SPELLCAST_EMPOWER_START / _EMPOWER_UPDATE / _EMPOWER_STOP
UNIT_SPELLCAST_INTERRUPTIBLE / _NOT_INTERRUPTIBLE
UNIT_SPELLCAST_SUCCEEDED
```

### Player Castbar

`PlayerCastingBarFrame` — global, inherits `EditModeCastBarSystemTemplate`:
- `PlayerFrame_AttachCastBar()` / `PlayerFrame_DetachCastBar()` — lock-to-player toggle
- Edit Mode settings: `BarSize`, `LockToPlayerFrame`
- Positioned via Edit Mode layout system

### Nameplate Castbar

`NamePlateCastingBarMixin` = `CastingBarMixin` + `NamePlateComponentMixin`:
- Attached to each nameplate unit frame
- Uses same event flow but filtered to nameplate unit

### SuaviUI Replacement

SuaviUI **completely replaces** all player castbars:

| SuaviUI Module | Action |
|---|---|
| `sui_castbar.lua` | Hides `PlayerCastingBarFrame`, creates custom player/target/focus/ToT/boss castbars |
| `CastbarMixin.lua` | Custom mixin with SuaviUI styling (statusbar color, icon, timer, spark) |
| `castbar_editmode.lua` | Registers castbars in LEM Edit Mode sidebar |

Hooks:
```lua
hooksecurefunc(PlayerCastingBarFrame, "Show")  -- immediately re-hides
```

### Risks

- `PlayerCastingBarFrame` is a secure frame — cannot be hidden in combat (only via `RegisterUnitWatch`)
- Blizzard still fires all SPELLCAST events — SuaviUI must handle the same event matrix
- Lock-to-player-frame toggle in Blizzard Edit Mode can interfere with SuaviUI positioning
- `GetEffectiveType()` logic for empowered spells is complex — must match Blizzard behavior

---

## 5. Unit Frames

### Blizzard Source: `Blizzard_UnitFrame/`

### Player Frame Hierarchy

```
PlayerFrame (EditModePlayerFrameSystemTemplate + ClickableParentMixin)
├── PlayerFrameContainer
│   └── FrameTexture (portrait ring art)
├── PlayerFrameContent
│   ├── PlayerFrameContentMain
│   │   ├── HealthBarsContainer
│   │   │   ├── HealthBar (StatusBar)
│   │   │   ├── HealPredictionBar
│   │   │   ├── HealAbsorbBar
│   │   │   └── TotalAbsorbBar + TotalAbsorbBarOverlay
│   │   ├── ManaBarArea
│   │   │   └── ManaBar (StatusBar)
│   │   └── StatusTexture (combat/rest icons)
│   └── PlayerFrameContentContextual
│       ├── GroupIndicator
│       ├── PVPIcon
│       └── PrestigePortrait
```

### Target/Focus Frames

`TargetFrameMixin` handles Target, Focus, Boss1-5:
- Dynamic `.spellbar` (CastingBarMixin)
- Dynamic `.totFrame` (Target of Target)
- `UNIT_HEALTH`, `UNIT_MAXHEALTH`, `UNIT_ABSORB_AMOUNT_CHANGED` events
- Threat indicators from `UnitThreatSituation()`

### Edit Mode Settings (Enum.EditModeUnitFrameSetting)

| Setting | Effect |
|---|---|
| `HidePortrait` | Hides portrait texture |
| `CastBarUnderneath` | Moves spellbar below frame |
| `BuffsOnTop` | Auras above vs below |
| `UseLargerFrame` | Switches to large template |
| `UseRaidStylePartyFrames` | Party frames as raid-style |
| `ShowPartyFrameBackground` | Background toggle |
| `UseHorizontalGroups` | Horizontal layout |
| `DisplayAggroHighlight` | Threat glow |
| `FrameWidth` | Width percentage |
| `FrameHeight` | Height percentage |
| `DisplayBorder` | Border toggle |
| `SortPlayersBy` | Group/Role/Alphabetical |
| `RowSize` | Raid-style frames per row |

### SuaviUI Replacement

SuaviUI creates **entirely custom unit frames** (5200+ lines):

| Unit | SuaviUI Frame | Blizzard Frame Hidden |
|---|---|---|
| Player | Custom SecureUnitButton | PlayerFrame (optionally) |
| Target | Custom SecureUnitButton | TargetFrame |
| Focus | Custom SecureUnitButton | FocusFrame |
| Pet | Custom SecureUnitButton | PetFrame |
| ToT | Custom SecureUnitButton | TargetFrameToT |
| Boss1-5 | Custom SecureUnitButton | Boss1-5TargetFrame |

Events handled: `UNIT_HEALTH`, `UNIT_MAXHEALTH`, `UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_HEAL_ABSORB_AMOUNT_CHANGED`, `UNIT_POWER_UPDATE`, `UNIT_POWER_FREQUENT`, `UNIT_POWER_MAX`, `UNIT_NAME_UPDATE`, `RAID_TARGET_UPDATE`, `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`, `UNIT_PET`, `UNIT_TARGET`, `PARTY_LEADER_CHANGED`, `GROUP_ROSTER_UPDATE`, `PLAYER_UPDATE_RESTING`, `PLAYER_REGEN_DISABLED/ENABLED`, `UPDATE_SHAPESHIFT_FORM`, `UNIT_AURA`, `INSTANCE_ENCOUNTER_ENGAGE_UNIT`

LEM Edit Mode integration with full settings panels for each frame.

---

## 6. NamePlates

### Blizzard Source: `Blizzard_NamePlates/`

### Nameplate Lifecycle

1. `NAME_PLATE_CREATED` → `NamePlateBaseMixin:OnAdded()` — frame enters pool
2. `NAME_PLATE_UNIT_ADDED` → Acquires from pool → Creates `NamePlateUnitFrameTemplate`
3. `NAME_PLATE_UNIT_REMOVED` → Returns to pool
4. `FORBIDDEN_NAME_PLATE_CREATED/UNIT_ADDED/REMOVED` — for restricted nameplates

### Nameplate Frame Structure

```
NamePlate (C_NamePlate managed)
└── UnitFrame (NamePlateUnitFrameTemplate)
    ├── healthBar (StatusBar)
    ├── castBar (NamePlateCastingBarMixin)
    ├── BuffFrame (NameplateBuffContainerMixin)
    ├── name (FontString)
    ├── RaidTargetFrame
    ├── selectionHighlight
    └── aggroHighlight
```

### SuaviUI Interaction

SuaviUI does **not** directly modify nameplates — it relies on Plater (imported via `imports/platynator.lua`). The Plater import profile handles all nameplate customization.

---

## 7. Minimap

### Blizzard Source: `Blizzard_Minimap/Mainline/`

### MinimapCluster Hierarchy

```
MinimapCluster (EditModeMinimapSystemTemplate + ResizeLayoutFrame, TOPRIGHT, 256×256)
├── BorderTop (header bar, 175×16)
│   └── ZoneTextButton → MinimapZoneText (PvP-color-coded zone name)
├── Tracking (hidden, 17×17)
│   └── Button (MiniMapTrackingButtonMixin) — tracking dropdown
├── IndicatorFrame (horizontal layout)
│   ├── MailFrame (MiniMapMailFrameMixin)
│   └── CraftingOrderFrame
├── MinimapContainer (215×226, the scalable wrapper)
│   └── Minimap (engine widget, 198×198, circular)
│       ├── ZoomHitArea (40×40)
│       ├── ZoomIn / ZoomOut (hidden until hover)
│       └── MinimapBackdrop (215×226)
│           ├── MinimapCompassTexture (compass ring art)
│           ├── StaticOverlayTexture (housing indoor)
│           └── ExpansionLandingPageMinimapButton (garrison/expansion)
└── InstanceDifficulty
```

### Minimap Shape & Masking

The `Minimap` is an engine-level `<Minimap>` widget — renders a circular map natively. The compass frame (`MinimapCompassTexture`) overlays decorative art. Zoom via `Minimap:SetZoom()` / `GetZoom()` / `GetZoomLevels()`.

### Edit Mode Settings (Enum.EditModeMinimapSetting)

| Setting | Effect |
|---|---|
| `HeaderUnderneath` | Moves header bar below the map |
| `RotateMinimap` | CVar `rotateMinimap` |
| `Size` | Scales `MinimapContainer` via `SetEditModeScale(value/100)` |

`SetHeaderUnderneath(true)` repositions BorderTop, InstanceDifficulty (flipped), and IndicatorFrame below the map.

### Tracking System

`MiniMapTrackingButtonMixin`:
- **Predicted tracking state** system for async spell cast delays
- Categories: `REMOVED_FILTERS`, `ALWAYS_ON_FILTERS`, `CONDITIONAL_FILTERS`, `OPTIONAL_FILTERS`
- Dropdown sorts into Hunter tracking, Townsfolk, Regular

### Zone Text

- Updated on `ZONE_CHANGED`, `ZONE_CHANGED_INDOORS`, `ZONE_CHANGED_NEW_AREA`
- Color-coded: sanctuary=cyan, arena=red, friendly=green, hostile=red, contested=orange

### AddonCompartment

```lua
AddonCompartmentFrame:RegisterAddon({
    text = "Addon Name",
    icon = "Interface\\...",
    func = function() ... end,
    funcOnEnter = function() ... end,
    funcOnLeave = function() ... end,
})
```
Or via TOC metadata: `AddonCompartmentFunc`, `IconTexture`, etc.

### SuaviUI Modifications (1613 lines)

| What | How |
|---|---|
| Square minimap | `Minimap:SetMaskTexture(squareMask)`, overrides `_G.GetMinimapShape` |
| Hide border art | Hides `MinimapCompassTexture`, backdrop elements |
| Hide zoom buttons | `hooksecurefunc(Minimap.ZoomIn/ZoomOut, "Show")` → re-hide |
| Blob ring removal | `Minimap:SetArchBlobRingScalar(0)`, `SetQuestBlobRingScalar(0)` |
| HybridMinimap (Delves) | Patches for delve minimap overlay |
| QueueStatusButton | `hooksecurefunc(QueueStatusButton, "UpdatePosition")` |
| GameTimeFrame | Visibility control |
| LEM Edit Mode | Registers Minimap in Edit Mode sidebar |

### Risks

- `MinimapCluster:SetEditModeScale()` only scales `MinimapContainer`, not header — SuaviUI must handle scaling separately
- `SetHeaderUnderneath()` resets all anchor points — any SUI-set anchors on header elements will be lost
- `_G.GetMinimapShape` override is checked by many addons (LibDBIcon, etc.) — must return correct shape

---

## 8. Action Bars

### Blizzard Source: `Blizzard_ActionBar/` + `Blizzard_ActionBarController/`

### Bar Roster

| Frame | Action Page | Position |
|---|---|---|
| `MainActionBar` | Dynamic (1–6) | Bottom center |
| `MultiBarBottomLeft` | 6 | Above main |
| `MultiBarBottomRight` | 5 | Above BottomLeft |
| `StanceBar` | N/A (shapeshifts) | Above BottomRight |
| `PetActionBar` | N/A (pet) | Above StanceBar |
| `PossessActionBar` | N/A (possess) | Above PetBar |
| `MultiBarRight` | 3 | Right edge |
| `MultiBarLeft` | 4 | Left of Right |
| `MultiBar5` | 13 | Floating |
| `MultiBar6` | 14 | Floating |
| `MultiBar7` | 15 | Floating |

### Action Button Structure

```
ActionBarButtonTemplate (CheckButton, 45×45)
├── icon (Texture) — spell icon
├── IconMask (MaskTexture)
├── SlotBackground / SlotArt
├── Flash — activation flash
├── Name (FontString) — macro name
├── Border — equipped item border (green)
├── TextOverlayContainer (frameLevel=500)
│   ├── HotKey (FontString) — keybind text
│   └── Count (FontString) — charge/stack count
├── cooldown (CooldownFrameTemplate) — swipe overlay
├── lossOfControlCooldown (CooldownFrameTemplate) — dark red LoC overlay
├── chargeCooldown (CooldownFrameTemplate) — charge timer (no swipe)
└── AutoCastOverlay — pet autocast
```

### Cooldown Priority on Action Buttons

Three concurrent CooldownFrames:
1. **Normal cooldown** (`self.cooldown`) — standard swipe, black 0.8 alpha
2. **Charge cooldown** (`self.chargeCooldown`) — no swipe, just timer (when `maxCharges > 1 && currentCharges < maxCharges`)
3. **Loss of Control** (`self.lossOfControlCooldown`) — dark red (0.17,0,0) overlay when LoC exceeds normal CD

### Icon Usability Colors

| State | Color | RGB |
|---|---|---|
| Usable | White | (1, 1, 1) |
| Not enough mana | Blue | (0.5, 0.5, 1.0) |
| Not usable | Gray | (0.4, 0.4, 0.4) |

### Edit Mode Settings (Enum.EditModeActionBarSetting)

| Setting | Effect |
|---|---|
| `Orientation` | Horizontal / Vertical |
| `NumRows` | Rows (or columns if vertical) |
| `NumIcons` | Buttons shown |
| `IconSize` | Scale percentage |
| `IconPadding` | Px between buttons (min=2) |
| `HideBarArt` | Hides border art, endcaps |
| `HideBarScrolling` | Hides page number |
| `VisibleSetting` | Always / InCombat / OutOfCombat / Hidden |
| `AlwaysShowButtons` | Grid on empty slots |

### Bar Paging (ActionBarController)

Priority order for MainActionBar page:
1. Skinned vehicle/override → OverrideActionBar
2. Bonus action bar (stance) → `C_ActionBar.GetBonusBarIndex()`
3. Vehicle bar → `C_ActionBar.GetVehicleBarIndex()`
4. Override bar → `C_ActionBar.GetOverrideBarIndex()`
5. Temp shapeshift → `C_ActionBar.GetTempShapeshiftBarIndex()`
6. Default → `C_ActionBar.GetActionBarPage()`

### Bottom Bar Stacking

`UpdateBottomActionBarPositions()` stacks from bottom-up:
```
MainActionBar → MultiBarBottomLeft → MultiBarBottomRight → StanceBar → PetActionBar → PossessActionBar → VehicleLeaveButton
```
Each bar that `IsShown() and IsInDefaultPosition()` gets cumulative Y offset. Spacer: `BOTTOM_ACTION_BARS_SPACER_Y`.

### Helper Functions for Addon Positioning

```lua
EditModeUtil:GetBottomActionBarHeight()  -- topmost visible bottom bar offset+height
EditModeUtil:GetRightActionBarWidth()    -- rightmost visible right bar offset+width
EditModeUtil:IsBottomAnchoredActionBar(frame)
EditModeUtil:IsRightAnchoredActionBar(frame)
```

### SuaviUI Modifications

| SuaviUI Module | What It Does |
|---|---|
| `sui_actionbars.lua` | Range/mana coloring, keybind styling, page arrow visibility, ExtraActionBar/ZoneAbilityFrame movers |
| `actionbars_editmode.lua` | LEM registration for ExtraActionBar + ZoneAbilityFrame |
| `skinning/overrideactionbar.lua` | Styles OverrideActionBar spell buttons |
| `keybinds.lua` | Keybind overlays on action buttons (supports Dominos/Bartender4) |
| `sui_crosshair.lua` | Scans action bar buttons for out-of-range detection |

Hooks:
```lua
hooksecurefunc(ExtraActionBarFrame, "SetPoint")
hooksecurefunc(ZoneAbilityFrame, "SetPoint")
hooksecurefunc(pageNum, "Show")
hooksecurefunc(EditModeManagerFrame, "EnterEditMode"/"ExitEditMode")
```

Events: `ACTIONBAR_UPDATE_USABLE`, `ACTIONBAR_UPDATE_COOLDOWN`, `SPELL_UPDATE_USABLE`, `SPELL_UPDATE_CHARGES`, `UNIT_POWER_UPDATE`, `PLAYER_TARGET_CHANGED`, `PLAYER_REGEN_DISABLED/ENABLED`, `ACTIONBAR_SLOT_CHANGED`, `UPDATE_BINDINGS`

### Risks

- SecureActionButton restrictions — cannot modify in combat
- ExtraActionBarFrame/ZoneAbilityFrame `SetPoint` hooks fire frequently during encounters
- `UpdateBottomActionBarPositions()` recalculates all bar positions — SuaviUI's position overrides may be reset
- Grid show/hide raises strata to `"TOOLTIP"` — may obscure SuaviUI overlays

---

## 9. Status Tracking Bars

### Blizzard Source: Part of `Blizzard_ActionBar/`

### Frame Structure

```
StatusTrackingBarManager (BOTTOM of UIParent, 571×34)
├── MainStatusTrackingBarContainer (Edit Mode: StatusTrackingBar1)
└── SecondaryStatusTrackingBarContainer (Edit Mode: StatusTrackingBar2)
```

Each container holds 6 bar types:
1. Reputation (ReputationStatusBarTemplate)
2. Honor (HonorStatusBarTemplate)
3. Artifact (ArtifactStatusBarTemplate)
4. Experience (ExpStatusBarTemplate)
5. Azerite (AzeriteBarTemplate)
6. HouseFavor (HouseFavorBarTemplate)

**Priority**: `Azerite(0) > Reputation(1) > Honor(2) > Artifact(3) > Experience(4) > HouseFavor(5)`

Higher number = primary container. Max 2 bars shown simultaneously.

### SuaviUI Interaction

`uihider.lua` can hide `StatusTrackingBarManager`:
```lua
hooksecurefunc(StatusTrackingBarManager, "Show")
hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown")
```

`sui_datatexts.lua` provides alternative XP/rep display via data text panels.

---

## 10. Alert Frames

### Blizzard Source: `Blizzard_FrameXML/AlertFrames.lua`

### Alert Subsystems

`AlertFrame` manages 20+ subsystems that generate popup notifications:
- AchievementAlert, CriteriaAlert, LootAlert, MoneyAlert, HonorAwardAlert
- NewRecipeLearnedAlert, NewPetAlert, NewMountAlert, NewToyAlert, NewRuneforgePowerAlert
- DigsiteCompleteAlert, GarrisonAlert, GuildChallengeAlert, DungeonCompletionAlert
- ScenarioAlert, InvasionAlert, WorldQuestCompleteAlert, LegendaryItemAlert
- EntitlementDeliveredAlert, RafRewardDeliveredAlert, BonusRollAlert

### SuaviUI Skinning

`skinning/alerts.lua` hooks:
```lua
hooksecurefunc(AlertFrame, "AddAlertFrameSubSystem")
hooksecurefunc(AlertFrame, "UpdateAnchors")
```
Plus individual hooks on 20+ subsystem frames to apply SuaviUI border/background styling.

---

## 11. Chat Frames

### Blizzard Source: `Blizzard_ChatFrame/`

### SuaviUI Modifications

`sui_chat.lua`:
- Glass-style theming on ChatFrame1-10
- Strips background textures
- URL copy functionality
- Custom tab styling

Hooks:
```lua
hooksecurefunc("FCF_OpenTemporaryWindow")
hooksecurefunc("FCF_OpenNewWindow")
hooksecurefunc("FCF_Tab_OnClick")
hooksecurefunc("FCF_SetChatWindowFontSize")
```

---

## 12. Tooltips

### Blizzard Source: `Blizzard_GameTooltip/`

### SuaviUI Modifications

`sui_tooltips.lua`:
- Cursor-following anchor
- Context-based visibility (combat hide, modifier key show)
- Spell ID display
- Custom backdrop styling

Hooks:
```lua
hooksecurefunc("GameTooltip_SetDefaultAnchor")
hooksecurefunc(GameTooltip, "SetUnit")
hooksecurefunc(GameTooltip, "SetSpellByID")
hooksecurefunc(GameTooltip, "SetItemByID")
```

---

## 13. Objective Tracker

### Blizzard Source: `Blizzard_ObjectiveTracker/`

### SuaviUI Interaction

Two modules:
1. `uihider.lua` — can hide `ObjectiveTrackerFrame` entirely (`hooksecurefunc(ObjectiveTrackerFrame, "Show")`)
2. `skinning/objectivetracker.lua` — custom font/color styling

Hooks:
```lua
hooksecurefunc(TrackerFrame.Header, "SetCollapsed")
hooksecurefunc(ObjectiveTrackerBlockMixin, "AddObjective")
hooksecurefunc(ObjectiveTrackerBlockMixin, "SetHeader")
hooksecurefunc(TrackerFrame, "Update")
hooksecurefunc(TrackerFrame, "SetCollapsed")
```

---

## 14. Other Blizzard Systems

| Blizzard System | SuaviUI Module | Interaction |
|---|---|---|
| `Blizzard_EncounterWarnings` | `init.lua` | Patches `SetIsEditing → noop` (crash workaround) |
| `GameMenuFrame` | `skinning/gamemenu.lua` | Hooks `InitButtons` for styling |
| `Blizzard_CharacterFrame` | `sui_character.lua`, `skinning/character.lua` | iLvl display, reputation/token list styling |
| `Blizzard_InspectUI` | `sui_inspect.lua`, `skinning/inspect.lua` | Custom iLvl overlay |
| `Blizzard_PVPUI` | `skinning/instanceframes.lua` | PVE/PVP frame styling |
| `Blizzard_ChallengesUI` | `sui_mplus_timer.lua`, `sui_dungeon_teleport.lua`, `skinning/keystone.lua` | M+ timer, dungeon teleport buttons, keystone styling |
| `Blizzard_LootFrame` | `skinning/loot.lua` | Loot/GroupLoot styling |
| `ReadyCheckFrame` | `skinning/readycheck.lua` | Custom ready check UI |
| `OverrideActionBar` | `skinning/overrideactionbar.lua` | Vehicle bar button styling |
| `PlayerPowerBarAlt` | `skinning/powerbaralt.lua` | Replaces with custom bar |
| `CompactRaidFrameManager` | `uihider.lua` | Can hide |
| `TalkingHeadFrame` | `uihider.lua` | Can hide |
| `WorldMapFrame` | `uihider.lua` | Controls BlackoutFrame alpha |
| `UIErrorsFrame` | `uihider.lua` | Visibility control |
| `Blizzard_Professions` | `sui_quicksalvage.lua` | Quick salvage integration |
| `C_AssistedCombat` | `sui_rotationassist.lua` | Rotation helper icon |
| `Dragonriding/Skyriding` | `sui_skyriding.lua` | Vigor bar tracking |
| `BackpackTokenFrame` | `sui_datatexts.lua` | Currency display |

---

## 15. Global Hook Summary

### Hooks by Type

#### hooksecurefunc on Frame Methods (most impactful)

| Target | Method | SuaviUI Module |
|---|---|---|
| `EditModeManagerFrame` | `EnterEditMode` | suicore_main, sui_actionbars, sui_unitframes, suicore_nudge |
| `EditModeManagerFrame` | `ExitEditMode` | suicore_main, sui_actionbars, sui_unitframes, suicore_nudge, skinning/loot |
| `PlayerCastingBarFrame` | `Show` | sui_castbar, sui_unitframes |
| `BuffFrame` | `Show`, `Update` | buffborders |
| `DebuffFrame` | `Show`, `Update` | buffborders |
| `BuffFrame.AuraContainer` | `Update` | buffborders |
| `DebuffFrame.AuraContainer` | `Update` | buffborders |
| `ExtraActionBarFrame` | `SetPoint` | sui_actionbars |
| `ZoneAbilityFrame` | `SetPoint` | sui_actionbars |
| `StatusTrackingBarManager` | `Show`, `UpdateBarsShown` | uihider |
| `ObjectiveTrackerFrame` | `Show` | uihider |
| `CompactRaidFrameManager` | `Show`, `SetShown` | uihider |
| `TalkingHeadFrame` | `Show`, `PlayCurrent` | uihider |
| `GameTooltip` | `SetUnit`, `SetSpellByID`, `SetItemByID` | sui_tooltips |
| `Minimap.ZoomIn/ZoomOut` | `Show` | suicore_minimap |
| `QueueStatusButton` | `UpdatePosition` | suicore_minimap |
| CDM viewer children | `OnActiveStateChanged`, `OnUnitAuraAddedEvent`, `RefreshLayout`, `Layout` | cooldownmanager, cooldown_icons, cooldowneffects, customglows, cooldownswipe |
| CDM icon children | `OnSpellActivationOverlayGlowShowEvent/HideEvent`, `RefreshOverlayGlow` | customglows |
| `icon.Cooldown` | `SetCooldown` | cooldownswipe |
| `tex` (IconBorder) | `SetAtlas` | cooldown_icons, sui_buffbar |

#### Overridden Blizzard Globals

| Global | New Value | Module |
|---|---|---|
| `_G.GetMinimapShape` | Returns "SQUARE" for square minimap | suicore_minimap |
| `BINDING_NAME_SUAVIUI_TOGGLE_OPTIONS` | SuaviUI keybind name | init.lua |

#### EventRegistry Callbacks

```lua
EventRegistry:RegisterCallback("EditMode.Enter", ...)
EventRegistry:RegisterCallback("EditMode.Exit", ...)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", ...)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", ...)
```

### Event Registration Summary

SuaviUI registers for 80+ unique WoW events across all modules. The most performance-critical (fire in combat):

| Event | Modules Listening | Frequency |
|---|---|---|
| `UNIT_AURA` | sui_unitframes, buffborders, sui_buffbar, cooldown_advanced, sui_raidbuffs | Very high |
| `SPELL_UPDATE_COOLDOWN` | cooldownmanager, cooldown_advanced, sui_ncdm, keybinds | High |
| `UNIT_HEALTH` / `UNIT_MAXHEALTH` | sui_unitframes | High |
| `UNIT_POWER_UPDATE` / `UNIT_POWER_FREQUENT` | sui_unitframes, sui_actionbars | High |
| `ACTIONBAR_UPDATE_COOLDOWN` | sui_actionbars, keybinds | High |
| `PLAYER_REGEN_DISABLED/ENABLED` | 10+ modules | Low (toggle) |

---

## Appendix: Frame Relationship Diagram

```
UIParent
├── EditModeManagerFrame (controls all Edit Mode positioning)
│
├── MinimapCluster (SUI: square mask, hidden border, LEM-registered)
│   └── Minimap
│
├── BuffFrame / DebuffFrame (SUI: custom borders via buffborders.lua)
│
├── PlayerCastingBarFrame (SUI: HIDDEN, replaced by sui_castbar.lua)
│
├── PlayerFrame / TargetFrame / FocusFrame (SUI: custom frames overlay/replace)
│
├── EssentialCooldownViewer (SUI: 8 modules modify icons, layout, effects, fonts)
├── UtilityCooldownViewer   (SUI: same as Essential)
├── BuffIconCooldownViewer  (SUI: custom icon styling + centering)
├── BuffBarCooldownViewer   (SUI: bar styling + centering, NO UIParentManagedFrameMixin)
│
├── MainActionBar (SUI: range colors, keybinds, page arrows)
│   └── ActionButton1-12 (SUI: icon styling, keybind overlays)
├── MultiBarBottomLeft/Right (SUI: same as MainActionBar)
├── MultiBarRight/Left (SUI: same)
├── MultiBar5/6/7 (SUI: same)
├── StanceBar / PetActionBar (SUI: styling)
├── ExtraActionBarFrame (SUI: LEM-registered, position hooks)
├── ZoneAbilityFrame (SUI: LEM-registered, position hooks)
├── OverrideActionBar (SUI: skinning)
│
├── StatusTrackingBarManager (SUI: can hide via uihider.lua)
├── ObjectiveTrackerFrame (SUI: can hide, custom font/color skinning)
├── CompactRaidFrameManager (SUI: can hide)
├── TalkingHeadFrame (SUI: can hide)
├── GameTooltip (SUI: cursor follow, spell ID, combat hide)
├── AlertFrame (SUI: border/background skinning on all subsystems)
├── ChatFrame1-10 (SUI: glass theme, URL copy)
├── GameMenuFrame (SUI: button skinning)
└── ReadyCheckFrame (SUI: custom UI)
```
