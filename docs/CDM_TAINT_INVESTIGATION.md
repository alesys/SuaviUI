# CDM Taint Investigation & Fix Record

**Sessions:** 4891 → 4912 → 4924 → 4927
**Files modified:** `utils/sui_buffbar.lua`, `utils/cooldownmanager.lua`, `utils/cooldown_advanced.lua`
**Status:** All identified taint vectors eliminated as of session 4927.

---

## What This Document Is

This is a record for future LLM sessions working on this codebase. It explains the WoW value-based taint model as it applies to SuaviUI's CDM (Cooldown Manager) integration, documents every taint vector found across four debugging sessions, explains why each fix worked or didn't, and states the rules that must be followed going forward.

If you are reading BugSack errors involving `isActive`, `spellID`, `charges`, `hasTotem`, or `previousCooldownChargesCount` as "secret value tainted by SuaviUI" on Blizzard's CDM viewers — this document is the starting point.

---

## Background: WoW Value-Based Taint

WoW's Lua security model tracks taint **per Lua value**, not per function call or per frame. The rules:

1. **Writing** a field on a Blizzard-owned frame object from addon context taints that specific field.
   Example: `BlizzardFrame.someField = 42` from SuaviUI code → `BlizzardFrame.someField` is now "secret number tainted by SuaviUI".

2. **Reading** a tainted field from Blizzard secure code produces a "secret value" error and halts that code path.

3. **Taint cascades through writes.** If Blizzard secure code reads a tainted field and uses the result in a write (`self.otherField = taintedValue`), `otherField` also becomes tainted. This cascade propagates through the entire data pipeline.

4. **Replacing a Blizzard frame method** with an addon closure (e.g. `frame.ShouldBeShown = function(self) ... end`) taints the method field. If Blizzard calls that method from secure context, the addon closure executes in **tainted execution context**, which taints all Lua values written inside it — including fields on other frames.

5. **`hooksecurefunc` on Lua frame methods** that fire synchronously inside Blizzard's secure call chain deliver addon code into that chain. While `hooksecurefunc` itself doesn't taint the hooked function, if your hook callback writes to any Blizzard frame field, those writes happen in tainted context.

6. **C Timer deferral does not help.** `C_Timer.After(0, function() frame.field = value end)` still runs in addon (tainted) context when the timer fires. The deferral only affects timing, not taint origin.

---

## The CDM Data Pipeline (Blizzard internals)

Understanding this is essential to knowing which writes are dangerous.

```
CooldownViewer OnUpdate
  └─ RefreshActive()
       └─ SetIsActive(frame, true/false)
            └─ frame.isActive = value          ← field write on CDM item frame
            └─ OnActiveStateChanged(frame)

CooldownViewer RefreshLayout()
  └─ Layout()
       └─ reads viewer.isHorizontal            ← field read on CDM viewer frame
       └─ reads viewer.layoutFramesGoingUp
  └─ RefreshData()
       └─ reads provider display data          ← reads from shared data provider tables
       └─ RefreshSpellChargeInfo()
            └─ frame.charges = value           ← field write on CDM item frame
            └─ frame.previousCooldownChargesCount = value
       └─ RefreshAuraInstance()
            └─ SpellIDMatchesAnyAssociatedSpellIDs()
                 └─ reads frame.spellID        ← field read on CDM item frame
       └─ RefreshTotemData()
            └─ frame.hasTotem = value          ← field write

CooldownViewerSettingsDataProvider:GetOrderedCooldownIDsForCategory()
  └─ self:CheckBuildDisplayData()              ← writes to shared provider tables
       └─ (taints provider data if called from addon context)
```

**Key insight:** All four CDM viewers (`BuffBarCooldownViewer`, `BuffIconCooldownViewer`, `EssentialCooldownViewer`, `UtilityCooldownViewer`) share the same data provider. Tainting it once taints all four simultaneously. This is why errors appeared on all viewers at the same time.

---

## Taint Vectors — Chronological

### Vector 1 (session 4891): `hooksecurefunc` on `OnActiveStateChanged`

**Location:** `utils/cooldownmanager.lua`, `GetBuffIconFrames()` and `GetBuffBarFrames()`

**What it did:** Each time a new CDM item frame was discovered in the pool, the code installed a per-frame hook:
```lua
hooksecurefunc(child, "OnActiveStateChanged", StateTracker.MarkBuffIconsDirty)
```

