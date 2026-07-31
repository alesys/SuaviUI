---------------------------------------------------------------------------
-- SuaviUI Omnium Folio
-- Shared data layer for Midnight's Omnium Folio (internally "Runes of Power")
-- plus the unspent-Omnium alert.
--
-- Blizzard reference: Blizzard_ExpansionLandingPage/Blizzard_MidnightLandingPage.lua
-- The folio is a trait tree driven by the generic C_Traits API. Omnium itself is
-- the currency the tree spends, reachable through the tree's traitCurrencyID.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SUI = ns.SUI or {}
ns.SUI = SUI

-- Matches RUNES_OF_POWER_SYSTEM_ID / RUNES_OF_POWER_TREE_ID in Blizzard_MidnightLandingPage.lua
local RUNES_OF_POWER_SYSTEM_ID = 48
local RUNES_OF_POWER_TREE_ID = 1186

local Omnium = {}
SUI.Omnium = Omnium

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function GetSettings()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile.omnium
    end
    return nil
end

Omnium.GetSettings = GetSettings

---------------------------------------------------------------------------
-- Availability
---------------------------------------------------------------------------

--- Is the Omnium Folio available to this character?
-- Pre-Midnight clients have neither the constant nor the API, so both are guarded.
function Omnium:IsUnlocked()
    local expansionID = _G.LE_EXPANSION_MIDNIGHT
    if not expansionID then return false end

    local api = C_PlayerInfo and C_PlayerInfo.IsExpansionLandingPageUnlockedForPlayer
    if not api then return false end

    local ok, unlocked = pcall(api, expansionID)
    return ok and unlocked or false
end

---------------------------------------------------------------------------
-- Trait data
---------------------------------------------------------------------------

--- Config ID for the folio's trait tree, or nil when unavailable.
function Omnium:GetConfigID()
    if not (C_Traits and C_Traits.GetConfigIDBySystemID) then return nil end
    local ok, configID = pcall(C_Traits.GetConfigIDBySystemID, RUNES_OF_POWER_SYSTEM_ID)
    if not ok then return nil end
    return configID
end

--- Tree currency info for the folio.
-- @return quantity (unspent points), spent, traitCurrencyID
function Omnium:GetTreeCurrency()
    local configID = self:GetConfigID()
    if not configID then return nil end

    local excludeStagedChanges = false
    local ok, treeCurrencies = pcall(C_Traits.GetTreeCurrencyInfo, configID, RUNES_OF_POWER_TREE_ID, excludeStagedChanges)
    if not ok or not treeCurrencies or #treeCurrencies <= 0 then return nil end

    local info = treeCurrencies[1]
    if not info then return nil end

    return info.quantity, info.spent, info.traitCurrencyID
end

--- Unspent trait points in the folio (0 when unavailable).
function Omnium:GetUnspentPoints()
    local quantity = self:GetTreeCurrency()
    return quantity or 0
end

--- Currency name / icon / owned amount behind the folio's trait currency.
-- Mirrors TalentFrameUtil.GenerateTreeCurrencyDisplayCallback: the trait currency
-- maps to a real currency (Omnium) unless it carries an override icon.
-- @return name, icon, owned quantity
function Omnium:GetCurrencyInfo()
    local _, _, traitCurrencyID = self:GetTreeCurrency()
    if not traitCurrencyID or not C_Traits.GetTraitCurrencyInfo then return nil end

    local ok, _, _, currencyTypesID, overrideIcon = pcall(C_Traits.GetTraitCurrencyInfo, traitCurrencyID)
    if not ok then return nil end

    if currencyTypesID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local infoOk, currencyInfo = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyTypesID)
        if infoOk and currencyInfo then
            return currencyInfo.name, currencyInfo.iconFileID or overrideIcon, currencyInfo.quantity
        end
    end

    return nil, overrideIcon, nil
end

