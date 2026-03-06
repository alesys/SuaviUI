-- cooldownswipe.lua
-- Granular cooldown swipe control: Buff Duration / GCD / Cooldown swipes

local _, SUI = ...

local hookedLayoutViewers = setmetatable({}, { __mode = "k" })
local pendingSwipeRescan = setmetatable({}, { __mode = "k" })

-- Get settings from AceDB
local function GetSettings()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if not SUICore or not SUICore.db or not SUICore.db.profile then
        return {
            showBuffSwipe = true,
            showBuffIconSwipe = false,
            showGCDSwipe = true,
            showCooldownSwipe = true,
        }
    end
    local cs = SUICore.db.profile.cooldownSwipe
    if not cs then
        cs = {
            showBuffSwipe = true,
            showBuffIconSwipe = false,
            showGCDSwipe = true,
            showCooldownSwipe = true,
        }
        SUICore.db.profile.cooldownSwipe = cs
    end
    return cs
end

-- TAINT-FIX: Apply swipe/edge settings to one icon without hooking CDM item frames.
-- Previously used hooksecurefunc(icon.Cooldown, "SetCooldown", ...) which rawset a
-- wrapper on the Cooldown widget inside Blizzard's secure RefreshData chain.
-- Now uses periodic polling instead — all CDM frame reads are pcall-guarded for
-- secret-value safety.
local function ApplySwipeSettings(icon)
    if not icon then return end
    local ok, cd = pcall(function() return icon.Cooldown end)
    if not ok or not cd then return end

    local settings = GetSettings()
    local showSwipe
    local auraActive

    pcall(function()
        auraActive = icon.auraInstanceID and icon.auraInstanceID > 0
    end)

    -- Swipe logic
    -- Priority 1: Buff duration (auraInstanceID > 0)
    if auraActive then
        -- Check if this icon is in BuffIconCooldownViewer (separate toggle)
        local parent
        pcall(function() parent = icon:GetParent() end)
        if parent == _G.BuffIconCooldownViewer then
            showSwipe = settings.showBuffIconSwipe
        else
            showSwipe = settings.showBuffSwipe
        end
    else
        -- Priority 2: GCD vs Cooldown (use CooldownFlash visibility)
        pcall(function()
            if icon.CooldownFlash and icon.CooldownFlash:IsShown() then
                showSwipe = settings.showCooldownSwipe
            else
                showSwipe = settings.showGCDSwipe
            end
        end)
        -- Fallback: treat as cooldown
        if showSwipe == nil then
            showSwipe = settings.showCooldownSwipe
        end
    end

    pcall(function() cd:SetDrawSwipe(showSwipe) end)

    -- Edge logic: Buff icons use their swipe setting, cooldowns use showRechargeEdge
    local showEdge
    if auraActive then
        showEdge = showSwipe  -- Buff icons: edge follows swipe toggle
    else
        showEdge = settings.showRechargeEdge  -- Cooldowns: separate setting
    end
    pcall(function() cd:SetDrawEdge(showEdge) end)
end

-- Process all icons in a viewer
local function ProcessViewer(viewer)
    if not viewer then return end

    local ok, children = pcall(function() return {viewer:GetChildren()} end)
    if not ok or not children then return end

    for _, icon in ipairs(children) do
        pcall(function()
            if icon.Cooldown and icon:IsShown() then
                ApplySwipeSettings(icon)
            end
        end)
    end
end

-- Apply settings to all CDM viewers
local function ApplyAllSettings()
    local viewers = {
        _G.EssentialCooldownViewer,
        _G.UtilityCooldownViewer,
        _G.BuffIconCooldownViewer,
    }

    for _, viewer in ipairs(viewers) do
        ProcessViewer(viewer)

        -- Hook Layout to catch new icons (viewer-level hook only, safe)
        if viewer and viewer.Layout and not hookedLayoutViewers[viewer] then
            hookedLayoutViewers[viewer] = true
            hooksecurefunc(viewer, "Layout", function()
                -- LOW-LEVEL SAFETY: Debounce to prevent timer flooding on empty viewers.
                if pendingSwipeRescan[viewer] then return end
                pendingSwipeRescan[viewer] = true
                C_Timer.After(0.15, function()
                    pendingSwipeRescan[viewer] = nil
                    ProcessViewer(viewer)
                end)
            end)
        end
    end
end

-- Periodic ticker to keep swipe settings applied continuously.
-- Replaces per-icon hooksecurefunc(icon.Cooldown, "SetCooldown", ...) hooks
-- which rawset on CDM Cooldown widgets inside Blizzard's secure chain.
local swipeTicker = nil

local function StartSwipeTicker()
    if swipeTicker then return end
    swipeTicker = C_Timer.NewTicker(0.2, function()
        local viewers = {
            _G.EssentialCooldownViewer,
            _G.UtilityCooldownViewer,
            _G.BuffIconCooldownViewer,
        }
        for _, viewer in ipairs(viewers) do
            ProcessViewer(viewer)
        end
    end)
end

-- Initialize on addon load
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" and arg == "Blizzard_CooldownManager" then
        C_Timer.After(0.5, ApplyAllSettings)
        C_Timer.After(1.0, StartSwipeTicker)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, ApplyAllSettings)
        StartSwipeTicker()
    end
end)

-- Export to SUI namespace
SUI.CooldownSwipe = {
    Apply = ApplyAllSettings,
    GetSettings = GetSettings,
}

-- Global function for config panel to call
_G.SuaviUI_RefreshCooldownSwipe = function()
    ApplyAllSettings()
end
