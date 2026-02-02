--[[
    SuaviUI Castbar Mixin
    Provides a mixin-based architecture for castbars matching the resource bar pattern.
    Implements ApplyLayout(), ApplySettings(), UpdateDisplay() for in-place updates.
    
    Key Design Principles:
    - Frame is NEVER destroyed after creation
    - Settings changes update properties in-place via ApplySettings()
    - Position/size changes use ApplyLayout()
    - LEM registration happens once at creation
]]

local ADDON_NAME, ns = ...
local LSM = LibStub("LibSharedMedia-3.0")
local LEM = LibStub("LibEQOLEditMode-1.0", true)

---------------------------------------------------------------------------
-- CASTBAR MIXIN
---------------------------------------------------------------------------
local CastbarMixin = {}
ns.CastbarMixin = CastbarMixin

---------------------------------------------------------------------------
-- HELPER FUNCTIONS (localized for performance)
---------------------------------------------------------------------------
local function Scale(x)
    local helpers = ns.CastbarHelpers
    return helpers and helpers.Scale and helpers.Scale(x) or x
end

local function GetFontPath()
    local helpers = ns.CastbarHelpers
    return helpers and helpers.GetFontPath and helpers.GetFontPath() or "Fonts\\FRIZQT__.TTF"
end

local function GetFontOutline()
    local helpers = ns.CastbarHelpers
    return helpers and helpers.GetFontOutline and helpers.GetFontOutline() or "OUTLINE"
end

local function GetTexturePath(textureName)
    local helpers = ns.CastbarHelpers
    return helpers and helpers.GetTexturePath and helpers.GetTexturePath(textureName) or "Interface\\Buttons\\WHITE8x8"
end

local function GetSafeColor(color, fallback)
    if color and color[1] and color[2] and color[3] then
        return color[1], color[2], color[3], color[4] or 1
    end
    fallback = fallback or {1, 0.7, 0, 1}
    return fallback[1], fallback[2], fallback[3], fallback[4] or 1
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
function CastbarMixin:Init(config)
    self.config = config
    self.unitKey = config.unitKey
    self.unit = config.unit or config.unitKey
    self.bossIndex = config.bossIndex
    
    -- State tracking
    self.isPreviewMode = false
    self.isEmpowered = false
    self.numStages = 0
    self.empoweredStages = {}
    self.stageOverlays = {}
    
    -- Create the main frame
    local frameName = "SUI_Castbar_" .. (self.unitKey or "Unknown"):gsub("^%l", string.upper)
    self.Frame = CreateFrame("Frame", frameName, UIParent)
    self.Frame:SetFrameStrata("MEDIUM")
    self.Frame:SetFrameLevel(200)
    self.Frame:Hide()
    
    -- Store reference to mixin on frame for callbacks
    self.Frame._castbarMixin = self
    self.Frame._suiCastbarUnit = self.unitKey
    
    -- Create UI elements
    self:CreateUIElements()
    
    return self
end

function CastbarMixin:CreateUIElements()
    local frame = self.Frame
    
    -- Status Bar
    self.statusBar = CreateFrame("StatusBar", nil, frame)
    self.statusBar:SetAllPoints()
    self.statusBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    self.statusBar:SetStatusBarColor(1, 0.7, 0, 1)
    self.statusBar:SetMinMaxValues(0, 1)
    self.statusBar:SetValue(0)
    
    -- Background Bar
    self.bgBar = self.statusBar:CreateTexture(nil, "BACKGROUND")
    self.bgBar:SetAllPoints(self.statusBar)
    self.bgBar:SetColorTexture(0.15, 0.15, 0.15, 1)
    
    -- Border (BackdropTemplate)
    self.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    self.border:SetFrameLevel(self.statusBar:GetFrameLevel() - 1)
    self.border:SetAllPoints(frame)
    
    -- Icon Frame
    self.icon = CreateFrame("Frame", nil, frame)
    self.icon:SetSize(25, 25)
    self.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    
    self.iconBorder = self.icon:CreateTexture(nil, "BACKGROUND", nil, -8)
    self.iconBorder:SetColorTexture(0, 0, 0, 1)
    self.iconBorder:SetAllPoints(self.icon)
    
    self.iconTexture = self.icon:CreateTexture(nil, "ARTWORK")
    self.iconTexture:SetPoint("TOPLEFT", self.icon, "TOPLEFT", 2, -2)
    self.iconTexture:SetPoint("BOTTOMRIGHT", self.icon, "BOTTOMRIGHT", -2, 2)
    self.iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Spell Text
    self.spellText = self.statusBar:CreateFontString(nil, "OVERLAY")
    self.spellText:SetFont(GetFontPath(), 12, GetFontOutline())
    self.spellText:SetPoint("LEFT", self.statusBar, "LEFT", 4, 0)
    self.spellText:SetJustifyH("LEFT")
    
    -- Time Text
    self.timeText = self.statusBar:CreateFontString(nil, "OVERLAY")
    self.timeText:SetFont(GetFontPath(), 12, GetFontOutline())
    self.timeText:SetPoint("RIGHT", self.statusBar, "RIGHT", -4, 0)
    self.timeText:SetJustifyH("RIGHT")
    
    -- Empowered Level Text (player only)
    self.empoweredLevelText = self.statusBar:CreateFontString(nil, "OVERLAY")
    self.empoweredLevelText:SetFont(GetFontPath(), 12, GetFontOutline())
    self.empoweredLevelText:SetPoint("CENTER", self.statusBar, "CENTER", 0, 0)
    self.empoweredLevelText:Hide()
    
    -- Store reference for compatibility
    frame.statusBar = self.statusBar
    frame.bgBar = self.bgBar
    frame.icon = self.icon
    frame.iconTexture = self.iconTexture
    frame.iconBorder = self.iconBorder
    frame.spellText = self.spellText
    frame.timeText = self.timeText
    frame.empoweredLevelText = self.empoweredLevelText
    frame.stageOverlays = self.stageOverlays
    frame.empoweredStages = self.empoweredStages
