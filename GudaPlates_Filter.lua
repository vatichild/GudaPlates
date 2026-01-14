-- =============================================================================
-- GudaPlates_Filter.lua
-- =============================================================================
-- Nameplate Filtering Module
-- Responsible for deciding which nameplates should be shown/hidden
-- based on unit type (critters, etc.)
--
-- Exports:
--   GudaPlates_Filter.IsCritter(frame, nameplate, original, unitstr) - Check if unit is a critter
--   GudaPlates_Filter.ShouldSkipNameplate(frame, nameplate, original, Settings) - Check if nameplate should be skipped entirely
-- =============================================================================

GudaPlates_Filter = {}

-- Local references for performance
local string_lower = string.lower
local UnitCreatureType = UnitCreatureType

-- =============================================================================
-- Critter Detection
-- =============================================================================

-- Check if unit is a critter using multiple detection methods
-- Returns: true if critter, false otherwise
function GudaPlates_Filter.IsCritter(frame, nameplate, original, unitstr)
    -- Method 1: SuperWoW - use UnitCreatureType API
    if unitstr and UnitCreatureType then
        local creatureType = UnitCreatureType(unitstr)
        if creatureType == "Critter" then
            return true
        end
    end

    -- Method 2: Check name against Critters list
    -- IMPORTANT: Read from original.name (Blizzard's FontString), not nameplate.name
    -- At OnShow time, our custom nameplate.name hasn't been populated yet
    if GudaPlates and GudaPlates.Critters then
        local plateName = nil
        -- Try original name first (always has text from Blizzard)
        if original and original.name and original.name.GetText then
            plateName = original.name:GetText()
        end
        -- Fallback to our name if original not available
        if not plateName and nameplate and nameplate.name and nameplate.name.GetText then
            plateName = nameplate.name:GetText()
        end
        if plateName and GudaPlates.Critters[string_lower(plateName)] then
            return true
        end
    end

    -- Method 3: Fallback - detect neutral units with level 1 and very low HP
    -- Only use this fallback when we don't have SuperWoW unit info
    if not unitstr and original and original.healthbar then
        local r, g, b = original.healthbar:GetStatusBarColor()
        local isNeutral = r > 0.9 and g > 0.9 and b < 0.2

        if isNeutral then
            -- Check level
            local levelText = nil
            if original.level and original.level.GetText then
                levelText = original.level:GetText()
            end

            -- Check HP
            local hp = original.healthbar:GetValue() or 0
            local _, hpmax = original.healthbar:GetMinMaxValues()

            -- Critters are typically level 1 with very low max HP (under 100)
            if levelText == "1" and hpmax and hpmax > 0 and hpmax < 100 then
                return true
            end
        end
    end

    return false
end

-- =============================================================================
-- Filter Application
-- =============================================================================

-- Check if nameplate should be COMPLETELY SKIPPED (no processing, no data updates)
-- Returns: true if should skip, false otherwise
--
-- SIMPLE APPROACH: If critter filtering is enabled and unit is a critter,
-- we skip ALL processing - no data updates, no element changes, nothing.
-- The nameplate stays hidden. When the frame is reused for a non-critter,
-- normal processing resumes.
function GudaPlates_Filter.ShouldSkipNameplate(frame, nameplate, original, Settings)
    -- If critter filtering is disabled, never skip
    if not Settings or Settings.showCritterNameplates then
        return false
    end

    -- Get unit string for SuperWoW detection
    local unitstr = nil
    if GudaPlates and GudaPlates.superwow_active and frame and frame.GetName then
        unitstr = frame:GetName(1)
    end

    -- Check if critter - if so, skip entirely
    return GudaPlates_Filter.IsCritter(frame, nameplate, original, unitstr)
end
