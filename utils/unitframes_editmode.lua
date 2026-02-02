--[[
    Unit Frames Edit Mode Integration
    Adds Blizzard Edit Mode sidebar panels for SuaviUI unit frames
    Uses LibEQOLEditMode-1.0 for native Edit Mode integration
]]

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local LEM = LibStub("LibEQOLEditMode-1.0", true)
local LSM = LibStub("LibSharedMedia-3.0")

-- Early exit if library not available
if not LEM then
    return
end

-- Anchor value constants (LEM stores the text, not the value)
local ANCHOR_NONE = "None (Free Position)"
local ANCHOR_ESSENTIAL = "Essential CDM"
local ANCHOR_UTILITY = "Utility CDM"
local ANCHOR_PRIMARY = "Primary Resource Bar"
local ANCHOR_SECONDARY = "Secondary Resource Bar"

-- Helper to check if frame is freely positionable (not anchored)
-- Handles both short values ("disabled") and text values ("None (Free Position)")
local function IsFrameFreelyPositioned(anchorTo)
    if not anchorTo then return true end
    if anchorTo == "disabled" then return true end
    if anchorTo == ANCHOR_NONE then return true end  -- Handle legacy text storage
    return false
end

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local UF_EditMode = {}
ns.UF_EditMode = UF_EditMode

-- Track registered frames
UF_EditMode.registeredFrames = {}

---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------

-- Get the unit frames database
local function GetUFDB()
    if not SUICore or not SUICore.db or not SUICore.db.profile then
        return nil
    end
    -- Database path: SUICore.db.profile.suiUnitFrames (not "unitframes")
    return SUICore.db.profile.suiUnitFrames
end

-- Get settings for a specific unit
local function GetUnitSettings(unitKey)
    local ufdb = GetUFDB()
    if not ufdb then return nil end
    return ufdb[unitKey]
end

-- Get texture list for dropdown
local function GetTextureList()
    local textures = {}
    local lsmTextures = LSM:HashTable(LSM.MediaType.STATUSBAR)
    for name, path in pairs(lsmTextures) do
        table.insert(textures, { text = name, value = name })
    end
    table.sort(textures, function(a, b) return a.text < b.text end)
    return textures
end

-- Refresh unit frame after settings change
local function RefreshUnitFrame(unitKey)
    local SUI_UF = ns.SUI_UnitFrames
    if SUI_UF then
        -- Use the correct method: RefreshFrame for single unit, RefreshAll for all
        if SUI_UF.RefreshFrame then
            SUI_UF:RefreshFrame(unitKey)
        elseif SUI_UF.RefreshAll then
            SUI_UF:RefreshAll()
        end
    end
    -- Also refresh anchored frames
    if _G.SuaviUI_UpdateAnchoredUnitFrames then
        _G.SuaviUI_UpdateAnchoredUnitFrames()
    end
end

-- Update anchored unit frames (player/target anchored to CDM/resource bars)
local function UpdateAnchoredFrames()
    if _G.SuaviUI_UpdateAnchoredUnitFrames then
        _G.SuaviUI_UpdateAnchoredUnitFrames()
    end
end

---------------------------------------------------------------------------
-- FRAME LABEL MAPPINGS
---------------------------------------------------------------------------
local FRAME_LABELS = {
    player = "Suaviframe: You",
    target = "Suaviframe: Target",
    targettarget = "Suaviframe: ToT",
    pet = "Suaviframe: Pet",
    focus = "Suaviframe: Focus",
    boss = "Suaviframe: Boss",
}

local FRAME_NAMES = {
    player = "sui_Player",
    target = "sui_Target",
    targettarget = "sui_TargetTarget",
    pet = "sui_Pet",
    focus = "sui_Focus",
    boss = "sui_Boss1",  -- Register boss1 as the main boss frame
}

---------------------------------------------------------------------------
-- SETTINGS DEFINITIONS
---------------------------------------------------------------------------

