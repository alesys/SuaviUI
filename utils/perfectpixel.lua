--- SuaviUI Perfect Pixel System
--- Provides pixel-perfect UI scaling and calculations

local ADDON_NAME, ns = ...

-- Get SUICore - must load after suicore_main.lua
local SUICore = ns.Addon or (SuaviUI and SuaviUI.SUICore)

if not SUICore then
    print("|cFFFF0000[SuaviUI] ERROR: perfectpixel.lua loaded before suicore_main.lua!|r")
    return
end

local min, max, format = min, max, string.format

local _G = _G
local UIParent = UIParent
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local InCombatLockdown = InCombatLockdown
local GetPhysicalScreenSize = GetPhysicalScreenSize

-- Refresh global FX scenes (prevents taint from RefreshModelScene)
function SUICore:RefreshGlobalFX()
    if _G.GlobalFXDialogModelScene then
        _G.GlobalFXDialogModelScene:Hide()
        _G.GlobalFXDialogModelScene:Show()
    end

    if _G.GlobalFXMediumModelScene then
        _G.GlobalFXMediumModelScene:Hide()
        _G.GlobalFXMediumModelScene:Show()
    end

    if _G.GlobalFXBackgroundModelScene then
        _G.GlobalFXBackgroundModelScene:Hide()
        _G.GlobalFXBackgroundModelScene:Show()
    end
end

-- Check for Eyefinity (triple monitor) setup
function SUICore:IsEyefinity(width, height)
    if SUICore.db and SUICore.db.profile.general.eyefinity and width >= 3840 then
        -- HQ resolution
        if width >= 9840 then return 3280 end                   -- WQSXGA
        if width >= 7680 and width < 9840 then return 2560 end  -- WQXGA
        if width >= 5760 and width < 7680 then return 1920 end  -- WUXGA & HDTV
        if width >= 5040 and width < 5760 then return 1680 end  -- WSXGA+

        -- Adding height condition for bezel compensation
        if width >= 4800 and width < 5760 and height == 900 then return 1600 end -- UXGA & HD+

        -- Low resolution screen
        if width >= 4320 and width < 4800 then return 1440 end  -- WSXGA
        if width >= 4080 and width < 4320 then return 1360 end  -- WXGA
        if width >= 3840 and width < 4080 then return 1224 end  -- SXGA & SXGA (UVGA) & WXGA & HDTV
    end
end

-- Check for Ultrawide setup
function SUICore:IsUltrawide(width, height)
    if SUICore.db and SUICore.db.profile.general.ultrawide and width >= 2560 then
        -- HQ Resolution
        if width >= 3440 and (height == 1440 or height == 1600) then return 2560 end -- DQHD, DQHD+, WQHD & WQHD+

        -- Low resolution
        if width >= 2560 and (height == 1080 or height == 1200) then return 1920 end -- WFHD, DFHD & WUXGA
    end
end

-- Calculate the UI multiplier for pixel snapping
function SUICore:UIMult()
    local uiScale = 1.0
    if SUICore.db and SUICore.db.profile and SUICore.db.profile.general then
        uiScale = SUICore.db.profile.general.uiScale or 1.0
    end
    -- Ensure perfect is initialized (can be nil if profile changes before pixel init)
    if not SUICore.perfect then
        local _, screenHeight = GetPhysicalScreenSize()
        if screenHeight and screenHeight > 0 then
            SUICore.perfect = 768 / screenHeight
        else
            SUICore.perfect = 1.0
        end
    end
    SUICore.mult = SUICore.perfect / uiScale
end

