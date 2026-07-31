---------------------------------------------------------------------------
-- SuaviUI Combat Timer
-- Displays elapsed time in combat (resets on combat exit)
-- Movable + configured via Edit Mode (LibEQOLEditMode-1.0)
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local SUI = ns.SUI or {}
ns.SUI = SUI

local LEM = LibStub("LibEQOLEditMode-1.0", true)

---------------------------------------------------------------------------
-- State tracking
---------------------------------------------------------------------------
local CombatTimerState = {
    combatStartTime = 0,
    timerFrame = nil,
    isInCombat = false,
    isPreviewMode = false,
    isInEncounter = false,  -- Track boss encounter state
}

local registeredWithLEM = false

---------------------------------------------------------------------------
-- Get settings from database (with one-time migration)
---------------------------------------------------------------------------
local function MigrateLegacyPosition(settings)
    if type(settings) ~= "table" then return end

    if type(settings.position) ~= "table" then
        settings.position = { point = "CENTER", x = 0, y = -150 }
    end
    settings.position.point = settings.position.point or "CENTER"
    settings.position.x = tonumber(settings.position.x) or 0
    settings.position.y = tonumber(settings.position.y) or -150

    -- Pre-Edit-Mode versions stored xOffset/yOffset directly. Fold them
    -- into the new position table once, then drop the legacy keys.
    if settings.xOffset ~= nil then
        settings.position.x = tonumber(settings.xOffset) or settings.position.x
        settings.xOffset = nil
    end
    if settings.yOffset ~= nil then
        settings.position.y = tonumber(settings.yOffset) or settings.position.y
        settings.yOffset = nil
    end
end

local function GetSettings()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.combatTimer then
        local s = SUICore.db.profile.combatTimer
        MigrateLegacyPosition(s)
        return s
    end
    return nil
end

---------------------------------------------------------------------------
-- Backdrop template with optional LSM border texture
---------------------------------------------------------------------------
local LSM = LibStub("LibSharedMedia-3.0", true)

local function GetBackdropInfo(borderTextureName, borderSize)
    local edgeFile = nil
    local edgeSize = 0

    -- Use LSM border texture if specified and not "None"
    if borderTextureName and borderTextureName ~= "None" and LSM then
        edgeFile = LSM:Fetch("border", borderTextureName)
        edgeSize = borderSize or 1
    end

    return {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = edgeFile,
        tile = false,
        tileSize = 0,
        edgeSize = edgeSize,
        insets = { left = 0, right = 1, top = 0, bottom = 1 },
    }
end

---------------------------------------------------------------------------
-- Create uniform border lines (for solid "None" border)
---------------------------------------------------------------------------
local function CreateBorderLines(frame)
    if frame.borderLines then return frame.borderLines end

    local borders = {}

    -- Use OVERLAY layer to render on top of backdrop, avoiding blend artifacts
    borders.top = frame:CreateTexture(nil, "OVERLAY")
    borders.top:SetColorTexture(0, 0, 0, 1)
    borders.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borders.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, 0)

    borders.bottom = frame:CreateTexture(nil, "OVERLAY")
    borders.bottom:SetColorTexture(0, 0, 0, 1)
    borders.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
    borders.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    borders.left = frame:CreateTexture(nil, "OVERLAY")
    borders.left:SetColorTexture(0, 0, 0, 1)
    borders.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borders.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)

    borders.right = frame:CreateTexture(nil, "OVERLAY")
    borders.right:SetColorTexture(0, 0, 0, 1)
    borders.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borders.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)

    frame.borderLines = borders
    return borders
end

local function UpdateBorderLines(frame, size, r, g, b, a, hide)
    local borders = frame.borderLines
    if not borders then return end

    -- Hide all if requested or size is 0
    if hide or size <= 0 then
        for _, line in pairs(borders) do
            line:Hide()
        end
        return
    end

    -- Set size and color
    borders.top:SetHeight(size)
    borders.bottom:SetHeight(size)
    borders.left:SetWidth(size)
    borders.right:SetWidth(size)

    borders.top:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    borders.bottom:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    borders.left:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
    borders.right:SetColorTexture(r or 0, g or 0, b or 0, a or 1)

    for _, line in pairs(borders) do
        line:Show()
    end
