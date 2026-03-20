-- customglows.lua
-- Custom glow effects for Essential and Utility cooldown viewers
-- Uses Blizzard's SpellActivationAlert system for proper sizing
-- Falls back to LibCustomGlow for additional glow styles

local _, SUI = ...

-- Get LibCustomGlow for fallback styles
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- Get IsSpellOverlayed API for reliable glow state detection
local IsSpellOverlayed = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed

-- Track which icons currently have active glows
local activeGlowIcons = {}  -- [icon] = true

-- TAINT-FIX: LibCustomGlow writes fields like icon["_PixelGlow_key"] directly on the frame
-- passed to it. When that frame is a Blizzard CDM item frame, this taints the entire frame,
-- causing all Blizzard reads of that frame's fields (isActive, charges, spellID, etc.) to
-- return "secret values tainted by SuaviUI". Fix: create a thin wrapper frame parented to the
-- CDM item. LibCustomGlow writes to the wrapper (SuaviUI-owned) instead of the CDM item frame.
local glowWrappers = setmetatable({}, { __mode = "k" })  -- [icon] = wrapper Frame

local function GetOrCreateGlowWrapper(icon)
    local wrapper = glowWrappers[icon]
    if not wrapper then
        wrapper = CreateFrame("Frame", nil, icon)
        wrapper:SetAllPoints(icon)
        wrapper:SetFrameLevel(icon:GetFrameLevel() + 2)
        glowWrappers[icon] = wrapper
    end
    return wrapper
end

-- Glow templates for proc effects
local GlowTemplates = {
    LoopGlow = {
        {
            name = "Default Blizzard Glow",
            atlas = "UI-HUD-ActionBar-Proc-Loop-Flipbook",
            rows = 6, columns = 5, frames = 30, duration = 1.0,
        },
        {
            name = "Blue Assist Glow",
            atlas = "RotationHelper-ProcLoopBlue-Flipbook",
            rows = 6, columns = 5, frames = 30, duration = 1.0,
        },
        {
            name = "Classic Ants",
            texture = "Interface\\SpellActivationOverlay\\IconAlertAnts",
            rows = 5, columns = 5, frames = 25, duration = 0.8,
        },
    },
}

-- ======================================================
-- Settings Access
-- ======================================================
local function GetSettings()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if not SUICore or not SUICore.db or not SUICore.db.profile then
        return nil
    end
    return SUICore.db.profile.customGlow
end

local function GetEffectsSettings()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if not SUICore or not SUICore.db or not SUICore.db.profile then
        return { hideEssential = true, hideUtility = true }
    end
    return SUICore.db.profile.cooldownEffects or { hideEssential = true, hideUtility = true }
end

-- ======================================================
-- Determine viewer type from icon
-- ======================================================
local function GetViewerType(icon)
    if not icon then return nil end
    
    local parent = icon:GetParent()
    if not parent then return nil end
    
    local parentName = parent:GetName()
    if not parentName then return nil end
    
    if parentName:find("EssentialCooldown") then
        return "Essential"
    elseif parentName:find("UtilityCooldown") then
        return "Utility"
    end
    
    return nil
end

-- ======================================================
-- Get settings for viewer type
-- ======================================================
local function GetViewerSettings(viewerType)
    local settings = GetSettings()
    if not settings then return nil end

    local effectsSettings = GetEffectsSettings()

    if viewerType == "Essential" then
        if not effectsSettings.hideEssential then return nil end
        if not settings.essentialEnabled then return nil end
        local glowType = settings.essentialGlowType or "Pixel Glow"
        if glowType == "Proc Glow" then glowType = "Pixel Glow" end
        return {
            enabled = true,
            glowType = glowType,
            color = settings.essentialColor or {0.95, 0.95, 0.32, 1},
            lines = settings.essentialLines or 14,
            frequency = settings.essentialFrequency or 0.25,
            thickness = settings.essentialThickness or 2,
            scale = settings.essentialScale or 1,
            xOffset = settings.essentialXOffset or 0,
            yOffset = settings.essentialYOffset or 0,
        }
    elseif viewerType == "Utility" then
        if not effectsSettings.hideUtility then return nil end
        if not settings.utilityEnabled then return nil end
        local glowType = settings.utilityGlowType or "Pixel Glow"
        if glowType == "Proc Glow" then glowType = "Pixel Glow" end
        return {
            enabled = true,
            glowType = glowType,
            color = settings.utilityColor or {0.95, 0.95, 0.32, 1},
            lines = settings.utilityLines or 14,
            frequency = settings.utilityFrequency or 0.25,
            thickness = settings.utilityThickness or 2,
            scale = settings.utilityScale or 1,
            xOffset = settings.utilityXOffset or 0,
            yOffset = settings.utilityYOffset or 0,
        }
    end

    return nil
end

