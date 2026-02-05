--[[
    SuaviUI Welcome Screen
    Shows on first install or when triggered from Credits page
    Provides an overview of features and getting started guide
]]

local ADDON_NAME, ns = ...
local SUI = SuaviUI
local LSM = LibStub("LibSharedMedia-3.0")

---------------------------------------------------------------------------
-- WELCOME SCREEN MODULE
---------------------------------------------------------------------------
local Welcome = {}
ns.Welcome = Welcome

-- Theme colors (match GUI)
local C = {
    bg = {0.067, 0.094, 0.153, 0.98},
    bgLight = {0.122, 0.161, 0.216, 1},
    accent = {0.659, 0.333, 0.969, 1},
    accentLight = {0.753, 0.518, 0.988, 1},
    text = {0.953, 0.957, 0.965, 1},
    textMuted = {0.6, 0.65, 0.7, 1},
    border = {0.2, 0.25, 0.3, 1},
    success = {0.204, 0.827, 0.600, 1},  -- #34D399 Emerald
}

---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------
local WELCOME_WIDTH = 650
local WELCOME_HEIGHT = 700
local LOGO_SIZE = 100
local PADDING = 25

---------------------------------------------------------------------------
-- FEATURES LIST (The Dark Arts)
---------------------------------------------------------------------------
local FEATURES = {
    {
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
        title = "Bound Unit Frames",
        desc = "Your enemies and allies, crystallized into perfect clarity. No soul escapes your gaze."
    },
    {
        icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
        title = "Cooldown Manager (CDM)",
        desc = "Channel the forbidden knowledge of when to strike. Every ability, tracked. Every moment, calculated."
    },
    {
        icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
        title = "Resource Bars",
        desc = "Your power made manifest. Combo points, runes, holy power—all dancing at your command."
    },
    {
        icon = "Interface\\Icons\\Spell_Nature_Lightning",
        title = "Cast Bars",
        desc = "See the future before it arrives. Know when spells complete—yours and theirs."
    },
    {
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        title = "Edit Mode Mastery",
        desc = "Reshape reality itself. Every frame bends to your will through Blizzard's own arcane interface."
    },
    {
        icon = "Interface\\Icons\\Achievement_BG_winAV",
        title = "Profile Grimoire",
        desc = "Store your configurations like spells in a tome. Switch specs, switch layouts. Share the knowledge."
    },
}