end

---------------------------------------------------------------------------
-- GETTERS
---------------------------------------------------------------------------
function CastbarMixin:GetFrame()
    return self.Frame
end

function CastbarMixin:GetUnitKey()
    return self.unitKey
end

function CastbarMixin:GetSettings()
    -- Get settings from unit frames module
    local helpers = ns.CastbarHelpers
    if helpers and helpers.GetUnitSettings then
        local unitSettings = helpers.GetUnitSettings(self.unitKey)
        return unitSettings and unitSettings.castbar or nil
    end
    return nil
end

function CastbarMixin:GetUnitFrame()
    local SUI_UF = ns.SUI_UnitFrames
    if SUI_UF and SUI_UF.frames then
        return SUI_UF.frames[self.unitKey]
    end
    return nil
end

---------------------------------------------------------------------------
-- APPLY LAYOUT (Position, Size, Anchoring)
-- Called when position/size/anchor changes - updates without recreation
---------------------------------------------------------------------------
function CastbarMixin:ApplyLayout(layoutName, force)
    if not self.Frame:IsShown() and not force then return end
    
    local settings = self:GetSettings()
    if not settings then return end
    
    local unitFrame = self:GetUnitFrame()
    
    -- Calculate sizing values
    local barHeight = Scale(settings.height or 25)
    barHeight = math.max(barHeight, Scale(4))
    local iconSize = Scale((settings.iconSize and settings.iconSize > 0) and settings.iconSize or 25)
    local iconScale = settings.iconScale or 1.0
    local borderSize = Scale(settings.borderSize or 1)
    
    -- Apply size
    self:ApplySize(settings, unitFrame, barHeight)
    
    -- Apply position/anchoring
    self:ApplyPosition(settings, unitFrame, barHeight)
    
    -- Apply icon layout
    self:ApplyIconLayout(settings, iconSize, iconScale, borderSize)
    
    -- Apply status bar layout
    self:ApplyStatusBarLayout(settings, barHeight, iconSize, iconScale, borderSize)
end

function CastbarMixin:ApplySize(settings, unitFrame, barHeight)
    local anchor = settings.anchor or "none"
    local frame = self.Frame
    
    if anchor == "essential" or anchor == "utility" then
        -- Size determined by cooldown manager bar
        frame:SetSize(1, barHeight)
    elseif anchor == "none" then
        local castWidth = Scale((settings.width and settings.width > 0) and settings.width or 250)
        frame:SetSize(castWidth, barHeight)
    else
        -- Anchored to unit frame
        local frameWidth = unitFrame and unitFrame:GetWidth() or 250
        local castWidth = Scale((settings.width and settings.width > 0) and settings.width or frameWidth)
        frame:SetSize(castWidth, barHeight)
    end
end

