--[[
    SuaviUI Custom GUI Framework
    Style: Horizontal tab grid at top
    Accent Color: #FF6AC1 (Snazzy Magenta)
]]

local ADDON_NAME, ns = ...
local SUI = SuaviUI
local LSM = LibStub("LibSharedMedia-3.0")

-- Create GUI namespace
SUI.GUI = SUI.GUI or {}
local GUI = SUI.GUI

---------------------------------------------------------------------------
-- THEME COLORS - "Snazzy" Palette (sindresorhus/terminal-snazzy)
---------------------------------------------------------------------------
GUI.Colors = {
    -- Backgrounds
    bg = {0.157, 0.165, 0.212, 0.97},         -- #282A36 Snazzy Background
    bgLight = {0.188, 0.196, 0.247, 1},        -- #303040 Slightly lighter
    bgDark = {0.133, 0.141, 0.188, 1},         -- #222430 Snazzy Border/Darker
    bgContent = {0.145, 0.153, 0.200, 0.55},   -- #252533 Content area

    -- Accent colors (Snazzy Magenta)
    accent = {1.0, 0.416, 0.757, 1},           -- #FF6AC1 Snazzy Magenta
    accentLight = {1.0, 0.553, 0.824, 1},      -- #FF8DD2 Lighter Magenta
    accentDark = {0.878, 0.322, 0.659, 1},     -- #E052A8 Deeper Magenta
    accentHover = {1.0, 0.490, 0.792, 1},      -- #FF7DCA Hover Magenta

    -- Nav/Tab colors
    tabSelected = {1.0, 0.416, 0.757, 1},      -- #FF6AC1 Magenta
    tabSelectedText = {0.157, 0.165, 0.212, 1}, -- Dark text on magenta
    tabNormal = {0.592, 0.592, 0.608, 1},      -- #97979B Snazzy Cursor Grey
    tabHover = {0.937, 0.941, 0.922, 1},       -- #EFF0EB Snazzy Foreground
    tabBg = {0.157, 0.165, 0.212, 1},          -- #282A36 Snazzy Background
    tabBgHover = {0.188, 0.196, 0.247, 1},     -- #303040
    tabBgActive = {0.200, 0.176, 0.243, 1},    -- Magenta-tinted dark

    -- Text colors
    text = {0.937, 0.941, 0.922, 1},           -- #EFF0EB Snazzy Foreground
    textBright = {0.945, 0.945, 0.941, 1},     -- #F1F1F0 Snazzy White
    textMuted = {0.502, 0.502, 0.518, 1},      -- #808084 Readable muted

    -- Borders
    border = {0.220, 0.227, 0.275, 1},         -- #383A46 Visible border
    borderLight = {0.290, 0.298, 0.345, 1},    -- #4A4C58 Light border
    borderAccent = {1.0, 0.416, 0.757, 1},     -- #FF6AC1 Magenta border

    -- Section headers
    sectionHeader = {0.604, 0.929, 0.996, 1},  -- #9AEDFE Snazzy Cyan

    -- Slider colors
    sliderTrack = {0.188, 0.196, 0.247, 1},    -- #303040
    sliderThumb = {0.937, 0.941, 0.922, 1},    -- #EFF0EB
    sliderThumbBorder = {0.290, 0.298, 0.345, 1}, -- #4A4C58

    -- Toggle switch colors
    toggleOff = {0.220, 0.227, 0.275, 1},      -- #383A46
    toggleThumb = {0.937, 0.941, 0.922, 1},    -- #EFF0EB

    -- Warning/semantic colors
    warning = {0.953, 0.976, 0.616, 1},        -- #F3F99D Snazzy Yellow
    success = {0.353, 0.969, 0.557, 1},         -- #5AF78E Snazzy Green
    error = {1.0, 0.361, 0.341, 1},             -- #FF5C57 Snazzy Red
    info = {0.604, 0.929, 0.996, 1},            -- #9AEDFE Snazzy Cyan

    -- Snazzy palette (direct access)
    snazzyRed = {1.0, 0.361, 0.341, 1},         -- #FF5C57
    snazzyGreen = {0.353, 0.969, 0.557, 1},     -- #5AF78E
    snazzyYellow = {0.953, 0.976, 0.616, 1},    -- #F3F99D
    snazzyBlue = {0.341, 0.780, 1.0, 1},        -- #57C7FF
    snazzyMagenta = {1.0, 0.416, 0.757, 1},     -- #FF6AC1
    snazzyCyan = {0.604, 0.929, 0.996, 1},      -- #9AEDFE
}

local C = GUI.Colors

---------------------------------------------------------------------------
-- LAYOUT SYSTEM - Centralized spacing, sizing, and positioning constants
---------------------------------------------------------------------------
-- This system replaces hard-coded "magic numbers" throughout the UI with
-- semantic constants, making the interface easier to customize and maintain.
--
-- Benefits:
--  • Single source of truth for all dimensions
--  • Easy theme/size adjustments (change once, update everywhere)
--  • Self-documenting code (formControlStart vs "180")
--  • Foundation for future responsive layouts
--
-- Usage: Access via L shorthand (e.g., L.toggle.width, L.space.md)
---------------------------------------------------------------------------
GUI.Layout = {
    -- Form layout (label on left, control on right)
    formLabelWidth = 180,        -- Width allocated for labels
    formControlStart = 220,  -- X position where controls start
    formRowHeight = 30,          -- Standard row height
    formGap = 6,                 -- Gap between label and control
    
    -- Widget dimensions
    checkbox = { 
        size = 16,               -- Checkbox box size
        checkSize = 20,          -- Checkmark texture size
        formSize = 18,           -- Form checkbox size (original style)
        formCheckSize = 22,      -- Form checkbox checkmark size
        containerWidth = 300,    -- Standard checkbox container width
        containerHeight = 20,    -- Standard checkbox container height
        centeredWidth = 100,     -- Centered checkbox container width
        centeredHeight = 40,     -- Centered checkbox container height
    },
    toggle = { 
        width = 40,              -- Toggle track width
        height = 20,             -- Toggle track height
        thumbSize = 16,          -- Thumb (circle) size
        thumbInset = 2,          -- Thumb position from track edge
    },
    dropdown = { 
        height = 24,             -- Dropdown button height
        chevronWidth = 28,       -- Right chevron zone width
        menuItemHeight = 22,     -- Individual menu item height
        containerHeight = 60,    -- Standard dropdown container height
        containerWidth = 200,    -- Default dropdown container width
        inset = 35,              -- Horizontal inset for standard dropdowns
        offsetY = -16,           -- Standard dropdown vertical offset
        fullWidthContainerHeight = 45, -- Full-width dropdown container height
        fullWidthYOffset = -18,  -- Full-width dropdown vertical offset
    },
    colorPicker = { 
        size = 24,               -- Standard color swatch size
        sizeSmall = 16,          -- Compact color swatch size
        containerWidth = 200,    -- Standard color picker container width
        containerHeight = 20,    -- Standard color picker container height
        centeredWidth = 100,     -- Centered color picker container width
        centeredHeight = 40,     -- Centered color picker container height
        formWidth = 50,          -- Form color picker swatch width
        formHeight = 18,         -- Form color picker swatch height
    },
    slider = { 
        height = 6,              -- Form slider track height
        thumbWidth = 14,         -- Form slider thumb width
        thumbHeight = 14,        -- Form slider thumb height
        rightInset = 95,         -- Space reserved for value input on right
    },
    
    -- Spacing scale (Tailwind-inspired)
    space = {
        xs = 4,                  -- Extra small spacing
        sm = 6,                  -- Small spacing (label offsets)
        md = 10,                 -- Medium spacing (general padding)
        lg = 15,                 -- Large spacing (section gaps)
        xl = 20,                 -- Extra large spacing
        xxl = 30,                -- Double extra large
    },
    
    -- Typography
    font = {
        tiny = 10,               -- Muted/small text
        small = 11,              -- Descriptions, secondary text
        normal = 12,             -- Standard labels and controls
        large = 14,              -- Headers, titles
    },
    
    -- Panel constraints
    panel = {
        defaultWidth = 840,      -- Default panel width (wider for sidebar)
        minWidth = 720,          -- Minimum resizable width
        maxWidth = 1100,         -- Maximum resizable width
        minHeight = 500,         -- Minimum resizable height
        maxHeight = 1200,        -- Maximum resizable height
        padding = 10,            -- Standard edge padding
        paddingDouble = 20,      -- Double padding (left + right)
    },

    -- Sidebar navigation
    sidebar = {
        width = 200,             -- Sidebar width
        categoryHeight = 28,     -- Category header height
        itemHeight = 24,         -- Page item height
        indent = 18,             -- Child item left indent
        padding = 8,             -- Internal padding
        searchHeight = 28,       -- Search box height
        searchGap = 8,           -- Gap below search box
        chevronWidth = 14,       -- Expand/collapse chevron size
        activeBarWidth = 3,      -- Active indicator bar width
        itemSpacing = 1,         -- Vertical gap between items
        categorySpacing = 4,     -- Extra gap before category headers
    },

    -- Tab system (legacy - kept for CreateSubTabs compatibility)
    tabs = {
        perRow = 5,              -- Tabs per row in main grid
        height = 24,             -- Tab button height
        spacing = 3,             -- Gap between tab buttons
        startY = -35,            -- Top offset for tab container
    },

    -- Sub-tab system (still used by Custom Trackers internal tabs)
    subTabs = {
        height = 24,             -- Sub-tab button height
        spacing = 4,             -- Gap between sub-tab buttons
        separatorSpacing = 15,   -- Extra gap after separator tabs
        containerHeight = 28,    -- Sub-tab container height
        defaultWidth = 90,       -- Default button width before relayout
    },
}

local L = GUI.Layout  -- Shorthand for layout constants

-- Panel dimensions (used for widget sizing)
GUI.PANEL_WIDTH = L.panel.defaultWidth
GUI.CONTENT_WIDTH = L.panel.defaultWidth - L.panel.paddingDouble

-- Settings Registry for search functionality
GUI.SettingsRegistry = {}

-- Search context (auto-populated by page builders)
GUI._searchContext = {
    tabIndex = nil,
    tabName = nil,
    subTabIndex = nil,
    subTabName = nil,
    sectionName = nil,
}

-- Suppress auto-registration when rebuilding widgets for search results
GUI._suppressSearchRegistration = false

-- Deduplication keys to prevent duplicate registry entries when tabs are re-clicked
GUI.SettingsRegistryKeys = {}

-- Widget instance tracking for cross-widget synchronization (search results <-> original tabs)
GUI.WidgetInstances = {}

-- Generate unique key for widget instance tracking
local function GetWidgetKey(dbTable, dbKey)
    if not dbTable or not dbKey then return nil end
    return tostring(dbTable) .. "_" .. dbKey
end

-- Register a widget instance for sync tracking
local function RegisterWidgetInstance(widget, dbTable, dbKey)
    local widgetKey = GetWidgetKey(dbTable, dbKey)
    if not widgetKey then return end
    GUI.WidgetInstances[widgetKey] = GUI.WidgetInstances[widgetKey] or {}
    table.insert(GUI.WidgetInstances[widgetKey], widget)
    widget._widgetKey = widgetKey
end

-- Unregister a widget instance (called during cleanup)
local function UnregisterWidgetInstance(widget)
    if not widget._widgetKey then return end
    local instances = GUI.WidgetInstances[widget._widgetKey]
    if not instances then return end
    for i = #instances, 1, -1 do
        if instances[i] == widget then
            table.remove(instances, i)
            break
        end
    end
end

-- Broadcast value change to all sibling widget instances
local function BroadcastToSiblings(widget, val)
    if not widget._widgetKey then return end
    local instances = GUI.WidgetInstances[widget._widgetKey]
    if not instances then return end
    for _, sibling in ipairs(instances) do
        if sibling ~= widget and sibling.UpdateVisual then
            sibling.UpdateVisual(val)
        end
    end
end

-- Set search context for auto-registration (call at start of page builder)
function GUI:SetSearchContext(info)
    self._searchContext.tabIndex = info.tabIndex
    self._searchContext.tabName = info.tabName
    self._searchContext.subTabIndex = info.subTabIndex or nil
    self._searchContext.subTabName = info.subTabName or nil
    self._searchContext.sectionName = info.sectionName or nil
end

-- Set current section (call when entering a new section within a page)
function GUI:SetSearchSection(sectionName)
    self._searchContext.sectionName = sectionName
end

-- Clear search context (optional, for safety)
function GUI:ClearSearchContext()
    self._searchContext = {
        tabIndex = nil,
        tabName = nil,
        subTabIndex = nil,
        subTabName = nil,
        sectionName = nil,
    }
end

-- Flag to track if search index has been built
GUI._searchIndexBuilt = false

-- Force-load all tabs to populate search registry
function GUI:ForceLoadAllTabs()
    local frame = self.MainFrame
    if not frame or not frame.pages then return end

    -- Initialize registry if needed (don't clear - keep registrations from already-visited tabs)
    if not self.SettingsRegistry then
        self.SettingsRegistry = {}
    end
    if not self.SettingsRegistryKeys then
        self.SettingsRegistryKeys = {}
    end

    -- Build each page that hasn't been built yet
    for pageIndex, page in pairs(frame.pages) do
        local builderFn = page.builder or page.createFunc
        if builderFn and not page.built then
            if not page.frame then
                page.frame = CreateFrame("Frame", nil, frame.contentArea)
                page.frame:SetAllPoints()
                page.frame:EnableMouse(false)
            end
            page.frame:Hide()
            builderFn(page.frame)
            page.built = true
        end
    end
end

---------------------------------------------------------------------------
-- FONT PATH (uses bundled Suavi font for consistent panel formatting)
---------------------------------------------------------------------------
local FONT_PATH = LSM:Fetch("font", "Suavi") or [[Interface\AddOns\SuaviUI\assets\fonts\Suavi.ttf]]
GUI.FONT_PATH = FONT_PATH

-- Helper for future configurability
local function GetFontPath()
    return FONT_PATH
end

---------------------------------------------------------------------------
-- UTILITY FUNCTIONS
---------------------------------------------------------------------------
local function CreateBackdrop(frame, bgColor, borderColor)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(bgColor or C.bg))
    frame:SetBackdropBorderColor(unpack(borderColor or C.border))
end

local function SetFont(fontString, size, flags, color)
    fontString:SetFont(GetFontPath(), size or 12, flags or "")
    if color then
        fontString:SetTextColor(unpack(color))
    end
end

---------------------------------------------------------------------------
-- ROUND SHAPE HELPERS (Apple-style pills and circles)
---------------------------------------------------------------------------
local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- Create a pill-shaped background from 3 textures: left cap + center + right cap
local function CreatePill(parent, layer, sublevel)
    layer = layer or "BACKGROUND"
    sublevel = sublevel or 0
    local pill = {}

    pill.left = parent:CreateTexture(nil, layer, nil, sublevel)
    pill.left:SetTexture(CIRCLE_TEX)
    pill.left:SetTexCoord(0, 0.5, 0, 1)

    pill.center = parent:CreateTexture(nil, layer, nil, sublevel)
    pill.center:SetTexture("Interface\\Buttons\\WHITE8x8")

    pill.right = parent:CreateTexture(nil, layer, nil, sublevel)
    pill.right:SetTexture(CIRCLE_TEX)
    pill.right:SetTexCoord(0.5, 1, 0, 1)

    function pill:SetVertexColor(r, g, b, a)
        self.left:SetVertexColor(r, g, b, a)
        self.center:SetVertexColor(r, g, b, a)
        self.right:SetVertexColor(r, g, b, a)
    end

    function pill:SetAlpha(a)
        self.left:SetAlpha(a)
        self.center:SetAlpha(a)
        self.right:SetAlpha(a)
    end

    function pill:Anchor(height, inset)
        inset = inset or 0
        local r = height / 2
        self.left:SetSize(r, height)
        self.right:SetSize(r, height)
        self.center:SetHeight(height)

        self.left:ClearAllPoints()
        self.left:SetPoint("LEFT", parent, "LEFT", inset, 0)
        self.right:ClearAllPoints()
        self.right:SetPoint("RIGHT", parent, "RIGHT", -inset, 0)
        self.center:ClearAllPoints()
        self.center:SetPoint("LEFT", self.left, "RIGHT", 0, 0)
        self.center:SetPoint("RIGHT", self.right, "LEFT", 0, 0)
    end

    -- Partial fill: pill from left edge to a fraction of parent width
    function pill:AnchorFill(height, fraction, inset)
        inset = inset or 0
        local r = height / 2
        self.left:SetSize(r, height)
        self.right:SetSize(r, height)
        self.center:SetHeight(height)

        self.left:ClearAllPoints()
        self.left:SetPoint("LEFT", parent, "LEFT", inset, 0)
        self.right:ClearAllPoints()
        -- Right cap positioned at the fill point
        local totalWidth = parent:GetWidth() - inset * 2
        local fillWidth = math.max(height, totalWidth * fraction)
        self.right:SetPoint("LEFT", parent, "LEFT", inset + fillWidth - r, 0)
        self.center:ClearAllPoints()
        self.center:SetPoint("LEFT", self.left, "RIGHT", 0, 0)
        self.center:SetPoint("RIGHT", self.right, "LEFT", 0, 0)
    end

    return pill
end

-- Create a circle texture (for slider/toggle thumbs)
local function CreateCircle(parent, layer, sublevel)
    local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    tex:SetTexture(CIRCLE_TEX)
    return tex
end

---------------------------------------------------------------------------
-- WIDGET: LABEL
---------------------------------------------------------------------------
function GUI:CreateLabel(parent, text, size, color, anchor, x, y)
    -- Mark content as added (for section header auto-spacing)
    if parent._hasContent ~= nil then
        parent._hasContent = true
    end
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(label, size or L.font.normal, "", color or C.text)
    label:SetText(text or "")
    if anchor then
        label:SetPoint(anchor, parent, anchor, x or 0, y or 0)
    end
    return label
end

---------------------------------------------------------------------------
-- WIDGET: THEMED BUTTON (Neutral style - accent border on hover only)
---------------------------------------------------------------------------
function GUI:CreateButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 26)

    -- Normal state: dark background with grey border (neutral)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 1)
    btn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

    -- Button text (off-white, not accent)
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btnText:SetFont(GetFontPath(), L.font.normal, "")
    btnText:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    btnText:SetPoint("CENTER", 0, 0)
    btnText:SetText(text or "Button")
    btn.text = btnText

    -- Hover effect: accent border only (no background change)
    btn:SetScript("OnEnter", function(self)
        pcall(self.SetBackdropBorderColor, self, C.accent[1], C.accent[2], C.accent[3], 1)
    end)

    btn:SetScript("OnLeave", function(self)
        pcall(self.SetBackdropBorderColor, self, C.border[1], C.border[2], C.border[3], 1)
    end)

    -- Click handler
    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    -- Method to update text
    function btn:SetText(newText)
        btnText:SetText(newText)
    end

    return btn
