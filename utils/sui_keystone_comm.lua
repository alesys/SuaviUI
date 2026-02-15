local addonName, ns = ...

---------------------------------------------------------------------------
-- SUAVIUI KEYSTONE COMMUNICATION MODULE
-- Replaces LibOpenRaid for keystone sharing between party members
-- Uses AceComm-3.0 for inter-party messaging
---------------------------------------------------------------------------

local KeystoneComm = {}
local keystoneCache = {}  -- Cache of all received keystone data
local callbacks = {}      -- List of registered callbacks
local requestPending = false
local AceCommLib = nil    -- Will be set during initialization

---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------

local COMM_PREFIX = "SuaviUIKeystone"
local REQUEST_TIMEOUT = 5  -- seconds before retrying
local CACHE_TIMEOUT = 120  -- seconds before invalidating cache

---------------------------------------------------------------------------
-- INITIALIZE ACECOMM (must be early so handler functions can use it)
---------------------------------------------------------------------------

-- Get AceComm library
AceCommLib = LibStub and LibStub:GetLibrary("AceComm-3.0", true)
if not AceCommLib then
    print("|cFFFF0000SuaviUI Keystone Comm: AceComm-3.0 not found. Disabling.|r")
    return
end

-- Embed AceComm into our module
AceCommLib:Embed(KeystoneComm)

---------------------------------------------------------------------------
-- BLIZZARD API WRAPPERS
---------------------------------------------------------------------------

-- Get local player's current keystone information
local function GetPlayerKeystoneData()
    local keystoneData = {
        level = 0,
        mapID = nil,
        challengeMapID = nil,
        classID = select(3, UnitClass("player")),
        rating = 0,
        mythicPlusMapID = nil,
        specID = GetSpecialization() or 0,
        timestamp = GetTime(),
    }

    -- Try using C_ChallengeMode to detect active keystone
    local challengeID = C_ChallengeMode.GetActiveChallengeMapID()
    if challengeID and challengeID > 0 then
        -- We're in an active M+ dungeon
        keystoneData.challengeMapID = challengeID
        keystoneData.mapID = challengeID
        -- Get level from C_ChallengeMode
        local level = C_ChallengeMode.GetActiveKeystoneLevel()
        keystoneData.level = level or 0
        keystoneData.mythicPlusMapID = challengeID
    end

    -- Get M+ rating
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local ratingInfo = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
        if ratingInfo and ratingInfo.currentSeasonScore then
            keystoneData.rating = ratingInfo.currentSeasonScore or 0
        end
    end

    return keystoneData
end

---------------------------------------------------------------------------
-- COMMUNICATION HANDLERS
---------------------------------------------------------------------------

-- Format keystone data for transmission
local function SerializeKeystoneData(data)
    return string.format(
        "%d,%d,%d,%d,%d,%d,%d",
        data.level or 0,
        data.mapID or 0,
        data.challengeMapID or 0,
        data.classID or 0,
        data.rating or 0,
        data.mythicPlusMapID or 0,
        data.specID or 0
    )
end

-- Parse keystone data from transmission
local function DeserializeKeystoneData(dataString)
    local parts = {}
    for part in string.gmatch(dataString, "([^,]+)") do
        table.insert(parts, part)
    end
    
    return {
        level = tonumber(parts[1]) or 0,
        mapID = tonumber(parts[2]) or 0,
        challengeMapID = tonumber(parts[3]) or 0,
        classID = tonumber(parts[4]) or 0,
        rating = tonumber(parts[5]) or 0,
        mythicPlusMapID = tonumber(parts[6]) or 0,
        specID = tonumber(parts[7]) or 0,
        timestamp = GetTime(),
    }
end

-- Handle incoming request for keystone data
local function OnReceiveRequest(prefix, message, channel, sender)
    if message ~= "REQUEST" then return end
    if InCombatLockdown() then return end
    
    -- Send our keystone data back
    local myData = GetPlayerKeystoneData()
    local serialized = SerializeKeystoneData(myData)
    KeystoneComm:SendCommMessage(COMM_PREFIX, "DATA:" .. serialized, channel, sender)
end

-- Handle incoming keystone data
local function OnReceiveData(prefix, message, channel, sender)
    if not message:sub(1, 5) == "DATA:" then return end
    
    local dataString = message:sub(6)
    local keystoneData = DeserializeKeystoneData(dataString)
    
    -- Store in cache
    keystoneCache[sender] = keystoneData
    
    -- Trigger callbacks
    TriggerCallback("KeystoneUpdate", sender, keystoneData, keystoneCache)
end

