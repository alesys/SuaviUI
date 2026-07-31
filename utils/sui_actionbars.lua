--[[
    SUI Action Bars - Button Skinning and Fade System
    Hooks Blizzard action buttons for visual customization
]]

local ADDON_NAME, ns = ...
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- MIDNIGHT (12.0+) DETECTION
---------------------------------------------------------------------------

local IS_MIDNIGHT = select(4, GetBuildInfo()) >= 120000

-- Extra action / zone ability customization.
-- Reason for the original DISABLE: `blizzFrame:SetParent(holder)` on
-- ExtraActionBarFrame / ZoneAbilityFrame taints those protected frames,
-- which then propagates into Blizzard's EditMode:UpdateBottomActionBarPositions
-- chain and blocks UIParentRightManagedFrameContainer:ClearAllPoints()
-- (session 5854+).
--
-- v0.3.23 fix: keep the customization (so the user gets the two separate
-- movers in Edit Mode) but DROP the SetParent call. We only re-anchor via
-- hooksecurefunc on the blizz frame's SetPoint — that's non-secure and
-- doesn't propagate taint into the Edit Mode managed-frame container.
local DISABLE_EXTRA_BUTTON_CUSTOMIZATION = false
-- TAINT-FIX (session 4942 → refactored): all Blizzard frame field writes moved to
-- module-level weak tables below.  Safe to enable.
local DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION = false

---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------

-- In-housed textures (self-contained, no external dependencies)
local TEXTURE_PATH = [[Interface\AddOns\SuaviUI\assets\iconskin\]]
local TEXTURES = {
    normal = TEXTURE_PATH .. "Normal",       -- Black border frame
    gloss = TEXTURE_PATH .. "Gloss",         -- ADD blend shine
    highlight = TEXTURE_PATH .. "Highlight", -- Hover state
    pushed = TEXTURE_PATH .. "Pushed",       -- Click state
    checked = TEXTURE_PATH .. "Checked",     -- Selected state
    flash = TEXTURE_PATH .. "Flash",         -- Ready flash
}

-- Icon texture coordinates (crop transparent edges)
local ICON_TEXCOORD = {0.07, 0.93, 0.07, 0.93}

-- Blizzard's range indicator placeholder (to detect and hide)
local RANGE_INDICATOR = RANGE_INDICATOR or "●"

-- Bar frame name mappings
local BAR_FRAMES = {
    bar1 = "MainMenuBar",
    bar2 = "MultiBarBottomLeft",
    bar3 = "MultiBarBottomRight",
    bar4 = "MultiBarRight",
    bar5 = "MultiBarLeft",
    bar6 = "MultiBar5",
    bar7 = "MultiBar6",
    bar8 = "MultiBar7",
    pet = "PetActionBar",
    stance = "StanceBar",
    -- Non-standard bars (special handling in GetBarButtons)
    microbar = "MicroMenuContainer",
    bags = "BagsBar",
    extraActionButton = "ExtraActionBarFrame",  -- Boss encounters, quests
    zoneAbility = "ZoneAbilityFrame",          -- Garrison, covenant, zone powers
}

-- Button name patterns for each bar
local BUTTON_PATTERNS = {
    bar1 = "ActionButton%d",
    bar2 = "MultiBarBottomLeftButton%d",
    bar3 = "MultiBarBottomRightButton%d",
    bar4 = "MultiBarRightButton%d",
    bar5 = "MultiBarLeftButton%d",
    bar6 = "MultiBar5Button%d",
    bar7 = "MultiBar6Button%d",
    bar8 = "MultiBar7Button%d",
    pet = "PetActionButton%d",
    stance = "StanceButton%d",
}

-- Button counts per bar
local BUTTON_COUNTS = {
    bar1 = 12, bar2 = 12, bar3 = 12, bar4 = 12, bar5 = 12,
    bar6 = 12, bar7 = 12, bar8 = 12, pet = 10, stance = 10,
}

-- Binding command prefixes for LibKeyBound integration
local BINDING_COMMANDS = {
    bar1 = "ACTIONBUTTON",           -- ACTIONBUTTON1-12
    bar2 = "MULTIACTIONBAR1BUTTON",  -- MULTIACTIONBAR1BUTTON1-12
    bar3 = "MULTIACTIONBAR2BUTTON",  -- MULTIACTIONBAR2BUTTON1-12
    bar4 = "MULTIACTIONBAR3BUTTON",  -- MULTIACTIONBAR3BUTTON1-12
    bar5 = "MULTIACTIONBAR4BUTTON",  -- MULTIACTIONBAR4BUTTON1-12
    bar6 = "MULTIACTIONBAR5BUTTON",  -- MULTIACTIONBAR5BUTTON1-12
    bar7 = "MULTIACTIONBAR6BUTTON",  -- MULTIACTIONBAR6BUTTON1-12
    bar8 = "MULTIACTIONBAR7BUTTON",  -- MULTIACTIONBAR7BUTTON1-12
    pet = "BONUSACTIONBUTTON",       -- BONUSACTIONBUTTON1-10
    stance = "SHAPESHIFTBUTTON",     -- SHAPESHIFTBUTTON1-10
}

---------------------------------------------------------------------------
-- MODULE STATE
---------------------------------------------------------------------------

local ActionBars = {
    initialized = false,
    skinnedButtons = {},        -- Track which buttons have been skinned
    fadeState = {},             -- Per-bar fade state tracking
    fadeFrame = nil,            -- OnUpdate frame for smooth fading
}

-- Weak tables for tracking state on Blizzard frames (avoids field-write taint).
-- Writing any field onto a Blizzard-owned frame taints it; using weak tables keyed
-- by frame object keeps tracking data in addon-owned memory instead.
local weakMeta = { __mode = "k" }
local strippedButtons        = setmetatable({}, weakMeta)
local skinKeys               = setmetatable({}, weakMeta)
local buttonBackdrops        = setmetatable({}, weakMeta)
local buttonNormals          = setmetatable({}, weakMeta)
local buttonGlosses          = setmetatable({}, weakMeta)
local hiddenEmptyButtons     = setmetatable({}, weakMeta)
local tintedButtons          = setmetatable({}, weakMeta)
local mouseoverHookedFrames  = setmetatable({}, weakMeta)
local onEnterHookedButtons   = setmetatable({}, weakMeta)
local visibilityHookedFrames = setmetatable({}, weakMeta)
local positionHookedFrames   = setmetatable({}, weakMeta)
local showHookedFrames       = setmetatable({}, weakMeta)
local bindingCommands        = setmetatable({}, weakMeta)
local keybindMethodsAdded    = setmetatable({}, weakMeta)

---------------------------------------------------------------------------
-- HELPER FUNCTIONS
---------------------------------------------------------------------------

-- Safe wrapper for HasAction which may return secret values in Midnight
local function SafeHasAction(action)
    if IS_MIDNIGHT then
        local ok, result = pcall(function()
            local has = HasAction(action)
            -- Force comparison to detect secrets
            if has then return true end
            return false
        end)
        if not ok then return true end  -- Secret value, treat as having action
        return result
    else
        return HasAction(action)
    end
end

local function GetDB()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if not SUICore or not SUICore.db or not SUICore.db.profile then
        return nil
    end
    return SUICore.db.profile.actionBars
end

local function GetGlobalSettings()
    local db = GetDB()
    return db and db.global
end

local function GetBarSettings(barKey)
    local db = GetDB()
    return db and db.bars and db.bars[barKey]
end

local function GetFadeSettings()
    local db = GetDB()
    return db and db.fade
end

-- Determine bar key from button name
local function GetBarKeyFromButton(button)
    local name = button and button:GetName()
    if not name then return nil end

    if name:match("^ActionButton%d+$") then return "bar1" end
    if name:match("^MultiBarBottomLeftButton%d+$") then return "bar2" end
    if name:match("^MultiBarBottomRightButton%d+$") then return "bar3" end
    if name:match("^MultiBarRightButton%d+$") then return "bar4" end
    if name:match("^MultiBarLeftButton%d+$") then return "bar5" end
    if name:match("^MultiBar5Button%d+$") then return "bar6" end
    if name:match("^MultiBar6Button%d+$") then return "bar7" end
    if name:match("^MultiBar7Button%d+$") then return "bar8" end
    if name:match("^PetActionButton%d+$") then return "pet" end
    if name:match("^StanceButton%d+$") then return "stance" end
    return nil
end

-- Get button index from button name
local function GetButtonIndex(button)
    local name = button and button:GetName()
    if not name then return nil end
    return tonumber(name:match("%d+$"))
end

-- Add LibKeyBound methods to a button for mousewheel binding support
local function AddKeybindMethods(button, barKey)
    if not button or keybindMethodsAdded[button] then return end

    local bindingPrefix = BINDING_COMMANDS[barKey]
    if not bindingPrefix then return end

    local buttonIndex = GetButtonIndex(button)
    if not buttonIndex then return end

    local bindingCommand = bindingPrefix .. buttonIndex
    bindingCommands[button] = bindingCommand
    keybindMethodsAdded[button] = true

    -- Required method: Returns current keybind text
    function button:GetHotkey()
        local cmd = bindingCommands[self]
        if not cmd then return nil end
        local key = GetBindingKey(cmd)
        if key then
            local LibKeyBound = LibStub("LibKeyBound-1.0", true)
            return LibKeyBound and LibKeyBound:ToShortKey(key) or key
        end
        return nil
    end

    -- Required method: Binds a key to this button
    function button:SetKey(key)
        if InCombatLockdown() then return end
        local cmd = bindingCommands[self]
        if cmd then SetBinding(key, cmd) end
    end

    -- Optional method: Returns all bindings as comma-separated string
    function button:GetBindings()
        local cmd = bindingCommands[self]
        if not cmd then return nil end
        local keys = {}
        for i = 1, select("#", GetBindingKey(cmd)) do
            local key = select(i, GetBindingKey(cmd))
            if key then
                table.insert(keys, key)
            end
        end
        return #keys > 0 and table.concat(keys, ", ") or nil
    end

    -- Optional method: Clears all bindings from this button
    function button:ClearBindings()
        if InCombatLockdown() then return end
        local cmd = bindingCommands[self]
        if not cmd then return end
        while GetBindingKey(cmd) do
            SetBinding(GetBindingKey(cmd), nil)
        end
    end

    -- Optional method: Returns display name for what we're binding
    function button:GetActionName()
        return bindingCommands[self]
    end
end

-- Get effective settings for a bar (merges global with per-bar overrides)
local function GetEffectiveSettings(barKey)
    local global = GetGlobalSettings()
    if not global then return nil end

    local barSettings = GetBarSettings(barKey)

    -- If overrides are disabled or bar doesn't support overrides, use global
    if not barSettings or not barSettings.overrideEnabled then
        return global
    end

    -- Merge: global as base, bar-specific overrides non-nil values
    local effective = {}
    for key, value in pairs(global) do
        effective[key] = value
    end

    -- Override with bar-specific values (only if not nil)
    local overrideKeys = {
        "iconZoom", "showBackdrop", "backdropAlpha", "showGloss", "glossAlpha",
        "showKeybinds", "hideEmptyKeybinds", "keybindFontSize", "keybindColor",
        "keybindAnchor", "keybindOffsetX", "keybindOffsetY",
        "showMacroNames", "macroNameFontSize", "macroNameColor",
        "macroNameAnchor", "macroNameOffsetX", "macroNameOffsetY",
        "showCounts", "countFontSize", "countColor",
        "countAnchor", "countOffsetX", "countOffsetY",
    }

    for _, key in ipairs(overrideKeys) do
        if barSettings[key] ~= nil then
            effective[key] = barSettings[key]
        end
    end

    return effective
end

-- Get buttons for a specific bar
local function GetBarButtons(barKey)
    local buttons = {}

    -- Special handling for non-standard bars
    if barKey == "microbar" then
        -- MicroMenu contains the micro buttons (Character, Spellbook, etc.)
        if MicroMenu then
            for _, child in ipairs({MicroMenu:GetChildren()}) do
                if child.IsObjectType and child:IsObjectType("Button") then
                    table.insert(buttons, child)
                end
            end
        end
        return buttons
    elseif barKey == "bags" then
        -- Bag slots: backpack + 4 bag slots + reagent bag
        if MainMenuBarBackpackButton then
            table.insert(buttons, MainMenuBarBackpackButton)
        end
        for i = 0, 3 do
            local slot = _G["CharacterBag" .. i .. "Slot"]
            if slot then table.insert(buttons, slot) end
        end
        if CharacterReagentBag0Slot then
            table.insert(buttons, CharacterReagentBag0Slot)
        end
        return buttons
    elseif barKey == "extraActionButton" then
        -- Extra Action Button (boss encounters, quests)
        if ExtraActionBarFrame and ExtraActionBarFrame.button then
            table.insert(buttons, ExtraActionBarFrame.button)
        end
        return buttons
    elseif barKey == "zoneAbility" then
        -- Zone Ability buttons (garrison, covenant, zone powers)
        if ZoneAbilityFrame and ZoneAbilityFrame.SpellButtonContainer then
            for button in ZoneAbilityFrame.SpellButtonContainer:EnumerateActive() do
                table.insert(buttons, button)
            end
        end
        return buttons
    end

    -- Standard bars with numbered buttons
    local pattern = BUTTON_PATTERNS[barKey]
    local count = BUTTON_COUNTS[barKey] or 12

    if not pattern then return buttons end

    for i = 1, count do
        local buttonName = string.format(pattern, i)
        local button = _G[buttonName]
        if button then
            table.insert(buttons, button)
        end
    end

    return buttons