end

---------------------------------------------------------------------------
-- CONFIRMATION DIALOG (SUI-styled replacement for StaticPopup)
-- Singleton frame, lazy-created and reused
---------------------------------------------------------------------------
local confirmDialog = nil

function GUI:ShowConfirmation(options)
    -- options = {
    --   title = "Delete Profile?",
    --   message = "Delete profile 'ProfileName'?",
    --   warningText = "This cannot be undone.",  -- optional, amber text
    --   acceptText = "Delete",
    --   cancelText = "Cancel",
    --   onAccept = function() end,
    --   onCancel = function() end,  -- optional
    --   isDestructive = true,       -- amber text on accept button
    -- }

    if not confirmDialog then
        -- Create singleton dialog frame
        confirmDialog = CreateFrame("Frame", "SUI_ConfirmDialog", UIParent, "BackdropTemplate")
        confirmDialog:SetSize(320, 160)
        confirmDialog:SetPoint("CENTER")
        confirmDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        confirmDialog:SetFrameLevel(500)
        confirmDialog:EnableMouse(true)
        confirmDialog:SetMovable(true)
        confirmDialog:RegisterForDrag("LeftButton")
        confirmDialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
        confirmDialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        confirmDialog:SetClampedToScreen(true)
        confirmDialog:Hide()

        -- Backdrop
        confirmDialog:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        confirmDialog:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.98)
        confirmDialog:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

        -- Title
        confirmDialog.title = confirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFont(confirmDialog.title, 14, "", C.accentLight)
        confirmDialog.title:SetPoint("TOP", 0, -18)

        -- Message
        confirmDialog.message = confirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFont(confirmDialog.message, 12, "", C.text)
        confirmDialog.message:SetPoint("TOP", 0, -50)
        confirmDialog.message:SetWidth(280)
        confirmDialog.message:SetJustifyH("CENTER")

        -- Warning text
        confirmDialog.warning = confirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFont(confirmDialog.warning, 11, "", C.warning)
        confirmDialog.warning:SetPoint("TOP", confirmDialog.message, "BOTTOM", 0, -8)

        -- Accept button (left)
        confirmDialog.acceptBtn = CreateFrame("Button", nil, confirmDialog, "BackdropTemplate")
        confirmDialog.acceptBtn:SetSize(100, 28)
        confirmDialog.acceptBtn:SetPoint("BOTTOMLEFT", 40, 20)
        confirmDialog.acceptBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        confirmDialog.acceptBtn:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 1)
        confirmDialog.acceptBtn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

        confirmDialog.acceptBtn.text = confirmDialog.acceptBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        confirmDialog.acceptBtn.text:SetFont(GetFontPath(), 12, "")
        confirmDialog.acceptBtn.text:SetPoint("CENTER", 0, 0)

        confirmDialog.acceptBtn:SetScript("OnEnter", function(self)
            pcall(self.SetBackdropBorderColor, self, C.accent[1], C.accent[2], C.accent[3], 1)
        end)
        confirmDialog.acceptBtn:SetScript("OnLeave", function(self)
            pcall(self.SetBackdropBorderColor, self, C.border[1], C.border[2], C.border[3], 1)
        end)

        -- Cancel button (right)
        confirmDialog.cancelBtn = CreateFrame("Button", nil, confirmDialog, "BackdropTemplate")
        confirmDialog.cancelBtn:SetSize(100, 28)
        confirmDialog.cancelBtn:SetPoint("BOTTOMRIGHT", -40, 20)
        confirmDialog.cancelBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        confirmDialog.cancelBtn:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 1)
        confirmDialog.cancelBtn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

        confirmDialog.cancelBtn.text = confirmDialog.cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        confirmDialog.cancelBtn.text:SetFont(GetFontPath(), 12, "")
        confirmDialog.cancelBtn.text:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        confirmDialog.cancelBtn.text:SetPoint("CENTER", 0, 0)

        confirmDialog.cancelBtn:SetScript("OnEnter", function(self)
            pcall(self.SetBackdropBorderColor, self, C.accent[1], C.accent[2], C.accent[3], 1)
        end)
        confirmDialog.cancelBtn:SetScript("OnLeave", function(self)
            pcall(self.SetBackdropBorderColor, self, C.border[1], C.border[2], C.border[3], 1)
        end)

        -- ESC to close
        confirmDialog:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:SetPropagateKeyboardInput(false)
                if self._onCancel then self._onCancel() end
                self:Hide()
            else
                self:SetPropagateKeyboardInput(true)
            end
        end)
    end

    -- Configure for this call
    confirmDialog.title:SetText(options.title or "Confirm")
    confirmDialog.message:SetText(options.message or "")

    if options.warningText then
        confirmDialog.warning:SetText(options.warningText)
        confirmDialog.warning:Show()
    else
        confirmDialog.warning:Hide()
    end

    -- Accept button styling
    confirmDialog.acceptBtn.text:SetText(options.acceptText or "OK")
    if options.isDestructive then
        confirmDialog.acceptBtn.text:SetTextColor(C.warning[1], C.warning[2], C.warning[3], 1)
    else
        confirmDialog.acceptBtn.text:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    end

    -- Cancel button
    confirmDialog.cancelBtn.text:SetText(options.cancelText or "Cancel")

    -- Store callbacks
    confirmDialog._onCancel = options.onCancel

    -- Button click handlers
    confirmDialog.acceptBtn:SetScript("OnClick", function()
        confirmDialog:Hide()
        if options.onAccept then options.onAccept() end
    end)

    confirmDialog.cancelBtn:SetScript("OnClick", function()
        confirmDialog:Hide()
        if options.onCancel then options.onCancel() end
    end)

    -- Show and enable keyboard
    confirmDialog:Show()
    confirmDialog:EnableKeyboard(true)
end

---------------------------------------------------------------------------
-- WIDGET: SECTION HEADER (Mint colored text with underline)
-- Auto-detects if first element in panel (no top margin) vs subsequent (12px margin)
---------------------------------------------------------------------------
function GUI:CreateSectionHeader(parent, text)
    -- Auto-detect if this is the first element (for compact spacing at top of panels)
    local isFirstElement = (parent._hasContent == false)
    if parent._hasContent ~= nil then
        parent._hasContent = true
    end

    -- First element: no top margin (18px), others: 12px top margin (30px)
    local topMargin = isFirstElement and 0 or 10
    local containerHeight = isFirstElement and 20 or 30

    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(containerHeight)

    local header = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(header, 14, "", C.sectionHeader)
    header:SetText(text or "Section")
    header:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -topMargin)

    -- Store references and recommended gap for calling code
    container.text = header
    container.parent = parent
    container.gap = isFirstElement and 32 or 40

    -- Expose SetText for convenience
    container.SetText = function(self, newText)
        header:SetText(newText)
    end

    -- Hook SetPoint to also set width and create underline after positioning
    local originalSetPoint = container.SetPoint
    container.SetPoint = function(self, point, ...)
        originalSetPoint(self, point, ...)
        -- After TOPLEFT is set, also anchor RIGHT to give container width
        if point == "TOPLEFT" then
            originalSetPoint(self, "RIGHT", parent, "RIGHT", -10, 0)
            -- Create underline now that we have positioning
            if not container.underline then
                local underline = container:CreateTexture(nil, "ARTWORK")
                underline:SetHeight(2)
                underline:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
                underline:SetPoint("RIGHT", container, "RIGHT", -4, 0)
                underline:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7)
                container.underline = underline
            end
        end
    end

    return container
end

---------------------------------------------------------------------------
-- WIDGET: SECTION BOX (Bordered group like old GUI)
-- Auto-calculates height based on content added via box:AddElement()
---------------------------------------------------------------------------
function GUI:CreateSectionBox(parent, title)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.8)
    box:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    
    -- Title (mint colored, positioned at top-left inside border)
    if title and title ~= "" then
        local titleText = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetFont(GetFontPath(), 12, "")
        titleText:SetTextColor(unpack(C.accentLight))
        titleText:SetText(title)
        titleText:SetPoint("TOPLEFT", 10, -8)
        box.title = titleText
    end
    
    -- Track current Y position for auto-layout
    box.currentY = -30  -- Starting Y position for content inside the box
    box.padding = 12    -- Left/right padding
    box.elementSpacing = 8  -- Default spacing between elements
    
    -- Helper to add element and auto-position it
    function box:AddElement(element, height, spacing)
        local sp = spacing or self.elementSpacing
        element:SetPoint("TOPLEFT", self.padding, self.currentY)
        if element.SetPoint then
            -- If element supports right anchor, stretch it
            element:SetPoint("TOPRIGHT", -self.padding, self.currentY)
        end
        self.currentY = self.currentY - (height or 25) - sp
    end
    
    -- Call this after adding all elements to set the box height
    function box:FinishLayout(bottomPadding)
        local pad = bottomPadding or 12
        self:SetHeight(math.abs(self.currentY) + pad)
        return math.abs(self.currentY) + pad  -- Return height for parent tracking
    end
    
    return box
end

---------------------------------------------------------------------------
-- WIDGET: COLLAPSIBLE SECTION
-- Expandable/collapsible container with clickable header
---------------------------------------------------------------------------
function GUI:CreateCollapsibleSection(parent, title, isExpandedByDefault, badgeConfig)
    local container = CreateFrame("Frame", nil, parent)
    local isExpanded = isExpandedByDefault ~= false  -- Default true

    -- Header (clickable, full width)
    local header = CreateFrame("Button", nil, container, "BackdropTemplate")
    header:SetHeight(28)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    header:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.6)
    header:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.5)

    -- Chevron indicator
    local chevron = header:CreateFontString(nil, "OVERLAY")
    chevron:SetFont(GetFontPath(), 12, "")
    chevron:SetPoint("LEFT", 10, 0)
    chevron:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)

    -- Title text
    local titleText = header:CreateFontString(nil, "OVERLAY")
    SetFont(titleText, 12, "", C.accent)
    titleText:SetText(title or "Section")
    titleText:SetPoint("LEFT", chevron, "RIGHT", 6, 0)

    -- Optional badge (e.g., "Override" indicator)
    local badge = nil
    if badgeConfig and badgeConfig.text then
        badge = CreateFrame("Frame", nil, header, "BackdropTemplate")
        badge:SetHeight(18)
        badge:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        badge:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 0.2)
        badge:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.5)

        local badgeText = badge:CreateFontString(nil, "OVERLAY")
        badgeText:SetFont(GetFontPath(), 10, "")
        badgeText:SetText(badgeConfig.text)
        badgeText:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
        badgeText:SetPoint("CENTER", 0, 0)

        -- Auto-width based on text
        local textWidth = badgeText:GetStringWidth() or 40
        badge:SetWidth(textWidth + 12)
        badge:SetPoint("RIGHT", header, "RIGHT", -10, 0)

        -- Initial visibility based on showFunc
        if badgeConfig.showFunc then
            badge:SetShown(badgeConfig.showFunc())
        end
    end

    -- Content area
    local content = CreateFrame("Frame", nil, container)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    content:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    content._hasContent = false

    -- Update function
    local function UpdateState()
        if isExpanded then
            chevron:SetText("v")  -- Down arrow
            content:Show()
            container:SetHeight(header:GetHeight() + 4 + (content:GetHeight() or 0))
        else
            chevron:SetText(">")  -- Right arrow
            content:Hide()
            container:SetHeight(header:GetHeight())
        end
    end

    -- Click handler
    header:SetScript("OnClick", function()
        isExpanded = not isExpanded
        UpdateState()
        if container.OnExpandChanged then
            container.OnExpandChanged(isExpanded)
        end
    end)

    -- Hover effects
    header:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.8)
    end)
    header:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.5)
    end)

    -- API methods
    container.SetExpanded = function(self, expanded)
        isExpanded = expanded
        UpdateState()
    end

    container.GetExpanded = function()
        return isExpanded
    end

    container.UpdateHeight = function()
        UpdateState()
    end

    container.SetTitle = function(self, newTitle)
        titleText:SetText(newTitle)
    end

    -- Badge update method
    container.UpdateBadge = function()
        if badge and badgeConfig and badgeConfig.showFunc then
            badge:SetShown(badgeConfig.showFunc())
        end
    end

    container.content = content
    container.header = header
    container.badge = badge

    UpdateState()
    return container
end

