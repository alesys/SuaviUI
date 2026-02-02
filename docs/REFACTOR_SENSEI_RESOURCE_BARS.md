# SuaviUI Resource Bars Refactor: Adopting SenseiClassResourceBar Architecture

## Executive Summary

This document analyzes replacing SuaviUI's monolithic resource bar implementation (~2900 lines in `suicore_resourcebars.lua`) with the modular, mixin-based architecture from **SenseiClassResourceBar**.

**Goal:** Adopt Sensei's proven architecture while preserving SuaviUI's unique features and settings.

---

## 1. Current State Analysis

### SuaviUI Resource Bars (`suicore_resourcebars.lua`)

**File Size:** ~2863 lines (monolithic)

**Bar Types:**
| Bar | Purpose | Status |
|-----|---------|--------|
| `powerBar` | Primary class resource (Mana, Rage, Energy, etc.) | ✅ Fully implemented |
| `secondaryPowerBar` | Secondary resources (Combo Points, Holy Power, Chi, etc.) | ✅ Fully implemented |
| `tertiaryPowerBar` | Tertiary resources (Ebon Might for Aug Evoker) | ✅ Implemented (limited) |

**Key Features:**
- ✅ Power-type-aware coloring (25+ power colors defined)
- ✅ Class-specific resource detection (Druid forms, DK spec runes)
- ✅ Fragmented power display (Runes with individual cooldown timers)
- ✅ Tick marks for segmented resources
- ✅ Integration with CDM (Cooldown Manager) viewers
- ✅ Edit Mode with drag positioning and nudge buttons
- ✅ Vertical/Horizontal orientation auto-detection
- ✅ Align-to and width-sync features (Essential/Utility CDM)
- ✅ Stagger level colors for Brewmaster Monk
- ✅ Soul Shard fragment display (Destruction Warlock)

**Architecture Issues:**
- ❌ Monolithic file - hard to maintain
- ❌ Tight coupling between bar creation, updating, and positioning logic
- ❌ No mixin inheritance - code duplication between bar types
- ❌ Mixed concerns (event handling, UI creation, configuration all intertwined)

### SenseiClassResourceBar Architecture

**File Structure:**
```
SenseiClassResourceBar/
├── SenseiClassResourceBar.toc
├── SenseiClassResourceBar.xml        # Load order
├── SenseiClassResourceBar.lua        # Factory + initialization
├── SenseiClassResourceBarSettings.lua # DB initialization
├── Bars/
│   ├── Abstract/
│   │   ├── Bar.lua                   # BarMixin (1350 lines base)
│   │   └── PowerBar.lua              # PowerBarMixin (power-specific)
│   ├── HealthBar.lua                 # HealthBarMixin
│   ├── PrimaryResourceBar.lua        # Primary resource
│   ├── SecondaryResourceBar.lua      # Secondary resource
│   └── TertiaryResourceBar.lua       # Tertiary resource
├── Resources/
│   ├── TipOfTheSpear.lua             # Hunter-specific tracking
│   ├── Whirlwind.lua                 # Warrior-specific tracking
│   └── ...
├── Settings/
│   ├── HealthAndPowerColorSettings.lua
│   └── SettingsLoader.lua            # LibEQOL integration
└── Locales/
```

**Key Patterns:**
1. **Mixin Inheritance:** `BarMixin → PowerBarMixin → [Specific]BarMixin`
2. **Factory Pattern:** Bars registered declaratively, instantiated at ADDON_LOADED
3. **Per-Layout Settings:** `SenseiClassResourceBarDB[dbName][layoutName]`
4. **Event-Driven:** Each bar registers its own events via mixin
5. **Separation of Concerns:** Settings, resources, bars are distinct modules

---

## 2. Feature Comparison Matrix

