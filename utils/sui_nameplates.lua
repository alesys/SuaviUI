--[[
    SuaviUI Nameplates
    ------------------
    Draws SuaviUI-styled nameplates on top of Blizzard's nameplate frames
    (WoW 12.x Midnight). Disabled by default; while disabled nothing here
    touches Blizzard's plates, CVars or driver.

    How it attaches
      * One SuaviUI plate per Blizzard nameplate base frame (bases are pooled
        by the client, so our plates are pooled with them).
      * We post-hook NamePlateDriverFrame:OnNamePlateAdded so Blizzard has
        already acquired its UnitFrame when we decide what to do with it.
      * Blizzard's UnitFrame is never hidden, re-anchored or unregistered:
        it is only faded to alpha 0 (it must stay visible for the client's
        click/stacking logic) and its mouse-enabled aura list is parked on a
        hidden holder. Both are restored when the pooled UnitFrame is later
        reused for a unit we leave to Blizzard, or when the module is
        disabled. No field is ever written on a Blizzard frame; bookkeeping
        lives in weak tables keyed by frame (same rule as suicore_main.lua).
      * Forbidden plates (e.g. friendly plates inside instances) are invisible
        to insecure code: C_NamePlate.GetNamePlateForUnit returns nil and we
        simply skip them.

    Secret values (12.x)
      * Health, cast info, aura data, raid marks and names can be secret for
        nameplate units. They are only ever passed straight into widget
        setters that accept secrets from tainted code (SetValue,
        SetMinMaxValues, SetText, SetFormattedText, SetTexture,
        SetSpriteSheetCell, SetStatusBarColor, SetAlphaFromBoolean) or into
        C_CurveUtil.EvaluateColorValueFromBoolean. Any value we branch on is
        checked with issecretvalue() first.
      * Threat situation between "player" and a nameplate is documented as
        non-secret; it is still guarded.
]]

local ADDON_NAME, ns = ...

local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

local SUI_NP = {}
ns.Nameplates = SUI_NP

local pairs, ipairs, type, pcall, select, wipe, tostring = pairs, ipairs, type, pcall, select, wipe, tostring
local CreateFrame, GetTime = CreateFrame, GetTime
local UnitExists, UnitIsUnit, UnitIsPlayer, UnitIsFriend = UnitExists, UnitIsUnit, UnitIsPlayer, UnitIsFriend
local UnitHealth, UnitHealthMax, UnitHealthPercent = UnitHealth, UnitHealthMax, UnitHealthPercent
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local UnitThreatSituation, UnitDetailedThreatSituation = UnitThreatSituation, UnitDetailedThreatSituation

---------------------------------------------------------------------------
-- SECRET HELPERS
---------------------------------------------------------------------------
local issecretvalue = issecretvalue

local function IsSecret(v)
    if issecretvalue then
        return issecretvalue(v) and true or false
    end
    return false
end

-- True when v holds something (a secret always holds something).
local function HasValue(v)
    if IsSecret(v) then return true end
    return v ~= nil
end

-- Plain boolean, or false if the value is secret / nil.
local function PlainTrue(v)
    if IsSecret(v) then return false end
    return v == true
end

---------------------------------------------------------------------------
-- DEFAULTS
-- Kept in this file (filled into profile.nameplates on first access) so the
-- module does not need to touch the shared defaults table in suicore_main.
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled = false,

    -- Size / media
    width = 130,
    height = 12,
    texture = "Suavitex",
    font = "",               -- "" = SuaviUI general font
    nameFontSize = 10,
    healthFontSize = 9,
    castFontSize = 9,
    auraFontSize = 9,

    -- Enemy plate content
    showName = true,
    healthText = "percent",  -- "none" | "percent"
    showLevel = true,
    showRaidIcon = true,
    raidIconSize = 18,

    -- Target / focus
    targetHighlight = "border",  -- "none" | "border" | "glow"
    targetScale = 1.1,
    showFocusMarker = true,

    -- Health colors
    threatColoring = true,
    classColorEnemyPlayers = true,

    -- Cast bar
    castBar = true,
    castHeight = 10,
    castIcon = true,
    castTimer = true,
    kickTint = true,

    -- Auras
    debuffs = true,
    debuffSize = 18,
    maxDebuffs = 5,
    buffs = true,
    buffSize = 16,
    maxBuffs = 3,
    buffFilter = "dispellable",  -- "dispellable" | "important" | "both"

    -- Friendly plates
    friendlyMode = "blizzard",   -- "blizzard" | "name" | "hide"
    friendlyFontSize = 11,

    colors = {
        hostile    = { 0.80, 0.18, 0.18, 1 },
        neutral    = { 0.90, 0.75, 0.20, 1 },
        friendly   = { 0.25, 0.70, 0.30, 1 },
        tapped     = { 0.55, 0.55, 0.55, 1 },
        background = { 0.06, 0.06, 0.06, 0.85 },

        tankSecure = { 0.20, 0.70, 0.35, 1 },
        tankLosing = { 1.00, 0.55, 0.10, 1 },
        tankLost   = { 0.90, 0.15, 0.15, 1 },
        offTank    = { 0.25, 0.50, 1.00, 1 },
        dpsSafe    = { 0.20, 0.70, 0.35, 1 },
        dpsWarn    = { 1.00, 0.55, 0.10, 1 },
        dpsAggro   = { 0.90, 0.15, 0.15, 1 },

        castInterruptible    = { 1.00, 0.70, 0.15, 1 },
        castNotInterruptible = { 0.55, 0.55, 0.60, 1 },
        castKickCooldown     = { 0.75, 0.35, 0.35, 1 },
        castInterrupted      = { 1.00, 0.15, 0.15, 1 },

        target = { 1.00, 1.00, 1.00, 1 },
        focus  = { 0.75, 0.40, 1.00, 1 },
    },
}
SUI_NP.DEFAULTS = DEFAULTS

local function FillDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                local copy = {}
                FillDefaults(copy, v)
                dst[k] = copy
            else
                FillDefaults(dst[k], v)
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local filledFor = nil
local function GetDB()
    local core = ns.Addon
    local profile = core and core.db and core.db.profile
    if not profile then return nil end
    local db = profile.nameplates
    if type(db) ~= "table" then
        db = {}
        profile.nameplates = db
    end
    if filledFor ~= db then
        FillDefaults(db, DEFAULTS)
        filledFor = db
    end
    return db
end
SUI_NP.GetDB = GetDB

