--- SuaviUI CDMAlignedMixin
-- Extends PowerBarMixin with CDM (Cooldown Manager) integration
-- Handles width sync, alignment, and auto-orientation detection

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local PowerBarMixin = ns.PowerBarMixin

local CDMAlignedMixin = CreateFromMixins(PowerBarMixin)

-- Scale helper (must be defined before use)
local function Scale(x)
    if SUICore and SUICore.Scale then
        return SUICore:Scale(x)
    end
    return x
end

-- Determine if bar should be vertical based on CDM
local function GetCDMOrientation(viewerName)
    local viewer = viewerName and _G[viewerName]
    if viewer and viewer.__cdmLayoutDirection then
        return viewer.__cdmLayoutDirection == "VERTICAL"
    end
    return false
end

-- Apply CDM width synchronization
function CDMAlignedMixin:SyncWidthToCDM()
    local cfg = self:GetDB()
    if not cfg or not cfg.widthSync or cfg.widthSync == "none" then
        return
    end
    
    local viewer
    if cfg.widthSync == "essential" then
        viewer = _G.EssentialCooldownViewer
    elseif cfg.widthSync == "utility" then
        viewer = _G.UtilityCooldownViewer
    elseif cfg.widthSync == "primary" and self.barKey == "secondary" then
        return self:SyncWidthToPrimaryBar()
    end
    
    if viewer then
        local width = viewer.__cdmIconWidth or viewer:GetWidth()
        if width and width > 0 then
            self:SetWidth(Scale(width))
            return true
        end
    end
    return false
end

-- Sync secondary bar to primary bar width
function CDMAlignedMixin:SyncWidthToPrimaryBar()
    local primaryBar = SUICore.bars and SUICore.bars.primary
    if primaryBar and primaryBar:IsShown() then
        self:SetWidth(primaryBar:GetWidth())
        return true
    end
    return false
end

-- Apply CDM alignment
function CDMAlignedMixin:AlignToCDM()
    local cfg = self:GetDB()
    if not cfg or not cfg.alignTo or cfg.alignTo == "none" then
        return
    end
    
    if cfg.alignTo == "primary" and self.barKey == "secondary" then
        return self:AlignToPrimaryBar()
    end
    
    local viewerName
    if cfg.alignTo == "essential" then
        viewerName = "EssentialCooldownViewer"
    elseif cfg.alignTo == "utility" then
        viewerName = "UtilityCooldownViewer"
    end
    
    if not viewerName then return false end
    
    local viewer = _G[viewerName]
    if not viewer or not viewer:IsShown() then
        return false
    end
    
    local centerX, centerY = viewer:GetCenter()
    local screenX, screenY = UIParent:GetCenter()
    
    if not centerX or not centerY or not screenX or not screenY then
        return false
    end
    
    centerX = math.floor(centerX + 0.5)
    centerY = math.floor(centerY + 0.5)
    screenX = math.floor(screenX + 0.5)
    screenY = math.floor(screenY + 0.5)
    
    local offsetX = math.floor(centerX - screenX + 0.5)
    local offsetY = math.floor(centerY - screenY + 0.5)
    
    local barHeight = cfg.height or 8
    local barWidth = cfg.width or 300
    local isVertical = cfg.orientation == "VERTICAL"
    
    if isVertical then
        -- Vertical orientation - position to side of viewer
        if cfg.alignTo == "essential" then
            local totalWidth = viewer.__cdmIconWidth or viewer:GetWidth()
            offsetX = offsetX + math.floor((totalWidth / 2) + 10)
        else
            offsetX = offsetX - math.floor((barHeight / 2) + 10)
        end
    else
        -- Horizontal orientation - position above/below viewer
        if cfg.alignTo == "essential" then
            offsetY = offsetY + math.floor((viewer:GetHeight() / 2) + cfg.snapGap)
        else
            offsetY = offsetY - math.floor((viewer:GetHeight() / 2) + cfg.snapGap)
        end
    end
    
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
    return true
end

-- Align secondary bar to primary bar
function CDMAlignedMixin:AlignToPrimaryBar()
    local primaryBar = SUICore.bars and SUICore.bars.primary
    if not primaryBar or not primaryBar:IsShown() then
        return false
    end
    
    local cfg = self:GetDB()
    local primaryCfg = SUICore.db.profile.resourceBars.primaryPowerBar[self:GetLayout()]
    
    local primaryX, primaryY = primaryBar:GetCenter()
    local screenX, screenY = UIParent:GetCenter()
    
    if not primaryX or not primaryY then
        return false
    end
    
    primaryX = math.floor(primaryX + 0.5)
    primaryY = math.floor(primaryY + 0.5)
    screenX = math.floor(screenX + 0.5)
    screenY = math.floor(screenY + 0.5)
    
    local offsetX = math.floor(primaryX - screenX + 0.5)
    local offsetY = math.floor(primaryY - screenY + 0.5) - primaryBar:GetHeight() - (cfg.snapGap or 5)
    
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY)
    return true
end

-- Get orientation (HORIZONTAL or VERTICAL)
function CDMAlignedMixin:GetOrientation()
    local cfg = self:GetDB()
    local orientation = cfg.orientation or "AUTO"
    
    if orientation == "VERTICAL" then
        return "VERTICAL"
    elseif orientation == "AUTO" then
        -- Auto-detect from synced CDM
        local syncTarget = cfg.widthSync or cfg.alignTo or "none"
        if syncTarget == "essential" then
            return GetCDMOrientation("EssentialCooldownViewer") and "VERTICAL" or "HORIZONTAL"
        elseif syncTarget == "utility" then
            return GetCDMOrientation("UtilityCooldownViewer") and "VERTICAL" or "HORIZONTAL"
        elseif syncTarget == "primary" and self.barKey == "secondary" then
            local primaryCfg = SUICore.db.profile.resourceBars.primaryPowerBar[self:GetLayout()]
            if primaryCfg then
                return self:GetOrientationForConfig(primaryCfg)
            end
        end
    end
    
    return "HORIZONTAL"
end

-- Helper: get orientation from a config object
function CDMAlignedMixin:GetOrientationForConfig(cfg)
    if cfg.orientation == "VERTICAL" then
        return "VERTICAL"
    elseif cfg.orientation == "AUTO" then
        if cfg.widthSync == "essential" then
            return GetCDMOrientation("EssentialCooldownViewer") and "VERTICAL" or "HORIZONTAL"
        elseif cfg.widthSync == "utility" then
            return GetCDMOrientation("UtilityCooldownViewer") and "VERTICAL" or "HORIZONTAL"
        end
    end
    return "HORIZONTAL"
end

-- Apply CDM-aligned layout
function CDMAlignedMixin:ApplyCDMLayout()
    local cfg = self:GetDB()
    if not cfg or not cfg.enabled then
        self:Hide()
        return
    end
    
    -- Sync width first
    self:SyncWidthToCDM()
    
    -- Then align position
    self:AlignToCDM()
    
    -- Set orientation
    local orientation = self:GetOrientation()
    self.StatusBar:SetOrientation(orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
end

ns.CDMAlignedMixin = CDMAlignedMixin
