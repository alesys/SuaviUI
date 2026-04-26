-- sui_rotationassist.lua
-- Displays a standalone icon showing Blizzard's next recommended ability
-- Uses C_AssistedCombat API (Starter Build / Rotation Helper)

local ADDON_NAME, SUI = ...
local LSM = LibStub("LibSharedMedia-3.0")
local LEM = LibStub("LibEQOLEditMode-1.0", true)

-- Locals for performance
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitCanAttack = UnitCanAttack
local UnitExists = UnitExists

-- Update intervals
local UPDATE_INTERVAL_COMBAT = 0.3
local UPDATE_INTERVAL_IDLE = 1.0

-- Icon state colors
local COLOR_USABLE = { 1, 1, 1 }
local COLOR_UNUSABLE = { 0.4, 0.4, 0.4 }
local COLOR_NO_MANA = { 0.5, 0.5, 1 }
local COLOR_OUT_OF_RANGE = { 0.8, 0.2, 0.2 }

-- Frame references
local iconFrame = nil
local isInitialized = false
local lastSpellID = nil
local inCombat = false

-- Performance: Ticker instead of OnUpdate
local updateTicker = nil

-- Cache for keybind lookup (reuse from keybinds.lua)
local spellToKeybind = {}
local lastKeybindCacheTime = 0
local KEYBIND_CACHE_INTERVAL = 1.0

-- GCD spell ID (standard global cooldown reference)
local GCD_SPELL_ID = 61304

-- Forward declarations
local CreateIconFrame, RefreshIconFrame, UpdateIconDisplay, UpdateVisibility

--------------------------------------------------------------------------------
-- Keybind Lookup (uses shared formatter from keybinds.lua)
--------------------------------------------------------------------------------

local function FormatKeybind(keybind)
    if SUI.FormatKeybind then
        return SUI.FormatKeybind(keybind)
    end
    return keybind -- fallback if not available
end

local function GetKeybindForSpell(spellID)
    if not spellID then return nil end

    local keybind = nil

    -- Use SUI.Keybinds if available (from keybinds.lua)
    if SUI.Keybinds and SUI.Keybinds.GetKeybindForSpell then
        keybind = SUI.Keybinds.GetKeybindForSpell(spellID)

        -- If no keybind found, try finding the BASE spell (for proc abilities)
        -- e.g., Thunder Blast -> Thunder Clap
        if not keybind then
            local ok, baseSpellID = pcall(function()
                return FindBaseSpellByID and FindBaseSpellByID(spellID)
            end)
            if ok and baseSpellID and baseSpellID ~= spellID then
                keybind = SUI.Keybinds.GetKeybindForSpell(baseSpellID)
            end
        end

        -- Also try C_Spell.GetOverrideSpell in reverse
        if not keybind then
            local ok, overrideID = pcall(function()
                return C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)
            end)
            if ok and overrideID and overrideID ~= spellID then
                keybind = SUI.Keybinds.GetKeybindForSpell(overrideID)
            end
        end

        if keybind then return keybind end
    end

    -- Fallback: Find action buttons with this spell (try base spell too)
    -- Mapping per Blizzard_ActionBar/Shared/MultiActionBars.xml `actionpage`
    -- and `commandNamePrefix` attributes. Slots 13-24 are page-2 vehicle/possess
    -- overrides — no user keybinds. Bars 2 and 3 (slots 49-72) had been
    -- swapped previously, causing wrong-key reports (e.g. Cataclysm S1 → A1).
    local function SlotToActionName(slot)
        if slot <= 12 then
            return "ACTIONBUTTON" .. slot
        elseif slot <= 24 then
            return nil
        elseif slot <= 36 then
            return "MULTIACTIONBAR3BUTTON" .. (slot - 24)
        elseif slot <= 48 then
            return "MULTIACTIONBAR4BUTTON" .. (slot - 36)
        elseif slot <= 60 then
            return "MULTIACTIONBAR2BUTTON" .. (slot - 48)
        elseif slot <= 72 then
            return "MULTIACTIONBAR1BUTTON" .. (slot - 60)
        elseif slot >= 145 and slot <= 156 then
            return "MULTIACTIONBAR5BUTTON" .. (slot - 144)
        elseif slot >= 157 and slot <= 168 then
            return "MULTIACTIONBAR6BUTTON" .. (slot - 156)
        elseif slot >= 169 and slot <= 180 then
            return "MULTIACTIONBAR7BUTTON" .. (slot - 168)
        end
        return nil
    end

    local baseSpellID = FindBaseSpellByID and FindBaseSpellByID(spellID) or spellID
    local slots = C_ActionBar.FindSpellActionButtons(baseSpellID)

    if slots and #slots > 0 then
        for _, slot in ipairs(slots) do
            local actionName = SlotToActionName(slot)
            if actionName then
                local key1 = GetBindingKey(actionName)
                if key1 then
                    return FormatKeybind(key1)
                end
            end
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- GCD Cooldown Helpers (handles Midnight 12.0+ secret values)
--------------------------------------------------------------------------------