end

-- Get the bar container frame
local function GetBarFrame(barKey)
    local frameName = BAR_FRAMES[barKey]
    return frameName and _G[frameName]
end

---------------------------------------------------------------------------
-- EXTRA BUTTON CUSTOMIZATION (Extra Action Button & Zone Ability)
---------------------------------------------------------------------------

local extraActionHolder = nil
local extraActionMover = nil
local zoneAbilityHolder = nil
local zoneAbilityMover = nil
local extraButtonMoversVisible = false
local HookExtraButtonPositioning

-- Get settings for a specific extra button type
local function GetExtraButtonDB(buttonType)
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if not SUICore or not SUICore.db or not SUICore.db.profile then return nil end
    return SUICore.db.profile.actionBars and SUICore.db.profile.actionBars.bars
        and SUICore.db.profile.actionBars.bars[buttonType]
end

-- Extra Action Button content check (avoid empty frame on reload)
local function HasExtraActionContent()
    if not HasExtraActionBar then
        return false
    end
    local okHas, hasBar = pcall(HasExtraActionBar)
    if not okHas or not hasBar then
        return false
    end
    if not ExtraActionBarFrame or not ExtraActionBarFrame.button then
        return false
    end

    local button = ExtraActionBarFrame.button
    local action = button.action or (button.GetAttribute and button:GetAttribute("action"))
    if not action then
        return false
    end

    if GetActionInfo then
        local okInfo, actionType = pcall(GetActionInfo, action)
        if not okInfo or not actionType then
            return false
        end
    end

    if GetActionTexture then
        local okTex, tex = pcall(GetActionTexture, action)
        if okTex and tex then
            return true
        end
    end

    local icon = button.icon or button.Icon
    if icon and icon.GetTexture and not icon:GetTexture() then
        return false
    end

    return true
end

-- Create holder frame and mover overlay for an extra button type
local function CreateExtraButtonHolder(buttonType, displayName)
    local settings = GetExtraButtonDB(buttonType)
    if not settings then return nil, nil end

    -- Create holder frame (MUST be movable for LEM dragging).
    -- The holder is invisible (no backdrop / no texture) and acts purely as a
    -- position anchor. Mouse interaction lives on the `mover` overlay below
    -- (and on LEM's Selection overlay during Edit Mode), so EnableMouse must
    -- stay false — otherwise the invisible holder silently eats clicks within
    -- its 64x64 bounding box.
    local holder = CreateFrame("Frame", "SUI_" .. buttonType .. "Holder", UIParent)
    holder:SetSize(64, 64)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:EnableMouse(false)
    holder:RegisterForDrag("LeftButton")

    -- Load saved position or default to center-bottom
    local pos = settings.position
    if pos and pos.point then
        holder:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        -- Default positions: Extra Action left of center, Zone Ability right of center
        if buttonType == "extraActionButton" then
            holder:SetPoint("CENTER", UIParent, "CENTER", -100, -200)
        else
            holder:SetPoint("CENTER", UIParent, "CENTER", 100, -200)
        end
    end

    -- Create mover overlay (visible only when toggled)
    local mover = CreateFrame("Frame", "SUI_" .. buttonType .. "Mover", holder, "BackdropTemplate")
    mover:SetAllPoints(holder)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    mover:SetBackdropColor(0.2, 0.8, 1, 0.3)  -- Light blue to match Edit Mode
    mover:SetBackdropBorderColor(0.3, 0.8, 1, 1)  -- Light blue border
    mover:EnableMouse(true)
    mover:SetMovable(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetFrameStrata("MEDIUM")  -- Match resource powerbar strata
    mover:Hide()

    -- Label text
    local text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetText(displayName)
    mover.text = text

    -- Drag handlers
    mover:SetScript("OnDragStart", function(self)
        if InCombatLockdown() or (holder.IsProtected and holder:IsProtected()) then
            return
        end
        holder:StartMoving()
    end)

    mover:SetScript("OnDragStop", function(self)
        holder:StopMovingOrSizing()
        local point, _, relPoint, x, y = holder:GetPoint()
        local db = GetExtraButtonDB(buttonType)
        if db then
            db.position = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)

    return holder, mover
end

-- Apply settings (scale, position, artwork) to an extra button frame
local function ApplyExtraButtonSettings(buttonType)
    if DISABLE_EXTRA_BUTTON_CUSTOMIZATION then return end

    if InCombatLockdown() then
        ActionBars.pendingExtraButtonRefresh = true
        return
    end

    local settings = GetExtraButtonDB(buttonType)
    if not settings or (not settings.enabled and not settings._editModeActive) then return end

    local blizzFrame
    local holder, mover

    if buttonType == "extraActionButton" then
        blizzFrame = ExtraActionBarFrame
        holder = extraActionHolder
        mover = extraActionMover
    else
        blizzFrame = ZoneAbilityFrame
        holder = zoneAbilityHolder
        mover = zoneAbilityMover
    end

    if not holder then return end
    if not blizzFrame then
        ActionBars.extraButtonRetry = ActionBars.extraButtonRetry or {}
        local retries = ActionBars.extraButtonRetry[buttonType] or 0
        if retries < 10 then
            ActionBars.extraButtonRetry[buttonType] = retries + 1
            C_Timer.After(0.5, function()
                ApplyExtraButtonSettings(buttonType)
            end)
        end
        return
    end

    -- Apply scale
    local scale = settings.scale or 1.0
    blizzFrame:SetScale(scale)

    -- Apply offsets (relative to holder position)
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 0

    -- TAINT-SAFE: anchor (SetPoint), but DO NOT reparent. SetParent on a
    -- protected frame from addon context taints it and cascades into Edit Mode
    -- layout. SetPoint is non-secure and safe even across parents — Blizzard's
    -- ExtraAbilityContainer keeps managing the parent / show state, while we
    -- override only the visual position.
    blizzFrame:ClearAllPoints()
    blizzFrame:SetPoint("CENTER", holder, "CENTER", offsetX, offsetY)

    -- Size the holder to roughly match the scaled blizz frame so the LEM
    -- mover overlay has the right hitbox.
    local width = (blizzFrame:GetWidth() or 64) * scale
    local height = (blizzFrame:GetHeight() or 64) * scale
    holder:SetSize(math.max(width, 64), math.max(height, 64))

    -- Hide artwork if enabled
    if settings.hideArtwork then
        if buttonType == "extraActionButton" and blizzFrame.button and blizzFrame.button.style then
            blizzFrame.button.style:SetAlpha(0)
        end
        if buttonType == "zoneAbility" and blizzFrame.Style then
            blizzFrame.Style:SetAlpha(0)
        end
    else
        -- Restore artwork
        if buttonType == "extraActionButton" and blizzFrame.button and blizzFrame.button.style then
            blizzFrame.button.style:SetAlpha(1)
        end
        if buttonType == "zoneAbility" and blizzFrame.Style then
            blizzFrame.Style:SetAlpha(1)
        end
    end

    -- Reset frame alpha if fade is not enabled (fixes toggling fade off without reload)
    if not settings.fadeEnabled then
        blizzFrame:SetAlpha(1)
    end
    
    -- Handle "Always Show" for positioning purposes
    -- Show holder when: Edit Mode active OR Always Show enabled OR button has content
    if holder then
        local function SetHolderVisible(isVisible)
            if isVisible then
                holder:Show()
                -- Holder mouse stays disabled — the invisible holder must never
                -- intercept clicks. The `mover` overlay (shown in Edit Mode /
                -- via toggle) and LEM's Selection overlay handle drag.
                holder:EnableMouse(false)
                -- TAINT-FIX: Don't call Show()/Hide()/EnableMouse() on protected
                -- ExtraActionBarFrame. Alpha 0/1 controls visibility.
                if blizzFrame then
                    blizzFrame:SetAlpha(1)
                end
            else
                holder:Hide()
                holder:EnableMouse(false)
                if blizzFrame then
                    blizzFrame:SetAlpha(0)
                end
            end
        end

        if settings._editModeActive or settings.alwaysShow then
            SetHolderVisible(true)
        else
            -- Check if button actually has content (not just frame visibility)
            local hasContent = false
            if buttonType == "extraActionButton" then
                hasContent = HasExtraActionContent()
            elseif buttonType == "zoneAbility" then
                -- Zone ability: check if there are any active buttons in the container
                if ZoneAbilityFrame and ZoneAbilityFrame.SpellButtonContainer then
                    for button in ZoneAbilityFrame.SpellButtonContainer:EnumerateActive() do
                        hasContent = true
                        break  -- Just need one active button to know there's content
                    end
                end
            end
            
            SetHolderVisible(hasContent)
        end
    end
    
    -- Setup visibility tracking hook (only once per button)
    if blizzFrame and not visibilityHookedFrames[blizzFrame] then
        visibilityHookedFrames[blizzFrame] = true
        
        -- Mirror Blizzard frame visibility changes to our holder
        -- But only show if button actually has content
        blizzFrame:HookScript("OnShow", function()
            local s = GetExtraButtonDB(buttonType)
            if holder and not (s and (s._editModeActive or s.alwaysShow)) then
                -- Verify there's actually content before showing
                local hasContent = false
                if buttonType == "extraActionButton" then
                    hasContent = HasExtraActionContent()
                elseif buttonType == "zoneAbility" then
                    -- Check if there are any active buttons in the container
                    if ZoneAbilityFrame and ZoneAbilityFrame.SpellButtonContainer then
                        for button in ZoneAbilityFrame.SpellButtonContainer:EnumerateActive() do
                            hasContent = true
                            break
                        end
                    end
                end
                -- TAINT-FIX: defer Show() out of any secure call chain (e.g.
                -- ExtraAbilityContainer:AddFrame → SetShown → EditModeSystemTemplates:168)
                -- to avoid ADDON_ACTION_BLOCKED on named frame.
                if hasContent then
                    C_Timer.After(0, function()
                        local ss = GetExtraButtonDB(buttonType)
                        if not (ss and (ss._editModeActive or ss.alwaysShow)) then
                            holder:Show()
                            -- Holder mouse stays disabled — see CreateExtraButtonHolder.
                            holder:EnableMouse(false)
                            -- TAINT-FIX: Don't call Show()/EnableMouse() on protected
                            -- ExtraActionBarFrame. Alpha 0/1 controls visibility;
                            -- Blizzard manages mouse interaction natively.
                            blizzFrame:SetAlpha(1)
                        end
                    end)
                else
                    -- No content - hide both holder and Blizzard frame to prevent mouse blocking
                    C_Timer.After(0, function()
                        holder:Hide()
                        holder:EnableMouse(false)
                        blizzFrame:SetAlpha(0)
                    end)
                end
            end
        end)
        
        blizzFrame:HookScript("OnHide", function()
            local s = GetExtraButtonDB(buttonType)
            if holder and not (s and (s._editModeActive or s.alwaysShow)) then
                -- TAINT-FIX: defer Hide() out of any secure call chain (e.g. CinematicFrame
                -- → ShowUIPanel → SetAttribute) to avoid ADDON_ACTION_BLOCKED on named frame.
                C_Timer.After(0, function()
                    if holder and not holder:IsShown() then return end  -- already hidden, skip
                    if InCombatLockdown() then
                        -- Can't hide protected named frame during combat; defer to combat end
                        ActionBars.pendingExtraButtonHide = ActionBars.pendingExtraButtonHide or {}
                        ActionBars.pendingExtraButtonHide[holder] = buttonType
                        return
                    end
                    local ss = GetExtraButtonDB(buttonType)
                    if not (ss and (ss._editModeActive or ss.alwaysShow)) then
                        holder:Hide()
                        holder:EnableMouse(false)
                    end
                end)
            end
        end)
    end

    -- Ensure positioning hooks are installed once frames exist
    HookExtraButtonPositioning()
end

-- Flag to prevent recursive SetPoint hooks
local hookingSetPoint = false

-- Hook Blizzard frames to prevent them from repositioning
HookExtraButtonPositioning = function()
    if DISABLE_EXTRA_BUTTON_CUSTOMIZATION then return end

    -- Hook ExtraActionBarFrame
    if ExtraActionBarFrame and not positionHookedFrames[ExtraActionBarFrame] then
        positionHookedFrames[ExtraActionBarFrame] = true
        pcall(hooksecurefunc, ExtraActionBarFrame, "SetPoint", function(self)
            if hookingSetPoint or InCombatLockdown() then return end
            -- Don't interfere during Edit Mode - let LEM handle positioning
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
            if extraActionHolder and GetExtraButtonDB("extraActionButton") then
                local settings = GetExtraButtonDB("extraActionButton")
                if settings and settings.enabled then
                    hookingSetPoint = true
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", extraActionHolder, "CENTER",
                        settings.offsetX or 0, settings.offsetY or 0)
                    hookingSetPoint = false
                end
            end
        end)
    end

    -- Hook ZoneAbilityFrame
    if ZoneAbilityFrame and not positionHookedFrames[ZoneAbilityFrame] then
        positionHookedFrames[ZoneAbilityFrame] = true
        pcall(hooksecurefunc, ZoneAbilityFrame, "SetPoint", function(self)
            if hookingSetPoint or InCombatLockdown() then return end
            -- Don't interfere during Edit Mode - let LEM handle positioning
            if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return end
            if zoneAbilityHolder and GetExtraButtonDB("zoneAbility") then
                local settings = GetExtraButtonDB("zoneAbility")
                if settings and settings.enabled then
                    hookingSetPoint = true
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", zoneAbilityHolder, "CENTER",
                        settings.offsetX or 0, settings.offsetY or 0)
                    hookingSetPoint = false
                end
            end
        end)
    end

    -- Avoid modifying Blizzard's managed frame container here.
    -- Direct table edits can taint Edit Mode layout updates in 12.0.5.
