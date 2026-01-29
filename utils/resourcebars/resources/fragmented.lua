--- SuaviUI Fragmented Power Display
-- Handles segmented resources like runes with individual cooldown timers

local ADDON_NAME, ns = ...
local SUICore = ns.Addon
local LSM = LibStub("LibSharedMedia-3.0")

local function Scale(x)
    if SUICore and SUICore.Scale then
        return SUICore:Scale(x)
    end
    return x
end

local tickedPowerTypes = {
    [Enum.PowerType.ArcaneCharges] = true,
    [Enum.PowerType.Chi] = true,
    [Enum.PowerType.ComboPoints] = true,
    [Enum.PowerType.Essence] = true,
    [Enum.PowerType.HolyPower] = true,
    [Enum.PowerType.Runes] = true,
    [Enum.PowerType.SoulShards] = true,
}

local fragmentedPowerTypes = {
    [Enum.PowerType.Runes] = true,
}

-- Get secondary resource value (handles fragmented display)
function SUICore:GetSecondaryResourceValue(resource)
    if not resource then return nil, nil, nil, nil end

    if resource == "STAGGER" then
        local stagger = UnitStagger("player") or 0
        local maxHealth = UnitHealthMax("player") or 1
        local staggerPercent = (stagger / maxHealth) * 100
        return 100, staggerPercent, staggerPercent, "percent"
    end

    if resource == "SOUL" then
        local soulBar = _G["DemonHunterSoulFragmentsBar"]
        if not soulBar then return nil, nil, nil, nil end
        
        if not soulBar:IsShown() then
            soulBar:Show()
            soulBar:SetAlpha(0)
        end

        local current = soulBar:GetValue()
        local _, max = soulBar:GetMinMaxValues()

        return max, current, current, "number"
    end

    if resource == Enum.PowerType.Runes then
        local current = 0
        local max = UnitPowerMax("player", resource)
        if max <= 0 then return nil, nil, nil, nil end

        for i = 1, max do
            local runeReady = select(3, GetRuneCooldown(i))
            if runeReady then
                current = current + 1
            end
        end

        return max, current, current, "number"
    end

    if resource == Enum.PowerType.SoulShards then
        local _, class = UnitClass("player")
        if class == "WARLOCK" then
            local spec = GetSpecialization()

            if spec == 3 then
                local fragments = UnitPower("player", resource, true)
                local maxFragments = UnitPowerMax("player", resource, true)
                if maxFragments <= 0 then return nil, nil, nil, nil end

                return maxFragments, fragments, fragments / 10, "shards"
            end
        end

        local current = UnitPower("player", resource)
        local max = UnitPowerMax("player", resource)
        if max <= 0 then return nil, nil, nil, nil end

        return max, current, current, "number"
    end

    local current = UnitPower("player", resource)
    local max = UnitPowerMax("player", resource)
    if max <= 0 then return nil, nil, nil, nil end

    return max, current, current, "number"
end

-- Create fragmented power bars (one per segment)
function SUICore:EnsureFragmentedPowerBars(bar, count)
    if not bar.FragmentedPowerBars then
        bar.FragmentedPowerBars = {}
        bar.FragmentedPowerBarTexts = {}
    end

    for i = 1, count do
        if not bar.FragmentedPowerBars[i] then
            local fragBar = CreateFrame("StatusBar", nil, bar)
            fragBar:SetFrameLevel(bar:GetFrameLevel() + 1)
            bar.FragmentedPowerBars[i] = fragBar

            local text = bar:CreateFontString(nil, "OVERLAY")
            text:SetJustifyH("CENTER")
            bar.FragmentedPowerBarTexts[i] = text
        end
    end
end