local function ReadSpellCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local a, b, c, d = C_Spell.GetSpellCooldown(spellID)
        if type(a) == "table" then
            -- Midnight 12.0+ returns table
            local start = a.startTime or a.start
            local duration = a.duration
            local modRate = a.modRate
            return start, duration, modRate
        else
            -- 11.x returns tuple: start, duration, enable, modRate
            return a, b, d
        end
    end
    return nil, nil, nil
end

local function IsCooldownActive(start, duration)
    if not start or not duration then return false end
    local ok, result = pcall(function()
        return duration > 0 and start > 0
    end)
    -- If comparison threw error = secret value = cooldown IS active
    if not ok then return true end
    return result
end

--------------------------------------------------------------------------------
-- Database Access
--------------------------------------------------------------------------------

local function GetDB()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile then
        return SUICore.db.profile.rotationAssistIcon
    end
    return nil
end

--------------------------------------------------------------------------------
-- Icon Frame Creation
--------------------------------------------------------------------------------

CreateIconFrame = function()
    if iconFrame then return iconFrame end

    -- Main frame
    iconFrame = CreateFrame("Button", "SuaviUI_RotationAssistIcon", UIParent, "BackdropTemplate")
    iconFrame:SetSize(56, 56)
    iconFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    iconFrame:SetFrameStrata("MEDIUM")
    iconFrame:SetClampedToScreen(true)
    iconFrame:EnableMouse(true)
    iconFrame:SetMovable(true)
    iconFrame:RegisterForDrag("LeftButton")

    -- Icon texture (inset by 2px default for border visibility)
    iconFrame.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    iconFrame.icon:SetPoint("TOPLEFT", 2, -2)
    iconFrame.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    iconFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Crop edges

    -- Cooldown frame (matches icon inset)
    iconFrame.cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
    iconFrame.cooldown:SetPoint("TOPLEFT", 2, -2)
    iconFrame.cooldown:SetPoint("BOTTOMRIGHT", -2, 2)
    iconFrame.cooldown:SetDrawSwipe(true)
    iconFrame.cooldown:SetDrawEdge(false)
    iconFrame.cooldown:SetSwipeColor(0, 0, 0, 0.8)
    iconFrame.cooldown:SetHideCountdownNumbers(true)

    -- Keybind text
    iconFrame.keybindText = iconFrame:CreateFontString(nil, "OVERLAY")
    iconFrame.keybindText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    iconFrame.keybindText:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -2, 2)
    iconFrame.keybindText:SetTextColor(1, 1, 1, 1)
    iconFrame.keybindText:SetShadowOffset(1, -1)
    iconFrame.keybindText:SetShadowColor(0, 0, 0, 1)

    -- Dragging is handled by LibEQOLEditMode in Edit Mode only.
    -- Hide initially
    iconFrame:Hide()

    return iconFrame
end

--------------------------------------------------------------------------------
-- Icon Display Update
--------------------------------------------------------------------------------

