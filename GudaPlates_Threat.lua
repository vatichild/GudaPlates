-- =============================================================================
-- GudaPlates_Threat.lua
-- =============================================================================
-- Threat and Tank Mode Module
-- Handles TWThreat addon integration and Tank Mode sharing between players
--
-- Exports:
--   GudaPlates_Threat.GetTWTankModeThreat(mobGUID, mobName) - Get tank mode threat for mob
--   GudaPlates_Threat.GetGPThreatData() - Get player threat data
--   GudaPlates_Threat.IsPlayerTank(playerName) - Check if player has tank mode
--   GudaPlates_Threat.BroadcastTankMode(force) - Broadcast tank mode to group
--   GudaPlates_Threat.IsInPlayerGroup(unit) - Check if unit is in player's group
--   GudaPlates_Threat.GP_TankModeThreats - Tank mode threat data table
--   GudaPlates_Threat.GP_Threats - Player threat data table
--   GudaPlates_Threat.GP_TankPlayers - Tank players table
-- =============================================================================

GudaPlates_Threat = {}

-- Local references for performance
local string_find = string.find
local string_sub = string.sub
local string_format = string.format
local string_gfind = string.gfind
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local GetTime = GetTime
local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitInRaid = UnitInRaid
local UnitInParty = UnitInParty
local SendAddonMessage = SendAddonMessage

-- Debug flag (set via GudaPlates.DEBUG_THREAT)
local DEBUG_THREAT = false
local debugThreatThrottle = 0

-- =============================================================================
-- Data Tables
-- =============================================================================

local GP_TankModeThreats = {}  -- Tank mode threat data (from TMTv1= messages)
local GP_Threats = {}          -- Player threat data (from TWTv4= messages)
local GP_TankPlayers = {}      -- Players who have Tank Mode enabled

-- Expose tables
GudaPlates_Threat.GP_TankModeThreats = GP_TankModeThreats
GudaPlates_Threat.GP_Threats = GP_Threats
GudaPlates_Threat.GP_TankPlayers = GP_TankPlayers

-- =============================================================================
-- Utility Functions
-- =============================================================================

-- Simple string split function
local function GP_Split(str, delimiter)
    local result = {}
    local pattern = "([^" .. delimiter .. "]+)"
    for match in string_gfind(str, pattern) do
        table.insert(result, match)
    end
    return result
end

-- Print helper (uses GudaPlates.Print if available)
local function Print(msg)
    if GudaPlates and GudaPlates.Print then
        GudaPlates.Print(msg)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00GudaPlates:|r " .. tostring(msg))
    end
end

-- =============================================================================
-- TWThreat Packet Handling
-- =============================================================================

-- Parse TWThreat tank mode packet (TMTv1=)
local function GP_HandleTankModePacket(packet)
    local startPos = string_find(packet, "TMTv1=")
    if not startPos then return end

    local dataStr = string_sub(packet, startPos + 6)  -- Skip "TMTv1="

    -- Clear old data
    for k in pairs(GP_TankModeThreats) do
        GP_TankModeThreats[k] = nil
    end

    -- Parse each entry (creature:guid:name:perc)
    local entries = GP_Split(dataStr, ";")
    for _, entry in ipairs(entries) do
        local parts = GP_Split(entry, ":")
        if parts[1] and parts[2] and parts[3] and parts[4] then
            local creature = parts[1]
            local guid = parts[2]
            local name = parts[3]
            local perc = tonumber(parts[4]) or 0

            GP_TankModeThreats[guid] = {
                creature = creature,
                name = name,
                perc = perc
            }

            if DEBUG_THREAT then
                Print(string_format("[GP_TankMode] %s: guid=%s, holder=%s, perc=%d",
                    creature, guid, name, perc))
            end
        end
    end
end

