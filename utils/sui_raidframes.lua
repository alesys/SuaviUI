--[[
    SuaviUI Raid & Party Frames
    Secure group headers (party + raid) with health, power, heal prediction,
    absorbs, dispel highlight, debuffs, own HoTs, private aura anchors, range
    fade and status icons. Positioned through Blizzard Edit Mode (see
    raidframes_editmode.lua). Disabled by default.

    Midnight (12.x) rules followed throughout this file:
      * Values that may be secret are never compared, tested or used in
        arithmetic. They go straight into widget setters that accept them
        (StatusBar:SetValue, Texture:SetTexture, FontString:SetFormattedText,
        SetVertexColor, SetAlphaFromBoolean...).
      * SetShown / SetAlpha reject secrets from addon code, so secret booleans
        are routed through SetAlphaFromBoolean instead.
      * Header buttons are created and sized out of combat only. Any layout
        change requested in combat is queued until PLAYER_REGEN_ENABLED.
      * No Lua keys are written onto the Blizzard-created header buttons; their
        state lives in the RF.data side table.
]]

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local RF = {}
ns.SUI_RaidFrames = RF

RF.data = {}            -- [frame] = per-frame state (real buttons and preview frames)
RF.buttons = {}         -- array of real header buttons
RF.headers = {}         -- party, group1..group8, raidAll
RF.movers = {}          -- party, raid (Edit Mode handles)
RF.previewFrames = { party = {}, raid = {} }
RF.previewSources = {}  -- [source] = true while that source wants the preview
RF.built = false
RF.pending = {}         -- work queued for PLAYER_REGEN_ENABLED

local MAX_RAID_GROUPS = 8
local MEMBERS_PER_GROUP = 5
local MAX_DEBUFFS = 8
local MAX_BUFFS = 6
local MAX_PRIVATE = 4

---------------------------------------------------------------------------
-- DEFAULTS (filled lazily into profile.suiRaidFrames, so no edit to the
-- shared defaults table in suicore_main.lua is needed)
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = false,
    hideBlizzard = true,
    party = {
        enabled = true,
        showPlayer = true,
        width = 120,
        height = 46,
        spacing = 2,
        growth = "DOWN",        -- DOWN / UP / RIGHT / LEFT
        sort = "INDEX",         -- INDEX / ROLE / NAME
    },
    raid = {
        enabled = true,
        width = 88,
        height = 40,
        spacing = 2,
        growth = "DOWN",        -- unit growth inside a group / column
        groupGrowth = "RIGHT",  -- direction groups / columns are added
        groupSpacing = 6,
        groupsPerLine = 8,      -- separate-group mode: groups before wrapping
        unitsPerColumn = 5,     -- combined mode (role / name sort)
        maxGroups = 8,
        sort = "GROUP",         -- GROUP / ROLE / NAME
        groupInnerSort = "INDEX", -- inside each group in GROUP mode: INDEX / ROLE / NAME
        previewSize = 20,
    },
    style = {
        texture = "",           -- empty = SuaviUI general texture
        followDarkMode = true,
        useClassColor = true,
        healthColor = { 0.2, 0.2, 0.2, 1 },
        bgColor = { 0.06, 0.06, 0.06, 0.9 },
        fontSize = 11,
        healthFontSize = 10,
        nameLength = 10,
        nameClassColor = false,
        healthText = "none",    -- none / percent / deficit
        showPower = true,
        powerHeight = 4,
        powerHealerOnly = true,
        showHealPrediction = true,
        showAbsorbs = true,
        showHealAbsorbs = true,
        targetHighlight = true,
        range = { enabled = true, alpha = 0.4 },
        dispel = { enabled = true, onlyMine = true, border = true, overlay = true, overlayAlpha = 0.25 },
        debuffs = { enabled = true, max = 3, size = 16, bossSize = 22, raidFilter = false },
        buffs = { enabled = true, max = 3, size = 12 },
        privateAuras = { enabled = true, max = 2, size = 20 },
        icons = {
            role = true, roleShowDamager = false, roleSize = 12,
            leader = true,
            marker = true, markerSize = 14,
            readyCheck = true,
            status = true,      -- incoming res / summon
            centerSize = 20,
        },
    },
    positions = {},             -- [editModeLayoutName] = { party = {point,x,y}, raid = {point,x,y} }
}

RF.DEFAULT_POS = {
    party = { point = "LEFT", x = 40, y = 120 },
    raid  = { point = "TOPLEFT", x = 40, y = -260 },
}

local function FillDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            FillDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local filledFor
function RF:GetDB()
    local profile = SUICore and SUICore.db and SUICore.db.profile
    if not profile then return nil end
    local db = profile.suiRaidFrames
    if type(db) ~= "table" then
        db = {}
        profile.suiRaidFrames = db
    end
    if filledFor ~= db then
        FillDefaults(db, DEFAULTS)
        filledFor = db
    end
    return db
end

local function GetGeneral()
    local profile = SUICore and SUICore.db and SUICore.db.profile
    return profile and profile.general
end

---------------------------------------------------------------------------
-- SECRET-SAFE HELPERS
---------------------------------------------------------------------------
local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- Call an API, swallowing errors (restricted unit tokens, aura access...)
local function Call(fn, ...)
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
    return nil
end

-- True when a value is present. Secret values count as present: they are
-- never nil-tested directly (a boolean test on a secret errors).
local function Has(v)
    return IsSecret(v) or v ~= nil
end

-- Returns the boolean only when it is a plain (non-secret) boolean.
local function PlainBool(v)
    if IsSecret(v) or v == nil then return nil end
    return v and true or false
end

-- Show a region from a boolean that may be secret.
local function ShowFromBool(region, value)
    if not Has(value) then
        region:Hide()
        return
    end
    if IsSecret(value) then
        region:Show()
        if not pcall(region.SetAlphaFromBoolean, region, value, 1, 0) then
            region:Hide()
        end
        return
    end
    region:SetAlpha(1)
    if value then region:Show() else region:Hide() end
end

local function Scale(x)
    if SUICore and SUICore.Scale then return SUICore:Scale(x) end
    return x
end

---------------------------------------------------------------------------
-- MEDIA
---------------------------------------------------------------------------
local function GetFontPath()
    local general = GetGeneral()
    local name = general and general.font or "Suavifont"
    return LSM:Fetch("font", name) or "Fonts\\FRIZQT__.TTF"
end

local function GetFontOutline()
    local general = GetGeneral()
    return general and general.fontOutline or "OUTLINE"
end

local function GetBarTexture()
    local db = RF:GetDB()
    local name = db and db.style.texture
    if not name or name == "" then
        local general = GetGeneral()
        name = general and general.texture or "Suavitex v3"
    end
    return LSM:Fetch("statusbar", name) or LSM:Fetch("statusbar", "Suavisolid") or "Interface\\Buttons\\WHITE8x8"
end

local WHITE = "Interface\\Buttons\\WHITE8x8"
local MARKER_TEXTURE = [[Interface\TargetingFrame\UI-RaidTargetingIcons]]

local ROLE_ATLAS = {
    TANK = "UI-LFG-RoleIcon-Tank-Micro",
    HEALER = "UI-LFG-RoleIcon-Healer-Micro",
    DAMAGER = "UI-LFG-RoleIcon-DPS-Micro",
}

local READY_ATLAS = {
    ready = "UI-LFG-ReadyMark",
    notready = "UI-LFG-DeclineMark",
    waiting = "UI-LFG-PendingMark",
}

-- Engine dispel type ids (x axis of the colour curve): 1 Magic, 2 Curse,
-- 3 Disease, 4 Poison, 9 Enrage, 11 Bleed.
local DISPEL_COLORS = {
    [1]  = { 0.20, 0.55, 1.00 },
    [2]  = { 0.62, 0.20, 0.95 },
    [3]  = { 0.75, 0.50, 0.10 },
    [4]  = { 0.10, 0.75, 0.25 },
    [9]  = { 0.90, 0.25, 0.15 },
    [11] = { 0.90, 0.25, 0.15 },
}

local dispelCurve, iconBorderCurve, deficitAlphaCurve
local function BuildCurves()
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return end
    local stepType = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step

    dispelCurve = C_CurveUtil.CreateColorCurve()
    iconBorderCurve = C_CurveUtil.CreateColorCurve()
    if stepType then
        dispelCurve:SetType(stepType)
        iconBorderCurve:SetType(stepType)
    end
    -- id 0 (no dispel type) is transparent for the highlight, dark red for icon borders
    dispelCurve:AddPoint(0, CreateColor(0, 0, 0, 0))
    iconBorderCurve:AddPoint(0, CreateColor(0.55, 0.05, 0.05, 1))
    local ids = { 1, 2, 3, 4, 9, 11 }
    for _, id in ipairs(ids) do
        local c = DISPEL_COLORS[id]
        dispelCurve:AddPoint(id, CreateColor(c[1], c[2], c[3], 1))
        iconBorderCurve:AddPoint(id, CreateColor(c[1], c[2], c[3], 1))
    end

    -- Health fraction -> text alpha. Hides "-0" deficit text at full health
    -- even when the health value is secret.
    if C_CurveUtil.CreateCurve then
        deficitAlphaCurve = C_CurveUtil.CreateCurve()
        if stepType then deficitAlphaCurve:SetType(stepType) end
        deficitAlphaCurve:AddPoint(0, 1)
        deficitAlphaCurve:AddPoint(0.9995, 0)
    end
end

---------------------------------------------------------------------------
-- GEOMETRY
---------------------------------------------------------------------------
local HEADER_POINT = { DOWN = "TOP", UP = "BOTTOM", RIGHT = "LEFT", LEFT = "RIGHT" }
local COLUMN_ANCHOR = { RIGHT = "LEFT", LEFT = "RIGHT", DOWN = "TOP", UP = "BOTTOM" }

local function IsVertical(dir) return dir == "DOWN" or dir == "UP" end

