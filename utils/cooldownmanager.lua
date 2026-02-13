-- cooldownmanager.lua
-- CooldownManagerCentered core centering logic integrated into SuaviUI

local _, ns = ...

local CooldownManager = {}
local Runtime = {}

-- Export to both the addon namespace and the global SuaviUI table
ns.CooldownManager = CooldownManager
ns.CooldownManagerCentered = CooldownManager
ns.CooldownRuntime = Runtime
SuaviUI.CooldownManager = CooldownManager
SuaviUI.CooldownManagerCentered = CooldownManager
SuaviUI.CooldownRuntime = Runtime

local function GetSUICore()
    return (ns and ns.SUICore) or (_G.SuaviUI and _G.SuaviUI.SUICore)
end

local function GetProfile()
    local core = GetSUICore()
    return (core and core.db and core.db.profile) or {}
end

local function GetSetting(key, default)
    local profile = GetProfile()
    if profile[key] == nil then
        return default
    end
    return profile[key]
end

local function GetCoordinator()
    return (ns and ns.CooldownCoordinator) or (_G.SuaviUI and _G.SuaviUI.CooldownCoordinator)
end

local function RequestCoordinatedRefresh(parts, source, opts)
    local coordinator = GetCoordinator()
    if coordinator and coordinator.RequestRefresh then
        coordinator:RequestRefresh(source or "cmc", parts, opts)
        return true
    end
    return false
end

local function IsCoordinatorInProgress()
    return _G.SuaviUI_CooldownRefreshInProgress
end

local function UpdateRuntime()
    if Runtime.isInEditMode or Runtime.hasSettingsOpened then
        Runtime.stop = true
    else
        Runtime.stop = false
    end
end

Runtime.stop = false
Runtime.isInEditMode = false
Runtime.hasSettingsOpened = false

if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Enter", function()
        Runtime.isInEditMode = true
        UpdateRuntime()
    end)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        Runtime.isInEditMode = false
        UpdateRuntime()
    end)
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function()
        Runtime.hasSettingsOpened = true
        UpdateRuntime()
    end)
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", function()
        Runtime.hasSettingsOpened = false
        UpdateRuntime()
    end)
end

function Runtime:IsReady(viewerNameOrFrame)
    local viewer = nil
    if type(viewerNameOrFrame) == "string" then
        viewer = _G[viewerNameOrFrame]
    elseif type(viewerNameOrFrame) == "table" then
        viewer = viewerNameOrFrame
    end
    if not viewer or not EditModeManagerFrame then
        return false
    end

    -- 12.0.5: CooldownViewer mixin properties are forbidden; pcall-protect access
    local hasInit = false
    pcall(function() hasInit = viewer.IsInitialized end)
    if not hasInit then
        return false
    end

    local initialized = false
    pcall(function() initialized = viewer:IsInitialized() end)
    if EditModeManagerFrame.layoutApplyInProgress or not initialized then
        return false
    end

    return true
end

CMC_DEBUG = false
-- CDM layout is controlled by the user-facing "Use Centered Styling" toggle
-- When disabled, all centering/alignment routines early-return.
local function FORCE_DISABLE_CDM_LAYOUT()
    return not GetSetting("cooldownManager_useCenteredStyling", false)
end
local PrintDebug = function(...)
    if CMC_DEBUG then
        print("[CMC]", ...)
    end
end

local floor = math.floor

-- Architecture:
-- LayoutEngine: pure layout computations (no frame access)
-- StateTracker: invalidation/diffing + repaint tracking
-- ViewerAdapters: WoW Frame interaction per viewer type
-- EventHandler: events

local LayoutEngine = {}
local StateTracker = {}
local ViewerAdapters = {}
local EventHandler = {}

local function DebugPrintSquare(...)
    print("[SuaviUI SquareIcons]", ...)
end

local function DebugSquareIcons()
    DebugPrintSquare("Test start")
    if not ns or not ns.StyledIcons then
        DebugPrintSquare("StyledIcons missing")
        return
    end

    local viewersToCheck = {
        { name = "EssentialCooldownViewer", typeKey = "Essential" },
        { name = "UtilityCooldownViewer", typeKey = "Utility" },
        { name = "BuffIconCooldownViewer", typeKey = "BuffIcons" },
    }

    for _, info in ipairs(viewersToCheck) do
        local viewer = _G[info.name]
        local count = 0
        if viewer and viewer.GetChildren then
            for _, child in ipairs({ viewer:GetChildren() }) do
                if child and (child.Icon or child.icon or child.texture or child.Texture) then
                    count = count + 1
                    ns.StyledIcons.UpdateIconStyle(child, info.typeKey)
                end
            end
        end

        DebugPrintSquare(info.name .. " icons:", count,
            "enabled:", GetSetting("cooldownManager_squareIcons_" .. info.typeKey, false))
    end

    DebugPrintSquare("Test end")
