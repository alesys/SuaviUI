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
CB_EditMode.allOverlaysHidden = false  -- Track global "hide all overlays" state

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
    if not ufdb then return nil end
    
    -- Boss frames (boss1-boss5) share settings from "boss" key
    local settingsKey = unitKey
    if unitKey:match("^boss%d$") then
        settingsKey = "boss"
    end
    
    if not ufdb[settingsKey] then return nil end
    return ufdb[settingsKey].castbar
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
local Constants = ns.Constants or {}
local ANCHOR_OPTIONS = (Constants.CASTBAR_ANCHOR_OPTIONS) or {
    {text = (Constants.CASTBAR_ANCHOR_TEXT and Constants.CASTBAR_ANCHOR_TEXT.NONE) or "None (Free Position)", value = (Constants.CASTBAR_ANCHOR and Constants.CASTBAR_ANCHOR.NONE) or "none"},
    {text = (Constants.CASTBAR_ANCHOR_TEXT and Constants.CASTBAR_ANCHOR_TEXT.UNIT_FRAME) or "Unit Frame", value = (Constants.CASTBAR_ANCHOR and Constants.CASTBAR_ANCHOR.UNIT_FRAME) or "unitframe"},
}

local PLAYER_ANCHOR_OPTIONS = (Constants.CASTBAR_PLAYER_ANCHOR_OPTIONS) or {
    {text = (Constants.CASTBAR_ANCHOR_TEXT and Constants.CASTBAR_ANCHOR_TEXT.NONE) or "None (Free Position)", value = (Constants.CASTBAR_ANCHOR and Constants.CASTBAR_ANCHOR.NONE) or "none"},
    {text = (Constants.CASTBAR_ANCHOR_TEXT and Constants.CASTBAR_ANCHOR_TEXT.UNIT_FRAME) or "Unit Frame", value = (Constants.CASTBAR_ANCHOR and Constants.CASTBAR_ANCHOR.UNIT_FRAME) or "unitframe"},
    {text = (Constants.CASTBAR_ANCHOR_TEXT and Constants.CASTBAR_ANCHOR_TEXT.ESSENTIAL) or "Essential Cooldowns", value = (Constants.CASTBAR_ANCHOR and Constants.CASTBAR_ANCHOR.ESSENTIAL) or "essential"},
    {text = (Constants.CASTBAR_ANCHOR_TEXT and Constants.CASTBAR_ANCHOR_TEXT.UTILITY) or "Utility Cooldowns", value = (Constants.CASTBAR_ANCHOR and Constants.CASTBAR_ANCHOR.UTILITY) or "utility"},
}

local CASTBAR_ANCHOR = (Constants and Constants.CASTBAR_ANCHOR) or {
    NONE = "none",
    UNIT_FRAME = "unitframe",
    ESSENTIAL = "essential",
    UTILITY = "utility",
}

local CASTBAR_ANCHOR_TEXT = (Constants and Constants.CASTBAR_ANCHOR_TEXT) or {
    NONE = "None (Free Position)",
    UNIT_FRAME = "Unit Frame",
    ESSENTIAL = "Essential Cooldowns",
    UTILITY = "Utility Cooldowns",
}

local ANCHOR_TEXT_TO_VALUE = {
    [CASTBAR_ANCHOR_TEXT.NONE] = CASTBAR_ANCHOR.NONE,
    [CASTBAR_ANCHOR_TEXT.UNIT_FRAME] = CASTBAR_ANCHOR.UNIT_FRAME,
}

local PLAYER_ANCHOR_TEXT_TO_VALUE = {
    [CASTBAR_ANCHOR_TEXT.NONE] = CASTBAR_ANCHOR.NONE,
    [CASTBAR_ANCHOR_TEXT.UNIT_FRAME] = CASTBAR_ANCHOR.UNIT_FRAME,
    [CASTBAR_ANCHOR_TEXT.ESSENTIAL] = CASTBAR_ANCHOR.ESSENTIAL,
    [CASTBAR_ANCHOR_TEXT.UTILITY] = CASTBAR_ANCHOR.UTILITY,
}

local ANCHOR_VALUE_TO_TEXT = {
    [CASTBAR_ANCHOR.NONE] = CASTBAR_ANCHOR_TEXT.NONE,
    [CASTBAR_ANCHOR.UNIT_FRAME] = CASTBAR_ANCHOR_TEXT.UNIT_FRAME,
}