---------------------------------------------------------------------------
-- MEDIA
---------------------------------------------------------------------------
local FALLBACK_BAR = "Interface\\Buttons\\WHITE8x8"
local FALLBACK_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local RAID_ICON_SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local function GetBarTexture(db)
    if LSM and db.texture and db.texture ~= "" then
        local path = LSM:Fetch("statusbar", db.texture, true)
        if path then return path end
    end
    return FALLBACK_BAR
end

local function GetFontInfo(db)
    local core = ns.Addon
    local general = core and core.db and core.db.profile and core.db.profile.general
    local name = db.font
    if not name or name == "" then
        name = general and general.font or "Friz Quadrata TT"
    end
    local path = LSM and LSM:Fetch("font", name, true) or nil
    local outline = general and general.fontOutline or "OUTLINE"
    return path or FALLBACK_FONT, outline
end

local function SetFontSafe(fs, path, size, outline)
    if not fs:SetFont(path, size, outline) then
        fs:SetFont(FALLBACK_FONT, size, outline)
    end
end

local function SetColor(region, c, method)
    region[method or "SetVertexColor"](region, c[1], c[2], c[3], c[4] or 1)
end

---------------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------------
local plates = {}        -- [nameplate base frame] = plate table
local unitPlates = {}    -- [unit token] = plate table
local activeCasts = {}   -- [plate] = true while a cast bar is running
local dirtyColor = {}    -- [plate] = true, flushed next frame
local dirtyAuras = {}    -- [plate] = true, flushed next frame

-- Blizzard UnitFrame bookkeeping (weak, never written onto the frames)
local ownedUF = setmetatable({}, { __mode = "k" })       -- [uf] = true while suppressed
local alphaHooked = setmetatable({}, { __mode = "k" })   -- [uf] = true once SetAlpha is hooked
local parkedAuras = setmetatable({}, { __mode = "k" })   -- [uf] = original parent of uf.AurasFrame
local savedHLAlpha = setmetatable({}, { __mode = "k" })  -- [uf] = selectionHighlight alpha

local auraHolder = CreateFrame("Frame")
auraHolder:Hide()

local playerRole = "DAMAGER"
local groupTanks = {}
local kickSpell = nil

SUI_NP.enabled = false

---------------------------------------------------------------------------
-- BLIZZARD UNITFRAME SUPPRESSION
---------------------------------------------------------------------------
local alphaGuard = false
local function OnBlizzardSetAlpha(uf)
    if alphaGuard or not ownedUF[uf] then return end
    alphaGuard = true
    uf:SetAlpha(0)
    alphaGuard = false
end

local function SuppressBlizzard(uf)
    if not uf or uf:IsForbidden() then return end
    ownedUF[uf] = true

    if not alphaHooked[uf] then
        alphaHooked[uf] = true
        hooksecurefunc(uf, "SetAlpha", OnBlizzardSetAlpha)
    end
    alphaGuard = true
    uf:SetAlpha(0)
    alphaGuard = false

    -- selectionHighlight ignores parent alpha (Classic style only); mute it.
    local hl = uf.selectionHighlight
    if hl and savedHLAlpha[uf] == nil then
        savedHLAlpha[uf] = hl:GetAlpha()
        hl:SetAlpha(0)
    end

    -- Aura buttons are mouse-enabled (tooltips): an alpha-0 copy would be an
    -- invisible tooltip trap over our plate, so park the whole list.
    local auras = uf.AurasFrame
    if auras and parkedAuras[uf] == nil and not auras:IsProtected() then
        parkedAuras[uf] = auras:GetParent() or uf
        auras:SetParent(auraHolder)
    end
end

local function RestoreBlizzard(uf)
    if not uf or not ownedUF[uf] or uf:IsForbidden() then return end
    ownedUF[uf] = nil

    alphaGuard = true
    uf:SetAlpha(1)
    alphaGuard = false

    local hl = uf.selectionHighlight
    if hl and savedHLAlpha[uf] ~= nil then
        hl:SetAlpha(savedHLAlpha[uf])
        savedHLAlpha[uf] = nil
    end

    local auras = uf.AurasFrame
    local parent = parkedAuras[uf]
    if auras and parent then
        auras:SetParent(parent)
    end
    parkedAuras[uf] = nil
end

---------------------------------------------------------------------------
-- ROLE / GROUP / INTERRUPT DETECTION
---------------------------------------------------------------------------
local function RefreshPlayerRole()
    local role = nil
    local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
    local info = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
    if spec and info then
        local ok, index = pcall(spec)
        if ok and not IsSecret(index) and type(index) == "number" and index > 0 then
            local ok2, _, _, _, _, r = pcall(info, index)
            if ok2 and not IsSecret(r) and type(r) == "string" then
                role = r
            end
        end
    end
    if not role and UnitGroupRolesAssigned then
        local r = UnitGroupRolesAssigned("player")
        if not IsSecret(r) and r and r ~= "NONE" then
            role = r
        end
    end
    playerRole = role or "DAMAGER"
end

local function RefreshGroupTanks()
    wipe(groupTanks)
    local prefix, count
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    elseif IsInGroup() then
        prefix, count = "party", GetNumSubgroupMembers()
    else
        return
    end
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and not PlainTrue(UnitIsUnit(unit, "player")) then
            local role = UnitGroupRolesAssigned(unit)
            if not IsSecret(role) and role == "TANK" then
                groupTanks[#groupTanks + 1] = unit
            end
        end
    end
end

-- Interrupt abilities per class (game data). First known one wins.
local INTERRUPT_SPELLS = {
    DEATHKNIGHT = { 47528 },                -- Mind Freeze
    DEMONHUNTER = { 183752 },               -- Disrupt
    DRUID       = { 106839, 78675 },        -- Skull Bash, Solar Beam
    EVOKER      = { 351338 },               -- Quell
    HUNTER      = { 147362, 187707 },       -- Counter Shot, Muzzle
    MAGE        = { 2139 },                 -- Counterspell
    MONK        = { 116705 },               -- Spear Hand Strike
    PALADIN     = { 96231 },                -- Rebuke
    PRIEST      = { 15487 },                -- Silence
    ROGUE       = { 1766 },                 -- Kick
    SHAMAN      = { 57994 },                -- Wind Shear
    WARLOCK     = { 119910, 132409, 19647 },-- Spell Lock (command demon / sacrificed / felhunter)
    WARRIOR     = { 6552 },                 -- Pummel
}

local function IsKnown(spellID, bank)
    local fn = C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook
    if not fn then return false end
    local ok, known
    if bank then
        ok, known = pcall(fn, spellID, bank)
    else
        ok, known = pcall(fn, spellID)
    end
    return ok and PlainTrue(known)
end

local function RefreshKickSpell()
    kickSpell = nil
    local _, classFile = UnitClass("player")
    local list = classFile and INTERRUPT_SPELLS[classFile]
    if not list then return end
    local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    for _, id in ipairs(list) do
        if IsKnown(id) or (petBank and IsKnown(id, petBank)) then
            kickSpell = id
            return
        end
    end
end

-- Returns known, ready: "ready" is a (possibly secret) boolean and is only
-- meaningful when "known" is true. Never branch on "ready" directly.
local function CallIsZero(d) return d:IsZero() end
local function GetKickReady()
    if not kickSpell or not (C_Spell and C_Spell.GetSpellCooldownDuration) then return false end
    local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, kickSpell, true)
    if not ok or not HasValue(dur) then return false end
    local ok2, zero = pcall(CallIsZero, dur)
    if not ok2 or not HasValue(zero) then return false end
    return true, zero