end

---------------------------------------------------------------------------
-- Get font path from LibSharedMedia
---------------------------------------------------------------------------
local function GetFontPath(fontName)
    if LSM and fontName then
        local path = LSM:Fetch("font", fontName)
        if path then return path end
    end
    return "Fonts\\FRIZQT__.TTF"
end

---------------------------------------------------------------------------
-- Position application (settings.position → SetPoint)
---------------------------------------------------------------------------
local function ApplyPosition(frame, settings)
    if not frame or not settings then return end
    local p = settings.position or { point = "CENTER", x = 0, y = -150 }
    frame:ClearAllPoints()
    frame:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x or 0, p.y or -150)
end

---------------------------------------------------------------------------
-- Create the timer frame (one-time setup)
---------------------------------------------------------------------------
local function CreateTimerFrame()
    if CombatTimerState.timerFrame then return end

    local frame = CreateFrame("Frame", "SuaviUI_CombatTimer", UIParent, "BackdropTemplate")
    frame:SetSize(80, 30)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(50)

    local s = GetSettings()
    if s then
        ApplyPosition(frame, s)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    end

    -- Set up backdrop (background only)
    frame:SetBackdrop(GetBackdropInfo())
    frame:SetBackdropColor(0, 0, 0, 0.6)

    -- Create manual border lines for uniform edges
    CreateBorderLines(frame)
    UpdateBorderLines(frame, 1, 0, 0, 0, 1)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    text:SetTextColor(1, 1, 1, 1)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetText("0:00")
    frame.text = text

    frame.editModeName = "Combat Timer"

    frame:Hide()
    CombatTimerState.timerFrame = frame
end

---------------------------------------------------------------------------
-- Format elapsed time as MM:SS
---------------------------------------------------------------------------
local function FormatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", mins, secs)
end

---------------------------------------------------------------------------
-- OnUpdate handler for timer
---------------------------------------------------------------------------
local function OnTimerUpdate(self, elapsed)
    if not CombatTimerState.isInCombat then return end

    local now = GetTime()
    local elapsedTime = now - CombatTimerState.combatStartTime

    if CombatTimerState.timerFrame and CombatTimerState.timerFrame.text then
        CombatTimerState.timerFrame.text:SetText(FormatTime(elapsedTime))
    end
end

---------------------------------------------------------------------------
-- Get global addon font setting
---------------------------------------------------------------------------
local function GetGlobalFont()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general and SUICore.db.profile.general.font then
        return SUICore.db.profile.general.font
    end
    return "Suavi"
end

---------------------------------------------------------------------------
-- Get player class color
---------------------------------------------------------------------------
local function GetClassColor()
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return {c.r, c.g, c.b, 1}
    end
    return {1, 1, 1, 1}  -- Fallback to white
end

