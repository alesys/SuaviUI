--[[
    SuaviUI Cast History
    Displays icons for the player's recently finished (successful) spell casts.
    - Movable in Edit Mode via LibEQOLEditMode-1.0
    - Configurable flow direction: left-to-right, right-to-left, top-to-bottom, bottom-to-top
    - Two icon skins: Blizzard default (texcoord crop) or SuaviUI Square (black border + crop)
    - Hybrid lifecycle: max N icons AND per-icon timeout, whichever trims first
]]

local ADDON_NAME, ns = ...

local LEM = LibStub("LibEQOLEditMode-1.0", true)
if not LEM then return end

local SUI_CastHistory = {}
ns.CastHistory = SUI_CastHistory

---------------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------------
local holder              -- the frame registered with Edit Mode
local eventFrame          -- receives UNIT_SPELLCAST_SUCCEEDED
local spellbookEventFrame -- receives SPELLS_CHANGED etc for cache invalidation
local slots = {}          -- array; slots[1] = newest
local pool = {}           -- hidden icon frames ready for reuse
local lastSpellID, lastSpellTime  -- dedupe state
local spellbookCache      -- [spellID] = "spellbook" | "racial"; nil = not cached
local tickerRunning = false
local iconCounter = 0
local registered = false
local initialized = false

local DIRS = {
    LEFT_TO_RIGHT = { anchor = "LEFT",   axis = "x", sign =  1 },
    RIGHT_TO_LEFT = { anchor = "RIGHT",  axis = "x", sign = -1 },
    TOP_TO_BOTTOM = { anchor = "TOP",    axis = "y", sign = -1 },
    BOTTOM_TO_TOP = { anchor = "BOTTOM", axis = "y", sign =  1 },
}

local DIR_OPTIONS = {
    { value = "LEFT_TO_RIGHT", text = "Left to Right" },
    { value = "RIGHT_TO_LEFT", text = "Right to Left" },
    { value = "TOP_TO_BOTTOM", text = "Top to Bottom" },
    { value = "BOTTOM_TO_TOP", text = "Bottom to Top" },
}

local SKIN_OPTIONS = {
    { value = "Square",   text = "SuaviUI Square" },
    { value = "Blizzard", text = "Blizzard Default" },
}

-- Build a LEM dropdown generator that correctly maps option.value <-> option.text.
-- Needed because LEM's `values = ...` shortcut stores option.text in the setting
-- rather than option.value, which breaks our enum-style settings.
local function MakeDropdownGenerator(options, fallbackText)
    return function(dropdown, rootDescription, settingObject)
        local layoutName = LEM and LEM.GetActiveLayoutName and LEM.GetActiveLayoutName() or "Default"
        local current = settingObject.get(layoutName)
        local currentText = fallbackText
        for _, opt in ipairs(options) do
            if opt.value == current then currentText = opt.text; break end
        end
        dropdown:SetDefaultText(currentText)
        for _, opt in ipairs(options) do
            local optText, optValue = opt.text, opt.value
            rootDescription:CreateButton(optText, function()
                dropdown:SetDefaultText(optText)
                settingObject.set(layoutName, optValue)
            end)
        end
    end
end

---------------------------------------------------------------------------
-- DATABASE HELPERS
---------------------------------------------------------------------------
local function GetDB()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile
    end
    return nil
end

local function GetSettings()
    local db = GetDB()
    return db and db.castHistory or nil
end

---------------------------------------------------------------------------
-- SPELLBOOK CACHE
---------------------------------------------------------------------------
local function BuildSpellbookCache()
    spellbookCache = {}
    if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines then return end

    local numLines = C_SpellBook.GetNumSpellBookSkillLines()
    for i = 1, numLines do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if lineInfo then
            local isGeneral = (lineInfo.name == _G.GENERAL or lineInfo.name == "General" or i == 1)
            local offset = lineInfo.itemIndexOffset or 0
            local count = lineInfo.numSpellBookItems or 0
            for j = 1, count do
                local slot = offset + j
                local okInfo, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, Enum.SpellBookSpellBank.Player)
                if okInfo and info and info.spellID then
                    spellbookCache[info.spellID] = isGeneral and "racial" or "spellbook"
                end
            end
        end
    end
end

local function InvalidateSpellbookCache()
    spellbookCache = nil
end