function CastbarMixin:ApplyPosition(settings, unitFrame, barHeight)
    local anchor = settings.anchor or "none"
    local frame = self.Frame
    
    frame:ClearAllPoints()
    
    if anchor == "essential" then
        local bar = _G["EssentialCooldownViewer"]
        if bar then
            local offsetY = Scale(settings.offsetY or -25)
            local anchorPoint = settings.anchorPoint or "BOTTOM"
            frame:SetPoint("TOP", bar, anchorPoint, 0, offsetY)
            frame:SetPoint("LEFT", bar, "LEFT", 0, 0)
            frame:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    elseif anchor == "utility" then
        local bar = _G["UtilityCooldownViewer"]
        if bar then
            local offsetY = Scale(settings.offsetY or -25)
            local anchorPoint = settings.anchorPoint or "BOTTOM"
            frame:SetPoint("TOP", bar, anchorPoint, 0, offsetY)
            frame:SetPoint("LEFT", bar, "LEFT", 0, 0)
            frame:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        else
            frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    elseif anchor == "unitframe" and unitFrame then
        local offsetX = Scale(settings.offsetX or 0)
        local offsetY = Scale(settings.offsetY or -25)
        local widthAdj = Scale(settings.widthAdjustment or 0)
        frame:SetPoint("TOPLEFT", unitFrame, "BOTTOMLEFT", offsetX - widthAdj, offsetY)
        frame:SetPoint("TOPRIGHT", unitFrame, "BOTTOMRIGHT", offsetX + widthAdj, offsetY)
    else
        -- Free position (none)
        local offsetX = settings.offsetX or 0
        local offsetY = settings.offsetY or 0
        frame:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
    end
end

function CastbarMixin:ApplyIconLayout(settings, iconSize, iconScale, borderSize)
    local iconFrame = self.icon
    if not iconFrame then return end
    
    local showIcon = settings.showIcon == true
    if not showIcon then
        iconFrame:Hide()
        return
    end
    
    local baseIconSize = iconSize * iconScale
    iconFrame:SetSize(baseIconSize, baseIconSize)
    iconFrame:ClearAllPoints()
    
    local iconAnchor = settings.iconAnchor or "TOPLEFT"
    iconFrame:SetPoint(iconAnchor, self.Frame, iconAnchor, 0, 0)
    
    -- Update icon border size
    local iconBorderSize = Scale(settings.iconBorderSize or 2)
    if self.iconTexture then
        self.iconTexture:ClearAllPoints()
        self.iconTexture:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", iconBorderSize, -iconBorderSize)
        self.iconTexture:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -iconBorderSize, iconBorderSize)
    end
    
    iconFrame:Show()
end

function CastbarMixin:ApplyStatusBarLayout(settings, barHeight, iconSize, iconScale, borderSize)
    local statusBar = self.statusBar
    if not statusBar then return end
    
    statusBar:SetHeight(barHeight)
    statusBar:ClearAllPoints()
    
    local showIcon = settings.showIcon == true
    
    if showIcon then
        local iconSizePx = iconSize * iconScale
        local iconSpacing = Scale(settings.iconSpacing or 0)
        local iconAnchor = settings.iconAnchor or "TOPLEFT"
        
        if iconAnchor:find("LEFT") then
            statusBar:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", iconSizePx + iconSpacing + borderSize, -borderSize)
            statusBar:SetPoint("BOTTOMRIGHT", self.Frame, "BOTTOMRIGHT", -borderSize, borderSize)
        elseif iconAnchor:find("RIGHT") then
            statusBar:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", borderSize, -borderSize)
            statusBar:SetPoint("BOTTOMRIGHT", self.Frame, "BOTTOMRIGHT", -iconSizePx - iconSpacing - borderSize, borderSize)
        else
            statusBar:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", borderSize, -borderSize)
            statusBar:SetPoint("BOTTOMRIGHT", self.Frame, "BOTTOMRIGHT", -borderSize, borderSize)
        end
    else
        statusBar:SetPoint("TOPLEFT", self.Frame, "TOPLEFT", borderSize, -borderSize)
        statusBar:SetPoint("BOTTOMRIGHT", self.Frame, "BOTTOMRIGHT", -borderSize, borderSize)
    end
    
    -- Update border
    self:ApplyBorderLayout(settings, borderSize)
end

function CastbarMixin:ApplyBorderLayout(settings, borderSize)
    local border = self.border
    if not border then return end
    
    border:ClearAllPoints()
    border:SetAllPoints(self.Frame)
    
    if borderSize > 0 then
        border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = borderSize,
        })
        local r, g, b, a = GetSafeColor(settings.borderColor, {0, 0, 0, 1})
        border:SetBackdropBorderColor(r, g, b, a)
        border:Show()
    else
        border:SetBackdrop(nil)
        border:Hide()
    end
end

