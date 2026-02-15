# Tertiary Resource Bar Implementation Strategy for SuaviUI

## Executive Summary

Implement a **minimal, maintainable tertiary resource bar** that works within SuaviUI's current monolithic architecture while laying groundwork for future modularization.

---

## Strategy Overview: Phased Approach

### Phase 1: Minimal Implementation (Recommended First Step)
- Add tertiary bar to existing `suicore_resourcebars.lua`
- Reuse current power bar rendering logic
- Support Evoker Ebon Might only initially
- Minimal config additions
- **Effort:** Low | **Risk:** Low | **Timeline:** 1-2 days

### Phase 2: Enhanced Support (Future)
- Add other potential tertiary resources per class/spec
- Refine UI controls and options
- Performance optimization
- **Effort:** Medium | **Risk:** Low | **Timeline:** 1 week

### Phase 3: Long-term Refactor (Future Major Update)
- Separate resource bars into modular mixins (Sensei-style)
- Split casting bars from resource bars
- Create reusable bar component system
- **Effort:** High | **Risk:** Medium | **Timeline:** 2-3 weeks

---

## Phase 1: Implementation Plan

### Step 1: Add Configuration (suicore_main.lua)

**Location:** After `secondaryPowerBar` config (~line 960)

```lua
tertiaryPowerBar = {
    enabled           = false,  -- Disabled by default (only Evoker uses)
    autoAttach        = false,
    standaloneMode    = false,
    attachTo          = "EssentialCooldownViewer",
    height            = 8,
    borderSize        = 1,
    offsetY           = 8,       -- Positioned below secondary bar
    offsetX           = 0,
    width             = 326,
    useRawPixels      = true,
    texture           = "Suavi v5",
    colorMode         = "power",
    usePowerColor     = true,
    useClassColor     = false,
    customColor       = { 0.5, 0.8, 1, 1 },  -- Blueish for tertiary
    showPercent       = false,
    showText          = true,
    textSize          = 14,
    textX             = 0,
    textY             = 2,
    textUseClassColor = false,
    textCustomColor   = { 1, 1, 1, 1 },
    bgColor           = { 0.078, 0.078, 0.078, 0.83 },
    showTicks         = false,
    tickThickness     = 2,
    tickColor         = { 0, 0, 0, 1 },
    lockedToEssential = false,
    lockedToUtility   = false,
    lockedToSecondary = true,    -- Position relative to secondary bar
    snapGap           = 5,
    orientation       = "HORIZONTAL",
},
```

### Step 2: Add Resource Detection Function (suicore_resourcebars.lua)

**Add after `GetPowerPct()` function (~line 100):**

```lua
-- Detect tertiary resource for current class/spec
local function GetTertiaryResource()
    local playerClass = select(2, UnitClass("player"))
    local spec = C_SpecializationInfo.GetSpecialization()
    local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec)
    
    -- Class-specific tertiary resources
    if playerClass == "EVOKER" then
        if specID == 1473 then  -- Augmentation
            return "EBON_MIGHT"
        end
    end
    
    -- Add more classes here in future:
    -- if playerClass == "HUNTER" then ... end
    -- if playerClass == "DEMONHUNTER" then ... end
    
    return nil  -- No tertiary resource
end

-- Get tertiary resource value (handles special cases like Ebon Might)
local function GetTertiaryResourceValue(resource)
    if not resource then return nil, nil end
    
    if resource == "EBON_MIGHT" then
        -- Ebon Might is an aura duration, not a power pool
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(395296)
        local current = auraData and (auraData.expirationTime - GetTime()) or 0
        local max = 20  -- Ebon Might duration is 20 seconds
        
        if current < 0 then current = 0 end
        return max, math.max(0, current)
    end
    
    -- Standard power resource
    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil, nil end
    
    return max, current
end

-- Get color for tertiary resource
local function GetTertiaryResourceColor(resource, colorMode, customColor, usePowerColor)
    if not resource then return 0.2, 0.6, 1, 1 end
    
    local db = SUICore.db.profile.powerColors
    if not db then return 0.2, 0.6, 1, 1 end
    
    -- Special handling for Ebon Might (cyan/turquoise)
    if resource == "EBON_MIGHT" then
        if usePowerColor and db.essence then
            local c = db.essence
            return c[1], c[2], c[3], c[4] or 1
        end
        return 0.3, 0.8, 1, 1  -- Default cyan
    end
    
    -- Standard power color lookup
    local powerTypeColor = db[resource]
    if powerTypeColor then
        return powerTypeColor[1], powerTypeColor[2], powerTypeColor[3], powerTypeColor[4] or 1
    end
    
    return customColor[1], customColor[2], customColor[3], customColor[4] or 1
end

-- Format tertiary resource text
local function FormatTertiaryResourceText(resource, current, max)
    if not resource then return "" end
    
    if resource == "EBON_MIGHT" then
        -- Show duration with decimal (e.g., "18.5s")
        return string.format("%.1fs", current)
    end
    
    -- Standard format
    return string.format("%d / %d", current, max)
end
```

