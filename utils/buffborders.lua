-- buffborders.lua
-- Adds configurable black borders around buff/debuff icons in the top right

local _, SUI = ...

-- Get settings from AceDB
local function GetSettings()
    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if not SUICore or not SUICore.db or not SUICore.db.profile then
        return nil
    end
    -- Ensure buffBorders table exists
    if not SUICore.db.profile.buffBorders then
        SUICore.db.profile.buffBorders = {
            enableBuffs = true,
            enableDebuffs = true,
            enableDeadlyDebuffs = true,
            enableExternalDefensives = true,
            hideBuffFrame = false,
            hideDebuffFrame = false,
            borderSize = 2,
            fontSize = 12,
            fontOutline = true,
        }
    end
    return SUICore.db.profile.buffBorders
end

-- Border colors by aura type
local BORDER_COLORS = {
    buff     = {0, 0, 0, 1},       -- Black for buffs
    debuff   = {0.5, 0, 0, 1},     -- Dark red for debuffs
    deadly   = {0.8, 0, 0, 1},     -- Bright red for deadly debuffs
    external = {0, 0.4, 0, 1},     -- Dark green for external defensives
}

-- Track which buttons we've already bordered
local borderedButtons = {}

-- Add border to a single aura button
-- auraType: "buff", "debuff", "deadly", "external"
local function AddBorderToButton(button, auraType)
    if not button or borderedButtons[button] then
        return
    end
    
    -- Check if borders are enabled for this type
    local settings = GetSettings()
    if not settings then return end
    local enableMap = {
        buff = settings.enableBuffs,
        debuff = settings.enableDebuffs,
        deadly = settings.enableDeadlyDebuffs ~= false,
        external = settings.enableExternalDefensives ~= false,
    }
    if enableMap[auraType] == false then
        return
    end
    
    -- Find the icon texture (the actual square icon, not the full button frame)
    local icon = button.Icon or button.icon
    if not icon then
        return
    end

    -- Validate button is a proper frame that supports CreateTexture
    -- (Boss fight frames may have Icon but not be valid Frame objects)
    if not button.CreateTexture or type(button.CreateTexture) ~= "function" then
        return
    end
    
    local borderSize = settings.borderSize or 2
    
    -- Choose border color based on aura type
    local borderColor = BORDER_COLORS[auraType] or BORDER_COLORS.buff
    
    -- Create 4 separate edge textures for clean borders around the ICON only
    if not button.suaviBorderTop then
        -- Top border
        button.suaviBorderTop = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.suaviBorderTop:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        button.suaviBorderTop:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
        
        -- Bottom border
        button.suaviBorderBottom = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.suaviBorderBottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
        button.suaviBorderBottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        
        -- Left border
        button.suaviBorderLeft = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.suaviBorderLeft:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        button.suaviBorderLeft:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
        
        -- Right border
        button.suaviBorderRight = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.suaviBorderRight:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
        button.suaviBorderRight:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    end
    
    -- Update border color based on type
    button.suaviBorderTop:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    button.suaviBorderBottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    button.suaviBorderLeft:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    button.suaviBorderRight:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    
    -- Update border size
    button.suaviBorderTop:SetHeight(borderSize)
    button.suaviBorderBottom:SetHeight(borderSize)
    button.suaviBorderLeft:SetWidth(borderSize)
    button.suaviBorderRight:SetWidth(borderSize)
    
    button.suaviBorderTop:Show()
    button.suaviBorderBottom:Show()
    button.suaviBorderLeft:Show()
    button.suaviBorderRight:Show()
    
    borderedButtons[button] = true
end

-- Hide borders on a button
local function HideBorderOnButton(button)
    if button.suaviBorderTop then button.suaviBorderTop:Hide() end
    if button.suaviBorderBottom then button.suaviBorderBottom:Hide() end
    if button.suaviBorderLeft then button.suaviBorderLeft:Hide() end
    if button.suaviBorderRight then button.suaviBorderRight:Hide() end
