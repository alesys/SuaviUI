--[[
    SuaviUI Skyriding Module - Edit Mode Integration
    Registers the Vigor Bar with Blizzard's Edit Mode using LibEQOLEditMode-1.0
    Provides sidebar settings panel for positioning and customization
    
    Pattern follows castbar_editmode.lua (working reference):
    - Register frame directly with LEM:AddFrame()
    - Settings use kind = LEM.SettingType.* format
    - Expand overlay to cover full widget (vigor + second wind + icon)
    - Force-show during Edit Mode even when not flying
]]

local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- LIBRARY REFERENCES
---------------------------------------------------------------------------
local LEM = LibStub("LibEQOLEditMode-1.0", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

if not LEM then
    return
end

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local SkyridingEditMode = {}
ns.SkyridingEditMode = SkyridingEditMode

SkyridingEditMode.registeredFrame = nil
SkyridingEditMode.previewActive = false

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

local function GetSkyridingSettings()
    local db = GetDB()
    if not db or not db.skyriding then return nil end
    return db.skyriding
end

local function RefreshVigorBar()
    if _G.SuaviUI_RefreshSkyriding then
        _G.SuaviUI_RefreshSkyriding()
    end
end

---------------------------------------------------------------------------
-- GET SKYRIDING FRAME (direct reference by global name)
---------------------------------------------------------------------------
local function GetSkyridingFrame()
    return _G["SuaviUI_Skyriding"]
end

---------------------------------------------------------------------------
-- POSITION CHANGE CALLBACK
---------------------------------------------------------------------------
local function OnPositionChanged(frame, layoutName, point, x, y)
    -- Handle both callback signatures LEM might use
    if type(layoutName) == "number" then
        x = layoutName
        y = point
        point = x
        layoutName = nil
    end
    
    if not frame then return end
    
    local settings = GetSkyridingSettings()
    if not settings then return end
    
    settings.offsetX = tonumber(x) or 0
    settings.offsetY = tonumber(y) or 0
    
    -- Refresh the settings panel to show updated values
    if LEM.RefreshFrameSettings then
        pcall(function() LEM:RefreshFrameSettings(frame) end)
    end
end

---------------------------------------------------------------------------
-- EXPAND SELECTION OVERLAY TO COVER FULL WIDGET
-- LEM creates a selection with SetAllPoints() on the registered frame.
-- Since skyridingFrame is only the vigor bar (250x12), the second wind bar
-- and ability icon fall outside. We expand the overlay to cover everything.
---------------------------------------------------------------------------
local function ExpandSelectionOverlay(frame)
    local lemState = LEM.State or (LEM.internal and LEM.internal.State)
    local selectionRegistry = (lemState and lemState.selectionRegistry) or LEM.selectionRegistry
    if not selectionRegistry or not selectionRegistry[frame] then return end
    
    local selection = selectionRegistry[frame]
    local settings = GetSkyridingSettings()
    local vigorHeight = settings and settings.vigorHeight or 12
    local swHeight = settings and settings.secondWindHeight or 6
    local swMode = settings and settings.secondWindMode or "MINIBAR"
    
    -- Calculate extra height below (second wind bar + gap)
    local extraBottom = 0
    if swMode == "MINIBAR" or swMode == "TEXT" then
        extraBottom = 2 + swHeight
    end
    
    -- Calculate extra height above (for pips mode)
    local extraTop = 0
    if swMode == "PIPS" then
        extraTop = 12  -- pip size + gap
    end
    
    -- Calculate extra width right (ability icon + gap)
    -- Icon spans both bars: totalHeight = vigorHeight + gap + swHeight (in MINIBAR mode)
    local iconTotalHeight = vigorHeight
    if swMode == "MINIBAR" then
        iconTotalHeight = vigorHeight + 2 + swHeight
    end
    local extraRight = 2 + iconTotalHeight  -- 2px gap + icon size
    
    selection:ClearAllPoints()
    selection:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, extraTop + 1)
    selection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", extraRight + 1, -(extraBottom + 1))
end

---------------------------------------------------------------------------
-- SETTINGS BUILDERS (using proper LEM.SettingType format)
---------------------------------------------------------------------------

