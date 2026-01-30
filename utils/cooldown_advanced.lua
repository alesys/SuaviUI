-- cooldown_advanced.lua
-- Advanced features implementation for CooldownManagerCentered integration
-- Handles swipe colors, size controls, and rotation highlights

local _, SUI = ...

local CooldownAdvanced = {}

-- Get setting value from profile
local function GetSetting(key, default)
    local profile = SUI and SUI.SUICore and SUI.SUICore.db and SUI.SUICore.db.profile
    if not profile then
        return default
    end
    return profile[key] or default
end

-- Set setting value in profile
local function SetSetting(key, value)
    local profile = SUI and SUI.SUICore and SUI.SUICore.db and SUI.SUICore.db.profile
    if profile then
        profile[key] = value
    end
end

-- =====================================================
-- COOLDOWN SWIPE COLORS
-- =====================================================

-- Apply custom swipe colors to a cooldown frame
function CooldownAdvanced.ApplySwipeColors(icon)
    if not icon or not icon.Cooldown then
        return
    end
    
    local enabled = GetSetting("cooldownManager_customSwipeColor_enabled", false)
    if not enabled then
        -- Reset to default colors
        if icon.Cooldown.SetSwipeColor then
            icon.Cooldown:SetSwipeColor(0, 0, 0, 0.8)  -- Default WoW swipe color
        end
        return
    end
    
    -- Get custom colors from settings
    local activeR = GetSetting("cooldownManager_customActiveColor_r", 1)
    local activeG = GetSetting("cooldownManager_customActiveColor_g", 0.95) 
    local activeB = GetSetting("cooldownManager_customActiveColor_b", 0.57)
    local activeA = GetSetting("cooldownManager_customActiveColor_a", 0.69)
    
    local cdR = GetSetting("cooldownManager_customCDSwipeColor_r", 0)
    local cdG = GetSetting("cooldownManager_customCDSwipeColor_g", 0)
    local cdB = GetSetting("cooldownManager_customCDSwipeColor_b", 0)
    local cdA = GetSetting("cooldownManager_customCDSwipeColor_a", 0.69)
    
    -- Apply the appropriate color based on cooldown state
    if icon.Cooldown.SetSwipeColor then
        -- Check if this is an active aura or on cooldown
        local isActiveAura = false
        if icon.GetDuration and icon.GetExpirationTime then
            local duration = icon:GetDuration()
            local expTime = icon:GetExpirationTime()
            isActiveAura = duration > 0 and expTime > GetTime()
        end
        
        if isActiveAura then
            icon.Cooldown:SetSwipeColor(activeR, activeG, activeB, activeA)
        else
            icon.Cooldown:SetSwipeColor(cdR, cdG, cdB, cdA)
        end
    end
end

-- Refresh swipe colors for all icons in a viewer
function CooldownAdvanced.RefreshViewerSwipeColors(viewerName)
    local viewer = _G[viewerName]
    if not viewer then
        return
    end
    
    for i = 1, viewer:GetNumChildren() do
        local child = select(i, viewer:GetChildren())
        if child then
            CooldownAdvanced.ApplySwipeColors(child)
        end
    end
end

-- =====================================================
-- SIZE CONTROLS
-- =====================================================

-- Apply size constraints between Essential and Utility viewers
function CooldownAdvanced.ApplySizeControls()
    local essentialViewer = _G.EssentialCooldownViewer
    local utilityViewer = _G.UtilityCooldownViewer
    
    if not essentialViewer or not utilityViewer then
        return
    end
    
    local limitSize = GetSetting("cooldownManager_limitUtilitySizeToEssential", false)
    local normalizeSize = GetSetting("cooldownManager_normalizeUtilitySize", false)
    
    if limitSize then
        -- Constrain Utility viewer width to match Essential viewer width
        local essentialWidth = essentialViewer:GetWidth()
        if essentialWidth > 0 then
            utilityViewer:SetWidth(essentialWidth)
        end
    end
    
    if normalizeSize then
        -- Make both viewers the same size
        local essentialWidth = essentialViewer:GetWidth()
        local essentialHeight = essentialViewer:GetHeight()
        
        if essentialWidth > 0 and essentialHeight > 0 then
            utilityViewer:SetSize(essentialWidth, essentialHeight)
        end
    end
end

-- =====================================================
-- UTILITY DIMMING
-- =====================================================

-- Apply dimming effect to utility icons when not on cooldown
function CooldownAdvanced.ApplyUtilityDimming(icon)
    if not icon then
        return
    end
    
    local enabled = GetSetting("cooldownManager_utility_dimWhenNotOnCD", false)
    if not enabled then
        -- Reset to full opacity
        icon:SetAlpha(1)
        return
    end
    
    local dimOpacity = GetSetting("cooldownManager_utility_dimOpacity", 0.3)
    
    -- Check if icon is on cooldown
    local isOnCooldown = false
    if icon.Cooldown then
        local start, duration = icon.Cooldown:GetCooldownTimes()
        isOnCooldown = start > 0 and duration > 1500  -- Ignore GCD (1.5s or less)
    end
    
    if isOnCooldown then
        icon:SetAlpha(1)  -- Full opacity when on cooldown
    else
        icon:SetAlpha(dimOpacity)  -- Dim when not on cooldown
    end
