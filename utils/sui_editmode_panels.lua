--[[
    SuaviUI Edit Mode Panel Injection
    Shared infrastructure for injecting SuaviUI settings into Blizzard's
    native EditModeSystemSettingsDialog panels.

    Architecture:
    - Factory functions create addon-owned frames that visually match
      Blizzard's Edit Mode templates but are completely isolated from
      Blizzard's setting pipeline (no taint, no fake setting IDs).
    - Systems register a predicate function + init callback + control keys.
    - A single hooksecurefunc on UpdateDialog iterates registered systems.
]]

local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- MODULE TABLE
---------------------------------------------------------------------------
local SUI_EditPanels = {}
ns.EditModePanels = SUI_EditPanels

-- All controls live here (keyed by unique name)
SUI_EditPanels.controls = {}

-- Registered systems: { predicate, init, controlKeys }
local registeredSystems = {}

---------------------------------------------------------------------------
-- CONTROL FACTORY FUNCTIONS
---------------------------------------------------------------------------

function SUI_EditPanels.CreateSlider(name, label, minVal, maxVal, stepSize, getter, setter)
    local frame = CreateFrame("Frame", "SUI_EditMode_" .. name, UIParent)
    frame:SetSize(343, 32)
    frame:Hide()

    local labelFS = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    labelFS:SetSize(100, 32)
    labelFS:SetPoint("LEFT")
    labelFS:SetJustifyH("LEFT")
    labelFS:SetText(label)
    frame.Label = labelFS

    local slider = CreateFrame("Frame", nil, frame, "MinimalSliderWithSteppersTemplate")
    slider:SetSize(200, 32)
    slider:SetPoint("LEFT", labelFS, "RIGHT", 5, 0)
    frame.Slider = slider

    frame.initInProgress = false
    frame._cbrHandles = EventUtil.CreateCallbackHandleContainer()
    frame._cbrHandles:RegisterCallback(slider, MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not frame.initInProgress then
            setter(value)
        end
    end)

    frame._suiGetter = getter
    frame._suiMin = minVal
    frame._suiMax = maxVal
    frame._suiStep = stepSize
    return frame
end

function SUI_EditPanels.CreateCheckbox(name, label, getter, setter)
    local frame = CreateFrame("Frame", "SUI_EditMode_" .. name, UIParent)
    frame:SetSize(343, 32)
    frame:Hide()

    local button = CreateFrame("CheckButton", nil, frame)
    button:SetSize(32, 32)
    button:SetPoint("LEFT", -5, 0)
    button:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    button:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    button:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    button:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    button:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        frame.checked = not frame.checked
        button:SetChecked(frame.checked)
        setter(frame.checked)
    end)
    frame.Button = button

    local labelFS = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    labelFS:SetSize(300, 32)
    labelFS:SetPoint("LEFT", button, "RIGHT", 5, 0)
    labelFS:SetJustifyH("LEFT")
    labelFS:SetText(label)
    frame.Label = labelFS

    frame._suiGetter = getter
    return frame
end

function SUI_EditPanels.CreateDropdown(name, label, optionsGetter, getter, setter)
    local frame = CreateFrame("Frame", "SUI_EditMode_" .. name, UIParent)
    frame:SetSize(343, 32)
    frame:Hide()

    local labelFS = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    labelFS:SetSize(100, 32)
    labelFS:SetPoint("LEFT")
    labelFS:SetJustifyH("LEFT")
    labelFS:SetText(label)
    frame.Label = labelFS

    local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(225)
    dropdown:SetPoint("LEFT", labelFS, "RIGHT", 5, 0)
    frame.Dropdown = dropdown

    frame._suiGetter = getter
    frame._suiOptionsGetter = optionsGetter
    frame._suiSetup = function()
        dropdown:SetupMenu(function(dd, rootDescription)
            local currentVal = getter()
            for _, opt in ipairs(optionsGetter()) do
                rootDescription:CreateRadio(opt.text, function() return getter() == opt.value end, function()
                    setter(opt.value)
                end, opt.value)
            end
        end)
    end
    return frame
end