end

-- Show/hide mover overlays
local function ShowExtraButtonMovers()
    extraButtonMoversVisible = true
    if extraActionMover then extraActionMover:Show() end
    if zoneAbilityMover then zoneAbilityMover:Show() end
end

local function HideExtraButtonMovers()
    extraButtonMoversVisible = false
    if extraActionMover then extraActionMover:Hide() end
    if zoneAbilityMover then zoneAbilityMover:Hide() end
end

local function ToggleExtraButtonMovers()
    if extraButtonMoversVisible then
        HideExtraButtonMovers()
    else
        ShowExtraButtonMovers()
    end
end

-- Initialize extra button holders
local function InitializeExtraButtons()
    if DISABLE_EXTRA_BUTTON_CUSTOMIZATION then return end

    if InCombatLockdown() then
        ActionBars.pendingExtraButtonInit = true
        return
    end

    -- Create holder frames
    extraActionHolder, extraActionMover = CreateExtraButtonHolder("extraActionButton", "Extra Action Button")
    zoneAbilityHolder, zoneAbilityMover = CreateExtraButtonHolder("zoneAbility", "Zone Ability")

    -- Expose holders globally for Edit Mode registration
    _G.SUI_extraActionButtonHolder = extraActionHolder
    _G.SUI_zoneAbilityHolder = zoneAbilityHolder

    -- Apply settings with delay to ensure Blizzard frames exist
    C_Timer.After(0.5, function()
        ApplyExtraButtonSettings("extraActionButton")
        ApplyExtraButtonSettings("zoneAbility")
        HookExtraButtonPositioning()
        
        -- Register with Edit Mode if available
        C_Timer.After(1.5, function()
            if _G.SuaviUI_AB_EditMode_Register then
                if extraActionHolder then
                    _G.SuaviUI_AB_EditMode_Register("extraActionButton", extraActionHolder)
                end
                
                if zoneAbilityHolder then
                    _G.SuaviUI_AB_EditMode_Register("zoneAbility", zoneAbilityHolder)
                end
            end
        end)
    end)
end

-- Refresh extra button settings (called from options)
local function RefreshExtraButtons()
    if DISABLE_EXTRA_BUTTON_CUSTOMIZATION then return end

    if InCombatLockdown() then
        ActionBars.pendingExtraButtonRefresh = true
        return
    end
    ApplyExtraButtonSettings("extraActionButton")
    ApplyExtraButtonSettings("zoneAbility")
end

-- Refresh a specific button (called from Edit Mode)
local function RefreshExtraButton(buttonType)
    if InCombatLockdown() then
        ActionBars.pendingExtraButtonRefresh = true
        return
    end
    ApplyExtraButtonSettings(buttonType)
end

-- Expose global functions for options panel and Edit Mode
_G.SuaviUI_ToggleExtraButtonMovers = ToggleExtraButtonMovers
_G.SuaviUI_RefreshExtraButtons = RefreshExtraButtons
_G.SuaviUI_RefreshExtraButton = RefreshExtraButton

-- Strip WoW color codes from text
local function StripColorCodes(text)
    if not text then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Check if keybind text is valid (not empty or placeholder)
local function IsValidKeybindText(text)
    if not text or text == "" then return false end

    local stripped = StripColorCodes(text)
    if stripped == "" then return false end
    if stripped == RANGE_INDICATOR then return false end
    if stripped == "[]" then return false end

    return true
end

---------------------------------------------------------------------------
-- BUTTON SKINNING
---------------------------------------------------------------------------

