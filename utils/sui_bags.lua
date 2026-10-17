---------------------------------------------------------------------------
-- SuaviUI Bags: combined bag window (core)
--
-- One movable window for backpack + bags + reagent bag, with an optional
-- category view. Item buttons are Blizzard's secure ContainerFrameItemButton
-- template, so use / equip / drag / right-click keep working in combat.
--
-- Design rules (see docs/DEVELOPMENT_PRINCIPLES.md and the Midnight notes):
--   * Blizzard's container frames are never modified. When the module is on
--     they are re-parented to a hidden frame and we mirror their open/closed
--     state through hooksecurefunc on the stock open/close/toggle functions.
--   * No field is ever written onto a Blizzard button or its sub-objects; all
--     of our per-button state lives in a weak side table.
--   * Buttons are only created / moved / shown / hidden out of combat. During
--     combat counts, icons, cooldowns and locks keep updating; the arrangement
--     is queued until PLAYER_REGEN_ENABLED.
--   * Refreshes are batched on BAG_UPDATE_DELAYED (one refresh per frame).
--
-- Bank + Warband window: sui_bags_bank.lua. Categories: sui_bags_categories.lua.
-- Options page: sui_bags_options.lua.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SUI = SuaviUI
local Cat = ns.BagsCategories

local Bags = {}
ns.Bags = Bags
_G.SuaviUI_Bags = Bags

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local strlower = string.lower

local WHITE = "Interface\\Buttons\\WHITE8x8"
local BAG_LIST = { 0, 1, 2, 3, 4, 5 }       -- backpack, four bags, reagent bag
local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
local PAD = 8
local TITLE_H = 28
local FOOTER_H = 26
local HEADER_H = 18
local SECTION_GAP = 8
local MIN_WIDTH = 250

---------------------------------------------------------------------------
-- Settings (profile.bags). Defaults are filled lazily so this module does
-- not touch the shared defaults table in suicore_main.lua.
---------------------------------------------------------------------------
local DEFAULTS = {
    enabled      = false,        -- module is opt-in: Blizzard bags stay untouched
    view         = "category",   -- "category" | "all"
    columns      = 10,           -- bag window
    bankColumns  = 14,           -- bank window
    iconSize     = 36,
    spacing      = 4,
    scale        = 1,
    showItemLevel = true,
    showJunk     = true,
    showQuest    = true,
    showNew      = true,
    showBagBar   = false,
}

local function CopyDefaults(db)
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    if type(db.catEnabled) ~= "table" then db.catEnabled = {} end
    if type(db.collapsed) ~= "table" then db.collapsed = {} end
    for _, key in ipairs(Cat.DEFAULT_ORDER) do
        if db.catEnabled[key] == nil then db.catEnabled[key] = true end
    end
    db.catEnabled.other = true
    db.catOrder = Cat.NormalizeOrder(db.catOrder)
end

local fallbackDB = {}
CopyDefaults(fallbackDB)

local function GetDB()
    local core = ns.Addon
    local profile = core and core.db and core.db.profile
    if not profile then return fallbackDB end
    local db = profile.bags
    if type(db) ~= "table" then
        db = {}
        profile.bags = db
    end
    if not db._ok then
        CopyDefaults(db)
        db._ok = true
    end
    return db
end
Bags.GetDB = GetDB

local function GetGeneral()
    local core = ns.Addon
    local profile = core and core.db and core.db.profile
    return profile and profile.general or {}
end

---------------------------------------------------------------------------
-- Style (shares the item level / square-skin options of sui_bag_itemlevel)
---------------------------------------------------------------------------
Bags.styleVersion = 1
local style = {}
Bags.style = style

local function Font()
    if SUI.GetGlobalFont then
        local ok, f = pcall(SUI.GetGlobalFont, SUI)
        if ok and f then return f end
    end
    return STANDARD_TEXT_FONT
end

local function LSMFont(name)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and name then
        local path = LSM:Fetch("font", name, true)
        if path then return path end
    end
    return Font()
end

function Bags:RefreshStyle()
    local g = GetGeneral()
    style.font = Font()
    style.ilvlFont = LSMFont(g.bagItemLevelFont)
    style.ilvlSize = g.bagItemLevelFontSize or 11
    style.ilvlOutline = g.bagItemLevelFontOutline or "OUTLINE"
    style.ilvlQuality = g.bagItemLevelUseQualityColor
    if style.ilvlQuality == nil then style.ilvlQuality = true end
    style.ilvlColor = g.bagItemLevelTextColor or { 1, 1, 1, 1 }
    style.borderSize = g.bagIconBorderThickness or 1
    style.borderQuality = g.bagIconUseQualityBorderColor
    if style.borderQuality == nil then style.borderQuality = true end
    style.borderColor = g.bagIconBorderColor or { 0.25, 0.25, 0.25, 0.8 }
    local r, gg, b = 0.2, 1.0, 0.6
    if SUI.GetSkinColor then r, gg, b = SUI:GetSkinColor() end
    style.accent = { r, gg, b }
    local br, bg, bb, ba = 0.05, 0.05, 0.05, 0.95
    if SUI.GetSkinBgColor then br, bg, bb, ba = SUI:GetSkinBgColor() end
    style.bg = { br, bg, bb, min(ba or 0.95, 0.97) }
    Bags.styleVersion = Bags.styleVersion + 1
end

local function QualityColor(quality)
    if quality and quality >= 1 then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    return nil
end

---------------------------------------------------------------------------
-- Per-button decoration state (weak, never written onto Blizzard objects)
---------------------------------------------------------------------------
local state = setmetatable({}, { __mode = "k" })
Bags.state = state

-- Item data that was not cached yet; refreshed on ITEM_DATA_LOAD_RESULT.
local loadRequested = {}
local function RequestItemData(itemID)
    if not itemID or loadRequested[itemID] then return end
    loadRequested[itemID] = true
    C_Item.RequestLoadItemDataByID(itemID)
end

---------------------------------------------------------------------------
-- Small widget helpers
---------------------------------------------------------------------------
local function ApplyBackdrop(f)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    local bg = style.bg or { 0.05, 0.05, 0.05, 0.95 }
    local a = style.accent or { 0.2, 1, 0.6 }
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    f:SetBackdropBorderColor(a[1], a[2], a[3], 0.9)
end

local function SetFS(fs, size, flags)
    fs:SetFont(style.font or STANDARD_TEXT_FONT, size or 12, flags or "")
end