function SUI_EditPanels.CreateDivider(name, label)
    local frame = CreateFrame("Frame", "SUI_EditMode_Divider_" .. name, UIParent)
    frame:SetSize(343, 20)
    frame:Hide()
    local text = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("LEFT", 0, 0)
    text:SetText("|cff00ccff" .. label .. "|r")
    text:SetJustifyH("LEFT")
    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", text, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    line:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    return frame
end

---------------------------------------------------------------------------
-- INJECTION INFRASTRUCTURE
---------------------------------------------------------------------------

local function HideAllSuiControls()
    for _, frame in pairs(SUI_EditPanels.controls) do
        if type(frame) == "table" and frame.Hide then
            frame:Hide()
        end
    end
end

local function InjectControls(dialog, controlKeys)
    -- Find highest layoutIndex among Blizzard's settings
    local maxIndex = 0
    for _, child in ipairs({dialog.Settings:GetChildren()}) do
        if child:IsShown() and child.layoutIndex then
            maxIndex = math.max(maxIndex, child.layoutIndex)
        end
    end

    local nextIndex = maxIndex + 1

    for _, key in ipairs(controlKeys) do
        local ctrl = SUI_EditPanels.controls[key]
        if ctrl then
            ctrl:SetParent(dialog.Settings)
            ctrl:SetPoint("TOPLEFT")
            ctrl.layoutIndex = nextIndex
            nextIndex = nextIndex + 1

            -- Type-specific refresh before showing
            if ctrl.Slider then
                ctrl.initInProgress = true
                local steps = (ctrl._suiMax - ctrl._suiMin) / ctrl._suiStep
                ctrl.Slider:Init(ctrl._suiGetter(), ctrl._suiMin, ctrl._suiMax, steps, {
                    [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right),
                })
                ctrl.initInProgress = false
            elseif ctrl.Button then
                local checked = ctrl._suiGetter()
                ctrl.checked = checked
                ctrl.Button:SetChecked(checked)
            elseif ctrl.Dropdown then
                ctrl._suiSetup()
            end

            ctrl:Show()
        end
    end

    dialog.Settings:Layout()

    -- Expand dialog height if our injected controls cause overflow.
    -- Blizzard's dialog may have a fixed height that clips our settings.
    C_Timer.After(0, function()
        if not dialog:IsShown() then return end
        local settingsHeight = dialog.Settings:GetHeight()
        local headerHeight = 60  -- approximate title + padding
        local neededHeight = settingsHeight + headerHeight + 20
        local maxHeight = select(2, GetPhysicalScreenSize()) * 0.85
        local finalHeight = math.min(neededHeight, maxHeight)
        if finalHeight > dialog:GetHeight() then
            dialog:SetHeight(finalHeight)
        end
    end)
end

-- Expose for direct use
SUI_EditPanels.InjectControls = InjectControls
SUI_EditPanels.HideAllSuiControls = HideAllSuiControls

---------------------------------------------------------------------------
-- SYSTEM REGISTRATION
---------------------------------------------------------------------------

--- Register a system to inject controls when its Edit Mode panel is active.
--- @param predicate function(systemFrame) -> boolean
--- @param init function() -- lazy-init controls (called once)
--- @param controlKeys table -- ordered list of keys in SUI_EditPanels.controls
function SUI_EditPanels.RegisterSystem(predicate, init, controlKeys)
    table.insert(registeredSystems, {
        predicate = predicate,
        init = init,
        controlKeys = controlKeys,
        inited = false,
    })
end

---------------------------------------------------------------------------
-- HOOK: EditModeSystemSettingsDialog:UpdateDialog
---------------------------------------------------------------------------

C_Timer.After(0, function()
    local dialog = EditModeSystemSettingsDialog
    if not dialog then return end

    hooksecurefunc(dialog, "UpdateDialog", function(self, systemFrame)
        HideAllSuiControls()

        for _, sys in ipairs(registeredSystems) do
            if sys.predicate(systemFrame) then
                if not sys.inited then
                    sys.init()
                    sys.inited = true
                end
                InjectControls(self, sys.controlKeys)
                return  -- Only one system matches at a time
            end
        end
    end)
end)