UpdateIconDisplay = function(spellID)
    if not iconFrame then return end

    local db = GetDB()
    if not db or not db.enabled then
        iconFrame:Hide()
        return
    end

    if not spellID or spellID == 0 then
        -- No spell recommended - hide the icon entirely
        iconFrame:Hide()
        return
    end

    -- We have a spell - make sure frame is visible (respecting visibility mode)
    UpdateVisibility()

    -- Get spell texture and usability state (TAINT-FIX: wrapped in pcall)
    local texture, isUsable, notEnoughMana, hasRange, inRange = nil, false, false, false, true
    
    local ok = pcall(function()
        texture = C_Spell.GetSpellTexture(spellID)
        isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID)
        hasRange = C_Spell.SpellHasRange(spellID)
        
        if hasRange and UnitExists("target") then
            local rangeCheck = C_Spell.IsSpellInRange(spellID, "target")
            if rangeCheck == false then
                inRange = false
            end
        end
    end)
    
    if texture then
        iconFrame.icon:SetTexture(texture)
    end

    -- Apply icon tint based on state
    local color
    if not inRange then
        color = COLOR_OUT_OF_RANGE
    elseif notEnoughMana then
        color = COLOR_NO_MANA
    elseif not isUsable then
        color = COLOR_UNUSABLE
    else
        color = COLOR_USABLE
    end
    iconFrame.icon:SetVertexColor(color[1], color[2], color[3], 1)

    -- GCD cooldown swipe is handled separately by UpdateGCDCooldown()
    -- (triggered by SPELL_UPDATE_COOLDOWN events for responsiveness)

    -- Update keybind text
    if db.showKeybind then
        local keybind = GetKeybindForSpell(spellID)
        iconFrame.keybindText:SetText(keybind or "")
        iconFrame.keybindText:Show()
    else
        iconFrame.keybindText:Hide()
    end
end

--------------------------------------------------------------------------------
-- GCD Cooldown Update (event-driven for responsiveness)
--------------------------------------------------------------------------------

local function UpdateGCDCooldown()
    if not iconFrame or not iconFrame.cooldown then return end

    local db = GetDB()
    if not db or not db.cooldownSwipeEnabled then
        iconFrame.cooldown:Hide()
        return
    end

    -- Only show GCD swipe when the icon itself is visible
    if not iconFrame:IsShown() then return end

    local start, duration, modRate = ReadSpellCooldown(GCD_SPELL_ID)

    if IsCooldownActive(start, duration) then
        iconFrame.cooldown:Show()
        if modRate then
            iconFrame.cooldown:SetCooldown(start, duration, modRate)
        else
            iconFrame.cooldown:SetCooldown(start, duration)
        end
    else
        iconFrame.cooldown:Clear()
    end
end

--------------------------------------------------------------------------------
-- Visibility Management
--------------------------------------------------------------------------------

UpdateVisibility = function()
    if not iconFrame then return end

    local db = GetDB()
    if not db or not db.enabled then
        iconFrame:Hide()
        return
    end

    local shouldShow = false
    local visibility = db.visibility or "always"

    if visibility == "always" then
        shouldShow = true
    elseif visibility == "combat" then
        shouldShow = inCombat
    elseif visibility == "hostile" then
        -- TAINT-FIX: Protect UnitExists() calls during SPELL_UPDATE_COOLDOWN combat events
        -- These protected APIs return secret values during combat that can taint Blizzard systems
        local canAttackTarget = false
        pcall(function()
            canAttackTarget = UnitExists("target") and UnitCanAttack("player", "target")
        end)
        shouldShow = canAttackTarget
    end

    if shouldShow then
        iconFrame:Show()
    else
        iconFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- Ticker-based Update (Performance: runs only when needed, not every frame)
--------------------------------------------------------------------------------

local function DoUpdate()
    local db = GetDB()
    if not db or not db.enabled then return end

    -- Check if C_AssistedCombat API is available
    if not C_AssistedCombat or not C_AssistedCombat.GetNextCastSpell then
        return
    end

    -- Get next recommended spell
    local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell, false)
    if not ok then
        spellID = nil
    end

    -- Only do full update if spell changed
    if spellID ~= lastSpellID then
        lastSpellID = spellID
        UpdateIconDisplay(spellID)
    end
end

local function StartUpdateTicker()
    -- Cancel existing ticker if any
    if updateTicker then updateTicker:Cancel() end

    local db = GetDB()
    if not db or not db.enabled then return end

    -- Use appropriate interval based on combat state
    local interval = inCombat and UPDATE_INTERVAL_COMBAT or UPDATE_INTERVAL_IDLE
    updateTicker = C_Timer.NewTicker(interval, DoUpdate)