-- Parse TWThreat player threat packet (TWTv4=)
local function GP_HandleThreatPacket(packet)
    local startPos = string_find(packet, "TWTv4=")
    if not startPos then return end

    local dataStr = string_sub(packet, startPos + 6)  -- Skip "TWTv4="

    -- Clear old data
    for k in pairs(GP_Threats) do
        GP_Threats[k] = nil
    end

    -- Parse each entry (name:class:threat:perc:melee:tank)
    local entries = GP_Split(dataStr, ";")
    for _, entry in ipairs(entries) do
        local parts = GP_Split(entry, ":")
        if parts[1] and parts[3] and parts[4] then
            local name = parts[1]
            local threat = tonumber(parts[3]) or 0
            local perc = tonumber(parts[4]) or 0
            local tank = (parts[6] == "1")

            GP_Threats[name] = {
                threat = threat,
                perc = perc,
                tank = tank
            }

            if DEBUG_THREAT then
                Print(string_format("[GP_Threat] %s: threat=%d, perc=%d, tank=%s",
                    name, threat, perc, tostring(tank)))
            end
        end
    end
end

-- =============================================================================
-- Tank Mode Sharing Between Players
-- =============================================================================

local GP_ADDON_PREFIX = "GudaPlates"
local TANK_BROADCAST_DEBOUNCE = 5
local lastTankBroadcast = 0

-- Broadcast our Tank Mode setting to group
function GudaPlates_Threat.BroadcastTankMode(force)
    local now = GetTime()

    -- Debounce check
    if not force and (now - lastTankBroadcast) < TANK_BROADCAST_DEBOUNCE then
        if DEBUG_THREAT then
            Print(string_format("[TankMode] Broadcast debounced (%.1fs remaining)",
                TANK_BROADCAST_DEBOUNCE - (now - lastTankBroadcast)))
        end
        return
    end

    -- Get player role from GudaPlates
    local playerRole = GudaPlates and GudaPlates.playerRole
    local isTank = (playerRole == "TANK")
    local msg = isTank and "TM=1" or "TM=0"

    -- Track ourselves
    local myName = UnitName("player")
    if myName then
        GP_TankPlayers[myName] = isTank or nil
    end

    if UnitInRaid("player") then
        SendAddonMessage(GP_ADDON_PREFIX, msg, "RAID")
        lastTankBroadcast = now
    elseif UnitInParty() then
        SendAddonMessage(GP_ADDON_PREFIX, msg, "PARTY")
        lastTankBroadcast = now
    end

    if DEBUG_THREAT then
        Print(string_format("[TankMode] Broadcast: %s, myTank=%s", msg, tostring(isTank)))
    end
end

-- Check if a player has Tank Mode enabled
function GudaPlates_Threat.IsPlayerTank(playerName)
    if not playerName then return false end
    return GP_TankPlayers[playerName] == true
end

-- Handle incoming Tank Mode messages
local function GP_HandleTankModeMessage(sender, msg)
    if string_find(msg, "TM=") then
        local isTank = string_sub(msg, 4, 4) == "1"
        GP_TankPlayers[sender] = isTank or nil
        if DEBUG_THREAT then
            Print(string_format("[TankMode] Received from %s: tank=%s", sender, tostring(isTank)))
        end
    end
end

-- =============================================================================
-- Threat Data Accessors
-- =============================================================================

-- Get Tank Mode threat data for a specific mob
-- Returns: hasData, playerHasAggro, otherPlayerName, otherPlayerPct
function GudaPlates_Threat.GetTWTankModeThreat(mobGUID, mobName)
    local playerName = UnitName("player")

    -- Debug output
    if DEBUG_THREAT then
        local now = GetTime()
        if now - debugThreatThrottle > 1 then
            debugThreatThrottle = now
            local count = 0
            for guid, data in pairs(GP_TankModeThreats) do
                count = count + 1
                Print(string_format("[TankMode] GUID=%s creature=%s player=%s perc=%s",
                    tostring(guid), tostring(data.creature), tostring(data.name), tostring(data.perc)))
            end
            if count == 0 then
                Print("[TankMode] No entries (is Tank Mode enabled in TWThreat? Are you in combat?)")
            end
        end
    end

    -- Look for this mob by GUID
    if mobGUID then
        local data = GP_TankModeThreats[mobGUID]
        if data then
            local playerHasAggro = (data.name == playerName)
            return true, playerHasAggro, data.name, data.perc or 0
        end
    end

    -- Fallback: search by creature name
    if mobName then
        for guid, data in pairs(GP_TankModeThreats) do
            if data.creature == mobName then
                local playerHasAggro = (data.name == playerName)
                return true, playerHasAggro, data.name, data.perc or 0
            end
        end
    end

    return false, false, nil, 0
