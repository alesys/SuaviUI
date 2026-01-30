-- cooldown_editmode.lua
-- EditMode settings integration for CooldownManagerCentered features
-- Adds growth direction dropdowns to Essential/Utility/BuffIcon/BuffBar viewers
-- NOTE: This feature is currently DISABLED because cooldown viewers are not available
-- in the current version of WoW. This file is kept for future use when Blizzard
-- adds CooldownManager API.

local _, SUI = ...

-- Early exit - cooldown viewers don't exist in current WoW version
do
    return
end

local LEM = LibStub("LibEQOLEditMode-1.0", true)
if not LEM then
    return
end

local registeredFrames = {}

local function GetSUICore()
    return (SUI and SUI.SUICore) or (_G.SuaviUI and _G.SuaviUI.SUICore)
end

local function GetProfile()
    local core = GetSUICore()
    return (core and core.db and core.db.profile) or {}
end

local function SetSetting(key, value)
    local profile = GetProfile()
    profile[key] = value
end

local function GetSetting(key, default)
    local profile = GetProfile()
    if profile[key] == nil then
        return default
    end
    return profile[key]
end

local function RefreshCentering()
    if SUI.CooldownManager then
        SUI.CooldownManager.ForceRefreshAll()
    end
end

-- Wait for viewers to be created
local function RegisterViewerSettings()
    local viewers = {
        {
            frameName = "EssentialCooldownViewer",
            name = "Essential Cooldowns",
            settingKey = "cooldownManager_centerEssential_growFromDirection",
            default = "TOP",
            getOptions = function()
                return {
                    {text = "New Rows Below", value = "TOP"},
                    {text = "New Rows on Top", value = "BOTTOM"},
                    {text = "Disable", value = "Disable"},
                }
            end,
        },
        {
            frameName = "UtilityCooldownViewer",
            name = "Utility Cooldowns",
            settingKey = "cooldownManager_centerUtility_growFromDirection",
            default = "TOP",
            getOptions = function()
                return {
                    {text = "New Rows Below", value = "TOP"},
                    {text = "New Rows on Top", value = "BOTTOM"},
                    {text = "Disable", value = "Disable"},
                }
            end,
        },
        {
            frameName = "BuffIconCooldownViewer",
            name = "Buff Icons",
            settingKey = "cooldownManager_alignBuffIcons_growFromDirection",
            default = "START",
            getOptions = function()
                return {
                    {text = "Grow from Left", value = "START"},
                    {text = "Grow from Center", value = "CENTER"},
                    {text = "Grow from Right", value = "END"},
                    {text = "Disable", value = "Disable"},
                }
            end,
        },
        {
            frameName = "BuffBarCooldownViewer",
            name = "Buff Bars",
            settingKey = "cooldownManager_alignBuffBars_growFromDirection",
            default = "BOTTOM",
            getOptions = function()
                return {
                    {text = "Bars grow from Bottom", value = "BOTTOM"},
                    {text = "Bars grow from Top", value = "TOP"},
                    {text = "Disable dynamic layout", value = "Disable"},
                }
            end,
        },
    }

    for _, config in ipairs(viewers) do
        local frame = _G[config.frameName]
        if frame and not registeredFrames[frame] then
            registeredFrames[frame] = true
            
            -- Register frame with LibEQOL
            local success, err = pcall(function()
                LEM:AddFrame(frame, function()
                    -- Position changed callback
                    RefreshCentering()
                end, {
                    enableOverlayToggle = false,
                })
            end)
            
            if not success then
                -- Frame already registered or error, skip
                return
            end

            -- Add growth direction setting
            local settings = {
                {
                    order = 100,
                    name = "Icon Layout",
                    kind = LEM.SettingType.Collapsible,
                    id = "cooldown_layout_" .. config.settingKey,
                },
                {
                    parentId = "cooldown_layout_" .. config.settingKey,
                    order = 101,
                    name = "Growth Direction",
                    kind = LEM.SettingType.Dropdown,
                    default = config.default,
                    useOldStyle = true,
                    values = config.getOptions(),
                    get = function()
                        return GetSetting(config.settingKey, config.default)
                    end,
                    set = function(_, value)
                        SetSetting(config.settingKey, value)
                        RefreshCentering()
                    end,
                    tooltip = "Controls how new rows/columns are added when icons wrap.",
                },
            }

            -- Add dim utility setting for Utility viewer
            if config.settingKey == "cooldownManager_centerUtility_growFromDirection" then
                table.insert(settings, {
                    parentId = "cooldown_layout_" .. config.settingKey,
                    order = 102,
                    name = "Dim When Not On CD",
                    kind = LEM.SettingType.Checkbox,
                    default = false,
                    get = function()
                        return GetSetting("cooldownManager_utility_dimWhenNotOnCD", false)
                    end,
                    set = function(_, value)
                        SetSetting("cooldownManager_utility_dimWhenNotOnCD", value)
                        RefreshCentering()
                    end,
                    tooltip = "Dim utility icons when they are not on cooldown.",
                })

                table.insert(settings, {
                    parentId = "cooldown_layout_" .. config.settingKey,
                    order = 103,
                    name = "Dim Opacity",
                    kind = LEM.SettingType.Slider,
                    default = 0.3,
                    minValue = 0,
                    maxValue = 0.9,
                    valueStep = 0.05,
                    get = function()
                        return GetSetting("cooldownManager_utility_dimOpacity", 0.3)
                    end,
                    set = function(_, value)
                        SetSetting("cooldownManager_utility_dimOpacity", value)
                        RefreshCentering()
                    end,
                    formatter = function(value)
                        return string.format("%.0f%%", value * 100)
                    end,
                    tooltip = "Opacity level when dimmed (0% = invisible, 90% = almost visible).",
                })

                table.insert(settings, {
                    parentId = "cooldown_layout_" .. config.settingKey,
                    order = 104,
                    name = "Limit Size to Essential Width",
                    kind = LEM.SettingType.Checkbox,
                    default = false,
                    get = function()
                        return GetSetting("cooldownManager_limitUtilitySizeToEssential", false)
                    end,
                    set = function(_, value)
                        SetSetting("cooldownManager_limitUtilitySizeToEssential", value)
                        RefreshCentering()
                    end,
                    tooltip = "Constrains Utility viewer width to match Essential viewer width.",
                })
            end

            pcall(LEM.AddFrameSettings, LEM, frame, settings)
        end
    end
end

-- Delayed initialization to ensure viewers are created
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local hasRun = false

local function TryRegister()
    if hasRun then return end
    
    -- Check if any viewer frames exist
    if _G["EssentialCooldownViewer"] or _G["UtilityCooldownViewer"] or 
       _G["BuffIconCooldownViewer"] or _G["BuffBarCooldownViewer"] then
        hasRun = true
        C_Timer.After(0.1, function()
            pcall(RegisterViewerSettings)
            pcall(RefreshCentering)
        end)
    end
end

initFrame:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        TryRegister()
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, TryRegister)
    end
end)
