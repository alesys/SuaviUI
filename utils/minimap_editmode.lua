--[[
    SuaviUI Minimap Edit Mode Integration
    Registers Minimap directly with Blizzard Edit Mode using LibEQOLEditMode-1.0
    Provides sidebar settings panel for minimap positioning and styling

    KEY DESIGN: We register the actual Minimap frame with LEM (not a holder frame).
    This is consistent with how castbar_editmode.lua and SenseiClassResourceBar work:
    the registered frame must be VISIBLE when Edit Mode opens so that the
    EditModeSystemSelectionTemplate child is rendered and clickable.

    LEM internally creates a selection overlay as a child of the registered frame.
    When resetSelectionIndicators() runs (before our "enter" callback), the selection
    calls :ShowHighlighted(). If the parent frame is hidden at that point, the overlay
    won't render. Registering a hidden holder frame broke this.
]]

local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- LIBRARY REFERENCES
---------------------------------------------------------------------------
local LEM = LibStub("LibEQOLEditMode-1.0", true)

if not LEM then
    return
end

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local MM_EditMode = {}
ns.MM_EditMode = MM_EditMode

MM_EditMode.registered = false
MM_EditMode.clusterWasShown = nil

---------------------------------------------------------------------------
-- DATABASE HELPERS
---------------------------------------------------------------------------
local function GetDB()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile
    end
    return nil
end

local function GetMinimapDB()
    local db = GetDB()
    return db and db.minimap or nil
end

local function RefreshMinimap()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.Minimap and SUICore.Minimap.Refresh then
        SUICore.Minimap:Refresh()
    end
end

---------------------------------------------------------------------------
-- POSITION CHANGE CALLBACK
-- Called by LEM after drag finishes (finishSelectionDrag -> TriggerCallback)
-- Signature from LEM: callback(frame, point, x, y)
---------------------------------------------------------------------------
local function OnPositionChanged(frame, point, x, y)
    local mm = GetMinimapDB()
    if not mm then return end

    if not mm.position then mm.position = {} end
    mm.position[1] = point or "TOPLEFT"
    mm.position[2] = point or "BOTTOMLEFT"
    mm.position[3] = tonumber(x) or 0
    mm.position[4] = tonumber(y) or 0

    -- DO NOT call RefreshMinimap() here.
    -- Refresh() calls SetMovable(false) which would kill the drag state.
    -- LEM's finishSelectionDrag already calls SetPoint on the frame.
    -- We only save to DB so the position persists on reload.
end