---------------------------------------------------------------------------
-- WIDGET: COLOR PICKER
---------------------------------------------------------------------------
function GUI:CreateColorPicker(parent, label, dbKey, dbTable, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(L.colorPicker.containerWidth, L.colorPicker.containerHeight)
    
    -- Color swatch button (same size as checkbox: 16x16)
    local swatch = CreateFrame("Button", nil, container, "BackdropTemplate")
    swatch:SetSize(L.colorPicker.sizeSmall, L.colorPicker.sizeSmall)
    swatch:SetPoint("LEFT", 0, 0)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    swatch:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
    
    -- Label (same font size as checkbox: 12)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Color")
    text:SetPoint("LEFT", swatch, "RIGHT", L.space.sm, 0)
    
    container.swatch = swatch
    container.label = text
    
    local function GetColor()
        if dbTable and dbKey then
            local c = dbTable[dbKey]
            if c then return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1 end
        end
        return 1, 1, 1, 1
    end
    
    local function SetColor(r, g, b, a)
        swatch:SetBackdropColor(r, g, b, a or 1)
        if dbTable and dbKey then
            dbTable[dbKey] = {r, g, b, a or 1}
        end
        if onChange then onChange(r, g, b, a) end
    end
    
    -- Initialize color
    local r, g, b, a = GetColor()
    swatch:SetBackdropColor(r, g, b, a)
    
    container.GetColor = GetColor
    container.SetColor = SetColor
    
    -- Open color picker on click
    swatch:SetScript("OnClick", function()
        local r, g, b, a = GetColor()
        local originalA = a or 1
        
        local info = {
            r = r,
            g = g,
            b = b,
            opacity = originalA,
            hasOpacity = true,
            swatchFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newA = ColorPickerFrame:GetColorAlpha()
                SetColor(newR, newG, newB, newA)
            end,
            opacityFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newA = ColorPickerFrame:GetColorAlpha()
                SetColor(newR, newG, newB, newA)
            end,
            cancelFunc = function(prev)
                SetColor(prev.r, prev.g, prev.b, originalA)
            end,
        }
        
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    
    -- Hover effect
    swatch:SetScript("OnEnter", function(self)
        pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
    end)
    swatch:SetScript("OnLeave", function(self)
        pcall(self.SetBackdropBorderColor, self, C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
    end)
    
    return container
end

---------------------------------------------------------------------------
-- WIDGET: SUB-TABS (Horizontal tabs within a page)
---------------------------------------------------------------------------
function GUI:CreateSubTabs(parent, tabs, options)
    options = options or {}
    local rows = options.rows or 1
    local perRow = options.perRow or math.ceil(#tabs / rows)
    local container = CreateFrame("Frame", nil, parent)
    local containerHeight = (rows == 1) and L.subTabs.containerHeight or (L.subTabs.height * rows + L.subTabs.spacing * (rows - 1))
    container:SetHeight(containerHeight)
    
    local tabButtons = {}
    local tabContents = {}
    local buttonWidth = L.subTabs.defaultWidth
    local spacing = L.subTabs.spacing
    local contentOffset = (rows == 1) and 30 or (L.subTabs.height * rows + L.subTabs.spacing * (rows - 1) + 6)
    
    for i, tabInfo in ipairs(tabs) do
        -- Tab button
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetSize(buttonWidth, L.subTabs.height)
        btn:SetPoint("TOPLEFT", L.space.md + (i-1) * (buttonWidth + spacing), 0)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(C.bgLight[1], C.bgLight[2], C.bgLight[3], 1)
        btn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFont(btn.text, L.font.tiny, "", C.text)
        btn.text:SetText(tabInfo.name)
        btn.text:SetPoint("CENTER", 0, 0)

        btn.index = i
        tabButtons[i] = btn
        
        -- Content frame for this tab
        local content = CreateFrame("Frame", nil, container)
        content:SetPoint("TOPLEFT", 0, -contentOffset)
        content:SetPoint("BOTTOMRIGHT", 0, 0)
        content:Hide()
        content:EnableMouse(false)  -- Container frame - let children handle clicks
        content._hasContent = false  -- Track if any content added (for auto-spacing)
        tabContents[i] = content
        
        -- Create content if builder function provided
        if tabInfo.builder then
            tabInfo.builder(content)
        end
    end

    -- Dynamic relayout function for responsive sub-tabs
    local function RelayoutSubTabs()
        local containerWidth = container:GetWidth()
        if containerWidth < 1 then return end  -- Not sized yet

        if rows == 1 then
            local separatorSpacing = L.subTabs.separatorSpacing  -- Extra spacing after tabs with isSeparator
            local availableWidth = containerWidth - (L.space.md * 2)  -- Padding each side

            -- Count separators to account for extra spacing
            local separatorCount = 0
            for _, tabInfo in ipairs(tabs) do
                if tabInfo.isSeparator then separatorCount = separatorCount + 1 end
            end

            local totalSpacing = (#tabButtons - 1) * spacing + (separatorCount * separatorSpacing)
            local newButtonWidth = math.floor((availableWidth - totalSpacing) / #tabButtons)
            newButtonWidth = math.max(newButtonWidth, 50)  -- minimum 50px

            local xOffset = 10
            for i, btn in ipairs(tabButtons) do
                btn:SetWidth(newButtonWidth)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", xOffset, 0)
                xOffset = xOffset + newButtonWidth + spacing

                -- Add extra spacing after separator tabs
                if tabs[i] and tabs[i].isSeparator then
                    xOffset = xOffset + separatorSpacing
                end
            end
        else
            local availableWidth = containerWidth - (L.space.md * 2)
            local totalSpacing = (perRow - 1) * spacing
            local newButtonWidth = math.floor((availableWidth - totalSpacing) / perRow)
            newButtonWidth = math.max(newButtonWidth, 50)

            for i, btn in ipairs(tabButtons) do
                local row = math.floor((i - 1) / perRow)
                local col = (i - 1) % perRow
                local x = 10 + col * (newButtonWidth + spacing)
                local y = -row * (L.subTabs.height + spacing)

                btn:SetWidth(newButtonWidth)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", x, y)
            end
        end
    end

    -- Hook resize to relayout sub-tabs dynamically
    container:SetScript("OnSizeChanged", RelayoutSubTabs)

    -- Tab selection function
    local function SelectSubTab(index)
        for i, btn in ipairs(tabButtons) do
            if i == index then
                -- ACTIVE: Dark background with magenta tint + accent border + accent text
                pcall(btn.SetBackdropColor, btn, 0.20, 0.16, 0.22, 1)  -- Magenta-tinted dark bg
                pcall(btn.SetBackdropBorderColor, btn, unpack(C.accent))
                btn.text:SetFont(GetFontPath(), L.font.tiny, "")
                btn.text:SetTextColor(unpack(C.accent))  -- Mint colored text - easy to read
                tabContents[i]:Show()
            else
                -- INACTIVE: Standard dark look
                pcall(btn.SetBackdropColor, btn, C.bgLight[1], C.bgLight[2], C.bgLight[3], 1)
                pcall(btn.SetBackdropBorderColor, btn, C.border[1], C.border[2], C.border[3], 1)
                btn.text:SetFont(GetFontPath(), L.font.tiny, "")
                btn.text:SetTextColor(unpack(C.text))
                tabContents[i]:Hide()
            end
        end
        container.selectedTab = index
    end
    
    -- Button click handlers
    for i, btn in ipairs(tabButtons) do
        btn:SetScript("OnClick", function() SelectSubTab(i) end)
        btn:SetScript("OnEnter", function(self)
            if container.selectedTab ~= i then
                pcall(self.SetBackdropBorderColor, self, unpack(C.accentHover))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if container.selectedTab ~= i then
                pcall(self.SetBackdropBorderColor, self, C.border[1], C.border[2], C.border[3], 1)
            end
        end)
    end
    
    container.tabButtons = tabButtons
    container.tabContents = tabContents
    container.SelectTab = SelectSubTab
    container.RelayoutSubTabs = RelayoutSubTabs  -- Expose for external use if needed

    -- Select first tab by default
    SelectSubTab(1)

    -- Initial layout (deferred to ensure container has width from parent anchoring)
    C_Timer.After(0, RelayoutSubTabs)

    return container
end

---------------------------------------------------------------------------
-- WIDGET: DESCRIPTION TEXT
---------------------------------------------------------------------------
function GUI:CreateDescription(parent, text, color)
    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(desc, L.font.small, "", color or C.textMuted)
    desc:SetText(text)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    return desc
end

---------------------------------------------------------------------------
-- WIDGET: CHECKBOX
---------------------------------------------------------------------------
function GUI:CreateCheckbox(parent, label, dbKey, dbTable, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(L.checkbox.containerWidth, L.checkbox.containerHeight)
    
    local box = CreateFrame("Button", nil, container, "BackdropTemplate")
    box:SetSize(L.checkbox.size, L.checkbox.size)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    box:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
    
    -- Checkmark (accent-colored using standard check but tinted)
    box.check = box:CreateTexture(nil, "OVERLAY")
    box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box.check:SetPoint("CENTER", 0, 0)
    box.check:SetSize(L.checkbox.checkSize, L.checkbox.checkSize)
    box.check:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)  -- Theme accent
    box.check:SetDesaturated(true)  -- Remove yellow, then apply accent
    box.check:Hide()
    
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Option")
    text:SetPoint("LEFT", box, "RIGHT", L.space.sm, 0)
    
    container.box = box
    container.label = text
    
    local function GetValue()
        if dbTable and dbKey then return dbTable[dbKey] end
        return container.checked
    end
    
    local function SetValue(val)
        container.checked = val
        if val then
            box.check:Show()
            box:SetBackdropBorderColor(unpack(C.accent))  -- Mint when checked
            box:SetBackdropColor(0.20, 0.16, 0.22, 1)
        else
            box.check:Hide()
            box:SetBackdropBorderColor(unpack(C.border))
            box:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
        end
        if dbTable and dbKey then dbTable[dbKey] = val end
        if onChange then onChange(val) end
    end
    
    container.GetValue = GetValue
    container.SetValue = SetValue
    SetValue(GetValue())
    
    box:SetScript("OnClick", function() SetValue(not GetValue()) end)
    box:SetScript("OnEnter", function(self) pcall(self.SetBackdropBorderColor, self, unpack(C.accentHover)) end)
    box:SetScript("OnLeave", function(self)
        if GetValue() then
            pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
        else
            pcall(self.SetBackdropBorderColor, self, unpack(C.border))
        end
    end)
    
    return container
end

---------------------------------------------------------------------------
-- WIDGET: CHECKBOX CENTERED (label centered above checkbox)
---------------------------------------------------------------------------
function GUI:CreateCheckboxCentered(parent, label, dbKey, dbTable, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(L.checkbox.centeredWidth, L.checkbox.centeredHeight)  -- Taller to fit label above
    
    -- Label on top, centered
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.small, "", C.accentLight)  -- Mint like slider labels
    text:SetText(label or "Option")
    text:SetPoint("TOP", container, "TOP", 0, 0)
    
    -- Checkbox box below label, centered
    local box = CreateFrame("Button", nil, container, "BackdropTemplate")
    box:SetSize(L.checkbox.size, L.checkbox.size)
    box:SetPoint("TOP", text, "BOTTOM", 0, -4)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    box:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
    
    -- Checkmark
    box.check = box:CreateTexture(nil, "OVERLAY")
    box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box.check:SetPoint("CENTER", 0, 0)
    box.check:SetSize(L.checkbox.checkSize, L.checkbox.checkSize)
    box.check:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    box.check:SetDesaturated(true)
    box.check:Hide()
    
    container.box = box
    container.label = text
    
    local function GetValue()
        if dbTable and dbKey then return dbTable[dbKey] end
        return container.checked
    end
    
    local function SetValue(val)
        container.checked = val
        if val then
            box.check:Show()
            box:SetBackdropBorderColor(unpack(C.accent))
            box:SetBackdropColor(0.20, 0.16, 0.22, 1)
        else
            box.check:Hide()
            box:SetBackdropBorderColor(unpack(C.border))
            box:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
        end
        if dbTable and dbKey then dbTable[dbKey] = val end
        if onChange then onChange(val) end
    end
    
    container.GetValue = GetValue
    container.SetValue = SetValue
    SetValue(GetValue())
    
    box:SetScript("OnClick", function() SetValue(not GetValue()) end)
    box:SetScript("OnEnter", function(self) pcall(self.SetBackdropBorderColor, self, unpack(C.accentHover)) end)
    box:SetScript("OnLeave", function(self)
        if GetValue() then
            pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
        else
            pcall(self.SetBackdropBorderColor, self, unpack(C.border))
        end
    end)
    
    return container
end

---------------------------------------------------------------------------
-- WIDGET: COLOR PICKER CENTERED (label centered above swatch)
---------------------------------------------------------------------------
function GUI:CreateColorPickerCentered(parent, label, dbKey, dbTable, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(L.colorPicker.centeredWidth, L.colorPicker.centeredHeight)  -- Taller to fit label above
    
    -- Label on top, centered (mint like slider labels)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.small, "", C.accentLight)
    text:SetText(label or "Color")
    text:SetPoint("TOP", container, "TOP", 0, 0)
    
    -- Color swatch below label, centered
    local swatch = CreateFrame("Button", nil, container, "BackdropTemplate")
    swatch:SetSize(L.colorPicker.sizeSmall, L.colorPicker.sizeSmall)
    swatch:SetPoint("TOP", text, "BOTTOM", 0, -4)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    swatch:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
    
    container.swatch = swatch
    container.label = text
    
    local function GetColor()
        if dbTable and dbKey then
            local c = dbTable[dbKey]
            if c then return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1 end
        end
        return 1, 1, 1, 1
    end
    
    local function SetColor(r, g, b, a)
        swatch:SetBackdropColor(r, g, b, a or 1)
        if dbTable and dbKey then
            dbTable[dbKey] = {r, g, b, a or 1}
        end
        if onChange then onChange(r, g, b, a) end
    end
    
    -- Initialize color
    local r, g, b, a = GetColor()
    swatch:SetBackdropColor(r, g, b, a)
    
    container.GetColor = GetColor
    container.SetColor = SetColor
    
    -- Open color picker on click
    swatch:SetScript("OnClick", function()
        local r, g, b, a = GetColor()
        local originalA = a or 1
        local info = {
            hasOpacity = true,
            opacity = originalA,
            r = r, g = g, b = b,
            swatchFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newA = ColorPickerFrame:GetColorAlpha()
                SetColor(newR, newG, newB, newA)
            end,
            opacityFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newA = ColorPickerFrame:GetColorAlpha()
                SetColor(newR, newG, newB, newA)
            end,
            cancelFunc = function(prev)
                SetColor(prev.r, prev.g, prev.b, originalA)
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    
    swatch:SetScript("OnEnter", function(self)
        pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
    end)
    swatch:SetScript("OnLeave", function(self)
        pcall(self.SetBackdropBorderColor, self, C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
    end)
    
    return container
end

---------------------------------------------------------------------------
-- Inverted Checkbox: checked = false in DB, unchecked = true in DB
-- Use for "Hide X" options where DB stores "showX"
---------------------------------------------------------------------------
function GUI:CreateCheckboxInverted(parent, label, dbKey, dbTable, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(L.checkbox.containerWidth, L.checkbox.containerHeight)
    
    local box = CreateFrame("Button", nil, container, "BackdropTemplate")
    box:SetSize(L.checkbox.size, L.checkbox.size)
    box:SetPoint("LEFT", 0, 0)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    box:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
    
    box.check = box:CreateTexture(nil, "OVERLAY")
    box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box.check:SetPoint("CENTER", 0, 0)
    box.check:SetSize(L.checkbox.checkSize, L.checkbox.checkSize)
    box.check:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    box.check:SetDesaturated(true)
    box.check:Hide()
    
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Option")
    text:SetPoint("LEFT", box, "RIGHT", L.space.sm, 0)
    
    container.box = box
    container.label = text
    
    -- INVERTED: DB true = unchecked, DB false = checked
    local function GetDBValue()
        if dbTable and dbKey then return dbTable[dbKey] end
        return true
    end
    
    local function IsChecked()
        return not GetDBValue()  -- Invert for display
    end
    
    local function SetChecked(checked)
        container.checked = checked
        local dbVal = not checked  -- Invert for storage
        if checked then
            box.check:Show()
            box:SetBackdropBorderColor(unpack(C.accent))
            box:SetBackdropColor(0.20, 0.16, 0.22, 1)
        else
            box.check:Hide()
            box:SetBackdropBorderColor(unpack(C.border))
            box:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
        end
        if dbTable and dbKey then dbTable[dbKey] = dbVal end
        if onChange then onChange(dbVal) end
    end
    
    container.GetValue = IsChecked
    container.SetValue = SetChecked
    SetChecked(IsChecked())
    
    box:SetScript("OnClick", function() SetChecked(not IsChecked()) end)
    box:SetScript("OnEnter", function(self) pcall(self.SetBackdropBorderColor, self, unpack(C.accentHover)) end)
    box:SetScript("OnLeave", function(self)
        if IsChecked() then
            pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
        else
            pcall(self.SetBackdropBorderColor, self, unpack(C.border))
        end
    end)
    
    return container
end

---------------------------------------------------------------------------
-- WIDGET: SLIDER (Full-width, stacks vertically like old GUI)
-- Layout: Label centered on top, slider bar below, min|editbox|max at bottom
-- Options table (optional 8th param): { deferOnDrag = true } to defer onChange until mouse release
---------------------------------------------------------------------------
function GUI:CreateSlider(parent, label, min, max, step, dbKey, dbTable, onChange, options)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(60)
    container:EnableMouse(true)  -- Block clicks from passing through to frames behind
    -- Width will be set by anchoring TOPLEFT and TOPRIGHT

    -- Parse options
    options = options or {}
    local deferOnDrag = options.deferOnDrag or false

    -- Label (top, centered, mint colored)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, 11, "", C.accentLight)
    text:SetText(label or "Setting")
    text:SetPoint("TOP", 0, 0)

    -- Track container (for the filled + unfilled portions)
    local trackContainer = CreateFrame("Frame", nil, container)
    trackContainer:SetHeight(6)  -- Premium thinner track
    trackContainer:SetPoint("TOPLEFT", 35, -18)
    trackContainer:SetPoint("TOPRIGHT", -35, -18)

    -- Unfilled track (pill-shaped background)
    local trackBgPill = CreatePill(trackContainer, "BACKGROUND", 0)
    trackBgPill:Anchor(6)
    trackBgPill:SetVertexColor(C.sliderTrack[1], C.sliderTrack[2], C.sliderTrack[3], 1)

    -- Filled track (accent pill from left to thumb)
    local trackFillPill = CreatePill(trackContainer, "BACKGROUND", 1)
    trackFillPill:Anchor(6)
    trackFillPill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    -- Compat shim: external code calls container.trackFill:SetWidth() — ignore it
    local trackFill = setmetatable({}, {__index = function() return function() end end})

    -- Actual slider (invisible, just for interaction)
    local slider = CreateFrame("Slider", nil, trackContainer)
    slider:SetAllPoints()
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    slider:SetHitRectInsets(0, 0, -10, -10)

    -- Thumb frame (circle)
    local thumbFrame = CreateFrame("Frame", nil, slider)
    thumbFrame:SetSize(L.slider.thumbWidth, L.slider.thumbHeight)
    thumbFrame:SetFrameLevel(slider:GetFrameLevel() + 2)
    thumbFrame:EnableMouse(false)
    local thumbCircle = CreateCircle(thumbFrame, "ARTWORK")
    thumbCircle:SetAllPoints()
    thumbCircle:SetVertexColor(C.sliderThumb[1], C.sliderThumb[2], C.sliderThumb[3], 1)

    -- Hidden thumb texture for slider mechanics
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(14, 14)
    thumb:SetAlpha(0)

    -- Min label (left of slider)
    local minText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(minText, 10, "", C.textMuted)
    minText:SetText(tostring(min or 0))
    minText:SetPoint("RIGHT", trackContainer, "LEFT", -5, 0)

    -- Max label (right of slider)
    local maxText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(maxText, 10, "", C.textMuted)
    maxText:SetText(tostring(max or 100))
    maxText:SetPoint("LEFT", trackContainer, "RIGHT", 5, 0)

    -- Editbox for value (center, below slider)
    local editBox = CreateFrame("EditBox", nil, container, "BackdropTemplate")
    editBox:SetSize(70, 22)
    editBox:SetPoint("TOP", trackContainer, "BOTTOM", 0, -6)
    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    editBox:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    editBox:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    editBox:SetFont(GetFontPath(), 11, "")
    editBox:SetTextColor(unpack(C.text))
    editBox:SetJustifyH("CENTER")
    editBox:SetAutoFocus(false)

    -- Configure slider
    slider:SetMinMaxValues(min or 0, max or 100)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)

    container.slider = slider
    container.editBox = editBox
    container.trackFill = trackFill
    container.thumbFrame = thumbFrame
    container.trackContainer = trackContainer
    container.min = min or 0
    container.max = max or 100
    container.step = step or 1

    -- Track dragging state for deferOnDrag mode
    local isDragging = false

    -- Update filled track and thumb position
    local function UpdateTrackFill(value)
        local minVal, maxVal = container.min, container.max
        local pct = (value - minVal) / (maxVal - minVal)
        pct = math.max(0, math.min(1, pct))

        local trackWidth = trackContainer:GetWidth()
        if trackWidth < 1 then return end
        trackFillPill:AnchorFill(6, pct)

        local thumbX = pct * (trackWidth - 14) + 7
        thumbFrame:ClearAllPoints()
        thumbFrame:SetPoint("CENTER", trackContainer, "LEFT", thumbX, 0)
    end

    local function GetValue()
        if dbTable and dbKey then return dbTable[dbKey] or container.min end
        return container.value or container.min
    end

    local function FormatVal(val)
        if container.step >= 1 then
            return tostring(math.floor(val))
        else
            return string.format("%.2f", val)
        end
    end

    local function SetValue(val, skipCallback)
        val = math.max(container.min, math.min(container.max, val))
        if container.step >= 1 then
            val = math.floor(val / container.step + 0.5) * container.step
        else
            local mult = 1 / container.step
            val = math.floor(val * mult + 0.5) / mult
        end

        container.value = val
        slider:SetValue(val)
        editBox:SetText(FormatVal(val))
        UpdateTrackFill(val)

        if dbTable and dbKey then dbTable[dbKey] = val end
        if onChange and not skipCallback then onChange(val) end
    end

    container.GetValue = GetValue
    container.SetValue = SetValue

    -- Slider drag callback
    slider:SetScript("OnValueChanged", function(self, value)
        if container.step >= 1 then
            value = math.floor(value / container.step + 0.5) * container.step
        else
            local mult = 1 / container.step
            value = math.floor(value * mult + 0.5) / mult
        end
        editBox:SetText(FormatVal(value))
        container.value = value
        UpdateTrackFill(value)
        if dbTable and dbKey then dbTable[dbKey] = value end

        -- If deferOnDrag, only call onChange when not dragging (or on release)
        if deferOnDrag then
            if not isDragging then
                if onChange then onChange(value) end
            end
        else
            if onChange then onChange(value) end
        end
    end)

    -- Track mouse down/up for deferOnDrag mode
    slider:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            isDragging = true
        end
    end)

    slider:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and isDragging then
            isDragging = false
            if deferOnDrag and onChange then
                local value = self:GetValue()
                if container.step >= 1 then
                    value = math.floor(value / container.step + 0.5) * container.step
                else
                    local mult = 1 / container.step
                    value = math.floor(value * mult + 0.5) / mult
                end
                onChange(value)
            end
        end
    end)

    -- Hover effects (scale up circle thumb slightly)
    slider:SetScript("OnEnter", function()
        thumbCircle:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    slider:SetScript("OnLeave", function()
        thumbCircle:SetVertexColor(C.sliderThumb[1], C.sliderThumb[2], C.sliderThumb[3], 1)
    end)

    editBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then SetValue(val) end
        self:ClearFocus()
    end)

    editBox:SetScript("OnEscapePressed", function(self)
        editBox:SetText(FormatVal(GetValue()))
        self:ClearFocus()
    end)

    -- Hover effect on editbox
    editBox:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    editBox:SetScript("OnLeave", function(self)
        if not self:HasFocus() then
            self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end
    end)

    -- Initialize after a brief delay to ensure width is calculated
    C_Timer.After(0, function()
        SetValue(GetValue(), true)
    end)

    return container
end

---------------------------------------------------------------------------
-- WIDGET: DROPDOWN (Matches slider width with same 35px inset, same height for alignment)
---------------------------------------------------------------------------
local CHEVRON_ZONE_WIDTH = L.dropdown.chevronWidth
local CHEVRON_BG_ALPHA = 0.15
local CHEVRON_BG_ALPHA_HOVER = 0.25
local CHEVRON_TEXT_ALPHA = 0.7

function GUI:CreateDropdown(parent, label, options, dbKey, dbTable, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(L.dropdown.containerHeight)  -- Match slider height for vertical alignment
    container:SetWidth(L.dropdown.containerWidth)  -- Default width, can be overridden by SetWidth()

    -- Label on top (if provided) - mint green like slider labels, centered
    if label and label ~= "" then
        local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFont(text, L.font.small, "", C.accentLight)  -- Mint green like other labels
        text:SetText(label)
        text:SetPoint("TOP", container, "TOP", 0, 0)  -- Centered
    end

    -- Dropdown button (same width as slider track - inset 35px on each side)
    local dropdown = CreateFrame("Button", nil, container, "BackdropTemplate")
    dropdown:SetHeight(L.dropdown.height)  -- Increased from 20 for better tap target
    dropdown:SetPoint("TOPLEFT", container, "TOPLEFT", L.dropdown.inset, L.dropdown.offsetY)
    dropdown:SetPoint("RIGHT", container, "RIGHT", -L.dropdown.inset, 0)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    dropdown:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)  -- Increased from 0.25 for better visibility

    -- Chevron zone (right side with accent tint)
    local chevronZone = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    chevronZone:SetWidth(CHEVRON_ZONE_WIDTH)
    chevronZone:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -1, -1)
    chevronZone:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -1, 1)
    chevronZone:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA)

    -- Separator line (left edge of chevron zone)
    local separator = chevronZone:CreateTexture(nil, "ARTWORK")
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", chevronZone, "TOPLEFT", 0, 0)
    separator:SetPoint("BOTTOMLEFT", chevronZone, "BOTTOMLEFT", 0, 0)
    separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)

    -- Line chevron (two angled lines forming a V pointing DOWN)
    local chevronLeft = chevronZone:CreateTexture(nil, "OVERLAY")
    chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    chevronLeft:SetSize(7, 2)
    chevronLeft:SetPoint("CENTER", chevronZone, "CENTER", -2, -1)
    chevronLeft:SetRotation(math.rad(-45))

    local chevronRight = chevronZone:CreateTexture(nil, "OVERLAY")
    chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    chevronRight:SetSize(7, 2)
    chevronRight:SetPoint("CENTER", chevronZone, "CENTER", 2, -1)
    chevronRight:SetRotation(math.rad(45))

    dropdown.chevronLeft = chevronLeft
    dropdown.chevronRight = chevronRight
    dropdown.chevronZone = chevronZone
    dropdown.separator = separator

    -- Selected text - centered, accounting for chevron zone
    dropdown.selected = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(dropdown.selected, L.font.small, "", C.text)
    dropdown.selected:SetPoint("LEFT", 8, 0)
    dropdown.selected:SetPoint("RIGHT", chevronZone, "LEFT", -5, 0)
    dropdown.selected:SetJustifyH("CENTER")

    -- Hover effect
    dropdown:SetScript("OnEnter", function(self)
        pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
        chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA_HOVER)
        separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.5)
        chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    dropdown:SetScript("OnLeave", function(self)
        pcall(self.SetBackdropBorderColor, self, C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
        chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA)
        separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)
        chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
        chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    end)
    
    container.dropdown = dropdown
    
    -- Normalize options to {value, text} format
    local normalizedOptions = {}
    if type(options) == "table" then
        for i, opt in ipairs(options) do
            if type(opt) == "table" then
                normalizedOptions[i] = opt
            else
                -- Simple string array like {"Up", "Down"}
                normalizedOptions[i] = {value = opt:lower(), text = opt}
            end
        end
    end
    container.options = normalizedOptions
    
    local function GetValue()
        if dbTable and dbKey then return dbTable[dbKey] end
        return container.value
    end
    
    local function GetDisplayText(val)
        for _, opt in ipairs(container.options) do
            if opt.value == val then return opt.text end
        end
        -- If not found, capitalize first letter
        if type(val) == "string" then
            return val:sub(1,1):upper() .. val:sub(2)
        end
        return tostring(val or "Select...")
    end
    
    local function SetValue(val, skipCallback)
        container.value = val
        dropdown.selected:SetText(GetDisplayText(val))
        if dbTable and dbKey then dbTable[dbKey] = val end
        if onChange and not skipCallback then onChange(val) end
    end
    
    container.GetValue = GetValue
    container.SetValue = SetValue
    
    -- Initialize with current value
    SetValue(GetValue(), true)
    
    -- Dropdown menu frame (created once, reused)
    local menuFrame = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    menuFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menuFrame:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.98)
    menuFrame:SetBackdropBorderColor(unpack(C.accent))
    menuFrame:SetFrameStrata("TOOLTIP")
    menuFrame:Hide()
    
    local menuButtons = {}
    local buttonHeight = L.dropdown.menuItemHeight
    
    for i, opt in ipairs(container.options) do
        local btn = CreateFrame("Button", nil, menuFrame, "BackdropTemplate")
        btn:SetHeight(buttonHeight)
        btn:SetPoint("TOPLEFT", 2, -2 - (i-1) * buttonHeight)
        btn:SetPoint("TOPRIGHT", -2, -2 - (i-1) * buttonHeight)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFont(btn.text, L.font.small, "", C.text)
        btn.text:SetText(opt.text)
        btn.text:SetPoint("LEFT", 8, 0)
        
        btn:SetScript("OnEnter", function(self)
            pcall(function()
                self:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
                self:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 0.25)  -- Theme accent at 25% opacity
            end)
            -- Keep text white
        end)
        btn:SetScript("OnLeave", function(self)
            pcall(function()
                self:SetBackdrop(nil)
            end)
        end)
        btn:SetScript("OnClick", function()
            SetValue(opt.value)
            menuFrame:Hide()
        end)
        
        menuButtons[i] = btn
    end
    
    menuFrame:SetHeight(4 + #container.options * buttonHeight)
    
    -- Toggle menu on click
    dropdown:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            menuFrame:Show()
        end
    end)
    
    -- Close menu when clicking elsewhere (with delay to handle gap)
    local closeTimer = 0
    local CLOSE_DELAY = 0.15  -- 150ms grace period
    
    menuFrame:SetScript("OnShow", function()
        closeTimer = 0
        menuFrame.__checkElapsed = 0
        menuFrame:SetScript("OnUpdate", function(self, elapsed)
            -- Throttle checks to ~15 FPS (66ms) for CPU efficiency
            self.__checkElapsed = self.__checkElapsed + elapsed
            if self.__checkElapsed < 0.066 then return end
            local deltaTime = self.__checkElapsed
            self.__checkElapsed = 0

            -- Check if mouse is over dropdown button OR menu (with tolerance)
            local isOverDropdown = dropdown:IsMouseOver()
            local isOverMenu = self:IsMouseOver()

            -- Also check if mouse is in the gap between them
            local scale = dropdown:GetEffectiveScale()
            local mouseX, mouseY = GetCursorPosition()
            mouseX, mouseY = mouseX / scale, mouseY / scale

            local dLeft, dBottom, dWidth, dHeight = dropdown:GetRect()
            local mLeft, mBottom, mWidth, mHeight = self:GetRect()

            if dLeft and mLeft then
                -- Check if mouse X is within the dropdown/menu horizontal bounds
                local inHorizontalBounds = mouseX >= dLeft and mouseX <= (dLeft + dWidth)
                -- Check if mouse Y is between the bottom of dropdown and top of menu (the gap)
                local inGap = mouseY >= mBottom and mouseY <= (dBottom + dHeight) and inHorizontalBounds

                if isOverDropdown or isOverMenu or inGap then
                    closeTimer = 0
                else
                    closeTimer = closeTimer + deltaTime
                    if closeTimer > CLOSE_DELAY then
                        self:Hide()
                    end
                end
            else
                -- Fallback if GetRect fails
                if not isOverDropdown and not isOverMenu then
                    closeTimer = closeTimer + deltaTime
                    if closeTimer > CLOSE_DELAY then
                        self:Hide()
                    end
                else
                    closeTimer = 0
                end
            end
        end)
    end)
    
    menuFrame:SetScript("OnHide", function()
        menuFrame:SetScript("OnUpdate", nil)
        closeTimer = 0
    end)
    
    return container