-- Update fragmented power display (runes with individual timers)
function SUICore:UpdateFragmentedPowerDisplay(bar, resource, isVertical)
    local cfg = self.db.profile.resourceBars.secondaryPowerBar[self:GetCurrentLayout()]
    local maxPower = UnitPowerMax("player", resource)
    if maxPower <= 0 then return end

    local barWidth = bar:GetWidth()
    local barHeight = bar:GetHeight()

    local fragmentedBarWidth, fragmentedBarHeight
    if isVertical then
        fragmentedBarHeight = barHeight / maxPower
        fragmentedBarWidth = barWidth
    else
        fragmentedBarWidth = barWidth / maxPower
        fragmentedBarHeight = barHeight
    end
    
    bar.StatusBar:SetAlpha(0)

    local tex = LSM:Fetch("statusbar", "Solid")
    for i = 1, maxPower do
        if bar.FragmentedPowerBars[i] then
            bar.FragmentedPowerBars[i]:SetStatusBarTexture(tex)
        end
    end

    local color

    if cfg.usePowerColor then
        color = self:GetResourceColor(resource)
    elseif cfg.useClassColor then
        local _, class = UnitClass("player")
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            color = { r = classColor.r, g = classColor.g, b = classColor.b }
        else
            color = self:GetResourceColor(resource)
        end
    elseif cfg.useCustomColor and cfg.customColor then
        local c = cfg.customColor
        color = { r = c[1], g = c[2], b = c[3], a = c[4] or 1 }
    else
        color = self:GetResourceColor(resource)
    end

    if resource == Enum.PowerType.Runes then
        local readyList = {}
        local cdList = {}
        local now = GetTime()
        
        for i = 1, maxPower do
            local start, duration, runeReady = GetRuneCooldown(i)
            if runeReady then
                table.insert(readyList, { index = i })
            else
                if start and duration and duration > 0 then
                    local elapsed = now - start
                    local remaining = math.max(0, duration - elapsed)
                    local frac = math.max(0, math.min(1, elapsed / duration))
                    table.insert(cdList, { index = i, remaining = remaining, frac = frac })
                else
                    table.insert(cdList, { index = i, remaining = math.huge, frac = 0 })
                end
            end
        end

        table.sort(cdList, function(a, b) return a.remaining < b.remaining end)

        local displayOrder = {}
        for _, v in ipairs(readyList) do
            table.insert(displayOrder, { index = v.index, ready = true })
        end
        for _, v in ipairs(cdList) do
            table.insert(displayOrder, { index = v.index, ready = false, remaining = v.remaining, frac = v.frac })
        end

        for pos = 1, #displayOrder do
            local data = displayOrder[pos]
            local runeFrame = bar.FragmentedPowerBars[data.index]
            local runeText = bar.FragmentedPowerBarTexts[data.index]

            if runeFrame then
                runeFrame:ClearAllPoints()
                runeFrame:SetSize(fragmentedBarWidth, fragmentedBarHeight)
                if isVertical then
                    runeFrame:SetPoint("BOTTOM", bar, "BOTTOM", 0, (pos - 1) * fragmentedBarHeight)
                else
                    runeFrame:SetPoint("LEFT", bar, "LEFT", (pos - 1) * fragmentedBarWidth, 0)
                end

                if runeText then
                    runeText:ClearAllPoints()
                    runeText:SetPoint("CENTER", runeFrame, "CENTER", 0, 0)
                    runeText:SetFont(GameFontHighlightSmall:GetFont())
                end

                if data.ready then
                    runeFrame:SetMinMaxValues(0, 1)
                    runeFrame:SetValue(1)
                    runeText:SetText("")
                    runeFrame:SetStatusBarColor(color.r, color.g, color.b)
                else
                    runeFrame:SetMinMaxValues(0, 1)
                    runeFrame:SetValue(data.frac)
                    
                    if cfg.showFragmentedPowerBarText ~= false then
                        runeText:SetText(string.format("%.1f", math.max(0, data.remaining)))
                    else
                        runeText:SetText("")
                    end
                    
                    runeFrame:SetStatusBarColor(color.r * 0.5, color.g * 0.5, color.b * 0.5)
                end

                runeFrame:Show()
            end
        end

        for i = maxPower + 1, #bar.FragmentedPowerBars do
            if bar.FragmentedPowerBars[i] then
                bar.FragmentedPowerBars[i]:Hide()
                if bar.FragmentedPowerBarTexts[i] then
                    bar.FragmentedPowerBarTexts[i]:SetText("")
                end
            end
        end
    end
end

ns.FragmentedPower = {
    tickedPowerTypes = tickedPowerTypes,
    fragmentedPowerTypes = fragmentedPowerTypes,
}
