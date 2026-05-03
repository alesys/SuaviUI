--[[
    SuaviUI Bonus Roll Mover
    Provides an Edit Mode-movable holder for Blizzard's BonusRollFrame.

    Background: BonusRollFrame is parented to UIParent but anchored via
    SetPoint to GroupLootContainer.BOTTOM (see Blizzard_UIPanels_Game/Mainline/
    GroupLootFrame.lua:88). GroupLootContainer's position is controlled by
    Blizzard's UIParentBottomManagedFrameTemplate panel manager — there's no
    Edit Mode entry for it.

    Strategy: register a SuaviUI-owned holder with LibEQOLEditMode, hook
    GroupLootContainer_Update so that whenever Blizzard sets BonusRollFrame's
    anchor we override it to point to our holder instead. The holder's
    position is persisted via AceDB.
]]

local ADDON_NAME, ns = ...

local LEM = LibStub("LibEQOLEditMode-1.0", true)
if not LEM then return end

local SUI_BonusRoll = {}
ns.BonusRoll = SUI_BonusRoll

---------------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------------
local holder
local previewFrame
local registered  = false
local initialized = false
local hookInstalled = false

---------------------------------------------------------------------------
-- DATABASE
---------------------------------------------------------------------------
local function GetDB()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile
    end
    return nil
end

local function GetSettings()
    local db = GetDB()
    return db and db.bonusRoll or nil
end

---------------------------------------------------------------------------
-- POSITION OVERRIDE
---------------------------------------------------------------------------
-- Whenever Blizzard's GroupLootContainer_Update sets BonusRollFrame's
-- anchor (via SetPoint to GroupLootContainer.BOTTOM), we override it.
local function OverrideBonusRollAnchor()
    if not BonusRollFrame or not holder then return end
    local s = GetSettings()
    if not s or not s.enabled then return end

    -- Only override if the frame is actually in the rollFrames list (i.e.
    -- Blizzard just placed it). Avoid stomping on unrelated SetPoint usage.
    local container = GroupLootContainer
    if not container or not container.rollFrames then return end
    local found = false
    for _, f in pairs(container.rollFrames) do
        if f == BonusRollFrame then found = true; break end
    end
    if not found then return end

    BonusRollFrame:ClearAllPoints()
    BonusRollFrame:SetPoint("CENTER", holder, "CENTER", 0, 0)
end

local function InstallHook()
    if hookInstalled then return end
    if type(GroupLootContainer_Update) ~= "function" then return end
    hooksecurefunc("GroupLootContainer_Update", function()
        -- Defer one tick so our anchor wins after Blizzard's SetPoint loop.
        C_Timer.After(0, OverrideBonusRollAnchor)
    end)
    hookInstalled = true
end

---------------------------------------------------------------------------
-- POSITION PERSISTENCE
---------------------------------------------------------------------------
local function LoadPosition()
    if not holder then return end
    local s = GetSettings()
    local p = (s and s.position) or { point = "CENTER", x = 0, y = -150 }
    holder:ClearAllPoints()
    holder:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x or 0, p.y or -150)
end

local function OnPositionChanged(frame, layoutName, point, x, y)
    if type(layoutName) == "number" then
        local origX, origY, origPoint = layoutName, point, x
        x, y, point = origX, origY, origPoint
    end
    local s = GetSettings(); if not s then return end
    if not s.position then s.position = {} end
    s.position.point = point or "CENTER"
    s.position.x = tonumber(x) or 0
    s.position.y = tonumber(y) or -150

    -- Re-anchor a currently-shown BonusRollFrame so the user sees the move
    -- immediately without waiting for the next bonus roll.
    if BonusRollFrame and BonusRollFrame:IsShown() then
        BonusRollFrame:ClearAllPoints()
        BonusRollFrame:SetPoint("CENTER", holder, "CENTER", 0, 0)
    end
end

---------------------------------------------------------------------------
-- EDIT MODE PREVIEW
---------------------------------------------------------------------------
-- BonusRollFrame_StartBonusRoll requires real spell IDs, currency, encounter
-- data, etc. — we can't fake one cleanly. Instead, render a labeled
-- placeholder of the same dimensions so the user has something to drag.
local function CreatePreview()
    if previewFrame then return previewFrame end
    previewFrame = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    previewFrame:SetAllPoints(holder)
    previewFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    previewFrame:SetBackdropColor(0.1, 0.1, 0.12, 0.7)
    previewFrame:SetBackdropBorderColor(0.30, 0.85, 0.99, 0.8)

    local icon = previewFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas("BonusLoot-Chest")
    icon:SetSize(48, 48)
    icon:SetPoint("LEFT", previewFrame, "LEFT", 12, 0)

    local label = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("LEFT", icon, "RIGHT", 10, 6)
    label:SetText("Bonus Roll")
    label:SetTextColor(1, 0.82, 0)

    local sub = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("LEFT", icon, "RIGHT", 10, -10)
    sub:SetText("(SuaviUI Edit Mode preview)")
    sub:SetTextColor(0.7, 0.7, 0.75)

    previewFrame:Hide()
    return previewFrame
end

local function StartEditModePreview()
    CreatePreview()
    previewFrame:Show()
    holder:Show()
end

local function StopEditModePreview()
    if previewFrame then previewFrame:Hide() end
    -- Holder stays "shown" (it's an invisible position frame); no children
    -- visible outside of preview.
end

---------------------------------------------------------------------------
-- LEM REGISTRATION
---------------------------------------------------------------------------
local function RegisterWithLEM()
    if registered or not holder then return end
    holder.editModeName = "Bonus Roll"

    local s = GetSettings()
    local defaults = {
        point = (s and s.position and s.position.point) or "CENTER",
        x = (s and s.position and s.position.x) or 0,
        y = (s and s.position and s.position.y) or -150,
    }

    local ok = pcall(function()
        LEM:AddFrame(holder, OnPositionChanged, defaults)
        LEM:SetFrameDragEnabled(holder, function()
            return LEM.IsInEditMode and LEM:IsInEditMode() or false
        end)
        if LEM.SetFrameResetVisible then
            LEM:SetFrameResetVisible(holder, function()
                return LEM.IsInEditMode and LEM:IsInEditMode() or false
            end)
        end
    end)

    if ok then
        registered = true
        if not holder._editModeOverlay then
            local overlay = CreateFrame("Frame", nil, holder, "BackdropTemplate")
            overlay:SetAllPoints(holder)
            overlay:SetFrameLevel(holder:GetFrameLevel() + 1)
            overlay:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 2,
            })
            overlay:SetBackdropBorderColor(0.3, 0.8, 1, 0.6)
            overlay:Hide()
            holder._editModeOverlay = overlay
        end
    end

    LEM:RegisterCallback("enter", function() StartEditModePreview() end)
    LEM:RegisterCallback("exit",  function() StopEditModePreview()  end)
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
local function CreateHolder()
    holder = CreateFrame("Frame", "SuaviUI_BonusRollHolder", UIParent)
    -- Match BonusRollFrame's dimensions (286 x 76 per the XML).
    holder:SetSize(286, 76)
    holder:SetFrameStrata("DIALOG")
end

function SUI_BonusRoll:Initialize()
    if initialized then return end
    if not LEM then return end
    if not GetDB() then
        C_Timer.After(1, function() SUI_BonusRoll:Initialize() end)
        return
    end

    CreateHolder()
    LoadPosition()
    RegisterWithLEM()
    InstallHook()

    initialized = true
end

---------------------------------------------------------------------------
-- DEFERRED START
---------------------------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(0.7, function()
        SUI_BonusRoll:Initialize()
    end)
end)