-- Remove Blizzard's default textures and masks
local function StripBlizzardArtwork(button)
    if strippedButtons[button] then return end
    strippedButtons[button] = true

    -- Hide NormalTexture (Blizzard's border)
    local normalTex = button:GetNormalTexture()
    if normalTex then
        normalTex:SetAlpha(0)
    end
    if button.NormalTexture then
        button.NormalTexture:SetAlpha(0)
    end

    -- Remove mask textures from icon
    local icon = button.icon or button.Icon
    if icon and icon.GetMaskTexture and icon.RemoveMaskTexture then
        for i = 1, 10 do
            local mask = icon:GetMaskTexture(i)
            if mask then
                icon:RemoveMaskTexture(mask)
            end
        end
    end

    -- Hide FloatingBG if present
    if button.FloatingBG then
        button.FloatingBG:SetAlpha(0)
    end

    -- Hide SlotBackground if present
    if button.SlotBackground then
        button.SlotBackground:SetAlpha(0)
    end

    -- Hide SlotArt if present
    if button.SlotArt then
        button.SlotArt:SetAlpha(0)
    end
end

---------------------------------------------------------------------------
-- BUTTON SKINNING
---------------------------------------------------------------------------

-- Apply SUI skin to a single button
local function SkinButton(button, settings)
    if not button or not settings or not settings.skinEnabled then return end

    -- Skip if already skinned with same settings
    local settingsKey = string.format("%d_%.2f_%s_%.2f_%s_%.2f",
        settings.iconSize or 36,
        settings.iconZoom or 0.07,
        tostring(settings.showBackdrop),
        settings.backdropAlpha or 0.8,
        tostring(settings.showGloss),
        settings.glossAlpha or 0.6
    )
    if skinKeys[button] == settingsKey then return end
    skinKeys[button] = settingsKey

    -- Strip Blizzard artwork first
    StripBlizzardArtwork(button)

    local iconSize = settings.iconSize or 36
    local zoom = settings.iconZoom or 0.07

    -- Apply icon TexCoords (crop transparent edges)
    local icon = button.icon or button.Icon
    if icon then
        icon:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
        icon:ClearAllPoints()
        icon:SetAllPoints(button)
    end

    -- Create or update backdrop (behind icon, configurable opacity)
    if settings.showBackdrop then
        if not buttonBackdrops[button] then
            buttonBackdrops[button] = button:CreateTexture(nil, "BACKGROUND", nil, -8)
            buttonBackdrops[button]:SetColorTexture(0, 0, 0, 1)
        end
        buttonBackdrops[button]:SetAlpha(settings.backdropAlpha or 0.8)
        buttonBackdrops[button]:ClearAllPoints()
        buttonBackdrops[button]:SetAllPoints(button)
        buttonBackdrops[button]:Show()
    elseif buttonBackdrops[button] then
        buttonBackdrops[button]:Hide()
    end

    -- Create or update Normal overlay (border frame texture)
    if settings.showBorders ~= false then
        if not buttonNormals[button] then
            buttonNormals[button] = button:CreateTexture(nil, "OVERLAY", nil, 1)
            buttonNormals[button]:SetTexture(TEXTURES.normal)
            buttonNormals[button]:SetVertexColor(0, 0, 0, 1)
        end
        buttonNormals[button]:SetSize(iconSize, iconSize)
        buttonNormals[button]:ClearAllPoints()
        buttonNormals[button]:SetAllPoints(button)
        buttonNormals[button]:Show()
    elseif buttonNormals[button] then
        buttonNormals[button]:Hide()
    end

    -- Create or update Gloss overlay (ADD blend shine)
    if settings.showGloss then
        if not buttonGlosses[button] then
            buttonGlosses[button] = button:CreateTexture(nil, "OVERLAY", nil, 2)
            buttonGlosses[button]:SetTexture(TEXTURES.gloss)
            buttonGlosses[button]:SetBlendMode("ADD")
        end
        buttonGlosses[button]:SetVertexColor(1, 1, 1, settings.glossAlpha or 0.6)
        buttonGlosses[button]:SetAllPoints(button)
        buttonGlosses[button]:Show()
    elseif buttonGlosses[button] then
        buttonGlosses[button]:Hide()
    end

    -- Fix Cooldown frame positioning
    local cooldown = button.cooldown or button.Cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(button)
    end

    ActionBars.skinnedButtons[button] = true
end

---------------------------------------------------------------------------
-- TEXT VISIBILITY
---------------------------------------------------------------------------

-- Update keybind/hotkey text visibility and styling
-- Directly modifies Blizzard's HotKey element with abbreviated text
local function UpdateKeybindText(button, settings)
    local hotkey = button.HotKey or button.hotKey
    if not hotkey then return end

    -- Determine if keybinds should be shown
    if not settings.showKeybinds then
        hotkey:SetAlpha(0)
        hotkey:Hide()
        return
    end

    -- Get abbreviated keybind text
    local buttonName = button:GetName()
    local bindingName = nil
    local abbreviated = nil

    if buttonName then
        local num

        -- Map button frame names to WoW binding names
        num = buttonName:match("^ActionButton(%d+)$")
        if num then bindingName = "ACTIONBUTTON" .. num end

        if not bindingName then
            num = buttonName:match("^MultiBarBottomRightButton(%d+)$")
            if num then bindingName = "MULTIACTIONBAR2BUTTON" .. num end
        end

        if not bindingName then
            num = buttonName:match("^MultiBarBottomLeftButton(%d+)$")
            if num then bindingName = "MULTIACTIONBAR1BUTTON" .. num end
        end

        if not bindingName then
            num = buttonName:match("^MultiBarRightButton(%d+)$")
            if num then bindingName = "MULTIACTIONBAR3BUTTON" .. num end
        end

        if not bindingName then
            num = buttonName:match("^MultiBarLeftButton(%d+)$")
            if num then bindingName = "MULTIACTIONBAR4BUTTON" .. num end
        end

        -- MultiBar5-7 (Midnight bars)
        if not bindingName then
            num = buttonName:match("^MultiBar5Button(%d+)$")
            if num then bindingName = "MULTIACTIONBAR5BUTTON" .. num end
        end

        if not bindingName then
            num = buttonName:match("^MultiBar6Button(%d+)$")
            if num then bindingName = "MULTIACTIONBAR6BUTTON" .. num end
        end

        if not bindingName then
            num = buttonName:match("^MultiBar7Button(%d+)$")
            if num then bindingName = "MULTIACTIONBAR7BUTTON" .. num end
        end

        -- Get keybind and abbreviate
        if bindingName then
            local key = GetBindingKey(bindingName)
            if key and ns and ns.FormatKeybind then
                abbreviated = ns.FormatKeybind(key)
            end
        end
    end

    -- Determine visibility
    local shouldShow = abbreviated and abbreviated ~= ""

    -- Only hide keybinds on empty action slots when hideEmptyKeybinds is enabled
    if shouldShow and settings.hideEmptyKeybinds then
        if button.action then
            local hasAction = SafeHasAction(button.action)
            if not hasAction then
                shouldShow = false
            end
        end
    end

    if not shouldShow then
        hotkey:SetAlpha(0)
        hotkey:Hide()
        return
    end

    -- Set the abbreviated text and show
    hotkey:SetText(abbreviated)
    hotkey:Show()
    hotkey:SetAlpha(1)

    -- Apply styling
    local fontPath = "Fonts\\FRIZQT__.TTF"
    local outline = "OUTLINE"
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general then
        local general = SUICore.db.profile.general
        if general.font and LSM then
            fontPath = LSM:Fetch("font", general.font) or fontPath
        end
        outline = general.fontOutline or outline
    end

    hotkey:SetFont(fontPath, settings.keybindFontSize or 11, outline)

    local color = settings.keybindColor
    local r = color and color[1] or 1
    local g = color and color[2] or 1
    local b = color and color[3] or 1
    local a = color and color[4] or 1
    hotkey:SetTextColor(r, g, b, a)

    -- Reposition with configurable anchor and offsets
    hotkey:ClearAllPoints()
    local anchor = settings.keybindAnchor or "TOPRIGHT"
    hotkey:SetPoint(anchor, button, anchor, (settings.keybindOffsetX or 0), (settings.keybindOffsetY or 0))
end

-- Update macro name text visibility and styling
local function UpdateMacroText(button, settings)
    local name = button.Name
    if not name then return end

    if not settings.showMacroNames then
        name:SetAlpha(0)
        return
    end

    name:SetAlpha(1)

    -- Apply styling
    local fontPath = "Fonts\\FRIZQT__.TTF"
    local outline = "OUTLINE"
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general then
        local general = SUICore.db.profile.general
        if general.font and LSM then
            fontPath = LSM:Fetch("font", general.font) or fontPath
        end
        outline = general.fontOutline or outline
    end

    name:SetFont(fontPath, settings.macroNameFontSize or 10, outline)

    local color = settings.macroNameColor
    local r = color and color[1] or 1
    local g = color and color[2] or 1
    local b = color and color[3] or 1
    local a = color and color[4] or 1
    name:SetTextColor(r, g, b, a)

    -- Reposition with configurable anchor and offsets
    name:ClearAllPoints()
    local anchor = settings.macroNameAnchor or "BOTTOM"
    name:SetPoint(anchor, button, anchor, (settings.macroNameOffsetX or 0), (settings.macroNameOffsetY or 0))
end

-- Update count/charge text visibility and styling
local function UpdateCountText(button, settings)
    local count = button.Count
    if not count then return end

    if not settings.showCounts then
        count:SetAlpha(0)
        return
    end

    count:SetAlpha(1)

    -- Apply styling
    local fontPath = "Fonts\\FRIZQT__.TTF"
    local outline = "OUTLINE"
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general then
        local general = SUICore.db.profile.general
        if general.font and LSM then
            fontPath = LSM:Fetch("font", general.font) or fontPath
        end
        outline = general.fontOutline or outline
    end

    count:SetFont(fontPath, settings.countFontSize or 14, outline)

    local color = settings.countColor
    local r = color and color[1] or 1
    local g = color and color[2] or 1
    local b = color and color[3] or 1
    local a = color and color[4] or 1
    count:SetTextColor(r, g, b, a)

    -- Reposition with configurable anchor and offsets
    count:ClearAllPoints()
    local anchor = settings.countAnchor or "BOTTOMRIGHT"
    count:SetPoint(anchor, button, anchor, (settings.countOffsetX or 0), (settings.countOffsetY or 0))
end

-- Update all text elements on a button
local function UpdateButtonText(button, settings)
    UpdateKeybindText(button, settings)
    UpdateMacroText(button, settings)
    UpdateCountText(button, settings)
end

---------------------------------------------------------------------------
-- BAR LAYOUT FEATURES
---------------------------------------------------------------------------

-- Apply global scale to all action bar container frames
-- NOTE: Disabled - action bar scaling should be done via Edit Mode for consistency
local function ApplyBarScale()
    -- No-op: Users should scale action bars via Edit Mode
end

-- Update empty slot visibility for a single button
local function UpdateEmptySlotVisibility(button, settings)
    if not settings then return end

    -- Get the bar's current fade alpha (respects mouseover hide)
    local barKey = GetBarKeyFromButton(button)
    local fadeState = barKey and ActionBars.fadeState and ActionBars.fadeState[barKey]
    local targetAlpha = fadeState and fadeState.currentAlpha or 1

    if not settings.hideEmptySlots then
        -- Restore visibility if setting is off (respect fade state)
        if hiddenEmptyButtons[button] then
            button:SetAlpha(targetAlpha)
            hiddenEmptyButtons[button] = nil
        end
        return
    end

    -- Only applies to action buttons with action property
    if button.action then
        local hasAction = SafeHasAction(button.action)
        if hasAction then
            button:SetAlpha(targetAlpha)
            hiddenEmptyButtons[button] = nil
        else
            button:SetAlpha(0)
            hiddenEmptyButtons[button] = true
        end
    end
end

-- One-time migration: if SUI lockButtons was true, apply it to Blizzard CVar
-- This preserves existing user settings after the fix that stops SUI from overwriting Blizzard's setting
local function MigrateLockSetting()
    local settings = GetGlobalSettings()
    if not settings then return end

    -- Only migrate once, and only if the user had lockButtons enabled
    if settings.lockButtons and not settings._lockMigrated then
        SetCVar('lockActionBars', '1')
        settings._lockMigrated = true
    end
end

-- Apply button lock - syncs LOCK_ACTIONBAR global from Blizzard's CVar
-- NOTE: No longer overwrites Blizzard's CVar - SUI options panel now syncs directly with it
local function ApplyButtonLock()
    local locked = GetCVar('lockActionBars') == '1'
    LOCK_ACTIONBAR = locked and '1' or '0'
end

-- Usability indicator state tracking
local usabilityCheckFrame = nil
-- Range check interval (only used when range indicator is enabled)
local RANGE_CHECK_INTERVAL_NORMAL = 0.25  -- 250ms = 4 FPS (CPU-friendly)
local RANGE_CHECK_INTERVAL_FAST = 0.05    -- 50ms = 20 FPS (responsive)

local function GetUpdateInterval()
    local settings = GetGlobalSettings()
    if settings and settings.fastUsabilityUpdates then
        return RANGE_CHECK_INTERVAL_FAST
    end
    return RANGE_CHECK_INTERVAL_NORMAL
end

-- Safe wrapper for APIs that may return secret values in Midnight
local function SafeIsActionInRange(action)
    if IS_MIDNIGHT then
        -- In Midnight, IsActionInRange can return secret values
        -- Use pcall to safely check the result
        local ok, result = pcall(function()
            local inRange = IsActionInRange(action)
            -- Try to compare - this will fail if inRange is a secret value
            if inRange == false then return false end
            if inRange == true then return true end
            return nil  -- No range check needed
        end)
        if not ok then return nil end  -- Secret value, treat as in range
        return result
    else
        return IsActionInRange(action)
    end
end

local function SafeIsUsableAction(action)
    if IS_MIDNIGHT then
        -- In Midnight, IsUsableAction can return secret values
        -- We must convert to actual booleans INSIDE pcall before returning
        local ok, isUsable, notEnoughMana = pcall(function()
            local usable, noMana = IsUsableAction(action)
            -- Convert to actual booleans - if secret, comparison fails and pcall catches it
            local boolUsable = usable and true or false
            local boolNoMana = noMana and true or false
            return boolUsable, boolNoMana
        end)
        if not ok then return true, false end  -- Secret value detected, treat as usable
        return isUsable, notEnoughMana
    else
        return IsUsableAction(action)
    end
end

-- Update range and usability indicators for a single button
local function UpdateButtonUsability(button, settings)
    if not settings then return end
    if not button.action then return end

    local icon = button.icon or button.Icon
    if not icon then return end

    -- Reset state if both features disabled
    if not settings.rangeIndicator and not settings.usabilityIndicator then
        if tintedButtons[button] then
            icon:SetVertexColor(1, 1, 1, 1)
            icon:SetDesaturated(false)
            tintedButtons[button] = nil
        end
        return
    end

    -- Priority 1: Out of Range check (if enabled)
    if settings.rangeIndicator then
        local inRange = SafeIsActionInRange(button.action)
        if inRange == false then  -- false = out of range, nil = no range check needed
            local c = settings.rangeColor
            local r = c and c[1] or 0.8
            local g = c and c[2] or 0.1
            local b = c and c[3] or 0.1
            local a = c and c[4] or 1
            icon:SetVertexColor(r, g, b, a)
            icon:SetDesaturated(false)
            tintedButtons[button] = "range"
            return
        end
    end

    -- Priority 2: Usability check (if enabled)
    if settings.usabilityIndicator then
        local isUsable, notEnoughMana = SafeIsUsableAction(button.action)

        if notEnoughMana then
            -- Out of mana/resources - blue tint
            local c = settings.manaColor
            local r = c and c[1] or 0.5
            local g = c and c[2] or 0.5
            local b = c and c[3] or 1.0
            local a = c and c[4] or 1
            icon:SetVertexColor(r, g, b, a)
            icon:SetDesaturated(false)
            tintedButtons[button] = "mana"
            return
        elseif not isUsable then
            -- Not usable - desaturate or apply grey tint
            if settings.usabilityDesaturate then
                icon:SetDesaturated(true)
                icon:SetVertexColor(0.6, 0.6, 0.6, 1)  -- Slight brightness reduction with desaturation
            else
                local c = settings.usabilityColor
                local r = c and c[1] or 0.4
                local g = c and c[2] or 0.4
                local b = c and c[3] or 0.4
                local a = c and c[4] or 1
                icon:SetVertexColor(r, g, b, a)
                icon:SetDesaturated(false)
            end
            tintedButtons[button] = "unusable"
            return
        end
    end

    -- Normal state - reset to full brightness
    if tintedButtons[button] then
        icon:SetVertexColor(1, 1, 1, 1)
        icon:SetDesaturated(false)
        tintedButtons[button] = nil
    end
end

-- Update all visible action buttons
local function UpdateAllButtonUsability()
    local globalSettings = GetGlobalSettings()
    if not globalSettings then return end
    if not globalSettings.rangeIndicator and not globalSettings.usabilityIndicator then return end

    -- Only check action bars 1-8 (not pet/stance/micro/bags)
    for i = 1, 8 do
        local barKey = "bar" .. i
        local buttons = GetBarButtons(barKey)
        for _, button in ipairs(buttons) do
            if button:IsVisible() then
                UpdateButtonUsability(button, globalSettings)
            end
        end
    end
end

-- Debounced event handler (prevents rapid-fire updates)
local usabilityUpdatePending = false
local function ScheduleUsabilityUpdate()
    if usabilityUpdatePending then return end
    usabilityUpdatePending = true
    C_Timer.After(0.05, function()
        usabilityUpdatePending = false
        UpdateAllButtonUsability()
    end)
end

-- Reset all button tints
local function ResetAllButtonTints()
    for i = 1, 8 do
        local barKey = "bar" .. i
        local buttons = GetBarButtons(barKey)
        for _, button in ipairs(buttons) do
            local icon = button.icon or button.Icon
            if icon and tintedButtons[button] then
                icon:SetVertexColor(1, 1, 1, 1)
                icon:SetDesaturated(false)
                tintedButtons[button] = nil
            end
        end
    end
end

-- Start/stop usability indicator system (event-driven + optional range polling)
local function UpdateUsabilityPolling()
    local settings = GetGlobalSettings()
    local usabilityEnabled = settings and settings.usabilityIndicator
    local rangeEnabled = settings and settings.rangeIndicator

    -- Create frame if needed
    if not usabilityCheckFrame then
        usabilityCheckFrame = CreateFrame("Frame")
        usabilityCheckFrame.elapsed = 0
    end

    -- Event-driven usability updates (very efficient)
    if usabilityEnabled or rangeEnabled then
        usabilityCheckFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
        usabilityCheckFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
        usabilityCheckFrame:RegisterEvent("SPELL_UPDATE_USABLE")
        usabilityCheckFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
        usabilityCheckFrame:RegisterEvent("UNIT_POWER_UPDATE")
        usabilityCheckFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

        usabilityCheckFrame:SetScript("OnEvent", function(self, event, ...)
            ScheduleUsabilityUpdate()
        end)

        -- Initial update
        ScheduleUsabilityUpdate()
    else
        usabilityCheckFrame:UnregisterAllEvents()
        usabilityCheckFrame:SetScript("OnEvent", nil)
    end

    -- Range requires slow polling (no "player moved" event exists)
    -- Only poll when range indicator is enabled, at 250ms (was 100ms)
    if rangeEnabled then
        usabilityCheckFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed < GetUpdateInterval() then return end
            self.elapsed = 0
            UpdateAllButtonUsability()
        end)
        usabilityCheckFrame:Show()
    else
        usabilityCheckFrame:SetScript("OnUpdate", nil)
        usabilityCheckFrame.elapsed = 0
        -- Don't hide - events still need to work if usability is enabled
        if not usabilityEnabled then
            usabilityCheckFrame:Hide()
            ResetAllButtonTints()
        end
    end
end

-- Apply all bar layout settings
local function ApplyBarLayoutSettings()
    if DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION then
        -- Keep Blizzard lock state sync only; skip all button mutation features.
        ApplyButtonLock()
        return
    end

    ApplyBarScale()
    ApplyButtonLock()
    UpdateUsabilityPolling()

    -- Apply empty slot visibility to all action buttons
    local settings = GetGlobalSettings()
    if settings then
        for barKey, _ in pairs(BUTTON_PATTERNS) do
            local buttons = GetBarButtons(barKey)
            for _, button in ipairs(buttons) do
                UpdateEmptySlotVisibility(button, settings)
            end
        end
    end