local function ShowTip(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(text, 1, 1, 1)
    GameTooltip:Show()
end

-- Square button with an icon (title-bar tools)
local function MakeToolButton(parent, texture, tip, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(20, 20)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(texture)
    b.icon = icon
    b:SetScript("OnEnter", function(self)
        local a = style.accent or { 0.2, 1, 0.6 }
        self:SetBackdropBorderColor(a[1], a[2], a[3], 1)
        local t = self.tipText
        if type(t) == "function" then t = t() end
        if t then ShowTip(self, t) end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", onClick)
    b.tipText = tip
    return b
end
Bags.MakeToolButton = MakeToolButton

-- Plain text button (same look)
local function MakeTextButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 60, 20)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    local fs = b:CreateFontString(nil, "OVERLAY")
    SetFS(fs, 11)
    fs:SetPoint("CENTER")
    fs:SetText(text)
    b.text = fs
    b:SetScript("OnEnter", function(self)
        local a = style.accent or { 0.2, 1, 0.6 }
        self:SetBackdropBorderColor(a[1], a[2], a[3], 1)
        local t = self.tipText
        if type(t) == "function" then t = t() end
        if t then ShowTip(self, t) end
    end)
    b:SetScript("OnLeave", function(self)
        if self.selected then
            local a = style.accent or { 0.2, 1, 0.6 }
            self:SetBackdropBorderColor(a[1], a[2], a[3], 1)
        else
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        end
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", onClick)
    function b:SetSelected(sel)
        self.selected = sel and true or false
        if self.selected then
            local a = style.accent or { 0.2, 1, 0.6 }
            self:SetBackdropBorderColor(a[1], a[2], a[3], 1)
            self.text:SetTextColor(a[1], a[2], a[3])
        else
            self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            self.text:SetTextColor(1, 1, 1)
        end
    end
    return b
end
Bags.MakeTextButton = MakeTextButton

---------------------------------------------------------------------------
-- WINDOW
---------------------------------------------------------------------------
local Window = {}
Window.__index = Window
Bags.Window = Window

--[[
opts = {
    name        = global frame name,
    kind        = "bags" | "bank",
    posKey      = key in profile.bags that stores the position,
    title       = function(win) -> string,
    getBagList  = function(win) -> array of container ids,
    getColumns  = function(db) -> number,
    forceFlat   = function(win) -> bool (optional),
    leftClickOnly = bool (bank buttons never use native right click),
    setup       = function(win) (create extra chrome, optional),
    updateChrome= function(win) (refresh extra chrome, optional),
    updateFooter= function(win) (optional, replaces the default footer),
    onShow / onHide = function(win) (optional),
}
]]
function Bags.NewWindow(opts)
    local self = setmetatable({}, Window)
    self.opts = opts
    self.kind = opts.kind
    self.buttons = {}        -- [bag][slot] = ItemButton
    self.bagFrames = {}      -- [bag] = Frame whose ID is the container id
    self.entries = {}        -- ordered slot entries for the current refresh
    self.entryCache = {}     -- [bag * 1000 + slot] = reusable entry table
    self.headerPool = {}
    self.rows = {}           -- extra chrome rows under the search bar
    self.placed = {}
    self.search = ""
    self:BuildFrame()
    if opts.setup then opts.setup(self) end
    return self
end

function Window:Frame() return self.frame end
function Window:IsShown() return self.frame:IsShown() end
function Window:Show() self.frame:Show() end
function Window:Hide() self.frame:Hide() end

-- Container ids shown by this window right now
function Window:GetBagList()
    return self.opts.getBagList(self)
end

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------
function Window:BuildFrame()
    local opts = self.opts
    local f = CreateFrame("Frame", opts.name, UIParent, "BackdropTemplate")
    self.frame = f
    f.suiWindow = self
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetSize(MIN_WIDTH, 200)
    ApplyBackdrop(f)
    f:Hide()

    -- Title bar (drag handle)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    bar:SetHeight(TITLE_H)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        self:SavePosition()
    end)
    self.titleBar = bar

    local title = bar:CreateFontString(nil, "OVERLAY")
    SetFS(title, 13, "OUTLINE")
    title:SetPoint("LEFT", bar, "LEFT", PAD + 2, 0)
    title:SetJustifyH("LEFT")
    self.titleText = title

    local close = MakeToolButton(bar, "Interface\\Buttons\\UI-StopButton", "Close", function()
        self:UserClose()
    end)
    close:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    close.icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    self.lastTool = close

    -- Search + toolbar row
    local toolbar = CreateFrame("Frame", nil, f)
    toolbar:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", PAD, 0)
    toolbar:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -PAD, 0)
    toolbar:SetHeight(22)
    self.toolbar = toolbar

    local sb = CreateFrame("EditBox", nil, toolbar, "BackdropTemplate")
    sb:SetAllPoints(toolbar)
    sb:SetAutoFocus(false)
    sb:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    sb:SetBackdropColor(0.02, 0.02, 0.02, 0.9)
    sb:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    sb:SetFont(style.font or STANDARD_TEXT_FONT, 12, "")
    sb:SetTextInsets(6, 6, 0, 0)
    sb:SetMaxLetters(60)
    local ph = sb:CreateFontString(nil, "OVERLAY")
    SetFS(ph, 12)
    ph:SetPoint("LEFT", sb, "LEFT", 6, 0)
    ph:SetText("Search")
    ph:SetTextColor(0.5, 0.5, 0.5)
    sb:SetScript("OnTextChanged", function(box)
        local txt = box:GetText() or ""
        ph:SetShown(txt == "")
        self.search = strlower(txt)
        self:UpdateVisuals()
    end)
    sb:SetScript("OnEscapePressed", function(box)
        if (box:GetText() or "") ~= "" then box:SetText("") end
        box:ClearFocus()
    end)
    sb:SetScript("OnEditFocusGained", function(box)
        local a = style.accent or { 0.2, 1, 0.6 }
        box:SetBackdropBorderColor(a[1], a[2], a[3], 1)
    end)
    sb:SetScript("OnEditFocusLost", function(box)
        box:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end)
    self.searchBox = sb

    -- Footer
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 4)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 4)
    footer:SetHeight(FOOTER_H - 4)
    self.footer = footer
    local free = footer:CreateFontString(nil, "OVERLAY")
    SetFS(free, 11)
    free:SetPoint("LEFT", footer, "LEFT", 0, 0)
    free:SetJustifyH("LEFT")
    self.freeText = free
    local gold = footer:CreateFontString(nil, "OVERLAY")
    SetFS(gold, 11)
    gold:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
    gold:SetJustifyH("RIGHT")
    self.goldText = gold

    -- Scroll area
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 4)
    scroll:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 4)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(100, 10)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(s, delta)
        local range = s:GetVerticalScrollRange()
        local cur = s:GetVerticalScroll()
        local step = (GetDB().iconSize + GetDB().spacing) * 2
        s:SetVerticalScroll(max(0, min(range, cur - delta * step)))
    end)
    scroll:SetScript("OnVerticalScroll", function() self:UpdateScrollBar() end)
    scroll:SetScript("OnScrollRangeChanged", function() self:UpdateScrollBar() end)
    self.scroll = scroll
    self.content = content

    -- Slim scroll indicator (wheel only)
    local track = f:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(1, 1, 1, 0.05)
    track:SetWidth(3)
    track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 5, 0)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 5, 0)
    local thumb = f:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.3)
    thumb:SetWidth(3)
    self.scrollTrack, self.scrollThumb = track, thumb

    self:RelayoutRows()

    f:SetScript("OnShow", function() self:OnShow() end)
    f:SetScript("OnHide", function() self:OnHide() end)
    -- ESC closes the window
    local special = _G.UISpecialFrames
    if special and opts.name then
        local found
        for _, n in ipairs(special) do if n == opts.name then found = true break end end
        if not found then table.insert(special, opts.name) end
    end