local function NormalizeGrowth(unitGrowth, groupGrowth)
    if unitGrowth ~= "UP" and unitGrowth ~= "RIGHT" and unitGrowth ~= "LEFT" then unitGrowth = "DOWN" end
    if IsVertical(unitGrowth) then
        if groupGrowth ~= "LEFT" then groupGrowth = "RIGHT" end
    else
        if groupGrowth ~= "UP" then groupGrowth = "DOWN" end
    end
    return unitGrowth, groupGrowth
end

local function CornerPoint(unitGrowth, groupGrowth)
    local v = (unitGrowth == "UP" or groupGrowth == "UP") and "BOTTOM" or "TOP"
    local h = (unitGrowth == "LEFT" or groupGrowth == "LEFT") and "RIGHT" or "LEFT"
    return v .. h
end

local function Step(dir, dx, dy)
    if dir == "DOWN" then return 0, -dy
    elseif dir == "UP" then return 0, dy
    elseif dir == "RIGHT" then return dx, 0
    else return -dx, 0 end
end

-- Resolved layout numbers for one kind ("party" / "raid")
function RF:GetLayout(kind)
    local db = self:GetDB()
    local cfg = db[kind]
    local L = {}
    L.w = Scale(cfg.width or 100)
    L.h = Scale(cfg.height or 40)
    L.s = cfg.spacing or 2
    if kind == "party" then
        L.unitGrowth, L.groupGrowth = NormalizeGrowth(cfg.growth, nil)
        L.count = cfg.showPlayer and MEMBERS_PER_GROUP or (MEMBERS_PER_GROUP - 1)
    else
        L.unitGrowth, L.groupGrowth = NormalizeGrowth(cfg.growth, cfg.groupGrowth)
        L.gs = cfg.groupSpacing or 6
        L.maxGroups = math.max(1, math.min(MAX_RAID_GROUPS, cfg.maxGroups or 8))
        L.perLine = math.max(1, math.min(MAX_RAID_GROUPS, cfg.groupsPerLine or 8))
        L.upc = math.max(1, math.min(40, cfg.unitsPerColumn or 5))
        L.combined = (cfg.sort == "ROLE" or cfg.sort == "NAME")
    end
    L.corner = CornerPoint(L.unitGrowth, L.groupGrowth)
    return L
end

