--[[
    SuaviUI Action Bars Edit Mode Integration
    Registers Extra Action and Zone Ability buttons with Blizzard's Edit Mode using LibEQOLEditMode-1.0
    Provides sidebar settings panel for positioning and customization
]]

local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- LIBRARY REFERENCES
---------------------------------------------------------------------------
local LEM = LibStub("LibEQOLEditMode-1.0", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

-- Early exit if library not available
if not LEM then
    return
end

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local AB_EditMode = {}
ns.AB_EditMode = AB_EditMode

AB_EditMode.registeredFrames = {}

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

local function GetActionBarsDB()
    local db = GetDB()
    return db and db.actionBars or nil
end

local function GetButtonSettings(buttonType)
    local abdb = GetActionBarsDB()
    if not abdb or not abdb.bars then return nil end
    return abdb.bars[buttonType]
end

-- Refresh button after settings change
local function RefreshButton(buttonType)
    -- Call the refresh function from sui_actionbars.lua
    if _G.SuaviUI_RefreshExtraButton then
        _G.SuaviUI_RefreshExtraButton(buttonType)
    end
end

---------------------------------------------------------------------------
-- FRAME LABELS
---------------------------------------------------------------------------
local FRAME_LABELS = {
    extraActionButton = "Extra Action Button",
    zoneAbility = "Zone Ability Button",
}

---------------------------------------------------------------------------
-- POSITION CHANGE CALLBACK
---------------------------------------------------------------------------
local function OnPositionChanged(frame, layoutName, point, x, y)
    -- Handle both callback signatures that LibEQOL might use
    if type(layoutName) == "number" then
        -- Arguments came in as (frame, point, x, y) - shift them
        local origX = layoutName
        local origY = point
        local origPoint = x
        x = origX
        y = origY
        point = origPoint
        layoutName = nil
    end
    
    if not frame or not frame._suiButtonType then return end
    
    local buttonType = frame._suiButtonType
    local settings = GetButtonSettings(buttonType)
    if not settings then return end
    
    -- Update position in database
    if not settings.position then settings.position = {} end
    settings.position.point = point
    settings.position.relPoint = point
    settings.position.x = tonumber(x) or 0
    settings.position.y = tonumber(y) or 0
    
    -- Refresh the settings panel to show updated values
    if LEM and LEM.RefreshFrameSettings then
        pcall(function()
            LEM:RefreshFrameSettings(frame)
        end)
    end
end

---------------------------------------------------------------------------
-- SETTINGS BUILDERS
---------------------------------------------------------------------------

-- Build settings for a specific button type
local function BuildButtonSettings(buttonType)
    local settings = {}
    
    -- GENERAL CATEGORY
    table.insert(settings, {
        type = "category",
        name = "General",
        id = "CATEGORY_GENERAL_" .. buttonType,
    })
    
    -- Enable checkbox
    table.insert(settings, {
        type = "checkbox",
        parentId = "CATEGORY_GENERAL_" .. buttonType,
        id = "ENABLE_" .. buttonType,
        name = "Enable Customization",
        tooltip = "Enable custom positioning and settings for this button",
        get = function()
            local s = GetButtonSettings(buttonType)
            return s and s.enabled or false
        end,
        set = function(value)
            local s = GetButtonSettings(buttonType)
            if s then
                s.enabled = value
                RefreshButton(buttonType)
            end
        end,
    })
    
    -- Scale slider
    table.insert(settings, {
        type = "slider",
        parentId = "CATEGORY_GENERAL_" .. buttonType,
        id = "SCALE_" .. buttonType,
        name = "Scale",
        tooltip = "Adjust the size of the button",
        min = 0.5,
        max = 2.0,
        step = 0.05,
        get = function()
            local s = GetButtonSettings(buttonType)
            return s and s.scale or 1.0
        end,
        set = function(value)
            local s = GetButtonSettings(buttonType)
            if s then
                s.scale = value
                RefreshButton(buttonType)
            end
        end,
    })
    
    -- POSITIONING CATEGORY
    table.insert(settings, {
        type = "category",
        name = "Fine-Tune Position",
        id = "CATEGORY_POSITION_" .. buttonType,
    })
    
    -- Offset X
    table.insert(settings, {
        type = "slider",
        parentId = "CATEGORY_POSITION_" .. buttonType,
        id = "OFFSET_X_" .. buttonType,
        name = "Horizontal Offset",
        tooltip = "Fine-tune horizontal position relative to anchor point",
        min = -100,
        max = 100,
        step = 1,
        get = function()
            local s = GetButtonSettings(buttonType)
            return s and s.offsetX or 0
        end,
        set = function(value)
            local s = GetButtonSettings(buttonType)
            if s then
                s.offsetX = value
                RefreshButton(buttonType)
            end
        end,
    })
    
    -- Offset Y
    table.insert(settings, {
        type = "slider",
        parentId = "CATEGORY_POSITION_" .. buttonType,
        id = "OFFSET_Y_" .. buttonType,
        name = "Vertical Offset",
        tooltip = "Fine-tune vertical position relative to anchor point",
        min = -100,
        max = 100,
        step = 1,
        get = function()
            local s = GetButtonSettings(buttonType)
            return s and s.offsetY or 0
        end,
        set = function(value)
            local s = GetButtonSettings(buttonType)
            if s then
                s.offsetY = value
                RefreshButton(buttonType)
            end
        end,
    })
    
    -- APPEARANCE CATEGORY
    table.insert(settings, {
        type = "category",
        name = "Appearance",
        id = "CATEGORY_APPEARANCE_" .. buttonType,
    })
    
    -- Hide Artwork
    table.insert(settings, {
        type = "checkbox",
        parentId = "CATEGORY_APPEARANCE_" .. buttonType,
        id = "HIDE_ARTWORK_" .. buttonType,
        name = "Hide Artwork",
        tooltip = "Hide the decorative border/background artwork",
        get = function()
            local s = GetButtonSettings(buttonType)
            return s and s.hideArtwork or false
        end,
        set = function(value)
            local s = GetButtonSettings(buttonType)
            if s then
                s.hideArtwork = value
                RefreshButton(buttonType)
            end
        end,
    })
    
    -- Always Show
    table.insert(settings, {
        type = "checkbox",
        parentId = "CATEGORY_APPEARANCE_" .. buttonType,
        id = "ALWAYS_SHOW_" .. buttonType,
        name = "Always Show",
        tooltip = "Keep the button visible even when not active (for positioning)",
        get = function()
            local s = GetButtonSettings(buttonType)
            return s and s.alwaysShow or false
        end,
        set = function(value)
            local s = GetButtonSettings(buttonType)
            if s then
                s.alwaysShow = value
                RefreshButton(buttonType)
            end
        end,
    })
    
    -- FADE SETTINGS CATEGORY
    table.insert(settings, {
        type = "category",
        name = "Fade Settings",
        id = "CATEGORY_FADE_" .. buttonType,
    })
    
    -- Enable Fade
    table.insert(settings, {
        type = "checkbox",
        parentId = "CATEGORY_FADE_" .. buttonType,
        id = "FADE_ENABLED_" .. buttonType,
        name = "Enable Fade",
        tooltip = "Fade the button when not in use",
        get = function()
            local s = GetButtonSettings(buttonType)
            return s and s.fadeEnabled or false
        end,
        set = function(value)
            local s = GetButtonSettings(buttonType)
            if s then
                s.fadeEnabled = value
                RefreshButton(buttonType)
            end
        end,
    })
    
    -- Fade Alpha
    table.insert(settings, {
        type = "slider",
        parentId = "CATEGORY_FADE_" .. buttonType,
        id = "FADE_ALPHA_" .. buttonType,
        name = "Fade Opacity",
        tooltip = "Opacity when faded out",
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            local s = GetButtonSettings(buttonType)
            return s and s.fadeAlpha or 0.4
        end,
        set = function(value)
            local s = GetButtonSettings(buttonType)
            if s then
                s.fadeAlpha = value
                RefreshButton(buttonType)
            end
        end,
    })
    
    return settings
end

---------------------------------------------------------------------------
-- FRAME REGISTRATION
---------------------------------------------------------------------------

-- Register a button holder with Edit Mode
function AB_EditMode:RegisterFrame(buttonType, holderFrame)
    if not LEM or not holderFrame then return end
    if self.registeredFrames[buttonType] then return end  -- Already registered
    
    -- Store button type on frame for callbacks
    holderFrame._suiButtonType = buttonType
    
    -- Set custom Edit Mode label directly on the frame
    holderFrame.editModeName = FRAME_LABELS[buttonType] or ("Action Bar: " .. buttonType)
    
    -- Get current position
    local s = GetButtonSettings(buttonType)
    local defaults = {
        point = s and s.position and s.position.point or "CENTER",
        x = s and s.position and s.position.x or 0,
        y = s and s.position and s.position.y or 0,
    }
    
    -- Register with LibEQOL
    local success, err = pcall(function()
        LEM:AddFrame(holderFrame, OnPositionChanged, defaults)
        
        -- Add settings
        local settings = BuildButtonSettings(buttonType)
        LEM:AddFrameSettings(holderFrame, settings)
        
        -- Enable dragging only when customization is enabled
        LEM:SetFrameDragEnabled(holderFrame, function(layoutName)
            local st = GetButtonSettings(buttonType)
            if LEM and LEM.IsInEditMode and LEM:IsInEditMode() then
                return true
            end
            return st and st.enabled or false
        end)
        
        -- Show reset button only when customization is enabled
        LEM:SetFrameResetVisible(holderFrame, function(layoutName)
            local st = GetButtonSettings(buttonType)
            if LEM and LEM.IsInEditMode and LEM:IsInEditMode() then
                return true
            end
            return st and st.enabled or false
        end)
    end)
    
    if success then
        self.registeredFrames[buttonType] = holderFrame
        
        -- Add visual indicator overlay for Edit Mode visibility
        if not holderFrame._editModeOverlay then
            local overlay = CreateFrame("Frame", nil, holderFrame, "BackdropTemplate")
            overlay:SetAllPoints(holderFrame)
            overlay:SetFrameLevel(holderFrame:GetFrameLevel() + 1)
            overlay:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 2,
            })
            overlay:SetBackdropBorderColor(0.3, 0.8, 1, 0.6)  -- Light blue border for visual feedback
            overlay:Hide()  -- Hidden by default, shown when Edit Mode is active/dragging
            holderFrame._editModeOverlay = overlay
        end
    else
        print("SuaviUI: Failed to register", buttonType, "with Edit Mode:", err)
    end