local function BuildVigorBarSettings()
    local settings = {}
    local order = 100
    
    -- =====================================================================
    -- GENERAL CATEGORY
    -- =====================================================================
    table.insert(settings, {
        order = order,
        name = "General",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_GENERAL_VIGOR",
        defaultCollapsed = false,
    })
    order = order + 1
    
    -- Enable checkbox
    table.insert(settings, {
        parentId = "CATEGORY_GENERAL_VIGOR",
        order = order,
        name = "Enable Vigor Bar",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.enabled ~= false
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.enabled = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- Lock Position checkbox
    table.insert(settings, {
        parentId = "CATEGORY_GENERAL_VIGOR",
        order = order,
        name = "Lock Position",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.locked ~= false
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.locked = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- =====================================================================
    -- SIZE & APPEARANCE CATEGORY
    -- =====================================================================
    table.insert(settings, {
        order = order,
        name = "Size & Appearance",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_SIZE_VIGOR",
        defaultCollapsed = false,
    })
    order = order + 1
    
    -- Width slider
    table.insert(settings, {
        parentId = "CATEGORY_SIZE_VIGOR",
        order = order,
        name = "Bar Width",
        kind = LEM.SettingType.Slider,
        default = 250,
        minValue = 100,
        maxValue = 500,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.width or 250
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.width = value
                RefreshVigorBar()
                -- Re-expand overlay since widget size changed
                local frame = SkyridingEditMode.registeredFrame
                if frame then ExpandSelectionOverlay(frame) end
            end
        end,
    })
    order = order + 1
    
    -- Vigor Bar Height slider
    table.insert(settings, {
        parentId = "CATEGORY_SIZE_VIGOR",
        order = order,
        name = "Vigor Height",
        kind = LEM.SettingType.Slider,
        default = 12,
        minValue = 4,
        maxValue = 40,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.vigorHeight or 12
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.vigorHeight = value
                RefreshVigorBar()
                local frame = SkyridingEditMode.registeredFrame
                if frame then ExpandSelectionOverlay(frame) end
            end
        end,
    })
    order = order + 1
    
    -- Second Wind Height slider
    table.insert(settings, {
        parentId = "CATEGORY_SIZE_VIGOR",
        order = order,
        name = "Second Wind Height",
        kind = LEM.SettingType.Slider,
        default = 6,
        minValue = 2,
        maxValue = 30,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%d", value) end,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.secondWindHeight or 6
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.secondWindHeight = value
                RefreshVigorBar()
                local frame = SkyridingEditMode.registeredFrame
                if frame then ExpandSelectionOverlay(frame) end
            end
        end,
    })
    order = order + 1
    
    -- Bar Texture dropdown (LSM-backed with texture previews, matches castbar pattern)
    table.insert(settings, {
        parentId = "CATEGORY_SIZE_VIGOR",
        order = order,
        name = "Bar Texture",
        kind = LEM.SettingType.Dropdown,
        default = "Suavisolid",
        useOldStyle = true,
        height = 200,
        generator = function(dropdown, rootDescription, settingObject)
            dropdown.texturePool = dropdown.texturePool or {}

            local TEXTURE_NAMES = (ns.ResourceBars and ns.ResourceBars.TEXTURE_DISPLAY_NAMES) or {}

            -- Clean up preview textures when menu closes
            if not dropdown._SKY_Texture_Dropdown_OnMenuClosed_hooked then
                hooksecurefunc(dropdown, "OnMenuClosed", function()
                    for _, texture in pairs(dropdown.texturePool) do
                        texture:Hide()
                    end
                end)
                dropdown._SKY_Texture_Dropdown_OnMenuClosed_hooked = true
            end

            local layoutName = LEM.GetActiveLayoutName() or "Default"

            -- Show current texture display name
            local currentTexture = settingObject.get(layoutName)
            dropdown:SetDefaultText(TEXTURE_NAMES[currentTexture] or currentTexture)

            if not LSM then
                local fallback = "Suavisolid"
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
                local displayName = TEXTURE_NAMES[textureName] or textureName

                local button = rootDescription:CreateButton(displayName, function()
                    dropdown:SetDefaultText(displayName)
                    settingObject.set(layoutName, textureName)
                end)

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
            local s = GetSkyridingSettings()
            return s and s.barTexture or "Suavisolid"
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.barTexture = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- =====================================================================
    -- DISPLAY OPTIONS CATEGORY
    -- =====================================================================
    table.insert(settings, {
        order = order,
        name = "Display Options",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_DISPLAY_VIGOR",
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Show Segment Markers checkbox
    table.insert(settings, {
        parentId = "CATEGORY_DISPLAY_VIGOR",
        order = order,
        name = "Show Segment Markers",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.showSegments ~= false
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.showSegments = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- Show Vigor Text checkbox
    table.insert(settings, {
        parentId = "CATEGORY_DISPLAY_VIGOR",
        order = order,
        name = "Show Vigor Text",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.showVigorText ~= false
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.showVigorText = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- Vigor Text Format dropdown
    table.insert(settings, {
        parentId = "CATEGORY_DISPLAY_VIGOR",
        order = order,
        name = "Vigor Text Format",
        kind = LEM.SettingType.Dropdown,
        default = "FRACTION",
        useOldStyle = true,
        values = {
            {value = "FRACTION", text = "Current / Max (3/6)"},
            {value = "CURRENT", text = "Current Only (3)"},
            {value = "PERCENT", text = "Percentage (50%)"},
        },
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.vigorTextFormat or "FRACTION"
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.vigorTextFormat = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- Show Flight Speed checkbox
    table.insert(settings, {
        parentId = "CATEGORY_DISPLAY_VIGOR",
        order = order,
        name = "Show Flight Speed",
        kind = LEM.SettingType.Checkbox,
        default = true,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.showSpeed ~= false
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.showSpeed = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- Speed Display Format dropdown
    table.insert(settings, {
        parentId = "CATEGORY_DISPLAY_VIGOR",
        order = order,
        name = "Speed Display Format",
        kind = LEM.SettingType.Dropdown,
        default = "PERCENT",
        useOldStyle = true,
        values = {
            {value = "PERCENT", text = "Percentage (125%)"},
            {value = "MULTIPLIER", text = "Multiplier (1.25x)"},
        },
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.speedFormat or "PERCENT"
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.speedFormat = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- =====================================================================
    -- VISIBILITY CATEGORY
    -- =====================================================================
    table.insert(settings, {
        order = order,
        name = "Visibility",
        kind = LEM.SettingType.Collapsible,
        id = "CATEGORY_VISIBILITY_VIGOR",
        defaultCollapsed = true,
    })
    order = order + 1
    
    -- Visibility Mode dropdown
    table.insert(settings, {
        parentId = "CATEGORY_VISIBILITY_VIGOR",
        order = order,
        name = "Visibility Mode",
        kind = LEM.SettingType.Dropdown,
        default = "AUTO",
        useOldStyle = true,
        values = {
            {value = "ALWAYS", text = "Always Visible"},
            {value = "FLYING_ONLY", text = "Only When Flying"},
            {value = "AUTO", text = "Auto (fade when grounded)"},
        },
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.visibility or "AUTO"
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.visibility = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- Fade Delay slider
    table.insert(settings, {
        parentId = "CATEGORY_VISIBILITY_VIGOR",
        order = order,
        name = "Fade Delay (sec)",
        kind = LEM.SettingType.Slider,
        default = 3,
        minValue = 0,
        maxValue = 10,
        valueStep = 0.5,
        formatter = function(value) return string.format("%.1f", value) end,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.fadeDelay or 3
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.fadeDelay = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    -- Fade Speed slider
    table.insert(settings, {
        parentId = "CATEGORY_VISIBILITY_VIGOR",
        order = order,
        name = "Fade Speed (sec)",
        kind = LEM.SettingType.Slider,
        default = 0.3,
        minValue = 0.1,
        maxValue = 2.0,
        valueStep = 0.1,
        formatter = function(value) return string.format("%.1f", value) end,
        get = function(layoutName)
            local s = GetSkyridingSettings()
            return s and s.fadeDuration or 0.3
        end,
        set = function(layoutName, value)
            local s = GetSkyridingSettings()
            if s then
                s.fadeDuration = value
                RefreshVigorBar()
            end
        end,
    })
    order = order + 1
    
    return settings
end

---------------------------------------------------------------------------
-- FRAME REGISTRATION
---------------------------------------------------------------------------

function SkyridingEditMode:RegisterFrame(skyridingFrame)
    if not LEM or not skyridingFrame then return end
    if self.registeredFrame then return end  -- Already registered
    
    -- Set the Edit Mode label
    skyridingFrame.editModeName = "Skyriding Vigor Bar"
    
    -- Get current position from DB
    local s = GetSkyridingSettings()
    local defaults = {
        point = "CENTER",
        x = s and s.offsetX or 0,
        y = s and s.offsetY or -150,
    }
    
    -- Register with LEM
    local success, err = pcall(function()
        LEM:AddFrame(skyridingFrame, OnPositionChanged, defaults)
        LEM:AddFrameSettings(skyridingFrame, BuildVigorBarSettings())
        LEM:SetFrameDragEnabled(skyridingFrame, function()
            return LEM:IsInEditMode()
        end)
        LEM:SetFrameResetVisible(skyridingFrame, function()
            return LEM:IsInEditMode()
        end)
    end)
    
    if success then
        self.registeredFrame = skyridingFrame
        
        -- Expand the overlay to cover the full widget (vigor + second wind + icon)
        C_Timer.After(0.05, function()
            ExpandSelectionOverlay(skyridingFrame)
        end)
    else
        print("|cffff6666SuaviUI:|r Failed to register Skyriding with Edit Mode:", tostring(err))
    end
end

function SkyridingEditMode:UnregisterFrame()
    if not LEM then return end
    local frame = self.registeredFrame
    if frame and LEM.RemoveFrame then
        pcall(function() LEM:RemoveFrame(frame) end)
        self.registeredFrame = nil
    end
end

---------------------------------------------------------------------------
-- PREVIEW MODE (force-show skyriding bar during Edit Mode)
-- Follows castbar_editmode.lua pattern: show frame on enter, restore on exit
---------------------------------------------------------------------------

local function StartPreview(skyridingFrame)
    if not skyridingFrame then return end
    
    SkyridingEditMode.previewActive = true
    
    -- Force-show the frame regardless of flying state
    skyridingFrame:Show()
    skyridingFrame:SetAlpha(1)
    skyridingFrame:EnableMouse(true)
    skyridingFrame:SetMovable(true)
    
    -- Show ability icon (last child Frame with a .texture and .border)
    for _, child in pairs({skyridingFrame:GetChildren()}) do
        if child.texture and child.border then
            child:Show()
        end
    end
    
    -- Show second wind mini bar if in MINIBAR mode
    local settings = GetSkyridingSettings()
    if settings then
        local swMode = settings.secondWindMode or "MINIBAR"
        if swMode == "MINIBAR" then
            for _, child in pairs({skyridingFrame:GetChildren()}) do
                if child:IsObjectType("StatusBar") then
                    child:Show()
                    child:SetValue(0.5)  -- Preview at 50%
                    break
                end
            end
        end
    end
    
    -- Expand the overlay to cover updated widget bounds
    ExpandSelectionOverlay(skyridingFrame)
end

local function StopPreview(skyridingFrame)
    if not skyridingFrame then return end
    
    SkyridingEditMode.previewActive = false
    
    -- Restore normal visibility (let UpdateVisibility handle show/hide)
    RefreshVigorBar()
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

function SkyridingEditMode:Initialize()
    if not LEM then return end
    
    -- Get the actual skyridingFrame by its global name
    local skyridingFrame = GetSkyridingFrame()
    
    if skyridingFrame and not self.registeredFrame then
        self:RegisterFrame(skyridingFrame)
    end
    
    -- Hook into Edit Mode enter/exit (follows castbar pattern)
    LEM:RegisterCallback("enter", function()
        -- If frame wasn't found on init, try again now
        local frame = self.registeredFrame or GetSkyridingFrame()
        if frame and not self.registeredFrame then
            self:RegisterFrame(frame)
        end
        
        if self.registeredFrame then
            C_Timer.After(0.1, function()
                StartPreview(self.registeredFrame)
                
                -- Force the selection to be highlighted
                -- (frame may have been hidden when resetSelectionIndicators ran)
                C_Timer.After(0.05, function()
                    local lemState = LEM.State or (LEM.internal and LEM.internal.State)
                    local selectionRegistry = (lemState and lemState.selectionRegistry) or LEM.selectionRegistry
                    if selectionRegistry and selectionRegistry[self.registeredFrame] then
                        local selection = selectionRegistry[self.registeredFrame]
                        if selection and selection.ShowHighlighted then
                            selection:ShowHighlighted()
                        end
                    end
                end)
            end)
        end
    end)
    
    LEM:RegisterCallback("exit", function()
        if self.registeredFrame then
            StopPreview(self.registeredFrame)
        end
    end)
end

---------------------------------------------------------------------------
-- DELAYED INITIALIZATION
-- Wait for PLAYER_ENTERING_WORLD + delay to ensure skyriding frame exists
-- Delay 3s: sui_skyriding.lua creates the frame during ApplySettings on load
---------------------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    C_Timer.After(3.0, function()
        SkyridingEditMode:Initialize()
    end)
end)

---------------------------------------------------------------------------
-- GLOBAL EXPORTS
---------------------------------------------------------------------------

_G.SuaviUI_SkyridingEditMode_Register = function(frame)
    SkyridingEditMode:RegisterFrame(frame)
end

_G.SuaviUI_SkyridingEditMode_Unregister = function()
    SkyridingEditMode:UnregisterFrame()
end

-- Allow external modules to check if preview is active
-- (so UpdateVisibility doesn't hide the frame during Edit Mode)
_G.SuaviUI_SkyridingEditMode_IsPreviewActive = function()
    return SkyridingEditMode.previewActive
end