end

-- Get threat data from GP_Threats
-- Returns: hasData, playerHasAggro, playerThreatPct, highestOtherPct, threatHolderName
function GudaPlates_Threat.GetGPThreatData()
    local playerName = UnitName("player")
    local playerPct = 0
    local highestOtherPct = 0
    local hasData = false
    local threatHolderName = nil

    for name, data in pairs(GP_Threats) do
        hasData = true
        local pct = data.perc or 0
        if name == playerName then
            playerPct = pct
        else
            if pct > highestOtherPct then
                highestOtherPct = pct
            end
        end
        if pct >= 100 then
            threatHolderName = name
        end
    end

    local playerHasAggro = (playerPct >= 100)

    return hasData, playerHasAggro, playerPct, highestOtherPct, threatHolderName
end

-- Check if a unit is in the player's group
function GudaPlates_Threat.IsInPlayerGroup(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsUnit(unit, "player") then return true end

    -- Check party members
    for i = 1, 4 do
        if UnitIsUnit(unit, "party" .. i) then return true end
    end

    -- Check raid members
    if UnitInRaid("player") then
        for i = 1, 40 do
            if UnitIsUnit(unit, "raid" .. i) then return true end
        end
    end

    -- Check pets
    if UnitIsUnit(unit, "pet") then return true end
    for i = 1, 4 do
        if UnitIsUnit(unit, "partypet" .. i) then return true end
    end

    return false
end

-- =============================================================================
-- Event Frame for Addon Messages
-- =============================================================================

local GP_ThreatFrame = CreateFrame("Frame")
GP_ThreatFrame:RegisterEvent("CHAT_MSG_ADDON")
GP_ThreatFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
GP_ThreatFrame:RegisterEvent("RAID_ROSTER_UPDATE")
GP_ThreatFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
GP_ThreatFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
GP_ThreatFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
        local prefix = arg1
        local msg = arg2 or ""
        local sender = arg4

        -- Check for tank mode data (TMTv1=)
        if string_find(msg, "TMTv1=") then
            GP_HandleTankModePacket(msg)
        end

        -- Check for player threat data (TWTv4=)
        if string_find(msg, "TWTv4=") then
            GP_HandleThreatPacket(msg)
        end

        -- Check for GudaPlates tank mode sharing
        if prefix == GP_ADDON_PREFIX and msg and sender then
            GP_HandleTankModeMessage(sender, msg)
        end
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE"
           or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        GudaPlates_Threat.BroadcastTankMode(true)
    end
end)

-- =============================================================================
-- Debug Support
-- =============================================================================

-- Allow enabling debug from main module
function GudaPlates_Threat.SetDebug(enabled)
    DEBUG_THREAT = enabled
end

-- =============================================================================
-- Backward Compatibility
-- =============================================================================

-- Expose on main GudaPlates table for other modules
if GudaPlates then
    GudaPlates.GP_TankModeThreats = GP_TankModeThreats
    GudaPlates.GP_Threats = GP_Threats
    GudaPlates.GP_TankPlayers = GP_TankPlayers
    GudaPlates.BroadcastTankMode = GudaPlates_Threat.BroadcastTankMode
    GudaPlates.IsPlayerTank = GudaPlates_Threat.IsPlayerTank
    GudaPlates.GetTWTankModeThreat = GudaPlates_Threat.GetTWTankModeThreat
    GudaPlates.GetGPThreatData = GudaPlates_Threat.GetGPThreatData
    GudaPlates.IsInPlayerGroup = GudaPlates_Threat.IsInPlayerGroup
end