-- Offsets (from the mover's corner) of every slot, plus the mover size.
function RF:ComputeSlots(kind, count)
    local L = self:GetLayout(kind)
    local slots = {}
    local ux, uy = Step(L.unitGrowth, L.w + L.s, L.h + L.s)
    local width, height

    if kind == "party" then
        count = count or L.count
        for i = 0, count - 1 do
            slots[#slots + 1] = { i * ux, i * uy }
        end
        local n = L.count
        if IsVertical(L.unitGrowth) then
            width, height = L.w, n * L.h + (n - 1) * L.s
        else
            width, height = n * L.w + (n - 1) * L.s, L.h
        end
        return slots, width, height, L
    end

    local gx, gy = Step(L.groupGrowth, L.w + L.gs, L.h + L.gs)
    if not L.combined then
        local groupLenW = MEMBERS_PER_GROUP * L.w + (MEMBERS_PER_GROUP - 1) * L.s
        local groupLenH = MEMBERS_PER_GROUP * L.h + (MEMBERS_PER_GROUP - 1) * L.s
        local wx, wy = Step(L.unitGrowth, groupLenW + L.gs, groupLenH + L.gs)
        L.groupOffsets = {}
        for g = 1, MAX_RAID_GROUPS do
            local k = g - 1
            local col = k % L.perLine
            local line = math.floor(k / L.perLine)
            L.groupOffsets[g] = { col * gx + line * wx, col * gy + line * wy }
        end
        count = count or (L.maxGroups * MEMBERS_PER_GROUP)
        for i = 0, count - 1 do
            local g = math.floor(i / MEMBERS_PER_GROUP) + 1
            local idx = i % MEMBERS_PER_GROUP
            local go = L.groupOffsets[g]
            if go then
                slots[#slots + 1] = { go[1] + idx * ux, go[2] + idx * uy }
            end
        end
        local cols = math.min(L.maxGroups, L.perLine)
        local lines = math.ceil(L.maxGroups / L.perLine)
        if IsVertical(L.unitGrowth) then
            width = cols * L.w + (cols - 1) * L.gs
            height = lines * groupLenH + (lines - 1) * L.gs
        else
            width = lines * groupLenW + (lines - 1) * L.gs
            height = cols * L.h + (cols - 1) * L.gs
        end
    else
        count = count or (L.maxGroups * MEMBERS_PER_GROUP)
        for i = 0, count - 1 do
            local col = math.floor(i / L.upc)
            local row = i % L.upc
            slots[#slots + 1] = { col * gx + row * ux, col * gy + row * uy }
        end
        local cols = math.ceil((L.maxGroups * MEMBERS_PER_GROUP) / L.upc)
        if IsVertical(L.unitGrowth) then
            width = cols * L.w + (cols - 1) * L.gs
            height = L.upc * L.h + (L.upc - 1) * L.s
        else
            width = L.upc * L.w + (L.upc - 1) * L.s
            height = cols * L.h + (cols - 1) * L.gs
        end
    end
    return slots, width, height, L
end

---------------------------------------------------------------------------
-- VISUALS (shared by header buttons and preview frames)
---------------------------------------------------------------------------
local function CreateEdgeBorder(parent, layer, thickness)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f.edges = {}
    for i = 1, 4 do
        local t = f:CreateTexture(nil, layer or "OVERLAY")
        t:SetTexture(WHITE)
        f.edges[i] = t
    end
    f.SetThickness = function(self, px)
        local e = self.edges
        e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(px)
        e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(px)
        e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(px)
        e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(px)
    end
    f.SetColor = function(self, r, g, b)
        for i = 1, 4 do self.edges[i]:SetVertexColor(r, g, b) end
    end
    f:SetThickness(thickness or 1)
    return f
end

local function CreateAuraIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(16, 16)
    icon.border = icon:CreateTexture(nil, "BACKGROUND")
    icon.border:SetAllPoints()
    icon.border:SetTexture(WHITE)
    icon.border:SetVertexColor(0, 0, 0)
    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    icon.tex:SetPoint("TOPLEFT", 1, -1)
    icon.tex:SetPoint("BOTTOMRIGHT", -1, 1)
    icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cd:SetAllPoints(icon.tex)
    icon.cd:SetDrawEdge(false)
    icon.cd:SetReverse(true)
    if icon.cd.SetHideCountdownNumbers then icon.cd:SetHideCountdownNumbers(true) end
    icon.cd:EnableMouse(false)
    local textHolder = CreateFrame("Frame", nil, icon)
    textHolder:SetAllPoints()
    textHolder:SetFrameLevel(icon.cd:GetFrameLevel() + 2)
    icon.count = textHolder:CreateFontString(nil, "OVERLAY")
    icon.count:SetPoint("BOTTOMRIGHT", 1, -1)
    icon.count:SetJustifyH("RIGHT")
    icon:Hide()
    return icon
end

local function BuildVisuals(owner, isPreview)
    local d = { owner = owner, isPreview = isPreview }

    local root = CreateFrame("Frame", nil, owner, "BackdropTemplate")
    root:SetAllPoints(owner)
    d.root = root

    local health = CreateFrame("StatusBar", nil, root)
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    health:SetClipsChildren(true)
    d.health = health
    local fill = health:GetStatusBarTexture()

    -- Incoming heals -> damage absorbs, chained from the end of the health fill
    local healPred = CreateFrame("StatusBar", nil, health)
    healPred:SetPoint("TOPLEFT", health, "TOPLEFT")
    healPred:SetMinMaxValues(0, 1)
    healPred:SetValue(0)
    d.healPred = healPred

    local absorb = CreateFrame("StatusBar", nil, health)
    absorb:SetMinMaxValues(0, 1)
    absorb:SetValue(0)
    d.absorb = absorb

    local healAbsorb = CreateFrame("StatusBar", nil, health)
    healAbsorb:SetReverseFill(true)
    healAbsorb:SetMinMaxValues(0, 1)
    healAbsorb:SetValue(0)
    d.healAbsorb = healAbsorb

    d.fill = fill

    local overAbsorb = health:CreateTexture(nil, "OVERLAY")
    overAbsorb:SetTexture(WHITE)
    overAbsorb:SetVertexColor(0.8, 0.95, 1, 0.9)
    overAbsorb:SetPoint("TOPRIGHT", health, "TOPRIGHT", 0, 0)
    overAbsorb:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
    overAbsorb:SetWidth(2)
    overAbsorb:Hide()
    d.overAbsorb = overAbsorb

    local dispelOverlay = health:CreateTexture(nil, "OVERLAY", nil, 2)
    dispelOverlay:SetAllPoints(health)
    dispelOverlay:SetTexture(WHITE)
    dispelOverlay:Hide()
    d.dispelOverlay = dispelOverlay

    local power = CreateFrame("StatusBar", nil, root)
    power:SetMinMaxValues(0, 1)
    power:SetValue(0)
    d.power = power
    d.powerBg = power:CreateTexture(nil, "BACKGROUND")
    d.powerBg:SetAllPoints()
    d.powerBg:SetTexture(WHITE)
    d.powerBg:SetVertexColor(0, 0, 0, 0.6)

    -- Overlay layer (text, icons, auras) above every bar
    local over = CreateFrame("Frame", nil, root)
    over:SetAllPoints(root)
    over:SetFrameLevel(root:GetFrameLevel() + 6)
    d.over = over

    d.name = over:CreateFontString(nil, "OVERLAY")
    d.name:SetWordWrap(false)
    d.healthText = over:CreateFontString(nil, "OVERLAY")
    d.statusText = over:CreateFontString(nil, "OVERLAY")
    d.afkText = over:CreateFontString(nil, "OVERLAY")
    d.afkText:SetFont(GetFontPath(), 9, GetFontOutline())
    d.afkText:SetText("AFK")
    d.afkText:SetTextColor(1, 0.8, 0.2)

    d.role = over:CreateTexture(nil, "OVERLAY")
    d.leader = over:CreateTexture(nil, "OVERLAY")
    d.leader:SetTexture([[Interface\GroupFrame\UI-Group-LeaderIcon]])
    d.assist = over:CreateTexture(nil, "OVERLAY")
    d.assist:SetTexture([[Interface\GroupFrame\UI-Group-AssistantIcon]])
    d.marker = over:CreateTexture(nil, "OVERLAY")
    d.marker:SetTexture(MARKER_TEXTURE)
    d.ready = over:CreateTexture(nil, "OVERLAY", nil, 3)
    d.center = over:CreateTexture(nil, "OVERLAY", nil, 3)
    d.role:Hide(); d.leader:Hide(); d.assist:Hide(); d.marker:Hide(); d.ready:Hide(); d.center:Hide()

    d.dispelBorder = CreateEdgeBorder(over, "OVERLAY", 2)
    d.dispelBorder:Hide()
    d.targetBorder = CreateEdgeBorder(root, "OVERLAY", 1)
    d.targetBorder:SetFrameLevel(over:GetFrameLevel() + 1)
    d.targetBorder:SetColor(1, 1, 1)
    d.targetBorder:Hide()

    d.debuffs = {}
    for i = 1, MAX_DEBUFFS do d.debuffs[i] = CreateAuraIcon(over) end
    d.buffs = {}
    for i = 1, MAX_BUFFS do d.buffs[i] = CreateAuraIcon(over) end

    if not isPreview then
        d.privateAnchors = {}
        d.privateIDs = {}
        for i = 1, MAX_PRIVATE do
            local a = CreateFrame("Frame", nil, over)
            a:SetSize(20, 20)
            d.privateAnchors[i] = a
        end
    end

    -- Prediction bars span the full health width
    health:SetScript("OnSizeChanged", function(self, w)
        healPred:SetWidth(w)
        absorb:SetWidth(w)
        healAbsorb:SetWidth(w)
    end)

    return d
end

-- Apply sizes, fonts, colours and anchors from the current settings.
local function Restyle(d)
    local db = RF:GetDB()
    if not db then return end
    local st = db.style
    local general = GetGeneral()
    local tex = GetBarTexture()
    local font, outline = GetFontPath(), GetFontOutline()

    local root = d.root
    root:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    local bg = st.bgColor
    if st.followDarkMode and general and general.darkMode and general.darkModeBgColor then
        bg = general.darkModeBgColor
    end
    root:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    root:SetBackdropBorderColor(0, 0, 0, 1)

    local showPower = d.powerShown and true or false
    local ph = showPower and (st.powerHeight or 4) or 0
    local health, power = d.health, d.power

    health:ClearAllPoints()
    health:SetPoint("TOPLEFT", root, "TOPLEFT", 1, -1)
    health:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -1, 1 + ph + (showPower and 1 or 0))
    health:SetStatusBarTexture(tex)
    d.fill = health:GetStatusBarTexture()

    power:ClearAllPoints()
    power:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 1, 1)
    power:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -1, 1)
    power:SetHeight(math.max(1, ph))
    power:SetStatusBarTexture(tex)
    power:SetShown(showPower)

    local fill = d.fill
    d.healPred:SetStatusBarTexture(tex)
    d.healPred:SetStatusBarColor(0.25, 0.85, 0.35, 0.55)
    d.healPred:ClearAllPoints()
    d.healPred:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
    d.healPred:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", 0, 0)

    local absorbTex = LSM:Fetch("statusbar", "Suavistripes") or tex
    d.absorb:SetStatusBarTexture(absorbTex)
    d.absorb:SetStatusBarColor(1, 1, 1, 0.7)
    local predFill = d.healPred:GetStatusBarTexture()
    d.absorb:ClearAllPoints()
    d.absorb:SetPoint("TOPLEFT", predFill, "TOPRIGHT", 0, 0)
    d.absorb:SetPoint("BOTTOMLEFT", predFill, "BOTTOMRIGHT", 0, 0)

    d.healAbsorb:SetStatusBarTexture(tex)
    d.healAbsorb:SetStatusBarColor(0.6, 0.1, 0.1, 0.75)
    d.healAbsorb:ClearAllPoints()
    d.healAbsorb:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
    d.healAbsorb:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)

    local w = health:GetWidth()
    if w and w > 0 then
        d.healPred:SetWidth(w); d.absorb:SetWidth(w); d.healAbsorb:SetWidth(w)
    end

    -- Text
    local fs = st.fontSize or 11
    local hfs = st.healthFontSize or 10
    d.name:SetFont(font, fs, outline)
    d.healthText:SetFont(font, hfs, outline)
    d.statusText:SetFont(font, hfs, outline)
    d.afkText:SetFont(font, math.max(7, hfs - 2), outline)

    local textOffset = (st.healthText ~= "none") and 5 or 0
    d.name:ClearAllPoints()
    d.name:SetPoint("LEFT", health, "LEFT", 2, textOffset)
    d.name:SetPoint("RIGHT", health, "RIGHT", -2, textOffset)
    d.name:SetJustifyH("CENTER")
    d.healthText:ClearAllPoints()
    d.healthText:SetPoint("CENTER", health, "CENTER", 0, -6)
    d.statusText:ClearAllPoints()
    d.statusText:SetPoint("CENTER", health, "CENTER", 0, -6)
    d.afkText:ClearAllPoints()
    d.afkText:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", -2, 2)

    -- Icons
    local ic = st.icons
    local rs = ic.roleSize or 12
    d.role:SetSize(rs, rs)
    d.role:ClearAllPoints()
    d.role:SetPoint("TOPLEFT", root, "TOPLEFT", 2, -2)
    d.leader:SetSize(rs, rs)
    d.leader:ClearAllPoints()
    d.leader:SetPoint("LEFT", d.role, "RIGHT", 1, 0)
    d.assist:SetSize(rs, rs)
    d.assist:ClearAllPoints()
    d.assist:SetPoint("LEFT", d.role, "RIGHT", 1, 0)
    local ms = ic.markerSize or 14
    d.marker:SetSize(ms, ms)
    d.marker:ClearAllPoints()
    d.marker:SetPoint("TOP", root, "TOP", 0, -1)
    local cs = ic.centerSize or 20
    d.ready:SetSize(cs, cs)
    d.ready:ClearAllPoints()
    d.ready:SetPoint("CENTER", health, "CENTER")
    d.center:SetSize(cs, cs)
    d.center:ClearAllPoints()
    d.center:SetPoint("CENTER", health, "CENTER")

    -- Auras
    local countSize = math.max(7, math.floor((st.debuffs.size or 16) * 0.55))
    for i = 1, MAX_DEBUFFS do
        d.debuffs[i].count:SetFont(font, countSize, "OUTLINE")
    end
    for i = 1, MAX_BUFFS do
        local b = d.buffs[i]
        b.count:SetFont(font, math.max(6, math.floor((st.buffs.size or 12) * 0.6)), "OUTLINE")
        b:SetSize(st.buffs.size or 12, st.buffs.size or 12)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", health, "TOPRIGHT", -1 - (i - 1) * ((st.buffs.size or 12) + 1), -1)
    end

    if d.privateAnchors then
        local pa = st.privateAuras
        local size = pa.size or 20
        local n = math.max(1, math.min(MAX_PRIVATE, pa.max or 2))
        local total = n * size + (n - 1) * 2
        for i = 1, MAX_PRIVATE do
            local a = d.privateAnchors[i]
            a:SetSize(size, size)
            a:ClearAllPoints()
            a:SetPoint("LEFT", health, "CENTER", -total / 2 + (i - 1) * (size + 2), 0)
        end
    end

    d.dispelOverlay:SetAlpha(st.dispel.overlayAlpha or 0.25)
end

---------------------------------------------------------------------------
-- UPDATES (real units)
---------------------------------------------------------------------------
local function GetRole(unit)
    local role = Call(UnitGroupRolesAssigned, unit)
    if IsSecret(role) or role == nil then return nil end
    return role
end

local function ShouldShowPower(d, unit)
    local st = RF:GetDB().style
    if not st.showPower then return false end
    if st.powerHealerOnly then
        local role
        if d.isPreview then role = d.fakeRole else role = GetRole(unit) end
        return role == "HEALER"
    end
    return true
end

local function TruncateName(name, maxLen)
    if IsSecret(name) then return name end
    if name == nil then return "" end
    if not maxLen or maxLen <= 0 or #name <= maxLen then return name end
    -- UTF-8 aware cut
    local i, c, n = 1, 0, #name
    while i <= n and c < maxLen do
        c = c + 1
        local b = string.byte(name, i)
        if b < 0x80 then i = i + 1
        elseif b < 0xE0 then i = i + 2
        elseif b < 0xF0 then i = i + 3
        else i = i + 4 end
    end
    return string.sub(name, 1, i - 1)
end

local function SetHealthColor(d, unit)
    local db = RF:GetDB()
    local st = db.style
    local general = GetGeneral()
    local bar = d.health
    if d.state then
        bar:SetStatusBarColor(0.35, 0.35, 0.35, 1)
        return
    end
    if st.followDarkMode and general and general.darkMode and general.darkModeHealthColor then
        local c = general.darkModeHealthColor
        bar:SetStatusBarColor(c[1], c[2], c[3], 1)
        return
    end
    if st.useClassColor and d.hasClass then
        bar:SetStatusBarColor(d.classR, d.classG, d.classB, 1)
        return
    end
    local c = st.healthColor
    bar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
end

local function UpdateClassColor(d, unit)
    d.classR, d.classG, d.classB, d.hasClass = nil, nil, nil, false
    local _, class = Call(UnitClass, unit)
    if not Has(class) then return end
    -- GetClassColor legally takes a secret class token; r/g/b may come back
    -- secret and are only ever handed to colour setters.
    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = Call(C_ClassColor.GetClassColor, class)
        if color then
            d.classR, d.classG, d.classB, d.hasClass = color.r, color.g, color.b, true
            return
        end
    end
    if not IsSecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        d.classR, d.classG, d.classB, d.hasClass = c.r, c.g, c.b, true
    end
