--- SuaviUI Tertiary Power Bar
-- Displays tertiary resources (Ebon Might for Augmentation Evoker)

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local CDMAlignedMixin = ns.CDMAlignedMixin

local TertiaryPowerBar = CreateFromMixins(CDMAlignedMixin)

function TertiaryPowerBar:Initialize()
    -- Initialize through mixin chain properly
    self:OnLoad({
        barKey = "tertiary",
        dbName = "tertiaryPowerBar",
    })
    self.lastUpdate = 0
    self.currentResource = nil
    self.currentMax = 0
    self.currentValue = 0
    self:RegisterPowerEvents()
end

function TertiaryPowerBar:GetResourceValue(resource)
    if not resource then return nil, nil end
    
    if resource == "EBON_MIGHT" then
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(395296)
        local current = auraData and (auraData.expirationTime - GetTime()) or 0
        local max = 20
        
        if current < 0 then current = 0 end
        return max, math.max(0, current)
    end
    
    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil, nil end
    
    return max, current
end

function TertiaryPowerBar:UpdatePower()
    if not self:GetDB() or not self:GetDB().enabled then
        self:Hide()
        return
    end
    
    -- Apply layout settings (position, size, textures, colors)
    self:ApplyLayout()
    if not self.currentResource then
        self:Hide()
        return
    end
    
    local max, current = self:GetResourceValue(self.currentResource)
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
    local r, g, b, a = SUICore:GetTertiaryResourceColor(self.currentResource, cfg.colorMode, cfg.customColor, cfg.usePowerColor)
    self.StatusBar:SetStatusBarColor(r, g, b, a or 1)
    
    -- Update text
    if cfg.showText ~= false then
        if self.currentResource == "EBON_MIGHT" then
            self.TextValue:SetText(string.format("%.1fs", current))
        else
            self.TextValue:SetText(string.format("%d / %d", current, max))
        end
    end
    
    -- Apply CDM layout
    self:ApplyCDMLayout()
    
    self:Show()
end

function TertiaryPowerBar:Create()
    local frame = CreateFrame("Frame", ADDON_NAME .. "TertiaryPowerBar", UIParent)
    Mixin(frame, TertiaryPowerBar)
    return frame
end

ns.TertiaryPowerBar = TertiaryPowerBar
