--------------------------------------------------------------------------------
-- GudaPlates_CombatLog.lua
-- Combat log parsing functions for GudaPlates nameplate addon
-- This file contains cmatch helper, cast icons, and combat log parsing functions
--------------------------------------------------------------------------------

-- Upvalue Lua functions for performance
local string_gsub = string.gsub
local string_gfind = string.gfind
local string_find = string.find
local string_sub = string.sub
local table = table
local GetTime = GetTime
local UnitExists = UnitExists
local UnitName = UnitName
local UnitGUID = UnitGUID

-- SuperWoW detection
local superwow_active = (SpellInfo ~= nil) or (UnitGUID ~= nil) or (SUPERWOW_VERSION ~= nil)

-- References to shared tables (set during main file load)
local castTracker
local recentMeleeHits

-- Initialize references when called from main file
local function InitReferences()
    castTracker = GudaPlates.castTracker
    recentMeleeHits = GudaPlates.recentMeleeHits
end

-- ============================================
-- LOCALE-AWARE COMBAT LOG PATTERNS
-- Built from WoW global strings at load time
-- ============================================
local function GlobalStringToPattern(gs)
    if not gs then return nil end
    local p = string.gsub(gs, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = string.gsub(p, "%%%%s", "(.+)")
    p = string.gsub(p, "%%%%d", "(%%d+)")
    return p
end

-- Cast start/perform patterns
local L_CAST_START = GlobalStringToPattern(SPELLCASTOTHERSTART)     -- "%s begins to cast %s."
local L_PERFORM_START = GlobalStringToPattern(SPELLPERFORMOTHERSTART) -- "%s begins to perform %s."

-- Extract fast-path prefix from global strings for cheap rejection
-- e.g., from "You hit %s for %d." extract "You hit "
local function ExtractPrefix(gs, placeholder)
    if not gs then return nil end
    local pos = string.find(gs, placeholder, 1, true)
    if pos and pos > 1 then
        return string.sub(gs, 1, pos - 1)
    end
    return nil
end

-- Melee hit/crit prefixes for fast-path checks
local L_YOU_HIT_PREFIX = ExtractPrefix(COMBATHITSELFOTHER, "%s") or "You hit "
local L_YOU_CRIT_PREFIX = ExtractPrefix(COMBATHITCRITSELFOTHER, "%s") or "You crit "

-- Melee hit/crit patterns
local L_MELEE_HIT_SELF = GlobalStringToPattern(COMBATHITSELFOTHER)     -- "You hit %s for %d."
local L_MELEE_CRIT_SELF = GlobalStringToPattern(COMBATHITCRITSELFOTHER) -- "You crit %s for %d."
local L_MELEE_HIT_OTHER = GlobalStringToPattern(COMBATHITOTHEROTHER)   -- "%s hits %s for %d."
local L_MELEE_CRIT_OTHER = GlobalStringToPattern(COMBATHITCRITOTHEROTHER) -- "%s crits %s for %d."

-- Helper function to match combat log patterns (ShaguPlates-style cmatch)
local function cmatch(str, pattern)
    if not str or not pattern then return nil end
    -- Convert WoW format strings to Lua patterns
    local pat = string_gsub(pattern, "%%%d?%$?s", "(.+)")
    pat = string_gsub(pat, "%%%d?%$?d", "(%d+)")
    for a, b, c, d in string_gfind(str, pat) do
        return a, b, c, d
    end
    return nil
end

-- Cast icons lookup table
local castIcons = {
    ["Fireball"] = "Interface\\Icons\\Spell_Fire_FlameBolt",
    ["Frostbolt"] = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    ["Shadow Bolt"] = "Interface\\Icons\\Spell_Shadow_ShadowBolt",
    ["Greater Heal"] = "Interface\\Icons\\Spell_Holy_GreaterHeal",
    ["Flash Heal"] = "Interface\\Icons\\Spell_Holy_FlashHeal",
    ["Lightning Bolt"] = "Interface\\Icons\\Spell_Nature_Lightning",
    ["Chain Lightning"] = "Interface\\Icons\\Spell_Nature_ChainLightning",
    ["Earthbind Totem"] = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
    ["Healing Wave"] = "Interface\\Icons\\Spell_Nature_MagicImmunity",
    ["Fear"] = "Interface\\Icons\\Spell_Shadow_Possession",
    ["Polymorph"] = "Interface\\Icons\\Spell_Nature_Polymorph",
    ["Scorching Totem"] = "Interface\\Icons\\Spell_Fire_ScorchingTotem",
    ["Slowing Poison"] = "Interface\\Icons\\Ability_PoisonSting",
    ["Web"] = "Interface\\Icons\\Ability_Ensnare",
    ["Cursed Blood"] = "Interface\\Icons\\Spell_Shadow_RitualOfSacrifice",
    ["Shrink"] = "Interface\\Icons\\Spell_Shadow_AntiShadow",
    ["Shadow Weaving"] = "Interface\\Icons\\Spell_Shadow_BlackPlague",
    ["Smite"] = "Interface\\Icons\\Spell_Holy_HolySmite",
    ["Mind Blast"] = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
    ["Holy Light"] = "Interface\\Icons\\Spell_Holy_HolyLight",
    ["Starfire"] = "Interface\\Icons\\Spell_Arcane_StarFire",
    ["Wrath"] = "Interface\\Icons\\Spell_Nature_AbolishMagic",
    ["Entangling Roots"] = "Interface\\Icons\\Spell_Nature_StrangleVines",
    ["Moonfire"] = "Interface\\Icons\\Spell_Nature_StarFall",
    ["Regrowth"] = "Interface\\Icons\\Spell_Nature_ResistNature",
    ["Rejuvenation"] = "Interface\\Icons\\Spell_Nature_Rejuvenation",
}

-- Helper function to parse cast starts from combat log
local function ParseCastStart(msg)
    if not msg then return end

    -- Ensure we have references
    if not castTracker then
        castTracker = GudaPlates.castTracker
    end
    if not castTracker then return end

    local unit, spell = nil, nil
    local SpellDB = GudaPlates_SpellDB

    -- Try locale-aware "begins to cast" pattern
    if L_CAST_START then
        for u, s in string_gfind(msg, L_CAST_START) do
            unit, spell = u, s
            break
        end
    end
    -- Fallback: English pattern
    if not unit then
        local hasBeginsTo = string_find(msg, "begins to ", 1, true)
        if hasBeginsTo then
            for u, s in string_gfind(msg, "(.+) begins to cast (.+)%.") do
                unit, spell = u, s
            end
        end
    end

    -- Try locale-aware "begins to perform" pattern
    if not unit then
        if L_PERFORM_START then
            for u, s in string_gfind(msg, L_PERFORM_START) do
                unit, spell = u, s
                break
            end
        end
        if not unit then
            local hasBeginsTo = string_find(msg, "begins to ", 1, true)
            if hasBeginsTo then
                for u, s in string_gfind(msg, "(.+) begins to perform (.+)%.") do
                    unit, spell = u, s
                end
            end
        end
    end

    if unit and spell then
        -- Resolve spell name to English for castIcons lookup
        local englishSpell = spell
        if SpellDB and SpellDB.ResolveSpellName then
            englishSpell = SpellDB:ResolveSpellName(spell, nil)
        end

        local duration = 2000 -- Default 2 seconds

        if not castTracker[unit] then castTracker[unit] = {} end

        local newCast = {
            spell = englishSpell,
            startTime = GetTime(),
            duration = duration,
            icon = castIcons[englishSpell],
        }

        table.insert(castTracker[unit], newCast)
    end

    -- Check for interrupts/failures (with cheap prefix check)
    local interruptedUnit = nil
    if string_find(msg, "interrupted", 1, true) then
        for u in string_gfind(msg, "(.+)'s .+ is interrupted%.") do interruptedUnit = u end
    end
    if not interruptedUnit and string_find(msg, "fails", 1, true) then
        for u in string_gfind(msg, "(.+)'s .+ fails%.") do interruptedUnit = u end
    end

    if interruptedUnit and castTracker[interruptedUnit] then
        table.remove(castTracker[interruptedUnit], 1)
    end
end

local function ParseAttackHit(msg)
    -- Debug: show raw combat message if debug enabled
    local showDebug = GudaPlates_Debuffs and GudaPlates_Debuffs.DEBUG_JUDGEMENT
    if showDebug then
        DEFAULT_CHAT_FRAME:AddMessage("[Judge] ParseAttackHit msg: " .. (msg or "nil"))
    end
    if not msg then return end

    -- For Paladin judgement refresh, we don't need SpellDB or recentMeleeHits
    -- Just parse the message and call SealHandler
    local attacker, victim = nil, nil
    local hitPrefixLen = string.len(L_YOU_HIT_PREFIX)
    local critPrefixLen = string.len(L_YOU_CRIT_PREFIX)

    -- Simple pattern: check if message starts with localized "You hit " or "You crit "
    if string_sub(msg, 1, hitPrefixLen) == L_YOU_HIT_PREFIX then
        -- Try locale-aware pattern first
        if L_MELEE_HIT_SELF then
            for v in string_gfind(msg, L_MELEE_HIT_SELF) do
                victim = v
                attacker = "You"
                break
            end
        end
        -- Fallback: manual extraction
        if not victim then
            local forPos = string_find(msg, " for ", 1, true)
            if forPos then
                victim = string_sub(msg, hitPrefixLen + 1, forPos - 1)
                attacker = "You"
            end
        end
    elseif string_sub(msg, 1, critPrefixLen) == L_YOU_CRIT_PREFIX then
        -- Try locale-aware pattern first
        if L_MELEE_CRIT_SELF then
            for v in string_gfind(msg, L_MELEE_CRIT_SELF) do
                victim = v
                attacker = "You"
                break
            end
        end
        -- Fallback: manual extraction
        if not victim then
            local forPos = string_find(msg, " for ", 1, true)
            if forPos then
                victim = string_sub(msg, critPrefixLen + 1, forPos - 1)
                attacker = "You"
            end
        end
    end

    if showDebug then
        DEFAULT_CHAT_FRAME:AddMessage("[Judge] Parsed: attacker=" .. tostring(attacker) .. ", victim=" .. tostring(victim))
    end

    -- Call SealHandler for Paladin judgement refresh
    if attacker == "You" and victim and GudaPlates_Debuffs then
        GudaPlates_Debuffs:SealHandler(attacker, victim)
    end

    -- Original melee tracking code (needs SpellDB and recentMeleeHits)
    if not SpellDB then return end
    if not recentMeleeHits then
        recentMeleeHits = GudaPlates.recentMeleeHits
    end
    if not recentMeleeHits then return end

    if attacker == "You" and victim then
        recentMeleeHits[victim] = GetTime()
        if superwow_active and UnitExists("target") and UnitName("target") == victim then
            local guid = UnitGUID and UnitGUID("target")
            if guid then
                recentMeleeHits[guid] = GetTime()
            end
        end
    end
    -- Only run expensive regex patterns if no victim found yet
    if not victim and string_find(msg, " for ", 1, true) then
        -- Try locale-aware other hit/crit patterns
        if string_find(msg, " hits ", 1, true) or (L_MELEE_HIT_OTHER and string_find(msg, L_MELEE_HIT_OTHER)) then
            if L_MELEE_HIT_OTHER then
                for a, v in string_gfind(msg, L_MELEE_HIT_OTHER) do
                    attacker, victim = a, v
                    break
                end
            end
            if not victim then
                for a, v in string_gfind(msg, "(.+) hits (.-) for %d+%.") do
                    attacker, victim = a, v
                    break
                end
            end
            -- Ranged: Your ranged attack hits X for Y.
            if not victim and string_find(msg, "ranged", 1, true) then
                for v in string_gfind(msg, "Your ranged attack hits (.-) for %d+%.") do
                    attacker = "You"
                    victim = v
                    break
                end
            end
            if not victim then
                for a, v in string_gfind(msg, "(.+)'s ranged attack hits (.-) for %d+%.") do
                    attacker, victim = a, v
                    break
                end
            end
        end
        if not victim then
            if string_find(msg, " crits ", 1, true) or (L_MELEE_CRIT_OTHER and string_find(msg, L_MELEE_CRIT_OTHER)) then
                if L_MELEE_CRIT_OTHER then
                    for a, v in string_gfind(msg, L_MELEE_CRIT_OTHER) do
                        attacker, victim = a, v
                        break
                    end
                end
                if not victim then
                    for a, v in string_gfind(msg, "(.+) crits (.-) for %d+%.") do
                        attacker, victim = a, v
                        break
                    end
                end
                -- Ranged crits
                if not victim and string_find(msg, "ranged", 1, true) then
                    for v in string_gfind(msg, "Your ranged attack crits (.-) for %d+%.") do
                        attacker = "You"
                        victim = v
                        break
                    end
                end
                if not victim then
                    for a, v in string_gfind(msg, "(.+)'s ranged attack crits (.-) for %d+%.") do
                        attacker, victim = a, v
                        break
                    end
                end
            end
        end
    end

    if attacker == "You" and victim then
        recentMeleeHits[victim] = GetTime()
        -- Also store by GUID if available
        if superwow_active and UnitExists("target") and UnitName("target") == victim then
            local guid = UnitGUID and UnitGUID("target")
            if guid then
                recentMeleeHits[guid] = GetTime()
            end
        end
    end

    if attacker and victim and GudaPlates_Debuffs then
        -- Debug output if judgement debug is enabled
        if GudaPlates_Debuffs.DEBUG_JUDGEMENT then
            DEFAULT_CHAT_FRAME:AddMessage("[Judge] ParseAttackHit: attacker=" .. (attacker or "nil") .. ", victim=" .. (victim or "nil"))
        end
        GudaPlates_Debuffs:SealHandler(attacker, victim)
    end
end

-- Expose functions via GudaPlates table
GudaPlates.CombatLog = {
    cmatch = cmatch,
    castIcons = castIcons,
    ParseCastStart = ParseCastStart,
    ParseAttackHit = ParseAttackHit,
    InitReferences = InitReferences,
}

-- Also expose directly for backwards compatibility
GudaPlates.cmatch = cmatch
GudaPlates.ParseCastStart = ParseCastStart
GudaPlates.ParseAttackHit = ParseAttackHit
GudaPlates.castIcons = castIcons