### Step 3: Initialize Tertiary Bar (suicore_resourcebars.lua)

**Add after secondary bar initialization (~line 800):**

```lua
-- TERTIARY POWER BAR
function SUICore:InitTertiaryPowerBar()
    if not self.db or not self.db.profile or not self.db.profile.tertiaryPowerBar then
        return
    end
    
    local cfg = self.db.profile.tertiaryPowerBar
    if not cfg.enabled then
        -- Hide if disabled
        if self.tertiaryPowerBar then
            self.tertiaryPowerBar:Hide()
        end
        return
    end
    
    -- Check if player has a tertiary resource
    local resource = GetTertiaryResource()
    if not resource then
        if self.tertiaryPowerBar then
            self.tertiaryPowerBar:Hide()
        end
        return
    end
    
    -- Create bar if needed
    if not self.tertiaryPowerBar then
        self.tertiaryPowerBar = CreateFrame("StatusBar", "SUICore_TertiaryPowerBar", UIParent)
        self.tertiaryPowerBar:SetFrameStrata("MEDIUM")
        self.tertiaryPowerBar:SetFrameLevel(20)
        
        -- Setup bar appearance
        local texture = LSM:Fetch("statusbar", cfg.texture) or "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"
        self.tertiaryPowerBar:SetStatusBarTexture(texture)
        
        -- Background
        local bg = self.tertiaryPowerBar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(cfg.bgColor[1], cfg.bgColor[2], cfg.bgColor[3], cfg.bgColor[4])
        self.tertiaryPowerBar.bg = bg
        
        -- Border
        if cfg.borderSize > 0 then
            local border = CreateFrame("Frame", nil, self.tertiaryPowerBar, "BackdropTemplate")
            border:SetAllPoints()
            border:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = Scale(cfg.borderSize),
            })
            border:SetBackdropBorderColor(0, 0, 0, 1)
            self.tertiaryPowerBar.border = border
        end
        
        -- Text
        self.tertiaryPowerBar.text = self.tertiaryPowerBar:CreateFontString(nil, "OVERLAY")
        self.tertiaryPowerBar.text:SetFont(GetGeneralFont(), cfg.textSize, GetGeneralFontOutline())
        self.tertiaryPowerBar.text:SetPoint("CENTER", cfg.textX, cfg.textY)
        self.tertiaryPowerBar.text:SetJustifyH("CENTER")
        
        -- Register for updates
        self.tertiaryPowerBar:RegisterEvent("UNIT_POWER_UPDATE")
        self.tertiaryPowerBar:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self.tertiaryPowerBar:RegisterEvent("AURA_UPDATE")  -- For Ebon Might tracking
        self.tertiaryPowerBar:SetScript("OnEvent", function(frame, event)
            SUICore:UpdateTertiaryPowerBar()
        end)
    end
    
    -- Apply positioning
    self:PositionTertiaryPowerBar()
    
    -- Update display
    self:UpdateTertiaryPowerBar()
    self.tertiaryPowerBar:Show()
end

function SUICore:PositionTertiaryPowerBar()
    if not self.tertiaryPowerBar then return end
    
    local cfg = self.db.profile.tertiaryPowerBar
    local width = cfg.width or 326
    local height = cfg.height or 8
    
    self.tertiaryPowerBar:SetSize(Scale(width), Scale(height))
    
    -- Position relative to secondary bar if locked
    if cfg.lockedToSecondary and self.secondaryPowerBar then
        local secBar = self.secondaryPowerBar
        self.tertiaryPowerBar:SetPoint("TOPLEFT", secBar, "BOTTOMLEFT", 
            Scale(cfg.offsetX), -Scale(cfg.snapGap) + Scale(cfg.offsetY))
    else
        -- Standard positioning
        local point = cfg.point or "CENTER"
        local relPoint = cfg.relPoint or "CENTER"
        local x = cfg.offsetX or 0
        local y = cfg.offsetY or -204
        
        self.tertiaryPowerBar:SetPoint(point, UIParent, relPoint, Scale(x), Scale(y))
    end
end

function SUICore:UpdateTertiaryPowerBar()
    if not self.tertiaryPowerBar or not self.db or not self.db.profile then return end
    
    local cfg = self.db.profile.tertiaryPowerBar
    if not cfg.enabled then return end
    
    local resource = GetTertiaryResource()
    if not resource then
        self.tertiaryPowerBar:Hide()
        return
    end
    
    local max, current = GetTertiaryResourceValue(resource)
    if not max or not current then
        self.tertiaryPowerBar:Hide()
        return
    end
    
    -- Update bar values
    self.tertiaryPowerBar:SetMinMaxValues(0, max)
    self.tertiaryPowerBar:SetValue(current)
    
    -- Update color
    local r, g, b, a = GetTertiaryResourceColor(resource, cfg.colorMode, cfg.customColor, cfg.usePowerColor)
    self.tertiaryPowerBar:SetStatusBarColor(r, g, b, a)
    
    -- Update text
    if cfg.showText and self.tertiaryPowerBar.text then
        local text = FormatTertiaryResourceText(resource, current, max)
        self.tertiaryPowerBar.text:SetText(text)
        self.tertiaryPowerBar.text:SetTextColor(
            cfg.textCustomColor[1], cfg.textCustomColor[2], 
            cfg.textCustomColor[3], cfg.textCustomColor[4]
        )
    end
    
    self.tertiaryPowerBar:Show()
end
```