end

if SLASH_SUI_SQUARETEST1 == nil then
    SLASH_SUI_SQUARETEST1 = "/suisquaretest"
    SlashCmdList.SUI_SQUARETEST = function()
        DebugSquareIcons()
    end
end

local viewers = {}
-- Populated by RefreshViewerRefs() (pcall-safe for WoW 12.0.5 forbidden tables)

local function RefreshViewerRefs()
    -- WoW 12.0.5: viewer globals may be forbidden. pcall each access.
    local ok, v
    ok, v = pcall(function() return _G["EssentialCooldownViewer"] end)
    viewers.EssentialCooldownViewer = ok and v or nil
    ok, v = pcall(function() return _G["UtilityCooldownViewer"] end)
    viewers.UtilityCooldownViewer = ok and v or nil
    ok, v = pcall(function() return _G["BuffIconCooldownViewer"] end)
    viewers.BuffIconCooldownViewer = ok and v or nil
    ok, v = pcall(function() return _G["BuffBarCooldownViewer"] end)
    viewers.BuffBarCooldownViewer = ok and v or nil
end

-- Defaults
local fontSizeDefault = {
    EssentialCooldownViewer = 14,
    UtilityCooldownViewer = 12,
    BuffIconCooldownViewer = 14,
}
local viewerSettingsMap = {
    ["EssentialCooldownViewer"] = {
        squareIconsEnabled = "cooldownManager_squareIcons_Essential",
        squareIconsBorder = "cooldownManager_squareIconsBorder_Essential",
        squareIconsBorderOverlap = "cooldownManager_squareIconsBorder_Essential_Overlap",
    },
    ["UtilityCooldownViewer"] = {
        squareIconsEnabled = "cooldownManager_squareIcons_Utility",
        squareIconsBorder = "cooldownManager_squareIconsBorder_Utility",
        squareIconsBorderOverlap = "cooldownManager_squareIconsBorder_Utility_Overlap",
    },
    ["BuffIconCooldownViewer"] = {
        squareIconsEnabled = "cooldownManager_squareIcons_BuffIcons",
        squareIconsBorder = "cooldownManager_squareIconsBorder_BuffIcons",
        squareIconsBorderOverlap = "cooldownManager_squareIconsBorder_BuffIcons_Overlap",
    },
}

function LayoutEngine.CenteredRowXOffsets(count, itemWidth, padding, directionModifier)
    -- Why: Produce symmetric X offsets to center a horizontal row.
    -- When: Positioning icons in rows; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local totalWidth = (count * itemWidth) + ((count - 1) * padding)
    local startX = ((-totalWidth / 2 + itemWidth / 2) * dir)
    local offsets = {}
    for i = 1, count do
        offsets[i] = startX + (i - 1) * (itemWidth + padding) * dir
    end
    return offsets
end

function LayoutEngine.CenteredColYOffsets(count, itemHeight, padding, directionModifier)
    -- Why: Produce symmetric Y offsets to center a vertical column.
    -- When: Positioning icons in columns; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local totalHeight = ((count * itemHeight) + ((count - 1) * padding))
    local startY = ((totalHeight / 2 - itemHeight / 2) * dir)
    local offsets = {}
    for i = 1, count do
        offsets[i] = (startY - (i - 1) * (itemHeight + padding) * dir)
    end
    return offsets
end

function LayoutEngine.StartRowXOffsets(count, itemWidth, padding, directionModifier)
    -- Why: Produce X offsets starting from the left edge.
    -- When: Positioning icons aligned to start; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local offsets = {}
    for i = 1, count do
        offsets[i] = ((i - 1) * (itemWidth + padding) * dir)
    end
    return offsets
end

function LayoutEngine.EndRowXOffsets(count, itemWidth, padding, directionModifier)
    -- Why: Produce X offsets starting from the right edge.
    -- When: Positioning icons aligned to end; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local offsets = {}
    for i = 1, count do
        offsets[i] = (-((i - 1) * (itemWidth + padding)) * dir)
    end
    return offsets
end