-- Build settings for a unit frame
local function BuildUnitFrameSettings(unitKey)
    local settings = {}
    local order = 100
    
    -- Position & Size Category
    table.insert(settings, {
        order = order,
        name = "Position & Size",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_POSITION_" .. unitKey,
        defaultCollapsed = false,
    })
    order = order + 1
    
    -- X Offset
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "X Offset",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -2000,
        maxValue = 2000,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.offsetX or 0
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.offsetX = value
                RefreshUnitFrame(unitKey)
            end
        end,
        isEnabled = function(layoutName, layoutIndex)
            -- Disabled if anchored (player/target)
            local s = GetUnitSettings(unitKey)
            return IsFrameFreelyPositioned(s and s.anchorTo)
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
        minValue = -2000,
        maxValue = 2000,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.offsetY or 0
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.offsetY = value
                RefreshUnitFrame(unitKey)
            end
        end,
        isEnabled = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return IsFrameFreelyPositioned(s and s.anchorTo)
        end,
    })
    order = order + 1
    
    -- Width
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Width",
        kind = LEM.SettingType.Slider,
        default = 220,
        minValue = 100,
        maxValue = 500,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.width or 220
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.width = value
                RefreshUnitFrame(unitKey)
                -- Update locked castbar width if player
                if unitKey == "player" and _G.SuaviUI_UpdateLockedCastbarToFrame then
                    _G.SuaviUI_UpdateLockedCastbarToFrame()
                end
            end
        end,
    })
    order = order + 1
    
    -- Height
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Height",
        kind = LEM.SettingType.Slider,
        default = 45,
        minValue = 20,
        maxValue = 100,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.height or 45
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.height = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Border Size
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Border Size",
        kind = LEM.SettingType.Slider,
        default = 1,
        minValue = 0,
        maxValue = 5,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.borderSize or 1
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.borderSize = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Boss frames: Spacing slider
    if unitKey == "boss" then
        table.insert(settings, {
            parentId = "CATEGORY_POSITION_" .. unitKey,
            order = order,
            name = "Spacing",
            kind = LEM.SettingType.Slider,
            default = 10,
            minValue = 0,
            maxValue = 100,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.spacing or 10
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    s.spacing = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
    end
    
    -- Anchoring Category (Player/Target only)
    if unitKey == "player" or unitKey == "target" then
        table.insert(settings, {
            order = order,
            name = "Frame Anchoring",
            kind = LEM.SettingType.Collapsible,
            id = "CATEGORY_ANCHOR_" .. unitKey,
            defaultCollapsed = true,
        })
        order = order + 1
        
        -- Anchor To dropdown
        -- LEM stores the text, so we map between stored values and display text
        local ANCHOR_VALUE_TO_TEXT = {
            ["disabled"] = ANCHOR_NONE,
            ["essential"] = ANCHOR_ESSENTIAL,
            ["utility"] = ANCHOR_UTILITY,
            ["primary"] = ANCHOR_PRIMARY,
            ["secondary"] = ANCHOR_SECONDARY,
            -- Also handle if text was previously stored
            [ANCHOR_NONE] = ANCHOR_NONE,
            [ANCHOR_ESSENTIAL] = ANCHOR_ESSENTIAL,
            [ANCHOR_UTILITY] = ANCHOR_UTILITY,
            [ANCHOR_PRIMARY] = ANCHOR_PRIMARY,
            [ANCHOR_SECONDARY] = ANCHOR_SECONDARY,
        }
        local ANCHOR_TEXT_TO_VALUE = {
            [ANCHOR_NONE] = "disabled",
            [ANCHOR_ESSENTIAL] = "essential",
            [ANCHOR_UTILITY] = "utility",
            [ANCHOR_PRIMARY] = "primary",
            [ANCHOR_SECONDARY] = "secondary",
        }
        
        table.insert(settings, {
            parentId = "CATEGORY_ANCHOR_" .. unitKey,
            order = order,
            name = "Anchor To",
            kind = LEM.SettingType.Dropdown,
            default = ANCHOR_NONE,
            useOldStyle = true,
            values = {
                { text = ANCHOR_NONE, value = ANCHOR_NONE },
                { text = ANCHOR_ESSENTIAL, value = ANCHOR_ESSENTIAL },
                { text = ANCHOR_UTILITY, value = ANCHOR_UTILITY },
                { text = ANCHOR_PRIMARY, value = ANCHOR_PRIMARY },
                { text = ANCHOR_SECONDARY, value = ANCHOR_SECONDARY },
            },
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                local storedVal = s and s.anchorTo or "disabled"
                return ANCHOR_VALUE_TO_TEXT[storedVal] or ANCHOR_NONE
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    -- Convert text back to short value for storage
                    s.anchorTo = ANCHOR_TEXT_TO_VALUE[value] or "disabled"
                    RefreshUnitFrame(unitKey)
                    UpdateAnchoredFrames()
                end
            end,
        })
        order = order + 1
        
        -- Horizontal Gap
        table.insert(settings, {
            parentId = "CATEGORY_ANCHOR_" .. unitKey,
            order = order,
            name = "Horizontal Gap",
            kind = LEM.SettingType.Slider,
            default = 10,
            minValue = 0,
            maxValue = 100,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.anchorGap or 10
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    s.anchorGap = value
                    UpdateAnchoredFrames()
                end
            end,
            isEnabled = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return not IsFrameFreelyPositioned(s and s.anchorTo)
            end,
        })
        order = order + 1
        
        -- Vertical Offset
        table.insert(settings, {
            parentId = "CATEGORY_ANCHOR_" .. unitKey,
            order = order,
            name = "Vertical Offset",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -200,
            maxValue = 200,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.anchorYOffset or 0
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    s.anchorYOffset = value
                    UpdateAnchoredFrames()
                end
            end,
            isEnabled = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return not IsFrameFreelyPositioned(s and s.anchorTo)
            end,
        })
        order = order + 1
    end
    
    -- Appearance Category
    table.insert(settings, {
        order = order,
        name = "Appearance",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_APPEARANCE_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Bar Texture dropdown
    table.insert(settings, {
        parentId = "CATEGORY_APPEARANCE_" .. unitKey,
        order = order,
        name = "Bar Texture",
        kind = LEM.SettingType.Dropdown,
        default = "Blizzard",
        useOldStyle = true,
        height = 200,
        values = GetTextureList(),
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.texture or "Blizzard"
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.texture = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Use Class Color
    table.insert(settings, {
        parentId = "CATEGORY_APPEARANCE_" .. unitKey,
        order = order,
        name = "Use Class Color",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.useClassColor
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.useClassColor = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Use Hostility Color (non-player frames)
    if unitKey ~= "player" then
        table.insert(settings, {
            parentId = "CATEGORY_APPEARANCE_" .. unitKey,
            order = order,
            name = "Use Hostility Color",
            kind = LEM.SettingType.Checkbox,
            default = false,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.useHostilityColor
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    s.useHostilityColor = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
    end
    
    -- Custom Health Color
    table.insert(settings, {
        parentId = "CATEGORY_APPEARANCE_" .. unitKey,
        order = order,
        name = "Custom Health Color",
        kind = LEM.SettingType.Color,
        default = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
        hasOpacity = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s and s.customHealthColor then
                local c = s.customHealthColor
                return { r = c[1] or 0.2, g = c[2] or 0.2, b = c[3] or 0.2, a = 1 }
            end
            return { r = 0.2, g = 0.2, b = 0.2, a = 1 }
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.customHealthColor = { value.r, value.g, value.b }
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    ---------------------------------------------------------------------------
    -- POWER BAR CATEGORY
    ---------------------------------------------------------------------------
    table.insert(settings, {
        order = order,
        name = "Power Bar",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_POWER_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Show Power Bar
    table.insert(settings, {
        parentId = "CATEGORY_POWER_" .. unitKey,
        order = order,
        name = "Show Power Bar",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.showPowerBar
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.showPowerBar = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Power Bar Height
    table.insert(settings, {
        parentId = "CATEGORY_POWER_" .. unitKey,
        order = order,
        name = "Height",
        kind = LEM.SettingType.Slider,
        default = 4,
        minValue = 1,
        maxValue = 20,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.powerBarHeight or 4
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.powerBarHeight = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Power Bar Border
    table.insert(settings, {
        parentId = "CATEGORY_POWER_" .. unitKey,
        order = order,
        name = "Show Border",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.powerBarBorder ~= false
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.powerBarBorder = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Use Power Type Color
    table.insert(settings, {
        parentId = "CATEGORY_POWER_" .. unitKey,
        order = order,
        name = "Use Power Type Color",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.powerBarUsePowerColor ~= false
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.powerBarUsePowerColor = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Custom Power Bar Color
    table.insert(settings, {
        parentId = "CATEGORY_POWER_" .. unitKey,
        order = order,
        name = "Custom Bar Color",
        kind = LEM.SettingType.Color,
        default = { r = 0, g = 0.5, b = 1, a = 1 },
        hasOpacity = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s and s.powerBarColor then
                local c = s.powerBarColor
                return { r = c[1] or 0, g = c[2] or 0.5, b = c[3] or 1, a = 1 }
            end
            return { r = 0, g = 0.5, b = 1, a = 1 }
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.powerBarColor = { value.r, value.g, value.b }
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    ---------------------------------------------------------------------------
    -- NAME TEXT CATEGORY
    ---------------------------------------------------------------------------
    table.insert(settings, {
        order = order,
        name = "Name Text",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_NAME_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Show Name
    table.insert(settings, {
        parentId = "CATEGORY_NAME_" .. unitKey,
        order = order,
        name = "Show Name",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.showName ~= false
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.showName = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Name Font Size
    table.insert(settings, {
        parentId = "CATEGORY_NAME_" .. unitKey,
        order = order,
        name = "Font Size",
        kind = LEM.SettingType.Slider,
        default = 12,
        minValue = 8,
        maxValue = 24,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.nameFontSize or 12
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.nameFontSize = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Name Anchor
    local anchorOptions = (ns.Constants and ns.Constants.ANCHOR_POINT_OPTIONS) or {
        { text = "Top Left", value = "TOPLEFT" },
        { text = "Top", value = "TOP" },
        { text = "Top Right", value = "TOPRIGHT" },
        { text = "Left", value = "LEFT" },
        { text = "Center", value = "CENTER" },
        { text = "Right", value = "RIGHT" },
        { text = "Bottom Left", value = "BOTTOMLEFT" },
        { text = "Bottom", value = "BOTTOM" },
        { text = "Bottom Right", value = "BOTTOMRIGHT" },
    }
    
    table.insert(settings, {
        parentId = "CATEGORY_NAME_" .. unitKey,
        order = order,
        name = "Anchor",
        kind = LEM.SettingType.Dropdown,
        default = ns.Constants and ns.Constants.DEFAULTS and ns.Constants.DEFAULTS.TEXT_ANCHOR or "TOPLEFT",
        useOldStyle = true,
        values = anchorOptions,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.nameAnchor or (ns.Constants and ns.Constants.DEFAULTS and ns.Constants.DEFAULTS.TEXT_ANCHOR or "TOPLEFT")
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.nameAnchor = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Name X Offset
    table.insert(settings, {
        parentId = "CATEGORY_NAME_" .. unitKey,
        order = order,
        name = "X Offset",
        kind = LEM.SettingType.Slider,
        default = 4,
        minValue = -100,
        maxValue = 100,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.nameOffsetX or 4
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.nameOffsetX = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Name Y Offset
    table.insert(settings, {
        parentId = "CATEGORY_NAME_" .. unitKey,
        order = order,
        name = "Y Offset",
        kind = LEM.SettingType.Slider,
        default = -2,
        minValue = -50,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.nameOffsetY or -2
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.nameOffsetY = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Max Name Length
    table.insert(settings, {
        parentId = "CATEGORY_NAME_" .. unitKey,
        order = order,
        name = "Max Length (0=none)",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = 0,
        maxValue = 30,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.maxNameLength or 0
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.maxNameLength = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Name Text Color
    table.insert(settings, {
        parentId = "CATEGORY_NAME_" .. unitKey,
        order = order,
        name = "Custom Color",
        kind = LEM.SettingType.Color,
        default = { r = 1, g = 1, b = 1, a = 1 },
        hasOpacity = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s and s.nameTextColor then
                local c = s.nameTextColor
                return { r = c[1] or 1, g = c[2] or 1, b = c[3] or 1, a = 1 }
            end
            return { r = 1, g = 1, b = 1, a = 1 }
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.nameTextColor = { value.r, value.g, value.b }
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    ---------------------------------------------------------------------------
    -- HEALTH TEXT CATEGORY
    ---------------------------------------------------------------------------
    table.insert(settings, {
        order = order,
        name = "Health Text",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_HEALTH_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Show Health
    table.insert(settings, {
        parentId = "CATEGORY_HEALTH_" .. unitKey,
        order = order,
        name = "Show Health",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.showHealth ~= false
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.showHealth = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Health Display Style
    local healthStyleOptions = {
        { text = "Percent Only (75%)", value = "percent" },
        { text = "Value Only (45.2k)", value = "absolute" },
        { text = "Value | Percent", value = "both" },
        { text = "Percent | Value", value = "both_reverse" },
        { text = "Missing Percent (-25%)", value = "missing_percent" },
        { text = "Missing Value (-12.5k)", value = "missing_value" },
    }
    
    table.insert(settings, {
        parentId = "CATEGORY_HEALTH_" .. unitKey,
        order = order,
        name = "Display Style",
        kind = LEM.SettingType.Dropdown,
        default = "percent",
        useOldStyle = true,
        values = healthStyleOptions,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.healthDisplayStyle or "percent"
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.healthDisplayStyle = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Health Text Size
    table.insert(settings, {
        parentId = "CATEGORY_HEALTH_" .. unitKey,
        order = order,
        name = "Font Size",
        kind = LEM.SettingType.Slider,
        default = 12,
        minValue = 1,
        maxValue = 20,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.healthTextSize or 12
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.healthTextSize = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Health Text Color
    table.insert(settings, {
        parentId = "CATEGORY_HEALTH_" .. unitKey,
        order = order,
        name = "Custom Color",
        kind = LEM.SettingType.Color,
        default = { r = 1, g = 1, b = 1, a = 1 },
        hasOpacity = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s and s.healthTextColor then
                local c = s.healthTextColor
                return { r = c[1] or 1, g = c[2] or 1, b = c[3] or 1, a = 1 }
            end
            return { r = 1, g = 1, b = 1, a = 1 }
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.healthTextColor = { value.r, value.g, value.b }
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    ---------------------------------------------------------------------------
    -- ABSORB INDICATOR CATEGORY
    ---------------------------------------------------------------------------
    table.insert(settings, {
        order = order,
        name = "Absorb Indicator",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_ABSORB_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Show Absorb
    table.insert(settings, {
        parentId = "CATEGORY_ABSORB_" .. unitKey,
        order = order,
        name = "Show Absorb Shields",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.absorbs and s.absorbs.enabled ~= false
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.absorbs then s.absorbs = {} end
                s.absorbs.enabled = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Absorb Opacity
    table.insert(settings, {
        parentId = "CATEGORY_ABSORB_" .. unitKey,
        order = order,
        name = "Opacity",
        kind = LEM.SettingType.Slider,
        default = 0.7,
        minValue = 0,
        maxValue = 1,
        valueStep = 0.05,
        formatter = function(value) return string.format("%.0f%%", value * 100) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.absorbs and s.absorbs.opacity or 0.7
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.absorbs then s.absorbs = {} end
                s.absorbs.opacity = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Absorb Color
    table.insert(settings, {
        parentId = "CATEGORY_ABSORB_" .. unitKey,
        order = order,
        name = "Color",
        kind = LEM.SettingType.Color,
        default = { r = 0.2, g = 0.8, b = 0.8, a = 1 },
        hasOpacity = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s and s.absorbs and s.absorbs.color then
                local c = s.absorbs.color
                return { r = c[1] or 0.2, g = c[2] or 0.8, b = c[3] or 0.8, a = 1 }
            end
            return { r = 0.2, g = 0.8, b = 0.8, a = 1 }
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.absorbs then s.absorbs = {} end
                s.absorbs.color = { value.r, value.g, value.b }
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    ---------------------------------------------------------------------------
    -- POWER TEXT CATEGORY
    ---------------------------------------------------------------------------
    table.insert(settings, {
        order = order,
        name = "Power Text",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_POWER_TEXT_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Show Power Text
    table.insert(settings, {
        parentId = "CATEGORY_POWER_TEXT_" .. unitKey,
        order = order,
        name = "Show Power Text",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.showPowerText
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.showPowerText = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Power Text Format
    local powerTextFormatOptions = {
        { text = "Percent (75%)", value = "percent" },
        { text = "Current (12.5k)", value = "current" },
        { text = "Both (12.5k | 75%)", value = "both" },
    }
    
    table.insert(settings, {
        parentId = "CATEGORY_POWER_TEXT_" .. unitKey,
        order = order,
        name = "Display Format",
        kind = LEM.SettingType.Dropdown,
        default = "percent",
        useOldStyle = true,
        values = powerTextFormatOptions,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.powerTextFormat or "percent"
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.powerTextFormat = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Power Text Font Size
    table.insert(settings, {
        parentId = "CATEGORY_POWER_TEXT_" .. unitKey,
        order = order,
        name = "Font Size",
        kind = LEM.SettingType.Slider,
        default = 10,
        minValue = 8,
        maxValue = 24,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.powerTextFontSize or 10
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.powerTextFontSize = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Power Text Anchor
    table.insert(settings, {
        parentId = "CATEGORY_POWER_TEXT_" .. unitKey,
        order = order,
        name = "Anchor",
        kind = LEM.SettingType.Dropdown,
        default = ns.Constants and ns.Constants.DEFAULTS and ns.Constants.DEFAULTS.POWER_TEXT_ANCHOR or "BOTTOMRIGHT",
        useOldStyle = true,
        values = anchorOptions,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.powerTextAnchor or (ns.Constants and ns.Constants.DEFAULTS and ns.Constants.DEFAULTS.POWER_TEXT_ANCHOR or "BOTTOMRIGHT")
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.powerTextAnchor = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Power Text Use Power Color
    table.insert(settings, {
        parentId = "CATEGORY_POWER_TEXT_" .. unitKey,
        order = order,
        name = "Use Power Type Color",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.powerTextUsePowerColor ~= false
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.powerTextUsePowerColor = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Power Text Custom Color
    table.insert(settings, {
        parentId = "CATEGORY_POWER_TEXT_" .. unitKey,
        order = order,
        name = "Custom Color",
        kind = LEM.SettingType.Color,
        default = { r = 1, g = 1, b = 1, a = 1 },
        hasOpacity = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s and s.powerTextColor then
                local c = s.powerTextColor
                return { r = c[1] or 1, g = c[2] or 1, b = c[3] or 1, a = 1 }
            end
            return { r = 1, g = 1, b = 1, a = 1 }
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                s.powerTextColor = { value.r, value.g, value.b }
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    ---------------------------------------------------------------------------
    -- DEBUFF ICONS CATEGORY
    ---------------------------------------------------------------------------
    table.insert(settings, {
        order = order,
        name = "Debuff Icons",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_DEBUFFS_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Show Debuffs
    table.insert(settings, {
        parentId = "CATEGORY_DEBUFFS_" .. unitKey,
        order = order,
        name = "Show Debuffs",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.showDebuffs
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.showDebuffs = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Only My Debuffs (non-player)
    if unitKey ~= "player" then
        table.insert(settings, {
            parentId = "CATEGORY_DEBUFFS_" .. unitKey,
            order = order,
            name = "Only My Debuffs",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.auras and s.auras.onlyMyDebuffs ~= false
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.auras then s.auras = {} end
                    s.auras.onlyMyDebuffs = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
    end
    
    -- Hide Duration Swipe
    table.insert(settings, {
        parentId = "CATEGORY_DEBUFFS_" .. unitKey,
        order = order,
        name = "Hide Duration Swipe",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.debuffHideSwipe
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.debuffHideSwipe = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Debuff Icon Size
    table.insert(settings, {
        parentId = "CATEGORY_DEBUFFS_" .. unitKey,
        order = order,
        name = "Icon Size",
        kind = LEM.SettingType.Slider,
        default = 22,
        minValue = 12,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.iconSize or 22
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.iconSize = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Debuff Max Icons
    table.insert(settings, {
        parentId = "CATEGORY_DEBUFFS_" .. unitKey,
        order = order,
        name = "Max Icons",
        kind = LEM.SettingType.Slider,
        default = 16,
        minValue = 1,
        maxValue = 32,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.debuffMaxIcons or 16
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.debuffMaxIcons = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Debuff Anchor
    local auraAnchorOptions = (ns.Constants and ns.Constants.ANCHOR_POINT_OPTIONS) or {
        { text = "Top Left", value = "TOPLEFT" },
        { text = "Top Right", value = "TOPRIGHT" },
        { text = "Bottom Left", value = "BOTTOMLEFT" },
        { text = "Bottom Right", value = "BOTTOMRIGHT" },
    }
    
    table.insert(settings, {
        parentId = "CATEGORY_DEBUFFS_" .. unitKey,
        order = order,
        name = "Anchor",
        kind = LEM.SettingType.Dropdown,
        default = ns.Constants and ns.Constants.DEFAULTS and ns.Constants.DEFAULTS.DEBUFF_ANCHOR or "TOPLEFT",
        useOldStyle = true,
        values = auraAnchorOptions,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.debuffAnchor or (ns.Constants and ns.Constants.DEFAULTS and ns.Constants.DEFAULTS.DEBUFF_ANCHOR or "TOPLEFT")
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.debuffAnchor = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Debuff Grow Direction
    local growOptions = {
        { text = "Left", value = "LEFT" },
        { text = "Right", value = "RIGHT" },
        { text = "Up", value = "UP" },
        { text = "Down", value = "DOWN" },
    }
    
    table.insert(settings, {
        parentId = "CATEGORY_DEBUFFS_" .. unitKey,
        order = order,
        name = "Grow Direction",
        kind = LEM.SettingType.Dropdown,
        default = "RIGHT",
        useOldStyle = true,
        values = growOptions,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.debuffGrow or "RIGHT"
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.debuffGrow = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Debuff X Offset
    table.insert(settings, {
        parentId = "CATEGORY_DEBUFFS_" .. unitKey,
        order = order,
        name = "X Offset",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -100,
        maxValue = 100,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.debuffOffsetX or 0
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.debuffOffsetX = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Debuff Y Offset
    table.insert(settings, {
        parentId = "CATEGORY_DEBUFFS_" .. unitKey,
        order = order,
        name = "Y Offset",
        kind = LEM.SettingType.Slider,
        default = 2,
        minValue = -100,
        maxValue = 100,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.debuffOffsetY or 2
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.debuffOffsetY = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Debuff Spacing
    table.insert(settings, {
        parentId = "CATEGORY_DEBUFFS_" .. unitKey,
        order = order,
        name = "Spacing",
        kind = LEM.SettingType.Slider,
        default = 2,
        minValue = 0,
        maxValue = 10,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.debuffSpacing or 2
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.debuffSpacing = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    ---------------------------------------------------------------------------
    -- BUFF ICONS CATEGORY
    ---------------------------------------------------------------------------
    table.insert(settings, {
        order = order,
        name = "Buff Icons",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_BUFFS_" .. unitKey,
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Show Buffs
    table.insert(settings, {
        parentId = "CATEGORY_BUFFS_" .. unitKey,
        order = order,
        name = "Show Buffs",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.showBuffs
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.showBuffs = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Hide Buff Swipe
    table.insert(settings, {
        parentId = "CATEGORY_BUFFS_" .. unitKey,
        order = order,
        name = "Hide Duration Swipe",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.buffHideSwipe
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.buffHideSwipe = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Buff Icon Size
    table.insert(settings, {
        parentId = "CATEGORY_BUFFS_" .. unitKey,
        order = order,
        name = "Icon Size",
        kind = LEM.SettingType.Slider,
        default = 22,
        minValue = 12,
        maxValue = 50,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.buffIconSize or 22
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.buffIconSize = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Buff Max Icons
    table.insert(settings, {
        parentId = "CATEGORY_BUFFS_" .. unitKey,
        order = order,
        name = "Max Icons",
        kind = LEM.SettingType.Slider,
        default = 16,
        minValue = 1,
        maxValue = 32,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.buffMaxIcons or 16
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.buffMaxIcons = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Buff Anchor
    table.insert(settings, {
        parentId = "CATEGORY_BUFFS_" .. unitKey,
        order = order,
        name = "Anchor",
        kind = LEM.SettingType.Dropdown,
        default = ns.Constants and ns.Constants.DEFAULTS and ns.Constants.DEFAULTS.BUFF_ANCHOR or "BOTTOMLEFT",
        useOldStyle = true,
        values = auraAnchorOptions,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.buffAnchor or (ns.Constants and ns.Constants.DEFAULTS and ns.Constants.DEFAULTS.BUFF_ANCHOR or "BOTTOMLEFT")
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.buffAnchor = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Buff Grow Direction
    table.insert(settings, {
        parentId = "CATEGORY_BUFFS_" .. unitKey,
        order = order,
        name = "Grow Direction",
        kind = LEM.SettingType.Dropdown,
        default = "RIGHT",
        useOldStyle = true,
        values = growOptions,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.buffGrow or "RIGHT"
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.buffGrow = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Buff X Offset
    table.insert(settings, {
        parentId = "CATEGORY_BUFFS_" .. unitKey,
        order = order,
        name = "X Offset",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -100,
        maxValue = 100,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.buffOffsetX or 0
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.buffOffsetX = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Buff Y Offset
    table.insert(settings, {
        parentId = "CATEGORY_BUFFS_" .. unitKey,
        order = order,
        name = "Y Offset",
        kind = LEM.SettingType.Slider,
        default = -2,
        minValue = -100,
        maxValue = 100,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.buffOffsetY or -2
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.buffOffsetY = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Buff Spacing
    table.insert(settings, {
        parentId = "CATEGORY_BUFFS_" .. unitKey,
        order = order,
        name = "Spacing",
        kind = LEM.SettingType.Slider,
        default = 2,
        minValue = 0,
        maxValue = 10,
        valueStep = 1,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName, layoutIndex)
            local s = GetUnitSettings(unitKey)
            return s and s.auras and s.auras.buffSpacing or 2
        end,
        set = function(layoutName, value, layoutIndex)
            local s = GetUnitSettings(unitKey)
            if s then
                if not s.auras then s.auras = {} end
                s.auras.buffSpacing = value
                RefreshUnitFrame(unitKey)
            end
        end,
    })
    order = order + 1
    
    ---------------------------------------------------------------------------
    -- CASTBAR CATEGORY (for units that have castbars)
    ---------------------------------------------------------------------------
    if unitKey == "player" or unitKey == "target" or unitKey == "focus" or unitKey == "pet" or unitKey == "targettarget" or unitKey == "boss" then
        table.insert(settings, {
            order = order,
            name = "Castbar",
            kind = LEM.SettingType.Collapsible,
            id = "CATEGORY_CASTBAR_" .. unitKey,
            defaultCollapsed = true,
        })
        order = order + 1
        
        -- Enable Castbar
        table.insert(settings, {
            parentId = "CATEGORY_CASTBAR_" .. unitKey,
            order = order,
            name = "Enable Castbar",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.castbar and s.castbar.enabled ~= false
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.castbar then s.castbar = {} end
                    s.castbar.enabled = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Castbar Width
        table.insert(settings, {
            parentId = "CATEGORY_CASTBAR_" .. unitKey,
            order = order,
            name = "Width",
            kind = LEM.SettingType.Slider,
            default = 220,
            minValue = 50,
            maxValue = 500,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.castbar and s.castbar.width or 220
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.castbar then s.castbar = {} end
                    s.castbar.width = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Castbar Height
        table.insert(settings, {
            parentId = "CATEGORY_CASTBAR_" .. unitKey,
            order = order,
            name = "Height",
            kind = LEM.SettingType.Slider,
            default = 20,
            minValue = 10,
            maxValue = 50,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.castbar and s.castbar.height or 20
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.castbar then s.castbar = {} end
                    s.castbar.height = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Castbar X Offset
        table.insert(settings, {
            parentId = "CATEGORY_CASTBAR_" .. unitKey,
            order = order,
            name = "X Offset",
            kind = LEM.SettingType.Slider,
            default = 0,
            minValue = -500,
            maxValue = 500,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.castbar and s.castbar.offsetX or 0
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.castbar then s.castbar = {} end
                    s.castbar.offsetX = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Castbar Y Offset
        table.insert(settings, {
            parentId = "CATEGORY_CASTBAR_" .. unitKey,
            order = order,
            name = "Y Offset",
            kind = LEM.SettingType.Slider,
            default = -30,
            minValue = -500,
            maxValue = 500,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.castbar and s.castbar.offsetY or -30
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.castbar then s.castbar = {} end
                    s.castbar.offsetY = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Show Icon
        table.insert(settings, {
            parentId = "CATEGORY_CASTBAR_" .. unitKey,
            order = order,
            name = "Show Icon",
            kind = LEM.SettingType.Checkbox,
            default = true,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.castbar and s.castbar.showIcon ~= false
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.castbar then s.castbar = {} end
                    s.castbar.showIcon = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Font Size
        table.insert(settings, {
            parentId = "CATEGORY_CASTBAR_" .. unitKey,
            order = order,
            name = "Font Size",
            kind = LEM.SettingType.Slider,
            default = 12,
            minValue = 8,
            maxValue = 24,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.castbar and s.castbar.fontSize or 12
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.castbar then s.castbar = {} end
                    s.castbar.fontSize = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Border Size
        table.insert(settings, {
            parentId = "CATEGORY_CASTBAR_" .. unitKey,
            order = order,
            name = "Border Size",
            kind = LEM.SettingType.Slider,
            default = 1,
            minValue = 0,
            maxValue = 5,
            valueStep = 1,
            formatter = function(value) return string.format("%d", value) end,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                return s and s.castbar and s.castbar.borderSize or 1
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.castbar then s.castbar = {} end
                    s.castbar.borderSize = value
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
        
        -- Castbar Color
        table.insert(settings, {
            parentId = "CATEGORY_CASTBAR_" .. unitKey,
            order = order,
            name = "Bar Color",
            kind = LEM.SettingType.Color,
            default = { r = 1, g = 0.7, b = 0, a = 1 },
            hasOpacity = false,
            get = function(layoutName, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s and s.castbar and s.castbar.color then
                    local c = s.castbar.color
                    return { r = c[1] or 1, g = c[2] or 0.7, b = c[3] or 0, a = 1 }
                end
                return { r = 1, g = 0.7, b = 0, a = 1 }
            end,
            set = function(layoutName, value, layoutIndex)
                local s = GetUnitSettings(unitKey)
                if s then
                    if not s.castbar then s.castbar = {} end
                    s.castbar.color = { value.r, value.g, value.b }
                    RefreshUnitFrame(unitKey)
                end
            end,
        })
        order = order + 1
    end
    
    return settings
end

---------------------------------------------------------------------------
-- POSITION CALLBACK
---------------------------------------------------------------------------

-- Called when frame is dragged in Edit Mode
local function OnPositionChanged(frame, layoutName, point, x, y)
    local unitKey = frame._suiUnitKey
    if not unitKey then return end
    
    local s = GetUnitSettings(unitKey)
    if not s then return end
    
    -- Don't save position if anchored
    if not IsFrameFreelyPositioned(s.anchorTo) then
        return
    end
    
    -- Convert to center-based offsets (our system uses CENTER anchor)
    local selfX, selfY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if selfX and selfY and parentX and parentY then
        s.offsetX = math.floor(selfX - parentX + 0.5)
        s.offsetY = math.floor(selfY - parentY + 0.5)
    end
end

---------------------------------------------------------------------------
-- FRAME REGISTRATION
---------------------------------------------------------------------------

-- Register a unit frame with Edit Mode
function UF_EditMode:RegisterFrame(unitKey, frame)
    if not LEM or not frame then return end
    if self.registeredFrames[unitKey] then return end  -- Already registered
    
    -- Store unit key on frame for callbacks
    frame._suiUnitKey = unitKey
    
    -- Set custom Edit Mode label directly on the frame (this is what LEM reads)
    frame.editModeName = FRAME_LABELS[unitKey] or ("Suaviframe: " .. unitKey:gsub("^%l", string.upper))
    
    -- Get default position
    local s = GetUnitSettings(unitKey)
    local defaults = {
        point = "CENTER",
        x = s and s.offsetX or 0,
        y = s and s.offsetY or 0,
    }
    
    -- Register with LibEQOL
    local success, err = pcall(function()
        LEM:AddFrame(frame, OnPositionChanged, defaults)
        
        -- Add settings
        local settings = BuildUnitFrameSettings(unitKey)
        LEM:AddFrameSettings(frame, settings)
        
        -- Disable position reset for anchored frames (only when actively anchored, not "disabled")
        if unitKey == "player" or unitKey == "target" then
            LEM:SetFrameResetVisible(frame, function(layoutName)
                local st = GetUnitSettings(unitKey)
                return IsFrameFreelyPositioned(st and st.anchorTo)
            end)
        end
        
        -- Disable dragging for anchored frames (only when actively anchored, not "disabled")
        if unitKey == "player" or unitKey == "target" then
            LEM:SetFrameDragEnabled(frame, function(layoutName)
                local st = GetUnitSettings(unitKey)
                return IsFrameFreelyPositioned(st and st.anchorTo)
            end)
        end
    end)
    
    if success then
        self.registeredFrames[unitKey] = frame
    else
        -- Silent fail - frame registration failed
    end
end

-- Unregister a frame
function UF_EditMode:UnregisterFrame(unitKey)
    if not LEM then return end
    local frame = self.registeredFrames[unitKey]
    if frame and LEM.RemoveFrame then
        pcall(function()
            LEM:RemoveFrame(frame)
        end)
    end
    self.registeredFrames[unitKey] = nil
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

-- Register all existing frames
function UF_EditMode:RegisterAllFrames()
    local SUI_UF = ns.SUI_UnitFrames
    if not SUI_UF or not SUI_UF.frames then return end
    
    for unitKey, frame in pairs(SUI_UF.frames) do
        -- For boss frames, only register boss1
        if unitKey:match("^boss%d+$") then
            if unitKey == "boss1" then
                self:RegisterFrame("boss", frame)
            end
        else
            self:RegisterFrame(unitKey, frame)
        end
    end
end

-- Hook into frame creation to auto-register
function UF_EditMode:HookFrameCreation()
    local SUI_UF = ns.SUI_UnitFrames
    if not SUI_UF then return end
    
    -- Hook CreateUnitFrame if it exists
    if SUI_UF.CreateUnitFrame then
        local orig = SUI_UF.CreateUnitFrame
        SUI_UF.CreateUnitFrame = function(self, unitKey, ...)
            local frame = orig(self, unitKey, ...)
            -- Delay registration to ensure frame is fully set up
            C_Timer.After(0.5, function()
                if unitKey:match("^boss%d+$") then
                    if unitKey == "boss1" then
                        UF_EditMode:RegisterFrame("boss", frame)
                    end
                else
                    UF_EditMode:RegisterFrame(unitKey, frame)
                end
            end)
            return frame
        end
    end
end

-- Initialize the module
function UF_EditMode:Initialize()
    if not LEM then return end
    
    -- Wait for unit frames to be created
    C_Timer.After(2, function()
        self:RegisterAllFrames()
    end)
    
    -- Hook future frame creation
    self:HookFrameCreation()
    
    local function EnsureRegisteredAndShow()
        self:RegisterAllFrames()
    end

    -- Register callbacks for Edit Mode events
    LEM:RegisterCallback("enter", function()
        -- Refresh all frame settings when entering Edit Mode
        for unitKey, frame in pairs(self.registeredFrames) do
            if LEM.RefreshFrameSettings then
                pcall(function()
                    LEM:RefreshFrameSettings(frame)
                end)
            end
        end
        
    end)
    
    LEM:RegisterCallback("exit", function()
        -- Ensure frames are properly positioned on exit
        local SUI_UF = ns.SUI_UnitFrames
        if SUI_UF and SUI_UF.RefreshFrames then
            C_Timer.After(0.1, function()
                SUI_UF:RefreshFrames()
            end)
        end
    end)

    -- Fallback hooks for Edit Mode UI show/hide (covers cases where LEM callbacks don't fire)
    if EditModeManagerFrame then
        if EditModeManagerFrame:HasScript("OnShow") then
            EditModeManagerFrame:HookScript("OnShow", function()
                EnsureRegisteredAndShow()
            end)
        end
        if EditModeManagerFrame:HasScript("OnHide") then
            EditModeManagerFrame:HookScript("OnHide", function()
                -- No-op: selection overlays handled by LibEQOL
            end)
        end
    end
end

---------------------------------------------------------------------------
-- AUTO-INITIALIZE ON ADDON LOAD
---------------------------------------------------------------------------

-- Create initialization frame
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        -- Delay to ensure all modules are loaded
        C_Timer.After(3, function()
            UF_EditMode:Initialize()
        end)
    end
end)

-- Export to global
if not _G.SuaviUI then _G.SuaviUI = {} end
_G.SuaviUI.UF_EditMode = UF_EditMode

-- Global convenience function to manually trigger registration
_G.SuaviUI_RegisterUnitFramesEditMode = function()
    UF_EditMode:RegisterAllFrames()
end

-- Debug command
SLASH_SUIUFEDITMODE1 = "/suiufeditmode"
SlashCmdList["SUIUFEDITMODE"] = function(msg)
    local cmd = msg:lower():trim()
    
    if cmd == "register" then
        UF_EditMode:RegisterAllFrames()
        print("|cFF56D1FFSuaviUI|r: Unit frames registered with Edit Mode")
    elseif cmd == "status" then
        print("|cFF56D1FFSuaviUI|r: Unit Frames Edit Mode Status")
        print("  LibEQOLEditMode: " .. (LEM and "Loaded" or "NOT LOADED"))
        print("  Registered frames:")
        for unitKey, frame in pairs(UF_EditMode.registeredFrames) do
            print("    - " .. unitKey .. ": " .. (frame:GetName() or "unnamed"))
        end
    else
        print("|cFF56D1FFSuaviUI|r: Unit Frames Edit Mode Commands:")
        print("  /suiufeditmode register - Manually register all unit frames")
        print("  /suiufeditmode status - Show registration status")
    end
end

-- Debug command: Edit Mode overlay state (library-safe)
SLASH_SUIEMDEBUG1 = "/suiemdebug"
SlashCmdList["SUIEMDEBUG"] = function(msg)
    local isEditModeShown = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    local isLemEdit = (LEM and LEM.IsInEditMode) and LEM:IsInEditMode() or false
    print(string.format("|cFF56D1FFSuaviUI|r EditMode: managerShown=%s lemIsEditing=%s", tostring(isEditModeShown), tostring(isLemEdit)))

    local total = 0
    for unitKey, frame in pairs(UF_EditMode.registeredFrames) do
        total = total + 1
        local name = frame and frame.GetName and frame:GetName() or "<unnamed>"
        local shown = frame and frame.IsShown and frame:IsShown() or false
        local mouse = frame and frame.IsMouseEnabled and frame:IsMouseEnabled() or false
        local children = frame and { frame:GetChildren() } or {}

        local selectionChild = false
        for _, child in ipairs(children) do
            if child and child.ShowHighlighted and child.Label and child.Text then
                selectionChild = true
                break
            end
        end

        print(string.format("  %s: name=%s shown=%s mouse=%s children=%d hasSelection=%s", unitKey, tostring(name), tostring(shown), tostring(mouse), #children, tostring(selectionChild)))
    end
    print(string.format("  Registered unit frames: %d", total))
end