-- Main comm handler
local function OnCommReceived(prefix, message, channel, sender)
    if prefix ~= COMM_PREFIX then return end
    
    if message == "REQUEST" then
        OnReceiveRequest(prefix, message, channel, sender)
    elseif message:sub(1, 5) == "DATA:" then
        OnReceiveData(prefix, message, channel, sender)
    end
end

---------------------------------------------------------------------------
-- CALLBACK SYSTEM (mimics LibOpenRaid interface)
---------------------------------------------------------------------------

function TriggerCallback(eventName, ...)
    if not callbacks[eventName] then return end
    
    for _, callback in ipairs(callbacks[eventName]) do
        pcall(callback, ...)
    end
end

function KeystoneComm.RegisterCallback(module, eventName, callback)
    if not callbacks[eventName] then
        callbacks[eventName] = {}
    end
    table.insert(callbacks[eventName], callback)
end

-- AceComm handler method (will be called by AceComm callbacks)
function KeystoneComm:OnCommReceived(prefix, message, channel, sender)
    OnCommReceived(prefix, message, channel, sender)
end

---------------------------------------------------------------------------
-- PUBLIC API (mimics LibOpenRaid interface)
---------------------------------------------------------------------------

-- Get keystones for all party members (from cache)
function KeystoneComm.GetAllKeystonesInfo()
    return keystoneCache
end

-- Get keystone info for a specific unit
function KeystoneComm.GetKeystoneInfo(unitId)
    if unitId == "player" then
        return GetPlayerKeystoneData()
    end
    
    -- Convert unitId to player name
    local unitName = UnitName(unitId)
    if unitName then
        return keystoneCache[unitName]
    end
    
    return nil
end

-- Request keystone data from party members
function KeystoneComm.RequestKeystoneDataFromParty()
    if InCombatLockdown() or not IsInGroup() then return end
    
    if requestPending then return end
    requestPending = true
    
    -- Send request to party
    KeystoneComm:SendCommMessage(COMM_PREFIX, "REQUEST", "PARTY")
    
    -- Set timeout to clear pending flag
    C_Timer.After(REQUEST_TIMEOUT, function()
        requestPending = false
        -- Trigger update with whatever we have cached
        TriggerCallback("KeystoneUpdate", UnitName("player"), GetPlayerKeystoneData(), keystoneCache)
    end)
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------

-- Get AceComm library
local AceComm = LibStub and LibStub:GetLibrary("AceComm-3.0", true)
if not AceComm then
    print("|cFFFF0000SuaviUI Keystone Comm: AceComm-3.0 not found. Disabling.|r")
    return
end

-- Embed AceComm into our module
AceCommLib:Embed(KeystoneComm)

-- Register communication handler
KeystoneComm:RegisterComm(COMM_PREFIX, "OnCommReceived")

-- Send initial data when entering a group
local groupChangeTimer = nil
local function OnGroupChange()
    if groupChangeTimer then
        groupChangeTimer:Cancel()
    end
    
    groupChangeTimer = C_Timer.NewTimer(2, function()
        if IsInGroup() and not InCombatLockdown() then
            KeystoneComm.RequestKeystoneDataFromParty()
        end
        groupChangeTimer = nil
    end)
end

-- Send initial keystone data on login
local loginTimer = nil
C_Timer.After(3, function()
    if not InCombatLockdown() then
        -- Update our own cache entry immediately
        keystoneCache[UnitName("player")] = GetPlayerKeystoneData()
        
        -- Request data from party if in group
        if IsInGroup() then
            KeystoneComm.RequestKeystoneDataFromParty()
        end
    else
        loginTimer = C_Timer.NewTimer(1, function() OnGroupChange() end)
    end
end)

-- Register for group events
local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" then
        OnGroupChange()
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(3, function()
            if IsInGroup() and not InCombatLockdown() then
                KeystoneComm.RequestKeystoneDataFromParty()
            end
        end)
    end
end)

-- Sync keystone when it changes during gameplay
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")

-- Update our cache and notify if in group
local syncTimer = nil
local function OnKeystoneChange()
    keystoneCache[UnitName("player")] = GetPlayerKeystoneData()
    
    if IsInGroup() and not InCombatLockdown() then
        if syncTimer then syncTimer:Cancel() end
        syncTimer = C_Timer.NewTimer(0.5, function()
            KeystoneComm.RequestKeystoneDataFromParty()
            syncTimer = nil
        end)
    end
end

frame:HookScript("OnEvent", function(self, event, ...)
    if event == "ZONE_CHANGED_NEW_AREA" or 
       event == "CHALLENGE_MODE_START" or 
       event == "CHALLENGE_MODE_COMPLETED" then
        OnKeystoneChange()
    end
end)

_G.SuaviUIKeystoneComm = KeystoneComm
ns.KeystoneComm = KeystoneComm

return KeystoneComm