end

local function UpdateName(d, unit)
    local st = RF:GetDB().style
    local name = Call(UnitName, unit)
    if not Has(name) then
        d.name:SetText("")
        return
    end
    local maxLen = st.nameLength or 10
    if IsSecret(name) then
        -- Secret names cannot be measured or cut by characters: show in full
        if not pcall(d.name.SetText, d.name, name) then
            d.name:SetText("")
        end
    else
        d.name:SetText(TruncateName(name, maxLen))
    end
    if st.nameClassColor and d.hasClass then
        d.name:SetTextColor(d.classR, d.classG, d.classB)
    else
        d.name:SetTextColor(1, 1, 1)
    end
end

local function UpdateHealthText(d, unit)
    local st = RF:GetDB().style
    local fs = d.healthText
    local mode = st.healthText
    if mode == "none" or d.state then
        fs:Hide()
        return
    end
    fs:Show()
    fs:SetTextColor(1, 1, 1, 1)
    if mode == "percent" then
        local curve = CurveConstants and CurveConstants.ScaleTo100
        local pct = Call(UnitHealthPercent, unit, true, curve)
        if not Has(pct) or not pcall(fs.SetFormattedText, fs, "%.0f%%", pct) then
            fs:SetText("")
        end
    elseif mode == "deficit" then
        local missing = Call(UnitHealthMissing, unit, true)
        if not Has(missing) then fs:SetText("") return end
        local abbr = Call(AbbreviateNumbers or AbbreviateLargeNumbers, missing)
        if not Has(abbr) or not pcall(fs.SetFormattedText, fs, "-%s", abbr) then
            fs:SetText("")
            return
        end
        if deficitAlphaCurve then
            local a = Call(UnitHealthPercent, unit, true, deficitAlphaCurve)
            if Has(a) then pcall(fs.SetTextColor, fs, 1, 1, 1, a) end
        end
    end
end

local function UpdateHealth(d, unit)
    local hp = Call(UnitHealth, unit)
    local maxhp = Call(UnitHealthMax, unit)
    local bar = d.health
    if Has(maxhp) then pcall(bar.SetMinMaxValues, bar, 0, maxhp) end
    if Has(hp) then pcall(bar.SetValue, bar, hp) end
    d.maxhp = maxhp

    local connected = PlainBool(Call(UnitIsConnected, unit))
    local dead = PlainBool(Call(UnitIsDeadOrGhost, unit))
    local state
    if connected == false then
        state = PLAYER_OFFLINE or "Offline"
    elseif dead then
        state = PlainBool(Call(UnitIsGhost, unit)) and "Ghost" or (DEAD or "Dead")
    end
    d.state = state
    if state then
        d.statusText:SetText(state)
        d.statusText:Show()
    else
        d.statusText:Hide()
    end
    SetHealthColor(d, unit)
    UpdateHealthText(d, unit)
end

-- Secret amounts go straight into the bar; a disabled part reads 0.
local function FeedBar(bar, maxhp, enabled, amount)
    pcall(bar.SetMinMaxValues, bar, 0, maxhp)
    if enabled and Has(amount) then
        if not pcall(bar.SetValue, bar, amount) then bar:SetValue(0) end
    else
        bar:SetValue(0)
    end
end

local function UpdatePrediction(d, unit)
    local st = RF:GetDB().style
    local maxhp = d.maxhp
    if not Has(maxhp) then return end

    local incoming, absorb, clamped, healAbsorb
    if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
        if not d.calc then
            d.calc = CreateUnitHealPredictionCalculator()
            local calc = d.calc
            pcall(calc.SetIncomingHealClampMode, calc, 0)  -- missing health
            pcall(calc.SetDamageAbsorbClampMode, calc, 0)  -- missing health minus incoming heals
            pcall(calc.SetHealAbsorbClampMode, calc, 0)    -- current health
            pcall(calc.SetHealAbsorbMode, calc, 1)         -- totals, no cross reduction
        end
        local calc = d.calc
        if pcall(UnitGetDetailedHealPrediction, unit, "player", calc) then
            incoming = Call(calc.GetIncomingHeals, calc)
            absorb, clamped = Call(calc.GetDamageAbsorbs, calc)
            healAbsorb = Call(calc.GetHealAbsorbs, calc)
        end
    else
        incoming = Call(UnitGetIncomingHeals, unit)
        absorb = Call(UnitGetTotalAbsorbs, unit)
        healAbsorb = Call(UnitGetTotalHealAbsorbs, unit)
    end

    FeedBar(d.healPred, maxhp, st.showHealPrediction, incoming)
    FeedBar(d.absorb, maxhp, st.showAbsorbs, absorb)
    FeedBar(d.healAbsorb, maxhp, st.showHealAbsorbs, healAbsorb)

    if st.showAbsorbs and Has(clamped) then
        ShowFromBool(d.overAbsorb, clamped)
    else
        d.overAbsorb:Hide()
    end
end

local function UpdatePower(d, unit)
    local show = ShouldShowPower(d, unit)
    if show ~= d.powerShown then
        d.powerShown = show
        Restyle(d)
    end
    if not show then return end
    local _, token = Call(UnitPowerType, unit)
    local color
    if PowerBarColor then
        if not IsSecret(token) and token then color = PowerBarColor[token] end
        color = color or PowerBarColor["MANA"]
    end
    if color then d.power:SetStatusBarColor(color.r, color.g, color.b, 1) end
    local maxp = Call(UnitPowerMax, unit)
    local p = Call(UnitPower, unit)
    if Has(maxp) then pcall(d.power.SetMinMaxValues, d.power, 0, maxp) end
    if Has(p) then pcall(d.power.SetValue, d.power, p) end
end

local function UpdateRole(d, unit)
    local ic = RF:GetDB().style.icons
    if not ic.role then d.role:Hide() return end
    local role = GetRole(unit)
    if role == "DAMAGER" and not ic.roleShowDamager then role = nil end
    local atlas = role and ROLE_ATLAS[role]
    if atlas then
        d.role:SetAtlas(atlas)
        d.role:Show()
    else
        d.role:Hide()
    end
end

local function UpdateLeader(d, unit)
    local ic = RF:GetDB().style.icons
    if not ic.leader or not IsInGroup() then
        d.leader:Hide(); d.assist:Hide()
        return
    end
    ShowFromBool(d.leader, Call(UnitIsGroupLeader, unit))
    if IsInRaid() then
        ShowFromBool(d.assist, Call(UnitIsGroupAssistant, unit))
    else
        d.assist:Hide()
    end
end

local function UpdateMarker(d, unit)
    local ic = RF:GetDB().style.icons
    if not ic.marker then d.marker:Hide() return end
    local index = Call(GetRaidTargetIndex, unit)
    if not Has(index) then d.marker:Hide() return end
    -- SetSpriteSheetCell takes a secret index; a secret nil fails and hides
    if SetRaidTargetIconTexture and pcall(SetRaidTargetIconTexture, d.marker, index) then
        d.marker:Show()
    else
        d.marker:Hide()
    end
end

local function UpdateReadyCheck(d, unit)
    local ic = RF:GetDB().style.icons
    if not ic.readyCheck or not RF.readyCheckActive then d.ready:Hide() return end
    local status = GetReadyCheckStatus and Call(GetReadyCheckStatus, unit)
    if IsSecret(status) or status == nil then d.ready:Hide() return end
    if RF.readyCheckFinished and status == "waiting" then status = "notready" end
    local atlas = READY_ATLAS[status]
    if atlas then
        d.ready:SetAtlas(atlas)
        d.ready:Show()
    else
        d.ready:Hide()
    end
end

local function UpdateCenterStatus(d, unit)
    local ic = RF:GetDB().style.icons
    if not ic.status then d.center:Hide() return end
    local atlas
    if C_IncomingSummon and C_IncomingSummon.HasIncomingSummon and PlainBool(Call(C_IncomingSummon.HasIncomingSummon, unit)) then
        local status = Call(C_IncomingSummon.IncomingSummonStatus, unit)
        if not IsSecret(status) and status ~= nil and Enum and Enum.SummonStatus then
            if status == Enum.SummonStatus.Pending then atlas = "RaidFrame-Icon-SummonPending"
            elseif status == Enum.SummonStatus.Accepted then atlas = "RaidFrame-Icon-SummonAccepted"
            elseif status == Enum.SummonStatus.Declined then atlas = "RaidFrame-Icon-SummonDeclined" end
        end
    end
    if not atlas and UnitHasIncomingResurrection and PlainBool(Call(UnitHasIncomingResurrection, unit)) then
        atlas = "RaidFrame-Icon-Rez"
    end
    if atlas then
        d.center:SetAtlas(atlas)
        d.center:Show()
    else
        d.center:Hide()
    end
end

local function UpdateAFK(d, unit)
    if d.state then d.afkText:Hide() return end
    ShowFromBool(d.afkText, Call(UnitIsAFK, unit))
end

local function UpdateTarget(d, unit)
    if not RF:GetDB().style.targetHighlight then d.targetBorder:Hide() return end
    ShowFromBool(d.targetBorder, Call(UnitIsUnit, unit, "target"))
end

local function UpdateRange(d, unit)
    local r = RF:GetDB().style.range
    local root = d.root
    if not r.enabled or d.isPlayer then
        root:SetAlpha(1)
        return
    end
    local oor = r.alpha or 0.4
    local ok, inRange, checked = pcall(UnitInRange, unit)
    if not ok then
        root:SetAlpha(1)
        return
    end
    if IsSecret(checked) or IsSecret(inRange) then
        -- A plain false "checked" means the game could not test range: stay opaque
        if not IsSecret(checked) and checked == false then
            root:SetAlpha(1)
            return
        end
        if not pcall(root.SetAlphaFromBoolean, root, inRange, 1, oor) then root:SetAlpha(1) end
        return
    end
    if inRange == nil or checked == false then
        root:SetAlpha(1)
        return
    end
    if checked and not inRange then root:SetAlpha(oor) else root:SetAlpha(1) end