local PLAYER_ANCHOR_VALUE_TO_TEXT = {
    [CASTBAR_ANCHOR.NONE] = CASTBAR_ANCHOR_TEXT.NONE,
    [CASTBAR_ANCHOR.UNIT_FRAME] = CASTBAR_ANCHOR_TEXT.UNIT_FRAME,
    [CASTBAR_ANCHOR.ESSENTIAL] = CASTBAR_ANCHOR_TEXT.ESSENTIAL,
    [CASTBAR_ANCHOR.UTILITY] = CASTBAR_ANCHOR_TEXT.UTILITY,
}

local function AnchorValueToText(value, isPlayer)
    local v = value or CASTBAR_ANCHOR.NONE
    if isPlayer then
        return PLAYER_ANCHOR_VALUE_TO_TEXT[v] or CASTBAR_ANCHOR_TEXT.NONE
    end
    return ANCHOR_VALUE_TO_TEXT[v] or CASTBAR_ANCHOR_TEXT.NONE
end

local function AnchorTextToValue(text, isPlayer)
    local t = text or CASTBAR_ANCHOR_TEXT.NONE
    if isPlayer then
        return PLAYER_ANCHOR_TEXT_TO_VALUE[t] or CASTBAR_ANCHOR.NONE
    end
    return ANCHOR_TEXT_TO_VALUE[t] or CASTBAR_ANCHOR.NONE
end

