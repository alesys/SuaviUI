# QUI vs SuaviUI: CDM Tracked Bars & Icons — Why QUI Works and We Don't

## Executive Summary

QUI's "owned" engine works reliably because it **reads from Blizzard's CDM item frames as the source of truth** (via `viewer:GetChildren()`) and **mirrors runtime data via sub-region hooks** (`hooksecurefunc` on CooldownFrame, StatusBar, FontString). It never reimplements Blizzard's `ShouldBeActive()` logic — it just asks "is this child shown?" and copies the cooldown/aura data that Blizzard already computed.

SuaviUI's approach fails because it uses the **C API only** (`GetCooldownViewerCategorySet` + `GetCooldownViewerCooldownInfo`) which returns static *configuration* data, then attempts to **manually determine what's active** via custom aura/totem detection. This reimplementation is incomplete and fragile — it misses edge cases that Blizzard's internal CDM system handles natively.

---

## The Core Problem: Data Source

### QUI's Data Pipeline (Owned Engine)

```
Blizzard CDM Viewer (alpha=0, still "shown")
  └── Item Frames (children) — Blizzard manages Show/Hide/SetCooldown
        │
        ├── child:IsShown() → "Is this active?" (Blizzard's ShouldBeActive result)
        ├── child.cooldownInfo.spellID → spell identity
        ├── hooksecurefunc(child.Cooldown, "SetCooldown", ...) → cooldown timer data
        ├── hooksecurefunc(child.StatusBar, "SetValue", ...) → bar progress (bars only)
        ├── hooksecurefunc(child.Icon, "SetTexture", ...) → icon texture
        └── hooksecurefunc(child.StackText, "SetText", ...) → charge/stack count
              │
              └── All data mirrored to addon-owned frames via pcall
```

**QUI reads the RESULT of Blizzard's computation.** It doesn't need to know HOW Blizzard determines active state — it just reads whether the child is shown and copies the visual data.

### SuaviUI's Data Pipeline (Current)

```
C_CooldownViewer.GetCooldownViewerCategorySet(TrackedBar, true)
  └── Returns cooldown IDs (static configuration list)
        │
        └── C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
              └── Returns struct: spellID, overrideSpellID, linkedSpellIDs, selfAura, etc.
                    │
                    └── SuaviUI manually checks:
                          ├── C_UnitAuras.GetPlayerAuraBySpellID(spellID) for each linked ID
                          ├── C_UnitAuras.GetUnitAuras("target", "HARMFUL|PLAYER") for debuffs
                          └── C_Totem.GetTotemInfo(slot) for totems
                                │
                                └── If ANY match found → mark as "active"
```

**SuaviUI reimplements Blizzard's ShouldBeActive() logic.** Every edge case Blizzard handles internally is a potential failure point:
- Aura IDs that don't match any configured spell IDs
- Multi-target aura tracking variations
- Cooldown-based tracking (not aura-based)
- Blizzard's special `GetAuraData()` → `SpellIDMatchesAnyAssociatedSpellIDs` path
- Timing differences (aura expired but cooldown still active)

---

## Five Key Differences

### 1. Viewer Visibility: OnUpdate Enforcer vs One-Shot

**QUI** uses a continuously running `OnUpdate` handler that checks EVERY FRAME whether any viewer's alpha was restored above 0 by Blizzard's internal code, and immediately re-zeros it:

```lua
-- QUI: cdm_spelldata.lua
alphaEnforcerFrame:SetScript("OnUpdate", function(self, dt)
    for _, viewerName in pairs(VIEWER_NAMES) do
        local viewer = _G[viewerName]
        if viewer then
            local ok, alpha = pcall(viewer.GetAlpha, viewer)
            if ok and alpha and alpha > 0 then
                viewer:SetAlpha(0)
            end
        end
    end
end)
```

This guarantees viewers are ALWAYS alpha=0 but NEVER hidden. The viewers remain `IsShown()=true`, so:
- Blizzard's `OnUpdate` keeps running on the viewers
- Item frame pools stay populated and active
- Children receive `Show()`/`Hide()`/`SetCooldown()` calls based on active state
- `viewer:GetChildren()` always returns current item frames

**SuaviUI** sets `SetAlpha(0)` once in `SetViewerHidden()` with no enforcer. When Blizzard's `UpdateShownState()` → `SetShown(true)` fires (e.g., cooldown activates while visibility="Always"), it can restore alpha. Without an enforcer, the viewer might flash briefly visible.

