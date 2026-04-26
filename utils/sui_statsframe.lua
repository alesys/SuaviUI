--[[
    SuaviUI Real-time Stats Frame
    Standalone HUD frame that shows player stats live (out of character pane).

    Sections (each independently toggleable in Edit Mode sidebar):
        - Health & Resource
        - Attributes (Strength, Agility, Stamina, Intellect)
        - Secondary  (Crit, Haste, Mastery, Versatility)
        - Attack     (AP, SP, Attack Speed)
        - Defense    (Armor, Dodge, Parry, Block)
        - General    (Leech, Speed)

    Movable in Edit Mode via LibEQOLEditMode-1.0.

    Secret-value safety: WoW 12.x stat APIs return secret values during combat
    while in groups. Each row read is sanitized via SafeStat / SafeGetStat,
    and each row render is wrapped in pcall so a single secret doesn't blank
    the whole frame.
]]

local ADDON_NAME, ns = ...

local LEM = LibStub("LibEQOLEditMode-1.0", true)
if not LEM then return end

local SUI_StatsFrame = {}
ns.StatsFrame = SUI_StatsFrame

---------------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------------
local holder              -- the frame registered with Edit Mode
local sectionsContainer   -- vertical layout of sections inside holder
local eventFrame
local updateThrottleTimer
local registered = false
local initialized = false

local IsSecretValue = function(v)
    return ns.Utils and ns.Utils.IsSecretValue and ns.Utils.IsSecretValue(v) or false
end

local function SafeStat(v)
    if v == nil or IsSecretValue(v) then return 0 end
    if type(v) == "number" then return v end
    return 0
end

