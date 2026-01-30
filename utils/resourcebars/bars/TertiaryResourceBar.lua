local addonName, SUICore = ...

local RB = SUICore.ResourceBars
local LEM = RB.LEM
local L = RB.L

------------------------------------------------------------
-- DRUID FORM CONSTANTS
------------------------------------------------------------
local DRUID_BEAR_FORM = 5
local DRUID_CAT_FORM = 1

------------------------------------------------------------
-- TERTIARY RESOURCE BAR MIXIN
------------------------------------------------------------

local TertiaryResourceBarMixin = Mixin({}, RB.PowerBarMixin)

function TertiaryResourceBarMixin:GetResource()
    local playerClass = select(2, UnitClass("player"))
    local tertiaryResources = {
        ["DRUID"] = {
            [DRUID_CAT_FORM] = Enum.PowerType.Mana, -- Cat form shows mana as tertiary
            [DRUID_BEAR_FORM] = Enum.PowerType.Mana, -- Bear form shows mana as tertiary
        },
        ["MONK"] = {
            [269] = Enum.PowerType.Mana, -- Windwalker shows mana as tertiary
        },
    }

    local spec = C_SpecializationInfo.GetSpecialization()
    local specID = C_SpecializationInfo.GetSpecializationInfo(spec)

    local resource = tertiaryResources[playerClass]

    -- Druid: form-based
    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        resource = resource and resource[formID or 0]
    end

    if type(resource) == "table" then
        return resource[specID]
    else
        return resource
    end
end

function TertiaryResourceBarMixin:GetResourceValue(resource)
    if not resource then return nil, nil end

    local data = self:GetData()
    if not data then return nil, nil end

    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil end

    return max, current
end

RB.TertiaryResourceBarMixin = TertiaryResourceBarMixin

------------------------------------------------------------
-- REGISTERED BAR CONFIG
------------------------------------------------------------

RB.RegisteredBar = RB.RegisteredBar or {}
RB.RegisteredBar.TertiaryResourceBar = {
    mixin = RB.TertiaryResourceBarMixin,
    dbName = "TertiaryResourceBarDB",
    editModeName = L["TERTIARY_POWER_BAR_EDIT_MODE_NAME"],
    frameName = "SuaviUI_TertiaryResourceBar",
    frameLevel = 1,
    defaultValues = {
        point = "CENTER",
        x = 0,
        y = -80,
        hideManaOnRole = {},
        showManaAsPercent = true,
    },
    allowEditPredicate = function()
        -- Only show in edit mode if the player class actually uses tertiary resources
        local playerClass = select(2, UnitClass("player"))
        return playerClass == "DRUID" or playerClass == "MONK"
    end,
    lemSettings = function(bar, defaults)
        local dbName = bar:GetConfig().dbName

        return {
            {
                parentId = L["CATEGORY_BAR_VISIBILITY"],
                order = 103,
                name = L["HIDE_MANA_ON_ROLE"],
                kind = LEM.SettingType.MultiDropdown,
                default = defaults.hideManaOnRole,
                values = RB.availableRoleOptions,
                hideSummary = true,
                useOldStyle = true,
                get = function(layoutName)
                    return (SuaviUI_ResourceBarsDB[dbName][layoutName] and SuaviUI_ResourceBarsDB[dbName][layoutName].hideManaOnRole) or defaults.hideManaOnRole
                end,
                set = function(layoutName, value)
                    SuaviUI_ResourceBarsDB[dbName][layoutName] = SuaviUI_ResourceBarsDB[dbName][layoutName] or CopyTable(defaults)
                    SuaviUI_ResourceBarsDB[dbName][layoutName].hideManaOnRole = value
                end,
            },
            {
                parentId = L["CATEGORY_TEXT_SETTINGS"],
                order = 505,
                name = L["SHOW_MANA_AS_PERCENT"],
                kind = LEM.SettingType.Checkbox,
                default = defaults.showManaAsPercent,
                get = function(layoutName)
                    local data = SuaviUI_ResourceBarsDB[dbName][layoutName]
                    if data and data.showManaAsPercent ~= nil then
                        return data.showManaAsPercent
                    else
                        return defaults.showManaAsPercent
                    end
                end,
                set = function(layoutName, value)
                    SuaviUI_ResourceBarsDB[dbName][layoutName] = SuaviUI_ResourceBarsDB[dbName][layoutName] or CopyTable(defaults)
                    SuaviUI_ResourceBarsDB[dbName][layoutName].showManaAsPercent = value
                    bar:UpdateDisplay(layoutName)
                end,
                isEnabled = function(layoutName)
                    local data = SuaviUI_ResourceBarsDB[dbName][layoutName]
                    return data.showText
                end,
                tooltip = L["SHOW_MANA_AS_PERCENT_TOOLTIP"],
            },
        }
    end,
}
