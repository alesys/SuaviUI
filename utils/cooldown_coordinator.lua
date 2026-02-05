-- cooldown_coordinator.lua
-- Coordinates refreshes between NCDM and CooldownManager to prevent layout fighting

local _, ns = ...

local Coordinator = {
    state = {
        timer = nil,
        inProgress = false,
        phase = nil,
    },
}

ns.CooldownCoordinator = Coordinator
if _G.SuaviUI then
    _G.SuaviUI.CooldownCoordinator = Coordinator
end

local DEFAULT_PARTS = { icons = true, bars = true, essential = true, utility = true }

local function SetInProgress(value)
    Coordinator.state.inProgress = value and true or false
    _G.SuaviUI_CooldownRefreshInProgress = Coordinator.state.inProgress
end

local function SetPhase(phase)
    Coordinator.state.phase = phase
    _G.SuaviUI_CooldownRefreshPhase = phase
end

function Coordinator:IsInProgress()
    return self.state.inProgress
end

function Coordinator:GetPhase()
    return self.state.phase
end

function Coordinator:RequestRefresh(source, parts, opts)
    parts = parts or DEFAULT_PARTS

    local delay = (opts and opts.delay) or 0.05
    if self.state.timer then
        self.state.timer:Cancel()
        self.state.timer = nil
    end

    self.state.timer = C_Timer.After(delay, function()
        if self.state.inProgress then
            return
        end

        SetInProgress(true)
        _G.SuaviUI_CooldownRefreshSource = source

        -- Pass 1: NCDM (styling/sizing)
        SetPhase("ncdm")
        if ns.NCDM and ns.NCDM.Refresh then
            pcall(ns.NCDM.Refresh, ns.NCDM)
        end
        if _G.SuaviUI_RefreshBuffBar then
            pcall(_G.SuaviUI_RefreshBuffBar)
        end

        -- Pass 2: CMC (centering/placement)
        SetPhase("cmc")
        if ns.CooldownManager and ns.CooldownManager.ForceRefresh then
            pcall(ns.CooldownManager.ForceRefresh, parts)
        end

        SetPhase(nil)
        _G.SuaviUI_CooldownRefreshSource = nil
        SetInProgress(false)
    end)
end

function Coordinator:RequestRefreshImmediate(source, parts)
    return self:RequestRefresh(source, parts, { delay = 0 })
end

_G.SuaviUI_RequestCooldownRefresh = function(source, parts, opts)
    if Coordinator and Coordinator.RequestRefresh then
        Coordinator:RequestRefresh(source, parts, opts)
        return true
    end
    return false
end
