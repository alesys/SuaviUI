---------------------------------------------------------------------------
-- SuaviUI Bags: options page ("Bags" > "Bags & Bank")
-- Registered from sui_options.lua (GUI:InitializeOptions).
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SUI = SuaviUI

local Opts = {}
ns.BagsOptions = Opts

local PADDING = 15
local FORM_ROW = 30
local DEFER = { deferOnDrag = true }

-- Same scroll container the other option pages use
local function CreateScrollableContent(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 5)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth())
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    content._hasContent = false

    scrollFrame:SetScript("OnSizeChanged", function(_, width)
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

function Opts.Build(parent)
    local GUI = SUI.GUI
    local C = GUI.Colors
    local Bags = ns.Bags
    local Cat = ns.BagsCategories
    if not Bags or not Cat then
        local err = GUI:CreateLabel(parent, "Bags module not loaded. Please /reload.", 12, { 1, 0.3, 0.3, 1 })
        err:SetPoint("TOPLEFT", PADDING, -10)
        return
    end

    GUI:ClearSearchContext()
    local _, content = CreateScrollableContent(parent)
    local db = Bags.GetDB()
    local y = -10

    local function Refresh() if _G.SuaviUI_RefreshBags then _G.SuaviUI_RefreshBags() end end

    local function AddRow(widget)
        widget:SetPoint("TOPLEFT", PADDING, y)
        widget:SetPoint("RIGHT", content, "RIGHT", -PADDING, 0)
        y = y - FORM_ROW
    end

    local function AddHeader(text)
        local h = GUI:CreateSectionHeader(content, text)
        h:SetPoint("TOPLEFT", PADDING, y)
        y = y - h.gap
    end

    local function AddNote(text, height)
        local n = GUI:CreateLabel(content, text, 11, C.textMuted)
        n:SetPoint("TOPLEFT", PADDING, y)
        n:SetPoint("RIGHT", content, "RIGHT", -PADDING, 0)
        n:SetJustifyH("LEFT")
        n:SetWordWrap(true)
        n:SetHeight(height or 28)
        y = y - (height or 28) - 7
    end

    ---------------------------------------------------------------------
    -- General
    ---------------------------------------------------------------------
    AddHeader("Bags & Bank")
    AddNote("Replaces Blizzard's bags and bank with one combined window (backpack, bags and reagent bag) "
        .. "plus a bank window with the Warband bank. Off by default: while it is off, the default bags are untouched.", 40)

    AddRow(GUI:CreateFormCheckbox(content, "Enable Bags & Bank", "enabled", db, function()
        Bags:SetEnabled(db.enabled)
    end))

    ---------------------------------------------------------------------
    -- Layout
    ---------------------------------------------------------------------
    AddHeader("Layout")
    AddRow(GUI:CreateFormDropdown(content, "Bag View", {
        { value = "category", text = "Categories" },
        { value = "all", text = "All items" },
    }, "view", db, Refresh))
    AddRow(GUI:CreateFormSlider(content, "Bag Columns", 6, 24, 1, "columns", db, Refresh, DEFER))
    AddRow(GUI:CreateFormSlider(content, "Bank Columns", 8, 30, 1, "bankColumns", db, Refresh, DEFER))
    AddRow(GUI:CreateFormSlider(content, "Icon Size", 24, 56, 1, "iconSize", db, Refresh, DEFER))
    AddRow(GUI:CreateFormSlider(content, "Icon Spacing", 0, 12, 1, "spacing", db, Refresh, DEFER))
    AddRow(GUI:CreateFormSlider(content, "Window Scale", 0.6, 1.6, 0.05, "scale", db, Refresh, DEFER))

    local reset = GUI:CreateButton(content, "Reset Window Positions", 190, 24, function()
        db.pos, db.bankPos = nil, nil
        local w = Bags.bagWindow
        if w and w:IsShown() then w:LoadPosition() end
        w = Bags.bankWindow
        if w and w:IsShown() then w:LoadPosition() end
    end)
    reset:SetPoint("TOPLEFT", PADDING, y)
    y = y - 34

    ---------------------------------------------------------------------
    -- Item display
    ---------------------------------------------------------------------
    AddHeader("Item Display")
    AddRow(GUI:CreateFormCheckbox(content, "Show Item Level", "showItemLevel", db, Refresh))
    AddRow(GUI:CreateFormCheckbox(content, "Show Junk Marker", "showJunk", db, Refresh))
    AddRow(GUI:CreateFormCheckbox(content, "Show Quest Marker", "showQuest", db, Refresh))
    AddRow(GUI:CreateFormCheckbox(content, "Highlight New Items", "showNew", db, Refresh))
    AddRow(GUI:CreateFormCheckbox(content, "Show Bag Slots Bar", "showBagBar", db, Refresh))
    AddNote("Item level font, outline, color and the icon border settings are shared with the "
        .. "General > Bag Item Level options.", 28)

    ---------------------------------------------------------------------
    -- Categories
    ---------------------------------------------------------------------
    AddHeader("Categories")
    AddNote("An item goes into the first enabled category (top to bottom) that matches it, so the order "
        .. "also decides priority. 'Other' always receives the rest.", 40)

    local ROW_H = 28
    local rows = {}
    local listTop = y

    local function PlaceRows()
        for i, key in ipairs(db.catOrder) do
            local row = rows[key]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", PADDING, listTop - (i - 1) * ROW_H)
            row:SetPoint("RIGHT", content, "RIGHT", -PADDING, 0)
            row.up:SetAlpha(i == 1 and 0.3 or 1)
            row.down:SetAlpha(i == #db.catOrder and 0.3 or 1)
        end
    end

    local function Move(key, dir)
        local order = db.catOrder
        for i, k in ipairs(order) do
            if k == key then
                local j = i + dir
                if j >= 1 and j <= #order then
                    order[i], order[j] = order[j], order[i]
                    PlaceRows()
                    Refresh()
                end
                return
            end
        end
    end

    for _, key in ipairs(db.catOrder) do
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_H)
        local toggle = GUI:CreateFormCheckbox(row, Cat.NAMES[key], key, db.catEnabled, Refresh)
        toggle:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        toggle:SetPoint("RIGHT", row, "RIGHT", -76, 0)
        if Cat.LOCKED[key] and toggle.SetEnabled then
            db.catEnabled[key] = true
            toggle:SetEnabled(false)
        end
        local up = GUI:CreateButton(row, "Up", 34, 22, function() Move(key, -1) end)
        up:SetPoint("RIGHT", row, "RIGHT", -38, 0)
        local down = GUI:CreateButton(row, "Dn", 34, 22, function() Move(key, 1) end)
        down:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.up, row.down = up, down
        rows[key] = row
    end
    PlaceRows()
    y = listTop - #db.catOrder * ROW_H - 8

    local resetCats = GUI:CreateButton(content, "Reset Categories", 150, 24, function()
        db.catOrder = Cat.NormalizeOrder(nil)
        for _, key in ipairs(Cat.DEFAULT_ORDER) do db.catEnabled[key] = true end
        wipe(db.collapsed)
        for _, key in ipairs(db.catOrder) do
            local row = rows[key]
            local t = row and row.GetChildren and select(1, row:GetChildren())
            if t and t.UpdateVisual then t.UpdateVisual(true) end
        end
        PlaceRows()
        Refresh()
    end)
    resetCats:SetPoint("TOPLEFT", PADDING, y)
    y = y - 34

    content:SetHeight(math.abs(y) + 30)
end
