## 🎮 SuaviUI v0.3.25 - Secret Values Edition

A round of Midnight compatibility fixes. In 12.x the client hides more and more
information from addons ("secret values"), and several SuaviUI features were either
erroring thousands of times per session or silently falling back to grey. This
release makes them play by Midnight's rules — and, where the game allows it, get the
*correct* data back instead of a fallback.

### 🔧 Fixes

- **Cursor ring is back.** The GCD ring that follows your mouse was completely broken
  in Midnight — it errored on every single frame and never moved. It now tracks the
  cursor again, and its global cooldown sweep no longer errors in combat.
- **Buff and debuff icons on unit frames** no longer flood your error log inside
  dungeons, raids and rated PvP. Auras the client refuses to hand over are skipped
  cleanly, and the ones it does allow keep showing normally — previously a single
  hidden aura also hid every aura after it.
- **Leader and assistant icons** (crown / flag) on the target and focus frames work
  again instead of erroring whenever you were in a group.
- **Class colors are correct in instances again.** Target, target-of-target, pets and
  portrait borders were falling back to grey inside restricted content. They now show
  the real class color. Where the game genuinely will not allow it — the inline
  target-of-target text, which has to be written as coloured text rather than drawn —
  it falls back to white instead of breaking the name.
- **Raid buff checks** no longer error while scanning group members' buffs.
- **Mythic+ key list**: the party leader crown no longer errors.

### ℹ️ Known limitation (not a bug)

Inside dungeons, raids and rated PvP, Midnight marks some auras as secret and no addon
can read or display them. If a buff or debuff icon is missing there, that is the game
hiding it, not SuaviUI dropping it. Blizzard's own frames still show them because
Blizzard's code is not subject to the same restriction.

### 📦 Package

- Clean release with only runtime files (no docs/, dev/, spec/)
- Compatible with Midnight (Interface 120000-120001)

### 🙏 Credits

Special thanks to our testers: Vela, Pataz, and Ñora for their feedback and testing!