end

-- Unregister a frame
function AB_EditMode:UnregisterFrame(buttonType)
    if not LEM then return end
    local frame = self.registeredFrames[buttonType]
    if frame and LEM.RemoveFrame then
        pcall(function()
            LEM:RemoveFrame(frame)
        end)
        self.registeredFrames[buttonType] = nil
    end
end

-- Register all available buttons
function AB_EditMode:RegisterAllFrames()
    -- Wait a bit for frames to be created
    C_Timer.After(0.5, function()
        -- Get holder frames from global namespace (set by sui_actionbars.lua)
        local extraHolder = _G.SUI_extraActionButtonHolder
        local zoneHolder = _G.SUI_zoneAbilityHolder
        
        if extraHolder and not self.registeredFrames.extraActionButton then
            self:RegisterFrame("extraActionButton", extraHolder)
        end
        
        if zoneHolder and not self.registeredFrames.zoneAbility then
            self:RegisterFrame("zoneAbility", zoneHolder)
        end
    end)
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
function AB_EditMode:Initialize()
    if not LEM then return end
    
    -- Register all existing frames
    self:RegisterAllFrames()
    
    -- Hook into Edit Mode enter/exit for any special handling
    LEM:RegisterCallback("enter", function()
        -- Hide ExtraAbilityContainer (Blizzard default) since we manage buttons separately
        if _G.ExtraAbilityContainer then
            _G.ExtraAbilityContainer:Hide()
        end
        
        -- Force buttons to show when entering Edit Mode for positioning
        local abdb = GetActionBarsDB()
        if abdb and abdb.bars then
            for buttonType, settings in pairs(abdb.bars) do
                if buttonType == "extraActionButton" or buttonType == "zoneAbility" then
                    settings._editModeActive = true
                    RefreshButton(buttonType)
                    
                    -- Show overlay and ensure frame is visible and interactable
                    local frame = self.registeredFrames[buttonType]
                    if frame then
                        frame:Show()
                        frame:SetFrameStrata("MEDIUM")  -- Match resource powerbar strata
                        if frame._editModeOverlay then
                            frame._editModeOverlay:Show()
                        end
                    end
                end
            end
        end
    end)
    
    LEM:RegisterCallback("exit", function()
        -- Show ExtraAbilityContainer again when exiting Edit Mode
        if _G.ExtraAbilityContainer then
            _G.ExtraAbilityContainer:Show()
        end
        
        -- Clear edit mode flag when exiting
        local abdb = GetActionBarsDB()
        if abdb and abdb.bars then
            for buttonType, settings in pairs(abdb.bars) do
                if buttonType == "extraActionButton" or buttonType == "zoneAbility" then
                    settings._editModeActive = nil
                    RefreshButton(buttonType)
                    
                    -- Hide overlay and restore normal frame strata
                    local frame = self.registeredFrames[buttonType]
                    if frame then
                        frame:SetFrameStrata("MEDIUM")  -- Normal strata when not in Edit Mode
                        if frame._editModeOverlay then
                            frame._editModeOverlay:Hide()
                        end
                    end
                end
            end
        end
    end)
end

---------------------------------------------------------------------------
-- DELAYED INITIALIZATION
---------------------------------------------------------------------------
-- Wait for both LEM and action bars to be ready
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Delay to ensure all modules are loaded
    C_Timer.After(2.5, function()
        AB_EditMode:Initialize()
    end)
end)

---------------------------------------------------------------------------
-- GLOBAL EXPORT FOR CROSS-MODULE COMMUNICATION
---------------------------------------------------------------------------
_G.SuaviUI_AB_EditMode_Register = function(buttonType, holderFrame)
    AB_EditMode:RegisterFrame(buttonType, holderFrame)
end

_G.SuaviUI_AB_EditMode_Unregister = function(buttonType)
    AB_EditMode:UnregisterFrame(buttonType)
end