---------------------------------------------------------------------------
-- Update timer appearance from settings
---------------------------------------------------------------------------
local function UpdateTimerAppearance()
    if not CombatTimerState.timerFrame then
        CreateTimerFrame()
    end

    local settings = GetSettings()
    if not settings then return end

    local frame = CombatTimerState.timerFrame

    -- Update size
    local width = settings.width or 80
    local height = settings.height or 30
    frame:SetSize(width, height)

    -- Update position from settings.position (managed by Edit Mode drag)
    ApplyPosition(frame, settings)

    -- Update font (using LSM) - check if using custom font or global
    local fontSize = settings.fontSize or 16
    local fontName = settings.useCustomFont and settings.font or GetGlobalFont()
    local fontPath = GetFontPath(fontName)
    frame.text:SetFont(fontPath, fontSize, "OUTLINE")

    -- Update text color (use class color or custom color)
    local textColor
    if settings.useClassColorText then
        textColor = GetClassColor()
    else
        textColor = settings.textColor or {1, 1, 1, 1}
    end
    frame.text:SetTextColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)

    -- Update backdrop and border
    local showBackdrop = settings.showBackdrop
    if showBackdrop == nil then showBackdrop = true end

    local borderSize = settings.borderSize or 1
    local borderTexture = settings.borderTexture or "None"
    local useLSMBorder = borderTexture ~= "None" and borderSize > 0

    -- Get border color
    local borderColor
    if settings.useClassColorBorder then
        borderColor = GetClassColor()
    else
        borderColor = settings.borderColor or {0, 0, 0, 1}
    end

    -- Set up backdrop with or without LSM border
    -- Skip LSM border if hideBorder is enabled
    local hideBorder = settings.hideBorder
    local effectiveUseLSMBorder = useLSMBorder and not hideBorder

    if showBackdrop or effectiveUseLSMBorder then
        frame:SetBackdrop(GetBackdropInfo(hideBorder and "None" or borderTexture, hideBorder and 0 or borderSize))

        if showBackdrop then
            local bgColor = settings.backdropColor or {0, 0, 0, 0.6}
            frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.6)
        else
            frame:SetBackdropColor(0, 0, 0, 0)
        end

        if effectiveUseLSMBorder then
            frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
        end
    else
        frame:SetBackdrop(nil)
    end

    -- Update manual border lines (only used when no LSM border is selected)
    -- Hide all borders if hideBorder is enabled
    CreateBorderLines(frame)  -- Ensure borders exist
    UpdateBorderLines(frame, borderSize, borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1, useLSMBorder or hideBorder)

    -- Ensure text is always centered
    frame.text:ClearAllPoints()
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 1)
end

---------------------------------------------------------------------------
-- Combat start handler
---------------------------------------------------------------------------
local function OnCombatStart()
    local settings = GetSettings()
    if not settings or not settings.enabled then return end

    -- Don't start combat timer if we're in preview mode
    if CombatTimerState.isPreviewMode then return end

    -- If encounters-only mode is enabled and we're not in an encounter, don't show
    if settings.onlyShowInEncounters and not CombatTimerState.isInEncounter then
        CombatTimerState.isInCombat = true  -- Track combat state but don't show timer
        return
    end

    CreateTimerFrame()
    UpdateTimerAppearance()

    CombatTimerState.combatStartTime = GetTime()
    CombatTimerState.isInCombat = true

    if CombatTimerState.timerFrame then
        CombatTimerState.timerFrame.text:SetText("00:00")
        CombatTimerState.timerFrame:Show()
        CombatTimerState.timerFrame:SetScript("OnUpdate", OnTimerUpdate)
    end
end

---------------------------------------------------------------------------
-- Combat end handler
---------------------------------------------------------------------------
local function OnCombatEnd()
    -- Don't hide if in preview mode
    if CombatTimerState.isPreviewMode then return end

    CombatTimerState.isInCombat = false

    if CombatTimerState.timerFrame then
        CombatTimerState.timerFrame:SetScript("OnUpdate", nil)
        CombatTimerState.timerFrame:Hide()
    end
end

---------------------------------------------------------------------------
-- Encounter start handler (boss encounters)
---------------------------------------------------------------------------
local function OnEncounterStart()
    local settings = GetSettings()
    if not settings or not settings.enabled then return end

    CombatTimerState.isInEncounter = true

    -- Don't interfere with preview mode
    if CombatTimerState.isPreviewMode then return end

    -- If encounters-only mode and we're in combat but timer not shown, show it now
    if settings.onlyShowInEncounters and CombatTimerState.isInCombat then
        CreateTimerFrame()
        UpdateTimerAppearance()

        CombatTimerState.combatStartTime = GetTime()

        if CombatTimerState.timerFrame then
            CombatTimerState.timerFrame.text:SetText("00:00")
            CombatTimerState.timerFrame:Show()
            CombatTimerState.timerFrame:SetScript("OnUpdate", OnTimerUpdate)
        end
    end
end

