---------------------------------------------------------------------------
-- SuaviUI Bag Item Level Overlay + Square Icon Skin
-- Display item level on bag item buttons with toggle in General settings
-- Optionally applies a square icon skin (black bg + quality border)
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SUI = SuaviUI
local LSM = LibStub("LibSharedMedia-3.0", true)

---------------------------------------------------------------------------
-- Locals
---------------------------------------------------------------------------
local itemLevelOverlays = {}  -- Store overlays by frame
local skinnedButtons = {}     -- Track all square-skinned buttons
local isEnabled = false
local SUICore = nil

-- Configuration cache
local fontSize = 11
local fontName = "Suavi"
local fontOutline = "OUTLINE"
local textColor = { 1.0, 1.0, 1.0, 1.0 }
local useQualityColor = true
local skinBagIcons = false
local borderThickness = 1
local useQualityBorderColor = true
local borderColor = { 0.25, 0.25, 0.25, 0.8 }

-- Glow config cache
local showGlow = false
local glowUseQualityColor = true
local glowColor = { 1.0, 0.82, 0.0, 1.0 }
local glowSize = 1
local glowAlpha = 0.6  -- stored internally as 0.0-1.0 fraction

-- 8-direction offsets for the glow halo (cardinal + diagonal)
local GLOW_OFFSETS = {
    { 1,  0}, {-1,  0}, { 0,  1}, { 0, -1},  -- cardinal
    { 1,  1}, {-1,  1}, { 1, -1}, {-1, -1},  -- diagonal
}

local itemLevelGlowLayers = {}  -- [itemButton] = { fs, fs, ... } (8 glow FontStrings)

---------------------------------------------------------------------------
-- Glow Layer Management
---------------------------------------------------------------------------
local function UpdateGlowLayers(itemButton, itemLevel, tr, tg, tb)
    -- Ensure 8 glow FontStrings exist for this button
    if not itemLevelGlowLayers[itemButton] then
        local layers = {}
        for i = 1, 8 do
            -- ARTWORK layer renders behind the main OVERLAY text automatically
            local fs = itemButton:CreateFontString(nil, "ARTWORK")
            layers[i] = fs
        end
        itemLevelGlowLayers[itemButton] = layers
    end

    local layers = itemLevelGlowLayers[itemButton]
    local font = LSM and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    local outline = fontOutline or ""
    local gr, gg, gb

    if glowUseQualityColor then
        -- Use the same color as the main text
        gr, gg, gb = tr, tg, tb
    else
        gr, gg, gb = glowColor[1], glowColor[2], glowColor[3]
    end

    for i, fs in ipairs(layers) do
        local dx = GLOW_OFFSETS[i][1] * glowSize
        local dy = GLOW_OFFSETS[i][2] * glowSize
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", -2 + dx, 2 + dy)
        fs:SetFont(font, fontSize, outline)
        fs:SetText(itemLevel)
        fs:SetTextColor(gr, gg, gb, glowAlpha)
        fs:Show()
    end
end

local function HideGlowLayers(itemButton)
    local layers = itemLevelGlowLayers[itemButton]
    if layers then
        for _, fs in ipairs(layers) do
            fs:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Square Icon Skinning
---------------------------------------------------------------------------

-- Creates or updates the border frame on a button using current settings.
-- Called on first skin and whenever border thickness/color settings change.
local function UpdateBorderOnButton(btn)
    if not btn then return end
    local icon = btn.icon or btn.Icon
    local t = borderThickness or 1

    -- Create border frame if it doesn't exist yet
    if not btn._quiBorderFrame then
        local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        border:SetFrameLevel(btn:GetFrameLevel() + 10)
        border:EnableMouse(false)
        btn._quiBorderFrame = border
    end

    local border = btn._quiBorderFrame

    -- Update position (extends t pixels outside the icon edges)
    border:ClearAllPoints()
    if icon then
        border:SetPoint("TOPLEFT",     icon, "TOPLEFT",     -t,  t)
        border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT",  t, -t)
    else
        border:SetAllPoints(btn)
    end

    -- Update edge thickness
    border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = t,
    })

    -- Apply color: quality color if enabled and item has one, else custom
    local function ApplyBorderColor(r, g, b)
        if r and g and b and not (r == 1 and g == 1 and b == 1) then
            border:SetBackdropBorderColor(r, g, b, 1)
        else
            local c = borderColor
            border:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 0.8)
        end
    end

    if useQualityBorderColor and btn.IconBorder then
        local r, g, b = btn.IconBorder:GetVertexColor()
        ApplyBorderColor(r, g, b)
    else
        local c = borderColor
        border:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 0.8)
    end

    border:Show()