---------------------------------------------------------------------------
-- APPLY SETTINGS (Visual properties: colors, textures, fonts)
-- Called when visual settings change - updates without recreation
---------------------------------------------------------------------------
function CastbarMixin:ApplySettings(layoutName, force)
    if not self.Frame:IsShown() and not force then return end
    
    local settings = self:GetSettings()
    if not settings then return end
    
    -- Apply texture
    self:ApplyTexture(settings)
    
    -- Apply colors
    self:ApplyColors(settings)
    
    -- Apply font settings
    self:ApplyFontSettings(settings)
    
    -- Apply text positions
    self:ApplyTextPositions(settings)
    
    -- Apply icon border color
    self:ApplyIconBorderColor(settings)
end

function CastbarMixin:ApplyTexture(settings)
    if self.statusBar then
        local texturePath = GetTexturePath(settings.texture)
        self.statusBar:SetStatusBarTexture(texturePath)
    end
end

function CastbarMixin:ApplyColors(settings)
    -- Bar color
    if self.statusBar then
        local barColor = settings.barColor or {1, 0.7, 0, 1}
        self.statusBar:SetStatusBarColor(GetSafeColor(barColor))
    end
    
    -- Background color
    if self.bgBar then
        local bgColor = settings.bgColor or {0.15, 0.15, 0.15, 1}
        self.bgBar:SetColorTexture(GetSafeColor(bgColor))
    end
    
    -- Border color
    if self.border then
        local borderColor = settings.borderColor or {0, 0, 0, 1}
        self.border:SetBackdropBorderColor(GetSafeColor(borderColor))
    end
end

function CastbarMixin:ApplyFontSettings(settings)
    local fontPath = GetFontPath()
    local fontOutline = GetFontOutline()
    local fontSize = settings.fontSize or 12
    
    if self.spellText then
        self.spellText:SetFont(fontPath, fontSize, fontOutline)
    end
    
    if self.timeText then
        self.timeText:SetFont(fontPath, fontSize, fontOutline)
    end
    
    if self.empoweredLevelText then
        self.empoweredLevelText:SetFont(fontPath, fontSize, fontOutline)
    end
end

function CastbarMixin:ApplyTextPositions(settings)
    -- Spell text position
    if self.spellText then
        self.spellText:ClearAllPoints()
        local anchor = settings.spellTextAnchor or "LEFT"
        local offsetX = Scale(settings.spellTextOffsetX or 4)
        local offsetY = Scale(settings.spellTextOffsetY or 0)
        self.spellText:SetPoint(anchor, self.statusBar, anchor, offsetX, offsetY)
        self.spellText:SetShown(settings.showSpellText ~= false)
    end
    
    -- Time text position
    if self.timeText then
        self.timeText:ClearAllPoints()
        local anchor = settings.timeTextAnchor or "RIGHT"
        local offsetX = Scale(settings.timeTextOffsetX or -4)
        local offsetY = Scale(settings.timeTextOffsetY or 0)
        self.timeText:SetPoint(anchor, self.statusBar, anchor, offsetX, offsetY)
        self.timeText:SetShown(settings.showTimeText ~= false)
    end
    
    -- Empowered level text position
    if self.empoweredLevelText then
        self.empoweredLevelText:ClearAllPoints()
        local anchor = settings.empoweredLevelTextAnchor or "CENTER"
        local offsetX = Scale(settings.empoweredLevelTextOffsetX or 0)
        local offsetY = Scale(settings.empoweredLevelTextOffsetY or 0)
        self.empoweredLevelText:SetPoint(anchor, self.statusBar, anchor, offsetX, offsetY)
        self.empoweredLevelText:SetShown(settings.showEmpoweredLevel == true)
    end
end

function CastbarMixin:ApplyIconBorderColor(settings)
    if self.iconBorder then
        local r, g, b, a = GetSafeColor(settings.iconBorderColor, {0, 0, 0, 1})
        self.iconBorder:SetColorTexture(r, g, b, a)
    end
end

---------------------------------------------------------------------------
-- VISIBILITY
---------------------------------------------------------------------------
function CastbarMixin:ApplyVisibilitySettings(layoutName)
    local settings = self:GetSettings()
    if not settings then
        self:Hide()
        return
    end
    
    -- In Edit Mode, always show
    if LEM and LEM:IsInEditMode() then
        self:Show()
        self:StartPreviewMode()
        return
    end
    
    -- Check if enabled
    if settings.enabled == false then
        self:Hide()
        return
    end
    
    -- During normal gameplay, visibility is controlled by cast events
    -- Don't force show here - let the event handlers manage it
end

function CastbarMixin:Show()
    self.Frame:Show()
end

function CastbarMixin:Hide()
    self.Frame:Hide()
end

function CastbarMixin:IsShown()
    return self.Frame:IsShown()
end

