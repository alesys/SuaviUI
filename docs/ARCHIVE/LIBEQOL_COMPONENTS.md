# LibEQOL Usage Audit (SuaviUI)

**Scope:** This list is based on code search for LibEQOL/LEM usage (LibEQOLEditMode-1.0, LEM:AddFrame, LEM:AddFrameSettings) across SuaviUI. Components listed under “Not on LibEQOL” have **no LibEQOL registration calls found** in their modules.

---

## ✅ Components Registered with LibEQOL (LEM)

These components explicitly call LEM:AddFrame and LEM:AddFrameSettings.

- **Unit Frames**
  - Registration module: [utils/unitframes_editmode.lua](utils/unitframes_editmode.lua)
  - Uses LEM for frame registration, sidebar settings, drag predicates

- **Castbars (Player/Target/Focus/Boss)**
  - Registration module: [utils/castbar_editmode.lua](utils/castbar_editmode.lua)
  - Mixin registration: [utils/CastbarMixin.lua](utils/CastbarMixin.lua)

- **Extra Action Button & Zone Ability (Holder Frames)**
  - Registration module: [utils/actionbars_editmode.lua](utils/actionbars_editmode.lua)

---

## ❌ Components Not on LibEQOL (No LEM Registration Found)

These components do **not** use LibEQOL for Edit Mode registration and rely on custom positioning, movers, or Blizzard-managed frames.

### Action Bars (Core Bars)
- Main action bars, pet bar, stance bar, micro menu, bags bar
- Module: [utils/sui_actionbars.lua](utils/sui_actionbars.lua)

### Cooldown Display Manager (CDM)
- Essential/Utility/Buff Icon/Buff Bar viewers
- Modules: [utils/sui_ncdm.lua](utils/sui_ncdm.lua), [utils/cooldownmanager.lua](utils/cooldownmanager.lua)

### Cooldown System (Global)
- Cooldown visuals, fonts, swipes, effects
- Modules: [utils/cooldown_editmode.lua](utils/cooldown_editmode.lua), [utils/cooldownswipe.lua](utils/cooldownswipe.lua), [utils/cooldown_fonts.lua](utils/cooldown_fonts.lua), [utils/cooldown_icons.lua](utils/cooldown_icons.lua), [utils/cooldown_advanced.lua](utils/cooldown_advanced.lua), [utils/cooldowneffects.lua](utils/cooldowneffects.lua)

### Custom Trackers
- Custom items/spells/buffs trackers
- Module: [utils/sui_customtrackers.lua](utils/sui_customtrackers.lua)

### Buff Bar
- Buff bar display system
- Module: [utils/sui_buffbar.lua](utils/sui_buffbar.lua)

### Minimap & Datatexts
- Minimap skinning and datatext panels
- Modules: [utils/suicore_minimap.lua](utils/suicore_minimap.lua), [utils/sui_datatexts.lua](utils/sui_datatexts.lua), [utils/sui_datapanels.lua](utils/sui_datapanels.lua)

### Skyriding HUD
- Skyriding/dragonriding UI
- Module: [utils/sui_skyriding.lua](utils/sui_skyriding.lua)

### Rotation Assist
- Suggested ability icon
- Module: [utils/sui_rotationassist.lua](utils/sui_rotationassist.lua)

### Chat & Tooltips
- Chat styling and tooltip adjustments
- Modules: [utils/sui_chat.lua](utils/sui_chat.lua), [utils/sui_tooltips.lua](utils/sui_tooltips.lua)

### Character/Inspect/Combat/QoL
- Character panel skinning, inspection, combat text, misc QoL
- Modules: [utils/sui_character.lua](utils/sui_character.lua), [utils/sui_inspect.lua](utils/sui_inspect.lua), [utils/sui_combattext.lua](utils/sui_combattext.lua), [utils/sui_qol.lua](utils/sui_qol.lua)