---------------------------------------------------------------------------
-- SETTINGS BUILDERS
-- Uses the correct LEM SettingType API (kind/order/get(layoutName)/set(layoutName, value))
-- Reference: castbar_editmode.lua, SenseiClassResourceBar
---------------------------------------------------------------------------
local function BuildMinimapSettings()
    local settings = {}
    local order = 100

    -- =================================================================
    -- POSITION & SIZE
    -- =================================================================
    table.insert(settings, {
        order = order,
        name = "Position & Size",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_POSITION",
        defaultCollapsed = false,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_POSITION",
        order = order,
        name = "Lock Minimap (outside Edit Mode)",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.lock or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then mm.lock = value end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_POSITION",
        order = order,
        name = "Map Size (Pixels)",
        kind = LEM.SettingType.Slider,
        default = 160,
        minValue = 100,
        maxValue = 400,
        valueStep = 1,
        formatter = function(value) return string.format("%d px", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.size or 160
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.size = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_POSITION",
        order = order,
        name = "Scale",
        kind = LEM.SettingType.Slider,
        default = 1.0,
        minValue = 0.5,
        maxValue = 2.0,
        valueStep = 0.01,
        formatter = function(value) return string.format("%.0f%%", value * 100) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.scale or 1.0
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.scale = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- =================================================================
    -- APPEARANCE
    -- =================================================================
    table.insert(settings, {
        order = order,
        name = "Appearance",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_APPEARANCE",
        defaultCollapsed = true,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_APPEARANCE",
        order = order,
        name = "Shape",
        kind = LEM.SettingType.Dropdown,
        default = "Square",
        useOldStyle = true,
        values = {
            { text = "Square", value = "SQUARE" },
            { text = "Round", value = "ROUND" },
        },
        get = function(layoutName)
            local mm = GetMinimapDB()
            local shape = mm and mm.shape or "SQUARE"
            return shape == "ROUND" and "Round" or "Square"
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.shape = (value == "Round") and "ROUND" or "SQUARE"
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_APPEARANCE",
        order = order,
        name = "Border Size",
        kind = LEM.SettingType.Slider,
        default = 2,
        minValue = 0,
        maxValue = 16,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.borderSize or 2
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.borderSize = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_APPEARANCE",
        order = order,
        name = "Class Color Border",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.useClassColorBorder or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.useClassColorBorder = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_APPEARANCE",
        order = order,
        name = "Border Color",
        kind = LEM.SettingType.Color,
        default = {0, 0, 0, 1},
        get = function(layoutName)
            local mm = GetMinimapDB()
            local c = mm and mm.borderColor or {0, 0, 0, 1}
            return c[1], c[2], c[3], c[4] or 1
        end,
        set = function(layoutName, r, g, b, a)
            local mm = GetMinimapDB()
            if mm then
                mm.borderColor = {r, g, b, a or 1}
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_APPEARANCE",
        order = order,
        name = "Auto Zoom Out",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.autoZoom or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.autoZoom = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- =================================================================
    -- HIDE ELEMENTS
    -- =================================================================
    table.insert(settings, {
        order = order,
        name = "Hide Elements",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_HIDE_ELEMENTS",
        defaultCollapsed = true,
    })
    order = order + 1

    -- showMail (default false = hidden)
    table.insert(settings, {
        parentId = "CATEGORY_HIDE_ELEMENTS",
        order = order,
        name = "Show Mail Icon",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showMail or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showMail = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- showTracking
    table.insert(settings, {
        parentId = "CATEGORY_HIDE_ELEMENTS",
        order = order,
        name = "Show Tracking Button",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showTracking or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showTracking = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- showDifficulty
    table.insert(settings, {
        parentId = "CATEGORY_HIDE_ELEMENTS",
        order = order,
        name = "Show Difficulty Flag",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showDifficulty or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showDifficulty = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- showMissions (Garrison/order hall)
    table.insert(settings, {
        parentId = "CATEGORY_HIDE_ELEMENTS",
        order = order,
        name = "Show Progress Report (Missions)",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showMissions or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showMissions = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- showZoomButtons
    table.insert(settings, {
        parentId = "CATEGORY_HIDE_ELEMENTS",
        order = order,
        name = "Show Zoom Buttons",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showZoomButtons or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showZoomButtons = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- showCraftingOrder
    table.insert(settings, {
        parentId = "CATEGORY_HIDE_ELEMENTS",
        order = order,
        name = "Show Crafting Orders",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showCraftingOrder or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showCraftingOrder = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- showAddonCompartment
    table.insert(settings, {
        parentId = "CATEGORY_HIDE_ELEMENTS",
        order = order,
        name = "Show Addon Compartment",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showAddonCompartment or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showAddonCompartment = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- showCalendar
    table.insert(settings, {
        parentId = "CATEGORY_HIDE_ELEMENTS",
        order = order,
        name = "Show Calendar",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showCalendar ~= false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showCalendar = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- hideAddonButtons (inverted: true = hidden on hover only)
    table.insert(settings, {
        parentId = "CATEGORY_HIDE_ELEMENTS",
        order = order,
        name = "Hide Addon Buttons (show on hover)",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.hideAddonButtons ~= false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.hideAddonButtons = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- =================================================================
    -- CLOCK
    -- =================================================================
    table.insert(settings, {
        order = order,
        name = "Clock",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_CLOCK",
        defaultCollapsed = true,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_CLOCK",
        order = order,
        name = "Show Clock",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showClock or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showClock = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_CLOCK",
        order = order,
        name = "Time Format",
        kind = LEM.SettingType.Dropdown,
        default = "Local Time",
        useOldStyle = true,
        values = {
            { text = "Local Time", value = "local" },
            { text = "Server Time", value = "server" },
        },
        get = function(layoutName)
            local mm = GetMinimapDB()
            local fmt = mm and mm.clockConfig and mm.clockConfig.timeFormat or "local"
            return fmt == "server" and "Server Time" or "Local Time"
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.clockConfig then mm.clockConfig = {} end
                mm.clockConfig.timeFormat = (value == "Server Time") and "server" or "local"
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_CLOCK",
        order = order,
        name = "Font Size",
        kind = LEM.SettingType.Slider,
        default = 12,
        minValue = 8,
        maxValue = 24,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.clockConfig and mm.clockConfig.fontSize or 12
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.clockConfig then mm.clockConfig = {} end
                mm.clockConfig.fontSize = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_CLOCK",
        order = order,
        name = "Offset X",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.clockConfig and mm.clockConfig.offsetX or 0
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.clockConfig then mm.clockConfig = {} end
                mm.clockConfig.offsetX = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_CLOCK",
        order = order,
        name = "Offset Y",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.clockConfig and mm.clockConfig.offsetY or 0
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.clockConfig then mm.clockConfig = {} end
                mm.clockConfig.offsetY = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_CLOCK",
        order = order,
        name = "Use Class Color",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.clockConfig and mm.clockConfig.useClassColor or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.clockConfig then mm.clockConfig = {} end
                mm.clockConfig.useClassColor = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_CLOCK",
        order = order,
        name = "Clock Color",
        kind = LEM.SettingType.Color,
        default = {1, 1, 1, 1},
        get = function(layoutName)
            local mm = GetMinimapDB()
            local c = mm and mm.clockConfig and mm.clockConfig.color or {1, 1, 1, 1}
            return c[1], c[2], c[3], c[4] or 1
        end,
        set = function(layoutName, r, g, b, a)
            local mm = GetMinimapDB()
            if mm then
                if not mm.clockConfig then mm.clockConfig = {} end
                mm.clockConfig.color = {r, g, b, a or 1}
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- =================================================================
    -- COORDINATES
    -- =================================================================
    table.insert(settings, {
        order = order,
        name = "Coordinates",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_COORDS",
        defaultCollapsed = true,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_COORDS",
        order = order,
        name = "Show Coordinates",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showCoords or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showCoords = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_COORDS",
        order = order,
        name = "Precision",
        kind = LEM.SettingType.Dropdown,
        default = "Normal",
        useOldStyle = true,
        values = {
            { text = "Normal", value = "%d,%d" },
            { text = "High (1 decimal)", value = "%.1f,%.1f" },
            { text = "Very High (2 decimals)", value = "%.2f,%.2f" },
        },
        get = function(layoutName)
            local mm = GetMinimapDB()
            local p = mm and mm.coordPrecision or "%d,%d"
            if p == "%.2f,%.2f" then return "Very High (2 decimals)"
            elseif p == "%.1f,%.1f" then return "High (1 decimal)"
            else return "Normal" end
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if value == "Very High (2 decimals)" then mm.coordPrecision = "%.2f,%.2f"
                elseif value == "High (1 decimal)" then mm.coordPrecision = "%.1f,%.1f"
                else mm.coordPrecision = "%d,%d" end
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_COORDS",
        order = order,
        name = "Update Interval (seconds)",
        kind = LEM.SettingType.Slider,
        default = 1,
        minValue = 0.1,
        maxValue = 5.0,
        valueStep = 0.1,
        formatter = function(value) return string.format("%.1fs", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.coordUpdateInterval or 1
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.coordUpdateInterval = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_COORDS",
        order = order,
        name = "Font Size",
        kind = LEM.SettingType.Slider,
        default = 12,
        minValue = 8,
        maxValue = 24,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.coordsConfig and mm.coordsConfig.fontSize or 12
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.coordsConfig then mm.coordsConfig = {} end
                mm.coordsConfig.fontSize = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_COORDS",
        order = order,
        name = "Offset X",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.coordsConfig and mm.coordsConfig.offsetX or 0
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.coordsConfig then mm.coordsConfig = {} end
                mm.coordsConfig.offsetX = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_COORDS",
        order = order,
        name = "Offset Y",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.coordsConfig and mm.coordsConfig.offsetY or 0
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.coordsConfig then mm.coordsConfig = {} end
                mm.coordsConfig.offsetY = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_COORDS",
        order = order,
        name = "Use Class Color",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.coordsConfig and mm.coordsConfig.useClassColor or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.coordsConfig then mm.coordsConfig = {} end
                mm.coordsConfig.useClassColor = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_COORDS",
        order = order,
        name = "Coordinates Color",
        kind = LEM.SettingType.Color,
        default = {1, 1, 1, 1},
        get = function(layoutName)
            local mm = GetMinimapDB()
            local c = mm and mm.coordsConfig and mm.coordsConfig.color or {1, 1, 1, 1}
            return c[1], c[2], c[3], c[4] or 1
        end,
        set = function(layoutName, r, g, b, a)
            local mm = GetMinimapDB()
            if mm then
                if not mm.coordsConfig then mm.coordsConfig = {} end
                mm.coordsConfig.color = {r, g, b, a or 1}
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- =================================================================
    -- ZONE TEXT
    -- =================================================================
    table.insert(settings, {
        order = order,
        name = "Zone Text",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_ZONE_TEXT",
        defaultCollapsed = true,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_ZONE_TEXT",
        order = order,
        name = "Show Zone Text",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.showZoneText ~= false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                mm.showZoneText = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_ZONE_TEXT",
        order = order,
        name = "Font Size",
        kind = LEM.SettingType.Slider,
        default = 12,
        minValue = 8,
        maxValue = 24,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.zoneTextConfig and mm.zoneTextConfig.fontSize or 12
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.zoneTextConfig then mm.zoneTextConfig = {} end
                mm.zoneTextConfig.fontSize = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_ZONE_TEXT",
        order = order,
        name = "Offset X",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.zoneTextConfig and mm.zoneTextConfig.offsetX or 0
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.zoneTextConfig then mm.zoneTextConfig = {} end
                mm.zoneTextConfig.offsetX = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_ZONE_TEXT",
        order = order,
        name = "Offset Y",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.zoneTextConfig and mm.zoneTextConfig.offsetY or 0
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.zoneTextConfig then mm.zoneTextConfig = {} end
                mm.zoneTextConfig.offsetY = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_ZONE_TEXT",
        order = order,
        name = "Uppercase",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.zoneTextConfig and mm.zoneTextConfig.allCaps or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.zoneTextConfig then mm.zoneTextConfig = {} end
                mm.zoneTextConfig.allCaps = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_ZONE_TEXT",
        order = order,
        name = "Use Class Color",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.zoneTextConfig and mm.zoneTextConfig.useClassColor or false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.zoneTextConfig then mm.zoneTextConfig = {} end
                mm.zoneTextConfig.useClassColor = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    -- =================================================================
    -- DUNGEON EYE (LFG Queue Status)
    -- =================================================================
    table.insert(settings, {
        order = order,
        name = "Dungeon Eye (Queue Status)",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_DUNGEON_EYE",
        defaultCollapsed = true,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_DUNGEON_EYE",
        order = order,
        name = "Enable Dungeon Eye",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.dungeonEye and mm.dungeonEye.enabled ~= false
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.dungeonEye then mm.dungeonEye = {} end
                mm.dungeonEye.enabled = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_DUNGEON_EYE",
        order = order,
        name = "Corner",
        kind = LEM.SettingType.Dropdown,
        default = "Bottom Left",
        useOldStyle = true,
        values = {
            { text = "Top Left", value = "TOPLEFT" },
            { text = "Top Right", value = "TOPRIGHT" },
            { text = "Bottom Left", value = "BOTTOMLEFT" },
            { text = "Bottom Right", value = "BOTTOMRIGHT" },
        },
        get = function(layoutName)
            local mm = GetMinimapDB()
            local corner = mm and mm.dungeonEye and mm.dungeonEye.corner or "BOTTOMLEFT"
            local map = { TOPLEFT = "Top Left", TOPRIGHT = "Top Right", BOTTOMLEFT = "Bottom Left", BOTTOMRIGHT = "Bottom Right" }
            return map[corner] or "Bottom Left"
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.dungeonEye then mm.dungeonEye = {} end
                local map = { ["Top Left"] = "TOPLEFT", ["Top Right"] = "TOPRIGHT", ["Bottom Left"] = "BOTTOMLEFT", ["Bottom Right"] = "BOTTOMRIGHT" }
                mm.dungeonEye.corner = map[value] or "BOTTOMLEFT"
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_DUNGEON_EYE",
        order = order,
        name = "Scale",
        kind = LEM.SettingType.Slider,
        default = 0.6,
        minValue = 0.3,
        maxValue = 1.5,
        valueStep = 0.05,
        formatter = function(value) return string.format("%.0f%%", value * 100) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.dungeonEye and mm.dungeonEye.scale or 0.6
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.dungeonEye then mm.dungeonEye = {} end
                mm.dungeonEye.scale = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_DUNGEON_EYE",
        order = order,
        name = "Offset X",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.dungeonEye and mm.dungeonEye.offsetX or 0
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.dungeonEye then mm.dungeonEye = {} end
                mm.dungeonEye.offsetX = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    table.insert(settings, {
        parentId = "CATEGORY_DUNGEON_EYE",
        order = order,
        name = "Offset Y",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local mm = GetMinimapDB()
            return mm and mm.dungeonEye and mm.dungeonEye.offsetY or 0
        end,
        set = function(layoutName, value)
            local mm = GetMinimapDB()
            if mm then
                if not mm.dungeonEye then mm.dungeonEye = {} end
                mm.dungeonEye.offsetY = value
                RefreshMinimap()
            end
        end,
    })
    order = order + 1

    return settings
end

---------------------------------------------------------------------------
-- FRAME REGISTRATION
-- Register the actual Minimap frame with LEM (not a wrapper/holder).
-- The Minimap is always visible, so the LEM selection overlay (child of
-- Minimap) will render when resetSelectionIndicators calls
-- :ShowHighlighted() during Edit Mode enter.
---------------------------------------------------------------------------
function MM_EditMode:RegisterFrame()
    if not LEM or not Minimap then return end
    if self.registered then return end

    -- Set custom Edit Mode label
    Minimap.editModeName = "SuaviUI Minimap"

    local mm = GetMinimapDB()
    local defaults = {
        point = (mm and mm.position and mm.position[1]) or "TOPLEFT",
        x     = (mm and mm.position and mm.position[3]) or 790,
        y     = (mm and mm.position and mm.position[4]) or 285,
    }

    local success, err = pcall(function()
        LEM:AddFrame(Minimap, OnPositionChanged, defaults)
        LEM:AddFrameSettings(Minimap, BuildMinimapSettings())

        -- Allow drag only during Edit Mode
        LEM:SetFrameDragEnabled(Minimap, function()
            return LEM:IsInEditMode()
        end)

        -- Show reset button only during Edit Mode
        LEM:SetFrameResetVisible(Minimap, function()
            return LEM:IsInEditMode()
        end)
    end)

    if success then
        self.registered = true
    else
        print("SuaviUI: Failed to register Minimap with Edit Mode:", tostring(err))
    end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
function MM_EditMode:Initialize()
    if not LEM then return end
    self:RegisterFrame()

    -- When entering Edit Mode: unlock Minimap for dragging, hide MinimapCluster
    LEM:RegisterCallback("enter", function()
        -- Temporarily undo FixedFrameStrata so LEM can manage strata during drag
        if Minimap.SetFixedFrameStrata then
            Minimap:SetFixedFrameStrata(false)
        end
        if Minimap.SetFixedFrameLevel then
            Minimap:SetFixedFrameLevel(false)
        end

        -- MinimapCluster sits over the Minimap area in default UI — hide it
        if MinimapCluster then
            self.clusterWasShown = MinimapCluster:IsShown()
            MinimapCluster:Hide()
        end
    end)

    -- When exiting Edit Mode: lock Minimap, restore MinimapCluster, save position
    LEM:RegisterCallback("exit", function()
        -- Re-lock the strata
        if Minimap.SetFixedFrameStrata then
            Minimap:SetFrameStrata("LOW")
            Minimap:SetFixedFrameStrata(true)
        end
        if Minimap.SetFixedFrameLevel then
            Minimap:SetFrameLevel(2)
            Minimap:SetFixedFrameLevel(true)
        end

        -- Ensure movable is off outside edit mode
        Minimap:SetMovable(false)

        -- Restore MinimapCluster
        if MinimapCluster and self.clusterWasShown ~= nil then
            if self.clusterWasShown then
                MinimapCluster:Show()
            else
                MinimapCluster:Hide()
            end
            self.clusterWasShown = nil
        end

        -- Save final position to DB
        local point, _, relPoint, x, y = Minimap:GetPoint()
        local mm = GetMinimapDB()
        if mm and point then
            mm.position = { point, relPoint or "BOTTOMLEFT", x or 0, y or 0 }
        end
    end)
end

---------------------------------------------------------------------------
-- DELAYED INITIALIZATION
-- Wait for Minimap to be fully set up by suicore_minimap.lua
---------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")

    C_Timer.After(2.0, function()
        MM_EditMode:Initialize()
    end)
end)