end

---------------------------------------------------------------------------
-- COLORS
---------------------------------------------------------------------------
local function OtherTankHolds(unit)
    for i = 1, #groupTanks do
        local ok, isTanking = pcall(UnitDetailedThreatSituation, groupTanks[i], unit)
        if ok and PlainTrue(isTanking) then
            return true
        end
    end
    return false
end

local function GetThreatColor(db, unit)
    if not db.threatColoring then return nil end
    local ok, status = pcall(UnitThreatSituation, "player", unit)
    if not ok or IsSecret(status) or type(status) ~= "number" then return nil end
    local c = db.colors
    if playerRole == "TANK" then
        if status == 3 then return c.tankSecure end
        if status == 2 or status == 1 then return c.tankLosing end
        if OtherTankHolds(unit) then return c.offTank end
        return c.tankLost
    end
    if status >= 2 then return c.dpsAggro end
    if status == 1 then return c.dpsWarn end
    return c.dpsSafe
end

local function GetReactionColor(db, unit)
    local c = db.colors
    local reaction = UnitReaction(unit, "player")
    if IsSecret(reaction) or type(reaction) ~= "number" then return c.hostile end
    if reaction >= 5 then return c.friendly end
    if reaction == 4 then return c.neutral end
    return c.hostile
end

-- Class color for a player unit, or nil.
local function GetClassColor(unit)
    local _, classFile = UnitClass(unit)
    if IsSecret(classFile) or type(classFile) ~= "string" then return nil end
    return RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
end

local function UpdateHealthColor(p)
    local db = GetDB()
    local unit = p.unit
    if not db or not unit or p.kind ~= "enemy" then return end

    local col
    if PlainTrue(UnitIsTapDenied(unit)) then
        col = db.colors.tapped
    end
    if not col then
        col = GetThreatColor(db, unit)
    end
    if not col and db.classColorEnemyPlayers and p.isPlayer then
        local cc = GetClassColor(unit)
        if cc then
            p.health:SetStatusBarColor(cc.r, cc.g, cc.b, 1)
            return
        end
    end
    col = col or GetReactionColor(db, unit)
    p.health:SetStatusBarColor(col[1], col[2], col[3], col[4] or 1)
end

---------------------------------------------------------------------------
-- COALESCED UPDATES (threat bursts, UNIT_AURA bursts)
---------------------------------------------------------------------------
local UpdateAuras -- forward

local flusher = CreateFrame("Frame")
flusher:Hide()
flusher:SetScript("OnUpdate", function(self)
    self:Hide()
    for p in pairs(dirtyColor) do
        if p.unit then UpdateHealthColor(p) end
    end
    wipe(dirtyColor)
    for p in pairs(dirtyAuras) do
        if p.unit then UpdateAuras(p) end
    end
    wipe(dirtyAuras)
end)

local function MarkColor(p)
    dirtyColor[p] = true
    flusher:Show()
end

local function MarkAuras(p)
    dirtyAuras[p] = true
    flusher:Show()
end

local function MarkAllColors()
    for _, p in pairs(unitPlates) do
        dirtyColor[p] = true
    end
    flusher:Show()
end

---------------------------------------------------------------------------
-- HEALTH / NAME / LEVEL / SELECTION / RAID ICON
---------------------------------------------------------------------------
local function UpdateHealthValuesUnsafe(p)
    local unit = p.unit
    p.health:SetMinMaxValues(0, UnitHealthMax(unit))
    p.health:SetValue(UnitHealth(unit))
    if p.showHealthText then
        local pct = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
        if HasValue(pct) then
            p.healthText:SetFormattedText("%.0f%%", pct)
        else
            p.healthText:SetText("")
        end
    end
end

local function UpdateHealthValues(p)
    if not p.unit or p.kind ~= "enemy" then return end
    if not pcall(UpdateHealthValuesUnsafe, p) then
        p.healthText:SetText("")
    end
end

local function UpdateName(p)
    if not p.unit then return end
    local name = UnitName(p.unit)
    p.name:SetText(name)

    if p.kind == "friendly" then
        local db = GetDB()
        local cc = p.isPlayer and GetClassColor(p.unit)
        if cc then
            p.name:SetTextColor(cc.r, cc.g, cc.b, 1)
        else
            local c = db.colors.friendly
            p.name:SetTextColor(c[1], c[2], c[3], 1)
        end
    else
        p.name:SetTextColor(1, 1, 1, 1)
    end
end

local CLASSIFICATION_SUFFIX = {
    elite = "+",
    rareelite = "R+",
    rare = "R",
}

local function UpdateLevel(p)
    local db = GetDB()
    if not p.unit or p.kind ~= "enemy" or not db.showLevel then
        p.level:Hide()
        return
    end
    local level = UnitLevel(p.unit)
    local class = UnitClassification(p.unit)
    if IsSecret(level) or IsSecret(class) or type(level) ~= "number" then
        p.level:Hide()
        return
    end

    if class == "worldboss" or level < 0 then
        p.level:SetText("??")
        p.level:SetTextColor(1, 0.25, 0.25, 1)
    else
        p.level:SetText(tostring(level) .. (CLASSIFICATION_SUFFIX[class] or ""))
        if class == "rare" or class == "rareelite" then
            p.level:SetTextColor(0.75, 0.80, 1, 1)
        elseif class == "elite" then
            p.level:SetTextColor(1, 0.82, 0, 1)
        else
            p.level:SetTextColor(0.85, 0.85, 0.85, 1)
        end
    end
    p.level:Show()
end

local GLOW_KEY = "SUINameplateTarget"