### Step 4: Hook into Addon Initialization

**In `init.lua` or main addon load function, add:**

```lua
-- After secondary power bar initialization
SUICore:InitTertiaryPowerBar()

-- In update loop (wherever you call UpdateSecondaryPowerBar):
SUICore:UpdateTertiaryPowerBar()
```

### Step 5: Add to Options UI (sui_options.lua)

**Add new section in CreateGeneralPage or create separate tab:**

```lua
-- Tertiary Power Bar Options
local function CreateTertiaryPowerBarPage(parent)
    local y = 0
    local spacing = 22
    
    -- Enable toggle
    local enableCheck = CreateCheckButton(parent, "Enable Tertiary Power Bar")
    enableCheck:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
    enableCheck:SetChecked(SUICore.db.profile.tertiaryPowerBar.enabled)
    enableCheck:SetScript("OnClick", function(self)
        SUICore.db.profile.tertiaryPowerBar.enabled = self:GetChecked()
        SUICore:InitTertiaryPowerBar()
    end)
    
    y = y - spacing
    
    -- Height slider
    local heightSlider = CreateSlider(parent, "Height", 4, 20, 1)
    heightSlider:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    heightSlider:SetValue(SUICore.db.profile.tertiaryPowerBar.height)
    heightSlider:SetScript("OnValueChanged", function(self, value)
        SUICore.db.profile.tertiaryPowerBar.height = value
        SUICore:PositionTertiaryPowerBar()
    end)
    
    y = y - spacing
    
    -- Offset Y slider
    local offsetYSlider = CreateSlider(parent, "Offset Y", -100, 100, 1)
    offsetYSlider:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    offsetYSlider:SetValue(SUICore.db.profile.tertiaryPowerBar.offsetY)
    offsetYSlider:SetScript("OnValueChanged", function(self, value)
        SUICore.db.profile.tertiaryPowerBar.offsetY = value
        SUICore:PositionTertiaryPowerBar()
    end)
    
    -- Add more controls as needed...
end
```

