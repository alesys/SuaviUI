--- SuaviUI BarMixin
-- Base mixin for all resource bars - handles frame creation, borders, backgrounds, text

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

local function Scale(x)
    if SUICore and SUICore.Scale then
        return SUICore:Scale(x)
    end
    return x
end

local BarMixin = {}

-- Create the bar frame and all sub-elements
function BarMixin:OnLoad(config)
    self.config = config
    self.barKey = config.barKey
    self.dbName = config.dbName
    
    -- Frame setup
    self:SetFrameStrata("MEDIUM")
    
    -- Background texture
    self.Background = self:CreateTexture(nil, "BACKGROUND")
    self.Background:SetAllPoints()
    
    -- Status bar (the actual progress bar)
    self.StatusBar = CreateFrame("StatusBar", nil, self)
    self.StatusBar:SetAllPoints()
    self.StatusBar:SetFrameLevel(self:GetFrameLevel())
    
    -- Border frame
    self.Border = CreateFrame("Frame", nil, self, "BackdropTemplate")
    self.Border:SetPoint("TOPLEFT", self, -1, 1)
    self.Border:SetPoint("BOTTOMRIGHT", self, 1, -1)
    self.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    self.Border:SetBackdropBorderColor(0, 0, 0, 1)
    
    -- Text frame (overlay for display values)
    self.TextFrame = CreateFrame("Frame", nil, self)
    self.TextFrame:SetAllPoints(self)
    self.TextFrame:SetFrameStrata("MEDIUM")
    self.TextFrame:SetFrameLevel(self:GetFrameLevel() + 2)
    
    self.TextValue = self.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.TextValue:SetPoint("CENTER", self.TextFrame, "CENTER", 0, 0)
    self.TextValue:SetJustifyH("CENTER")
    self.TextValue:SetText("0")
    
    -- Ticks array for segmented resources
    self.ticks = {}
    
    -- Cache for optimization
    self._cachedX = nil
    self._cachedY = nil
    self._cachedW = nil
    self._cachedH = nil
    self._cachedTex = nil
    self._cachedBorderSize = nil
    self._cachedTextX = nil
    self._cachedTextY = nil
    
    self:Hide()
end

-- Get current Edit Mode layout name
function BarMixin:GetLayout()
    local LEM = LibStub("LibEQOLEditMode-1.0", true)
    if LEM then
        return LEM.GetActiveLayoutName() or "Default"
    end
    return "Default"
end

-- Get point for positioning the bar
-- Returns: point, relativeTo, relativePoint, x, y
function BarMixin:GetPoint(layoutName)
    local helpers = ns.ResourceBars.helpers
    local db = self:GetDB(layoutName)
    
    -- If no layout data, use defaults
    if not db then
        return "CENTER", UIParent, "CENTER", 0, 0
    end
    
    -- Get values from DB with fallbacks
    local point = db.point or "CENTER"
    local relativePoint = db.relativePoint or "CENTER"
    local relativeFrameText = db.relativeTo or "UIParent"
    local resolvedRelativeFrame = helpers.resolveRelativeFrame(relativeFrameText)
    
    -- Cannot anchor to itself or create cyclic reference
    if self == resolvedRelativeFrame or self == select(2, resolvedRelativeFrame:GetPoint(1)) then
        resolvedRelativeFrame = UIParent
        db.relativeTo = "UIParent"
        print("|cFF00FFFFSuaviUI:|r Warning: Cyclic frame reference detected, using UIParent instead")
    end
    
    -- Clamp x/y to screen bounds
    local uiWidth, uiHeight = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
    local x = helpers.clamp(db.x or 0, uiWidth * -1, uiWidth)
    local y = helpers.clamp(db.y or 0, uiHeight * -1, uiHeight)
    
    return point, resolvedRelativeFrame, relativePoint, x, y
end

-- Get size for the bar
-- Returns: width, height (with scale applied)
function BarMixin:GetSize(layoutName, data)
    local helpers = ns.ResourceBars.helpers
    local db = data or self:GetDB(layoutName)
    
    -- If no layout data, use defaults
    if not db then
        return 326, 8  -- Default size
    end
    
    local width = db.width or 326
    local height = db.height or 8
    local scale = helpers.rounded(db.scale or 1, 2)
    
    -- Future: Handle widthMode sync (e.g., "Sync With Cooldowns")
    -- if db.widthMode and db.widthMode ~= "Manual" then
    --     width = self:GetCooldownManagerWidth(layoutName) or width
    --     if db.minWidth and db.minWidth > 0 then
    --         width = max(width, db.minWidth)
    --     end
    -- end
    
    return width * scale, height * scale
end

-- Apply layout settings from database
function BarMixin:ApplyLayout(layoutName, force)
    layoutName = layoutName or self:GetLayout()
    local db = self:GetDB(layoutName)
    if not db then return end
    
    -- Skip if hidden unless forced
    if not self:IsShown() and not force then return end
    
    -- Get size and position
    local width, height = self:GetSize(layoutName, db)
    local point, relativeTo, relativePoint, x, y = self:GetPoint(layoutName)
    
    -- Apply size and position
    self:SetSize(width, height)
    self:ClearAllPoints()
    self:SetPoint(point, relativeTo, relativePoint, x, y)
    
    -- Update drag enabled state based on relative frame (LibEQOL only supports dragging relative to UIParent)
    local LEM = LibStub("LibEQOLEditMode-1.0", true)
    if LEM and LEM.SetFrameDragEnabled then
        local dragEnabled = (relativeTo == UIParent)
        LEM:SetFrameDragEnabled(self, dragEnabled)
    end
    
    -- Apply appearance settings
    self:UpdateAppearance(layoutName)
end

-- Update bar appearance (colors, textures, text)
function BarMixin:UpdateAppearance(layoutName)
    layoutName = layoutName or self:GetLayout()
    local layout = self:GetDB(layoutName)
    if not layout then return end
    
    -- Update background color
    local bgColor = layout.bgColor or { 0.1, 0.1, 0.1, 0.8 }
    self.Background:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    
    -- Update border
    local borderSize = Scale(layout.borderSize or 1)
    self.Border:ClearAllPoints()
    self.Border:SetPoint("TOPLEFT", self, -borderSize, borderSize)
    self.Border:SetPoint("BOTTOMRIGHT", self, borderSize, -borderSize)
    self.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = borderSize,
    })
    self.Border:SetShown(borderSize > 0)
    
    -- Update texture
    local texName = layout.texture or "Solid"
    local tex = LSM:Fetch("statusbar", texName)
    self.StatusBar:SetStatusBarTexture(tex)
    
    -- Update text
    local textSize = layout.textSize or 12
    self.TextValue:SetFont(GameFontHighlightSmall:GetFont())
    self.TextValue:SetTextColor(1, 1, 1, 1)
    self.TextFrame:SetShown(layout.showText ~= false)
end

-- Get database for this bar
function BarMixin:GetDB(layoutName)
    layoutName = layoutName or self:GetLayout()
    local db = SUICore.db.profile.resourceBars
    if not db or not db[self.dbName] then return nil end
    
    -- Ensure layout exists - if not, copy from Default
    if not db[self.dbName][layoutName] then
        local defaults = db[self.dbName]["Default"]
        if defaults then
            db[self.dbName][layoutName] = CopyTable(defaults)
        else
            return nil
        end
    end
    
    return db[self.dbName][layoutName]
end

-- Show the bar
function BarMixin:ShowBar()
    self:Show()
end

-- Hide the bar
function BarMixin:HideBar()
    self:Hide()
end

ns.BarMixin = BarMixin