-- ============================================================
-- STRING CACHE — read from Blizzard's PaperDollFrame_Set* hooks
-- ============================================================
-- Blizzard's own paper-doll stat functions run when CharacterFrame is shown.
-- They internally read UnitStat / GetCritChance / etc., format the result,
-- and write the result string to `statFrame.Value:SetText(text)`.
--
-- Crucially, those internal API calls happen in Blizzard's secure execution
-- context (the panel's OnEvent was registered by Blizzard, not us), so the
-- returned values are NOT secret-tainted. The resulting FontString contains
-- a regular Lua string we can read with `:GetText()`.
--
-- We hooksecurefunc each PaperDollFrame_Set* function. After Blizzard runs,
-- we read the formatted text and stash it in `statTexts[key]`. We then
-- display that string directly in our frame — no arithmetic, no
-- comparisons, no taint.
--
-- The only requirement is that CharacterFrame has been shown at least once
-- in the session so the hooks fire and populate the cache.
local statTexts = {}

local function CacheStringFromFrame(key, statFrame)
    if not statFrame or not statFrame.Value or not statFrame.Value.GetText then return end
    local ok, txt = pcall(statFrame.Value.GetText, statFrame.Value)
    if not ok then return end
    if type(txt) ~= "string" then return end
    -- Defensive: if our addon ever triggers Blizzard's UpdateStats from a
    -- tainted context, the resulting string is also secret. Comparing it
    -- (txt ~= "") would error, so bail early.
    if IsSecretValue(txt) then return end
    if txt ~= "" then statTexts[key] = txt end
end

local SET_STAT_INDEX_KEY = { [1] = "strength", [2] = "agility", [3] = "stamina", [4] = "intellect" }

local function InstallBlizzardHooks()
    if statTexts.__hooked then return end
    statTexts.__hooked = true

    -- Primary stats — same function called with different statIndex
    if type(PaperDollFrame_SetStat) == "function" then
        hooksecurefunc("PaperDollFrame_SetStat", function(frame, _, statIndex)
            local k = SET_STAT_INDEX_KEY[statIndex]
            if k then CacheStringFromFrame(k, frame) end
        end)
    end

    local function HookOne(funcName, key)
        if type(_G[funcName]) == "function" then
            hooksecurefunc(funcName, function(frame) CacheStringFromFrame(key, frame) end)
        end
    end
    HookOne("PaperDollFrame_SetHealth",      "health")
    HookOne("PaperDollFrame_SetPower",       "power")
    HookOne("PaperDollFrame_SetCritChance",  "crit")
    HookOne("PaperDollFrame_SetHaste",       "haste")
    HookOne("PaperDollFrame_SetMastery",     "mastery")
    HookOne("PaperDollFrame_SetVersatility", "versatility")
    HookOne("PaperDollFrame_SetLifesteal",   "leech")
    HookOne("PaperDollFrame_SetAvoidance",   "avoidance")
    HookOne("PaperDollFrame_SetSpeed",       "speed")
    HookOne("PaperDollFrame_SetAttackPower", "attackPower")
    HookOne("PaperDollFrame_SetSpellPower",  "spellPower")
    HookOne("PaperDollFrame_SetDamage",      "damage")
    HookOne("PaperDollFrame_SetWeaponSpeed", "attackSpeed")
    HookOne("PaperDollFrame_SetArmor",       "armor")
    HookOne("PaperDollFrame_SetDodge",       "dodge")
    HookOne("PaperDollFrame_SetParry",       "parry")
    HookOne("PaperDollFrame_SetBlock",       "block")
end

-- Per-stat cache of the last "good" (non-secret) numeric reading. During
-- combat in groups, WoW 12.x stat APIs return secret values which can't be
-- displayed or arithmetically processed. CachedStat falls back to the most
-- recent good value so the row keeps showing instead of disappearing.
local lastGood = {}

-- Returns (numericValue, isStale). isStale is true when the current API call
-- returned a secret/nil and we're falling back to the cache.
local function CachedStat(cacheKey, func, ...)
    if type(func) ~= "function" then return lastGood[cacheKey], true end
    local ok, result = pcall(func, ...)
    if ok and result ~= nil and not IsSecretValue(result) and type(result) == "number" then
        lastGood[cacheKey] = result
        return result, false
    end
    return lastGood[cacheKey], true
end

-- Same idea but for APIs that return multiple values (e.g. UnitStat returns
-- base, effective, posBuff, negBuff). We cache the second return (effective)
-- since that's what every fetcher uses. If the API fails or returns secrets,
-- fall back to the cached effective value.
local function CachedStatEffective(cacheKey, func, ...)
    if type(func) ~= "function" then return lastGood[cacheKey], true end
    local ok, _, eff = pcall(func, ...)
    if ok and eff ~= nil and not IsSecretValue(eff) and type(eff) == "number" then
        lastGood[cacheKey] = eff
        return eff, false
    end
    return lastGood[cacheKey], true
end

-- Legacy alias kept for any older callsite that wants a numeric-only result.
local function SafeGetStat(func, ...)
    if type(func) ~= "function" then return 0 end
    local ok, result = pcall(func, ...)
    if not ok then return 0 end
    if IsSecretValue(result) then return 0 end
    return tonumber(result) or 0
end

---------------------------------------------------------------------------
-- DATABASE
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
    return db and db.statsFrame or nil
end

---------------------------------------------------------------------------
-- COLORS (hex-ish, normalized 0-1)
---------------------------------------------------------------------------
local C = {
    text       = { 0.95, 0.95, 0.95 },
    label      = { 0.8,  0.8,  0.85 },
    header     = { 0.30, 0.85, 0.99 },  -- Snazzy cyan
    accent     = { 0.30, 0.85, 0.99 },
    health     = { 0.40, 0.95, 0.40 },
    mana       = { 0.30, 0.55, 1.00 },
    crit       = { 1.00, 0.60, 0.20 },
    haste      = { 0.30, 0.85, 0.99 },
    mastery    = { 0.85, 0.50, 1.00 },
    versatility= { 0.50, 1.00, 0.60 },
}

local POWER_NAMES = {
    [0] = { name = "Mana",        color = C.mana },
    [1] = { name = "Rage",        color = { 1, 0.2, 0.2 } },
    [2] = { name = "Focus",       color = { 1, 0.5, 0.25 } },
    [3] = { name = "Energy",      color = { 1, 1, 0.2 } },
    [6] = { name = "Runic Power", color = { 0, 0.82, 1 } },
    [11]= { name = "Maelstrom",   color = { 0, 0.5, 1 } },
    [13]= { name = "Insanity",    color = { 0.4, 0, 0.8 } },
    [17]= { name = "Fury",        color = { 0.79, 0.26, 0.99 } },
    [18]= { name = "Pain",        color = { 1, 0.6, 0.2 } },
}

---------------------------------------------------------------------------
-- FORMATTERS
---------------------------------------------------------------------------
local function FormatNumber(n)
    n = tonumber(n) or 0
    if n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n + 0.5)) end
end

local function FormatPercent(v)
    v = tonumber(v) or 0
    return string.format("%.2f%%", v)
end

---------------------------------------------------------------------------
-- ROW POOL
---------------------------------------------------------------------------
local rowPool = {}

local function AcquireRow(parent)
    local row = table.remove(rowPool)
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:SetHeight(14)
        row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.label:SetJustifyH("LEFT")
        row.value = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        row.value:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.value:SetJustifyH("RIGHT")
    end
    row:SetParent(parent)
    row:Show()
    return row
end

local function ReleaseRow(row)
    if not row then return end
    row:Hide()
    row:ClearAllPoints()
    row:SetParent(nil)
    row.label:SetText("")
    row.value:SetText("")
    row.label:SetTextColor(C.label[1], C.label[2], C.label[3], 1)
    row.value:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    table.insert(rowPool, row)
end