--- Can the player actually spend points right now?
-- Ported from CanPurchaseRuneOfPower in Blizzard_MidnightLandingPage.lua: having
-- unspent currency is not enough, an affordable and purchasable node must exist.
function Omnium:CanPurchase()
    local configID = self:GetConfigID()
    if not configID then return false end

    local unspent = self:GetUnspentPoints()
    if unspent == 0 then return false end

    local ok, nodeIDs = pcall(C_Traits.GetTreeNodes, RUNES_OF_POWER_TREE_ID)
    if not ok or not nodeIDs then return false end

    for _, nodeID in ipairs(nodeIDs) do
        local costOk, nodeCosts = pcall(C_Traits.GetNodeCost, configID, nodeID)
        if costOk and nodeCosts then
            local canAffordNode = (#nodeCosts == 0) or (unspent >= nodeCosts[1].amount)
            if canAffordNode then
                local infoOk, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if infoOk and nodeInfo and nodeInfo.entryIDs then
                    for _, entryID in ipairs(nodeInfo.entryIDs) do
                        local purchaseOk, canPurchase = pcall(C_Traits.CanPurchaseRank, configID, nodeID, entryID)
                        if purchaseOk and canPurchase then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

--- Open the folio (the Midnight expansion landing page).
function Omnium:Open()
    if InCombatLockdown() then return false end
    if not _G.ToggleExpansionLandingPage then return false end

    local page = _G.ExpansionLandingPage
    if page and page:IsShown() then return true end

    _G.ToggleExpansionLandingPage()
    return true
end

---------------------------------------------------------------------------
-- Unspent Omnium alert
--
-- Blizzard nudges with a HelpTip on the minimap button. We add an optional
-- SuaviUI glow on the same button (and an optional one-time chat notice), so
-- the reminder survives users who dismiss/disable Blizzard tutorials.
---------------------------------------------------------------------------
local alertState = {
    glow = nil,
    active = false,
    announced = false,
}

local function GetGlowColor()
    local settings = GetSettings()
    if settings and settings.alertUseClassColor then
        local _, class = UnitClass("player")
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then
            return color.r, color.g, color.b
        end
    end

    local c = settings and settings.alertColor or { 1, 0.82, 0, 1 }
    return c[1] or 1, c[2] or 0.82, c[3] or 0, c[4] or 1
end

local function GetGlow()
    local button = _G.ExpansionLandingPageMinimapButton
    if not button then return nil end

    if not alertState.glow then
        local glow = button:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Cooldown\\star4")
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", button, "CENTER", 0, 0)
        glow:Hide()

        local anim = glow:CreateAnimationGroup()
        anim:SetLooping("BOUNCE")
        local alpha = anim:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0.25)
        alpha:SetToAlpha(0.9)
        alpha:SetDuration(0.9)
        glow.pulse = anim

        alertState.glow = glow
    end

    return alertState.glow
end

local function HideGlow()
    if alertState.glow then
        if alertState.glow.pulse then alertState.glow.pulse:Stop() end
        alertState.glow:Hide()
    end
    alertState.active = false
end

local function ShowGlow()
    local glow = GetGlow()
    if not glow then return end

    local button = _G.ExpansionLandingPageMinimapButton
    local size = (button:GetWidth() or 32) * 1.6
    glow:SetSize(size, size)

    local r, g, b, a = GetGlowColor()
    glow:SetVertexColor(r, g, b, a or 1)

    glow:Show()
    if glow.pulse then glow.pulse:Play() end
    alertState.active = true
end

--- Re-evaluate the alert state and show/hide accordingly.
local function RefreshAlert()
    local settings = GetSettings()

    if not settings or not settings.alertEnabled or not Omnium:IsUnlocked() then
        HideGlow()
        return
    end

    -- The button is hidden (or parked on the hidden parent) when the user turns
    -- the minimap landing button off — no point glowing something invisible.
    local button = _G.ExpansionLandingPageMinimapButton
    if not button or not button:IsVisible() then
        HideGlow()
        return
    end

    if Omnium:CanPurchase() then
        if not alertState.active then
            ShowGlow()

            if settings.alertChatMessage and not alertState.announced then
                alertState.announced = true
                local name = Omnium:GetCurrencyInfo() or "Omnium"
                local points = Omnium:GetUnspentPoints()
                print(format("|cFF30D1FFSuaviUI:|r %s |cFFFFFFFF(%d)|r ready to spend in the Omnium Folio.", name, points))
            end
        end
    else
        HideGlow()
        alertState.announced = false
    end
end

Omnium.RefreshAlert = RefreshAlert

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Trait data is not reliably populated on the first frame after login.
        C_Timer.After(3, RefreshAlert)
    else
        RefreshAlert()
    end
end)

-- Clear the glow as soon as the folio is opened — the user is acting on it.
-- Blizzard fires this from MidnightLandingOverlayMixin:OnShow.
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("ExpansionLandingPage.ClearPulses", function()
        HideGlow()
    end, "SuaviUI_Omnium")
end

_G.SuaviUI_RefreshOmniumAlert = RefreshAlert