end

---------------------------------------------------------------------------
-- MOUSEOVER FADE SYSTEM
---------------------------------------------------------------------------

-- Get or create fade state for a bar
local function GetBarFadeState(barKey)
    if not ActionBars.fadeState[barKey] then
        ActionBars.fadeState[barKey] = {
            isFading = false,
            currentAlpha = 1,
            targetAlpha = 1,
            fadeStart = 0,
            fadeStartAlpha = 1,
            fadeDuration = 0.3,
            isMouseOver = false,
            delayTimer = nil,
            detector = nil,
        }
    end
    return ActionBars.fadeState[barKey]
end

-- Apply alpha to all buttons in a bar
local function SetBarAlpha(barKey, alpha)
    local buttons = GetBarButtons(barKey)
    local settings = GetGlobalSettings()
    local hideEmptyEnabled = settings and settings.hideEmptySlots

    for _, button in ipairs(buttons) do
        -- Respect hide empty slots setting - keep empty buttons hidden
        if hideEmptyEnabled and hiddenEmptyButtons[button] then
            button:SetAlpha(0)
        else
            button:SetAlpha(alpha)
        end
    end

    local barFrame = GetBarFrame(barKey)
    if barFrame then
        barFrame:SetAlpha(alpha)
    end

    GetBarFadeState(barKey).currentAlpha = alpha
end

-- Start smooth fade animation for a bar
local function StartBarFade(barKey, targetAlpha)
    local state = GetBarFadeState(barKey)
    local fadeSettings = GetFadeSettings()

    local duration = targetAlpha > state.currentAlpha
        and (fadeSettings and fadeSettings.fadeInDuration or 0.2)
        or (fadeSettings and fadeSettings.fadeOutDuration or 0.3)

    -- Skip if already at target
    if math.abs(state.currentAlpha - targetAlpha) < 0.01 then
        state.isFading = false
        return
    end

    state.isFading = true
    state.targetAlpha = targetAlpha
    state.fadeStart = GetTime()
    state.fadeStartAlpha = state.currentAlpha
    state.fadeDuration = duration

    -- Create fade frame if needed
    if not ActionBars.fadeFrame then
        ActionBars.fadeFrame = CreateFrame("Frame")
        ActionBars.fadeFrame:SetScript("OnUpdate", function(self, elapsed)
            local now = GetTime()
            local anyFading = false

            for bKey, bState in pairs(ActionBars.fadeState) do
                if bState.isFading then
                    anyFading = true
                    local elapsedTime = now - bState.fadeStart
                    local progress = math.min(elapsedTime / bState.fadeDuration, 1)

                    -- Smooth easing
                    local easedProgress = progress * (2 - progress)

                    local alpha = bState.fadeStartAlpha +
                        (bState.targetAlpha - bState.fadeStartAlpha) * easedProgress

                    SetBarAlpha(bKey, alpha)

                    if progress >= 1 then
                        bState.isFading = false
                        SetBarAlpha(bKey, bState.targetAlpha)
                    end
                end
            end

            if not anyFading then
                self:Hide()
            end
        end)
    end
    ActionBars.fadeFrame:Show()
end

-- Check if mouse is over bar area or any of its buttons
local function IsMouseOverBar(barKey)
    local barFrame = GetBarFrame(barKey)
    if barFrame and barFrame:IsMouseOver() then
        return true
    end

    -- Also check individual buttons
    local buttons = GetBarButtons(barKey)
    for _, button in ipairs(buttons) do
        if button:IsMouseOver() then
            return true
        end
    end

    return false
end

---------------------------------------------------------------------------
-- LINKED ACTION BARS (1-8) MOUSEOVER
---------------------------------------------------------------------------

-- Bars that participate in linked mouseover behavior
local LINKED_BAR_KEYS = {"bar1", "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8"}

local function IsLinkedBar(barKey)
    for _, key in ipairs(LINKED_BAR_KEYS) do
        if key == barKey then return true end
    end
    return false
end

local function IsMouseOverAnyLinkedBar()
    for _, barKey in ipairs(LINKED_BAR_KEYS) do
        if IsMouseOverBar(barKey) then
            return true
        end
    end
    return false
end

-- Show a linked bar without triggering recursion
local function ShowLinkedBarDirect(barKey)
    local barSettings = GetBarSettings(barKey)
    local fadeSettings = GetFadeSettings()

    if not barSettings then return end
    if barSettings.alwaysShow then return end

    local fadeEnabled = barSettings.fadeEnabled
    if fadeEnabled == nil then
        fadeEnabled = fadeSettings and fadeSettings.enabled
    end
    if not fadeEnabled then return end

    local state = GetBarFadeState(barKey)

    -- Cancel pending fade-out timers
    if state.delayTimer then
        state.delayTimer:Cancel()
        state.delayTimer = nil
    end
    if state.leaveCheckTimer then
        state.leaveCheckTimer:Cancel()
        state.leaveCheckTimer = nil
    end

    StartBarFade(barKey, 1)
end

-- Start fade-out for a linked bar
local function FadeLinkedBarDirect(barKey)
    local barSettings = GetBarSettings(barKey)
    local fadeSettings = GetFadeSettings()

    if not barSettings then return end
    if barSettings.alwaysShow then return end

    local fadeEnabled = barSettings.fadeEnabled
    if fadeEnabled == nil then
        fadeEnabled = fadeSettings and fadeSettings.enabled
    end
    if not fadeEnabled then return end

    local state = GetBarFadeState(barKey)
    state.isMouseOver = false

    local fadeOutAlpha = barSettings.fadeOutAlpha
    if fadeOutAlpha == nil then
        fadeOutAlpha = fadeSettings and fadeSettings.fadeOutAlpha or 0
    end

    local delay = fadeSettings and fadeSettings.fadeOutDelay or 0.5

    if state.delayTimer then
        state.delayTimer:Cancel()
    end

    state.delayTimer = C_Timer.NewTimer(delay, function()
        state.delayTimer = nil
        -- Re-check at fade time in case mouse moved back
        if not IsMouseOverAnyLinkedBar() then
            StartBarFade(barKey, fadeOutAlpha)
        end
    end)
end

-- Handle mouse entering the bar area (event-based, no polling)
local function OnBarMouseEnter(barKey)
    local state = GetBarFadeState(barKey)
    local fadeSettings = GetFadeSettings()
    local barSettings = GetBarSettings(barKey)

    -- If bar should always be visible, skip fade logic entirely
    if barSettings and barSettings.alwaysShow then return end

    -- Check if fade is enabled
    local fadeEnabled = barSettings and barSettings.fadeEnabled
    if fadeEnabled == nil then
        fadeEnabled = fadeSettings and fadeSettings.enabled
    end
    if not fadeEnabled then return end

    state.isMouseOver = true

    -- LINKED BARS: If enabled and this is a linked bar, show ALL linked bars
    if fadeSettings and fadeSettings.linkBars1to8 and IsLinkedBar(barKey) then
        for _, linkedKey in ipairs(LINKED_BAR_KEYS) do
            if linkedKey ~= barKey then
                ShowLinkedBarDirect(linkedKey)
            end
        end
    end

    -- Cancel any pending fade-out
    if state.delayTimer then
        state.delayTimer:Cancel()
        state.delayTimer = nil
    end
    if state.leaveCheckTimer then
        state.leaveCheckTimer:Cancel()
        state.leaveCheckTimer = nil
    end

    StartBarFade(barKey, 1)
end

-- Handle mouse leaving a bar element (with delay to check if still over bar)
local function OnBarMouseLeave(barKey)
    local state = GetBarFadeState(barKey)
    local fadeSettings = GetFadeSettings()
    local barSettings = GetBarSettings(barKey)

    -- If bar should always be visible, skip fade logic entirely
    if barSettings and barSettings.alwaysShow then return end

    -- If in combat and "always show in combat" is enabled, don't fade out (bars 1-8 only)
    local isMainBar = barKey and barKey:match("^bar%d$")
    if isMainBar and InCombatLockdown() and fadeSettings and fadeSettings.alwaysShowInCombat then
        return
    end

    -- Check if fade is enabled
    local fadeEnabled = barSettings and barSettings.fadeEnabled
    if fadeEnabled == nil then
        fadeEnabled = fadeSettings and fadeSettings.enabled
    end
    if not fadeEnabled then return end

    -- Cancel any existing leave check timer
    if state.leaveCheckTimer then
        state.leaveCheckTimer:Cancel()
    end

    -- Short delay to check if mouse moved to another element in the bar
    state.leaveCheckTimer = C_Timer.NewTimer(0.066, function()
        state.leaveCheckTimer = nil

        -- If mouse is still over the bar somewhere, don't fade
        if IsMouseOverBar(barKey) then return end

        -- LINKED BARS: If enabled and this is a linked bar, check if over ANY linked bar
        if fadeSettings and fadeSettings.linkBars1to8 and IsLinkedBar(barKey) then
            if IsMouseOverAnyLinkedBar() then
                return  -- Mouse moved to another linked bar, don't fade any
            end
            -- Mouse left all linked bars - fade them all
            for _, linkedKey in ipairs(LINKED_BAR_KEYS) do
                FadeLinkedBarDirect(linkedKey)
            end
            return  -- Skip normal single-bar fade logic
        end

        state.isMouseOver = false

        -- Get fade out alpha
        local fadeOutAlpha = barSettings and barSettings.fadeOutAlpha
        if fadeOutAlpha == nil then
            fadeOutAlpha = fadeSettings and fadeSettings.fadeOutAlpha or 0
        end

        local delay = fadeSettings and fadeSettings.fadeOutDelay or 0.5

        if state.delayTimer then
            state.delayTimer:Cancel()
        end

        state.delayTimer = C_Timer.NewTimer(delay, function()
            if not state.isMouseOver then
                -- Read fresh value at fade time in case settings changed
                local freshBarSettings = GetBarSettings(barKey)
                local freshFadeSettings = GetFadeSettings()
                local freshFadeOutAlpha = freshBarSettings and freshBarSettings.fadeOutAlpha
                if freshFadeOutAlpha == nil then
                    freshFadeOutAlpha = freshFadeSettings and freshFadeSettings.fadeOutAlpha or 0
                end
                StartBarFade(barKey, freshFadeOutAlpha)
            end
            state.delayTimer = nil
        end)
    end)
end

-- Hook OnEnter/OnLeave on a frame for bar mouseover detection
local function HookFrameForMouseover(frame, barKey)
    if not frame or mouseoverHookedFrames[frame] then return end
    mouseoverHookedFrames[frame] = true

    frame:HookScript("OnEnter", function()
        OnBarMouseEnter(barKey)
    end)

    frame:HookScript("OnLeave", function()
        OnBarMouseLeave(barKey)
    end)
end

-- Setup mouseover detection for a bar (event-based, no polling)
local function SetupBarMouseover(barKey)
    local barSettings = GetBarSettings(barKey)
    local fadeSettings = GetFadeSettings()
    local db = GetDB()

    if not db or not db.enabled then return end

    -- Extra button bars (Zone Ability, Extra Action) should never inherit global fade
    -- They only fade if explicitly enabled for that specific bar
    if barKey == "extraActionButton" or barKey == "zoneAbility" then
        if not barSettings or barSettings.fadeEnabled ~= true then
            return
        end
    end

    local state = GetBarFadeState(barKey)

    -- Check if bar should always be visible (overrides fade)
    if barSettings and barSettings.alwaysShow then
        SetBarAlpha(barKey, 1)
        return
    end

    -- Check if fade is enabled for this bar
    local fadeEnabled = barSettings and barSettings.fadeEnabled
    if fadeEnabled == nil then
        fadeEnabled = fadeSettings and fadeSettings.enabled
    end

    if not fadeEnabled then
        -- Ensure bar is fully visible
        SetBarAlpha(barKey, 1)
        return
    end

    -- Get target alpha for this bar when faded out
    local fadeOutAlpha = barSettings and barSettings.fadeOutAlpha
    if fadeOutAlpha == nil then
        fadeOutAlpha = fadeSettings and fadeSettings.fadeOutAlpha or 0
    end

    -- Hook bar frame for mouseover
    local barFrame = GetBarFrame(barKey)
    if barFrame then
        HookFrameForMouseover(barFrame, barKey)
    end

    -- Hook all buttons in the bar for mouseover
    local buttons = GetBarButtons(barKey)
    for _, button in ipairs(buttons) do
        HookFrameForMouseover(button, barKey)
    end

    -- Update target alpha state to match current settings
    state.targetAlpha = fadeOutAlpha

    -- Cancel any ongoing fade animation for this bar (so new settings take effect)
    state.isFading = false
    if state.delayTimer then
        state.delayTimer:Cancel()
        state.delayTimer = nil
    end
    if state.leaveCheckTimer then
        state.leaveCheckTimer:Cancel()
        state.leaveCheckTimer = nil
    end

    -- Initialize to faded state if not moused over
    if not IsMouseOverBar(barKey) then
        SetBarAlpha(barKey, fadeOutAlpha)
    end
