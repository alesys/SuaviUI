--[[
    SUI Debug Window System
    Global debugging interface accessible from any module
    Auto-opens when debugMode is enabled and there's data to display
]]

local ADDON_NAME, ns = ...
local SUICore = ns.Addon

---------------------------------------------------------------------------
-- DEBUG WINDOW STATE
---------------------------------------------------------------------------
local debugWindow = nil
local debugLog = {}
local maxLogSize = 100

---------------------------------------------------------------------------
-- HELPER: Get database
---------------------------------------------------------------------------
local function GetDB()
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile
    end
    return nil
end

---------------------------------------------------------------------------
-- LOG ENTRY
---------------------------------------------------------------------------
local function AddDebugLog(message, category, showWindow)
    if not message then return end
    
    category = category or "INFO"
    showWindow = (showWindow ~= false)  -- default to true
    
    local timestamp = date("%H:%M:%S")
    local entry = string.format("[%s] <%s> %s", timestamp, category, tostring(message))
    
    table.insert(debugLog, entry)
    
    -- Keep log size manageable
    if #debugLog > maxLogSize then
        table.remove(debugLog, 1)
    end
    
    -- Auto-open if debug mode enabled and showWindow requested
    local db = GetDB()
    if showWindow and db and db.general and db.general.debugMode then
        ns.DebugWindow:Show()
    end
end

---------------------------------------------------------------------------
-- CREATE DEBUG WINDOW
---------------------------------------------------------------------------
local function CreateDebugWindow()
    if debugWindow then return debugWindow end
    
    local frame = CreateFrame("Frame", "SUI_DebugWindow", UIParent, "BackdropTemplate")
    frame:SetSize(800, 600)
    -- Position at top-left, making it very obvious
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -30)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 3,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.08, 0.99)
    frame:SetBackdropBorderColor(0.4, 0.8, 1.0, 1)  -- Bright cyan border
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()
    
    -- Title bar with prominent styling
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, -10)
    title:SetText("|cFFFF6AC1SuaviUI Debug Window|r")
    title:SetFont(title:GetFont(), 14, "OUTLINE")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    
    -- Scroll frame for debug content
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 45)
    
    -- Edit box (for selectable/copyable text)
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetWidth(scrollFrame:GetWidth() - 10)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)
    
    frame.editBox = editBox
    frame.scrollFrame = scrollFrame
    
    -- Button bar
    local buttonFrame = CreateFrame("Frame", nil, frame)
    buttonFrame:SetSize(frame:GetWidth() - 20, 35)
    buttonFrame:SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
    
    -- Select All button
    local selectBtn = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
    selectBtn:SetSize(100, 22)
    selectBtn:SetPoint("LEFT", 10, 0)
    selectBtn:SetText("Select All")
    selectBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)
    
    -- Clear button
    local clearBtn = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 22)
    clearBtn:SetPoint("LEFT", selectBtn, "RIGHT", 5, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        debugLog = {}
        editBox:SetText("")
    end)
    
    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
    refreshBtn:SetSize(100, 22)
    refreshBtn:SetPoint("LEFT", clearBtn, "RIGHT", 5, 0)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        ns.DebugWindow:UpdateContent()
    end)
    
    -- Copy to Clipboard button
    local copyBtn = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
    copyBtn:SetSize(120, 22)
    copyBtn:SetPoint("RIGHT", -10, 0)
    copyBtn:SetText("Copy All")
    copyBtn:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
        -- WoW doesn't have native clipboard, but selected text can be copied manually
        -- This just highlights it for manual Ctrl+C
    end)
    
    debugWindow = frame
    return frame
end