local function UpdateSelection(p)
    if not p.unit then return end
    local db = GetDB()
    local isTarget = PlainTrue(UnitIsUnit(p.unit, "target"))
    local isFocus = PlainTrue(UnitIsUnit(p.unit, "focus"))
    p.isTarget = isTarget

    if p.kind ~= "enemy" then
        p.root:SetScale(1)
        return
    end

    local mode = db.targetHighlight
    local borderColor
    if isTarget and mode == "border" then
        borderColor = db.colors.target
    elseif isFocus and db.showFocusMarker then
        borderColor = db.colors.focus
    end
    if borderColor then
        for i = 1, 4 do SetColor(p.border[i], borderColor) end
    else
        for i = 1, 4 do p.border[i]:SetVertexColor(0, 0, 0, 1) end
    end

    if LCG then
        if isTarget and mode == "glow" then
            if not p.glowing then
                local c = db.colors.target
                LCG.PixelGlow_Start(p.health, { c[1], c[2], c[3], c[4] or 1 }, 8, 0.25, nil, 2, 2, 2, false, GLOW_KEY)
                p.glowing = true
            end
        elseif p.glowing then
            LCG.PixelGlow_Stop(p.health, GLOW_KEY)
            p.glowing = nil
        end
    end

    p.focusMark:SetShown(isFocus and db.showFocusMarker)
    p.root:SetScale(isTarget and (db.targetScale or 1) or 1)
end

local function UpdateRaidIcon(p)
    local db = GetDB()
    if not p.unit or p.kind ~= "enemy" or not db.showRaidIcon then
        p.raidIcon:Hide()
        return
    end
    local index = GetRaidTargetIndex(p.unit)
    if HasValue(index) then
        p.raidIcon:SetSpriteSheetCell(index, 4, 4)
        p.raidIcon:Show()
    else
        p.raidIcon:Hide()
    end
end

---------------------------------------------------------------------------
-- CAST BAR
---------------------------------------------------------------------------
local INTERP_IMMEDIATE = (Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate) or 0
local DIR_ELAPSED = (Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime) or 0
local DIR_REMAINING = (Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime) or 1

local castTicker = CreateFrame("Frame")
castTicker:Hide()

local function ClearCastTimer(p)
    if p.castTimerInstalled and C_DurationUtil and C_DurationUtil.CreateDuration then
        pcall(p.cast.SetTimerDuration, p.cast, C_DurationUtil.CreateDuration(), INTERP_IMMEDIATE, DIR_ELAPSED)
    end
    p.castTimerInstalled = nil
end

-- Bar color from (possibly secret) notInterruptible + (possibly secret) kick readiness.
local function ApplyCastColor(p)
    local db = GetDB()
    local c = db.colors
    local int, notInt = c.castInterruptible, c.castNotInterruptible
    local r, g, b = int[1], int[2], int[3]

    local eval = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
    if db.kickTint and kickSpell and eval then
        local known, ready = GetKickReady()
        if known then
            local cd = c.castKickCooldown
            r = eval(ready, int[1], cd[1])
            g = eval(ready, int[2], cd[2])
            b = eval(ready, int[3], cd[3])
        end
    end

    local locked = p.castNotInt
    if IsSecret(locked) then
        if eval then
            r = eval(locked, notInt[1], r)
            g = eval(locked, notInt[2], g)
            b = eval(locked, notInt[3], b)
        end
        p.castShield:SetAlphaFromBoolean(locked, 1, 0)
    elseif locked then
        r, g, b = notInt[1], notInt[2], notInt[3]
        p.castShield:SetAlpha(1)
    else
        p.castShield:SetAlpha(0)
    end
    p.cast:SetStatusBarColor(r, g, b, 1)
end

local function HideCast(p)
    activeCasts[p] = nil
    if p.castFlash:IsPlaying() then p.castFlash:Stop() end
    p.castFlashing = nil
    ClearCastTimer(p)
    p.castDuration = nil
    p.castHasDuration = nil
    p.castManual = nil
    p.castFrame:SetAlpha(1)
    p.castFrame:Hide()
end

-- Returns true if a cast or channel is now shown.
local function StartCast(p, isChannel)
    local db = GetDB()
    if not p.unit or p.kind ~= "enemy" or not db.castBar then return false end
    local unit = p.unit

    local name, text, texture, startMs, endMs, notInt, _
    if isChannel then
        name, text, texture, startMs, endMs, _, notInt = UnitChannelInfo(unit)
    else
        name, text, texture, startMs, endMs, _, _, notInt = UnitCastingInfo(unit)
    end
    if not HasValue(name) then return false end

    if p.castFlash:IsPlaying() then p.castFlash:Stop() end
    p.castFlashing = nil
    p.castFrame:SetAlpha(1)

    p.castText:SetText(text)
    p.castIconTex:SetTexture(texture)
    if not IsSecret(notInt) and notInt == nil then notInt = false end
    p.castNotInt = notInt
    p.castIsChannel = isChannel

    -- Engine-driven progress (works with secret timing); manual fallback
    -- only when the timestamps are plain numbers.
    p.castDuration = nil
    p.castHasDuration = nil
    p.castManual = nil
    local getter = isChannel and UnitChannelDuration or UnitCastingDuration
    local dur, hasDur = nil, false
    if getter then
        local ok, d = pcall(getter, unit)
        if ok and HasValue(d) then dur, hasDur = d, true end
    end
    local timerOK = false
    if hasDur and p.cast.SetTimerDuration then
        local direction = isChannel and DIR_REMAINING or DIR_ELAPSED
        timerOK = pcall(p.cast.SetTimerDuration, p.cast, dur, INTERP_IMMEDIATE, direction)
        if timerOK then
            p.castTimerInstalled = true
            p.castDuration = dur
            p.castHasDuration = true
        end
    end
    if not timerOK then
        ClearCastTimer(p)
        if not IsSecret(startMs) and not IsSecret(endMs) and type(startMs) == "number" and type(endMs) == "number" then
            p.castStart = startMs / 1000
            p.castEnd = endMs / 1000
            p.castManual = true
        else
            p.cast:SetMinMaxValues(0, 1)
            p.cast:SetValue(1)
        end
    end

    p.castTime:SetText("")
    ApplyCastColor(p)
    p.castFrame:Show()
    activeCasts[p] = true
    castTicker:Show()
    return true
end

local function RefreshCast(p)
    if not StartCast(p, false) and not StartCast(p, true) then
        HideCast(p)
    end
end

