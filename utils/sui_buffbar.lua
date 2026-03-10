local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

-- Session 4933 emergency hotfix lifted: CDM taint vectors fixed (sessions 4891-4927),
-- remaining frame field writes moved to weak tables.
local FORCE_DISABLE_CDM_BUFFBAR = false

---------------------------------------------------------------------------
-- SUI Buff Bar Manager
-- Handles dynamic centering of BuffIconCooldownViewer and BuffBarCooldownViewer
-- Uses hash-based polling + sticky center debounce for stable updates
---------------------------------------------------------------------------

local SUI_BuffBar = {}
ns.BuffBar = SUI_BuffBar

-- Forward declarations for runtime ownership gates
local USE_CUSTOM_BARS
local USE_CUSTOM_ICONS

---------------------------------------------------------------------------
-- SAFE VIEWER ACCESS (WoW 12.0.5: viewer internals may be forbidden)
---------------------------------------------------------------------------
local function SafeGetViewer(name)
    local ok, viewer = pcall(function() return _G[name] end)
    return ok and viewer or nil
end

local function SafeViewerCall(viewer, method, ...)
    if not viewer then return end
    local args = {...}
    local ok, result = pcall(function()
        if type(method) == "string" then
            return viewer[method](viewer, unpack(args))
        else
            return method(viewer, unpack(args))
        end
    end)
    return ok and result or nil
end

local function SafeViewerProp(viewer, prop)
    if not viewer then return nil end
    local ok, val = pcall(function() return viewer[prop] end)
    return ok and val or nil
end

local function SafeViewerSet(viewer, prop, val)
    if not viewer then return end
    pcall(function() viewer[prop] = val end)
end

---------------------------------------------------------------------------
-- TAINT-SAFE SIDE TABLES
-- WoW 12.x (Midnight): writing ANY field to a Blizzard frame from addon
-- context taints that frame table. Blizzard secure code reading ANY other
-- field on the same frame then errors with "secret value tainted by SuaviUI".
-- Solution: store all per-frame metadata in addon-owned weak-keyed tables
-- instead of writing directly onto Blizzard frame objects.
---------------------------------------------------------------------------
local SUI_trackedBg         = setmetatable({}, {__mode = "k"})  -- [frame]  → Texture
local SUI_trackedBorderCont = setmetatable({}, {__mode = "k"})  -- [frame]  → Frame
local SUI_trackedBarStyled  = setmetatable({}, {__mode = "k"})  -- [frame]  → bool
local SUI_overlayHooked     = setmetatable({}, {__mode = "k"})  -- [region] → bool
-- TAINT-FIX: weak tables to avoid writing fields onto Blizzard CDM icon/texture objects
local SUI_buffSetup         = setmetatable({}, {__mode = "k"})  -- [icon]   → bool
local SUI_buffBorder        = setmetatable({}, {__mode = "k"})  -- [icon]   → Texture
local SUI_buffBorderSize    = setmetatable({}, {__mode = "k"})  -- [icon]   → number
local SUI_atlasDisabled     = setmetatable({}, {__mode = "k"})  -- [tex]    → bool
local SUI_atlasHooked       = setmetatable({}, {__mode = "k"})  -- [tex]    → bool

---------------------------------------------------------------------------
-- HELPER: Get font from general settings
---------------------------------------------------------------------------
local function GetGeneralFont()
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general then
        local general = SUICore.db.profile.general
        local fontName = general.font or "Friz Quadrata TT"
        return LSM:Fetch("font", fontName) or "Fonts\\FRIZQT__.TTF"
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function GetGeneralFontOutline()
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general then
        return SUICore.db.profile.general.fontOutline or "OUTLINE"
    end
    return "OUTLINE"
end

---------------------------------------------------------------------------
-- UTILITY FUNCTIONS
---------------------------------------------------------------------------

local floor = math.floor

local function roundPixel(value)
    if not value then return 0 end
    return floor(value + 0.5)
end

-- Tolerance-based position check: skip repositioning if within tolerance
-- Prevents jitter from floating-point drift
local abs = math.abs
local function PositionMatchesTolerance(icon, expectedX, tolerance)
    if not icon then return false end
    local point, _, _, xOfs = icon:GetPoint(1)
    if not point then return false end
    return abs((xOfs or 0) - expectedX) <= (tolerance or 2)
end

---------------------------------------------------------------------------
-- DATABASE ACCESS
---------------------------------------------------------------------------

local function GetDB()
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.ncdm then
        return SUICore.db.profile.ncdm
    end
    return nil
end

local function GetBuffSettings()
    local db = GetDB()
    if db and db.buff then
        local buff = db.buff
        -- Migrate old 'shape' setting to new 'aspectRatioCrop'
        if buff.aspectRatioCrop == nil and buff.shape then
            if buff.shape == "rectangle" or buff.shape == "flat" then
                buff.aspectRatioCrop = 1.33  -- 4:3 aspect ratio
            else
                buff.aspectRatioCrop = 1.0  -- square
            end
        end
        return buff
    end
    -- Return defaults if no DB
    return {
        enabled = true,
        iconSize = 42,
        borderSize = 2,
        aspectRatioCrop = 1.0,
        zoom = 0,
        padding = 0,
        opacity = 1.0,
    }
end

local function GetTrackedBarSettings()
    local db = GetDB()
    if db and db.trackedBar then
        return db.trackedBar
    end
    -- Return defaults if no DB
    return {
        enabled = true,
        barHeight = 24,
        barWidth = 200,
        texture = "Suavitex v3",
        useClassColor = true,
        barColor = {0.204, 0.827, 0.6, 1},
        borderSize = 1,
        bgColor = {0, 0, 0, 1},
        bgOpacity = 0.7,
        textSize = 12,
        spacing = 4,
        growUp = true,
        -- Vertical bar settings
        orientation = "horizontal",
        fillDirection = "up",
        iconPosition = "top",
    }
end

local function IsCustomBarsActive()
    local settings = GetTrackedBarSettings()
    return USE_CUSTOM_BARS and settings and settings.enabled ~= false
end

local function IsCustomIconsActive()
    local settings = GetBuffSettings()
    return USE_CUSTOM_ICONS and settings and settings.enabled ~= false
end

---------------------------------------------------------------------------
-- ALPHA ENFORCER (QUI pattern: cdm_spelldata.lua:141-153)
-- Keeps viewer alpha=0 every frame when custom styling is active.
-- Blizzard's CDM system may restore alpha via UpdateShownState; this
-- catches it immediately. Disabled during Edit Mode so viewers are visible.
---------------------------------------------------------------------------
local alphaEnforcerActive = false
local alphaEnforcerFrame = CreateFrame("Frame")
alphaEnforcerFrame:SetScript("OnUpdate", function()
    if not alphaEnforcerActive then return end
    if IsCustomBarsActive() then
        local v = _G["BuffBarCooldownViewer"]
        if v then
            local ok, alpha = pcall(v.GetAlpha, v)
            if ok and alpha and alpha > 0 then
                pcall(v.SetAlpha, v, 0)
            end
        end
    end
    if IsCustomIconsActive() then
        local v = _G["BuffIconCooldownViewer"]
        if v then
            local ok, alpha = pcall(v.GetAlpha, v)
            if ok and alpha and alpha > 0 then
                pcall(v.SetAlpha, v, 0)
            end
        end
    end
end)

local function UpdateOwnershipExports()
    if FORCE_DISABLE_CDM_BUFFBAR then
        SUI_BuffBar.USE_CUSTOM_BARS = false
        SUI_BuffBar.USE_CUSTOM_ICONS = false
        return
    end
    SUI_BuffBar.USE_CUSTOM_BARS = IsCustomBarsActive()
    SUI_BuffBar.USE_CUSTOM_ICONS = IsCustomIconsActive()
end

---------------------------------------------------------------------------
-- FORWARD DECLARATIONS
---------------------------------------------------------------------------

local LayoutBuffIcons
local LayoutBuffBars

---------------------------------------------------------------------------
-- RE-ENTRY GUARDS: Prevent recursive layout calls
---------------------------------------------------------------------------

local isIconLayoutRunning = false
local isBarLayoutRunning = false

---------------------------------------------------------------------------
-- ARCHITECTURE NOTES:
-- - Hash-based change detection: only layout when count OR settings change
-- - Direct centering: immediate layout on count change (no debounce)
-- - 0.05s polling rate (20 FPS) matches proven stable implementations
-- - Per-icon OnShow hooks REMOVED - they caused cascade during rapid changes
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- LAYOUT SUPPRESSION: Prevents recursive layout calls from our own SetSize()
---------------------------------------------------------------------------

local layoutSuppressed = 0

local function SuppressLayout()
    layoutSuppressed = layoutSuppressed + 1
end

local function UnsuppressLayout()
    layoutSuppressed = math.max(0, layoutSuppressed - 1)
end

local function IsLayoutSuppressed()
    return layoutSuppressed > 0
end

---------------------------------------------------------------------------
-- CUSTOM BUFF BAR SYSTEM (Option C Phase 1)
-- Replaces Blizzard's BuffBarCooldownViewer children with our own frames.
-- WHY: Blizzard's viewer children can have secret-value fields that crash
-- their OnUpdate/RefreshData (WoW 12.x). Our custom bars read clean data
-- from C_CooldownViewer + C_UnitAuras APIs — no hooks on Blizzard frames.
-- The Blizzard viewer frame is kept alive for:
--   - GetCooldownIDs() (spell categorization / CDM assignment)
--   - Edit Mode positioning (LibEQOL registration)
-- Our custom container is parented to UIParent and positioned via anchor
-- to the viewer, so it follows Edit Mode repositioning but is NOT affected
-- by the viewer's alpha (which we set to 0 to hide Blizzard's children).
---------------------------------------------------------------------------

USE_CUSTOM_BARS = false  -- Legacy path is taint-safe now: viewer field writes
-- (isHorizontal, layoutFramesGoingRight, layoutFramesGoingUp) were removed in
-- session 4979. Legacy path skins Blizzard's children in place using C API calls
-- (SetSize, SetPoint, SetFrameStrata, ApplyBarStyle) — no Lua field writes.
-- Viewer stays visible; Blizzard manages data, we only apply visual styling.
local customContainer          -- Frame: SuaviBuffBarContainer (created lazily)
local customBarPool = {}       -- All created bar frames (recycled via ._inUse)
local activeCustomBars = {}    -- Currently visible custom bar frames
local customBarNameCounter = 0

-- TAINT-FIX: track hook/state flags as module-level variables instead of as fields on
-- Blizzard's CooldownViewer frames. Writing _any_ field to a Blizzard frame from addon
-- code taints it, causing all Blizzard reads of that frame's properties to be
-- "secret values tainted by SuaviUI" which crashes Blizzard's secure functions.
local iconViewerHooked    = false
local iconViewerElapsed   = 0
local barViewerHooked     = false
local barViewerElapsed    = 0
local iconAuraHook        = nil   -- event-frame for UNIT_AURA
local iconRescanPending   = false

local function EnsureCooldownViewerLoaded()
    if InCombatLockdown() then return end
    pcall(function()
        if IsAddOnLoaded and UIParentLoadAddOn then
            if not IsAddOnLoaded("Blizzard_CooldownViewer") then
                UIParentLoadAddOn("Blizzard_CooldownViewer")
            end
        end
    end)
    pcall(function()
        if SetCVar then
            SetCVar("cooldownViewerEnabled", 1)
        end
    end)
end

-- Lazily create the container (parented to UIParent, anchored to viewer)
local function GetOrCreateContainer()
    if customContainer then return customContainer end
    local viewer = SafeGetViewer("BuffBarCooldownViewer")
    if not viewer then return nil end

    customContainer = CreateFrame("Frame", "SuaviBuffBarContainer", UIParent)
    customContainer:SetPoint("CENTER", viewer, "CENTER", 0, 0)
    -- TAINT-FIX (session 4986): Use settings defaults instead of querying viewer
    local barSettings = GetTrackedBarSettings()
    customContainer:SetSize(barSettings.barWidth or 200, barSettings.barHeight or 24)
    customContainer:Show()
    return customContainer
end