---------------------------------------------------------------------------
-- Encounter end handler
---------------------------------------------------------------------------
local function OnEncounterEnd()
    CombatTimerState.isInEncounter = false

    local settings = GetSettings()
    if not settings then return end

    -- Don't hide if in preview mode
    if CombatTimerState.isPreviewMode then return end

    -- If encounters-only mode is enabled, hide the timer when encounter ends
    -- (even if still in combat)
    if settings.onlyShowInEncounters and CombatTimerState.timerFrame then
        CombatTimerState.timerFrame:SetScript("OnUpdate", nil)
        CombatTimerState.timerFrame:Hide()
    end
end

---------------------------------------------------------------------------
-- Refresh function (called when settings change)
---------------------------------------------------------------------------
local function RefreshCombatTimer()
    local settings = GetSettings()

    -- If we're in preview mode, just refresh appearance and keep showing.
    if CombatTimerState.isPreviewMode then
        UpdateTimerAppearance()
        if CombatTimerState.timerFrame then
            CombatTimerState.timerFrame:Show()
        end
        return
    end

    -- If disabled, hide the timer
    if not settings or not settings.enabled then
        CombatTimerState.isInCombat = false
        if CombatTimerState.timerFrame then
            CombatTimerState.timerFrame:SetScript("OnUpdate", nil)
            CombatTimerState.timerFrame:Hide()
        end
        return
    end

    -- Update appearance if settings changed
    UpdateTimerAppearance()

    -- If currently in combat, make sure it's visible
    if InCombatLockdown() and CombatTimerState.timerFrame then
        if not CombatTimerState.isInCombat then
            -- Entered combat while feature was disabled, start now
            CombatTimerState.combatStartTime = GetTime()
            CombatTimerState.isInCombat = true
            CombatTimerState.timerFrame.text:SetText("0:00")
            CombatTimerState.timerFrame:Show()
            CombatTimerState.timerFrame:SetScript("OnUpdate", OnTimerUpdate)
        end
    end
end

---------------------------------------------------------------------------
-- Toggle preview mode (used by options panel + Edit Mode enter/exit)
---------------------------------------------------------------------------
local function TogglePreview(enable)
    CreateTimerFrame()
    if not CombatTimerState.timerFrame then return end

    CombatTimerState.isPreviewMode = enable

    if enable then
        -- Show preview
        UpdateTimerAppearance()
        CombatTimerState.timerFrame.text:SetText("01:23")
        CombatTimerState.timerFrame:Show()
        CombatTimerState.timerFrame:SetScript("OnUpdate", nil)  -- No counting in preview
    else
        -- Hide preview (unless actually in combat with feature enabled)
        local settings = GetSettings()
        if settings and settings.enabled and InCombatLockdown() then
            -- Don't hide, we're in combat with feature enabled
            CombatTimerState.isInCombat = true
            CombatTimerState.combatStartTime = GetTime()
            CombatTimerState.timerFrame.text:SetText("0:00")
            CombatTimerState.timerFrame:SetScript("OnUpdate", OnTimerUpdate)
        else
            CombatTimerState.timerFrame:SetScript("OnUpdate", nil)
            CombatTimerState.timerFrame:Hide()
        end
    end
end

local function IsPreviewMode()
    return CombatTimerState.isPreviewMode
end

---------------------------------------------------------------------------
-- Edit Mode integration (LibEQOLEditMode-1.0)
---------------------------------------------------------------------------

-- Position-changed callback. LEM versions vary in argument order, so
-- accept both (frame, layoutName, point, x, y) and (frame, x, y, point).
local function OnPositionChanged(frame, layoutName, point, x, y)
    if type(layoutName) == "number" then
        local origX, origY, origPoint = layoutName, point, x
        x, y, point = origX, origY, origPoint
    end
    local s = GetSettings(); if not s then return end
    if type(s.position) ~= "table" then s.position = {} end
    s.position.point = point or "CENTER"
    s.position.x = tonumber(x) or 0
    s.position.y = tonumber(y) or 0
end