local function ClassifySpell(spellID)
    if not spellbookCache then BuildSpellbookCache() end
    local bucket = spellbookCache and spellbookCache[spellID]
    if bucket then return bucket end
    if IsPlayerSpell and IsPlayerSpell(spellID) then return "spellbook" end
    return "item"
end

---------------------------------------------------------------------------
-- SKIN
---------------------------------------------------------------------------
local function EnsureMask(icon)
    if icon._suiMask then return icon._suiMask end
    local mask = icon:CreateMaskTexture(nil, "ARTWORK")
    mask:SetAllPoints(icon)
    icon.Icon:AddMaskTexture(mask)
    icon._suiMask = mask
    return mask
end

local function EnsureBlizzardOverlay(icon)
    if icon._suiOverlay then return icon._suiOverlay end
    local ov = icon:CreateTexture(nil, "OVERLAY")
    ov:SetAtlas("UI-HUD-CoolDownManager-IconOverlay")
    icon._suiOverlay = ov
    return ov
end

local function EnsureSquareBorderFrame(icon)
    if icon._suiBorderFrame then return icon._suiBorderFrame end
    local bf = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    bf:SetAllPoints(icon)
    bf:SetFrameLevel(icon:GetFrameLevel() + 5)
    icon._suiBorderFrame = bf
    return bf
end

local function ApplySkin(icon)
    local s = GetSettings(); if not s then return end
    local size = s.iconSize or 36
    icon:SetSize(size, size)

    icon.Icon:ClearAllPoints()
    icon.Icon:SetAllPoints(icon)

    local skin = s.iconSkin or "Square"

    local mask = EnsureMask(icon)

    if skin == "Blizzard" then
        -- Blizzard default: circular mask + decorative overlay ring (matches CooldownViewerBuffIconItemTemplate)
        if icon._suiBorderFrame then icon._suiBorderFrame:Hide() end
        mask:SetAtlas("UI-HUD-CoolDownManager-Mask")
        mask:Show()
        local overlay = EnsureBlizzardOverlay(icon)
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT",     icon, "TOPLEFT",     -6,  5)
        overlay:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT",  6, -5)
        overlay:Show()
        icon.Icon:SetTexCoord(0, 1, 0, 1)
    else
        -- Square: use solid-white pass-through mask (no shape cropping), apply clean black border
        mask:SetColorTexture(1, 1, 1, 1)
        mask:Show()
        if icon._suiOverlay then icon._suiOverlay:Hide() end

        local bw = s.squareBorderSize or 2
        if bw > 0 then
            local bf = EnsureSquareBorderFrame(icon)
            bf:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = bw,
            })
            bf:SetBackdropBorderColor(0, 0, 0, 1)
            bf:Show()
        elseif icon._suiBorderFrame then
            icon._suiBorderFrame:Hide()
        end

        local zoom = s.squareZoom or 0
        local lo = 0.07 + zoom
        local hi = 0.93 - zoom
        if lo >= hi then lo, hi = 0.07, 0.93 end
        icon.Icon:SetTexCoord(lo, hi, lo, hi)
    end
end

---------------------------------------------------------------------------
-- ICON CREATION / POOL
---------------------------------------------------------------------------
local function CreateIcon()
    iconCounter = iconCounter + 1
    local f = CreateFrame("Frame", "SuaviCastHistoryIcon" .. iconCounter, holder, "BackdropTemplate")
    f:SetSize(36, 36)
    f:Hide()

    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetAllPoints(f)

    -- animations
    local animIn = f:CreateAnimationGroup()
    local translateIn = animIn:CreateAnimation("Translation")
    translateIn:SetDuration(0.18); translateIn:SetSmoothing("OUT")
    local alphaIn = animIn:CreateAnimation("Alpha")
    alphaIn:SetFromAlpha(0); alphaIn:SetToAlpha(1)
    alphaIn:SetDuration(0.18); alphaIn:SetSmoothing("OUT")
    animIn:SetScript("OnFinished", function()
        f:SetAlpha(1)
    end)
    f.animIn = animIn
    f.translateIn = translateIn

    local animOut = f:CreateAnimationGroup()
    local alphaOut = animOut:CreateAnimation("Alpha")
    alphaOut:SetFromAlpha(1); alphaOut:SetToAlpha(0)
    alphaOut:SetDuration(0.15)
    local translateOut = animOut:CreateAnimation("Translation")
    translateOut:SetDuration(0.15); translateOut:SetSmoothing("IN")
    f.animOut = animOut
    f.translateOut = translateOut

    animOut:SetScript("OnFinished", function()
        f:Hide()
        f.spellID = nil
        f.createdAt = nil
        f._leaving = nil
        f._editModePreview = nil
        f:ClearAllPoints()
        table.insert(pool, f)
    end)

    ApplySkin(f)
    return f
