local addonName, SUICore = ...

local RB = SUICore.ResourceBars
local LEM = RB.LEM

------------------------------------------------------------
-- BAR INSTANCES STORAGE
------------------------------------------------------------

RB.barInstances = {}

------------------------------------------------------------
-- BAR FACTORY
------------------------------------------------------------

local function CreateBarInstance(barName, config, parent)
    local bar = Mixin({}, config.mixin)

    -- Build defaults by merging common defaults with bar-specific defaults
    local defaults = CopyTable(RB.commonDefaults)
    for k, v in pairs(config.defaultValues or {}) do
        defaults[k] = v
    end

    bar:Init(config, parent, config.frameLevel or 0)

    -- Initialize LEMSettingsLoader for this bar
    local settingsLoader = Mixin({}, RB.LEMSettingsLoaderMixin)
    settingsLoader:Init(bar, defaults)
    settingsLoader:LoadSettings()

    -- Store reference to settings loader
    bar.settingsLoader = settingsLoader

    -- Set up event handler
    bar.Frame:SetScript("OnEvent", function(_, event, ...)
        bar:OnEvent(event, ...)
    end)

    -- Call OnLoad
    bar:OnLoad()

    return bar
end

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------

local function InitializeResourceBars()
    -- Ensure database exists (profile-aware)
    RB.GetResourceBarsDB()

    -- Initialize each bar type from RegisteredBar configs
    for barName, config in pairs(RB.RegisteredBar) do
        -- Ensure database table exists for this bar
        if not SuaviUI_ResourceBarsDB[config.dbName] then
            SuaviUI_ResourceBarsDB[config.dbName] = {}
        end

        -- Create the bar instance
        local bar = CreateBarInstance(barName, config, UIParent)

        -- Store instance by frame name for cross-bar references
        RB.barInstances[config.frameName] = bar

        -- Initial layout and visibility
        local layoutName = LEM.GetActiveLayoutName() or "Default"
        if not SuaviUI_ResourceBarsDB[config.dbName][layoutName] then
            local defaults = CopyTable(RB.commonDefaults)
            for k, v in pairs(config.defaultValues or {}) do
                defaults[k] = v
            end
            SuaviUI_ResourceBarsDB[config.dbName][layoutName] = CopyTable(defaults)
        end

        bar:InitCooldownManagerWidthHook(layoutName)
        bar:ApplyVisibilitySettings(layoutName)
        bar:ApplyLayout(layoutName, true)
        bar:UpdateDisplay(layoutName, true)
    end
end

------------------------------------------------------------
-- ADDON LOADED HANDLER
------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName == addonName then
        InitializeResourceBars()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

------------------------------------------------------------
-- SLASH COMMANDS
------------------------------------------------------------

SLASH_SUIBAR1 = "/suibar"
SlashCmdList["SUIBAR"] = function(msg)
    local cmd = msg:lower():trim()

    if cmd == "show" then
        for _, bar in pairs(RB.barInstances) do
            bar:Show()
        end
        RB.prettyPrint("All resource bars shown.")
    elseif cmd == "hide" then
        for _, bar in pairs(RB.barInstances) do
            bar:Hide()
        end
        RB.prettyPrint("All resource bars hidden.")
    elseif cmd == "status" then
        RB.prettyPrint("Resource Bar Status:")
        local layoutName = LEM.GetActiveLayoutName() or "Default"
        print(string.format("Current Layout: %s", layoutName))
        for name, bar in pairs(RB.barInstances) do
            local resource = bar:GetResource()
            local resourceStr = type(resource) == "number" and tostring(resource) or tostring(resource or "none")
            print(string.format("  %s: %s (resource: %s)", name, bar:IsShown() and "visible" or "hidden", resourceStr))
        end
        -- Debug: show database state
        print("Database entries:")
        for dbName, layouts in pairs(SuaviUI_ResourceBarsDB or {}) do
            print(string.format("  %s: {%s}", dbName, table.concat(RB.getTableKeys(layouts), ", ")))
        end
    elseif cmd == "reset" then
        for name, bar in pairs(RB.barInstances) do
            local config = bar:GetConfig()
            local layoutName = LEM.GetActiveLayoutName() or "Default"
            local defaults = CopyTable(RB.commonDefaults)
            for k, v in pairs(config.defaultValues or {}) do
                defaults[k] = v
            end
            SuaviUI_ResourceBarsDB[config.dbName][layoutName] = CopyTable(defaults)
            bar:ApplyLayout(layoutName, true)
            bar:ApplyVisibilitySettings(layoutName)
        end
        RB.prettyPrint("All resource bars reset to defaults for current layout.")
    elseif cmd == "texture" then
        RB.prettyPrint("Texture Debug Info:")
        local layoutName = LEM.GetActiveLayoutName() or "Default"
        for name, bar in pairs(RB.barInstances) do
            local data = bar:GetData(layoutName)
            if data then
                print(string.format("%s foregroundStyle: %s", name, data.foregroundStyle or "nil"))
                local LSM = RB.LSM
                local texture = LSM:Fetch(LSM.MediaType.STATUSBAR, data.foregroundStyle or "SUI FG Fade Left")
                print(string.format("  Fetched texture: %s", texture or "nil"))
                print(string.format("  StatusBar alpha: %.2f", bar.StatusBar:GetAlpha()))
                print(string.format("  StatusBar shown: %s", tostring(bar.StatusBar:IsShown())))
                local min, max = bar.StatusBar:GetMinMaxValues()
                local value = bar.StatusBar:GetValue()
                print(string.format("  StatusBar values: %d/%d (current: %d)", min, max, value))
                local r, g, b, a = bar.StatusBar:GetStatusBarColor()
                print(string.format("  StatusBar color: r=%.2f g=%.2f b=%.2f a=%.2f", r or 0, g or 0, b or 0, a or 1))
            end
        end
    else
        RB.prettyPrint("Commands: show, hide, status, reset, texture")
    end
end
