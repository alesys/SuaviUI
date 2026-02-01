--[[
    SuaviUI Castbar Edit Mode Integration
    Registers castbars with Blizzard's Edit Mode using LibEQOLEditMode-1.0
    Provides sidebar settings panel for castbar customization
]]

local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- LIBRARY REFERENCES
---------------------------------------------------------------------------
-- Use LibStub to get LEM directly, same pattern as SenseiClassResourceBar
local LEM = LibStub("LibEQOLEditMode-1.0", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local CB_EditMode = {}
ns.CB_EditMode = CB_EditMode

CB_EditMode.registeredFrames = {}

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

local function GetUFDB()
    local db = GetDB()
    return db and db.suiUnitFrames or nil
end

local function GetCastSettings(unitKey)
    local ufdb = GetUFDB()
    if not ufdb or not ufdb[unitKey] then return nil end
    return ufdb[unitKey].castbar
end

-- Refresh castbar after settings change - NEW: Uses in-place updates instead of recreation
local function RefreshCastbar(unitKey)
    local SUI_Castbar = ns.SUI_Castbar
    
    -- Try to use the new mixin-based refresh (in-place updates)
    if SUI_Castbar and SUI_Castbar.castbars then
        local castbar = SUI_Castbar.castbars[unitKey]
        if castbar and castbar._castbarMixin then
            -- Use mixin's in-place update methods
            castbar._castbarMixin:ApplyLayout(nil, true)
            castbar._castbarMixin:ApplySettings(nil, true)
            return
        end
    end
    
    -- Fallback to old recreation method (for legacy castbars)
    local SUI_UF = ns.SUI_UnitFrames
    if SUI_UF and SUI_UF.RefreshFrame then
        SUI_UF:RefreshFrame(unitKey)
    elseif _G.SuaviUI_RefreshCastbar then
        _G.SuaviUI_RefreshCastbar(unitKey)
    end
end

---------------------------------------------------------------------------
-- TEXTURE LIST FOR DROPDOWNS
---------------------------------------------------------------------------
local function GetTextureList()
    local textures = {}
    if LSM then
        for name in pairs(LSM:HashTable("statusbar")) do
            table.insert(textures, {value = name, text = name})
        end
        table.sort(textures, function(a, b) return a.text < b.text end)
    end
    if #textures == 0 then
        table.insert(textures, {value = "Solid", text = "Solid"})
    end
    return textures
end

---------------------------------------------------------------------------
-- ANCHOR OPTIONS
---------------------------------------------------------------------------
local ANCHOR_OPTIONS = {
    {value = "none", text = "None (Free Position)"},
    {value = "unitframe", text = "Unit Frame"},
}

local PLAYER_ANCHOR_OPTIONS = {
    {value = "none", text = "None (Free Position)"},
    {value = "unitframe", text = "Unit Frame"},
    {value = "essential", text = "Essential Cooldowns"},
    {value = "utility", text = "Utility Cooldowns"},
}

local NINE_POINT_ANCHOR_OPTIONS = {
    {value = "TOPLEFT", text = "Top Left"},
    {value = "TOP", text = "Top"},
    {value = "TOPRIGHT", text = "Top Right"},
    {value = "LEFT", text = "Left"},
    {value = "CENTER", text = "Center"},
    {value = "RIGHT", text = "Right"},
    {value = "BOTTOMLEFT", text = "Bottom Left"},
    {value = "BOTTOM", text = "Bottom"},
    {value = "BOTTOMRIGHT", text = "Bottom Right"},
}

---------------------------------------------------------------------------
-- FRAME LABEL MAPPINGS
---------------------------------------------------------------------------
local FRAME_LABELS = {
    player = "Suavicast: You",
    target = "Suavicast: Target",
    targettarget = "Suavicast: ToT",
    pet = "Suavicast: Pet",
    focus = "Suavicast: Focus",
    boss = "Suavicast: Boss",
}

---------------------------------------------------------------------------
-- POSITION CHANGE CALLBACK
---------------------------------------------------------------------------
local function OnPositionChanged(frame, point, x, y, layoutName)
    if not frame or not frame._suiCastbarUnit then return end
    
    local unitKey = frame._suiCastbarUnit
    local castSettings = GetCastSettings(unitKey)
    if not castSettings then return end
    
    -- Only update position if anchor is nil or "none" (free positioning mode)
    if castSettings.anchor == nil or castSettings.anchor == "none" then
        castSettings.offsetX = math.floor(x + 0.5)
        castSettings.offsetY = math.floor(y + 0.5)
        RefreshCastbar(unitKey)
    end
end

---------------------------------------------------------------------------
-- SETTINGS DEFINITIONS
---------------------------------------------------------------------------

-- Build settings for a castbar
local function BuildCastbarSettings(unitKey)
    local settings = {}
    local order = 100
    
    local isPlayer = (unitKey == "player")
    
    -- =====================================================================
    -- GENERAL CATEGORY
    -- =====================================================================
    table.insert(settings, {
        order = order,
        name = "General",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_GENERAL_" .. unitKey,
        defaultCollapsed = false,
    })
    order = order + 1
    
    -- Enable Castbar
    table.insert(settings, {
        parentId = "CATEGORY_GENERAL_" .. unitKey,
        order = order,
        name = "Enable Castbar",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.enabled ~= false
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.enabled = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Show Spell Icon
    table.insert(settings, {
        parentId = "CATEGORY_GENERAL_" .. unitKey,
        order = order,
        name = "Show Spell Icon",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.showIcon ~= false
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.showIcon = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Use Class Color (player only)
    if isPlayer then
        table.insert(settings, {
            parentId = "CATEGORY_GENERAL_" .. unitKey,
            order = order,
            name = "Use Class Color",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function(layoutName)
                local s = GetCastSettings(unitKey)
                return s and s.useClassColor == true
            end,
            set = function(layoutName, value)
                local s = GetCastSettings(unitKey)
                if s then
                    s.useClassColor = value
                    RefreshCastbar(unitKey)
                end
            end,
        })
        order = order + 1
    end
    
    -- Castbar Color
    table.insert(settings, {
        parentId = "CATEGORY_GENERAL_" .. unitKey,
        order = order,
        name = "Castbar Color",
        kind = LEM.SettingType.Color,
        default = {1, 0.7, 0, 1},
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            if s and s.color then
                return s.color[1] or 1, s.color[2] or 0.7, s.color[3] or 0, s.color[4] or 1
            end
            return 1, 0.7, 0, 1
        end,
        set = function(layoutName, r, g, b, a)
            local s = GetCastSettings(unitKey)
            if s then
                s.color = {r, g, b, a or 1}
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Background Color
    table.insert(settings, {
        parentId = "CATEGORY_GENERAL_" .. unitKey,
        order = order,
        name = "Background Color",
        kind = LEM.SettingType.Color,
        default = {0.149, 0.149, 0.149, 1},
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            if s and s.bgColor then
                return s.bgColor[1] or 0.149, s.bgColor[2] or 0.149, s.bgColor[3] or 0.149, s.bgColor[4] or 1
            end
            return 0.149, 0.149, 0.149, 1
        end,
        set = function(layoutName, r, g, b, a)
            local s = GetCastSettings(unitKey)
            if s then
                s.bgColor = {r, g, b, a or 1}
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Bar Texture
    table.insert(settings, {
        parentId = "CATEGORY_GENERAL_" .. unitKey,
        order = order,
        name = "Bar Texture",
        kind = LEM.SettingType.Dropdown,
        values = GetTextureList(),
        default = "Solid",
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.texture or "Solid"
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.texture = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Border Size
    table.insert(settings, {
        parentId = "CATEGORY_GENERAL_" .. unitKey,
        order = order,
        name = "Border Size",
        kind = LEM.SettingType.Slider,
        default = 1,
        minValue = 0,
        maxValue = 5,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.borderSize or 1
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.borderSize = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- =====================================================================
    -- POSITIONING & SIZE CATEGORY
    -- =====================================================================
    table.insert(settings, {
        order = order,
        name = "Position & Size",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_POSITION_" .. unitKey,
        defaultCollapsed = false,
    })
    order = order + 1
    
    -- Anchor dropdown
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Lock To",
        kind = LEM.SettingType.Dropdown,
        values = isPlayer and PLAYER_ANCHOR_OPTIONS or ANCHOR_OPTIONS,
        default = "none",
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.anchor or "none"
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                -- Treat nil as "none" for comparison purposes
                local wasNone = (s.anchor == nil or s.anchor == "none")
                local isNone = (value == "none")
                
                -- Swap offsets between free and locked modes
                if wasNone and not isNone then
                    s.freeOffsetX = s.offsetX or 0
                    s.freeOffsetY = s.offsetY or 0
                    s.offsetX = s.lockedOffsetX or 0
                    s.offsetY = s.lockedOffsetY or -25
                elseif not wasNone and isNone then
                    s.lockedOffsetX = s.offsetX or 0
                    s.lockedOffsetY = s.offsetY or 0
                    s.offsetX = s.freeOffsetX or 0
                    s.offsetY = s.freeOffsetY or 0
                end
                
                s.anchor = value
                
                -- Clear width for auto-resize anchors
                if value == "essential" or value == "utility" then
                    s.width = 0
                end
                
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Width
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Width",
        kind = LEM.SettingType.Slider,
        default = 250,
        minValue = 50,
        maxValue = 2000,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.width or 250
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.width = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Width Adjustment (for locked modes)
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Width Adjustment",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -500,
        maxValue = 500,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.widthAdjustment or 0
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.widthAdjustment = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Bar Height
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Bar Height",
        kind = LEM.SettingType.Slider,
        default = 25,
        minValue = 4,
        maxValue = 40,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.height or 25
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.height = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- X Offset
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "X Offset",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -3000,
        maxValue = 3000,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.offsetX or 0
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.offsetX = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Y Offset
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Y Offset",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -3000,
        maxValue = 3000,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.offsetY or 0
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.offsetY = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Channel Fill Forward
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Channel Fill Forward",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.channelFillForward == true
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.channelFillForward = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- =====================================================================
    -- ICON SETTINGS CATEGORY
    -- =====================================================================
    table.insert(settings, {
        order = order,
        name = "Icon",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_ICON_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Icon Size
    table.insert(settings, {
        parentId = "CATEGORY_ICON_" .. unitKey,
        order = order,
        name = "Icon Size",
        kind = LEM.SettingType.Slider,
        default = 25,
        minValue = 8,
        maxValue = 80,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.iconSize or 25
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.iconSize = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Icon Scale
    table.insert(settings, {
        parentId = "CATEGORY_ICON_" .. unitKey,
        order = order,
        name = "Icon Scale",
        kind = LEM.SettingType.Slider,
        default = 1.0,
        minValue = 0.5,
        maxValue = 2.0,
        valueStep = 0.1,
        formatter = function(value) return string.format("%.1f", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.iconScale or 1.0
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.iconScale = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Icon Anchor
    table.insert(settings, {
        parentId = "CATEGORY_ICON_" .. unitKey,
        order = order,
        name = "Icon Anchor",
        kind = LEM.SettingType.Dropdown,
        values = NINE_POINT_ANCHOR_OPTIONS,
        default = "LEFT",
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.iconAnchor or "LEFT"
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.iconAnchor = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Icon Spacing
    table.insert(settings, {
        parentId = "CATEGORY_ICON_" .. unitKey,
        order = order,
        name = "Icon Spacing",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.iconSpacing or 0
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.iconSpacing = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Icon Border Size
    table.insert(settings, {
        parentId = "CATEGORY_ICON_" .. unitKey,
        order = order,
        name = "Icon Border Size",
        kind = LEM.SettingType.Slider,
        default = 2,
        minValue = 0,
        maxValue = 5,
        valueStep = 0.1,
        formatter = function(value) return string.format("%.1f", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.iconBorderSize or 2
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.iconBorderSize = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- =====================================================================
    -- TEXT SETTINGS CATEGORY
    -- =====================================================================
    table.insert(settings, {
        order = order,
        name = "Text",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_TEXT_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Font Size
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Font Size",
        kind = LEM.SettingType.Slider,
        default = 12,
        minValue = 8,
        maxValue = 24,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.fontSize or 12
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.fontSize = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Max Length
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Max Text Length (0=none)",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = 0,
        maxValue = 30,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.maxLength or 0
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.maxLength = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Show Spell Text
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Show Spell Text",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.showSpellText ~= false
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.showSpellText = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Spell Text Anchor
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Spell Text Anchor",
        kind = LEM.SettingType.Dropdown,
        values = NINE_POINT_ANCHOR_OPTIONS,
        default = "LEFT",
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.spellTextAnchor or "LEFT"
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.spellTextAnchor = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Spell Text X Offset
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Spell Text X Offset",
        kind = LEM.SettingType.Slider,
        default = 4,
        minValue = -200,
        maxValue = 200,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.spellTextOffsetX or 4
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.spellTextOffsetX = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Spell Text Y Offset
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Spell Text Y Offset",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -200,
        maxValue = 200,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.spellTextOffsetY or 0
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.spellTextOffsetY = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Show Time Text
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Show Time Text",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.showTimeText ~= false
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.showTimeText = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Time Text Anchor
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Time Text Anchor",
        kind = LEM.SettingType.Dropdown,
        values = NINE_POINT_ANCHOR_OPTIONS,
        default = "RIGHT",
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.timeTextAnchor or "RIGHT"
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.timeTextAnchor = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Time Text X Offset
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Time Text X Offset",
        kind = LEM.SettingType.Slider,
        default = -4,
        minValue = -200,
        maxValue = 200,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.timeTextOffsetX or -4
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.timeTextOffsetX = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Time Text Y Offset
    table.insert(settings, {
        parentId = "CATEGORY_TEXT_" .. unitKey,
        order = order,
        name = "Time Text Y Offset",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -200,
        maxValue = 200,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.timeTextOffsetY or 0
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.timeTextOffsetY = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- =====================================================================
    -- EMPOWERED SETTINGS (PLAYER ONLY)
    -- =====================================================================
    if isPlayer then
        table.insert(settings, {
            order = order,
            name = "Empowered Casts",
            kind = LEM.SettingType.Collapsible,
            id = "CATEGORY_EMPOWERED_" .. unitKey,
            defaultCollapsed = true,
        })
        order = order + 1
        
        -- Hide Time Text on Empowered
        table.insert(settings, {
            parentId = "CATEGORY_EMPOWERED_" .. unitKey,
            order = order,
            name = "Hide Time on Empowered",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function(layoutName)
                local s = GetCastSettings(unitKey)
                return s and s.hideTimeTextOnEmpowered == true
            end,
            set = function(layoutName, value)
                local s = GetCastSettings(unitKey)
                if s then
                    s.hideTimeTextOnEmpowered = value
                    RefreshCastbar(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Show Empowered Level
        table.insert(settings, {
            parentId = "CATEGORY_EMPOWERED_" .. unitKey,
            order = order,
            name = "Show Empowered Level",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function(layoutName)
                local s = GetCastSettings(unitKey)
                return s and s.showEmpoweredLevel == true
            end,
            set = function(layoutName, value)
                local s = GetCastSettings(unitKey)
                if s then
                    s.showEmpoweredLevel = value
                    RefreshCastbar(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Empowered Level Text Anchor
        table.insert(settings, {
            parentId = "CATEGORY_EMPOWERED_" .. unitKey,
            order = order,
            name = "Level Text Anchor",
            kind = LEM.SettingType.Dropdown,
            values = NINE_POINT_ANCHOR_OPTIONS,
            default = "CENTER",
            get = function(layoutName)
                local s = GetCastSettings(unitKey)
                return s and s.empoweredLevelTextAnchor or "CENTER"
            end,
            set = function(layoutName, value)
                local s = GetCastSettings(unitKey)
                if s then
                    s.empoweredLevelTextAnchor = value
                    RefreshCastbar(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Empowered Level X Offset
        table.insert(settings, {
            parentId = "CATEGORY_EMPOWERED_" .. unitKey,
            order = order,
            name = "Level Text X Offset",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -200,
            maxValue = 200,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName)
                local s = GetCastSettings(unitKey)
                return s and s.empoweredLevelTextOffsetX or 0
            end,
            set = function(layoutName, value)
                local s = GetCastSettings(unitKey)
                if s then
                    s.empoweredLevelTextOffsetX = value
                    RefreshCastbar(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Empowered Level Y Offset
        table.insert(settings, {
            parentId = "CATEGORY_EMPOWERED_" .. unitKey,
            order = order,
            name = "Level Text Y Offset",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -200,
            maxValue = 200,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName)
                local s = GetCastSettings(unitKey)
                return s and s.empoweredLevelTextOffsetY or 0
            end,
            set = function(layoutName, value)
                local s = GetCastSettings(unitKey)
                if s then
                    s.empoweredLevelTextOffsetY = value
                    RefreshCastbar(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Stage Colors (5 colors)
        for i = 1, 5 do
            local defaultColors = {
                {0.15, 0.38, 0.58, 1},
                {0.55, 0.20, 0.24, 1},
                {0.58, 0.45, 0.18, 1},
                {0.27, 0.50, 0.21, 1},
                {0.45, 0.20, 0.50, 1},
            }
            table.insert(settings, {
                parentId = "CATEGORY_EMPOWERED_" .. unitKey,
                order = order,
                name = "Stage " .. i .. " Color",
                kind = LEM.SettingType.Color,
                default = defaultColors[i],
                get = function(layoutName)
                    local s = GetCastSettings(unitKey)
                    if s and s.empoweredStageColors and s.empoweredStageColors[i] then
                        local c = s.empoweredStageColors[i]
                        return c[1] or defaultColors[i][1], c[2] or defaultColors[i][2], c[3] or defaultColors[i][3], c[4] or 1
                    end
                    return defaultColors[i][1], defaultColors[i][2], defaultColors[i][3], defaultColors[i][4]
                end,
                set = function(layoutName, r, g, b, a)
                    local s = GetCastSettings(unitKey)
                    if s then
                        if not s.empoweredStageColors then s.empoweredStageColors = {} end
                        s.empoweredStageColors[i] = {r, g, b, a or 1}
                        RefreshCastbar(unitKey)
                    end
                end,
            })
            order = order + 1
        end
        
        -- Fill Colors (5 colors)
        for i = 1, 5 do
            local defaultFillColors = {
                {0.26, 0.64, 0.96, 1},
                {0.91, 0.35, 0.40, 1},
                {0.95, 0.75, 0.30, 1},
                {0.45, 0.82, 0.35, 1},
                {0.75, 0.40, 0.85, 1},
            }
            table.insert(settings, {
                parentId = "CATEGORY_EMPOWERED_" .. unitKey,
                order = order,
                name = "Fill " .. i .. " Color",
                kind = LEM.SettingType.Color,
                default = defaultFillColors[i],
                get = function(layoutName)
                    local s = GetCastSettings(unitKey)
                    if s and s.empoweredFillColors and s.empoweredFillColors[i] then
                        local c = s.empoweredFillColors[i]
                        return c[1] or defaultFillColors[i][1], c[2] or defaultFillColors[i][2], c[3] or defaultFillColors[i][3], c[4] or 1
                    end
                    return defaultFillColors[i][1], defaultFillColors[i][2], defaultFillColors[i][3], defaultFillColors[i][4]
                end,
                set = function(layoutName, r, g, b, a)
                    local s = GetCastSettings(unitKey)
                    if s then
                        if not s.empoweredFillColors then s.empoweredFillColors = {} end
                        s.empoweredFillColors[i] = {r, g, b, a or 1}
                        RefreshCastbar(unitKey)
                    end
                end,
            })
            order = order + 1
        end
    end
    
    return settings
end

---------------------------------------------------------------------------
-- FRAME REGISTRATION
---------------------------------------------------------------------------

-- Register a castbar with Edit Mode
function CB_EditMode:RegisterFrame(unitKey, frame)
    if not LEM or not frame then return end
    if self.registeredFrames[unitKey] then return end  -- Already registered
    
    -- Store unit key on frame for callbacks
    frame._suiCastbarUnit = unitKey
    
    -- Set custom Edit Mode label directly on the frame
    frame.editModeName = FRAME_LABELS[unitKey] or ("Suavicast: " .. unitKey:gsub("^%l", string.upper))
    
    -- Get current position
    local s = GetCastSettings(unitKey)
    local defaults = {
        point = "CENTER",
        x = s and s.offsetX or 0,
        y = s and s.offsetY or 0,
    }
    
    -- Register with LibEQOL
    local success, err = pcall(function()
        LEM:AddFrame(frame, OnPositionChanged, defaults)
        
        -- Add settings
        local settings = BuildCastbarSettings(unitKey)
        LEM:AddFrameSettings(frame, settings)
        
        -- Disable position reset when locked to anchor
        LEM:SetFrameResetVisible(frame, function(layoutName)
            local st = GetCastSettings(unitKey)
            -- If settings not found or anchor is nil/"none", allow reset (free positioning mode)
            if not st then return true end
            return st.anchor == nil or st.anchor == "none"
        end)
        
        -- Disable dragging when locked to anchor
        LEM:SetFrameDragEnabled(frame, function(layoutName)
            local st = GetCastSettings(unitKey)
            -- If settings not found or anchor is nil/"none", allow dragging (free positioning mode)
            if not st then return true end
            return st.anchor == nil or st.anchor == "none"
        end)
    end)
    
    if success then
        self.registeredFrames[unitKey] = frame
        
        -- Add visual indicator overlay for Edit Mode visibility
        if not frame._editModeOverlay then
            local overlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
            overlay:SetAllPoints(frame)
            overlay:SetFrameLevel(frame:GetFrameLevel() + 1)
            overlay:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 2,
            })
            overlay:SetBackdropBorderColor(0.3, 0.8, 1, 0.6)  -- Light blue border for visual feedback
            overlay:Hide()  -- Hidden by default, shown when Edit Mode is active/dragging
            frame._editModeOverlay = overlay
        end
    end
end

-- Unregister a frame
function CB_EditMode:UnregisterFrame(unitKey)
    if not LEM then return end
    local frame = self.registeredFrames[unitKey]
    if frame and LEM.RemoveFrame then
        pcall(function()
            LEM:RemoveFrame(frame)
        end)
    end
    self.registeredFrames[unitKey] = nil
end

-- Register all available castbars
function CB_EditMode:RegisterAllFrames()
    -- FIXED: Use correct reference table (SUI_Castbar.castbars, NOT SUI_UnitFrames.castbars)
    local SUI_Castbar = ns.SUI_Castbar
    if not SUI_Castbar or not SUI_Castbar.castbars then return end
    
    for unitKey, castbar in pairs(SUI_Castbar.castbars) do
        if castbar and castbar.statusBar then
            -- Boss frames share settings, only register once
            if unitKey:match("^boss%d+$") then
                if not self.registeredFrames["boss"] then
                    self:RegisterFrame("boss", castbar)
                end
            else
                self:RegisterFrame(unitKey, castbar)
            end
        end
    end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

function CB_EditMode:Initialize()
    if not LEM then
        print("|cFFFF0000SuaviUI:|r LibEQOLEditMode-1.0 not available - castbar Edit Mode disabled")
        return
    end
    
    -- Try to register frames immediately
    self:RegisterAllFrames()
    
    -- FIXED: Hook into SUI_Castbar's CreateCastbar method to register frames as they're created
    -- This ensures frames are registered with proper _suiCastbarUnit BEFORE Edit Mode might need them
    local SUI_Castbar = ns.SUI_Castbar
    if SUI_Castbar then
        hooksecurefunc(SUI_Castbar, "CreateCastbar", function(self, unitFrame, unit, unitKey)
            -- Register newly created castbar (or re-register after recreation)
            if unitKey and self.castbars and self.castbars[unitKey] then
                local castbar = self.castbars[unitKey]
                if castbar and castbar.statusBar then
                    -- Unregister old frame if it exists (recreation case)
                    if CB_EditMode.registeredFrames[unitKey] then
                        CB_EditMode:UnregisterFrame(unitKey)
                    end
                    -- Register the new frame
                    CB_EditMode:RegisterFrame(unitKey, castbar)
                    
                    -- If Edit Mode is active, ensure the castbar is visible
                    local isEditModeActive = EditModeManagerFrame and EditModeManagerFrame:IsShown()
                    if isEditModeActive then
                        castbar:EnableMouse(true)
                        castbar:Show()
                        castbar.isPreviewSimulation = true
                        castbar.previewStartTime = GetTime()
                        castbar.previewEndTime = GetTime() + 3
                        castbar.previewMaxValue = 3
                        castbar.previewValue = 0
                        if castbar._editModeOverlay then
                            castbar._editModeOverlay:Show()
                        end
                    end
                end
            end
        end)
    end
    
    -- Register callbacks for Edit Mode enter/exit
    LEM:RegisterCallback("enter", function()
        -- Enable edit mode overlay display for visual feedback
        for unitKey, castbar in pairs(self.registeredFrames) do
            if castbar._editModeOverlay then
                castbar._editModeOverlay:Show()
            end
        end
        
        -- Immediately show all enabled castbars and set up preview animation
        local SUI_Castbar = ns.SUI_Castbar
        if SUI_Castbar and SUI_Castbar.castbars then
            for unitKey, castbar in pairs(SUI_Castbar.castbars) do
                if castbar then
                    local settings = GetCastSettings(unitKey)
                    if settings and settings.enabled ~= false then
                        castbar:EnableMouse(true)
                        castbar:Show()
                        
                        -- Set up preview animation data so OnUpdate doesn't hide it
                        castbar.isPreviewSimulation = true
                        castbar.previewStartTime = GetTime()
                        castbar.previewEndTime = GetTime() + 3
                        castbar.previewMaxValue = 3
                        castbar.previewValue = 0
                        
                        -- Set OnUpdate to keep castbar visible
                        if castbar.castbarOnUpdate or castbar.playerOnUpdate then
                            local onUpdate = castbar.castbarOnUpdate or castbar.playerOnUpdate
                            castbar:SetScript("OnUpdate", onUpdate)
                        end
                    end
                end
            end
        end
    end)
    
    LEM:RegisterCallback("exit", function()
        -- Hide visual overlays
        for unitKey, castbar in pairs(self.registeredFrames) do
            if castbar._editModeOverlay then
                castbar._editModeOverlay:Hide()
            end
        end
        
        -- Clear preview state and hide castbars if not actually casting
        C_Timer.After(0.05, function()
            local SUI_Castbar = ns.SUI_Castbar
            if SUI_Castbar and SUI_Castbar.castbars then
                for unitKey, castbar in pairs(SUI_Castbar.castbars) do
                    if castbar then
                        castbar:SetScript("OnUpdate", nil)
                        -- Hide if not actively casting
                        if not UnitCastingInfo(castbar.unit) and not UnitChannelInfo(castbar.unit) then
                            castbar:Hide()
                        end
                    end
                end
            end
        end)
    end)
end

---------------------------------------------------------------------------
-- DELAYED INITIALIZATION
---------------------------------------------------------------------------
-- Wait for both LEM and unit frames to be ready
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Delay to ensure all modules are loaded (after unit frames init at 3s)
    C_Timer.After(4, function()
        CB_EditMode:Initialize()
    end)
end)

-- Debug Window
local debugWindow = nil

local function CreateDebugWindow()
    if debugWindow then return debugWindow end
    
    local frame = CreateFrame("Frame", "SUI_CastbarDebugWindow", UIParent, "BackdropTemplate")
    frame:SetSize(500, 400)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText("|cFF56D1FFSuaviUI|r Castbar Debug")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)
    
    -- Edit box (for selectable/copyable text)
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() - 10)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    
    frame.editBox = editBox
    
    -- Copy All button
    local copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copyBtn:SetSize(100, 22)
    copyBtn:SetPoint("BOTTOMLEFT", 10, 10)
    copyBtn:SetText("Select All")
    copyBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(100, 22)
    refreshBtn:SetPoint("LEFT", copyBtn, "RIGHT", 10, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        CB_EditMode:ShowDebugStatus()
    end)
    
    debugWindow = frame
    return frame
end

function CB_EditMode:ShowDebugStatus()
    local window = CreateDebugWindow()
    local lines = {}
    
    table.insert(lines, "=== SuaviUI Castbar Edit Mode Debug ===")
    table.insert(lines, "Generated: " .. date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "")
    
    table.insert(lines, "=== LEM Status ===")
    table.insert(lines, "LibEQOLEditMode: " .. (LEM and "Loaded ✓" or "NOT LOADED ✗"))
    table.insert(lines, "LEM:IsInEditMode(): " .. (LEM and LEM:IsInEditMode() and "YES ✓" or "NO"))
    table.insert(lines, "EditModeManagerFrame:IsShown(): " .. (EditModeManagerFrame and EditModeManagerFrame:IsShown() and "YES ✓" or "NO"))
    
    -- Check LEM internal state
    if LEM then
        local lemState = LEM.State or (LEM.internal and LEM.internal.State)
        if lemState then
            table.insert(lines, "LEM.State available: YES ✓")
            local dragPredCount = 0
            if lemState.dragPredicates then
                for _ in pairs(lemState.dragPredicates) do dragPredCount = dragPredCount + 1 end
            end
            table.insert(lines, "  dragPredicates count: " .. dragPredCount)
            
            local selRegCount = 0
            if lemState.selectionRegistry then
                for _ in pairs(lemState.selectionRegistry) do selRegCount = selRegCount + 1 end
            end
            table.insert(lines, "  selectionRegistry count: " .. selRegCount)
        else
            table.insert(lines, "LEM.State available: NO (checking lib.dragPredicates)")
            if LEM.dragPredicates then
                local count = 0
                for _ in pairs(LEM.dragPredicates) do count = count + 1 end
                table.insert(lines, "  lib.dragPredicates count: " .. count)
            end
        end
    end
    
    table.insert(lines, "")
    table.insert(lines, "=== Registered Castbars ===")
    
    local SUI_Castbar = ns.SUI_Castbar
    if SUI_Castbar and SUI_Castbar.castbars then
        for unitKey, castbar in pairs(SUI_Castbar.castbars) do
            local name = castbar:GetName() or "UNNAMED"
            local hasStatusBar = castbar.statusBar and "✓" or "✗"
            local isShown = castbar:IsShown() and "SHOWN" or "HIDDEN"
            local width, height = castbar:GetSize()
            local mouseEnabled = castbar:IsMouseEnabled() and "✓" or "✗"
            
            table.insert(lines, "")
            table.insert(lines, string.format("[%s] %s", unitKey:upper(), name))
            table.insert(lines, string.format("  Size: %.0fx%.0f  Visible: %s  Mouse: %s", width or 0, height or 0, isShown, mouseEnabled))
            
            -- Check our registration
            local ourReg = CB_EditMode.registeredFrames[unitKey] and "✓" or "✗"
            table.insert(lines, string.format("  CB_EditMode registered: %s", ourReg))
            
            -- Check LEM internal registration
            if LEM then
                local lemState = LEM.State or (LEM.internal and LEM.internal.State)
                local dragPreds = (lemState and lemState.dragPredicates) or LEM.dragPredicates
                local selReg = lemState and lemState.selectionRegistry
                
                if dragPreds then
                    local hasDragPred = dragPreds[castbar] ~= nil
                    table.insert(lines, string.format("  LEM dragPredicate set: %s", hasDragPred and "✓" or "✗"))
                    
                    if hasDragPred then
                        local pred = dragPreds[castbar]
                        local predType = type(pred)
                        table.insert(lines, string.format("  Predicate type: %s", predType))
                        
                        if predType == "function" then
                            local ok, result = pcall(pred, LEM.activeLayoutName or "Unknown")
                            if ok then
                                table.insert(lines, string.format("  Predicate returns: %s", tostring(result)))
                            else
                                table.insert(lines, string.format("  Predicate ERROR: %s", tostring(result)))
                            end
                        else
                            table.insert(lines, string.format("  Predicate value: %s", tostring(pred)))
                        end
                    end
                end
                
                if selReg then
                    local hasSelection = selReg[castbar] ~= nil
                    table.insert(lines, string.format("  LEM selectionRegistry: %s", hasSelection and "✓" or "✗"))
                    if hasSelection then
                        local sel = selReg[castbar]
                        table.insert(lines, string.format("    Selection shown: %s", sel:IsShown() and "YES" or "NO"))
                        table.insert(lines, string.format("    Selection mouse: %s", sel:IsMouseEnabled() and "YES" or "NO"))
                    end
                end
            end
            
            -- Check cast settings
            local castSettings = GetCastSettings(unitKey)
            if castSettings then
                table.insert(lines, string.format("  Settings found: ✓"))
                table.insert(lines, string.format("  anchor = %s", tostring(castSettings.anchor)))
            else
                table.insert(lines, string.format("  Settings found: ✗ (nil!)"))
            end
        end
    else
        table.insert(lines, "No castbars found in ns.SUI_Castbar.castbars")
    end
    
    table.insert(lines, "")
    table.insert(lines, "=== Commands ===")
    table.insert(lines, "/suicbeditmode status - Show this window")
    table.insert(lines, "/suicbeditmode force - Force re-register")
    
    window.editBox:SetText(table.concat(lines, "\n"))
    window:Show()
    
    print("|cFF56D1FFSuaviUI:|r Debug window opened. Check castbar drag info above.")
end

-- Debug command
SLASH_SUICBEDITMODE1 = "/suicbeditmode"
SlashCmdList["SUICBEDITMODE"] = function(msg)
    local cmd = msg:lower():trim()
    
    if cmd == "register" then
        CB_EditMode:RegisterAllFrames()
        print("|cFF56D1FFSuaviUI|r: Castbars registered with Edit Mode")
    elseif cmd == "status" then
        CB_EditMode:ShowDebugStatus()
    elseif cmd == "force" then
        print("|cFF56D1FFSuaviUI|r: Force registering castbars...")
        local SUI_UF = ns.SUI_UnitFrames
        if SUI_UF and SUI_UF.castbars then
            for unitKey, castbar in pairs(SUI_UF.castbars) do
                if castbar then
                    local name = castbar:GetName() or "UNNAMED"
                    print("  Trying to register: " .. unitKey .. " (" .. name .. ")")
                    CB_EditMode.registeredFrames[unitKey] = nil  -- Clear existing
                    CB_EditMode:RegisterFrame(unitKey, castbar)
                    if CB_EditMode.registeredFrames[unitKey] then
                        print("    SUCCESS")
                    else
                        print("    FAILED")
                    end
                end
            end
        else
            print("  ERROR: No castbars found")
        end
        CB_EditMode:ShowDebugStatus()
    else
        print("|cFF56D1FFSuaviUI|r: Castbar Edit Mode Commands:")
        print("  /suicbeditmode status - Show debug window")
        print("  /suicbeditmode register - Manually register all castbars")
        print("  /suicbeditmode force - Force re-register with debug")
    end
end