-- Build a LEM dropdown generator that maps option.value <-> option.text.
-- LEM's `values = ...` shortcut stores option.text into the setting,
-- which breaks any setting that uses a stable internal value (font names
-- tend to work because text == value, but border textures need this).
local function MakeDropdownGenerator(getList, getCurrentValue, setValue, fallbackText)
    return function(dropdown, rootDescription, settingObject)
        local layoutName = LEM and LEM.GetActiveLayoutName and LEM.GetActiveLayoutName() or "Default"
        local options = getList()
        local current = getCurrentValue()
        local currentText = fallbackText or current
        for _, opt in ipairs(options) do
            if opt.value == current then currentText = opt.text; break end
        end
        dropdown:SetDefaultText(currentText)
        for _, opt in ipairs(options) do
            local optText, optValue = opt.text, opt.value
            rootDescription:CreateButton(optText, function()
                dropdown:SetDefaultText(optText)
                setValue(optValue)
            end)
        end
    end
end

local function GetFontList()
    local fonts = {}
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            local path = LSM:Fetch("font", name) or ""
            local pathLower = path:lower()
            local isWoWFont = pathLower:find("^fonts\\") ~= nil or pathLower:find("^fonts/") ~= nil
            local isSuaviFont = pathLower:find("suaviui") ~= nil
            local isSharedMediaFont = pathLower:find("sharedmedia") ~= nil
            if (isWoWFont or isSuaviFont or isSharedMediaFont) and path ~= "" then
                table.insert(fonts, { value = name, text = name })
            end
        end
    end
    if #fonts == 0 then
        fonts = { { value = "Friz Quadrata TT", text = "Friz Quadrata TT" } }
    end
    return fonts
end

local function GetBorderList()
    local borders = { { value = "None", text = "None (Solid)" } }
    if LSM then
        for _, name in ipairs(LSM:List("border")) do
            table.insert(borders, { value = name, text = name })
        end
    end
    return borders
end

