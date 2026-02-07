-- Keybinding display name (must be global before Bindings.xml loads)
BINDING_NAME_SUAVIUI_TOGGLE_OPTIONS = "Open SuaviUI Options"

---@type table|AceAddon
SuaviUI = LibStub("AceAddon-3.0"):NewAddon("SuaviUI", "AceConsole-3.0", "AceEvent-3.0")
---@type table<string, string>
SuaviUI.L = LibStub("AceLocale-3.0"):GetLocale("SuaviUI")

local L = SuaviUI.L

---@type table
SuaviUI.DF = _G["DetailsFramework"]
SuaviUI.DEBUG_MODE = false

-- Version info
SuaviUI.versionString = C_AddOns.GetAddOnMetadata("SuaviUI", "Version") or "1.42"

---@type table
SuaviUI.defaults = {
    global = {
        welcomeScreenShown = false,  -- Has the welcome screen been shown?
        hideWelcomeScreen = false,   -- User preference to hide welcome screen
    },
    char = {
        ---@type table
        debug = {
            ---@type boolean
            reload = false
        }
    }
}

function SuaviUI:OnInitialize()
    ---@type AceDBObject-3.0
    self.db = LibStub("AceDB-3.0"):New("SuaviUI_DB", self.defaults, "Default")

    self:RegisterChatCommand("SUI", "SlashCommandOpen")
    self:RegisterChatCommand("suavi", "SlashCommandOpen")
    self:RegisterChatCommand("suaviui", "SlashCommandOpen")
    self:RegisterChatCommand("rl", "SlashCommandReload")
    
    -- Register our media files with LibSharedMedia
    self:CheckMediaRegistration()
end

-- Blizzard EncounterWarnings Edit Mode crash workaround (WoW 12.x)
-- EncounterWarningsViewElements:Init crashes with "attempt to compare a secret value"
-- because Edit Mode placeholder data contains protected nil fields.
-- Fix: noop SetIsEditing on the actual encounter warning frames.
-- Previous attempts failed because they patched a non-existent "EncounterWarnings" global;
-- the real frames are CriticalEncounterWarnings, MediumEncounterWarnings, MinorEncounterWarnings.
do
    local names = { "CriticalEncounterWarnings", "MediumEncounterWarnings", "MinorEncounterWarnings" }

    local function PatchFrames()
        local allDone = true
        for _, name in ipairs(names) do
            local frame = _G[name]
            if frame and frame.SetIsEditing then
                frame.SetIsEditing = function() end
            elseif not frame then
                allDone = false
            end
        end
        return allDone
    end

    -- Blizzard addons load before third-party, so frames should exist now
    if not PatchFrames() then
        -- Fallback: wait for the addon to finish loading
        local f = CreateFrame("Frame")
        f:RegisterEvent("ADDON_LOADED")
        f:SetScript("OnEvent", function(self, _, addon)
            if addon == "Blizzard_EncounterWarnings" then
                PatchFrames()
                self:UnregisterAllEvents()
            end
        end)
    end
end

