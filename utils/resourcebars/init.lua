------------------------------------------------------------
-- RESOURCE BAR INITIALIZATION
-- Based on SenseiClassResourceBar by Equilateral (EQOL)
-- Modified for SuaviUI AceDB profile integration
-- Includes original migration code for SavedVariable → AceDB
------------------------------------------------------------

local addonName, SUICore = ...

local RB = SUICore.ResourceBars
local LEM = RB.LEM

-- Debug helper — logs to the SuaviUI debug window
local function dbg(msg)
    if _G.SuaviUI_Debug then _G.SuaviUI_Debug(msg, "RB") end
end
-- Expose globally so Bar.lua etc. can use it
RB.dbg = dbg

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

-- One-time migration from old SavedVariable to AceDB profile
local function MigrateOldDatabase()
    -- Check if old SavedVariable exists
    if not _G.SuaviUI_ResourceBarsDB then
        return  -- Nothing to migrate
    end

    local db = RB.GetResourceBarsDB()
    if not db then
        return  -- Profile not available yet
    end

    -- Copy old data to profile
    for dbName, layouts in pairs(_G.SuaviUI_ResourceBarsDB) do
        if type(layouts) == "table" then
            db[dbName] = db[dbName] or {}
            for layoutName, settings in pairs(layouts) do
                if type(settings) == "table" and layoutName ~= "_Settings" then
                    db[dbName][layoutName] = CopyTable(settings)
                end
            end
        end
    end

    -- Migrate global settings if they exist
    if _G.SuaviUI_ResourceBarsDB["_Settings"] then
        db["_Settings"] = CopyTable(_G.SuaviUI_ResourceBarsDB["_Settings"])
    end

    -- Clear old variable (cleanup)
    _G.SuaviUI_ResourceBarsDB = nil

    print("|cFF30D1FFSuaviUI:|r Resource bars migrated to profile system.")
end

------------------------------------------------------------
-- SENSEI FORMAT MIGRATION
-- Migrates old SenseiClassResourceBar DB names and field
-- names to the current SuaviUI format (one-time per layout).
------------------------------------------------------------

-- Old DB name → New DB name
local SENSEI_DB_MAP = {
    secondaryPowerBar   = "SecondaryResourceBarDB",
    primaryPowerBar     = "PrimaryResourceBarDB",
    tertiaryPowerBar    = "TertiaryResourceBarDB",
    healthBar           = "healthBarDB",
}

-- Convert array color {r,g,b,a} to object {r=,g=,b=,a=}
local function ArrayToColorObj(arr)
    if type(arr) ~= "table" then return nil end
    if arr.r ~= nil then return arr end  -- already object format
    return { r = arr[1] or 0, g = arr[2] or 0, b = arr[3] or 0, a = arr[4] or 1 }
end

-- Map old fields to new fields, returns a new-format table
local function MapSenseiFields(old, defaults)
    local new = CopyTable(defaults)

    -- Position & size (same field names)
    if old.x ~= nil then new.x = old.x end
    if old.y ~= nil then new.y = old.y end
    if old.width ~= nil then new.width = old.width end
    if old.height ~= nil then new.height = old.height end
    if old.point then new.point = old.point end
    if old.relativePoint then new.relativePoint = old.relativePoint end

    -- Visibility: boolean enabled → string barVisible
    if old.enabled == false then
        new.barVisible = "Hidden"
    elseif old.enabled == true then
        new.barVisible = "Always Visible"
    end

    -- Relative frame
    if old.relativeTo then new.relativeFrame = old.relativeTo end

    -- Texture
    if old.texture then new.foregroundStyle = old.texture end

    -- Background color
    local bgc = ArrayToColorObj(old.bgColor)
    if bgc then new.backgroundColor = bgc end

    -- Text
    if old.showText ~= nil then new.showText = old.showText end
    if old.textSize then new.fontSize = old.textSize end
    if old.showPercent == true then
        new.textFormat = "Percent"
    elseif old.showPercent == false and old.showText then
        new.textFormat = "Current"
    end

    -- Text color
    local tc = ArrayToColorObj(old.textCustomColor)
    if tc then new.textColor = tc end

    -- Ticks
    if old.showTicks ~= nil then new.showTicks = old.showTicks end
    if old.tickThickness then new.tickThickness = old.tickThickness end
    local tkc = ArrayToColorObj(old.tickColor)
    if tkc then new.tickColor = tkc end

    -- Fragmented power bar text
    if old.showFragmentedPowerBarText ~= nil then
        new.showFragmentedPowerBarText = old.showFragmentedPowerBarText
    end

    -- Orientation mapping
    if old.orientation then
        if old.orientation == "VERTICAL" or old.orientation == "Vertical" then
            new.orientation = "Vertical"
        else
            new.orientation = "Normal"
        end
    end

    return new