**Why it tainted:** `OnActiveStateChanged` is called synchronously inside:
```
OnUpdate → RefreshActive → SetIsActive → OnActiveStateChanged
```
This entire chain is Blizzard secure code. When the hook fires, `MarkBuffIconsDirty` runs inside that chain from addon context, tainting CDM item frame fields that Blizzard subsequently reads.

**Fix:** Removed the `HookState` table and all `hooksecurefunc(child/frame, "OnActiveStateChanged", ...)` installations. The dirty-marking was an optimization; `UNIT_AURA`-driven refresh covers the same use case without entering the secure chain.

---

### Vector 2 (session 4912): `viewer:Show()` + `ShouldBeShown` override

**Location:** `utils/sui_buffbar.lua`, `SetViewerHidden()` function and `Initialize()`

**What it did:** A proposed fix to keep the CDM viewer's item pool live added:
1. `viewer:Show()` inside `SetViewerHidden(true)` after `SetAlpha(0)`
2. Overriding `BuffBarCooldownViewer.ShouldBeShown` with an addon closure

**Why viewer:Show() tainted:** Calling `Show()` on `BuffBarCooldownViewer` triggers:
```
OnShow → RefreshLayout → RefreshData
```
Running this from addon context (even inside `pcall`) executes Blizzard code in tainted context, tainting all fields it writes.

**Why ShouldBeShown override tainted:** Writing `viewer.ShouldBeShown = function(self) ... end` replaces the Blizzard method field with an addon closure. Blizzard's `UpdateShownState()` calls `self:ShouldBeShown()` from secure context — executing the addon closure inside that secure call taints the entire `UpdateShownState → SetShown` chain.

**Fix:** Reverted both. `SetViewerHidden` uses `SetAlpha(0/1)` and `EnableMouse(false/false)` only. The viewer's item pool stays live because the viewer is never `Hide()`d; only its alpha is zeroed. Blizzard's `UpdateShownState()` may call `Hide()` on the viewer if CDM visibility settings are "Hidden" — that's acceptable because the pool is still retained and re-populated when the viewer is shown again.

**Also fixed in this pass:**
- Wrong API name: `GetCooldownInfoByCooldownID` does not exist → correct name is `GetCooldownViewerCooldownInfo`
- `linkedSpellID` is a scalar in older code but is actually `linkedSpellIDs` (a table) in the current CDM API — must iterate with `ipairs`

---

### Vector 3 (session 4924): `isHorizontal` write from deferred C_Timer callback

**Location:** `utils/sui_buffbar.lua`, `Initialize()` → legacy Layout hook block

**What it did:**
```lua
hooksecurefunc(BuffBarCooldownViewer, "Layout", function()
    C_Timer.After(0, function()
        BuffBarCooldownViewer.isHorizontal = false   -- ← THIS
        BuffBarCooldownViewer.layoutFramesGoingRight = true
        BuffBarCooldownViewer.layoutFramesGoingUp = false
        LayoutBuffBars()
    end)
end)
```

**Why it tainted:** Even though the write is deferred via `C_Timer.After`, when the timer fires it runs in addon (tainted) execution context. `isHorizontal` is read by Blizzard at `CooldownViewer.lua:1781-1787` inside `Layout()`. The cascade:
```
viewer.isHorizontal (tainted) → read in Layout()
→ itemContainerFrame fields tainted
→ RefreshData() reads tainted container fields
→ writes tainted values to isActive / charges / spellID / hasTotem
   on ALL four CDM viewers simultaneously
```

**Fix:** Removed the hook entirely. `USE_CUSTOM_BARS = true` renders bars into `customContainer` (SuaviUI-owned frames). The CDM viewer's layout direction is completely irrelevant. The hook served no purpose in the custom bars path.

**Note on other `isHorizontal` writes in the file:** Other writes to `BuffBarCooldownViewer.isHorizontal` exist but are all guarded by `if not USE_CUSTOM_BARS` or the `else` branch of `IsCustomBarsActive()`. Since `USE_CUSTOM_BARS = true`, they do not execute.

---

### Vector 4 (session 4924 attempted / session 4927 completed): Provider `CheckBuildDisplayData` + `GetOrderedCooldownIDsForCategory`

**Location:** `utils/sui_buffbar.lua`, `GetViewerCooldownIDs()` and `GetIconViewerCooldownIDs()`

