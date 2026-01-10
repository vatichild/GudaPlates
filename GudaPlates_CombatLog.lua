--------------------------------------------------------------------------------
-- GudaPlates_CombatLog.lua
-- Combat log parsing functions for GudaPlates nameplate addon
-- This file contains cmatch helper, cast icons, and combat log parsing functions
--------------------------------------------------------------------------------

-- Upvalue Lua functions for performance
local string_gsub = string.gsub
local string_gfind = string.gfind
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

    -- Try "begins to cast"
    for u, s in string_gfind(msg, "(.+) begins to cast (.+)%.") do
        unit, spell = u, s
    end

    -- Try "begins to perform"
    if not unit then
        for u, s in string_gfind(msg, "(.+) begins to perform (.+)%.") do
            unit, spell = u, s
        end
    end

    if unit and spell then
        local duration = 2000 -- Default 2 seconds

        if not castTracker[unit] then castTracker[unit] = {} end

        local newCast = {
            spell = spell,
            startTime = GetTime(),
            duration = duration,
            icon = castIcons[spell],
        }

        table.insert(castTracker[unit], newCast)
    end

    -- Check for interrupts/failures
    local interruptedUnit = nil
    for u in string_gfind(msg, "(.+)'s .+ is interrupted%.") do interruptedUnit = u end
    if not interruptedUnit then
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

    -- Simple pattern: check if message starts with "You hit " or "You crit "
    if string.sub(msg, 1, 8) == "You hit " then
        -- Find " for " to get the victim name
        local forPos = string.find(msg, " for ")
        if forPos then
            victim = string.sub(msg, 9, forPos - 1)
            attacker = "You"
        end
    elseif string.sub(msg, 1, 9) == "You crit " then
        local forPos = string.find(msg, " for ")
        if forPos then
            victim = string.sub(msg, 10, forPos - 1)
            attacker = "You"
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
    if not victim then
    -- X hits Y for Z.
        for a, v in string_gfind(msg, "(.+) hits (.-) for %d+%.") do
            attacker = a
            victim = v
            break
        end
    end
    if not victim then
    -- X crits Y for Z.
        for a, v in string_gfind(msg, "(.+) crits (.-) for %d+%.") do
            attacker = a
            victim = v
            break
        end
    end

    -- Patterns for ranged hits
    if not victim then
    -- Your ranged attack hits X for Y.
        for v in string_gfind(msg, "Your ranged attack hits (.-) for %d+%.") do
            attacker = "You"
            victim = v
            break
        end
    end
    if not victim then
    -- Your ranged attack crits X for Y.
        for v in string_gfind(msg, "Your ranged attack crits (.-) for %d+%.") do
            attacker = "You"
            victim = v
            break
        end
    end
    if not victim then
    -- X's ranged attack hits Y for Z.
        for a, v in string_gfind(msg, "(.+)'s ranged attack hits (.-) for %d+%.") do
            attacker = a
            victim = v
            break
        end
    end
    if not victim then
    -- X's ranged attack crits Y for Z.
        for a, v in string_gfind(msg, "(.+)'s ranged attack crits (.-) for %d+%.") do
            attacker = a
            victim = v
            break
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