end

-- Adds a tool button to the title bar (right to left)
function Window:AddTitleButton(texture, tip, onClick)
    local b = MakeToolButton(self.titleBar, texture, tip, onClick)
    b:SetPoint("RIGHT", self.lastTool, "LEFT", -4, 0)
    self.lastTool = b
    return b
end

-- Extra rows between the search box and the item grid
function Window:AddRow(frame, height)
    frame:SetParent(self.frame)
    frame.rowHeight = height
    self.rows[#self.rows + 1] = frame
    self:RelayoutRows()
end

function Window:RelayoutRows()
    local prev = self.toolbar
    for _, row in ipairs(self.rows) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
            row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -4)
            row:SetHeight(row.rowHeight)
            prev = row
        end
    end
    self.scroll:ClearAllPoints()
    self.scroll:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
    self.scroll:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -6)
    self.scroll:SetPoint("BOTTOMRIGHT", self.footer, "TOPRIGHT", 0, 4)
    self.scroll:SetPoint("BOTTOMLEFT", self.footer, "TOPLEFT", 0, 4)
    self.lastRow = prev
end

function Window:ChromeHeight()
    local h = TITLE_H + 22 + 6 + 4 + FOOTER_H
    for _, row in ipairs(self.rows) do
        if row:IsShown() then h = h + row.rowHeight + 4 end
    end
    return h
end

---------------------------------------------------------------------------
-- Position / open / close
---------------------------------------------------------------------------
function Window:LoadPosition()
    local f = self.frame
    local p = GetDB()[self.opts.posKey]
    f:ClearAllPoints()
    if type(p) == "table" and p.point then
        f:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
    elseif self.kind == "bank" then
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -120)
    else
        f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -90, 120)
    end
end

function Window:SavePosition()
    local f = self.frame
    local point, _, rel, x, y = f:GetPoint(1)
    if point then
        GetDB()[self.opts.posKey] = { point = point, rel = rel, x = floor(x + 0.5), y = floor(y + 0.5) }
    end
    f:SetUserPlaced(false)
end

function Window:ApplyScale()
    self.frame:SetScale(max(0.5, min(2, GetDB().scale or 1)))
end

function Window:OnShow()
    self:ApplyScale()
    self:LoadPosition()
    self.titleText:SetText(self.opts.title(self))
    PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    if self.opts.onShow then self.opts.onShow(self) end
    self:FullRefresh()
end

function Window:OnHide()
    PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
    self.searchBox:SetText("")
    self.searchBox:ClearFocus()
    GameTooltip:Hide()
    if self.kind == "bags" then
        -- same housekeeping Blizzard does when a container closes
        for _, bag in ipairs(BAG_LIST) do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                C_NewItems.RemoveNewItem(bag, slot)
            end
        end
    end
    if self.opts.onHide then self.opts.onHide(self) end
end

-- Close button: closes ours and keeps Blizzard's open/closed flags in step
function Window:UserClose()
    self.frame:Hide()
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
function Window:GetBagFrame(bag)
    local bf = self.bagFrames[bag]
    if not bf then
        bf = CreateFrame("Frame", nil, self.content)
        bf:SetID(bag)
        bf:SetAllPoints(self.content)
        self.bagFrames[bag] = bf
    end
    return bf
end

local HIDE_KEYS = {
    "IconBorder", "IconOverlay", "IconOverlay2", "IconQuestTexture", "UpgradeIcon",
    "flash", "NewItemTexture", "BattlepayItemTexture", "BagIndicator", "ExtendedSlot",
    "JunkIcon", "searchOverlay", "ProfessionQualityOverlay",
}

local function ClickMode(btn, leftOnly)
    if leftOnly then
        btn:RegisterForClicks("LeftButtonUp")
    else
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
end

function Window:StyleButton(btn, st)
    local d = GetDB()
    local icon = btn.icon or btn.Icon
    local t = max(1, style.borderSize or 1)
    st.styledSize = d.iconSize
    -- Icon: square, cropped, inset by the border thickness
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", t, -t)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -t, t)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    -- Border frame
    st.border:SetBackdrop({ edgeFile = WHITE, edgeSize = t })
    st.styleVer = Bags.styleVersion
    -- Text
    local g = max(8, floor(d.iconSize * 0.3))
    st.count:SetFont(style.font or STANDARD_TEXT_FONT, max(9, min(14, g + 2)), "OUTLINE")
    st.ilvl:SetFont(style.ilvlFont or style.font or STANDARD_TEXT_FONT, style.ilvlSize or 11, style.ilvlOutline or "OUTLINE")
    local junkSize = max(10, floor(d.iconSize * 0.34))
    st.junk:SetSize(junkSize, junkSize)
    st.quest:SetSize(junkSize, junkSize)
end