**What the code did (before fix):**
```lua
local function GetViewerCooldownIDs()
    -- Path 1: provider
    pcall(function()
        local provider = CooldownViewerSettings:GetDataProvider()
        if provider.CheckBuildDisplayData then
            provider:CheckBuildDisplayData()                           -- explicit call
        end
        local result = provider:GetOrderedCooldownIDsForCategory(     -- implicit call
            Enum.CooldownViewerCategory.TrackedBar, true
        )
        ...
    end)
    -- Path 2: C API fallback
    ...
end
```

**Why `CheckBuildDisplayData()` taints:** This method writes to the shared CDM data provider's internal tables from addon (tainted) context. The provider is shared across all four CDM viewers. Blizzard's `RefreshData()` reads the tainted provider tables and writes tainted values into item frame fields (`isActive`, `spellID`, `charges`, `hasTotem`) on all four viewers simultaneously.

**Session 4924 fix (incomplete):** Removed the explicit `provider:CheckBuildDisplayData()` call. This had no effect on session 4927 errors because:

**`GetOrderedCooldownIDsForCategory` calls `CheckBuildDisplayData` internally.** From Blizzard source `CooldownViewerSettingsDataProvider.lua:243`:
```lua
function CooldownViewerSettingsDataProviderMixin:GetOrderedCooldownIDsForCategory(category, allowUnknown)
    ...
    self:CheckBuildDisplayData()    -- line 243, always called
    ...
end
```

Calling `GetOrderedCooldownIDsForCategory` from addon context is functionally identical to calling `CheckBuildDisplayData` directly. Session 4927 had the same error set as session 4924 because the root cause wasn't actually removed.

**Session 4927 fix (complete):** Removed the ENTIRE provider path from both functions. Both now use C API only:
```lua
local function GetViewerCooldownIDs()
    local ok, result = pcall(function()
        if C_CooldownViewer then
            if C_CooldownViewer.GetCooldownViewerCategorySet then
                return C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBar, true)
            elseif C_CooldownViewer.GetCooldownIDsForCategory then
                return C_CooldownViewer.GetCooldownIDsForCategory(Enum.CooldownViewerCategory.TrackedBar)
            end
        end
        return nil
    end)
    if ok and type(result) == "table" then return result end
    return {}
end
```

The C API functions have `SecretArguments="AllowedWhenUntainted"` and return a flat list of configured spell IDs without touching any Lua data structures on CDM frames. Safe from addon context.

---

### Vector 5 (session 4924): `SPELL_UPDATE_COOLDOWN` writes during combat

**Location:** `utils/cooldown_advanced.lua`, `HookCooldownUpdates()`

**What it did:** The `SPELL_UPDATE_COOLDOWN` handler (fires every GCD, ~every 1.5s in combat) called `RefreshUtilityDimming()` and `RefreshViewerSwipeColors()`, which write `SetSwipeColor` and `SetAlpha` to CDM item frames.

**Why it risks taint:** High-frequency writes to CDM frames during combat increase the probability that a write happens in a context that Blizzard's combat system subsequently reads. `SPELL_UPDATE_COOLDOWN` fires from Blizzard's combat event system — the execution context at that point may already be partially tainted by combat lockdown interactions.

**Fix:** Added `if InCombatLockdown() then return end` as the first check in both `SPELL_UPDATE_COOLDOWN` and `UNIT_AURA` branches. Dimming/swipe colors are refreshed out-of-combat on the next relevant event.

---

## Rules Going Forward

These rules must be followed for any new code that touches Blizzard CDM viewer frames:

### 1. Never write to CDM viewer frame fields from addon context
```lua
-- FORBIDDEN:
BuffBarCooldownViewer.isHorizontal = false
BuffBarCooldownViewer.layoutFramesGoingRight = true
viewer.someField = value

-- SAFE: reading is fine
local isH = BuffBarCooldownViewer.isHorizontal ~= false
```
This applies regardless of deferral — `C_Timer.After(0, ...)` does not change the execution context of the write.

### 2. Never call any method on `CooldownViewerSettings:GetDataProvider()` from addon code
```lua
-- FORBIDDEN:
local provider = CooldownViewerSettings:GetDataProvider()
provider:CheckBuildDisplayData()
provider:GetOrderedCooldownIDsForCategory(...)
provider:AnyOtherMethod()

-- SAFE: C API only
C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
C_CooldownViewer.GetCooldownIDsForCategory(category)
C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
```

