--[[
    Raid & Party Frames - options pages for the /sui panel.
    Exposes GUI.CreateRaidFrameBuilders(), registered from sui_options.lua.
]]

local ADDON_NAME, ns = ...
local SUI = SuaviUI
local GUI = SUI and SUI.GUI
if not GUI then return end
local C = GUI.Colors

local PAD = 15
local FORM_ROW = 32

local function RF() return ns.SUI_RaidFrames end

local function GetDB()
    local rf = RF()
    return rf and rf:GetDB()
end

local function Refresh()
    local rf = RF()
    if rf then rf:Refresh() end
end

-- Same scroll container the other SuaviUI pages use
local function CreateScrollableContent(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 5)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth())
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    content._hasContent = false
    scrollFrame:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
    end)
    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -16)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 16)
        local thumb = scrollBar:GetThumbTexture()
        if thumb then thumb:SetColorTexture(0.502, 0.502, 0.518, 0.5) end
        local up = scrollBar.ScrollUpButton or scrollBar.Back
        local down = scrollBar.ScrollDownButton or scrollBar.Forward
        if up then up:Hide(); up:SetAlpha(0) end
        if down then down:Hide(); down:SetAlpha(0) end
    end
    return scrollFrame, content
end

local function Wrap(builder)
    return function(parent)
        local _, content = CreateScrollableContent(parent)
        GUI:ClearSearchContext()
        builder(content)
    end
end

-- Small layout helper: places rows top-down
local function Flow(content)
    local f = { y = -10 }
    function f:Row(widget, height)
        widget:SetPoint("TOPLEFT", PAD, self.y)
        widget:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
        self.y = self.y - (height or FORM_ROW)
        return widget
    end
    function f:Header(text)
        local h = GUI:CreateSectionHeader(content, text)
        h:SetPoint("TOPLEFT", PAD, self.y)
        self.y = self.y - (h.gap or 46)
        return h
    end
    function f:Note(text)
        local l = GUI:CreateLabel(content, text, 11, C.textMuted)
        l:SetPoint("TOPLEFT", PAD, self.y)
        l:SetPoint("RIGHT", content, "RIGHT", -PAD, 0)
        l:SetJustifyH("LEFT")
        l:SetWordWrap(true)
        self.y = self.y - 30
        return l
    end
    function f:Check(label, key, tbl, onChange)
        return self:Row(GUI:CreateFormCheckbox(content, label, key, tbl, onChange or Refresh))
    end
    function f:Slider(label, minV, maxV, step, key, tbl)
        return self:Row(GUI:CreateFormSlider(content, label, minV, maxV, step, key, tbl, Refresh))
    end
    function f:Drop(label, options, key, tbl)
        return self:Row(GUI:CreateFormDropdown(content, label, options, key, tbl, Refresh))
    end
    function f:Color(label, key, tbl, noAlpha)
        return self:Row(GUI:CreateFormColorPicker(content, label, key, tbl, Refresh, { noAlpha = noAlpha }))
    end
    function f:Finish()
        content:SetHeight(math.abs(self.y) + 30)
    end
    return f
end

local function NotLoaded(content)
    local l = GUI:CreateLabel(content, "Raid frame settings are not available yet. Please /reload.", 12, C.textMuted)
    l:SetPoint("TOPLEFT", PAD, -10)
    content:SetHeight(60)
end

local GROWTH_OPTIONS = {
    { value = "DOWN", text = "Down" },
    { value = "UP", text = "Up" },
    { value = "RIGHT", text = "Right" },
    { value = "LEFT", text = "Left" },
}