end

-- Duration onto a cooldown swipe without touching (possibly secret) numbers
local function SetAuraCooldown(cd, unit, auraInstanceID)
    if not Has(auraInstanceID) or not C_UnitAuras.GetAuraDuration or not cd.SetCooldownFromDurationObject then
        cd:Hide()
        return
    end
    local duration = Call(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
    if Has(duration) and pcall(cd.SetCooldownFromDurationObject, cd, duration, true) then
        cd:Show()
    else
        cd:Hide()
    end
end

local function SetAuraCount(fs, unit, auraInstanceID)
    if not Has(auraInstanceID) or not C_UnitAuras.GetAuraApplicationDisplayCount then
        fs:SetText("")
        return
    end
    local text = Call(C_UnitAuras.GetAuraApplicationDisplayCount, unit, auraInstanceID, 2, 99)
    if not Has(text) or not pcall(fs.SetText, fs, text) then fs:SetText("") end
end

local function GetAuraList(unit, filter, max)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return nil end
    local sortRule = Enum and Enum.UnitAuraSortRule and Enum.UnitAuraSortRule.Default
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter, max, sortRule)
    if ok and type(list) == "table" then return list end
    return nil
end

local function UpdateAuras(d, unit)
    local st = RF:GetDB().style

    -- Debuffs
    local deb = st.debuffs
    local shown = 0
    if deb.enabled then
        local max = math.max(0, math.min(MAX_DEBUFFS, deb.max or 3))
        local filter = deb.raidFilter and "HARMFUL|RAID_IN_COMBAT" or "HARMFUL"
        local list = max > 0 and GetAuraList(unit, filter, max)
        local x = 1
        if list then
            for i = 1, max do
                local aura = list[i]
                if IsSecret(aura) or not aura then break end
                local icon = d.debuffs[i]
                local big = aura.isBossAura
                big = (not IsSecret(big)) and big == true
                local size = big and (deb.bossSize or 22) or (deb.size or 16)
                icon:SetSize(size, size)
                icon:ClearAllPoints()
                icon:SetPoint("BOTTOMLEFT", d.health, "BOTTOMLEFT", x, 1)
                x = x + size + 1
                pcall(icon.tex.SetTexture, icon.tex, aura.icon)
                local id = aura.auraInstanceID
                SetAuraCooldown(icon.cd, unit, id)
                SetAuraCount(icon.count, unit, id)
                local color = iconBorderCurve and Has(id) and Call(C_UnitAuras.GetAuraDispelTypeColor, unit, id, iconBorderCurve)
                if color then
                    pcall(icon.border.SetVertexColor, icon.border, color.r, color.g, color.b)
                else
                    icon.border:SetVertexColor(0.55, 0.05, 0.05)
                end
                icon:Show()
                shown = i
            end
        end
    end
    for i = shown + 1, MAX_DEBUFFS do d.debuffs[i]:Hide() end

    -- Own buffs / HoTs
    local bf = st.buffs
    shown = 0
    if bf.enabled then
        local max = math.max(0, math.min(MAX_BUFFS, bf.max or 3))
        local list = max > 0 and GetAuraList(unit, "HELPFUL|PLAYER|RAID_IN_COMBAT", max)
        if list then
            for i = 1, max do
                local aura = list[i]
                if IsSecret(aura) or not aura then break end
                local icon = d.buffs[i]
                pcall(icon.tex.SetTexture, icon.tex, aura.icon)
                SetAuraCooldown(icon.cd, unit, aura.auraInstanceID)
                SetAuraCount(icon.count, unit, aura.auraInstanceID)
                icon:Show()
                shown = i
            end
        end
    end
    for i = shown + 1, MAX_BUFFS do d.buffs[i]:Hide() end

    -- Dispel highlight
    local dp = st.dispel
    local dispelColor
    if dp.enabled and dispelCurve then
        local filter = dp.onlyMine and "HARMFUL|RAID" or "HARMFUL|RAID_PLAYER_DISPELLABLE"
        local list = GetAuraList(unit, filter, 1)
        local aura = list and list[1]
        if not IsSecret(aura) and aura and Has(aura.auraInstanceID) then
            dispelColor = Call(C_UnitAuras.GetAuraDispelTypeColor, unit, aura.auraInstanceID, dispelCurve)
        end
    end
    if dispelColor then
        local r, g, b = dispelColor.r, dispelColor.g, dispelColor.b
        if dp.border then
            pcall(d.dispelBorder.SetColor, d.dispelBorder, r, g, b)
            d.dispelBorder:Show()
        else
            d.dispelBorder:Hide()
        end
        if dp.overlay then
            pcall(d.dispelOverlay.SetVertexColor, d.dispelOverlay, r, g, b)
            d.dispelOverlay:Show()
        else
            d.dispelOverlay:Hide()
        end
    else
        d.dispelBorder:Hide()
        d.dispelOverlay:Hide()
    end
end

local function RemovePrivateAnchors(d)
    if not d.privateIDs then return end
    for i, id in pairs(d.privateIDs) do
        if C_UnitAuras and C_UnitAuras.RemovePrivateAuraAnchor then
            pcall(C_UnitAuras.RemovePrivateAuraAnchor, id)
        end
        d.privateIDs[i] = nil
    end
end

local function UpdatePrivateAnchors(d, unit)
    if not d.privateAnchors then return end
    RemovePrivateAnchors(d)
    local pa = RF:GetDB().style.privateAuras
    if not pa.enabled or not unit or not (C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor) then return end
    local n = math.max(1, math.min(MAX_PRIVATE, pa.max or 2))
    local size = pa.size or 20
    for i = 1, n do
        local anchor = d.privateAnchors[i]
        local args = {
            unitToken = unit,
            auraIndex = i,
            parent = anchor,
            showCooldownFrame = true,
            showCooldownEdge = false,
            showCountdownNumbers = false,
            showDispelIcon = false,
            isContainer = false,
            iconInfo = {
                iconAnchor = { point = "CENTER", relativeTo = anchor, relativePoint = "CENTER", offsetX = 0, offsetY = 0 },
                iconWidth = size,
                iconHeight = size,
            },
        }
        local id = Call(C_UnitAuras.AddPrivateAuraAnchor, args)
        if Has(id) then d.privateIDs[i] = id end
    end
end

local function FullUpdate(d)
    local unit = d.unit
    if not unit or d.isPreview then return end
    if not Call(UnitExists, unit) then return end
    UpdateClassColor(d, unit)
    UpdateName(d, unit)
    UpdateHealth(d, unit)
    UpdatePrediction(d, unit)
    UpdatePower(d, unit)
    UpdateRole(d, unit)
    UpdateLeader(d, unit)
    UpdateMarker(d, unit)
    UpdateReadyCheck(d, unit)
    UpdateCenterStatus(d, unit)
    UpdateAFK(d, unit)
    UpdateTarget(d, unit)
    UpdateRange(d, unit)
    UpdateAuras(d, unit)
end
RF.FullUpdate = FullUpdate

---------------------------------------------------------------------------
-- UNIT -> BUTTON MAP
---------------------------------------------------------------------------
local unitMap = {}
local unitMapDirty = true

local function RebuildUnitMap()
    wipe(unitMap)
    for _, btn in ipairs(RF.buttons) do
        local d = RF.data[btn]
        local unit = d and d.unit
        if unit and btn:IsVisible() then
            unitMap[unit] = unitMap[unit] or {}
            table.insert(unitMap[unit], d)
            -- Raid tokens that point at the player also answer to "player" events
            d.isPlayer = (unit == "player") or (PlainBool(Call(UnitIsUnit, unit, "player")) == true)
            if d.isPlayer and unit ~= "player" then
                unitMap.player = unitMap.player or {}
                table.insert(unitMap.player, d)
            end
        end
    end
    unitMapDirty = false
end

local function ForUnit(unit, fn)
    if unitMapDirty then RebuildUnitMap() end
    local list = unitMap[unit]
    if not list then return end
    for i = 1, #list do
        fn(list[i], list[i].unit)
    end
end

local function ForAll(fn)
    if unitMapDirty then RebuildUnitMap() end
    for _, btn in ipairs(RF.buttons) do
        local d = RF.data[btn]
        if d and d.unit and btn:IsVisible() then fn(d, d.unit) end
    end
end

---------------------------------------------------------------------------
-- HEADER BUTTONS
---------------------------------------------------------------------------
local function OnButtonAttributeChanged(btn, name, value)
    if name ~= "unit" then return end
    local d = RF.data[btn]
    if not d then return end
    if d.unit ~= value then
        d.unit = value
        d.isPlayer = (value == "player") or (value ~= nil and PlainBool(Call(UnitIsUnit, value, "player")) == true)
        unitMapDirty = true
        UpdatePrivateAnchors(d, value)
        if value and btn:IsVisible() then FullUpdate(d) end
    end
end

local function OnButtonShow(btn)
    local d = RF.data[btn]
    if not d then return end
    unitMapDirty = true
    d.unit = btn:GetAttribute("unit")
    d.isPlayer = (d.unit == "player") or (d.unit ~= nil and PlainBool(Call(UnitIsUnit, d.unit, "player")) == true)
    FullUpdate(d)
end

local function OnButtonHide(btn)
    unitMapDirty = true
end

local function OnButtonEnter(btn)
    local unit = btn:GetAttribute("unit")
    if not unit then return end
    local ufdb = SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.suiUnitFrames
    if ufdb and ufdb.general and ufdb.general.showTooltips == false then return end
    if not Call(UnitExists, unit) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, btn)
    GameTooltip:SetUnit(unit)
    GameTooltip:Show()
end

local function OnButtonLeave()
    GameTooltip:Hide()
end