end

local function StopUpdateTicker()
    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
    end
end

--------------------------------------------------------------------------------
-- Frame Refresh (Apply Settings)
--------------------------------------------------------------------------------

RefreshIconFrame = function()
    if not iconFrame then
        CreateIconFrame()
    end

    local db = GetDB()
    if not db then
        if iconFrame then iconFrame:Hide() end
        return
    end

    if not db.enabled then
        iconFrame:Hide()
        StopUpdateTicker()
        return
    end

    -- Ensure ticker is running when enabled (may have been stopped)
    StartUpdateTicker()

    -- Size (guard with pcall to prevent secret value crash when backdrop recalculates)
    -- SetSize triggers backdrop texture coordinate recalculation which can fail during combat
    local size = db.iconSize or 56
    pcall(iconFrame.SetSize, iconFrame, size, size)

    -- Position (always anchored to CENTER of screen)
    iconFrame:ClearAllPoints()
    local posX = db.positionX or 0
    local posY = db.positionY or -180
    iconFrame:SetPoint("CENTER", UIParent, "CENTER", posX, posY)

    -- Frame strata
    iconFrame:SetFrameStrata(db.frameStrata or "MEDIUM")

    -- Border (uses SafeSetBackdrop to avoid secret value errors during combat)
    local inset = 0
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    local SafeSetBackdrop = SUICore and SUICore.SafeSetBackdrop

    if db.showBorder then
        -- Sanitize borderColor — earlier versions of the LEM setter could have
        -- written a malformed table (with an {r=,g=,b=,a=} object as element 1).
        -- Repair it on read so SetBackdropBorderColor gets plain numbers.
        local bc = db.borderColor
        if type(bc) ~= "table" then
            bc = { 0, 0, 0, 1 }
        elseif type(bc[1]) == "table" then
            local t = bc[1]
            bc = { t.r or 0, t.g or 0, t.b or 0, t.a or 1 }
            db.borderColor = bc
        elseif type(bc[1]) ~= "number" then
            bc = { 0, 0, 0, 1 }
            db.borderColor = bc
        end
        local borderColor = bc
        local thickness = db.borderThickness or 2
        inset = thickness

        -- Use backdrop for border
        local backdropInfo = {
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = thickness,
        }
        if SafeSetBackdrop then
            SafeSetBackdrop(iconFrame, backdropInfo, borderColor)
        else
            iconFrame:SetBackdrop(backdropInfo)
            iconFrame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
        end
    else
        if SafeSetBackdrop then
            SafeSetBackdrop(iconFrame, nil)
        else
            iconFrame:SetBackdrop(nil)
        end
    end

    -- Adjust icon and cooldown inset based on border
    iconFrame.icon:ClearAllPoints()
    iconFrame.icon:SetPoint("TOPLEFT", inset, -inset)
    iconFrame.icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    iconFrame.cooldown:ClearAllPoints()
    iconFrame.cooldown:SetPoint("TOPLEFT", inset, -inset)
    iconFrame.cooldown:SetPoint("BOTTOMRIGHT", -inset, inset)

    -- Update cooldown swipe visibility based on setting
    iconFrame.cooldown:SetDrawSwipe(db.cooldownSwipeEnabled)
    if not db.cooldownSwipeEnabled then
        iconFrame.cooldown:Hide()
    end

    iconFrame:EnableMouse(true)

    -- Keybind text styling
    if db.showKeybind then
        -- Get font: use keybindFont if set, otherwise fall back to general.font
        local fontName = db.keybindFont
        if not fontName then
            local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
            if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general then
                fontName = SUICore.db.profile.general.font
            end
        end
        local fontPath = LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
        local fontSize = db.keybindSize or 13
        local outline = db.keybindOutline and "OUTLINE" or ""
        iconFrame.keybindText:SetFont(fontPath, fontSize, outline)

        -- Sanitize keybindColor same as borderColor (repair pre-fix corruption).
        local kc = db.keybindColor
        if type(kc) ~= "table" then
            kc = { 1, 1, 1, 1 }
        elseif type(kc[1]) == "table" then
            local t = kc[1]
            kc = { t.r or 1, t.g or 1, t.b or 1, t.a or 1 }
            db.keybindColor = kc
        elseif type(kc[1]) ~= "number" then
            kc = { 1, 1, 1, 1 }
            db.keybindColor = kc
        end
        iconFrame.keybindText:SetTextColor(kc[1], kc[2], kc[3], kc[4] or 1)

        -- Anchor position
        local anchor = db.keybindAnchor or "BOTTOMRIGHT"
        local offsetX = db.keybindOffsetX or -2
        local offsetY = db.keybindOffsetY or 2
        iconFrame.keybindText:ClearAllPoints()
        iconFrame.keybindText:SetPoint(anchor, iconFrame, anchor, offsetX, offsetY)
    end

    -- Force a fresh spell check so visibility-setting changes take effect
    -- immediately (otherwise the frame waits for the next ticker tick before
    -- re-evaluating, and "always" mode wouldn't switch on until a new spell
    -- recommendation changed).
    lastSpellID = nil
    DoUpdate()
