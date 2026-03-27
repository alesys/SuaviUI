---------------------------------------------------------------------------
-- CDM Enhanced Alerts
-- Extends Blizzard's Cooldown Manager alert system with:
--   1. Custom SoundKit IDs — injected into Blizzard's data, played natively
--   2. SharedMedia sounds — post-hook via PlaySoundFile
--   3. Custom TTS messages — post-hook via StopSpeakingText + SpeakText
--
-- APPROACH:
--   SoundKit IDs are injected into CooldownViewerSoundData at load time.
--   Blizzard's own pipeline plays them (zero taint, zero double sounds).
--   SharedMedia + TTS use hooksecurefunc post-hook on PlayAlert.
--
-- NEVER replace global CooldownViewerAlert_PlayAlert — doing so taints
-- the calling context (TriggerAlertEvent → RefreshData cascade).
---------------------------------------------------------------------------
local _, ns = ...
local SUI = SuaviUI
if ns.DISABLE_ALL_CDM_HOOKS or (ns.CDM_HOOKS and not ns.CDM_HOOKS.alerts) then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------
local CUSTOM_ENUM_BASE = 1000  -- our enum values start here (Blizzard uses 0-67)
local ALERT_DEBOUNCE = 2.0     -- seconds between same alert per item

---------------------------------------------------------------------------
-- DB ACCESS
---------------------------------------------------------------------------
local function GetDB()
    return SUI and SUI.SUICore and SUI.SUICore.db
        and SUI.SUICore.db.profile and SUI.SUICore.db.profile.cdmAlerts
end

local function GetOverride(cooldownID, alertEvent)
    local db = GetDB()
    if not db or not db.enabled then return nil end
    local overrides = db.overrides
    return overrides and overrides[cooldownID] and overrides[cooldownID][alertEvent]
end

local function SetOverride(cooldownID, alertEvent, data)
    local db = GetDB()
    if not db then return end
    db.overrides = db.overrides or {}
    db.overrides[cooldownID] = db.overrides[cooldownID] or {}
    db.overrides[cooldownID][alertEvent] = data
end

local function RemoveOverride(cooldownID, alertEvent)
    local db = GetDB()
    if not db or not db.overrides then return end
    if db.overrides[cooldownID] then
        db.overrides[cooldownID][alertEvent] = nil
        if not next(db.overrides[cooldownID]) then
            db.overrides[cooldownID] = nil
        end
    end
end

---------------------------------------------------------------------------
-- DETAINT
-- Secret/tainted strings pass type()=="string" but fail string operations.
-- Detect via pcall(string.len), then clean via FontString round-trip.
---------------------------------------------------------------------------
local detaintFS = nil
local function Detaint(value, fallback)
    local ok = pcall(string.len, value)
    if ok then return value end
    if not detaintFS then
        detaintFS = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        detaintFS:Hide()
    end
    local ok2, result = pcall(function()
        detaintFS:SetText(value)
        return detaintFS:GetText()
    end)
    return (ok2 and result) or fallback or ""
end

---------------------------------------------------------------------------
-- NATIVE INJECTION: SoundKit IDs → CooldownViewerSoundData
-- Injected at load time so Blizzard's lazy init picks them up.
-- BuildSoundMenus() traverses CooldownViewerSoundData and shows them
-- in the dropdown. Entries with soundEnum+text are treated as leaf buttons.
---------------------------------------------------------------------------
local customSoundKitMap = {}  -- enumVal → soundKitID (for post-hook fallback)
local injected = false

local function InjectCustomSounds()
    if injected then return end
    injected = true

    if not CooldownViewerSoundData or not CooldownViewerSound then return end

    local db = GetDB()
    if not db then return end
    local sounds = db.customSounds
    if not sounds then return end

    for i, entry in ipairs(sounds) do
        if entry.soundKitID and entry.soundKitID > 0 then
            local enumVal = CUSTOM_ENUM_BASE + i
            local label = entry.label or ("Sound " .. entry.soundKitID)

            -- Add to Blizzard's enum table
            CooldownViewerSound["SuaviUI_" .. i] = enumVal

            -- Add as top-level entry in Blizzard's data table.
            -- BuildSoundMenus sees soundEnum+text → creates a selectable button.
            -- Prefixed with colored marker for visual distinction.
            CooldownViewerSoundData[enumVal] = {
                soundEnum = enumVal,
                soundKitID = entry.soundKitID,
                text = "|cFF30D1FF\226\150\186|r " .. label,
            }

            -- Keep our own mapping for post-hook fallback
            -- (in case lazy init already ran before our injection)
            customSoundKitMap[enumVal] = entry.soundKitID
        end
    end
end