| Feature | SuaviUI Current | Sensei | Keep/Adopt |
|---------|-----------------|--------|------------|
| **Health Bar** | ❌ (via Unit Frames) | ✅ Dedicated | ⚠️ Evaluate later |
| **Primary Power** | ✅ | ✅ | KEEP |
| **Secondary Power** | ✅ | ✅ | KEEP |
| **Tertiary Power** | ✅ (limited) | ✅ | ADOPT expansion |
| **Fragmented Runes** | ✅ (with timers) | ✅ | KEEP SUI impl |
| **Stagger Colors** | ✅ (3-tier dynamic) | ❌ | KEEP |
| **Soul Shard Decimals** | ✅ | ❌ | KEEP |
| **CDM Width Sync** | ✅ | ❌ | KEEP |
| **CDM Align-To** | ✅ | ❌ | KEEP |
| **Edit Mode Nudge** | ✅ | ❌ (LibEQOL drag) | KEEP |
| **Orientation Auto** | ✅ | ❌ | KEEP |
| **Standalone Mode** | ✅ | ❌ | KEEP |
| **Power Colors UI** | ✅ (25+ colors) | ✅ (simpler) | KEEP |
| **Per-Layout Settings** | ❌ | ✅ | ADOPT |
| **Mixin Architecture** | ❌ | ✅ | ADOPT |
| **Modular Files** | ❌ | ✅ | ADOPT |

---

## 3. Settings Structure Analysis

### Current SuaviUI Settings (`SuaviUI.db.profile`)

```lua
powerBar = {
    enabled           = true,
    autoAttach        = false,
    standaloneMode    = false,
    attachTo          = "EssentialCooldownViewer",
    height            = 8,
    borderSize        = 1,
    offsetY           = -204,
    offsetX           = 0,
    width             = 326,
    useRawPixels      = true,
    texture           = "Suavi v5",
    colorMode         = "power",
    usePowerColor     = true,
    useClassColor     = false,
    customColor       = { 0.2, 0.6, 1, 1 },
    showPercent       = true,
    showText          = true,
    textSize          = 16,
    textX             = 1,
    textY             = 3,
    textUseClassColor = false,
    textCustomColor   = { 1, 1, 1, 1 },
    bgColor           = { 0.078, 0.078, 0.078, 1 },
    showTicks         = false,
    tickThickness     = 2,
    tickColor         = { 0, 0, 0, 1 },
    alignTo           = "none",
    widthSync         = "none",
    snapGap           = 5,
    orientation       = "HORIZONTAL",
}

secondaryPowerBar = { ... similar ... }
tertiaryPowerBar = { ... similar ... }

powerColors = {
    rage = { 1.00, 0.00, 0.00, 1 },
    energy = { 1.00, 1.00, 0.00, 1 },
    -- ... 25+ power colors
    useStaggerLevelColors = true,
}
```

### Sensei Settings (`SenseiClassResourceBarDB`)

```lua
SenseiClassResourceBarDB = {
    ["PrimaryResourceBarDB"] = {
        ["Default"] = {
            point = "CENTER",
            x = 0, y = -50,
            width = 300, height = 20,
            showText = true,
            -- ...
        },
        ["Raid Layout"] = { ... },
    },
    ["_Settings"] = {
        ["PowerColors"] = { ... },
        ["HealthColors"] = { ... },
    },
}
```

### Migration Strategy for Settings

| SuaviUI Setting | Migration |
|-----------------|-----------|
| `enabled` | KEEP (add to mixin) |
| `standaloneMode` | KEEP (SuaviUI-specific) |
| `autoAttach` | DEPRECATE (use alignTo) |
| `attachTo` | DEPRECATE (use alignTo) |
| `alignTo` | KEEP (SuaviUI-specific for CDM integration) |
| `widthSync` | KEEP (SuaviUI-specific for CDM integration) |
| `useRawPixels` | KEEP (pixel-perfect scaling) |
| `orientation` | KEEP (add AUTO inherit from CDM) |
| All others | KEEP with mixin refactor |

**Settings that remain SuaviUI-specific (NOT in Sensei):**
- `standaloneMode` - Visibility independent of CDM
- `alignTo` / `widthSync` - CDM integration
- `useRawPixels` - Pixel-perfect mode
- `snapGap` - CDM snapping gap
- `showFragmentedPowerBarText` - Rune timer display