end

local function MigrateSenseiFormat()
    local db = RB.GetResourceBarsDB()
    if not db then return end

    local migrated = false
    for oldName, newName in pairs(SENSEI_DB_MAP) do
        local oldData = db[oldName]
        if oldData and type(oldData) == "table" then
            db[newName] = db[newName] or {}

            -- Build defaults for this bar type
            local defaults = CopyTable(RB.commonDefaults)
            for _, config in pairs(RB.RegisteredBar or {}) do
                if config.dbName == newName then
                    for k, v in pairs(config.defaultValues or {}) do
                        defaults[k] = v
                    end
                    break
                end
            end

            for layoutName, oldLayout in pairs(oldData) do
                if type(oldLayout) == "table" then
                    db[newName][layoutName] = MapSenseiFields(oldLayout, defaults)
                    migrated = true
                end
            end

            -- Remove old key after migration (self-cleaning)
            db[oldName] = nil
        end
    end

    -- Clean up old migration marker if present
    db._senseiMigrated = nil

    if migrated then
        print("|cFF30D1FFSuaviUI:|r Resource bar settings migrated from legacy format.")
    end
end

------------------------------------------------------------
-- LAYOUT RESOLUTION
------------------------------------------------------------

-- Resolve layout name directly from C_EditMode (bypasses LEM cache)
local function GetRawActiveLayoutName()
    if not (C_EditMode and C_EditMode.GetLayouts) then return nil end
    local layouts = C_EditMode.GetLayouts()
    if not layouts or not layouts.activeLayout then return nil end
    local idx = layouts.activeLayout
    if idx == 1 then return _G.LAYOUT_STYLE_MODERN or "Modern" end
    if idx == 2 then return _G.LAYOUT_STYLE_CLASSIC or "Classic" end
    if layouts.layouts then
        local custom = layouts.layouts[idx - 2]
        return custom and custom.layoutName
    end
    return nil
end

-- Resolve active layout name: try LEM first, then C_EditMode fallback
local function ResolveActiveLayoutName()
    local name = LEM.GetActiveLayoutName()
    if name then return name end
    return GetRawActiveLayoutName() or "Default"
end

------------------------------------------------------------
-- MAIN INIT
------------------------------------------------------------

