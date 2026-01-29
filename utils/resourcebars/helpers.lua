--- Resource Bars Helper Functions
-- Utility functions for positioning, frame resolution, and calculations

local ADDON_NAME, ns = ...
local SUICore = ns.Addon

-- Create namespace for helpers
local helpers = {}
ns.ResourceBars = ns.ResourceBars or {}
ns.ResourceBars.helpers = helpers

-- Clamp a value between min and max
function helpers.clamp(x, min, max)
    if x < min then
        return min
    elseif x > max then
        return max
    else
        return x
    end
end

-- Round a number to specified decimal places
function helpers.rounded(num, idp)
    if not num then return num end
    
    local mult = 10^(idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

-- Get pixel-perfect scale for sharp rendering
function helpers.getPixelPerfectScale()
    local _, screenHeight = GetPhysicalScreenSize()
    local scale = UIParent:GetEffectiveScale()
    return 768 / screenHeight / scale
end

-- Resolve relative frame text name to actual frame object
-- Returns UIParent as fallback if frame not found or invalid
function helpers.resolveRelativeFrame(relativeFrameText)
    local tbl = {
        ["UIParent"] = UIParent,
        ["Health Bar"] = SUICore.bars and SUICore.bars.health,
        ["Primary Power Bar"] = SUICore.bars and SUICore.bars.primary,
        ["Secondary Power Bar"] = SUICore.bars and SUICore.bars.secondary,
        ["Tertiary Power Bar"] = SUICore.bars and SUICore.bars.tertiary,
        ["PlayerFrame"] = PlayerFrame,
        ["TargetFrame"] = TargetFrame,
        ["Essential Cooldowns"] = _G["EssentialCooldownViewer"],
        ["Utility Cooldowns"] = _G["UtilityCooldownViewer"],
        ["Tracked Buffs"] = _G["BuffIconCooldownViewer"],
        ["Action Bar"] = _G["MainMenuBar"],
        ["Action Bar 2"] = _G["MultiBarBottomLeft"],
        ["Action Bar 3"] = _G["MultiBarBottomRight"],
        ["Action Bar 4"] = _G["MultiBarRight"],
        ["Action Bar 5"] = _G["MultiBarLeft"],
        ["Action Bar 6"] = _G["MultiBar5"],
        ["Action Bar 7"] = _G["MultiBar6"],
        ["Action Bar 8"] = _G["MultiBar7"],
    }
    
    return tbl[relativeFrameText] or UIParent
end

-- Get available relative frame options for dropdown
-- Returns different lists based on which bar is being configured
function helpers.getAvailableRelativeFrames(barType)
    local frames = {
        { text = "UIParent" },
    }
    
    -- Add other resource bars based on which bar this is
    if barType == "health" then
        table.insert(frames, { text = "Primary Power Bar" })
        table.insert(frames, { text = "Secondary Power Bar" })
        table.insert(frames, { text = "Tertiary Power Bar" })
    elseif barType == "primary" then
        table.insert(frames, { text = "Health Bar" })
        table.insert(frames, { text = "Secondary Power Bar" })
        table.insert(frames, { text = "Tertiary Power Bar" })
    elseif barType == "secondary" then
        table.insert(frames, { text = "Health Bar" })
        table.insert(frames, { text = "Primary Power Bar" })
        table.insert(frames, { text = "Tertiary Power Bar" })
    elseif barType == "tertiary" then
        table.insert(frames, { text = "Health Bar" })
        table.insert(frames, { text = "Primary Power Bar" })
        table.insert(frames, { text = "Secondary Power Bar" })
    end
    
    -- Add standard WoW frames
    local additionalFrames = {
        { text = "PlayerFrame" },
        { text = "TargetFrame" },
        { text = "Essential Cooldowns" },
        { text = "Utility Cooldowns" },
        { text = "Tracked Buffs" },
        { text = "Action Bar" },
    }
    
    for _, frame in pairs(additionalFrames) do
        table.insert(frames, frame)
    end
    
    -- Add numbered action bars
    for i = 2, 8 do
        table.insert(frames, { text = "Action Bar " .. i })
    end
    
    return frames
end

-- Update a specific bar's layout
function helpers.updateBar(barKey)
    local bar = SUICore.bars[barKey]
    if not bar then return end
    
    bar:ApplyLayout()
end

-- Update all bars
function helpers.updateAllBars()
    for barKey, _ in pairs(SUICore.bars or {}) do
        helpers.updateBar(barKey)
    end
end

return helpers