---------------------------------------------------------------------------
-- PAGE: General
---------------------------------------------------------------------------
local function BuildGeneral(content)
    local db = GetDB()
    if not db then NotLoaded(content) return end
    local f = Flow(content)

    f:Header("Raid & Party Frames")
    f:Check("Enable Raid & Party Frames (Req. Reload)", "enabled", db, function() end)
    f:Note("Replaces Blizzard's party and raid frames with SuaviUI frames. Disabled by default. Changing this needs a /reload.")
    f:Check("Hide Blizzard Party/Raid Frames (Req. Reload)", "hideBlizzard", db, function() end)
    f:Note("Blizzard's frames come back after a /reload once this (or the module) is turned off.")

    local reloadBtn = GUI:CreateButton(content, "Reload UI", 140, 26, function() ReloadUI() end)
    reloadBtn:SetPoint("TOPLEFT", PAD, f.y)
    f.y = f.y - 40

    f:Header("Positioning & Preview")
    f:Note("Move the party and raid frames in Blizzard Edit Mode (Suaviframe: Party / Raid). Fake units are shown while Edit Mode is open.")

    local editBtn = GUI:CreateButton(content, "Open Edit Mode", 160, 26, function()
        if _G.ShowUIPanel and _G.EditModeManagerFrame and not _G.EditModeManagerFrame:IsShown() then
            _G.ShowUIPanel(_G.EditModeManagerFrame)
        end
    end)
    editBtn:SetPoint("TOPLEFT", PAD, f.y)

    local previewBtn
    previewBtn = GUI:CreateButton(content, "Toggle Preview", 160, 26, function()
        local rf = RF()
        if not rf or not rf.built then
            print("|cFFFF6AC1SuaviUI|r: Enable Raid & Party Frames and /reload first.")
            return
        end
        local on = rf:TogglePreview()
        print("|cFFFF6AC1SuaviUI|r: Raid frame preview " .. (on and "on" or "off"))
    end)
    previewBtn:SetPoint("LEFT", editBtn, "RIGHT", 10, 0)
    f.y = f.y - 40

    f:Finish()
end

---------------------------------------------------------------------------
-- PAGE: Layout
---------------------------------------------------------------------------
local function BuildLayout(content)
    local db = GetDB()
    if not db then NotLoaded(content) return end
    local f = Flow(content)
    local party, raid = db.party, db.raid

    f:Header("Party")
    f:Check("Enable Party Frames", "enabled", party)
    f:Check("Show Player in Party", "showPlayer", party)
    f:Slider("Width", 40, 300, 1, "width", party)
    f:Slider("Height", 16, 120, 1, "height", party)
    f:Slider("Spacing", 0, 30, 1, "spacing", party)
    f:Drop("Growth Direction", GROWTH_OPTIONS, "growth", party)
    f:Drop("Sort", {
        { value = "INDEX", text = "Group Order" },
        { value = "ROLE", text = "Role (Tank, Healer, DPS)" },
        { value = "NAME", text = "Name" },
    }, "sort", party)

    f:Header("Raid")
    f:Check("Enable Raid Frames", "enabled", raid)
    f:Slider("Width", 30, 250, 1, "width", raid)
    f:Slider("Height", 16, 120, 1, "height", raid)
    f:Slider("Spacing", 0, 30, 1, "spacing", raid)
    f:Drop("Unit Growth", GROWTH_OPTIONS, "growth", raid)
    f:Drop("Group / Column Growth", GROWTH_OPTIONS, "groupGrowth", raid)
    f:Note("Group growth must be perpendicular to unit growth; otherwise the nearest valid direction is used.")
    f:Slider("Group Spacing", 0, 40, 1, "groupSpacing", raid)
    f:Drop("Sort", {
        { value = "GROUP", text = "By Group" },
        { value = "ROLE", text = "By Role (Tank, Healer, DPS)" },
        { value = "NAME", text = "By Name" },
    }, "sort", raid)
    f:Drop("Order Inside Groups", {
        { value = "INDEX", text = "Group Order" },
        { value = "ROLE", text = "Role" },
        { value = "NAME", text = "Name" },
    }, "groupInnerSort", raid)
    f:Slider("Groups per Row (By Group)", 1, 8, 1, "groupsPerLine", raid)
    f:Slider("Units per Column (Role / Name)", 1, 40, 1, "unitsPerColumn", raid)
    f:Slider("Groups Shown", 1, 8, 1, "maxGroups", raid)
    f:Slider("Preview Size", 5, 40, 1, "previewSize", raid)
    f:Note("Layout changes made in combat are applied when combat ends.")

    f:Finish()
end