end

---------------------------------------------------------------------------
-- WIDGET: DROPDOWN FULL WIDTH (For pages like Spec Profiles - no inset)
---------------------------------------------------------------------------
function GUI:CreateDropdownFullWidth(parent, label, options, dbKey, dbTable, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(L.dropdown.fullWidthContainerHeight)  -- Compact height for full-width dropdowns
    container:SetWidth(L.dropdown.containerWidth)  -- Default width, can be overridden by SetWidth()

    -- Label on top (if provided) - mint green, centered
    if label and label ~= "" then
        local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFont(text, L.font.small, "", C.accentLight)
        text:SetText(label)
        text:SetPoint("TOP", container, "TOP", 0, 0)
    end

    -- Dropdown button (full width, no inset)
    local dropdown = CreateFrame("Button", nil, container, "BackdropTemplate")
    dropdown:SetHeight(L.dropdown.height)
    dropdown:SetPoint("TOPLEFT", container, "TOPLEFT", 0, L.dropdown.fullWidthYOffset)
    dropdown:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    dropdown:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)  -- Increased from 0.25

    -- Chevron zone (right side with accent tint)
    local chevronZone = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    chevronZone:SetWidth(CHEVRON_ZONE_WIDTH)
    chevronZone:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -1, -1)
    chevronZone:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -1, 1)
    chevronZone:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA)

    -- Separator line (left edge of chevron zone)
    local separator = chevronZone:CreateTexture(nil, "ARTWORK")
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", chevronZone, "TOPLEFT", 0, 0)
    separator:SetPoint("BOTTOMLEFT", chevronZone, "BOTTOMLEFT", 0, 0)
    separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)

    -- Line chevron (two angled lines forming a V pointing DOWN)
    local chevronLeft = chevronZone:CreateTexture(nil, "OVERLAY")
    chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    chevronLeft:SetSize(7, 2)
    chevronLeft:SetPoint("CENTER", chevronZone, "CENTER", -2, -1)
    chevronLeft:SetRotation(math.rad(-45))

    local chevronRight = chevronZone:CreateTexture(nil, "OVERLAY")
    chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    chevronRight:SetSize(7, 2)
    chevronRight:SetPoint("CENTER", chevronZone, "CENTER", 2, -1)
    chevronRight:SetRotation(math.rad(45))

    dropdown.chevronLeft = chevronLeft
    dropdown.chevronRight = chevronRight
    dropdown.chevronZone = chevronZone
    dropdown.separator = separator

    -- Selected text - centered, accounting for chevron zone
    dropdown.selected = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(dropdown.selected, L.font.small, "", C.text)
    dropdown.selected:SetPoint("LEFT", 10, 0)
    dropdown.selected:SetPoint("RIGHT", chevronZone, "LEFT", -5, 0)
    dropdown.selected:SetJustifyH("CENTER")

    -- Hover effect
    dropdown:SetScript("OnEnter", function(self)
        pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
        chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA_HOVER)
        separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.5)
        chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    dropdown:SetScript("OnLeave", function(self)
        pcall(self.SetBackdropBorderColor, self, C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
        chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA)
        separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)
        chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
        chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    end)

    container.dropdown = dropdown

    -- Normalize options
    local normalizedOptions = {}
    if type(options) == "table" then
        for i, opt in ipairs(options) do
            if type(opt) == "table" then
                normalizedOptions[i] = opt
            else
                normalizedOptions[i] = {value = opt:lower(), text = opt}
            end
        end
    end
    container.options = normalizedOptions
    
    local function GetValue()
        if dbTable and dbKey then return dbTable[dbKey] end
        return container.value
    end
    
    local function GetDisplayText(val)
        for _, opt in ipairs(container.options) do
            if opt.value == val then return opt.text end
        end
        if type(val) == "string" then
            return val:sub(1,1):upper() .. val:sub(2)
        end
        return tostring(val or "Select...")
    end
    
    local function SetValue(val, skipCallback)
        container.value = val
        dropdown.selected:SetText(GetDisplayText(val))
        if dbTable and dbKey then dbTable[dbKey] = val end
        if onChange and not skipCallback then onChange(val) end
    end
    
    container.GetValue = GetValue
    container.SetValue = SetValue
    SetValue(GetValue(), true)
    
    -- Dropdown menu
    local menuFrame = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    menuFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menuFrame:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.98)
    menuFrame:SetBackdropBorderColor(unpack(C.accent))
    menuFrame:SetFrameStrata("TOOLTIP")
    menuFrame:Hide()
    
    local buttonHeight = L.dropdown.menuItemHeight
    for i, opt in ipairs(container.options) do
        local btn = CreateFrame("Button", nil, menuFrame, "BackdropTemplate")
        btn:SetHeight(buttonHeight)
        btn:SetPoint("TOPLEFT", 2, -2 - (i-1) * buttonHeight)
        btn:SetPoint("TOPRIGHT", -2, -2 - (i-1) * buttonHeight)
        
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFont(btn.text, L.font.small, "", C.text)
        btn.text:SetText(opt.text)
        btn.text:SetPoint("LEFT", 8, 0)
        
        btn:SetScript("OnEnter", function(self)
            pcall(function()
                self:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
                self:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 0.25)  -- Theme accent at 25% opacity
            end)
            -- Keep text white
        end)
        btn:SetScript("OnLeave", function(self)
            pcall(function() self:SetBackdrop(nil) end)
        end)
        btn:SetScript("OnClick", function()
            SetValue(opt.value)
            menuFrame:Hide()
        end)
    end
    
    menuFrame:SetHeight(4 + #container.options * buttonHeight)
    
    dropdown:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            menuFrame:Show()
        end
    end)
    
    -- Close menu when clicking elsewhere
    local closeTimer = 0
    menuFrame:SetScript("OnShow", function()
        closeTimer = 0
        menuFrame.__checkElapsed = 0
        menuFrame:SetScript("OnUpdate", function(self, elapsed)
            -- Throttle checks to ~15 FPS (66ms) for CPU efficiency
            self.__checkElapsed = self.__checkElapsed + elapsed
            if self.__checkElapsed < 0.066 then return end
            local deltaTime = self.__checkElapsed
            self.__checkElapsed = 0

            local isOverDropdown = dropdown:IsMouseOver()
            local isOverMenu = self:IsMouseOver()
            if not isOverDropdown and not isOverMenu then
                closeTimer = closeTimer + deltaTime
                if closeTimer > 0.15 then
                    self:Hide()
                end
            else
                closeTimer = 0
            end
        end)
    end)

    menuFrame:SetScript("OnHide", function()
        menuFrame:SetScript("OnUpdate", nil)
        closeTimer = 0
    end)

    return container
end

---------------------------------------------------------------------------
-- FORM WIDGETS (Label on left, widget on right)
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- WIDGET: iOS-STYLE TOGGLE SWITCH (Premium)
-- Track: Fully rounded pill shape
-- OFF: Dark grey track, white circle on left
-- ON: Accent track, white circle slides to right
---------------------------------------------------------------------------
function GUI:CreateFormToggle(parent, label, dbKey, dbTable, onChange, registryInfo)
    if parent._hasContent ~= nil then parent._hasContent = true end
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(L.formRowHeight)

    -- Label on left (off-white text)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Option")
    text:SetPoint("LEFT", 0, 0); text:SetPoint("RIGHT", container, "LEFT", 210, 0)  -- Constrain label width to avoid overlap
    text:SetJustifyH("LEFT")

    -- Toggle track (pill-shaped)
    local track = CreateFrame("Button", nil, container)
    track:SetSize(L.toggle.width, L.toggle.height)
    track:SetPoint("LEFT", container, "LEFT", L.formControlStart, 0)
    local trackPill = CreatePill(track, "BACKGROUND", 0)
    trackPill:Anchor(L.toggle.height)

    -- Thumb (circle)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetSize(L.toggle.thumbSize, L.toggle.thumbSize)
    thumb:SetFrameLevel(track:GetFrameLevel() + 1)
    local thumbTex = CreateCircle(thumb, "ARTWORK")
    thumbTex:SetAllPoints()
    thumbTex:SetVertexColor(C.toggleThumb[1], C.toggleThumb[2], C.toggleThumb[3], 1)

    container.track = track
    container.thumb = thumb
    container.label = text

    local function GetValue()
        if dbTable and dbKey then return dbTable[dbKey] end
        return container.checked
    end

    local function UpdateVisual(val)
        if val then
            -- ON state: Accent pill, thumb on right
            trackPill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
            thumb:ClearAllPoints()
            thumb:SetPoint("RIGHT", track, "RIGHT", -L.toggle.thumbInset, 0)
        else
            -- OFF state: Dark grey pill, thumb on left
            trackPill:SetVertexColor(C.toggleOff[1], C.toggleOff[2], C.toggleOff[3], 1)
            thumb:ClearAllPoints()
            thumb:SetPoint("LEFT", track, "LEFT", L.toggle.thumbInset, 0)
        end
    end

    local function SetValue(val, skipCallback)
        container.checked = val
        UpdateVisual(val)
        if dbTable and dbKey then dbTable[dbKey] = val end
        BroadcastToSiblings(container, val)
        if onChange and not skipCallback then onChange(val) end
    end

    container.GetValue = GetValue
    container.SetValue = SetValue
    container.UpdateVisual = UpdateVisual

    -- Register for cross-widget sync
    RegisterWidgetInstance(container, dbTable, dbKey)

    SetValue(GetValue(), true)  -- Skip callback on init

    -- Click to toggle
    track:SetScript("OnClick", function() SetValue(not GetValue()) end)

    -- Hover effects (brighten pill slightly)
    track:SetScript("OnEnter", function(self)
        if GetValue() then
            trackPill:SetVertexColor(C.accentHover[1], C.accentHover[2], C.accentHover[3], 1)
        else
            trackPill:SetVertexColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
        end
    end)
    track:SetScript("OnLeave", function(self)
        UpdateVisual(GetValue())
    end)

    -- Enable/disable the toggle (for conditional UI)
    container.SetEnabled = function(self, enabled)
        track:EnableMouse(enabled)
        -- Visual feedback: dim when disabled
        container:SetAlpha(enabled and 1 or 0.4)
    end

    -- Auto-register for search using current context (if context is set)
    if GUI._searchContext.tabIndex and label and not GUI._suppressSearchRegistration then
        local regKey = label .. "_" .. (GUI._searchContext.tabIndex or 0) .. "_" .. (GUI._searchContext.subTabIndex or 0)
        if not GUI.SettingsRegistryKeys[regKey] then
            GUI.SettingsRegistryKeys[regKey] = true
            local entry = {
                label = label,
                widgetType = "toggle",
                tabIndex = GUI._searchContext.tabIndex,
                tabName = GUI._searchContext.tabName,
                subTabIndex = GUI._searchContext.subTabIndex,
                subTabName = GUI._searchContext.subTabName,
                sectionName = GUI._searchContext.sectionName,
                widgetBuilder = function(p)
                    return GUI:CreateFormToggle(p, label, dbKey, dbTable, onChange)
                end,
            }
            -- Add keywords from registryInfo if provided
            if registryInfo and registryInfo.keywords then
                entry.keywords = registryInfo.keywords
            end
            table.insert(GUI.SettingsRegistry, entry)
        end
    end

    return container
