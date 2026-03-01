-- cooldown_icons.lua
-- Square icon styling for Blizzard Cooldown Viewers
-- Properly ported from CooldownManagerCentered/modules/styled.lua

local _, ns = ...

local StyledIcons = {}
-- Export to both the addon namespace and the global SuaviUI table
ns.StyledIcons = StyledIcons
SuaviUI.StyledIcons = StyledIcons

-- TEMP: Force-disable CDM icon styling (square icons + size normalization)
-- Re-enabled to restore main CDM styling feature.
local FORCE_DISABLE_CDM_STYLING = false
local DISABLE_PANDEMIC_ALERT_HOOK = true

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
    if FORCE_DISABLE_CDM_STYLING then
        return false
    end
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

-- TAINT-FIX: Store SuaviUI state in module-level tables rather than as fields on Blizzard's
-- CooldownViewer item frames. Writing any field to a Blizzard frame from addon context taints
-- the frame's entire table, causing all subsequent field reads in Blizzard secure code to come
-- back as "secret values tainted by SuaviUI".
local styledButtons = {}       -- [button] = true when square-styled
local buttonBorders = {}       -- [button] = border Frame
local viewerRefreshPending = {} -- [viewerFrame] = true when a deferred refresh is queued
local pandemicHooked = setmetatable({}, { __mode = "k" }) -- [button] = true if hook installed
-- TAINT-FIX: Track which regions we replaced with BASE_SQUARE_MASK in a module-level
-- weak table instead of writing __sui_set6707800 directly onto Blizzard's texture objects.
-- Writing ANY field onto a Blizzard-owned region taints it; tainted regions bleed taint
-- into Blizzard's secure OnUpdate/RefreshData execution context, causing pandemicEndTime
-- and wasOnGCDLookup to become secret/forbidden values (session 4796 root cause).
local markedRegions = setmetatable({}, { __mode = "k" })  -- [region] = true

local function ApplySquareStyle(button, viewerSettingName)
    local profile = GetProfile()
    local config = styleConfig[viewerSettingName]
    if not config or not profile then
        return
    end

    -- Guard against secret-value taint when accessing button internals
    if issecretvalue and (issecretvalue(button) or issecretvalue(button.Icon) or issecretvalue(button.icon)) then
        return
    end

    local width = GetViewerIconSize(viewerSettingName)
    local borderKey = "cooldownManager_squareIconsBorder_" .. viewerSettingName
    local borderThickness = profile[borderKey] or 1

    -- TAINT-FIX: Do NOT call button:SetSize(), iconTexture:SetPoint(), or any other
    -- frame layout method on Blizzard CDM pool item frames from addon context.
    -- Calling layout methods (SetSize, SetPoint, ClearAllPoints, SetScale) on a Blizzard
    -- managed pool frame from insecure (addon) context taints that frame at the C++ level.
    -- Blizzard's secureexecuterange then cannot read ANY Lua field on those frames without
    -- throwing "secret value tainted by SuaviUI" or "attempted to index a forbidden table".
    -- Safe operations: SetTexCoord, SetTexture, SetAlpha (texture data only, no layout).
    -- Safe operations: SetSwipeTexture (changes visual texture, not frame geometry).

    local iconTexture = button.Icon or button.icon or button.texture or button.Texture
    local iconSourceTexture = nil
    if iconTexture and iconTexture.GetTexture then
        pcall(function() iconSourceTexture = iconTexture:GetTexture() end)
    end

    -- If the icon has no source texture, treat it as inactive/placeholder and hide border.
    -- This prevents empty black square borders from remaining visible when Blizzard keeps
    -- pooled item frames shown but with no icon payload.
    if not iconSourceTexture then
        if buttonBorders[button] then buttonBorders[button]:Hide() end
        return
    end
    if iconTexture and not (issecretvalue and issecretvalue(iconTexture)) then
        -- Calculate zoom-based texture coordinates (UV crop only — no layout change)
        local zoomKey = "cooldownManager_squareIconsZoom_" .. viewerSettingName
        local zoom = profile[zoomKey] or 0
        local crop = zoom * 0.5
        if iconTexture.SetTexCoord then
            iconTexture:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
        end
    end

    -- Update swipe texture for cooldown children (SetSwipeTexture only — no SetPoint/SetSize)
    local children = {button:GetChildren()}
    for i = 1, #children do
        local texture = children[i]
        if texture and not (issecretvalue and issecretvalue(texture)) and texture.SetSwipeTexture then
            texture:SetSwipeTexture(BASE_SQUARE_MASK)
            -- NOTE: intentionally NOT calling ClearAllPoints/SetPoint on the swipe child
            -- because those are layout operations that taint the parent CDM item frame.
        end
    end

    -- Update textures (guard against secret values)
    local regions = {button:GetRegions()}
    for _, region in ipairs(regions) do
        if region and not (issecretvalue and issecretvalue(region)) and region:IsObjectType("Texture") then
            local texture = region:GetTexture()
            local atlas = region:GetAtlas()

            -- Safe texture comparison with issecretvalue guards
            if texture and not (issecretvalue and issecretvalue(texture)) and texture == 6707800 then
                -- TAINT-FIX (v0.3.8): Do NOT replace the region texture with BASE_SQUARE_MASK.
                -- Without SetSize/SetPoint (removed to prevent taint), the region renders at
                -- full button size and square_mask.tga appears as an opaque white overlay on
                -- the icon, causing the "white square" visual bug (sessions 4823-4824 report).
                -- Safe fix: just hide the circular edge region (SetAlpha is a texture-data op).
                region:SetAlpha(0)
                markedRegions[region] = true
            elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(0)
            end
        end
    end

    -- BUG-FIX (v0.3.9): If the CDM item button is hidden (Blizzard pooled it back after
    -- Edit Mode exit or when no cooldown is active), hide the border immediately.
    -- The border is parented to UIParent so it does NOT inherit button visibility —
    -- without this guard it remains floating as an empty black square on screen.
    if not button:IsShown() then
        if buttonBorders[button] then buttonBorders[button]:Hide() end
        return
    end

    -- Create/update inset black border.
    -- TAINT-FIX: Parent to UIParent, NOT to the CDM item frame.
    -- Adding an addon-created child to a Blizzard CDM pool frame taints the frame's
    -- C++ child list; when secure code later iterates children or accesses frame fields,
    -- it gets tainted results. SetPoint with the CDM button as ANCHOR (not parent) is safe.
    if not buttonBorders[button] then
        buttonBorders[button] = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        buttonBorders[button]:SetFrameLevel(button:GetFrameLevel() + 1)
    end
    buttonBorders[button]:ClearAllPoints()
    buttonBorders[button]:SetPoint("TOPLEFT", button, "TOPLEFT", -config.paddingFixup / 2, config.paddingFixup / 2)
    buttonBorders[button]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", config.paddingFixup / 2, -config.paddingFixup / 2)
    buttonBorders[button]:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = borderThickness,
    })
    buttonBorders[button]:SetBackdropBorderColor(0, 0, 0, 1)
    buttonBorders[button]:Show()

    styledButtons[button] = true