end

---------------------------------------------------------------------------
-- COMBAT VISIBILITY HANDLER
---------------------------------------------------------------------------

-- Combat event handler for "always show in combat" feature
-- Only applies to main action bars (1-8), not microbar, bags, pet, stance
local COMBAT_FADE_BARS = {
    bar1 = true, bar2 = true, bar3 = true, bar4 = true,
    bar5 = true, bar6 = true, bar7 = true, bar8 = true,
}

local combatFadeFrame = CreateFrame("Frame")
combatFadeFrame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Enter combat
combatFadeFrame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Leave combat

combatFadeFrame:SetScript("OnEvent", function(self, event)
    local fadeSettings = GetFadeSettings()
    if not fadeSettings or not fadeSettings.enabled then return end
    if not fadeSettings.alwaysShowInCombat then return end

    if event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: Force action bars 1-8 to full opacity
        for barKey, _ in pairs(COMBAT_FADE_BARS) do
            local state = GetBarFadeState(barKey)
            -- Cancel any pending fade timers
            if state.delayTimer then
                state.delayTimer:Cancel()
                state.delayTimer = nil
            end
            if state.leaveCheckTimer then
                state.leaveCheckTimer:Cancel()
                state.leaveCheckTimer = nil
            end
            -- Fade to full opacity
            StartBarFade(barKey, 1)
        end
    else
        -- Leaving combat: Resume normal mouseover behavior for bars 1-8
        for barKey, _ in pairs(COMBAT_FADE_BARS) do
            SetupBarMouseover(barKey)
        end
    end
end)

---------------------------------------------------------------------------
-- MOUNT / VEHICLE VISIBILITY
-- Hide action bars while mounted/flying/in vehicle.
-- Uses SetAlpha(0/1) on holder frames (safe, no taint).
---------------------------------------------------------------------------
local mountFadeFrame = CreateFrame("Frame")
mountFadeFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mountFadeFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
mountFadeFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
mountFadeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mountFadeFrame:SetScript("OnEvent", function()
    local fadeSettings = GetFadeSettings()
    if not fadeSettings or not fadeSettings.hideWhileMounted then return end
    local isMounted = IsMounted() or UnitInVehicle("player")
    for barKey, _ in pairs(COMBAT_FADE_BARS) do
        local holder = _G["SuaviUI_ActionBar_" .. barKey]
        if holder then
            if isMounted then
                holder:SetAlpha(0)
                holder:EnableMouse(false)
            else
                -- Restore normal state (respect fade settings)
                holder:EnableMouse(true)
                local state = GetBarFadeState(barKey)
                if state and state.currentAlpha then
                    holder:SetAlpha(state.currentAlpha)
                else
                    holder:SetAlpha(1)
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- BAR PROCESSING
---------------------------------------------------------------------------

-- Skin all buttons for a specific bar
local function SkinBar(barKey)
    local db = GetDB()
    if not db or not db.enabled then return end

    local barSettings = GetBarSettings(barKey)
    if not barSettings or not barSettings.enabled then return end

    -- Use effective settings (global merged with per-bar overrides)
    local effectiveSettings = GetEffectiveSettings(barKey)
    if not effectiveSettings then return end

    local buttons = GetBarButtons(barKey)

    for _, button in ipairs(buttons) do
        SkinButton(button, effectiveSettings)
        UpdateButtonText(button, effectiveSettings)

        -- Add LibKeyBound methods for mousewheel binding support
        AddKeybindMethods(button, barKey)

        -- Hook OnEnter to register with LibKeyBound when in keybind mode
        -- Use HookScript to avoid tainting Blizzard's secure execution context
        -- (SetScript + calling old handler causes ADDON_ACTION_BLOCKED during combat)
        if not onEnterHookedButtons[button] then
            onEnterHookedButtons[button] = true
            button:HookScript("OnEnter", function(self)
                local LibKeyBound = LibStub("LibKeyBound-1.0", true)
                if LibKeyBound and LibKeyBound:IsShown() then
                    LibKeyBound:Set(self)
                end
            end)
        end
    end
end

-- Skin all enabled bars
local function SkinAllBars()
    if DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION then return end

    local db = GetDB()
    if not db or not db.enabled then return end

    -- Iterate over all bars (including non-standard ones like microbar, bags, etc.)
    for barKey, _ in pairs(BAR_FRAMES) do
        -- Only skin bars that have button patterns (standard action bars)
        if BUTTON_PATTERNS[barKey] then
            SkinBar(barKey)
        end
        -- Setup mouseover fade for ALL bars
        SetupBarMouseover(barKey)
    end
end

---------------------------------------------------------------------------
-- PAGE ARROW VISIBILITY
---------------------------------------------------------------------------

local function ApplyPageArrowVisibility(hide)
    local pageNum = MainActionBar and MainActionBar.ActionBarPageNumber
    if not pageNum then return end

    if hide then
        pageNum:Hide()
        if not showHookedFrames[pageNum] then
            showHookedFrames[pageNum] = true
            hooksecurefunc(pageNum, "Show", function(self)
                local db = GetDB()
                if db and db.bars and db.bars.bar1 and db.bars.bar1.hidePageArrow then
                    self:Hide()
                end
            end)
        end
    else
        pageNum:Show()
    end
end

_G.SuaviUI_ApplyPageArrowVisibility = ApplyPageArrowVisibility

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

-- Refresh all action bar styling (called from options)
function ActionBars:Refresh()
    if not ActionBars.initialized then return end

    if DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION then
        ApplyButtonLock()
        return
    end

    -- Clear skinned cache to force re-skin
    for button, _ in pairs(ActionBars.skinnedButtons) do
        skinKeys[button] = nil
    end

    SkinAllBars()
    ApplyBarLayoutSettings()

    -- Apply page arrow visibility
    local db = GetDB()
    if db and db.bars and db.bars.bar1 then
        ApplyPageArrowVisibility(db.bars.bar1.hidePageArrow)
    end
end

-- Initialize the module
function ActionBars:Initialize()
    if ActionBars.initialized then return end

    -- Defer initialization if in combat (protects SetScale calls on action bars)
    if InCombatLockdown() then
        ActionBars.pendingInitialize = true
        return
    end

    local db = GetDB()
    if not db or not db.enabled then return end

    ActionBars.initialized = true

    if DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION then
        ApplyButtonLock()
        return
    end

    -- One-time migration for lock setting (preserves user setting after CVar sync fix)
    MigrateLockSetting()

    -- Initial skin pass
    SkinAllBars()

    -- Apply bar layout settings (scale, lock, range indicator, empty slots)
    ApplyBarLayoutSettings()

    -- Apply page arrow visibility
    if db.bars and db.bars.bar1 then
        ApplyPageArrowVisibility(db.bars.bar1.hidePageArrow)
    end

    -- Initialize extra button holders (Extra Action Button & Zone Ability)
    InitializeExtraButtons()

    -- Debounced button update system (prevents rapid-fire during combat)
    local pendingButtonUpdates = {}
    local buttonUpdatePending = false

    local function ProcessPendingButtonUpdates()
        buttonUpdatePending = false
        for button, updateType in pairs(pendingButtonUpdates) do
            local barKey = GetBarKeyFromButton(button)
            local settings = barKey and GetEffectiveSettings(barKey) or GetGlobalSettings()
            if settings then
                if updateType == "hotkey" or updateType == "both" then
                    UpdateKeybindText(button, settings)
                end
                if updateType == "action" or updateType == "both" then
                    UpdateButtonText(button, settings)
                    UpdateEmptySlotVisibility(button, settings)
                end
            end
        end
        wipe(pendingButtonUpdates)
    end

    local function ScheduleButtonUpdate(button, updateType)
        local existing = pendingButtonUpdates[button]
        if existing and existing ~= updateType then
            pendingButtonUpdates[button] = "both"
        else
            pendingButtonUpdates[button] = updateType
        end
        if not buttonUpdatePending then
            buttonUpdatePending = true
            C_Timer.After(0.05, ProcessPendingButtonUpdates)
        end
    end

    -- NOTE: Direct hooks on ActionButton_Update and ActionButton_UpdateHotkeys have been
    -- removed as they cause taint in Midnight (12.0+). These hooks run during Blizzard's
    -- update cycle and can cause SetAttribute() calls to be blocked.
    -- Instead, we rely purely on event-driven updates (ACTIONBAR_SLOT_CHANGED,
    -- UPDATE_BINDINGS) which are already handled in the event frame below.
end

---------------------------------------------------------------------------
-- EVENT HANDLING
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- Delay initialization to ensure all frames exist
        C_Timer.After(0.5, function()
            ActionBars:Initialize()
        end)

    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        if DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION then return end
        -- Re-apply text styling and hide-empty when actions change
        C_Timer.After(0.1, function()
            for barKey, _ in pairs(BUTTON_PATTERNS) do
                local effectiveSettings = GetEffectiveSettings(barKey)
                if effectiveSettings then
                    local buttons = GetBarButtons(barKey)
                    for _, button in ipairs(buttons) do
                        UpdateButtonText(button, effectiveSettings)
                        UpdateEmptySlotVisibility(button, effectiveSettings)
                    end
                end
            end
        end)

    elseif event == "UPDATE_BINDINGS" then
        if DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION then return end
        -- Re-apply keybind styling when bindings change
        C_Timer.After(0.1, function()
            for barKey, _ in pairs(BUTTON_PATTERNS) do
                local effectiveSettings = GetEffectiveSettings(barKey)
                if effectiveSettings then
                    local buttons = GetBarButtons(barKey)
                    for _, button in ipairs(buttons) do
                        UpdateKeybindText(button, effectiveSettings)
                    end
                end
            end
        end)

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Process pending initialization (from /reload during combat)
        if ActionBars.pendingInitialize then
            ActionBars.pendingInitialize = false
            ActionBars:Initialize()
        end
        -- Process any pending refresh operations
        if ActionBars.pendingRefresh then
            ActionBars.pendingRefresh = false
            ActionBars:Refresh()
        end
        -- Process pending extra button operations
        if ActionBars.pendingExtraButtonInit then
            ActionBars.pendingExtraButtonInit = false
            InitializeExtraButtons()
        end
        if ActionBars.pendingExtraButtonRefresh then
            ActionBars.pendingExtraButtonRefresh = false
            RefreshExtraButtons()
        end
        if ActionBars.pendingExtraButtonHide then
            for h, bType in pairs(ActionBars.pendingExtraButtonHide) do
                if h:IsShown() then
                    local ss = GetExtraButtonDB(bType)
                    if not (ss and (ss._editModeActive or ss.alwaysShow)) then
                        h:Hide()
                        h:EnableMouse(false)
                    end
                end
            end
            ActionBars.pendingExtraButtonHide = nil
        end

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- Spec change reassigns spells to action bar slots.
        -- SkinBar uses a settings cache and won't re-evaluate empty slots
        -- unless the skin settings changed. Force re-evaluate visibility.
        C_Timer.After(0.5, function()
            if DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION then return end
            for barKey, _ in pairs(BUTTON_PATTERNS) do
                local effectiveSettings = GetEffectiveSettings(barKey)
                if effectiveSettings then
                    local buttons = GetBarButtons(barKey)
                    for _, button in ipairs(buttons) do
                        UpdateEmptySlotVisibility(button, effectiveSettings)
                        UpdateButtonText(button, effectiveSettings)
                    end
                end
            end
        end)
    end
end)

---------------------------------------------------------------------------
-- GLOBAL REFRESH FUNCTION
---------------------------------------------------------------------------

_G.SuaviUI_RefreshActionBars = function()
    if DISABLE_STANDARD_ACTIONBAR_CUSTOMIZATION then
        ApplyButtonLock()
        return
    end

    if InCombatLockdown() then
        ActionBars.pendingRefresh = true
        return
    end
    ActionBars:Refresh()
end

---------------------------------------------------------------------------
-- EDIT MODE INTEGRATION
-- Show/hide extra button movers when Edit Mode is entered/exited
---------------------------------------------------------------------------

local function SetupEditModeHooks()
    if not EditModeManagerFrame then return end

    -- Show movers when entering Edit Mode
    pcall(hooksecurefunc, EditModeManagerFrame, "EnterEditMode", function()
        local extraSettings = GetExtraButtonDB("extraActionButton")
        local zoneSettings = GetExtraButtonDB("zoneAbility")
        -- Only show movers if at least one extra button feature is enabled
        if (extraSettings and extraSettings.enabled) or (zoneSettings and zoneSettings.enabled) then
            ShowExtraButtonMovers()
        end
    end)

    -- Hide movers when exiting Edit Mode
    pcall(hooksecurefunc, EditModeManagerFrame, "ExitEditMode", function()
        HideExtraButtonMovers()
    end)