end

-- Inverted toggle: checked = DB false, unchecked = DB true (for "Hide X" options)
function GUI:CreateFormToggleInverted(parent, label, dbKey, dbTable, onChange)
    if parent._hasContent ~= nil then parent._hasContent = true end
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(L.formRowHeight)

    -- Label on left (off-white text)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Option")
    text:SetPoint("LEFT", 0, 0); text:SetPoint("RIGHT", container, "LEFT", 210, 0)
    text:SetJustifyH("LEFT")

    -- Toggle track (pill-shaped)
    local track = CreateFrame("Button", nil, container)
    track:SetSize(L.toggle.width, L.toggle.height)
    track:SetPoint("LEFT", container, "LEFT", L.formControlStart, 0)
    local trackPill = CreatePill(track, "BACKGROUND", 0)
    trackPill:Anchor(L.toggle.height)

    -- Thumb (circle)
    local thumb = CreateFrame("Frame", nil, track)
    thumb:SetSize(L.toggle.thumbSize, L.toggle.thumbSize)
    thumb:SetFrameLevel(track:GetFrameLevel() + 1)
    local thumbTex = CreateCircle(thumb, "ARTWORK")
    thumbTex:SetAllPoints()
    thumbTex:SetVertexColor(C.toggleThumb[1], C.toggleThumb[2], C.toggleThumb[3], 1)

    container.track = track
    container.thumb = thumb
    container.label = text

    -- INVERTED: DB true = toggle OFF, DB false = toggle ON
    local function GetDBValue()
        if dbTable and dbKey then return dbTable[dbKey] end
        return true
    end

    local function IsOn()
        return not GetDBValue()
    end

    local function UpdateVisual(isOn)
        if isOn then
            trackPill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
            thumb:ClearAllPoints()
            thumb:SetPoint("RIGHT", track, "RIGHT", -L.toggle.thumbInset, 0)
        else
            trackPill:SetVertexColor(C.toggleOff[1], C.toggleOff[2], C.toggleOff[3], 1)
            thumb:ClearAllPoints()
            thumb:SetPoint("LEFT", track, "LEFT", L.toggle.thumbInset, 0)
        end
    end

    local function SetOn(isOn, skipCallback)
        container.checked = isOn
        local dbVal = not isOn
        UpdateVisual(isOn)
        if dbTable and dbKey then dbTable[dbKey] = dbVal end
        BroadcastToSiblings(container, isOn)
        if onChange and not skipCallback then onChange(dbVal) end
    end

    container.GetValue = IsOn
    container.SetValue = SetOn
    container.UpdateVisual = UpdateVisual

    RegisterWidgetInstance(container, dbTable, dbKey)

    SetOn(IsOn(), true)

    track:SetScript("OnClick", function() SetOn(not IsOn()) end)

    track:SetScript("OnEnter", function(self)
        if IsOn() then
            trackPill:SetVertexColor(C.accentHover[1], C.accentHover[2], C.accentHover[3], 1)
        else
            trackPill:SetVertexColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
        end
    end)
    track:SetScript("OnLeave", function(self)
        UpdateVisual(IsOn())
    end)

    container.SetEnabled = function(self, enabled)
        track:EnableMouse(enabled)
        container:SetAlpha(enabled and 1 or 0.4)
    end

    return container
end

---------------------------------------------------------------------------
-- WIDGET: FORM CHECKBOX (Now uses Toggle Switch style!)
---------------------------------------------------------------------------
function GUI:CreateFormCheckbox(parent, label, dbKey, dbTable, onChange, registryInfo)
    -- Redirect to toggle for the premium look
    return GUI:CreateFormToggle(parent, label, dbKey, dbTable, onChange, registryInfo)
end

-- Keep original checkbox available for multi-select scenarios
function GUI:CreateFormCheckboxOriginal(parent, label, dbKey, dbTable, onChange)
    if parent._hasContent ~= nil then parent._hasContent = true end
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(L.formRowHeight)

    -- Label on left (off-white text)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Option")
    text:SetPoint("LEFT", 0, 0); text:SetPoint("RIGHT", container, "LEFT", 210, 0)  -- Constrain label width to avoid overlap
    text:SetJustifyH("LEFT")

    -- Checkbox aligned with other widgets (starts at 180px from left)
    local box = CreateFrame("Button", nil, container, "BackdropTemplate")
    box:SetSize(L.checkbox.formSize, L.checkbox.formSize)
    box:SetPoint("LEFT", container, "LEFT", L.formControlStart, 0)
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    box:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)

    -- Checkmark
    box.check = box:CreateTexture(nil, "OVERLAY")
    box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box.check:SetPoint("CENTER", 0, 0)
    box.check:SetSize(L.checkbox.formCheckSize, L.checkbox.formCheckSize)
    box.check:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    box.check:SetDesaturated(true)
    box.check:Hide()

    container.box = box
    container.label = text

    local function GetValue()
        if dbTable and dbKey then return dbTable[dbKey] end
        return container.checked
    end

    local function UpdateVisual(val)
        if val then
            box.check:Show()
            box:SetBackdropBorderColor(unpack(C.accent))
            box:SetBackdropColor(0.20, 0.16, 0.22, 1)
        else
            box.check:Hide()
            box:SetBackdropBorderColor(unpack(C.border))
            box:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
        end
    end

    local function SetValue(val, skipCallback)
        container.checked = val
        UpdateVisual(val)
        if dbTable and dbKey then dbTable[dbKey] = val end
        BroadcastToSiblings(container, val)
        if onChange and not skipCallback then onChange(val) end
    end

    container.GetValue = GetValue
    container.SetValue = SetValue
    container.UpdateVisual = UpdateVisual

    -- Register for cross-widget sync
    RegisterWidgetInstance(container, dbTable, dbKey)

    SetValue(GetValue(), true)

    box:SetScript("OnClick", function() SetValue(not GetValue()) end)
    box:SetScript("OnEnter", function(self) pcall(self.SetBackdropBorderColor, self, unpack(C.accentHover)) end)
    box:SetScript("OnLeave", function(self)
        if GetValue() then
            pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
        else
            pcall(self.SetBackdropBorderColor, self, unpack(C.border))
        end
    end)

    return container
end

-- Form Checkbox Inverted: checked = DB false, unchecked = DB true (for "Hide X" options)
function GUI:CreateFormCheckboxInverted(parent, label, dbKey, dbTable, onChange)
    -- Redirect to toggle inverted for the premium look
    return GUI:CreateFormToggleInverted(parent, label, dbKey, dbTable, onChange)
end

function GUI:CreateFormSlider(parent, label, min, max, step, dbKey, dbTable, onChange, options, registryInfo)
    if parent._hasContent ~= nil then parent._hasContent = true end
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(L.formRowHeight)
    container:EnableMouse(true)  -- Block clicks from passing through to frames behind

    options = options or {}
    local deferOnDrag = options.deferOnDrag or false
    local precision = options.precision
    local formatStr = precision and string.format("%%.%df", precision) or (step < 1 and "%.2f" or "%d")

    -- Label on left (off-white text)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Setting")
    text:SetPoint("LEFT", 0, 0); text:SetPoint("RIGHT", container, "LEFT", 210, 0)  -- Constrain label width to avoid overlap
    text:SetJustifyH("LEFT")
    container.label = text

    -- Track container (for the filled + unfilled portions)
    local trackContainer = CreateFrame("Frame", nil, container)
    trackContainer:SetHeight(L.slider.height)  -- Track height
    trackContainer:SetPoint("LEFT", container, "LEFT", L.formControlStart, 0)
    trackContainer:SetPoint("RIGHT", container, "RIGHT", -L.slider.rightInset, 0)

    -- Unfilled track (pill-shaped background)
    local trackBgPill = CreatePill(trackContainer, "BACKGROUND", 0)
    trackBgPill:Anchor(L.slider.height)
    trackBgPill:SetVertexColor(C.sliderTrack[1], C.sliderTrack[2], C.sliderTrack[3], 1)

    -- Filled track (accent pill from left to thumb)
    local trackFillPill = CreatePill(trackContainer, "BACKGROUND", 1)
    trackFillPill:Anchor(L.slider.height)
    trackFillPill:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    -- Compat shim: external code calls container.trackFill:SetWidth() — ignore it
    local trackFill = setmetatable({}, {__index = function() return function() end end})

    -- Actual slider (invisible, just for interaction)
    local slider = CreateFrame("Slider", nil, trackContainer)
    slider:SetAllPoints()
    slider:SetOrientation("HORIZONTAL")
    slider:SetHitRectInsets(0, 0, -10, -10)

    -- Thumb frame (circle)
    local thumbFrame = CreateFrame("Frame", nil, slider)
    thumbFrame:SetSize(14, 14)
    thumbFrame:SetFrameLevel(slider:GetFrameLevel() + 2)
    thumbFrame:EnableMouse(false)
    local thumbCircle = CreateCircle(thumbFrame, "ARTWORK")
    thumbCircle:SetAllPoints()
    thumbCircle:SetVertexColor(C.sliderThumb[1], C.sliderThumb[2], C.sliderThumb[3], 1)

    slider.thumbFrame = thumbFrame

    -- Hidden thumb texture for slider mechanics
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(14, 14)
    thumb:SetAlpha(0)

    -- Editbox for value (far right)
    local editBox = CreateFrame("EditBox", nil, container, "BackdropTemplate")
    editBox:SetSize(85, 22)
    editBox:SetPoint("RIGHT", 0, 0)
    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    editBox:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    editBox:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    editBox:SetFont(GetFontPath(), 11, "")
    editBox:SetTextColor(unpack(C.text))
    editBox:SetJustifyH("CENTER")
    editBox:SetAutoFocus(false)

    -- Configure slider
    slider:SetMinMaxValues(min or 0, max or 100)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)

    container.slider = slider
    container.editBox = editBox
    container.trackFill = trackFill
    container.thumbFrame = thumbFrame
    container.trackContainer = trackContainer
    container.min = min or 0
    container.max = max or 100
    container.step = step or 1

    local isDragging = false

    -- Update filled track and thumb position
    local function UpdateTrackFill(value)
        local minVal, maxVal = container.min, container.max
        local pct = (value - minVal) / (maxVal - minVal)
        pct = math.max(0, math.min(1, pct))

        local trackWidth = trackContainer:GetWidth()
        if trackWidth < 1 then return end
        trackFillPill:AnchorFill(L.slider.height, pct)

        local thumbX = pct * (trackWidth - 14) + 7
        thumbFrame:ClearAllPoints()
        thumbFrame:SetPoint("CENTER", trackContainer, "LEFT", thumbX, 0)
    end

    local function GetValue()
        if dbTable and dbKey then return dbTable[dbKey] or container.min end
        return container.value or container.min
    end

    local function UpdateVisual(val)
        val = math.max(container.min, math.min(container.max, val))
        if not precision then
            val = math.floor(val / container.step + 0.5) * container.step
        end
        slider:SetValue(val)
        editBox:SetText(string.format(formatStr, val))
        UpdateTrackFill(val)
    end

    local function SetValue(val, skipOnChange)
        val = math.max(container.min, math.min(container.max, val))
        if precision then
            local factor = 10 ^ precision
            val = math.floor(val * factor + 0.5) / factor
        else
            val = math.floor(val / container.step + 0.5) * container.step
        end
        container.value = val
        UpdateVisual(val)
        if dbTable and dbKey then dbTable[dbKey] = val end
        BroadcastToSiblings(container, val)
        if not skipOnChange and onChange then onChange(val) end
    end

    container.GetValue = GetValue
    container.SetValue = SetValue
    container.UpdateVisual = UpdateVisual

    -- Register for cross-widget sync
    RegisterWidgetInstance(container, dbTable, dbKey)

    slider:SetScript("OnValueChanged", function(self, value, userInput)
        -- Ignore user input if slider is disabled
        if userInput and container.isEnabled == false then return end

        value = math.floor(value / container.step + 0.5) * container.step
        editBox:SetText(string.format(formatStr, value))
        UpdateTrackFill(value)
        if dbTable and dbKey then dbTable[dbKey] = value end
        if userInput then
            BroadcastToSiblings(container, value)
            if deferOnDrag and isDragging then return end
            if onChange then onChange(value) end
        end
    end)

    slider:SetScript("OnMouseDown", function() isDragging = true end)
    slider:SetScript("OnMouseUp", function()
        if isDragging and deferOnDrag then
            isDragging = false
            if onChange then onChange(slider:GetValue()) end
        end
        isDragging = false
    end)

    -- Hover effects on thumb (tint circle)
    slider:SetScript("OnEnter", function()
        thumbCircle:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    slider:SetScript("OnLeave", function()
        thumbCircle:SetVertexColor(C.sliderThumb[1], C.sliderThumb[2], C.sliderThumb[3], 1)
    end)

    editBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText()) or container.min
        SetValue(val)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText(string.format(formatStr, GetValue()))
        self:ClearFocus()
    end)

    -- Hover effect on editbox
    editBox:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    editBox:SetScript("OnLeave", function(self)
        if not self:HasFocus() then
            self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end
    end)

    -- Re-update track fill when container size changes (fixes initial layout timing)
    trackContainer:SetScript("OnSizeChanged", function(self, width, height)
        if width and width > 0 then
            UpdateTrackFill(GetValue())
        end
    end)

    -- Initialize value (visual update will happen via OnSizeChanged when layout completes)
    SetValue(GetValue(), true)

    -- Enable/disable the slider (for conditional UI)
    -- Note: Uses self parameter for colon-call syntax (widget:SetEnabled(bool))
    container.SetEnabled = function(self, enabled)
        slider:EnableMouse(enabled)
        editBox:EnableMouse(enabled)
        editBox:SetEnabled(enabled)

        -- Store state for scripts to check
        container.isEnabled = enabled

        -- Visual feedback: dim when disabled (matches HUD Visibility pattern)
        container:SetAlpha(enabled and 1 or 0.4)
    end

    -- Initialize enabled state
    container.isEnabled = true

    -- Auto-register for search using current context (if context is set)
    if GUI._searchContext.tabIndex and label and not GUI._suppressSearchRegistration then
        local regKey = label .. "_" .. (GUI._searchContext.tabIndex or 0) .. "_" .. (GUI._searchContext.subTabIndex or 0)
        if not GUI.SettingsRegistryKeys[regKey] then
            GUI.SettingsRegistryKeys[regKey] = true
            table.insert(GUI.SettingsRegistry, {
                label = label,
                widgetType = "slider",
                tabIndex = GUI._searchContext.tabIndex,
                tabName = GUI._searchContext.tabName,
                subTabIndex = GUI._searchContext.subTabIndex,
                subTabName = GUI._searchContext.subTabName,
                sectionName = GUI._searchContext.sectionName,
                widgetBuilder = function(p)
                    return GUI:CreateFormSlider(p, label, min, max, step, dbKey, dbTable, onChange, options)
                end,
            })
        end
    end

    return container
end

