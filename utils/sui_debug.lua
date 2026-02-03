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
    frame:SetSize(600, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.08, 0.98)
    frame:SetBackdropBorderColor(0.2, 0.2, 0.3, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()
    
    -- Title bar
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 15, -10)
    title:SetText("|cFF56D1FFSuaviUI Debug Window|r")
    
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
-- SLASH COMMAND
---------------------------------------------------------------------------
SLASH_SUICDEBUG1 = "/sucdebug"
SlashCmdList["SUICDEBUG"] = function(msg)
    msg = msg and msg:lower():trim() or ""
    
    if msg == "clear" then
        DebugWindow:ClearLog()
        print("|cFF56D1FFSuaviUI:|r Debug log cleared")
    elseif msg == "hide" then
        DebugWindow:Hide()
        print("|cFF56D1FFSuaviUI:|r Debug window hidden")
    else
        -- Default: show window
        DebugWindow:Show()
        print("|cFF56D1FFSuaviUI:|r Debug window opened. Use |cFFFFFF00/sucdebug clear|r or |cFFFFFF00/sucdebug hide|r")
    end
end