end

--------------------------------------------------------------------------------
-- Event Handling
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            if not isInitialized then
                CreateIconFrame()
                isInitialized = true
            end
            local db = GetDB()
            if db and db.enabled then
                RefreshIconFrame()
                -- Start ticker for spell updates (performance: replaces OnUpdate)
                StartUpdateTicker()
            end
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        local db = GetDB()
        if db and db.enabled then
            UpdateVisibility()
            -- Restart ticker with idle interval (1.0s instead of 0.3s)
            StartUpdateTicker()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        local db = GetDB()
        if db and db.enabled then
            UpdateVisibility()
            -- Restart ticker with combat interval (0.3s for faster response)
            StartUpdateTicker()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateVisibility()
        -- Force spell update on target change
        lastSpellID = nil
        DoUpdate()  -- Immediate update on target change
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
        UpdateGCDCooldown()
    end
end)

--------------------------------------------------------------------------------
-- Global Refresh Function
--------------------------------------------------------------------------------

local function RefreshRotationAssistIcon()
    RefreshIconFrame()
end

_G.SuaviUI_RefreshRotationAssistIcon = RefreshRotationAssistIcon

--------------------------------------------------------------------------------
-- Edit Mode (LibEQOLEditMode) Integration
--------------------------------------------------------------------------------

local lemRegistered = false

local function OnLEMPositionChanged(frame, layoutName, point, x, y)
    -- LibEQOL can invoke with either 4 or 5 positional args; prefer GetCenter.
    if not frame then return end
    local db = GetDB(); if not db then return end
    local selfX, selfY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if selfX and selfY and parentX and parentY then
        db.positionX = selfX - parentX
        db.positionY = selfY - parentY
    end
end

local ANCHOR_OPTIONS = {
    { value = "TOPLEFT",     text = "Top Left" },
    { value = "TOPRIGHT",    text = "Top Right" },
    { value = "BOTTOMLEFT",  text = "Bottom Left" },
    { value = "BOTTOMRIGHT", text = "Bottom Right" },
    { value = "CENTER",      text = "Center" },
}
local VISIBILITY_OPTIONS = {
    { value = "always",  text = "Always" },
    { value = "combat",  text = "In Combat" },
    { value = "hostile", text = "Hostile Target" },
}
local STRATA_OPTIONS = {
    { value = "LOW",    text = "Low" },
    { value = "MEDIUM", text = "Medium" },
    { value = "HIGH",   text = "High" },
    { value = "DIALOG", text = "Dialog" },
}

-- Build a LEM dropdown generator that correctly maps option.value <-> option.text.
-- LEM's `values = ...` shortcut stores option.text in the setting instead of
-- option.value, which breaks enum-style settings.
local function MakeDropdownGenerator(options, fallbackText)
    return function(dropdown, rootDescription, settingObject)
        local layoutName = LEM and LEM.GetActiveLayoutName and LEM.GetActiveLayoutName() or "Default"
        local current = settingObject.get(layoutName)
        local currentText = fallbackText
        for _, opt in ipairs(options) do
            if opt.value == current then currentText = opt.text; break end
        end
        dropdown:SetDefaultText(currentText)
        for _, opt in ipairs(options) do
            local optText, optValue = opt.text, opt.value
            rootDescription:CreateButton(optText, function()
                dropdown:SetDefaultText(optText)
                settingObject.set(layoutName, optValue)
            end)
        end
    end
