--- SuaviUI Power Colors System
-- Comprehensive power type coloring with customization

local ADDON_NAME, ns = ...
local SUICore = ns.Addon

-- Get color for any resource type
function SUICore:GetResourceColor(resource)
    local db = self.db and self.db.profile and self.db.profile.resourceBars
    if not db or not db.powerColors then 
        return GetPowerBarColor("MANA")
    end
    
    local pc = db.powerColors
    local customColor = nil

    if resource == "STAGGER" then
        if pc.useStaggerLevelColors then
            local stagger = UnitStagger("player") or 0
            local maxHealth = UnitHealthMax("player") or 1
            local staggerPercent = (stagger / maxHealth) * 100

            if staggerPercent >= 60 then
                customColor = pc.staggerHeavy
            elseif staggerPercent >= 30 then
                customColor = pc.staggerModerate
            else
                customColor = pc.staggerLight
            end
        else
            customColor = pc.stagger
        end
    elseif resource == "SOUL" then
        customColor = pc.soulFragments
    elseif resource == Enum.PowerType.SoulShards then
        customColor = pc.soulShards
    elseif resource == Enum.PowerType.Runes then
        local _, class = UnitClass("player")
        if class == "DEATHKNIGHT" then
            local spec = GetSpecialization()
            if spec == 1 then customColor = pc.bloodRunes
            elseif spec == 2 then customColor = pc.frostRunes
            elseif spec == 3 then customColor = pc.unholyRunes
            else customColor = pc.runes end
        else
            customColor = pc.runes
        end
    elseif resource == Enum.PowerType.Essence then
        customColor = pc.essence
    elseif resource == Enum.PowerType.ComboPoints then
        customColor = pc.comboPoints
    elseif resource == Enum.PowerType.Chi then
        customColor = pc.chi
    elseif resource == Enum.PowerType.Mana then
        customColor = pc.mana
    elseif resource == Enum.PowerType.Rage then
        customColor = pc.rage
    elseif resource == Enum.PowerType.Energy then
        customColor = pc.energy
    elseif resource == Enum.PowerType.Focus then
        customColor = pc.focus
    elseif resource == Enum.PowerType.RunicPower then
        customColor = pc.runicPower
    elseif resource == Enum.PowerType.Insanity then
        customColor = pc.insanity
    elseif resource == Enum.PowerType.Fury then
        customColor = pc.fury
    elseif resource == Enum.PowerType.Maelstrom then
        customColor = pc.maelstrom
    elseif resource == Enum.PowerType.LunarPower then
        customColor = pc.lunarPower
    elseif resource == Enum.PowerType.HolyPower then
        customColor = pc.holyPower
    elseif resource == Enum.PowerType.ArcaneCharges then
        customColor = pc.arcaneCharges
    end

    if customColor then
        return { r = customColor[1], g = customColor[2], b = customColor[3], a = customColor[4] or 1 }
    end

    local powerName = nil
    if type(resource) == "number" then
        for name, value in pairs(Enum.PowerType) do
            if value == resource then
                powerName = name:gsub("(%u)", "_%1"):gsub("^_", ""):upper()
                break
            end
        end
    end

    return GetPowerBarColor(powerName) or GetPowerBarColor(resource) or GetPowerBarColor("MANA")
end

-- Get color for tertiary resource
function SUICore:GetTertiaryResourceColor(resource, colorMode, customColor, usePowerColor)
    if not resource then return 0.5, 0.8, 1, 1 end
    
    local db = self.db and self.db.profile and self.db.profile.resourceBars
    if not db or not db.powerColors then return 0.5, 0.8, 1, 1 end
    
    if resource == "EBON_MIGHT" then
        if usePowerColor and db.powerColors.essence then
            local c = db.powerColors.essence
            return c[1], c[2], c[3], c[4] or 1
        end
        return 0.3, 0.8, 1, 1
    end
    
    local powerTypeColor = db.powerColors[resource]
    if powerTypeColor then
        return powerTypeColor[1], powerTypeColor[2], powerTypeColor[3], powerTypeColor[4] or 1
    end
    
    return customColor[1], customColor[2], customColor[3], customColor[4] or 1
end

ns.PowerColors = {
    defaults = {
        rage = { 1.00, 0.00, 0.00, 1 },
        energy = { 1.00, 1.00, 0.00, 1 },
        mana = { 0.00, 0.00, 1.00, 1 },
        focus = { 1.00, 0.50, 0.25, 1 },
        runicPower = { 0.00, 0.82, 1.00, 1 },
        fury = { 0.79, 0.26, 0.99, 1 },
        insanity = { 0.40, 0.00, 0.80, 1 },
        maelstrom = { 0.00, 0.50, 1.00, 1 },
        lunarPower = { 0.30, 0.52, 0.90, 1 },
        holyPower = { 0.95, 0.90, 0.60, 1 },
        chi = { 0.00, 1.00, 0.59, 1 },
        comboPoints = { 1.00, 0.96, 0.41, 1 },
        soulShards = { 0.58, 0.51, 0.79, 1 },
        arcaneCharges = { 0.10, 0.10, 0.98, 1 },
        essence = { 0.20, 0.58, 0.50, 1 },
        stagger = { 0.00, 1.00, 0.59, 1 },
        staggerLight = { 0.52, 1.00, 0.52, 1 },
        staggerModerate = { 1.00, 0.98, 0.72, 1 },
        staggerHeavy = { 1.00, 0.42, 0.42, 1 },
        useStaggerLevelColors = true,
        soulFragments = { 0.64, 0.19, 0.79, 1 },
        runes = { 0.77, 0.12, 0.23, 1 },
        bloodRunes = { 0.77, 0.12, 0.23, 1 },
        frostRunes = { 0.00, 0.82, 1.00, 1 },
        unholyRunes = { 0.00, 0.80, 0.00, 1 },
    }
}
