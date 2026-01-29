--- SuaviUI Health Bar
-- Displays player health as a dedicated bar

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local CDMAlignedMixin = ns.CDMAlignedMixin

local HealthBar = CreateFromMixins(CDMAlignedMixin)

function HealthBar:Initialize()
    -- Initialize through mixin chain properly
    self:OnLoad({
        barKey = "health",
        dbName = "healthBar",
    })
    self:RegisterHealthEvents()
end

function HealthBar:RegisterHealthEvents()
    self:RegisterEvent("UNIT_HEALTH")
    self:RegisterEvent("UNIT_MAXHEALTH")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    self:SetScript("OnEvent", function(frame, event, unit)
        if unit and unit ~= "player" and event ~= "PLAYER_REGEN_DISABLED" and event ~= "PLAYER_REGEN_ENABLED" then
            return
        end
        frame:UpdateHealth()
    end)
end

function HealthBar:UpdateHealth()
    if not self:GetDB() or not self:GetDB().enabled then
        self:Hide()
        return
    end
    
    -- Apply layout settings (position, size, textures, colors)
    self:ApplyLayout()
    local currentHealth = UnitHealth("player")
    
    if not maxHealth or maxHealth <= 0 then
        self:Hide()
        return
    end
    
    self.StatusBar:SetMinMaxValues(0, maxHealth)
    self.StatusBar:SetValue(currentHealth)
    
    -- Health color - gradual from green to red
    local healthPercent = currentHealth / maxHealth
    local r, g, b
    
    if healthPercent > 0.5 then
        -- Green to yellow
        r = (1 - healthPercent) * 2
        g = 1
        b = 0
    else
        -- Yellow to red
        r = 1
        g = healthPercent * 2
        b = 0
    end
    
    self.StatusBar:SetStatusBarColor(r, g, b)
    
    -- Update text
    local cfg = self:GetDB()
    if cfg.showText ~= false then
        if cfg.showPercent then
            self.TextValue:SetText(string.format("%.0f%%", healthPercent * 100))
        else
            self.TextValue:SetText(string.format("%d / %d", currentHealth, maxHealth))
        end
    end
    
    self:Show()
end

function HealthBar:Create()
    local frame = CreateFrame("Frame", ADDON_NAME .. "HealthBar", UIParent)
    Mixin(frame, HealthBar)
    return frame
end

ns.HealthBar = HealthBar