end

-- Call setup after a short delay to ensure EditModeManagerFrame exists
C_Timer.After(1, SetupEditModeHooks)

---------------------------------------------------------------------------
-- EXPOSE MODULE
---------------------------------------------------------------------------

local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
if SUICore then
    SUICore.ActionBars = ActionBars
end

---------------------------------------------------------------------------
-- EDIT MODE PANEL INJECTION (Action Bars)
-- Injects SuaviUI master visual + mouseover hide controls into Blizzard's
-- native EditModeSystemSettingsDialog when any action bar is selected.
---------------------------------------------------------------------------

do
    local EP = ns.EditModePanels
    if not EP then return end

    local controls = EP.controls

    ---------------------------------------------------------------------------
    -- DB helpers
    ---------------------------------------------------------------------------
    local function GetABDB()
        local core = _G.SuaviUI and _G.SuaviUI.SUICore
        return core and core.db and core.db.profile and core.db.profile.actionBars or nil
    end

    local function GetGlobal()
        local ab = GetABDB()
        return ab and ab.global or nil
    end

    local function GetFade()
        local ab = GetABDB()
        return ab and ab.fade or nil
    end

    local function GetBarDB(barKey)
        local ab = GetABDB()
        return ab and ab.bars and ab.bars[barKey] or nil
    end

    local function RefreshAB()
        if _G.SuaviUI_RefreshActionBars then _G.SuaviUI_RefreshActionBars() end
    end

    ---------------------------------------------------------------------------
    -- Map Blizzard systemIndex to SuaviUI bar key
    ---------------------------------------------------------------------------
    local SYSTEM_INDEX_TO_BAR_KEY = {
        [1]  = "bar1",    -- MainBar
        [2]  = "bar2",    -- Bar2
        [3]  = "bar3",    -- Bar3
        [4]  = "bar4",    -- RightBar1
        [5]  = "bar5",    -- RightBar2
        [6]  = "bar6",    -- ExtraBar1
        [7]  = "bar7",    -- ExtraBar2
        [8]  = "bar8",    -- ExtraBar3
        [11] = "stance",  -- StanceBar
        [12] = "pet",     -- PetActionBar
    }

    ---------------------------------------------------------------------------
    -- 9-point anchor options
    ---------------------------------------------------------------------------
    local function GetAnchorOptions()
        return {
            {value = "TOPLEFT", text = "Top Left"},
            {value = "TOP", text = "Top"},
            {value = "TOPRIGHT", text = "Top Right"},
            {value = "LEFT", text = "Left"},
            {value = "CENTER", text = "Center"},
            {value = "RIGHT", text = "Right"},
            {value = "BOTTOMLEFT", text = "Bottom Left"},
            {value = "BOTTOM", text = "Bottom"},
            {value = "BOTTOMRIGHT", text = "Bottom Right"},
        }
    end

    ---------------------------------------------------------------------------
    -- Predicate: is this an action bar system?
    ---------------------------------------------------------------------------
    local function IsActionBarSystem(sf)
        return sf and sf.system == Enum.EditModeSystem.ActionBar
    end

    ---------------------------------------------------------------------------
    -- Control keys (built dynamically per-bar for the Always Show checkbox)
    ---------------------------------------------------------------------------
    local abControlKeys = {
        "abDivider",
        -- Per-bar setting (always visible)
        "abAlwaysShow",
        -- Collapsible: Button Appearance
        "abAppearanceSection",
        "abIconCrop", "abBackdrop", "abBackdropAlpha",
        "abGloss", "abGlossAlpha", "abBorders", "abHideEmpty",
        -- Collapsible: Keybinds
        "abKeybindSection",
        "abShowKeybinds", "abHideEmptyKeybinds", "abKeybindSize",
        "abKeybindAnchor", "abKeybindOffX", "abKeybindOffY",
        -- Collapsible: Macro Names
        "abMacroSection",
        "abShowMacro", "abMacroSize",
        "abMacroAnchor", "abMacroOffX", "abMacroOffY",
        -- Collapsible: Stack Counts
        "abCountSection",
        "abShowCounts", "abCountSize",
        "abCountAnchor", "abCountOffX", "abCountOffY",
        -- Collapsible: Mouseover Hide
        "abFadeSection",
        "abFadeEnable", "abFadeIn", "abFadeOut", "abFadeAlpha", "abFadeDelay",
        "abFadeCombat", "abFadeLink", "abFadeMounted",
    }

    ---------------------------------------------------------------------------
    -- Init all controls (called once)
    ---------------------------------------------------------------------------
    local function InitABControls()
        controls.abDivider = EP.CreateDivider("AB", "SuaviUI")

        -- Per-bar: Always Show (moved to top, always visible)
        controls.abAlwaysShow = EP.CreateCheckbox("ABAlwaysShow", "Always Show This Bar",
            function() return false end,
            function() end
        )

        -- Collapsible: Button Appearance
        controls.abAppearanceSection = EP.CreateCollapsible("ABAppearance", "Button Appearance", {
            "abIconCrop", "abBackdrop", "abBackdropAlpha",
            "abGloss", "abGlossAlpha", "abBorders", "abHideEmpty",
        }, true)

        controls.abIconCrop = EP.CreateSlider("ABIconCrop", "Icon Crop", 5, 15, 1,
            function() local g = GetGlobal(); return g and math.floor((g.iconZoom or 0.08) * 100 + 0.5) or 8 end,
            function(v) local g = GetGlobal(); if g then g.iconZoom = v / 100 end; RefreshAB() end
        )
        controls.abBackdrop = EP.CreateCheckbox("ABBackdrop", "Show Backdrop",
            function() local g = GetGlobal(); return g and g.showBackdrop ~= false end,
            function(v) local g = GetGlobal(); if g then g.showBackdrop = v end; RefreshAB() end
        )
        controls.abBackdropAlpha = EP.CreateSlider("ABBackdropAlpha", "Backdrop Alpha", 0, 100, 5,
            function() local g = GetGlobal(); return g and math.floor((g.backdropAlpha or 0.8) * 100 + 0.5) or 80 end,
            function(v) local g = GetGlobal(); if g then g.backdropAlpha = v / 100 end; RefreshAB() end
        )
        controls.abGloss = EP.CreateCheckbox("ABGloss", "Show Gloss",
            function() local g = GetGlobal(); return g and g.showGloss ~= false end,
            function(v) local g = GetGlobal(); if g then g.showGloss = v end; RefreshAB() end
        )
        controls.abGlossAlpha = EP.CreateSlider("ABGlossAlpha", "Gloss Alpha", 0, 100, 5,
            function() local g = GetGlobal(); return g and math.floor((g.glossAlpha or 0.3) * 100 + 0.5) or 30 end,
            function(v) local g = GetGlobal(); if g then g.glossAlpha = v / 100 end; RefreshAB() end
        )
        controls.abBorders = EP.CreateCheckbox("ABBorders", "Show Borders",
            function() local g = GetGlobal(); return g and g.showBorders ~= false end,
            function(v) local g = GetGlobal(); if g then g.showBorders = v end; RefreshAB() end
        )
        controls.abHideEmpty = EP.CreateCheckbox("ABHideEmpty", "Hide Empty Slots",
            function() local g = GetGlobal(); return g and g.hideEmptySlots or false end,
            function(v) local g = GetGlobal(); if g then g.hideEmptySlots = v end; RefreshAB() end
        )

        -- Collapsible: Keybinds
        controls.abKeybindSection = EP.CreateCollapsible("ABKeybinds", "Keybinds", {
            "abShowKeybinds", "abHideEmptyKeybinds", "abKeybindSize",
            "abKeybindAnchor", "abKeybindOffX", "abKeybindOffY",
        }, true)

        controls.abShowKeybinds = EP.CreateCheckbox("ABShowKeybinds", "Show Keybinds",
            function() local g = GetGlobal(); return g and g.showKeybinds ~= false end,
            function(v) local g = GetGlobal(); if g then g.showKeybinds = v end; RefreshAB() end
        )
        controls.abHideEmptyKeybinds = EP.CreateCheckbox("ABHideEmptyKB", "Hide Empty Keybinds",
            function() local g = GetGlobal(); return g and g.hideEmptyKeybinds or false end,
            function(v) local g = GetGlobal(); if g then g.hideEmptyKeybinds = v end; RefreshAB() end
        )
        controls.abKeybindSize = EP.CreateSlider("ABKeybindSize", "Keybind Size", 8, 50, 1,
            function() local g = GetGlobal(); return g and g.keybindFontSize or 12 end,
            function(v) local g = GetGlobal(); if g then g.keybindFontSize = v end; RefreshAB() end
        )
        controls.abKeybindAnchor = EP.CreateDropdown("ABKeybindAnchor", "KB Anchor",
            GetAnchorOptions,
            function() local g = GetGlobal(); return g and g.keybindAnchor or "TOPRIGHT" end,
            function(v) local g = GetGlobal(); if g then g.keybindAnchor = v end; RefreshAB() end
        )
        controls.abKeybindOffX = EP.CreateSlider("ABKeybindOffX", "KB X Offset", -20, 20, 1,
            function() local g = GetGlobal(); return g and g.keybindOffsetX or 0 end,
            function(v) local g = GetGlobal(); if g then g.keybindOffsetX = v end; RefreshAB() end
        )
        controls.abKeybindOffY = EP.CreateSlider("ABKeybindOffY", "KB Y Offset", -20, 20, 1,
            function() local g = GetGlobal(); return g and g.keybindOffsetY or 0 end,
            function(v) local g = GetGlobal(); if g then g.keybindOffsetY = v end; RefreshAB() end
        )

        -- Collapsible: Macro Names
        controls.abMacroSection = EP.CreateCollapsible("ABMacros", "Macro Names", {
            "abShowMacro", "abMacroSize",
            "abMacroAnchor", "abMacroOffX", "abMacroOffY",
        }, true)

        controls.abShowMacro = EP.CreateCheckbox("ABShowMacro", "Show Macro Names",
            function() local g = GetGlobal(); return g and g.showMacroNames or false end,
            function(v) local g = GetGlobal(); if g then g.showMacroNames = v end; RefreshAB() end
        )
        controls.abMacroSize = EP.CreateSlider("ABMacroSize", "Macro Size", 8, 50, 1,
            function() local g = GetGlobal(); return g and g.macroNameFontSize or 10 end,
            function(v) local g = GetGlobal(); if g then g.macroNameFontSize = v end; RefreshAB() end
        )
        controls.abMacroAnchor = EP.CreateDropdown("ABMacroAnchor", "Macro Anchor",
            GetAnchorOptions,
            function() local g = GetGlobal(); return g and g.macroNameAnchor or "BOTTOM" end,
            function(v) local g = GetGlobal(); if g then g.macroNameAnchor = v end; RefreshAB() end
        )
        controls.abMacroOffX = EP.CreateSlider("ABMacroOffX", "Macro X Offset", -20, 20, 1,
            function() local g = GetGlobal(); return g and g.macroNameOffsetX or 0 end,
            function(v) local g = GetGlobal(); if g then g.macroNameOffsetX = v end; RefreshAB() end
        )
        controls.abMacroOffY = EP.CreateSlider("ABMacroOffY", "Macro Y Offset", -20, 20, 1,
            function() local g = GetGlobal(); return g and g.macroNameOffsetY or 0 end,
            function(v) local g = GetGlobal(); if g then g.macroNameOffsetY = v end; RefreshAB() end
        )

        -- Collapsible: Stack Counts
        controls.abCountSection = EP.CreateCollapsible("ABCounts", "Stack Counts", {
            "abShowCounts", "abCountSize",
            "abCountAnchor", "abCountOffX", "abCountOffY",
        }, true)

        controls.abShowCounts = EP.CreateCheckbox("ABShowCounts", "Show Stack Counts",
            function() local g = GetGlobal(); return g and g.showCounts ~= false end,
            function(v) local g = GetGlobal(); if g then g.showCounts = v end; RefreshAB() end
        )
        controls.abCountSize = EP.CreateSlider("ABCountSize", "Count Size", 8, 50, 1,
            function() local g = GetGlobal(); return g and g.countFontSize or 14 end,
            function(v) local g = GetGlobal(); if g then g.countFontSize = v end; RefreshAB() end
        )
        controls.abCountAnchor = EP.CreateDropdown("ABCountAnchor", "Count Anchor",
            GetAnchorOptions,
            function() local g = GetGlobal(); return g and g.countAnchor or "BOTTOMRIGHT" end,
            function(v) local g = GetGlobal(); if g then g.countAnchor = v end; RefreshAB() end
        )
        controls.abCountOffX = EP.CreateSlider("ABCountOffX", "Count X Offset", -20, 20, 1,
            function() local g = GetGlobal(); return g and g.countOffsetX or 0 end,
            function(v) local g = GetGlobal(); if g then g.countOffsetX = v end; RefreshAB() end
        )
        controls.abCountOffY = EP.CreateSlider("ABCountOffY", "Count Y Offset", -20, 20, 1,
            function() local g = GetGlobal(); return g and g.countOffsetY or 0 end,
            function(v) local g = GetGlobal(); if g then g.countOffsetY = v end; RefreshAB() end
        )

        -- Collapsible: Mouseover Hide
        controls.abFadeSection = EP.CreateCollapsible("ABFade", "Mouseover Hide", {
            "abFadeEnable", "abFadeIn", "abFadeOut", "abFadeAlpha", "abFadeDelay",
            "abFadeCombat", "abFadeLink", "abFadeMounted",
        }, true)

        controls.abFadeEnable = EP.CreateCheckbox("ABFadeEnable", "Enable Mouseover Hide",
            function() local f = GetFade(); return f and f.enabled or false end,
            function(v) local f = GetFade(); if f then f.enabled = v end; RefreshAB() end
        )
        controls.abFadeIn = EP.CreateSlider("ABFadeIn", "Fade In (sec)", 1, 100, 5,
            function() local f = GetFade(); return f and math.floor((f.fadeInDuration or 0.2) * 100 + 0.5) or 20 end,
            function(v) local f = GetFade(); if f then f.fadeInDuration = v / 100 end; RefreshAB() end
        )
        controls.abFadeOut = EP.CreateSlider("ABFadeOut", "Fade Out (sec)", 1, 100, 5,
            function() local f = GetFade(); return f and math.floor((f.fadeOutDuration or 0.3) * 100 + 0.5) or 30 end,
            function(v) local f = GetFade(); if f then f.fadeOutDuration = v / 100 end; RefreshAB() end
        )
        controls.abFadeAlpha = EP.CreateSlider("ABFadeAlpha", "Faded Opacity", 0, 100, 5,
            function() local f = GetFade(); return f and math.floor((f.fadeOutAlpha or 0) * 100 + 0.5) or 0 end,
            function(v) local f = GetFade(); if f then f.fadeOutAlpha = v / 100 end; RefreshAB() end
        )
        controls.abFadeDelay = EP.CreateSlider("ABFadeDelay", "Fade Delay (sec)", 0, 200, 10,
            function() local f = GetFade(); return f and math.floor((f.fadeOutDelay or 0) * 100 + 0.5) or 0 end,
            function(v) local f = GetFade(); if f then f.fadeOutDelay = v / 100 end; RefreshAB() end
        )
        controls.abFadeCombat = EP.CreateCheckbox("ABFadeCombat", "Show In Combat",
            function() local f = GetFade(); return f and f.alwaysShowInCombat or false end,
            function(v) local f = GetFade(); if f then f.alwaysShowInCombat = v end; RefreshAB() end
        )
        controls.abFadeLink = EP.CreateCheckbox("ABFadeLink", "Link Bars 1-8",
            function() local f = GetFade(); return f and f.linkBars1to8 or false end,
            function(v) local f = GetFade(); if f then f.linkBars1to8 = v end; RefreshAB() end
        )
        controls.abFadeMounted = EP.CreateCheckbox("ABFadeMounted", "Hide While Mounted/Vehicle",
            function() local f = GetFade(); return f and f.hideWhileMounted or false end,
            function(v)
                local f = GetFade()
                if f then f.hideWhileMounted = v end
                -- Trigger mount watcher immediately
                mountFadeFrame:GetScript("OnEvent")(mountFadeFrame, "PLAYER_MOUNT_DISPLAY_CHANGED")
            end
        )

    end

    ---------------------------------------------------------------------------
    -- Custom inject: update the Always Show checkbox for the currently selected bar
    ---------------------------------------------------------------------------
    local lastBarKey = nil

    local function InjectABControls(dialog, systemFrame)
        local barKey = SYSTEM_INDEX_TO_BAR_KEY[systemFrame.systemIndex]
        lastBarKey = barKey

        -- Update the Always Show checkbox getter/setter for this specific bar
        local alwaysShow = controls.abAlwaysShow
        if alwaysShow and barKey then
            alwaysShow._suiGetter = function()
                local bdb = GetBarDB(barKey)
                return bdb and bdb.alwaysShow or false
            end
            alwaysShow.Button:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                local bdb = GetBarDB(barKey)
                if bdb then
                    bdb.alwaysShow = not bdb.alwaysShow
                    alwaysShow.checked = bdb.alwaysShow
                    alwaysShow.Button:SetChecked(bdb.alwaysShow)
                    RefreshAB()
                end
            end)
        end

        EP.InjectControls(dialog, abControlKeys)
    end

    ---------------------------------------------------------------------------
    -- Register with shared infrastructure
    -- We use a custom inject override via the predicate return + manual call
    ---------------------------------------------------------------------------
    EP.RegisterSystem(IsActionBarSystem, InitABControls, abControlKeys)

    -- Override the default inject to add per-bar dynamic behavior
    -- The registration above handles init + standard inject. We hook
    -- UpdateDialog again to update the Always Show checkbox dynamically.
    C_Timer.After(0.1, function()
        local dialog = EditModeSystemSettingsDialog
        if not dialog then return end
        hooksecurefunc(dialog, "UpdateDialog", function(self, systemFrame)
            if IsActionBarSystem(systemFrame) and controls.abAlwaysShow then
                local barKey = SYSTEM_INDEX_TO_BAR_KEY[systemFrame.systemIndex]
                if barKey then
                    local bdb = GetBarDB(barKey)
                    local isShown = bdb and bdb.alwaysShow or false
                    controls.abAlwaysShow.checked = isShown
                    if controls.abAlwaysShow.Button then
                        controls.abAlwaysShow.Button:SetChecked(isShown)
                    end
                    -- Update the setter for this bar
                    controls.abAlwaysShow._suiGetter = function()
                        local bd = GetBarDB(barKey)
                        return bd and bd.alwaysShow or false
                    end
                    controls.abAlwaysShow.Button:SetScript("OnClick", function()
                        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                        local bd = GetBarDB(barKey)
                        if bd then
                            bd.alwaysShow = not bd.alwaysShow
                            controls.abAlwaysShow.checked = bd.alwaysShow
                            controls.abAlwaysShow.Button:SetChecked(bd.alwaysShow)
                            RefreshAB()
                        end
                    end)
                else
                    -- Not a mappable bar (e.g. possess bar) — hide the Always Show checkbox
                    controls.abAlwaysShow:Hide()
                end
            end
        end)
    end)
