-- cooldown_fonts.lua
-- Font customization implementation for CooldownManagerCentered integration
-- Handles cooldown numbers, stack numbers, and keybind fonts

local _, SUI = ...

local CooldownFonts = {}

-- Font flag options
local FONT_FLAGS = {
    OUTLINE = "OUTLINE",
    THICKOUTLINE = "THICKOUTLINE", 
    MONOCHROME = "MONOCHROME",
}

-- Default fonts  
local DEFAULT_COOLDOWN_FONT = "Friz Quadrata TT"
local DEFAULT_STACK_FONT = "Friz Quadrata TT"
local DEFAULT_KEYBIND_FONT = "Friz Quadrata TT"

-- Get setting value from profile
local function GetSetting(key, default)
    local profile = SUI and SUI.SUICore and SUI.SUICore.db and SUI.SUICore.db.profile
    if not profile then
        return default
    end
    return profile[key] or default
end

-- Create font string from settings
local function CreateFontString(fontName, fontSize, flags)
    local font = _G.SharedMedia and _G.SharedMedia:Fetch("font", fontName or DEFAULT_COOLDOWN_FONT) or "Fonts\\FRIZQT__.TTF"
    local flagsStr = ""
    
    if flags and type(flags) == "table" then
        local flagsList = {}
        if flags.OUTLINE then table.insert(flagsList, "OUTLINE") end
        if flags.THICKOUTLINE then table.insert(flagsList, "THICKOUTLINE") end
        if flags.MONOCHROME then table.insert(flagsList, "MONOCHROME") end
        flagsStr = table.concat(flagsList, ",")
    end
    
    return font, fontSize or 12, flagsStr
end

-- =====================================================
-- COOLDOWN NUMBER FONTS
-- =====================================================

-- Apply cooldown font to a single icon
function CooldownFonts.ApplyCooldownFont(icon, viewerType)
    if not icon or not icon.Cooldown then
        return
    end
    
    -- Check for per-viewer font size override
    local sizeOverrideKey = "cooldownManager_cooldownFontSize" .. viewerType .. "_enabled"
    local sizeKey = "cooldownManager_cooldownFontSize" .. viewerType
    local useOverride = GetSetting(sizeOverrideKey, false)
    
    local globalFont = GetSetting("cooldownManager_cooldownFontName", DEFAULT_COOLDOWN_FONT)
    local globalFlags = GetSetting("cooldownManager_cooldownFontFlags", {OUTLINE = true})
    local fontSize = nil
    
    if useOverride then
        local sizeValue = GetSetting(sizeKey, "NIL")
        if sizeValue == "0" then
            -- Hide cooldown text
            if icon.Cooldown.Text then
                icon.Cooldown.Text:Hide()
            end
            return
        elseif sizeValue ~= "NIL" then
            fontSize = tonumber(sizeValue)
        end
    end
    
    if not fontSize then
        fontSize = 12  -- Default size
    end
    
    local font, size, flagsStr = CreateFontString(globalFont, fontSize, globalFlags)
    
    if icon.Cooldown.Text then
        icon.Cooldown.Text:SetFont(font, size, flagsStr)
        icon.Cooldown.Text:Show()
    end
end

-- Refresh all cooldown fonts for a viewer
function CooldownFonts.RefreshViewerCooldownFonts(viewerName, viewerType)
    local viewer = _G[viewerName]
    if not viewer then
        return
    end
    
    for i = 1, viewer:GetNumChildren() do
        local child = select(i, viewer:GetChildren())
        if child then
            CooldownFonts.ApplyCooldownFont(child, viewerType)
        end
    end
end

-- =====================================================
-- STACK NUMBER FONTS
-- =====================================================

-- Apply stack font and positioning to a single icon
function CooldownFonts.ApplyStackFont(icon, viewerType)
    if not icon then
        return
    end
    
    local enabledKey = "cooldownManager_stackAnchor" .. viewerType .. "_enabled"
    local enabled = GetSetting(enabledKey, false)
    
    if not enabled then
        -- Hide stack text if disabled
        if icon.StackText then
            icon.StackText:Hide()
        end
        return
    end
    
    -- Get stack settings
    local anchorKey = "cooldownManager_stackAnchor" .. viewerType .. "_point"
    local sizeKey = "cooldownManager_stackFontSize" .. viewerType
    local offsetXKey = "cooldownManager_stackAnchor" .. viewerType .. "_offsetX"
    local offsetYKey = "cooldownManager_stackAnchor" .. viewerType .. "_offsetY"
    
    local anchor = GetSetting(anchorKey, "BOTTOMRIGHT")
    local fontSize = GetSetting(sizeKey, "NIL")
    local offsetX = GetSetting(offsetXKey, 0)
    local offsetY = GetSetting(offsetYKey, 0)
    
    if fontSize == "NIL" then
        fontSize = 12  -- Default
    else
        fontSize = tonumber(fontSize) or 12
    end
    
    -- Get global stack font settings
    local globalFont = GetSetting("cooldownManager_stackFontName", DEFAULT_STACK_FONT)
    local globalFlags = GetSetting("cooldownManager_stackFontFlags", {OUTLINE = true})
    
    local font, size, flagsStr = CreateFontString(globalFont, fontSize, globalFlags)
    
    -- Create or update stack text
    if not icon.StackText then
        icon.StackText = icon:CreateFontString(nil, "OVERLAY")
    end
    
    icon.StackText:SetFont(font, size, flagsStr)
    icon.StackText:ClearAllPoints()
    icon.StackText:SetPoint(anchor, icon, anchor, offsetX, offsetY)
    icon.StackText:Show()
    
    -- Hook to show stack count
    if icon.GetStackCount then
        local count = icon:GetStackCount()
        if count and count > 1 then
            icon.StackText:SetText(tostring(count))
        else
            icon.StackText:SetText("")
        end
    end