---------------------------------------------------------------------------
-- CREATE WELCOME FRAME
---------------------------------------------------------------------------
function Welcome:CreateFrame()
    if self.frame then return self.frame end
    
    -- Main frame
    local frame = CreateFrame("Frame", "SuaviUI_WelcomeScreen", UIParent, "BackdropTemplate")
    frame:SetSize(WELCOME_WIDTH, WELCOME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    
    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    frame:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Scroll frame for content
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 60)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(WELCOME_WIDTH - 40, 1000)  -- Height will be adjusted
    scrollFrame:SetScrollChild(content)
    
    -- Build content
    local y = -PADDING
    
    -- Logo
    local logo = content:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOP", content, "TOP", 0, y)
    logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    logo:SetTexture("Interface\\AddOns\\SuaviUI\\assets\\textures\\suaviLogo")
    y = y - LOGO_SIZE - 15
    
    -- Title
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", content, "TOP", 0, y)
    title:SetText("The Ritual is Complete.")
    title:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
    title:SetFont(title:GetFont(), 26, "OUTLINE")
    y = y - 35
    
    -- Version
    local version = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    version:SetPoint("TOP", content, "TOP", 0, y)
    local ADDON_VERSION = C_AddOns.GetAddOnMetadata("SuaviUI", "Version") or "2.0.0"
    version:SetText("Grimoire Edition " .. ADDON_VERSION)
    version:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
    y = y - 30
    
    -- Thank you message
    local thankYou = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    thankYou:SetPoint("TOP", content, "TOP", 0, y)
    thankYou:SetWidth(WELCOME_WIDTH - 60)
    thankYou:SetText("You have summoned SuaviUI into your realm. This |cffA855F7dark work|r is still being perfected in the fires of the Twisting Nether. Your whispers shape its destiny.")
    thankYou:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    thankYou:SetJustifyH("CENTER")
    thankYou:SetWordWrap(true)
    thankYou:SetFont(thankYou:GetFont(), 13)
    y = y - 50
    
    -- Separator
    local sep1 = content:CreateTexture(nil, "ARTWORK")
    sep1:SetPoint("TOP", content, "TOP", 0, y)
    sep1:SetSize(400, 1)
    sep1:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.5)
    y = y - 20
    
    -- Features header
    local featuresHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    featuresHeader:SetPoint("TOP", content, "TOP", 0, y)
    featuresHeader:SetText("The Dark Arts")
    featuresHeader:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3], 1)
    featuresHeader:SetFont(featuresHeader:GetFont(), 16, "OUTLINE")
    y = y - 30
    
    -- Features list
    for _, feature in ipairs(FEATURES) do
        -- Icon
        local icon = content:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", content, "TOPLEFT", PADDING, y)
        icon:SetSize(28, 28)
        icon:SetTexture(feature.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        -- Title
        local featureTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        featureTitle:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
        featureTitle:SetText(feature.title)
        featureTitle:SetTextColor(C.accent[1], C.accent[2], C.accent[3], 1)
        featureTitle:SetFont(featureTitle:GetFont(), 13)
        
        -- Description
        local featureDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        featureDesc:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -18)
        featureDesc:SetWidth(WELCOME_WIDTH - 100)
        featureDesc:SetText(feature.desc)
        featureDesc:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
        featureDesc:SetJustifyH("LEFT")
        featureDesc:SetWordWrap(true)
        featureDesc:SetFont(featureDesc:GetFont(), 11)
        
        y = y - 50
    end
    
    y = y - 10
    
    -- Separator
    local sep2 = content:CreateTexture(nil, "ARTWORK")
    sep2:SetPoint("TOP", content, "TOP", 0, y)
    sep2:SetSize(400, 1)
    sep2:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.5)
    y = y - 20
    
    -- Getting Started header
    local gettingStarted = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    gettingStarted:SetPoint("TOP", content, "TOP", 0, y)
    gettingStarted:SetText("Begin the Incantation")
    gettingStarted:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3], 1)
    gettingStarted:SetFont(gettingStarted:GetFont(), 16, "OUTLINE")
    y = y - 30
    
    -- Steps
    local steps = {
        { num = "1", text = "Whisper |cffA855F7/sui|r to commune with the configuration realm." },
        { num = "2", text = "Invoke |cffA855F7/em|r or |cffA855F7/ed|r to bend reality and position your frames." },
        { num = "3", text = "Chant |cffA855F7/cdm|r to shape the appearance of your cooldown trackers." },
        { num = "4", text = "Consult the |cffA855F7Profiles|r grimoire to store and recall your configurations." },
    }
    
    for _, step in ipairs(steps) do
        -- Number circle
        local numBg = content:CreateTexture(nil, "ARTWORK")
        numBg:SetPoint("TOPLEFT", content, "TOPLEFT", PADDING, y + 2)
        numBg:SetSize(22, 22)
        numBg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        numBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        
        local numText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        numText:SetPoint("CENTER", numBg, "CENTER", 0, 0)
        numText:SetText(step.num)
        numText:SetTextColor(0.05, 0.05, 0.1, 1)
        numText:SetFont(numText:GetFont(), 12, "OUTLINE")
        
        -- Step text
        local stepText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stepText:SetPoint("TOPLEFT", numBg, "TOPRIGHT", 10, 0)
        stepText:SetWidth(WELCOME_WIDTH - 90)
        stepText:SetText(step.text)
        stepText:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
        stepText:SetJustifyH("LEFT")
        stepText:SetWordWrap(true)
        stepText:SetFont(stepText:GetFont(), 12)
        
        y = y - 30
    end
    
    y = y - 20
    
    -- Separator
    local sep3 = content:CreateTexture(nil, "ARTWORK")
    sep3:SetPoint("TOP", content, "TOP", 0, y)
    sep3:SetSize(400, 1)
    sep3:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.5)
    y = y - 20
    
    -- Feedback section
    local feedbackHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    feedbackHeader:SetPoint("TOP", content, "TOP", 0, y)
    feedbackHeader:SetText("Send Word to the Nether")
    feedbackHeader:SetTextColor(C.accentLight[1], C.accentLight[2], C.accentLight[3], 1)
    feedbackHeader:SetFont(feedbackHeader:GetFont(), 16, "OUTLINE")
    y = y - 30
    
    local feedbackText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    feedbackText:SetPoint("TOP", content, "TOP", 0, y)
    feedbackText:SetWidth(WELCOME_WIDTH - 60)
    feedbackText:SetText("The dark work continues, and your counsel strengthens the spell.\n\nDiscovered an anomaly? Have forbidden knowledge to share? Send your whispers through |cffA855F7CurseForge|r or |cffA855F7GitHub|r. Every report makes the magic more... |cffA855F7smooth|r.")
    feedbackText:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
    feedbackText:SetJustifyH("CENTER")
    feedbackText:SetWordWrap(true)
    feedbackText:SetFont(feedbackText:GetFont(), 12)
    y = y - 70
    
    -- WIP Notice
    local wipNotice = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wipNotice:SetPoint("TOP", content, "TOP", 0, y)
    wipNotice:SetWidth(WELCOME_WIDTH - 60)
    wipNotice:SetText("|cffF59E0B⚠ Ritual in Progress|r\nThe spell is still being woven. Some incantations may shift in future summonings.")
    wipNotice:SetTextColor(C.text[1], C.text[2], C.text[3], 1)
    wipNotice:SetJustifyH("CENTER")
    wipNotice:SetWordWrap(true)
    wipNotice:SetFont(wipNotice:GetFont(), 11)
    y = y - 50
    
    -- Set content height
    content:SetHeight(math.abs(y) + 30)
    
    -- Bottom buttons container
    local btnContainer = CreateFrame("Frame", nil, frame)
    btnContainer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    btnContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    btnContainer:SetHeight(55)
    
    -- "Don't show again" checkbox
    local dontShowAgain = CreateFrame("CheckButton", nil, btnContainer, "UICheckButtonTemplate")
    dontShowAgain:SetSize(24, 24)
    dontShowAgain:SetPoint("BOTTOMLEFT", btnContainer, "BOTTOMLEFT", PADDING, 15)
    
    local dontShowLabel = btnContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dontShowLabel:SetPoint("LEFT", dontShowAgain, "RIGHT", 5, 0)
    dontShowLabel:SetText("Don't show this again")
    dontShowLabel:SetTextColor(C.textMuted[1], C.textMuted[2], C.textMuted[3], 1)
    dontShowLabel:SetFont(dontShowLabel:GetFont(), 11)
    
    dontShowAgain:SetScript("OnClick", function(self)
        local db = SuaviUI.db and SuaviUI.db.global
        if db then
            db.hideWelcomeScreen = self:GetChecked()
        end
    end)
    
    -- Get Started button
    local getStartedBtn = CreateFrame("Button", nil, btnContainer, "BackdropTemplate")
    getStartedBtn:SetSize(140, 36)
    getStartedBtn:SetPoint("BOTTOMRIGHT", btnContainer, "BOTTOMRIGHT", -PADDING, 12)
    getStartedBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    getStartedBtn:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 1)
    getStartedBtn:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    
    local btnText = getStartedBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btnText:SetPoint("CENTER", getStartedBtn, "CENTER", 0, 0)
    btnText:SetText("Let's Go!")
    btnText:SetTextColor(1, 1, 1, 1)
    btnText:SetFont(btnText:GetFont(), 14, "OUTLINE")
    
    getStartedBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C.accentLight[1], C.accentLight[2], C.accentLight[3], 1)
    end)
    
    getStartedBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    
    getStartedBtn:SetScript("OnClick", function()
        frame:Hide()
        -- Mark as seen
        local db = SuaviUI.db and SuaviUI.db.global
        if db then
            db.welcomeScreenShown = true
        end
    end)
    
    -- Store references
    self.frame = frame
    self.dontShowAgain = dontShowAgain
    
    -- Hide by default
    frame:Hide()
    
    return frame