function Window:SkinButton(btn)
    local st = {}
    state[btn] = st

    -- Silence Blizzard's decoration (methods only; nothing is written onto them)
    local nt = btn:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    for _, key in ipairs(HIDE_KEYS) do
        local r = btn[key]
        if r and r.Hide then r:Hide() end
    end
    if btn.Count then btn.Count:Hide() end
    local ht = btn:GetHighlightTexture()
    if ht then
        ht:SetColorTexture(1, 1, 1, 0.18)
        ht:ClearAllPoints()
        ht:SetAllPoints(btn)
    end
    local pt = btn:GetPushedTexture()
    if pt then
        pt:SetColorTexture(1, 1, 1, 0.1)
        pt:ClearAllPoints()
        pt:SetAllPoints(btn)
    end

    -- Dark slot background
    local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetColorTexture(0.04, 0.04, 0.045, 1)
    bg:SetAllPoints(btn)
    st.bg = bg

    -- Our own overlay frame (above the cooldown swipe)
    local deco = CreateFrame("Frame", nil, btn)
    deco:SetAllPoints(btn)
    deco:SetFrameLevel(btn:GetFrameLevel() + 5)
    deco:EnableMouse(false)
    st.deco = deco

    local border = CreateFrame("Frame", nil, deco, "BackdropTemplate")
    border:SetAllPoints(deco)
    border:EnableMouse(false)
    border:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    st.border = border

    local glow = deco:CreateTexture(nil, "OVERLAY", nil, 1)
    glow:SetAtlas("bags-glow-white")
    glow:SetBlendMode("ADD")
    glow:SetPoint("TOPLEFT", deco, "TOPLEFT", -5, 5)
    glow:SetPoint("BOTTOMRIGHT", deco, "BOTTOMRIGHT", 5, -5)
    glow:Hide()
    st.glow = glow
    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local a1 = ag:CreateAnimation("Alpha")
    a1:SetFromAlpha(1) a1:SetToAlpha(0.25) a1:SetDuration(0.6) a1:SetOrder(1)
    local a2 = ag:CreateAnimation("Alpha")
    a2:SetFromAlpha(0.25) a2:SetToAlpha(1) a2:SetDuration(0.6) a2:SetOrder(2)
    st.glowAnim = ag

    local dim = deco:CreateTexture(nil, "OVERLAY", nil, 2)
    dim:SetColorTexture(0, 0, 0, 0.72)
    dim:SetAllPoints(deco)
    dim:Hide()
    st.dim = dim

    local count = deco:CreateFontString(nil, "OVERLAY")
    count:SetPoint("BOTTOMRIGHT", deco, "BOTTOMRIGHT", -2, 2)
    count:SetJustifyH("RIGHT")
    st.count = count

    local ilvl = deco:CreateFontString(nil, "OVERLAY")
    ilvl:SetPoint("BOTTOMLEFT", deco, "BOTTOMLEFT", 2, 2)
    ilvl:SetJustifyH("LEFT")
    st.ilvl = ilvl

    local junk = deco:CreateTexture(nil, "OVERLAY", nil, 3)
    junk:SetAtlas("bags-junkcoin")
    junk:SetPoint("TOPLEFT", deco, "TOPLEFT", 1, -1)
    junk:Hide()
    st.junk = junk

    local quest = deco:CreateTexture(nil, "OVERLAY", nil, 3)
    quest:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBang")
    quest:SetPoint("TOPRIGHT", deco, "TOPRIGHT", -1, -1)
    quest:Hide()
    st.quest = quest

    if btn.Cooldown then
        btn.Cooldown:SetFrameLevel(btn:GetFrameLevel() + 2)
        btn.Cooldown:SetDrawEdge(false)
    end

    -- Entering an item clears its "new" glow right away (Blizzard clears the
    -- flag itself in its own OnEnter)
    btn:HookScript("OnEnter", function(self)
        local s = state[self]
        if s and s.glow then s.glow:Hide(); s.glowAnim:Stop() end
    end)
    -- Right-click routing while a bank window is up (see sui_bags_bank.lua)
    btn:HookScript("OnMouseUp", function(self, mouseButton)
        if Bags.OnItemMouseUp then Bags.OnItemMouseUp(self, mouseButton) end
    end)

    self:StyleButton(btn, st)
    return st
end

-- Creates (out of combat only) or returns the button for a container slot
function Window:GetButton(bag, slot, create)
    local row = self.buttons[bag]
    if not row then
        row = {}
        self.buttons[bag] = row
    end
    local btn = row[slot]
    if btn or not create then return btn end
    if InCombatLockdown() then
        self.needsRebuild = true
        return nil
    end
    btn = CreateFrame("ItemButton", nil, self:GetBagFrame(bag), "ContainerFrameItemButtonTemplate")
    btn:SetID(slot)
    btn:RegisterForDrag("LeftButton")
    ClickMode(btn, self.opts.leftClickOnly or Bags.bankMode and self.kind == "bags")
    self:SkinButton(btn)
    row[slot] = btn
    return btn
end

function Window:SetLeftClickOnly(on)
    for _, row in pairs(self.buttons) do
        for _, btn in pairs(row) do
            ClickMode(btn, on)
        end
    end
end

