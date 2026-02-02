------------------------------------------------------------
-- HEALTH BAR
-- Based on SenseiClassResourceBar by Equilateral (EQOL)
-- Modified for SuaviUI AceDB profile integration
------------------------------------------------------------

local addonName, SUICore = ...

local RB = SUICore.ResourceBars
local LEM = RB.LEM
local L = RB.L

------------------------------------------------------------
-- HELPER FUNCTIONS
------------------------------------------------------------

local function GetBarData(config, layoutName)
    local db = RB.GetResourceBarsDB()
    return db and db[config.dbName] and db[config.dbName][layoutName]
end

local function EnsureBarData(config, layoutName, defaults)
    local db = RB.GetResourceBarsDB()
    if not db then return nil end
    if not db[config.dbName] then
        db[config.dbName] = {}
    end
    if not db[config.dbName][layoutName] then
        db[config.dbName][layoutName] = CopyTable(defaults)
    end
    return db[config.dbName][layoutName]
end

------------------------------------------------------------
-- HEALTH BAR MIXIN
------------------------------------------------------------

local HealthBarMixin = Mixin({}, RB.BarMixin)

function HealthBarMixin:GetBarColor()
    local playerClass = select(2, UnitClass("player"))

    local data = self:GetData()

    local color = RB:GetOverrideHealthBarColor()

    if data and data.useClassColor == true then
        local r, g, b = GetClassColor(playerClass)
        return { r = r, g = g, b = b, a = color.a }
    else
        return color
    end
end

function HealthBarMixin:GetResource()
    return "HEALTH"
end

function HealthBarMixin:GetResourceValue()
    local current = UnitHealth("player")
    local max = UnitHealthMax("player")
    if max <= 0 then return nil, nil end

    return max, current
end

function HealthBarMixin:GetTagValues(_, max, current, precision)
    local pFormat = "%." .. (precision or 0) .. "f"

    -- Pre-compute values instead of creating closures for better performance
    local currentStr = string.format("%s", AbbreviateNumbers(current))
    local percentStr = string.format(pFormat, UnitHealthPercent("player", true, CurveConstants.ScaleTo100))
    local maxStr = string.format("%s", AbbreviateNumbers(max))

    return {
        ["[current]"] = function() return currentStr end,
        ["[percent]"] = function() return percentStr end,
        ["[max]"] = function() return maxStr end,
    }
end

function HealthBarMixin:OnLoad()
    self.Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.Frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    self.Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.Frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    self.Frame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    self.Frame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
    self.Frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    self.Frame:RegisterEvent("PET_BATTLE_OPENING_START")
    self.Frame:RegisterEvent("PET_BATTLE_CLOSE")
end

function HealthBarMixin:OnEvent(event, ...)
    local unit = ...

    if event == "PLAYER_ENTERING_WORLD"
        or (event == "PLAYER_SPECIALIZATION_CHANGED" and unit == "player") then

        self:ApplyVisibilitySettings()
        self:ApplyLayout()
        self:UpdateDisplay()

    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_TARGET_CHANGED"
        or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE"
        or event == "PLAYER_MOUNT_DISPLAY_CHANGED"
        or event == "PET_BATTLE_OPENING_START" or event == "PET_BATTLE_CLOSE" then

        self:ApplyVisibilitySettings(nil, event == "PLAYER_REGEN_DISABLED")
        self:UpdateDisplay()

    end
end

function HealthBarMixin:GetPoint(layoutName, ignorePositionMode)
    local data = self:GetData(layoutName)

    if not ignorePositionMode then
        if data and data.positionMode == "Use Primary Resource Bar Position If Hidden" then
            local primaryResource = RB.barInstances and RB.barInstances["SuaviUI_PrimaryResourceBar"]

            if primaryResource then
                primaryResource:ApplyVisibilitySettings(layoutName)
                if not primaryResource:IsShown() then
                    return primaryResource:GetPoint(layoutName, true)
                end
            end
        elseif data and data.positionMode == "Use Secondary Resource Bar Position If Hidden" then
            local secondaryResource = RB.barInstances and RB.barInstances["SuaviUI_SecondaryResourceBar"]

            if secondaryResource then
                secondaryResource:ApplyVisibilitySettings(layoutName)
                if not secondaryResource:IsShown() then
                    return secondaryResource:GetPoint(layoutName, true)
                end
            end
        end
    end

    return RB.BarMixin.GetPoint(self, layoutName)