-- Apply UI scale to UIParent
function SUICore:UIScale()
    if InCombatLockdown() then
        -- Defer scale change until out of combat
        if not self._UIScalePending then
            self._UIScalePending = true
            self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                self._UIScalePending = nil
                self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                self:UIScale()
            end)
        end
    else
        local uiScale = 1.0
        if SUICore.db and SUICore.db.profile and SUICore.db.profile.general then
            uiScale = SUICore.db.profile.general.uiScale or 1.0
        end

        -- Use pcall to catch protected states not detected by InCombatLockdown
        local success = pcall(function() UIParent:SetScale(uiScale) end)
        if not success then
            -- Protected state detected - defer to combat end
            if not self._UIScalePending then
                self._UIScalePending = true
                self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                    self._UIScalePending = nil
                    self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                    self:UIScale()
                end)
            end
            return
        end

        SUICore.uiscale = UIParent:GetScale()
        SUICore.screenWidth, SUICore.screenHeight = GetScreenWidth(), GetScreenHeight()

        local width, height = SUICore.physicalWidth, SUICore.physicalHeight
        SUICore.eyefinity = SUICore:IsEyefinity(width, height)
        SUICore.ultrawide = SUICore:IsUltrawide(width, height)

        local newWidth = SUICore.eyefinity or SUICore.ultrawide
        if newWidth then
            -- Center UIParent for multi-monitor setups
            width, height = newWidth / (height / SUICore.screenHeight), SUICore.screenHeight
        else
            width, height = SUICore.screenWidth, SUICore.screenHeight
        end

        -- Refresh GlobalFX if in Retail
        if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and _G.GlobalFXDialogModelScene then
            SUICore:RefreshGlobalFX()
        end
    end
end

-- Get the best pixel size for current setup
function SUICore:PixelBestSize()
    return max(0.4, min(1.15, SUICore.perfect))
end

-- Handle UI scale changes
function SUICore:PixelScaleChanged(event)
    if event == 'UI_SCALE_CHANGED' then
        SUICore.physicalWidth, SUICore.physicalHeight = GetPhysicalScreenSize()
        SUICore.resolution = format('%dx%d', SUICore.physicalWidth, SUICore.physicalHeight)
        SUICore.perfect = 768 / SUICore.physicalHeight
    end

    SUICore:UIMult()
    SUICore:UIScale()
end

-- Scale a value to align with physical pixels
-- This is the core pixel-perfect function
function SUICore:Scale(x)
    local m = SUICore.mult
    if m == 1 or x == 0 then
        return x
    else
        local y = m > 1 and m or -m
        return x - x % (x < 0 and y or -y)
    end
end

-- Initialize the pixel perfect system
function SUICore:InitializePixelPerfect()
    -- Initialize physical screen size and perfect scale
    self.physicalWidth, self.physicalHeight = GetPhysicalScreenSize()
    self.resolution = format('%dx%d', self.physicalWidth, self.physicalHeight)
    self.perfect = 768 / self.physicalHeight
    
    -- Initialize multiplier (will be 1.0 until db is ready)
    self.mult = 1.0
    
    -- Calculate initial multiplier if db is ready
    if self.db and self.db.profile then
        self:UIMult()
    end
    
    -- Register for UI scale changes
    self:RegisterEvent('UI_SCALE_CHANGED', 'PixelScaleChanged')
end

-- Get smart default scale based on screen resolution (Option 3)
function SUICore:GetSmartDefaultScale()
    local _, screenHeight = GetPhysicalScreenSize()
    
    if screenHeight >= 2160 then      -- 4K
        return 0.53
    elseif screenHeight >= 1440 then  -- 1440p
        return 0.64
    else                              -- 1080p or lower
        return 1.0
    end
end

-- Apply saved UI scale (call this after db is initialized)
function SUICore:ApplyUIScale()
    if self.db and self.db.profile and self.db.profile.general then
        local savedScale = self.db.profile.general.uiScale
        local scaleToApply
        if savedScale and savedScale > 0 then
            scaleToApply = savedScale
        else
            -- No saved scale - use smart default based on resolution
            scaleToApply = self:GetSmartDefaultScale()
            self.db.profile.general.uiScale = scaleToApply
        end

        -- Use pcall to catch protected states not detected by InCombatLockdown
        if InCombatLockdown() then
            -- Defer to combat end
            if not self._UIScalePending then
                self._UIScalePending = true
                self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                    self._UIScalePending = nil
                    self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                    self:ApplyUIScale()
                end)
            end
            return
        end

        local success = pcall(function() UIParent:SetScale(scaleToApply) end)
        if not success then
            -- Protected state detected - defer to combat end
            if not self._UIScalePending then
                self._UIScalePending = true
                self:RegisterEvent('PLAYER_REGEN_ENABLED', function()
                    self._UIScalePending = nil
                    self:UnregisterEvent('PLAYER_REGEN_ENABLED')
                    self:ApplyUIScale()
                end)
            end
            return
        end
    end

    -- Update pixel perfect calculations
    if self.UIMult and self.UIScale then
        self:UIMult()
        self:UIScale()
    end
end






