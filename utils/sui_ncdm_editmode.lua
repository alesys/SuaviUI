--[[
    SUI NCDM Edit Mode Integration
    Registers Essential/Utility cooldown viewers with LibEQOL Edit Mode
    Consolidates position/scale under Edit Mode, keeps layout logic in SUI
]]

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local LEM = LibStub("LibEQOL-1.0", true)

if not LEM then
    print("|cFF56D1FFSuaviUI:|r LibEQOL not found. NCDM Edit Mode integration disabled.")
    return
end

local NCDM_EditMode = {}
ns.NCDM_EditMode = NCDM_EditMode

---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------
local VIEWER_ESSENTIAL = "EssentialCooldownViewer"
local VIEWER_UTILITY = "UtilityCooldownViewer"

---------------------------------------------------------------------------
-- DATABASE ACCESS
---------------------------------------------------------------------------
local function GetNCDMDB()
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.ncdm then
        return SUICore.db.profile.ncdm
    end
    return nil
end

---------------------------------------------------------------------------
-- MARK EDIT MODE DIRTY (Enable Save button)
---------------------------------------------------------------------------
local function MarkEditModeDirty()
    if LEM:IsInEditMode() and EditModeManagerFrame then
        EditModeManagerFrame.hasActiveChanges = true
        EditModeManagerFrame:UpdateSaveButton()
    end
end

---------------------------------------------------------------------------
-- BUILD ESSENTIAL SETTINGS PANEL
---------------------------------------------------------------------------
function BuildEssentialSettings()
    local settings = {}
    
    -- For now, return empty settings array
    -- CDM uses dedicated settings in sui_ncdm.lua for icon layout
    -- This file is just for position/scale via EditMode
    -- Settings can be added here if needed for icon size, spacing, etc.
    
    return settings
end

---------------------------------------------------------------------------
-- BUILD UTILITY SETTINGS PANEL
---------------------------------------------------------------------------
function BuildUtilitySettings()
    local settings = {}
    
    -- For now, return empty settings array
    -- CDM uses dedicated settings in sui_ncdm.lua for icon layout
    
    return settings
end

---------------------------------------------------------------------------
-- REGISTER CDM FRAMES WITH EDIT MODE
---------------------------------------------------------------------------

-- Essential Cooldowns
local function RegisterEssentialCooldownViewer()
    if not _G[VIEWER_ESSENTIAL] then
        return
    end
    
    local viewer = _G[VIEWER_ESSENTIAL]
    
    local function OnPositionChanged(frame, layoutName, point, x, y)
        -- Position saved automatically by Edit Mode
        -- Don't call ApplyViewerLayout here - it interferes with scaling
        -- Just refresh resource bars if they exist
        C_Timer.After(0.01, function()
            if SUICore.UpdatePowerBar then
                SUICore:UpdatePowerBar()
            end
            if SUICore.UpdateSecondaryPowerBar then
                SUICore:UpdateSecondaryPowerBar()
            end
        end)
    end
    
    local defaults = {
        point = "CENTER",
        relativeFrame = "UIParent",
        relativePoint = "CENTER",
        x = 0,
        y = -100,
        scale = 1.0,
    }
    
    LEM:AddFrame(viewer, OnPositionChanged, defaults)
end

-- Utility Cooldowns
local function RegisterUtilityCooldownViewer()
    if not _G[VIEWER_UTILITY] then
        return
    end
    
    local viewer = _G[VIEWER_UTILITY]
    
    local function OnPositionChanged(frame, layoutName, point, x, y)
        -- Position saved automatically by Edit Mode
        -- Don't call ApplyViewerLayout here - it interferes with scaling
        -- Just refresh resource bars if they exist
        C_Timer.After(0.01, function()
            if SUICore.UpdatePowerBar then
                SUICore:UpdatePowerBar()
            end
            if SUICore.UpdateSecondaryPowerBar then
                SUICore:UpdateSecondaryPowerBar()
            end
        end)
    end
    
    local defaults = {
        point = "CENTER",
        relativeFrame = "UIParent",
        relativePoint = "CENTER",
        x = 0,
        y = 50,
        scale = 1.0,
    }
    
    LEM:AddFrame(viewer, OnPositionChanged, defaults)
end

---------------------------------------------------------------------------
-- HOOK EDIT MODE ENTER/EXIT
---------------------------------------------------------------------------
if LEM then
    -- Hook EditMode exit to refresh resource bars
    -- (EnterEditMode not needed - positions are already applied by LibEQOL)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function()
        -- Small delay to let EditMode finish cleanup
        C_Timer.After(0.05, function()
            if SUICore.UpdatePowerBar then
                SUICore:UpdatePowerBar()
            end
            if SUICore.UpdateSecondaryPowerBar then
                SUICore:UpdateSecondaryPowerBar()
            end
        end)
    end)
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
local function Initialize()
    if not LEM then return end
    
    -- Check if LEM is ready
    if LEM.IsReady and LEM:IsReady() then
        RegisterEssentialCooldownViewer()
        RegisterUtilityCooldownViewer()
    else
        -- Retry after a small delay
        C_Timer.After(0.5, Initialize)
    end
end

-- Wait for both SUICore and a brief delay to avoid taint issues
if SUICore and SUICore.db then
    -- Delay initialization to avoid EditMode taint issues during addon load
    -- Use a longer delay to ensure all Blizzard UI initialization is complete
    C_Timer.After(2.0, function()
        Initialize()
        -- After registration, refresh resource bars to correct positions
        C_Timer.After(0.1, function()
            if SUICore.UpdatePowerBar then
                SUICore:UpdatePowerBar()
            end
            if SUICore.UpdateSecondaryPowerBar then
                SUICore:UpdateSecondaryPowerBar()
            end
        end)
    end)
else
    -- Wait for SUICore to initialize
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if addonName == ADDON_NAME then
            C_Timer.After(2.0, function()
                Initialize()
                -- After registration, refresh resource bars to correct positions
                C_Timer.After(0.1, function()
                    if SUICore.UpdatePowerBar then
                        SUICore:UpdatePowerBar()
                    end
                    if SUICore.UpdateSecondaryPowerBar then
                        SUICore:UpdateSecondaryPowerBar()
                    end
                end)
            end)
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

---------------------------------------------------------------------------
-- HOOK SAVE BUTTON
---------------------------------------------------------------------------
if LEM and EditModeManagerFrame then
    hooksecurefunc(EditModeManagerFrame, "SaveLayouts", function()
        -- Settings already saved by individual callbacks
        -- Just ensure database is marked for write to SavedVariables
        if SUICore and SUICore.db then
            if SUICore.db.SaveToProfile then
                SUICore.db:SaveToProfile()
            end
        end
    end)
end

---------------------------------------------------------------------------
-- UPDATE ON PROFILE CHANGE
---------------------------------------------------------------------------
if SUICore and SUICore.db then
    SUICore.db.RegisterCallback(SUICore, "OnProfileChanged", function()
        -- Refresh resource bars after profile change
        C_Timer.After(0.1, function()
            if SUICore.UpdatePowerBar then
                SUICore:UpdatePowerBar()
            end
            if SUICore.UpdateSecondaryPowerBar then
                SUICore:UpdateSecondaryPowerBar()
            end
        end)
    end)
end

