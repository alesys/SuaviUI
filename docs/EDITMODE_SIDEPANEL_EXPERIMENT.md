# Edit Mode Sidepanel Experiment - Findings

**Date**: February 3, 2026  
**Status**: ❌ Not Feasible

## Objective
Investigate whether LibEQOL can add settings to Blizzard's native Edit Mode sidepanels for frames like `EssentialCooldownViewer` and `UtilityCooldownViewer`.

## Experiment
Created `sui_ncdm_editmode.lua` that:
1. Called `LEM:AddFrame()` on Blizzard's `EssentialCooldownViewer`
2. Called `LEM:AddFrameSettings()` with custom settings

## Result
**❌ FAILURE** - Lua error when entering Edit Mode:
```
attempt to compare a secret value
[Blizzard_EncounterWarnings/EncounterWarningsViewElements.lua]:75
```

## Root Cause
Blizzard's native frames (EssentialCooldownViewer, UtilityCooldownViewer, etc.) are **already registered** with Edit Mode by Blizzard's own system. Attempting to re-register them with LibEQOL causes conflicts.

### Key Architectural Limitation
- **LibEQOL is designed for addon-provided frames only**
- It cannot modify the settings panel of existing native frames
- Calling `LEM:AddFrame()` on an already-registered frame breaks Edit Mode

## Documentation Reference
From `BLIZZARD_EDIT_MODE_DOCUMENTATION.md`:
> Blizzard's `EditModeManagerFrame:RegisterSystemFrame()` is designed for internal frames only. **Use LibEQOL instead.**

This means:
- Blizzard frames: Use internal API (not exposed to addons)
- Addon frames: Use LibEQOL
- Mixed: Not supported

## Conclusion
**To add settings to Essential Cooldowns Edit Mode sidepanel:**

We would need **direct access to Blizzard's EditMode system**, which is:
1. ✅ Not publicly exposed
2. ✅ Not designed for addon modification
3. ✅ Protected by Blizzard's architecture

**Current best practice**: Store CDM settings in the addon's own options panel, not in Edit Mode's sidepanel.

## What We Can Do Instead
1. ✅ Keep CDM settings in `/sui options` → Cooldown section
2. ✅ Keep CDM positioning in Edit Mode (dragging/positioning works fine)
3. ✅ Use LibEQOL for our own addon frames (castbars, resource bars, etc.)

## File Status
- `sui_ncdm_editmode.lua` - Kept for documentation; early-returns with explanation
- Will not be loaded in production