end

local function RestoreOriginalStyle(button, viewerSettingName)
    -- Only restore if button was previously styled by us
    -- DO NOT restore Blizzard's default state - that causes unwanted modifications
    if not styledButtons[button] then
        return
    end

    local width, height = GetViewerIconSize(viewerSettingName)
    -- TAINT-FIX: Do NOT call button:SetSize() — restoring frame dimensions is a layout op
    -- that taints the CDM item frame at C++ level (same reasoning as in ApplySquareStyle).

    local iconTexture = button.Icon or button.icon or button.texture or button.Texture
    if iconTexture then
        -- TAINT-FIX: Do NOT call ClearAllPoints/SetPoint/SetSize on iconTexture — those
        -- are layout operations.  Only reset the UV coordinates (safe texture-data op).
        if iconTexture.SetTexCoord then
            iconTexture:SetTexCoord(0, 1, 0, 1)
        end

        -- Re-attach any existing mask texture if present on the frame
        local maskTexture = button.IconMask or button.mask or button.Mask or button.iconMask
        if maskTexture and iconTexture.AddMaskTexture and iconTexture.GetMaskTexture then
            local hasMask = false
            for i = 1, 10 do
                if iconTexture:GetMaskTexture(i) == maskTexture then
                    hasMask = true
                    break
                end
            end
            if not hasMask then
                iconTexture:AddMaskTexture(maskTexture)
            end
        end
    end

    -- Restore cooldown swipe to default circular texture (SetSwipeTexture only — no layout)
    for i = 1, select("#", button:GetChildren()) do
        local child = select(i, button:GetChildren())
        if child and child.SetSwipeTexture then
            child:SetSwipeTexture(6707800)  -- Blizzard default
            -- TAINT-FIX: Do NOT call ClearAllPoints/SetPoint/SetSize on the swipe Cooldown
            -- child — those are layout operations that taint the parent CDM item frame.
            break
        end
    end

    -- Restore NCDM-stripped masks (if NCDM was applied)
    if button._originalMasks then
        local textures = { button.Icon, button.icon }
        for _, tex in ipairs(textures) do
            if tex and button._originalMasks[tostring(tex)] then
                for _, mask in ipairs(button._originalMasks[tostring(tex)]) do
                    if tex.AddMaskTexture then
                        tex:AddMaskTexture(mask)
                    end
                end
            end
        end
    end

    -- Restore NCDM-stripped NormalTexture
    if button._originalNormalAlpha and button.NormalTexture then
        button.NormalTexture:SetAlpha(button._originalNormalAlpha)
    end
    if button._originalNormalAlpha and button.GetNormalTexture then
        local normalTex = button:GetNormalTexture()
        if normalTex then
            normalTex:SetAlpha(button._originalNormalAlpha)
        end
    end

    -- Restore hidden overlay textures
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local atlas = region:GetAtlas()
            if markedRegions[region] then
                region:SetAlpha(1)  -- restore visibility (we now hide rather than replace texture)
                markedRegions[region] = nil
            elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(1)
            end
        end
    end

    -- Hide square border
    if buttonBorders[button] then
        buttonBorders[button]:Hide()
        buttonBorders[button]:SetBackdrop(nil)  -- Clear backdrop completely
    end

    styledButtons[button] = nil
    
    -- Also restore NCDM styling if available (clears NCDM's styling flags)
    if ns.NCDM and ns.NCDM.RestoreIcon then
        ns.NCDM.RestoreIcon(button)
    end
end

-- Process all children of a viewer
local function ProcessViewer(viewer, viewerSettingName, applyStyle)
    if not viewer then
        return
    end

    -- Pre-pass: hide borders for any styled button that is no longer shown.
    -- Complements the 1.5s cleanup ticker; runs on every ProcessViewer call for
    -- faster cleanup when RefreshAll is triggered by SPELL_UPDATE_COOLDOWN / UNIT_AURA.
    for button in pairs(styledButtons) do
        local shown = false
        pcall(function() shown = button:IsShown() end)
        if not shown and buttonBorders[button] then
            buttonBorders[button]:Hide()
        end
    end

    local children = {}
    local ok = pcall(function() children = { viewer:GetChildren() } end)
    if not ok then return end
    
    for _, child in ipairs(children) do
        -- Guard against tainted children
        if child and not (issecretvalue and issecretvalue(child)) then
            -- Check Icon property safely
            local hasIcon = false
            if pcall(function() hasIcon = child.Icon ~= nil end) and hasIcon then
                if applyStyle then
                    ApplySquareStyle(child, viewerSettingName)
                else
                    RestoreOriginalStyle(child, viewerSettingName)
                end

                -- Hook pandemic alerts (guard against tainted child)
                if (not DISABLE_PANDEMIC_ALERT_HOOK) and not (issecretvalue and issecretvalue(child)) and child.TriggerPandemicAlert and not pandemicHooked[child] then
                    pandemicHooked[child] = true
                    hooksecurefunc(child, "TriggerPandemicAlert", function()
                        -- TAINT-FIX: Defer ALL work to avoid tainting execution context.
                        -- TriggerPandemicAlert fires inside RefreshData's event chain.
                        C_Timer.After(0, function()
                            if child.PandemicIcon and not (issecretvalue and issecretvalue(child.PandemicIcon)) then
                                if applyStyle then
                                    child.PandemicIcon:SetScale(1.38)
                                else
                                    child.PandemicIcon:SetScale(1.0)
                                end
                            end
                        end)
                    end)
                end

                -- TAINT-FIX: Removed DebuffBorder:SetScale() calls.
                -- SetScale is a layout operation on a Blizzard child frame; it taints the
                -- parent CDM item frame at C++ level causing secret-value errors in
                -- secureexecuterange contexts (sessions 4796–4824 root cause).
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
    if FORCE_DISABLE_CDM_STYLING then
        if styledButtons[icon] then
            RestoreOriginalStyle(icon, viewerSettingName)
        end
        return
    end
    local enabled = IsSquareIconsEnabled(viewerSettingName)
    
    if enabled then
        ApplySquareStyle(icon, viewerSettingName)
    else
        -- Only restore if this icon was previously styled by us
        if styledButtons[icon] then
            RestoreOriginalStyle(icon, viewerSettingName)
        end
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
    -- TAINT-FIX: Disabled all layout operations (SetSize, SetPoint, ClearAllPoints) on
    -- Blizzard CDM pool frames.  These taint the frames at C++ level causing all subsequent
    -- secure-context field reads to fail as "secret values tainted by SuaviUI".
    -- The normalizeUtilitySize visual feature is suspended until a taint-safe approach exists.
    _ = button  -- suppress unused-var warning
end

local function RestoreOriginalSizeToButton(button, viewerSettingName)
    -- TAINT-FIX: Disabled all layout operations — see ApplyNormalizedSizeToButton.
    _ = button  -- suppress unused-var warning
end

function StyledIcons:Shutdown()
    isModuleStyledEnabled = false

    for viewerName, settingName in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local children = {}
            pcall(function() children = { viewerFrame:GetChildren() } end)
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
    if FORCE_DISABLE_CDM_STYLING then
        return
    end
    if isModuleStyledEnabled then
        return
    end

    isModuleStyledEnabled = true

    if not areHooksInitialized then
        areHooksInitialized = true

        -- ROOT-CAUSE FIX (v0.3.10): hooksecurefunc(viewerFrame, "RefreshLayout", ...)
        -- silently fails when CDM viewer frames are forbidden tables in WoW 12.x.
        -- pcall catches the error, sets areHooksInitialized=true, but installs no hook.
        -- Without a working hook, ProcessViewer/ApplySquareStyle never re-runs after
        -- CDM item pool changes (enter/exit combat, spell CD changes), leaving orphaned
        -- border frames floating on screen as black squares.
        --
        -- Fix: replace viewer hooks with SPELL_UPDATE_COOLDOWN + UNIT_AURA game events
        -- for re-styling, plus a periodic cleanup ticker for border orphan removal.
        local refreshEventFrame = CreateFrame("Frame")
        refreshEventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        refreshEventFrame:RegisterEvent("UNIT_AURA")
        refreshEventFrame:SetScript("OnEvent", function(_, event, unit)
            if event == "SPELL_UPDATE_COOLDOWN"
            or (event == "UNIT_AURA" and (unit == "player" or unit == "target")) then
                if viewerRefreshPending._global then return end
                viewerRefreshPending._global = true
                C_Timer.After(0.15, function()
                    viewerRefreshPending._global = nil
                    if not isModuleStyledEnabled then return end
                    pcall(function() StyledIcons:RefreshAll() end)
                end)
            end
        end)

        -- BORDER CLEANUP TICKER: sweep styledButtons every 1.5s and hide any border
        -- whose CDM item button is no longer shown (pooled/hidden by Blizzard).
        -- This is the primary safety net — event triggers cover cooldown transitions,
        -- the ticker covers Edit Mode exit and other non-event-driven pool changes.
        C_Timer.NewTicker(1.5, function()
            if not isModuleStyledEnabled then return end
            for button, _ in pairs(styledButtons) do
                local shown = false
                pcall(function() shown = button:IsShown() end)
                if not shown and buttonBorders[button] then
                    buttonBorders[button]:Hide()
                end
            end
        end)
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
    if FORCE_DISABLE_CDM_STYLING then
        return
    end
    if not IsAnyStyledFeatureEnabled() then
        return
    end
    self:Enable()
end

function StyledIcons:OnSettingChanged()
    if FORCE_DISABLE_CDM_STYLING then
        if isModuleStyledEnabled then
            self:Disable()
        end
        return
    end
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
    local coordinator = (ns and ns.CooldownCoordinator) or (_G.SuaviUI and _G.SuaviUI.CooldownCoordinator)
    if coordinator and coordinator.RequestRefresh then
        coordinator:RequestRefresh("icons", { icons = true, bars = true, essential = true, utility = true }, { delay = 0 })
    elseif ns.CooldownManager and ns.CooldownManager.ForceRefreshAll then
        ns.CooldownManager.ForceRefreshAll()
    end
end

function StyledIcons:ApplyNormalizedSize()
    local viewerFrame = _G["UtilityCooldownViewer"]
    if not viewerFrame then
        return
    end

    local enabled = IsNormalizedSizeEnabled()

    local children = {}
    pcall(function() children = { viewerFrame:GetChildren() } end)
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
    local coordinator = (ns and ns.CooldownCoordinator) or (_G.SuaviUI and _G.SuaviUI.CooldownCoordinator)
    if coordinator and coordinator.RequestRefresh then
        coordinator:RequestRefresh("icons", { icons = true, bars = true, essential = true, utility = true }, { delay = 0 })
    elseif ns.CooldownManager and ns.CooldownManager.ForceRefreshAll then
        ns.CooldownManager.ForceRefreshAll()
    end
    print("  Done!")
end