end

-- Apply font settings to duration text
local function ApplyFontSettings(button)
    if not button then return end

    local settings = GetSettings()
    if not settings then return end

    -- Get font and outline from general settings
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local generalFont = "Fonts\\FRIZQT__.TTF"
    local generalOutline = "OUTLINE"

    local SUICore = _G.SuaviUI and _G.SuaviUI.SUICore
    if SUICore and SUICore.db and SUICore.db.profile and SUICore.db.profile.general then
        local general = SUICore.db.profile.general
        if general.font and LSM then
            generalFont = LSM:Fetch("font", general.font) or generalFont
        end
        generalOutline = general.fontOutline or "OUTLINE"
    end

    -- Duration text (timer showing remaining time)
    local duration = button.Duration or button.duration
    if duration and duration.SetFont then
        local fontSize = settings.fontSize or 12
        duration:SetFont(generalFont, fontSize, generalOutline)
    end
end

-- Process all aura buttons in a container
-- auraType: "buff", "debuff", "deadly", "external"
local function ProcessAuraContainer(container, auraType)
    if not container then return end
    
    -- Get all child frames
    local frames = {container:GetChildren()}
    for _, frame in ipairs(frames) do
        -- Check if this looks like an aura button
        if frame.Icon or frame.icon then
            AddBorderToButton(frame, auraType)
            ApplyFontSettings(frame)
        end
    end
end

-- Hide/show entire BuffFrame or DebuffFrame based on settings
local function ApplyFrameHiding()
    local settings = GetSettings()
    if not settings then return end

    -- BuffFrame hiding (simple Hide + Show hook, no EnableMouse)
    if BuffFrame then
        if settings.hideBuffFrame then
            BuffFrame:Hide()
        else
            BuffFrame:Show()
        end
        -- Hook Show() once to prevent Blizzard from re-showing
        if not BuffFrame._SUI_ShowHooked then
            BuffFrame._SUI_ShowHooked = true
            hooksecurefunc(BuffFrame, "Show", function(self)
                local s = GetSettings()
                if s and s.hideBuffFrame then
                    self:Hide()
                end
            end)
        end
    end

    -- DebuffFrame hiding (simple Hide + Show hook, no EnableMouse)
    if DebuffFrame then
        if settings.hideDebuffFrame then
            DebuffFrame:Hide()
        else
            DebuffFrame:Show()
        end
        -- Hook Show() once to prevent Blizzard from re-showing
        if not DebuffFrame._SUI_ShowHooked then
            DebuffFrame._SUI_ShowHooked = true
            hooksecurefunc(DebuffFrame, "Show", function(self)
                local s = GetSettings()
                if s and s.hideDebuffFrame then
                    self:Hide()
                end
            end)
        end
    end
end

-- Main function to process all buff/debuff frames
local function ApplyBuffBorders()
    -- Wipe cache each cycle to prevent stale references from aura button pool recycling.
    -- Textures already exist on the buttons so re-processing is cheap (just color/size updates).
    wipe(borderedButtons)

    -- Apply frame hiding first
    ApplyFrameHiding()

    -- Process BuffFrame containers (top right buffs)
    if BuffFrame and BuffFrame.AuraContainer then
        ProcessAuraContainer(BuffFrame.AuraContainer, "buff")
    end
    
    -- Process DebuffFrame if it exists separately
    if DebuffFrame and DebuffFrame.AuraContainer then
        ProcessAuraContainer(DebuffFrame.AuraContainer, "debuff")
    end
    
    -- Process DeadlyDebuffFrame (boss deadly mechanics, shown at 1.25x scale)
    if DeadlyDebuffFrame then
        local debuff = DeadlyDebuffFrame.Debuff
        if debuff and (debuff.Icon or debuff.icon) then
            AddBorderToButton(debuff, "deadly")
            ApplyFontSettings(debuff)
        end
    end

    -- Process ExternalDefensivesFrame (Pain Suppression, Ironbark, etc.)
    if ExternalDefensivesFrame and ExternalDefensivesFrame.AuraContainer then
        ProcessAuraContainer(ExternalDefensivesFrame.AuraContainer, "external")
    end

    -- Process temporary enchant frames (treat as buffs)
    if TemporaryEnchantFrame then
        local frames = {TemporaryEnchantFrame:GetChildren()}
        for _, frame in ipairs(frames) do
            AddBorderToButton(frame, "buff")
            ApplyFontSettings(frame)
        end
    end