end

local function BuildLEMSettings()
    local settings = {}
    local order = 1
    local function refresh() RefreshRotationAssistIcon() end
    local function get(key, default)
        return function()
            local db = GetDB()
            local v = db and db[key]
            if v == nil then return default end
            return v
        end
    end
    local function set(key)
        return function(_, value)
            local db = GetDB()
            if db then db[key] = value; refresh() end
        end
    end

    -- ICON
    table.insert(settings, {
        order = order, name = "Icon", kind = LEM.SettingType.Collapsible,
        id = "RAI_ICON", defaultCollapsed = false,
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_ICON", order = order, name = "Icon Size",
        kind = LEM.SettingType.Slider, default = 56,
        minValue = 16, maxValue = 200, valueStep = 1,
        get = get("iconSize", 56), set = set("iconSize"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_ICON", order = order, name = "Frame Strata",
        kind = LEM.SettingType.Dropdown, default = "MEDIUM", useOldStyle = true,
        generator = MakeDropdownGenerator(STRATA_OPTIONS, "Medium"),
        get = get("frameStrata", "MEDIUM"), set = set("frameStrata"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_ICON", order = order, name = "Visibility",
        kind = LEM.SettingType.Dropdown, default = "always", useOldStyle = true,
        generator = MakeDropdownGenerator(VISIBILITY_OPTIONS, "Always"),
        get = get("visibility", "always"), set = set("visibility"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_ICON", order = order, name = "Cooldown Swipe",
        kind = LEM.SettingType.Checkbox, default = true,
        get = get("cooldownSwipeEnabled", true), set = set("cooldownSwipeEnabled"),
    }); order = order + 1

    -- BORDER
    table.insert(settings, {
        order = order, name = "Border", kind = LEM.SettingType.Collapsible,
        id = "RAI_BORDER", defaultCollapsed = true,
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_BORDER", order = order, name = "Show Border",
        kind = LEM.SettingType.Checkbox, default = true,
        get = get("showBorder", true), set = set("showBorder"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_BORDER", order = order, name = "Border Size",
        kind = LEM.SettingType.Slider, default = 2,
        minValue = 0, maxValue = 15, valueStep = 1,
        get = get("borderThickness", 2), set = set("borderThickness"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_BORDER", order = order, name = "Border Color",
        kind = LEM.SettingType.Color, default = { 0, 0, 0, 1 },
        get = function()
            local db = GetDB()
            local c = db and db.borderColor or { 0, 0, 0, 1 }
            return c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1
        end,
        set = function(_, r, g, b, a)
            local db = GetDB(); if not db then return end
            if type(r) == "table" then
                db.borderColor = { r.r or 0, r.g or 0, r.b or 0, r.a or 1 }
            else
                db.borderColor = { r or 0, g or 0, b or 0, a or 1 }
            end
            refresh()
        end,
    }); order = order + 1

    -- KEYBIND
    table.insert(settings, {
        order = order, name = "Keybind", kind = LEM.SettingType.Collapsible,
        id = "RAI_KEYBIND", defaultCollapsed = true,
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_KEYBIND", order = order, name = "Show Keybind",
        kind = LEM.SettingType.Checkbox, default = true,
        get = get("showKeybind", true), set = set("showKeybind"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_KEYBIND", order = order, name = "Keybind Size",
        kind = LEM.SettingType.Slider, default = 13,
        minValue = 6, maxValue = 48, valueStep = 1,
        get = get("keybindSize", 13), set = set("keybindSize"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_KEYBIND", order = order, name = "Keybind Anchor",
        kind = LEM.SettingType.Dropdown, default = "BOTTOMRIGHT", useOldStyle = true,
        generator = MakeDropdownGenerator(ANCHOR_OPTIONS, "Bottom Right"),
        get = get("keybindAnchor", "BOTTOMRIGHT"), set = set("keybindAnchor"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_KEYBIND", order = order, name = "Keybind X Offset",
        kind = LEM.SettingType.Slider, default = -2,
        minValue = -50, maxValue = 50, valueStep = 1,
        get = get("keybindOffsetX", -2), set = set("keybindOffsetX"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_KEYBIND", order = order, name = "Keybind Y Offset",
        kind = LEM.SettingType.Slider, default = 2,
        minValue = -50, maxValue = 50, valueStep = 1,
        get = get("keybindOffsetY", 2), set = set("keybindOffsetY"),
    }); order = order + 1

    table.insert(settings, {
        parentId = "RAI_KEYBIND", order = order, name = "Keybind Color",
        kind = LEM.SettingType.Color, default = { 1, 1, 1, 1 },
        get = function()
            local db = GetDB()
            local c = db and db.keybindColor or { 1, 1, 1, 1 }
            return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
        end,
        set = function(_, r, g, b, a)
            local db = GetDB(); if not db then return end
            if type(r) == "table" then
                db.keybindColor = { r.r or 1, r.g or 1, r.b or 1, r.a or 1 }
            else
                db.keybindColor = { r or 1, g or 1, b or 1, a or 1 }
            end
            refresh()
        end,
    }); order = order + 1

    return settings
end

local function RegisterWithLEM()
    if not LEM or lemRegistered or not iconFrame then return end

    iconFrame.editModeName = "Rotation Assist Icon"

    local db = GetDB()
    local defaults = {
        point = "CENTER",
        x = (db and db.positionX) or 0,
        y = (db and db.positionY) or -180,
    }

    local ok = pcall(function()
        LEM:AddFrame(iconFrame, OnLEMPositionChanged, defaults)
        LEM:AddFrameSettings(iconFrame, BuildLEMSettings())
        LEM:SetFrameDragEnabled(iconFrame, function()
            return LEM.IsInEditMode and LEM:IsInEditMode() or false
        end)
        if LEM.SetFrameResetVisible then
            LEM:SetFrameResetVisible(iconFrame, function()
                return LEM.IsInEditMode and LEM:IsInEditMode() or false
            end)
        end

        -- Preview: force-show the icon during Edit Mode with a placeholder
        -- texture so the frame is visible even when no spell is recommended.
        LEM:RegisterCallback("enter", function()
            if not iconFrame then return end
            iconFrame._suiEditModePreview = true
            iconFrame.icon:SetTexture("Interface\\Icons\\Ability_Warrior_Savageblow")
            iconFrame.icon:SetVertexColor(1, 1, 1, 1)
            if iconFrame.cooldown then iconFrame.cooldown:Clear() end
            if iconFrame.keybindText then iconFrame.keybindText:Hide() end
            iconFrame:Show()
        end)
        LEM:RegisterCallback("exit", function()
            if not iconFrame then return end
            iconFrame._suiEditModePreview = nil
            RefreshIconFrame()
        end)
    end)

    if ok then
        lemRegistered = true

        -- Blue-border overlay for visual feedback (same idiom as other frames)
        if not iconFrame._editModeOverlay then
            local overlay = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
            overlay:SetAllPoints(iconFrame)
            overlay:SetFrameLevel(iconFrame:GetFrameLevel() + 1)
            overlay:SetBackdrop({
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 2,
            })
            overlay:SetBackdropBorderColor(0.3, 0.8, 1, 0.6)
            overlay:Hide()
            iconFrame._editModeOverlay = overlay
        end
    end
end

-- Hook the existing PLAYER_ENTERING_WORLD handler's frame creation: register
-- with LEM once after CreateIconFrame runs. We do this via a retry timer
-- because the initial event fires 0.5s deferred.
local lemInitTries = 0
local function TryRegisterLEM()
    if lemRegistered then return end
    if iconFrame then
        RegisterWithLEM()
        return
    end
    lemInitTries = lemInitTries + 1
    if lemInitTries < 20 then
        C_Timer.After(0.5, TryRegisterLEM)
    end
end
C_Timer.After(1.0, TryRegisterLEM)

--------------------------------------------------------------------------------
-- Export
--------------------------------------------------------------------------------

SUI.RotationAssistIcon = {
    Refresh = RefreshRotationAssistIcon,
    GetFrame = function() return iconFrame end,
}






