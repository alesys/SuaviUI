-- cooldown_icons.lua  
-- Square icon styling implementation for CooldownManagerCentered integration
-- Copied from CMC's proven StyledIcons module

local _, SUI = ...

-- Square mask texture path
local BASE_SQUARE_MASK = "Interface\\AddOns\\SuaviUI\\assets\\cooldown\\square_mask"

-- Style configuration per viewer type
local styleConfig = {
    Essential = {
        paddingFixup = 0,
        iconSizeKey = "cooldownManager_iconSize_Essential", 
        defaultSize = 64,
    },
    Utility = {
        paddingFixup = 0,
        iconSizeKey = "cooldownManager_iconSize_Utility",
        defaultSize = 64,
    },
    BuffIcons = {
        paddingFixup = 0,
        iconSizeKey = "cooldownManager_iconSize_BuffIcons",
        defaultSize = 32,
    },
}

local StyledIcons = {}

-- Get icon size for a specific viewer
local function GetViewerIconSize(viewerSettingName)
    local config = styleConfig[viewerSettingName]
    if not config then
        return 64
    end
    
    local profile = SUI and SUI.SUICore and SUI.SUICore.db and SUI.SUICore.db.profile
    if not profile then
        return config.defaultSize
    end
    
    return profile.cooldownManager and profile.cooldownManager[config.iconSizeKey] or config.defaultSize
end

-- Get setting value from profile
local function GetSetting(key, default)
    local profile = SUI and SUI.SUICore and SUI.SUICore.db and SUI.SUICore.db.profile
    if not profile or not profile.cooldownManager then
        return default
    end
    return profile.cooldownManager[key] or default
end

-- Apply square styling to an icon button
function StyledIcons.ApplySquareStyle(button, viewerSettingName)
    if not button or not viewerSettingName then
        return
    end
    
    local config = styleConfig[viewerSettingName]
    if not config then
        return
    end

    -- Check if square styling is enabled for this viewer
    local squareKey = "cooldownManager_squareIcons_" .. viewerSettingName
    if not GetSetting(squareKey, false) then
        return
    end

    local width = GetViewerIconSize(viewerSettingName)
    local borderKey = "cooldownManager_squareIconsBorder_" .. viewerSettingName
    local borderThickness = GetSetting(borderKey, 1)

    button:SetSize(width, width)

    -- Apply square styling to icon texture
    if button.Icon then
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", -config.paddingFixup / 2, config.paddingFixup / 2)
        button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", config.paddingFixup / 2, -config.paddingFixup / 2)

        -- Calculate zoom-based texture coordinates
        local zoomKey = "cooldownManager_squareIconsZoom_" .. viewerSettingName
        local zoom = GetSetting(zoomKey, 0)
        local crop = zoom * 0.5
        if button.Icon.SetTexCoord then
            button.Icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
        end
    end

    -- Apply square mask to cooldown swipe
    for i = 1, select("#", button:GetChildren()) do
        local texture = select(i, button:GetChildren())
        if texture and texture.SetSwipeTexture then
            texture:SetSwipeTexture(BASE_SQUARE_MASK)
            texture:ClearAllPoints()
            texture:SetPoint(
                "TOPLEFT",
                button,
                "TOPLEFT",
                -config.paddingFixup / 2 + borderThickness,
                config.paddingFixup / 2 - borderThickness
            )
            texture:SetPoint(
                "BOTTOMRIGHT",
                button,
                "BOTTOMRIGHT",
                config.paddingFixup / 2 - borderThickness,
                -config.paddingFixup / 2 + borderThickness
            )
        end
    end

    -- Create inset black border
    if not button.suiSquareBorder then
        button.suiSquareBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.suiSquareBorder:SetFrameLevel(button:GetFrameLevel() + 1)
    end
    button.suiSquareBorder:ClearAllPoints()
    button.suiSquareBorder:SetPoint("TOPLEFT", button, "TOPLEFT", -config.paddingFixup / 2, config.paddingFixup / 2)
    button.suiSquareBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", config.paddingFixup / 2, -config.paddingFixup / 2)
    button.suiSquareBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = borderThickness,
    })
    button.suiSquareBorder:SetBackdropBorderColor(0, 0, 0, 1)
    button.suiSquareBorder:Show()

    button.suiSquareStyled = true
end

-- Remove square styling from an icon button
function StyledIcons.RemoveSquareStyle(button)
    if not button then
        return
    end
    
    -- Remove square border
    if button.suiSquareBorder then
        button.suiSquareBorder:Hide()
        button.suiSquareBorder = nil
    end
    
    -- Reset icon texture coordinates to default circular
    if button.Icon and button.Icon.SetTexCoord then
        button.Icon:SetTexCoord(0, 1, 0, 1)
    end
    
    -- Reset cooldown swipe texture to default circular
    for i = 1, select("#", button:GetChildren()) do
        local texture = select(i, button:GetChildren())
        if texture and texture.SetSwipeTexture then
            texture:SetSwipeTexture("")  -- Reset to default
        end
    end
    
    button.suiSquareStyled = false
end

-- Apply or remove square styling based on settings
function StyledIcons.UpdateIconStyle(button, viewerSettingName)
    if not button or not viewerSettingName then
        return
    end
    
    local squareKey = "cooldownManager_squareIcons_" .. viewerSettingName
    local isEnabled = GetSetting(squareKey, false)
    
    if isEnabled then
        StyledIcons.ApplySquareStyle(button, viewerSettingName)
    else
        StyledIcons.RemoveSquareStyle(button)
    end
end

-- Refresh all icons for a specific viewer
function StyledIcons.RefreshViewerIcons(viewerName, viewerSettingName)
    local viewer = _G[viewerName]
    if not viewer then
        return
    end
    
    -- Apply styling to all child frames
    for i = 1, viewer:GetNumChildren() do
        local child = select(i, viewer:GetChildren())
        if child and child.Icon then
            StyledIcons.UpdateIconStyle(child, viewerSettingName)
        end
    end
end

-- Refresh all icons across all viewers  
function StyledIcons.RefreshAllIcons()
    local viewers = {
        {"EssentialCooldownViewer", "Essential"},
        {"UtilityCooldownViewer", "Utility"},
        {"BuffIconCooldownViewer", "BuffIcons"},
    }
    
    for _, viewerInfo in ipairs(viewers) do
        StyledIcons.RefreshViewerIcons(viewerInfo[1], viewerInfo[2])
    end
end

-- Export the module
SUI.StyledIcons = StyledIcons