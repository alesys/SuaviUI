## 🎮 SuaviUI v0.3.29 - New Modules Edition

Three new modules: nameplates, raid & party frames, and a combined bag window with
bank support. All three are **off by default**, so nothing changes until you turn them on
in `/sui` options.

### 🛠️ New

- **Nameplates.** SuaviUI nameplates drawn on top of Blizzard's plates: health bar with
  threat and role coloring (tank loose-mob warnings), name, health percent, level/elite,
  target border, glow and scale, focus marker, raid icon, and a cast bar with
  interruptible/locked colors, an interrupt-on-cooldown tint and an interrupted flash.
  Shows your debuffs plus purgeable/important enemy buffs. Friendly plates can be
  name-only or hidden. Blizzard's frame is only faded, and everything is restored when you
  disable the module.
- **Raid & Party Frames.** Secure group headers for party and raid (by group, or one
  combined frame sorted by role or name). Health and power bars, heal prediction, absorbs
  and heal absorbs, dispel highlight, debuffs (boss debuffs larger), your own HoTs,
  private aura anchors, range fade, dead/offline/AFK states, role/leader/marker/ready
  check/res/summon icons, target highlight and Clique support. Positioned through Edit
  Mode with per-layout positions and a preview with fake units. Blizzard's party and raid
  frames are hidden while the module is on.
- **Bags & Bank.** One combined bag window with categories, plus the bank and the
  Warband bank. Opens and closes in sync with Blizzard's bag keybinds and the bank NPC.
  Turning it on or off asks for a reload.

### 🔧 Under the hood

- The sell-junk routine is now shared, so the bag window can use it too.
- Profile import and profile switch refresh the new modules.

### ℹ️ Who this affects

Everyone can update safely: with the new modules left off, the addon behaves exactly
like v0.3.28. Turn them on in `/sui` to try them, and report anything odd.