---------------------------------------------------------------------------
-- PLAYBACK FUNCTIONS
---------------------------------------------------------------------------
local function PlaySoundKitAlert(soundKitID)
    PlaySound(soundKitID)
end

local function PlayLSMAlert(lsmName)
    if not LSM then return end
    local path = LSM:Fetch("sound", lsmName, true)
    if path then PlaySoundFile(path, "SFX") end
end

local function PlayTTSAlert(message, spellName)
    local text = message:gsub("{Spell}", spellName or "")
    local voice = TextToSpeechFrame_GetSpeakerVoiceForMessageType
        and TextToSpeechFrame_GetSpeakerVoiceForMessageType(nil)
    if voice then
        C_VoiceChat.SpeakText(
            voice.voiceID, text,
            C_TTSSettings.GetSpeechRate(),
            C_TTSSettings.GetSpeechVolume(), true
        )
    end
end

local function PlayCustomAlert(override, spellName)
    if override.type == "soundkit" and override.soundKitID then
        PlaySoundKitAlert(override.soundKitID)
    elseif override.type == "lsm" and override.lsmName then
        PlayLSMAlert(override.lsmName)
    elseif override.type == "tts" and override.ttsMessage then
        PlayTTSAlert(override.ttsMessage, spellName)
    end
end

---------------------------------------------------------------------------
-- POST-HOOK: hooksecurefunc on CooldownViewerAlert_PlayAlert
-- Runs AFTER the original Blizzard function (secure context preserved).
-- Handles:
--   1. Fallback for SoundKit entries added after lazy init (Blizzard's
--      PlaySound(nil) is silent, our hook plays the actual sound)
--   2. SharedMedia overrides (PlaySoundFile on top of original)
--   3. Custom TTS overrides (StopSpeakingText + custom message)
---------------------------------------------------------------------------
local recentAlerts = setmetatable({}, { __mode = "k" })

local function OnAlertPlayed(cooldownItem, spellName, alert)
    local alertType = CooldownViewerAlert_GetType(alert)
    if alertType ~= Enum.CooldownViewerAlertType.Sound then return end

    local ok, cooldownID = pcall(function() return cooldownItem:GetCooldownID() end)
    if not ok or not cooldownID then return end

    local alertEvent = CooldownViewerAlert_GetEvent(alert)

    -- Debounce: weak table, no CDM frame writes
    local now = GetTime()
    local itemAlerts = recentAlerts[cooldownItem]
    if itemAlerts and itemAlerts[alertEvent]
       and (now - itemAlerts[alertEvent]) < ALERT_DEBOUNCE then
        return
    end
    if not itemAlerts then
        itemAlerts = {}
        recentAlerts[cooldownItem] = itemAlerts
    end
    itemAlerts[alertEvent] = now

    -- Check for SuaviUI override (SharedMedia / TTS)
    local override = GetOverride(cooldownID, alertEvent)
    if override then
        local cleanName = Detaint(spellName, "Spell")
        if override.type == "tts" then
            pcall(C_VoiceChat.StopSpeakingText)
        end
        PlayCustomAlert(override, cleanName)
        return
    end

    -- Fallback: if the alert payload is one of our custom enum values
    -- but Blizzard's mapping didn't have it (lazy init already ran),
    -- play it from our own map.
    local alertPayload = CooldownViewerAlert_GetPayload(alert)
    if alertPayload and alertPayload >= CUSTOM_ENUM_BASE then
        local soundKitID = customSoundKitMap[alertPayload]
        if soundKitID then
            PlaySound(soundKitID)
        end
    end
end

---------------------------------------------------------------------------
-- DIALOG UI INJECTION
-- Adds SuaviUI controls to Blizzard's CooldownViewerSettingsEditAlert
-- dialog for SharedMedia + Custom TTS overrides.
-- SoundKit sounds go through Blizzard's native dropdown (no override needed).
---------------------------------------------------------------------------
local suaviPanel = nil

local SOURCE_LSM = "lsm"
local SOURCE_TTS = "tts"
local SOURCE_LABELS = {
    [SOURCE_LSM] = "SharedMedia Sound",
    [SOURCE_TTS] = "Custom TTS Message",
}
local SOURCE_ORDER = { SOURCE_LSM, SOURCE_TTS }