local headerPool = {}
local function AcquireHeader(parent)
    local h = table.remove(headerPool)
    if not h then
        h = CreateFrame("Frame", nil, parent)
        h:SetHeight(16)
        h.text = h:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        h.text:SetPoint("LEFT", h, "LEFT", 0, 0)
        h.text:SetJustifyH("LEFT")
        h.line = h:CreateTexture(nil, "ARTWORK")
        h.line:SetHeight(1)
        h.line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.5)
    end
    h:SetParent(parent)
    h:Show()
    return h
end

local function ReleaseHeader(h)
    if not h then return end
    h:Hide()
    h:ClearAllPoints()
    h:SetParent(nil)
    h.text:SetText("")
    h.line:ClearAllPoints()
    table.insert(headerPool, h)
end

---------------------------------------------------------------------------
-- DATA FETCHERS — return list of {label, value, color?} per section
---------------------------------------------------------------------------
-- Color helper: dim the value when we're showing a cached (stale) reading
-- because the live API returned a secret value.
local function ColorOrStale(baseColor, stale)
    if stale then return { 0.55, 0.55, 0.55 } end
    return baseColor
end

-- Build a row entry. PRIORITY:
--   1. Live numeric value (`num`) when it's NOT stale — comes from a fresh
--      API call we just made (out of combat, no buff/debuff issues). This
--      reflects auras, equipment swaps, etc. immediately.
--   2. statTexts[key] — string captured from Blizzard's CharacterStatsPane.
--      Used as fallback when `num` is stale (combat in groups → cache hit
--      from before combat; the Blizzard string may actually be MORE current
--      if the user opened the panel during combat in clean context).
--   3. Stale numeric (`num`) — last cached numeric formatted by us.
--   4. "—" placeholder — never had a good reading yet.
local function MakeRow(key, label, num, stale, formatter, baseColor)
    -- Fresh numeric beats anything (reflects auras out of combat).
    if num ~= nil and not stale then
        return {
            key = key, label = label,
            value = formatter(num),
            color = baseColor,
            stale = false,
        }
    end

    -- Numeric is stale (in combat with secret returns). Prefer Blizzard's
    -- string if we have one — it may have been refreshed when the user
    -- opened the panel during combat.
    local blizzText = statTexts[key]
    if blizzText then
        return {
            key = key, label = label,
            value = blizzText,
            color = baseColor,
            stale = false,
        }
    end

    -- Fall back to stale numeric (last known good before combat).
    if num ~= nil then
        return {
            key = key, label = label,
            value = formatter(num),
            color = ColorOrStale(baseColor, true),
            stale = true,
        }
    end

    return {
        key = key, label = label,
        value = "—",
        color = { 0.4, 0.4, 0.4 },
        stale = true,
    }
end

local function GetHealthRows(unit)
    local rows = {}
    local hp, hpStale = CachedStat("health", UnitHealthMax, unit)
    local r = MakeRow("health", "Health", hp, hpStale, FormatNumber, C.health)
    if r then table.insert(rows, r) end

    -- Power name/color depends on power type — also cache per-type so it stays
    -- stable through combat.
    local pType, _ = CachedStat("powerType", UnitPowerType, unit)
    pType = pType or 0
    local pInfo = POWER_NAMES[pType]
    local pName = pInfo and pInfo.name or "Power"
    local pColor = pInfo and pInfo.color or C.mana
    local pMax, pStale = CachedStat("powerMax", UnitPowerMax, unit, pType)
    local pr = MakeRow("power", pName, pMax, pStale, FormatNumber, pColor)
    if pr then table.insert(rows, pr) end
    return rows
end

local function GetAttributeRows(unit)
    local rows = {}
    local labels = { "Strength", "Agility", "Stamina", "Intellect" }
    local keys   = { "strength", "agility", "stamina", "intellect" }
    for i = 1, 4 do
        local eff, stale = CachedStatEffective("attr_" .. i, UnitStat, unit, i)
        local r = MakeRow(keys[i], labels[i], eff, stale, FormatNumber, C.text)
        if r and (eff or 0) > 0 then table.insert(rows, r) end
    end
    return rows
end

local function GetSecondaryRows()
    local rows = {}
    local v, stale
    v, stale = CachedStat("crit", GetCritChance)
    table.insert(rows, MakeRow("crit", "Crit", v, stale, FormatPercent, C.crit))
    v, stale = CachedStat("haste", GetHaste)
    table.insert(rows, MakeRow("haste", "Haste", v, stale, FormatPercent, C.haste))
    v, stale = CachedStat("mastery", GetMasteryEffect)
    table.insert(rows, MakeRow("mastery", "Mastery", v, stale, FormatPercent, C.mastery))
    v, stale = CachedStat("vers", GetCombatRatingBonus, CR_VERSATILITY_DAMAGE_DONE)
    table.insert(rows, MakeRow("versatility", "Versatility", v, stale, FormatPercent, C.versatility))

    -- Drop nil placeholders (rare — happens only if API never returned a good value)
    for i = #rows, 1, -1 do if rows[i] == nil then table.remove(rows, i) end end
    return rows