### 2. Active State Detection: Read vs Reimplement

**QUI** reads `blizzChild:IsShown()` — the authoritative answer from Blizzard's CDM system. If Blizzard considers a tracked bar/buff active, the child is shown. Period.

**SuaviUI** calls `C_UnitAuras.GetPlayerAuraBySpellID()` for each possible spell ID, then checks target debuffs, then checks totems. This STILL misses cases where Blizzard's internal `ShouldBeActive()` returns true but our manual check doesn't find a matching aura. Examples:
- Spells tracked by cooldown state (not aura)
- Auras applied with a different spell ID than any configured/linked ID
- Target debuffs where `SpellIDMatchesAnyAssociatedSpellIDs` uses additional associations not exposed via `linkedSpellIDs`

### 3. Runtime Data: Hook Mirroring vs No Mirroring

**QUI** hooks sub-regions of Blizzard item frames to mirror runtime data:
- `hooksecurefunc(blizzCD, "SetCooldown", ...)` → copies (start, duration) to addon-owned CooldownFrame
- `hooksecurefunc(blizzStatusBar, "SetValue", ...)` → copies value to addon-owned StatusBar
- `hooksecurefunc(blizzFontString, "SetText", ...)` → copies text to addon-owned FontString

These hooks are on **sub-regions** (CooldownFrame, StatusBar, Texture, FontString), NOT on the item frame itself. Sub-region hooks are safe because the hook wrapper is written to the sub-region's table, not the parent item frame's table.

**SuaviUI** has no hook mirroring. It tries to reconstruct runtime data from C API + aura lookups. For bars, it doesn't have access to the actual bar progress values that Blizzard computes internally.

### 4. `hooksecurefunc` on CDM Items: Not As Dangerous As We Thought

SuaviUI's MEMORY.md rule: *"NEVER hooksecurefunc Lua methods on CDM item frames"*

**This rule is overly broad.** QUI successfully uses:
- `hooksecurefunc(child, "OnActiveStateChanged", ...)` on buff icon children
- `hooksecurefunc(child, "OnUnitAuraAddedEvent", ...)` on buff icon children
- `hooksecurefunc(child.Cooldown, "SetCooldown", ...)` on CooldownFrame sub-regions
- `hooksecurefunc(child.StatusBar, "SetValue/SetMinMaxValues", ...)` on StatusBar sub-regions

**Why these are safe:**
1. `hooksecurefunc` C implementation writes a SECURE entry to the frame's table — it doesn't taint the frame
2. The hook CALLBACK runs in addon context, but that's a separate execution context from the original call
3. **The critical rule is: the hook callback must NOT write fields to the Blizzard frame.** Reading is fine. Writing to addon-owned tables is fine.

**What caused SuaviUI's taint was not the hooks themselves, but what the callbacks DID:**
- Writing `icon._someFlag = true` → taints the frame
- Writing `viewer.isHorizontal = false` → taints the viewer → cascades via shared provider
- Calling `provider:CheckBuildDisplayData()` → taints the shared provider

QUI's callbacks only: read from Blizzard frames via pcall, write to addon-owned frames/tables.

### 5. Glow Application: Wrapper Frames

**QUI (classic engine)** creates an overlay `Frame` parented to the icon and applies LibCustomGlow to the OVERLAY, not the icon:

```lua
-- QUI: classic/glows.lua
function GetGlowOverlay(icon)
    local state = glowIconState[icon]
    if not state.overlay then
        state.overlay = CreateFrame("Frame", nil, icon)
        state.overlay:SetAllPoints(icon)
        state.overlay:SetFrameLevel(icon:GetFrameLevel() + 5)
    end
    return state.overlay
end
LCG.PixelGlow_Start(overlay, color, ...)  -- LCG writes to overlay, not icon
```

**SuaviUI v0.3.11** now does the same via `GetOrCreateGlowWrapper(icon)` in customglows.lua — this was fixed.

---

## What SuaviUI Should Learn / Change

### High Priority: Fix the Data Pipeline

The C API only approach for `FetchBuffBarData()` / `FetchBuffIconData()` is fundamentally flawed. The C API returns **configuration data**, not **runtime state**. We need to read runtime state from the source of truth: Blizzard's viewer children.