local function FlashInterrupted(p)
    local db = GetDB()
    if not p.unit or p.kind ~= "enemy" or not db.castBar then return end
    activeCasts[p] = nil
    ClearCastTimer(p)
    p.castDuration = nil
    p.castHasDuration = nil
    p.castManual = nil

    p.cast:SetMinMaxValues(0, 1)
    p.cast:SetValue(1)
    SetColor(p.cast, db.colors.castInterrupted, "SetStatusBarColor")
    p.castText:SetText(INTERRUPTED or "Interrupted")
    p.castTime:SetText("")
    p.castShield:SetAlpha(0)

    p.castFlashing = true
    p.castFrame:SetAlpha(1)
    p.castFrame:Show()
    p.castFlash:Stop()
    p.castFlash:Play()
end

local function CallGetRemaining(d) return d:GetRemainingDuration() end

local tickAccum, colorAccum = 0, 0
castTicker:SetScript("OnUpdate", function(self, elapsed)
    tickAccum = tickAccum + elapsed
    if tickAccum < 0.1 then return end
    colorAccum = colorAccum + tickAccum
    tickAccum = 0

    local db = GetDB()
    local showTimer = db and db.castTimer
    local recolor = false
    if colorAccum >= 0.25 then
        colorAccum = 0
        recolor = db and db.kickTint and kickSpell ~= nil
    end

    local now = GetTime()
    local any = false
    for p in pairs(activeCasts) do
        any = true
        if p.castManual then
            local s, e = p.castStart, p.castEnd
            local total = e - s
            if total <= 0 then total = 0.001 end
            local value = p.castIsChannel and (e - now) or (now - s)
            if value < 0 then value = 0 elseif value > total then value = total end
            p.cast:SetMinMaxValues(0, total)
            p.cast:SetValue(value)
            if showTimer then
                local remain = e - now
                if remain < 0 then remain = 0 end
                p.castTime:SetFormattedText("%.1f", remain)
            end
            if now >= e + 0.5 then
                -- Missed STOP event safety net.
                HideCast(p)
            end
        elseif p.castHasDuration and showTimer then
            local ok, remain = pcall(CallGetRemaining, p.castDuration)
            if ok and HasValue(remain) then
                p.castTime:SetFormattedText("%.1f", remain)
            end
        end
        if recolor and activeCasts[p] then
            ApplyCastColor(p)
        end
    end
    if not any then self:Hide() end
end)

---------------------------------------------------------------------------
-- AURAS
---------------------------------------------------------------------------
local DEBUFF_FILTER = "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY"
local BUFF_FILTERS = {
    dispellable = { "HELPFUL|RAID_PLAYER_DISPELLABLE" },
    important   = { "HELPFUL|IMPORTANT" },
    both        = { "HELPFUL|RAID_PLAYER_DISPELLABLE", "HELPFUL|IMPORTANT" },
}

local function FetchAuras(unit, filter, maxCount)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return nil end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter, maxCount)
    if ok and type(list) == "table" then return list end
    return nil
end

local function CreateAuraIcon(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:Hide()
    local bd = f:CreateTexture(nil, "BACKGROUND")
    bd:SetAllPoints()
    bd:SetColorTexture(0, 0, 0, 1)
    f.border = bd

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1)
    tex:SetPoint("BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.tex = tex

    local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cd:SetAllPoints(tex)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetReverse(true)
    cd:SetHideCountdownNumbers(false)
    f.cd = cd

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cd:GetFrameLevel() + 2)
    local count = overlay:CreateFontString(nil, "OVERLAY")
    count:SetPoint("BOTTOMRIGHT", 1, -1)
    count:SetJustifyH("RIGHT")
    f.count = count
    return f
end

local function StyleAuraIcon(icon, size, fontPath, fontSize, outline)
    icon:SetSize(size, size)
    SetFontSafe(icon.count, fontPath, fontSize, outline)
    local cdText = icon.cd.GetCountdownFontString and icon.cd:GetCountdownFontString()
    if cdText then
        SetFontSafe(cdText, fontPath, fontSize, outline)
    end
end

local function ApplyAura(icon, unit, aura, isBuff)
    icon.tex:SetTexture(aura.icon)
    if isBuff then
        icon.border:SetColorTexture(0.85, 0.65, 0.15, 1)
    else
        icon.border:SetColorTexture(0, 0, 0, 1)
    end

    local id = aura.auraInstanceID
    local hasTimer = false
    if not IsSecret(id) and id ~= nil then
        if C_UnitAuras.GetAuraDuration then
            local ok, dur = pcall(C_UnitAuras.GetAuraDuration, unit, id)
            if ok and HasValue(dur) then
                hasTimer = pcall(icon.cd.SetCooldownFromDurationObject, icon.cd, dur, true)
            end
        end
        local okc, txt = false, nil
        if C_UnitAuras.GetAuraApplicationDisplayCount then
            okc, txt = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, id, 2, 99)
        end
        if okc then
            icon.count:SetText(txt)
        else
            icon.count:SetText("")
        end
    else
        icon.count:SetText("")
    end
    if hasTimer then
        icon.cd:Show()
    else
        icon.cd:Clear()
        icon.cd:Hide()
    end
end

local function LayoutAuraRow(icons, count, anchor, point, relPoint, x, y, grow, size)
    for i = 1, count do
        local icon = icons[i]
        icon:ClearAllPoints()
        if i == 1 then
            icon:SetPoint(point, anchor, relPoint, x, y)
        elseif grow == "LEFT" then
            icon:SetPoint("RIGHT", icons[i - 1], "LEFT", -2, 0)
        else
            icon:SetPoint("LEFT", icons[i - 1], "RIGHT", 2, 0)
        end
    end
end