-- Called from the header's restricted initialConfigFunction via CallMethod
local function HeaderInitButton(header, buttonName)
    local btn = buttonName and _G[buttonName]
    if not btn or RF.data[btn] then return end
    local d = BuildVisuals(btn, false)
    d.header = header
    RF.data[btn] = d
    table.insert(RF.buttons, btn)
    d.powerShown = false
    Restyle(d)

    if InCombatLockdown() then
        RF.pending.clicks = RF.pending.clicks or {}
        table.insert(RF.pending.clicks, btn)
    else
        btn:RegisterForClicks("AnyUp")
    end

    btn:HookScript("OnAttributeChanged", OnButtonAttributeChanged)
    btn:HookScript("OnShow", OnButtonShow)
    btn:HookScript("OnHide", OnButtonHide)
    btn:HookScript("OnEnter", OnButtonEnter)
    btn:HookScript("OnLeave", OnButtonLeave)

    -- Clique (and other click-cast addons) pick frames up from this table
    _G.ClickCastFrames = _G.ClickCastFrames or {}
    _G.ClickCastFrames[btn] = true
end

local INIT_SNIPPET = [[
    local header = self:GetParent()
    self:SetWidth(header:GetAttribute("suirf-width"))
    self:SetHeight(header:GetAttribute("suirf-height"))
    self:SetAttribute("*type1", "target")
    self:SetAttribute("*type2", "togglemenu")
    header:CallMethod("SUIRF_InitButton", self:GetName())
]]

local function CreateHeader(name, isRaid)
    local hdr = CreateFrame("Frame", name, UIParent, "SecureGroupHeaderTemplate")
    hdr.SUIRF_InitButton = HeaderInitButton
    hdr:SetAttribute("template", "SecureUnitButtonTemplate,PingableUnitFrameTemplate")
    hdr:SetAttribute("initialConfigFunction", INIT_SNIPPET)
    if isRaid then
        hdr:SetAttribute("showRaid", true)
    else
        hdr:SetAttribute("showParty", true)
    end
    hdr:SetAttribute("suirf-width", 80)
    hdr:SetAttribute("suirf-height", 40)
    return hdr
end

-- Make the header create `count` buttons now (out of combat), so nothing has
-- to be created or sized later while combat lockdown is active.
-- Number of units this header will list right now (so pre-creation can ask
-- for exactly the missing buttons instead of count extra on top of the roster).
local function HeaderUnitCount(hdr)
    local filter = hdr:GetAttribute("groupFilter")
    if hdr:GetAttribute("showParty") then
        local n = (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0)
        if hdr:GetAttribute("showPlayer") then n = n + 1 end
        return n
    end
    if not IsInRaid or not IsInRaid() then return 0 end
    if not filter or not GetRaidRosterInfo then
        return GetNumGroupMembers and GetNumGroupMembers() or 0
    end
    local wanted = {}
    for g in string.gmatch(filter, "%d+") do wanted[tonumber(g)] = true end
    local n = 0
    for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
        local _, _, subgroup = GetRaidRosterInfo(i)
        if subgroup and not IsSecret(subgroup) and wanted[subgroup] then n = n + 1 end
    end
    return n
end

-- Make the header create `count` buttons now (out of combat), so nothing has
-- to be created or sized later while combat lockdown is active.
local function PrecreateButtons(hdr, count)
    if InCombatLockdown() then return end
    if hdr._suirfPrecreated and hdr._suirfPrecreated >= count then return end
    if hdr:GetAttribute("child" .. count) then
        hdr._suirfPrecreated = count
        return
    end
    hdr:Show()
    -- The header lists (unitCount - (startingIndex - 1)) buttons: ask only for the missing ones
    local missing = math.max(0, count - HeaderUnitCount(hdr))
    if missing > 0 then
        hdr:SetAttribute("startingIndex", 1 - missing)
    end
    hdr:SetAttribute("startingIndex", 1)
    if hdr:GetAttribute("child" .. count) then hdr._suirfPrecreated = count end
end

local function ForEachChild(hdr, fn)
    local i = 1
    while true do
        local child = hdr:GetAttribute("child" .. i)
        if not child then break end
        fn(child)
        i = i + 1
    end
end

local function ConfigureHeader(hdr, L, opts)
    local s = L.s
    local xo, yo = 0, 0
    if L.unitGrowth == "DOWN" then yo = -s
    elseif L.unitGrowth == "UP" then yo = s
    elseif L.unitGrowth == "RIGHT" then xo = s
    else xo = -s end

    -- Resize existing children first so the header's own update lays them out
    -- from the new size (otherwise frames shift until the next update).
    ForEachChild(hdr, function(child)
        child:SetSize(L.w, L.h)
    end)

    hdr:SetAttribute("suirf-width", L.w)
    hdr:SetAttribute("suirf-height", L.h)
    hdr:SetAttribute("point", HEADER_POINT[L.unitGrowth])
    hdr:SetAttribute("xOffset", xo)
    hdr:SetAttribute("yOffset", yo)
    hdr:SetAttribute("unitsPerColumn", opts.unitsPerColumn)
    hdr:SetAttribute("maxColumns", opts.maxColumns or 1)
    hdr:SetAttribute("columnSpacing", L.gs or 0)
    hdr:SetAttribute("columnAnchorPoint", opts.unitsPerColumn and COLUMN_ANCHOR[L.groupGrowth] or nil)
    hdr:SetAttribute("groupFilter", opts.groupFilter)
    hdr:SetAttribute("groupBy", opts.groupBy)
    hdr:SetAttribute("groupingOrder", opts.groupingOrder)
    hdr:SetAttribute("sortMethod", opts.sortMethod or "INDEX")
    if opts.showPlayer ~= nil then hdr:SetAttribute("showPlayer", opts.showPlayer) end

    -- Harmless poke: forces one more SecureGroupHeader_Update with everything applied
    hdr:SetAttribute("suirf-poke", (hdr:GetAttribute("suirf-poke") or 0) + 1)
end

local ROLE_ORDER = "TANK,HEALER,DAMAGER,NONE"

local function SortOptions(sort)
    if sort == "ROLE" then
        return "INDEX", "ASSIGNEDROLE", ROLE_ORDER
    elseif sort == "NAME" then
        return "NAME", nil, nil
    end
    return "INDEX", nil, nil
end

---------------------------------------------------------------------------
-- BUILD / LAYOUT
---------------------------------------------------------------------------
local function CreateMover(kind, label)
    local f = CreateFrame("Frame", "SuaviUI_RaidFrames_" .. kind .. "Mover", UIParent)
    f:SetSize(100, 100)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f.editModeName = label
    f._suirfKind = kind
    return f
end

function RF:BuildHeaders()
    local db = self:GetDB()
    self.movers.party = self.movers.party or CreateMover("party", "Suaviframe: Party")
    self.movers.raid = self.movers.raid or CreateMover("raid", "Suaviframe: Raid")

    if not self.headers.party then
        self.headers.party = CreateHeader("SuaviUI_RaidFrames_Party", false)
    end
    if db.raid.sort == "GROUP" then
        for g = 1, MAX_RAID_GROUPS do
            if not self.headers["group" .. g] then
                self.headers["group" .. g] = CreateHeader("SuaviUI_RaidFrames_Group" .. g, true)
            end
        end
    elseif not self.headers.raidAll then
        self.headers.raidAll = CreateHeader("SuaviUI_RaidFrames_RaidAll", true)
    end
end

