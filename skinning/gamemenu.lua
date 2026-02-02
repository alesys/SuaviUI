local addonName, ns = ...

---------------------------------------------------------------------------
-- GAME MENU (ESC MENU) SKINNING + Suavi UI BUTTON
---------------------------------------------------------------------------

-- Static colors
local COLORS = {
    text = { 0.9, 0.9, 0.9, 1 },
}

local FONT_FLAGS = "OUTLINE"

-- Get game menu font size from settings
local function GetGameMenuFontSize()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    local settings = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general
    return settings and settings.gameMenuFontSize or 12
end

-- Get skinning colors (uses unified color system)
local function GetGameMenuColors()
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
    if not button or button.quiStyled then return end

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
    if button.Center then button.Center:SetAlpha(0) end
    if button.Middle then button.Middle:SetAlpha(0) end

    -- Hide highlight/pushed/normal/disabled textures
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end
    local pushed = button:GetPushedTexture()
    if pushed then pushed:SetAlpha(0) end
    local normal = button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    local disabled = button:GetDisabledTexture()
    if disabled then disabled:SetAlpha(0) end

    -- Style button text
    local text = button:GetFontString()
    if text then
        local SUI = _G.SuaviUI
        local fontPath = SUI and SUI.GetGlobalFont and SUI:GetGlobalFont() or STANDARD_TEXT_FONT
        local fontSize = GetGameMenuFontSize()
        text:SetFont(fontPath, fontSize, FONT_FLAGS)
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

    button.quiStyled = true
end

-- Update button colors (for live refresh)
local function UpdateButtonColors(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
    if not button or not button.suiBackdrop then return end

    local btnBgR = math.min(bgr + 0.07, 1)
    local btnBgG = math.min(bgg + 0.07, 1)
    local btnBgB = math.min(bgb + 0.07, 1)
    button.suiBackdrop:SetBackdropColor(btnBgR, btnBgG, btnBgB, 1)
    button.suiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
    button.suiSkinColor = { sr, sg, sb, sa }
end

-- Hide Blizzard decorative elements
local function HideBlizzardDecorations()
    if GameMenuFrame.Border then GameMenuFrame.Border:Hide() end
    if GameMenuFrame.Header then GameMenuFrame.Header:Hide() end
end

-- Main skinning function
local function SkinGameMenu()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    local settings = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general
    if not settings or not settings.skinGameMenu then return end

    if not GameMenuFrame then return end
    if GameMenuFrame.quiSkinned then return end

    -- Get colors based on setting
    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetGameMenuColors()

    -- Hide Blizzard decorations
    HideBlizzardDecorations()

    -- Create backdrop
    CreateQUIBackdrop(GameMenuFrame, sr, sg, sb, sa, bgr, bgg, bgb, bga)

    -- Adjust frame padding for cleaner look
    GameMenuFrame.topPadding = 15
    GameMenuFrame.bottomPadding = 15
    GameMenuFrame.leftPadding = 15
    GameMenuFrame.rightPadding = 15
    GameMenuFrame.spacing = 2

    -- Style all buttons in the pool
    if GameMenuFrame.buttonPool then
        for button in GameMenuFrame.buttonPool:EnumerateActive() do
            StyleButton(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
        end
    end

    GameMenuFrame:MarkDirty()
    GameMenuFrame.quiSkinned = true
end

-- Refresh colors on already-skinned game menu (for live preview)
local function RefreshGameMenuColors()
    if not GameMenuFrame or not GameMenuFrame.quiSkinned then return end

    -- Get colors based on setting
    local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetGameMenuColors()

    -- Update main frame backdrop
    if GameMenuFrame.suiBackdrop then
        GameMenuFrame.suiBackdrop:SetBackdropColor(bgr, bgg, bgb, bga)
        GameMenuFrame.suiBackdrop:SetBackdropBorderColor(sr, sg, sb, sa)
    end

    -- Update all buttons
    if GameMenuFrame.buttonPool then
        for button in GameMenuFrame.buttonPool:EnumerateActive() do
            UpdateButtonColors(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
        end
    end
end

-- Refresh font size on game menu buttons
local function RefreshGameMenuFontSize()
    if not GameMenuFrame then return end

    local fontSize = GetGameMenuFontSize()
    local SUI = _G.SuaviUI
    local fontPath = SUI and SUI.GetGlobalFont and SUI:GetGlobalFont() or STANDARD_TEXT_FONT

    if GameMenuFrame.buttonPool then
        for button in GameMenuFrame.buttonPool:EnumerateActive() do
            local text = button:GetFontString()
            if text then
                text:SetFont(fontPath, fontSize, FONT_FLAGS)
            end
        end
    end

    -- Mark dirty to recalculate layout if needed
    if GameMenuFrame.MarkDirty then
        GameMenuFrame:MarkDirty()
    end
end

-- Expose refresh functions globally
_G.SuaviUI_RefreshGameMenuColors = RefreshGameMenuColors
_G.SuaviUI_RefreshGameMenuFontSize = RefreshGameMenuFontSize

---------------------------------------------------------------------------
-- Suavi UI BUTTON INJECTION
---------------------------------------------------------------------------

-- Inject button on every InitButtons call (buttonPool gets reset each time)
local function InjectSuaviUIButton()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    local settings = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general
    if not settings or settings.addSuaviUIButton == false then return end

    if not GameMenuFrame or not GameMenuFrame.buttonPool then return end

    -- Find the Macros button to insert after
    local macrosIndex = nil
    for button in GameMenuFrame.buttonPool:EnumerateActive() do
        if button:GetText() == MACROS then
            macrosIndex = button.layoutIndex
            break
        end
    end

    if macrosIndex then
        -- Shift buttons after Macros down by 1
        for button in GameMenuFrame.buttonPool:EnumerateActive() do
            if button.layoutIndex and button.layoutIndex > macrosIndex then
                button.layoutIndex = button.layoutIndex + 1
            end
        end

        -- Add Suavi UI button
        local quiButton = GameMenuFrame:AddButton("Suavi UI", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            HideUIPanel(GameMenuFrame)
            local SUI = _G.SuaviUI
            if SUI and SUI.GUI then
                SUI.GUI:Show()
            end
        end)
        quiButton.layoutIndex = macrosIndex + 1
        GameMenuFrame:MarkDirty()
    end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

-- Hook into GameMenuFrame button initialization (with defensive check)
if GameMenuFrame and GameMenuFrame.InitButtons then
    hooksecurefunc(GameMenuFrame, "InitButtons", function()
        -- Inject Suavi UI button (always, regardless of skinning setting)
        InjectSuaviUIButton()

        -- Skin menu if enabled (defer to ensure buttons are ready)
        C_Timer.After(0, function()
            SkinGameMenu()

            -- Style any new buttons that were added
            if GameMenuFrame.quiSkinned and GameMenuFrame.buttonPool then
                local sr, sg, sb, sa, bgr, bgg, bgb, bga = GetGameMenuColors()

                for button in GameMenuFrame.buttonPool:EnumerateActive() do
                    if not button.quiStyled then
                        StyleButton(button, sr, sg, sb, sa, bgr, bgg, bgb, bga)
                    end
                end
            end
        end)
    end)
end







