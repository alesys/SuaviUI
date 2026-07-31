## 🎮 SuaviUI v0.3.23 - Midnight Castbars Edition

### ✨ Major Features

- **Boss castbars work with Midnight's secret cast timing**: Midnight redacts cast start/end times on many boss units. The castbar now detects redacted timing and hands the animation to the engine (`SetTimerDuration`), so boss bars fill and drain correctly instead of freezing or running backwards. Channels drain, casts fill — verified against Blizzard's own timeline code.
- **Combat Timer moved to Edit Mode**: position, size, font, colors and border are now configured by dragging the timer in Edit Mode, with a live preview while Edit Mode is open. Existing `xOffset`/`yOffset` positions are migrated automatically on first load. The options panel keeps the enable toggle plus a "Configure in Edit Mode" button.
- **Buff/Debuff text settings moved to Edit Mode**: stack and duration text (show, size, color, anchor, X/Y offset) now live in the Edit Mode sidepanel under Buff Icons / Debuff Icons.
- **Target Marker settings moved to Edit Mode**: raid target marker (skull, cross, etc.) size and position are configured in the Edit Mode sidepanel.
- **Extra Action Button customization re-enabled**: the Extra Action Button and Zone Ability button are movable and scalable again, using a taint-safe approach — the button is anchored, never reparented, so Blizzard keeps ownership of the protected frame.

### 🔧 Fixes & Improvements

- **Spec swap no longer left settings stale**: switching specs (profile change via LibDualSpec) now refreshes every module — action bars, keybinds, castbars, cast history, custom glows, rotation assist, datapanels, combat text/timer, crosshair, character pane, chat and more. Previously many modules kept the old profile's settings until `/reload`.
- **Boss castbars appear when enabled mid-session**: enabling boss castbars now creates the bar instead of only refreshing an existing one.
- **Castbars catch casts already in progress**: a boss unit appearing mid-cast now shows the bar instead of waiting for the next cast.
- **No more visible restart on long boss casts**: the castbar trusts the API's start/end times instead of rebasing them, so a concurrent instant cast no longer resets a long boss cast.
- **Extra Action Button no longer eats clicks**: the invisible position holder had mouse input enabled, silently swallowing clicks inside its 64x64 area. Mouse handling now lives only on the mover overlay.
- **Minimap clock/coords color picker self-heals**: profiles written by older library versions stored the color in a different shape and could come back wrong or error. Both read and write paths are now sanitized.
- **Skyriding vigor bar dropdowns store the right value**: dropdowns now use radio generators mapping label to internal value, so settings like border texture no longer save the display text.
- **Castbar preview no longer resets mid-drag**: previews only restart when the simulation isn't already running, instead of resetting on every settings tick.

### 📦 Package

- Clean release with only runtime files (no docs/, dev/, spec/)
- Compatible with Midnight (Interface 120000-120001)

### 🙏 Credits

Special thanks to our testers: Vela, Pataz, and Ñora for their feedback and testing!
