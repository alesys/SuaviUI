--- SuaviUI Resource Detection
-- Detects primary, secondary, and tertiary resources for all classes/specs

local ADDON_NAME, ns = ...
local SUICore = ns.Addon

-- Power percent with 12.01 API compatibility
local tocVersion = select(4, GetBuildInfo())
local HAS_UNIT_POWER_PERCENT = type(UnitPowerPercent) == "function"

local function GetPowerPct(unit, powerType, usePredicted)
    if (tonumber(tocVersion) or 0) >= 120000 and HAS_UNIT_POWER_PERCENT then
        local ok, pct
        if CurveConstants and CurveConstants.ScaleTo100 then
            ok, pct = pcall(UnitPowerPercent, unit, powerType, usePredicted, CurveConstants.ScaleTo100)
        end
        if not ok or pct == nil then
            ok, pct = pcall(UnitPowerPercent, unit, powerType, usePredicted)
        end
        if ok and pct ~= nil then
            return pct
        end
    end
    local cur = UnitPower(unit, powerType)
    local max = UnitPowerMax(unit, powerType)
    if cur and max and max > 0 then
        return (cur / max) * 100
    end
    return nil
end

-- Druid utility forms (show spec resource instead of form resource)
local druidUtilityForms = {
    [0]  = true, [2]  = true, [3]  = true, [4]  = true,
    [27] = true, [29] = true, [36] = true,
}

-- Druid spec primary resources
local druidSpecResource = {
    [1] = Enum.PowerType.LunarPower,  -- Balance
    [2] = Enum.PowerType.Energy,       -- Feral
    [3] = Enum.PowerType.Rage,         -- Guardian
    [4] = Enum.PowerType.Mana,         -- Restoration
}

-- Detect primary resource for player
function SUICore:GetPrimaryResource()
    local playerClass = select(2, UnitClass("player"))
    local primaryResources = {
        ["DEATHKNIGHT"] = Enum.PowerType.RunicPower,
        ["DEMONHUNTER"] = Enum.PowerType.Fury,
        ["DRUID"]       = {
            [0]   = Enum.PowerType.Mana,
            [1]   = Enum.PowerType.Energy,
            [3]   = Enum.PowerType.Mana,
            [4]   = Enum.PowerType.Mana,
            [5]   = Enum.PowerType.Rage,
            [27]  = Enum.PowerType.Mana,
            [31]  = Enum.PowerType.LunarPower,
        },
        ["EVOKER"]      = Enum.PowerType.Mana,
        ["HUNTER"]      = Enum.PowerType.Focus,
        ["MAGE"]        = Enum.PowerType.Mana,
        ["MONK"]        = {
            [268] = Enum.PowerType.Energy,
            [269] = Enum.PowerType.Energy,
            [270] = Enum.PowerType.Mana,
        },
        ["PALADIN"]     = Enum.PowerType.Mana,
        ["PRIEST"]      = {
            [256] = Enum.PowerType.Mana,
            [257] = Enum.PowerType.Mana,
            [258] = Enum.PowerType.Insanity,
        },
        ["ROGUE"]       = Enum.PowerType.Energy,
        ["SHAMAN"]      = {
            [262] = Enum.PowerType.Maelstrom,
            [263] = Enum.PowerType.Mana,
            [264] = Enum.PowerType.Mana,
        },
        ["WARLOCK"]     = Enum.PowerType.Mana,
        ["WARRIOR"]     = Enum.PowerType.Rage,
    }

    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)

    -- Druid: spec-aware for utility forms
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        if druidUtilityForms[formID or 0] then
            local druidSpec = GetSpecialization()
            if druidSpec and druidSpecResource[druidSpec] then
                return druidSpecResource[druidSpec]
            end
        end
        return primaryResources[playerClass][formID or 0]
    end

    if type(primaryResources[playerClass]) == "table" then
        return primaryResources[playerClass][specID]
    else 
        return primaryResources[playerClass]
    end
end

-- Detect secondary resource for player
function SUICore:GetSecondaryResource()
    local playerClass = select(2, UnitClass("player"))
    local secondaryResources = {
        ["DEATHKNIGHT"] = Enum.PowerType.Runes,
        ["DEMONHUNTER"] = {
            [1480] = "SOUL",
        },
        ["DRUID"]       = {
            [1]    = Enum.PowerType.ComboPoints,
            [31]   = Enum.PowerType.Mana,
        },
        ["EVOKER"]      = Enum.PowerType.Essence,
        ["HUNTER"]      = nil,
        ["MAGE"]        = {
            [62]   = Enum.PowerType.ArcaneCharges,
        },
        ["MONK"]        = {
            [268]  = "STAGGER",
            [269]  = Enum.PowerType.Chi,
        },
        ["PALADIN"]     = Enum.PowerType.HolyPower,
        ["PRIEST"]      = {
            [258]  = Enum.PowerType.Mana,
        },
        ["ROGUE"]       = Enum.PowerType.ComboPoints,
        ["SHAMAN"]      = {
            [262]  = Enum.PowerType.Mana,
        },
        ["WARLOCK"]     = Enum.PowerType.SoulShards,
        ["WARRIOR"]     = nil,
    }

    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)

    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        if druidUtilityForms[formID] or formID == nil then
            local druidSpec = GetSpecialization()
            if druidSpec and druidSpec ~= 4 then
                return Enum.PowerType.Mana
            end
            return nil
        end
        return secondaryResources[playerClass][formID]
    end

    if type(secondaryResources[playerClass]) == "table" then
        return secondaryResources[playerClass][specID]
    else 
        return secondaryResources[playerClass]
    end
end

-- Detect tertiary resource (limited to Evoker Augmentation for now)
function SUICore:GetTertiaryResource()
    local playerClass = select(2, UnitClass("player"))
    local spec = C_SpecializationInfo.GetSpecialization()
    local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec)
    
    if playerClass == "EVOKER" then
        if specID == 1473 then  -- Augmentation
            return "EBON_MIGHT"
        end
    end
    
    return nil
end

-- Get tertiary resource value (special handling for Ebon Might)
function SUICore:GetTertiaryResourceValue(resource)
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

-- Get primary resource value
function SUICore:GetPrimaryResourceValue(resource, cfg)
    if not resource then return nil, nil, nil, nil end

    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil, nil, nil, nil end

    if (cfg.showPercent or cfg.showManaAsPercent) and resource == Enum.PowerType.Mana then
        if HAS_UNIT_POWER_PERCENT then
            return max, current, GetPowerPct("player", resource, false), "percent"
        else
            return max, current, math.floor((current / max) * 100 + 0.5), "percent"
        end
    else
        return max, current, current, "number"
    end
end

ns.ResourceDetection = {
    GetPowerPct = GetPowerPct,
}