local function CreateSuaviPanel(dialog)
    if suaviPanel then return suaviPanel end

    dialog:SetHeight(520)

    local panel = CreateFrame("Frame", nil, dialog)
    panel:SetPoint("TOPLEFT", dialog.PayloadDropdown, "BOTTOMLEFT", 0, -20)
    panel:SetPoint("RIGHT", dialog, "RIGHT", -20, 0)
    panel:SetHeight(130)

    -- Divider
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    -- Header
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -8)
    header:SetText("|cFF30D1FFSuaviUI|r Custom Alert")

    -- Enable checkbox
    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -6)
    checkbox:SetSize(26, 26)
    local cbText = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbText:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    cbText:SetText("Override with custom alert")
    panel.enableCheckbox = checkbox

    -- Controls container
    local controls = CreateFrame("Frame", nil, panel)
    controls:SetPoint("TOPLEFT", checkbox, "BOTTOMLEFT", 4, -4)
    controls:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    controls:SetHeight(80)
    panel.controls = controls

    -- Source label
    local sourceLabel = controls:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sourceLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, 0)
    sourceLabel:SetText("Source:")
    sourceLabel:SetTextColor(1, 0.82, 0, 1)

    -- Source dropdown
    local sourceDropdown = CreateFrame("DropdownButton", nil, controls, "WowStyle1DropdownTemplate")
    sourceDropdown:SetPoint("TOPLEFT", sourceLabel, "BOTTOMLEFT", 0, -2)
    sourceDropdown:SetSize(200, 25)
    panel.sourceDropdown = sourceDropdown
    panel.currentSource = SOURCE_LSM

    -- Preview button
    local previewBtn = CreateFrame("Button", nil, controls, "UIPanelButtonNoTooltipTemplate, UIButtonTemplate")
    previewBtn:SetSize(60, 25)
    previewBtn:SetPoint("LEFT", sourceDropdown, "RIGHT", 6, 0)
    previewBtn:SetText("Play")
    panel.previewBtn = previewBtn

    -- SharedMedia dropdown
    local lsmDropdown = CreateFrame("DropdownButton", nil, controls, "WowStyle1DropdownTemplate")
    lsmDropdown:SetSize(200, 25)
    lsmDropdown:SetPoint("TOPLEFT", sourceDropdown, "BOTTOMLEFT", 0, -6)
    panel.lsmDropdown = lsmDropdown
    panel.currentLSMName = nil

    -- TTS editbox
    local ttsBox = CreateFrame("EditBox", nil, controls, "InputBoxTemplate")
    ttsBox:SetSize(262, 22)
    ttsBox:SetPoint("TOPLEFT", sourceDropdown, "BOTTOMLEFT", 0, -6)
    ttsBox:SetAutoFocus(false)
    ttsBox:SetMaxLetters(200)
    local ttsHint = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ttsHint:SetPoint("TOPLEFT", ttsBox, "BOTTOMLEFT", 2, -2)
    ttsHint:SetText("Use {Spell} for spell name")
    ttsHint:SetTextColor(0.5, 0.5, 0.5, 1)
    panel.ttsBox = ttsBox
    panel.ttsHint = ttsHint

    -- Control visibility
    local function ShowSourceControls(source)
        panel.currentSource = source
        panel.lsmDropdown:Hide()
        panel.ttsBox:Hide()
        panel.ttsHint:Hide()
        if source == SOURCE_LSM then
            panel.lsmDropdown:Show()
        elseif source == SOURCE_TTS then
            panel.ttsBox:Show()
            panel.ttsHint:Show()
        end
    end

    -- Source dropdown setup
    sourceDropdown:SetSelectionText(function()
        return SOURCE_LABELS[panel.currentSource] or "SharedMedia Sound"
    end)
    sourceDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:SetTag("SUI_ALERT_SOURCE")
        for _, source in ipairs(SOURCE_ORDER) do
            rootDescription:CreateRadio(SOURCE_LABELS[source], function()
                return panel.currentSource == source
            end, function()
                ShowSourceControls(source)
            end)
        end
    end)

    -- LSM dropdown setup
    lsmDropdown:SetSelectionText(function()
        return panel.currentLSMName or "Select Sound..."
    end)
    lsmDropdown:SetupMenu(function(dropdown, rootDescription)
        rootDescription:SetTag("SUI_ALERT_LSM")
        if LSM then
            local sounds = LSM:List("sound") or {}
            for _, name in ipairs(sounds) do
                rootDescription:CreateRadio(name, function()
                    return panel.currentLSMName == name
                end, function()
                    panel.currentLSMName = name
                end)
            end
        end
    end)

    -- Preview handler
    previewBtn:SetScript("OnClick", function()
        local source = panel.currentSource
        if source == SOURCE_LSM then
            if panel.currentLSMName then
                PlayCustomAlert({ type = SOURCE_LSM, lsmName = panel.currentLSMName })
            end
        elseif source == SOURCE_TTS then
            local text = panel.ttsBox:GetText()
            if text and text ~= "" then
                local spellName = dialog:GetCooldownName() or "Spell"
                PlayCustomAlert({ type = SOURCE_TTS, ttsMessage = text }, spellName)
            end
        end
    end)

    -- Checkbox toggle
    checkbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            controls:Show()
        else
            controls:Hide()
        end
    end)

    controls:Hide()
    ShowSourceControls(SOURCE_LSM)

    suaviPanel = panel
    return panel