-- ======================================================
-- Customize Blizzard's SpellActivationAlert
-- ======================================================
local function CustomizeBlizzardGlow(button, viewerSettings)
    if not button then return false end
    
    local region = button.SpellActivationAlert
    if not region then return false end
    
    -- Get the loop flipbook texture
    local loopFlipbook = region.ProcLoopFlipbook
    if not loopFlipbook then return false end
    
    -- Apply custom color
    local color = viewerSettings.color or {0.95, 0.95, 0.32, 1}
    loopFlipbook:SetDesaturated(true)  -- Desaturate first so color applies properly
    loopFlipbook:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    
    -- Also color the start flipbook if it exists
    local startFlipbook = region.ProcStartFlipbook
    if startFlipbook then
        startFlipbook:SetDesaturated(true)
        startFlipbook:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
    
    -- Mark as active in side table (avoid mutating Blizzard icon userdata)
    activeGlowIcons[button] = true
    
    return true
end

-- ======================================================
-- LibCustomGlow application (supports 3 glow types)
-- ======================================================
local function ApplyLibCustomGlow(icon, viewerSettings)
    if not LCG then return false end
    if not icon then return false end

    local glowType = viewerSettings.glowType
    local color = viewerSettings.color
    local lines = viewerSettings.lines
    local frequency = viewerSettings.frequency
    local thickness = viewerSettings.thickness
    local scale = viewerSettings.scale or 1
    local xOffset = viewerSettings.xOffset or 0
    local yOffset = viewerSettings.yOffset or 0

    -- Stop any existing glow first
    StopGlow(icon)

    -- TAINT-FIX: Use a wrapper frame so LibCustomGlow writes its tracking fields
    -- (e.g., frame["_PixelGlow_key"]) on our wrapper, not on the Blizzard CDM item frame.
    local wrapper = GetOrCreateGlowWrapper(icon)

    if glowType == "Pixel Glow" then
        -- Pixel Glow: animated lines around the border
        LCG.PixelGlow_Start(wrapper, color, lines, frequency, nil, thickness, 0, 0, true, "_QUICustomGlow")
        local glowFrame = wrapper["_PixelGlow_QUICustomGlow"]
        if glowFrame then
            glowFrame:ClearAllPoints()
            glowFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", -xOffset, xOffset)
            glowFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", xOffset, -xOffset)
        end

    elseif glowType == "Autocast Shine" then
        -- Autocast Shine: orbiting sparkle spots
        LCG.AutoCastGlow_Start(wrapper, color, lines, frequency, scale, 0, 0, "_QUICustomGlow")
        local glowFrame = wrapper["_AutoCastGlow_QUICustomGlow"]
        if glowFrame then
            glowFrame:ClearAllPoints()
            glowFrame:SetPoint("TOPLEFT", icon, "TOPLEFT", -xOffset, xOffset)
            glowFrame:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", xOffset, -xOffset)
        end
    end

    -- Flag already set by StartGlow, just ensure it's there
    activeGlowIcons[icon] = true

    return true
end

-- ======================================================
-- Main glow application function
-- ======================================================
local function StartGlow(icon)
    if not icon then return end
    
    -- Already has our glow? Skip
    if activeGlowIcons[icon] then return end
    
    local viewerType = GetViewerType(icon)
    if not viewerType then return end
    
    local viewerSettings = GetViewerSettings(viewerType)
    if not viewerSettings then return end
    
    -- Always use LibCustomGlow since we hide Blizzard's SpellActivationAlert
    -- Set active state first in side table so cooldowneffects.lua doesn't interfere
    activeGlowIcons[icon] = true
    
    ApplyLibCustomGlow(icon, viewerSettings)
end

-- Stop all glow effects on an icon
function StopGlow(icon)
    if not icon then return end

    -- TAINT-FIX: Stop glow on the wrapper frame, not the CDM item frame
    local wrapper = glowWrappers[icon]
    if LCG and wrapper then
        pcall(LCG.PixelGlow_Stop, wrapper, "_QUICustomGlow")
        pcall(LCG.AutoCastGlow_Stop, wrapper, "_QUICustomGlow")
    end

    activeGlowIcons[icon] = nil
end

-- ======================================================
-- Scan for existing proc glows on CDM icons
-- Used on init and zone changes to catch already-active procs
-- ======================================================
local function ScanForExistingGlows()
    for _, viewerName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer"}) do
        local viewer = _G[viewerName]
        if viewer then
            local ok, children = pcall(function() return {viewer:GetChildren()} end)
            if ok and children then
                for _, icon in ipairs(children) do
                    if not activeGlowIcons[icon] then
                        pcall(function()
                            if icon:IsShown() and icon.SpellActivationAlert
                               and icon.SpellActivationAlert:IsShown() then
                                StartGlow(icon)
                            end
                        end)
                    end
                end
            end
        end
    end
end