local function BuildEditModeSettings()
    local settings = {}
    local order = 1

    -- ENABLE
    table.insert(settings, {
        order = order, name = "Enable",
        kind = LEM.SettingType.Checkbox, default = false,
        get = function() local s = GetSettings(); return s and s.enabled or false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.enabled = value; RefreshCombatTimer() end
        end,
    }); order = order + 1

    -- BEHAVIOR
    table.insert(settings, {
        order = order, name = "Behavior", kind = LEM.SettingType.Collapsible,
        id = "CT_BEHAVIOR", defaultCollapsed = false,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_BEHAVIOR", order = order, name = "Only Show In Encounters",
        kind = LEM.SettingType.Checkbox, default = false,
        get = function() local s = GetSettings(); return s and s.onlyShowInEncounters or false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.onlyShowInEncounters = value; RefreshCombatTimer() end
        end,
    }); order = order + 1

    -- FRAME SIZE
    table.insert(settings, {
        order = order, name = "Frame Size", kind = LEM.SettingType.Collapsible,
        id = "CT_SIZE", defaultCollapsed = true,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_SIZE", order = order, name = "Frame Width",
        kind = LEM.SettingType.Slider, default = 80, minValue = 40, maxValue = 200, valueStep = 1,
        get = function() local s = GetSettings(); return s and s.width or 80 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.width = math.floor(value); RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_SIZE", order = order, name = "Frame Height",
        kind = LEM.SettingType.Slider, default = 30, minValue = 20, maxValue = 100, valueStep = 1,
        get = function() local s = GetSettings(); return s and s.height or 30 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.height = math.floor(value); RefreshCombatTimer() end
        end,
    }); order = order + 1

    -- TEXT
    table.insert(settings, {
        order = order, name = "Text", kind = LEM.SettingType.Collapsible,
        id = "CT_TEXT", defaultCollapsed = true,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_TEXT", order = order, name = "Font Size",
        kind = LEM.SettingType.Slider, default = 16, minValue = 12, maxValue = 32, valueStep = 1,
        get = function() local s = GetSettings(); return s and s.fontSize or 16 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.fontSize = math.floor(value); RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_TEXT", order = order, name = "Use Custom Font",
        kind = LEM.SettingType.Checkbox, default = false,
        get = function() local s = GetSettings(); return s and s.useCustomFont or false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.useCustomFont = value; RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_TEXT", order = order, name = "Font",
        kind = LEM.SettingType.Dropdown, default = "Suavi", useOldStyle = true,
        generator = MakeDropdownGenerator(
            GetFontList,
            function() local s = GetSettings(); return s and s.font or "Suavi" end,
            function(value) local s = GetSettings(); if s then s.font = value; RefreshCombatTimer() end end,
            "Suavi"
        ),
        get = function() local s = GetSettings(); return s and s.font or "Suavi" end,
        set = function(_, value)
            local s = GetSettings(); if s then s.font = value; RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_TEXT", order = order, name = "Use Class Color for Text",
        kind = LEM.SettingType.Checkbox, default = false,
        get = function() local s = GetSettings(); return s and s.useClassColorText or false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.useClassColorText = value; RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_TEXT", order = order, name = "Text Color",
        kind = LEM.SettingType.Color, default = {1, 1, 1, 1},
        get = function()
            local s = GetSettings()
            local c = s and s.textColor or {1, 1, 1, 1}
            if type(c[1]) == "table" then
                local t = c[1]
                return t.r or 1, t.g or 1, t.b or 1, t.a or 1
            end
            return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
        end,
        set = function(_, r, g, b, a)
            local s = GetSettings(); if not s then return end
            if type(r) == "table" then
                s.textColor = { r.r or 1, r.g or 1, r.b or 1, r.a or 1 }
            else
                s.textColor = { r or 1, g or 1, b or 1, a or 1 }
            end
            RefreshCombatTimer()
        end,
    }); order = order + 1

    -- BACKDROP
    table.insert(settings, {
        order = order, name = "Backdrop", kind = LEM.SettingType.Collapsible,
        id = "CT_BACKDROP", defaultCollapsed = true,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_BACKDROP", order = order, name = "Show Backdrop",
        kind = LEM.SettingType.Checkbox, default = true,
        get = function() local s = GetSettings(); if not s then return true end
            if s.showBackdrop == nil then return true end; return s.showBackdrop end,
        set = function(_, value)
            local s = GetSettings(); if s then s.showBackdrop = value; RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_BACKDROP", order = order, name = "Backdrop Color",
        kind = LEM.SettingType.Color, default = {0, 0, 0, 0.6},
        get = function()
            local s = GetSettings()
            local c = s and s.backdropColor or {0, 0, 0, 0.6}
            if type(c[1]) == "table" then
                local t = c[1]
                return t.r or 0, t.g or 0, t.b or 0, t.a or 0.6
            end
            return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 0.6
        end,
        set = function(_, r, g, b, a)
            local s = GetSettings(); if not s then return end
            if type(r) == "table" then
                s.backdropColor = { r.r or 0, r.g or 0, r.b or 0, r.a or 0.6 }
            else
                s.backdropColor = { r or 0, g or 0, b or 0, a or 0.6 }
            end
            RefreshCombatTimer()
        end,
    }); order = order + 1

    -- BORDER
    table.insert(settings, {
        order = order, name = "Border", kind = LEM.SettingType.Collapsible,
        id = "CT_BORDER", defaultCollapsed = true,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_BORDER", order = order, name = "Hide Border",
        kind = LEM.SettingType.Checkbox, default = false,
        get = function() local s = GetSettings(); return s and s.hideBorder or false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.hideBorder = value; RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_BORDER", order = order, name = "Border Size",
        kind = LEM.SettingType.Slider, default = 1, minValue = 0, maxValue = 5, valueStep = 1,
        get = function() local s = GetSettings(); return s and s.borderSize or 1 end,
        set = function(_, value)
            local s = GetSettings(); if s then s.borderSize = math.floor(value); RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_BORDER", order = order, name = "Border Texture",
        kind = LEM.SettingType.Dropdown, default = "None", useOldStyle = true,
        generator = MakeDropdownGenerator(
            GetBorderList,
            function() local s = GetSettings(); return s and s.borderTexture or "None" end,
            function(value) local s = GetSettings(); if s then s.borderTexture = value; RefreshCombatTimer() end end,
            "None (Solid)"
        ),
        get = function() local s = GetSettings(); return s and s.borderTexture or "None" end,
        set = function(_, value)
            local s = GetSettings(); if s then s.borderTexture = value; RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_BORDER", order = order, name = "Use Class Color for Border",
        kind = LEM.SettingType.Checkbox, default = false,
        get = function() local s = GetSettings(); return s and s.useClassColorBorder or false end,
        set = function(_, value)
            local s = GetSettings(); if s then s.useClassColorBorder = value; RefreshCombatTimer() end
        end,
    }); order = order + 1

    table.insert(settings, {
        parentId = "CT_BORDER", order = order, name = "Border Color",
        kind = LEM.SettingType.Color, default = {0, 0, 0, 1},
        get = function()
            local s = GetSettings()
            local c = s and s.borderColor or {0, 0, 0, 1}
            if type(c[1]) == "table" then
                local t = c[1]
                return t.r or 0, t.g or 0, t.b or 0, t.a or 1
            end
            return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
        end,
        set = function(_, r, g, b, a)
            local s = GetSettings(); if not s then return end
            if type(r) == "table" then
                s.borderColor = { r.r or 0, r.g or 0, r.b or 0, r.a or 1 }
            else
                s.borderColor = { r or 0, g or 0, b or 0, a or 1 }
            end
            RefreshCombatTimer()
        end,
    }); order = order + 1

    return settings