end

function HealthBarMixin:OnShow()
    local data = self:GetData()

    if data and data.positionMode ~= nil and data.positionMode ~= "Self" then
        self:ApplyLayout()
    end
end

function HealthBarMixin:OnHide()
    local data = self:GetData()

    if data and data.positionMode ~= nil and data.positionMode ~= "Self" then
        self:ApplyLayout()
    end
end

RB.HealthBarMixin = HealthBarMixin

------------------------------------------------------------
-- REGISTERED BAR CONFIG
------------------------------------------------------------

RB.RegisteredBar = RB.RegisteredBar or {}
RB.RegisteredBar.HealthBar = {
    mixin = RB.HealthBarMixin,
    dbName = "healthBarDB",
    editModeName = L["HEALTH_BAR_EDIT_MODE_NAME"],
    frameName = "SuaviUI_HealthBar",
    frameLevel = 0,
    defaultValues = {
        point = "CENTER",
        x = 0,
        y = 40,
        positionMode = "Self",
        barVisible = "Hidden",
        hideHealthOnRole = {},
        hideBlizzardPlayerContainerUi = false,
        useClassColor = true,
    },
    lemSettings = function(bar, defaults)
        local config = bar:GetConfig()
        local dbName = config.dbName

        return {
            {
                parentId = L["CATEGORY_BAR_VISIBILITY"],
                order = 103,
                name = L["HIDE_HEALTH_ON_ROLE"],
                kind = LEM.SettingType.MultiDropdown,
                default = defaults.hideHealthOnRole,
                values = RB.availableRoleOptions,
                hideSummary = true,
                useOldStyle = true,
                get = function(layoutName)
                    local data = GetBarData(config, layoutName)
                    return (data and data.hideHealthOnRole) or defaults.hideHealthOnRole
                end,
                set = function(layoutName, value)
                    local data = EnsureBarData(config, layoutName, defaults)
                    if data then data.hideHealthOnRole = value end
                end,
            },
            {
                parentId = L["CATEGORY_BAR_VISIBILITY"],
                order = 105,
                name = L["HIDE_BLIZZARD_UI"],
                kind = LEM.SettingType.Checkbox,
                default = defaults.hideBlizzardPlayerContainerUi,
                get = function(layoutName)
                    local data = GetBarData(config, layoutName)
                    if data and data.hideBlizzardPlayerContainerUi ~= nil then
                        return data.hideBlizzardPlayerContainerUi
                    else
                        return defaults.hideBlizzardPlayerContainerUi
                    end
                end,
                set = function(layoutName, value)
                    local data = EnsureBarData(config, layoutName, defaults)
                    if data then
                        data.hideBlizzardPlayerContainerUi = value
                        bar:HideBlizzardPlayerContainer(layoutName)
                    end
                end,
                tooltip = L["HIDE_BLIZZARD_UI_HEALTH_BAR_TOOLTIP"],
            },
            {
                parentId = L["CATEGORY_POSITION_AND_SIZE"],
                order = 201,
                name = L["POSITION"],
                kind = LEM.SettingType.Dropdown,
                default = defaults.positionMode,
                useOldStyle = true,
                values = RB.availablePositionModeOptions(config),
                get = function(layoutName)
                    local data = GetBarData(config, layoutName)
                    return (data and data.positionMode) or defaults.positionMode
                end,
                set = function(layoutName, value)
                    local data = EnsureBarData(config, layoutName, defaults)
                    if data then
                        data.positionMode = value
                        bar:ApplyLayout(layoutName)
                    end
                end,
            },
            {
                parentId = L["CATEGORY_BAR_STYLE"],
                order = 401,
                name = L["USE_CLASS_COLOR"],
                kind = LEM.SettingType.Checkbox,
                default = defaults.useClassColor,
                get = function(layoutName)
                    local data = GetBarData(config, layoutName)
                    if data and data.useClassColor ~= nil then
                        return data.useClassColor
                    else
                        return defaults.useClassColor
                    end
                end,
                set = function(layoutName, value)
                    local data = EnsureBarData(config, layoutName, defaults)
                    if data then
                        data.useClassColor = value
                        bar:ApplyLayout(layoutName)
                    end
                end,
            },
        }
    end,
}