function GUI:CreateFormDropdown(parent, label, options, dbKey, dbTable, onChange, registryInfo)
    if parent._hasContent ~= nil then parent._hasContent = true end
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(L.formRowHeight)

    -- Label on left (off-white text)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Setting")
    text:SetPoint("LEFT", 0, 0); text:SetPoint("RIGHT", container, "LEFT", 210, 0)  -- Constrain label width to avoid overlap
    text:SetJustifyH("LEFT")

    -- Dropdown button (right side)
    local dropdown = CreateFrame("Button", nil, container, "BackdropTemplate")
    dropdown:SetHeight(L.dropdown.height)
    dropdown:SetPoint("LEFT", container, "LEFT", L.formControlStart, 0)
    dropdown:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    dropdown:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    dropdown:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)  -- Increased from 0.25

    -- Chevron zone (right side with accent tint)
    local chevronZone = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    chevronZone:SetWidth(CHEVRON_ZONE_WIDTH)
    chevronZone:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -1, -1)
    chevronZone:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -1, 1)
    chevronZone:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA)

    -- Separator line (left edge of chevron zone)
    local separator = chevronZone:CreateTexture(nil, "ARTWORK")
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", chevronZone, "TOPLEFT", 0, 0)
    separator:SetPoint("BOTTOMLEFT", chevronZone, "BOTTOMLEFT", 0, 0)
    separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)

    -- Line chevron (two angled lines forming a V pointing DOWN)
    local chevronLeft = chevronZone:CreateTexture(nil, "OVERLAY")
    chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    chevronLeft:SetSize(7, 2)
    chevronLeft:SetPoint("CENTER", chevronZone, "CENTER", -2, -1)
    chevronLeft:SetRotation(math.rad(-45))

    local chevronRight = chevronZone:CreateTexture(nil, "OVERLAY")
    chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    chevronRight:SetSize(7, 2)
    chevronRight:SetPoint("CENTER", chevronZone, "CENTER", 2, -1)
    chevronRight:SetRotation(math.rad(45))

    dropdown.chevronLeft = chevronLeft
    dropdown.chevronRight = chevronRight
    dropdown.chevronZone = chevronZone
    dropdown.separator = separator

    -- Selected text, accounting for chevron zone
    dropdown.selected = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(dropdown.selected, L.font.small, "", C.text)
    dropdown.selected:SetPoint("LEFT", 8, 0)
    dropdown.selected:SetPoint("RIGHT", chevronZone, "LEFT", -5, 0)
    dropdown.selected:SetJustifyH("LEFT")

    -- Hover effect
    dropdown:SetScript("OnEnter", function(self)
        pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
        chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA_HOVER)
        separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.5)
        chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    dropdown:SetScript("OnLeave", function(self)
        pcall(self.SetBackdropBorderColor, self, C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
        chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA)
        separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)
        chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
        chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    end)

    -- Menu frame
    local menuFrame = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    menuFrame:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menuFrame:SetPoint("TOPRIGHT", dropdown, "BOTTOMRIGHT", 0, -2)
    menuFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menuFrame:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.98)
    menuFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    menuFrame:SetFrameStrata("TOOLTIP")
    menuFrame:SetClipsChildren(true)
    menuFrame:Hide()

    -- Scroll frame for long option lists
    local scrollFrame = CreateFrame("ScrollFrame", nil, menuFrame)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollFrame:EnableMouseWheel(true)

    -- Scroll content (child frame)
    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(menuFrame:GetWidth() or 200)
    scrollFrame:SetScrollChild(scrollContent)
    menuFrame.scrollContent = scrollContent

    -- Mouse wheel scrolling
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local currentScroll = self:GetVerticalScroll()
        local maxScroll = math.max(0, scrollContent:GetHeight() - menuFrame:GetHeight())
        local newScroll = currentScroll - (delta * 20)
        newScroll = math.max(0, math.min(newScroll, maxScroll))
        self:SetVerticalScroll(newScroll)
    end)

    -- Update scroll content width when menu opens
    menuFrame:SetScript("OnShow", function(self)
        scrollContent:SetWidth(self:GetWidth() - 2)
    end)

    container.dropdown = dropdown
    container.menuFrame = menuFrame
    container.options = options or {}

    local function GetValue()
        if dbTable and dbKey then return dbTable[dbKey] end
        return container.selectedValue
    end

    local function UpdateVisual(val)
        for _, opt in ipairs(container.options) do
            if opt.value == val then
                dropdown.selected:SetText(opt.text)
                break
            end
        end
    end

    local function SetValue(val, skipOnChange)
        container.selectedValue = val
        if dbTable and dbKey then dbTable[dbKey] = val end
        UpdateVisual(val)
        BroadcastToSiblings(container, val)
        if not skipOnChange and onChange then onChange(val) end
    end

    local function BuildMenu()
        -- Clear existing children from scroll content
        local scrollContent = menuFrame.scrollContent
        if scrollContent then
            for _, child in ipairs({scrollContent:GetChildren()}) do child:Hide() end
        end

        local yOff = -4
        local itemHeight = 20
        local maxVisibleItems = 8
        local numItems = #container.options

        for i, opt in ipairs(container.options) do
            local btn = CreateFrame("Button", nil, scrollContent or menuFrame)
            btn:SetHeight(itemHeight)
            btn:SetPoint("TOPLEFT", 4, yOff)
            btn:SetPoint("TOPRIGHT", -4, yOff)
            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            SetFont(btnText, 11, "", C.text)
            btnText:SetText(opt.text)
            btnText:SetPoint("LEFT", 4, 0)
            btn:SetScript("OnClick", function()
                SetValue(opt.value)
                menuFrame:Hide()
            end)
            btn:SetScript("OnEnter", function() btnText:SetTextColor(unpack(C.accent)) end)
            btn:SetScript("OnLeave", function() btnText:SetTextColor(unpack(C.text)) end)
            yOff = yOff - itemHeight
        end

        local totalHeight = math.abs(yOff) + 4
        local maxHeight = (maxVisibleItems * itemHeight) + 8

        -- Update scroll content height
        if scrollContent then
            scrollContent:SetHeight(totalHeight)
        end

        -- Set menu height (capped at maxHeight)
        menuFrame:SetHeight(math.min(totalHeight, maxHeight))
    end

    local function PositionMenu()
        local left = dropdown:GetLeft()
        local right = dropdown:GetRight()
        local top = dropdown:GetTop()
        local bottom = dropdown:GetBottom()
        if not left or not right or not top or not bottom then return end

        local scale = dropdown:GetEffectiveScale()
        local uiScale = UIParent:GetEffectiveScale()
        local leftScaled = left * scale / uiScale
        local rightScaled = right * scale / uiScale
        local topScaled = top * scale / uiScale
        local bottomScaled = bottom * scale / uiScale
        local menuHeight = menuFrame:GetHeight()
        local gap = 2

        menuFrame:SetParent(UIParent)
        menuFrame:SetFrameStrata("TOOLTIP")
        menuFrame:SetFrameLevel(1000)
        menuFrame:SetWidth(dropdown:GetWidth())
        menuFrame:ClearAllPoints()

        if (bottomScaled - menuHeight - gap) < 0 then
            menuFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", leftScaled, topScaled + gap)
            menuFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", rightScaled, topScaled + gap)
        else
            menuFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", leftScaled, bottomScaled - gap)
            menuFrame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", rightScaled, bottomScaled - gap)
        end
    end

    dropdown:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            BuildMenu()
            PositionMenu()
            menuFrame:Show()
        end
    end)

    local function SetOptions(newOptions)
        container.options = newOptions or {}
        -- Check if current value still exists in new options
        local currentVal = GetValue()
        local found = false
        for _, opt in ipairs(container.options) do
            if opt.value == currentVal then
                dropdown.selected:SetText(opt.text)
                found = true
                break
            end
        end
        if not found then
            dropdown.selected:SetText("")
            container.selectedValue = nil
            if dbTable and dbKey then dbTable[dbKey] = "" end
        end
    end

    container.GetValue = GetValue
    container.SetValue = SetValue
    container.SetOptions = SetOptions
    container.UpdateVisual = UpdateVisual

    -- Register for cross-widget sync
    RegisterWidgetInstance(container, dbTable, dbKey)

    SetValue(GetValue(), true)

    -- Enable/disable the dropdown (for conditional UI)
    container.SetEnabled = function(self, enabled)
        dropdown:EnableMouse(enabled)
        container.isEnabled = enabled
        container:SetAlpha(enabled and 1 or 0.4)
    end
    container.isEnabled = true

    -- Auto-register for search using current context (if context is set)
    if GUI._searchContext.tabIndex and label and not GUI._suppressSearchRegistration then
        local regKey = label .. "_" .. (GUI._searchContext.tabIndex or 0) .. "_" .. (GUI._searchContext.subTabIndex or 0)
        if not GUI.SettingsRegistryKeys[regKey] then
            GUI.SettingsRegistryKeys[regKey] = true
            table.insert(GUI.SettingsRegistry, {
                label = label,
                widgetType = "dropdown",
                tabIndex = GUI._searchContext.tabIndex,
                tabName = GUI._searchContext.tabName,
                subTabIndex = GUI._searchContext.subTabIndex,
                subTabName = GUI._searchContext.subTabName,
                sectionName = GUI._searchContext.sectionName,
                widgetBuilder = function(p)
                    return GUI:CreateFormDropdown(p, label, options, dbKey, dbTable, onChange)
                end,
            })
        end
    end

    return container
end

function GUI:CreateFormDropdownWithTexturePreview(parent, label, dbKey, dbTable, onChange)
    if parent._hasContent ~= nil then parent._hasContent = true end
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(L.formRowHeight)

    -- Get texture display names from ResourceBars
    local TEXTURE_NAMES = (ns.ResourceBars and ns.ResourceBars.TEXTURE_DISPLAY_NAMES) or {}
    
    -- Helper function to get display name for a texture key
    local function GetTextureDisplayName(textureName)
        return TEXTURE_NAMES[textureName] or textureName
    end

    -- Label on left (off-white text)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Texture")
    text:SetPoint("LEFT", 0, 0)
    text:SetPoint("RIGHT", container, "LEFT", 210, 0)
    text:SetJustifyH("LEFT")

    -- Dropdown button (same style as CreateFormDropdown)
    local dropdown = CreateFrame("Button", nil, container, "BackdropTemplate")
    dropdown:SetHeight(L.dropdown.height)
    dropdown:SetPoint("LEFT", container, "LEFT", L.formControlStart, 0)
    dropdown:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    dropdown:SetBackdrop({
        bgFile = "Interface\\\\Buttons\\\\WHITE8x8",
        edgeFile = "Interface\\\\Buttons\\\\WHITE8x8",
        edgeSize = 1,
    })
    dropdown:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    dropdown:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)

    -- Chevron zone
    local CHEVRON_ZONE_WIDTH = 22
    local CHEVRON_BG_ALPHA = 0.15
    local CHEVRON_BG_ALPHA_HOVER = 0.25
    local CHEVRON_TEXT_ALPHA = 0.7
    
    local chevronZone = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    chevronZone:SetWidth(CHEVRON_ZONE_WIDTH)
    chevronZone:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -1, -1)
    chevronZone:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -1, 1)
    chevronZone:SetBackdrop({ bgFile = "Interface\\\\Buttons\\\\WHITE8x8" })
    chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA)

    local separator = chevronZone:CreateTexture(nil, "ARTWORK")
    separator:SetWidth(1)
    separator:SetPoint("TOPLEFT", chevronZone, "TOPLEFT", 0, 0)
    separator:SetPoint("BOTTOMLEFT", chevronZone, "BOTTOMLEFT", 0, 0)
    separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)

    local chevronLeft = chevronZone:CreateTexture(nil, "OVERLAY")
    chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    chevronLeft:SetSize(7, 2)
    chevronLeft:SetPoint("CENTER", chevronZone, "CENTER", -2, -1)
    chevronLeft:SetRotation(math.rad(-45))

    local chevronRight = chevronZone:CreateTexture(nil, "OVERLAY")
    chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    chevronRight:SetSize(7, 2)
    chevronRight:SetPoint("CENTER", chevronZone, "CENTER", 2, -1)
    chevronRight:SetRotation(math.rad(45))

    -- Selected text
    dropdown.selected = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(dropdown.selected, L.font.small, "", C.text)
    dropdown.selected:SetPoint("LEFT", 8, 0)
    dropdown.selected:SetPoint("RIGHT", chevronZone, "LEFT", -5, 0)
    dropdown.selected:SetJustifyH("LEFT")
    dropdown.selected:SetText(GetTextureDisplayName(dbTable[dbKey]) or "Select...")

    -- Hover effect
    dropdown:SetScript("OnEnter", function(self)
        pcall(self.SetBackdropBorderColor, self, unpack(C.accent))
        chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA_HOVER)
        separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.5)
        chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    dropdown:SetScript("OnLeave", function(self)
        pcall(self.SetBackdropBorderColor, self, C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)
        chevronZone:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], CHEVRON_BG_ALPHA)
        separator:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)
        chevronLeft:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
        chevronRight:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], CHEVRON_TEXT_ALPHA)
    end)

    -- Menu frame
    local menuFrame = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
    menuFrame:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menuFrame:SetPoint("TOPRIGHT", dropdown, "BOTTOMRIGHT", 0, -2)
    menuFrame:SetBackdrop({
        bgFile = "Interface\\\\Buttons\\\\WHITE8x8",
        edgeFile = "Interface\\\\Buttons\\\\WHITE8x8",
        edgeSize = 1,
    })
    menuFrame:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.98)
    menuFrame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    menuFrame:SetFrameStrata("TOOLTIP")
    menuFrame:SetClipsChildren(true)
    menuFrame:Hide()

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, menuFrame)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    scrollFrame:EnableMouseWheel(true)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(menuFrame:GetWidth() or 200)
    scrollFrame:SetScrollChild(scrollContent)
    menuFrame.scrollContent = scrollContent

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local currentScroll = self:GetVerticalScroll()
        local maxScroll = math.max(0, scrollContent:GetHeight() - menuFrame:GetHeight())
        local newScroll = currentScroll - (delta * 20)
        newScroll = math.max(0, math.min(newScroll, maxScroll))
        self:SetVerticalScroll(newScroll)
    end)

    menuFrame:SetScript("OnShow", function(self)
        scrollContent:SetWidth(self:GetWidth() - 2)
    end)

    -- Build menu with texture previews
    local function BuildMenu()
        if not LSM then return end

        -- Clear existing
        for _, child in ipairs({scrollContent:GetChildren()}) do child:Hide() end

        -- Get and sort textures
        local textures = LSM:HashTable(LSM.MediaType.STATUSBAR)
        local sortedTextures = {}
        for textureName in pairs(textures) do
            table.insert(sortedTextures, textureName)
        end
        table.sort(sortedTextures)

        local yOff = -4
        local itemHeight = 20
        local maxVisibleItems = 12
        local numItems = #sortedTextures

        for i, textureName in ipairs(sortedTextures) do
            local texturePath = textures[textureName]
            
            local btn = CreateFrame("Button", nil, scrollContent)
            btn:SetHeight(itemHeight)
            btn:SetPoint("TOPLEFT", 4, yOff)
            btn:SetPoint("TOPRIGHT", -4, yOff)
            
            -- Texture preview background
            local preview = btn:CreateTexture(nil, "BACKGROUND")
            preview:SetAllPoints()
            preview:SetTexture(texturePath)
            preview:SetAlpha(0.8)
            
            -- Text label (on top of texture)
            local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            SetFont(btnText, 11, "OUTLINE", C.textBright)
            btnText:SetText(GetTextureDisplayName(textureName))
            btnText:SetPoint("LEFT", 4, 0)
            btnText:SetShadowColor(0, 0, 0, 1)
            btnText:SetShadowOffset(1, -1)
            
            btn:SetScript("OnClick", function()
                dbTable[dbKey] = textureName
                dropdown.selected:SetText(GetTextureDisplayName(textureName))
                if onChange then onChange() end
                menuFrame:Hide()
            end)
            btn:SetScript("OnEnter", function()
                preview:SetAlpha(1)
                btnText:SetTextColor(1, 1, 0.3, 1)
            end)
            btn:SetScript("OnLeave", function()
                preview:SetAlpha(0.8)
                btnText:SetTextColor(unpack(C.textBright))
            end)
            
            yOff = yOff - itemHeight
        end

        local totalHeight = math.abs(yOff) + 4
        local maxHeight = (maxVisibleItems * itemHeight) + 8
        scrollContent:SetHeight(totalHeight)
        menuFrame:SetHeight(math.min(totalHeight, maxHeight))
    end

    local function PositionMenu()
        local left = dropdown:GetLeft()
        local right = dropdown:GetRight()
        local top = dropdown:GetTop()
        local bottom = dropdown:GetBottom()
        if not left or not right or not top or not bottom then return end

        local scale = dropdown:GetEffectiveScale()
        local uiScale = UIParent:GetEffectiveScale()
        local leftScaled = left * scale / uiScale
        local rightScaled = right * scale / uiScale
        local topScaled = top * scale / uiScale
        local bottomScaled = bottom * scale / uiScale
        local menuHeight = menuFrame:GetHeight()
        local gap = 2

        menuFrame:SetParent(UIParent)
        menuFrame:SetFrameStrata("TOOLTIP")
        menuFrame:SetFrameLevel(1000)
        menuFrame:SetWidth(dropdown:GetWidth())
        menuFrame:ClearAllPoints()

        if (bottomScaled - menuHeight - gap) < 0 then
            menuFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", leftScaled, topScaled + gap)
            menuFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", rightScaled, topScaled + gap)
        else
            menuFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", leftScaled, bottomScaled - gap)
            menuFrame:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", rightScaled, bottomScaled - gap)
        end
    end

    dropdown:SetScript("OnClick", function()
        if menuFrame:IsShown() then
            menuFrame:Hide()
        else
            BuildMenu()
            PositionMenu()
            menuFrame:Show()
        end
    end)

    container.dropdown = dropdown
    container.menuFrame = menuFrame
    return container
end

function GUI:CreateFormColorPicker(parent, label, dbKey, dbTable, onChange, options)
    options = options or {}
    local noAlpha = options.noAlpha or false

    if parent._hasContent ~= nil then parent._hasContent = true end
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(L.formRowHeight)

    -- Label on left (off-white text)
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(text, L.font.normal, "", C.text)
    text:SetText(label or "Color")
    text:SetPoint("LEFT", 0, 0); text:SetPoint("RIGHT", container, "LEFT", 210, 0)  -- Constrain label width to avoid overlap
    text:SetJustifyH("LEFT")

    -- Color swatch aligned with other widgets (starts at 180px from left)
    local swatch = CreateFrame("Button", nil, container, "BackdropTemplate")
    swatch:SetSize(L.colorPicker.formWidth, L.colorPicker.formHeight)
    swatch:SetPoint("LEFT", container, "LEFT", L.formControlStart, 0)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    swatch:SetBackdropBorderColor(C.borderLight[1], C.borderLight[2], C.borderLight[3], 1)

    container.swatch = swatch
    container.label = text

    local function GetColor()
        if dbTable and dbKey then
            local c = dbTable[dbKey]
            if c then return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1 end
        end
        return 1, 1, 1, 1
    end

    local function SetColor(r, g, b, a)
        local finalAlpha = noAlpha and 1 or (a or 1)
        swatch:SetBackdropColor(r, g, b, finalAlpha)
        if dbTable and dbKey then
            dbTable[dbKey] = {r, g, b, finalAlpha}
        end
        if onChange then onChange(r, g, b, finalAlpha) end
    end

    container.GetColor = GetColor
    container.SetColor = SetColor

    local r, g, b, a = GetColor()
    swatch:SetBackdropColor(r, g, b, a)

    swatch:SetScript("OnClick", function()
        local currentR, currentG, currentB, currentA = GetColor()
        local originalA = currentA
        ColorPickerFrame:SetupColorPickerAndShow({
            r = currentR, g = currentG, b = currentB, opacity = currentA,
            hasOpacity = not noAlpha,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = noAlpha and 1 or ColorPickerFrame:GetColorAlpha()
                SetColor(r, g, b, a)
            end,
            cancelFunc = function(prev)
                SetColor(prev.r, prev.g, prev.b, noAlpha and 1 or originalA)
            end,
        })
    end)

    swatch:SetScript("OnEnter", function(self) pcall(self.SetBackdropBorderColor, self, unpack(C.accent)) end)
    swatch:SetScript("OnLeave", function(self) pcall(self.SetBackdropBorderColor, self, C.borderLight[1], C.borderLight[2], C.borderLight[3], 1) end)

    -- Enable/disable (for conditional UI)
    container.SetEnabled = function(self, enabled)
        swatch:EnableMouse(enabled)
        container:SetAlpha(enabled and 1 or 0.4)
    end

    -- Auto-register for search using current context (if context is set)
    if GUI._searchContext.tabIndex and label and not GUI._suppressSearchRegistration then
        local regKey = label .. "_" .. (GUI._searchContext.tabIndex or 0) .. "_" .. (GUI._searchContext.subTabIndex or 0)
        if not GUI.SettingsRegistryKeys[regKey] then
            GUI.SettingsRegistryKeys[regKey] = true
            table.insert(GUI.SettingsRegistry, {
                label = label,
                widgetType = "colorpicker",
                tabIndex = GUI._searchContext.tabIndex,
                tabName = GUI._searchContext.tabName,
                subTabIndex = GUI._searchContext.subTabIndex,
                subTabName = GUI._searchContext.subTabName,
                sectionName = GUI._searchContext.sectionName,
                widgetBuilder = function(p)
                    return GUI:CreateFormColorPicker(p, label, dbKey, dbTable, onChange, options)
                end,
            })
        end
    end

    return container
