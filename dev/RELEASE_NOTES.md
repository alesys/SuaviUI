## 🎮 SuaviUI v0.3.24 - Omnium Folio Edition

Full support for Midnight's Omnium Folio (the Runes of Power tree on the expansion landing page).

### ✨ Major Features

- **Omnium datatext**: new datatext showing unspent Omnium Folio points, turning gold whenever there is actually something you can buy. Tooltip breaks down unspent points, spent points and your Omnium balance; left click opens the folio. Add it to any datapanel slot from the Character category.
- **Omnium Folio skinning**: the folio frame now wears the SuaviUI look — the ornate Midnight frame is replaced with the standard 1px SuaviUI border, and the header title and Omnium counter use your configured font. The tree artwork is left intact so the nodes still read correctly. Toggle it in Options → General & QoL → Omnium Folio.
- **Spendable Omnium alert**: an optional pulsing glow on the landing page minimap button whenever you have points ready to spend, with class color or a custom color, plus an optional chat notice. Blizzard only nudges you with a tutorial HelpTip, so this keeps working for players who disable tutorials. The glow clears as soon as you open the folio.
- **Landing page minimap button controls**: scale and X/Y offset for the expansion landing page button, configurable in the Edit Mode minimap panel. Previously it was pinned to a fixed spot.

### 🔧 Fixes & Improvements

- **The landing page minimap button is now shown by default**. In Midnight it is the entry point to the Omnium Folio, and hiding it by default left players with no obvious way in. If you prefer it hidden, turn off "Show Progress Report (Missions)" in the Edit Mode minimap panel.
- Detecting whether Omnium is actually spendable uses Blizzard's own rule: having unspent points is not enough, an affordable and purchasable node must exist. The alert no longer sticks on once your tree is maxed.
- All Omnium code is guarded for pre-Midnight clients, so nothing errors if the system is unavailable on your character.

### 📦 Package

- Clean release with only runtime files (no docs/, dev/, spec/)
- Compatible with Midnight (Interface 120000-120001)

### 🙏 Credits

Special thanks to our testers: Vela, Pataz, and Ñora for their feedback and testing!
