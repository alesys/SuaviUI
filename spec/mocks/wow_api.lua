-- WoW API Mocks for unit testing
-- This file provides fake implementations of WoW functions

-- Basic globals
_G.ADDON_NAME = "SuaviUI"

-- Time
_G.GetTime = function() return 1000 end

-- UI Parent
_G.UIParent = {
    GetWidth = function() return 1920 end,
    GetHeight = function() return 1080 end,
}

-- Mock frame factory
local function CreateMockFrame(frameType, name, parent, template)
    local frame = {
        _type = frameType,
        _name = name,
        _parent = parent,
        _shown = false,
        _width = 100,
        _height = 25,
        _points = {},
        _scripts = {},
        _children = {},
        _level = 1,
        _strata = "MEDIUM",
    }
    
    -- Basic methods
    function frame:SetSize(w, h)
        self._width = w
        self._height = h
    end
    
    function frame:GetWidth() return self._width end
    function frame:GetHeight() return self._height end
    function frame:GetSize() return self._width, self._height end
    
    function frame:SetWidth(w) self._width = w end
    function frame:SetHeight(h) self._height = h end
    
    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        table.insert(self._points, {point, relativeTo, relativePoint, x, y})
    end
    
    function frame:ClearAllPoints()
        self._points = {}
    end
    
    function frame:SetAllPoints(relativeTo)
        self._points = {{"TOPLEFT", relativeTo or self._parent, "TOPLEFT", 0, 0}}
    end
    
    function frame:Show() self._shown = true end
    function frame:Hide() self._shown = false end
    function frame:IsShown() return self._shown end
    function frame:SetShown(show) self._shown = show end
    
    function frame:SetFrameLevel(level) self._level = level end
    function frame:GetFrameLevel() return self._level end
    function frame:SetFrameStrata(strata) self._strata = strata end
    function frame:GetFrameStrata() return self._strata end
    
    function frame:SetScript(scriptType, handler)
        self._scripts[scriptType] = handler
    end
    
    function frame:GetScript(scriptType)
        return self._scripts[scriptType]
    end
    
    function frame:SetParent(parent) self._parent = parent end
    function frame:GetParent() return self._parent end
    function frame:GetName() return self._name end
    
    -- StatusBar methods
    if frameType == "StatusBar" then
        frame._minValue = 0
        frame._maxValue = 1
        frame._value = 0
        frame._statusBarTexture = nil
        frame._reverseFill = false
        
        function frame:SetMinMaxValues(min, max)
            self._minValue = min
            self._maxValue = max
        end
        function frame:GetMinMaxValues() return self._minValue, self._maxValue end
        function frame:SetValue(val) self._value = val end
        function frame:GetValue() return self._value end
        function frame:SetStatusBarTexture(tex) self._statusBarTexture = tex end
        function frame:GetStatusBarTexture() return self._statusBarTexture end
        function frame:SetStatusBarColor(r, g, b, a) self._color = {r, g, b, a} end
        function frame:SetReverseFill(reverse) self._reverseFill = reverse end
    end
    
    -- Texture creation
    function frame:CreateTexture(name, layer, inherits, sublevel)
        local tex = {
            _layer = layer,
            SetTexture = function(self, path) self._path = path end,
            SetTexCoord = function() end,
            SetColorTexture = function(self, r, g, b, a) self._color = {r, g, b, a} end,
            SetVertexColor = function(self, r, g, b, a) self._color = {r, g, b, a} end,
            SetAllPoints = function() end,
            SetPoint = function() end,
            ClearAllPoints = function() end,
            Show = function() end,
            Hide = function() end,
        }
        return tex
    end
    
    -- FontString creation
    function frame:CreateFontString(name, layer, inherits)
        local fs = {
            _text = "",
            _shown = true,
            SetFont = function() end,
            SetText = function(self, text) self._text = text end,
            GetText = function(self) return self._text end,
            SetPoint = function() end,
            ClearAllPoints = function() end,
            SetJustifyH = function() end,
            SetJustifyV = function() end,
            Show = function(self) self._shown = true end,
            Hide = function(self) self._shown = false end,
            SetShown = function(self, show) self._shown = show end,
            IsShown = function(self) return self._shown end,
        }
        return fs
    end
    
    -- BackdropTemplate methods
    if template == "BackdropTemplate" then
        frame._backdrop = nil
        function frame:SetBackdrop(backdrop) self._backdrop = backdrop end
        function frame:GetBackdrop() return self._backdrop end
        function frame:SetBackdropColor(r, g, b, a) self._backdropColor = {r, g, b, a} end
        function frame:SetBackdropBorderColor(r, g, b, a) self._backdropBorderColor = {r, g, b, a} end
    end
    
    -- Register in _G if named
    if name then
        _G[name] = frame
    end
    
    return frame
end

_G.CreateFrame = CreateMockFrame

-- Unit info mocks
_G.UnitCastingInfo = function(unit) return nil end
_G.UnitChannelInfo = function(unit) return nil end
_G.UnitExists = function(unit) return unit == "player" or unit == "target" end
_G.UnitName = function(unit) return "TestUnit" end

-- LibStub mock
local libs = {}
_G.LibStub = function(name, silent)
    if libs[name] then
        return libs[name]
    end
    if silent then
        return nil
    end
    -- Return a minimal mock for common libs
    local mock = {}
    libs[name] = mock
    return mock
end

-- Allow registering mock libs
_G.LibStub.libs = libs
_G.LibStub.Register = function(name, lib)
    libs[name] = lib
end

-- String functions (WoW globals)
_G.strmatch = string.match
_G.strfind = string.find
_G.strsub = string.sub
_G.strlen = string.len
_G.strlower = string.lower
_G.strupper = string.upper
_G.format = string.format

-- Table functions
_G.tinsert = table.insert
_G.tremove = table.remove
_G.wipe = function(t)
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end

-- Math
_G.floor = math.floor
_G.ceil = math.ceil
_G.abs = math.abs
_G.min = math.min
_G.max = math.max

-- Secure hook
_G.hooksecurefunc = function(tbl, name, hook)
    if type(tbl) == "string" then
        -- Global function hook
        local orig = _G[tbl]
        _G[tbl] = function(...)
            local result = orig(...)
            hook(...)
            return result
        end
    else
        -- Table method hook
        local orig = tbl[name]
        tbl[name] = function(...)
            local result = orig(...)
            hook(...)
            return result
        end
    end
end

-- Print
_G.print = print

return _G