end

-- Debounce state for buff border updates (shared across all hooks)
local buffBorderPending = false

-- Schedule a debounced buff border update
-- Only one timer runs at a time, no matter how many hooks fire
local function ScheduleBuffBorders()
    if buffBorderPending then return end
    buffBorderPending = true
    C_Timer.After(0.15, function()  -- 150ms debounce for CPU efficiency
        buffBorderPending = false
        ApplyBuffBorders()
    end)
end

-- Hook into aura update functions
local function HookAuraUpdates()
    -- Hook BuffFrame updates
    if BuffFrame and BuffFrame.Update then
        hooksecurefunc(BuffFrame, "Update", ScheduleBuffBorders)
    end

    -- Hook AuraContainer updates if it exists (buffs)
    if BuffFrame and BuffFrame.AuraContainer and BuffFrame.AuraContainer.Update then
        hooksecurefunc(BuffFrame.AuraContainer, "Update", ScheduleBuffBorders)
    end

    -- Hook DebuffFrame updates
    if DebuffFrame and DebuffFrame.Update then
        hooksecurefunc(DebuffFrame, "Update", ScheduleBuffBorders)
    end

    -- Hook DebuffFrame.AuraContainer updates if it exists
    if DebuffFrame and DebuffFrame.AuraContainer and DebuffFrame.AuraContainer.Update then
        hooksecurefunc(DebuffFrame.AuraContainer, "Update", ScheduleBuffBorders)
    end

    -- Hook DeadlyDebuffFrame updates (boss deadly mechanics)
    if DeadlyDebuffFrame and DeadlyDebuffFrame.Update then
        hooksecurefunc(DeadlyDebuffFrame, "Update", ScheduleBuffBorders)
    end

    -- Hook ExternalDefensivesFrame updates (external defensives like Pain Suppression)
    if ExternalDefensivesFrame then
        if ExternalDefensivesFrame.Update then
            hooksecurefunc(ExternalDefensivesFrame, "Update", ScheduleBuffBorders)
        end
        if ExternalDefensivesFrame.AuraContainer and ExternalDefensivesFrame.AuraContainer.Update then
            hooksecurefunc(ExternalDefensivesFrame.AuraContainer, "Update", ScheduleBuffBorders)
        end
    end

    -- Hook the global aura update function if available
    if type(AuraButton_Update) == "function" then
        hooksecurefunc("AuraButton_Update", ScheduleBuffBorders)
    end
end

-- Performance: Removed redundant 1-second polling loop
-- UNIT_AURA event and AuraButton_Update hook already handle all buff border updates

-- Initialize (UNIT_AURA handles dynamic updates)
-- Note: Initial application is now called from suicore_main.lua OnEnable() to ensure AceDB is ready
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_AURA")

eventFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "UNIT_AURA" and arg == "player" then
        ScheduleBuffBorders()  -- Use shared debounce
    end
end)

-- Hook aura updates on first load
C_Timer.After(2, HookAuraUpdates)

-- Export to SUI namespace
SUI.BuffBorders = {
    Apply = ApplyBuffBorders,
    AddBorder = AddBorderToButton,
}

-- Global function for config panel to call
_G.SuaviUI_RefreshBuffBorders = function()
    ApplyBuffBorders()  -- Cache is wiped inside ApplyBuffBorders
end