function LayoutEngine.StartColYOffsets(count, itemHeight, padding, directionModifier)
    -- Why: Produce Y offsets starting from the top edge.
    -- When: Positioning icons aligned to start; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local offsets = {}
    for i = 1, count do
        offsets[i] = (-((i - 1) * (itemHeight + padding)) * dir)
    end
    return offsets
end

function LayoutEngine.EndColYOffsets(count, itemHeight, padding, directionModifier)
    -- Why: Produce Y offsets starting from the bottom edge.
    -- When: Positioning icons aligned to end; supports reversed direction via modifier.
    if not count or count <= 0 then
        return {}
    end
    local dir = directionModifier or 1
    local offsets = {}
    for i = 1, count do
        offsets[i] = ((i - 1) * (itemHeight + padding) * dir)
    end
    return offsets
end

function LayoutEngine.BuildRows(iconLimit, children)
    -- Why: Group a flat list of icons into rows limited by `iconLimit`.
    -- When: Before computing centered layout for Essential/Utility viewers.
    local rows = {}
    local limit = iconLimit or 0
    if limit <= 0 then
        return rows
    end
    for i = 1, #children do
        local rowIndex = floor((i - 1) / limit) + 1
        rows[rowIndex] = rows[rowIndex] or {}
        rows[rowIndex][#rows[rowIndex] + 1] = children[i]
    end
    return rows
end

-- StateTracker: invalidation/diffing

function StateTracker.MarkViewersDirty(name)
    if name == "EssentialCooldownViewer" then
        CooldownManager.UpdateEssentialIfNeeded()
    end
    if name == "UtilityCooldownViewer" then
        CooldownManager.UpdateUtilityIfNeeded()
    end
end

function StateTracker.MarkBuffIconsDirty()
    ViewerAdapters.UpdateBuffIcons()
end

function StateTracker.MarkBuffBarsDirty()
    ViewerAdapters.UpdateBuffBarsIfNeeded()
end

-- ViewerAdapters: BuffIcon/BuffBar collection + hooks

function ViewerAdapters.GetBuffIconFrames()
    -- Why: Collect visible Buff Icon viewer children, hook change events, and apply stack visuals.
    -- When: Before positioning buff icons and whenever aura events trigger layout updates.
    -- Custom icons: managed entirely by sui_buffbar.lua — skip Blizzard frame collection
    if ns.BuffBar and ns.BuffBar.USE_CUSTOM_ICONS then
        return {}
    end
    if not BuffIconCooldownViewer then
        return {}
    end
    local visible = {}
    local ok, children = pcall(BuffIconCooldownViewer.GetChildren, BuffIconCooldownViewer)
    if not ok or not children then return visible end
    for _, child in ipairs({ children }) do
        if child and (child.icon or child.Icon) then
            if child:IsShown() then
                visible[#visible + 1] = child
            end
            if not child._wt_isHooked then
                child._wt_isHooked = true
                pcall(hooksecurefunc, child, "OnActiveStateChanged", StateTracker.MarkBuffIconsDirty)
                -- TAINT-FIX: Remove OnUnitAura hooks - they taint spellID values used in Blizzard comparisons
                -- Fallback to OnUpdate polling (0.05s) is already in place and sufficient
            end
        end
    end
    table.sort(visible, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return visible
end

function ViewerAdapters.GetBuffBarFrames()
    -- Why: Collect active Buff Bar frames with resilience to API differences, and hook changes.
    -- When: Before aligning bars vertically and whenever aura events trigger layout updates.
    -- Custom bars: managed entirely by sui_buffbar.lua — skip Blizzard frame collection
    if ns.BuffBar and ns.BuffBar.USE_CUSTOM_BARS then
        return {}
    end
    if not BuffBarCooldownViewer then
        return {}
    end
    local frames = {}
    local hasGetItemFrames = false
    pcall(function() hasGetItemFrames = BuffBarCooldownViewer.GetItemFrames ~= nil end)
    if hasGetItemFrames then
        local ok, items = pcall(BuffBarCooldownViewer.GetItemFrames, BuffBarCooldownViewer)
        if ok and items then
            frames = items
        end
    end
    if #frames == 0 then
        local okc, children = pcall(BuffBarCooldownViewer.GetChildren, BuffBarCooldownViewer)
        if okc and children then
            for _, child in ipairs({ children }) do
                if child and child:IsObjectType("Frame") then
                    frames[#frames + 1] = child
                end
            end
        end
    end
    local active = {}
    for _, frame in ipairs(frames) do
        if frame:IsShown() and frame:IsVisible() then
            active[#active + 1] = frame
        end
        if not frame._wt_isHooked and (frame.icon or frame.Icon or frame.bar or frame.Bar) then
            frame._wt_isHooked = true
            pcall(hooksecurefunc, frame, "OnActiveStateChanged", StateTracker.MarkBuffBarsDirty)
            -- TAINT-FIX: Remove OnUnitAura hooks - they taint spellID/charges values used in Blizzard comparisons
            -- Fallback to OnUpdate polling (0.05s) is already in place and sufficient
        end
    end
    table.sort(active, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return active
end

function ViewerAdapters.UpdateBuffIcons()
    -- Why: Position Buff Icon viewer children based on isHorizontal, iconDirection, and alignment.
    -- When: On aura events, settings changes, or explicit refresh calls when the feature is enabled.
    -- Custom icons: layout handled by sui_buffbar.lua — skip CMC icon positioning
    if ns.BuffBar and ns.BuffBar.USE_CUSTOM_ICONS then
        return
    end
    if FORCE_DISABLE_CDM_LAYOUT() then
        return
    end

    if not Runtime:IsReady(BuffIconCooldownViewer)
        or GetSetting("cooldownManager_alignBuffIcons_growFromDirection", "START") == "Disable" then
        return
    end

    local icons = ViewerAdapters.GetBuffIconFrames()
    local count = #icons
    if count == 0 then
        return
    end

    local refIcon = icons[1]
    local iconWidth = refIcon:GetWidth()
    local iconHeight = refIcon:GetHeight()
    if not iconWidth or iconWidth == 0 or not iconHeight or iconHeight == 0 then
        return
    end

    local isHorizontal = true
    local iconDirection = "NORMAL"
    local padding = 0
    pcall(function()
        isHorizontal = BuffIconCooldownViewer.isHorizontal ~= false
        iconDirection = BuffIconCooldownViewer.iconDirection == 1 and "NORMAL" or "REVERSED"
        padding = isHorizontal and BuffIconCooldownViewer.childXPadding or BuffIconCooldownViewer.childYPadding
    end)
    local iconDirectionModifier = iconDirection == "NORMAL" and 1 or -1
    local alignment = GetSetting("cooldownManager_alignBuffIcons_growFromDirection", "CENTER")
    local settingMap = viewerSettingsMap["BuffIconCooldownViewer"]

    if isHorizontal then
        local offsets
        local anchor, relativePoint

        if alignment == "START" then
            offsets = LayoutEngine.StartRowXOffsets(count, iconWidth, padding, iconDirectionModifier)
            anchor = "TOPLEFT"
            relativePoint = "TOPLEFT"
        elseif alignment == "END" then
            offsets = LayoutEngine.EndRowXOffsets(count, iconWidth, padding, iconDirectionModifier)
            anchor = "TOPRIGHT"
            relativePoint = "TOPRIGHT"
        else -- CENTER
            offsets = LayoutEngine.CenteredRowXOffsets(count, iconWidth, padding, iconDirectionModifier)
            anchor = "TOP"
            relativePoint = "TOP"
        end

        for i, icon in ipairs(icons) do
            local x = offsets[i] or 0
            if ns.StyledIcons then
                ns.StyledIcons.UpdateIconStyle(icon, "BuffIcons")
            end
            icon:ClearAllPoints()
            icon:SetPoint(anchor, BuffIconCooldownViewer, relativePoint, x, 0)
        end
    else
        -- Vertical layout
        local offsets
        local anchor, relativePoint

        if alignment == "START" then
            offsets = LayoutEngine.StartColYOffsets(count, iconHeight, padding, iconDirectionModifier)
            anchor = "TOPLEFT"
            relativePoint = "TOPLEFT"
        elseif alignment == "END" then
            offsets = LayoutEngine.EndColYOffsets(count, iconHeight, padding, iconDirectionModifier)
            anchor = "BOTTOMLEFT"
            relativePoint = "BOTTOMLEFT"
        else -- CENTER
            offsets = LayoutEngine.CenteredColYOffsets(count, iconHeight, padding, iconDirectionModifier)
            anchor = "LEFT"
            relativePoint = "LEFT"
        end

        for i, icon in ipairs(icons) do
            local y = offsets[i] or 0
            if ns.StyledIcons then
                ns.StyledIcons.UpdateIconStyle(icon, "BuffIcons")
            end
            icon:ClearAllPoints()
            icon:SetPoint(anchor, BuffIconCooldownViewer, relativePoint, 0, y)
        end
    end
end

function ViewerAdapters.UpdateBuffBarsIfNeeded()
    -- Why: Align Buff Bar frames from chosen growth direction when enabled and changes detected.
    -- When: On aura events, settings changes, or explicit refresh calls when the feature is enabled.
    -- Custom bars: layout handled by sui_buffbar.lua — skip CMC bar positioning
    if ns.BuffBar and ns.BuffBar.USE_CUSTOM_BARS then
        return
    end
    if FORCE_DISABLE_CDM_LAYOUT() then
        return
    end
    if not Runtime:IsReady(BuffBarCooldownViewer)
        or GetSetting("cooldownManager_alignBuffBars_growFromDirection", "BOTTOM") == "Disable" then
        return
    end

    local bars = ViewerAdapters.GetBuffBarFrames()
    local count = #bars
    if count == 0 then
        return
    end

    local refBar = bars[1]
    local barHeight = refBar and refBar:GetHeight()
    local spacing = 0
    pcall(function() spacing = BuffBarCooldownViewer.childYPadding or 0 end)
    if not barHeight or barHeight == 0 then
        return
    end

    local growFromBottom = GetSetting("cooldownManager_alignBuffBars_growFromDirection", "BOTTOM") == "BOTTOM"

    for index, bar in ipairs(bars) do
        local offsetIndex = index - 1
        local y = growFromBottom and offsetIndex * (barHeight + spacing) or -offsetIndex * (barHeight + spacing)
        bar:ClearAllPoints()
        if growFromBottom then
            bar:SetPoint("BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, y)
        else
            bar:SetPoint("TOP", BuffBarCooldownViewer, "TOP", 0, y)
        end
    end
end

function ViewerAdapters.CollectViewerChildren(viewer)
    -- Why: Standardized filtered list of visible icon-like children sorted by layoutIndex.
    -- When: Building rows/columns for Essential/Utility centered layouts.
    -- WoW 12.0.5: viewer children may be forbidden. All access is pcall-wrapped.
    local all = {}
    local ok, viewerName = pcall(function() return viewer:GetName() end)
    if not ok then return all end
    local toDim = viewerName == "UtilityCooldownViewer" and GetSetting("cooldownManager_utility_dimWhenNotOnCD", false)
    local toDimOpacity = GetSetting("cooldownManager_utility_dimOpacity", 0.3)
    local okc, children = pcall(function() return { viewer:GetChildren() } end)
    if not okc or not children then return all end
    for _, child in ipairs(children) do
        pcall(function()
            if child and child:IsShown() and child.Icon then
                all[#all + 1] = child

                if child.cooldownID and toDim and ns.CooldownTracker then
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(child.cooldownID)
                    if not C_Spell.GetSpellCooldown(info.spellID).isOnGCD then
                        local cd = nil
                        if not issecretvalue(child.cooldownChargesShown) and child.cooldownChargesShown then
                            cd = ns.CooldownTracker:getChargeCD(info.spellID)
                        else
                            cd = ns.CooldownTracker:getSpellCD(info.spellID)
                        end

                        local curve = C_CurveUtil.CreateCurve()
                        curve:AddPoint(0.0, toDimOpacity)
                        curve:AddPoint(0.1, 1)
                        local EvaluateDuration = cd.EvaluateRemainingDuration and cd:EvaluateRemainingDuration(curve)

                        child:SetAlpha(EvaluateDuration)
                    end
                else
                    child:SetAlpha(1)
                end
            end
        end)
    end
    table.sort(all, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    return all
end

local function PositionRowHorizontal(viewer, row, yOffset, w, padding, iconDirectionModifier, rowAnchor, viewerType)
    -- Why: Place a single horizontal row centered with optional reversed direction and stack visuals.
    -- When: Essential/Utility viewers are horizontal or configured to grow by rows.
    local count = #row
    local xOffsets = LayoutEngine.CenteredRowXOffsets(count, w, padding, iconDirectionModifier)
    for i, icon in ipairs(row) do
        -- Apply square styling if enabled
        if ns.StyledIcons and viewerType then
            ns.StyledIcons.UpdateIconStyle(icon, viewerType)
        end
        
        -- Apply font styling
        if ns.CooldownFonts and viewerType then
            ns.CooldownFonts.ApplyCooldownFont(icon, viewerType)
            ns.CooldownFonts.ApplyStackFont(icon, viewerType)
            ns.CooldownFonts.ApplyKeybindFont(icon, viewerType)
        end
        
        -- Apply advanced features
        if ns.CooldownAdvanced and viewerType then
            ns.CooldownAdvanced.ApplyAllFeatures(icon, viewerType)
        end
        
        local x = xOffsets[i] or 0
        local stillNeedToSet = true
        if icon.GetPoint then
            local point, _, relativePoint, offsetX, offsetY = icon:GetPoint()
            if offsetX ~= nil and offsetY ~= nil then
                local xDiff = math.abs(x - offsetX)
                local yDiff = math.abs(yOffset - offsetY)
                if point == rowAnchor and relativePoint == rowAnchor and xDiff < 1 and yDiff < 1 then
                    stillNeedToSet = false
                else
                    if xDiff <= 1 then
                        x = offsetX
                    end
                end
            end
        end
        if stillNeedToSet then
            icon:ClearAllPoints()
            icon:SetPoint(rowAnchor, viewer, rowAnchor, x, yOffset)
        end
    end
end

local function PositionRowVertical(viewer, row, xOffset, h, padding, iconDirectionModifier, colAnchor, viewerType)
    -- Why: Place a single vertical column centered with optional reversed direction and stack visuals.
    -- When: Essential/Utility viewers are vertical or configured to grow by columns.
    local count = #row
    local yOffsets = LayoutEngine.CenteredColYOffsets(count, h, padding, iconDirectionModifier)
    for i, icon in ipairs(row) do
        -- Apply square styling if enabled
        if ns.StyledIcons and viewerType then
            ns.StyledIcons.UpdateIconStyle(icon, viewerType)
        end
        
        -- Apply font styling
        if ns.CooldownFonts and viewerType then
            ns.CooldownFonts.ApplyCooldownFont(icon, viewerType)
            ns.CooldownFonts.ApplyStackFont(icon, viewerType)
            ns.CooldownFonts.ApplyKeybindFont(icon, viewerType)
        end
        
        -- Apply advanced features
        if ns.CooldownAdvanced and viewerType then
            ns.CooldownAdvanced.ApplyAllFeatures(icon, viewerType)
        end
        
        local y = yOffsets[i] or 0
        icon:ClearAllPoints()
        icon:SetPoint(colAnchor, viewer, colAnchor, xOffset, y)
    end
end

local sizeSavedValues = {
    EssentialCooldownViewer = { width = 0, height = 0 },
    UtilityCooldownViewer = { width = 0, height = 0 },
}

function ViewerAdapters.CenterAllRows(viewer, fromDirection)
    -- Why: Core centering routine that groups children into rows/columns and applies offsets.
    -- When: `UpdateEssentialIfNeeded` or `UpdateUtilityIfNeeded` determines changes require recompute.
    -- WoW 12.0.5: viewer may be forbidden. All access wrapped in pcall.
    if FORCE_DISABLE_CDM_LAYOUT() then
        return
    end
    if not viewer then return end
    local ok = pcall(function()
        if not Runtime:IsReady(viewer) then
            return
        end

        local viewerName = viewer:GetName()
        local viewerType = nil
        if viewerName == "EssentialCooldownViewer" then
            viewerType = "Essential"
        elseif viewerName == "UtilityCooldownViewer" then
            viewerType = "Utility"
        end

        local isHorizontal, iconDirection, iconLimit, iconScale
        local propsOk = pcall(function()
            isHorizontal = viewer.isHorizontal ~= false
            iconDirection = viewer.iconDirection == 1 and "NORMAL" or "REVERSED"
            iconLimit = viewer.iconLimit or 0
            iconScale = viewer.iconScale or 1
        end)
        if not propsOk then
            return
        end
        if not iconLimit or iconLimit <= 0 then
            return
        end

        local children = ViewerAdapters.CollectViewerChildren(viewer)
        if fromDirection == "Disable" or #children == 0 then
            return
        end

        local first = children[1]
        if not first then
            return
        end
        local w, h = first:GetWidth(), first:GetHeight()
        if not w or w == 0 or not h or h == 0 then
            return
        end

        local padding = 0
        pcall(function() padding = isHorizontal and viewer.childXPadding or viewer.childYPadding end)
        if viewerName == "UtilityCooldownViewer" and GetSetting("cooldownManager_limitUtilitySizeToEssential", false) then
            local essentialViewer = viewers["EssentialCooldownViewer"]
            if essentialViewer then
                local eWidth = essentialViewer:GetWidth()
                if eWidth and eWidth > 0 then
                    local iconActualWidth = (w + padding) * (iconScale or 1)
                    local maxIcons = floor((eWidth + (padding * (iconScale or 1))) / iconActualWidth)
                    if maxIcons > 0 then
                        iconLimit = math.max(math.min(iconLimit, maxIcons), math.min(iconLimit, 5))
                    end
                end
            end
        end

        local rows = LayoutEngine.BuildRows(iconLimit, children)
        if #rows == 0 then
            return
        end

        if isHorizontal then
            local rowOffsetModifier = fromDirection == "BOTTOM" and 1 or -1
            local iconDirectionModifier = iconDirection == "NORMAL" and 1 or -1
            local rowAnchor = (fromDirection == "BOTTOM") and "BOTTOM" or "TOP"
            for iRow, row in ipairs(rows) do
                local yOffset = (iRow - 1) * (h + padding) * rowOffsetModifier
                PositionRowHorizontal(viewer, row, yOffset, w, padding, iconDirectionModifier, rowAnchor, viewerType)
            end
        else
            local rowOffsetModifier = fromDirection == "BOTTOM" and -1 or 1
            local iconDirectionModifier = iconDirection == "NORMAL" and -1 or 1
            local colAnchor = (fromDirection == "BOTTOM") and "RIGHT" or "LEFT"
            for iRow, row in ipairs(rows) do
                local xOffset = (iRow - 1) * (w + padding) * rowOffsetModifier
                PositionRowVertical(viewer, row, xOffset, h, padding, iconDirectionModifier, colAnchor, viewerType)
            end
        end
    end)
end

function CooldownManager.UpdateEssentialIfNeeded()
    if FORCE_DISABLE_CDM_LAYOUT() then
        return
    end
    local growKey = "cooldownManager_centerEssential_growFromDirection"
    local viewer = viewers["EssentialCooldownViewer"]
    if viewer then
        ViewerAdapters.CenterAllRows(viewer, GetSetting(growKey, "TOP"))
    end
end

function CooldownManager.UpdateUtilityIfNeeded()
    if FORCE_DISABLE_CDM_LAYOUT() then
        return
    end
    local growKey = "cooldownManager_centerUtility_growFromDirection"
    local viewer = viewers["UtilityCooldownViewer"]
    if viewer then
        ViewerAdapters.CenterAllRows(viewer, GetSetting(growKey, "TOP"))
    end
end

local function ShouldDebugRefreshLog()
    if GetSetting("cooldownManager_debugRefreshLogs", nil) ~= nil then
        return GetSetting("cooldownManager_debugRefreshLogs", false)
    end
    return false
end

function CooldownManager.ForceRefresh(parts)
    parts = parts or { icons = true, bars = true, essential = true, utility = true }
    if FORCE_DISABLE_CDM_LAYOUT() then
        -- Centering is OFF: tell Blizzard to re-layout so positions reset to default
        for _, name in ipairs({ "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
            local v = viewers[name]
            if v then
                pcall(function()
                    if v.RefreshLayout then
                        v:RefreshLayout()
                    end
                end)
            end
        end
        return
    end
    if parts.icons then
        StateTracker.MarkBuffIconsDirty()
    end
    if parts.bars then
        StateTracker.MarkBuffBarsDirty()
    end
    if parts.essential then
        StateTracker.MarkViewersDirty("EssentialCooldownViewer")
    end
    if parts.utility then
        StateTracker.MarkViewersDirty("UtilityCooldownViewer")
    end
end

function CooldownManager.ForceRefreshAll()
    CooldownManager.ForceRefresh({ icons = true, bars = true, essential = true, utility = true })
end

-- EventHandler: events

EventHandler.frame = EventHandler.frame or CreateFrame("FRAME")
EventHandler.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventHandler.frame:RegisterEvent("PLAYER_TALENT_UPDATE")
EventHandler.frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
EventHandler.frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
EventHandler.frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
EventHandler.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
-- TAINT-FIX: Disable SPELL_UPDATE_COOLDOWN registration to prevent hasTotem taint
-- This event fires when Blizzard's CooldownViewer processes totem data; our handler
-- triggers layout refreshes that access viewer properties, tainting hasTotem values.
-- Refreshes are already handled by other events (combat, spec changes, etc.)
-- EventHandler.frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
EventHandler.frame:RegisterEvent("CINEMATIC_STOP")
EventHandler.frame:RegisterEvent("ADDON_LOADED")

-- Simple event→refresh routing map for targeted invalidation where safe
EventHandler.EventRefreshMap = {
    PLAYER_SPECIALIZATION_CHANGED = { essential = true, utility = true },
    CINEMATIC_STOP = { essential = true, utility = true },
}

EventHandler.frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "Blizzard_CooldownManager" then
        RefreshViewerRefs()
        if CooldownManager.HookViewerRefreshLayout then
            CooldownManager.HookViewerRefreshLayout()
        end
        C_Timer.After(0, function()
            if not RequestCoordinatedRefresh({ icons = true, bars = true, essential = true, utility = true }, "cmc", { delay = 0 }) then
                CooldownManager.ForceRefreshAll()
            end
        end)
        return
    end
    local parts = EventHandler.EventRefreshMap[event]
    if event == "PLAYER_REGEN_DISABLED" then
        C_Timer.After(0, function()
            if not RequestCoordinatedRefresh({ icons = true, bars = true, essential = true, utility = true }, "cmc", { delay = 0 }) then
                CooldownManager.ForceRefreshAll()
            end
        end)
        return
    end
    -- SPELL_UPDATE_COOLDOWN handler removed (event no longer registered to prevent hasTotem taint)
    if parts then
        if not RequestCoordinatedRefresh(parts, "cmc", { delay = 0 }) then
            CooldownManager.ForceRefresh(parts)
        end
    else
        if not RequestCoordinatedRefresh({ icons = true, bars = true, essential = true, utility = true }, "cmc", { delay = 0 }) then
            CooldownManager.ForceRefreshAll()
        end
    end
end)

if EventRegistry then
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
        PrintDebug("CooldownViewerSettings.OnDataChanged triggered refresh")
        if not RequestCoordinatedRefresh({ icons = true, bars = true, essential = true, utility = true }, "cmc", { delay = 0 }) then
            CooldownManager.ForceRefreshAll("CooldownViewerSettings.OnDataChanged")
        end
    end)
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function()
        PrintDebug("CooldownViewerSettings.OnShow triggered refresh")
        if not RequestCoordinatedRefresh({ icons = true, bars = true, essential = true, utility = true }, "cmc", { delay = 0 }) then
            CooldownManager.ForceRefreshAll("CooldownViewerSettings.OnShow")
        end
    end)
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", function()
        PrintDebug("CooldownViewerSettings.OnHide triggered refresh")
        if not RequestCoordinatedRefresh({ icons = true, bars = true, essential = true, utility = true }, "cmc", { delay = 0 }) then
            CooldownManager.ForceRefreshAll("CooldownViewerSettings.OnHide")
        end
    end)

    EventRegistry:RegisterCallback("EditMode.Exit", function()
        if not RequestCoordinatedRefresh({ icons = true, bars = true, essential = true, utility = true }, "cmc", { delay = 0 }) then
            CooldownManager.ForceRefreshAll()
        end
    end)
end

local viewerReasonPartsMap = {
    EssentialCooldownViewer = { essential = true },
    UtilityCooldownViewer = { utility = true },
    BuffIconCooldownViewer = { icons = true },
    BuffBarCooldownViewer = { bars = true },
}

function CooldownManager.HookViewerRefreshLayout()
    for n, v in pairs(viewers) do
        -- WoW 12.0.5: viewer internals may be forbidden to addon access.
        -- Wrap every property read in pcall to avoid "attempted to index a forbidden table".
        local ok, hasRL, isHooked = pcall(function()
            return v and v.RefreshLayout, v and v.__suiCMCRefreshHooked
        end)
        if ok and hasRL and not isHooked then
            pcall(function() v.__suiCMCRefreshHooked = true end)
            local hookOk = pcall(hooksecurefunc, v, "RefreshLayout", function()
                if IsCoordinatorInProgress() then
                    return
                end
                pcall(function()
                    if not RequestCoordinatedRefresh(viewerReasonPartsMap[n], "cmc", { delay = 0 }) then
                        CooldownManager.ForceRefresh(viewerReasonPartsMap[n])
                    end
                end)
                C_Timer.After(0, function()
                    if IsCoordinatorInProgress() then
                        return
                    end
                    pcall(function()
                        if not RequestCoordinatedRefresh(viewerReasonPartsMap[n], "cmc", { delay = 0 }) then
                            CooldownManager.ForceRefresh(viewerReasonPartsMap[n])
                        end
                    end)
                end)
            end)
        end
    end
end

function CooldownManager.Initialize()
    RefreshViewerRefs()
    CooldownManager.HookViewerRefreshLayout()
    if not RequestCoordinatedRefresh({ icons = true, bars = true, essential = true, utility = true }, "cmc", { delay = 0 }) then
        CooldownManager.ForceRefreshAll()
    end
end

C_Timer.After(0, function()
    CooldownManager.Initialize()
end)





