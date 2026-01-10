--------------------------------------------------------------------------------
-- GudaPlates_Castbar.lua
-- Castbar tracking functions for GudaPlates nameplate addon
-- This file contains UNIT_CASTEVENT handling and castDB management
--------------------------------------------------------------------------------

-- Upvalue Lua functions for performance
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitName = UnitName

-- SuperWoW detection
local superwow_active = (SpellInfo ~= nil) or (UnitGUID ~= nil) or (SUPERWOW_VERSION ~= nil)

-- Reference to castDB (set during initialization)
local castDB

-- Initialize references when called from main file
local function InitReferences()
    castDB = GudaPlates.castDB
end

-- Handle UNIT_CASTEVENT from SuperWoW
-- This provides exact GUID of caster for accurate per-mob cast tracking
-- Returns true if the event should cause the main handler to return early
local function HandleUnitCastEvent(guid, target, eventType, spellId, timer)
    -- Ensure we have castDB reference
    if not castDB then
        castDB = GudaPlates.castDB
    end
    if not castDB then return false end

    if eventType == "START" or eventType == "CAST" or eventType == "CHANNEL" then
        -- Get spell info from SpellInfo if available
        local spell, icon
        if SpellInfo and spellId then
            spell, _, icon = SpellInfo(spellId)
        end

        -- Fallback values
        spell = spell or "Casting"
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"

        -- Update SpellDB with debuff info if it's a known debuff
        if SpellDB and eventType == "CAST" and target and target ~= "" then
            local duration = SpellDB:GetDuration(spell, 0)
            if duration and duration > 0 then
                local isOwn = (guid == (UnitGUID and UnitGUID("player")))
                SpellDB:RefreshEffect(target, 0, spell, duration, isOwn)

                -- Also handle Thunderfury double-refresh if one of them procs
                if spell == "Thunderfury" or spell == "Thunderfury's Blessing" then
                    SpellDB:RefreshEffect(target, 0, "Thunderfury", duration, isOwn)
                    SpellDB:RefreshEffect(target, 0, "Thunderfury's Blessing", duration, isOwn)
                    if GudaPlates_Debuffs and GudaPlates_Debuffs.timers then
                        GudaPlates_Debuffs.timers[target .. "_" .. "Thunderfury"] = nil
                        GudaPlates_Debuffs.timers[target .. "_" .. "Thunderfury's Blessing"] = nil

                        -- Also clear by name if we can find it
                        local targetName = UnitName("target")
                        if targetName and (UnitGUID and UnitGUID("target") == target) then
                            GudaPlates_Debuffs.timers[targetName .. "_" .. "Thunderfury"] = nil
                            GudaPlates_Debuffs.timers[targetName .. "_" .. "Thunderfury's Blessing"] = nil
                        end
                    end
                elseif GudaPlates_Debuffs and GudaPlates_Debuffs.timers then
                    GudaPlates_Debuffs.timers[target .. "_" .. spell] = nil
                end
            end
        end

        -- Skip buff procs during cast (same logic as ShaguPlates)
        if eventType == "CAST" then
            if castDB[guid] and castDB[guid].spell ~= spell then
                return true  -- Signal main handler to return
            end
        end

        -- Store cast by GUID
        castDB[guid] = {
            spell = spell,
            startTime = GetTime(),
            duration = timer or 2000,
            icon = icon,
            channel = (eventType == "CHANNEL")
        }
    elseif eventType == "FAIL" then
        -- Remove cast entry for this GUID
        if castDB[guid] then
            castDB[guid] = nil
        end
    end

    return false
end

-- Clear all cast tracking data (called on zone change/reload)
local function ClearCastData()
    if not castDB then
        castDB = GudaPlates.castDB
    end
    if castDB then
        for k in pairs(castDB) do
            castDB[k] = nil
        end
    end
end

-- Get cast info for a GUID
local function GetCast(guid)
    if not castDB then
        castDB = GudaPlates.castDB
    end
    return castDB and castDB[guid]
end

-- Remove cast info for a GUID
local function RemoveCast(guid)
    if not castDB then
        castDB = GudaPlates.castDB
    end
    if castDB and castDB[guid] then
        castDB[guid] = nil
    end
end

-- Expose functions via GudaPlates table
GudaPlates.Castbar = {
    InitReferences = InitReferences,
    HandleUnitCastEvent = HandleUnitCastEvent,
    ClearCastData = ClearCastData,
    GetCast = GetCast,
    RemoveCast = RemoveCast,
}

-- Also expose directly for backwards compatibility
GudaPlates.HandleUnitCastEvent = HandleUnitCastEvent