end

local function GetAttackRows(unit)
    local rows = {}
    local ap, apStale = CachedStatEffective("attackPower", UnitAttackPower, unit)
    if ap and ap ~= 0 then
        table.insert(rows, MakeRow("attackPower", "Attack Power", ap, apStale, FormatNumber, C.text))
    end
    if GetSpellBonusDamage then
        local sp, spStale = CachedStat("spellPower", GetSpellBonusDamage, 2)
        if sp and sp ~= 0 then
            table.insert(rows, MakeRow("spellPower", "Spell Power", sp, spStale, FormatNumber, C.text))
        end
    end
    local speed, spdStale = CachedStat("attackSpeed", UnitAttackSpeed, unit)
    if speed and speed ~= 0 then
        local function FormatSpeed(s) return string.format("%.2fs", s) end
        table.insert(rows, MakeRow("attackSpeed", "Attack Speed", speed, spdStale, FormatSpeed, C.text))
    end
    for i = #rows, 1, -1 do if rows[i] == nil then table.remove(rows, i) end end
    return rows
end

local function GetDefenseRows(unit)
    local rows = {}
    local armor, arStale = CachedStatEffective("armor", UnitArmor, unit)
    table.insert(rows, MakeRow("armor", "Armor", armor, arStale, FormatNumber, C.text))
    local dodge, dgStale = CachedStat("dodge", GetDodgeChance)
    table.insert(rows, MakeRow("dodge", "Dodge", dodge, dgStale, FormatPercent, C.text))
    local parry, prStale = CachedStat("parry", GetParryChance)
    table.insert(rows, MakeRow("parry", "Parry", parry, prStale, FormatPercent, C.text))
    local block, blStale = CachedStat("block", GetBlockChance)
    if block and block > 0 then
        table.insert(rows, MakeRow("block", "Block", block, blStale, FormatPercent, C.text))
    end
    for i = #rows, 1, -1 do if rows[i] == nil then table.remove(rows, i) end end
    return rows
end

local function GetGeneralRows()
    local rows = {}
    local v, stale
    v, stale = CachedStat("leech", GetLifesteal)
    table.insert(rows, MakeRow("leech", "Leech", v, stale, FormatPercent, C.text))
    v, stale = CachedStat("speed", GetSpeed)
    table.insert(rows, MakeRow("speed", "Speed", v, stale, FormatPercent, C.text))
    if GetAvoidance then
        v, stale = CachedStat("avoidance", GetAvoidance)
        table.insert(rows, MakeRow("avoidance", "Avoidance", v, stale, FormatPercent, C.text))
    end
    for i = #rows, 1, -1 do if rows[i] == nil then table.remove(rows, i) end end
    return rows
end

-- Each section lists the keys of its rows so the sidebar can build per-stat
-- checkboxes without us having to hardcode them in two places.
local SECTIONS = {
    { id = "showHealth",     title = "Vitals",     fetch = GetHealthRows,    rowKeys = { { "health", "Health" }, { "power", "Power" } } },
    { id = "showAttributes", title = "Attributes", fetch = GetAttributeRows, rowKeys = { { "strength", "Strength" }, { "agility", "Agility" }, { "stamina", "Stamina" }, { "intellect", "Intellect" } } },
    { id = "showSecondary",  title = "Secondary",  fetch = GetSecondaryRows, rowKeys = { { "crit", "Crit" }, { "haste", "Haste" }, { "mastery", "Mastery" }, { "versatility", "Versatility" } } },
    { id = "showAttack",     title = "Attack",     fetch = GetAttackRows,    rowKeys = { { "attackPower", "Attack Power" }, { "spellPower", "Spell Power" }, { "attackSpeed", "Attack Speed" } } },
    { id = "showDefense",    title = "Defense",    fetch = GetDefenseRows,   rowKeys = { { "armor", "Armor" }, { "dodge", "Dodge" }, { "parry", "Parry" }, { "block", "Block" } } },
    { id = "showGeneral",    title = "General",    fetch = GetGeneralRows,   rowKeys = { { "leech", "Leech" }, { "speed", "Speed" }, { "avoidance", "Avoidance" } } },
}

-- Per-stat visibility check: missing entry or true = show; false = hide.
local function IsStatVisible(s, key)
    if not s or not s.stats then return true end
    return s.stats[key] ~= false
end

---------------------------------------------------------------------------
-- LAYOUT / RENDERING
---------------------------------------------------------------------------
local activeRows = {}
local activeHeaders = {}