---------------------------------------------------------------------------
-- PAGE: Appearance
---------------------------------------------------------------------------
local function BuildAppearance(content)
    local db = GetDB()
    if not db then NotLoaded(content) return end
    local f = Flow(content)
    local st = db.style

    f:Header("Health")
    f:Row(GUI:CreateFormDropdownWithTexturePreview(content, "Bar Texture", "texture", st, Refresh))
    f:Check("Follow SuaviUI Dark Mode", "followDarkMode", st)
    f:Check("Class Colored Health", "useClassColor", st)
    f:Color("Health Color (no class color)", "healthColor", st, true)
    f:Color("Background Color", "bgColor", st)
    f:Drop("Health Text", {
        { value = "none", text = "None" },
        { value = "percent", text = "Percent" },
        { value = "deficit", text = "Deficit" },
    }, "healthText", st)
    f:Check("Incoming Heals", "showHealPrediction", st)
    f:Check("Absorb Shields", "showAbsorbs", st)
    f:Check("Heal Absorbs", "showHealAbsorbs", st)
    f:Check("Highlight Current Target", "targetHighlight", st)

    f:Header("Power")
    f:Check("Show Power Bar", "showPower", st)
    f:Check("Healers Only", "powerHealerOnly", st)
    f:Slider("Power Bar Height", 1, 12, 1, "powerHeight", st)

    f:Header("Text")
    f:Slider("Name Font Size", 6, 24, 1, "fontSize", st)
    f:Slider("Health / Status Font Size", 6, 24, 1, "healthFontSize", st)
    f:Slider("Name Length", 0, 24, 1, "nameLength", st)
    f:Check("Class Colored Names", "nameClassColor", st)

    f:Header("Range")
    f:Check("Fade Out of Range", "enabled", st.range)
    f:Slider("Out of Range Alpha", 0.05, 1, 0.05, "alpha", st.range)

    f:Finish()
end

---------------------------------------------------------------------------
-- PAGE: Auras & Indicators
---------------------------------------------------------------------------
local function BuildAuras(content)
    local db = GetDB()
    if not db then NotLoaded(content) return end
    local f = Flow(content)
    local st = db.style

    f:Header("Debuffs")
    f:Check("Show Debuffs", "enabled", st.debuffs)
    f:Check("Raid-Relevant Only (Blizzard filter)", "raidFilter", st.debuffs)
    f:Slider("Max Debuffs", 0, 8, 1, "max", st.debuffs)
    f:Slider("Debuff Size", 8, 40, 1, "size", st.debuffs)
    f:Slider("Boss Debuff Size", 8, 48, 1, "bossSize", st.debuffs)
    f:Note("Bigger boss debuffs may not apply in combat inside instances: the game hides that flag there.")

    f:Header("Dispel Highlight")
    f:Check("Highlight Dispellable Debuffs", "enabled", st.dispel)
    f:Check("Only Debuffs I Can Dispel", "onlyMine", st.dispel)
    f:Check("Colored Border", "border", st.dispel)
    f:Check("Colored Overlay", "overlay", st.dispel)
    f:Slider("Overlay Opacity", 0.05, 1, 0.05, "overlayAlpha", st.dispel)

    f:Header("My Buffs / HoTs")
    f:Check("Show My HoTs", "enabled", st.buffs)
    f:Slider("Max Buffs", 0, 6, 1, "max", st.buffs)
    f:Slider("Buff Size", 6, 30, 1, "size", st.buffs)

    f:Header("Private Auras")
    f:Check("Show Private Auras", "enabled", st.privateAuras)
    f:Slider("Max Private Auras", 1, 4, 1, "max", st.privateAuras)
    f:Slider("Private Aura Size", 10, 40, 1, "size", st.privateAuras)

    f:Header("Indicators")
    local ic = st.icons
    f:Check("Role Icon", "role", ic)
    f:Check("Role Icon for DPS", "roleShowDamager", ic)
    f:Slider("Role Icon Size", 6, 24, 1, "roleSize", ic)
    f:Check("Leader / Assist Icon", "leader", ic)
    f:Check("Raid Target Marker", "marker", ic)
    f:Slider("Marker Size", 6, 32, 1, "markerSize", ic)
    f:Check("Ready Check", "readyCheck", ic)
    f:Check("Incoming Res / Summon", "status", ic)
    f:Slider("Center Icon Size", 8, 40, 1, "centerSize", ic)

    f:Finish()
end

function GUI.CreateRaidFrameBuilders()
    return {
        { name = "General", builder = Wrap(BuildGeneral) },
        { name = "Layout", builder = Wrap(BuildLayout) },
        { name = "Appearance", builder = Wrap(BuildAppearance) },
        { name = "Auras & Indicators", builder = Wrap(BuildAuras) },
    }
end