-- CooldownViewer secret-value crash recovery (WoW 12.x)
-- Blizzard's RefreshLayout does: ReleaseAll() → Acquire → RefreshData() → Layout().
-- When RefreshData hits a restricted spell (hero talent 442726 / cooldownID 33527),
-- the for-loop crashes. Items after the crash point never get cooldownIDs, AND
-- Layout() never runs — so ALL items (even those set up correctly) have no anchor
-- points and are invisible. Fix: assign cooldownIDs to orphaned items, show them,
-- set icon textures, and run Layout() to position everything.
do
    local function IsSafeNumber(val)
        if val == nil then return true end
        local ok = pcall(function() return val + 0 end)
        return ok
    end

    local function SanitizeFrame(frame)
        if not IsSafeNumber(frame.cooldownChargesCount) then frame.cooldownChargesCount = 0 end
        if not IsSafeNumber(frame.previousCooldownChargesCount) then frame.previousCooldownChargesCount = 0 end
        if not IsSafeNumber(frame.cooldownStartTime) then frame.cooldownStartTime = 0 end
        if not IsSafeNumber(frame.cooldownDuration) then frame.cooldownDuration = 0 end
        if not IsSafeNumber(frame.cooldownModRate) then frame.cooldownModRate = 1 end
        if not IsSafeNumber(frame.availableAlertTriggerTime) then frame.availableAlertTriggerTime = nil end
        local ca = frame.cooldownIsActive
        if ca ~= nil and ca ~= true and ca ~= false then frame.cooldownIsActive = false end
        local oa = frame.isOnActualCooldown
        if oa ~= nil and oa ~= true and oa ~= false then frame.isOnActualCooldown = false end
        local ao = frame.allowOnCooldownAlert
        if ao ~= nil and ao ~= true and ao ~= false then frame.allowOnCooldownAlert = false end
    end

    local function RecoverViewer(viewer)
        if not viewer or not viewer.itemFramePool then return end

        local cooldownIDs
        pcall(function() cooldownIDs = viewer:GetCooldownIDs() end)

        for frame in viewer.itemFramePool:EnumerateActive() do
            SanitizeFrame(frame)

            -- Assign cooldownID to orphaned items (loop crashed before reaching them).
            -- Set minimum state directly instead of calling Blizzard's SetCooldownID
            -- to avoid triggering RefreshData in addon context.
            if cooldownIDs and frame.layoutIndex and not frame.cooldownID then
                local expectedID = cooldownIDs[frame.layoutIndex]
                if expectedID then
                    frame.cooldownID = expectedID
                    pcall(function()
                        frame.cooldownInfo =
                            C_CooldownViewer.GetCooldownInfoByCooldownID(expectedID)
                    end)
                    frame.isActive = true
                end
            end

            -- Show items that have a cooldownID but aren't visible
            if frame.cooldownID and not frame:IsShown() then
                pcall(frame.Show, frame)
            end

            -- Fix missing icon texture (RefreshSpellTexture never ran due to crash)
            if frame.cooldownID and frame.Icon then
                pcall(function()
                    if not frame.Icon:GetTexture() then
                        local info = frame.cooldownInfo
                        local sid = info and (info.overrideSpellID or info.spellID)
                        if sid then
                            local tex = C_Spell.GetSpellTexture(sid)
                            if tex then frame.Icon:SetTexture(tex) end
                        end
                    end
                end)
            end
        end

        -- CRITICAL: Re-run Layout() to set anchor points and position items.
        -- RefreshLayout calls Layout() AFTER RefreshData, but if RefreshData crashes,
        -- Layout() never runs. All items have cleared anchors (from ReleaseAll) and
        -- are invisible even when shown. This one call fixes all positioning.
        pcall(function()
            local container = viewer.ItemContainer
            if not container and viewer.GetItemContainerFrame then
                container = viewer:GetItemContainerFrame()
            end
            if container and container.Layout then
                container:Layout()
            end
        end)
    end

    local function RecoverAll()
        local viewers = {
            _G.EssentialCooldownViewer, _G.UtilityCooldownViewer,
            _G.BuffIconCooldownViewer,  _G.BuffBarCooldownViewer,
        }
        for _, v in ipairs(viewers) do RecoverViewer(v) end
    end

    local ticker
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Viewer just became visible → RefreshLayout → crash → no Layout()
            C_Timer.After(0.05, RecoverAll)
            C_Timer.After(0.15, RecoverAll)
            C_Timer.After(0.5,  RecoverAll)
            -- Keep recovering during combat (subsequent event crashes)
            if ticker then ticker:Cancel() end
            ticker = C_Timer.NewTicker(2.0, RecoverAll)
        elseif event == "PLAYER_REGEN_ENABLED" then
            if ticker then ticker:Cancel(); ticker = nil end
            C_Timer.After(0.5, RecoverAll)
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1.0, RecoverAll)
        end
    end)
end

-- Quick Keybind Mode shortcut (/kb)
SLASH_SUIKB1 = "/kb"
SlashCmdList["SUIKB"] = function()
    local LibKeyBound = LibStub("LibKeyBound-1.0", true)
    if LibKeyBound then
        LibKeyBound:Toggle()
    elseif QuickKeybindFrame then
        -- Fallback to Blizzard's Quick Keybind Mode (no mousewheel support)
        ShowUIPanel(QuickKeybindFrame)
    else
        print("|cff34D399SuaviUI:|r Quick Keybind Mode not available.")
    end