### 3. Never replace a Blizzard frame method field with an addon closure
```lua
-- FORBIDDEN:
viewer.ShouldBeShown = function(self) ... end
viewer.GetScaledRect = function(self) ... end

-- SAFE: hooksecurefunc on a function name (not a frame method that fires in secure chain)
-- RISKY: hooksecurefunc on frame methods that fire inside OnUpdate/RefreshLayout chains
```

### 4. Never call Show() on CDM viewers from addon context
```lua
-- FORBIDDEN:
viewer:Show()

-- SAFE: alpha only
pcall(function() viewer:SetAlpha(0) end)
pcall(function() viewer:EnableMouse(false) end)
-- Blizzard's UpdateShownState() handles Show/Hide transitions
```

### 5. Gate all CDM frame writes with InCombatLockdown() in high-frequency event handlers
```lua
-- In SPELL_UPDATE_COOLDOWN, UNIT_AURA, etc.:
if InCombatLockdown() then return end
```

### 6. Use module-level tables for hook-guard flags, never frame fields
```lua
-- FORBIDDEN:
frame._myHookInstalled = true

-- SAFE:
local hookedFrames = setmetatable({}, { __mode = "k" })
hookedFrames[frame] = true
```

---

## Data Flow for FetchBuffBarData() (current safe implementation)

```
FetchBuffBarData()
│
├─ PATH 1 (primary): viewer:GetItemFrames()
│   Reads: item:IsShown(), item:GetCooldownID(), item.layoutIndex, item:GetSpellID()
│   Safe: reads only, no writes. Fails gracefully if method doesn't exist.
│
├─ PATH 2 (primary): viewer.itemFramePool:EnumerateActive()
│   Reads: frame.cooldownID, frame.layoutIndex
│   Safe: reads only. Pool stays live because viewer uses SetAlpha(0) not Hide().
│   Note: EnumerateActive() guarantees active frames — do NOT check frame.isActive again.
│
└─ PATH 3 (fallback): GetViewerCooldownIDs() → C API only
    Uses: C_CooldownViewer.GetCooldownViewerCategorySet / GetCooldownIDsForCategory
    Safe: C API, no Lua data structure writes.
    Then: aura lookup (C_UnitAuras, C_Spell) acts as active filter.
    Used when: pool is empty (viewer hidden by Blizzard due to visibility settings).
```

---

## Session Error Cross-Reference

| Session | Errors seen | Root cause | Fixed in |
|---------|-------------|------------|----------|
| 4891 | `isActive`, `charges`, `wasOnGCDLookup`, `spellID` tainted on Essential/BuffIcon | `OnActiveStateChanged` hooks in secure chain | 4891 |
| 4912 | New `OnShow → RefreshData` taint; `ShouldBeShown` closure taint | `viewer:Show()` + method override introduced as fix | 4912 (reverted) |
| 4924 | All 5 fields tainted on all 4 viewers | `isHorizontal` write + explicit `CheckBuildDisplayData()` + combat writes | 4924 (partial) |
| 4927 | Same 5 fields, same 4 viewers — identical to 4924 | `GetOrderedCooldownIDsForCategory` implicitly calls `CheckBuildDisplayData()` | 4927 (complete) |

---

## Blizzard Source References

These files in `C:\Users\rolf\Documents\WOWLibs\wow-ui-source` are the ground truth:

- `Interface\AddOns\Blizzard_CooldownViewer\CooldownViewer.lua` — `RefreshLayout`, `Layout`, `RefreshData`, `SetIsActive`, `OnActiveStateChanged`, reads `isHorizontal` at line 1781-1787
- `Interface\AddOns\Blizzard_CooldownViewer\CooldownViewerSettingsDataProvider.lua` — `GetOrderedCooldownIDsForCategory` (line 230), `CheckBuildDisplayData` called at line 243
- `Interface\AddOns\Blizzard_CooldownViewer\CooldownViewerItemData.lua` — `SpellIDMatchesAnyAssociatedSpellIDs`, `RefreshAuraInstance`, `RefreshTotemData`, `RefreshSpellChargeInfo`
- `Interface\FrameXML\EditModeSystemTemplates.lua` — `EditModeCooldownViewerSystemMixin:OnEditModeExit()` calls `SetIsEditing(false)` which triggers `RefreshLayout` + `UpdateShownState`