end

local function SkinItemButton(btn)
    if not btn or skinnedButtons[btn] then return end
    skinnedButtons[btn] = true

    local icon = btn.icon or btn.Icon

    -- Remove circular mask textures so icon renders square
    if icon and icon.GetMaskTexture and icon.RemoveMaskTexture then
        for i = 1, 10 do
            local mask = icon:GetMaskTexture(i)
            if mask then icon:RemoveMaskTexture(mask) end
        end
    end

    -- Crop icon texture to remove grey/rounded edges
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- Hide NormalTexture (Blizzard's button frame border art)
    local normalTex = btn:GetNormalTexture()
    if normalTex then normalTex:SetAlpha(0) end
    if btn.NormalTexture then btn.NormalTexture:SetAlpha(0) end

    -- Hide all non-icon region textures (empty slot graphic, sparkles, etc.)
    -- Store original alphas for clean reversal
    if not btn._suiOriginalRegionAlphas then
        btn._suiOriginalRegionAlphas = {}
        local n = select("#", btn:GetRegions())
        for i = 1, n do
            local region = select(i, btn:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                if region ~= icon then
                    btn._suiOriginalRegionAlphas[i] = region:GetAlpha()
                    region:SetAlpha(0)
                end
            end
        end
    end

    -- Black background texture at BACKGROUND layer (renders behind icon)
    if not btn._suiBagBlackBg then
        local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetColorTexture(0, 0, 0, 1)
        if icon then
            bg:SetAllPoints(icon)
        else
            bg:SetAllPoints(btn)
        end
        btn._suiBagBlackBg = bg
    end
    btn._suiBagBlackBg:Show()

    -- Create/update border with current thickness and color settings
    UpdateBorderOnButton(btn)

    -- Hook Blizzard's IconBorder to react to quality color changes (only once per button)
    if btn.IconBorder and not btn._suiBorderHooked then
        btn._suiBorderHooked = true
        hooksecurefunc(btn.IconBorder, "SetVertexColor", function(self, r, g, b)
            -- Only apply when quality color mode is active
            if btn._quiBorderFrame and useQualityBorderColor then
                if r == 1 and g == 1 and b == 1 then
                    local c = borderColor
                    btn._quiBorderFrame:SetBackdropBorderColor(c[1], c[2], c[3], c[4] or 0.8)
                else
                    btn._quiBorderFrame:SetBackdropBorderColor(r, g, b, 1)
                end
            end
        end)
        btn.IconBorder:SetAlpha(0)
    end
end

local function UnskinItemButton(btn)
    if not btn or not skinnedButtons[btn] then return end
    skinnedButtons[btn] = nil

    local icon = btn.icon or btn.Icon

    -- Restore icon texcoord
    if icon and icon.SetTexCoord then
        icon:SetTexCoord(0, 1, 0, 1)
    end

    -- Restore NormalTexture
    local normalTex = btn:GetNormalTexture()
    if normalTex then normalTex:SetAlpha(1) end
    if btn.NormalTexture then btn.NormalTexture:SetAlpha(1) end

    -- Restore original region alphas
    if btn._suiOriginalRegionAlphas then
        local regions = { btn:GetRegions() }
        for i, alpha in pairs(btn._suiOriginalRegionAlphas) do
            if regions[i] then regions[i]:SetAlpha(alpha) end
        end
        btn._suiOriginalRegionAlphas = nil
    end

    -- Hide black background
    if btn._suiBagBlackBg then btn._suiBagBlackBg:Hide() end

    -- Hide border frame
    if btn._quiBorderFrame then btn._quiBorderFrame:Hide() end

    -- Restore Blizzard's IconBorder
    if btn.IconBorder then btn.IconBorder:SetAlpha(1) end
end

-- Refreshes border appearance on all currently-skinned buttons.
-- Used when thickness or color settings change without toggling the skin off/on.
local function UpdateSkinSettings()
    for btn in pairs(skinnedButtons) do
        UpdateBorderOnButton(btn)
    end
end

local function ApplySkinToAll()
    -- Bags
    if ContainerFrameUtil_EnumerateContainerFrames then
        for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
            if frame.Items then
                for _, itemButton in ipairs(frame.Items) do
                    if skinBagIcons then
                        SkinItemButton(itemButton)
                    else
                        UnskinItemButton(itemButton)
                    end
                end
            end
        end
    end
    -- Traditional bank main slots
    for slot = 1, 28 do
        local btn = _G["BankFrameItem" .. slot]
        if btn then
            if skinBagIcons then SkinItemButton(btn) else UnskinItemButton(btn) end
        end
    end
    -- Bank bag slots
    for bag = 0, 6 do
        for slot = 1, 36 do
            local btn = _G["BankFrameBag" .. bag .. "Item" .. slot]
            if btn then
                if skinBagIcons then SkinItemButton(btn) else UnskinItemButton(btn) end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Item Level Display Helper
---------------------------------------------------------------------------
-- WoW returns invType as e.g. "INVTYPE_HEAD", "INVTYPE_CHEST", etc.
local EQUIPPABLE_SLOTS = {
    INVTYPE_HEAD        = true,
    INVTYPE_NECK        = true,
    INVTYPE_SHOULDER    = true,
    INVTYPE_BODY        = true,
    INVTYPE_CHEST       = true,
    INVTYPE_ROBE        = true,
    INVTYPE_WAIST       = true,
    INVTYPE_LEGS        = true,
    INVTYPE_FEET        = true,
    INVTYPE_WRIST       = true,
    INVTYPE_HAND        = true,
    INVTYPE_FINGER      = true,
    INVTYPE_TRINKET     = true,
    INVTYPE_CLOAK       = true,
    INVTYPE_WEAPON      = true,
    INVTYPE_SHIELD      = true,
    INVTYPE_2HWEAPON    = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND  = true,
    INVTYPE_HOLDABLE    = true,
    INVTYPE_RANGED      = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_THROWN      = true,
    INVTYPE_RELIC       = true,
}

local function GetItemLevelFromBag(bagID, slotID)
    -- Get item link first (most reliable for item level)
    local itemLink = C_Container.GetContainerItemLink(bagID, slotID)
    if not itemLink then return nil end

    local itemID = C_Container.GetContainerItemID(bagID, slotID)
    if not itemID then return nil end

    -- Only show item level on equippable items
    local _, _, _, _, _, _, _, _, invType = GetItemInfo(itemLink)
    if not invType or not EQUIPPABLE_SLOTS[invType] then
        return nil
    end

    -- GetDetailedItemLevelInfo gives the actual scaled/upgraded level from the link
    local actualLevel, isScaled, baseLevel = GetDetailedItemLevelInfo(itemLink)
    if actualLevel and actualLevel > 0 then
        return actualLevel
    end

    -- Fallback: GetItemInfo base level
    local _, _, _, ilvl = GetItemInfo(itemLink)
    if ilvl and ilvl > 0 then
        return ilvl
    end

    return nil
end

---------------------------------------------------------------------------
-- Create or Update Overlay on Item Button
---------------------------------------------------------------------------
local function CreateOrUpdateOverlay(itemButton)
    if not isEnabled then
        -- Hide overlay if feature is disabled
        if itemLevelOverlays[itemButton] then
            itemLevelOverlays[itemButton]:Hide()
        end
        HideGlowLayers(itemButton)
        return
    end

    -- Get bag and slot info
    local bagID = itemButton:GetBagID()
    local slotID = itemButton:GetID()

    if not bagID or not slotID then return end

    -- Get item level
    local itemLevel = GetItemLevelFromBag(bagID, slotID)
    if not itemLevel or itemLevel == 0 then
        if itemLevelOverlays[itemButton] then
            itemLevelOverlays[itemButton]:Hide()
        end
        HideGlowLayers(itemButton)
        return
    end

    -- Create overlay if it doesn't exist
    if not itemLevelOverlays[itemButton] then
        local overlay = itemButton:CreateFontString(nil, "OVERLAY")
        overlay:SetPoint("BOTTOMRIGHT", itemButton, "BOTTOMRIGHT", -2, 2)
        itemLevelOverlays[itemButton] = overlay
    end

    local overlay = itemLevelOverlays[itemButton]
    -- Apply font settings (pass empty string instead of nil for "None" outline)
    local font = LSM and LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
    local outline = fontOutline or ""
    overlay:SetFont(font, fontSize, outline)
    overlay:SetText(itemLevel)
    overlay:Show()

    -- Resolve the text color (shared with glow)
    local tr, tg, tb, ta = 1, 1, 1, 1
    local itemLink = C_Container.GetContainerItemLink(bagID, slotID)
    if itemLink then
        if useQualityColor then
            local _, _, quality = GetItemInfo(itemLink)
            if quality then
                tr, tg, tb = GetItemQualityColor(quality)
                ta = 1
            end
        else
            if textColor then
                tr, tg, tb, ta = textColor[1], textColor[2], textColor[3], textColor[4] or 1
            end
        end
        overlay:SetTextColor(tr, tg, tb, ta)
    else
        overlay:SetTextColor(1, 1, 1)
    end

    -- Glow layers (8 offset FontStrings at ARTWORK layer, behind main text)
    if showGlow then
        UpdateGlowLayers(itemButton, itemLevel, tr, tg, tb)
    else
        HideGlowLayers(itemButton)
    end
end

---------------------------------------------------------------------------
-- Hook into Container Frame Updates
---------------------------------------------------------------------------
local function HookContainerFrames()
    -- Hook the UpdateItems method from ContainerFrameMixin
    hooksecurefunc("ContainerFrame_UpdateAll", function()
        for i, frame in ContainerFrameUtil_EnumerateContainerFrames() do
            if frame.Items then
                for j, itemButton in ipairs(frame.Items) do
                    CreateOrUpdateOverlay(itemButton)
                    if skinBagIcons then SkinItemButton(itemButton) end
                end
            end
        end
    end)

    -- Also hook individual item updates
    if ContainerFrameItemButtonMixin then
        local originalUpdate = ContainerFrameItemButtonMixin.UpdateTooltip
        if originalUpdate then
            ContainerFrameItemButtonMixin.UpdateTooltip = function(self)
                originalUpdate(self)
                CreateOrUpdateOverlay(self)
            end
        end
    end

    -- Hook on bag updates
    local bagEventFrame = CreateFrame("Frame")
    bagEventFrame:RegisterEvent("BAG_UPDATE")
    bagEventFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
    bagEventFrame:SetScript("OnEvent", function(self, event)
        if event == "BAG_UPDATE" or event == "BAG_UPDATE_COOLDOWN" then
            C_Timer.After(0.05, function()
                ContainerFrame_UpdateAll()
            end)
        end
    end)

    -- Hook bank frame open to skin bank buttons
    local bankEventFrame = CreateFrame("Frame")
    bankEventFrame:RegisterEvent("BANKFRAME_OPENED")
    bankEventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    bankEventFrame:SetScript("OnEvent", function(self, event)
        if skinBagIcons then
            C_Timer.After(0.1, function()
                ApplySkinToAll()
            end)
        end
    end)
end

---------------------------------------------------------------------------
-- Settings Callback
---------------------------------------------------------------------------
local function UpdateSettings()
    if not SUICore or not SUICore.db then return end

    local enabled = SUICore.db.profile.general.showBagItemLevel
    local newFontSize = SUICore.db.profile.general.bagItemLevelFontSize or 11
    local newFontName = SUICore.db.profile.general.bagItemLevelFont or "Suavi"
    local newFontOutline = SUICore.db.profile.general.bagItemLevelFontOutline or "OUTLINE"
    local newTextColor = SUICore.db.profile.general.bagItemLevelTextColor or { 1.0, 1.0, 1.0, 1.0 }
    local newUseQualityColor = SUICore.db.profile.general.bagItemLevelUseQualityColor
    if newUseQualityColor == nil then newUseQualityColor = true end
    local newSkinBagIcons = SUICore.db.profile.general.skinBagIcons
    if newSkinBagIcons == nil then newSkinBagIcons = false end
    local newBorderThickness = SUICore.db.profile.general.bagIconBorderThickness or 1
    local newUseQualityBorderColor = SUICore.db.profile.general.bagIconUseQualityBorderColor
    if newUseQualityBorderColor == nil then newUseQualityBorderColor = true end
    local newBorderColor = SUICore.db.profile.general.bagIconBorderColor or { 0.25, 0.25, 0.25, 0.8 }

    -- Glow settings
    local newShowGlow = SUICore.db.profile.general.showBagItemLevelGlow
    if newShowGlow == nil then newShowGlow = false end
    local newGlowUseQualityColor = SUICore.db.profile.general.bagItemLevelGlowUseQualityColor
    if newGlowUseQualityColor == nil then newGlowUseQualityColor = true end
    local newGlowColor = SUICore.db.profile.general.bagItemLevelGlowColor or { 1.0, 0.82, 0.0, 1.0 }
    local newGlowSize = SUICore.db.profile.general.bagItemLevelGlowSize or 1
    local newGlowAlpha = (SUICore.db.profile.general.bagItemLevelGlowAlpha or 60) / 100

    -- Check if any settings changed
    local settingsChanged = (enabled ~= isEnabled) or (newFontSize ~= fontSize) or (newFontName ~= fontName) or
                           (newFontOutline ~= fontOutline) or (newUseQualityColor ~= useQualityColor) or
                           (newSkinBagIcons ~= skinBagIcons) or
                           (newShowGlow ~= showGlow) or (newGlowUseQualityColor ~= glowUseQualityColor) or
                           (newGlowSize ~= glowSize) or (newGlowAlpha ~= glowAlpha)

    -- Check text color change
    if not settingsChanged and newTextColor then
        if not textColor or newTextColor[1] ~= textColor[1] or newTextColor[2] ~= textColor[2] or
           newTextColor[3] ~= textColor[3] or newTextColor[4] ~= textColor[4] then
            settingsChanged = true
        end
    end
    -- Check glow color change
    if not settingsChanged and newGlowColor then
        if not glowColor or newGlowColor[1] ~= glowColor[1] or newGlowColor[2] ~= glowColor[2] or
           newGlowColor[3] ~= glowColor[3] then
            settingsChanged = true
        end
    end

    -- Check border-specific changes (only need border refresh, not full re-skin)
    local borderChanged = (newBorderThickness ~= borderThickness) or
                          (newUseQualityBorderColor ~= useQualityBorderColor)
    if not borderChanged and newBorderColor then
        if not borderColor or newBorderColor[1] ~= borderColor[1] or newBorderColor[2] ~= borderColor[2] or
           newBorderColor[3] ~= borderColor[3] or newBorderColor[4] ~= borderColor[4] then
            borderChanged = true
        end
    end

    -- Update all cached values
    isEnabled = enabled
    fontSize = newFontSize
    fontName = newFontName
    fontOutline = newFontOutline
    textColor = newTextColor
    useQualityColor = newUseQualityColor
    skinBagIcons = newSkinBagIcons
    borderThickness = newBorderThickness
    useQualityBorderColor = newUseQualityBorderColor
    borderColor = newBorderColor
    showGlow = newShowGlow
    glowUseQualityColor = newGlowUseQualityColor
    glowColor = newGlowColor
    glowSize = newGlowSize
    glowAlpha = newGlowAlpha

    -- Refresh overlays and skins when any setting changed
    if (settingsChanged or borderChanged) and ContainerFrameUtil_EnumerateContainerFrames then
        for i, frame in ContainerFrameUtil_EnumerateContainerFrames() do
            if frame.Items then
                for j, itemButton in ipairs(frame.Items) do
                    CreateOrUpdateOverlay(itemButton)
                end
            end
        end
        if skinBagIcons then
            if settingsChanged then
                ApplySkinToAll()  -- Full re-skin (handles enable/disable toggle too)
            else
                UpdateSkinSettings()  -- Just refresh borders on already-skinned buttons
            end
        end
    end
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------
local function OnAddonLoaded()
    -- Get SUICore reference
    SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if not SUICore then return end

    -- Set initial state
    UpdateSettings()

    -- Register for settings changes using proper Ace3 syntax
    if SUICore and SUICore.db and SUICore.db.RegisterCallback then
        -- Register callback for profile changes (event name, callback function)
        SUICore.db:RegisterCallback("OnProfileChanged", UpdateSettings)
    end

    -- Hook container frames
    HookContainerFrames()
end

-- Wait for UI to load
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == "SuaviUI" then
        OnAddonLoaded()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

---------------------------------------------------------------------------
-- Cleanup on Container Close
---------------------------------------------------------------------------
local function CleanupOverlays()
    for itemButton, overlay in pairs(itemLevelOverlays) do
        if overlay and overlay:GetParent() == nil then
            itemLevelOverlays[itemButton] = nil
        end
    end
end

local cleanupFrame = CreateFrame("Frame")
cleanupFrame:SetScript("OnUpdate", function()
    if GetTime() % 5 < 0.016 then  -- Every ~5 seconds
        CleanupOverlays()
    end
end)

-- Export for access by other modules if needed
_G.SuaviUI_BagItemLevel = {
    IsEnabled = function() return isEnabled end,
    Update = function() UpdateSettings() end,
}