---------------------------------------------------------------------------
-- PREVIEW MODE (Edit Mode simulation)
---------------------------------------------------------------------------
function CastbarMixin:StartPreviewMode()
    self.isPreviewMode = true
    
    local settings = self:GetSettings() or {}
    local castTime = 3.0
    local spellName = "Preview Cast"
    local iconTexture = 136048  -- Generic spell icon
    
    self.previewStartTime = GetTime()
    self.previewEndTime = GetTime() + castTime
    self.previewValue = 0
    self.previewMaxValue = castTime
    
    -- Set visual state
    if self.statusBar then
        self.statusBar:SetMinMaxValues(0, castTime)
        self.statusBar:SetValue(0)
        self.statusBar:SetReverseFill(false)
    end
    
    if self.iconTexture then
        self.iconTexture:SetTexture(iconTexture)
        if settings.showIcon ~= false then
            self.icon:Show()
        end
    end
    
    if self.spellText then
        self.spellText:SetText(spellName)
        if settings.showSpellText ~= false then
            self.spellText:Show()
        end
    end
    
    if self.timeText then
        self.timeText:SetText(string.format("%.1f", castTime))
        if settings.showTimeText ~= false then
            self.timeText:Show()
        end
    end
    
    -- Start preview animation
    self:SetupPreviewOnUpdate()
end

function CastbarMixin:StopPreviewMode()
    self.isPreviewMode = false
    self.Frame:SetScript("OnUpdate", nil)
end

function CastbarMixin:SetupPreviewOnUpdate()
    self.Frame:SetScript("OnUpdate", function(frame, elapsed)
        if not self.isPreviewMode then return end
        
        local now = GetTime()
        local progress = now - self.previewStartTime
        
        if progress >= self.previewMaxValue then
            -- Loop the preview
            self.previewStartTime = now
            progress = 0
        end
        
        self.previewValue = progress
        
        if self.statusBar then
            self.statusBar:SetValue(progress)
        end
        
        if self.timeText then
            local remaining = self.previewMaxValue - progress
            self.timeText:SetText(string.format("%.1f", remaining))
        end
    end)
end

---------------------------------------------------------------------------
-- LEM INTEGRATION
---------------------------------------------------------------------------
function CastbarMixin:RegisterWithLEM(defaults)
    if not LEM then return false end
    
    local frame = self.Frame
    if not frame then return false end
    
    -- Position change callback
    local function OnPositionChanged(frame, point, x, y, layoutName)
        local settings = self:GetSettings()
        if settings then
            settings.offsetX = x
            settings.offsetY = y
            self:ApplyLayout(layoutName)
        end
    end
    
    defaults = defaults or {
        point = "CENTER",
        x = 0,
        y = 0,
    }
    
    -- Register frame with LEM
    local success = pcall(function()
        LEM:AddFrame(frame, OnPositionChanged, defaults)
    end)
    
    if success then
        -- Register callbacks
        LEM:RegisterCallback("enter", function()
            self:ApplyVisibilitySettings()
            self:ApplyLayout(nil, true)
            self:ApplySettings(nil, true)
        end)
        
        LEM:RegisterCallback("exit", function()
            self:StopPreviewMode()
            self:ApplyVisibilitySettings()
        end)
        
        LEM:RegisterCallback("layout", function(layoutName)
            self:ApplyVisibilitySettings(layoutName)
            self:ApplyLayout(layoutName, true)
            self:ApplySettings(layoutName, true)
        end)
    end
    
    return success
end

function CastbarMixin:AddLEMSettings(settings)
    if not LEM then return end
    LEM:AddFrameSettings(self.Frame, settings)
end

function CastbarMixin:SetLEMDragEnabled(enabled)
    if not LEM then return end
    if type(enabled) == "function" then
        LEM:SetFrameDragEnabled(self.Frame, enabled)
    else
        LEM:SetFrameDragEnabled(self.Frame, enabled)
    end
end

function CastbarMixin:SetLEMResetVisible(visible)
    if not LEM then return end
    if type(visible) == "function" then
        LEM:SetFrameResetVisible(self.Frame, visible)
    else
        LEM:SetFrameResetVisible(self.Frame, visible)
    end
end

---------------------------------------------------------------------------
-- FULL REFRESH (applies all settings)
---------------------------------------------------------------------------
function CastbarMixin:Refresh(layoutName, force)
    self:ApplyVisibilitySettings(layoutName)
    self:ApplyLayout(layoutName, force)
    self:ApplySettings(layoutName, force)
end

---------------------------------------------------------------------------
-- EXPORT MIXIN
---------------------------------------------------------------------------
ns.CastbarMixin = CastbarMixin
