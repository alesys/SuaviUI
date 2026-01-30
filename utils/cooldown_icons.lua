-- cooldown_icons.lua
-- Square icon styling for Blizzard Cooldown Viewers
-- Properly ported from CooldownManagerCentered/modules/styled.lua

local _, ns = ...

local StyledIcons = {}
-- Export to both the addon namespace and the global SuaviUI table
ns.StyledIcons = StyledIcons
SuaviUI.StyledIcons = StyledIcons

local isModuleStyledEnabled = false
local areHooksInitialized = false

local BASE_SQUARE_MASK = "Interface\\AddOns\\SuaviUI\\assets\\cooldown\\square_mask"

local viewersSettingKey = {
    EssentialCooldownViewer = "Essential",
    UtilityCooldownViewer = "Utility",
    BuffIconCooldownViewer = "BuffIcons",
}

local normalizedSizeConfig = {
    Utility = { width = 50, height = 50 },
}

local originalSizesConfig = {
    Essential = { width = 50, height = 50 },
    Utility = { width = 30, height = 30 },
    BuffIcons = { width = 40, height = 40 },
}

-- Helper to get SUICore (matches pattern from cooldownmanager.lua)
local function GetSUICore()
    return (ns and ns.SUICore) or (_G.SuaviUI and _G.SuaviUI.SUICore) or _G.SUICore
end

-- Helper to get profile
local function GetProfile()
    local core = GetSUICore()
    return core and core.db and core.db.profile
end

local function IsAnyStyledFeatureEnabled()
    local profile = GetProfile()
    if not profile then
        return false
    end
    for _, viewerSettingName in pairs(viewersSettingKey) do
        local squareKey = "cooldownManager_squareIcons_" .. viewerSettingName
        if profile[squareKey] then
            return true
        end
    end
    if profile.cooldownManager_normalizeUtilitySize then
        return true
    end
    return false
end

local function GetViewerIconSize(viewerSettingName)
    local profile = GetProfile()
    if profile and profile.cooldownManager_normalizeUtilitySize and viewerSettingName == "Utility" then
        local config = normalizedSizeConfig[viewerSettingName]
        if config then
            return config.width, config.height
        end
    end
    local data = originalSizesConfig[viewerSettingName]
    return data.width, data.height
end

local styleConfig = {
    Essential = {
        paddingFixup = 0,
    },
    Utility = {
        paddingFixup = 0,
    },
    BuffIcons = {
        paddingFixup = 0,
    },
}

local function ApplySquareStyle(button, viewerSettingName)
    local profile = GetProfile()
    local config = styleConfig[viewerSettingName]
    if not config or not profile then
        return
    end

    local width = GetViewerIconSize(viewerSettingName)
    local borderKey = "cooldownManager_squareIconsBorder_" .. viewerSettingName
    local borderThickness = profile[borderKey] or 1

    button:SetSize(width, width)

    if button.Icon then
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", -config.paddingFixup / 2, config.paddingFixup / 2)
        button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", config.paddingFixup / 2, -config.paddingFixup / 2)

        -- Calculate zoom-based texture coordinates
        local zoomKey = "cooldownManager_squareIconsZoom_" .. viewerSettingName
        local zoom = profile[zoomKey] or 0
        local crop = zoom * 0.5
        if button.Icon.SetTexCoord then
            button.Icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
        end
    end

    -- Update swipe texture for cooldown children
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

    -- Update textures
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local texture = region:GetTexture()
            local atlas = region:GetAtlas()

            if (issecretvalue and not issecretvalue(texture) or not issecretvalue) and texture == 6707800 then
                region:SetTexture(BASE_SQUARE_MASK)
                region.__sui_set6707800 = true
            elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(0)
            end
        end
    end

    -- Create/update inset black border
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

local function RestoreOriginalStyle(button, viewerSettingName)
    if not button.suiSquareStyled then
        return
    end

    local width, height = GetViewerIconSize(viewerSettingName)
    button:SetSize(width, height)

    if button.Icon then
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.Icon:SetSize(width, height)
        -- Reset texture coordinates
        if button.Icon.SetTexCoord then
            button.Icon:SetTexCoord(0, 1, 0, 1)
        end
    end

    for i = 1, select("#", button:GetChildren()) do
        local child = select(i, button:GetChildren())
        if child and child.SetSwipeTexture then
            child:SetSwipeTexture(6707800)
            child:ClearAllPoints()
            child:SetPoint("CENTER", button, "CENTER", 0, 0)
            child:SetSize(width, height)
            break
        end
    end

    -- Restore hidden overlay textures
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local atlas = region:GetAtlas()
            if region.__sui_set6707800 then
                region:SetTexture(6707800)
                region.__sui_set6707800 = nil
            elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(1)
            end
        end
    end

    if button.suiSquareBorder then
        button.suiSquareBorder:Hide()
    end

    button.suiSquareStyled = false
