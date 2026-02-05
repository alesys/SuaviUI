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
        ShowUIPanel(EditModeManagerFrame)
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