local function ClearActiveWidgets()
    for _, r in ipairs(activeRows) do ReleaseRow(r) end
    wipe(activeRows)
    for _, h in ipairs(activeHeaders) do ReleaseHeader(h) end
    wipe(activeHeaders)
end

local function Rebuild()
    if not initialized or not holder or not sectionsContainer then return end
    local s = GetSettings(); if not s then return end

    ClearActiveWidgets()

    local fontSize = s.fontSize or 11
    local width = s.width or 180
    sectionsContainer:SetWidth(width - 8)

    local yCursor = 0
    local rowHeight = fontSize + 3
    local headerHeight = fontSize + 4
    local sectionGap = 6

    local renderedAny = false

    for _, section in ipairs(SECTIONS) do
        if s[section.id] then
            local ok, rawRows = pcall(section.fetch, "player")
            -- Filter out rows whose individual stat toggle is off.
            local rows = {}
            if ok and rawRows then
                for _, rd in ipairs(rawRows) do
                    if IsStatVisible(s, rd.key) then
                        table.insert(rows, rd)
                    end
                end
            end
            if #rows > 0 then
                renderedAny = true
                if yCursor < 0 then yCursor = yCursor - sectionGap end

                local h = AcquireHeader(sectionsContainer)
                h:SetPoint("TOPLEFT", sectionsContainer, "TOPLEFT", 0, yCursor)
                h:SetPoint("RIGHT", sectionsContainer, "RIGHT", 0, 0)
                h:SetHeight(headerHeight)
                h.text:SetTextColor(C.header[1], C.header[2], C.header[3], 1)
                local font, _, flags = h.text:GetFont()
                if font then h.text:SetFont(font, math.floor(fontSize * 0.95), flags or "") end
                h.text:SetText(section.title)
                h.line:ClearAllPoints()
                h.line:SetPoint("LEFT", h.text, "RIGHT", 4, 1)
                h.line:SetPoint("RIGHT", h, "RIGHT", 0, 1)
                table.insert(activeHeaders, h)
                yCursor = yCursor - headerHeight

                for _, rd in ipairs(rows) do
                    pcall(function()
                        local r = AcquireRow(sectionsContainer)
                        r:SetPoint("TOPLEFT", sectionsContainer, "TOPLEFT", 0, yCursor)
                        r:SetPoint("RIGHT", sectionsContainer, "RIGHT", 0, 0)
                        r:SetHeight(rowHeight)
                        local font, _, flags = r.label:GetFont()
                        if font then r.label:SetFont(font, fontSize, flags or "") end
                        local font2, _, flags2 = r.value:GetFont()
                        if font2 then r.value:SetFont(font2, fontSize, flags2 or "") end
                        r.label:SetText(rd.label or "")
                        r.value:SetText(rd.value or "")
                        local col = rd.color or C.text
                        r.value:SetTextColor(col[1], col[2], col[3], 1)
                        r.label:SetTextColor(C.label[1], C.label[2], C.label[3], 1)
                        table.insert(activeRows, r)
                        yCursor = yCursor - rowHeight
                    end)
                end
            end
        end
    end

    -- If nothing rendered, show a stub so the holder isn't zero-size in Edit Mode
    if not renderedAny and holder._editModePreviewActive then
        local h = AcquireHeader(sectionsContainer)
        h:SetPoint("TOPLEFT", sectionsContainer, "TOPLEFT", 0, 0)
        h:SetPoint("RIGHT", sectionsContainer, "RIGHT", 0, 0)
        h:SetHeight(headerHeight)
        h.text:SetText("(no sections enabled)")
        h.text:SetTextColor(0.6, 0.6, 0.6, 1)
        table.insert(activeHeaders, h)
        yCursor = -headerHeight
    end

    -- Resize holder to fit content
    local totalHeight = math.max(20, math.abs(yCursor) + 12)
    holder:SetSize(width, totalHeight)
    sectionsContainer:ClearAllPoints()
    sectionsContainer:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -6)
    sectionsContainer:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -4, 6)
end

local function ScheduleRebuild()
    if updateThrottleTimer then return end
    updateThrottleTimer = C_Timer.NewTimer(0.15, function()
        updateThrottleTimer = nil
        Rebuild()
    end)
end

---------------------------------------------------------------------------
-- BACKGROUND
---------------------------------------------------------------------------
local function ApplyBackground()
    if not holder then return end
    local s = GetSettings(); if not s then return end
    if s.showBackground then
        if not holder._bg then
            holder._bg = holder:CreateTexture(nil, "BACKGROUND")
            holder._bg:SetAllPoints(holder)
        end
        holder._bg:SetColorTexture(0.08, 0.08, 0.10, s.backgroundOpacity or 0.6)
        holder._bg:Show()
    elseif holder._bg then
        holder._bg:Hide()
    end
end