end

---------------------------------------------------------------------------
-- EXTRA ABILITIES (Extra Action Button + Zone Ability Button) EDIT MODE PANEL
---------------------------------------------------------------------------
-- Positioning is handled by Blizzard's native Edit Mode (ExtraAbilities
-- system). SuaviUI injects scale / artwork / fade controls into Blizzard's
-- dialog when the user selects that system. No reparenting, no SetParent,
-- no custom holders — so none of the taint paths that blocked
-- UIParentRightManagedFrameContainer:ClearAllPoints() run.

local function ApplyExtraButtonAppearanceSafe(buttonType)
    if InCombatLockdown() then
        ActionBars.pendingExtraButtonRefresh = true
        return
    end
    local settings = GetExtraButtonDB(buttonType)
    if not settings then return end

    local frameName = (buttonType == "extraActionButton") and "ExtraActionBarFrame" or "ZoneAbilityFrame"
    local blizzFrame = _G[frameName]
    if not blizzFrame then return end

    if not settings.enabled then
        -- User disabled customization — restore Blizzard defaults.
        pcall(blizzFrame.SetScale, blizzFrame, 1.0)
        if buttonType == "extraActionButton" and blizzFrame.button and blizzFrame.button.style then
            blizzFrame.button.style:SetAlpha(1)
        elseif buttonType == "zoneAbility" and blizzFrame.Style then
            blizzFrame.Style:SetAlpha(1)
        end
        return
    end

    pcall(blizzFrame.SetScale, blizzFrame, settings.scale or 1.0)

    if buttonType == "extraActionButton" and blizzFrame.button and blizzFrame.button.style then
        blizzFrame.button.style:SetAlpha(settings.hideArtwork and 0 or 1)
    elseif buttonType == "zoneAbility" and blizzFrame.Style then
        blizzFrame.Style:SetAlpha(settings.hideArtwork and 0 or 1)
    end
end

local function RefreshExtraButtonAppearance()
    ApplyExtraButtonAppearanceSafe("extraActionButton")
    ApplyExtraButtonAppearanceSafe("zoneAbility")
end

_G.SuaviUI_RefreshExtraButtonAppearance = RefreshExtraButtonAppearance

-- Reapply on entering world (after UI reload / login)
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
        C_Timer.After(1.0, RefreshExtraButtonAppearance)
    end)
end

-- Inject SuaviUI controls into Blizzard's Extra Abilities Edit Mode dialog
C_Timer.After(0.5, function()
    local EP = ns.EditModePanels
    if not EP or not Enum or not Enum.EditModeSystem then return end

    local EXTRA_ABILITIES_SYSTEM = Enum.EditModeSystem.ExtraAbilities
    if EXTRA_ABILITIES_SYSTEM == nil then return end

    local function IsExtraAbilitiesSystem(sf)
        return sf and sf.system == EXTRA_ABILITIES_SYSTEM
    end

    local extraControlKeys = {
        "extraAbilities_dividerEA",
        "extraAbilities_scaleEA",
        "extraAbilities_artEA",
        "extraAbilities_fadeEA",
        "extraAbilities_dividerZA",
        "extraAbilities_scaleZA",
        "extraAbilities_artZA",
        "extraAbilities_fadeZA",
    }

    local function MakeScaleGetter(bt)
        return function() local db = GetExtraButtonDB(bt); return db and db.scale or 1.0 end
    end
    local function MakeScaleSetter(bt)
        return function(v)
            local db = GetExtraButtonDB(bt)
            if db then db.scale = v; ApplyExtraButtonAppearanceSafe(bt) end
        end
    end
    local function MakeArtGetter(bt)
        return function() local db = GetExtraButtonDB(bt); return db and db.hideArtwork or false end
    end
    local function MakeArtSetter(bt)
        return function(v)
            local db = GetExtraButtonDB(bt)
            if db then db.hideArtwork = v; ApplyExtraButtonAppearanceSafe(bt) end
        end
    end
    local function MakeFadeGetter(bt)
        return function() local db = GetExtraButtonDB(bt); return db and db.fadeEnabled or false end
    end
    local function MakeFadeSetter(bt)
        return function(v)
            local db = GetExtraButtonDB(bt)
            if db then db.fadeEnabled = v end
            -- Mouseover fade requires a reload to fully wire up.
        end
    end

    local function InitExtraAbilityControls()
        local c = EP.controls
        c.extraAbilities_dividerEA = EP.CreateDivider("ExtraAbilities_EA", "Extra Action Button")
        c.extraAbilities_scaleEA   = EP.CreateSlider("ExtraAbilities_Scale_EA", "Scale",
            0.5, 2.0, 0.05, MakeScaleGetter("extraActionButton"), MakeScaleSetter("extraActionButton"))
        c.extraAbilities_artEA     = EP.CreateCheckbox("ExtraAbilities_Art_EA", "Hide Button Artwork",
            MakeArtGetter("extraActionButton"), MakeArtSetter("extraActionButton"))
        c.extraAbilities_fadeEA    = EP.CreateCheckbox("ExtraAbilities_Fade_EA", "Enable Mouseover Fade (reload required)",
            MakeFadeGetter("extraActionButton"), MakeFadeSetter("extraActionButton"))

        c.extraAbilities_dividerZA = EP.CreateDivider("ExtraAbilities_ZA", "Zone Ability Button")
        c.extraAbilities_scaleZA   = EP.CreateSlider("ExtraAbilities_Scale_ZA", "Scale",
            0.5, 2.0, 0.05, MakeScaleGetter("zoneAbility"), MakeScaleSetter("zoneAbility"))
        c.extraAbilities_artZA     = EP.CreateCheckbox("ExtraAbilities_Art_ZA", "Hide Button Artwork",
            MakeArtGetter("zoneAbility"), MakeArtSetter("zoneAbility"))
        c.extraAbilities_fadeZA    = EP.CreateCheckbox("ExtraAbilities_Fade_ZA", "Enable Mouseover Fade (reload required)",
            MakeFadeGetter("zoneAbility"), MakeFadeSetter("zoneAbility"))
    end

    EP.RegisterSystem(IsExtraAbilitiesSystem, InitExtraAbilityControls, extraControlKeys)
end)










