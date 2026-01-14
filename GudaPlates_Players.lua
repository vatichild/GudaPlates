-- =============================================================================
-- GudaPlates_Players.lua
-- =============================================================================
-- Player Detection and Coloring Module
-- Handles enemy player detection, PvP status, and class color logic
--
-- Exports:
--   GudaPlates_Players.DetectEnemyPlayer(frame, nameplate, unitstr) - Detect if unit is enemy player
--   GudaPlates_Players.GetEnemyPlayerColor(nameplate, Settings) - Get color for enemy player
--   GudaPlates_Players.ShouldUsePlayerDimensions(nameplate, Settings) - Check if should use friendly dimensions
--   GudaPlates_Players.ResetCache(nameplate) - Reset cached player data
-- =============================================================================

GudaPlates_Players = {}

-- Local references for performance
local UnitIsPlayer = UnitIsPlayer
local UnitIsPVP = UnitIsPVP
local UnitClass = UnitClass
local UnitExists = UnitExists
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- Default hostile red color
local HOSTILE_RED = {0.85, 0.2, 0.2, 1}

-- =============================================================================
-- Player Detection
-- =============================================================================

-- Detect if a hostile unit is an enemy player and cache the results
-- Note: PvP status is always checked fresh (not cached) since it can change dynamically
-- Returns: isEnemyPlayer, isEnemyPlayerPvP, enemyClass
function GudaPlates_Players.DetectEnemyPlayer(frame, nameplate, unitstr)
    if not nameplate then return false, false, nil end

    local isEnemyPlayer = false
    local isEnemyPlayerPvP = false
    local enemyClass = nil

    -- Check if we have a valid unit string and SuperWoW APIs
    if unitstr and unitstr ~= "" and UnitIsPlayer and UnitExists(unitstr) then
        isEnemyPlayer = UnitIsPlayer(unitstr)
        if isEnemyPlayer then
            -- Get class (static - can be cached)
            local _, classToken = UnitClass(unitstr)
            enemyClass = classToken

            -- Check PvP status EVERY TIME (dynamic - can change without targeting)
            if UnitIsPVP then
                isEnemyPlayerPvP = UnitIsPVP(unitstr)
            end

            -- Cache static data
            nameplate.cachedIsEnemyPlayer = isEnemyPlayer
            nameplate.cachedEnemyClass = enemyClass
            -- Always update PvP status (not truly cached, refreshed every check)
            nameplate.cachedIsEnemyPlayerPvP = isEnemyPlayerPvP
        else
            -- Not a player - clear any stale cache
            nameplate.cachedIsEnemyPlayer = false
            nameplate.cachedIsEnemyPlayerPvP = false
            nameplate.cachedEnemyClass = nil
        end
    elseif nameplate.cachedIsEnemyPlayer then
        -- Use cached static values
        isEnemyPlayer = nameplate.cachedIsEnemyPlayer
        enemyClass = nameplate.cachedEnemyClass
        -- PvP status from cache (last known state when we had valid unitstr)
        isEnemyPlayerPvP = nameplate.cachedIsEnemyPlayerPvP or false
    end

    return isEnemyPlayer, isEnemyPlayerPvP, enemyClass
end

-- =============================================================================
-- Color Logic
-- =============================================================================

-- Get the appropriate color for an enemy player
-- Returns: r, g, b, a (color values) or nil if not an enemy player
function GudaPlates_Players.GetEnemyPlayerColor(nameplate, Settings)
    if not nameplate then return nil end

    local isEnemyPlayer = nameplate.cachedIsEnemyPlayer
    local isEnemyPlayerPvP = nameplate.cachedIsEnemyPlayerPvP
    local enemyClass = nameplate.cachedEnemyClass

    if not isEnemyPlayer then
        return nil  -- Not an enemy player, let caller handle
    end

    -- Determine if we should use class colors
    local useClassColor = true

    -- If PvP-flagged AND "No class colors for PvP enemies" is enabled -> use red
    if isEnemyPlayerPvP and Settings and Settings.pvpEnemyNoClassColors then
        useClassColor = false
    end

    -- Apply color
    if useClassColor and enemyClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[enemyClass] then
        local classColor = RAID_CLASS_COLORS[enemyClass]
        return classColor.r, classColor.g, classColor.b, 1
    else
        -- Simple hostile red for enemy players
        return HOSTILE_RED[1], HOSTILE_RED[2], HOSTILE_RED[3], HOSTILE_RED[4]
    end
end

-- =============================================================================
-- Dimension Logic
-- =============================================================================

-- Check if nameplate should use player (friendly) dimensions
-- Returns: true if should use friendly dimensions, false for enemy dimensions
function GudaPlates_Players.ShouldUsePlayerDimensions(nameplate, Settings, isFriendly)
    if isFriendly then
        return true  -- Friendly units always use friendly dimensions
    end

    if not nameplate then return false end

    local isEnemyPlayer = nameplate.cachedIsEnemyPlayer
    local isEnemyPlayerPvP = nameplate.cachedIsEnemyPlayerPvP

    if not isEnemyPlayer then
        return false  -- Not a player, use enemy dimensions
    end

    -- Non-PvP enemy players always use friendly dimensions
    if not isEnemyPlayerPvP then
        return true
    end

    -- PvP enemy players: check setting
    if Settings and Settings.pvpEnemyAsFriendly then
        return true  -- Setting enabled: use friendly dimensions for PvP enemies
    end

    return false  -- Default: PvP enemies use enemy dimensions
end

-- =============================================================================
-- Cache Management
-- =============================================================================

-- Reset cached player data (call on nameplate reuse)
function GudaPlates_Players.ResetCache(nameplate)
    if not nameplate then return end

    nameplate.cachedIsEnemyPlayer = nil
    nameplate.cachedIsEnemyPlayerPvP = nil
    nameplate.cachedEnemyClass = nil
end

-- =============================================================================
-- Utility Functions
-- =============================================================================

-- Check if a unit is an enemy player (quick check using cache)
function GudaPlates_Players.IsEnemyPlayer(nameplate)
    return nameplate and nameplate.cachedIsEnemyPlayer or false
end

-- Check if an enemy player is PvP flagged (quick check using cache)
function GudaPlates_Players.IsEnemyPlayerPvP(nameplate)
    return nameplate and nameplate.cachedIsEnemyPlayerPvP or false
end

-- Get cached enemy class
function GudaPlates_Players.GetEnemyClass(nameplate)
    return nameplate and nameplate.cachedEnemyClass or nil
end