end

-- Refresh dimming for all utility icons
function CooldownAdvanced.RefreshUtilityDimming()
    local utilityViewer = _G.UtilityCooldownViewer
    if not utilityViewer then
        return
    end
    
    for i = 1, utilityViewer:GetNumChildren() do
        local child = select(i, utilityViewer:GetChildren())
        if child then
            CooldownAdvanced.ApplyUtilityDimming(child)
        end
    end
end

-- =====================================================
-- ROTATION HIGHLIGHT
-- =====================================================

-- Apply rotation highlight to icons based on rotation assist addon
function CooldownAdvanced.ApplyRotationHighlight(icon, viewerType)
    if not icon then
        return
    end
    
    local showKey = "cooldownManager_showHighlight_" .. viewerType
    local enabled = GetSetting(showKey, false)
    
    if not enabled then
        -- Remove any existing highlights
        if icon.suiRotationGlow then
            icon.suiRotationGlow:Hide()
            icon.suiRotationGlow = nil
        end
        return
    end
    
    -- This would integrate with rotation assist addons like Hekili, MaxDps, etc.
    -- For now, this is a placeholder that could be expanded based on specific addon integration
    -- The actual implementation would depend on which rotation addon the user has installed
    
    -- Example: Check if this ability is recommended by rotation addon
    local isRecommended = false  -- Placeholder - would check rotation addon state
    
    if isRecommended then
        -- Apply glow effect using SuaviUI's custom glow system
        if SUI.CustomGlow and not icon.suiRotationGlow then
            SUI.CustomGlow.CreateGlow(icon, {
                glowType = "Pixel Glow",
                color = {1, 1, 0, 1},  -- Yellow highlight
                lines = 8,
                frequency = 0.25,
                thickness = 2,
            })
            icon.suiRotationGlow = true
        end
    else
        -- Remove highlight
        if icon.suiRotationGlow then
            if SUI.CustomGlow then
                SUI.CustomGlow.RemoveGlow(icon)
            end
            icon.suiRotationGlow = nil
        end
    end
end

-- Refresh rotation highlights for a viewer
function CooldownAdvanced.RefreshViewerRotationHighlights(viewerName, viewerType)
    local viewer = _G[viewerName]
    if not viewer then
        return
    end
    
    -- Only Essential and Utility viewers support rotation highlights
    if viewerType ~= "Essential" and viewerType ~= "Utility" then
        return
    end
    
    for i = 1, viewer:GetNumChildren() do
        local child = select(i, viewer:GetChildren())
        if child then
            CooldownAdvanced.ApplyRotationHighlight(child, viewerType)
        end
    end
end

-- =====================================================
-- MASTER REFRESH FUNCTIONS
-- =====================================================

-- Apply all advanced features to a single icon
function CooldownAdvanced.ApplyAllFeatures(icon, viewerType)
    CooldownAdvanced.ApplySwipeColors(icon)
    
    if viewerType == "Utility" then
        CooldownAdvanced.ApplyUtilityDimming(icon)
    end
    
    CooldownAdvanced.ApplyRotationHighlight(icon, viewerType)
end

-- Refresh all advanced features for a specific viewer
function CooldownAdvanced.RefreshViewerFeatures(viewerName, viewerType)
    CooldownAdvanced.RefreshViewerSwipeColors(viewerName)
    
    if viewerType == "Utility" then
        CooldownAdvanced.RefreshUtilityDimming()
    end
    
    CooldownAdvanced.RefreshViewerRotationHighlights(viewerName, viewerType)
end

-- Refresh all advanced features across all viewers
function CooldownAdvanced.RefreshAllFeatures()
    local viewers = {
        {"EssentialCooldownViewer", "Essential"},
        {"UtilityCooldownViewer", "Utility"},
        {"BuffIconCooldownViewer", "BuffIcons"},
    }
    
    for _, viewerInfo in ipairs(viewers) do
        CooldownAdvanced.RefreshViewerFeatures(viewerInfo[1], viewerInfo[2])
    end
    
    -- Apply size controls
    CooldownAdvanced.ApplySizeControls()
end

-- Hook cooldown updates to refresh dimming and colors
local function HookCooldownUpdates()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    frame:RegisterEvent("UNIT_AURA")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "SPELL_UPDATE_COOLDOWN" then
            CooldownAdvanced.RefreshUtilityDimming()
            
            -- Refresh swipe colors for all viewers
            local viewers = {"EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer"}
            for _, viewerName in ipairs(viewers) do
                CooldownAdvanced.RefreshViewerSwipeColors(viewerName)
            end
        elseif event == "UNIT_AURA" then
            local unit = ...
            if unit == "player" then
                CooldownAdvanced.RefreshUtilityDimming()
            end
        end
    end)
end

-- Initialize hooks when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == GetAddOnMetadata("SuaviUI", "Title") then
        HookCooldownUpdates()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- Export the module
SUI.CooldownAdvanced = CooldownAdvanced