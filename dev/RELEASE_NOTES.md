## 🎮 SuaviUI v0.3.26 - Click Blocker Edition

Hunts down the "something invisible is eating my clicks" problem — a frame left shown
and mouse-enabled while drawing nothing still swallows every click over its rectangle.

### 🔧 Fixes

- **Anchoring options popover could leave the whole screen unclickable.** Its
  "click outside to close" catcher is a full-screen, invisible, mouse-enabled frame,
  and it was parented to the screen rather than to the popover — so it did not
  inherit the popover's visibility. If the popover was ever closed by any route
  other than its own close path, the catcher stayed up and silently ate every click
  on your entire UI. It now hides no matter how the popover goes away.

### ✨ New: mouse blocker diagnostic

If clicks ever die on you again, you can now find the culprit yourself instead of
disabling addons one by one:

- **`/suimouse`** — lists every region under the cursor right now, topmost first,
  with its transparency, whether it accepts clicks, its layer and its size. Anything
  invisible but still clickable is flagged in red.
- **`/suimouse 3`** — the same, sampled 3 seconds from now, so you can park the
  cursor on the dead spot first.
- **`/suimouse scan`** — sweeps every frame in the game and reports two kinds of
  blocker: frames drawn at zero opacity that still take clicks, and frames covering
  more than a quarter of the screen with clicks enabled. Sorted biggest first.

It only reports — it never disables anything, since silently switching off a frame's
mouse can break working UI or taint protected frames. Works on any addon's frames,
not just SuaviUI's.

### 📦 Package

- Clean release with only runtime files (no docs/, dev/, spec/)
- Compatible with Midnight (Interface 120000-120001)

### 🙏 Credits

Special thanks to our testers: Vela, Pataz, and Ñora for their feedback and testing!