end

---------------------------------------------------------------------------
-- SEARCH FUNCTIONALITY
---------------------------------------------------------------------------
local SEARCH_DEBOUNCE = 0.15  -- 150ms debounce
local SEARCH_MIN_CHARS = 2    -- Minimum characters before searching
local SEARCH_MAX_RESULTS = 30 -- Cap results to prevent UI overload

-- Search timer reference (for cleanup)
GUI._searchTimer = nil

-- Create the search box widget for the top bar
function GUI:CreateSearchBox(parent)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(160, 20)
    container:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    container:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 1)
    container:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

    -- Search icon (magnifying glass character)
    local icon = container:CreateFontString(nil, "OVERLAY")
    SetFont(icon, 11, "", C.textMuted)
    icon:SetText("|TInterface\\Common\\UI-Searchbox-Icon:12:12:0:0|t")
    icon:SetPoint("LEFT", 6, 0)

    -- EditBox for search input
    local editBox = CreateFrame("EditBox", nil, container)
    editBox:SetPoint("LEFT", 24, 0)
    editBox:SetPoint("RIGHT", container, "RIGHT", -24, 0)
    editBox:SetHeight(16)
    editBox:SetAutoFocus(false)
    editBox:SetFont(GetFontPath(), 11, "")
    editBox:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    editBox:SetMaxLetters(50)

    -- Placeholder text
    local placeholder = editBox:CreateFontString(nil, "OVERLAY")
    SetFont(placeholder, 11, "", {C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.6})
    placeholder:SetText("Search settings...")
    placeholder:SetPoint("LEFT", 0, 0)

    -- Clear button (X)
    local clearBtn = CreateFrame("Button", nil, container)
    clearBtn:SetSize(14, 14)
    clearBtn:SetPoint("RIGHT", -4, 0)
    clearBtn:Hide()

    local clearText = clearBtn:CreateFontString(nil, "OVERLAY")
    SetFont(clearText, 12, "", C.textMuted)
    clearText:SetText("x")
    clearText:SetPoint("CENTER", 0, 0)

    clearBtn:SetScript("OnEnter", function()
        clearText:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    end)
    clearBtn:SetScript("OnLeave", function()
        clearText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
    end)
    clearBtn:SetScript("OnClick", function()
        editBox:SetText("")
        editBox:ClearFocus()
        -- OnTextChanged handler will trigger result clearing
    end)

    -- Text changed handler with debounce
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end

        local text = self:GetText()

        -- Show/hide placeholder and clear button
        placeholder:SetShown(text == "")
        clearBtn:SetShown(text ~= "")

        -- Cancel pending search timer
        if GUI._searchTimer then
            GUI._searchTimer:Cancel()
            GUI._searchTimer = nil
        end

        -- Debounce search execution (handled by parent via onSearch callback)
        if text:len() >= SEARCH_MIN_CHARS then
            GUI._searchTimer = C_Timer.NewTimer(SEARCH_DEBOUNCE, function()
                if container.onSearch then
                    container.onSearch(text)
                end
            end)
        elseif text == "" then
            if container.onClear then
                container.onClear()
            end
        end
    end)

    -- Focus effects
    editBox:SetScript("OnEditFocusGained", function()
        container:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    editBox:SetScript("OnEditFocusLost", function()
        container:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)

    -- ESC clears search
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
        if container.onClear then
            container.onClear()
        end
    end)

    -- Enter also clears focus (search already happened via debounce)
    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    container.editBox = editBox
    container.placeholder = placeholder
    container.clearBtn = clearBtn

    return container
end

-- Execute search against the settings registry (returns filtered results)
function GUI:ExecuteSearch(searchTerm)
    if not searchTerm or searchTerm:len() < SEARCH_MIN_CHARS then
        return {}
    end

    local results = {}
    local lowerSearch = searchTerm:lower()

    for _, entry in ipairs(self.SettingsRegistry) do
        local score = 0

        -- Label match (highest priority)
        local lowerLabel = (entry.label or ""):lower()
        if lowerLabel:find(lowerSearch, 1, true) then
            score = 100
            -- Bonus for starts-with match
            if lowerLabel:sub(1, lowerSearch:len()) == lowerSearch then
                score = score + 50
            end
        end

        -- Keyword match (secondary)
        if score == 0 and entry.keywords then
            for _, keyword in ipairs(entry.keywords) do
                if keyword:lower():find(lowerSearch, 1, true) then
                    score = 50
                    break
                end
            end
        end

        -- Section name matching removed - causes too many false positives

        if score > 0 then
            table.insert(results, {data = entry, score = score})
        end
    end

    -- Sort by score (highest first), then alphabetically
    table.sort(results, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return (a.data.label or "") < (b.data.label or "")
    end)

    -- Limit results
    if #results > SEARCH_MAX_RESULTS then
        for i = SEARCH_MAX_RESULTS + 1, #results do
            results[i] = nil
        end
    end

    return results
end

-- Render search results into a content frame (for Search tab)
function GUI:RenderSearchResults(content, results, searchTerm)
    if not content then return end

    -- Clear previous child frames (unregister from widget sync first)
    for _, child in ipairs({content:GetChildren()}) do
        UnregisterWidgetInstance(child)
        child:Hide()
        child:SetParent(nil)
    end

    -- Clear previous font strings
    if content._fontStrings then
        for _, fs in ipairs(content._fontStrings) do
            fs:Hide()
            fs:SetText("")
        end
    end
    content._fontStrings = {}

    -- Clear previous textures
    if content._textures then
        for _, tex in ipairs(content._textures) do
            tex:Hide()
        end
    end
    content._textures = {}

    local y = -10
    local PADDING = 15
    local FORM_ROW = 32

    -- No results message
    if not results or #results == 0 then
        if searchTerm and searchTerm ~= "" then
            local noResults = content:CreateFontString(nil, "OVERLAY")
            SetFont(noResults, 12, "", C.textMuted)
            noResults:SetText("No settings found for \"" .. searchTerm .. "\"")
            noResults:SetPoint("TOPLEFT", PADDING, y)
            table.insert(content._fontStrings, noResults)
            y = y - 30

            local tip = content:CreateFontString(nil, "OVERLAY")
            SetFont(tip, 10, "", {C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.7})
            tip:SetText("Try different keywords, or visit other tabs first to index their settings")
            tip:SetPoint("TOPLEFT", PADDING, y)
            table.insert(content._fontStrings, tip)
            y = y - 30
        else
            -- Empty state - show instructions
            local instructions = content:CreateFontString(nil, "OVERLAY")
            SetFont(instructions, 12, "", C.textMuted)
            instructions:SetText("Type at least 2 characters to search settings")
            instructions:SetPoint("TOPLEFT", PADDING, y)
            table.insert(content._fontStrings, instructions)
            y = y - 30

            local tip2 = content:CreateFontString(nil, "OVERLAY")
            SetFont(tip2, 10, "", {C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.7})
            tip2:SetText("Settings are indexed when you visit each tab")
            tip2:SetPoint("TOPLEFT", PADDING, y)
            table.insert(content._fontStrings, tip2)
            y = y - 20
        end

        content:SetHeight(math.abs(y) + 20)
        return
    end

    -- Group results by tab
    local groupedResults = {}
    local tabOrder = {}

    for _, result in ipairs(results) do
        local tabName = result.data.tabName or "Other"
        if not groupedResults[tabName] then
            groupedResults[tabName] = {}
            table.insert(tabOrder, tabName)
        end
        table.insert(groupedResults[tabName], result)
    end

    -- Suppress auto-registration while creating search result widgets
    GUI._suppressSearchRegistration = true

    -- Render grouped results with actual widgets
    for _, tabName in ipairs(tabOrder) do
        local group = groupedResults[tabName]

        -- Tab header
        local header = content:CreateFontString(nil, "OVERLAY")
        SetFont(header, 12, "", C.accentLight)
        header:SetText(tabName)
        header:SetPoint("TOPLEFT", PADDING, y)
        table.insert(content._fontStrings, header)
        y = y - 24

        -- Separator line under header
        local sep = content:CreateTexture(nil, "ARTWORK")
        sep:SetPoint("TOPLEFT", PADDING, y + 2)
        sep:SetSize(content:GetWidth() - (PADDING * 2), 1)
        sep:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.3)
        table.insert(content._textures, sep)
        y = y - 12

        -- Results in this group - create actual widgets
        for _, result in ipairs(group) do
            local entry = result.data

            if entry.widgetBuilder then
                local widget = entry.widgetBuilder(content)
                if widget then
                    widget:SetPoint("TOPLEFT", PADDING, y)
                    widget:SetPoint("RIGHT", content, "RIGHT", -PADDING, 0)
                    y = y - FORM_ROW
                end
            else
                -- Fallback: show label if no builder
                local fallbackLabel = content:CreateFontString(nil, "OVERLAY")
                SetFont(fallbackLabel, 11, "", C.textMuted)
                fallbackLabel:SetText(entry.label or "Unknown setting")
                fallbackLabel:SetPoint("TOPLEFT", PADDING, y)
                table.insert(content._fontStrings, fallbackLabel)
                y = y - 24
            end
        end

        y = y - 10  -- Gap between groups
    end

    -- Re-enable auto-registration
    GUI._suppressSearchRegistration = false

    content:SetHeight(math.abs(y) + 20)
end

-- Clear search results display
function GUI:ClearSearchInTab(content)
    self:RenderSearchResults(content, nil, nil)
end


