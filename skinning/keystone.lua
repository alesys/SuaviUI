local addonName, ns = ...

---------------------------------------------------------------------------
-- KEYSTONE FRAME SKINNING
---------------------------------------------------------------------------

-- Static colors (text only - bg comes from SUI:GetSkinBgColor())
local COLORS = {
    text = { 0.9, 0.9, 0.9, 1 },
    textMuted = { 0.6, 0.6, 0.6, 1 },
}

local FONT_FLAGS = "OUTLINE"

-- Create a styled backdrop for frames
local function CreateQUIBackdrop(frame, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    if not frame.suiBackdrop then
        frame.suiBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.suiBackdrop:SetAllPoints()
        frame.suiBackdrop:SetFrameLevel(frame:GetFrameLevel())
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

-- Style a button with SUI theme
local function StyleButton(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    if not button then return end

    if not button.suiBackdrop then
        button.suiBackdrop = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.suiBackdrop:SetAllPoints()
        button.suiBackdrop:SetFrameLevel(button:GetFrameLevel())
        button.suiBackdrop:EnableMouse(false)
    end

    button.suiBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    -- Button bg slightly lighter than main bg
    local btnBgR = math.min(bgr + 0.07, 1)
    local btnBgG = math.min(bgg + 0.07, 1)
    local btnBgB = math.min(bgb + 0.07, 1)
    button.suiBackdrop:SetBackdropColor(btnBgR, btnBgG, btnBgB, 1)
    button.suiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)

    -- Hide default textures
    if button.Left then button.Left:SetAlpha(0) end
    if button.Right then button.Right:SetAlpha(0) end
    if button.Middle then button.Middle:SetAlpha(0) end
    if button.LeftSeparator then button.LeftSeparator:SetAlpha(0) end
    if button.RightSeparator then button.RightSeparator:SetAlpha(0) end

    -- Hide highlight/pushed textures (removes red hover tint)
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end
    local pushed = button:GetPushedTexture()
    if pushed then pushed:SetAlpha(0) end

    -- Style button text
    local text = button:GetFontString()
    if text then
        text:SetFont(STANDARD_TEXT_FONT, 12, FONT_FLAGS)
        text:SetTextColor(unpack(COLORS.text))
    end

    -- Store skin color for hover effects
    button.suiSkinColor = { sr, sg, sb, sa }

    -- Hover effect (brighten border)
    button:HookScript("OnEnter", function(self)
        if self.suiBackdrop and self.suiSkinColor then
            local r, g, b, a = unpack(self.suiSkinColor)
            self.suiBackdrop:SetBackdropBorderColor(math.min(r * 1.3, 1), math.min(g * 1.3, 1), math.min(b * 1.3, 1), a)
        end
    end)
    button:HookScript("OnLeave", function(self)
        if self.suiBackdrop and self.suiSkinColor then
            self.suiBackdrop:SetBackdropBorderColor(unpack(self.suiSkinColor))
        end
    end)
end

-- Style the close button
local function StyleCloseButton(button)
    if not button then return end
    if button.Border then button.Border:SetAlpha(0) end
end

-- Style the keystone slot
local function StyleKeystoneSlot(slot, sr, sg, sb, sa)
    if not slot then return end

    if not slot.quiBorder then
        slot.quiBorder = CreateFrame("Frame", nil, slot, "BackdropTemplate")
        slot.quiBorder:SetPoint("TOPLEFT", -4, 4)
        slot.quiBorder:SetPoint("BOTTOMRIGHT", 4, -4)
        slot.quiBorder:SetFrameLevel(slot:GetFrameLevel() - 1)
        slot.quiBorder:EnableMouse(false)
        slot.quiBorder:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        slot.quiBorder:SetBackdropColor(0, 0, 0, 0.5)
        slot.quiBorder:SetBackdropBorderColor(sr, sg, sb, sa)
    end
end

-- Hide Blizzard decorative elements
local function HideBlizzardDecorations(f)
    local region = f:GetRegions()
    if region then region:SetAlpha(0) end
    if f.InstructionBackground then f.InstructionBackground:SetAlpha(0) end
    if f.KeystoneSlotGlow then f.KeystoneSlotGlow:Hide() end
    if f.SlotBG then f.SlotBG:Hide() end
    if f.KeystoneFrame then f.KeystoneFrame:Hide() end
    if f.Divider then f.Divider:Hide() end
end

-- Main skinning function
local function SkinKeystoneFrame()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    local settings = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general
    if not settings or not settings.skinKeystoneFrame then return end

    local keystoneFrame = _G.ChallengesKeystoneFrame
    if not keystoneFrame or keystoneFrame.quiSkinned then return end

    -- Get skin colors from SUI system
    local SUI = _G.SuaviUI
    local sr, sg, sb, sa
    local bgr, bgg, bgb, bga
    if SUI and SUI.GetSkinColor then
        sr, sg, sb, sa = SUI:GetSkinColor()
    else
        sr, sg, sb, sa = 0.2, 1.0, 0.6, 1  -- Fallback mint
    end
    if SUI and SUI.GetSkinBgColor then
        bgr, bgg, bgb, bga = SUI:GetSkinBgColor()
    else
        bgr, bgg, bgb, bga = 0.05, 0.05, 0.05, 0.95  -- Fallback dark
    end

    -- Create backdrop
    CreateQUIBackdrop(keystoneFrame, sr, sg, sb, sa, bgr, bgg, bgb, bga)

    -- Hide Blizzard decorations via hooks
    hooksecurefunc(keystoneFrame, "Reset", HideBlizzardDecorations)
    keystoneFrame:HookScript("OnShow", HideBlizzardDecorations)

    -- Style fonts
    if keystoneFrame.DungeonName then
        keystoneFrame.DungeonName:SetFont(STANDARD_TEXT_FONT, 22, FONT_FLAGS)
        keystoneFrame.DungeonName:SetTextColor(unpack(COLORS.text))
    end

    if keystoneFrame.TimeLimit then
        keystoneFrame.TimeLimit:SetFont(STANDARD_TEXT_FONT, 16, FONT_FLAGS)
        keystoneFrame.TimeLimit:SetTextColor(unpack(COLORS.textMuted))
    end

    if keystoneFrame.Instructions then
        keystoneFrame.Instructions:SetFont(STANDARD_TEXT_FONT, 11, FONT_FLAGS)
        keystoneFrame.Instructions:SetTextColor(unpack(COLORS.textMuted))
    end

    -- Style buttons
    StyleButton(keystoneFrame.StartButton, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    StyleCloseButton(keystoneFrame.CloseButton)

    -- Style keystone slot
    StyleKeystoneSlot(keystoneFrame.KeystoneSlot, sr, sg, sb, sa)

    -- Store skin color for affix hook
    keystoneFrame.suiSkinColor = { sr, sg, sb, sa }

    -- Style affix icons when keystone is slotted
    hooksecurefunc(keystoneFrame, "OnKeystoneSlotted", function(f)
        local r, g, b, a = unpack(f.suiSkinColor or { 0.2, 1.0, 0.6, 1 })
        for i = 1, 4 do
            local affix = f["Affix" .. i]
            if affix and affix.Portrait then
                if not affix.quiBorder then
                    affix.quiBorder = affix:CreateTexture(nil, "OVERLAY")
                    affix.quiBorder:SetPoint("TOPLEFT", affix.Portrait, -1, 1)
                    affix.quiBorder:SetPoint("BOTTOMRIGHT", affix.Portrait, 1, -1)
                    affix.quiBorder:SetColorTexture(r, g, b, a)
                    affix.quiBorder:SetDrawLayer("OVERLAY", -1)
                end
            end
        end
    end)

    keystoneFrame.quiSkinned = true
end

-- Refresh colors on already-skinned keystone frame (for live preview)
local function RefreshKeystoneColors()
    local keystoneFrame = _G.ChallengesKeystoneFrame
    if not keystoneFrame or not keystoneFrame.quiSkinned then return end

    -- Get current colors
    local SUI = _G.SuaviUI
    local sr, sg, sb, sa = 0.2, 1.0, 0.6, 1
    local bgr, bgg, bgb, bga = 0.05, 0.05, 0.05, 0.95

    if SUI and SUI.GetSkinColor then
        sr, sg, sb, sa = SUI:GetSkinColor()
    end
    if SUI and SUI.GetSkinBgColor then
        bgr, bgg, bgb, bga = SUI:GetSkinBgColor()
    end

    -- Update main frame backdrop
    if keystoneFrame.suiBackdrop then
        keystoneFrame.suiBackdrop:SetBackdropColor(bgr, bgg, bgb, bga)
        keystoneFrame.suiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
    end

    -- Update button backdrop
    if keystoneFrame.StartButton and keystoneFrame.StartButton.suiBackdrop then
        local btnBgR = math.min(bgr + 0.07, 1)
        local btnBgG = math.min(bgg + 0.07, 1)
        local btnBgB = math.min(bgb + 0.07, 1)
        keystoneFrame.StartButton.suiBackdrop:SetBackdropColor(btnBgR, btnBgG, btnBgB, 1)
        keystoneFrame.StartButton.suiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
        keystoneFrame.StartButton.suiSkinColor = { sr, sg, sb, sa }
    end

    -- Update keystone slot border
    if keystoneFrame.KeystoneSlot and keystoneFrame.KeystoneSlot.quiBorder then
        keystoneFrame.KeystoneSlot.quiBorder:SetBackdropBorderColor(sr, sg, sb, sa)
    end

    -- Update affix borders
    for i = 1, 4 do
        local affix = keystoneFrame["Affix" .. i]
        if affix and affix.quiBorder then
            affix.quiBorder:SetColorTexture(sr, sg, sb, sa)
        end
    end

    -- Update stored color for future affix borders
    keystoneFrame.quiSkinned = true
    keystoneFrame.suiSkinColor = { sr, sg, sb, sa }
end

-- Expose refresh function globally
_G.SuaviUI_RefreshKeystoneColors = RefreshKeystoneColors

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_ChallengesUI" then
        if ChallengesKeystoneFrame then
            SkinKeystoneFrame()
        end
        self:UnregisterEvent("ADDON_LOADED")
    end
end)






