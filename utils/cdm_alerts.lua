---------------------------------------------------------------------------
-- CDM Enhanced Alerts
-- Custom SoundKit IDs, SharedMedia sounds, and custom TTS messages
-- for Blizzard's Cooldown Manager alert system.
---------------------------------------------------------------------------
local _, ns = ...
local SUI = SuaviUI
if ns.DISABLE_ALL_CDM_HOOKS or (ns.CDM_HOOKS and not ns.CDM_HOOKS.alerts) then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

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
-- PLAYALERT OVERRIDE (Option A: pre-hook replacement)
---------------------------------------------------------------------------
local originalPlayAlert = nil

local function SuaviUI_PlayAlert(cooldownItem, spellName, alert)
    local alertType = CooldownViewerAlert_GetType(alert)
    -- Only override Sound alerts (leave Visual alerts untouched)
    if alertType ~= Enum.CooldownViewerAlertType.Sound then
        return originalPlayAlert(cooldownItem, spellName, alert)
    end

    local ok, cooldownID = pcall(function() return cooldownItem:GetCooldownID() end)
    if not ok or not cooldownID then
        return originalPlayAlert(cooldownItem, spellName, alert)
    end

    local alertEvent = CooldownViewerAlert_GetEvent(alert)
    local override = GetOverride(cooldownID, alertEvent)
    if override then
        PlayCustomAlert(override, spellName)
    else
        originalPlayAlert(cooldownItem, spellName, alert)
    end
end

---------------------------------------------------------------------------
-- DIALOG UI INJECTION
-- Adds SuaviUI controls to Blizzard's CooldownViewerSettingsEditAlert
-- dialog (the "New Alert" / "Edit Alert" panel).
---------------------------------------------------------------------------
local suaviPanel = nil  -- cached SuaviUI sub-frame

-- Source type constants
local SOURCE_SOUNDKIT = "soundkit"
local SOURCE_LSM = "lsm"
local SOURCE_TTS = "tts"
local SOURCE_LABELS = {
    [SOURCE_SOUNDKIT] = "SoundKit ID",
    [SOURCE_LSM] = "SharedMedia Sound",
    [SOURCE_TTS] = "Custom TTS Message",
}
local SOURCE_ORDER = { SOURCE_SOUNDKIT, SOURCE_LSM, SOURCE_TTS }

