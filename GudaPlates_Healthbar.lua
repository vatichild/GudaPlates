-- =============================================================================
-- GudaPlates_Healthbar.lua
-- =============================================================================
-- Healthbar Color Module
-- Handles unit type detection, neutral state tracking, and color determination
--
-- Exports:
--   GudaPlates_Healthbar.DetectUnitType(nameplate, original) - Detect hostile/neutral/friendly
--   GudaPlates_Healthbar.CheckUnitChange(nameplate, plateName, isNeutral) - Check if unit changed
--   GudaPlates_Healthbar.ResetCache(nameplate) - Reset cached data on nameplate show
--   GudaPlates_Healthbar.IsNeutral(nameplate) - Check if unit is/was neutral
--   GudaPlates_Healthbar.IsFriendly(nameplate) - Check if unit is friendly
--   GudaPlates_Healthbar.GetNeutralColor() - Get neutral color values
--   GudaPlates_Healthbar.ApplyNeutralColor(nameplate) - Apply neutral yellow color
-- =============================================================================

GudaPlates_Healthbar = {}

-- =============================================================================
-- Constants
-- =============================================================================

-- Neutral mob color (golden yellow)
local NEUTRAL_COLOR = {0.9, 0.7, 0.0, 1}

-- Color detection thresholds
local HOSTILE_THRESHOLD = {r_min = 0.9, g_max = 0.2, b_max = 0.2}
local NEUTRAL_THRESHOLD = {r_min = 0.9, g_min = 0.9, b_max = 0.2}

-- =============================================================================
-- Cache Management
-- =============================================================================

-- Reset all cached healthbar color data (call on nameplate show/reuse)
function GudaPlates_Healthbar.ResetCache(nameplate)
    if not nameplate then return end

    -- Unit type cache
    nameplate.cachedIsFriendly = nil
    nameplate.cachedIsHostile = nil
    nameplate.cachedIsNeutral = nil

    -- Neutral tracking (persists through WoW color changes)
    nameplate.wasNeutral = nil
    nameplate.lastPlateName = nil

    -- Color cache (force recalculation on next frame)
    nameplate.lastColorR = nil
    nameplate.lastColorG = nil
    nameplate.lastColorB = nil
end

-- =============================================================================
-- Unit Type Detection
-- =============================================================================

-- Detect unit type from original healthbar color
-- Returns: isHostile, isNeutral, isFriendly, r, g, b
function GudaPlates_Healthbar.DetectUnitType(nameplate, original)
    if not nameplate or not original or not original.healthbar then
        return false, false, true, 0, 1, 0  -- Default to friendly
    end

    local r, g, b = original.healthbar:GetStatusBarColor()
    local isHostile, isNeutral, isFriendly

    -- Check if color changed since last frame (optimization)
    local lastR, lastG, lastB = nameplate.lastColorR, nameplate.lastColorG, nameplate.lastColorB

    if r == lastR and g == lastG and b == lastB then
        -- Use cached values
        isHostile = nameplate.cachedIsHostile
        isNeutral = nameplate.cachedIsNeutral
        isFriendly = nameplate.cachedIsFriendly
    else
        -- Recalculate based on color thresholds
        isHostile = r > HOSTILE_THRESHOLD.r_min and g < HOSTILE_THRESHOLD.g_max and b < HOSTILE_THRESHOLD.b_max
        isNeutral = r > NEUTRAL_THRESHOLD.r_min and g > NEUTRAL_THRESHOLD.g_min and b < NEUTRAL_THRESHOLD.b_max
        isFriendly = not isHostile and not isNeutral

        -- Update color cache
        nameplate.lastColorR = r
        nameplate.lastColorG = g
        nameplate.lastColorB = b

        -- Update unit type cache
        nameplate.cachedIsHostile = isHostile
        nameplate.cachedIsNeutral = isNeutral
        nameplate.cachedIsFriendly = isFriendly

        -- Save initial neutral state (only on first detection)
        -- This persists even when WoW changes neutral mobs to red during combat
        if nameplate.wasNeutral == nil then
            nameplate.wasNeutral = isNeutral
        end
    end

    return isHostile, isNeutral, isFriendly, r, g, b
end

-- Check if nameplate was reused for a different unit (name changed)
-- Updates wasNeutral to current state for new unit
function GudaPlates_Healthbar.CheckUnitChange(nameplate, plateName, isNeutral)
    if not nameplate then return end

    if plateName and plateName ~= nameplate.lastPlateName then
        nameplate.lastPlateName = plateName
        nameplate.wasNeutral = isNeutral
    end
end

-- =============================================================================
-- Quick Checks
-- =============================================================================

-- Check if unit is currently or was initially neutral
function GudaPlates_Healthbar.IsNeutral(nameplate)
    if not nameplate then return false end
    return nameplate.cachedIsNeutral or nameplate.wasNeutral or false
end

-- Check if unit was initially neutral (persists through combat)
function GudaPlates_Healthbar.WasNeutral(nameplate)
    if not nameplate then return false end
    return nameplate.wasNeutral or false
end

-- Check if unit is friendly
function GudaPlates_Healthbar.IsFriendly(nameplate)
    if not nameplate then return false end
    return nameplate.cachedIsFriendly or false
end

-- Check if unit is hostile
function GudaPlates_Healthbar.IsHostile(nameplate)
    if not nameplate then return false end
    return nameplate.cachedIsHostile or false
end

-- =============================================================================
-- Neutral Color Helpers
-- =============================================================================

-- Get neutral color values
function GudaPlates_Healthbar.GetNeutralColor()
    return NEUTRAL_COLOR[1], NEUTRAL_COLOR[2], NEUTRAL_COLOR[3], NEUTRAL_COLOR[4]
end

-- Apply neutral yellow color to healthbar
function GudaPlates_Healthbar.ApplyNeutralColor(nameplate)
    if not nameplate or not nameplate.health then return end
    nameplate.health:SetStatusBarColor(NEUTRAL_COLOR[1], NEUTRAL_COLOR[2], NEUTRAL_COLOR[3], NEUTRAL_COLOR[4])
end

-- Check if should show neutral color (neutral and not attacking player)
function GudaPlates_Healthbar.ShouldShowNeutral(nameplate, isNeutral, isAttackingPlayer)
    if not nameplate then return false end
    return (isNeutral or nameplate.wasNeutral) and not isAttackingPlayer
end

-- =============================================================================
-- Backward Compatibility
-- =============================================================================

if GudaPlates then
    GudaPlates.Healthbar = GudaPlates_Healthbar
end