UpdateAuras = function(p)
    local db = GetDB()
    local unit = p.unit
    local shownDebuffs, shownBuffs = 0, 0

    if unit and p.kind == "enemy" then
        local fontPath, outline

        if db.debuffs then
            local maxN = db.maxDebuffs or 5
            local list = FetchAuras(unit, DEBUFF_FILTER, maxN)
            if list then
                for i = 1, #list do
                    if shownDebuffs >= maxN then break end
                    shownDebuffs = shownDebuffs + 1
                    local icon = p.debuffIcons[shownDebuffs]
                    if not icon then
                        icon = CreateAuraIcon(p.root)
                        p.debuffIcons[shownDebuffs] = icon
                        if not fontPath then fontPath, outline = GetFontInfo(db) end
                        StyleAuraIcon(icon, db.debuffSize, fontPath, db.auraFontSize, outline)
                    end
                    ApplyAura(icon, unit, list[i], false)
                    icon:Show()
                end
            end
        end

        if db.buffs then
            local maxN = db.maxBuffs or 3
            local seen = nil
            for _, filter in ipairs(BUFF_FILTERS[db.buffFilter] or BUFF_FILTERS.dispellable) do
                if shownBuffs >= maxN then break end
                local list = FetchAuras(unit, filter, maxN)
                if list then
                    for i = 1, #list do
                        if shownBuffs >= maxN then break end
                        local aura = list[i]
                        local id = aura.auraInstanceID
                        local plainID = (not IsSecret(id)) and id or nil
                        if not (plainID and seen and seen[plainID]) then
                            if plainID then
                                seen = seen or {}
                                seen[plainID] = true
                            end
                            shownBuffs = shownBuffs + 1
                            local icon = p.buffIcons[shownBuffs]
                            if not icon then
                                icon = CreateAuraIcon(p.root)
                                p.buffIcons[shownBuffs] = icon
                                if not fontPath then fontPath, outline = GetFontInfo(db) end
                                StyleAuraIcon(icon, db.buffSize, fontPath, db.auraFontSize, outline)
                            end
                            ApplyAura(icon, unit, aura, true)
                            icon:Show()
                        end
                    end
                end
            end
        end
    end

    for i = shownDebuffs + 1, #p.debuffIcons do p.debuffIcons[i]:Hide() end
    for i = shownBuffs + 1, #p.buffIcons do p.buffIcons[i]:Hide() end

    if shownDebuffs > 0 then
        local nameH = (db.showName and (db.nameFontSize or 10) + 3) or 0
        LayoutAuraRow(p.debuffIcons, shownDebuffs, p.health, "BOTTOMLEFT", "TOPLEFT", 0, 3 + nameH, "RIGHT")
    end
    if shownBuffs > 0 then
        LayoutAuraRow(p.buffIcons, shownBuffs, p.health, "LEFT", "RIGHT", 4, 0, "RIGHT")
    end
end

---------------------------------------------------------------------------
-- PLATE CONSTRUCTION / LAYOUT
---------------------------------------------------------------------------
local PlateOnEvent -- forward

local function CreateEdge(parent)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 1, 1, 1)
    t:SetVertexColor(0, 0, 0, 1)
    return t
end

local function CreatePlate(base)
    local p = { base = base, debuffIcons = {}, buffIcons = {} }

    local root = CreateFrame("Frame", nil, base)
    root:SetPoint("CENTER", base, "CENTER", 0, 0)
    root:SetSize(1, 1)
    root:SetFrameLevel(base:GetFrameLevel() + 5)
    root:Hide()
    p.root = root

    -- Health bar
    local health = CreateFrame("StatusBar", nil, root)
    health:SetMinMaxValues(0, 1)
    health:SetValue(1)
    p.health = health

    local bg = health:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    p.healthBG = bg

    -- 1px border: top, bottom, left, right
    local border = { CreateEdge(health), CreateEdge(health), CreateEdge(health), CreateEdge(health) }
    border[1]:SetPoint("BOTTOMLEFT", health, "TOPLEFT", -1, 0)
    border[1]:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 1, 0)
    border[1]:SetHeight(1)
    border[2]:SetPoint("TOPLEFT", health, "BOTTOMLEFT", -1, 0)
    border[2]:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 1, 0)
    border[2]:SetHeight(1)
    border[3]:SetPoint("TOPRIGHT", health, "TOPLEFT", 0, 0)
    border[3]:SetPoint("BOTTOMRIGHT", health, "BOTTOMLEFT", 0, 0)
    border[3]:SetWidth(1)
    border[4]:SetPoint("TOPLEFT", health, "TOPRIGHT", 0, 0)
    border[4]:SetPoint("BOTTOMLEFT", health, "BOTTOMRIGHT", 0, 0)
    border[4]:SetWidth(1)
    p.border = border

    local healthText = health:CreateFontString(nil, "OVERLAY")
    healthText:SetPoint("RIGHT", health, "RIGHT", -2, 0)
    healthText:SetJustifyH("RIGHT")
    p.healthText = healthText

    local name = root:CreateFontString(nil, "OVERLAY")
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    p.name = name

    local level = root:CreateFontString(nil, "OVERLAY")
    level:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 0, 2)
    level:SetJustifyH("RIGHT")
    p.level = level

    local raidIcon = health:CreateTexture(nil, "OVERLAY", nil, 2)
    raidIcon:SetTexture(RAID_ICON_SHEET)
    raidIcon:SetPoint("BOTTOMRIGHT", health, "BOTTOMLEFT", -4, 0)
    raidIcon:Hide()
    p.raidIcon = raidIcon

    -- Focus marker: small diamond sitting on the left edge of the bar
    local focusMark = health:CreateTexture(nil, "OVERLAY", nil, 3)
    focusMark:SetColorTexture(1, 1, 1, 1)
    focusMark:SetSize(7, 7)
    focusMark:SetPoint("CENTER", health, "LEFT", 0, 0)
    focusMark:SetRotation(math.rad(45))
    focusMark:Hide()
    p.focusMark = focusMark

    -- Cast bar (holder fades as a unit for the interrupted flash)
    local castFrame = CreateFrame("Frame", nil, root)
    castFrame:Hide()
    p.castFrame = castFrame

    local cast = CreateFrame("StatusBar", nil, castFrame)
    cast:SetAllPoints(castFrame)
    cast:SetMinMaxValues(0, 1)
    cast:SetValue(0)
    p.cast = cast

    local castBG = cast:CreateTexture(nil, "BACKGROUND")
    castBG:SetAllPoints()
    p.castBG = castBG

    local castIcon = CreateFrame("Frame", nil, castFrame)
    castIcon:SetPoint("TOPRIGHT", castFrame, "TOPLEFT", -2, 0)
    p.castIcon = castIcon
    local castIconBD = castIcon:CreateTexture(nil, "BACKGROUND")
    castIconBD:SetAllPoints()
    castIconBD:SetColorTexture(0, 0, 0, 1)
    local castIconTex = castIcon:CreateTexture(nil, "ARTWORK")
    castIconTex:SetPoint("TOPLEFT", 1, -1)
    castIconTex:SetPoint("BOTTOMRIGHT", -1, 1)
    castIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.castIconTex = castIconTex

    local castShield = castIcon:CreateTexture(nil, "OVERLAY")
    castShield:SetAtlas("nameplates-InterruptShield")
    castShield:SetPoint("CENTER", castIcon, "CENTER", 0, 0)
    castShield:SetAlpha(0)
    p.castShield = castShield

    local castText = cast:CreateFontString(nil, "OVERLAY")
    castText:SetPoint("LEFT", cast, "LEFT", 2, 0)
    castText:SetPoint("RIGHT", cast, "RIGHT", -28, 0)
    castText:SetJustifyH("LEFT")
    castText:SetWordWrap(false)
    p.castText = castText

    local castTime = cast:CreateFontString(nil, "OVERLAY")
    castTime:SetPoint("RIGHT", cast, "RIGHT", -2, 0)
    castTime:SetJustifyH("RIGHT")
    p.castTime = castTime

    local flash = castFrame:CreateAnimationGroup()
    local fade = flash:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetStartDelay(0.35)
    fade:SetDuration(0.5)
    flash:SetScript("OnFinished", function()
        p.castFlashing = nil
        castFrame:Hide()
        castFrame:SetAlpha(1)
    end)
    p.castFlash = flash

    -- Per-plate unit event frame (RegisterUnitEvent keeps filtering in C)
    local ev = CreateFrame("Frame", nil, root)
    ev.plate = p
    ev:SetScript("OnEvent", PlateOnEvent)
    p.ev = ev

    plates[base] = p
    return p
