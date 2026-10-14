## 🎮 SuaviUI v0.3.28 - Patch 12.1.5 Edition

Patch 12.1.5 removed Blizzard's deprecated item API aliases. Without this release the
character panel, bag item levels, loot frames and alerts throw "attempt to call a nil
value" the moment you open them.

### 🔧 Fixes

- **12.1.5 compatibility.** Every remaining call to the retired globals
  (`GetItemInfo`, `GetDetailedItemLevelInfo`, `GetItemInfoInstant`,
  `GetItemQualityColor`, `GetItemGem`) now goes through the `C_Item` namespace.
  Affected: character panel item names and item levels, equipment flyout, bag item
  levels, loot roll frames, loot/alert quality colors, datatext quality colors.
- **Interface version bumped to 120105** so the addon no longer shows as out of date.
- **Objective Tracker taint, round two.** The UI Hider was writing a bookkeeping flag
  directly onto Blizzard's `ObjectiveTrackerFrame` (and onto `GameTimeFrame`,
  `TalkingHeadFrame` and `StatusTrackingBarManager`). In Midnight a tainted key on a
  Blizzard frame table is enough to make its whole update chain run restricted, which
  kept the "Auras cannot be accessed when secret" storm alive for anyone hiding the
  tracker. The flags now live in an addon-owned table.
- **Loot roll click blocker.** Hiding Blizzard's roll frames leaked a container slot on
  every roll, growing an invisible 256px-wide wall that ate clicks. The slot is now
  handed back through Blizzard's own `GroupLootContainer_RemoveFrame`, and the container
  no longer accepts mouse input (it draws nothing).
- **Tooltip forbidden-frame crash.** Walking a frame's parents could hit a forbidden
  frame (`PingListenerFrame`) and die with "Attempt to access forbidden object". The walk
  now stops at forbidden frames.

### 🛠️ New

- `/suitaint` — audits the Objective Tracker chain with `issecurevariable()` and names
  which field is tainted and by whom. Run it inside the scenario while the error fires;
  taint clears on reload.

### ℹ️ Who this affected

Everyone on 12.1.5. Update before opening the character panel or your bags.