---

## 4. Proposed Refactor Plan

### Phase 1: Architectural Foundation (Low Risk)

**Goal:** Create mixin structure without changing user-facing behavior

**New File Structure:**
```
utils/
├── resourcebars/
│   ├── init.lua                      # Module loader
│   ├── mixins/
│   │   ├── BarMixin.lua              # Base bar (frame creation, border, bg)
│   │   └── PowerBarMixin.lua         # Power-specific (events, colors)
│   ├── bars/
│   │   ├── PrimaryPowerBar.lua       # Primary implementation
│   │   ├── SecondaryPowerBar.lua     # Secondary + fragmented
│   │   └── TertiaryPowerBar.lua      # Tertiary (Ebon Might, etc.)
│   └── resources/
│       ├── detection.lua             # GetPrimaryResource, GetSecondaryResource
│       ├── colors.lua                # GetResourceColor, power colors
│       └── fragmented.lua            # Rune display logic
```

**Tasks:**
1. Create `resourcebars/` directory structure
2. Extract `BarMixin` with common frame creation logic
3. Extract `PowerBarMixin` for power-specific event handling
4. Create bar factory with registration pattern
5. **Keep `suicore_resourcebars.lua` as compatibility shim** during transition

### Phase 2: Settings Preservation (Medium Risk)

**Goal:** Maintain full backwards compatibility with existing user settings

**Tasks:**
1. Keep settings path unchanged: `SuaviUI.db.profile.powerBar`, etc.
2. Add migration function for any renamed/restructured settings
3. Implement `ApplyLayout()` pattern from Sensei for live updates
4. **DO NOT adopt per-layout settings yet** - SuaviUI uses AceDB profiles

### Phase 3: Feature Parity (Medium Risk)

**Goal:** Ensure all existing features work with new architecture

**Critical Features to Preserve:**
1. **CDM Integration** (`alignTo`, `widthSync`) - SuaviUI-specific, not in Sensei
2. **Fragmented Runes** with individual cooldown timers
3. **Stagger dynamic colors** (Light/Moderate/Heavy)
4. **Soul Shard decimal display** for Destruction
5. **Edit Mode** with nudge buttons
6. **Orientation AUTO** inheriting from CDM

### Phase 4: Code Cleanup (Low Risk)

**Goal:** Remove old monolithic file, finalize new structure

**Tasks:**
1. Delete `suicore_resourcebars.lua` (after full validation)
2. Update `utils.xml` to load new module structure
3. Update all references in `sui_options.lua`
4. Full testing across all classes/specs

---

## 5. Risk Assessment

### High Risk Areas

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking user settings | Users lose customizations | Keep same DB path, add migration |
| Rune timer regression | DK players upset | Keep existing rune logic unchanged |
| CDM sync breaks | Bars misaligned with cooldowns | Test extensively with both layouts |
| Combat lockdown issues | ADDON_ACTION_BLOCKED | Audit all frame modifications |

### What NOT to Change

1. **Settings DB paths** - Users have existing profiles
2. **Power color keys** - `powerColors.rage`, `powerColors.energy`, etc.
3. **Fragmented rune logic** - Already works well
4. **CDM integration** - SuaviUI-unique feature, don't remove
5. **Edit Mode behavior** - Users expect current drag/nudge UX

### What to Adopt from Sensei

1. **Mixin inheritance** - Reduces code duplication
2. **Modular file structure** - Easier maintenance
3. **Factory pattern** - Cleaner initialization
4. **Event isolation** - Each bar manages own events
5. **`ApplyLayout()` pattern** - Live updates without recreation

---

## 6. Implementation Considerations

### Option A: Full Refactor (Recommended)

- **Effort:** 2-3 weeks
- **Risk:** Medium
- **Benefit:** Clean architecture, maintainable long-term
- **Approach:** Create new module system, then swap