end

local function Acquire()
    local f = table.remove(pool) or CreateIcon()
    ApplySkin(f)
    return f
end

local function ImmediateRelease(icon)
    if not icon then return end
    if icon.animIn:IsPlaying() then icon.animIn:Stop() end
    if icon.animOut:IsPlaying() then icon.animOut:Stop() end
    icon:Hide()
    icon.spellID = nil
    icon.createdAt = nil
    icon._leaving = nil
    icon._editModePreview = nil
    icon:ClearAllPoints()
    table.insert(pool, icon)
end

---------------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------------
local function GetDirConfig()
    local s = GetSettings()
    return DIRS[s and s.direction] or DIRS.RIGHT_TO_LEFT
end

local function SizeHolder()
    local s = GetSettings(); if not s then return end
    local maxN = s.maxIcons or 5
    local size = s.iconSize or 36
    local spacing = s.spacing or 4
    local length = maxN * size + math.max(0, maxN - 1) * spacing
    local dir = GetDirConfig()
    if dir.axis == "x" then
        holder:SetSize(length, size)
    else
        holder:SetSize(size, length)
    end
end

local function RelayoutSlots()
    local s = GetSettings(); if not s then return end
    local dir = GetDirConfig()
    local size = s.iconSize or 36
    local spacing = s.spacing or 4
    local step = size + spacing
    for i, icon in ipairs(slots) do
        icon:ClearAllPoints()
        local offset = (i - 1) * step * dir.sign
        if dir.axis == "x" then
            icon:SetPoint(dir.anchor, holder, dir.anchor, offset, 0)
        else
            icon:SetPoint(dir.anchor, holder, dir.anchor, 0, offset)
        end
    end
end

local function PlayInAnimation(icon)
    local dir = GetDirConfig()
    local s = GetSettings()
    local size = (s and s.iconSize) or 36
    -- Slide from opposite of entry direction by one icon size
    local dx, dy = 0, 0
    if dir.axis == "x" then
        dx = -dir.sign * size
    else
        dy = -dir.sign * size
    end
    icon.translateIn:SetOffset(dx, dy)
    icon:SetAlpha(0)
    icon:Show()
    if icon.animIn:IsPlaying() then icon.animIn:Stop() end
    icon.animIn:Play()
end

local function PlayOutAnimation(icon)
    if icon._leaving then return end
    icon._leaving = true
    local dir = GetDirConfig()
    local s = GetSettings()
    local size = (s and s.iconSize) or 36
    local dx, dy = 0, 0
    if dir.axis == "x" then
        dx = dir.sign * size * 0.4
    else
        dy = dir.sign * size * 0.4
    end
    icon.translateOut:SetOffset(dx, dy)
    if icon.animOut:IsPlaying() then icon.animOut:Stop() end
    icon.animOut:Play()
end