---------------------------------------------------------------------------
-- POSITION
---------------------------------------------------------------------------
local function LoadPosition()
    local s = GetSettings(); if not s or not holder then return end
    local p = s.position or { point = "CENTER", x = 250, y = 0 }
    holder:ClearAllPoints()
    holder:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x or 0, p.y or 0)
end

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

---------------------------------------------------------------------------
-- REFRESH
---------------------------------------------------------------------------
function SUI_StatsFrame:Refresh()
    if not initialized then return end
    local s = GetSettings(); if not s then return end
    if not s.enabled and not (holder and holder._editModePreviewActive) then
        if holder then holder:Hide() end
        return
    end
    if holder then holder:Show() end
    ApplyBackground()
    Rebuild()
end

---------------------------------------------------------------------------
-- LEM SETTINGS
---------------------------------------------------------------------------
local function MakeBoolSetting(name, key, default)
    return {
        name = name, kind = LEM.SettingType.Checkbox, default = default,
        get = function() local s = GetSettings(); return s and s[key] or false end,
        set = function(_, value)
            local s = GetSettings()
            if s then s[key] = value; SUI_StatsFrame:Refresh() end
        end,
    }
end

local function BuildLEMSettings()
    local settings = {}
    local order = 1
    local function add(t)
        t.order = order; order = order + 1
        table.insert(settings, t)
    end

    add({
        name = "Enable", kind = LEM.SettingType.Checkbox, default = false,
        get = function() local s = GetSettings(); return s and s.enabled or false end,
        set = function(_, v)
            local s = GetSettings(); if s then s.enabled = v; SUI_StatsFrame:Refresh() end
        end,
    })

    -- Per-section collapsibles. Each contains:
    --   1. Master "Show <Section>" checkbox
    --   2. Per-stat checkboxes for every row in that section
    -- This lets a Warlock disable Strength/Agility under Attributes while
    -- keeping the section visible for Stamina/Intellect.
    local function MakePerStatSetting(parentId, label, statKey)
        return {
            parentId = parentId, name = label,
            kind = LEM.SettingType.Checkbox, default = true,
            get = function()
                local s = GetSettings()
                return s and s.stats and s.stats[statKey] ~= false or false
            end,
            set = function(_, v)
                local s = GetSettings()
                if s then
                    if not s.stats then s.stats = {} end
                    s.stats[statKey] = v
                    SUI_StatsFrame:Refresh()
                end
            end,
        }
    end

    for i, section in ipairs(SECTIONS) do
        local categoryId = "STATS_SEC_" .. section.id
        add({
            name = section.title,
            kind = LEM.SettingType.Collapsible,
            id = categoryId,
            defaultCollapsed = (i > 2),  -- Vitals + Attributes open by default; rest collapsed
        })

        -- Master toggle for the whole section
        local master = MakeBoolSetting("Show " .. section.title, section.id, true)
        master.parentId = categoryId
        add(master)

        -- Per-stat toggles
        for _, kv in ipairs(section.rowKeys) do
            local statKey, statLabel = kv[1], kv[2]
            add(MakePerStatSetting(categoryId, statLabel, statKey))
        end
    end

    -- Appearance
    add({ name = "Appearance", kind = LEM.SettingType.Collapsible, id = "STATS_APPEARANCE", defaultCollapsed = true })

    add({
        parentId = "STATS_APPEARANCE", name = "Width",
        kind = LEM.SettingType.Slider, default = 180,
        minValue = 120, maxValue = 320, valueStep = 5,
        get = function() local s = GetSettings(); return s and s.width or 180 end,
        set = function(_, v)
            local s = GetSettings(); if s then s.width = math.floor(v); SUI_StatsFrame:Refresh() end
        end,
    })

    add({
        parentId = "STATS_APPEARANCE", name = "Font Size",
        kind = LEM.SettingType.Slider, default = 11,
        minValue = 8, maxValue = 18, valueStep = 1,
        get = function() local s = GetSettings(); return s and s.fontSize or 11 end,
        set = function(_, v)
            local s = GetSettings(); if s then s.fontSize = math.floor(v); SUI_StatsFrame:Refresh() end
        end,
    })

    local bgT = MakeBoolSetting("Show Background", "showBackground", true)
    bgT.parentId = "STATS_APPEARANCE"; add(bgT)

    add({
        parentId = "STATS_APPEARANCE", name = "Background Opacity",
        kind = LEM.SettingType.Slider, default = 0.6,
        minValue = 0, maxValue = 1, valueStep = 0.05,
        formatter = function(v) return string.format("%.0f%%", v * 100) end,
        get = function() local s = GetSettings(); return s and s.backgroundOpacity or 0.6 end,
        set = function(_, v)
            local s = GetSettings(); if s then s.backgroundOpacity = v; SUI_StatsFrame:Refresh() end
        end,
    })

    -- Live Combat Updates section (separate so it's discoverable)
    add({ name = "Live Combat Updates", kind = LEM.SettingType.Collapsible, id = "STATS_LIVE", defaultCollapsed = true })

    add({
        parentId = "STATS_LIVE", name = "Enable Live Combat Updates",
        kind = LEM.SettingType.Checkbox, default = false,
        get = function() local s = GetSettings(); return s and s.liveCombatStats or false end,
        set = function(_, v)
            local s = GetSettings(); if s then
                s.liveCombatStats = v
                ApplyLiveTrickState()
                SUI_StatsFrame:Refresh()
            end
        end,
    })

    return settings
end

---------------------------------------------------------------------------
-- LEM REGISTRATION
---------------------------------------------------------------------------
local function RegisterWithLEM()
    if registered or not holder then return end
    holder.editModeName = "Stats Frame"

    local s = GetSettings()
    local defaults = {
        point = (s and s.position and s.position.point) or "CENTER",
        x = (s and s.position and s.position.x) or 250,
        y = (s and s.position and s.position.y) or 0,
    }

    local ok = pcall(function()
        LEM:AddFrame(holder, OnPositionChanged, defaults)
        LEM:AddFrameSettings(holder, BuildLEMSettings())
        LEM:SetFrameDragEnabled(holder, function()
            if LEM.IsInEditMode and LEM:IsInEditMode() then return true end
            return s and s.enabled or false
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
    end

    LEM:RegisterCallback("enter", function()
        if not holder then return end
        holder._editModePreviewActive = true
        SUI_StatsFrame:Refresh()
    end)
    LEM:RegisterCallback("exit", function()
        if not holder then return end
        holder._editModePreviewActive = nil
        SUI_StatsFrame:Refresh()
    end)
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
local function CreateHolder()
    holder = CreateFrame("Frame", "SuaviUI_StatsFrame", UIParent)
    holder:SetSize(180, 80)
    holder:SetFrameStrata("MEDIUM")

    sectionsContainer = CreateFrame("Frame", nil, holder)
    sectionsContainer:SetPoint("TOPLEFT", holder, "TOPLEFT", 4, -6)
    sectionsContainer:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -4, 6)
end

local function CreateEventFrame()
    eventFrame = CreateFrame("Frame")
    -- Account-wide / non-unit events
    local accountEvents = {
        "PLAYER_ENTERING_WORLD",
        "PLAYER_EQUIPMENT_CHANGED",
        "COMBAT_RATING_UPDATE",
        "MASTERY_UPDATE",
        "SPEED_UPDATE",
        "LIFESTEAL_UPDATE",
        "AVOIDANCE_UPDATE",
        "PLAYER_DAMAGE_DONE_MODS",
        "SPELL_POWER_CHANGED",
        "PLAYER_SPECIALIZATION_CHANGED",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_REGEN_ENABLED",
    }
    for _, ev in ipairs(accountEvents) do
        eventFrame:RegisterEvent(ev)
    end

    -- Unit events filtered to "player" so we don't fire on every party
    -- member's buff/health change. UNIT_AURA in particular is critical for
    -- temporary stat buffs/debuffs (potions, raid buffs) that don't fire
    -- specific stat events but still alter displayed values.
    local playerUnitEvents = {
        "UNIT_STATS", "UNIT_DAMAGE", "UNIT_RANGEDDAMAGE", "UNIT_RESISTANCES",
        "UNIT_HEALTH", "UNIT_MAXHEALTH",
        "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
        "UNIT_AURA",
    }
    for _, ev in ipairs(playerUnitEvents) do
        eventFrame:RegisterUnitEvent(ev, "player")
    end
    eventFrame:SetScript("OnEvent", function()
        ScheduleRebuild()
    end)
end

-- NOTE: We do NOT call PaperDollFrame_UpdateStats() from addon code.
-- Doing so taints the entire Blizzard call chain — every internal call to
-- UnitStat/GetCritChance/etc. inside Blizzard's update returns secret
-- values, the resulting strings are secret strings, and our hooks then
-- error trying to compare them. The string cache only populates from
-- Blizzard's own OnEvent (when the user opens the character pane), which
-- runs in clean context.
--
-- For the case when the user has never opened the panel this session, the
-- numeric cache (`lastGood`, populated by CachedStat below) takes over.
-- That cache reads from the live APIs only when out of combat (where they
-- return regular numbers), so it stays current without any taint risk.

-- ============================================================
-- LIVE COMBAT STATS — keep CharacterFrame logically visible
-- ============================================================
-- Optional opt-in. When enabled, we Show() CharacterFrame at addon load
-- with alpha=0 and mouse disabled. The frame is invisible to the user but
-- IsVisible() returns true, so Blizzard's PaperDollFrame:OnEvent doesn't
-- bail and UpdateStats keeps running on every stat-relevant event — in
-- Blizzard's clean execution context. Our hooksecurefunc callbacks then
-- capture freshly-formatted strings even during combat in groups.
--
-- When the user opens the panel normally (ToggleCharacter, hotkey, etc.)
-- ShowUIPanel runs and we restore alpha=1 + mouse on so the user sees the
-- real panel. When they close, we re-engage the invisible state.
local trickActive = false

local function ShouldUseTrick()
    local s = GetSettings()
    return s and s.enabled and s.liveCombatStats or false
end

local function EngageInvisibleShow()
    if not CharacterFrame then return end
    if InCombatLockdown() then return end

    -- Suppress the IG_CHARACTER_INFO_OPEN sound by briefly muting SFX.
    -- C_Timer restores after one frame so other sounds aren't affected.
    local sfx = GetCVar("Sound_EnableSFX")
    SetCVar("Sound_EnableSFX", "0")

    if not CharacterFrame:IsShown() then
        CharacterFrame:Show()
    end
    CharacterFrame:SetAlpha(0)
    CharacterFrame:EnableMouse(false)

    C_Timer.After(0.1, function()
        SetCVar("Sound_EnableSFX", sfx)
    end)
end

local function DisengageInvisibleShow()
    if not CharacterFrame then return end
    CharacterFrame:SetAlpha(1)
    CharacterFrame:EnableMouse(true)
    if CharacterFrame:IsShown() then
        local sfx = GetCVar("Sound_EnableSFX")
        SetCVar("Sound_EnableSFX", "0")
        CharacterFrame:Hide()
        C_Timer.After(0.1, function()
            SetCVar("Sound_EnableSFX", sfx)
        end)
    end
end

local function ApplyLiveTrickState()
    if ShouldUseTrick() then
        if not trickActive then
            trickActive = true
            EngageInvisibleShow()
        end
    else
        if trickActive then
            trickActive = false
            DisengageInvisibleShow()
        end
    end
end

-- Hook ShowUIPanel: when user explicitly opens the panel, restore alpha+mouse
-- so they actually see it. We don't disable trickActive — when they close,
-- HideUIPanel hook will re-engage the invisible state.
local function InstallTrickHooks()
    if statTexts.__trickHooked then return end
    statTexts.__trickHooked = true

    hooksecurefunc("ShowUIPanel", function(frame)
        if not trickActive then return end
        if frame == CharacterFrame then
            CharacterFrame:SetAlpha(1)
            CharacterFrame:EnableMouse(true)
        end
    end)

    hooksecurefunc("HideUIPanel", function(frame)
        if not trickActive then return end
        if frame ~= CharacterFrame then return end
        -- HideUIPanel just called Hide on the frame. Re-Show invisibly on
        -- the next tick (out of combat — if in combat, leave it for now;
        -- PLAYER_REGEN_ENABLED will re-engage).
        C_Timer.After(0, function()
            if not trickActive or not CharacterFrame then return end
            if InCombatLockdown() then return end
            EngageInvisibleShow()
        end)
    end)
end

function SUI_StatsFrame:Initialize()
    if initialized then return end
    if not LEM then return end
    if not GetDB() then
        C_Timer.After(1, function() SUI_StatsFrame:Initialize() end)
        return
    end

    CreateHolder()
    LoadPosition()
    ApplyBackground()
    CreateEventFrame()
    RegisterWithLEM()

    -- Hook Blizzard's PaperDollFrame_Set* functions so we cache the formatted
    -- strings whenever Blizzard updates its stat pane. These strings come
    -- from Blizzard's secure context and are safe to display during combat /
    -- groups, where direct stat-API reads return secret values.
    InstallBlizzardHooks()
    InstallTrickHooks()

    -- If the user has opted into live combat stats, engage the trick at login
    -- (out of combat) so Blizzard's stat panel stays "logically" visible and
    -- updates in real time even during combat in groups.
    C_Timer.After(0.5, ApplyLiveTrickState)

    initialized = true

    -- Initial render. Out of combat the numeric fetchers return real values
    -- and the row strings are formatted by us. In combat (without ever having
    -- opened the panel) rows fall back to "—" placeholders.
    self:Refresh()

    -- Re-render whenever the user opens or closes the character pane
    -- (Blizzard runs UpdateStats then in its clean context, refreshing our
    -- string cache via the hooks).
    if CharacterFrame then
        CharacterFrame:HookScript("OnShow",  function() ScheduleRebuild() end)
        CharacterFrame:HookScript("OnHide",  function() ScheduleRebuild() end)
    end
end

_G.SuaviUI_RefreshStatsFrame = function() SUI_StatsFrame:Refresh() end

---------------------------------------------------------------------------
-- DEFERRED START
---------------------------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    C_Timer.After(0.7, function()
        SUI_StatsFrame:Initialize()
    end)
end)
