--[[
    SuaviUI Nameplates - options page
    Registered from sui_options.lua (GUI:InitializeOptions) via
    ns.NameplatesOptions.BuildPage. All settings live in
    profile.nameplates (defaults: utils/sui_nameplates.lua).
]]

local ADDON_NAME, ns = ...
local SUI = SuaviUI
local GUI = SUI and SUI.GUI
if not GUI then return end

local C = GUI.Colors
local LSM = LibStub("LibSharedMedia-3.0", true)

local PAD = 15
local FORM_ROW = 30

local function CreateScrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", -28, 5)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(scroll:GetWidth())
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    content._hasContent = false

    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(width)
    end)

    local bar = scroll.ScrollBar
    if bar then
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, -16)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 16)
        local thumb = bar:GetThumbTexture()
        if thumb then thumb:SetColorTexture(0.502, 0.502, 0.518, 0.5) end
        local up = bar.ScrollUpButton or bar.Back
        local down = bar.ScrollDownButton or bar.Forward
        if up then up:Hide(); up:SetAlpha(0) end
        if down then down:Hide(); down:SetAlpha(0) end
    end
    return scroll, content
end

local function GetFontOptions()
    local list = { { value = "", text = "SuaviUI Default" } }
    if LSM then
        local names = {}
        for name in pairs(LSM:HashTable("font")) do
            names[#names + 1] = name
        end
        table.sort(names)
        for _, name in ipairs(names) do
            list[#list + 1] = { value = name, text = name }
        end
    end
    return list
end

local function BuildNameplatesPage(parent)
    local NP = ns.Nameplates
    local db = NP and NP.GetDB and NP.GetDB()
    local scroll, content = CreateScrollArea(parent)
    local y = -15

    if not db then
        local err = GUI:CreateLabel(content, "Nameplates module not loaded. Please /reload.", 12, { 1, 0.3, 0.3, 1 })
        err:SetPoint("TOPLEFT", PAD, y)
        content:SetHeight(60)
        return scroll
    end
    local colors = db.colors

    local function Refresh()
        if NP and NP.Refresh then NP:Refresh() end
    end

    local function Row(widget)
        widget:SetPoint("TOPLEFT", PAD, y)
        widget:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
        y = y - FORM_ROW
        return widget
    end

    local function Header(text)
        local h = GUI:CreateSectionHeader(content, text)
        h:SetPoint("TOPLEFT", PAD, y)
        y = y - h.gap
    end

    local function Note(text, height)
        local label = GUI:CreateLabel(content, text, 11, C.textMuted)
        label:SetPoint("TOPLEFT", PAD, y)
        label:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetHeight(height or 28)
        y = y - (height or 28) - 6
    end

    local function Toggle(label, key)
        return Row(GUI:CreateFormToggle(content, label, key, db, Refresh))
    end

    local function Slider(label, minV, maxV, step, key)
        return Row(GUI:CreateFormSlider(content, label, minV, maxV, step, key, db, Refresh, { deferOnDrag = true }))
    end

    local function Dropdown(label, options, key)
        return Row(GUI:CreateFormDropdown(content, label, options, key, db, Refresh))
    end

    local function RefreshColors()
        if NP and NP.RefreshColors then NP:RefreshColors() end
    end

    local function Color(label, key)
        return Row(GUI:CreateFormColorPicker(content, label, key, colors, RefreshColors))
    end

    -- General -------------------------------------------------------------
    Header("Nameplates")
    Note("Draws SuaviUI health and cast bars on enemy nameplates. Off by default; while off, Blizzard's nameplates are left completely alone. Turning it off again restores them; a /reload removes every hook.", 42)
    Toggle("Enable SuaviUI Nameplates", "enabled")
    Row(GUI:CreateFormDropdownWithTexturePreview(content, "Bar Texture", "texture", db, Refresh))
    Dropdown("Font", GetFontOptions(), "font")

    -- Size ------------------------------------------------------------------
    Header("Size")
    Slider("Width", 60, 260, 1, "width")
    Slider("Health Bar Height", 4, 30, 1, "height")
    Slider("Name Font Size", 6, 20, 1, "nameFontSize")
    Slider("Health Text Font Size", 6, 20, 1, "healthFontSize")

    -- Health ------------------------------------------------------------------
    Header("Health Bar")
    Dropdown("Health Text", {
        { value = "none", text = "None" },
        { value = "percent", text = "Percent" },
    }, "healthText")
    Toggle("Show Name", "showName")
    Toggle("Show Level / Elite / Rare", "showLevel")
    Toggle("Class Colors for Enemy Players", "classColorEnemyPlayers")

    -- Target & focus ----------------------------------------------------------
    Header("Target & Focus")
    Dropdown("Target Highlight", {
        { value = "none", text = "None" },
        { value = "border", text = "Border" },
        { value = "glow", text = "Glow" },
    }, "targetHighlight")
    Slider("Target Scale", 1, 1.5, 0.05, "targetScale")
    Color("Target Color", "target")
    Toggle("Focus Marker", "showFocusMarker")
    Color("Focus Color", "focus")
    Toggle("Raid Target Icon", "showRaidIcon")
    Slider("Raid Icon Size", 10, 32, 1, "raidIconSize")

    -- Threat ------------------------------------------------------------------
    Header("Threat Colors")
    Note("Tanks: holding aggro is good, losing it warns. Damage and healers: having aggro is bad. Your role comes from your current specialization. Out of combat the bar uses the reaction colors below.", 42)
    Toggle("Color by Threat", "threatColoring")
    Color("Tank: Holding Aggro", "tankSecure")
    Color("Tank: Losing / Gaining", "tankLosing")
    Color("Tank: Aggro Lost", "tankLost")
    Color("Tank: Other Tank Has It", "offTank")
    Color("DPS/Healer: Safe", "dpsSafe")
    Color("DPS/Healer: High Threat", "dpsWarn")
    Color("DPS/Healer: Has Aggro", "dpsAggro")

    Header("Reaction Colors")
    Color("Hostile", "hostile")
    Color("Neutral", "neutral")
    Color("Friendly", "friendly")
    Color("Tapped by Others", "tapped")
    Color("Bar Background", "background")

    -- Cast bar ----------------------------------------------------------------
    Header("Cast Bar")
    Toggle("Show Cast Bar", "castBar")
    Slider("Cast Bar Height", 4, 24, 1, "castHeight")
    Slider("Cast Font Size", 6, 20, 1, "castFontSize")
    Toggle("Spell Icon", "castIcon")
    Toggle("Cast Timer", "castTimer")
    Toggle("Tint When My Interrupt Is on Cooldown", "kickTint")
    Color("Interruptible", "castInterruptible")
    Color("Not Interruptible", "castNotInterruptible")
    Color("Interrupt on Cooldown", "castKickCooldown")
    Color("Interrupted", "castInterrupted")

    -- Auras -------------------------------------------------------------------
    Header("Auras")
    Toggle("My Debuffs", "debuffs")
    Slider("Debuff Size", 10, 36, 1, "debuffSize")
    Slider("Max Debuffs", 1, 10, 1, "maxDebuffs")
    Toggle("Important Enemy Buffs", "buffs")
    Dropdown("Buff Filter", {
        { value = "dispellable", text = "Purgeable / Enrage" },
        { value = "important", text = "Blizzard Important" },
        { value = "both", text = "Both" },
    }, "buffFilter")
    Slider("Buff Size", 10, 36, 1, "buffSize")
    Slider("Max Buffs", 1, 6, 1, "maxBuffs")
    Slider("Aura Font Size", 6, 16, 1, "auraFontSize")

    -- Friendly ----------------------------------------------------------------
    Header("Friendly Nameplates")
    Note("Friendly plates inside dungeons and raids are protected by the game and always use Blizzard's style.", 28)
    Dropdown("Friendly Plates", {
        { value = "blizzard", text = "Blizzard Default" },
        { value = "name", text = "Class-Colored Name Only" },
        { value = "hide", text = "Hide" },
    }, "friendlyMode")
    Slider("Friendly Name Font Size", 6, 20, 1, "friendlyFontSize")

    content:SetHeight(math.abs(y) + 20)
    return scroll
end

ns.NameplatesOptions = {
    BuildPage = BuildNameplatesPage,
}
