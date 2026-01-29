--- SuaviUI Secondary Power Bar
-- Displays secondary resources (Combo Points, Holy Power, Chi, Runes with timers, etc.)

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local CDMAlignedMixin = ns.CDMAlignedMixin
local FragmentedPower = ns.FragmentedPower

local SecondaryPowerBar = CreateFromMixins(CDMAlignedMixin)

local runeUpdateElapsed = 0
local runeUpdateRunning = false

function SecondaryPowerBar:Initialize()
    -- Initialize through mixin chain properly
    self:OnLoad({
        barKey = "secondary",
        dbName = "secondaryPowerBar",
    })
    self.lastUpdate = 0
    self.currentResource = nil
    self.currentMax = 0
    self.currentValue = 0
    self:RegisterPowerEvents()
end

function SecondaryPowerBar:UpdatePower()
    if not self:GetDB() or not self:GetDB().enabled then
        self:Hide()
        return
    end
    
    -- Apply layout settings (position, size, textures, colors)
    self:ApplyLayout()
    if not self.currentResource then
        self:Hide()
        return
    end
    
    local max, current, displayValue, valueType = self:GetResourceValue(self.currentResource)
    if not max or max <= 0 then
        self:Hide()
        return
    end
    
    self.currentMax = max
    self.currentValue = current
    
    -- Check if fragmented display
    if FragmentedPower.fragmentedPowerTypes[self.currentResource] then
        self:EnsureFragmentedPowerBars(max)
        self:UpdateFragmentedDisplay()
    else
        -- Standard bar display
        self.StatusBar:SetMinMaxValues(0, max)
        self.StatusBar:SetValue(current)
        self.StatusBar:SetAlpha(1)
        
        -- Update color
        local cfg = self:GetDB()
        if cfg.usePowerColor then
            local color = SUICore:GetResourceColor(self.currentResource)
            self.StatusBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 1)
        elseif cfg.useClassColor then
            local _, class = UnitClass("player")
            local classColor = RAID_CLASS_COLORS[class]
            if classColor then
                self.StatusBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
            end
        elseif cfg.useCustomColor and cfg.customColor then
            local c = cfg.customColor
            self.StatusBar:SetStatusBarColor(c[1], c[2], c[3], c[4] or 1)
        end
        
        -- Update text
        if cfg.showText ~= false then
            if valueType == "percent" then
                self.TextValue:SetText(string.format("%.0f%%", displayValue))
            elseif valueType == "shards" then
                self.TextValue:SetText(string.format("%.1f", displayValue))
            else
                self.TextValue:SetText(tostring(displayValue))
            end
        end
    end
    
    -- Apply CDM layout
    self:ApplyCDMLayout()
    
    self:Show()
end

function SecondaryPowerBar:UpdateFragmentedDisplay()
    local cfg = self:GetDB()
    local resource = self.currentResource
    local orientation = self:GetOrientation()
    local isVertical = (orientation == "VERTICAL")
    
    SUICore:UpdateFragmentedPowerDisplay(self, resource, isVertical)
    
    -- Handle rune timer updates
    if resource == Enum.PowerType.Runes then
        if not runeUpdateRunning then
            runeUpdateRunning = true
            runeUpdateElapsed = 0
            self:SetScript("OnUpdate", function(frame, delta)
                frame:OnRuneTimerUpdate(delta)
            end)
        end
    end
end

function SecondaryPowerBar:OnRuneTimerUpdate(delta)
    runeUpdateElapsed = runeUpdateElapsed + delta
    if runeUpdateElapsed < 0.05 then return end
    runeUpdateElapsed = 0

    local now = GetTime()
    local anyOnCooldown = false

    for i = 1, 6 do
        local runeFrame = self.FragmentedPowerBars and self.FragmentedPowerBars[i]
        local runeText = self.FragmentedPowerBarTexts and self.FragmentedPowerBarTexts[i]
        if runeFrame and runeFrame:IsShown() then
            local start, duration, runeReady = GetRuneCooldown(i)
            if not runeReady and start and duration and duration > 0 then
                anyOnCooldown = true
                local remaining = math.max(0, duration - (now - start))
                local frac = math.max(0, math.min(1, (now - start) / duration))
                runeFrame:SetValue(frac)
                if runeText then
                    local cfg = self:GetDB()
                    if cfg.showFragmentedPowerBarText ~= false then
                        runeText:SetText(string.format("%.1f", remaining))
                    else
                        runeText:SetText("")
                    end
                end
            end
        end
    end

    if not anyOnCooldown then
        self:SetScript("OnUpdate", nil)
        runeUpdateRunning = false
    end
end

function SecondaryPowerBar:EnsureFragmentedPowerBars(count)
    SUICore:EnsureFragmentedPowerBars(self, count)
end

function SecondaryPowerBar:Create()
    local frame = CreateFrame("Frame", ADDON_NAME .. "SecondaryPowerBar", UIParent)
    Mixin(frame, SecondaryPowerBar)
    return frame
end

ns.SecondaryPowerBar = SecondaryPowerBar
