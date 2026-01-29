--- SuaviUI PowerBarMixin
-- Extends BarMixin with power-specific logic: events, colors, resource detection

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local BarMixin = ns.BarMixin

local PowerBarMixin = CreateFromMixins(BarMixin)

local UPDATE_THROTTLE = 0.016  -- 60 FPS smoothness

local instantFeedbackTypes = {
    [Enum.PowerType.HolyPower] = true,
    [Enum.PowerType.ComboPoints] = true,
    [Enum.PowerType.Chi] = true,
    [Enum.PowerType.Runes] = true,
    [Enum.PowerType.ArcaneCharges] = true,
    [Enum.PowerType.Essence] = true,
    [Enum.PowerType.SoulShards] = true,
}

-- Override OnLoad to initialize power bar specific logic
function PowerBarMixin:OnLoad(config)
    -- Store config first
    self.config = config
    self.barKey = config.barKey
    self.dbName = config.dbName
    
    -- Setup frame (don't call parent, just setup directly)
    self:SetFrameStrata("MEDIUM")
    
    -- Background texture
    self.Background = self:CreateTexture(nil, "BACKGROUND")
    self.Background:SetAllPoints()
    
    -- Status bar (the actual progress bar)
    self.StatusBar = CreateFrame("StatusBar", nil, self)
    self.StatusBar:SetAllPoints()
    self.StatusBar:SetFrameLevel(self:GetFrameLevel())
    
    -- Border frame
    self.Border = CreateFrame("Frame", nil, self, "BackdropTemplate")
    self.Border:SetPoint("TOPLEFT", self, -1, 1)
    self.Border:SetPoint("BOTTOMRIGHT", self, 1, -1)
    self.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    self.Border:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- Text frame (overlay for display values)
    self.TextFrame = CreateFrame("Frame", nil, self)
    self.TextFrame:SetAllPoints(self)
    self.TextFrame:SetFrameStrata("MEDIUM")
    self.TextFrame:SetFrameLevel(self:GetFrameLevel() + 2)
    
    -- Text value display
    self.TextValue = self.TextFrame:CreateFontString(nil, "OVERLAY")
    self.TextValue:SetFont(GameFontHighlightSmall:GetFont())
    self.TextValue:SetTextColor(1, 1, 1, 1)
    self.TextValue:SetPoint("CENTER", self, "CENTER", 0, 0)
    
    -- Cache values
    self._cachedX = 0
    self._cachedY = 0
    self._cachedW = 0
    self._cachedH = 0
    self._cachedLayout = nil
    
    -- Power bar initialization
    self.lastUpdate = 0
    self.currentResource = nil
    self.currentMax = 0
    self.currentValue = 0
end

-- Register events for power updates
function PowerBarMixin:RegisterPowerEvents()
    self:RegisterEvent("UNIT_POWER_FREQUENT")
    self:RegisterEvent("UNIT_POWER_UPDATE")
    self:RegisterEvent("UNIT_MAXPOWER")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    if self.barKey == "secondary" then
        self:RegisterEvent("RUNE_POWER_UPDATE")
    end
    
    if self.barKey == "tertiary" then
        self:RegisterEvent("UNIT_AURA")
    end
    
    self:SetScript("OnEvent", function(frame, event, unit)
        frame:OnPowerEvent(event, unit)
    end)
end

-- Handle power events
function PowerBarMixin:OnPowerEvent(event, unit)
    if unit and unit ~= "player" then return end
    
    local now = GetTime()
    
    if self.barKey == "secondary" and ns.FragmentedPower.fragmentedPowerTypes[self.currentResource] then
        if event == "RUNE_POWER_UPDATE" then
            self:UpdatePower()
        elseif now - self.lastUpdate >= UPDATE_THROTTLE or instantFeedbackTypes[self.currentResource] then
            self:UpdatePower()
            self.lastUpdate = now
        end
    else
        if event == "UNIT_POWER_UPDATE" or event == "RUNE_POWER_UPDATE" then
            if instantFeedbackTypes[self.currentResource] or now - self.lastUpdate >= UPDATE_THROTTLE then
                self:UpdatePower()
                self.lastUpdate = now
            end
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then
            self:UpdatePower()
        elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
            self:UpdatePower()
        else
            self:UpdatePower()
        end
    end
end

-- Detect current resource for this bar
function PowerBarMixin:DetectResource()
    if self.barKey == "primary" then
        return SUICore:GetPrimaryResource()
    elseif self.barKey == "secondary" then
        return SUICore:GetSecondaryResource()
    elseif self.barKey == "tertiary" then
        return SUICore:GetTertiaryResource()
    end
    return nil
end

-- Get resource value
function PowerBarMixin:GetResourceValue(resource)
    if self.barKey == "primary" then
        return SUICore:GetPrimaryResourceValue(resource, self:GetDB())
    elseif self.barKey == "secondary" then
        return SUICore:GetSecondaryResourceValue(resource)
    elseif self.barKey == "tertiary" then
        return SUICore:GetTertiaryResourceValue(resource)
    end
    return nil, nil
end

-- Update the bar with current resource value and color
function PowerBarMixin:UpdatePower()
    if not self:GetDB() or not self:GetDB().enabled then
        self:Hide()
        return
    end
    
    self.currentResource = self:DetectResource()
    if not self.currentResource then
        self:Hide()
        return
    end
    
    local max, current, displayValue, valueType = self:GetResourceValue(self.currentResource)
    if not max or max <= 0 then
        self:Hide()
        return
    end
    
    self.currentMax = max
    self.currentValue = current
    
    -- Update bar value
    self.StatusBar:SetMinMaxValues(0, max)
    self.StatusBar:SetValue(current)
    
    -- Update color
    local cfg = self:GetDB()
    if cfg.usePowerColor then
        local color = SUICore:GetResourceColor(self.currentResource)
        self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
    elseif cfg.useClassColor then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            self.StatusBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
        end
    elseif cfg.useCustomColor and cfg.customColor then
        local c = cfg.customColor
        self.StatusBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
    end
    
    -- Update text
    if valueType == "percent" then
        self.TextValue:SetText(string.format("%.0f%%", displayValue))
    else
        self.TextValue:SetText(tostring(displayValue))
    end
    
    self:Show()
end

-- Update ticks for segmented resources
function PowerBarMixin:UpdatePowerTicks()
    -- This will be overridden by specific bar implementations
end

ns.PowerBarMixin = PowerBarMixin
