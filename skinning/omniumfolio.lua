local addonName, ns = ...

---------------------------------------------------------------------------
-- OMNIUM FOLIO SKINNING
-- Skins Midnight's Omnium Folio (the Expansion Landing Page overlay that hosts
-- the Runes of Power tree).
--
-- Blizzard reference: Blizzard_ExpansionLandingPage/Blizzard_MidnightLandingPage.xml
--   ExpansionLandingPage.overlayFrame
--     .Background        (atlas talenttree-PowerSystem-background — the tree art)
--     .Border            (atlas ui-frame-midnight-border — the ornate frame)
--     .Header.Title      (FontString)
--     .CloseButton       (UIPanelCloseButton, from LandingPageExpansionOverlayTemplate)
--     .RunesOfPowerFrame.CurrencyDisplay
--
-- The tree art (.Background) is deliberately left alone: the talent nodes are
-- positioned over it and hiding it leaves them floating on nothing. We replace
-- the ornate .Border with the standard SuaviUI 1px backdrop instead.
---------------------------------------------------------------------------

local FONT_FLAGS = "OUTLINE"

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function IsSkinningEnabled()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    local settings = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.omnium
    if not settings then return false end
    return settings.skinFolio ~= false
end

local function GetFontPath()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    local settings = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general
    return (LSM and settings and LSM:Fetch("font", settings.font or "Suavi")) or STANDARD_TEXT_FONT
end

local function GetColors()
    local SUI = _G.SuaviUI
    local sr, sg, sb, sa = 0.2, 1.0, 0.6, 1
    local bgr, bgg, bgb, bga = 0.05, 0.05, 0.05, 0.95

    if SUI and SUI.GetSkinColor then
        sr, sg, sb, sa = SUI:GetSkinColor()
    end
    if SUI and SUI.GetSkinBgColor then
        bgr, bgg, bgb, bga = SUI:GetSkinBgColor()
    end

    return sr, sg, sb, sa, bgr, bgg, bgb, bga
end

-- The tree art fills the overlay edge to edge, so a backdrop anchored with
-- SetAllPoints would be completely hidden behind it. Anchor it slightly outside
-- instead (where Blizzard's ornate border used to sit) and keep it below the
-- overlay, so only the 1px ring shows.
local BACKDROP_INSET = 2

local function CreateQUIBackdrop(frame, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    if not frame.suiBackdrop then
        frame.suiBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.suiBackdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -BACKDROP_INSET, BACKDROP_INSET)
        frame.suiBackdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", BACKDROP_INSET, -BACKDROP_INSET)
        frame.suiBackdrop:EnableMouse(false)
    end

    frame.suiBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame.suiBackdrop:SetBackdropColor(bgr, bgg, bgb, bga)
    frame.suiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
end

---------------------------------------------------------------------------
-- Resolve the Midnight overlay
---------------------------------------------------------------------------

-- ExpansionLandingPage hosts one overlay per expansion; only the Midnight one
-- carries RunesOfPowerFrame, so that key doubles as the identity check.
local function GetFolioOverlay()
    local page = _G.ExpansionLandingPage
    if not page then return nil end

    local overlay = page.overlayFrame
    if not overlay and page.Overlay then
        overlay = page.Overlay.MidnightLandingOverlay
    end

    if overlay and overlay.RunesOfPowerFrame then
        return overlay
    end

    return nil
end

---------------------------------------------------------------------------
-- Skinning
---------------------------------------------------------------------------
local function SkinFolio()
    if not IsSkinningEnabled() then return end

    local overlay = GetFolioOverlay()
    if not overlay then return end

    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetColors()
    local fontPath = GetFontPath()

    -- Ornate frame out, SuaviUI backdrop in
    if overlay.Border then
        overlay.Border:SetAlpha(0)
    end
    CreateQUIBackdrop(overlay, sr, sg, sb, sa, bgr, bgg, bgb, bga)

    -- Behind the tree art, so the fill never covers the talent nodes
    if overlay.suiBackdrop then
        overlay.suiBackdrop:SetFrameLevel(math.max(overlay:GetFrameLevel() - 1, 0))
    end

    -- Header title
    if overlay.Header and overlay.Header.Title then
        local title = overlay.Header.Title
        local _, size = title:GetFont()
        local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
        if SUICore and SUICore.SafeSetFont then
            SUICore:SafeSetFont(title, fontPath, size or 20, FONT_FLAGS)
        else
            title:SetFont(fontPath, size or 20, FONT_FLAGS)
        end
        title:SetTextColor(sr, sg, sb, 1)
    end

    -- Currency display (the Omnium counter in the top right of the tree)
    local runesFrame = overlay.RunesOfPowerFrame
    if runesFrame and runesFrame.CurrencyDisplay then
        local display = runesFrame.CurrencyDisplay
        if display.Background then
            display.Background:Hide()
        end
        if display.Text then
            local _, size = display.Text:GetFont()
            local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
            if SUICore and SUICore.SafeSetFont then
                SUICore:SafeSetFont(display.Text, fontPath, size or 12, FONT_FLAGS)
            else
                display.Text:SetFont(fontPath, size or 12, FONT_FLAGS)
            end
        end
    end

    overlay.suiSkinned = true
end

--- Re-apply the skin (colors/font changed in the options).
local function RefreshFolioSkin()
    local overlay = GetFolioOverlay()
    if not overlay then return end

    if not IsSkinningEnabled() then
        -- Restore Blizzard's look without requiring a reload
        if overlay.Border then overlay.Border:SetAlpha(1) end
        if overlay.suiBackdrop then overlay.suiBackdrop:Hide() end
        overlay.suiSkinned = false
        return
    end

    if overlay.suiBackdrop then overlay.suiBackdrop:Show() end
    SkinFolio()
end

_G.SuaviUI_RefreshOmniumFolioSkin = RefreshFolioSkin

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
    if addon ~= "Blizzard_ExpansionLandingPage" then return end

    local page = _G.ExpansionLandingPage
    if page then
        -- The overlay is built lazily in RefreshExpansionOverlay, so skin on show
        -- as well as on every overlay swap.
        page:HookScript("OnShow", SkinFolio)

        if page.RefreshExpansionOverlay then
            hooksecurefunc(page, "RefreshExpansionOverlay", SkinFolio)
        end

        SkinFolio()
    end

    self:UnregisterEvent("ADDON_LOADED")
end)
