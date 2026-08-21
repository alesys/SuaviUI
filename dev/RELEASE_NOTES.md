## 🎮 SuaviUI v0.3.27 - Tracker Taint Edition

Fixes an error storm — nearly 43,000 in a single session — coming out of the Objective
Tracker during scenarios, delves and Mythic+.

### 🔧 Fixes

- **Objective Tracker no longer taints Blizzard's own code.** SuaviUI was attaching a
  script hook directly to the Objective Tracker frame in order to apply your global
  font to it. In Midnight that marks the frame as addon-touched, so Blizzard's own
  tracker code then runs in a restricted context — and Blizzard's scenario tracker
  asks the game for your player auras on every layout pass without checking whether
  it is allowed to. The result was a flood of errors blamed on SuaviUI from a call
  stack that contained no SuaviUI code at all. The font is now applied from a frame
  SuaviUI owns, with identical timing and no side effects on Blizzard's frames.
- Two more hooks of the same kind removed from the Objective Tracker skin, which
  would have caused the same storm for anyone with tracker skinning enabled. One of
  them was redundant anyway — it was watching a button whose action SuaviUI already
  tracked safely elsewhere.

### ℹ️ Who this affected

Anyone running scenarios, delves, Torghast or Mythic+ with the global font option on
— which is the default. If your error log was filling up with aura-related messages
naming SuaviUI, this is why.

### 📦 Package

- Clean release with only runtime files (no docs/, dev/, spec/)
- Compatible with Midnight (Interface 120000-120001)

### 🙏 Credits

Special thanks to our testers: Vela, Pataz, and Ñora for their feedback and testing!