-- Create a bar frame that mimics Blizzard's hierarchy for ApplyBarStyle compat
-- Structure: frame.Bar (StatusBar), frame.Icon (Frame → .Icon texture)
local function CreateCustomBarFrame()
    local container = GetOrCreateContainer()
    if not container then return nil end

    customBarNameCounter = customBarNameCounter + 1
    local frame = CreateFrame("Frame", "SuaviBuffBar" .. customBarNameCounter, container)
    frame:SetSize(200, 24)

    -- StatusBar (ApplyBarStyle looks for frame.Bar)
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetAllPoints()
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    frame.Bar = bar

    -- Name text (on the StatusBar so ApplyBarStyle's FontString scan finds it)
    local nameText = bar:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(GetGeneralFont(), 11, GetGeneralFontOutline())
    nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    frame._nameText = nameText

    -- Time text
    local timeText = bar:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(GetGeneralFont(), 11, GetGeneralFontOutline())
    timeText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timeText:SetJustifyH("RIGHT")
    frame._timeText = timeText

    -- Icon container (ApplyBarStyle looks for frame.Icon → .Icon texture)
    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetSize(24, 24)
    iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.Icon = iconFrame

    local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconFrame.Icon = iconTex

    -- Marker for identification
    frame._isCustomBar = true
    SUI_trackedBarStyled[frame] = false

    frame:Hide()
    return frame
end

local function AcquireCustomBar()
    for _, bar in ipairs(customBarPool) do
        if not bar._inUse then
            bar._inUse = true
            return bar
        end
    end
    local bar = CreateCustomBarFrame()
    if not bar then return nil end
    bar._inUse = true
    customBarPool[#customBarPool + 1] = bar
    return bar
end

local function ReleaseAllCustomBars()
    for _, bar in ipairs(customBarPool) do
        bar._inUse = false
        bar:Hide()
    end
    activeCustomBars = {}
end

local function FormatTimeRemaining(remaining)
    if not remaining or remaining <= 0 then return "" end
    if remaining >= 60 then
        return string.format("%d:%02d", floor(remaining / 60), floor(remaining % 60))
    elseif remaining >= 10 then
        return string.format("%d", floor(remaining))
    else
        return string.format("%.1f", remaining)
    end
end

-- Read cooldownIDs for tracked bars using C API only.
-- TAINT-FIX (session 4927): The provider path (GetOrderedCooldownIDsForCategory) internally
-- calls CheckBuildDisplayData() at CooldownViewerSettingsDataProvider.lua:243. Running that
-- from addon (tainted) context taints the shared CDM data provider, which Blizzard's
-- RefreshData() then reads — writing tainted isActive/spellID/charges to ALL viewer item
-- frames, causing "secret value" errors across all CDM viewers. Use C API only.
-- Aura lookup in FetchBuffBarData acts as the active filter.
local function GetViewerCooldownIDs()
    local ok, result = pcall(function()
        if C_CooldownViewer then
            if C_CooldownViewer.GetCooldownViewerCategorySet then
                return C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBar, true)
            elseif C_CooldownViewer.GetCooldownIDsForCategory then
                return C_CooldownViewer.GetCooldownIDsForCategory(Enum.CooldownViewerCategory.TrackedBar)
            end
        end
        return nil
    end)
    if ok and type(result) == "table" then return result end
    return {}
end

---------------------------------------------------------------------------
-- VIEWER CHILDREN DATA PATH (QUI "owned engine" pattern)
-- Reads Blizzard's viewer children as the source of truth for active state.
-- child:IsShown() gives Blizzard's ShouldBeActive() result directly,
-- eliminating manual aura detection. Sub-region reads (GetValue, GetTexture)
-- are C API widget methods — safe from addon code, no taint.
-- Returns nil if viewer is hidden or has no shown children → caller falls
-- through to C API path.
---------------------------------------------------------------------------
local function TryFetchFromChildren(viewer)
    -- Try to read viewer children regardless of viewer shown state.
    -- When viewer is shown (alpha=0, IsShown=true), Blizzard's OnUpdate keeps
    -- children current. When viewer is hidden (visibility≠"Always"), children
    -- may have stale data from their last active state — still useful for spell
    -- identity, and our progress update cycle handles expiration.
    local results = {}
    pcall(function()
        local children = { viewer:GetChildren() }
        local now = GetTime()
        for idx, child in ipairs(children) do
            if child:IsShown() then
                -- Read spell identity from Blizzard's cooldownInfo struct
                local spellID = nil
                if child.cooldownInfo then
                    spellID = child.cooldownInfo.overrideSpellID or child.cooldownInfo.spellID
                end
                if spellID then
                    -- Read bar progress from StatusBar sub-region (C API)
                    local duration, remaining = 0, 0
                    local bar = child.Bar or child.bar
                    if bar then
                        pcall(function()
                            local _, maxVal = bar:GetMinMaxValues()
                            if maxVal then duration = maxVal end
                            remaining = bar:GetValue() or 0
                        end)
                    end
                    -- If bar sub-region didn't have data, try aura lookup
                    if duration == 0 then
                        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                        if aura and aura.duration and aura.duration > 0 then
                            duration = aura.duration
                            remaining = (aura.expirationTime or now) - now
                        end
                    end
                    -- Infinite aura sentinel (duration=0 means permanent buff)
                    local expTime
                    if duration == 0 then
                        duration = 86400      -- 24h sentinel
                        expTime = now + duration
                    else
                        expTime = now + math.max(0, remaining)
                    end
                    -- Texture from sub-region (C API) or spell API
                    local texture = nil
                    local iconTex = child.Icon or child.icon
                    if iconTex then
                        pcall(function() texture = iconTex:GetTexture() end)
                    end
                    if not texture then
                        pcall(function() texture = C_Spell.GetSpellTexture(spellID) end)
                    end

                    results[#results + 1] = {
                        spellID        = spellID,
                        layoutIndex    = child.layoutIndex or idx,
                        name           = C_Spell.GetSpellName(spellID) or "",
                        texture        = texture,
                        duration       = duration,
                        expirationTime = expTime,
                    }
                end
            end
        end
    end)
    -- Accept partial results even if pcall failed midway
    if #results > 0 then return results end
    return nil  -- Fall through to C API
end

-- Fetch active aura data — hybrid: viewer children (preferred) + C API fallback
local function FetchBuffBarData()
    -- PATH 1: Viewer children (preferred) — reads Blizzard's active state directly.
    -- child:IsShown() = Blizzard's ShouldBeActive() result. Eliminates manual aura
    -- detection edge cases. Only available when viewer is shown (OnUpdate running).
    local viewer = SafeGetViewer("BuffBarCooldownViewer")
    if viewer then
        local childrenResult = TryFetchFromChildren(viewer)
        if childrenResult then return childrenResult end
    end

    -- PATH 2 (C API fallback): Works when viewer is hidden (visibility="Hidden"
    -- or "InCombat" out of combat). Uses C_CooldownViewer for configuration data
    -- then manual aura/totem lookup for active state detection.

    local srcFrames = nil

    -- PRIMARY: C API data provider. GetViewerCooldownIDs() returns ALL configured
    -- spell IDs (active or not), so aura data below acts as the active filter.
    local cooldownIDs = GetViewerCooldownIDs()
    if #cooldownIDs == 0 then return {} end
    srcFrames = {}
    for layoutIdx, cdID in ipairs(cooldownIDs) do
        srcFrames[#srcFrames + 1] = {
            cooldownID  = cdID,
            layoutIndex = layoutIdx,
        }
    end

    table.sort(srcFrames, function(a, b) return a.layoutIndex < b.layoutIndex end)

    -- Pre-fetch target debuffs once for the whole batch.
    -- BuffBarCooldownViewer tracks both player buffs (HoTs) AND target debuffs (DoTs).
    local targetAuras = {}
    pcall(function()
        targetAuras = C_UnitAuras.GetUnitAuras("target", "HARMFUL|PLAYER") or {}
    end)

    local results = {}
    local now = GetTime()
    for _, src in ipairs(srcFrames) do
        -- GetCooldownViewerCooldownInfo returns CooldownViewerCooldown struct.
        -- SecretArguments="AllowedWhenUntainted" → safe from addon (untainted) context.
        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, src.cooldownID)
        if ok and info then
            -- Collect ALL associated spell IDs (matches Blizzard's GetSpellID priority chain).
            -- Blizzard checks: auraSpellID > linkedSpellID > overrideTooltipSpellID > overrideSpellID > spellID.
            -- We don't have auraSpellID (runtime state), so start from linkedSpellIDs.
            local primarySpellID = info.overrideSpellID or info.spellID
            local allSpellIDs = {}
            pcall(function()
                -- linkedSpellIDs first (highest priority for aura matching)
                if type(info.linkedSpellIDs) == "table" then
                    for _, lID in ipairs(info.linkedSpellIDs) do
                        allSpellIDs[#allSpellIDs + 1] = lID
                    end
                end
                -- Then primary spell ID
                if primarySpellID then
                    allSpellIDs[#allSpellIDs + 1] = primarySpellID
                end
                -- Also base spellID if different from override
                if info.overrideSpellID and info.spellID and info.spellID ~= info.overrideSpellID then
                    allSpellIDs[#allSpellIDs + 1] = info.spellID
                end
            end)
            if #allSpellIDs == 0 and primarySpellID then
                allSpellIDs[1] = primarySpellID
            end

            if #allSpellIDs > 0 then
                local auraResult = {}
                pcall(function()
                    local auraData = nil

                    -- 1. Player aura: try ALL associated spell IDs
                    for _, sid in ipairs(allSpellIDs) do
                        auraData = C_UnitAuras.GetPlayerAuraBySpellID(sid)
                        if auraData then break end
                    end

                    -- 2. Target debuffs: match by ANY associated spell ID
                    if not auraData then
                        for _, aura in ipairs(targetAuras) do
                            for _, sid in ipairs(allSpellIDs) do
                                if aura.spellId == sid then
                                    auraData = aura
                                    break
                                end
                            end
                            if auraData then break end
                        end
                    end

                    -- 3. Totem detection (shaman totems have no aura on player/target)
                    if not auraData and C_Totem then
                        for slot = 1, 5 do
                            local haveTotem, name, startTime, duration, icon = C_Totem.GetTotemInfo(slot)
                            if haveTotem and duration and duration > 0 then
                                -- C_Totem doesn't expose spellID directly; match by spell name
                                for _, sid in ipairs(allSpellIDs) do
                                    local spellName = C_Spell.GetSpellName(sid)
                                    if spellName and spellName == name then
                                        auraData = {
                                            name = name,
                                            icon = icon,
                                            duration = duration,
                                            expirationTime = startTime + duration,
                                            spellId = sid,
                                        }
                                        break
                                    end
                                end
                                if auraData then break end
                            end
                        end
                    end

                    -- 4. Cooldown detection (abilities tracked by cooldown, not aura)
                    if not auraData and C_Spell and C_Spell.GetSpellCooldown then
                        for _, sid in ipairs(allSpellIDs) do
                            local cdOk, cdInfo = pcall(C_Spell.GetSpellCooldown, sid)
                            if cdOk and cdInfo and cdInfo.duration and cdInfo.duration > 1.5 then
                                -- duration > 1.5 filters out GCD (1.5s). Only real cooldowns.
                                auraData = {
                                    name = C_Spell.GetSpellName(sid) or "",
                                    icon = C_Spell.GetSpellTexture(sid),
                                    duration = cdInfo.duration,
                                    expirationTime = cdInfo.startTime + cdInfo.duration,
                                    spellId = sid,
                                }
                                break
                            end
                        end
                    end

                    -- 5. Charge detection (abilities with charges on cooldown)
                    if not auraData and C_Spell and C_Spell.GetSpellCharges then
                        for _, sid in ipairs(allSpellIDs) do
                            local chOk, chInfo = pcall(C_Spell.GetSpellCharges, sid)
                            if chOk and chInfo and chInfo.currentCharges ~= nil then
                                if chInfo.maxCharges and chInfo.currentCharges < chInfo.maxCharges
                                    and chInfo.cooldownDuration and chInfo.cooldownDuration > 0 then
                                    auraData = {
                                        name = C_Spell.GetSpellName(sid) or "",
                                        icon = C_Spell.GetSpellTexture(sid),
                                        duration = chInfo.cooldownDuration,
                                        expirationTime = chInfo.cooldownStartTime + chInfo.cooldownDuration,
                                        spellId = sid,
                                    }
                                    break
                                end
                            end
                        end
                    end

                    -- Accept aura if active. Blizzard's ShouldBeActive logic:
                    -- expirationTime == 0 (infinite) OR expirationTime > GetTime()
                    if auraData then
                        local isActive = (auraData.expirationTime == 0)
                            or (auraData.expirationTime and auraData.expirationTime > now)
                        if isActive then
                            local displaySpellID = primarySpellID or allSpellIDs[1]
                            local texture = auraData.icon
                            if not texture and displaySpellID then
                                local texOk, tex = pcall(C_Spell.GetSpellTexture, displaySpellID)
                                if texOk then texture = tex end
                            end
                            -- For infinite auras (duration=0), use a large sentinel so bar renders full
                            local dur = auraData.duration or 0
                            local expTime = auraData.expirationTime or 0
                            if dur == 0 and expTime == 0 then
                                dur = 86400      -- 24h sentinel
                                expTime = now + dur
                            end
                            auraResult = {
                                cooldownID     = src.cooldownID,
                                spellID        = displaySpellID,
                                layoutIndex    = src.layoutIndex,
                                name           = auraData.name or "",
                                texture        = texture,
                                duration       = dur,
                                expirationTime = expTime,
                            }
                        end
                    end
                end)
                if auraResult.cooldownID then
                    results[#results + 1] = auraResult
                end
            end
        end
    end

    return results
end

-- Reconcile custom bars with current aura data
-- Creates/removes bars as needed, sets icon textures and initial progress
local function UpdateCustomBarData()
    if not IsCustomBarsActive() then return {} end
    if not GetOrCreateContainer() then return {} end

    local data = FetchBuffBarData()
    local now = GetTime()

    ReleaseAllCustomBars()

    for _, aura in ipairs(data) do
        local bar = AcquireCustomBar()
        if not bar then break end

        bar.cooldownID  = aura.cooldownID
        bar.layoutIndex = aura.layoutIndex
        bar._auraData   = aura

        -- Icon texture
        if bar.Icon and bar.Icon.Icon and aura.texture then
            bar.Icon.Icon:SetTexture(aura.texture)
        end
        bar.Icon:Show()

        -- Bar progress
        local remaining = math.max(0, aura.expirationTime - now)
        bar.Bar:SetMinMaxValues(0, aura.duration)
        bar.Bar:SetValue(remaining)

        -- Text
        if bar._nameText then bar._nameText:SetText(aura.name) end
        if bar._timeText then bar._timeText:SetText(FormatTimeRemaining(remaining)) end

        bar:Show()
        activeCustomBars[#activeCustomBars + 1] = bar
    end

    return activeCustomBars
end

-- Smooth animation: update bar fill + time text every tick (called from OnUpdate)
local function UpdateCustomBarProgress()
    local now = GetTime()
    for _, bar in ipairs(activeCustomBars) do
        local aura = bar._auraData
        if aura then
            local remaining = math.max(0, aura.expirationTime - now)
            if remaining <= 0 then
                bar:Hide()
            else
                bar.Bar:SetValue(remaining)
                if bar._timeText then
                    bar._timeText:SetText(FormatTimeRemaining(remaining))
                end
            end
        end
    end
end

-- Hide Blizzard's viewer children, show it during Edit Mode for positioning
local function SetViewerHidden(hide)
    local viewer = SafeGetViewer("BuffBarCooldownViewer")
    if not viewer then return end
    if hide then
        pcall(function() viewer:SetAlpha(0) end)
        if not InCombatLockdown() then
            pcall(function() viewer:EnableMouse(false) end)
        end
    else
        pcall(function() viewer:SetAlpha(1) end)
        -- Do NOT enable mouse here — that makes the viewer block camera-drag clicks
        -- when empty/invisible (Bug 2). Mouse is re-enabled explicitly in EditMode.Enter.
        if not InCombatLockdown() then
            pcall(function() viewer:EnableMouse(false) end)
        end
    end
end

---------------------------------------------------------------------------
-- CUSTOM BUFF ICON SYSTEM (Option C Phase 2)
-- Same pattern as Custom Buff Bars: replaces Blizzard's BuffIconCooldownViewer
-- children with our own frames. Data pipeline: C_CooldownViewer + C_UnitAuras.
-- Blizzard viewer kept alive for GetCooldownIDs() and Edit Mode positioning.
---------------------------------------------------------------------------

USE_CUSTOM_ICONS = false  -- Legacy path: skin Blizzard's icon children in place (same as bars)
local customIconContainer       -- Frame: SuaviBuffIconContainer (created lazily)
local customIconPool = {}       -- All created icon frames (recycled via ._inUse)
local activeCustomIcons = {}    -- Currently visible custom icon frames
local customIconNameCounter = 0

local function GetOrCreateIconContainer()
    if customIconContainer then return customIconContainer end
    local viewer = SafeGetViewer("BuffIconCooldownViewer")
    if not viewer then return nil end

    customIconContainer = CreateFrame("Frame", "SuaviBuffIconContainer", UIParent)
    customIconContainer:SetPoint("CENTER", viewer, "CENTER", 0, 0)
    -- TAINT-FIX (session 4986): Use settings defaults instead of querying viewer
    local iconSettings = GetBuffSettings()
    local iconSz = iconSettings.iconSize or 42
    customIconContainer:SetSize(iconSz, iconSz)
    customIconContainer:Show()
    return customIconContainer
end

-- Create icon frame compatible with ApplyIconStyle
-- Structure: frame.Icon (texture), frame.Cooldown (overlay), frame.Applications (stacks)
local function CreateCustomIconFrame()
    local container = GetOrCreateIconContainer()
    if not container then return nil end

    customIconNameCounter = customIconNameCounter + 1
    local frame = CreateFrame("Button", "SuaviBuffIcon" .. customIconNameCounter, container)
    frame:SetSize(42, 42)

    -- Main texture (ApplyIconStyle processes frame.Icon)
    local tex = frame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.Icon = tex

    -- Cooldown overlay
    local cd = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetDrawSwipe(false)
    cd:SetDrawEdge(false)
    frame.Cooldown = cd

    -- Stack count (mimics Blizzard's Applications structure for ApplyIconStyle compat)
    local apps = CreateFrame("Frame", nil, frame)
    apps:SetAllPoints()
    local countFS = apps:CreateFontString(nil, "OVERLAY")
    countFS:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    countFS:SetFont(GetGeneralFont(), 12, GetGeneralFontOutline())
    countFS:SetJustifyH("RIGHT")
    frame.Applications = apps

    -- Mark as custom (skip Blizzard-specific cleanup in SetupIconOnce)
    frame._isCustomIcon = true
    SUI_buffSetup[frame] = true  -- Skip SetupIconOnce's mask/overlay removal

    frame:Hide()
    return frame
end

local function AcquireCustomIcon()
    for _, icon in ipairs(customIconPool) do
        if not icon._inUse then
            icon._inUse = true
            return icon
        end
    end
    local icon = CreateCustomIconFrame()
    if not icon then return nil end
    icon._inUse = true
    customIconPool[#customIconPool + 1] = icon
    return icon
end

local function ReleaseAllCustomIcons()
    for _, icon in ipairs(customIconPool) do
        icon._inUse = false
        icon:Hide()
    end
    activeCustomIcons = {}
end

-- Read cooldownIDs for tracked buffs (icons) using C API only.
-- TAINT-FIX (session 4927): Same as GetViewerCooldownIDs — provider path internally calls
-- CheckBuildDisplayData() which taints the shared CDM data provider from addon context.
-- Aura lookup in FetchBuffIconData acts as the active filter.
local function GetIconViewerCooldownIDs()
    local ok, result = pcall(function()
        if C_CooldownViewer then
            if C_CooldownViewer.GetCooldownViewerCategorySet then
                return C_CooldownViewer.GetCooldownViewerCategorySet(Enum.CooldownViewerCategory.TrackedBuff, true)
            elseif C_CooldownViewer.GetCooldownIDsForCategory then
                return C_CooldownViewer.GetCooldownIDsForCategory(Enum.CooldownViewerCategory.TrackedBuff)
            end
        end
        return nil
    end)
    if ok and type(result) == "table" then return result end
    return {}
end

-- Viewer children path for icons (same pattern as TryFetchFromChildren for bars).
-- Reads CooldownFrame sub-region for cooldown timing, and aura for stack count.
local function TryFetchIconsFromChildren(viewer)
    local results = {}
    pcall(function()
        local children = { viewer:GetChildren() }
        local now = GetTime()
        for idx, child in ipairs(children) do
            if child:IsShown() then
                local spellID = nil
                if child.cooldownInfo then
                    spellID = child.cooldownInfo.overrideSpellID or child.cooldownInfo.spellID
                end
                if spellID then
                    -- Read cooldown from CooldownFrame sub-region (C API)
                    local duration, expTime = 0, 0
                    local cd = child.Cooldown or child.cooldown
                    if cd then
                        pcall(function()
                            local startMs, durMs = cd:GetCooldownTimes()
                            if startMs and durMs and durMs > 0 then
                                duration = durMs / 1000
                                expTime = (startMs + durMs) / 1000
                            end
                        end)
                    end
                    -- If CooldownFrame didn't have data, try aura lookup
                    if duration == 0 then
                        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                        if aura and aura.duration and aura.duration > 0 then
                            duration = aura.duration
                            expTime = aura.expirationTime or (now + duration)
                        end
                    end
                    -- Infinite aura sentinel
                    if duration == 0 then
                        duration = 86400
                        expTime = now + duration
                    end
                    -- Texture from sub-region or spell API
                    local texture = nil
                    local iconTex = child.Icon or child.icon
                    if iconTex then
                        pcall(function() texture = iconTex:GetTexture() end)
                    end
                    if not texture then
                        pcall(function() texture = C_Spell.GetSpellTexture(spellID) end)
                    end
                    -- Stack count from aura lookup
                    local applications = 0
                    local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
                    if aura then applications = aura.applications or 0 end

                    results[#results + 1] = {
                        spellID        = spellID,
                        layoutIndex    = child.layoutIndex or idx,
                        name           = C_Spell.GetSpellName(spellID) or "",
                        texture        = texture,
                        duration       = duration,
                        expirationTime = expTime,
                        applications   = applications,
                    }
                end
            end
        end
    end)
    if #results > 0 then return results end
    return nil
end

-- Fetch active icon aura data — hybrid: viewer children (preferred) + C API fallback
local function FetchBuffIconData()
    -- PATH 1: Viewer children (preferred) — same as FetchBuffBarData
    local viewer = SafeGetViewer("BuffIconCooldownViewer")
    if viewer then
        local childrenResult = TryFetchIconsFromChildren(viewer)
        if childrenResult then return childrenResult end
    end

    -- PATH 2 (C API fallback): Works when viewer is hidden
    local cooldownIDs = GetIconViewerCooldownIDs()
    if #cooldownIDs == 0 then return {} end
    local srcFrames = {}
    for layoutIdx, cdID in ipairs(cooldownIDs) do
        srcFrames[#srcFrames + 1] = {
            cooldownID  = cdID,
            layoutIndex = layoutIdx,
        }
    end

    table.sort(srcFrames, function(a, b) return a.layoutIndex < b.layoutIndex end)

    -- Pre-fetch target debuffs once for the whole batch.
    local targetAuras = {}
    pcall(function()
        targetAuras = C_UnitAuras.GetUnitAuras("target", "HARMFUL|PLAYER") or {}
    end)

    local results = {}
    local now = GetTime()
    for _, src in ipairs(srcFrames) do
        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, src.cooldownID)
        if ok and info then
            -- Collect ALL associated spell IDs (same pattern as FetchBuffBarData)
            local primarySpellID = info.overrideSpellID or info.spellID
            local allSpellIDs = {}
            pcall(function()
                if type(info.linkedSpellIDs) == "table" then
                    for _, lID in ipairs(info.linkedSpellIDs) do
                        allSpellIDs[#allSpellIDs + 1] = lID
                    end
                end
                if primarySpellID then
                    allSpellIDs[#allSpellIDs + 1] = primarySpellID
                end
                if info.overrideSpellID and info.spellID and info.spellID ~= info.overrideSpellID then
                    allSpellIDs[#allSpellIDs + 1] = info.spellID
                end
            end)
            if #allSpellIDs == 0 and primarySpellID then
                allSpellIDs[1] = primarySpellID
            end

            if #allSpellIDs > 0 then
                local auraResult = {}
                pcall(function()
                    local auraData = nil

                    -- 1. Player aura: try ALL associated spell IDs
                    for _, sid in ipairs(allSpellIDs) do
                        auraData = C_UnitAuras.GetPlayerAuraBySpellID(sid)
                        if auraData then break end
                    end

                    -- 2. Target debuffs: match by ANY associated spell ID
                    if not auraData then
                        for _, aura in ipairs(targetAuras) do
                            for _, sid in ipairs(allSpellIDs) do
                                if aura.spellId == sid then
                                    auraData = aura
                                    break
                                end
                            end
                            if auraData then break end
                        end
                    end

                    -- 3. Totem detection
                    if not auraData and C_Totem then
                        for slot = 1, 5 do
                            local haveTotem, name, startTime, duration, icon = C_Totem.GetTotemInfo(slot)
                            if haveTotem and duration and duration > 0 then
                                for _, sid in ipairs(allSpellIDs) do
                                    local spellName = C_Spell.GetSpellName(sid)
                                    if spellName and spellName == name then
                                        auraData = {
                                            name = name,
                                            icon = icon,
                                            duration = duration,
                                            expirationTime = startTime + duration,
                                            spellId = sid,
                                            applications = 0,
                                        }
                                        break
                                    end
                                end
                                if auraData then break end
                            end
                        end
                    end

                    -- 4. Cooldown detection (abilities tracked by cooldown, not aura)
                    if not auraData and C_Spell and C_Spell.GetSpellCooldown then
                        for _, sid in ipairs(allSpellIDs) do
                            local cdOk, cdInfo = pcall(C_Spell.GetSpellCooldown, sid)
                            if cdOk and cdInfo and cdInfo.duration and cdInfo.duration > 1.5 then
                                auraData = {
                                    name = C_Spell.GetSpellName(sid) or "",
                                    icon = C_Spell.GetSpellTexture(sid),
                                    duration = cdInfo.duration,
                                    expirationTime = cdInfo.startTime + cdInfo.duration,
                                    spellId = sid,
                                    applications = 0,
                                }
                                break
                            end
                        end
                    end

                    -- 5. Charge detection (abilities with charges on cooldown)
                    if not auraData and C_Spell and C_Spell.GetSpellCharges then
                        for _, sid in ipairs(allSpellIDs) do
                            local chOk, chInfo = pcall(C_Spell.GetSpellCharges, sid)
                            if chOk and chInfo and chInfo.currentCharges ~= nil then
                                if chInfo.maxCharges and chInfo.currentCharges < chInfo.maxCharges
                                    and chInfo.cooldownDuration and chInfo.cooldownDuration > 0 then
                                    auraData = {
                                        name = C_Spell.GetSpellName(sid) or "",
                                        icon = C_Spell.GetSpellTexture(sid),
                                        duration = chInfo.cooldownDuration,
                                        expirationTime = chInfo.cooldownStartTime + chInfo.cooldownDuration,
                                        spellId = sid,
                                        applications = chInfo.currentCharges,
                                    }
                                    break
                                end
                            end
                        end
                    end

                    -- Accept if active (expirationTime == 0 for infinite, or > now)
                    if auraData then
                        local isActive = (auraData.expirationTime == 0)
                            or (auraData.expirationTime and auraData.expirationTime > now)
                        if isActive then
                            local displaySpellID = primarySpellID or allSpellIDs[1]
                            local texture = auraData.icon
                            if not texture and displaySpellID then
                                local texOk, tex = pcall(C_Spell.GetSpellTexture, displaySpellID)
                                if texOk then texture = tex end
                            end
                            auraResult = {
                                cooldownID     = src.cooldownID,
                                spellID        = displaySpellID,
                                layoutIndex    = src.layoutIndex,
                                name           = auraData.name or "",
                                texture        = texture,
                                duration       = auraData.duration or 0,
                                expirationTime = auraData.expirationTime or 0,
                                applications   = auraData.applications or 0,
                            }
                        end
                    end
                end)
                if auraResult.cooldownID then
                    results[#results + 1] = auraResult
                end
            end
        end
    end

    return results
end

-- Reconcile custom icons with current aura data
local function UpdateCustomIconData()
    if not IsCustomIconsActive() then return {} end
    if not GetOrCreateIconContainer() then return {} end

    local data = FetchBuffIconData()

    ReleaseAllCustomIcons()

    for _, aura in ipairs(data) do
        local icon = AcquireCustomIcon()
        if not icon then break end

        icon.cooldownID  = aura.cooldownID
        icon.layoutIndex = aura.layoutIndex
        icon._auraData   = aura

        -- Icon texture
        if icon.Icon and aura.texture then
            icon.Icon:SetTexture(aura.texture)
        end

        -- Cooldown overlay
        if icon.Cooldown then
            if aura.duration and aura.duration > 0 and aura.expirationTime then
                local startTime = aura.expirationTime - aura.duration
                icon.Cooldown:SetCooldown(startTime, aura.duration)
            else
                icon.Cooldown:Clear()
            end
        end

        -- Stack count
        if icon.Applications then
            for _, region in ipairs({ icon.Applications:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    if aura.applications and aura.applications > 1 then
                        region:SetText(aura.applications)
                        region:Show()
                    else
                        region:SetText("")
                        region:Hide()
                    end
                    break
                end
            end
        end

        icon:Show()
        activeCustomIcons[#activeCustomIcons + 1] = icon
    end

    return activeCustomIcons
end

-- Hide/show Blizzard's BuffIcon viewer
local function SetIconViewerHidden(hide)
    local viewer = SafeGetViewer("BuffIconCooldownViewer")
    if not viewer then return end
    if hide then
        pcall(function() viewer:SetAlpha(0) end)
        if not InCombatLockdown() then
            pcall(function() viewer:EnableMouse(false) end)
        end
    else
        pcall(function() viewer:SetAlpha(1) end)
        -- Do NOT enable mouse here — that makes the viewer block camera-drag clicks
        -- when empty/invisible (Bug 2). BuffIconCooldownViewer Edit Mode interaction
        -- is handled by the Blizzard edit mode system (UIParentBottomManagedFrameTemplate).
        if not InCombatLockdown() then
            pcall(function() viewer:EnableMouse(false) end)
        end
    end
end

---------------------------------------------------------------------------
-- ICON FRAME COLLECTION
---------------------------------------------------------------------------

local function GetBuffIconFrames()
    -- Custom icons: return our own frames (no Blizzard frame dependency)
    if IsCustomIconsActive() then
        return activeCustomIcons
    end

    if not BuffIconCooldownViewer then
        return {}
    end

    local all = {}

    pcall(function()
        for _, child in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
            if child then
                -- Skip Selection frame (Edit Mode)
                if child == BuffIconCooldownViewer.Selection then
                    -- Skip
                else
                    local hasIcon = child.icon or child.Icon
                    local hasCooldown = child.cooldown or child.Cooldown

                    if hasIcon or hasCooldown then
                        table.insert(all, child)
                    end
                end
            end
        end
    end)

    table.sort(all, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    -- Only keep visible icons that have been fully initialized (have cooldownID)
    local visible = {}
    for _, icon in ipairs(all) do
        if icon:IsShown() and icon.cooldownID then
            table.insert(visible, icon)
        end
    end

    return visible
end

---------------------------------------------------------------------------
-- BAR FRAME COLLECTION
---------------------------------------------------------------------------

local function GetBuffBarFrames()
    -- Custom bars: return our own frames (no Blizzard frame dependency)
    if IsCustomBarsActive() then
        return activeCustomBars
    end

    -- Legacy path: collect from Blizzard viewer
    if not BuffBarCooldownViewer then
        return {}
    end

    local frames = {}

    -- First, try CooldownViewer API if present
    pcall(function()
        if BuffBarCooldownViewer.GetItemFrames then
            local ok, items = pcall(BuffBarCooldownViewer.GetItemFrames, BuffBarCooldownViewer)
            if ok and items then
                frames = items
            end
        end
    end)

    -- Fallback to raw children scan
    if #frames == 0 then
        local okc, children = pcall(BuffBarCooldownViewer.GetChildren, BuffBarCooldownViewer)
        if okc and children then
            for _, child in ipairs({ children }) do
                if child and child:IsObjectType("Frame") then
                    -- Skip Selection frame
                    pcall(function()
                        if child ~= BuffBarCooldownViewer.Selection then
                            table.insert(frames, child)
                        end
                    end)
                end
            end
        end
    end

    -- Filter to active/visible frames
    local active = {}
    for _, frame in ipairs(frames) do
        if frame:IsShown() and frame:IsVisible() then
            table.insert(active, frame)
        end
    end

    table.sort(active, function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)

    return active
end

---------------------------------------------------------------------------
-- HELPER: Strip Blizzard's overlay texture (the square artifact)
---------------------------------------------------------------------------

local function StripBlizzardOverlay(icon)
    if not icon or not icon.GetRegions then return end

    for _, region in ipairs({ icon:GetRegions() }) do
        if region:IsObjectType("Texture") then
            -- Check for the specific overlay atlas
            if region.GetAtlas then
                local atlas = region:GetAtlas()
                if atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                    region:SetTexture("")
                    region:Hide()
                    -- TAINT-FIX: hooksecurefunc preserves the original C Show as secure.
                    -- Don't call Hide() — causes Show→Hide→Show infinite loop.
                    if not SUI_overlayHooked[region] then
                        SUI_overlayHooked[region] = true
                        hooksecurefunc(region, "Show", function(self)
                            self:SetTexture("")
                            self:SetAlpha(0)
                        end)
                    end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- HELPER: Disable atlas-based border textures (debuff type colors, etc.)
-- Hooks SetAtlas to prevent Blizzard from re-applying borders on updates
---------------------------------------------------------------------------

local function DisableAtlasBorder(tex)
    if not tex then return end

    -- Immediately clear everything
    if tex.SetAtlas then tex:SetAtlas(nil) end
    if tex.SetTexture then tex:SetTexture(nil) end
    if tex.SetAlpha then tex:SetAlpha(0) end
    if tex.Hide then tex:Hide() end

    -- Hook to re-clear on future SetAtlas calls (Blizzard re-applies on buff updates)
    if tex.SetAtlas and not SUI_atlasDisabled[tex] then
        SUI_atlasDisabled[tex] = true
        hooksecurefunc(tex, "SetAtlas", function(self)
            C_Timer.After(0, function()
                -- Safety check in case texture was released before timer fires
                if not self or (self.IsForbidden and self:IsForbidden()) then return end
                -- Must also clear the atlas, not just texture/alpha
                pcall(function()
                    self:SetAtlas(nil)
                    self:SetTexture(nil)
                    self:SetAlpha(0)
                    self:Hide()
                end)
            end)
        end)
    end
end

---------------------------------------------------------------------------
-- HELPER: One-time icon setup (mask removal, overlay strip)
-- NOTE: Per-icon OnShow hooks removed - they caused cascade during rapid buff changes
-- Polling at 0.05s + viewer hooks handle detection efficiently
---------------------------------------------------------------------------

local function SetupIconOnce(icon)
    if SUI_buffSetup[icon] then return end

    -- Remove ALL of Blizzard's masks (they may have multiple)
    local textures = { icon.Icon, icon.icon, icon.texture, icon.Texture }
    for _, tex in ipairs(textures) do
        if tex and tex.GetMaskTexture then
            for i = 1, 10 do
                local mask = tex:GetMaskTexture(i)
                if mask then
                    tex:RemoveMaskTexture(mask)
                end
            end
        end
    end

    -- Hide any NormalTexture border that Blizzard adds
    if icon.NormalTexture then icon.NormalTexture:SetAlpha(0) end
    if icon.GetNormalTexture then
        local normalTex = icon:GetNormalTexture()
        if normalTex then normalTex:SetAlpha(0) end
    end

    -- Strip Blizzard's overlay texture
    StripBlizzardOverlay(icon)

    -- Disable aura type border textures (debuff colors, buff borders, enchant borders)
    DisableAtlasBorder(icon.DebuffBorder)
    DisableAtlasBorder(icon.BuffBorder)
    DisableAtlasBorder(icon.TempEnchantBorder)

    SUI_buffSetup[icon] = true
end

---------------------------------------------------------------------------
-- HELPER: Apply icon size, aspect ratio, border, and perfect square fix
---------------------------------------------------------------------------

local function ApplyIconStyle(icon, settings)
    if not icon then return end

    SetupIconOnce(icon)

    local size = settings.iconSize or 42
    
    -- Only apply square styling if enabled in settings
    local profile = SUICore and SUICore.db and SUICore.db.profile
    local squareIconsEnabled = profile and profile.cooldownManager_squareIcons_BuffIcons or false
    
    -- If square icons disabled, use circular aspect ratio (1.0 means circle, not square)
    local aspectRatio = squareIconsEnabled and (settings.aspectRatioCrop or 1.0) or 1.0
    local zoom = squareIconsEnabled and (settings.zoom or 0) or 0
    local borderSize = squareIconsEnabled and (settings.borderSize or 2) or 0

    -- Calculate dimensions using crop-based aspect ratio
    local width, height = size, size
    if aspectRatio > 1.0 then
        -- Wider: height shrinks
        height = size / aspectRatio
    elseif aspectRatio < 1.0 then
        -- Taller: width shrinks
        width = size * aspectRatio
    end

    icon:SetSize(width, height)

    -- Create or update border (using BACKGROUND texture to avoid secret value errors during combat)
    -- BackdropTemplate causes "arithmetic on secret value" crashes when frame is resized during combat
    if borderSize > 0 then
        if not SUI_buffBorder[icon] then
            SUI_buffBorder[icon] = icon:CreateTexture(nil, "BACKGROUND", nil, -8)
            SUI_buffBorder[icon]:SetColorTexture(0, 0, 0, 1)
        end

        SUI_buffBorder[icon]:ClearAllPoints()
        SUI_buffBorder[icon]:SetPoint("TOPLEFT", icon, "TOPLEFT", -borderSize, borderSize)
        SUI_buffBorder[icon]:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", borderSize, -borderSize)
        SUI_buffBorder[icon]:Show()
        SUI_buffBorderSize[icon] = borderSize
    else
        if SUI_buffBorder[icon] then
            SUI_buffBorder[icon]:Hide()
        end
        SUI_buffBorderSize[icon] = 0
    end

    -- Calculate texture coordinates (crop-based, no stretching)
    -- BASE_CROP always applied first to hide Blizzard's grey icon edges
    local BASE_CROP = 0.08
    local left, right, top, bottom = BASE_CROP, 1 - BASE_CROP, BASE_CROP, 1 - BASE_CROP

    -- Apply aspect ratio crop ON TOP of base crop (within the already-cropped area)
    if aspectRatio > 1.0 then
        -- Wider: crop MORE from top/bottom
        local cropAmount = 1.0 - (1.0 / aspectRatio)
        local availableHeight = bottom - top
        local offset = (cropAmount * availableHeight) / 2.0
        top = top + offset
        bottom = bottom - offset
    elseif aspectRatio < 1.0 then
        -- Taller: crop MORE from left/right
        local cropAmount = 1.0 - aspectRatio
        local availableWidth = right - left
        local offset = (cropAmount * availableWidth) / 2.0
        left = left + offset
        right = right - offset
    end

    -- Apply zoom on top of everything (zooms into center)
    if zoom > 0 then
        local centerX = (left + right) / 2.0
        local centerY = (top + bottom) / 2.0
        local currentWidth = right - left
        local currentHeight = bottom - top
        local visibleSize = 1.0 - (zoom * 2)
        left = centerX - (currentWidth * visibleSize / 2.0)
        right = centerX + (currentWidth * visibleSize / 2.0)
        top = centerY - (currentHeight * visibleSize / 2.0)
        bottom = centerY + (currentHeight * visibleSize / 2.0)
    end

    local function ProcessTexture(tex)
        if not tex then return end
        tex:ClearAllPoints()
        tex:SetAllPoints(icon)
        if tex.SetTexCoord then
            tex:SetTexCoord(left, right, top, bottom)
        end
    end

    -- Try common texture property names
    ProcessTexture(icon.Icon)
    ProcessTexture(icon.icon)
    ProcessTexture(icon.texture)
    ProcessTexture(icon.Texture)

    -- Fix the Cooldown frame
    local cooldown = icon.Cooldown or icon.cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(icon)
        -- Use simple stretchable texture so swipe fills entire frame
        cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
        cooldown:SetSwipeColor(0, 0, 0, 0.8)

        -- Show cooldown swipe based on showBuffIconSwipe setting (opt-in, default OFF)
        local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
        local showBuffIconSwipe = SUICore and SUICore.db and SUICore.db.profile.cooldownSwipe
            and SUICore.db.profile.cooldownSwipe.showBuffIconSwipe or false
        if cooldown.SetDrawSwipe then
            cooldown:SetDrawSwipe(showBuffIconSwipe)
        end
        if cooldown.SetDrawEdge then
            cooldown:SetDrawEdge(showBuffIconSwipe)
        end
    end

    -- Fix CooldownFlash if it exists
    if icon.CooldownFlash then
        icon.CooldownFlash:ClearAllPoints()
        icon.CooldownFlash:SetAllPoints(icon)
    end

    -- Apply text sizes and offsets
    local durationSize = settings.durationSize or 12
    local stackSize = settings.stackSize or 12
    local durationOffsetX = settings.durationOffsetX or 0
    local durationOffsetY = settings.durationOffsetY or 0
    local durationAnchor = settings.durationAnchor or "CENTER"
    local stackOffsetX = settings.stackOffsetX or 0
    local stackOffsetY = settings.stackOffsetY or 0
    local stackAnchor = settings.stackAnchor or "BOTTOMRIGHT"

    -- Get font from general settings
    local generalFont = GetGeneralFont()
    local generalOutline = GetGeneralFontOutline()

    -- Apply duration text size and offset (cooldown text)
    if cooldown and durationSize then
        -- Method 1: Check for OmniCC text
        if cooldown.text then
            cooldown.text:SetFont(generalFont, durationSize, generalOutline)
            pcall(function()
                cooldown.text:ClearAllPoints()
                cooldown.text:SetPoint(durationAnchor, icon, durationAnchor, durationOffsetX, durationOffsetY)
            end)
        end

        -- Method 2: Check for Blizzard's built-in cooldown text (GetRegions)
        for _, region in ipairs({ cooldown:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                region:SetFont(generalFont, durationSize, generalOutline)
                pcall(function()
                    region:ClearAllPoints()
                    region:SetPoint(durationAnchor, icon, durationAnchor, durationOffsetX, durationOffsetY)
                end)
            end
        end
    end

    -- Apply stack text size using same approach as suicore_main.lua
    local fs = nil

    -- 1. ChargeCount (ability charges)
    local charge = icon.ChargeCount
    if charge then
        fs = charge.Current or charge.Text or charge.Count or nil
        if not fs and charge.GetRegions then
            for _, region in ipairs({ charge:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    fs = region
                    break
                end
            end
        end
    end

    -- 2. Applications (Buff stacks)
    if not fs then
        local apps = icon.Applications
        if apps and apps.GetRegions then
            for _, region in ipairs({ apps:GetRegions() }) do
                if region:GetObjectType() == "FontString" then
                    fs = region
                    break
                end
            end
        end
    end

    -- 3. Fallback: look for named stack text
    if not fs and icon.GetRegions then
        for _, region in ipairs({ icon:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                local name = region:GetName()
                if name and (name:find("Stack") or name:find("Applications") or name:find("Count")) then
                    fs = region
                    break
                end
            end
        end
    end

    -- Apply the stack size and offset
    if fs and stackSize then
        fs:SetFont(generalFont, stackSize, generalOutline)
        pcall(function()
            fs:ClearAllPoints()
            fs:SetPoint(stackAnchor, icon, stackAnchor, stackOffsetX, stackOffsetY)
        end)
    end

    -- Apply opacity
    local opacity = settings.opacity or 1.0
    icon:SetAlpha(opacity)
end

---------------------------------------------------------------------------
-- BAR STYLING (for BuffBarCooldownViewer item cooldowns)
---------------------------------------------------------------------------

local function ApplyBarStyle(frame, settings)
    if not frame then return end
    if frame.IsForbidden and frame:IsForbidden() then return end

    local barHeight = settings.barHeight or 24
    local texture = settings.texture or "Suavitex v3"
    local useClassColor = settings.useClassColor
    local barColor = settings.barColor or {0.204, 0.827, 0.6, 1}
    local borderSize = settings.borderSize or 1
    local bgColor = settings.bgColor or {0, 0, 0, 1}
    local bgOpacity = settings.bgOpacity or 0.7
    local textSize = settings.textSize or 12

    -- Note: Icon visibility, bar width, bar opacity, and text visibility
    -- are controlled by CDM's Edit Mode panel (Display Mode, Bar Width %, Opacity)

    -- Vertical bar settings
    local orientation = settings.orientation or "horizontal"
    local isVertical = (orientation == "vertical")
    local fillDirection = settings.fillDirection or "up"
    local iconPosition = settings.iconPosition or "top"

    -- Use CDM's current frame width, SUI only controls bar height
    local currentWidth = frame:GetWidth() or 200
    local frameWidth, frameHeight
    if isVertical then
        frameWidth = barHeight      -- Height setting becomes width
        frameHeight = currentWidth   -- CDM-controlled width becomes height
    else
        frameWidth = currentWidth    -- CDM controls width
        frameHeight = barHeight      -- SUI controls height
    end

    -- Get the StatusBar child (usually frame.Bar)
    local statusBar = frame.Bar
    if not statusBar and frame.GetChildren then
        local okC, children = pcall(frame.GetChildren, frame)
        if okC and children then
            for _, child in ipairs({children}) do
                if child and child.IsObjectType and child:IsObjectType("StatusBar") then
                    statusBar = child
                    break
                end
            end
        end
    end
    
    if not statusBar then
        return
    end

    -- 1. STRIP Blizzard's decorative textures from the statusBar (keep only the fill texture)
    if statusBar and statusBar.GetRegions then
        pcall(function()
            local mainTex = statusBar:GetStatusBarTexture()
            for _, region in ipairs({statusBar:GetRegions()}) do
                if region and region:IsObjectType("Texture") and region ~= mainTex then
                    region:SetTexture(nil)
                    region:Hide()
                end
            end
        end)
    end

    -- 1b. Disable atlas borders on the bar FRAME itself (debuff type colors like red/purple/green)
    DisableAtlasBorder(frame.DebuffBorder)
    DisableAtlasBorder(frame.BuffBorder)
    DisableAtlasBorder(frame.TempEnchantBorder)

    -- 2. Set bar dimensions (swapped for vertical orientation)
    pcall(function()
        frame:SetHeight(frameHeight)
        frame:SetWidth(frameWidth)
        if statusBar then
            statusBar:SetHeight(frameHeight)
            statusBar:SetWidth(frameWidth)
            -- Set StatusBar orientation
            if statusBar.SetOrientation then
                statusBar:SetOrientation(isVertical and "VERTICAL" or "HORIZONTAL")
            end
            -- Set fill direction for vertical bars
            if isVertical and statusBar.SetReverseFill then
                statusBar:SetReverseFill(fillDirection == "down")
            end
        end
    end)

    -- 3. Style icon if visible (CDM Display Mode controls icon visibility)
    local iconContainer = frame.Icon
    if iconContainer and iconContainer:IsShown() then
            -- Style icon with full texture stripping for clean rendering
            pcall(function()

                -- Disable atlas borders on iconContainer (prevents thick border reappearance)
                DisableAtlasBorder(iconContainer.DebuffBorder)
                DisableAtlasBorder(iconContainer.BuffBorder)
                DisableAtlasBorder(iconContainer.TempEnchantBorder)

                -- Icon size: use the smaller dimension for vertical bars
                local iconSize = isVertical and frameWidth or frameHeight
                iconContainer:SetSize(iconSize, iconSize)

            -- Get the actual icon texture inside the container
            local iconTexture = iconContainer.Icon or iconContainer.icon or iconContainer.texture
            if iconTexture and iconTexture.IsObjectType and iconTexture:IsObjectType("Texture") then
                -- Step A: Remove ALL mask textures FIRST (iterate through all of them)
                if iconTexture.GetMaskTexture then
                    local i = 1
                    local mask = iconTexture:GetMaskTexture(i)
                    while mask do
                        iconTexture:RemoveMaskTexture(mask)
                        i = i + 1
                        mask = iconTexture:GetMaskTexture(i)
                    end
                end

                -- Disable cooldown swipe on buff bar icons (bar shows duration, swipe is redundant)
                local cooldown = iconContainer.Cooldown or iconContainer.cooldown
                if cooldown then
                    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(false) end
                    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
                end

                -- Step B: Clear anchor points and fill container completely
                iconTexture:ClearAllPoints()
                iconTexture:SetPoint("TOPLEFT", iconContainer, "TOPLEFT", 0, 0)
                iconTexture:SetPoint("BOTTOMRIGHT", iconContainer, "BOTTOMRIGHT", 0, 0)

                -- Step C: Apply TexCoord cropping (removes transparent icon border)
                iconTexture:SetTexCoord(0.07, 0.93, 0.07, 0.93)

                -- Step D: Strip ALL sibling textures from iconContainer (removes debuff rings, borders)
                for _, region in ipairs({iconContainer:GetRegions()}) do
                    if region:IsObjectType("Texture") and region ~= iconTexture then
                        region:SetTexture(nil)
                        region:Hide()
                    end
                end

                -- Step E: Also strip any child frames that might contain borders
                if iconContainer.GetChildren then
                    for _, child in ipairs({iconContainer:GetChildren()}) do
                        if child and child ~= iconTexture then
                            -- Hide border frames but not the cooldown
                            local childName = child.GetName and child:GetName() or ""
                            if not childName:find("Cooldown") then
                                for _, reg in ipairs({child:GetRegions()}) do
                                    if reg:IsObjectType("Texture") then
                                        reg:SetTexture(nil)
                                        reg:Hide()
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Step E2: Hide text on icon EXCEPT stack count (duration shown by bar, text is redundant)
            local appsFontString = iconContainer.Applications  -- Stack count FontString
            for _, region in ipairs({iconContainer:GetRegions()}) do
                if region:IsObjectType("FontString") and region ~= appsFontString then
                    region:SetAlpha(0)
                end
            end
            -- Ensure stack count stays visible
            if appsFontString and appsFontString.SetAlpha then
                appsFontString:SetAlpha(1)
            end
            -- Also check icon children for text (cooldown timers, count text)
            if iconContainer.GetChildren then
                for _, child in ipairs({iconContainer:GetChildren()}) do
                    if child.GetRegions then
                        for _, region in ipairs({child:GetRegions()}) do
                            if region:IsObjectType("FontString") then
                                region:SetAlpha(0)
                            end
                        end
                    end
                end
            end

            -- Step F: Hook SetAtlas on icon texture to prevent Blizzard re-applying borders (one-time hook)
            if iconTexture and iconTexture.SetAtlas and not SUI_atlasHooked[iconTexture] then
                SUI_atlasHooked[iconTexture] = true
                hooksecurefunc(iconTexture, "SetAtlas", function(self)
                    -- Restore TexCoord after any atlas change
                    self:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                end)
            end
        end)
    end

    -- 3b. Reposition statusBar and icon based on orientation and visibility
    local iconVisible = iconContainer and iconContainer:IsShown()
    if statusBar then
        pcall(function()
            statusBar:ClearAllPoints()

            if isVertical then
                -- VERTICAL: Icon at top or bottom, bar fills remaining space
                if not iconVisible then
                    -- No icon: bar fills entire frame
                    statusBar:SetAllPoints(frame)
                else
                    -- Position icon based on iconPosition setting
                    iconContainer:ClearAllPoints()
                    if iconPosition == "bottom" then
                        iconContainer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
                        statusBar:SetPoint("TOP", frame, "TOP", 0, 0)
                        statusBar:SetPoint("LEFT", frame, "LEFT", 0, 0)
                        statusBar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
                        statusBar:SetPoint("BOTTOM", iconContainer, "TOP", 0, 0)
                    else -- "top" (default)
                        iconContainer:SetPoint("TOP", frame, "TOP", 0, 0)
                        statusBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
                        statusBar:SetPoint("LEFT", frame, "LEFT", 0, 0)
                        statusBar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
                        statusBar:SetPoint("TOP", iconContainer, "BOTTOM", 0, 0)
                    end
                end
            else
                -- HORIZONTAL: Original behavior
                if not iconVisible then
                    statusBar:SetPoint("LEFT", frame, "LEFT", 0, 0)
                else
                    statusBar:SetPoint("LEFT", iconContainer, "RIGHT", 0, 0)
                end
                statusBar:SetPoint("TOP", frame, "TOP", 0, 0)
                statusBar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
                statusBar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            end
        end)
    end

    -- 4. Apply StatusBar texture
    if statusBar and statusBar.SetStatusBarTexture then
        local texturePath = LSM:Fetch("statusbar", texture) or LSM:Fetch("statusbar", "Suavisolid")
        if texturePath then
            pcall(statusBar.SetStatusBarTexture, statusBar, texturePath)
        end
    end

    -- 5. Apply bar color (class or custom) — CDM controls overall opacity
    if statusBar and statusBar.SetStatusBarColor then
        pcall(function()
            if useClassColor then
                local _, class = UnitClass("player")
                local color = RAID_CLASS_COLORS[class]
                if color then
                    statusBar:SetStatusBarColor(color.r, color.g, color.b, 1)
                end
            else
                local c = barColor
                statusBar:SetStatusBarColor(c[1] or 0.2, c[2] or 0.8, c[3] or 0.6, 1)
            end
        end)
    end

    -- 6. Apply clean backdrop (solid background BEHIND the statusBar fill)
    -- Create on the frame itself, positioned behind statusBar
    if not SUI_trackedBg[frame] then
        SUI_trackedBg[frame] = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    end
    -- Apply background color from settings
    local bgR, bgG, bgB = bgColor[1] or 0, bgColor[2] or 0, bgColor[3] or 0
    SUI_trackedBg[frame]:SetColorTexture(bgR, bgG, bgB, 1)
    if statusBar then
        SUI_trackedBg[frame]:ClearAllPoints()
        SUI_trackedBg[frame]:SetAllPoints(statusBar)
    end
    SUI_trackedBg[frame]:SetAlpha(bgOpacity)
    SUI_trackedBg[frame]:Show()

    -- 7. Apply crisp border using 4-edge technique
    -- Parent to the bar frame itself (not viewer) so it hides when bar hides
    if borderSize > 0 then
        if not SUI_trackedBorderCont[frame] then
            local container = CreateFrame("Frame", nil, frame)
            container:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 1) + 5)

            -- Create 4 edge textures
            container._top = container:CreateTexture(nil, "OVERLAY", nil, 7)
            container._top:SetColorTexture(0, 0, 0, 1)
            container._bottom = container:CreateTexture(nil, "OVERLAY", nil, 7)
            container._bottom:SetColorTexture(0, 0, 0, 1)
            container._left = container:CreateTexture(nil, "OVERLAY", nil, 7)
            container._left:SetColorTexture(0, 0, 0, 1)
            container._right = container:CreateTexture(nil, "OVERLAY", nil, 7)
            container._right:SetColorTexture(0, 0, 0, 1)

            SUI_trackedBorderCont[frame] = container
        end

        local container = SUI_trackedBorderCont[frame]
        -- Position container to wrap around the bar (extends OUTSIDE by borderSize)
        container:ClearAllPoints()
        container:SetPoint("TOPLEFT", frame, "TOPLEFT", -borderSize, borderSize)
        container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", borderSize, -borderSize)

        -- Top edge
        container._top:ClearAllPoints()
        container._top:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        container._top:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
        container._top:SetHeight(borderSize)

        -- Bottom edge
        container._bottom:ClearAllPoints()
        container._bottom:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        container._bottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        container._bottom:SetHeight(borderSize)

        -- Left edge
        container._left:ClearAllPoints()
        container._left:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        container._left:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        container._left:SetWidth(borderSize)

        -- Right edge
        container._right:ClearAllPoints()
        container._right:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
        container._right:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        container._right:SetWidth(borderSize)

        container:Show()
    else
        if SUI_trackedBorderCont[frame] then
            SUI_trackedBorderCont[frame]:Hide()
        end
    end

    -- 8. Apply text size — CDM Display Mode controls text visibility
    local generalFont = GetGeneralFont()
    local generalOutline = GetGeneralFontOutline()

    if frame.GetRegions then
        for _, region in ipairs({frame:GetRegions()}) do
            if region and region:GetObjectType() == "FontString" then
                pcall(function()
                    region:SetFont(generalFont, textSize, generalOutline)
                end)
            end
        end
    end

    if statusBar and statusBar.GetRegions then
        for _, region in ipairs({statusBar:GetRegions()}) do
            if region and region:GetObjectType() == "FontString" then
                pcall(function()
                    region:SetFont(generalFont, textSize, generalOutline)
                end)
            end
        end
    end

    SUI_trackedBarStyled[frame] = true
end

---------------------------------------------------------------------------
-- ICON CENTER MANAGER (PARENT-SYNCHRONIZED & STABILIZED)
---------------------------------------------------------------------------

local iconState = {
    isInitialized = false,
    lastCount     = 0,
}

LayoutBuffIcons = function()
    if FORCE_DISABLE_CDM_BUFFBAR then return end
    if not BuffIconCooldownViewer then return end
    if isIconLayoutRunning then return end  -- Re-entry guard
    if IsLayoutSuppressed() then return end

    isIconLayoutRunning = true

    ---------------------------------------------------------------------------
    -- CUSTOM ICONS PATH: Position our own frames, skip Blizzard viewer mods
    ---------------------------------------------------------------------------
    local customIconsActive = IsCustomIconsActive()
    UpdateOwnershipExports()

    if customIconsActive then
        SetIconViewerHidden(true)
        if customIconContainer then
            customIconContainer:Show()
        end

        local container = GetOrCreateIconContainer()
        if not container then
            isIconLayoutRunning = false
            return
        end

        local settings = GetBuffSettings()

        -- HUD layer priority
        local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
        local hudLayering = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.hudLayering
        local layerPriority = hudLayering and hudLayering.buffIcon or 5
        local frameLevel = 200
        if SUICore and SUICore.GetHUDFrameLevel then
            frameLevel = SUICore:GetHUDFrameLevel(layerPriority)
        end
        container:SetFrameStrata("MEDIUM")
        container:SetFrameLevel(frameLevel + 10)

        local icons = activeCustomIcons
        local currentCount = #icons

        if currentCount == 0 then
            iconState.lastCount = 0
            iconState.isInitialized = false
            isIconLayoutRunning = false
            return
        end

        local iconSize = settings.iconSize or 42
        local padding = settings.padding or 0
        local aspectRatio = settings.aspectRatioCrop or 1.0
        local growthDirection = settings.growthDirection or "CENTERED_HORIZONTAL"

        local iconWidth, iconHeight = iconSize, iconSize
        if aspectRatio > 1.0 then
            iconHeight = iconSize / aspectRatio
        elseif aspectRatio < 1.0 then
            iconWidth = iconSize * aspectRatio
        end

        iconState.lastCount = currentCount
        iconState.isInitialized = true

        local isVertical = (growthDirection == "UP" or growthDirection == "DOWN")

        local totalWidth, totalHeight
        if isVertical then
            totalWidth = iconWidth
            totalHeight = (currentCount * iconHeight) + ((currentCount - 1) * padding)
            totalHeight = roundPixel(totalHeight)
        else
            totalWidth = (currentCount * iconWidth) + ((currentCount - 1) * padding)
            totalWidth = roundPixel(totalWidth)
            totalHeight = iconHeight
        end

        local startX, startY
        if isVertical then
            startX = 0
            if growthDirection == "UP" then
                startY = -totalHeight / 2 + iconHeight / 2
            else
                startY = totalHeight / 2 - iconHeight / 2
            end
            startY = roundPixel(startY)
        else
            startX = -totalWidth / 2 + iconWidth / 2
            startX = roundPixel(startX)
            startY = 0
        end

        -- Position each custom icon (anchor to container, not viewer — viewer may be forbidden)
        local anchorFrame = customIconContainer or SafeGetViewer("BuffIconCooldownViewer")
        for i, icon in ipairs(icons) do
            ApplyIconStyle(icon, settings)
            icon:ClearAllPoints()

            if isVertical then
                local y
                if growthDirection == "UP" then
                    y = startY + (i - 1) * (iconHeight + padding)
                else
                    y = startY - (i - 1) * (iconHeight + padding)
                end
                icon:SetPoint("CENTER", anchorFrame, "CENTER", 0, roundPixel(y))
            else
                local x = startX + (i - 1) * (iconWidth + padding)
                icon:SetPoint("CENTER", anchorFrame, "CENTER", roundPixel(x), 0)
            end

            icon:SetFrameStrata("MEDIUM")
            icon:SetFrameLevel(frameLevel + 10)
        end

        -- TAINT-FIX (session 4986): Removed BuffIconCooldownViewer:SetSize() and
        -- .Selection manipulation — same taint vector as BuffBarCooldownViewer.
        -- SetSize() triggers internal layout recalculation that taints the SHARED
        -- CooldownViewerSettingsDataProvider singleton, cascading taint to ALL viewers
        -- (including BuffBarCooldownViewer). Container size is all we need.

        isIconLayoutRunning = false
        return  -- Custom path complete; skip legacy code below
    else
        SetIconViewerHidden(false)
        if customIconContainer then
            customIconContainer:Hide()
        end
    end

    ---------------------------------------------------------------------------
    -- LEGACY PATH: Original Blizzard viewer layout (USE_CUSTOM_ICONS = false)
    -- Entire body wrapped in pcall — viewer internals may be forbidden (12.0.5)
    ---------------------------------------------------------------------------
    pcall(function()

    local settings = GetBuffSettings()
    if not settings.enabled then
        isIconLayoutRunning = false
        return
    end

    -- Apply HUD layer priority
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    local hudLayering = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.hudLayering
    local layerPriority = hudLayering and hudLayering.buffIcon or 5
    if SUICore and SUICore.GetHUDFrameLevel then
        local frameLevel = SUICore:GetHUDFrameLevel(layerPriority)
        BuffIconCooldownViewer:SetFrameLevel(frameLevel)
    end

    local icons = GetBuffIconFrames()
    local currentCount = #icons

    -- Handle empty state
    if currentCount == 0 then
        iconState.lastCount = 0
        iconState.isInitialized = false
        isIconLayoutRunning = false
        return
    end

    -- Get settings — prefer Blizzard's CDM Icon Padding when available
    local iconSize = settings.iconSize or 42
    local blizzPadding = BuffIconCooldownViewer.childXPadding or BuffIconCooldownViewer.childYPadding
    local padding = blizzPadding or (settings.padding or 0)
    local aspectRatio = settings.aspectRatioCrop or 1.0
    local growthDirection = settings.growthDirection or "CENTERED_HORIZONTAL"

    -- Calculate dimensions using crop-based aspect ratio
    local iconWidth, iconHeight = iconSize, iconSize
    if aspectRatio > 1.0 then
        -- Wider: height shrinks
        iconHeight = iconSize / aspectRatio
    elseif aspectRatio < 1.0 then
        -- Taller: width shrinks
        iconWidth = iconSize * aspectRatio
    end

    local targetCount = currentCount
    iconState.lastCount = currentCount
    iconState.isInitialized = true

    -- Determine if vertical or horizontal layout
    local isVertical = (growthDirection == "UP" or growthDirection == "DOWN")

    -- Calculate total size using our settings
    local totalWidth, totalHeight
    if isVertical then
        totalWidth = iconWidth
        totalHeight = (targetCount * iconHeight) + ((targetCount - 1) * padding)
        totalHeight = roundPixel(totalHeight)
    else
        totalWidth = (targetCount * iconWidth) + ((targetCount - 1) * padding)
        totalWidth = roundPixel(totalWidth)
        totalHeight = iconHeight
    end

    -- Calculate starting position for centering within the viewer
    local startX, startY
    if isVertical then
        startX = 0
        if growthDirection == "UP" then
            -- Grow up: icon 1 at bottom, icons stack upward
            startY = -totalHeight / 2 + iconHeight / 2
        else -- DOWN
            -- Grow down: icon 1 at top, icons stack downward
            startY = totalHeight / 2 - iconHeight / 2
        end
        startY = roundPixel(startY)
    else
        -- Horizontal (centered)
        startX = -totalWidth / 2 + iconWidth / 2
        startX = roundPixel(startX)
        startY = 0
    end

    -- Tolerance-based check: skip repositioning if all icons are already in correct positions
    -- Prevents jitter from floating-point drift (allows 2px tolerance)
    local needsReposition = false
    for i, icon in ipairs(icons) do
        local expectedX, expectedY
        if isVertical then
            expectedX = 0
            if growthDirection == "UP" then
                expectedY = roundPixel(startY + (i - 1) * (iconHeight + padding))
            else -- DOWN
                expectedY = roundPixel(startY - (i - 1) * (iconHeight + padding))
            end
            -- Check Y position for vertical layout
            local point, _, _, xOfs, yOfs = icon:GetPoint(1)
            if not point or abs((yOfs or 0) - expectedY) > 2 then
                needsReposition = true
                break
            end
        else
            expectedX = roundPixel(startX + (i - 1) * (iconWidth + padding))
            if not PositionMatchesTolerance(icon, expectedX, 2) then
                needsReposition = true
                break
            end
        end
    end

    if needsReposition then
        -- TWO-PASS LAYOUT: Clear all points first, then position - prevents mixed state flicker
        -- PASS 1: Clear all points first
        for _, icon in ipairs(icons) do
            icon:ClearAllPoints()
        end

        -- PASS 2: Apply style and position each icon
        for i, icon in ipairs(icons) do
            ApplyIconStyle(icon, settings)
            if isVertical then
                local y
                if growthDirection == "UP" then
                    y = startY + (i - 1) * (iconHeight + padding)
                else -- DOWN
                    y = startY - (i - 1) * (iconHeight + padding)
                end
                icon:SetPoint("CENTER", BuffIconCooldownViewer, "CENTER", 0, roundPixel(y))
            else
                local x = startX + (i - 1) * (iconWidth + padding)
                icon:SetPoint("CENTER", BuffIconCooldownViewer, "CENTER", roundPixel(x), 0)
            end
        end
    else
        -- Positions are correct, just apply styling (skip SetPoint calls)
        for _, icon in ipairs(icons) do
            ApplyIconStyle(icon, settings)
        end
    end

    -- During Edit Mode, let Blizzard manage viewer size + Selection overlay so panel
    -- settings (Icon Size, Icon Padding, etc.) update immediately.
    -- Outside Edit Mode, pin viewer size to prevent layout drift.
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame.editModeActive
    if not isEditMode and not InCombatLockdown() then
        SuppressLayout()
        BuffIconCooldownViewer:SetSize(roundPixel(totalWidth), roundPixel(totalHeight))
        UnsuppressLayout()
    end

    end) -- end pcall wrapping legacy icon path

    isIconLayoutRunning = false
end

---------------------------------------------------------------------------
-- BAR ALIGNMENT MANAGER (FORCED UPWARD GROWTH)
---------------------------------------------------------------------------

local barState = {
    lastCount      = 0,
    lastBarWidth   = nil,
    lastBarHeight  = nil,
    lastSpacing    = nil,
}

LayoutBuffBars = function()
    if FORCE_DISABLE_CDM_BUFFBAR then return end
    if not BuffBarCooldownViewer then return end
    if isBarLayoutRunning then return end  -- Re-entry guard
    if IsLayoutSuppressed() then return end

    isBarLayoutRunning = true

    ---------------------------------------------------------------------------
    -- CUSTOM BARS PATH: Position our own frames, skip Blizzard viewer mods
    ---------------------------------------------------------------------------
    local customBarsActive = IsCustomBarsActive()
    UpdateOwnershipExports()

    if customBarsActive then
        SetViewerHidden(true)
        if customContainer then
            customContainer:Show()
        end

        -- Ensure container exists and is positioned
        local container = GetOrCreateContainer()
        if not container then
            isBarLayoutRunning = false
            return
        end

        -- HUD layer priority
        local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
        local hudLayering = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.hudLayering
        local layerPriority = hudLayering and hudLayering.buffBar or 5
        local frameLevel = 200
        if SUICore and SUICore.GetHUDFrameLevel then
            frameLevel = SUICore:GetHUDFrameLevel(layerPriority)
        end
        container:SetFrameStrata("MEDIUM")
        container:SetFrameLevel(frameLevel + 10)

        local bars = activeCustomBars
        local count = #bars
        if count == 0 then
            barState.lastCount = 0
            isBarLayoutRunning = false
            return
        end

        -- Settings
        local settings = GetTrackedBarSettings()
        local stylingEnabled = true
        -- TAINT-FIX (session 4986): Use settings value instead of querying viewer
        local barWidth = settings.barWidth or 200
        local barHeight = stylingEnabled and settings.barHeight or 24
        local spacing = stylingEnabled and settings.spacing or 4
        local growFromBottom = (not stylingEnabled) or (settings.growUp ~= false)
        local orientation = stylingEnabled and settings.orientation or "horizontal"
        local isVertical = (orientation == "vertical")

        -- Effective dimensions (swapped for vertical)
        local effectiveBarWidth, effectiveBarHeight
        if isVertical then
            effectiveBarWidth = barHeight
            effectiveBarHeight = stylingEnabled and settings.barWidth or 200
        else
            effectiveBarWidth = barWidth
            effectiveBarHeight = barHeight
        end

        if not effectiveBarHeight or effectiveBarHeight == 0 then
            isBarLayoutRunning = false
            return
        end

        barState.lastCount = count
        barState.lastBarWidth = effectiveBarWidth
        barState.lastBarHeight = effectiveBarHeight
        barState.lastSpacing = spacing

        -- Position each bar (anchored to viewer for Edit Mode compat)
        for index, bar in ipairs(bars) do
            local offsetIndex = index - 1
            bar:SetSize(effectiveBarWidth, effectiveBarHeight)
            bar:ClearAllPoints()

            if isVertical then
                if growFromBottom then
                    local x = roundPixel(offsetIndex * (effectiveBarWidth + spacing))
                    bar:SetPoint("LEFT", container, "LEFT", x, 0)
                else
                    local x = roundPixel(-offsetIndex * (effectiveBarWidth + spacing))
                    bar:SetPoint("RIGHT", container, "RIGHT", x, 0)
                end
            else
                if growFromBottom then
                    local y = roundPixel(offsetIndex * (effectiveBarHeight + spacing))
                    bar:SetPoint("BOTTOM", container, "BOTTOM", 0, y)
                else
                    local y = roundPixel(-offsetIndex * (effectiveBarHeight + spacing))
                    bar:SetPoint("TOP", container, "TOP", 0, y)
                end
            end

            -- Visual style
            if stylingEnabled then
                ApplyBarStyle(bar, settings)
            end

            -- Frame strata/level
            bar:SetFrameStrata("MEDIUM")
            bar:SetFrameLevel(frameLevel + 10)
            if bar.Bar then
                bar.Bar:SetFrameStrata("MEDIUM")
                bar.Bar:SetFrameLevel(frameLevel + 11)
            end
            if bar.Icon then
                bar.Icon:SetFrameStrata("MEDIUM")
                bar.Icon:SetFrameLevel(frameLevel + 11)
            end
        end

        -- Total stack size
        local totalSize
        if isVertical then
            totalSize = (count * effectiveBarWidth) + ((count - 1) * spacing)
        else
            totalSize = (count * effectiveBarHeight) + ((count - 1) * spacing)
        end
        totalSize = roundPixel(totalSize)

        -- TAINT-FIX (session 4986): Removed BuffBarCooldownViewer:SetSize() — any Lua-level
        -- interaction with the viewer from addon context risks tainting its item frame fields.
        -- Container size is all we need for custom bar anchoring.

        -- Set container size so bars can anchor against it
        container:SetSize(roundPixel(effectiveBarWidth), roundPixel(effectiveBarHeight))

        -- TAINT-FIX (session 4986): Removed Selection overlay manipulation on
        -- BuffBarCooldownViewer — accessing .Selection and calling SetPoint/SetFrameLevel
        -- on viewer children from addon context risks tainting viewer frame fields.

        isBarLayoutRunning = false
        return  -- Custom path complete; skip legacy code below
    else
        SetViewerHidden(false)
        if customContainer then
            customContainer:Hide()
        end
        -- Fall through to legacy path below
    end

    ---------------------------------------------------------------------------
    -- LEGACY PATH: Skin Blizzard's viewer children in place (USE_CUSTOM_BARS = false)
    -- Viewer stays visible; Blizzard manages data, we only apply visual styling.
    -- Entire body wrapped in pcall — viewer internals may be forbidden (12.0.5)
    ---------------------------------------------------------------------------
    pcall(function()

    -- Apply HUD layer priority (strata + level)
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    local hudLayering = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.hudLayering
    local layerPriority = hudLayering and hudLayering.buffBar or 5
    local frameLevel = 200  -- Default fallback
    if SUICore and SUICore.GetHUDFrameLevel then
        frameLevel = SUICore:GetHUDFrameLevel(layerPriority)
    end
    -- Set strata to MEDIUM to match power bars, then apply frame level
    BuffBarCooldownViewer:SetFrameStrata("MEDIUM")
    BuffBarCooldownViewer:SetFrameLevel(frameLevel)

    local bars = GetBuffBarFrames()
    local count = #bars
    if count == 0 then
        barState.lastCount = 0
        isBarLayoutRunning = false
        return
    end

    local refBar = bars[1]
    if not refBar then
        isBarLayoutRunning = false
        return
    end

    -- Get tracked bar settings
    local settings = GetTrackedBarSettings()
    local stylingEnabled = settings.enabled

    -- Use settings for dimensions if styling enabled, otherwise use frame defaults
    local barWidth = refBar:GetWidth()
    local barHeight = stylingEnabled and settings.barHeight or refBar:GetHeight()
    -- Always use Blizzard's CDM Icon Padding (set by RefreshLayout → childYPadding/childXPadding)
    -- so the Edit Mode panel setting takes effect immediately.
    local spacing = BuffBarCooldownViewer.childYPadding or (stylingEnabled and settings.spacing or 0)
    local growFromBottom = (not stylingEnabled) or (settings.growUp ~= false)

    -- Vertical bar support
    local orientation = stylingEnabled and settings.orientation or "horizontal"
    local isVertical = (orientation == "vertical")

    -- TAINT-FIX (session 4979): NEVER write isHorizontal / layoutFramesGoingRight /
    -- layoutFramesGoingUp to BuffBarCooldownViewer. Writing these from addon context
    -- taints the field. Blizzard's RefreshLayout reads it, calls into the SHARED
    -- CooldownViewerSettingsDataProvider singleton, and if the provider is dirty it
    -- rebuilds displayData in tainted context — infecting ALL viewers (Essential,
    -- Utility, BuffIcon) with cascading taint on spellID, charges, isActive, etc.
    -- Custom bars render in customContainer, so viewer layout direction is irrelevant.

    -- For vertical bars, swap dimensions (height setting becomes width)
    local effectiveBarWidth, effectiveBarHeight
    if isVertical then
        effectiveBarWidth = barHeight  -- Height setting becomes bar width
        effectiveBarHeight = stylingEnabled and settings.barWidth or 200  -- Width setting becomes bar height
    else
        effectiveBarWidth = barWidth
        effectiveBarHeight = barHeight
    end

    if not effectiveBarHeight or effectiveBarHeight == 0 then
        isBarLayoutRunning = false
        return
    end

    barState.lastCount = count
    barState.lastBarWidth = effectiveBarWidth
    barState.lastBarHeight = effectiveBarHeight
    barState.lastSpacing = spacing

    -- Total size of the stack (height for horizontal bars, width for vertical)
    local totalSize
    if isVertical then
        totalSize = (count * effectiveBarWidth) + ((count - 1) * spacing)
    else
        totalSize = (count * effectiveBarHeight) + ((count - 1) * spacing)
    end
    totalSize = roundPixel(totalSize)

    -- POSITION VERIFICATION: Check if bars are already in correct positions (within 2px tolerance)
    -- This mirrors the icon layout's self-correcting behavior - if Blizzard moves a bar,
    -- we detect it and snap it back immediately
    local needsReposition = false
    for index, bar in ipairs(bars) do
        local offsetIndex = index - 1

        if isVertical then
            -- Check X position for vertical layout
            local expectedX
            if growFromBottom then
                expectedX = roundPixel(offsetIndex * (effectiveBarWidth + spacing))
            else
                expectedX = roundPixel(-offsetIndex * (effectiveBarWidth + spacing))
            end
            local point, _, _, xOfs = bar:GetPoint(1)
            if not point or abs((xOfs or 0) - expectedX) > 2 then
                needsReposition = true
                break
            end
        else
            -- Check Y position for horizontal layout
            local expectedY
            if growFromBottom then
                expectedY = roundPixel(offsetIndex * (effectiveBarHeight + spacing))
            else
                expectedY = roundPixel(-offsetIndex * (effectiveBarHeight + spacing))
            end
            local point, _, _, _, yOfs = bar:GetPoint(1)
            if not point or abs((yOfs or 0) - expectedY) > 2 then
                needsReposition = true
                break
            end
        end
    end

    if needsReposition then
        -- PASS 1: Clear all points
        for _, bar in ipairs(bars) do
            bar:ClearAllPoints()
        end

        -- PASS 2: Position each bar
        for index, bar in ipairs(bars) do
            local offsetIndex = index - 1

            if isVertical then
                -- VERTICAL BARS: Stack horizontally (left/right)
                local x
                if growFromBottom then
                    -- Grow Right: bar 1 at LEFT edge, stacks rightward
                    x = offsetIndex * (effectiveBarWidth + spacing)
                    x = roundPixel(x)
                    bar:SetPoint("LEFT", BuffBarCooldownViewer, "LEFT", x, 0)
                else
                    -- Grow Left: bar 1 at RIGHT edge, stacks leftward
                    x = -offsetIndex * (effectiveBarWidth + spacing)
                    x = roundPixel(x)
                    bar:SetPoint("RIGHT", BuffBarCooldownViewer, "RIGHT", x, 0)
                end
            else
                -- HORIZONTAL BARS: Stack vertically (up/down)
                local y
                if growFromBottom then
                    y = offsetIndex * (effectiveBarHeight + spacing)
                    y = roundPixel(y)
                    bar:SetPoint("BOTTOM", BuffBarCooldownViewer, "BOTTOM", 0, y)
                else
                    y = -offsetIndex * (effectiveBarHeight + spacing)
                    y = roundPixel(y)
                    bar:SetPoint("TOP", BuffBarCooldownViewer, "TOP", 0, y)
                end
            end
        end
    end

    -- Apply visual styling and frame strata/level to each bar (always, regardless of reposition)
    for _, bar in ipairs(bars) do
        if stylingEnabled then
            ApplyBarStyle(bar, settings)
        end
        -- Apply frame strata/level to each bar AND its .Bar child for proper HUD layering
        bar:SetFrameStrata("MEDIUM")
        bar:SetFrameLevel(frameLevel)
        if bar.Bar then
            bar.Bar:SetFrameStrata("MEDIUM")
            bar.Bar:SetFrameLevel(frameLevel + 1)
        end
        if bar.Icon then
            bar.Icon:SetFrameStrata("MEDIUM")
            bar.Icon:SetFrameLevel(frameLevel + 1)
        end
    end

    -- During Edit Mode, let Blizzard manage viewer size + Selection overlay so the
    -- panel settings (Bar Width, Icon Size, Padding, etc.) update immediately.
    -- Outside Edit Mode, pin viewer to single-bar size to prevent layout drift.
    local isEditMode = EditModeManagerFrame and EditModeManagerFrame.editModeActive

    if not isEditMode then
        SuppressLayout()
        BuffBarCooldownViewer:SetSize(roundPixel(effectiveBarWidth), roundPixel(effectiveBarHeight))
        UnsuppressLayout()
    end

    end) -- end pcall wrapping legacy bar path

    isBarLayoutRunning = false
end

---------------------------------------------------------------------------
-- CHANGE DETECTION (called from OnUpdate hooks on viewers)
-- Icons: Hash-based detection for count/settings changes
-- Bars: Position verification (hash removed - bars now self-correct via position checks)
---------------------------------------------------------------------------

local lastIconHash = ""

-- Build hash of icon count + settings to detect actual changes
local function BuildIconHash(count, settings)
    return string.format("%d_%d_%d_%.2f_%d_%s",
        count,
        settings.iconSize or 42,
        settings.padding or 0,
        settings.aspectRatioCrop or 1.0,
        settings.borderSize or 2,
        settings.growthDirection or "CENTERED_HORIZONTAL"
    )
end

local function CheckIconChanges()
    if FORCE_DISABLE_CDM_BUFFBAR then return end
    if not BuffIconCooldownViewer then return end
    if isIconLayoutRunning then return end
    if IsLayoutSuppressed() then return end

    if IsCustomIconsActive() then
        -- Custom icons: reconcile data then layout
        UpdateCustomIconData()
        LayoutBuffIcons()
        return
    end

    -- Legacy: Count visible icons (wrapped in pcall - viewer may be forbidden)
    local visibleCount = 0
    pcall(function()
        for _, child in ipairs({ BuffIconCooldownViewer:GetChildren() }) do
            if child and child ~= BuffIconCooldownViewer.Selection then
                if (child.icon or child.Icon) and child:IsShown() then
                    visibleCount = visibleCount + 1
                end
            end
        end
    end)

    -- Build hash including count AND settings
    local settings = GetBuffSettings()
    local hash = BuildIconHash(visibleCount, settings)

    -- Only layout if hash changed (count or settings)
    if hash == lastIconHash then
        return
    end

    lastIconHash = hash
    LayoutBuffIcons()
end

local function CheckBarChanges()
    if FORCE_DISABLE_CDM_BUFFBAR then return end
    if not BuffBarCooldownViewer then return end
    if isBarLayoutRunning then return end  -- Skip if already laying out

    if IsCustomBarsActive() then
        -- Custom bars: reconcile data then layout
        UpdateCustomBarData()
        LayoutBuffBars()
        return
    end

    -- Legacy: Always call LayoutBuffBars - it has internal position verification
    -- that skips repositioning if all bars are already in correct positions.
    LayoutBuffBars()
end

-- TAINT-FIX: ForcePopulateBuffIcons REMOVED. It called viewer:Layout() and
-- viewer:SetSize() from addon context, running Blizzard's entire
-- Layout → RefreshLayout → RefreshData chain in tainted execution context.
-- This tainted CDM item frame fields (isActive, hasTotem, etc.), causing
-- cascading errors in CompactUnitFrame (oldR), AuraUtil (cachedBigDefensives),
-- and TargetUnit() ADDON_ACTION_FORBIDDEN during Edit Mode transitions.
-- With USE_CUSTOM_ICONS=false, viewers stay visible and Blizzard populates
-- them via its own OnShow → RefreshLayout → RefreshData chain.

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

local initialized = false

local function Initialize()
    if FORCE_DISABLE_CDM_BUFFBAR then return end
    if initialized then return end
    initialized = true
    UpdateOwnershipExports()

    EnsureCooldownViewerLoaded()

    ---------------------------------------------------------------------------
    -- CUSTOM BARS INITIALIZATION
    ---------------------------------------------------------------------------
    if USE_CUSTOM_BARS and BuffBarCooldownViewer then
        -- Hide Blizzard viewer's visual output (our custom bars render instead).
        -- Alpha enforcer (QUI pattern) zeros alpha every frame so Blizzard can't
        -- restore it. We do NOT override ShouldBeShown or call viewer:Show() — both
        -- run addon code inside Blizzard's secure chain, tainting CDM fields.
        -- FetchBuffBarData uses hybrid pipeline: viewer children (when shown) for
        -- accurate active state, C API fallback when viewer is hidden.
        SetViewerHidden(IsCustomBarsActive())
        alphaEnforcerActive = IsCustomBarsActive() or IsCustomIconsActive()

        -- Create the container
        local container = GetOrCreateContainer()
        if container then
            -- OnUpdate loop: smooth animation + periodic data refresh
            container._elapsed = 0
            container._dataElapsed = 0
            container:SetScript("OnUpdate", function(self, elapsed)
                if not IsCustomBarsActive() then
                    SetViewerHidden(false)
                    if customContainer then customContainer:Hide() end
                    return
                end
                self._elapsed = (self._elapsed or 0) + elapsed
                self._dataElapsed = (self._dataElapsed or 0) + elapsed

                -- Animation update (20 FPS): smooth bar fill + time text
                if self._elapsed >= 0.05 then
                    self._elapsed = 0
                    UpdateCustomBarProgress()
                end

                -- Data refresh (2 FPS): reconcile bar count with active auras
                if self._dataElapsed >= 0.5 then
                    self._dataElapsed = 0
                    UpdateCustomBarData()
                    LayoutBuffBars()
                end
            end)

            -- UNIT_AURA / target-change events: immediate data reconciliation on aura change.
            -- Must watch both "player" (buffs on self) and "target" (DoTs on target).
            local auraFrame = CreateFrame("Frame")
            auraFrame:RegisterEvent("UNIT_AURA")
            auraFrame:RegisterEvent("PLAYER_TARGET_CHANGED")  -- target swap clears/sets DoTs
            auraFrame:SetScript("OnEvent", function(_, event, unit)
                if event == "PLAYER_TARGET_CHANGED" or unit == "player" or unit == "target" then
                    if not container._rescanPending then
                        container._rescanPending = true
                        C_Timer.After(0.1, function()
                            container._rescanPending = nil
                            UpdateCustomBarData()
                            LayoutBuffBars()
                        end)
                    end
                end
            end)

            -- Edit Mode: show Blizzard viewer for positioning, hide our bars
            EventRegistry:RegisterCallback("EditMode.Enter", function()
                alphaEnforcerActive = false  -- Let viewers be visible for positioning
                SetViewerHidden(false)
                -- Re-enable mouse for Edit Mode interaction (SetViewerHidden(false) disables
                -- it to prevent blocking outside Edit Mode; enable it explicitly here).
                local _v = SafeGetViewer("BuffBarCooldownViewer")
                if _v then pcall(function() _v:EnableMouse(true) end) end
                if customContainer then customContainer:Hide() end
            end, "SuaviBuffBarCustom")

            EventRegistry:RegisterCallback("EditMode.Exit", function()
                -- Defer viewer hide + container show to after all synchronous EditMode.Exit
                -- processing. Our callback fires before Blizzard's CDM handler, so any
                -- alpha/visibility reset Blizzard performs in the same frame would override
                -- a synchronous SetAlpha(0) call here.
                C_Timer.After(0, function()
                    local useCustom = IsCustomBarsActive()
                    SetViewerHidden(useCustom)
                    alphaEnforcerActive = useCustom or IsCustomIconsActive()
                    if customContainer then
                        if useCustom then customContainer:Show() else customContainer:Hide() end
                    end
                end)
                C_Timer.After(0.2, function()
                    if IsCustomBarsActive() then
                        UpdateCustomBarData()
                        LayoutBuffBars()
                    end
                end)
            end, "SuaviBuffBarCustom")
        end
    end

    ---------------------------------------------------------------------------
    -- CUSTOM ICONS INITIALIZATION
    ---------------------------------------------------------------------------
    if USE_CUSTOM_ICONS and BuffIconCooldownViewer then
        -- Hide Blizzard viewer's visual output (our custom icons render instead)
        SetIconViewerHidden(IsCustomIconsActive())
        alphaEnforcerActive = IsCustomIconsActive()

        local iconContainer = GetOrCreateIconContainer()
        if iconContainer then
            -- OnUpdate: periodic data refresh (icons don't need smooth animation;
            -- the Cooldown frame handles swipe natively)
            iconContainer._dataElapsed = 0
            iconContainer:SetScript("OnUpdate", function(self, elapsed)
                if not IsCustomIconsActive() then
                    SetIconViewerHidden(false)
                    if customIconContainer then customIconContainer:Hide() end
                    return
                end
                self._dataElapsed = (self._dataElapsed or 0) + elapsed
                if self._dataElapsed >= 0.5 then  -- 2 FPS data refresh
                    self._dataElapsed = 0
                    UpdateCustomIconData()
                    LayoutBuffIcons()
                end
            end)

            -- UNIT_AURA / target-change: immediate data reconciliation on aura change.
            -- Watch both "player" (self-buffs) and "target" (target debuffs like tracked DoTs).
            local iconAuraFrame = CreateFrame("Frame")
            iconAuraFrame:RegisterEvent("UNIT_AURA")
            iconAuraFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
            iconAuraFrame:SetScript("OnEvent", function(_, event, unit)
                if event == "PLAYER_TARGET_CHANGED" or unit == "player" or unit == "target" then
                    if not iconContainer._rescanPending then
                        iconContainer._rescanPending = true
                        C_Timer.After(0.1, function()
                            iconContainer._rescanPending = nil
                            UpdateCustomIconData()
                            LayoutBuffIcons()
                        end)
                    end
                end
            end)

            -- Edit Mode: show Blizzard viewer for positioning, hide our icons
            EventRegistry:RegisterCallback("EditMode.Enter", function()
                alphaEnforcerActive = false  -- Let viewers be visible for positioning
                SetIconViewerHidden(false)
                if customIconContainer then customIconContainer:Hide() end
            end, "SuaviBuffIconCustom")

            EventRegistry:RegisterCallback("EditMode.Exit", function()
                -- Same deferral as bar viewer: let Blizzard's CDM exit handler run first.
                C_Timer.After(0, function()
                    local useCustom = IsCustomIconsActive()
                    SetIconViewerHidden(useCustom)
                    alphaEnforcerActive = useCustom or IsCustomBarsActive()
                    if customIconContainer then
                        if useCustom then customIconContainer:Show() else customIconContainer:Hide() end
                    end
                end)
                C_Timer.After(0.2, function()
                    if IsCustomIconsActive() then
                        UpdateCustomIconData()
                        LayoutBuffIcons()
                    end
                end)
            end, "SuaviBuffIconCustom")
        end
    end

    -- TAINT-FIX (session 4979): Removed legacy viewer property writes (isHorizontal,
    -- layoutFramesGoingRight, layoutFramesGoingUp). Even in the legacy path these writes
    -- taint the shared CooldownViewerSettingsDataProvider, cascading to all viewers.

    -- ForcePopulateBuffIcons removed (taint source — see comment at line 2734)

    -- Legacy icon OnUpdate polling (only when not using custom icons)
    if not USE_CUSTOM_ICONS then
        pcall(function()
            if BuffIconCooldownViewer and not iconViewerHooked then
                iconViewerHooked = true
                iconViewerElapsed = 0
                BuffIconCooldownViewer:HookScript("OnUpdate", function(self, elapsed)
                    iconViewerElapsed = iconViewerElapsed + elapsed
                    if iconViewerElapsed > 0.05 then
                        iconViewerElapsed = 0
                        if self:IsShown() then
                            CheckIconChanges()
                        end
                    end
                end)
            end
        end)
    end

    -- Legacy bar OnUpdate hook (only when not using custom bars)
    if not USE_CUSTOM_BARS then
        pcall(function()
            if BuffBarCooldownViewer and not barViewerHooked then
                barViewerHooked = true
                barViewerElapsed = 0
                BuffBarCooldownViewer:HookScript("OnUpdate", function(self, elapsed)
                    barViewerElapsed = barViewerElapsed + elapsed
                    if barViewerElapsed > 0.05 then
                        barViewerElapsed = 0
                        if self:IsShown() then
                            CheckBarChanges()
                        end
                    end
                end)
            end
        end)
    end

    -- Legacy icon viewer hooks (only when not using custom icons)
    if not USE_CUSTOM_ICONS then
        pcall(function()
            -- CRITICAL: OnSizeChanged hook - immediate response when Blizzard resizes viewer
            if BuffIconCooldownViewer then
                BuffIconCooldownViewer:HookScript("OnSizeChanged", function(self)
                    if IsLayoutSuppressed() then return end
                    if isIconLayoutRunning then return end
                    LayoutBuffIcons()
                end)
            end

            -- OnShow hook - refresh when viewer becomes visible
            if BuffIconCooldownViewer then
                BuffIconCooldownViewer:HookScript("OnShow", function(self)
                    if IsLayoutSuppressed() then return end
                    if isIconLayoutRunning then return end
                    LayoutBuffIcons()
                end)
            end

            -- Hook Layout - deferred to avoid taint inside Blizzard's secure call chain
            if BuffIconCooldownViewer and BuffIconCooldownViewer.Layout then
                hooksecurefunc(BuffIconCooldownViewer, "Layout", function()
                    if IsLayoutSuppressed() then return end
                    if isIconLayoutRunning then return end
                    -- TAINT-FIX: defer so we don't run inside Blizzard's secure Layout call stack
                    C_Timer.After(0, function()
                        if IsLayoutSuppressed() then return end
                        if isIconLayoutRunning then return end
                        LayoutBuffIcons()
                    end)
                end)
            end
        end)
    end

    -- Legacy bar Layout hooks (only when not using custom bars)
    if not USE_CUSTOM_BARS then
        pcall(function()
            if BuffBarCooldownViewer and BuffBarCooldownViewer.Layout then
                hooksecurefunc(BuffBarCooldownViewer, "Layout", function()
                    if IsLayoutSuppressed() then return end
                    if isBarLayoutRunning then return end
                    -- TAINT-FIX: defer so we don't run inside Blizzard's secure Layout call stack
                    C_Timer.After(0, function()
                        if IsLayoutSuppressed() then return end
                        if isBarLayoutRunning then return end
                        LayoutBuffBars()
                    end)
                end)
            end

            -- TAINT-FIX (session 4924): Do NOT write to BuffBarCooldownViewer.isHorizontal or
            -- any other CDM viewer frame field from addon context. Writing these fields from
            -- a C_Timer callback (even deferred) taints them; Blizzard's next RefreshLayout
            -- reads the tainted isHorizontal at CooldownViewer.lua:1781-1787, cascading the
            -- taint to itemContainerFrame fields, then through Layout() and RefreshData() into
            -- all item frame fields (isActive, charges, spellID, etc.) across ALL viewers,
            -- causing "secret value" errors. Since USE_CUSTOM_BARS=true renders bars in
            -- customContainer instead of BuffBarCooldownViewer, the viewer's layout direction
            -- is completely irrelevant and this hook is unnecessary.
        end)
    end

    ---------------------------------------------------------------------------
    -- EVENT-BASED UPDATES: UNIT_AURA hook for immediate buff change detection
    -- (Replaces polling as primary detection - polling becomes fallback only)
    ---------------------------------------------------------------------------

    -- Legacy icon UNIT_AURA hook (only when not using custom icons)
    if not USE_CUSTOM_ICONS then
        pcall(function()
            if BuffIconCooldownViewer and not iconAuraHook then
                iconAuraHook = CreateFrame("Frame")
                iconAuraHook:RegisterEvent("UNIT_AURA")
                iconAuraHook:SetScript("OnEvent", function(_, event, unit)
                    if unit == "player" and BuffIconCooldownViewer:IsShown() then
                        if not iconRescanPending then
                            iconRescanPending = true
                            C_Timer.After(0.1, function()
                                iconRescanPending = false
                                if BuffIconCooldownViewer:IsShown() then
                                    if isIconLayoutRunning then return end
                                    if IsLayoutSuppressed() then return end
                                    lastIconHash = ""
                                    CheckIconChanges()
                                end
                            end)
                        end
                    end
                end)
            end
        end)
    end

    -- Initial layouts (after force populate)
    C_Timer.After(0.3, function()
        LayoutBuffIcons()  -- Direct calls
        LayoutBuffBars()
    end)
end

---------------------------------------------------------------------------
-- EVENT HANDLING
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if FORCE_DISABLE_CDM_BUFFBAR then return end
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, Initialize)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if isInitialLogin or isReloadingUi then
            C_Timer.After(1.5, function()
                LayoutBuffIcons()
                LayoutBuffBars()
            end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- After combat ends, refresh layout (viewers may have been hidden during combat)
        C_Timer.After(0.5, function()
            LayoutBuffIcons()
            LayoutBuffBars()
        end)
    end
end)

-- Also try to initialize immediately if viewers exist
C_Timer.After(0, function()
    if BuffIconCooldownViewer or BuffBarCooldownViewer then
        Initialize()
    end
end)

---------------------------------------------------------------------------
-- EDIT MODE PANEL INJECTION (CDM Viewers)
-- Uses shared ns.EditModePanels infrastructure to inject SuaviUI controls
-- into Blizzard's native EditModeSystemSettingsDialog for CDM viewers.
---------------------------------------------------------------------------

do
    local EP = ns.EditModePanels
    if not EP then return end

    local controls = EP.controls

    ---------------------------------------------------------------------------
    -- DB helpers
    ---------------------------------------------------------------------------
    local function GetOrCreateTrackedBarDB()
        local db = GetDB()
        if not db then return nil end
        if not db.trackedBar then db.trackedBar = {} end
        return db.trackedBar
    end

    local function GetProfile()
        return SUICore and SUICore.db and SUICore.db.profile
    end

    local function RefreshIcons()
        if _G.SuaviUI_RefreshCooldownIcons then _G.SuaviUI_RefreshCooldownIcons() end
    end

    local function RefreshAdvanced()
        local SUI = _G.SuaviUI and _G.SuaviUI.SUICore
        if SUI and SUI.CooldownAdvanced then SUI.CooldownAdvanced.RefreshAllFeatures() end
    end

    ---------------------------------------------------------------------------
    -- Texture list from LibSharedMedia
    ---------------------------------------------------------------------------
    local function GetLSMTextureOptions()
        local textures = {}
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        local TEXTURE_NAMES = (ns.ResourceBars and ns.ResourceBars.TEXTURE_DISPLAY_NAMES) or {}
        if lsm then
            for _, name in ipairs(lsm:List("statusbar")) do
                local displayName = TEXTURE_NAMES[name] or name
                table.insert(textures, {value = name, text = displayName})
            end
            table.sort(textures, function(a, b) return a.text < b.text end)
        else
            textures = {{value = "Solid", text = "Solid"}}
        end
        return textures
    end

    ---------------------------------------------------------------------------
    -- Viewer detection predicates
    ---------------------------------------------------------------------------
    local function IsBuffBarViewer(sf)
        return sf and sf.system == Enum.EditModeSystem.CooldownViewer
            and sf.systemIndex == Enum.EditModeCooldownViewerSystemIndices.BuffBar
    end
    local function IsBuffIconViewer(sf)
        return sf and sf.system == Enum.EditModeSystem.CooldownViewer
            and sf.systemIndex == Enum.EditModeCooldownViewerSystemIndices.BuffIcon
    end
    local function IsEssentialViewer(sf)
        return sf and sf.system == Enum.EditModeSystem.CooldownViewer
            and sf.systemIndex == Enum.EditModeCooldownViewerSystemIndices.Essential
    end
    local function IsUtilityViewer(sf)
        return sf and sf.system == Enum.EditModeSystem.CooldownViewer
            and sf.systemIndex == Enum.EditModeCooldownViewerSystemIndices.Utility
    end

    ---------------------------------------------------------------------------
    -- Helper: create square-icon controls for a CDM viewer category
    ---------------------------------------------------------------------------
    local function CreateCDMSquareIconControls(prefix, suffix, refreshFn)
        controls[prefix .. "Divider"] = EP.CreateDivider(prefix, "SuaviUI")

        controls[prefix .. "Square"] = EP.CreateCheckbox(prefix .. "Square", "Square Icons",
            function() local p = GetProfile(); return p and p["cooldownManager_squareIcons_" .. suffix] or false end,
            function(v) local p = GetProfile(); if p then p["cooldownManager_squareIcons_" .. suffix] = v end; refreshFn() end
        )
        controls[prefix .. "BorderSize"] = EP.CreateSlider(prefix .. "BorderSize", "Border Size", 1, 6, 1,
            function() local p = GetProfile(); return p and p["cooldownManager_squareIconsBorder_" .. suffix] or 4 end,
            function(v) local p = GetProfile(); if p then p["cooldownManager_squareIconsBorder_" .. suffix] = v end; refreshFn() end
        )
        controls[prefix .. "BorderOverlap"] = EP.CreateCheckbox(prefix .. "BorderOverlap", "Border Overlap",
            function() local p = GetProfile(); return p and p["cooldownManager_squareIconsBorder_" .. suffix .. "_Overlap"] or false end,
            function(v) local p = GetProfile(); if p then p["cooldownManager_squareIconsBorder_" .. suffix .. "_Overlap"] = v end; refreshFn() end
        )
        controls[prefix .. "Zoom"] = EP.CreateSlider(prefix .. "Zoom", "Icon Zoom", 0, 50, 5,
            function() local p = GetProfile(); return math.floor(((p and p["cooldownManager_squareIconsZoom_" .. suffix]) or 0) * 100 + 0.5) end,
            function(v) local p = GetProfile(); if p then p["cooldownManager_squareIconsZoom_" .. suffix] = v / 100 end; refreshFn() end
        )
    end

    ---------------------------------------------------------------------------
    -- BuffBar: bar styling controls
    ---------------------------------------------------------------------------
    local barControlKeys = {
        "barDivider", "barHeight", "barTexture", "barOrientation", "barGrowth",
        "barClassColor", "barBorderSize", "barBgOpacity", "barTextSize",
    }

    EP.RegisterSystem(IsBuffBarViewer, function()
        controls.barDivider = EP.CreateDivider("Bars", "SuaviUI")

        controls.barHeight = EP.CreateSlider("BarHeight", "Bar Height", 2, 48, 1,
            function() return (GetTrackedBarSettings()).barHeight or 24 end,
            function(v) local t = GetOrCreateTrackedBarDB(); if t then t.barHeight = v end; LayoutBuffBars() end
        )
        controls.barTexture = EP.CreateDropdown("BarTexture", "Bar Texture",
            GetLSMTextureOptions,
            function() return (GetTrackedBarSettings()).texture or "Suavitex v3" end,
            function(v) local t = GetOrCreateTrackedBarDB(); if t then t.texture = v end; LayoutBuffBars() end
        )
        controls.barOrientation = EP.CreateDropdown("BarOrientation", "Orientation",
            function() return {
                {value = "horizontal", text = "Horizontal"},
                {value = "vertical", text = "Vertical"},
            } end,
            function() return (GetTrackedBarSettings()).orientation or "horizontal" end,
            function(v) local t = GetOrCreateTrackedBarDB(); if t then t.orientation = v end; LayoutBuffBars() end
        )
        controls.barGrowth = EP.CreateDropdown("BarGrowth", "Stack Direction",
            function() return {
                {value = true, text = "Up / Right"},
                {value = false, text = "Down / Left"},
            } end,
            function() local s = GetTrackedBarSettings(); return s.growUp ~= false end,
            function(v) local t = GetOrCreateTrackedBarDB(); if t then t.growUp = v end; LayoutBuffBars() end
        )
        controls.barClassColor = EP.CreateCheckbox("ClassColor", "Use Class Color",
            function() return (GetTrackedBarSettings()).useClassColor ~= false end,
            function(v) local t = GetOrCreateTrackedBarDB(); if t then t.useClassColor = v end; LayoutBuffBars() end
        )
        controls.barBorderSize = EP.CreateSlider("BarBorderSize", "Border Size", 0, 4, 1,
            function() return (GetTrackedBarSettings()).borderSize or 1 end,
            function(v) local t = GetOrCreateTrackedBarDB(); if t then t.borderSize = v end; LayoutBuffBars() end
        )
        controls.barBgOpacity = EP.CreateSlider("BarBgOpacity", "BG Opacity", 0, 100, 10,
            function() return math.floor(((GetTrackedBarSettings()).bgOpacity or 0.7) * 100 + 0.5) end,
            function(v) local t = GetOrCreateTrackedBarDB(); if t then t.bgOpacity = v / 100 end; LayoutBuffBars() end
        )
        controls.barTextSize = EP.CreateSlider("BarTextSize", "Text Size", 8, 24, 1,
            function() return (GetTrackedBarSettings()).textSize or 12 end,
            function(v) local t = GetOrCreateTrackedBarDB(); if t then t.textSize = v end; LayoutBuffBars() end
        )
    end, barControlKeys)

    ---------------------------------------------------------------------------
    -- BuffIcon: square icon controls
    ---------------------------------------------------------------------------
    local iconControlKeys = {
        "buffIconDivider", "buffIconSquare", "buffIconBorderSize",
        "buffIconBorderOverlap", "buffIconZoom",
    }

    EP.RegisterSystem(IsBuffIconViewer, function()
        CreateCDMSquareIconControls("buffIcon", "BuffIcons", LayoutBuffIcons)
    end, iconControlKeys)

    ---------------------------------------------------------------------------
    -- Essential: square icon controls + CDM global settings
    ---------------------------------------------------------------------------
    local essentialControlKeys = {
        "essentialDivider", "essentialSquare", "essentialBorderSize",
        "essentialBorderOverlap", "essentialZoom",
        "cdmGlobalDivider", "cdmCentered",
        "cdmEssentialGrow", "cdmUtilityGrow",
        "cdmDimUtility", "cdmDimOpacity",
        "cdmLimitUtilitySize", "cdmNormalizeUtility",
        "cdmHighlightEssential", "cdmHighlightUtility",
    }

    EP.RegisterSystem(IsEssentialViewer, function()
        CreateCDMSquareIconControls("essential", "Essential", RefreshIcons)

        -- CDM Global settings (shown on Essential panel as the "main" CDM panel)
        controls.cdmGlobalDivider = EP.CreateDivider("CDMGlobal", "CDM Global")

        controls.cdmCentered = EP.CreateCheckbox("CDMCentered", "Use Centered Styling",
            function() local p = GetProfile(); return p and p.cooldownManager_useCenteredStyling or false end,
            function(v) local p = GetProfile(); if p then p.cooldownManager_useCenteredStyling = v end; RefreshIcons() end
        )
        controls.cdmEssentialGrow = EP.CreateDropdown("CDMEssentialGrow", "Essential Grow",
            function() return { {value = "TOP", text = "Top"}, {value = "BOTTOM", text = "Bottom"} } end,
            function() local p = GetProfile(); return p and p.cooldownManager_centerEssential_growFromDirection or "TOP" end,
            function(v) local p = GetProfile(); if p then p.cooldownManager_centerEssential_growFromDirection = v end; RefreshIcons() end
        )
        controls.cdmUtilityGrow = EP.CreateDropdown("CDMUtilityGrow", "Utility Grow",
            function() return { {value = "TOP", text = "Top"}, {value = "BOTTOM", text = "Bottom"} } end,
            function() local p = GetProfile(); return p and p.cooldownManager_centerUtility_growFromDirection or "TOP" end,
            function(v) local p = GetProfile(); if p then p.cooldownManager_centerUtility_growFromDirection = v end; RefreshIcons() end
        )
        controls.cdmDimUtility = EP.CreateCheckbox("CDMDimUtility", "Dim Utility Off CD",
            function() local p = GetProfile(); return p and p.cooldownManager_utility_dimWhenNotOnCD or false end,
            function(v) local p = GetProfile(); if p then p.cooldownManager_utility_dimWhenNotOnCD = v end; RefreshIcons() end
        )
        controls.cdmDimOpacity = EP.CreateSlider("CDMDimOpacity", "Dim Opacity", 0, 90, 5,
            function() local p = GetProfile(); return math.floor(((p and p.cooldownManager_utility_dimOpacity) or 0.3) * 100 + 0.5) end,
            function(v) local p = GetProfile(); if p then p.cooldownManager_utility_dimOpacity = v / 100 end; RefreshIcons() end
        )
        controls.cdmLimitUtilitySize = EP.CreateCheckbox("CDMLimitUtility", "Limit Utility to Essential Width",
            function() local p = GetProfile(); return p and p.cooldownManager_limitUtilitySizeToEssential or false end,
            function(v) local p = GetProfile(); if p then p.cooldownManager_limitUtilitySizeToEssential = v end; RefreshAdvanced() end
        )
        controls.cdmNormalizeUtility = EP.CreateCheckbox("CDMNormalizeUtility", "Normalize Utility Size",
            function() local p = GetProfile(); return p and p.cooldownManager_normalizeUtilitySize or false end,
            function(v) local p = GetProfile(); if p then p.cooldownManager_normalizeUtilitySize = v end; RefreshAdvanced() end
        )
        controls.cdmHighlightEssential = EP.CreateCheckbox("CDMHighlightEssential", "Rotation Highlight",
            function() local p = GetProfile(); return p and p.cooldownManager_showHighlight_Essential or false end,
            function(v) local p = GetProfile(); if p then p.cooldownManager_showHighlight_Essential = v end; RefreshAdvanced() end
        )
        controls.cdmHighlightUtility = EP.CreateCheckbox("CDMHighlightUtility", "Utility Rot. Highlight",
            function() local p = GetProfile(); return p and p.cooldownManager_showHighlight_Utility or false end,
            function(v) local p = GetProfile(); if p then p.cooldownManager_showHighlight_Utility = v end; RefreshAdvanced() end
        )
    end, essentialControlKeys)

    ---------------------------------------------------------------------------
    -- Utility: square icon controls
    ---------------------------------------------------------------------------
    local utilityControlKeys = {
        "utilityDivider", "utilitySquare", "utilityBorderSize",
        "utilityBorderOverlap", "utilityZoom",
    }

    EP.RegisterSystem(IsUtilityViewer, function()
        CreateCDMSquareIconControls("utility", "Utility", RefreshIcons)
    end, utilityControlKeys)
end

---------------------------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------------------------

SUI_BuffBar.LayoutIcons = LayoutBuffIcons
SUI_BuffBar.LayoutBars = LayoutBuffBars
SUI_BuffBar.Initialize = Initialize
-- Feature-flag exports: cooldownmanager.lua checks these to skip its own bar/icon layout
-- when sui_buffbar is managing them. Without these exports cooldownmanager reads nil and
-- falls through to its own (now redundant) layout logic on the hidden Blizzard viewers.
UpdateOwnershipExports()

-- Force refresh function (can be called from GUI)
function SUI_BuffBar.Refresh()
    if FORCE_DISABLE_CDM_BUFFBAR then return end
    -- Reset states to force recalculation
    iconState.isInitialized = false
    iconState.lastCount = 0
    barState.lastCount = 0
    lastIconHash = ""  -- Force hash recalculation for icons

    if IsCustomIconsActive() then
        SetIconViewerHidden(true)
        if customIconContainer then customIconContainer:Show() end
        -- Custom icons: refetch data and relayout
        UpdateCustomIconData()
    else
        SetIconViewerHidden(false)
        if customIconContainer then customIconContainer:Hide() end
    end

    if IsCustomBarsActive() then
        SetViewerHidden(true)
        if customContainer then customContainer:Show() end
        -- Custom bars: refetch data and relayout (no viewer property changes)
        UpdateCustomBarData()
    else
        SetViewerHidden(false)
        if customContainer then customContainer:Hide() end
        -- TAINT-FIX (session 4979): Removed legacy viewer property writes.
    end

    UpdateOwnershipExports()

    LayoutBuffIcons()
    LayoutBuffBars()
end

-- Global refresh function for GUI
_G.SuaviUI_RefreshBuffBar = SUI_BuffBar.Refresh