end

---------------------------------------------------------------------------
-- Populate / save from panel
---------------------------------------------------------------------------
local function PopulatePanelFromOverride(panel, override)
    if not override then
        panel.enableCheckbox:SetChecked(false)
        panel.controls:Hide()
        panel.currentSource = SOURCE_LSM
        panel.currentLSMName = nil
        panel.ttsBox:SetText("")
        return
    end

    panel.enableCheckbox:SetChecked(true)
    panel.controls:Show()

    if override.type == SOURCE_LSM then
        panel.currentSource = SOURCE_LSM
        panel.currentLSMName = override.lsmName
    elseif override.type == SOURCE_TTS then
        panel.currentSource = SOURCE_TTS
        panel.ttsBox:SetText(override.ttsMessage or "")
    end

    panel.lsmDropdown:Hide()
    panel.ttsBox:Hide()
    panel.ttsHint:Hide()
    if panel.currentSource == SOURCE_LSM then
        panel.lsmDropdown:Show()
    elseif panel.currentSource == SOURCE_TTS then
        panel.ttsBox:Show()
        panel.ttsHint:Show()
    end
end

local function SaveOverrideFromPanel(panel, cooldownID, alertEvent)
    if not panel.enableCheckbox:GetChecked() then
        RemoveOverride(cooldownID, alertEvent)
        return
    end

    local source = panel.currentSource
    local data = { type = source }

    if source == SOURCE_LSM then
        if not panel.currentLSMName then return end
        data.lsmName = panel.currentLSMName
    elseif source == SOURCE_TTS then
        local text = panel.ttsBox:GetText()
        if not text or text == "" then return end
        data.ttsMessage = text
    end

    SetOverride(cooldownID, alertEvent, data)
end

---------------------------------------------------------------------------
-- DIALOG HOOKS
---------------------------------------------------------------------------
local function SetupDialogHooks()
    local dialog = CooldownViewerSettingsEditAlert
    if not dialog then return end

    hooksecurefunc(CooldownViewerSettingsEditAlertMixin, "DisplayForAlert", function(self)
        local panel = CreateSuaviPanel(self)
        local cooldownID = self:GetCooldownID()
        local alertEvent = CooldownViewerAlert_GetEvent(self.workingCopyOfAlert)
        local override = GetOverride(cooldownID, alertEvent)
        PopulatePanelFromOverride(panel, override)
        panel:Show()
    end)

    hooksecurefunc(CooldownViewerSettingsEditAlertMixin, "SetupDropdowns", function(self)
        if not suaviPanel then return end
        local alertType = CooldownViewerAlert_GetType(self.workingCopyOfAlert)
        if alertType == Enum.CooldownViewerAlertType.Sound then
            suaviPanel:Show()
            local cooldownID = self:GetCooldownID()
            local alertEvent = CooldownViewerAlert_GetEvent(self.workingCopyOfAlert)
            local override = GetOverride(cooldownID, alertEvent)
            PopulatePanelFromOverride(suaviPanel, override)
        else
            suaviPanel:Hide()
        end
    end)

    hooksecurefunc(CooldownViewerSettingsEditAlertMixin, "AddCurrentAlert", function(self)
        if not suaviPanel then return end
        local cooldownID = self:GetCooldownID()
        local alertEvent = CooldownViewerAlert_GetEvent(self.workingCopyOfAlert)
        SaveOverrideFromPanel(suaviPanel, cooldownID, alertEvent)
    end)

    hooksecurefunc(CooldownViewerSettingsEditAlertMixin, "OnHide", function()
        if suaviPanel then suaviPanel:Hide() end
    end)
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
local hookInstalled = false

local function InstallHook()
    if hookInstalled then return true end
    if not CooldownViewerAlert_PlayAlert then return false end

    hooksecurefunc("CooldownViewerAlert_PlayAlert", OnAlertPlayed)
    hookInstalled = true
    return true
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == "Blizzard_CooldownViewer" then
        -- Inject BEFORE lazy init (CheckCreateSoundAlertData) runs
        InjectCustomSounds()
        InstallHook()
        SetupDialogHooks()
    elseif event == "PLAYER_LOGIN" then
        InjectCustomSounds()
        if InstallHook() then
            SetupDialogHooks()
        end
    end
end)

-- Deferred fallback if Blizzard_CooldownViewer loaded before us
C_Timer.After(0, function()
    InjectCustomSounds()
    if InstallHook() then
        SetupDialogHooks()
    end
end)