-- ======================================================
-- Hook into Blizzard's glow system
-- ======================================================
local function SetupGlowHooks()
    if SUI.DISABLE_ALL_CDM_HOOKS or not SUI.CDM_HOOKS.glows then return end
    -- TAINT-FIX: Hook ActionButtonSpellAlertManager (singleton) for CDM proc detection.
    -- Previously hooked per-CDM-icon methods (OnSpellActivationOverlayGlowShowEvent,
    -- OnSpellActivationOverlayGlowHideEvent, RefreshOverlayGlow) which rawset wrapper
    -- functions on each CDM item frame's Lua table, tainting those tables.
    -- Hooking the singleton manager only rawsets on the manager's table.
    local mgr = _G.ActionButtonSpellAlertManager
    if mgr then
        if mgr.ShowAlert then
            hooksecurefunc(mgr, "ShowAlert", function(self, button)
                if not button then return end
                if activeGlowIcons[button] then return end  -- Already glowing
                local viewerType = GetViewerType(button)
                if not viewerType then return end
                -- Defer glow creation outside RefreshData secure chain
                C_Timer.After(0, function()
                    local settings = GetViewerSettings(viewerType)
                    if settings then
                        pcall(function()
                            if button:IsShown() then
                                StartGlow(button)
                            end
                        end)
                    end
                end)
            end)
        end
        if mgr.HideAlert then
            hooksecurefunc(mgr, "HideAlert", function(self, button)
                if not button then return end
                if not activeGlowIcons[button] then return end  -- No glow to remove
                local viewerType = GetViewerType(button)
                if viewerType then
                    StopGlow(button)
                end
            end)
        end
    end

    -- Keep ActionButton hooks as backup for non-CDM scenarios
    if type(ActionButton_ShowOverlayGlow) == "function" then
        hooksecurefunc("ActionButton_ShowOverlayGlow", function(button)
            if not button then return end
            local viewerType = GetViewerType(button)
            if not viewerType then return end
            local viewerSettings = GetViewerSettings(viewerType)
            if not viewerSettings then return end
            if button:IsShown() then
                StartGlow(button)
            end
        end)
    end

    if type(ActionButton_HideOverlayGlow) == "function" then
        hooksecurefunc("ActionButton_HideOverlayGlow", function(button)
            if not button then return end
            local viewerType = GetViewerType(button)
            if viewerType then
                StopGlow(button)
            end
        end)
    end

    -- Initial scan for existing proc glows + re-scan on zone changes
    C_Timer.After(1.0, ScanForExistingGlows)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(self, event)
        C_Timer.After(0.5, ScanForExistingGlows)
    end)
end

-- ======================================================
-- Refresh all glows (called when settings change)
-- ======================================================
local function RefreshAllGlows()
    -- Store which icons had glows before refresh
    local iconsWithGlows = {}
    for icon, _ in pairs(activeGlowIcons) do
        if icon then
            iconsWithGlows[icon] = true
        end
    end
    
    -- Stop all existing custom glows
    for icon, _ in pairs(activeGlowIcons) do
        if icon then
            StopGlow(icon)
        end
    end
    wipe(activeGlowIcons)
    
    -- Re-apply glows to icons that had them before
    for icon, _ in pairs(iconsWithGlows) do
        if icon and icon:IsShown() then
            StartGlow(icon)
        end
    end
end

-- ======================================================
-- Initialize
-- ======================================================
local glowHooksSetup = false

local function EnsureGlowHooks()
    if glowHooksSetup then return end
    glowHooksSetup = true
    SetupGlowHooks()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        -- Set up hooks immediately - no delay!
        EnsureGlowHooks()
    elseif event == "PLAYER_LOGIN" then
        -- Backup: ensure hooks are set up by login
        EnsureGlowHooks()
    end
end)

-- ======================================================
-- Export to SUI namespace
-- ======================================================
SUI.CustomGlows = {
    StartGlow = StartGlow,
    StopGlow = StopGlow,
    RefreshAllGlows = RefreshAllGlows,
    GetViewerType = GetViewerType,
    activeGlowIcons = activeGlowIcons,
}

-- Global function for config panel to call
_G.SuaviUI_RefreshCustomGlows = RefreshAllGlows

-- Debug functions
_G.SuaviUI_TestCustomGlow = function(viewerType)
    viewerType = viewerType or "Essential"
    local viewer = _G[viewerType .. "CooldownViewer"]
    if viewer then
        local children = {viewer:GetChildren()}
        for i, child in ipairs(children) do
            if child:IsShown() then
                StartGlow(child)
                print("|cFF00FF00[SuaviUI]|r Test glow applied to " .. viewerType .. " icon #" .. i)
                return
            end
        end
        print("|cFFFF0000[SuaviUI]|r No visible icons in " .. viewerType .. " viewer")
    else
        print("|cFFFF0000[SuaviUI]|r " .. viewerType .. "CooldownViewer not found")
    end
end

_G.SuaviUI_StopAllCustomGlows = function()
    for icon, _ in pairs(activeGlowIcons) do
        if icon then
            StopGlow(icon)
        end
    end
    wipe(activeGlowIcons)
    print("|cFF00FF00[SuaviUI]|r All custom glows stopped")
end