end

local function ApplyLayout(p)
    local db = GetDB()
    local tex = GetBarTexture(db)
    local fontPath, outline = GetFontInfo(db)
    local w, h = db.width, db.height
    local bgc = db.colors.background

    p.root:SetSize(w, h)
    p.health:ClearAllPoints()
    p.health:SetPoint("CENTER", p.root, "CENTER", 0, 0)
    p.health:SetSize(w, h)
    p.health:SetStatusBarTexture(tex)
    p.healthBG:SetTexture(tex)
    SetColor(p.healthBG, bgc)

    SetFontSafe(p.healthText, fontPath, db.healthFontSize, outline)
    SetFontSafe(p.level, fontPath, db.nameFontSize, outline)
    p.showHealthText = db.healthText == "percent"
    p.healthText:SetShown(p.showHealthText)

    p.raidIcon:SetSize(db.raidIconSize, db.raidIconSize)

    -- Cast bar under the health bar
    local ch = db.castHeight
    p.castFrame:ClearAllPoints()
    p.castFrame:SetPoint("TOPLEFT", p.health, "BOTTOMLEFT", 0, -3)
    p.castFrame:SetPoint("TOPRIGHT", p.health, "BOTTOMRIGHT", 0, -3)
    p.castFrame:SetHeight(ch)
    p.cast:SetStatusBarTexture(tex)
    p.castBG:SetTexture(tex)
    SetColor(p.castBG, bgc)
    p.castIcon:SetSize(ch, ch)
    p.castIcon:SetShown(db.castIcon)
    p.castShield:SetSize(ch * 0.8, ch)
    SetFontSafe(p.castText, fontPath, db.castFontSize, outline)
    SetFontSafe(p.castTime, fontPath, db.castFontSize, outline)
    p.castTime:SetShown(db.castTimer)

    for _, icon in ipairs(p.debuffIcons) do
        StyleAuraIcon(icon, db.debuffSize, fontPath, db.auraFontSize, outline)
    end
    for _, icon in ipairs(p.buffIcons) do
        StyleAuraIcon(icon, db.buffSize, fontPath, db.auraFontSize, outline)
    end

    -- Name placement depends on enemy vs friendly name-only mode
    p.name:ClearAllPoints()
    if p.kind == "friendly" then
        SetFontSafe(p.name, fontPath, db.friendlyFontSize, outline)
        p.name:SetPoint("CENTER", p.root, "CENTER", 0, 0)
        p.name:SetJustifyH("CENTER")
    else
        SetFontSafe(p.name, fontPath, db.nameFontSize, outline)
        p.name:SetPoint("BOTTOMLEFT", p.health, "TOPLEFT", 0, 2)
        p.name:SetPoint("RIGHT", p.health, "RIGHT", -24, 0)
        p.name:SetJustifyH("LEFT")
    end
end

---------------------------------------------------------------------------
-- UNIT EVENTS
---------------------------------------------------------------------------
local PLATE_EVENTS_ENEMY = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_THREAT_LIST_UPDATE", "UNIT_AURA",
    "UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_LEVEL", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FLAGS",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_UPDATE", "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
local PLATE_EVENTS_FRIENDLY = { "UNIT_NAME_UPDATE", "UNIT_FACTION" }

local function RegisterPlateEvents(p)
    local ev = p.ev
    ev:UnregisterAllEvents()
    local list = (p.kind == "enemy") and PLATE_EVENTS_ENEMY or PLATE_EVENTS_FRIENDLY
    for _, event in ipairs(list) do
        ev:RegisterUnitEvent(event, p.unit)
    end
end

PlateOnEvent = function(self, event, unit)
    local p = self.plate
    if not p.unit then return end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        UpdateHealthValues(p)
    elseif event == "UNIT_THREAT_LIST_UPDATE" or event == "UNIT_FLAGS" then
        MarkColor(p)
    elseif event == "UNIT_AURA" then
        MarkAuras(p)
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
        StartCast(p, false)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        StartCast(p, true)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        FlashInterrupted(p)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        if not p.castFlashing then HideCast(p) end
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        if activeCasts[p] then p.castNotInt = false; ApplyCastColor(p) end
    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if activeCasts[p] then p.castNotInt = true; ApplyCastColor(p) end
    elseif event == "UNIT_NAME_UPDATE" then
        UpdateName(p)
    elseif event == "UNIT_LEVEL" or event == "UNIT_CLASSIFICATION_CHANGED" then
        UpdateLevel(p)
    elseif event == "UNIT_FACTION" then
        -- Hostility can flip (e.g. quest NPCs); re-decide ownership.
        SUI_NP:AttachUnit(p.unit, p.base)
    end
end

---------------------------------------------------------------------------
-- ATTACH / DETACH
---------------------------------------------------------------------------
-- Returns "enemy", "friendly" or nil (leave the plate to Blizzard).
local function ClassifyUnit(unit)
    local db = GetDB()
    if PlainTrue(UnitIsUnit(unit, "player")) then return nil end -- personal resource display
    if PlainTrue(UnitNameplateShowsWidgetsOnly(unit)) then return nil end
    if PlainTrue(UnitIsGameObject(unit)) then return nil end

    local isFriend = UnitIsFriend("player", unit)
    if IsSecret(isFriend) then return nil end
    if isFriend then
        if db.friendlyMode == "name" or db.friendlyMode == "hide" then
            return "friendly"
        end
        return nil
    end
    return "enemy"