---------------------------------------------------------------------------
-- TIMEOUT TICKER
---------------------------------------------------------------------------
local tickerAccum = 0
local function OnTick(_, elapsed)
    tickerAccum = tickerAccum + elapsed
    if tickerAccum < 0.1 then return end
    tickerAccum = 0
    local s = GetSettings(); if not s then return end
    local timeout = s.iconTimeout or 6.0
    local now = GetTime()
    -- trim tail while oldest non-leaving, non-preview icon is expired
    while #slots > 0 do
        local tail = slots[#slots]
        if tail._editModePreview then break end
        if tail._leaving then break end
        if (tail.createdAt or now) + timeout > now then break end
        table.remove(slots)
        PlayOutAnimation(tail)
    end
    if #slots == 0 and not holder._editModePreviewActive then
        holder:SetScript("OnUpdate", nil)
        tickerRunning = false
    end
end

local function StartTicker()
    if tickerRunning then return end
    tickerRunning = true
    tickerAccum = 0
    holder:SetScript("OnUpdate", OnTick)
end

---------------------------------------------------------------------------
-- INSERT / PUSH
---------------------------------------------------------------------------
local function PushIcon(spellID, texture)
    local s = GetSettings(); if not s or not s.enabled then return end
    if holder and holder._editModePreviewActive then return end

    if s.collapseRepeats and slots[1] and slots[1].spellID == spellID and not slots[1]._leaving then
        slots[1].createdAt = GetTime()
        PlayInAnimation(slots[1])
        StartTicker()
        return
    end

    local icon = Acquire()
    icon.spellID = spellID
    icon.createdAt = GetTime()
    icon._leaving = nil
    icon._editModePreview = nil
    icon.Icon:SetTexture(texture)

    table.insert(slots, 1, icon)

    local maxN = s.maxIcons or 5
    while #slots > maxN do
        local removed = table.remove(slots)
        PlayOutAnimation(removed)
    end

    RelayoutSlots()
    PlayInAnimation(icon)
    StartTicker()
end

---------------------------------------------------------------------------
-- CLEAR ALL
---------------------------------------------------------------------------
local function ClearAllSlots()
    for i = #slots, 1, -1 do
        ImmediateRelease(slots[i])
        slots[i] = nil
    end
end

---------------------------------------------------------------------------
-- EVENT HANDLER
---------------------------------------------------------------------------
local function OnSpellCastSucceeded(spellID)
    local s = GetSettings(); if not s or not s.enabled then return end
    if not spellID then return end

    local now = GetTime()
    if spellID == lastSpellID and (now - (lastSpellTime or 0)) < 0.25 then
        lastSpellTime = now
        return
    end
    lastSpellID = spellID
    lastSpellTime = now

    local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if not texture then return end

    local bucket = ClassifySpell(spellID)
    if bucket == "racial" and not s.includeRacials then return end
    if bucket == "item" and not s.includeItems then return end

    PushIcon(spellID, texture)
end

---------------------------------------------------------------------------
-- EDIT MODE PREVIEW
---------------------------------------------------------------------------
local PREVIEW_GENERIC_TEXTURES = {
    "Interface\\Icons\\Spell_Fire_Fireball02",
    "Interface\\Icons\\Spell_Frost_FrostBolt02",
    "Interface\\Icons\\Spell_Nature_Lightning",
    "Interface\\Icons\\Spell_Holy_HolyBolt",
    "Interface\\Icons\\Ability_Warrior_Savageblow",
}

local function GetPreviewTextures(count)
    local out = {}
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and Enum and Enum.SpellBookSpellBank then
        for slot = 1, 20 do
            local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, slot, Enum.SpellBookSpellBank.Player)
            if ok and info and info.spellID and info.iconID then
                out[#out + 1] = info.iconID
                if #out >= count then return out end
            end
        end
    end
    for _, tex in ipairs(PREVIEW_GENERIC_TEXTURES) do
        if #out >= count then break end
        out[#out + 1] = tex
    end
    return out
end

local function StartEditModePreview()
    ClearAllSlots()
    holder._editModePreviewActive = true
    local s = GetSettings(); if not s then return end
    local n = math.min(s.maxIcons or 5, 5)
    local textures = GetPreviewTextures(n)
    for i = 1, n do
        local icon = Acquire()
        icon.spellID = 0
        icon.createdAt = GetTime()
        icon._editModePreview = true
        icon.Icon:SetTexture(textures[i] or PREVIEW_GENERIC_TEXTURES[1])
        table.insert(slots, i, icon)
    end
    RelayoutSlots()
    for _, icon in ipairs(slots) do
        icon:SetAlpha(1)
        icon:Show()
    end
end

local function StopEditModePreview()
    holder._editModePreviewActive = false
    ClearAllSlots()
end

---------------------------------------------------------------------------
-- REFRESH (called when settings change)
---------------------------------------------------------------------------
function SUI_CastHistory:Refresh()
    if not initialized then return end
    local s = GetSettings(); if not s then return end
    SizeHolder()
    for _, icon in ipairs(pool) do ApplySkin(icon) end
    if holder._editModePreviewActive then
        -- Regenerate preview from scratch so direction / size / count changes
        -- always produce a clean, correctly-anchored layout.
        StartEditModePreview()
    else
        for _, icon in ipairs(slots) do ApplySkin(icon) end
        RelayoutSlots()
        if not s.enabled then
            ClearAllSlots()
        end
    end
end

---------------------------------------------------------------------------
-- POSITION CHANGE CALLBACK
---------------------------------------------------------------------------
local function OnPositionChanged(frame, layoutName, point, x, y)
    if type(layoutName) == "number" then
        local origX, origY, origPoint = layoutName, point, x
        x, y, point = origX, origY, origPoint
    end
    local s = GetSettings(); if not s then return end
    if not s.position then s.position = {} end
    s.position.point = point or "CENTER"
    s.position.x = tonumber(x) or 0
    s.position.y = tonumber(y) or 0
end

local function LoadPosition()
    local s = GetSettings(); if not s or not holder then return end
    local p = s.position or { point = "CENTER", x = 0, y = -220 }
    holder:ClearAllPoints()
    holder:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x or 0, p.y or -220)
end

---------------------------------------------------------------------------
-- EDIT MODE SETTINGS
---------------------------------------------------------------------------
local function BuildEditModeSettings()
    local settings = {}
    local order = 1

    table.insert(settings, {
        order = order, name = "Enable", kind = LEM.SettingType.Checkbox, default = false,
        get = function() local s = GetSettings(); return s and s.enabled or false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.enabled = value; SUI_CastHistory:Refresh() end
        end,
    }); order = order + 1

    -- LAYOUT
    table.insert(settings, {
        order = order, name = "Layout", kind = LEM.SettingType.Collapsible,
        id = "CH_LAYOUT", defaultCollapsed = false,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_LAYOUT", order = order, name = "Max Icons",
        kind = LEM.SettingType.Slider, default = 5, minValue = 1, maxValue = 10, valueStep = 1,
        get = function() local s = GetSettings(); return s and s.maxIcons or 5 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.maxIcons = math.floor(value); SUI_CastHistory:Refresh() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_LAYOUT", order = order, name = "Icon Size",
        kind = LEM.SettingType.Slider, default = 36, minValue = 20, maxValue = 64, valueStep = 1,
        get = function() local s = GetSettings(); return s and s.iconSize or 36 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.iconSize = math.floor(value); SUI_CastHistory:Refresh() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_LAYOUT", order = order, name = "Spacing",
        kind = LEM.SettingType.Slider, default = 4, minValue = 0, maxValue = 20, valueStep = 1,
        get = function() local s = GetSettings(); return s and s.spacing or 4 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.spacing = math.floor(value); SUI_CastHistory:Refresh() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_LAYOUT", order = order, name = "Flow Direction",
        kind = LEM.SettingType.Dropdown, default = "RIGHT_TO_LEFT", useOldStyle = true,
        generator = MakeDropdownGenerator(DIR_OPTIONS, "Right to Left"),
        get = function() local s = GetSettings(); return s and s.direction or "RIGHT_TO_LEFT" end,
        set = function(_, value)
            local s = GetSettings(); if s then s.direction = value; SUI_CastHistory:Refresh() end
        end,
    }); order = order + 1

    -- BEHAVIOR
    table.insert(settings, {
        order = order, name = "Behavior", kind = LEM.SettingType.Collapsible,
        id = "CH_BEHAVIOR", defaultCollapsed = true,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_BEHAVIOR", order = order, name = "Icon Timeout (sec)",
        kind = LEM.SettingType.Slider, default = 6.0, minValue = 2, maxValue = 30, valueStep = 0.5,
        formatter = function(v) return string.format("%.1f", v) end,
        get = function() local s = GetSettings(); return s and s.iconTimeout or 6.0 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.iconTimeout = value end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_BEHAVIOR", order = order, name = "Include Items", kind = LEM.SettingType.Checkbox,
        default = true,
        get = function() local s = GetSettings(); return s and s.includeItems ~= false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.includeItems = value end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_BEHAVIOR", order = order, name = "Include Racials", kind = LEM.SettingType.Checkbox,
        default = true,
        get = function() local s = GetSettings(); return s and s.includeRacials ~= false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.includeRacials = value end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_BEHAVIOR", order = order, name = "Collapse Repeats",
        kind = LEM.SettingType.Checkbox, default = true,
        get = function() local s = GetSettings(); return s and s.collapseRepeats ~= false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.collapseRepeats = value end
        end,
    }); order = order + 1

    -- APPEARANCE
    table.insert(settings, {
        order = order, name = "Appearance", kind = LEM.SettingType.Collapsible,
        id = "CH_APPEARANCE", defaultCollapsed = true,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_APPEARANCE", order = order, name = "Icon Skin",
        kind = LEM.SettingType.Dropdown, default = "Square", useOldStyle = true,
        generator = MakeDropdownGenerator(SKIN_OPTIONS, "SuaviUI Square"),
        get = function() local s = GetSettings(); return s and s.iconSkin or "Square" end,
        set = function(_, value)
            local s = GetSettings(); if s then s.iconSkin = value; SUI_CastHistory:Refresh() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_APPEARANCE", order = order, name = "Square Border Size",
        kind = LEM.SettingType.Slider, default = 1, minValue = 0, maxValue = 4, valueStep = 1,
        get = function() local s = GetSettings(); return s and s.squareBorderSize or 1 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.squareBorderSize = math.floor(value); SUI_CastHistory:Refresh() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CH_APPEARANCE", order = order, name = "Square Zoom",
        kind = LEM.SettingType.Slider, default = 0, minValue = 0, maxValue = 0.3, valueStep = 0.01,
        formatter = function(v) return string.format("%.2f", v) end,
        get = function() local s = GetSettings(); return s and s.squareZoom or 0 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.squareZoom = value; SUI_CastHistory:Refresh() end
        end,
    }); order = order + 1

    return settings
end

---------------------------------------------------------------------------
-- LEM REGISTRATION
---------------------------------------------------------------------------
local function RegisterWithLEM()
    if registered then return end
    local s = GetSettings(); if not s then return end
    holder.editModeName = "Cast History"

    local defaults = {
        point = (s.position and s.position.point) or "CENTER",
        x = (s.position and s.position.x) or 0,
        y = (s.position and s.position.y) or -220,
    }

    local ok, err = pcall(function()
        LEM:AddFrame(holder, OnPositionChanged, defaults)
        LEM:AddFrameSettings(holder, BuildEditModeSettings())
        LEM:SetFrameDragEnabled(holder, function()
            if LEM.IsInEditMode and LEM:IsInEditMode() then return true end
            return s.enabled or false
        end)
        if LEM.SetFrameResetVisible then
            LEM:SetFrameResetVisible(holder, function()
                return LEM.IsInEditMode and LEM:IsInEditMode() or false
            end)
        end
    end)

    if ok then
        registered = true
        if not holder._editModeOverlay then
            local overlay = CreateFrame("Frame", nil, holder, "BackdropTemplate")
            overlay:SetAllPoints(holder)
            overlay:SetFrameLevel(holder:GetFrameLevel() + 1)
            overlay:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 2,
            })
            overlay:SetBackdropBorderColor(0.3, 0.8, 1, 0.6)
            overlay:Hide()
            holder._editModeOverlay = overlay
        end
    else
        print("|cffff6666SuaviUI:|r Failed to register Cast History with Edit Mode:", tostring(err))
    end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