**Recommended approach (following QUI's pattern):**

1. **Keep viewers at alpha=0 with an OnUpdate enforcer** — ensures viewers stay shown and children are active
2. **Read `viewer:GetChildren()` to discover item frames** — this is a C API call (safe)
3. **Read `child:IsShown()` for active state** — read-only, safe
4. **Hook sub-regions for runtime data:**
   - For icons: `hooksecurefunc(child.Cooldown, "SetCooldown", fn)` + `hooksecurefunc(child.Icon, "SetTexture", fn)`
   - For bars: `hooksecurefunc(child.Bar, "SetValue", fn)` + `hooksecurefunc(child.Bar, "SetMinMaxValues", fn)`
5. **Mirror to addon-owned frames** — all display on SuaviUI-created frames, zero Blizzard frame modification

**What this eliminates:**
- All custom aura detection code (500+ lines in FetchBuffBarData/FetchBuffIconData)
- All edge cases with linked spell IDs, override spell IDs, totem detection
- The fundamental "why aren't bars showing?" bug — because we'd be reading Blizzard's answer directly

### Medium Priority: OnUpdate Alpha Enforcer

Add a lightweight per-frame alpha check like QUI does. This prevents viewer alpha flashing and ensures children stay active even when Blizzard's `UpdateShownState` runs.

### Low Priority: Revise hooksecurefunc Rules

Update MEMORY.md to distinguish between:
- **SAFE**: `hooksecurefunc` on CDM item frame METHODS — the C implementation writes secure entries
- **SAFE**: `hooksecurefunc` on sub-regions (CooldownFrame, StatusBar, FontString, Texture)
- **DANGEROUS**: Hook callbacks that WRITE fields to Blizzard frames
- **DANGEROUS**: Direct function replacement (rawset) on Blizzard frames

---

## QUI's One Taint Risk

QUI does one thing SuaviUI strictly avoids: it overwrites `viewer.RefreshTotemData` with a pcall wrapper (cdm_spelldata.lua line 70). This is a direct Lua field write on the viewer frame. Per SuaviUI's session 4979 findings, writing to a viewer frame can cascade taint via the shared `CooldownViewerSettingsDataProvider`. QUI mitigates this because:
1. The viewers are permanently alpha=0
2. The pcall wrapper preserves the original function's behavior
3. The write happens once at initialization

This is a calculated risk that QUI takes to prevent crashes from tainted totem data. SuaviUI could consider a similar approach if totem crashes occur.

---

## Architecture Comparison Table

| Aspect | QUI (Owned Engine) | SuaviUI (Current) |
|--------|-------------------|-------------------|
| **Spell list source** | `viewer:GetChildren()` + `child.cooldownInfo` | C API: `GetCooldownViewerCategorySet` |
| **Active state source** | `child:IsShown()` (Blizzard's answer) | Manual aura/totem lookup (reimplemented) |
| **Cooldown data source** | `hooksecurefunc(child.Cooldown, "SetCooldown")` | Not mirrored; uses aura expirationTime |
| **Bar progress source** | `hooksecurefunc(child.Bar, "SetValue")` | Not mirrored; computed from aura data |
| **Texture source** | `hooksecurefunc(child.Icon, "SetTexture")` | `C_Spell.GetSpellTexture(spellID)` |
| **Viewer hiding** | `SetAlpha(0)` + OnUpdate enforcer (every frame) | `SetAlpha(0)` one-shot |
| **Frame field writes** | Zero on item frames; one viewer method override | Zero (after v0.3.11 cleanup) |
| **State storage** | Weak-keyed tables for ALL per-frame state | Weak-keyed tables (migrated in v0.3.11) |
| **Glow application** | Overlay wrapper frame (classic) / direct (owned) | Wrapper frame (v0.3.11) |
| **Data pipeline complexity** | ~200 lines (hook mirroring) | ~500 lines (manual aura detection) |
| **Edge case coverage** | Complete (reads Blizzard's result) | Incomplete (reimplements Blizzard logic) |

---

## Bottom Line

**SuaviUI is solving the wrong problem.** Instead of asking "how do I determine what's active using public APIs?", it should ask "how do I read what Blizzard already determined is active?" The answer is: the viewer children ARE the answer. Keep the viewers alpha=0 (not hidden), read from their children, hook their sub-regions, and mirror everything to addon-owned display frames. This is exactly what QUI does, and it works.