end

local function RegisterWithLEM()
    if registeredWithLEM then return end
    if not LEM then return end
    if not CombatTimerState.timerFrame then return end

    local s = GetSettings(); if not s then return end
    MigrateLegacyPosition(s)

    local frame = CombatTimerState.timerFrame
    local defaults = {
        point = (s.position and s.position.point) or "CENTER",
        x = (s.position and s.position.x) or 0,
        y = (s.position and s.position.y) or -150,
    }

    local ok, err = pcall(function()
        LEM:AddFrame(frame, OnPositionChanged, defaults)
        LEM:AddFrameSettings(frame, BuildEditModeSettings())
        LEM:SetFrameDragEnabled(frame, function()
            if LEM.IsInEditMode and LEM:IsInEditMode() then return true end
            return s.enabled or false
        end)
        if LEM.SetFrameResetVisible then
            LEM:SetFrameResetVisible(frame, function()
                return LEM.IsInEditMode and LEM:IsInEditMode() or false
            end)
        end
    end)

    if ok then
        registeredWithLEM = true

        -- Wire enter/exit so the timer auto-shows a preview while in Edit Mode
        LEM:RegisterCallback("enter", function()
            TogglePreview(true)
        end)
        LEM:RegisterCallback("exit", function()
            TogglePreview(false)
        end)
    else
        print("|cffff6666SuaviUI:|r Failed to register Combat Timer with Edit Mode:", tostring(err))
    end
end

---------------------------------------------------------------------------
-- Initialize
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, function()
            CreateTimerFrame()
            RegisterWithLEM()
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()
    elseif event == "ENCOUNTER_START" then
        OnEncounterStart()
    elseif event == "ENCOUNTER_END" then
        OnEncounterEnd()
    end
end)

---------------------------------------------------------------------------
-- Global functions for GUI
---------------------------------------------------------------------------
_G.SuaviUI_RefreshCombatTimer = RefreshCombatTimer
_G.SuaviUI_ToggleCombatTimerPreview = TogglePreview
_G.SuaviUI_IsCombatTimerPreviewMode = IsPreviewMode

_G.SuaviUI_OpenCombatTimerEditMode = function()
    if _G.ShowUIPanel and _G.EditModeManagerFrame then
        if not _G.EditModeManagerFrame:IsShown() then
            _G.ShowUIPanel(_G.EditModeManagerFrame)
        end
    end
end

SUI.CombatTimer = {
    Refresh = RefreshCombatTimer,
    TogglePreview = TogglePreview,
    IsPreviewMode = IsPreviewMode,
}