---

## Phase 2: Enhanced Support (Future)

### Potential Tertiary Resources by Class

```lua
-- Future expansion
local TertiaryResourcesByClass = {
    EVOKER = {
        [1473] = "EBON_MIGHT",          -- Augmentation
    },
    DEMONHUNTER = {
        [1480] = "SOUL_FRAGMENTS_DEVOURER", -- Devourer spec (if added)
    },
    HUNTER = {
        [255] = "TIP_OF_THE_SPEAR",     -- Survival (alternative tracking)
    },
    -- Add as needed when specs get more complex
}
```

### Event Handling Improvements

- **AURA_UPDATE** - For Ebon Might duration tracking
- **COMBAT_LOG_EVENT_UNFILTERED** - For tracking damage-based resources
- **PLAYER_SPECIALIZATION_CHANGED** - Recalculate resource type

---

## Phase 3: Long-term Architecture (Future Refactor)

### Proposed Mixin Structure (Inspired by Sensei)

```
suicore_resourcebars.lua (new structure)
├── Mixins/
│   ├── BarMixin.lua (base class)
│   ├── PowerBarMixin.lua (extends BarMixin)
│   ├── CastbarMixin.lua (extends BarMixin)
│   └── SpecialResourceMixin.lua (for Ebon Might, etc.)
├── Bars/
│   ├── PrimaryPowerBar.lua
│   ├── SecondaryPowerBar.lua
│   ├── TertiaryPowerBar.lua
│   ├── PlayerCastbar.lua
│   ├── TargetCastbar.lua
│   └── FocusCastbar.lua
└── BarFactory.lua (initialization)
```

---

## Risks & Mitigation

| Risk | Mitigation |
|------|-----------|
| Breaking existing power bars | Reuse existing rendering code, extensive testing |
| Performance impact from extra events | Lazy-load tertiary bar, unregister when not needed |
| Complex Ebon Might tracking | Create dedicated function with fallback handling |
| Code duplication | Create shared utility functions for color/text formatting |
| Testing coverage | Test with Evoker on live server before release |

---

## Testing Checklist

- [ ] Create Evoker character (Augmentation spec)
- [ ] Enable tertiary power bar
- [ ] Verify bar shows Ebon Might duration
- [ ] Test positioning and resizing
- [ ] Test with secondary bar locked
- [ ] Verify text updates correctly
- [ ] Test switching specs (should hide on non-Augmentation)
- [ ] Test with all textures
- [ ] Performance: No FPS drops
- [ ] Test with other addons loaded
- [ ] Test import/export profile with tertiary bar settings

---

## Implementation Timeline

- **Phase 1:** 1-2 days (immediate)
- **Phase 2:** 3-5 days (after 1-2 weeks of testing)
- **Phase 3:** 2-3 weeks (future major update)

---

## Recommendation

**Start with Phase 1 immediately:**
1. Implement tertiary bar with minimal code
2. Support only Evoker Ebon Might initially
3. Reuse existing infrastructure
4. Get community feedback
5. Plan refactor after stabilization

This is **low-risk, high-value** and keeps SuaviUI competitive with Sensei while maintaining code stability.