---------------------------------------------------------------------------
-- UPDATE WINDOW CONTENT
---------------------------------------------------------------------------
local function UpdateContent()
    local window = CreateDebugWindow()
    local editBox = window.editBox
    
    local lines = {}
    
    table.insert(lines, "=== SuaviUI Debug Log ===")
    table.insert(lines, "Generated: " .. date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "Debug Entries: " .. #debugLog)
    table.insert(lines, "")
    
    if #debugLog == 0 then
        table.insert(lines, "(no debug events logged)")
    else
        table.insert(lines, "=== Recent Events ===")
        for i = 1, #debugLog do
            table.insert(lines, debugLog[i])
        end
    end
    
    table.insert(lines, "")
    table.insert(lines, "=== System Info ===")
    local db = GetDB()
    table.insert(lines, "Debug Mode: " .. (db and db.general and db.general.debugMode and "ENABLED" or "DISABLED"))
    
    editBox:SetText(table.concat(lines, "\n"))
end

---------------------------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------------------------
local DebugWindow = {
    AddLog = AddDebugLog,
    Show = function(self)
        local window = CreateDebugWindow()
        self:UpdateContent()
        window:Show()
    end,
    Hide = function(self)
        if debugWindow then debugWindow:Hide() end
    end,
    UpdateContent = UpdateContent,
    IsVisible = function(self)
        return debugWindow and debugWindow:IsShown() or false
    end,
    GetLog = function(self)
        return debugLog
    end,
    ClearLog = function(self)
        debugLog = {}
    end,
}

ns.DebugWindow = DebugWindow

-- Global access for easy debugging from any module
_G.SuaviUI_Debug = AddDebugLog
_G.SuaviUI_DebugWindow = DebugWindow

---------------------------------------------------------------------------
-- SLASH COMMANDS
---------------------------------------------------------------------------
-- Primary slash commands: /suidebug, /suid (new), /sucdebug (legacy)
SLASH_SUICDEBUG1 = "/suidebug"
SLASH_SUICDEBUG2 = "/suid"
SLASH_SUICDEBUG3 = "/sucdebug"
SlashCmdList["SUICDEBUG"] = function(msg)
    msg = msg and msg:lower():trim() or ""
    
    if msg == "clear" then
        DebugWindow:ClearLog()
        print("|cFFFF6AC1SuaviUI:|r Debug log cleared")
    elseif msg == "hide" then
        DebugWindow:Hide()
        print("|cFFFF6AC1SuaviUI:|r Debug window hidden")
    else
        -- Default: show window
        DebugWindow:Show()
        print("|cFFFF6AC1SuaviUI:|r Debug window opened. Use |cFFFFFF00/suidebug clear|r or |cFFFFFF00/suidebug hide|r")
    end
end

---------------------------------------------------------------------------
-- MOUSE BLOCKER DIAGNOSTIC
--
-- Finds the classic "something invisible is eating my clicks": a frame left
-- SHOWN and MOUSE-ENABLED at alpha 0. It still swallows every click over its
-- rectangle even though nothing is drawn.
--
-- Read-only on purpose. It reports what is there; it never disables anything,
-- because blindly calling EnableMouse(false) on an unknown (possibly protected)
-- frame either breaks real UI or taints it.
---------------------------------------------------------------------------
local PREFIX = "|cFFFF6AC1SuaviUI:|r "

local function SafeName(region)
    local ok, name = pcall(region.GetName, region)
    if ok and name then return name end
    ok, name = pcall(region.GetDebugName, region)
    if ok and name then return name end
    return "<anonymous>"
end

local function MouseState(region)
    -- IsMouseClickEnabled is the one that actually decides if clicks are eaten
    if region.IsMouseClickEnabled then
        local click = region:IsMouseClickEnabled()
        local motion = region.IsMouseMotionEnabled and region:IsMouseMotionEnabled()
        if click and motion then return "click+motion" end
        if click then return "CLICK" end
        if motion then return "motion" end
        return "no"
    end
    if region.IsMouseEnabled then
        return region:IsMouseEnabled() and "enabled" or "no"
    end
    return "?"
end

local function EffAlpha(region)
    if region.GetEffectiveAlpha then
        local ok, a = pcall(region.GetEffectiveAlpha, region)
        if ok and a then return a end
    end
    local ok, a = pcall(region.GetAlpha, region)
    return (ok and a) or 1
end

local function Describe(region, idx)
    local objType = (region.GetObjectType and region:GetObjectType()) or "?"
    local eff = EffAlpha(region)
    local own = (region.GetAlpha and region:GetAlpha()) or 1

    local strata, level = "-", "-"
    if region.GetFrameStrata then strata = region:GetFrameStrata() or "-" end
    if region.GetFrameLevel then level = region:GetFrameLevel() or "-" end

    local w, h = 0, 0
    if region.GetRect then
        local ok, _, _, rw, rh = pcall(region.GetRect, region)
        if ok and rw then w, h = rw, rh end
    end

    -- Highlight the smoking gun: invisible but still taking clicks
    local flag = ""
    if eff < 0.01 and MouseState(region):find("[Cc]lick") then
        flag = " |cFFFF0000<== INVISIBLE + CLICKABLE|r"
    end

    print(string.format(
        "%s|cFFFFFF00%d.|r %s |cFF888888(%s)|r alpha=%.2f eff=|cFF%s%.2f|r mouse=%s %s:%s %dx%d%s",
        PREFIX, idx, SafeName(region), objType, own,
        eff < 0.01 and "FF0000" or "00FF00", eff,
        MouseState(region), tostring(strata), tostring(level),
        math.floor(w + 0.5), math.floor(h + 0.5), flag))
end

local function ReportUnderCursor()
    local foci
    if GetMouseFoci then
        foci = GetMouseFoci()
    elseif GetMouseFocus then
        local f = GetMouseFocus()
        foci = f and { f } or {}
    end

    if not foci or #foci == 0 then
        print(PREFIX .. "Nothing under the cursor (or the blocker has no mouse focus).")
        print(PREFIX .. "Try |cFFFFFF00/suimouse scan|r to sweep every frame instead.")
        return
    end

    print(PREFIX .. "|cFF30D1FF" .. #foci .. " region(s) under the cursor|r (topmost first):")
    for i, region in ipairs(foci) do
        Describe(region, i)
    end
end

local function ScanAllFrames()
    if type(EnumerateFrames) ~= "function" then
        print(PREFIX .. "|cFFFF0000EnumerateFrames unavailable on this client.|r")
        return
    end

    local uiScale = UIParent:GetEffectiveScale()
    local screenW, screenH = UIParent:GetWidth() * uiScale, UIParent:GetHeight() * uiScale
    local screenArea = screenW * screenH

    -- Two different ways a frame can be an invisible click blocker:
    --   ghosts = drawn at alpha 0 but still clickable
    --   giants = fully opaque *value* but nothing actually drawn, covering a
    --            huge slice of the screen (a bare CreateFrame has no texture,
    --            so it is invisible no matter what its alpha says)
    local ghosts, giants = {}, {}

    -- WorldFrame is legitimately full-screen and mouse-enabled (it IS the 3D
    -- world). Reporting it every time is pure noise.
    local expectedGiants = { [WorldFrame] = true, [UIParent] = true }

    local f = EnumerateFrames()
    while f do
        pcall(function()
            if f:IsVisible() and MouseState(f):find("[Cc]lick") then
                local _, _, w, h = f:GetRect()
                if w and h and w > 1 and h > 1 then
                    -- GetRect is in the frame's OWN coordinate space. Frames with
                    -- different scales (WorldFrame vs UIParent) are not comparable
                    -- until both are converted to real screen pixels.
                    local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
                    local area = (w * scale) * (h * scale)
                    if EffAlpha(f) < 0.01 then
                        ghosts[#ghosts + 1] = { frame = f, area = area }
                    elseif area > screenArea * 0.25 and not expectedGiants[f] then
                        giants[#giants + 1] = { frame = f, area = area }
                    end
                end
            end
        end)
        f = EnumerateFrames(f)
    end

    local function Dump(list, label, color)
        if #list == 0 then return false end
        table.sort(list, function(a, b) return a.area > b.area end)
        print(PREFIX .. "|cFF" .. color .. #list .. " " .. label .. "|r (biggest first):")
        local shown = math.min(#list, 12)
        for i = 1, shown do
            Describe(list[i].frame, i)
        end
        if #list > shown then
            print(PREFIX .. "... and " .. (#list - shown) .. " more (smaller).")
        end
        return true
    end

    local any = false
    any = Dump(ghosts, "frame(s) invisible but still eating clicks", "FF0000") or any
    any = Dump(giants, "huge click-enabled frame(s) covering >25% of the screen", "FFAA00") or any

    if not any then
        print(PREFIX .. "|cFF00FF00Nothing suspicious found by the sweep.|r")
        print(PREFIX .. "Hover the dead spot and run |cFFFFFF00/suimouse 3|r — that reads the actual click target.")
    end

    print(PREFIX .. "Screen: " .. math.floor(screenW) .. "x" .. math.floor(screenH) ..
        " real px |cFF888888(UIParent scale " .. string.format("%.3f", uiScale) ..
        "; WorldFrame/UIParent excluded as expected full-screen)|r")
end

SLASH_SUIMOUSE1 = "/suimouse"
SLASH_SUIMOUSE2 = "/suim"
SlashCmdList["SUIMOUSE"] = function(msg)
    msg = msg and msg:lower():trim() or ""

    if msg == "scan" then
        ScanAllFrames()
        return
    end

    local delay = tonumber(msg)
    if delay and delay > 0 then
        print(PREFIX .. "Put the cursor on the dead spot — sampling in " .. delay .. "s...")
        C_Timer.After(delay, ReportUnderCursor)
        return
    end

    if msg == "help" then
        print(PREFIX .. "|cFF30D1FFMouse blocker diagnostic|r")
        print("  |cFFFFFF00/suimouse|r        — what is under the cursor right now")
        print("  |cFFFFFF00/suimouse 3|r      — same, but sampled 3s from now (move the cursor first)")
        print("  |cFFFFFF00/suimouse scan|r   — sweep EVERY frame for invisible click-enabled ones")
        return
    end

    ReportUnderCursor()
end
