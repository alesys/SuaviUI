# SuaviUI Cooldown Features – Complete Inventory

> Scope: All cooldown-related systems in this repo (SuaviUI integrated systems, legacy NCDM, and external CooldownManagerCentered addon). This is a feature inventory, not a behavior guarantee. Some features may be disabled via force-disable flags.

## 0) Systems Overview (What Exists)

1) **SuaviUI Integrated Cooldown Manager (CDM)**
   - Code: [utils/cooldownmanager.lua](../utils/cooldownmanager.lua)
   - Styling helpers: [utils/cooldown_icons.lua](../utils/cooldown_icons.lua)
   - Buff bar integration: [utils/sui_buffbar.lua](../utils/sui_buffbar.lua)
   - Edit-mode nudge: [utils/suicore_nudge.lua](../utils/suicore_nudge.lua)

2) **Legacy NCDM (New Cooldown Display Manager)**
   - Code: [utils/sui_ncdm.lua](../utils/sui_ncdm.lua)
   - Settings integration notes: [docs/NCDM_SETTINGS_INTEGRATION.md](NCDM_SETTINGS_INTEGRATION.md)

3) **External Addon: CooldownManagerCentered**
   - Entry: [CooldownManagerCentered/CooldownManagerCentered.lua](../../CooldownManagerCentered/CooldownManagerCentered.lua)
   - Core: [CooldownManagerCentered/modules/cooldownManager.lua](../../CooldownManagerCentered/modules/cooldownManager.lua)
   - Styling: [CooldownManagerCentered/modules/styled.lua](../../CooldownManagerCentered/modules/styled.lua)

---

## 1) SuaviUI Integrated CDM (utils/cooldownmanager.lua)

### 1.1 Viewer Types
- Essential cooldowns
- Utility cooldowns
- Buff icon cooldowns
- Buff bar cooldowns

### 1.2 Layout / Arrangement
- Centered row layout helpers
- Start/end alignment helpers
- Growth direction per viewer (essential/utility)
- Buff icon alignment direction
- Buff bar growth direction
- Optional normalization of utility sizes
- Optional limit utility size to essential width

### 1.3 Square Icons (per viewer)
- Enable square icons (Essential/Utility/BuffIcons)
- Border thickness
- Border overlap
- Icon zoom

### 1.4 Visual States
- Dim utility icons when not on cooldown
- Dim opacity control
- Rotation highlight for essential and utility

### 1.5 Fonts
- Cooldown number font family
- Cooldown number font flags (outline/thick/mono)
- Per-viewer cooldown number sizes
- Stack number font family
- Stack number font flags (outline/thick/mono)
- Per-viewer stack number sizes
- Stack number anchors (point + offsets)
- Keybind font family
- Keybind font flags (outline/thick/mono)
- Per-viewer keybind size
- Keybind anchors (point + offsets)
- Per-viewer keybind visibility

### 1.6 Swipe / Colors
- Custom swipe color enable
- Active aura color
- Cooldown swipe color

### 1.7 Debugging / Utilities
- Refresh debug logs
- Slash test for square icon settings

---

## 2) SuaviUI Styling Layer (utils/cooldown_icons.lua)

- Icon sizing normalization
- Border thickness + overlap handling
- Icon texture zoom/crop
- Style application per viewer type
- Refresh utilities for all icons

---

## 3) Buff Bar Integration (utils/sui_buffbar.lua)

- Buff bar layout coordination with cooldown viewers
- Spacing and size adjustments for buff bar icons
- Refresh hooks for buff bar when cooldown viewer layout changes

---

## 4) NCDM (utils/sui_ncdm.lua) – Legacy System

### 4.1 Viewer Control
- Essential and utility viewers with row-based configuration
- Per-row settings (counts/sizes/padding/aspect)
- Per-row text positioning
- Per-row border configuration
- Optional mouseover visibility rules
- Layout direction and alignment options

### 4.2 System Integrations
- Refresh exports for global use (`_G.SuaviUI_RefreshNCDM`)
- Tracked bar subsystem
- Unitframe castbar alignment callbacks
- Keybind integration hooks

> Note: NCDM options panel UI is not currently active; see [docs/NCDM_SETTINGS_INTEGRATION.md](NCDM_SETTINGS_INTEGRATION.md).

---

## 5) CooldownManagerCentered (external addon)

### 5.1 Core Features
- Central cooldown viewers (essential/utility)
- Buff icon and buff bar viewers
- Layout rules and spacing logic

### 5.2 Styling Features
- Icon styling, borders, and masks
- Texture zoom/crop handling
- Per-viewer styling rules

---

## 6) Options Panel Coverage

### 6.1 Wired in Options (SuaviUI integrated CDM)
- Square icons (Essential/Utility/BuffIcons)
- Borders + overlap + zoom
- Dim utility icons (and opacity)
- Buff icon alignment & buff bar growth
- Essential/utility row growth direction
- Cooldown number font options
- Stack number font options + anchors
- Keybind font options + anchors + visibility
- Swipe colors
- Normalize/limit utility size
- Rotation highlight toggles

### 6.2 Not Wired in Options (NCDM legacy)
- Per-row counts/sizes/padding/aspect
- Per-row borders and text positions
- Mouseover visibility rules
- Layout direction
- Enable/disable toggles

---

## 7) Disable Flags (Current State)

These flags may disable layout/styling effects even if options exist:
- [utils/cooldownmanager.lua](../utils/cooldownmanager.lua) – `FORCE_DISABLE_CDM_LAYOUT`
- [utils/cooldown_icons.lua](../utils/cooldown_icons.lua) – `FORCE_DISABLE_CDM_STYLING`
- [utils/sui_buffbar.lua](../utils/sui_buffbar.lua) – `FORCE_DISABLE_CDM_BUFFBAR`
- [utils/sui_ncdm.lua](../utils/sui_ncdm.lua) – `FORCE_DISABLE_NCDM`
- [utils/suicore_nudge.lua](../utils/suicore_nudge.lua) – `FORCE_DISABLE_CDM_NUDGE`
- [CooldownManagerCentered/modules/cooldownManager.lua](../../CooldownManagerCentered/modules/cooldownManager.lua) – `FORCE_DISABLE_CDM_LAYOUT`
- [CooldownManagerCentered/modules/styled.lua](../../CooldownManagerCentered/modules/styled.lua) – `FORCE_DISABLE_CDM_STYLING`

See [docs/CDM_LAYOUT_DISABLE_NOTES.md](CDM_LAYOUT_DISABLE_NOTES.md) for details.

---

## 8) Related Reference Docs

- [docs/COOLDOWN_SYSTEMS_COMPARISON.md](COOLDOWN_SYSTEMS_COMPARISON.md)
- [docs/COOLDOWN_MODIFICATION_AUDIT.md](COOLDOWN_MODIFICATION_AUDIT.md)
- [docs/COOLDOWN_BUFF_STYLING_ANALYSIS.md](COOLDOWN_BUFF_STYLING_ANALYSIS.md)
- [docs/NCDM_SETTINGS_INTEGRATION.md](NCDM_SETTINGS_INTEGRATION.md)