local NINE_POINT_ANCHOR_OPTIONS = (ns.Constants and ns.Constants.ANCHOR_POINT_OPTIONS) or {
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
-- WIDTH MODE OPTIONS
---------------------------------------------------------------------------
-- Use centralized WIDTH_MODE constants
local WIDTH_MODE = Constants.WIDTH_MODE or {
    MANUAL = "Manual",
    SYNC_UNIT_FRAME = "Sync With Unit Frame",
    SYNC_ESSENTIAL = "Sync With Essential Cooldowns",
    SYNC_UTILITY = "Sync With Utility Cooldowns",
    SYNC_TRACKED_BUFFS = "Sync With Tracked Buffs",
}

local WIDTH_MODE_OPTIONS = {
    {value = WIDTH_MODE.MANUAL, text = WIDTH_MODE.MANUAL},
    {value = WIDTH_MODE.SYNC_UNIT_FRAME, text = WIDTH_MODE.SYNC_UNIT_FRAME},
}

local PLAYER_WIDTH_MODE_OPTIONS = {
    {value = WIDTH_MODE.MANUAL, text = WIDTH_MODE.MANUAL},
    {value = WIDTH_MODE.SYNC_UNIT_FRAME, text = WIDTH_MODE.SYNC_UNIT_FRAME},
    {value = WIDTH_MODE.SYNC_ESSENTIAL, text = WIDTH_MODE.SYNC_ESSENTIAL},
    {value = WIDTH_MODE.SYNC_UTILITY, text = WIDTH_MODE.SYNC_UTILITY},
    {value = WIDTH_MODE.SYNC_TRACKED_BUFFS, text = WIDTH_MODE.SYNC_TRACKED_BUFFS},
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
local function OnPositionChanged(frame, layoutName, point, x, y)
    -- DEBUG: Log all parameters
    CB_EditMode:LogDebug("OnPositionChanged called: frame=" .. tostring(frame and frame:GetName()) .. 
                         " layoutName=" .. tostring(layoutName) .. 
                         " point=" .. tostring(point) .. 
                         " x=" .. tostring(x) .. 
                         " y=" .. tostring(y))
    
    if not frame or not frame._suiCastbarUnit then 
        CB_EditMode:ReportDebug("OnPositionChanged: Early return - no frame or unitKey")
        return 
    end
    
    local unitKey = frame._suiCastbarUnit
    local castSettings = GetCastSettings(unitKey)
    if not castSettings then 
        CB_EditMode:ReportDebug("OnPositionChanged: Early return - no castSettings for " .. unitKey)
        return 
    end

    -- Normalize argument order in case the callback supplies swapped values
    -- Expected: layoutName (string), point (string), x (number), y (number)
    if type(layoutName) == "number" and type(point) == "string" and type(x) == "string" and tonumber(y) then
        local actualLayout = point
        local actualPoint = x
        local actualX = layoutName
        local actualY = y
        layoutName, point, x, y = actualLayout, actualPoint, actualX, actualY
        CB_EditMode:LogDebug("OnPositionChanged: Normalized arguments")
    end
    
    -- Prefer actual frame center to avoid coordinate mismatches
    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not cy or not ux or not uy then
        local nx = tonumber(x)
        local ny = tonumber(y)
        if not nx or not ny then
            CB_EditMode:ReportDebug("OnPositionChanged: non-numeric offsets x=" .. tostring(x) .. " y=" .. tostring(y))
            return
        end
        cx, cy = nx + ux, ny + uy
    end

    local nx = cx - ux
    local ny = cy - uy
    
    -- Check if castbar is anchored to something
    local anchor = castSettings.anchor or CASTBAR_ANCHOR.NONE
    local isAnchored = (anchor ~= CASTBAR_ANCHOR.NONE) and (anchor ~= "disabled")
    
    if isAnchored then
        -- Switch to free positioning when the user drags an anchored castbar
        CB_EditMode:LogDebug("OnPositionChanged: switching to free position from anchor " .. tostring(anchor))
        -- Preserve locked offsets for later re-anchoring
        if castSettings.lockedOffsetX == nil then castSettings.lockedOffsetX = castSettings.offsetX or 0 end
        if castSettings.lockedOffsetY == nil then castSettings.lockedOffsetY = castSettings.offsetY or 0 end
        -- Save free offsets
        castSettings.freeOffsetX = math.floor(nx + 0.5)
        castSettings.freeOffsetY = math.floor(ny + 0.5)
        castSettings.offsetX = castSettings.freeOffsetX
        castSettings.offsetY = castSettings.freeOffsetY
        castSettings.anchor = CASTBAR_ANCHOR.NONE
    else
        -- Save position for free-positioned castbars
        castSettings.offsetX = math.floor(nx + 0.5)
        castSettings.offsetY = math.floor(ny + 0.5)
    end
    
    CB_EditMode:LogDebug("OnPositionChanged: " .. unitKey .. " position saved to (" .. castSettings.offsetX .. ", " .. castSettings.offsetY .. ")")
    
    -- Apply the new position immediately
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", castSettings.offsetX, castSettings.offsetY)
    CB_EditMode:LogDebug("OnPositionChanged: SetPoint called")
    
    -- Update sidebar values using LEM's internal API
    if LEM and LEM.internal and LEM.internal.RefreshSettingValues then
        CB_EditMode:LogDebug("OnPositionChanged: Calling RefreshSettingValues")
        LEM.internal:RefreshSettingValues({"Anchor To", "X Offset", "Y Offset"})
    else
        CB_EditMode:ReportDebug("OnPositionChanged: LEM.internal.RefreshSettingValues not available")
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
    
    -- Preview Mode
    table.insert(settings, {
        parentId = "CATEGORY_GENERAL_" .. unitKey,
        order = order,
        name = "Preview Mode",
        kind = LEM.SettingType.Checkbox,
        default = false,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.previewMode == true
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.previewMode = value
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
        default = "Solid",
        useOldStyle = true,
        height = 200,
        generator = function(dropdown, rootDescription, settingObject)
            -- Initialize texture pool for previews
            dropdown.texturePool = {}

            -- Hook cleanup on menu close
            if not dropdown._CB_Texture_Dropdown_OnMenuClosed_hooked then
                hooksecurefunc(dropdown, "OnMenuClosed", function()
                    for _, texture in pairs(dropdown.texturePool) do
                        texture:Hide()
                    end
                end)
                dropdown._CB_Texture_Dropdown_OnMenuClosed_hooked = true
            end

            local layoutName = LEM.GetActiveLayoutName() or "Default"

            -- Set current texture as default text
            dropdown:SetDefaultText(settingObject.get(layoutName))

            if not LSM then
                local fallback = "Solid"
                rootDescription:CreateButton(fallback, function()
                    dropdown:SetDefaultText(fallback)
                    settingObject.set(layoutName, fallback)
                end)
                return
            end

            -- Get and sort available textures
            local textures = LSM:HashTable("statusbar")
            local sortedTextures = {}
            for textureName in pairs(textures) do
                table.insert(sortedTextures, textureName)
            end
            table.sort(sortedTextures)

            -- Create button for each texture with preview
            for index, textureName in ipairs(sortedTextures) do
                local texturePath = textures[textureName]

                local button = rootDescription:CreateButton(textureName, function()
                    dropdown:SetDefaultText(textureName)
                    settingObject.set(layoutName, textureName)
                end)

                -- Add texture preview to button
                if texturePath then
                    button:AddInitializer(function(self)
                        local texturePreview = dropdown.texturePool[index]
                        if not texturePreview then
                            texturePreview = dropdown:CreateTexture(nil, "BACKGROUND")
                            dropdown.texturePool[index] = texturePreview
                        end

                        texturePreview:SetParent(self)
                        texturePreview:SetAllPoints(self)
                        texturePreview:SetTexture(texturePath)

                        texturePreview:Show()
                    end)
                end
            end
        end,
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
        name = "Anchor To",
        kind = LEM.SettingType.Dropdown,
        values = isPlayer and PLAYER_ANCHOR_OPTIONS or ANCHOR_OPTIONS,
        default = CASTBAR_ANCHOR_TEXT.NONE,
           useOldStyle = true,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return AnchorValueToText(s and s.anchor, isPlayer)
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                value = AnchorTextToValue(value, isPlayer)
                -- Treat nil as "none" for comparison purposes
                local wasNone = (s.anchor == nil or s.anchor == CASTBAR_ANCHOR.NONE)
                local isNone = (value == CASTBAR_ANCHOR.NONE)
                
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
                
                -- Keep manual width intact for Width Mode fallback
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Width Mode
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Width Mode",
        kind = LEM.SettingType.Dropdown,
        values = isPlayer and PLAYER_WIDTH_MODE_OPTIONS or WIDTH_MODE_OPTIONS,
        default = WIDTH_MODE.MANUAL,
        useOldStyle = true,
        get = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.widthMode or WIDTH_MODE.MANUAL
        end,
        set = function(layoutName, value)
            local s = GetCastSettings(unitKey)
            if s then
                s.widthMode = value
                RefreshCastbar(unitKey)
            end
        end,
    })
    order = order + 1
    
    -- Width (only visible in Manual mode)
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
        isEnabled = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.widthMode == WIDTH_MODE.MANUAL or (not s)
        end,
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
    
    -- Width Adjustment (for synced modes)
    table.insert(settings, {
        parentId = "CATEGORY_POSITION_" .. unitKey,
        order = order,
        name = "Width Adjustment",
        kind = LEM.SettingType.Slider,
        default = 0,
        minValue = -500,
        maxValue = 500,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%d", value) end,
        isEnabled = function(layoutName)
            local s = GetCastSettings(unitKey)
            return s and s.widthMode ~= WIDTH_MODE.MANUAL or (not s)
        end,
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
        allowInput = true,
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
        minValue = -2000,
        maxValue = 2000,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%5d", value) end,
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
        minValue = -2000,
        maxValue = 2000,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%5d", value) end,
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

    -- Show Spell Icon
    table.insert(settings, {
        parentId = "CATEGORY_ICON_" .. unitKey,
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
        allowInput = true,
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
        allowInput = true,
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
        useOldStyle = true,
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
        allowInput = true,
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
        allowInput = true,
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
        allowInput = true,
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
        allowInput = true,
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
        useOldStyle = true,
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
        useOldStyle = true,
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
        allowInput = true,
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
        allowInput = true,
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
            useOldStyle = true,
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
            allowInput = true,
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
            allowInput = true,
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
        
        -- Override magnetism to add distance threshold and prevent wild snapping
        -- Only snap to frames within 500 pixels (reasonable screen distance)
        if frame.GetFrameMagneticEligibility then
            local SNAP_DISTANCE_THRESHOLD = 500
            local originalGetFrameMagneticEligibility = frame.GetFrameMagneticEligibility
            
            frame.GetFrameMagneticEligibility = function(self, systemFrame)
                -- First check the original eligibility (alignment check)
                local horizontalEligible, verticalEligible = originalGetFrameMagneticEligibility(self, systemFrame)
                if not horizontalEligible and not verticalEligible then
                    return nil, nil
                end
                
                -- Add distance check to prevent snapping to faraway frames
                local myLeft, myRight, myBottom, myTop = self:GetScaledSelectionSides()
                local otherLeft, otherRight, otherBottom, otherTop = systemFrame:GetScaledSelectionSides()
                
                local myCenterX = (myLeft + myRight) / 2
                local myCenterY = (myBottom + myTop) / 2
                local otherCenterX = (otherLeft + otherRight) / 2
                local otherCenterY = (otherBottom + otherTop) / 2
                
                local distance = math.sqrt((myCenterX - otherCenterX)^2 + (myCenterY - otherCenterY)^2)
                
                -- If too far away, don't snap
                if distance > SNAP_DISTANCE_THRESHOLD then
                    return nil, nil
                end
                
                return horizontalEligible, verticalEligible
            end
        end
        
        -- Disable position reset when locked to anchor
        LEM:SetFrameResetVisible(frame, function(layoutName)
            local st = GetCastSettings(unitKey)
            -- If settings not found or anchor is nil/"none", allow reset (free positioning mode)
            if not st then return true end
            return st.anchor == nil or st.anchor == CASTBAR_ANCHOR.NONE
        end)
        
        -- Disable dragging when locked to anchor (but always allow in Edit Mode)
        LEM:SetFrameDragEnabled(frame, function(layoutName)
            if LEM and LEM.IsInEditMode and LEM:IsInEditMode() then
                return true
            end
            local st = GetCastSettings(unitKey)
            -- If settings not found or anchor is nil/"none", allow dragging (free positioning mode)
            if not st then return true end
            return st.anchor == nil or st.anchor == CASTBAR_ANCHOR.NONE
        end)
    end)
    
    if success then
        self.registeredFrames[unitKey] = frame
        CB_EditMode:LogDebug("Registered " .. unitKey .. " successfully")
    else
        CB_EditMode:ReportDebug("Failed to register " .. unitKey .. ": " .. tostring(err))
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
    -- Use unit frames module to access castbars (they're stored in SUI_UF.castbars)
    local SUI_UF = ns.SUI_UnitFrames
    if not SUI_UF or not SUI_UF.castbars then 
        CB_EditMode:ReportDebug("SUI_UF or SUI_UF.castbars is nil")
        return 
    end
    
    local registeredCount = 0
    for unitKey, castbar in pairs(SUI_UF.castbars) do
        if castbar and castbar.statusBar then
            -- Check if this is a different frame object than what we have registered
            local needsRegistration = false
            if not self.registeredFrames[unitKey] then
                needsRegistration = true
                CB_EditMode:LogDebug("RegisterAll: " .. unitKey .. " not registered yet")
            elseif self.registeredFrames[unitKey] ~= castbar then
                needsRegistration = true
                CB_EditMode:ReportDebug("RegisterAll: " .. unitKey .. " frame changed, re-registering")
                self:UnregisterFrame(unitKey)
            end
            
            if needsRegistration then
                self:RegisterFrame(unitKey, castbar)
                registeredCount = registeredCount + 1
            end
        elseif castbar then
            CB_EditMode:ReportDebug("Castbar for " .. unitKey .. " has no statusBar")
        end
    end
    
    if registeredCount > 0 then
        CB_EditMode:LogDebug("Registered " .. registeredCount .. " castbars")
    end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

function CB_EditMode:Initialize()
    if not LEM then
        CB_EditMode:ReportDebug("LibEQOLEditMode-1.0 not available - castbar Edit Mode disabled")
        return
    end
    
    -- Try to register frames immediately
    self:RegisterAllFrames()
    
    -- FIXED: Hook into SUI_Castbar's CreateCastbar method to register frames as they're created
    -- This ensures frames are registered with proper _suiCastbarUnit BEFORE Edit Mode might need them
    local SUI_Castbar = ns.SUI_Castbar
    if SUI_Castbar then
        CB_EditMode:LogDebug("Hooking SUI_Castbar:CreateCastbar")
        hooksecurefunc(SUI_Castbar, "CreateCastbar", function(self, unitFrame, unit, unitKey)
            CB_EditMode:LogDebug("Hook: CreateCastbar called for " .. tostring(unitKey))
            -- Register newly created castbar (or re-register after recreation)
            if unitKey and self.castbars and self.castbars[unitKey] then
                local castbar = self.castbars[unitKey]
                if castbar and castbar.statusBar then
                    CB_EditMode:LogDebug("Hook: Castbar exists for " .. unitKey .. ", re-registering")
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
        -- First, detect and fix any frame mismatches before entering
        local SUI_UF = ns.SUI_UnitFrames
        if SUI_UF and SUI_UF.castbars then
            for unitKey, castbar in pairs(SUI_UF.castbars) do
                if castbar and CB_EditMode.registeredFrames[unitKey] ~= castbar then
                    CB_EditMode:ReportDebug("EditMode enter: Frame mismatch detected for " .. unitKey .. ", re-registering")
                    if CB_EditMode.registeredFrames[unitKey] then
                        CB_EditMode:UnregisterFrame(unitKey)
                    end
                    CB_EditMode:RegisterFrame(unitKey, castbar)
                end
            end
        end
        
        -- Delay to ensure frames are ready
        C_Timer.After(0.1, function()
            local SUI_UF = ns.SUI_UnitFrames
            local SUI_Castbar = ns.SUI_Castbar
            
            if not SUI_UF or not SUI_Castbar then 
                CB_EditMode:ReportDebug("EditMode enter: SUI_UF or SUI_Castbar is nil")
                return 
            end
            
            -- Track which castbars are newly created
            local newlyCreated = {}
            
            -- Create missing castbars
            local unitsToPreview = {"player", "target", "focus", "pet"}
            for _, unitKey in ipairs(unitsToPreview) do
                local settings = GetCastSettings(unitKey)
                if settings and settings.enabled ~= false then
                    if not SUI_UF.castbars[unitKey] then
                        local unitFrame = SUI_UF.frames[unitKey]
                        if unitFrame then
                            SUI_UF.castbars[unitKey] = SUI_Castbar:CreateCastbar(unitFrame, unitKey, unitKey)
                            newlyCreated[unitKey] = true
                            CB_EditMode:LogDebug("EditMode enter: Created castbar for " .. unitKey)
                        end
                    end
                end
            end
            
            -- Create missing boss castbars
            if SUI_UF.frames.boss1 then
                for i = 1, 5 do
                    local bossKey = "boss" .. i
                    local settings = GetCastSettings(bossKey)
                    if settings and settings.enabled ~= false then
                        if not SUI_UF.castbars[bossKey] then
                            SUI_Castbar:CreateBossCastbar(SUI_UF.frames.boss1, "boss" .. i, i)
                            newlyCreated[bossKey] = true
                            CB_EditMode:LogDebug("EditMode enter: Created castbar for " .. bossKey)
                        end
                    end
                end
            end
            
            -- Register all castbars (including newly created ones)
            CB_EditMode:RegisterAllFrames()
            
            -- Show overlays for newly registered frames
            -- LibEQOL's resetSelectionIndicators already ran, so we need to manually show new selections
            C_Timer.After(0.05, function()
                local lemState = LEM.State or (LEM.internal and LEM.internal.State)
                local selectionRegistry = (lemState and lemState.selectionRegistry) or LEM.selectionRegistry
                
                if selectionRegistry then
                    for unitKey, _ in pairs(newlyCreated) do
                        local castbar = SUI_UF.castbars[unitKey]
                        if castbar then
                            local selection = selectionRegistry[castbar]
                            if selection and selection.ShowHighlighted then
                                selection:ShowHighlighted()
                                CB_EditMode:LogDebug("EditMode enter: Showed overlay for " .. unitKey)
                            else
                                CB_EditMode:ReportDebug("EditMode enter: No selection found for " .. unitKey)
                            end
                        end
                    end
                end
            end)
            
            -- Show preview for all castbars
            C_Timer.After(0.2, function()
                if not SUI_UF or not SUI_UF.castbars then
                    CB_EditMode:ReportDebug("EditMode enter: SUI_UF.castbars missing during preview")
                    return
                end
                
                local previewCount = 0
                local visibleCount = 0
                for unitKey, castbar in pairs(SUI_UF.castbars) do
                    if castbar then
                        local settings = GetCastSettings(unitKey)
                        if settings and settings.enabled ~= false then
                            previewCount = previewCount + 1
                            -- Force show and enable mouse
                            castbar:Show()
                            castbar:EnableMouse(true)
                            castbar:SetMovable(true)
                            
                            -- Use mixin methods if available
                            if castbar._castbarMixin then
                                castbar._castbarMixin:Show()
                                if castbar._castbarMixin.StartPreviewMode then
                                    castbar._castbarMixin:StartPreviewMode()
                                end
                            else
                                -- Legacy fallback
                                castbar.isPreviewSimulation = true
                                castbar.previewStartTime = GetTime()
                                castbar.previewEndTime = GetTime() + 3
                                castbar.previewMaxValue = 3
                                castbar.previewValue = 0
                                
                                if castbar.castbarOnUpdate or castbar.playerOnUpdate then
                                    local onUpdate = castbar.castbarOnUpdate or castbar.playerOnUpdate
                                    castbar:SetScript("OnUpdate", onUpdate)
                                end
                            end
                            
                            if not castbar:IsShown() then
                                castbar:Show()
                                castbar:SetAlpha(1)
                                CB_EditMode:ReportDebug("EditMode enter: Preview not visible for " .. unitKey .. ", forced Show()")
                            else
                                visibleCount = visibleCount + 1
                                CB_EditMode:LogDebug("EditMode enter: Started preview for " .. unitKey)
                            end
                        end
                    end
                end
                if previewCount == 0 then
                    CB_EditMode:ReportDebug("EditMode enter: No enabled castbars found for preview")
                elseif visibleCount == 0 then
                    CB_EditMode:ReportDebug("EditMode enter: No castbar previews visible")
                end
            end)
        end)
    end)
    
    LEM:RegisterCallback("exit", function()
        -- AceDB auto-saves, no manual save needed
        -- LEM handles position restoration automatically - just clear preview state
        C_Timer.After(0.05, function()
            local SUI_UF = ns.SUI_UnitFrames
            if SUI_UF and SUI_UF.castbars then
                for unitKey, castbar in pairs(SUI_UF.castbars) do
                    if castbar then
                        -- Use mixin methods if available (new architecture)
                        if castbar._castbarMixin then
                            castbar._castbarMixin:StopPreviewMode()
                            castbar._castbarMixin:ApplyVisibilitySettings()
                        else
                            -- Legacy fallback
                            castbar:SetScript("OnUpdate", nil)
                            -- Hide if not actively casting
                            if not UnitCastingInfo(castbar.unit) and not UnitChannelInfo(castbar.unit) then
                                castbar:Hide()
                            end
                        end
                    end
                end
            end
        end)
    end)
    
    -- Hook to track and enforce "hide all overlays" state when selecting frames
    -- This ensures that when "Hide All Overlays" is active, new selections don't show their overlay
    if LEM and LEM.internal and LEM.internal.State then
        local originalState = LEM.internal.State
        
        -- Periodically check if all overlays are hidden and maintain this state
        local checkHideAllTimer
        checkHideAllTimer = C_Timer.NewLoopTimer(0.2, function()
            if not EditModeManagerFrame or not EditModeManagerFrame:IsShown() then
                if checkHideAllTimer then
                    checkHideAllTimer:Cancel()
                    checkHideAllTimer = nil
                end
                return
            end
            
            -- Check if all overlays should be hidden
            local areAllHidden = true
            if originalState.selectionRegistry then
                for _, selection in pairs(originalState.selectionRegistry) do
                    if selection and not selection.overlayHidden then
                        areAllHidden = false
                        break
                    end
                end
            end
            
            CB_EditMode.allOverlaysHidden = areAllHidden
        end, 0)
    end
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

-- Debug command to check castbar state
SLASH_SUICASTDEBUG1 = "/suicastdebug"
SlashCmdList["SUICASTDEBUG"] = function(msg)
    CB_EditMode:ShowDebugStatus()
end

-- Debug Window
local debugWindow = nil
local debugLog = {}
local debugLogMax = 200

local function AddDebugLog(message, level, autoOpen)
    local prefix = date("%H:%M:%S") .. " "
    local tag = level and ("[" .. level .. "] ") or ""
    table.insert(debugLog, prefix .. tag .. message)
    if #debugLog > debugLogMax then
        table.remove(debugLog, 1)
    end
    if autoOpen then
        CB_EditMode:ShowDebugStatus()
    end
end

function CB_EditMode:ReportDebug(message)
    AddDebugLog(message, "REPORT", false)
    
    -- Check global debug mode setting
    local db = GetDB()
    local debugEnabled = db and db.general and db.general.debugMode == true
    
    -- Only auto-open window if debug mode is enabled
    if debugEnabled then
        self:ShowDebugStatus()
    end
end

function CB_EditMode:LogDebug(message)
    AddDebugLog(message, "INFO", false)
end

local function CreateDebugWindow()
    if debugWindow then return debugWindow end
    
    local frame = CreateFrame("Frame", "SUI_CastbarDebugWindow", UIParent, "BackdropTemplate")
    frame:SetSize(500, 400)
    frame:SetPoint("LEFT", UIParent, "LEFT", 20, 0)
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
    frame:SetFrameStrata(ns.Constants and ns.Constants.FRAME_STRATA and ns.Constants.FRAME_STRATA.DIALOG or "DIALOG")
    frame:SetClampedToScreen(true)
    
    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint(ns.Constants and ns.Constants.ANCHOR_POINTS and ns.Constants.ANCHOR_POINTS.TOPLEFT or "TOPLEFT", 10, -10)
    title:SetText("|cFF56D1FFSuaviUI|r Castbar Debug")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint(ns.Constants and ns.Constants.ANCHOR_POINTS and ns.Constants.ANCHOR_POINTS.TOPRIGHT or "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint(ns.Constants and ns.Constants.ANCHOR_POINTS and ns.Constants.ANCHOR_POINTS.TOPLEFT or "TOPLEFT", 10, -35)
    scrollFrame:SetPoint(ns.Constants and ns.Constants.ANCHOR_POINTS and ns.Constants.ANCHOR_POINTS.BOTTOMRIGHT or "BOTTOMRIGHT", -30, 40)
    
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
    copyBtn:SetPoint(ns.Constants and ns.Constants.ANCHOR_POINTS and ns.Constants.ANCHOR_POINTS.BOTTOMLEFT or "BOTTOMLEFT", 10, 10)
    copyBtn:SetText("Select All")
    copyBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(100, 22)
    refreshBtn:SetPoint(ns.Constants and ns.Constants.ANCHOR_POINTS and ns.Constants.ANCHOR_POINTS.LEFT or "LEFT", copyBtn, ns.Constants and ns.Constants.ANCHOR_POINTS and ns.Constants.ANCHOR_POINTS.RIGHT or "RIGHT", 10, 0)
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
    table.insert(lines, "=== Recent Events ===")
    if #debugLog == 0 then
        table.insert(lines, "(no events logged)")
    else
        local startIndex = math.max(1, #debugLog - 40)
        for i = startIndex, #debugLog do
            table.insert(lines, debugLog[i])
        end
    end
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
            
            -- Show frame object pointer for debugging
            if CB_EditMode.registeredFrames[unitKey] then
                local ourFrame = CB_EditMode.registeredFrames[unitKey]
                local sameFrame = (ourFrame == castbar) and "✓" or "✗ MISMATCH!"
                table.insert(lines, string.format("  Frame match: %s", sameFrame))
            end
            
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
end

-- Debug command
SLASH_SUICBEDITMODE1 = "/suicbeditmode"
SlashCmdList["SUICBEDITMODE"] = function(msg)
    local cmd = msg:lower():trim()
    
    if cmd == "register" then
        CB_EditMode:RegisterAllFrames()
        CB_EditMode:LogDebug("Manual: RegisterAllFrames called")
        CB_EditMode:ShowDebugStatus()
    elseif cmd == "status" then
        CB_EditMode:ShowDebugStatus()
    elseif cmd == "force" then
        CB_EditMode:LogDebug("Manual: Force registering castbars")
        local SUI_UF = ns.SUI_UnitFrames
        if SUI_UF and SUI_UF.castbars then
            for unitKey, castbar in pairs(SUI_UF.castbars) do
                if castbar then
                    local name = castbar:GetName() or "UNNAMED"
                    CB_EditMode:LogDebug("Force register: " .. unitKey .. " (" .. name .. ")")
                    CB_EditMode.registeredFrames[unitKey] = nil  -- Clear existing
                    CB_EditMode:RegisterFrame(unitKey, castbar)
                    if not CB_EditMode.registeredFrames[unitKey] then
                        CB_EditMode:ReportDebug("Force register failed for " .. unitKey)
                    end
                end
            end
        else
            CB_EditMode:ReportDebug("Force register: No castbars found")
        end
        CB_EditMode:ShowDebugStatus()
    else
        CB_EditMode:LogDebug("Commands: /suicbeditmode status | register | force")
        CB_EditMode:ShowDebugStatus()
    end
end