---------------------------------------------------------------------------
-- MAIN OPTIONS FRAME (Sidebar Navigation)
---------------------------------------------------------------------------
function GUI:CreateMainFrame()
    if self.MainFrame then
        return self.MainFrame
    end

    local FRAME_HEIGHT = 850
    local TITLE_HEIGHT = 36
    local BOTTOM_HEIGHT = 40
    local SB = L.sidebar

    -- Load saved dimensions
    local savedWidth = SUI.SUICore and SUI.SUICore.db and SUI.SUICore.db.profile.configPanelWidth or L.panel.defaultWidth

    local frame = CreateFrame("Frame", "SuaviUI_Options", UIParent, "BackdropTemplate")
    frame:SetSize(savedWidth, FRAME_HEIGHT)
    frame:SetPoint("RIGHT", -50, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    CreateBackdrop(frame, C.bg, C.border)

    local savedAlpha = SUI.SUICore and SUI.SUICore.db and SUI.SUICore.db.profile.configPanelAlpha or 0.97
    frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], savedAlpha)

    self.MainFrame = frame

    ---------------------------------------------------------------------------
    -- TITLE BAR
    ---------------------------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(TITLE_HEIGHT)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(title, 14, "OUTLINE", C.accent)
    title:SetText("Suavi UI")
    title:SetPoint("TOPLEFT", 14, -10)

    local version = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(version, 10, "", C.textMuted)
    version:SetText("v" .. (ns.VERSION or "0.0.1"))
    version:SetPoint("LEFT", title, "RIGHT", 8, 0)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() frame:Hide() end)

    local titleSep = frame:CreateTexture(nil, "ARTWORK")
    titleSep:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT)
    titleSep:SetPoint("TOPRIGHT", 0, -TITLE_HEIGHT)
    titleSep:SetHeight(1)
    titleSep:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    ---------------------------------------------------------------------------
    -- SIDEBAR
    ---------------------------------------------------------------------------
    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", 0, -(TITLE_HEIGHT + 1))
    sidebar:SetPoint("BOTTOMLEFT", 0, BOTTOM_HEIGHT + 1)
    sidebar:SetWidth(SB.width)
    sidebar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    sidebar:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.95)
    sidebar:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0)
    frame.sidebar = sidebar

    -- Right edge line for sidebar
    local sidebarEdge = sidebar:CreateTexture(nil, "ARTWORK")
    sidebarEdge:SetPoint("TOPRIGHT", 0, 0)
    sidebarEdge:SetPoint("BOTTOMRIGHT", 0, 0)
    sidebarEdge:SetWidth(1)
    sidebarEdge:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    -- Search box in sidebar
    local searchContainer = CreateFrame("Frame", nil, sidebar, "BackdropTemplate")
    searchContainer:SetPoint("TOPLEFT", SB.padding, -SB.padding)
    searchContainer:SetPoint("TOPRIGHT", -SB.padding - 1, -SB.padding)
    searchContainer:SetHeight(SB.searchHeight)
    searchContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    searchContainer:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
    searchContainer:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)

    local searchIcon = searchContainer:CreateFontString(nil, "OVERLAY")
    SetFont(searchIcon, 10, "", C.textMuted)
    searchIcon:SetText("|TInterface\\Common\\UI-Searchbox-Icon:12:12:0:0|t")
    searchIcon:SetPoint("LEFT", 6, 0)

    local searchEditBox = CreateFrame("EditBox", nil, searchContainer)
    searchEditBox:SetPoint("LEFT", 22, 0)
    searchEditBox:SetPoint("RIGHT", -6, 0)
    searchEditBox:SetHeight(16)
    searchEditBox:SetAutoFocus(false)
    searchEditBox:SetFont(GetFontPath(), 10, "")
    searchEditBox:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    searchEditBox:SetMaxLetters(40)

    local searchPlaceholder = searchEditBox:CreateFontString(nil, "OVERLAY")
    SetFont(searchPlaceholder, 10, "", {C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.5})
    searchPlaceholder:SetText("Search...")
    searchPlaceholder:SetPoint("LEFT", 0, 0)

    searchEditBox:SetScript("OnEditFocusGained", function()
        searchContainer:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    searchEditBox:SetScript("OnEditFocusLost", function()
        searchContainer:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    searchEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    frame.searchEditBox = searchEditBox

    -- Nav scroll frame (below search)
    local navScroll = CreateFrame("ScrollFrame", nil, sidebar, "UIPanelScrollFrameTemplate")
    navScroll:SetPoint("TOPLEFT", SB.padding, -(SB.padding + SB.searchHeight + SB.searchGap))
    navScroll:SetPoint("BOTTOMRIGHT", -SB.padding - 1, SB.padding)

    local navScrollBar = navScroll.ScrollBar
    if navScrollBar then
        navScrollBar:SetPoint("TOPLEFT", navScroll, "TOPRIGHT", 0, -14)
        navScrollBar:SetPoint("BOTTOMLEFT", navScroll, "BOTTOMRIGHT", 0, 14)
        local navThumb = navScrollBar:GetThumbTexture()
        if navThumb then navThumb:SetColorTexture(C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.4) end
        local su = navScrollBar.ScrollUpButton or navScrollBar.Back
        local sd = navScrollBar.ScrollDownButton or navScrollBar.Forward
        if su then su:Hide(); su:SetAlpha(0) end
        if sd then sd:Hide(); sd:SetAlpha(0) end
    end

    local navContent = CreateFrame("Frame", nil, navScroll)
    navContent:SetWidth(SB.width - SB.padding * 2 - 14)
    navContent:SetHeight(1)
    navScroll:SetScrollChild(navContent)

    navScroll:SetScript("OnSizeChanged", function(self, w)
        navContent:SetWidth(w)
    end)

    frame.navContent = navContent

    ---------------------------------------------------------------------------
    -- CONTENT AREA (right of sidebar)
    ---------------------------------------------------------------------------
    local contentArea = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    contentArea:SetPoint("BOTTOMRIGHT", 0, BOTTOM_HEIGHT + 1)
    contentArea:EnableMouse(false)
    contentArea:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    contentArea:SetBackdropColor(C.bgContent[1], C.bgContent[2], C.bgContent[3], C.bgContent[4])
    contentArea:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0)

    frame.contentArea = contentArea

    ---------------------------------------------------------------------------
    -- NAVIGATION STATE
    ---------------------------------------------------------------------------
    frame.categories = {}       -- ordered list of category defs
    frame.pages = {}            -- flat list of all pages {name, builder, catIndex, frame, built}
    frame.navItems = {}         -- rendered nav item frames
    frame.activePage = nil      -- currently active page index
    frame._pageIndex = 0        -- auto-increment page index

    -- Legacy compatibility
    frame.tabs = {}
    frame.activeTab = nil

    ---------------------------------------------------------------------------
    -- BOTTOM PANEL
    ---------------------------------------------------------------------------
    local bottomPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bottomPanel:SetPoint("BOTTOMLEFT", 0, 0)
    bottomPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    bottomPanel:SetHeight(BOTTOM_HEIGHT)
    bottomPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bottomPanel:SetBackdropColor(C.bgDark[1], C.bgDark[2], C.bgDark[3], 0.95)
    bottomPanel:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0)

    -- Top border on bottom panel
    local bottomSep = bottomPanel:CreateTexture(nil, "ARTWORK")
    bottomSep:SetPoint("TOPLEFT", 0, 0)
    bottomSep:SetPoint("TOPRIGHT", 0, 0)
    bottomSep:SetHeight(1)
    bottomSep:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

    local function CreateBottomButton(text, callback)
        local btn = CreateFrame("Button", nil, bottomPanel, "BackdropTemplate")
        btn:SetSize(110, 26)
        btn:EnableMouse(true)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
        btn:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.8)

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        SetFont(btnText, 10, "", C.textMuted)
        btnText:SetText(text)
        btnText:SetPoint("CENTER")

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
            btnText:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.8)
            btnText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
        end)
        btn:SetScript("OnClick", callback)
        return btn
    end

    local cdmBtn = CreateBottomButton("CDM Settings", function()
        if CooldownViewerSettings then
            CooldownViewerSettings:SetShown(not CooldownViewerSettings:IsShown())
        else
            local CDMLoaded = C_AddOns.IsAddOnLoaded("CooldownManager")
            if not CDMLoaded then
                C_AddOns.EnableAddOn("CooldownManager")
                print("|cFFFF6AC1SuaviUI:|r Enabling Cooldown Manager... Please reload UI.")
            else
                print("|cFFFF6AC1SuaviUI:|r Cooldown Manager enabled but settings frame not found. Try /reload")
            end
        end
    end)
    cdmBtn:SetPoint("BOTTOMLEFT", bottomPanel, "BOTTOMLEFT", 8, 7)

    local editModeBtn = CreateBottomButton("Edit Mode", function()
        if EditModeManagerFrame then
            DEFAULT_CHAT_FRAME.editBox:SetText("/editmode")
            ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
        end
    end)
    editModeBtn:SetPoint("LEFT", cdmBtn, "RIGHT", 6, 0)

    local reloadBtn = CreateBottomButton("Reload UI", function() ReloadUI() end)
    reloadBtn:SetPoint("LEFT", editModeBtn, "RIGHT", 6, 0)

    -- Scale controls
    local function ApplyScale(value)
        value = math.max(0.8, math.min(1.5, value))
        value = math.floor(value * 20 + 0.5) / 20
        frame:SetScale(value)
        if SUI.SUICore and SUI.SUICore.db then
            SUI.SUICore.db.profile.configPanelScale = value
        end
        return value
    end

    local scaleLabel = bottomPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SetFont(scaleLabel, 9, "", C.textMuted)
    scaleLabel:SetText("Scale:")
    scaleLabel:SetPoint("BOTTOMRIGHT", bottomPanel, "BOTTOMRIGHT", -105, 12)

    local scaleEditBox = CreateFrame("EditBox", nil, bottomPanel, "BackdropTemplate")
    scaleEditBox:SetSize(32, 18)
    scaleEditBox:SetPoint("BOTTOMRIGHT", bottomPanel, "BOTTOMRIGHT", -68, 11)
    scaleEditBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    scaleEditBox:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
    scaleEditBox:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    scaleEditBox:SetFont(GetFontPath(), 9, "")
    scaleEditBox:SetTextColor(unpack(C.text))
    scaleEditBox:SetJustifyH("CENTER")
    scaleEditBox:SetAutoFocus(false)
    scaleEditBox:SetMaxLetters(4)

    local scaleSlider = CreateFrame("Slider", nil, bottomPanel, "BackdropTemplate")
    scaleSlider:SetSize(50, 10)
    scaleSlider:SetPoint("BOTTOMRIGHT", bottomPanel, "BOTTOMRIGHT", -12, 14)
    scaleSlider:SetOrientation("HORIZONTAL")
    scaleSlider:SetMinMaxValues(0.8, 1.5)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:EnableMouse(true)
    scaleSlider:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    scaleSlider:SetBackdropColor(C.border[1], C.border[2], C.border[3], 0.9)
    local sThumb = scaleSlider:CreateTexture(nil, "OVERLAY")
    sThumb:SetSize(8, 12)
    sThumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    scaleSlider:SetThumbTexture(sThumb)

    local savedScale = SUI.SUICore and SUI.SUICore.db and SUI.SUICore.db.profile.configPanelScale or 1.0
    scaleSlider:SetValue(savedScale)
    scaleEditBox:SetText(string.format("%.2f", savedScale))
    frame:SetScale(savedScale)

    local isDragging = false
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20
        scaleEditBox:SetText(string.format("%.2f", value))
        if not isDragging then ApplyScale(value) end
    end)
    scaleSlider:SetScript("OnMouseDown", function(_, btn) if btn == "LeftButton" then isDragging = true end end)
    scaleSlider:SetScript("OnMouseUp", function(self, btn)
        if btn == "LeftButton" and isDragging then isDragging = false; ApplyScale(self:GetValue()) end
    end)
    scaleEditBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then val = ApplyScale(val); scaleSlider:SetValue(val); self:SetText(string.format("%.2f", val)) end
        self:ClearFocus()
    end)
    scaleEditBox:SetScript("OnEscapePressed", function(self)
        self:SetText(string.format("%.2f", scaleSlider:GetValue())); self:ClearFocus()
    end)
    scaleEditBox:SetScript("OnEditFocusGained", function(self) pcall(self.SetBackdropBorderColor, self, unpack(C.accent)) end)
    scaleEditBox:SetScript("OnEditFocusLost", function(self)
        pcall(self.SetBackdropBorderColor, self, C.border[1], C.border[2], C.border[3], 1)
        if not tonumber(self:GetText()) then self:SetText(string.format("%.2f", scaleSlider:GetValue())) end
    end)

    ---------------------------------------------------------------------------
    -- RESIZE HANDLE
    ---------------------------------------------------------------------------
    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetSize(20, 20)
    resizeHandle:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeHandle:SetFrameLevel(frame:GetFrameLevel() + 10)

    local gripTexture = resizeHandle:CreateTexture(nil, "OVERLAY")
    gripTexture:SetAllPoints()
    gripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTexture:SetVertexColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.6)

    local gripHighlight = resizeHandle:CreateTexture(nil, "HIGHLIGHT")
    gripHighlight:SetAllPoints()
    gripHighlight:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    gripHighlight:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)

    local gripPushed = resizeHandle:CreateTexture(nil, "ARTWORK")
    gripPushed:SetAllPoints()
    gripPushed:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    gripPushed:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    gripPushed:Hide()

    resizeHandle:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            gripPushed:Show(); gripTexture:Hide()
            local left, top = frame:GetLeft(), frame:GetTop()
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            local cursorX, cursorY = GetCursorPosition()
            local scale = frame:GetEffectiveScale()
            self.startX = cursorX / scale; self.startY = cursorY / scale
            self.startWidth = frame:GetWidth(); self.startHeight = frame:GetHeight()
            self.isResizing = true; self._resizeElapsed = 0
            self:SetScript("OnUpdate", function(self, elapsed)
                if not self.isResizing then return end
                self._resizeElapsed = (self._resizeElapsed or 0) + elapsed
                if self._resizeElapsed < 0.016 then return end
                self._resizeElapsed = 0
                local cx, cy = GetCursorPosition()
                local s = frame:GetEffectiveScale()
                local nw = math.max(L.panel.minWidth, math.min(L.panel.maxWidth, self.startWidth + cx/s - self.startX))
                local nh = math.max(L.panel.minHeight, math.min(L.panel.maxHeight, self.startHeight + self.startY - cy/s))
                frame:SetSize(nw, nh)
            end)
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            gripPushed:Hide(); gripTexture:Show()
            self.isResizing = false; self:SetScript("OnUpdate", nil)
            if SUI.SUICore and SUI.SUICore.db then
                SUI.SUICore.db.profile.configPanelWidth = frame:GetWidth()
            end
        end
    end)
    resizeHandle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT"); GameTooltip:SetText("Drag to resize", 1, 1, 1); GameTooltip:Show()
    end)
    resizeHandle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.resizeHandle = resizeHandle

    ---------------------------------------------------------------------------
    -- SEARCH INTEGRATION
    ---------------------------------------------------------------------------
    local searchResultsPage = nil

    searchEditBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local text = self:GetText()
        searchPlaceholder:SetShown(text == "")

        if GUI._searchTimer then GUI._searchTimer:Cancel(); GUI._searchTimer = nil end

        if text:len() >= 2 then
            GUI._searchTimer = C_Timer.NewTimer(0.25, function()
                -- Force-load all pages for search indexing
                if not GUI._searchIndexBuilt then
                    GUI:ForceLoadAllTabs()
                    GUI._searchIndexBuilt = true
                end
                local results = GUI:ExecuteSearch(text)
                -- Show search results in content area
                if not searchResultsPage then
                    searchResultsPage = CreateFrame("Frame", nil, frame.contentArea)
                    searchResultsPage:SetAllPoints()
                    searchResultsPage:EnableMouse(false)

                    local sr = CreateFrame("ScrollFrame", nil, searchResultsPage, "UIPanelScrollFrameTemplate")
                    sr:SetPoint("TOPLEFT", 5, -5)
                    sr:SetPoint("BOTTOMRIGHT", -28, 5)
                    local sc = CreateFrame("Frame", nil, sr)
                    sc:SetWidth(sr:GetWidth())
                    sc:SetHeight(1)
                    sr:SetScrollChild(sc)
                    sr:SetScript("OnSizeChanged", function(self, w) sc:SetWidth(w) end)
                    local sb = sr.ScrollBar
                    if sb then
                        local t = sb:GetThumbTexture()
                        if t then t:SetColorTexture(C.textMuted[1], C.textMuted[2], C.textMuted[3], 0.4) end
                        local su2 = sb.ScrollUpButton or sb.Back
                        local sd2 = sb.ScrollDownButton or sb.Forward
                        if su2 then su2:Hide(); su2:SetAlpha(0) end
                        if sd2 then sd2:Hide(); sd2:SetAlpha(0) end
                    end
                    searchResultsPage._scrollContent = sc
                end
                -- Hide active page, show search results
                if frame.activePage and frame.pages[frame.activePage] and frame.pages[frame.activePage].frame then
                    frame.pages[frame.activePage].frame:Hide()
                end
                searchResultsPage:Show()
                frame._searchActive = true
                GUI:RenderSearchResults(searchResultsPage._scrollContent, results, text)
            end)
        elseif text == "" and frame._searchActive then
            -- Restore active page
            frame._searchActive = false
            if searchResultsPage then searchResultsPage:Hide() end
            if frame.activePage and frame.pages[frame.activePage] and frame.pages[frame.activePage].frame then
                frame.pages[frame.activePage].frame:Show()
            end
        end
    end)

    return frame
end

---------------------------------------------------------------------------
-- ADD CATEGORY (collapsible group in sidebar)
---------------------------------------------------------------------------
function GUI:AddCategory(frame, name)
    local cat = {
        name = name,
        expanded = true,
        pages = {},
        navItem = nil,
    }
    table.insert(frame.categories, cat)
    return cat
end

---------------------------------------------------------------------------
-- ADD PAGE (leaf item under a category, or top-level leaf if category is nil)
---------------------------------------------------------------------------
function GUI:AddPage(frame, categoryName, pageName, pageBuilderFunc)
    frame._pageIndex = frame._pageIndex + 1
    local index = frame._pageIndex

    local page = {
        name = pageName,
        builder = pageBuilderFunc,
        catIndex = nil,
        frame = nil,
        built = false,
        index = index,
    }

    -- Find category
    if categoryName then
        for i, cat in ipairs(frame.categories) do
            if cat.name == categoryName then
                page.catIndex = i
                table.insert(cat.pages, page)
                break
            end
        end
    end

    frame.pages[index] = page

    -- Legacy compatibility for search system
    frame.tabs[index] = { index = index, name = pageName }

    return index
end

---------------------------------------------------------------------------
-- RENDER SIDEBAR (rebuild nav items from categories/pages)
---------------------------------------------------------------------------
function GUI:RenderSidebar(frame)
    -- Hide existing nav items
    for _, item in ipairs(frame.navItems) do
        item:Hide()
    end
    wipe(frame.navItems)

    local navContent = frame.navContent
    local SB = L.sidebar
    local y = 0

    local function CreateNavItem(text, isCategory, isActive, pageIndex)
        local height = isCategory and SB.categoryHeight or SB.itemHeight
        local item = CreateFrame("Button", nil, navContent)
        item:SetHeight(height)
        item:SetPoint("TOPLEFT", 0, y)
        item:SetPoint("RIGHT", 0, 0)

        -- Active indicator bar (left edge, magenta)
        local activeBar = item:CreateTexture(nil, "OVERLAY")
        activeBar:SetPoint("TOPLEFT", 0, 0)
        activeBar:SetPoint("BOTTOMLEFT", 0, 0)
        activeBar:SetWidth(SB.activeBarWidth)
        activeBar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        activeBar:SetShown(isActive and not isCategory)
        item._activeBar = activeBar

        -- Hover highlight
        local highlight = item:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0)
        item._highlight = highlight

        -- Text
        local label = item:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local leftPad = isCategory and 4 or SB.indent
        label:SetPoint("LEFT", leftPad, 0)
        label:SetPoint("RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        item._label = label

        if isCategory then
            SetFont(label, 10, "", C.text)
            label:SetText(text:upper())
        else
            local textColor = isActive and C.accent or C.tabNormal
            SetFont(label, 11, "", textColor)
            label:SetText(text)
        end

        -- Chevron for categories
        if isCategory then
            local chevron = item:CreateFontString(nil, "OVERLAY")
            SetFont(chevron, 8, "", C.textMuted)
            chevron:SetPoint("LEFT", 4, 0)
            item._chevron = chevron
            -- Shift label right to make room for chevron
            label:SetPoint("LEFT", 16, 0)
        end

        -- Hover behavior
        item:SetScript("OnEnter", function(self)
            if not isCategory and pageIndex ~= frame.activePage then
                self._highlight:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.5)
                self._label:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
            elseif isCategory then
                self._highlight:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0.3)
            end
        end)
        item:SetScript("OnLeave", function(self)
            self._highlight:SetColorTexture(C.bgLight[1], C.bgLight[2], C.bgLight[3], 0)
            if not isCategory and pageIndex ~= frame.activePage then
                self._label:SetTextColor(C.tabNormal[1], C.tabNormal[2], C.tabNormal[3], 1)
            end
        end)

        item.pageIndex = pageIndex
        return item
    end

    -- Build nav from categories
    for catIdx, cat in ipairs(frame.categories) do
        -- Category header (only if multiple pages)
        if #cat.pages > 1 then
            if catIdx > 1 then y = y - SB.categorySpacing end

            local catItem = CreateNavItem(cat.name, true, false, nil)
            catItem._chevron:SetText(cat.expanded and "v" or ">")

            catItem:SetScript("OnClick", function()
                cat.expanded = not cat.expanded
                GUI:RenderSidebar(frame)
            end)

            table.insert(frame.navItems, catItem)
            y = y - SB.categoryHeight - SB.itemSpacing

            -- Pages under this category (only if expanded)
            if cat.expanded then
                for _, page in ipairs(cat.pages) do
                    local isActive = (page.index == frame.activePage)
                    local pageItem = CreateNavItem(page.name, false, isActive, page.index)

                    pageItem:SetScript("OnClick", function()
                        GUI:SelectPage(frame, page.index)
                    end)

                    table.insert(frame.navItems, pageItem)
                    y = y - SB.itemHeight - SB.itemSpacing
                end
            end
        else
            -- Single-page category: show as a leaf item
            if catIdx > 1 then y = y - SB.categorySpacing end
            local page = cat.pages[1]
            if page then
                local isActive = (page.index == frame.activePage)
                local leafItem = CreateNavItem(page.name, false, isActive, page.index)
                -- Style like a category (bolder) but clickable as page
                leafItem._label:SetPoint("LEFT", 4, 0)
                SetFont(leafItem._label, 11, "", isActive and C.accent or C.text)

                leafItem:SetScript("OnClick", function()
                    GUI:SelectPage(frame, page.index)
                end)

                table.insert(frame.navItems, leafItem)
                y = y - SB.itemHeight - SB.itemSpacing
            end
        end
    end

    navContent:SetHeight(math.abs(y) + 20)
end

---------------------------------------------------------------------------
-- SELECT PAGE
---------------------------------------------------------------------------
function GUI:SelectPage(frame, index)
    if not frame.pages[index] then return end

    -- Clear search if active
    if frame._searchActive then
        frame._searchActive = false
        if frame.searchEditBox then
            frame.searchEditBox:SetText("")
            frame.searchEditBox:ClearFocus()
        end
        -- Hide search results frame
        for _, child in ipairs({frame.contentArea:GetChildren()}) do
            if child ~= (frame.pages[frame.activePage] and frame.pages[frame.activePage].frame) then
                child:Hide()
            end
        end
    end

    -- Hide previous page
    if frame.activePage and frame.pages[frame.activePage] and frame.pages[frame.activePage].frame then
        frame.pages[frame.activePage].frame:Hide()
    end

    frame.activePage = index
    frame.activeTab = index  -- Legacy compatibility

    -- Create/show page
    local page = frame.pages[index]
    if not page.frame then
        page.frame = CreateFrame("Frame", nil, frame.contentArea)
        page.frame:SetAllPoints()
        page.frame:EnableMouse(false)
        if page.builder then
            page.builder(page.frame)
            page.built = true
        end
    end
    page.frame:Show()

    -- Fire OnShow on children for dynamic content refresh
    local function TriggerOnShow(f)
        if f.GetScript and f:GetScript("OnShow") then
            f:GetScript("OnShow")(f)
        end
        if f.GetChildren then
            for _, child in ipairs({f:GetChildren()}) do
                TriggerOnShow(child)
            end
        end
    end
    TriggerOnShow(page.frame)

    -- Update sidebar active state
    self:RenderSidebar(frame)
end

---------------------------------------------------------------------------
-- LEGACY: RelayoutTabs (no-op for backward compat with CreateSubTabs)
---------------------------------------------------------------------------
function GUI:RelayoutTabs(targetFrame)
    -- No-op: sidebar does not use tab grid layout
end

---------------------------------------------------------------------------
-- LEGACY: AddTab shim (maps to AddPage for backward compat during transition)
---------------------------------------------------------------------------
function GUI:AddTab(frame, name, pageCreateFunc)
    self:AddCategory(frame, name)
    local index = self:AddPage(frame, name, name, pageCreateFunc)
    -- Auto-select first page
    if frame._pageIndex == 1 then
        C_Timer.After(0, function()
            self:SelectPage(frame, 1)
        end)
    end
    return { index = index, name = name }
end

---------------------------------------------------------------------------
-- LEGACY: SelectTab shim
---------------------------------------------------------------------------
function GUI:SelectTab(frame, index)
    self:SelectPage(frame, index)
end

---------------------------------------------------------------------------
-- FINALIZE SIDEBAR (call after all pages registered)
---------------------------------------------------------------------------
function GUI:FinalizeSidebar(frame)
    self._allTabsAdded = true
    self:RenderSidebar(frame)
    -- Select first page if none selected
    if not frame.activePage and frame._pageIndex > 0 then
        self:SelectPage(frame, 1)
    end
end

---------------------------------------------------------------------------
-- SHOW FUNCTION
---------------------------------------------------------------------------
function GUI:Show()
    if not self.MainFrame then
        self:InitializeOptions()
    end
    self.MainFrame:Show()
end

---------------------------------------------------------------------------
-- HIDE FUNCTION
---------------------------------------------------------------------------
function GUI:Hide()
    if self.MainFrame then
        self.MainFrame:Hide()
    end
end

---------------------------------------------------------------------------
-- TOGGLE FUNCTION
---------------------------------------------------------------------------
function GUI:Toggle()
    if self.MainFrame and self.MainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Store reference
SUI.GUI = GUI








