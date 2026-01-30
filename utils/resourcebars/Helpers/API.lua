local addonName, SUICore = ...

local RB = SUICore.ResourceBars
local LEM = RB.LEM
local LibSerialize = RB.LibSerialize
local LibDeflate = RB.LibDeflate
local L = RB.L

local EXPORT_VERSION = 1
local DB_NAME = "SuaviUI_ResourceBars"

------------------------------------------------------------
-- BAR UPDATE FUNCTIONS
------------------------------------------------------------

RB.updateBar = function(name)
    local bar = RB.barInstances[name]
    if not bar then return end

    bar:ApplyLayout()
end

RB.updateBars = function()
    for name, _ in pairs(RB.barInstances or {}) do
        RB.updateBar(name)
    end
end

RB.fullUpdateBar = function(name)
    local bar = RB.barInstances[name]
    if not bar then return end

    bar:InitCooldownManagerWidthHook()
    bar:ApplyVisibilitySettings()
    bar:ApplyLayout()
    bar:UpdateDisplay()
end

RB.fullUpdateBars = function()
    for name, _ in pairs(RB.barInstances or {}) do
        RB.fullUpdateBar(name)
    end
end

------------------------------------------------------------
-- IMPORT/EXPORT
------------------------------------------------------------

RB.decodeImportString = function(importString)
    local prefix, version, encoded = importString:match("^([^:]+):(%d+):(.+)$")
    if prefix ~= DB_NAME then
        return nil, L["IMPORT_STRING_NOT_SUITABLE"] .. " " .. DB_NAME
    end
    if not version or version ~= tostring(EXPORT_VERSION) then
        return nil, L["IMPORT_STRING_OLDER_VERSION"] .. " " .. DB_NAME
    end
    if not encoded then
        return nil, L["IMPORT_STRING_INVALID"]
    end

    local compressed = LibDeflate:DecodeForPrint(encoded)
    if not compressed then
        return nil, L["IMPORT_DECODE_FAILED"]
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return nil, L["IMPORT_DECOMPRESSION_FAILED"]
    end

    local success, data = LibSerialize:Deserialize(serialized)
    if not success then
        return nil, L["IMPORT_DESERIALIZATION_FAILED"]
    end

    return data
end

RB.encodeDataAsString = function(data)
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
    local encoded = LibDeflate:EncodeForPrint(compressed)

    return DB_NAME .. ":" .. EXPORT_VERSION .. ":" .. encoded
end

RB.exportBarAsString = function(dbName)
    local data = {
        BARS = {},
    }

    local layoutName = LEM.GetActiveLayoutName() or "Default"
    if dbName
        and SuaviUI_ResourceBarsDB
        and SuaviUI_ResourceBarsDB[dbName]
        and SuaviUI_ResourceBarsDB[dbName][layoutName] then
        data.BARS[dbName] = SuaviUI_ResourceBarsDB[dbName][layoutName] or nil
    end

    return RB.encodeDataAsString(data)
end

RB.importBarAsString = function(importString, dbName)
    local data, errMsg = RB.decodeImportString(importString)
    if not data or errMsg then
        return nil, errMsg or "?"
    end

    if data.BARS[dbName] then
        if not SuaviUI_ResourceBarsDB then
            SuaviUI_ResourceBarsDB = {}
        end

        local layoutName = LEM.GetActiveLayoutName() or "Default"
        SuaviUI_ResourceBarsDB[dbName][layoutName] = data.BARS[dbName]
    end

    return data
end

RB.exportProfileAsString = function(includeBarSettings, includeAddonSettings, layoutNameToExport)
    local data = {
        BARS = {},
        GLOBAL = nil,
    }

    if includeBarSettings then
        local layoutName = layoutNameToExport or LEM.GetActiveLayoutName() or "Default"
        for _, barSettings in pairs(RB.RegisteredBar or {}) do
            if barSettings
                and barSettings.dbName
                and SuaviUI_ResourceBarsDB
                and SuaviUI_ResourceBarsDB[barSettings.dbName]
                and SuaviUI_ResourceBarsDB[barSettings.dbName][layoutName] then
                data.BARS[barSettings.dbName] = SuaviUI_ResourceBarsDB[barSettings.dbName][layoutName] or nil
            end
        end
    end

    if includeAddonSettings then
        if SuaviUI_ResourceBarsDB and SuaviUI_ResourceBarsDB["_Settings"] then
            data.GLOBAL = SuaviUI_ResourceBarsDB["_Settings"]
        end
    end

    return RB.encodeDataAsString(data)
end

RB.importProfileFromString = function(importString)
    local data, errMsg = RB.decodeImportString(importString)
    if not data or errMsg then
        return nil, errMsg or "?"
    end

    local layoutName = LEM.GetActiveLayoutName() or "Default"
    for dbName, barSettings in pairs(data.BARS or {}) do
        if not SuaviUI_ResourceBarsDB then
            SuaviUI_ResourceBarsDB = {}
        end

        if not SuaviUI_ResourceBarsDB[dbName] then
            SuaviUI_ResourceBarsDB[dbName] = {}
        end

        SuaviUI_ResourceBarsDB[dbName][layoutName] = barSettings
    end

    if data.GLOBAL then
        if not SuaviUI_ResourceBarsDB then
            SuaviUI_ResourceBarsDB = {}
        end

        SuaviUI_ResourceBarsDB["_Settings"] = data.GLOBAL
    end

    return data
end

RB.getAvailableProfiles = function()
    local profiles = {}

    if not SuaviUI_ResourceBarsDB then
        return profiles
    end

    for _, barSettings in pairs(RB.RegisteredBar or {}) do
        if barSettings and barSettings.dbName then
            local dbName = barSettings.dbName
            if SuaviUI_ResourceBarsDB[dbName] then
                for layoutName, _ in pairs(SuaviUI_ResourceBarsDB[dbName]) do
                    profiles[layoutName] = true
                end
            end
        end
    end

    local keyset = {}
    for k, _ in pairs(profiles) do
        keyset[#keyset + 1] = k
    end

    return keyset
end

RB.getCurrentProfileName = function()
    return LEM.GetActiveLayoutName() or "Default"
end

------------------------------------------------------------
-- UTILITY FUNCTIONS
------------------------------------------------------------

RB.prettyPrint = function(...)
    print("|cffA855F7SuaviUI ResourceBars:|r", ...)
end

RB.clamp = function(x, min, max)
    if x < min then
        return min
    elseif x > max then
        return max
    else
        return x
    end
end

RB.rounded = function(num, idp)
    if not num then return num end

    local mult = 10 ^ (idp or 0)
    return math.floor(num * mult + 0.5) / mult
end

RB.getPixelPerfectScale = function()
    local _, screenHeight = GetPhysicalScreenSize()
    local scale = UIParent:GetEffectiveScale()
    return 768 / screenHeight / scale
end