end

-- Process all children of a viewer
local function ProcessViewer(viewer, viewerSettingName, applyStyle)
    if not viewer then
        return
    end

    local children = { viewer:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon then -- Only process icon-like children
            if applyStyle then
                ApplySquareStyle(child, viewerSettingName)
            else
                RestoreOriginalStyle(child, viewerSettingName)
            end

            -- Hook pandemic alerts
            if child.TriggerPandemicAlert and not child._suiStyleHooked then
                child._suiStyleHooked = true
                hooksecurefunc(child, "TriggerPandemicAlert", function()
                    if child.PandemicIcon then
                        if applyStyle then
                            child.PandemicIcon:SetScale(1.38)
                        else
                            child.PandemicIcon:SetScale(1.0)
                        end
                    end
                    C_Timer.After(0, function()
                        if child.PandemicIcon then
                            if applyStyle then
                                child.PandemicIcon:SetScale(1.38)
                            else
                                child.PandemicIcon:SetScale(1.0)
                            end
                        end
                    end)
                end)
            end

            -- Scale debuff border
            if child.DebuffBorder then
                if applyStyle then
                    child.DebuffBorder:SetScale(1.7)
                else
                    child.DebuffBorder:SetScale(1.0)
                end
            end
        end
    end
end

local function GetSettingKey(viewerSettingName)
    return "cooldownManager_squareIcons_" .. viewerSettingName
end

local function IsSquareIconsEnabled(viewerSettingName)
    local profile = GetProfile()
    if not profile then
        return false
    end
    return profile[GetSettingKey(viewerSettingName)] or false
end

-- Public function for external callers (cooldownmanager.lua)
function StyledIcons.UpdateIconStyle(icon, viewerSettingName)
    if not icon or not viewerSettingName then
        return
    end
    if IsSquareIconsEnabled(viewerSettingName) then
        ApplySquareStyle(icon, viewerSettingName)
    else
        RestoreOriginalStyle(icon, viewerSettingName)
    end
end

function StyledIcons:RefreshViewer(viewerName)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then
        return
    end

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    local enabled = IsSquareIconsEnabled(settingName)
    ProcessViewer(viewerFrame, settingName, enabled)
end

function StyledIcons:RefreshAll()
    for viewerName, settingName in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local enabled = IsSquareIconsEnabled(settingName)
            ProcessViewer(viewerFrame, settingName, enabled)
        end
    end
end

local function IsNormalizedSizeEnabled()
    local profile = GetProfile()
    return profile and profile.cooldownManager_normalizeUtilitySize or false
end

local function ApplyNormalizedSizeToButton(button, viewerSettingName)
    local config = normalizedSizeConfig[viewerSettingName]
    if not config then
        return
    end

    button:SetSize(config.width, config.height)

    for i = 1, select("#", button:GetRegions()) do
        local texture = select(i, button:GetRegions())
        if texture.GetAtlas and texture:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", button, "CENTER", 0, 0)
            texture:SetSize(config.width * 1.36, config.height * 1.36)
        end
    end

    if button.Icon then
        local padding = button.suiSquareStyled and 4 or 0
        button.Icon:SetSize(config.width - padding, config.height - padding)
    end
end

local function RestoreOriginalSizeToButton(button, viewerSettingName)
    local config = originalSizesConfig[viewerSettingName]
    if not config then
        return
    end

    button:SetSize(config.width, config.height)
    for i = 1, select("#", button:GetRegions()) do
        local texture = select(i, button:GetRegions())
        if texture.GetAtlas and texture:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", button, "CENTER", 0, 0)
            texture:SetSize(config.width * 1.36, config.height * 1.36)
        end
    end

    if button.Icon then
        local padding = button.suiSquareStyled and 4 or 0
        button.Icon:SetSize(config.width - padding, config.height - padding)
    end
end

function StyledIcons:Shutdown()
    isModuleStyledEnabled = false

    for viewerName, settingName in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local children = { viewerFrame:GetChildren() }
            for _, child in ipairs(children) do
                if child.Icon then
                    RestoreOriginalStyle(child, settingName)
                    RestoreOriginalSizeToButton(child, settingName)
                end
            end
        end
    end
end

function StyledIcons:Enable()
    if isModuleStyledEnabled then
        return
    end

    isModuleStyledEnabled = true

    if not areHooksInitialized then
        areHooksInitialized = true

        for viewerName, _ in pairs(viewersSettingKey) do
            local viewerFrame = _G[viewerName]
            if viewerFrame then
                hooksecurefunc(viewerFrame, "RefreshLayout", function()
                    if not isModuleStyledEnabled then
                        return
                    end
                    -- Wrap in pcall to prevent affecting Blizzard's Edit Mode flow
                    -- which can trigger EncounterWarnings bugs
                    pcall(function()
                        StyledIcons:RefreshViewer(viewerName)
                        if viewerName == "UtilityCooldownViewer" then
                            StyledIcons:ApplyNormalizedSize()
                        end
                    end)
                end)
            end
        end
    end

    self:RefreshAll()
    self:ApplyNormalizedSize()
end

function StyledIcons:Disable()
    if not isModuleStyledEnabled then
        return
    end
    self:Shutdown()
end

function StyledIcons:Initialize()
    if not IsAnyStyledFeatureEnabled() then
        return
    end
    self:Enable()
end

function StyledIcons:OnSettingChanged()
    local shouldBeEnabled = IsAnyStyledFeatureEnabled()

    if shouldBeEnabled and not isModuleStyledEnabled then
        self:Enable()
    elseif not shouldBeEnabled and isModuleStyledEnabled then
        self:Disable()
    elseif isModuleStyledEnabled then
        self:RefreshAll()
        self:ApplyNormalizedSize()
    end

    -- Trigger a refresh of the cooldown manager if available
    if ns.CooldownManager and ns.CooldownManager.ForceRefreshAll then
        ns.CooldownManager.ForceRefreshAll()
    end
end

function StyledIcons:ApplyNormalizedSize()
    local viewerFrame = _G["UtilityCooldownViewer"]
    if not viewerFrame then
        return
    end

    local enabled = IsNormalizedSizeEnabled()

    local children = { viewerFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child.Icon then
            if enabled then
                ApplyNormalizedSizeToButton(child, "Utility")
            else
                RestoreOriginalSizeToButton(child, "Utility")
            end
        end
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================
-- We need to initialize after the cooldown viewer frames exist.
-- Blizzard_CooldownManager creates them, so we wait for that addon.

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local hasInitialized = false

local function TryInitialize()
    if hasInitialized then
        return
    end
    
    -- Check if viewers exist before initializing
    if _G["EssentialCooldownViewer"] or _G["UtilityCooldownViewer"] or _G["BuffIconCooldownViewer"] then
        hasInitialized = true
        -- Delay slightly to ensure everything is fully loaded
        C_Timer.After(0.2, function()
            StyledIcons:Initialize()
        end)
    end
end

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_CooldownManager" then
            C_Timer.After(0.1, TryInitialize)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Also try on PLAYER_ENTERING_WORLD in case addon was already loaded
        C_Timer.After(0.5, TryInitialize)
    end
end)

-- If Blizzard_CooldownManager is already loaded (e.g., /reload), try immediately
if C_AddOns.IsAddOnLoaded("Blizzard_CooldownManager") then
    C_Timer.After(0.1, TryInitialize)
end

-- ============================================================================
-- DEBUG COMMANDS
-- ============================================================================
SLASH_SUISTYLEDICONS1 = "/suistyledicons"
SlashCmdList.SUISTYLEDICONS = function()
    print("|cFF00FF00[SuaviUI StyledIcons Debug]|r")
    print("  Module Enabled:", isModuleStyledEnabled and "YES" or "NO")
    print("  Hooks Initialized:", areHooksInitialized and "YES" or "NO")
    print("  hasInitialized:", hasInitialized and "YES" or "NO")
    
    local core = GetSUICore()
    print("  SUICore found:", core and "YES" or "NO")
    if core then
        print("    via:", (ns and ns.SUICore) and "ns.SUICore" or (_G.SuaviUI and _G.SuaviUI.SUICore) and "_G.SuaviUI.SUICore" or "_G.SUICore")
        print("    db exists:", core.db and "YES" or "NO")
        print("    profile exists:", (core.db and core.db.profile) and "YES" or "NO")
    end
    
    local profile = GetProfile()
    print("  Profile exists:", profile and "YES" or "NO")
    
    if profile then
        for viewerName, settingName in pairs(viewersSettingKey) do
            local key = "cooldownManager_squareIcons_" .. settingName
            print("    " .. key .. ":", profile[key] and "ON" or "OFF")
        end
    end
    
    print("  Viewers:")
    for viewerName, _ in pairs(viewersSettingKey) do
        local f = _G[viewerName]
        if f then
            local count = 0
            for _, c in ipairs({f:GetChildren()}) do
                if c.Icon then count = count + 1 end
            end
            print("    " .. viewerName .. ": EXISTS, " .. count .. " icons")
        else
            print("    " .. viewerName .. ": NOT FOUND")
        end
    end
end

SLASH_SUISTYLEFORCE1 = "/suistyleforce"
SlashCmdList.SUISTYLEFORCE = function()
    print("|cFF00FF00[SuaviUI StyledIcons]|r Force refreshing all viewers...")
    if not isModuleStyledEnabled then
        print("  Enabling module first...")
        StyledIcons:Enable()
    end
    StyledIcons:RefreshAll()
    if ns.CooldownManager and ns.CooldownManager.ForceRefreshAll then
        ns.CooldownManager.ForceRefreshAll()
    end
    print("  Done!")
end