### Option B: Incremental Extraction

- **Effort:** 4-6 weeks
- **Risk:** Low
- **Benefit:** Safer, can validate each step
- **Approach:** Extract one component at a time, test thoroughly

### Option C: Keep Current + Add Patterns

- **Effort:** 1 week
- **Risk:** Very Low
- **Benefit:** Quick, minimal disruption
- **Approach:** Just add mixin patterns to existing file, no restructure

**Recommendation:** Start with **Option C** (add mixin patterns) as immediate improvement, then pursue **Option A** (full refactor) as a major version update.

---

## 7. Questions for Discussion

1. **Health Bar:** Should SuaviUI add a dedicated Health Bar like Sensei, or keep using Unit Frames?

2. **Per-Layout Settings:** Sensei stores settings per Edit Mode layout. SuaviUI uses AceDB profiles. Should we:
   - Keep AceDB profiles only?
   - Add per-layout on top of profiles?
   - Ignore per-layout (simpler)?

3. **CDM Integration:** This is SuaviUI-unique. Should we:
   - Keep current implementation?
   - Make it more modular?
   - Add it as an optional mixin?

4. **Tertiary Bar Expansion:** Currently only supports Ebon Might. Should we:
   - Keep limited scope?
   - Add more class-specific trackers (like Sensei's TipOfTheSpear)?
   - Wait for community feedback?

5. **Options UI:** Current UI is in `sui_options.lua`. Should we:
   - Keep integrated in main options?
   - Create separate Resource Bars options module?
   - Use Sensei's LibEQOLSettingsMode pattern?

---

## 8. Next Steps

### Immediate (Before Refactor)

1. [ ] Back up current `suicore_resourcebars.lua`
2. [ ] Create test matrix for all class/spec combinations
3. [ ] Document all CDM integration points
4. [ ] Identify all `sui_options.lua` dependencies

### Phase 1 Start

1. [ ] Create `utils/resourcebars/` directory
2. [ ] Create `BarMixin.lua` with extracted base logic
3. [ ] Create `PowerBarMixin.lua` with power-specific logic
4. [ ] Create shim in old file to use new mixins
5. [ ] Test with one bar type (Primary)

### Validation

1. [ ] Test all classes without secondary resource
2. [ ] Test DK (runes with timers)
3. [ ] Test Warlock (soul shard decimals)
4. [ ] Test Monk (stagger colors)
5. [ ] Test Evoker (tertiary bar)
6. [ ] Test CDM alignment with both orientations
7. [ ] Test Edit Mode drag and nudge
8. [ ] Test profile import/export

---

## Appendix: Code Patterns from Sensei

### Mixin Registration Pattern

```lua
addonTable.RegisteredBar["PrimaryResourceBar"] = {
    mixin = addonTable.PowerBarMixin,
    dbName = "PrimaryResourceBarDB",
    editModeName = L["PRIMARY_RESOURCE_BAR"],
    frameName = "PrimaryResourceBar",
    defaults = {
        width = 300, height = 20,
        -- ...
    },
    getSettings = function() return SettingsModule.GetPrimarySettings() end,
    loadPredicate = function() return true end,
}
```

### ApplyLayout Pattern

```lua
function BarMixin:ApplyLayout()
    local db = self:GetDB()
    self:SetSize(db.width, db.height)
    self:ClearAllPoints()
    self:SetPoint(db.point, UIParent, db.point, db.x, db.y)
    self:UpdateAppearance()
end
```

### Event Registration Pattern

```lua
function PowerBarMixin:OnLoad()
    BarMixin.OnLoad(self)
    self:RegisterEvent("UNIT_POWER_UPDATE")
    self:RegisterEvent("UNIT_MAXPOWER")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end

function PowerBarMixin:OnEvent(event, ...)
    if event == "UNIT_POWER_UPDATE" then
        self:UpdatePower()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        self:UpdateResourceType()
    end
end
```

---

*Document created: 2026-01-28*
*Last updated: 2026-01-28*