local function CreateHolder()
    holder = CreateFrame("Frame", "SuaviUI_CastHistory", UIParent)
    holder:SetFrameStrata("MEDIUM")
    SizeHolder()
end

local function CreateEventFrame()
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:SetScript("OnEvent", function(_, _, _, _, spellID)
        OnSpellCastSucceeded(spellID)
    end)
end

local function CreateSpellbookEventFrame()
    spellbookEventFrame = CreateFrame("Frame")
    spellbookEventFrame:RegisterEvent("SPELLS_CHANGED")
    spellbookEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    spellbookEventFrame:SetScript("OnEvent", function()
        InvalidateSpellbookCache()
    end)
end

function SUI_CastHistory:Initialize()
    if initialized then return end
    if not LEM then return end
    if not GetDB() then
        C_Timer.After(1, function() SUI_CastHistory:Initialize() end)
        return
    end

    CreateHolder()
    LoadPosition()
    CreateEventFrame()
    CreateSpellbookEventFrame()
    RegisterWithLEM()

    LEM:RegisterCallback("enter", function()
        if holder then
            StartEditModePreview()
        end
    end)

    LEM:RegisterCallback("exit", function()
        if holder then
            StopEditModePreview()
        end
    end)

    initialized = true
end

_G.SuaviUI_RefreshCastHistory = function() SUI_CastHistory:Refresh() end
_G.SuaviUI_OpenCastHistoryEditMode = function()
    if _G.ShowUIPanel and _G.EditModeManagerFrame then
        if not _G.EditModeManagerFrame:IsShown() then
            _G.ShowUIPanel(_G.EditModeManagerFrame)
        end
    end
end

---------------------------------------------------------------------------
-- DEFERRED START
---------------------------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(0.5, function()
        SUI_CastHistory:Initialize()
    end)
end)