-- Create buttons for the current bag sizes a few at a time (out of combat),
-- so the first open and combat looting never need to create secure frames.
function Window:Prewarm()
    if self.prewarming then return end
    self.prewarming = true
    local list = {}
    for _, bag in ipairs(self:GetBagList()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            if not (self.buttons[bag] and self.buttons[bag][slot]) then
                list[#list + 1] = { bag, slot }
            end
        end
    end
    local i = 1
    local function step()
        if InCombatLockdown() or not Bags.active then
            self.prewarming = false
            return
        end
        local stop = min(i + 15, #list)
        while i <= stop do
            self:GetButton(list[i][1], list[i][2], true)
            i = i + 1
        end
        if i <= #list then
            C_Timer.After(0, step)
        else
            self.prewarming = false
        end
    end
    step()
end

---------------------------------------------------------------------------
-- Entries (one per container slot; tables are reused between refreshes)
---------------------------------------------------------------------------
function Window:GetEntry(bag, slot)
    local key = bag * 1000 + slot
    local e = self.entryCache[key]
    if not e then
        e = { bag = bag, slot = slot }
        self.entryCache[key] = e
    end
    return e
end

function Window:BuildEntries()
    local db = GetDB()
    local flat = self:IsFlat()
    local entries = self.entries
    wipe(entries)
    local n = 0
    for _, bag in ipairs(self:GetBagList()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local e = self:GetEntry(bag, slot)
            local info = C_Container.GetContainerItemInfo(bag, slot)
            e.info = info
            n = n + 1
            entries[n] = e
            if info and info.itemID then
                local inst = Cat.GetInstant(info.itemID)
                e.itemID = info.itemID
                e.quality = info.quality or 0
                e.count = info.stackCount or 1
                e.link = info.hyperlink
                e.classID = inst and inst.classID or nil
                e.sortName = info.itemName and strlower(info.itemName) or ""
                local qi = C_Container.GetContainerItemQuestInfo(bag, slot)
                e.isQuest = qi and (qi.isQuestItem or qi.questID ~= nil) or false
                e.questStart = qi and qi.questID ~= nil and not qi.isActive or false
                e.isNew = db.showNew and C_NewItems.IsNewItem(bag, slot) or false
                if inst and Cat.IsGearClass(inst.classID) then
                    local lvl = Cat.GetItemLevel(info.hyperlink, inst.classID)
                    if not lvl then RequestItemData(info.itemID) end
                    e.ilvl = lvl
                else
                    e.ilvl = nil
                end
                if flat then
                    e.inSet = false
                    e.isReagent = nil
                else
                    if db.catEnabled.sets ~= false then
                        e.inSet = (C_Container.GetContainerItemEquipmentSetInfo(bag, slot)) and true or false
                    else
                        e.inSet = false
                    end
                    if db.catEnabled.reagents ~= false and bag ~= REAGENT_BAG then
                        e.isReagent = Cat.GetIsReagent(info.itemID)
                        if e.isReagent == nil then RequestItemData(info.itemID) end
                    else
                        e.isReagent = nil
                    end
                end
            else
                e.itemID, e.quality, e.count, e.link = nil, nil, nil, nil
                e.classID, e.ilvl, e.isQuest, e.questStart = nil, nil, nil, nil
                e.isNew, e.inSet, e.isReagent, e.sortName = nil, nil, nil, nil
            end
        end
    end
    return entries
end

function Window:IsFlat()
    if self.opts.forceFlat and self.opts.forceFlat(self) then return true end
    return GetDB().view == "all"
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
-- Pure computation: returns a description of where everything goes.
function Window:BuildLayout()
    local db = GetDB()
    local cols = max(1, floor(self.opts.getColumns(db)))
    local size, sp = db.iconSize, db.spacing
    local step = size + sp
    local L = {
        cols = cols, size = size, step = step,
        itemE = {}, itemX = {}, itemY = {},
        headers = {},
        width = cols * step - sp,
        height = 0,
    }
    local entries = self.entries
    local n = 0
    local function put(e, col, y)
        n = n + 1
        L.itemE[n] = e
        L.itemX[n] = col * step
        L.itemY[n] = y
    end

    if self:IsFlat() then
        for i, e in ipairs(entries) do
            put(e, (i - 1) % cols, floor((i - 1) / cols) * step)
        end
        L.height = max(0, ceil(#entries / cols) * step - sp)
        return L
    end

    -- Category view
    local order, enabled = db.catOrder, db.catEnabled
    local sections, byKey = {}, {}
    for _, key in ipairs(order) do
        if key == "other" or enabled[key] ~= false then
            local s = { key = key, name = Cat.NAMES[key], list = {} }
            sections[#sections + 1] = s
            byKey[key] = s
        end
    end
    local free, freeCount = {}, 0
    local freeSeen = {}
    for _, e in ipairs(entries) do
        if e.info then
            local key = Cat.Classify(e, order, enabled)
            local s = byKey[key] or byKey.other
            s.list[#s.list + 1] = e
        else
            freeCount = freeCount + 1
            local group = (e.bag == REAGENT_BAG) and 2 or 1
            if not freeSeen[group] then
                freeSeen[group] = true
                free[#free + 1] = e
            end
        end
    end
    if #free > 0 then
        sections[#sections + 1] = { key = "free", name = "Free Slots", list = free, count = freeCount, noSort = true }
    end

    local y = 0
    local hn = 0
    for _, s in ipairs(sections) do
        local count = #s.list
        if count > 0 then
            if not s.noSort then table.sort(s.list, Cat.Compare) end
            local collapsed = db.collapsed[s.key] and true or false
            hn = hn + 1
            L.headers[hn] = {
                key = s.key, name = s.name, count = s.count or count,
                collapsed = collapsed, y = y,
            }
            y = y + HEADER_H + 2
            if not collapsed then
                for i, e in ipairs(s.list) do
                    put(e, (i - 1) % cols, y + floor((i - 1) / cols) * step)
                end
                y = y + ceil(count / cols) * step
            end
            y = y + SECTION_GAP
        end
    end
    L.height = max(0, y - SECTION_GAP)
    return L
end

function Window:GetHeader(i)
    local h = self.headerPool[i]
    if h then return h end
    h = CreateFrame("Button", nil, self.content)
    h:SetHeight(HEADER_H)
    local tex = h:CreateTexture(nil, "BACKGROUND")
    tex:SetColorTexture(1, 1, 1, 0.05)
    tex:SetAllPoints(h)
    h.bg = tex
    local arrow = h:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(12, 12)
    arrow:SetPoint("LEFT", h, "LEFT", 3, 0)
    h.arrow = arrow
    local fs = h:CreateFontString(nil, "OVERLAY")
    SetFS(fs, 11, "OUTLINE")
    fs:SetPoint("LEFT", arrow, "RIGHT", 4, 0)
    h.label = fs
    h:SetScript("OnEnter", function(b) b.bg:SetColorTexture(1, 1, 1, 0.12) end)
    h:SetScript("OnLeave", function(b) b.bg:SetColorTexture(1, 1, 1, 0.05) end)
    h:SetScript("OnClick", function(b)
        local d = GetDB()
        if b.key then
            d.collapsed[b.key] = not d.collapsed[b.key]
        end
        self:RequestRefresh()
    end)
    self.headerPool[i] = h
    return h
end

function Window:ApplyLayout(L)
    local content = self.content
    local placed = self.placed
    wipe(placed)
    local size = L.size
    for i = 1, #L.itemE do
        local e = L.itemE[i]
        local btn = self:GetButton(e.bag, e.slot, true)
        if btn then
            local st = state[btn]
            local x, y = L.itemX[i], L.itemY[i]
            if st.styledSize ~= size or st.styleVer ~= Bags.styleVersion then
                btn:SetSize(size, size)
                self:StyleButton(btn, st)
                st.px = nil
            end
            if st.px ~= x or st.py ~= y then
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
                st.px, st.py = x, y
            end
            if not btn:IsShown() then btn:Show() end
            placed[btn] = true
        end
    end
    for _, row in pairs(self.buttons) do
        for _, btn in pairs(row) do
            if not placed[btn] and btn:IsShown() then btn:Hide() end
        end
    end

    -- headers
    local nh = #L.headers
    for i = 1, nh do
        local info = L.headers[i]
        local h = self:GetHeader(i)
        h.key = info.key
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -info.y)
        h:SetWidth(max(L.width, 80))
        h.arrow:SetTexture(info.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        h.label:SetText(("%s |cff888888(%d)|r"):format(info.name, info.count))
        local a = style.accent or { 0.2, 1, 0.6 }
        h.label:SetTextColor(a[1], a[2], a[3])
        h:Show()
    end
    for i = nh + 1, #self.headerPool do
        self.headerPool[i]:Hide()
    end
end

function Window:ApplySize(L)
    local f = self.frame
    local gridW = L.width
    local width = max(MIN_WIDTH, gridW + PAD * 2)
    self.content:SetWidth(max(gridW, 10))
    self.content:SetHeight(max(L.height, 10))
    local maxH = (UIParent:GetHeight() * 0.88) / f:GetScale()
    local chrome = self:ChromeHeight()
    local height = min(L.height + chrome + 4, maxH)
    height = max(height, chrome + 40)
    f:SetSize(width, height)
    local range = self.scroll:GetVerticalScrollRange()
    if self.scroll:GetVerticalScroll() > range then
        self.scroll:SetVerticalScroll(range)
    end
end

function Window:UpdateScrollBar()
    local scroll = self.scroll
    local range = scroll:GetVerticalScrollRange()
    local thumb = self.scrollThumb
    if range <= 1 then
        thumb:Hide()
        self.scrollTrack:Hide()
        return
    end
    self.scrollTrack:Show()
    local viewH = scroll:GetHeight()
    local total = viewH + range
    local th = max(16, viewH * viewH / total)
    local pos = scroll:GetVerticalScroll() / range
    thumb:ClearAllPoints()
    thumb:SetHeight(th)
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 5, -pos * (viewH - th))
    thumb:Show()
end

---------------------------------------------------------------------------
-- Visuals
---------------------------------------------------------------------------
local function ParseMatch(self, e)
    local q = self.search
    if q == "" then return true end
    local info = e.info
    if not info then return false end
    local hay = e.sortName or ""
    local inst = Cat.GetInstant(e.itemID)
    if inst then hay = hay .. " " .. strlower(inst.itemType) .. " " .. strlower(inst.itemSub) end
    return hay:find(q, 1, true) ~= nil
end

function Window:UpdateButton(btn, e)
    local st = state[btn]
    if not st then return end
    if st.styleVer ~= Bags.styleVersion then self:StyleButton(btn, st) end
    local db = GetDB()
    local icon = btn.icon or btn.Icon
    local info = e.info
    local border = st.border
    local bc = style.borderColor or { 0.25, 0.25, 0.25, 0.8 }

    if not info then
        if icon then icon:Hide() end
        st.count:Hide(); st.ilvl:Hide(); st.junk:Hide(); st.quest:Hide()
        st.glow:Hide(); st.glowAnim:Stop()
        st.dim:SetShown(self.search ~= "")
        border:SetBackdropBorderColor(bc[1], bc[2], bc[3], 0.5)
        if btn.Cooldown then btn.Cooldown:Clear() end
        return
    end

    if icon then
        icon:SetTexture(info.iconFileID)
        icon:SetDesaturated(info.isLocked and true or false)
        icon:Show()
    end

    local count = info.stackCount or 1
    if count > 1 then
        st.count:SetText(count >= 10000 and (floor(count / 1000) .. "k") or count)
        st.count:Show()
    else
        st.count:Hide()
    end

    -- Border colour: quest > quality > default
    local r, g, b
    if db.showQuest and e.isQuest then
        r, g, b = 1, 0.82, 0
    elseif style.borderQuality then
        if e.quality == 0 then
            r, g, b = 0.55, 0.55, 0.55
        elseif e.quality and e.quality >= 2 then
            r, g, b = QualityColor(e.quality)
        end
    end
    if r then
        border:SetBackdropBorderColor(r, g, b, 1)
    else
        border:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 0.8)
    end

    -- Item level (gear only)
    if db.showItemLevel and e.ilvl then
        local ir, ig, ib = 1, 1, 1
        if style.ilvlQuality then
            ir, ig, ib = QualityColor(e.quality)
            if not ir then ir, ig, ib = 1, 1, 1 end
        else
            local c = style.ilvlColor
            ir, ig, ib = c[1], c[2], c[3]
        end
        st.ilvl:SetText(e.ilvl)
        st.ilvl:SetTextColor(ir, ig, ib)
        st.ilvl:Show()
    else
        st.ilvl:Hide()
    end

    -- Junk / quest markers
    st.junk:SetShown(db.showJunk and e.quality == 0 and not info.hasNoValue)
    st.quest:SetShown(db.showQuest and e.questStart)

    -- New item glow
    if db.showNew and e.isNew then
        local gr, gg, gb = QualityColor(e.quality)
        st.glow:SetVertexColor(gr or 1, gg or 1, gb or 1)
        st.glow:Show()
        if not st.glowAnim:IsPlaying() then st.glowAnim:Play() end
    else
        st.glow:Hide()
        st.glowAnim:Stop()
    end

    -- Search dimming
    st.dim:SetShown(not ParseMatch(self, e))

    -- Cooldown
    self:UpdateButtonCooldown(btn, e.bag, e.slot)
end

function Window:UpdateButtonCooldown(btn, bag, slot)
    local cd = btn.Cooldown
    if not cd then return end
    local start, duration = C_Container.GetContainerItemCooldown(bag, slot)
    local secret = issecretvalue and (issecretvalue(start) or issecretvalue(duration))
    if secret or (start and duration and duration > 0) then
        cd:SetCooldown(start, duration)
    else
        cd:Clear()
    end
end

-- Update every visible slot button from the current entries
function Window:UpdateVisuals()
    if not self.frame:IsShown() then return end
    for _, e in ipairs(self.entries) do
        local row = self.buttons[e.bag]
        local btn = row and row[e.slot]
        if btn and btn:IsShown() then
            self:UpdateButton(btn, e)
        end
    end
end

function Window:UpdateCooldowns()
    if not self.frame:IsShown() then return end
    for _, e in ipairs(self.entries) do
        if e.info then
            local row = self.buttons[e.bag]
            local btn = row and row[e.slot]
            if btn and btn:IsShown() then
                self:UpdateButtonCooldown(btn, e.bag, e.slot)
            end
        end
    end
end

-- A single slot changed lock state: cheap in-place update
function Window:UpdateSlotLock(bag, slot)
    local row = self.buttons[bag]
    local btn = row and row[slot]
    if not (btn and btn:IsShown()) then return end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local icon = btn.icon or btn.Icon
    if icon then icon:SetDesaturated(info and info.isLocked and true or false) end
end

---------------------------------------------------------------------------
-- Footer
---------------------------------------------------------------------------
function Window:UpdateFooter()
    if self.opts.updateFooter then
        self.opts.updateFooter(self)
        return
    end
    local gFree, gTotal, rFree, rTotal = 0, 0, 0, 0
    for _, bag in ipairs(BAG_LIST) do
        local total = C_Container.GetContainerNumSlots(bag)
        if total > 0 then
            local free = C_Container.GetContainerNumFreeSlots(bag)
            if bag == REAGENT_BAG then
                rFree, rTotal = rFree + free, rTotal + total
            else
                gFree, gTotal = gFree + free, gTotal + total
            end
        end
    end
    local txt = ("Free: %d/%d"):format(gFree, gTotal)
    if rTotal > 0 then txt = txt .. ("  |cff888888Reagent %d/%d|r"):format(rFree, rTotal) end
    self.freeText:SetText(txt)
    self.goldText:SetText(C_CurrencyInfo.GetCoinTextureString(GetMoney() or 0))
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
function Window:FullRefresh()
    if not self.frame:IsShown() then
        self.dirty = true
        return
    end
    self.dirty = false
    self:ApplyScale()
    self.titleText:SetText(self.opts.title(self))
    if self.opts.updateChrome then
        self.opts.updateChrome(self)
        self:RelayoutRows()
    end
    self:BuildEntries()
    local L = self:BuildLayout()
    self.layout = L
    if InCombatLockdown() then
        -- Buttons are not touched in combat; the arrangement is applied on
        -- PLAYER_REGEN_ENABLED. Counts / icons / locks still update below.
        self.pendingLayout = true
    else
        self.pendingLayout = false
        self:ApplyLayout(L)
        self:ApplySize(L)
    end
    self:UpdateVisuals()
    self:UpdateFooter()
    self:UpdateScrollBar()
end

-- Coalesce bursts (BAG_UPDATE_DELAYED, item data loads, option changes)
function Window:RequestRefresh()
    if self.refreshQueued then return end
    self.refreshQueued = true
    C_Timer.After(0, function()
        self.refreshQueued = false
        self:FullRefresh()
    end)
end

---------------------------------------------------------------------------
-- Bag slot bar (equip / swap bags)
---------------------------------------------------------------------------
function Window:BuildBagBar()
    local row = CreateFrame("Frame", nil, self.frame)
    row:Hide()
    self.bagBar = row
    row.buttons = {}
    local prev
    for i, bag in ipairs({ 1, 2, 3, 4, REAGENT_BAG }) do
        local invID = C_Container.ContainerIDToInventoryID(bag)
        local b = CreateFrame("Button", nil, row, "BackdropTemplate")
        b:SetSize(26, 26)
        b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        b:SetBackdropColor(0.04, 0.04, 0.045, 1)
        b:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        b:RegisterForClicks("LeftButtonUp")
        b:RegisterForDrag("LeftButton")
        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 1, -1)
        tex:SetPoint("BOTTOMRIGHT", -1, 1)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.tex = tex
        b.invID = invID
        b.bag = bag
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", row, "LEFT", 0, 0) end
        prev = b
        local function Interact()
            if InCombatLockdown() then return end
            if CursorHasItem() then
                PutItemInBag(b.invID)
            else
                PickupBagFromSlot(b.invID)
            end
        end
        b:SetScript("OnClick", Interact)
        b:SetScript("OnDragStart", function() if not InCombatLockdown() then PickupBagFromSlot(b.invID) end end)
        b:SetScript("OnReceiveDrag", function() if not InCombatLockdown() then PutItemInBag(b.invID) end end)
        b:SetScript("OnEnter", function(self2)
            GameTooltip:SetOwner(self2, "ANCHOR_TOP")
            if not GameTooltip:SetInventoryItem("player", self2.invID) then
                GameTooltip:SetText(bag == REAGENT_BAG and EQUIP_CONTAINER_REAGENT or EQUIP_CONTAINER)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.buttons[i] = b
    end
    self:AddRow(row, 26)
end

function Window:UpdateBagBar()
    local row = self.bagBar
    if not row or not row:IsShown() then return end
    for _, b in ipairs(row.buttons) do
        local tex = GetInventoryItemTexture("player", b.invID)
        if tex then
            b.tex:SetTexture(tex)
            b.tex:SetVertexColor(1, 1, 1)
        else
            b.tex:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
            b.tex:SetVertexColor(0.5, 0.5, 0.5)
        end
    end
end

function Window:SetBagBarShown(show)
    if not self.bagBar then
        if not show then return end
        self:BuildBagBar()
    end
    self.bagBar:SetShown(show)
    self:RelayoutRows()
    self:UpdateBagBar()
    if self.frame:IsShown() then self:FullRefresh() end
end

---------------------------------------------------------------------------
-- BAG WINDOW
---------------------------------------------------------------------------
local bagWindow

local function SellJunkNow()
    if InCombatLockdown() then return end
    if _G.SuaviUI_SellJunk then
        _G.SuaviUI_SellJunk()
    end
end

local function CreateBagWindow()
    bagWindow = Bags.NewWindow({
        name = "SuaviUI_BagFrame",
        kind = "bags",
        posKey = "pos",
        title = function() return (UnitName("player") or "Bags") .. "'s Bags" end,
        getBagList = function() return BAG_LIST end,
        getColumns = function(db) return db.columns end,
        setup = function(win)
            win.sortBtn = win:AddTitleButton("Interface\\Icons\\INV_Pet_Broom", "Sort bags", function()
                if InCombatLockdown() then return end
                PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
                C_Container.SortBags()
            end)
            win.bagBarBtn = win:AddTitleButton("Interface\\Buttons\\Button-Backpack-Up", "Toggle bag slots", function()
                local d = GetDB()
                d.showBagBar = not d.showBagBar
                win:SetBagBarShown(d.showBagBar)
            end)
            win.sellBtn = win:AddTitleButton("Interface\\Icons\\INV_Misc_Coin_01", "Sell junk", function()
                SellJunkNow()
            end)
            win.sellBtn:Hide()
            if GetDB().showBagBar then win:SetBagBarShown(true) end
        end,
        updateChrome = function(win)
            local d = GetDB()
            if d.showBagBar and not win.bagBar then win:BuildBagBar() end
            if win.bagBar then win.bagBar:SetShown(d.showBagBar) end
            win:UpdateBagBar()
            local atMerchant = MerchantFrame and MerchantFrame:IsShown()
            win.sellBtn:SetShown(atMerchant and true or false)
        end,
        onShow = function(win)
            win:Prewarm()
        end,
    })
    Bags.bagWindow = bagWindow
end

---------------------------------------------------------------------------
-- Blizzard integration (hide stock frames, mirror open/close state)
---------------------------------------------------------------------------
local hiddenParent
local origParent = {}

local function BlizzardFrames()
    local list = {}
    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f then list[#list + 1] = f end
    end
    if _G.ContainerFrameCombinedBags then list[#list + 1] = _G.ContainerFrameCombinedBags end
    return list
end

local function HideBlizzardBags()
    hiddenParent = hiddenParent or CreateFrame("Frame")
    hiddenParent:Hide()
    for _, f in ipairs(BlizzardFrames()) do
        if not origParent[f] then origParent[f] = f:GetParent() end
        f:SetParent(hiddenParent)
    end
end

local function RestoreBlizzardBags()
    for f, parent in pairs(origParent) do
        f:SetParent(parent or UIParent)
    end
    wipe(origParent)
end

-- Frames under a hidden parent never run OnShow/OnHide, so closing them here
-- only flips their shown flag (keeps IsAnyBagOpen() truthful for the B key).
local function ForceCloseBlizzardFlags()
    for _, f in ipairs(BlizzardFrames()) do
        -- IsVisible() would be true only for a frame that is NOT under our
        -- hidden parent; those are left alone (their OnHide would really run).
        if f:IsShown() and not f:IsVisible() then f:Hide() end
    end
end
Bags.ForceCloseBlizzardFlags = ForceCloseBlizzardFlags

local function SyncOpenState()
    if not Bags.active or not bagWindow then return end
    local want = IsAnyBagOpen and IsAnyBagOpen() or false
    if want then
        if not bagWindow:IsShown() then bagWindow:Show() end
    elseif bagWindow:IsShown() then
        bagWindow:Hide()
    end
end

local hooksInstalled = false
local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    local names = {
        "ToggleAllBags", "ToggleBackpack", "ToggleBag",
        "OpenAllBags", "OpenBag", "OpenBackpack",
        "CloseAllBags", "CloseBag", "CloseBackpack",
    }
    for _, name in ipairs(names) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, SyncOpenState)
        end
    end
end

-- Closing our window by hand also closes Blizzard's flags (done in OnHide of
-- the bag window so ESC, the X button and keybinds behave the same).
local function HookBagWindowHide()
    bagWindow.frame:HookScript("OnHide", function()
        if Bags.active then ForceCloseBlizzardFlags() end
    end)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}
Bags.handlers = handlers

local ACTIVE_EVENTS = {
    "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED",
    "BAG_NEW_ITEMS_UPDATED", "PLAYER_MONEY", "ITEM_DATA_LOAD_RESULT",
    "EQUIPMENT_SETS_CHANGED", "BAG_SLOT_FLAGS_UPDATED", "UNIT_INVENTORY_CHANGED",
    "MERCHANT_SHOW", "MERCHANT_CLOSED",
    -- bank (handled in sui_bags_bank.lua)
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BANK_TABS_CHANGED",
    "BANK_TAB_SETTINGS_UPDATED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED",
    "PLAYERBANKSLOTS_CHANGED", "ACCOUNT_MONEY",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
}

local function EachWindow(fn, ...)
    if bagWindow then fn(bagWindow, ...) end
    if Bags.bankWindow then fn(Bags.bankWindow, ...) end
end

handlers.BAG_UPDATE_DELAYED = function()
    EachWindow(function(w) if w:IsShown() then w:RequestRefresh() else w.dirty = true end end)
    if bagWindow then
        bagWindow:UpdateBagBar()
        -- a bigger bag may have been equipped: make sure its buttons exist
        if not InCombatLockdown() then bagWindow:Prewarm() end
    end
end
handlers.UNIT_INVENTORY_CHANGED = function(unit)
    if unit == "player" then handlers.BAG_UPDATE_DELAYED() end
end
handlers.EQUIPMENT_SETS_CHANGED = handlers.BAG_UPDATE_DELAYED
handlers.BAG_SLOT_FLAGS_UPDATED = handlers.BAG_UPDATE_DELAYED
handlers.BAG_NEW_ITEMS_UPDATED = function()
    EachWindow(function(w) w:UpdateVisuals() end)
end

local cooldownQueued = false
handlers.BAG_UPDATE_COOLDOWN = function()
    if cooldownQueued then return end
    cooldownQueued = true
    C_Timer.After(0.1, function()
        cooldownQueued = false
        EachWindow(function(w) w:UpdateCooldowns() end)
    end)
end

handlers.ITEM_LOCK_CHANGED = function(bag, slot)
    if not bag or not slot then return end
    EachWindow(function(w) w:UpdateSlotLock(bag, slot) end)
end

handlers.PLAYER_MONEY = function()
    EachWindow(function(w) if w:IsShown() then w:UpdateFooter() end end)
end

handlers.ITEM_DATA_LOAD_RESULT = function(itemID)
    if itemID and loadRequested[itemID] then
        EachWindow(function(w) if w:IsShown() then w:RequestRefresh() end end)
    end
end

local function UpdateSellButton()
    if not bagWindow then return end
    local atMerchant = MerchantFrame and MerchantFrame:IsShown()
    bagWindow.sellBtn:SetShown(atMerchant and true or false)
end
handlers.MERCHANT_SHOW = function() C_Timer.After(0, UpdateSellButton) end
handlers.MERCHANT_CLOSED = function() C_Timer.After(0, UpdateSellButton) end

handlers.PLAYER_REGEN_ENABLED = function()
    if Bags.pendingEnable then Bags.pendingEnable = false; Bags:Enable() end
    if Bags.pendingDisable then Bags.pendingDisable = false; Bags:Disable() end
    if not Bags.active then return end
    EachWindow(function(w)
        if w.pendingLayout or w.needsRebuild then
            w.needsRebuild = false
            w:RequestRefresh()
        end
    end)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local h = handlers[event]
    if h then h(...) end
end)

local function RegisterActiveEvents(on)
    for _, ev in ipairs(ACTIVE_EVENTS) do
        if on then
            if ev == "UNIT_INVENTORY_CHANGED" then
                pcall(eventFrame.RegisterUnitEvent, eventFrame, ev, "player")
            else
                pcall(eventFrame.RegisterEvent, eventFrame, ev)
            end
        else
            pcall(eventFrame.UnregisterEvent, eventFrame, ev)
        end
    end
end

---------------------------------------------------------------------------
-- Enable / disable
---------------------------------------------------------------------------
-- Tutorial popups would anchor to the hidden stock frames
local TUTORIAL_FLAGS = {
    "LE_FRAME_TUTORIAL_HUD_REVAMP_BAG_CHANGES", "LE_FRAME_TUTORIAL_BAG_SLOTS_AUTHENTICATOR",
    "LE_FRAME_TUTORIAL_MOUNT_EQUIPMENT_SLOT_FRAME", "LE_FRAME_TUTORIAL_UPGRADEABLE_ITEM_IN_SLOT",
    "LE_FRAME_TUTORIAL_EQUIP_REAGENT_BAG",
}
local function CloseTutorials()
    for _, name in ipairs(TUTORIAL_FLAGS) do
        local flag = _G[name]
        if flag then pcall(SetCVarBitfield, "closedInfoFrames", flag, true) end
    end
end

function Bags:Enable()
    if self.active then return end
    if InCombatLockdown() then
        self.pendingEnable = true
        return
    end
    self:RefreshStyle()
    self.active = true
    if not bagWindow then
        CreateBagWindow()
        HookBagWindowHide()
    end
    if self.CreateBankWindow then self:CreateBankWindow() end
    HideBlizzardBags()
    if self.HideBlizzardBank then self:HideBlizzardBank() end
    InstallHooks()
    RegisterActiveEvents(true)
    CloseTutorials()
    bagWindow:Prewarm()
    -- Mirror anything Blizzard already has open
    SyncOpenState()
end

function Bags:Disable()
    if not self.active then return end
    if InCombatLockdown() then
        self.pendingDisable = true
        return
    end
    self.active = false
    RegisterActiveEvents(false)
    if bagWindow then bagWindow:Hide() end
    if self.bankWindow then self.bankWindow:Hide() end
    RestoreBlizzardBags()
    if self.RestoreBlizzardBank then self:RestoreBlizzardBank() end
end

function Bags:SetEnabled(on)
    local db = GetDB()
    db.enabled = on and true or false
    if on then self:Enable() else self:Disable() end
end

-- Called by the options page after any visual setting changed
function Bags:RefreshAll()
    self:RefreshStyle()
    for _, w in ipairs({ bagWindow, self.bankWindow }) do
        if w then
            ApplyBackdrop(w.frame)
            if w:IsShown() then w:FullRefresh() else w.dirty = true end
        end
    end
    if bagWindow and bagWindow.bagBar then
        bagWindow:SetBagBarShown(GetDB().showBagBar)
    end
end
_G.SuaviUI_RefreshBags = function() Bags:RefreshAll() end

function Bags:IsActive() return self.active and true or false end

function Bags:ToggleBags()
    if not bagWindow then return end
    if bagWindow:IsShown() then bagWindow:Hide() else bagWindow:Show() end
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    Bags:RefreshStyle()
    local core = ns.Addon
    if core and core.db and core.db.RegisterCallback then
        local function OnProfile()
            Bags:RefreshStyle()
            local on = GetDB().enabled
            if on then Bags:Enable() else Bags:Disable() end
            if Bags.active then Bags:RefreshAll() end
        end
        core.db.RegisterCallback(Bags, "OnProfileChanged", OnProfile)
        core.db.RegisterCallback(Bags, "OnProfileCopied", OnProfile)
        core.db.RegisterCallback(Bags, "OnProfileReset", OnProfile)
    end
    if GetDB().enabled then Bags:Enable() end
end)