local function CreateSuaviPanel(dialog)
    if suaviPanel then return suaviPanel end

    -- Increase dialog height to accommodate our controls
    dialog:SetHeight(520)

    local panel = CreateFrame("Frame", nil, dialog)
    panel:SetPoint("TOPLEFT", dialog.PayloadDropdown, "BOTTOMLEFT", 0, -20)
    panel:SetPoint("RIGHT", dialog, "RIGHT", -20, 0)
    panel:SetHeight(130)

    -- Divider line
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    -- Section header
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -8)
    header:SetText("|cFF30D1FFSuaviUI|r Custom Alert")

    -- Enable checkbox
    local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -4, -6)
    checkbox:SetSize(26, 26)
    local cbText = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbText:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    cbText:SetText("Override with custom sound")
    panel.enableCheckbox = checkbox

    -- Controls container (shown/hidden by checkbox)
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
    panel.currentSource = SOURCE_SOUNDKIT

    -- Preview button (right of source dropdown)
    local previewBtn = CreateFrame("Button", nil, controls, "UIPanelButtonNoTooltipTemplate, UIButtonTemplate")
    previewBtn:SetSize(60, 25)
    previewBtn:SetPoint("LEFT", sourceDropdown, "RIGHT", 6, 0)
    previewBtn:SetText("Play")
    panel.previewBtn = previewBtn

    -- SoundKit ID editbox
    local soundKitBox = CreateFrame("EditBox", nil, controls, "InputBoxTemplate")
    soundKitBox:SetSize(200, 22)
    soundKitBox:SetPoint("TOPLEFT", sourceDropdown, "BOTTOMLEFT", 0, -6)
    soundKitBox:SetAutoFocus(false)
    soundKitBox:SetNumeric(true)
    soundKitBox:SetMaxLetters(10)
    local skLabel = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skLabel:SetPoint("LEFT", soundKitBox, "RIGHT", 6, 0)
    skLabel:SetText("Enter SoundKit ID")
    skLabel:SetTextColor(0.5, 0.5, 0.5, 1)
    panel.soundKitBox = soundKitBox
    panel.soundKitLabel = skLabel

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

    ---------------------------------------------------------------------------
    -- Control visibility based on source type
    ---------------------------------------------------------------------------
    local function ShowSourceControls(source)
        panel.currentSource = source
        panel.soundKitBox:Hide()
        panel.soundKitLabel:Hide()
        panel.lsmDropdown:Hide()
        panel.ttsBox:Hide()
        panel.ttsHint:Hide()

        if source == SOURCE_SOUNDKIT then
            panel.soundKitBox:Show()
            panel.soundKitLabel:Show()
        elseif source == SOURCE_LSM then
            panel.lsmDropdown:Show()
        elseif source == SOURCE_TTS then
            panel.ttsBox:Show()
            panel.ttsHint:Show()
        end
    end

    ---------------------------------------------------------------------------
    -- Source dropdown setup
    ---------------------------------------------------------------------------
    sourceDropdown:SetSelectionText(function()
        return SOURCE_LABELS[panel.currentSource] or "SoundKit ID"
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

    ---------------------------------------------------------------------------
    -- LSM dropdown setup
    ---------------------------------------------------------------------------
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

    ---------------------------------------------------------------------------
    -- Preview button handler
    ---------------------------------------------------------------------------
    previewBtn:SetScript("OnClick", function()
        local source = panel.currentSource
        if source == SOURCE_SOUNDKIT then
            local id = panel.soundKitBox:GetNumber()
            if id and id > 0 then PlaySound(id) end
        elseif source == SOURCE_LSM then
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

    ---------------------------------------------------------------------------
    -- Checkbox toggle
    ---------------------------------------------------------------------------
    checkbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            controls:Show()
        else
            controls:Hide()
        end
    end)

    -- Initial state: hidden
    controls:Hide()
    ShowSourceControls(SOURCE_SOUNDKIT)

    suaviPanel = panel
    return panel
end

---------------------------------------------------------------------------
-- Populate controls from existing override data
---------------------------------------------------------------------------
local function PopulatePanelFromOverride(panel, override)
    if not override then
        panel.enableCheckbox:SetChecked(false)
        panel.controls:Hide()
        -- Reset to defaults
        panel.currentSource = SOURCE_SOUNDKIT
        panel.soundKitBox:SetText("")
        panel.currentLSMName = nil
        panel.ttsBox:SetText("")
        return
    end

    panel.enableCheckbox:SetChecked(true)
    panel.controls:Show()

    if override.type == SOURCE_SOUNDKIT then
        panel.currentSource = SOURCE_SOUNDKIT
        panel.soundKitBox:SetText(tostring(override.soundKitID or ""))
    elseif override.type == SOURCE_LSM then
        panel.currentSource = SOURCE_LSM
        panel.currentLSMName = override.lsmName
    elseif override.type == SOURCE_TTS then
        panel.currentSource = SOURCE_TTS
        panel.ttsBox:SetText(override.ttsMessage or "")
    end

    -- Show correct controls
    panel.soundKitBox:Hide()
    panel.soundKitLabel:Hide()
    panel.lsmDropdown:Hide()
    panel.ttsBox:Hide()
    panel.ttsHint:Hide()

    if panel.currentSource == SOURCE_SOUNDKIT then
        panel.soundKitBox:Show()
        panel.soundKitLabel:Show()
    elseif panel.currentSource == SOURCE_LSM then
        panel.lsmDropdown:Show()
    elseif panel.currentSource == SOURCE_TTS then
        panel.ttsBox:Show()
        panel.ttsHint:Show()
    end
end

---------------------------------------------------------------------------
-- Save override from current panel state
---------------------------------------------------------------------------
local function SaveOverrideFromPanel(panel, cooldownID, alertEvent)
    if not panel.enableCheckbox:GetChecked() then
        RemoveOverride(cooldownID, alertEvent)
        return
    end

    local source = panel.currentSource
    local data = { type = source }

    if source == SOURCE_SOUNDKIT then
        local id = panel.soundKitBox:GetNumber()
        if not id or id <= 0 then return end
        data.soundKitID = id
    elseif source == SOURCE_LSM then
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

    -- Hook DisplayForAlert to populate SuaviUI controls when dialog opens
    hooksecurefunc(CooldownViewerSettingsEditAlertMixin, "DisplayForAlert", function(self)
        local panel = CreateSuaviPanel(self)
        local cooldownID = self:GetCooldownID()
        local alertEvent = CooldownViewerAlert_GetEvent(self.workingCopyOfAlert)
        local override = GetOverride(cooldownID, alertEvent)
        PopulatePanelFromOverride(panel, override)
        panel:Show()
    end)

    -- Hook SetupDropdowns to re-read event type when user changes dropdowns
    hooksecurefunc(CooldownViewerSettingsEditAlertMixin, "SetupDropdowns", function(self)
        if not suaviPanel then return end
        local alertType = CooldownViewerAlert_GetType(self.workingCopyOfAlert)
        -- Only show SuaviUI panel for Sound alerts
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

    -- Hook AddCurrentAlert to save SuaviUI override when user clicks Apply
    hooksecurefunc(CooldownViewerSettingsEditAlertMixin, "AddCurrentAlert", function(self)
        if not suaviPanel then return end
        local cooldownID = self:GetCooldownID()
        local alertEvent = CooldownViewerAlert_GetEvent(self.workingCopyOfAlert)
        SaveOverrideFromPanel(suaviPanel, cooldownID, alertEvent)
    end)

    -- Clear panel state when dialog hides
    hooksecurefunc(CooldownViewerSettingsEditAlertMixin, "OnHide", function()
        if suaviPanel then
            suaviPanel:Hide()
        end
    end)
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
local function InitAlertOverride()
    if not CooldownViewerAlert_PlayAlert then return false end
    if originalPlayAlert then return true end  -- already initialized

    originalPlayAlert = CooldownViewerAlert_PlayAlert
    CooldownViewerAlert_PlayAlert = SuaviUI_PlayAlert
    return true
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == "Blizzard_CooldownViewer" then
        InitAlertOverride()
        SetupDialogHooks()
    elseif event == "PLAYER_LOGIN" then
        -- Fallback: if Blizzard_CooldownViewer loaded before us
        if InitAlertOverride() then
            SetupDialogHooks()
        end
    end
end)

-- Also try immediate init if already loaded
if CooldownViewerAlert_PlayAlert then
    InitAlertOverride()
    -- Dialog hooks deferred to PLAYER_LOGIN since dialog frame may not exist yet
end