end

-- Cooldown Settings shortcut (/cdm)
SLASH_SUAVIUI_CDM1 = "/cdm"
SlashCmdList["SUAVIUI_CDM"] = function()
    if CooldownViewerSettings then
        CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown())
    else
        print("|cff34D399SuaviUI:|r Cooldown Settings not available. Enable CDM first.")
    end
end

-- Edit Mode shortcuts (/em and /ed)
SLASH_SUAVIUI_EM1 = "/em"
SLASH_SUAVIUI_EM2 = "/ed"
SlashCmdList["SUAVIUI_EM"] = function()
    if EditModeManagerFrame then
        -- Use the Blizzard slash command to avoid tainting EditMode
        RunSlashCmd("/editmode")
    else
        print("|cff34D399SuaviUI:|r Edit Mode not available.")
    end
end

function SuaviUI:SlashCommandOpen(input)
    if input and input == "debug" then
        self.db.char.debug.reload = true
        SuaviUI:SafeReload()
    elseif input and input == "editmode" then
        -- Toggle Unit Frames Edit Mode
        if _G.SuaviUI_ToggleUnitFrameEditMode then
            _G.SuaviUI_ToggleUnitFrameEditMode()
        else
            print("|cFF56D1FFSuaviUI:|r Unit Frames module not loaded.")
        end
        return
    end
    
    -- Default: Open custom GUI
    if self.GUI then
        self.GUI:Toggle()
    else
        print("|cFF56D1FFSuaviUI:|r GUI not loaded yet. Try again in a moment.")
    end
end

function SuaviUI:SlashCommandReload()
    SuaviUI:SafeReload()
end

function SuaviUI:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    -- Initialize SUICore (AceDB-based integration)
    if self.SUICore then
        -- Show intro message if enabled (defaults to true)
        if self.db.profile.chat.showIntroMessage ~= false then
            print("|cFF30D1FFSuaviUI|r loaded. |cFFFFFF00/sui|r to setup.")
            print("|cFF30D1FFSUI QUICK START:|r")
            print("|cFF34D3991.|r Action Bars & Menu Bar |cFFFFFF00HIDDEN|r on mouseover |cFFFFFF00by default|r. Go to |cFFFFFF00'Actionbars'|r tab in |cFFFFFF00/sui|r to unhide.")
            print("|cFF34D3992.|r Use |cFFFFFF00100% Icon Size|r on CDM Essential & Utility bars via |cFFFFFF00Edit Mode|r for best results.")
            print("|cFF34D3993.|r Position your |cFFFFFF00CDM bars|r in |cFFFFFF00Edit Mode|r and click |cFFFFFF00Save|r before exiting.")
        end
    end
end

function SuaviUI:PLAYER_ENTERING_WORLD(_, isInitialLogin, isReloadingUi)
    SuaviUI:BackwardsCompat()

    -- Ensure debug table exists
    if not self.db.char.debug then
        self.db.char.debug = { reload = false }
    end

    if not self.DEBUG_MODE then
        if self.db.char.debug.reload then
            self.DEBUG_MODE = true
            self.db.char.debug.reload = false
            self:DebugPrint("Debug Mode Enabled")
        end
    else
        self:DebugPrint("Debug Mode Enabled")
    end
end

function SuaviUI:DebugPrint(...)
    if self.DEBUG_MODE then
        self:Print(...)
    end
end

-- ADDON COMPARTMENT FUNCTIONS --
function SuaviUI_CompartmentClick()
    -- Open the new GUI
    if SuaviUI.GUI then
        SuaviUI.GUI:Toggle()
    end
end

local GameTooltip = GameTooltip
function SuaviUI_CompartmentOnEnter(self, button)
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(type(self) ~= "string" and self or button, "ANCHOR_LEFT")
    GameTooltip:AddLine(L["AddonName"] .. " v" .. SuaviUI.versionString)
    GameTooltip:AddLine(L["LeftClickOpen"])
    GameTooltip:Show()
end

function SuaviUI_CompartmentOnLeave()
    GameTooltip:Hide()
end