local function InitializeResourceBars()
    -- Run migrations
    MigrateOldDatabase()
    MigrateSenseiFormat()

    -- Get profile database
    local db = RB.GetResourceBarsDB()
    if not db then
        dbg("FATAL: resource bars DB not available")
        return
    end

    local layoutName = ResolveActiveLayoutName()
    RB.activeLayoutName = layoutName
    dbg("Init layout: " .. tostring(layoutName))

    -- Initialize each bar type from RegisteredBar configs
    for barName, config in pairs(RB.RegisteredBar) do
        -- Ensure database table exists for this bar
        if not db[config.dbName] then
            db[config.dbName] = {}
        end

        -- Create the bar instance
        local bar = CreateBarInstance(barName, config, UIParent)

        -- Store instance by frame name for cross-bar references
        RB.barInstances[config.frameName] = bar

        -- Initial layout and visibility
        if not db[config.dbName][layoutName] then
            local defaults = CopyTable(RB.commonDefaults)
            for k, v in pairs(config.defaultValues or {}) do
                defaults[k] = v
            end
            db[config.dbName][layoutName] = CopyTable(defaults)
        end

        bar:InitCooldownManagerWidthHook(layoutName)
        bar:ApplyVisibilitySettings(layoutName)
        bar:ApplyLayout(layoutName, true)
        bar:UpdateDisplay(layoutName, true)
    end

    dbg("Init complete with layout '" .. layoutName .. "'")

    -- WoW resolves the per-character active layout AFTER ADDON_LOADED.
    -- At init time, C_EditMode reports the account-default layout (e.g. "Modern")
    -- instead of the character's actual layout. Poll until the real layout resolves.
    local initLayoutName = layoutName
    local function ReapplyAllBars(newLayout)
        dbg("Layout resolved: '" .. initLayoutName .. "' -> '" .. newLayout .. "'")
        RB.activeLayoutName = newLayout
        local db2 = RB.GetResourceBarsDB()
        for _, bar in pairs(RB.barInstances) do
            local config = bar:GetConfig()
            if db2 and db2[config.dbName] then
                if not db2[config.dbName][newLayout] then
                    local defs = CopyTable(RB.commonDefaults)
                    for k, v in pairs(config.defaultValues or {}) do
                        defs[k] = v
                    end
                    db2[config.dbName][newLayout] = CopyTable(defs)
                end
            end
            bar:InitCooldownManagerWidthHook(newLayout)
            bar:ApplyVisibilitySettings(newLayout)
            bar:ApplyLayout(newLayout, true)
            bar:UpdateDisplay(newLayout, true)
        end
        initLayoutName = newLayout
    end

    -- Poll C_EditMode every few frames until the layout changes or timeout
    local pollFrame = CreateFrame("Frame")
    local pollCount = 0
    local resolved = false
    pollFrame:SetScript("OnUpdate", function(self)
        pollCount = pollCount + 1
        if resolved or pollCount > 600 then
            self:SetScript("OnUpdate", nil)
            return
        end
        if pollCount % 5 ~= 0 then return end
        local rawName = GetRawActiveLayoutName()
        if rawName and rawName ~= initLayoutName then
            resolved = true
            self:SetScript("OnUpdate", nil)
            ReapplyAllBars(rawName)
        end
    end)

    -- Also catch EDIT_MODE_LAYOUTS_UPDATED in case it fires after the poll ends.
    -- This also fires on spec change when per-character layouts differ by spec.
    local layoutWatcher = CreateFrame("Frame")
    layoutWatcher:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    layoutWatcher:SetScript("OnEvent", function()
        local rawName = GetRawActiveLayoutName()
        if rawName then
            RB.activeLayoutName = rawName
            if rawName ~= initLayoutName then
                ReapplyAllBars(rawName)
            end
        end
    end)
end

------------------------------------------------------------
-- ADDON LOADED HANDLER
------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if loadedAddonName == addonName then
        -- Create placeholder frames immediately so Edit Mode can resolve
        -- anchors (e.g., UtilityCooldownViewer anchored to our resource bar).
        -- Full initialization is deferred to avoid CDM taint during
        -- Edit Mode's secureexecuterange.
        for _, config in pairs(RB.RegisteredBar or {}) do
            if config.frameName and not _G[config.frameName] then
                CreateFrame("Frame", config.frameName, UIParent)
            end
        end
        C_Timer.After(0, InitializeResourceBars)
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
        local db = RB.GetResourceBarsDB()
        if db then
            print("Database entries:")
            for dbName, layouts in pairs(db) do
                print(string.format("  %s: {%s}", dbName, table.concat(RB.getTableKeys(layouts), ", ")))
            end
        else
            print("Database not available (profile not loaded)")
        end
    elseif cmd == "reset" then
        local db = RB.GetResourceBarsDB()
        if not db then
            RB.prettyPrint("Cannot reset - profile not available!")
            return
        end

        for name, bar in pairs(RB.barInstances) do
            local config = bar:GetConfig()
            local layoutName = LEM.GetActiveLayoutName() or "Default"
            local defaults = CopyTable(RB.commonDefaults)
            for k, v in pairs(config.defaultValues or {}) do
                defaults[k] = v
            end
            db[config.dbName][layoutName] = CopyTable(defaults)
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