end

local function DetachPlate(p)
    if p.unit and unitPlates[p.unit] == p then
        unitPlates[p.unit] = nil
    end
    p.ev:UnregisterAllEvents()
    HideCast(p)
    if p.glowing and LCG then
        LCG.PixelGlow_Stop(p.health, GLOW_KEY)
    end
    p.glowing = nil
    dirtyColor[p] = nil
    dirtyAuras[p] = nil
    for _, icon in ipairs(p.debuffIcons) do icon:Hide() end
    for _, icon in ipairs(p.buffIcons) do icon:Hide() end
    p.root:SetScale(1)
    p.root:Hide()
    p.unit = nil
    p.kind = nil
end

local layoutVersion = 1

local function FullUpdate(p)
    local db = GetDB()
    if p.layoutVersion ~= layoutVersion or p.layoutKind ~= p.kind then
        ApplyLayout(p)
        p.layoutVersion = layoutVersion
        p.layoutKind = p.kind
    end

    if p.kind == "friendly" then
        p.health:Hide()
        p.level:Hide()
        p.raidIcon:Hide()
        HideCast(p)
        UpdateAuras(p)
        if db.friendlyMode == "hide" then
            p.root:Hide()
            return
        end
        p.name:Show()
        UpdateName(p)
        p.root:SetScale(1)
        p.root:Show()
        return
    end

    p.health:Show()
    p.name:SetShown(db.showName)
    UpdateName(p)
    UpdateHealthValues(p)
    UpdateHealthColor(p)
    UpdateLevel(p)
    UpdateSelection(p)
    UpdateRaidIcon(p)
    RefreshCast(p)
    UpdateAuras(p)
    p.root:Show()
end

function SUI_NP:AttachUnit(unit, base)
    if not self.enabled or not unit then return end
    base = base or C_NamePlate.GetNamePlateForUnit(unit)
    if not base or base:IsForbidden() then return end

    local uf = base.UnitFrame
    local kind = ClassifyUnit(unit)
    local p = plates[base] or CreatePlate(base)

    local previous = unitPlates[unit]
    if previous and previous ~= p then DetachPlate(previous) end
    if p.unit and p.unit ~= unit then DetachPlate(p) end

    if not kind then
        if p.unit then DetachPlate(p) end
        RestoreBlizzard(uf)
        return
    end

    if uf then
        SuppressBlizzard(uf)
    else
        -- Fallback path (no driver hook): UnitFrame not acquired yet.
        C_Timer.After(0, function()
            if unitPlates[unit] == p and base.UnitFrame then
                SuppressBlizzard(base.UnitFrame)
            end
        end)
    end

    p.unit = unit
    p.kind = kind
    p.isPlayer = PlainTrue(UnitIsPlayer(unit))
    unitPlates[unit] = p

    RegisterPlateEvents(p)
    FullUpdate(p)
end

function SUI_NP:DetachUnit(unit)
    local p = unitPlates[unit]
    if p then DetachPlate(p) end
end

local function ForEachLivePlate(fn)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, base in ipairs(C_NamePlate.GetNamePlates()) do
        if not base:IsForbidden() then
            local unit = base.GetUnit and base:GetUnit()
            if not IsSecret(unit) and unit then
                fn(unit, base)
            end
        end
    end
end

---------------------------------------------------------------------------
-- DRIVER (global events, hooks, enable/disable)
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local driverHooked = false
local hooksInstalled = false

local GLOBAL_EVENTS = {
    "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "RAID_TARGET_UPDATE",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD",
    "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN",
}

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    if NamePlateDriverFrame and NamePlateDriverFrame.OnNamePlateAdded then
        hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, unit)
            if SUI_NP.enabled then
                SUI_NP:AttachUnit(unit)
            end
        end)
        driverHooked = true
    end
end

driver:SetScript("OnEvent", function(_, event, arg1)
    if not SUI_NP.enabled then return end

    if event == "NAME_PLATE_UNIT_ADDED" then
        SUI_NP:AttachUnit(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        SUI_NP:DetachUnit(arg1)
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        for _, p in pairs(unitPlates) do UpdateSelection(p) end
    elseif event == "RAID_TARGET_UPDATE" then
        for _, p in pairs(unitPlates) do UpdateRaidIcon(p) end
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        MarkAllColors()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        RefreshGroupTanks()
        RefreshPlayerRole()
        MarkAllColors()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        RefreshPlayerRole()
        RefreshKickSpell()
        MarkAllColors()
    elseif event == "SPELLS_CHANGED" or event == "UNIT_PET" then
        RefreshKickSpell()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if kickSpell and GetDB().kickTint then
            for p in pairs(activeCasts) do ApplyCastColor(p) end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshPlayerRole()
        RefreshGroupTanks()
        RefreshKickSpell()
        ForEachLivePlate(function(unit, base) SUI_NP:AttachUnit(unit, base) end)
    end
end)

function SUI_NP:Enable()
    if self.enabled then return end
    self.enabled = true
    InstallHooks()

    for _, event in ipairs(GLOBAL_EVENTS) do driver:RegisterEvent(event) end
    driver:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
    driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    driver:RegisterUnitEvent("UNIT_PET", "player")
    if not driverHooked then
        driver:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    end

    RefreshPlayerRole()
    RefreshGroupTanks()
    RefreshKickSpell()
    ForEachLivePlate(function(unit, base) SUI_NP:AttachUnit(unit, base) end)
end

function SUI_NP:Disable()
    if not self.enabled then return end
    self.enabled = false
    driver:UnregisterAllEvents()

    for _, p in pairs(plates) do
        if p.unit then DetachPlate(p) end
    end
    for uf in pairs(ownedUF) do
        RestoreBlizzard(uf)
    end
    wipe(activeCasts)
    wipe(dirtyColor)
    wipe(dirtyAuras)
    castTicker:Hide()
    flusher:Hide()
end

-- Called by the options page after any change.
function SUI_NP:Refresh()
    local db = GetDB()
    if not db then return end
    if db.enabled and not self.enabled then
        self:Enable()
        return
    elseif not db.enabled then
        self:Disable()
        return
    end

    -- Re-run attach for every live plate: picks up layout, colors and
    -- friendly-mode changes in one pass.
    layoutVersion = layoutVersion + 1
    ForEachLivePlate(function(unit, base) SUI_NP:AttachUnit(unit, base) end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local db = GetDB()
    if db and db.enabled then
        SUI_NP:Enable()
    end
end)

_G.SuaviUI_RefreshNameplates = function() SUI_NP:Refresh() end