function RF:ApplyLayout()
    if not self.built then return end
    if InCombatLockdown() then
        self.pending.layout = true
        return
    end
    local db = self:GetDB()
    self:BuildHeaders()

    -- Party
    do
        local _, mw, mh, L = self:ComputeSlots("party")
        local mover = self.movers.party
        mover:SetSize(math.max(mw, 10), math.max(mh, 10))
        local hdr = self.headers.party
        local sortMethod, groupBy, groupingOrder = SortOptions(db.party.sort)
        ConfigureHeader(hdr, L, {
            sortMethod = sortMethod, groupBy = groupBy, groupingOrder = groupingOrder,
            groupFilter = groupBy and "1,2,3,4,5,6,7,8" or nil,
            showPlayer = db.party.showPlayer and true or false,
        })
        hdr:ClearAllPoints()
        hdr:SetPoint(L.corner, mover, L.corner, 0, 0)
        PrecreateButtons(hdr, MEMBERS_PER_GROUP)
        local cond = db.party.enabled and "[group:raid] hide; [group:party] show; hide" or "hide"
        RegisterStateDriver(hdr, "visibility", cond)
    end

    -- Raid
    do
        local _, mw, mh, L = self:ComputeSlots("raid")
        local mover = self.movers.raid
        mover:SetSize(math.max(mw, 10), math.max(mh, 10))
        local raidOn = db.raid.enabled

        for g = 1, MAX_RAID_GROUPS do
            local hdr = self.headers["group" .. g]
            if hdr then
                if not L.combined and raidOn and g <= L.maxGroups then
                    local sortMethod, groupBy, groupingOrder = SortOptions(db.raid.groupInnerSort)
                    ConfigureHeader(hdr, L, {
                        groupFilter = tostring(g),
                        sortMethod = sortMethod, groupBy = groupBy, groupingOrder = groupingOrder,
                    })
                    local off = L.groupOffsets[g]
                    hdr:ClearAllPoints()
                    hdr:SetPoint(L.corner, mover, L.corner, off[1], off[2])
                    PrecreateButtons(hdr, MEMBERS_PER_GROUP)
                    RegisterStateDriver(hdr, "visibility", "[group:raid] show; hide")
                else
                    RegisterStateDriver(hdr, "visibility", "hide")
                end
            end
        end

        local all = self.headers.raidAll
        if all then
            if L.combined and raidOn then
                local filter = {}
                for g = 1, L.maxGroups do filter[#filter + 1] = tostring(g) end
                local sortMethod, groupBy, groupingOrder = SortOptions(db.raid.sort)
                ConfigureHeader(all, L, {
                    groupFilter = table.concat(filter, ","),
                    sortMethod = sortMethod, groupBy = groupBy, groupingOrder = groupingOrder,
                    unitsPerColumn = L.upc,
                    maxColumns = math.ceil((L.maxGroups * MEMBERS_PER_GROUP) / L.upc),
                })
                all:ClearAllPoints()
                all:SetPoint(L.corner, mover, L.corner, 0, 0)
                PrecreateButtons(all, MAX_RAID_GROUPS * MEMBERS_PER_GROUP)
                RegisterStateDriver(all, "visibility", "[group:raid] show; hide")
            else
                RegisterStateDriver(all, "visibility", "hide")
            end
        end
    end

    unitMapDirty = true
    for _, btn in ipairs(self.buttons) do
        local d = self.data[btn]
        if d then
            d.powerShown = nil
            Restyle(d)
            UpdatePrivateAnchors(d, d.unit)
        end
    end
    ForAll(function(d) FullUpdate(d) end)
    self:ApplyPositions()
    self:ApplyHeaderAlpha()
    if self:IsPreviewing() then self:ShowPreview() end
end

-- Restyle + refresh without touching secure layout (safe in combat)
function RF:RefreshStyle()
    for _, btn in ipairs(self.buttons) do
        local d = self.data[btn]
        if d then
            d.powerShown = nil
            Restyle(d)
            UpdatePrivateAnchors(d, d.unit)
        end
    end
    ForAll(function(d) FullUpdate(d) end)
    if self:IsPreviewing() then self:ShowPreview() end
end

-- Full refresh entry point used by options and Edit Mode
function RF:Refresh()
    if not self.built then return end
    if InCombatLockdown() then
        self.pending.layout = true
        self:RefreshStyle()
        return
    end
    self:ApplyLayout()
end

---------------------------------------------------------------------------
-- POSITIONS (per Edit Mode layout)
---------------------------------------------------------------------------
function RF:GetActiveLayoutName()
    local LEM = LibStub("LibEQOLEditMode-1.0", true)
    return self.activeLayoutName or (LEM and LEM.GetActiveLayoutName and LEM:GetActiveLayoutName()) or "Default"
end

function RF:GetPosition(kind, layoutName)
    local db = self:GetDB()
    layoutName = layoutName or self:GetActiveLayoutName()
    local entry = db.positions[layoutName]
    local pos = entry and entry[kind]
    return pos or self.DEFAULT_POS[kind]
end

function RF:SavePosition(kind, layoutName, point, x, y)
    local db = self:GetDB()
    layoutName = layoutName or self:GetActiveLayoutName()
    db.positions[layoutName] = db.positions[layoutName] or {}
    db.positions[layoutName][kind] = { point = point or "CENTER", x = x or 0, y = y or 0 }
end

function RF:ApplyPositions(layoutName)
    if not self.built then return end
    if InCombatLockdown() then
        self.pending.positions = true
        return
    end
    for _, kind in ipairs({ "party", "raid" }) do
        local mover = self.movers[kind]
        if mover then
            local pos = self:GetPosition(kind, layoutName)
            mover:ClearAllPoints()
            mover:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
        end
    end
end

---------------------------------------------------------------------------
-- PREVIEW (fake units, insecure frames)
---------------------------------------------------------------------------
local PREVIEW_NAMES = {
    "Suavi", "Thrallina", "Bolvar", "Jaina", "Anduin", "Valeera", "Rexxar", "Tyrande",
    "Maiev", "Alleria", "Khadgar", "Velen", "Garrosh", "Sylvanas", "Illidan", "Chen",
    "Taelia", "Lorthemar", "Moira", "Rokhan", "Liadrin", "Turalyon", "Kael", "Vereesa",
    "Zekhan", "Calia", "Genn", "Talanji", "Baine", "Malfurion", "Shandris", "Magni",
    "Gazlowe", "Mekkatorque", "Aysa", "Ji", "Lilian", "Nathanos", "Thalyssra", "Wrathion",
}
local PREVIEW_CLASSES = {
    "WARRIOR", "PRIEST", "PALADIN", "MAGE", "ROGUE", "DRUID", "HUNTER", "SHAMAN",
    "DEATHKNIGHT", "WARLOCK", "MONK", "DEMONHUNTER", "EVOKER",
}
local PREVIEW_ROLES = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }

local function ApplyFake(d, i)
    local db = RF:GetDB()
    local st = db.style
    local unitClass = PREVIEW_CLASSES[((i - 1) % #PREVIEW_CLASSES) + 1]
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[unitClass]
    d.classR, d.classG, d.classB = c and c.r or 0.5, c and c.g or 0.5, c and c.b or 0.5
    d.hasClass = true
    d.fakeRole = PREVIEW_ROLES[((i - 1) % #PREVIEW_ROLES) + 1]

    local showPower = ShouldShowPower(d, nil)
    if showPower ~= d.powerShown then
        d.powerShown = showPower
        Restyle(d)
    end

    -- deterministic pseudo-random health per slot
    local pct = ((i * 37) % 70 + 30) / 100
    d.state = nil
    if i % 11 == 6 then d.state = DEAD or "Dead"; pct = 0 end
    if i % 13 == 9 then d.state = PLAYER_OFFLINE or "Offline" end

    d.name:SetText(TruncateName(PREVIEW_NAMES[((i - 1) % #PREVIEW_NAMES) + 1], st.nameLength or 10))
    if st.nameClassColor then d.name:SetTextColor(d.classR, d.classG, d.classB) else d.name:SetTextColor(1, 1, 1) end

    d.health:SetMinMaxValues(0, 100)
    d.health:SetValue(pct * 100)
    SetHealthColor(d)
    if d.state then
        d.statusText:SetText(d.state); d.statusText:Show(); d.healthText:Hide()
    else
        d.statusText:Hide()
        if st.healthText == "percent" then
            d.healthText:SetText(string.format("%d%%", math.floor(pct * 100 + 0.5))); d.healthText:SetTextColor(1, 1, 1, 1); d.healthText:Show()
        elseif st.healthText == "deficit" and pct < 1 then
            d.healthText:SetText(string.format("-%dk", math.floor((1 - pct) * 300))); d.healthText:SetTextColor(1, 1, 1, 1); d.healthText:Show()
        else
            d.healthText:Hide()
        end
    end

    d.healPred:SetMinMaxValues(0, 100)
    d.healPred:SetValue(st.showHealPrediction and (i % 3 == 0) and 12 or 0)
    d.absorb:SetMinMaxValues(0, 100)
    d.absorb:SetValue(st.showAbsorbs and (i % 4 == 1) and 15 or 0)
    d.healAbsorb:SetMinMaxValues(0, 100)
    d.healAbsorb:SetValue(st.showHealAbsorbs and (i % 7 == 3) and 10 or 0)
    d.overAbsorb:Hide()

    if showPower then
        local color = PowerBarColor and PowerBarColor[d.fakeRole == "TANK" and "RAGE" or "MANA"]
        if color then d.power:SetStatusBarColor(color.r, color.g, color.b) end
        d.power:SetMinMaxValues(0, 100)
        d.power:SetValue(60 + (i * 13) % 40)
    end

    local ic = st.icons
    local role = d.fakeRole
    if role == "DAMAGER" and not ic.roleShowDamager then role = nil end
    if ic.role and role then d.role:SetAtlas(ROLE_ATLAS[role]); d.role:Show() else d.role:Hide() end
    if ic.leader and i == 1 then d.leader:SetAlpha(1); d.leader:Show() else d.leader:Hide() end
    d.assist:Hide()
    if ic.marker and i == 2 and SetRaidTargetIconTexture then SetRaidTargetIconTexture(d.marker, 8); d.marker:Show() else d.marker:Hide() end
    d.ready:Hide()
    if ic.status and i == 4 then d.center:SetAtlas("RaidFrame-Icon-Rez"); d.center:Show() else d.center:Hide() end
    d.afkText:Hide()
    d.targetBorder:SetShown(st.targetHighlight and i == 3)

    -- debuffs: one on a few slots, a boss-sized one on slot 5
    local deb = st.debuffs
    for k = 1, MAX_DEBUFFS do d.debuffs[k]:Hide() end
    if deb.enabled and (deb.max or 0) > 0 and (i % 3 == 2 or i == 5) then
        local icon = d.debuffs[1]
        local size = (i == 5) and (deb.bossSize or 22) or (deb.size or 16)
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOMLEFT", d.health, "BOTTOMLEFT", 1, 1)
        icon.tex:SetTexture(136207)  -- Shadow Word: Pain
        icon.border:SetVertexColor(0.55, 0.05, 0.05)
        icon.cd:Hide()
        icon.count:SetText(i == 5 and "3" or "")
        icon:Show()
    end
    local bf = st.buffs
    for k = 1, MAX_BUFFS do d.buffs[k]:Hide() end
    if bf.enabled and (bf.max or 0) > 0 and i % 2 == 1 then
        local icon = d.buffs[1]
        icon.tex:SetTexture(136081)  -- Rejuvenation
        icon.cd:Hide()
        icon.count:SetText("")
        icon:Show()
    end

    -- dispel highlight on slot 7 (magic)
    local dp = st.dispel
    if dp.enabled and i % 8 == 7 then
        local col = DISPEL_COLORS[1]
        d.dispelBorder:SetColor(col[1], col[2], col[3]); d.dispelBorder:SetShown(dp.border)
        d.dispelOverlay:SetVertexColor(col[1], col[2], col[3]); d.dispelOverlay:SetShown(dp.overlay)
    else
        d.dispelBorder:Hide(); d.dispelOverlay:Hide()
    end

    -- out of range on slot 8
    if st.range.enabled and i % 8 == 0 then d.root:SetAlpha(st.range.alpha or 0.4) else d.root:SetAlpha(1) end
end

local function GetPreviewFrame(kind, i)
    local pool = RF.previewFrames[kind]
    local f = pool[i]
    if not f then
        f = CreateFrame("Frame", nil, RF.movers[kind])
        f:SetFrameStrata("MEDIUM")
        local d = BuildVisuals(f, true)
        RF.data[f] = d
        pool[i] = f
    end
    return f
end

function RF:IsPreviewing()
    return next(self.previewSources) ~= nil
end

function RF:ShowPreview()
    if not self.built or InCombatLockdown() then return end
    local db = self:GetDB()
    for _, kind in ipairs({ "party", "raid" }) do
        local enabled = db[kind].enabled
        local count
        if kind == "party" then
            count = self:GetLayout("party").count
        else
            local L = self:GetLayout("raid")
            count = math.min(db.raid.previewSize or 20, L.maxGroups * MEMBERS_PER_GROUP)
        end
        local slots, _, _, L = self:ComputeSlots(kind, count)
        local pool = self.previewFrames[kind]
        local shown = 0
        if enabled then
            for i = 1, #slots do
                local f = GetPreviewFrame(kind, i)
                f:SetSize(L.w, L.h)
                f:ClearAllPoints()
                f:SetPoint(L.corner, self.movers[kind], L.corner, slots[i][1], slots[i][2])
                local d = self.data[f]
                d.powerShown = nil
                Restyle(d)
                ApplyFake(d, i)
                f:Show()
                shown = i
            end
        end
        for i = shown + 1, #pool do pool[i]:Hide() end
    end
    self.previewShown = true
    self:ApplyHeaderAlpha()
end

function RF:HidePreview()
    for _, kind in ipairs({ "party", "raid" }) do
        for _, f in ipairs(self.previewFrames[kind]) do f:Hide() end
    end
    self.previewShown = false
    self:ApplyHeaderAlpha()
end

-- Real headers are faded out only while the preview is actually on screen
-- (the preview is hidden in combat, and the real frames must be visible then)
function RF:ApplyHeaderAlpha()
    local a = self.previewShown and 0 or 1
    for _, hdr in pairs(self.headers) do
        hdr:SetAlpha(a)
    end
end

function RF:SetPreview(source, on)
    self.previewSources[source] = on and true or nil
    if self:IsPreviewing() then self:ShowPreview() else self:HidePreview() end
end

function RF:TogglePreview()
    self:SetPreview("options", not self.previewSources.options)
    return self.previewSources.options == true
end

---------------------------------------------------------------------------
-- BLIZZARD FRAMES
-- Reparenting the Blizzard containers under a hidden frame hides them without
-- writing any Lua field on Blizzard frames (no taint spreads into
-- CompactUnitFrame code). Protected containers can only be reparented out of
-- combat, so this runs at build time and again after combat / roster changes
-- (CompactPartyFrame is created lazily by Blizzard). Restoring requires /reload.
---------------------------------------------------------------------------
local blizzHider
local stashed = {}

local function Stash(frame, silenceEvents)
    if not frame or stashed[frame] then return end
    if InCombatLockdown() then
        RF.pending.blizzard = true
        return
    end
    if not blizzHider then
        blizzHider = CreateFrame("Frame", "SuaviUI_RaidFrames_BlizzHider", UIParent)
        blizzHider:Hide()
    end
    if silenceEvents then pcall(frame.UnregisterAllEvents, frame) end
    if pcall(frame.SetParent, frame, blizzHider) then
        stashed[frame] = true
    end
end

function RF:HideBlizzard()
    local db = self:GetDB()
    if not db or not db.enabled or not db.hideBlizzard then return end
    if db.raid.enabled then
        Stash(_G.CompactRaidFrameContainer, true)
    end
    if db.party.enabled then
        Stash(_G.PartyFrame, false)
        Stash(_G.CompactPartyFrame, false)
    end
end

---------------------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local auraDirty = {}
local auraDirtyAny = false
local auraElapsed = 0
local rangeElapsed = 0 -- range is polled in OnUpdate (single mechanism)

local UNIT_EVENTS = {
    UNIT_HEALTH = function(d, u) UpdateHealth(d, u); UpdatePrediction(d, u) end,
    UNIT_MAXHEALTH = function(d, u) UpdateHealth(d, u); UpdatePrediction(d, u) end,
    UNIT_HEAL_PREDICTION = function(d, u) UpdatePrediction(d, u) end,
    UNIT_ABSORB_AMOUNT_CHANGED = function(d, u) UpdatePrediction(d, u) end,
    UNIT_HEAL_ABSORB_AMOUNT_CHANGED = function(d, u) UpdatePrediction(d, u) end,
    UNIT_POWER_UPDATE = function(d, u) if d.powerShown then UpdatePower(d, u) end end,
    UNIT_MAXPOWER = function(d, u) UpdatePower(d, u) end,
    UNIT_DISPLAYPOWER = function(d, u) UpdatePower(d, u) end,
    UNIT_NAME_UPDATE = function(d, u) UpdateClassColor(d, u); UpdateName(d, u); SetHealthColor(d, u) end,
    UNIT_CONNECTION = function(d, u) UpdateHealth(d, u); UpdateAFK(d, u) end,
    UNIT_FLAGS = function(d, u) UpdateHealth(d, u); UpdateAFK(d, u) end,
    UNIT_PHASE = function(d, u) UpdateCenterStatus(d, u) end,
    PLAYER_FLAGS_CHANGED = function(d, u) UpdateAFK(d, u) end,
    INCOMING_RESURRECT_CHANGED = function(d, u) UpdateCenterStatus(d, u) end,
    INCOMING_SUMMON_CHANGED = function(d, u) UpdateCenterStatus(d, u) end,
    READY_CHECK_CONFIRM = function(d, u) UpdateReadyCheck(d, u) end,
}

local function OnEvent(self, event, arg1)
    local handler = UNIT_EVENTS[event]
    if handler then
        if arg1 then ForUnit(arg1, handler) end
        return
    end

    if event == "UNIT_AURA" then
        if not arg1 then return end
        if unitMapDirty then RebuildUnitMap() end
        local list = unitMap[arg1]
        if list then
            for i = 1, #list do auraDirty[list[i]] = true end
            auraDirtyAny = true
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" or event == "PARTY_LEADER_CHANGED" then
        unitMapDirty = true
        C_Timer.After(0, function() ForAll(FullUpdate) end)
        if not InCombatLockdown() then RF:HideBlizzard() end
    elseif event == "RAID_TARGET_UPDATE" then
        ForAll(UpdateMarker)
    elseif event == "PLAYER_TARGET_CHANGED" then
        ForAll(UpdateTarget)
    elseif event == "READY_CHECK" then
        RF.readyCheckActive = true
        RF.readyCheckFinished = false
        ForAll(UpdateReadyCheck)
    elseif event == "READY_CHECK_FINISHED" then
        RF.readyCheckFinished = true
        ForAll(UpdateReadyCheck)
        C_Timer.After(6, function()
            if RF.readyCheckFinished then
                RF.readyCheckActive = false
                ForAll(UpdateReadyCheck)
            end
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if RF:IsPreviewing() then RF:HidePreview() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        RF:ProcessPending()
        if RF:IsPreviewing() then RF:ShowPreview() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        unitMapDirty = true
        C_Timer.After(0.5, function() ForAll(FullUpdate) end)
        if not InCombatLockdown() then RF:HideBlizzard() end
    end
end

local function OnUpdate(self, elapsed)
    if auraDirtyAny then
        auraElapsed = auraElapsed + elapsed
        if auraElapsed >= 0.1 then
            auraElapsed = 0
            auraDirtyAny = false
            for d in pairs(auraDirty) do
                auraDirty[d] = nil
                if d.unit then UpdateAuras(d, d.unit) end
            end
        end
    end
    rangeElapsed = rangeElapsed + elapsed
    if rangeElapsed >= 0.5 then
        rangeElapsed = 0
        ForAll(UpdateRange)
    end
end

function RF:RegisterEvents()
    for event in pairs(UNIT_EVENTS) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    local others = {
        "UNIT_AURA", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PARTY_LEADER_CHANGED",
        "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED", "READY_CHECK", "READY_CHECK_FINISHED",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
    }
    for _, event in ipairs(others) do
        pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:SetScript("OnUpdate", OnUpdate)
end

function RF:ProcessPending()
    if InCombatLockdown() then return end
    local p = self.pending
    if p.build then
        p.build = nil
        self:Build()
        return
    end
    if p.clicks then
        for _, btn in ipairs(p.clicks) do btn:RegisterForClicks("AnyUp") end
        p.clicks = nil
    end
    if p.layout then
        p.layout = nil
        p.positions = nil
        self:ApplyLayout()
    elseif p.positions then
        p.positions = nil
        self:ApplyPositions()
    end
    if p.blizzard then
        p.blizzard = nil
        self:HideBlizzard()
    end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
function RF:Build()
    if self.built then return end
    local db = self:GetDB()
    if not db or not db.enabled then return end
    if InCombatLockdown() then
        self.pending.build = true
        return
    end
    BuildCurves()
    self.built = true
    self:RegisterEvents()
    self:ApplyLayout()
    self:HideBlizzard()

    if ns.RF_EditMode and ns.RF_EditMode.Register then
        ns.RF_EditMode:Register()
    end
end

function RF:OnProfileChanged()
    filledFor = nil
    if not self.built then return end
    self:Refresh()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(0.5, function()
        if SUICore and SUICore.db and SUICore.db.RegisterCallback then
            SUICore.db.RegisterCallback(RF, "OnProfileChanged", "OnProfileChanged")
            SUICore.db.RegisterCallback(RF, "OnProfileCopied", "OnProfileChanged")
            SUICore.db.RegisterCallback(RF, "OnProfileReset", "OnProfileChanged")
        end
        if InCombatLockdown() then
            RF.pending.build = true
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            eventFrame:SetScript("OnEvent", OnEvent)
        else
            RF:Build()
        end
    end)
end)

-- Global hooks for options pages
_G.SuaviUI_RefreshRaidFrames = function() RF:Refresh() end
_G.SuaviUI_ToggleRaidFramesPreview = function() return RF:TogglePreview() end