### Misc UI Components
- Crosshair/reticle, key trackers, dungeon UI, timers, raid buffs, salvage, spell scanner
- Modules: [utils/sui_crosshair.lua](utils/sui_crosshair.lua), [utils/sui_reticle.lua](utils/sui_reticle.lua), [utils/sui_key_tracker.lua](utils/sui_key_tracker.lua), [utils/sui_dungeon_data.lua](utils/sui_dungeon_data.lua), [utils/sui_dungeon_teleport.lua](utils/sui_dungeon_teleport.lua), [utils/sui_mplus_timer.lua](utils/sui_mplus_timer.lua), [utils/sui_raidbuffs.lua](utils/sui_raidbuffs.lua), [utils/sui_quicksalvage.lua](utils/sui_quicksalvage.lua), [utils/sui_spellscanner.lua](utils/sui_spellscanner.lua)

---

## 🔄 Components That Should Be Migrated to LibEQOL

These components would benefit from LibEQOL integration to provide standardized Edit Mode features (drag predicates, visual overlays, reset controls, settings sidebar).

### High Priority (User-Facing Movable UI)

- **Cooldown Display Manager (CDM) Viewers**
  - Essential/Utility/Buff Icon/Buff Bar viewers are manually positioned
  - Module: [utils/sui_ncdm.lua](utils/sui_ncdm.lua), [utils/cooldownmanager.lua](utils/cooldownmanager.lua)
  - Benefit: Consistent Edit Mode experience with drag predicates and visual feedback

- **Buff Bar**
  - Custom buff display system with manual positioning
  - Module: [utils/sui_buffbar.lua](utils/sui_buffbar.lua)
  - Benefit: Drag predicates, reset controls, Edit Mode integration

- **Custom Trackers**
  - Custom item/spell/buff tracker frames
  - Module: [utils/sui_customtrackers.lua](utils/sui_customtrackers.lua)
  - Benefit: Per-tracker Edit Mode controls and visual overlays

- **Rotation Assist**
  - Suggested ability icon frame
  - Module: [utils/sui_rotationassist.lua](utils/sui_rotationassist.lua)
  - Benefit: Edit Mode positioning with drag predicates

- **Skyriding HUD**
  - Dragonriding UI elements
  - Module: [utils/sui_skyriding.lua](utils/sui_skyriding.lua)
  - Benefit: Modern Edit Mode positioning controls

### Medium Priority (Utility UI)

- **Datatexts & Data Panels**
  - Datatext panels with custom positioning
  - Modules: [utils/sui_datatexts.lua](utils/sui_datatexts.lua), [utils/sui_datapanels.lua](utils/sui_datapanels.lua)
  - Benefit: Standardized Edit Mode controls

- **Key Tracker**
  - Mythic+ key tracking display
  - Module: [utils/sui_key_tracker.lua](utils/sui_key_tracker.lua)
  - Benefit: Edit Mode integration for user positioning

- **M+ Timer**
  - Mythic+ dungeon timer display
  - Module: [utils/sui_mplus_timer.lua](utils/sui_mplus_timer.lua)
  - Benefit: Drag predicates and visual overlays

- **Crosshair/Reticle**
  - Combat crosshair/reticle display
  - Modules: [utils/sui_crosshair.lua](utils/sui_crosshair.lua), [utils/sui_reticle.lua](utils/sui_reticle.lua)
  - Benefit: Edit Mode positioning controls

### Low Priority (Consider Migration)

- **Raid Buffs Display**
  - Raid buff tracker
  - Module: [utils/sui_raidbuffs.lua](utils/sui_raidbuffs.lua)
  - Benefit: Edit Mode integration if user-positionable

### Not Recommended for Migration

- **Action Bars (Core Bars)**: Already integrated with Blizzard Edit Mode; custom LibEQOL wrapper may create conflicts
- **Minimap**: Skinning-only module; positioning managed by Blizzard
- **Chat & Tooltips**: Styling/anchor systems; not traditional movable frames
- **Character/Inspect/Combat Text**: Blizzard-managed or styling-only features
- **Cooldown System (Global)**: Font/swipe/effect styling, not frame positioning

---

## Notes

- LibEQOL usage is currently limited to unit frames, castbars, and the Extra Action/Zone Ability holder frames.
- No other modules in SuaviUI were found to call LEM:AddFrame or LEM:AddFrameSettings.
- Migration priority is based on user interaction frequency, positioning flexibility needs, and Edit Mode feature benefit.
- High priority items are all user-facing movable UI elements that would benefit most from LibEQOL's drag predicates, visual overlays, and standardized Edit Mode integration.