end

-- Refresh all stack fonts for a viewer
function CooldownFonts.RefreshViewerStackFonts(viewerName, viewerType)
    local viewer = _G[viewerName]
    if not viewer then
        return
    end
    
    for i = 1, viewer:GetNumChildren() do
        local child = select(i, viewer:GetChildren())
        if child then
            CooldownFonts.ApplyStackFont(child, viewerType)
        end
    end
end

-- =====================================================
-- KEYBIND FONTS
-- =====================================================

-- Apply keybind font to a single icon
function CooldownFonts.ApplyKeybindFont(icon, viewerType)
    if not icon then
        return
    end
    
    local showKey = "cooldownManager_showKeybinds_" .. viewerType
    local show = GetSetting(showKey, false)
    
    if not show then
        -- Hide keybind text if disabled
        if icon.KeybindText then
            icon.KeybindText:Hide()
        end
        return
    end
    
    -- Get keybind settings
    local anchorKey = "cooldownManager_keybindAnchor_" .. viewerType
    local sizeKey = "cooldownManager_keybindFontSize_" .. viewerType
    local offsetXKey = "cooldownManager_keybindOffsetX_" .. viewerType
    local offsetYKey = "cooldownManager_keybindOffsetY_" .. viewerType
    
    local anchor = GetSetting(anchorKey, "TOPRIGHT")
    local fontSize = GetSetting(sizeKey, viewerType == "Essential" and 14 or 10)
    local offsetX = GetSetting(offsetXKey, -3)
    local offsetY = GetSetting(offsetYKey, -3)
    
    -- Get global keybind font settings
    local globalFont = GetSetting("cooldownManager_keybindFontName", DEFAULT_KEYBIND_FONT)
    local globalFlags = GetSetting("cooldownManager_keybindFontFlags", {OUTLINE = true})
    
    local font, size, flagsStr = CreateFontString(globalFont, fontSize, globalFlags)
    
    -- Create or update keybind text
    if not icon.KeybindText then
        icon.KeybindText = icon:CreateFontString(nil, "OVERLAY")
    end
    
    icon.KeybindText:SetFont(font, size, flagsStr)
    icon.KeybindText:ClearAllPoints()
    icon.KeybindText:SetPoint(anchor, icon, anchor, offsetX, offsetY)
    icon.KeybindText:Show()
    
    -- Try to get keybind from action button
    if icon.GetActionSlot then
        local slot = icon:GetActionSlot()
        if slot then
            local keybind = GetBindingKey("ACTIONBUTTON" .. slot)
            if keybind then
                icon.KeybindText:SetText(keybind)
            else
                icon.KeybindText:SetText("")
            end
        end
    else
        icon.KeybindText:SetText("")
    end
end

-- Refresh all keybind fonts for a viewer
function CooldownFonts.RefreshViewerKeybindFonts(viewerName, viewerType)
    local viewer = _G[viewerName]
    if not viewer then
        return
    end
    
    -- Only Essential and Utility viewers support keybinds
    if viewerType ~= "Essential" and viewerType ~= "Utility" then
        return
    end
    
    for i = 1, viewer:GetNumChildren() do
        local child = select(i, viewer:GetChildren())
        if child then
            CooldownFonts.ApplyKeybindFont(child, viewerType)
        end
    end
end

-- =====================================================
-- MASTER REFRESH FUNCTIONS
-- =====================================================

-- Refresh all fonts for a specific viewer
function CooldownFonts.RefreshViewerFonts(viewerName, viewerType)
    CooldownFonts.RefreshViewerCooldownFonts(viewerName, viewerType)
    CooldownFonts.RefreshViewerStackFonts(viewerName, viewerType)
    CooldownFonts.RefreshViewerKeybindFonts(viewerName, viewerType)
end

-- Refresh all fonts across all viewers
function CooldownFonts.RefreshAllFonts()
    local viewers = {
        {"EssentialCooldownViewer", "Essential"},
        {"UtilityCooldownViewer", "Utility"},
        {"BuffIconCooldownViewer", "BuffIcons"},
    }
    
    for _, viewerInfo in ipairs(viewers) do
        CooldownFonts.RefreshViewerFonts(viewerInfo[1], viewerInfo[2])
    end
end

-- Export the module
SUI.CooldownFonts = CooldownFonts