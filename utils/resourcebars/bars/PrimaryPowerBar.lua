--- SuaviUI Primary Power Bar
-- Displays primary resource (Mana, Rage, Energy, etc.)

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local CDMAlignedMixin = ns.CDMAlignedMixin

local PrimaryPowerBar = CreateFromMixins(CDMAlignedMixin)

function PrimaryPowerBar:Initialize()
    -- Initialize through mixin chain properly
    self:OnLoad({
        barKey = "primary",
        dbName = "primaryPowerBar",
    })
    self.lastUpdate = 0
    self.currentResource = nil
    self.currentMax = 0
    self.currentValue = 0
    self:RegisterPowerEvents()
end

function PrimaryPowerBar:UpdatePower()
    if not self:GetDB() or not self:GetDB().enabled then
        self:Hide()
        return
    end
    
    -- Apply layout settings (position, size, textures, colors)
    self:ApplyLayout()
    
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
    if cfg.showText ~= false then
        if valueType == "percent" then
            self.TextValue:SetText(string.format("%.0f%%", displayValue))
        else
            self.TextValue:SetText(tostring(displayValue))
        end
    end
    
    -- Apply CDM layout (may override position/size)
    self:ApplyCDMLayout()
    
    self:Show()
end

function PrimaryPowerBar:Create()
    local frame = CreateFrame("Frame", ADDON_NAME .. "PrimaryPowerBar", UIParent)
    Mixin(frame, PrimaryPowerBar)
    return frame
end

ns.PrimaryPowerBar = PrimaryPowerBar