end

---------------------------------------------------------------------------
-- SHOW WELCOME SCREEN
---------------------------------------------------------------------------
function Welcome:Show(force)
    local frame = self:CreateFrame()
    
    -- Check if we should show
    local db = SuaviUI.db and SuaviUI.db.global
    if not force and db then
        if db.hideWelcomeScreen then
            return
        end
    end
    
    -- Update checkbox state
    if self.dontShowAgain and db then
        self.dontShowAgain:SetChecked(db.hideWelcomeScreen or false)
    end
    
    frame:Show()
end

---------------------------------------------------------------------------
-- HIDE WELCOME SCREEN
---------------------------------------------------------------------------
function Welcome:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

---------------------------------------------------------------------------
-- CHECK FIRST RUN
---------------------------------------------------------------------------
function Welcome:CheckFirstRun()
    local db = SuaviUI.db and SuaviUI.db.global
    if not db then return end
    
    -- Check if this is the first time running
    if not db.welcomeScreenShown and not db.hideWelcomeScreen then
        -- Delay showing to ensure UI is fully loaded
        C_Timer.After(2, function()
            self:Show()
            db.welcomeScreenShown = true
        end)
    end
end

---------------------------------------------------------------------------
-- INITIALIZE
---------------------------------------------------------------------------
local function Initialize()
    -- Register for player login to check first run
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(self, event, isInitialLogin, isReloadingUi)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Only check on initial login, not on /reload
            if isInitialLogin then
                C_Timer.After(3, function()
                    Welcome:CheckFirstRun()
                end)
            end
            self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end)
end

Initialize()

-- Export for external access
ns.Welcome = Welcome
SuaviUI.Welcome = Welcome
