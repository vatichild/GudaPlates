-- GudaPlates for WoW 1.12.1
-- Written for Lua 5.0 (Vanilla)

GudaPlates = GudaPlates or {}

-- ============================================
-- PERFORMANCE: Upvalue frequently used globals
-- Local lookups are faster than global table lookups
-- ============================================

-- Lua functions
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local tonumber = tonumber
local unpack = unpack
local getglobal = getglobal

-- Lua string functions
local string_find = string.find
local string_lower = string.lower
local string_upper = string.upper
local string_format = string.format
local string_gsub = string.gsub
local string_gfind = string.gfind
local string_sub = string.sub
local string_len = string.len

-- Lua math functions
local math_floor = math.floor
local math_ceil = math.ceil
local math_abs = math.abs
local math_max = math.max
local math_min = math.min

-- Lua table functions
local table_insert = table.insert
local table_remove = table.remove
local table_getn = table.getn

-- WoW API functions (client-side)
local GetTime = GetTime
local UnitExists = UnitExists
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitClass = UnitClass
local UnitIsUnit = UnitIsUnit
local UnitCanAttack = UnitCanAttack
local UnitIsFriend = UnitIsFriend
local UnitIsEnemy = UnitIsEnemy
local UnitInRaid = UnitInRaid
local UnitDebuff = UnitDebuff
local UnitCreatureType = UnitCreatureType
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local CreateFrame = CreateFrame

-- SuperWoW API (may not exist)
local UnitGUID = UnitGUID

-- ============================================

-- Performance: Throttle intervals
local DEBUFF_UPDATE_INTERVAL = 0.1  -- Update debuffs 10 times/sec instead of every frame

-- Performance: Event lookup tables (faster than string.find)
local SPELL_EVENTS = {
    ["CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF"] = true,
    ["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF"] = true,
    ["CHAT_MSG_SPELL_SELF_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_TRADESKILLS"] = true,
    ["CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_AURA_GONE_OTHER"] = true,
    ["CHAT_MSG_SPELL_AURA_GONE_SELF"] = true,
    ["CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF"] = true,
    ["CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF"] = true,
    ["CHAT_MSG_SPELL_FAILED_LOCALPLAYER"] = true,
}

-- Subset of SPELL_EVENTS that are damage/miss events (for proc tracking like Thunderfury)
local SPELL_DAMAGE_EVENTS = {
    ["CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_SELF_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE"] = true,
    ["CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE"] = true,
}

local COMBAT_EVENTS = {
    ["CHAT_MSG_COMBAT_SELF_HITS"] = true,
    ["CHAT_MSG_COMBAT_PARTY_HITS"] = true,
    ["CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS"] = true,
    ["CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS"] = true,
    ["CHAT_MSG_COMBAT_SELF_RANGED_HITS"] = true,
    ["CHAT_MSG_COMBAT_PARTY_RANGED_HITS"] = true,
}

-- Macro Texture Hover Only
local macroFrame = CreateFrame("Frame")

if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GudaPlates]|r Loading...")
end

-- Disable pfUI nameplates module
local function DisablePfUINameplates()
    if pfUI then
        -- Disable the module registration
        if pfUI.modules then
            pfUI.modules["nameplates"] = nil
        end
        -- Hide existing pfUI nameplate frame if it exists
        if pfNameplates then
            pfNameplates:Hide()
            pfNameplates:UnregisterAllEvents()
        end
        -- Block pfUI nameplate creation function
        if pfUI.nameplates then
            pfUI.nameplates = nil
        end
        return true
    end
    return false
end

-- Try to disable pfUI nameplates immediately
if DisablePfUINameplates() then
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GudaPlates]|r Disabled pfUI nameplates module")
    end
end

-- Debug flag for duration tracking
local DEBUG_DURATION = false
GudaPlates.lua_DEBUG_DURATION = DEBUG_DURATION

local function Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[GudaPlates]|r " .. tostring(msg))
    end
end
GudaPlates.Print = Print  -- Expose for Options module

local initialized = 0
local parentcount = 0
local platecount = 0
local registry = {}
GudaPlates.registry = registry  -- Expose for Options module

-- Forward declarations for functions used before they're defined
local LoadSettings
local REGION_ORDER = { "border", "glow", "name", "level", "levelicon", "raidicon" }
-- Track combat state per nameplate frame to avoid issues with same-named mobs
local superwow_active = (SpellInfo ~= nil) or (UnitGUID ~= nil) or (SUPERWOW_VERSION ~= nil) -- SuperWoW detection
local twthreat_active = UnitThreat ~= nil -- TWThreat detection

-- Player class for debuff filtering
local _, playerClass = UnitClass("player")
playerClass = playerClass or ""

-- Cast tracking database (keyed by GUID when SuperWoW, or by name otherwise)
local castDB = {}
GudaPlates.castDB = castDB  -- Expose for Castbar module

-- Cast tracking for non-SuperWoW
local castTracker = {}
GudaPlates.castTracker = castTracker  -- Expose for CombatLog module

-- Settings and other variables from GudaPlates_Settings.lua
local Settings = GudaPlates.Settings
local THREAT_COLORS = GudaPlates.THREAT_COLORS
local playerRole = GudaPlates.playerRole
local minimapAngle = GudaPlates.minimapAngle
local nameplateOverlap = GudaPlates.nameplateOverlap
local clickThrough = GudaPlates.nameplateClickThrough


local fontOptions = {
    {value = "Fonts\\ARIALN.TTF", text = "Arial Narrow (Default)"},
    {value = "Fonts\\FRIZQT__.TTF", text = "Friz Quadrata"},
    {value = "Interface\\AddOns\\GudaPlates\\fonts\\BigNoodleTitling.ttf", text = "Big Noodle Titling"},
    {value = "Interface\\AddOns\\GudaPlates\\fonts\\Continuum.ttf", text = "Continuum"},
    {value = "Interface\\AddOns\\GudaPlates\\fonts\\DieDieDie.ttf", text = "DieDieDie"},
    {value = "Interface\\AddOns\\GudaPlates\\fonts\\Expressway.ttf", text = "Expressway"},
    {value = "Interface\\AddOns\\GudaPlates\\fonts\\Homespun.ttf", text = "Homespun"},
    {value = "Interface\\AddOns\\GudaPlates\\fonts\\Hooge.ttf", text = "Hooge"},
    {value = "Interface\\AddOns\\GudaPlates\\fonts\\Myriad-Pro.ttf", text = "Myriad Pro"},
    {value = "Interface\\AddOns\\GudaPlates\\fonts\\PT-Sans-Narrow-Bold.ttf", text = "PT Sans Narrow Bold"},
    {value = "Interface\\AddOns\\GudaPlates\\fonts\\PT-Sans-Narrow-Regular.ttf", text = "PT Sans Narrow"},
}
GudaPlates.fontOptions = fontOptions  -- Expose for Options module

-- Tank class detection for OTHER_TANK coloring
local TANK_CLASSES = {
    ["Warrior"] = true,
    ["Paladin"] = true,
    ["Druid"] = true,
	["Shaman"] = true,
}

-- Helper function to check if a unit is a tank class
local function IsTankClass(unit)
    if not unit or not UnitExists(unit) then return false end
    local _, class = UnitClass(unit)
    return class and TANK_CLASSES[class]
end

-- Helper function to check if we are in an instance (raid or dungeon)
local function IsInInstance()
    -- On Turtle WoW / Vanilla 1.12.1
    -- 1. Check if IsInInstance() exists (some clients backport it)
    if getglobal("IsInInstance") then
        local inInst, instType = getglobal("IsInInstance")()
        if inInst then return true end
    end

    -- 2. Check for raid or party and zone type
    local pvpType, isFFA, faction = GetZonePVPInfo()
    -- 'sanctuary' is usually used for safe zones in cities but also some instances in custom servers
    -- More importantly, check if we are in a raid/party and if the zone is an instance
    
    -- 3. Check if we have a raid/party and if GetRealZoneText() matches common instance names
    -- but a better way in 1.12.1 is checking if the world map is unavailable or using specific zone checks
    
    -- For Turtle WoW specifically, many people use GetRealZoneText and compare with known instances
    -- but we can use a simpler heuristic: if we are in a raid, we are likely in an instance or world boss.
    -- The requirement says "raid or dungeon".
    
    -- Let's use a more robust check for 1.12.1
    local zone = GetRealZoneText()
    if not zone or zone == "" then return false end
    
    -- Instances usually have a specific map ID or are not on continents
    -- In 1.12.1, we can't easily get MapID, but we can check if we're in a party/raid 
    -- and if the zone is NOT one of the major continents.
    
    -- Turtle WoW uses a backported IsInInstance if I'm not mistaken.
    -- If not, checking for raid status is a common fallback for "raid or dungeon" 
    -- because you're almost always in a party/raid in those.
    if UnitInRaid("player") or GetNumPartyMembers() > 0 then
        -- If in a group, check if we are in a known non-instance zone
        local isContinent = (zone == "Azeroth" or zone == "Kalimdor" or zone == "Eastern Kingdoms" or zone == "Stranglethorn Vale" or zone == "Tanaris") -- etc
        if not isContinent then
            -- This is still a bit weak, but better than nothing.
            -- Actually, let's just trust IsInInstance() if it exists.
        end
    end
    
    return false 
end

-- Helper function to check if a unit is in the player's group (player, party, or raid)
local function IsInPlayerGroup(unit)
    if not unit or not UnitExists(unit) then return false end
    -- Check if it's the player
    if UnitIsUnit(unit, "player") then return true end
    -- Check party members (party1-4)
    for i = 1, 4 do
        if UnitIsUnit(unit, "party" .. i) then return true end
    end
    -- Check raid members (raid1-40)
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

-- Load spell database if available
local SpellDB = GudaPlates_SpellDB

-- Verify SpellDB loaded correctly
if not SpellDB then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[GudaPlates]|r ERROR: SpellDB failed to load!")
end

-- Melee crit tracker for Deep Wound heuristic
-- Stores recent melee crits: recentMeleeCrits[targetName] = timestamp
local recentMeleeCrits = {}
GudaPlates.recentMeleeCrits = recentMeleeCrits  -- Expose for CombatLog module
-- Melee hit tracker for procs (Vindication)
local recentMeleeHits = {}
GudaPlates.recentMeleeHits = recentMeleeHits  -- Expose for CombatLog module

-- ============================================
-- SPELL CAST HOOKS (ShaguTweaks-style)
-- Detects when player casts spells to track debuff durations with correct rank
-- ============================================

-- Helper: Extract rank number from rank string like "Rank 2" (Lua 5.0 compatible)
local function GetRankNumber(rankStr)
	if not rankStr then return 0 end
	-- Lua 5.0 uses string_gfind instead of string.match
	for num in string_gfind(rankStr, "(%d+)") do
		return tonumber(num) or 0
	end
	return 0
end

-- Helper: Get spell name and rank from spellbook by ID
local function GetSpellInfoFromBook(spellId, bookType)
	local name, rank = GetSpellName(spellId, bookType)
	return name, GetRankNumber(rank)
end

-- Helper: Get spell name and rank from spell name string (e.g., "Rend(Rank 2)")
local function ParseSpellName(spellString)
	if not spellString then return nil, 0 end
	-- Try to match "SpellName(Rank X)" format (Lua 5.0 compatible)
	for name, rank in string_gfind(spellString, "^(.+)%(Rank (%d+)%)$") do
		return name, tonumber(rank) or 0
	end
	-- No rank specified, just spell name
	return spellString, 0
end

-- Strip rank suffix from spell name (for combat log parsing)
-- "Rend (Rank 2)" -> "Rend", rank 2
-- "Deadly Poison II" -> "Deadly Poison", rank 2
-- "Rend" -> "Rend", rank 0
local function StripSpellRank(spellString)
	if not spellString then return nil, 0 end
	-- Match "SpellName (Rank X)" with space before parenthesis
	for name, rank in string_gfind(spellString, "^(.+) %(Rank (%d+)%)$") do
		return name, tonumber(rank) or 0
	end
	-- Also try without space
	for name, rank in string_gfind(spellString, "^(.+)%(Rank (%d+)%)$") do
		return name, tonumber(rank) or 0
	end
	
	-- Match Roman numerals: II, III, IV, V, VI
	for name, rank in string_gfind(spellString, "^(.+) (VI)$") do return name, 6 end
	for name, rank in string_gfind(spellString, "^(.+) (V)$") do return name, 5 end
	for name, rank in string_gfind(spellString, "^(.+) (IV)$") do return name, 4 end
	for name, rank in string_gfind(spellString, "^(.+) (III)$") do return name, 3 end
	for name, rank in string_gfind(spellString, "^(.+) (II)$") do return name, 2 end

	return spellString, 0
end

-- Hook original CastSpell (ShaguPlates-style)
local Original_CastSpell = CastSpell
CastSpell = function(spellId, bookType)
	if SpellDB and spellId and bookType then
		local spellName, rank = GetSpellName(spellId, bookType)
		if spellName and UnitExists("target") and UnitCanAttack("player", "target") then
			local targetName = UnitName("target")
			local targetLevel = UnitLevel("target") or 0
			local duration = SpellDB:GetDuration(spellName, rank)
			if duration and duration > 0 then
				SpellDB:AddPending(targetName, targetLevel, spellName, duration)
			end
		end
	end
	return Original_CastSpell(spellId, bookType)
end

-- Hook original CastSpellByName (ShaguPlates-style)
local Original_CastSpellByName = CastSpellByName
CastSpellByName = function(spellString, onSelf)
	if SpellDB and spellString then
		local spellName, rank = ParseSpellName(spellString)
		if spellName and UnitExists("target") and UnitCanAttack("player", "target") then
			local targetName = UnitName("target")
			local targetLevel = UnitLevel("target") or 0
			local duration = SpellDB:GetDuration(spellName, rank)
			if duration and duration > 0 then
				SpellDB:AddPending(targetName, targetLevel, spellName, duration)
			end
		end
	end
	return Original_CastSpellByName(spellString, onSelf)
end

-- Hook UseAction (for action bar clicks) (ShaguPlates-style)
local Original_UseAction = UseAction
UseAction = function(slot, checkCursor, onSelf)
	if SpellDB and slot then
		local actionTexture = GetActionTexture(slot)
		if GetActionText(slot) == nil and actionTexture ~= nil then
			local spellName, rank = SpellDB:ScanAction(slot)
			if spellName then
				-- Cache texture -> spell name for debuff display lookup
				if SpellDB.textureToSpell then
					SpellDB.textureToSpell[actionTexture] = spellName
				end
				if UnitExists("target") then
					local targetName = UnitName("target")
					local targetLevel = UnitLevel("target") or 0
					local duration = SpellDB:GetDuration(spellName, rank)
					if duration and duration > 0 then
						SpellDB:AddPending(targetName, targetLevel, spellName, duration)
					end
				end
			end
		end
	end
	return Original_UseAction(slot, checkCursor, onSelf)
end

-- Initialize tooltip scanner for action bar scanning
if SpellDB then
	SpellDB:InitScanner()
end

local function IsNamePlate(frame)
    if not frame then return nil end
    local objType = frame:GetObjectType()
    if objType ~= "Frame" and objType ~= "Button" then return nil end

    -- Check ALL regions for the nameplate border texture
    local regions = { frame:GetRegions() }
    for _, r in ipairs(regions) do
        if r and r.GetObjectType and r:GetObjectType() == "Texture" then
            if r.GetTexture then
                local tex = r:GetTexture()
                if tex == "Interface\\Tooltips\\Nameplate-Border" then
                    return true
                end
            end
        end
    end
    return nil
end

local function DisableObject(object)
    if not object then return end
    if object.SetAlpha then object:SetAlpha(0) end
end

local function HideVisual(object)
    if not object then return end
    if object.SetAlpha then object:SetAlpha(0) end
    if object.GetObjectType then
        local otype = object:GetObjectType()
        if otype == "Texture" then
            object:SetTexture("")
        elseif otype == "FontString" then
            object:SetTextColor(0, 0, 0, 0)
        end
    end
end

local GudaPlates = CreateFrame("Frame", "GudaPlatesFrame", UIParent)
GudaPlates:RegisterEvent("PLAYER_ENTERING_WORLD")
GudaPlates:RegisterEvent("ADDON_LOADED")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_BUFF")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_TRADESKILLS")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE") -- Player's DoTs ticking (Deep Wound, etc.)
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_BUFF")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_BUFF")
GudaPlates:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
GudaPlates:RegisterEvent("CHAT_MSG_COMBAT_PARTY_HITS")
GudaPlates:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS")
GudaPlates:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS")
GudaPlates:RegisterEvent("CHAT_MSG_COMBAT_SELF_RANGED_HITS")
GudaPlates:RegisterEvent("CHAT_MSG_COMBAT_PARTY_RANGED_HITS")
-- SuperWoW cast event (provides exact GUID of caster)
GudaPlates:RegisterEvent("UNIT_CASTEVENT")
-- ShaguPlates-style events for debuff tracking
GudaPlates:RegisterEvent("SPELLCAST_STOP")
GudaPlates:RegisterEvent("CHAT_MSG_SPELL_FAILED_LOCALPLAYER")
GudaPlates:RegisterEvent("PLAYER_TARGET_CHANGED")
GudaPlates:RegisterEvent("UNIT_AURA")
GudaPlates:RegisterEvent("PARTY_MEMBERS_CHANGED")
GudaPlates:RegisterEvent("RAID_ROSTER_UPDATE")

-- Patterns for removing pending spells (ShaguPlates-style)
local REMOVE_PENDING_PATTERNS = {
	SPELLIMMUNESELFOTHER or "%s is immune to your %s.",
	IMMUNEDAMAGECLASSSELFOTHER or "%s is immune to your %s damage.",
	SPELLMISSSELFOTHER or "Your %s missed %s.",
	SPELLRESISTSELFOTHER or "Your %s was resisted by %s.",
	SPELLEVADEDSELFOTHER or "Your %s was evaded by %s.",
	SPELLDODGEDSELFOTHER or "Your %s was dodged by %s.",
	SPELLDEFLECTEDSELFOTHER or "Your %s was deflected by %s.",
	SPELLREFLECTSELFOTHER or "Your %s was reflected back by %s.",
	SPELLPARRIEDSELFOTHER or "Your %s was parried by %s.",
	SPELLLOGABSORBSELFOTHER or "Your %s is absorbed by %s.",
}

local function UpdateNamePlateDimensions(frame)
    local nameplate = frame.nameplate
    if not nameplate then return end

    -- Use cached unit type if available, otherwise calculate
    local isFriendly = nameplate.cachedIsFriendly
    if isFriendly == nil then
        local r, g, b = nameplate.original.healthbar:GetStatusBarColor()
        local isHostile = r > 0.9 and g < 0.2 and b < 0.2
        local isNeutral = r > 0.9 and g > 0.9 and b < 0.2
        isFriendly = not isHostile and not isNeutral
    end

    local hHeight, hWidth, hFontSize, hTextPos, lFontSize, nFontSize
    if isFriendly then
        hHeight = Settings.friendHealthbarHeight
        hWidth = Settings.friendHealthbarWidth
        hFontSize = Settings.friendHealthFontSize
        hTextPos = Settings.friendHealthTextPosition
        lFontSize = Settings.friendLevelFontSize
        nFontSize = Settings.friendNameFontSize
    else
        hHeight = Settings.healthbarHeight
        hWidth = Settings.healthbarWidth
        hFontSize = Settings.healthFontSize
        hTextPos = Settings.healthTextPosition
        lFontSize = Settings.levelFontSize
        nFontSize = Settings.nameFontSize
    end

    nameplate.health:SetHeight(hHeight)
    nameplate.health:SetWidth(hWidth)
    
    -- Update castbar dimensions
    local cHeight, cIndependent, cWidth
    if isFriendly then
        cHeight = Settings.friendCastbarHeight
        cIndependent = Settings.friendCastbarIndependent
        cWidth = Settings.friendCastbarWidth
    else
        cHeight = Settings.castbarHeight
        cIndependent = Settings.castbarIndependent
        cWidth = Settings.castbarWidth
    end

    nameplate.castbar:SetHeight(cHeight)
    if cIndependent then
        nameplate.castbar:SetWidth(cWidth)
    else
        nameplate.castbar:SetWidth(hWidth)
    end
    
    -- Update castbar icon size (will be properly positioned in UpdateNamePlate when casting)
    local iconSize
    if cIndependent and cWidth > hWidth then
        -- Castbar wider: icon aligns with healthbar (+ manabar if visible)
        if nameplate.mana and nameplate.mana:IsShown() then
            iconSize = hHeight + Settings.manabarHeight
        else
            iconSize = hHeight
        end
    else
        -- Normal: icon spans healthbar + castbar (+ manabar if visible)
        if nameplate.mana and nameplate.mana:IsShown() then
            iconSize = hHeight + cHeight + Settings.manabarHeight
        else
            iconSize = hHeight + cHeight
        end
    end
    nameplate.castbar.icon:SetWidth(iconSize)
    nameplate.castbar.icon:SetHeight(iconSize)
    
    -- Update mana bar dimensions and text position
    if nameplate.mana then
        local mManaHeight, mManaTextPos
        if isFriendly then
            mManaHeight = Settings.friendManabarHeight
            mManaTextPos = Settings.friendManaTextPosition
        else
            mManaHeight = Settings.manabarHeight
            mManaTextPos = Settings.manaTextPosition
        end
        
        nameplate.mana:SetWidth(hWidth)
        nameplate.mana:SetHeight(mManaHeight)
        
        -- Update mana text position
        if nameplate.mana.text then
            nameplate.mana.text:ClearAllPoints()
            if mManaTextPos == "LEFT" then
                nameplate.mana.text:SetPoint("LEFT", nameplate.mana, "LEFT", 2, 0)
                nameplate.mana.text:SetJustifyH("LEFT")
            elseif mManaTextPos == "RIGHT" then
                nameplate.mana.text:SetPoint("RIGHT", nameplate.mana, "RIGHT", -2, 0)
                nameplate.mana.text:SetJustifyH("RIGHT")
            else
                nameplate.mana.text:SetPoint("CENTER", nameplate.mana, "CENTER", 0, 0)
                nameplate.mana.text:SetJustifyH("CENTER")
            end
        end
    end

    local healthFont, _, healthFlags = nameplate.healthtext:GetFont()
    nameplate.healthtext:SetFont(healthFont, hFontSize, healthFlags)
    
    -- Update health text position
    nameplate.healthtext:ClearAllPoints()
    if hTextPos == "LEFT" then
        nameplate.healthtext:SetPoint("LEFT", nameplate.health, "LEFT", 2, 0)
        nameplate.healthtext:SetJustifyH("LEFT")
    elseif hTextPos == "RIGHT" then
        nameplate.healthtext:SetPoint("RIGHT", nameplate.health, "RIGHT", -2, 0)
        nameplate.healthtext:SetJustifyH("RIGHT")
    else
        nameplate.healthtext:SetPoint("CENTER", nameplate.health, "CENTER", 0, 0)
        nameplate.healthtext:SetJustifyH("CENTER")
    end

    -- Apply font from settings
    nameplate.level:SetFont(Settings.textFont, lFontSize, "OUTLINE")
    nameplate.name:SetFont(Settings.textFont, nFontSize, "OUTLINE")
    nameplate.healthtext:SetFont(Settings.textFont, hFontSize, "OUTLINE")
    if nameplate.mana and nameplate.mana.text then
        nameplate.mana.text:SetFont(Settings.textFont, 7, "OUTLINE")
    end
    if nameplate.castbar then
        nameplate.castbar.text:SetFont(Settings.textFont, 8, "OUTLINE")
        nameplate.castbar.timer:SetFont(Settings.textFont, 8, "OUTLINE")
    end
    -- Update debuff fonts
    if nameplate.debuffs then
        for i = 1, GudaPlates_Debuffs:GetMaxDebuffs() do
            if nameplate.debuffs[i] then
                nameplate.debuffs[i].cd:SetFont(Settings.textFont, 10, "OUTLINE")
                nameplate.debuffs[i].count:SetFont(Settings.textFont, 9, "OUTLINE")
            end
        end
    end

    -- Apply text colors from settings
    nameplate.name:SetTextColor(Settings.nameColor[1], Settings.nameColor[2], Settings.nameColor[3], Settings.nameColor[4])
    nameplate.level:SetTextColor(Settings.levelColor[1], Settings.levelColor[2], Settings.levelColor[3], Settings.levelColor[4])
    nameplate.healthtext:SetTextColor(Settings.healthTextColor[1], Settings.healthTextColor[2], Settings.healthTextColor[3], Settings.healthTextColor[4])
    if nameplate.mana and nameplate.mana.text then
        nameplate.mana.text:SetTextColor(Settings.manaTextColor[1], Settings.manaTextColor[2], Settings.manaTextColor[3], Settings.manaTextColor[4])
    end
    
    -- Apply castbar color
    if nameplate.castbar then
        nameplate.castbar:SetStatusBarColor(Settings.castbarColor[1], Settings.castbarColor[2], Settings.castbarColor[3], Settings.castbarColor[4])
    end

    -- Update Raid Icon position
    if nameplate.original.raidicon then
        nameplate.original.raidicon:ClearAllPoints()
        if Settings.raidIconPosition == "LEFT" then
            nameplate.original.raidicon:SetPoint("RIGHT", nameplate.health, "LEFT", -5, 0)
        else
            nameplate.original.raidicon:SetPoint("LEFT", nameplate.health, "RIGHT", 5, 0)
        end
    end
    if frame.raidicon and frame.raidicon ~= nameplate.original.raidicon then
        frame.raidicon:ClearAllPoints()
        if Settings.raidIconPosition == "LEFT" then
            frame.raidicon:SetPoint("RIGHT", nameplate.health, "LEFT", -5, 0)
        else
            frame.raidicon:SetPoint("LEFT", nameplate.health, "RIGHT", 5, 0)
        end
    end

    -- Update Name and Debuff positions
    nameplate.name:ClearAllPoints()
    
    -- Update mana bar position based on swap setting
    if nameplate.mana then
        nameplate.mana:ClearAllPoints()
    end
    
    if Settings.swapNameDebuff then
        -- Swapped: Name above, Debuffs below healthbar, Mana bar below healthbar
        nameplate.name:SetPoint("BOTTOM", nameplate.health, "TOP", 0, 6)
        
        -- Mana bar below healthbar
        if nameplate.mana then
            nameplate.mana:SetPoint("TOP", nameplate.health, "BOTTOM", 0, 0)
        end
        
        -- Debuffs below mana bar (or healthbar if no mana)
        for i = 1, GudaPlates_Debuffs:GetMaxDebuffs() do
            nameplate.debuffs[i]:ClearAllPoints()
            if i == 1 then
                if nameplate.mana and nameplate.mana:IsShown() then
                    nameplate.debuffs[i]:SetPoint("TOPLEFT", nameplate.mana, "BOTTOMLEFT", 0, -1)
                else
                    nameplate.debuffs[i]:SetPoint("TOPLEFT", nameplate.health, "BOTTOMLEFT", 0, -1)
                end
            else
                nameplate.debuffs[i]:SetPoint("LEFT", nameplate.debuffs[i-1], "RIGHT", 1, 0)
            end
        end
        
        -- Castbar above healthbar (no gap), align based on raid icon position when wider
        nameplate.castbar:ClearAllPoints()
        if Settings.castbarIndependent and Settings.castbarWidth > Settings.healthbarWidth then
            if Settings.raidIconPosition == "RIGHT" then
                nameplate.castbar:SetPoint("BOTTOMRIGHT", nameplate.health, "TOPRIGHT", 0, 2)
            else
                nameplate.castbar:SetPoint("BOTTOMLEFT", nameplate.health, "TOPLEFT", 0, 2)
            end
        else
            nameplate.castbar:SetPoint("BOTTOM", nameplate.health, "TOP", 0, 2)
        end
        
        -- Level above healthbar (swapped mode - mana is below)
        nameplate.level:ClearAllPoints()
        nameplate.level:SetPoint("BOTTOMRIGHT", nameplate.health, "TOPRIGHT", 0, 2)
    else
        -- Default: Name below, Mana bar above healthbar, Debuffs above mana bar
        nameplate.name:SetPoint("TOP", nameplate.health, "BOTTOM", 0, -6)
        
        -- Mana bar above healthbar
        if nameplate.mana then
            nameplate.mana:SetPoint("BOTTOM", nameplate.health, "TOP", 0, 0)
        end
        
        -- Level above mana bar (or healthbar if no mana)
        nameplate.level:ClearAllPoints()
        if nameplate.mana and nameplate.mana:IsShown() then
            nameplate.level:SetPoint("BOTTOMRIGHT", nameplate.mana, "TOPRIGHT", 0, 2)
        else
            nameplate.level:SetPoint("BOTTOMRIGHT", nameplate.health, "TOPRIGHT", 0, 2)
        end
        
        -- Debuffs above mana bar (or healthbar if no mana)
        for i = 1, GudaPlates_Debuffs:GetMaxDebuffs() do
            nameplate.debuffs[i]:ClearAllPoints()
            if i == 1 then
                if nameplate.mana and nameplate.mana:IsShown() then
                    nameplate.debuffs[i]:SetPoint("BOTTOMLEFT", nameplate.mana, "TOPLEFT", 0, 1)
                else
                    nameplate.debuffs[i]:SetPoint("BOTTOMLEFT", nameplate.health, "TOPLEFT", 0, 1)
                end
            else
                nameplate.debuffs[i]:SetPoint("LEFT", nameplate.debuffs[i-1], "RIGHT", 1, 0)
            end
        end
        
        -- Castbar below healthbar (default mode), align based on raid icon position when wider
        nameplate.castbar:ClearAllPoints()
        if Settings.castbarIndependent and Settings.castbarWidth > Settings.healthbarWidth then
            if Settings.raidIconPosition == "RIGHT" then
                nameplate.castbar:SetPoint("TOPRIGHT", nameplate.health, "BOTTOMRIGHT", 0, -2)
            else
                nameplate.castbar:SetPoint("TOPLEFT", nameplate.health, "BOTTOMLEFT", 0, -2)
            end
        else
            nameplate.castbar:SetPoint("TOP", nameplate.health, "BOTTOM", 0, -2)
        end
    end

    -- When stacking, we also need to update the parent frame size
    -- so the game's stacking logic uses the new dimensions
    if not nameplateOverlap then
        local npWidth = Settings.healthbarWidth * UIParent:GetScale()
        local npHeight = (Settings.healthbarHeight + 20) * UIParent:GetScale() -- Added space for name/level
        frame:SetWidth(npWidth)
        frame:SetHeight(npHeight)
        nameplate:SetAllPoints(frame)
    else
    -- In overlap mode, frame is 1x1 but nameplate should be clickable
        nameplate:ClearAllPoints()
        nameplate:SetPoint("CENTER", frame, "CENTER", 0, 0)
        nameplate:SetWidth(Settings.healthbarWidth)
        nameplate:SetHeight(Settings.healthbarHeight + 20)
    end
end
GudaPlates.UpdateNamePlateDimensions = UpdateNamePlateDimensions  -- Expose for Options module


local function HandleNamePlate(frame)
    if not frame then return end
    if registry[frame] then return end

    platecount = platecount + 1
    local platename = "GudaPlate" .. platecount

    local nameplate = CreateFrame("Button", platename, frame)
    nameplate.platename = platename
    nameplate:EnableMouse(false)
    nameplate.parent = frame
    nameplate.original = {}

    -- Click handler for overlap mode - forward clicks to parent
    nameplate:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    nameplate:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            this.parent:Click()
        elseif arg1 == "RightButton" then
            this.parent:Click()
        end
    end)

    -- Get healthbar - ShaguTweaks sets frame.healthbar directly
    if frame.healthbar then
        nameplate.original.healthbar = frame.healthbar
    else
        nameplate.original.healthbar = frame:GetChildren()
    end

    -- Find name and level from regions before hiding
    -- Get regions by index (vanilla nameplate order: border, glow, name, level, levelicon, raidicon)
    -- Cache these for performance (avoid creating tables every frame in UpdateNamePlate)
    local regions = {frame:GetRegions()}
    nameplate.cachedRegions = regions
    nameplate.cachedChildren = {frame:GetChildren()}

    for i, region in ipairs(regions) do
        if region and region.GetObjectType then
            local rtype = region:GetObjectType()
            if i == 2 then
            -- 2nd region is glow texture
                nameplate.original.glow = region
            elseif i == 6 then
            -- 6th region is raid icon
                nameplate.original.raidicon = region
            elseif rtype == "FontString" then
                local text = region:GetText()
                if text then
                    if tonumber(text) then
                        nameplate.original.level = region
                    else
                        nameplate.original.name = region
                    end
                end
            end
        end
    end

    -- Also check frame.new (ShaguTweaks creates this)
    if frame.new then
        nameplate.cachedNewRegions = {frame.new:GetRegions()}
        for _, region in ipairs(nameplate.cachedNewRegions) do
            if region and region.GetObjectType then
                local rtype = region:GetObjectType()
                if rtype == "FontString" then
                    local text = region:GetText()
                    if text and not tonumber(text) and not nameplate.original.name then
                        nameplate.original.name = region
                    end
                end
            end
        end
    end

    nameplate:SetAllPoints(frame)
    nameplate:SetFrameStrata("BACKGROUND")
    nameplate:SetFrameLevel(frame:GetFrameLevel() + 10)

    -- Plater-style health bar with higher frame level
    nameplate.health = CreateFrame("StatusBar", nil, nameplate)
    nameplate.health:SetFrameLevel(frame:GetFrameLevel() + 11)
    nameplate.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    nameplate.health:SetHeight(Settings.healthbarHeight)
    nameplate.health:SetWidth(Settings.healthbarWidth)
    nameplate.health:SetPoint("CENTER", nameplate, "CENTER", 0, 0)

    -- Dark background
    nameplate.health.bg = nameplate.health:CreateTexture(nil, "BACKGROUND")
    nameplate.health.bg:SetTexture(0, 0, 0, 0.8)
    nameplate.health.bg:SetAllPoints()

    -- Border
    nameplate.health.border = nameplate.health:CreateTexture(nil, "OVERLAY")
    nameplate.health.border:SetTexture(0, 0, 0, 1)
    nameplate.health.border:SetPoint("TOPLEFT", nameplate.health, "TOPLEFT", -1, 1)
    nameplate.health.border:SetPoint("BOTTOMRIGHT", nameplate.health, "BOTTOMRIGHT", 1, -1)
    nameplate.health.border:SetDrawLayer("BACKGROUND", -1)

    -- Reparent original raid icon to our health bar
    if nameplate.original.raidicon then
        nameplate.original.raidicon:SetParent(nameplate.health)
        nameplate.original.raidicon:ClearAllPoints()
        nameplate.original.raidicon:SetPoint("RIGHT", nameplate.health, "LEFT", -5, 0)
        nameplate.original.raidicon:SetWidth(24)
        nameplate.original.raidicon:SetHeight(24)
        nameplate.original.raidicon:SetDrawLayer("OVERLAY")
    end

    -- Also reparent ShaguTweaks raid icon if present (frame.raidicon)
    if frame.raidicon and frame.raidicon ~= nameplate.original.raidicon then
        frame.raidicon:SetParent(nameplate.health)
        frame.raidicon:ClearAllPoints()
        frame.raidicon:SetPoint("RIGHT", nameplate.health, "LEFT", -5, 0)
        frame.raidicon:SetWidth(24)
        frame.raidicon:SetHeight(24)
        frame.raidicon:SetDrawLayer("OVERLAY")
    end

    -- Target highlight brackets (square bracket shape [ ])
    -- Left bracket [
    nameplate.targetBracket = {}
    
    nameplate.targetBracket.leftVert = nameplate.health:CreateTexture(nil, "OVERLAY")
    nameplate.targetBracket.leftVert:SetTexture(1, 1, 1, 0.5)
    nameplate.targetBracket.leftVert:SetWidth(1)
    nameplate.targetBracket.leftVert:Hide()
    
    nameplate.targetBracket.leftTop = nameplate.health:CreateTexture(nil, "OVERLAY")
    nameplate.targetBracket.leftTop:SetTexture(1, 1, 1, 0.5)
    nameplate.targetBracket.leftTop:SetHeight(1)
    nameplate.targetBracket.leftTop:SetWidth(6)
    nameplate.targetBracket.leftTop:Hide()
    
    nameplate.targetBracket.leftBottom = nameplate.health:CreateTexture(nil, "OVERLAY")
    nameplate.targetBracket.leftBottom:SetTexture(1, 1, 1, 0.5)
    nameplate.targetBracket.leftBottom:SetHeight(1)
    nameplate.targetBracket.leftBottom:SetWidth(6)
    nameplate.targetBracket.leftBottom:Hide()
    
    -- Right bracket ]
    nameplate.targetBracket.rightVert = nameplate.health:CreateTexture(nil, "OVERLAY")
    nameplate.targetBracket.rightVert:SetTexture(1, 1, 1, 0.5)
    nameplate.targetBracket.rightVert:SetWidth(1)
    nameplate.targetBracket.rightVert:Hide()
    
    nameplate.targetBracket.rightTop = nameplate.health:CreateTexture(nil, "OVERLAY")
    nameplate.targetBracket.rightTop:SetTexture(1, 1, 1, 0.5)
    nameplate.targetBracket.rightTop:SetHeight(1)
    nameplate.targetBracket.rightTop:SetWidth(6)
    nameplate.targetBracket.rightTop:Hide()
    
    nameplate.targetBracket.rightBottom = nameplate.health:CreateTexture(nil, "OVERLAY")
    nameplate.targetBracket.rightBottom:SetTexture(1, 1, 1, 0.5)
    nameplate.targetBracket.rightBottom:SetHeight(1)
    nameplate.targetBracket.rightBottom:SetWidth(6)
    nameplate.targetBracket.rightBottom:Hide()

    -- Target glow effect (Dragonflight3-style with top and bottom glow)
    nameplate.targetGlowTop = nameplate:CreateTexture(nil, "BACKGROUND")
    nameplate.targetGlowTop:SetTexture("Interface\\AddOns\\-Dragonflight3\\media\\tex\\generic\\nocontrol_glow.blp")
    nameplate.targetGlowTop:SetWidth(Settings.healthbarWidth)
    nameplate.targetGlowTop:SetHeight(20)
    nameplate.targetGlowTop:SetPoint("BOTTOM", nameplate.health, "TOP", 0, 0)
    nameplate.targetGlowTop:SetVertexColor(Settings.targetGlowColor[1], Settings.targetGlowColor[2], Settings.targetGlowColor[3], 0.4)
    nameplate.targetGlowTop:Hide()

    nameplate.targetGlowBottom = nameplate:CreateTexture(nil, "BACKGROUND")
    nameplate.targetGlowBottom:SetTexture("Interface\\AddOns\\-Dragonflight3\\media\\tex\\generic\\nocontrol_glow.blp")
    nameplate.targetGlowBottom:SetTexCoord(0, 1, 1, 0)  -- Flip vertically
    nameplate.targetGlowBottom:SetWidth(Settings.healthbarWidth)
    nameplate.targetGlowBottom:SetHeight(20)
    nameplate.targetGlowBottom:SetPoint("TOP", nameplate.health, "BOTTOM", 0, 0)
    nameplate.targetGlowBottom:SetVertexColor(Settings.targetGlowColor[1], Settings.targetGlowColor[2], Settings.targetGlowColor[3], 0.4)
    nameplate.targetGlowBottom:Hide()

    -- Name below the health bar (like in Plater)
    nameplate.name = nameplate:CreateFontString(nil, "OVERLAY")
    nameplate.name:SetFont(Settings.textFont, 9, "OUTLINE")
    nameplate.name:SetTextColor(Settings.nameColor[1], Settings.nameColor[2], Settings.nameColor[3], Settings.nameColor[4])
    nameplate.name:SetJustifyH("CENTER")

    -- Level above the health bar on the right
    nameplate.level = nameplate:CreateFontString(nil, "OVERLAY")
    nameplate.level:SetFont(Settings.textFont, 9, "OUTLINE")
    nameplate.level:SetPoint("BOTTOMRIGHT", nameplate.health, "TOPRIGHT", 0, 2)
    nameplate.level:SetTextColor(Settings.levelColor[1], Settings.levelColor[2], Settings.levelColor[3], Settings.levelColor[4])
    nameplate.level:SetJustifyH("RIGHT")

    -- Health text centered on bar
    nameplate.healthtext = nameplate.health:CreateFontString(nil, "OVERLAY")
    nameplate.healthtext:SetFont(Settings.textFont, 8, "OUTLINE")
    nameplate.healthtext:SetPoint("CENTER", nameplate.health, "CENTER", 0, 0)
    nameplate.healthtext:SetTextColor(Settings.healthTextColor[1], Settings.healthTextColor[2], Settings.healthTextColor[3], Settings.healthTextColor[4])

    -- Mana Bar below healthbar (optional, hidden by default)
    nameplate.mana = CreateFrame("StatusBar", nil, nameplate)
    nameplate.mana:SetFrameLevel(frame:GetFrameLevel() + 11)
    nameplate.mana:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    nameplate.mana:SetStatusBarColor(unpack(THREAT_COLORS.MANA_BAR))
    nameplate.mana:SetHeight(Settings.manabarHeight)
    nameplate.mana:SetWidth(Settings.healthbarWidth)
    nameplate.mana:SetPoint("TOP", nameplate.health, "BOTTOM", 0, 0)
    nameplate.mana:Hide()

    nameplate.mana.bg = nameplate.mana:CreateTexture(nil, "BACKGROUND")
    nameplate.mana.bg:SetTexture(0, 0, 0, 0.8)
    nameplate.mana.bg:SetAllPoints()

    nameplate.mana.border = nameplate.mana:CreateTexture(nil, "OVERLAY")
    nameplate.mana.border:SetTexture(0, 0, 0, 1)
    nameplate.mana.border:SetPoint("TOPLEFT", nameplate.mana, "TOPLEFT", -1, 1)
    nameplate.mana.border:SetPoint("BOTTOMRIGHT", nameplate.mana, "BOTTOMRIGHT", 1, -1)
    nameplate.mana.border:SetDrawLayer("BACKGROUND", -1)

    -- Mana text (position based on settings)
    nameplate.mana.text = nameplate.mana:CreateFontString(nil, "OVERLAY")
    nameplate.mana.text:SetFont(Settings.textFont, 7, "OUTLINE")
    nameplate.mana.text:SetTextColor(Settings.manaTextColor[1], Settings.manaTextColor[2], Settings.manaTextColor[3], Settings.manaTextColor[4])

    -- Cast Bar below the name
    nameplate.castbar = CreateFrame("StatusBar", nil, nameplate)
    nameplate.castbar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    nameplate.castbar:SetHeight(Settings.castbarHeight)
    nameplate.castbar:SetStatusBarColor(Settings.castbarColor[1], Settings.castbarColor[2], Settings.castbarColor[3], Settings.castbarColor[4])
    nameplate.castbar:Hide()

    nameplate.castbar.bg = nameplate.castbar:CreateTexture(nil, "BACKGROUND")
    nameplate.castbar.bg:SetTexture(0, 0, 0, 1.0)
    nameplate.castbar.bg:SetAllPoints()

    nameplate.castbar.border = nameplate.castbar:CreateTexture(nil, "OVERLAY")
    nameplate.castbar.border:SetTexture(0, 0, 0, 1)
    nameplate.castbar.border:SetPoint("TOPLEFT", nameplate.castbar, "TOPLEFT", -1, 1)
    nameplate.castbar.border:SetPoint("BOTTOMRIGHT", nameplate.castbar, "BOTTOMRIGHT", 1, -1)
    nameplate.castbar.border:SetDrawLayer("BACKGROUND", -1)

    nameplate.castbar.text = nameplate.castbar:CreateFontString(nil, "OVERLAY")
    nameplate.castbar.text:SetFont(Settings.textFont, 8, "OUTLINE")
    nameplate.castbar.text:SetPoint("LEFT", nameplate.castbar, "LEFT", 2, 0)
    nameplate.castbar.text:SetTextColor(1, 1, 1, 1)
    nameplate.castbar.text:SetJustifyH("LEFT")

    nameplate.castbar.timer = nameplate.castbar:CreateFontString(nil, "OVERLAY")
    nameplate.castbar.timer:SetFont(Settings.textFont, 8, "OUTLINE")
    nameplate.castbar.timer:SetPoint("RIGHT", nameplate.castbar, "RIGHT", -2, 0)
    nameplate.castbar.timer:SetTextColor(1, 1, 1, 1)
    nameplate.castbar.timer:SetJustifyH("RIGHT")

    nameplate.castbar.icon = nameplate.castbar:CreateTexture(nil, "OVERLAY")
    -- Icon size will be set dynamically based on healthbar + castbar height
    nameplate.castbar.icon:SetWidth(Settings.healthbarHeight + Settings.castbarHeight)
    nameplate.castbar.icon:SetHeight(Settings.healthbarHeight + Settings.castbarHeight)
    -- Position will be set dynamically based on raidIconPosition
    nameplate.castbar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    nameplate.castbar.icon.border = nameplate.castbar:CreateTexture(nil, "BACKGROUND")
    nameplate.castbar.icon.border:SetTexture(0, 0, 0, 1)
    nameplate.castbar.icon.border:SetPoint("TOPLEFT", nameplate.castbar.icon, "TOPLEFT", -1, 1)
    nameplate.castbar.icon.border:SetPoint("BOTTOMRIGHT", nameplate.castbar.icon, "BOTTOMRIGHT", 1, -1)

    -- Debuff icons
    if GudaPlates_Debuffs then
        GudaPlates_Debuffs:CreateDebuffFrames(nameplate)
    end

    UpdateNamePlateDimensions(frame)

    frame.nameplate = nameplate
    registry[frame] = nameplate

    --Print("Hooked: " .. platename)
end



local function UpdateNamePlate(frame)
    local nameplate = frame.nameplate
    if not nameplate then return end

    local original = nameplate.original
    if not original.healthbar then return end

    -- Critter filtering: Hide nameplates for critters/ambient mobs if setting is disabled
    if not Settings.showCritterNameplates then
        local isCritter = false

        -- Get unit info for critter detection
        local unitstr = nil
        if superwow_active and frame and frame.GetName then
            unitstr = frame:GetName(1)
        end

        -- Method 1: SuperWoW - use UnitCreatureType
        if unitstr and UnitCreatureType then
            local creatureType = UnitCreatureType(unitstr)
            if creatureType == "Critter" then
                isCritter = true
            end
        end

        -- Method 2: Fallback - detect neutral units with level 1 and very low HP (typical critters)
        if not isCritter and not unitstr then
            local r, g, b = original.healthbar:GetStatusBarColor()
            local isNeutral = r > 0.9 and g > 0.9 and b < 0.2

            if isNeutral then
                -- Check level
                local levelText = nil
                if original.level and original.level.GetText then
                    levelText = original.level:GetText()
                end
                if not levelText and frame.level and frame.level.GetText then
                    levelText = frame.level:GetText()
                end

                -- Check HP
                local hp = original.healthbar:GetValue() or 0
                local _, hpmax = original.healthbar:GetMinMaxValues()

                -- Critters are typically level 1 with very low max HP (under 100)
                if levelText == "1" and hpmax and hpmax > 0 and hpmax < 100 then
                    isCritter = true
                end
            end
        end

        -- Hide the nameplate if it's a critter
        if isCritter then
            nameplate:Hide()
            return
        end
    end

    -- Ensure nameplate is shown (in case it was hidden as a critter before)
    if not nameplate:IsShown() then
        nameplate:Show()
    end

    -- Hide ALL original elements every frame
    original.healthbar:SetStatusBarTexture("")
    original.healthbar:SetAlpha(0)

    -- Hide regions on main frame (but NOT the raid icon - it's reparented to us)
    -- Use cached regions to avoid creating new table every frame
    local cachedRegions = nameplate.cachedRegions
    if cachedRegions then
        for i, region in ipairs(cachedRegions) do
            if region and region.GetObjectType then
                local otype = region:GetObjectType()
                if otype == "Texture" then
                -- Skip raid icons - we reparented them
                    if region ~= nameplate.original.raidicon and region ~= frame.raidicon then
                        region:SetAlpha(0)
                    end
                elseif otype == "FontString" then
                    region:SetAlpha(0)
                end
            end
        end
    end

    -- Hide all other children frames (like Blizzard or other addon castbars)
    -- Use cached children to avoid creating new table every frame
    local cachedChildren = nameplate.cachedChildren
    if cachedChildren then
        for i, child in ipairs(cachedChildren) do
            if child and child ~= nameplate and child ~= original.healthbar then
            -- Only hide if it's not a known useful child (like the original castbar if we want it)
            -- ShaguPlates disables the original castbar explicitly.
                if child.SetAlpha then child:SetAlpha(0) end
                if child.Hide then child:Hide() end
            end
        end
    end

    -- Hide ShaguTweaks new frame elements if present (but not raidicon)
    if frame.new then
        frame.new:SetAlpha(0)
        -- Use cached new regions to avoid creating new table every frame
        local cachedNewRegions = nameplate.cachedNewRegions
        if cachedNewRegions then
            for _, region in ipairs(cachedNewRegions) do
                if region and region ~= frame.raidicon then
                    if region.SetTexture then region:SetTexture("") end
                    if region.SetAlpha then region:SetAlpha(0) end
                    if region.SetWidth and region.GetObjectType and region:GetObjectType() == "FontString" then
                        region:SetWidth(0.001)
                    end
                end
            end
        end
    end

    local hp = original.healthbar:GetValue() or 0
    local hpmin, hpmax = original.healthbar:GetMinMaxValues()
    if not hpmax or hpmax == 0 then hpmax = 1 end

    nameplate.health:SetMinMaxValues(hpmin, hpmax)
    nameplate.health:SetValue(hp)

    -- Cache unit type detection (hostile/neutral/friendly)
    -- Only recalculate if color changed to avoid redundant checks
    local r, g, b = original.healthbar:GetStatusBarColor()
    local isHostile, isNeutral, isFriendly

    -- Check if color changed since last frame
    local lastR, lastG, lastB = nameplate.lastColorR, nameplate.lastColorG, nameplate.lastColorB
    if r == lastR and g == lastG and b == lastB then
        -- Use cached values
        isHostile = nameplate.cachedIsHostile
        isNeutral = nameplate.cachedIsNeutral
        isFriendly = nameplate.cachedIsFriendly
    else
        -- Recalculate and cache
        isHostile = r > 0.9 and g < 0.2 and b < 0.2
        isNeutral = r > 0.9 and g > 0.9 and b < 0.2
        isFriendly = not isHostile and not isNeutral

        nameplate.lastColorR = r
        nameplate.lastColorG = g
        nameplate.lastColorB = b
        nameplate.cachedIsHostile = isHostile
        nameplate.cachedIsNeutral = isNeutral
        nameplate.cachedIsFriendly = isFriendly
    end

    -- Format health text based on settings
    local hpText = ""

    local hTextFormat
    if isFriendly then
        hTextFormat = Settings.friendHealthTextFormat
    else
        hTextFormat = Settings.healthTextFormat
    end

    if hTextFormat ~= 0 then
        local perc = (hp / hpmax) * 100
        local format = hTextFormat
        local name = ""
        if original.name and original.name.GetText then
            name = original.name:GetText() or ""
        end

        if format == 1 then
            -- Percent only
            hpText = string_format("%.0f%%", perc)
        elseif format == 2 then
            -- Current HP only
            if hp > 1000 then
                hpText = string_format("%.1fK", hp / 1000)
            else
                hpText = string_format("%d", hp)
            end
        elseif format == 3 then
            -- Health (percentage%)
            if hp > 1000 then
                hpText = string_format("%.1fK (%.0f%%)", hp / 1000, perc)
            else
                hpText = string_format("%d (%.0f%%)", hp, perc)
            end
        elseif format == 4 then
            -- Current HP - Max HP
            if hpmax > 1000 then
                hpText = string_format("%.1fK - %.1fK", hp / 1000, hpmax / 1000)
            else
                hpText = string_format("%d - %d", hp, hpmax)
            end
        elseif format == 5 then
            -- Current HP - Max HP (Percentage %)
            if hpmax > 1000 then
                hpText = string_format("%.1fK - %.1fK (%.0f%%)", hp / 1000, hpmax / 1000, perc)
            else
                hpText = string_format("%d - %d (%.0f%%)", hp, hpmax, perc)
            end
        elseif format == 6 then
            -- Name - %
            hpText = string_format("%s - %.0f%%", name, perc)
        elseif format == 7 then
            -- Name - HP(%)
            local hpStr
            if hp > 1000 then
                hpStr = string_format("%.1fK", hp / 1000)
            else
                hpStr = string_format("%d", hp)
            end
            hpText = string_format("%s - %s (%.0f%%)", name, hpStr, perc)
        elseif format == 8 then
            -- Name
            hpText = name
        end
    end
    nameplate.healthtext:SetText(hpText)

    -- Apply name color if Name-integrated format is selected, otherwise use health text color
    if hTextFormat >= 6 then
        nameplate.healthtext:SetTextColor(Settings.nameColor[1], Settings.nameColor[2], Settings.nameColor[3], Settings.nameColor[4])
    else
        nameplate.healthtext:SetTextColor(Settings.healthTextColor[1], Settings.healthTextColor[2], Settings.healthTextColor[3], Settings.healthTextColor[4])
    end

    -- Hide name if Name-integrated format is selected
    if hTextFormat >= 6 then
        nameplate.name:Hide()
    else
        nameplate.name:Show()
    end

    -- Update level from original or ShaguTweaks
    local levelText = nil
    if original.level and original.level.GetText then
        levelText = original.level:GetText()
    end
    -- ShaguTweaks stores level on frame.level
    if not levelText and frame.level and frame.level.GetText then
        levelText = frame.level:GetText()
    end
    if levelText then
        nameplate.level:SetText(levelText)
    end

    -- Plater-style colors with threat support
    -- Note: r, g, b and isHostile/isNeutral/isFriendly are cached above

    -- Get unit string for threat check
    local unitstr = nil
    local plateName = nil
    if original.name and original.name.GetText then
        plateName = original.name:GetText()
    end

    -- SuperWoW: get GUID for unit from the parent nameplate frame
    if superwow_active and frame and frame.GetName then
        unitstr = frame:GetName(1)
    end

    -- Check if this mob is attacking the player (mob→player targeting)
    local isAttackingPlayer = false
    local hasValidGUID = unitstr and unitstr ~= ""

    -- Check original glow texture (shows when having aggro in Vanilla)
    local hasAggroGlow = false
    if original.glow and original.glow.IsShown and original.glow:IsShown() then
        hasAggroGlow = true
    end

    -- SuperWoW method: use GUID to check mob's target directly (real-time, per-plate)
    if hasValidGUID then
        local mobTarget = unitstr .. "target"
        -- This check works regardless of what player is targeting
        if UnitIsUnit(mobTarget, "player") then
            isAttackingPlayer = true
            -- Store on nameplate object for this specific plate
            nameplate.isAttackingPlayer = true
            nameplate.lastAttackTime = GetTime()
        elseif UnitExists(mobTarget) then
            -- Mob has a target and it's NOT the player - clear stickiness immediately
            isAttackingPlayer = false
            nameplate.isAttackingPlayer = false
            nameplate.lastAttackTime = nil
        else
        -- Check if this specific plate was recently attacking
            if nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime < 2) then
                isAttackingPlayer = true
            else
                nameplate.isAttackingPlayer = false
            end
        end
    else
    -- Fallback: use name-based tracking (has same-name mob limitation)
        if plateName then
        -- Use original glow texture as primary indicator if available
        -- Glow usually appears when unit is in combat and has threat
            if hasAggroGlow then
                isAttackingPlayer = true
                nameplate.isAttackingPlayer = true
                nameplate.lastAttackTime = GetTime()
            end

            -- Check if this specific plate was recently confirmed attacking
            if not isAttackingPlayer and nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime < 2) then
                isAttackingPlayer = true
            end

            -- If we're targeting this mob, verify and update tracking
            if UnitExists("target") and UnitName("target") == plateName then
            -- Check if target is actually this nameplate (alpha check is a common vanilla trick)
            -- Usually target nameplate has alpha 1.0, others might be 0.x
            -- Note: GetAlpha might be affected by UI modifications, but 1.0 is default for target
                if frame:GetAlpha() > 0.9 then
                    if UnitExists("targettarget") and UnitIsUnit("targettarget", "player") then
                        nameplate.isAttackingPlayer = true
                        nameplate.lastAttackTime = GetTime()
                        isAttackingPlayer = true
                    elseif UnitExists("targettarget") then
                    -- Mob is targeting someone else, clear tracking immediately
                        nameplate.isAttackingPlayer = false
                        nameplate.lastAttackTime = nil
                        isAttackingPlayer = false
                    end
                end
            end

            -- Expire old entries after 2 seconds without refresh
            if nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime > 2) then
                nameplate.isAttackingPlayer = false
                nameplate.lastAttackTime = nil
                isAttackingPlayer = false
            end
        end
    end

    -- TWThreat: get threat information
    local threatPct = 0
    local isTanking = false
    local threatStatus = 0

    if twthreat_active and unitstr and isHostile then
    -- UnitThreat returns: isTanking, status, threatpct, rawthreatpct, threatvalue
        local tanking, status, pct = UnitThreat("player", unitstr)
        if tanking ~= nil then
            isTanking = tanking
            threatStatus = status or 0
            threatPct = pct or 0
        end
    end

    -- Determine color based on role and threat
    if isFriendly then
        -- Only override to our custom green if it was standard green or blue
        if (r < 0.2 and g > 0.9 and b < 0.2) or (r < 0.2 and g < 0.2 and b > 0.9) then
            nameplate.health:SetStatusBarColor(0.27, 0.63, 0.27, 1)
        else
            -- Keep original color (e.g. class colors)
            nameplate.health:SetStatusBarColor(r, g, b, 1)
        end
    else
        -- Hostile or Neutral
        -- Check if mob is in combat (has a target)
        local mobInCombat = false
        local mobTargetUnit = nil

        if hasValidGUID then
            mobTargetUnit = unitstr .. "target"
            mobInCombat = UnitExists(mobTargetUnit)
        else
        -- Fallback: assume in combat if attacking player or we have threat data or has glow
            mobInCombat = isAttackingPlayer or (twthreat_active and threatPct > 0) or hasAggroGlow
            -- For fallback, use targettarget if we're targeting this mob
            if plateName and UnitExists("target") and UnitName("target") == plateName and frame:GetAlpha() > 0.9 then
                mobTargetUnit = "targettarget"
            end
        end

        -- Check if mob is tapped by others
        local isTappedByOthers = false
        
        -- Requirement: In instances, ignore tapping coloring
        local inInstance = IsInInstance()
        
        if not inInstance then
            -- 1. Check original color for gray (tapped)
            -- Blizzard gray for tapped is (0.5, 0.5, 0.5)
            if r > 0.4 and r < 0.6 and g > 0.4 and g < 0.6 and b > 0.4 and b < 0.6 then
                isTappedByOthers = true
            end

            -- 2. Use API for 100% accuracy if unit is available
            local unitForAPI = nil
            if hasValidGUID then
                unitForAPI = unitstr
            elseif UnitExists("target") and UnitName("target") == plateName and frame:GetAlpha() > 0.9 then
                unitForAPI = "target"
            end

            if not isTappedByOthers and unitForAPI then
                if UnitIsTapped(unitForAPI) and not UnitIsTappedByPlayer(unitForAPI) then
                    -- Double check if the mob is attacking someone in our group (excluding player)
                    -- (Fixes cases where joining a group mid-combat doesn't update UnitIsTappedByPlayer immediately)
                    local isMobTargetingGroupMate = false
                    local apiTarget = unitForAPI .. "target"
                    if UnitExists(apiTarget) and not UnitIsUnit(apiTarget, "player") then
                        isMobTargetingGroupMate = IsInPlayerGroup(apiTarget)
                    end
                    
                    if not isMobTargetingGroupMate then
                        isTappedByOthers = true
                    end
                end
            end

            -- 3. Also keep the current logic as backup if color detection fails for some reason
            -- or if it's already attacking someone not in group.
            -- IMPORTANT: Only run this fallback if we haven't already confirmed it's ours (original bar not gray)
            local originalIsGray = (r > 0.4 and r < 0.6 and g > 0.4 and g < 0.6 and b > 0.4 and b < 0.6)
            if not isTappedByOthers and mobInCombat and (originalIsGray or (r < 0.1 and g < 0.1 and b < 0.1)) then
                local isMobTargetingGroupMate = false

                if mobTargetUnit and UnitExists(mobTargetUnit) and not UnitIsUnit(mobTargetUnit, "player") then
                    isMobTargetingGroupMate = IsInPlayerGroup(mobTargetUnit)
                end
                
                -- If it's targeting us, we don't set isMobTargetingGroupMate to true here.
                -- This means if it was already tapped (but color detection failed), 
                -- it will stay tapped even if attacking us, unless UnitIsTappedByPlayer says otherwise (handled by API check above).
                
                -- However, if it's NOT targeting a group mate AND it's not our tap, it's tapped by others.
                -- But wait, if it's targeting US, isMobTargetingGroupMate is false.
                -- If we are the one who tapped it, it shouldn't be here (ideally).
                -- But Block 3 is a fallback for non-target plates where we don't have UnitIsTapped.
                -- For non-target plates, if it's attacking us, we usually assume it's ours.
                -- This is tricky. But if color detection (Block 1) didn't catch it as gray, 
                -- it's probably NOT tapped by someone else, or the color hasn't updated.
                
                -- Let's stick to the user request: "shouldn't change any color if I aggro it".
                -- If it was gray, Block 1 should catch it.
                -- If Block 1 caught it, isTappedByOthers is true, and Block 2 & 3 don't run.
                
                -- If it's attacking us, we'll keep the existing logic for now but be careful.
                local isMobTargetingGroup = isMobTargetingGroupMate or isAttackingPlayer or hasAggroGlow
                isTappedByOthers = not isMobTargetingGroup
            end
        end

        -- Apply color based on state (priority order: TAPPED -> STUNNED -> NEUTRAL -> THREAT COLORS)
        local isStunned = false
        if hasValidGUID and GudaPlates_Debuffs then
            -- We can check our own timers for this unit
            -- Stun types in WoW: Stun, Incapacitate, Fear? User specifically asked for "Stun color"
            local stuns = { "Cheap Shot", "Kidney Shot", "Bash", "Hammer of Justice", "Charge Stun", "Intercept Stun", "Concussion Blow", "Gouge", "Sap", "Pounce" }
            for _, stunName in ipairs(stuns) do
                if GudaPlates_Debuffs.timers[unitstr .. "_" .. stunName] or GudaPlates_Debuffs.timers[plateName .. "_" .. stunName] then
                    isStunned = true
                    break
                end
            end
        end

        if isTappedByOthers and hp < hpmax then
        -- TAPPED: Mob is tapped by others and took damage - no other colors applied
            nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TAPPED))
        elseif isStunned then
        -- STUNNED: Unit is stunned
            nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.STUN))
        elseif isNeutral and not isAttackingPlayer then
        -- Neutral and not attacking - yellow
            nameplate.health:SetStatusBarColor(0.9, 0.7, 0.0, 1)
        elseif not mobInCombat then
        -- Not in combat (and not neutral/tapped) - default hostile red
            nameplate.health:SetStatusBarColor(0.85, 0.2, 0.2, 1)
        elseif hasValidGUID and twthreat_active then
        -- Full threat-based coloring (mob is in combat with us, has GUID and threat data)
            if playerRole == "TANK" then
                if isTanking then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.AGGRO))
                elseif threatPct > 80 then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.LOSING_AGGRO))
                elseif isAttackingPlayer then
                    -- Stickiness or mob mid-swing but we don't officially have 'isTanking' status yet
                    -- and threat is not high enough to be LOSING_AGGRO
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.AGGRO))
                else
                    if IsTankClass(mobTargetUnit) then
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.OTHER_TANK))
                    else
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.NO_AGGRO))
                    end
                end
            else
                if isTanking then
                    -- DPS having aggro is bad
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.AGGRO))
                elseif threatPct > 80 then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.HIGH_THREAT))
                elseif isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.AGGRO))
                else
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.NO_AGGRO))
                end
            end
        elseif hasValidGUID then
        -- Has GUID but no TWThreat - use targeting-based colors
            if playerRole == "TANK" then
                if isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.AGGRO))
                elseif mobTargetUnit and UnitExists(mobTargetUnit) and not UnitIsUnit(mobTargetUnit, "player") then
                    -- Mob is targeting someone else, but it's still orange if it was just attacking us (stickiness)
                    -- Wait, targeting-based mode has no threatPct, so we rely purely on target.
                    -- If we want "Losing Aggro" (Orange) here, we need a condition.
                    -- Usually Orange is when we ARE targeted but about to lose it (hard to know without threat API),
                    -- OR when we WERE targeted but just lost it.
                    if nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime < 2) then
                        -- We just lost it (stickiness is active) -> Orange
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.LOSING_AGGRO))
                    elseif IsTankClass(mobTargetUnit) then
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.OTHER_TANK))
                    else
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.NO_AGGRO))
                    end
                elseif IsTankClass(mobTargetUnit) then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.OTHER_TANK))
                else
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.NO_AGGRO))
                end
            else
                if isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.AGGRO))
                elseif nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime < 2) then
                    -- Just lost it -> High Threat
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.HIGH_THREAT))
                else
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.NO_AGGRO))
                end
            end
        else
        -- No GUID (no SuperWoW) - fallback with name-based detection
            if playerRole == "TANK" then
                if isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.AGGRO))
                elseif nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime < 2) then
                    -- Just lost it -> Orange
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.LOSING_AGGRO))
                else
                    local otherTankHasAggro = false
                    if plateName and UnitExists("target") and UnitName("target") == plateName then
                        if frame:GetAlpha() > 0.9 and UnitExists("targettarget") then
                            otherTankHasAggro = IsTankClass("targettarget")
                        end
                    end
                    if otherTankHasAggro then
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.OTHER_TANK))
                    else
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.NO_AGGRO))
                    end
                end
            else
                if isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.AGGRO))
                elseif nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime < 2) then
                    -- Just lost it -> High Threat
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.HIGH_THREAT))
                else
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.NO_AGGRO))
                end
            end
        end
    end

    -- Update name from original
    if original.name and original.name.GetText then
        local name = original.name:GetText()
        if name then 
            nameplate.name:SetText(name)
            nameplate.name:SetTextColor(Settings.nameColor[1], Settings.nameColor[2], Settings.nameColor[3], Settings.nameColor[4])
        end
    end

    -- Update Mana Bar (only with SuperWoW GUID support)
    local mShowManaBar, mManaTextFormat
    if isFriendly then
        mShowManaBar = Settings.friendShowManaBar
        mManaTextFormat = Settings.friendManaTextFormat
    else
        mShowManaBar = Settings.showManaBar
        mManaTextFormat = Settings.manaTextFormat
    end

    if mShowManaBar and superwow_active and hasValidGUID then
        local mana = UnitMana(unitstr) or 0
        local manaMax = UnitManaMax(unitstr) or 0
        local powerType = UnitPowerType and UnitPowerType(unitstr) or 0
        
        -- Only show for units with mana (powerType 0 = mana)
        if manaMax > 0 and powerType == 0 then
            nameplate.mana:SetMinMaxValues(0, manaMax)
            nameplate.mana:SetValue(mana)
            nameplate.mana:SetStatusBarColor(unpack(THREAT_COLORS.MANA_BAR))
            
            -- Format mana text based on settings
            local manaText = ""
            if mManaTextFormat ~= 0 then
                local manaPerc = (mana / manaMax) * 100
                if mManaTextFormat == 1 then
                    -- Percent only
                    manaText = string_format("%.0f%%", manaPerc)
                elseif mManaTextFormat == 2 then
                    -- Current Mana only
                    if mana > 1000 then
                        manaText = string_format("%.1fK", mana / 1000)
                    else
                        manaText = string_format("%d", mana)
                    end
                elseif mManaTextFormat == 3 then
                    -- Mana (Percent%)
                    local manaStr
                    if mana > 1000 then
                        manaStr = string_format("%.1fK", mana / 1000)
                    else
                        manaStr = string_format("%d", mana)
                    end
                    manaText = string_format("%s (%.0f%%)", manaStr, manaPerc)
                end
            end
            if nameplate.mana.text then
                nameplate.mana.text:SetText(manaText)
            end
            
            nameplate.mana:Show()
        else
            nameplate.mana:Hide()
        end
    else
        if nameplate.mana then
            nameplate.mana:Hide()
        end
    end

    -- Target highlight - show borders on current target
    local isTarget = false
    if UnitExists("target") and plateName then
        local targetName = UnitName("target")
        if targetName and targetName == plateName then
        -- Additional check: verify via alpha (target nameplate has alpha 1)
            if frame:GetAlpha() == 1 then
                isTarget = true
            end
        end
    end

    if isTarget then
        -- Position brackets based on mana bar visibility
        local topAnchor = nameplate.health
        local bottomAnchor = nameplate.health
        local bracketHeight = Settings.healthbarHeight
        
        -- Check if mana bar is visible and adjust anchors
        if nameplate.mana and nameplate.mana:IsShown() then
            if Settings.swapNameDebuff then
                -- Swapped mode: mana below healthbar
                topAnchor = nameplate.health
                bottomAnchor = nameplate.mana
                bracketHeight = Settings.healthbarHeight + 4  -- 4 is mana bar height
            else
                -- Default mode: mana above healthbar
                topAnchor = nameplate.mana
                bottomAnchor = nameplate.health
                bracketHeight = Settings.healthbarHeight + 4
            end
        end
        
        -- Position left bracket [ (offset by 3px from bar, extend 4px beyond borders)
        nameplate.targetBracket.leftVert:ClearAllPoints()
        nameplate.targetBracket.leftVert:SetPoint("TOPRIGHT", topAnchor, "TOPLEFT", -1, 2)
        nameplate.targetBracket.leftVert:SetPoint("BOTTOMRIGHT", bottomAnchor, "BOTTOMLEFT", -1, -2)
        nameplate.targetBracket.leftVert:Show()
        
        nameplate.targetBracket.leftTop:ClearAllPoints()
        nameplate.targetBracket.leftTop:SetPoint("TOPLEFT", nameplate.targetBracket.leftVert, "TOPRIGHT", 0, 0)
        nameplate.targetBracket.leftTop:Show()
        
        nameplate.targetBracket.leftBottom:ClearAllPoints()
        nameplate.targetBracket.leftBottom:SetPoint("BOTTOMLEFT", nameplate.targetBracket.leftVert, "BOTTOMRIGHT", 0, 0)
        nameplate.targetBracket.leftBottom:Show()
        
        -- Position right bracket ] (offset by 3px from bar, extend 4px beyond borders)
        nameplate.targetBracket.rightVert:ClearAllPoints()
        nameplate.targetBracket.rightVert:SetPoint("TOPLEFT", topAnchor, "TOPRIGHT", 1, 2)
        nameplate.targetBracket.rightVert:SetPoint("BOTTOMLEFT", bottomAnchor, "BOTTOMRIGHT", 1, -2)
        nameplate.targetBracket.rightVert:Show()
        
        nameplate.targetBracket.rightTop:ClearAllPoints()
        nameplate.targetBracket.rightTop:SetPoint("TOPRIGHT", nameplate.targetBracket.rightVert, "TOPLEFT", 0, 0)
        nameplate.targetBracket.rightTop:Show()
        
        nameplate.targetBracket.rightBottom:ClearAllPoints()
        nameplate.targetBracket.rightBottom:SetPoint("BOTTOMRIGHT", nameplate.targetBracket.rightVert, "BOTTOMLEFT", 0, 0)
        nameplate.targetBracket.rightBottom:Show()
        
        -- Show target glow if enabled (Dragonflight3-style top/bottom glow)
        if Settings.showTargetGlow then
            if nameplate.targetGlowTop then
                nameplate.targetGlowTop:SetVertexColor(Settings.targetGlowColor[1], Settings.targetGlowColor[2], Settings.targetGlowColor[3], 0.4)
                nameplate.targetGlowTop:SetWidth(Settings.healthbarWidth)
                nameplate.targetGlowTop:Show()
            end
            if nameplate.targetGlowBottom then
                nameplate.targetGlowBottom:SetVertexColor(Settings.targetGlowColor[1], Settings.targetGlowColor[2], Settings.targetGlowColor[3], 0.4)
                nameplate.targetGlowBottom:SetWidth(Settings.healthbarWidth)
                nameplate.targetGlowBottom:Show()
            end
        end
        -- Target always has highest z-index
        nameplate:SetFrameStrata("BACKGROUND")
        nameplate:SetFrameLevel(10)
    else
        -- Hide all bracket parts
        nameplate.targetBracket.leftVert:Hide()
        nameplate.targetBracket.leftTop:Hide()
        nameplate.targetBracket.leftBottom:Hide()
        nameplate.targetBracket.rightVert:Hide()
        nameplate.targetBracket.rightTop:Hide()
        nameplate.targetBracket.rightBottom:Hide()
        -- Hide target glow
        if nameplate.targetGlowTop then
            nameplate.targetGlowTop:Hide()
        end
        if nameplate.targetGlowBottom then
            nameplate.targetGlowBottom:Hide()
        end
        -- Non-target z-index based on attacking state
        nameplate:SetFrameStrata("BACKGROUND")
        if nameplate.isAttackingPlayer then
            nameplate:SetFrameLevel(5)
        else
            nameplate:SetFrameLevel(2)
        end
    end

    -- Update Cast Bar
    local casting = nil
    local now = GetTime()

    -- Method 1: Check castDB by GUID (SuperWoW UNIT_CASTEVENT - most accurate)
    if hasValidGUID and castDB[unitstr] then
        local cast = castDB[unitstr]
        -- Check if cast is still active
        if cast.startTime + (cast.duration / 1000) > now then
            casting = cast
        else
            -- Expired, clean up
            castDB[unitstr] = nil
        end
    end

    -- Method 2: Try UnitCastingInfo/UnitChannelInfo (SuperWoW 1.5+)
    if not casting and superwow_active and hasValidGUID then
        if UnitCastingInfo then
            local spell, nameSubtext, text, texture, startTime, endTime, isTradeSkill = UnitCastingInfo(unitstr)
            if spell then
                casting = {
                    spell = spell,
                    startTime = startTime / 1000,
                    duration = endTime - startTime,
                    icon = texture
                }
            end
        end

        if not casting and UnitChannelInfo then
            local spell, nameSubtext, text, texture, startTime, endTime, isTradeSkill = UnitChannelInfo(unitstr)
            if spell then
                casting = {
                    spell = spell,
                    startTime = startTime / 1000,
                    duration = endTime - startTime,
                    icon = texture
                }
            end
        end
    end

    -- Method 3: Fallback to castTracker (combat log based, name-based)
    -- Only used when SuperWoW GUID-based methods didn't find a cast
    if not casting and plateName and castTracker[plateName] and not hasValidGUID then
        -- Clean up expired casts first
        local i = 1
        while i <= table.getn(castTracker[plateName]) do
            local cast = castTracker[plateName][i]
            if now > cast.startTime + (cast.duration / 1000) then
                table.remove(castTracker[plateName], i)
            else
                -- Use first valid cast for this name
                if not casting then
                    casting = cast
                end
                i = i + 1
            end
        end
    end

    if casting and casting.spell then
        local now = GetTime()
        local start = casting.startTime
        local duration = casting.duration

        -- Determine settings to use based on reaction
        local cHeight, cIndependent, cWidth, cShowIcon, hHeight, hWidth, mHeight
        if isFriendly then
            cHeight = Settings.friendCastbarHeight
            cIndependent = Settings.friendCastbarIndependent
            cWidth = Settings.friendCastbarWidth
            cShowIcon = Settings.friendShowCastbarIcon
            hHeight = Settings.friendHealthbarHeight
            hWidth = Settings.friendHealthbarWidth
            mHeight = Settings.friendManabarHeight
        else
            cHeight = Settings.castbarHeight
            cIndependent = Settings.castbarIndependent
            cWidth = Settings.castbarWidth
            cShowIcon = Settings.showCastbarIcon
            hHeight = Settings.healthbarHeight
            hWidth = Settings.healthbarWidth
            mHeight = Settings.manabarHeight
        end

        if now < start + (duration / 1000) then
            nameplate.castbar:SetMinMaxValues(0, duration)
            nameplate.castbar:SetValue((now - start) * 1000)
            nameplate.castbar.text:SetText(casting.spell)

            local timeLeft = (start + (duration / 1000)) - now
            nameplate.castbar.timer:SetText(string_format("%.1fs", timeLeft))

            if casting.icon and cShowIcon then
                nameplate.castbar.icon:SetTexture(casting.icon)
                nameplate.castbar.icon:ClearAllPoints()
                
                -- Calculate icon size based on castbar width vs healthbar width
                local iconSize
                
                if cIndependent and cWidth > hWidth then
                    -- Castbar wider than healthbar: icon aligns with healthbar (+ manabar if visible)
                    if nameplate.mana and nameplate.mana:IsShown() then
                        iconSize = hHeight + mHeight
                    else
                        iconSize = hHeight
                    end
                else
                    -- Normal mode: icon spans healthbar + castbar (+ manabar if visible)
                    if nameplate.mana and nameplate.mana:IsShown() then
                        iconSize = hHeight + cHeight + mHeight
                    else
                        iconSize = hHeight + cHeight
                    end
                end
                
                nameplate.castbar.icon:SetWidth(iconSize)
                nameplate.castbar.icon:SetHeight(iconSize)
                
                -- Position icon based on raid icon position and swap setting
                nameplate.castbar.icon:ClearAllPoints()
                
                if cIndependent and cWidth > hWidth then
                    -- Independent castbar wider than healthbar: anchor to healthbar/manabar
                    if Settings.raidIconPosition == "RIGHT" then
                        if Settings.swapNameDebuff then
                            nameplate.castbar.icon:SetPoint("TOPRIGHT", nameplate.health, "TOPLEFT", -4, 0)
                        else
                            if nameplate.mana and nameplate.mana:IsShown() then
                                nameplate.castbar.icon:SetPoint("TOPRIGHT", nameplate.mana, "TOPLEFT", -4, 0)
                            else
                                nameplate.castbar.icon:SetPoint("TOPRIGHT", nameplate.health, "TOPLEFT", -4, 0)
                            end
                        end
                    else
                        if Settings.swapNameDebuff then
                            nameplate.castbar.icon:SetPoint("TOPLEFT", nameplate.health, "TOPRIGHT", 4, 0)
                        else
                            if nameplate.mana and nameplate.mana:IsShown() then
                                nameplate.castbar.icon:SetPoint("TOPLEFT", nameplate.mana, "TOPRIGHT", 4, 0)
                            else
                                nameplate.castbar.icon:SetPoint("TOPLEFT", nameplate.health, "TOPRIGHT", 4, 0)
                            end
                        end
                    end
                else
                    -- Normal mode: anchor to castbar
                    if Settings.raidIconPosition == "RIGHT" then
                        if Settings.swapNameDebuff then
                            -- Swapped: castbar above healthbar, anchor icon top to castbar top
                            nameplate.castbar.icon:SetPoint("TOPRIGHT", nameplate.castbar, "TOPLEFT", -4, 0)
                        else
                            -- Normal: castbar below healthbar, anchor icon bottom to castbar bottom
                            nameplate.castbar.icon:SetPoint("BOTTOMRIGHT", nameplate.castbar, "BOTTOMLEFT", -4, 0)
                        end
                    else
                        if Settings.swapNameDebuff then
                            -- Swapped: castbar above healthbar, anchor icon top to castbar top
                            nameplate.castbar.icon:SetPoint("TOPLEFT", nameplate.castbar, "TOPRIGHT", 4, 0)
                        else
                            -- Normal: castbar below healthbar, anchor icon bottom to castbar bottom
                            nameplate.castbar.icon:SetPoint("BOTTOMLEFT", nameplate.castbar, "BOTTOMRIGHT", 4, 0)
                        end
                    end
                end
                nameplate.castbar.icon:Show()
                if nameplate.castbar.icon.border then nameplate.castbar.icon.border:Show() end
            else
                nameplate.castbar.icon:Hide()
                if nameplate.castbar.icon.border then nameplate.castbar.icon.border:Hide() end
            end

            nameplate.castbar:Show()
        else
            nameplate.castbar:Hide()
        end
    else
        nameplate.castbar:Hide()
    end

    -- Debuff logic is now handled by GudaPlates_Debuffs module
    -- Throttle debuff updates to DEBUFF_UPDATE_INTERVAL (default 0.1s = 10 updates/sec)
    if GudaPlates_Debuffs then
        local lastDebuffUpdate = nameplate.lastDebuffUpdate or 0
        if now - lastDebuffUpdate >= DEBUFF_UPDATE_INTERVAL then
            nameplate.lastDebuffUpdate = now
            local numDebuffs = GudaPlates_Debuffs:UpdateDebuffs(nameplate, unitstr, plateName, isTarget, hasValidGUID, superwow_active)
            nameplate.lastDebuffCount = numDebuffs
            GudaPlates_Debuffs:UpdateDebuffPositions(nameplate, numDebuffs)
        else
            -- Still update positions in case nameplate moved, using cached count
            local numDebuffs = nameplate.lastDebuffCount or 0
            GudaPlates_Debuffs:UpdateDebuffPositions(nameplate, numDebuffs)
        end
    end
end
GudaPlates.UpdateNamePlate = UpdateNamePlate  -- Expose for Options module

-- Check if ShaguTweaks libnameplate is available
local function TryShaguTweaksHook()
    if ShaguTweaks and ShaguTweaks.libnameplate then
        Print("Using ShaguTweaks libnameplate")

        -- Hook into ShaguTweaks OnInit
        ShaguTweaks.libnameplate.OnInit["GudaPlates"] = function(plate)
            if plate and not registry[plate] then
                HandleNamePlate(plate)
            end
        end

        -- Hook into ShaguTweaks OnUpdate for our updates
        -- Note: ShaguTweaks passes 'this' as the plate in Lua 5.0 style
        ShaguTweaks.libnameplate.OnUpdate["GudaPlates"] = function()
            local plate = this
            if plate and plate:IsShown() and registry[plate] then
                UpdateNamePlate(plate)
            end
        end

        return true
    end
    return false
end

-- Try ShaguTweaks hook first, otherwise use our own scanner
local usingShaguTweaks = false
local scanCount = 0
local lastChildCount = 0
-- Throttle for debuff timer cleanup
local lastDebuffCleanup = 0

GudaPlates:SetScript("OnUpdate", function()
    if GudaPlates_Debuffs then
        GudaPlates_Debuffs:CleanupTimers()
    end

    -- Try to hook ShaguTweaks once
    if not usingShaguTweaks and ShaguTweaks and ShaguTweaks.libnameplate then
        if TryShaguTweaksHook() then
            usingShaguTweaks = true
        end
    end

    -- If using ShaguTweaks, still apply overlap settings
    if usingShaguTweaks then
        for plate, nameplate in pairs(registry) do
            if plate:IsShown() then
            -- Apply overlap/stacking setting
                if nameplateOverlap then
                    plate:EnableMouse(false)
                    if plate:GetWidth() > 1 then
                        plate:SetWidth(1)
                        plate:SetHeight(1)
                    end
                    -- Z-index is handled in UpdateNamePlate (target > attacking > others)
                    -- If clickThrough, disable mouse on nameplate too
                    nameplate:EnableMouse(not clickThrough)
                else
                    -- If NOT clickThrough, enable mouse on plate; otherwise disable
                    plate:EnableMouse(not clickThrough)
                    nameplate:EnableMouse(false)
                end

                -- Ensure dimensions are correct
                UpdateNamePlateDimensions(plate)
            end
        end
        return
    end

    -- Our own scanning logic
    parentcount = WorldFrame:GetNumChildren()

    local childs = { WorldFrame:GetChildren() }
    for i = 1, parentcount do
        local plate = childs[i]
        if plate then
            local isPlate = IsNamePlate(plate)
            if isPlate and not registry[plate] then
                HandleNamePlate(plate)
            end
        end
    end

    for plate, nameplate in pairs(registry) do
        if plate:IsShown() then
            UpdateNamePlate(plate)

            -- Apply overlap/stacking setting
            if nameplateOverlap then
            -- Overlapping: disable parent mouse and shrink to 1px
            -- This prevents game's collision avoidance from moving nameplates
                plate:EnableMouse(false)

                if plate:GetWidth() > 1 then
                    plate:SetWidth(1)
                    plate:SetHeight(1)
                end

                -- Z-index is handled in UpdateNamePlate (target > attacking > others)
                -- Enable clicking on nameplate itself if click-through is disabled
                nameplate:EnableMouse(not clickThrough)
            else
            -- Stacking: restore parent frame size so game stacks them
                plate:EnableMouse(not clickThrough)
                nameplate:EnableMouse(false)
            end

            -- Ensure dimensions are correct
            UpdateNamePlateDimensions(plate)
        end
    end
end)

-- Combat log parsing functions (castIcons, ParseCastStart, ParseAttackHit) moved to GudaPlates_CombatLog.lua
-- cmatch kept here due to load order (needed before CombatLog loads)
local function cmatch(str, pattern)
    if not str or not pattern then return nil end
    local pat = string_gsub(pattern, "%%%d?%$?s", "(.+)")
    pat = string_gsub(pat, "%%%d?%$?d", "(%d+)")
    for a, b, c, d in string_gfind(str, pat) do
        return a, b, c, d
    end
    return nil
end

GudaPlates:SetScript("OnEvent", function()
    -- Parse cast starts for ALL combat log events first
    -- Using lookup tables instead of string.find for better performance
    if arg1 and SPELL_EVENTS[event] then
        if GudaPlates.ParseCastStart then GudaPlates.ParseCastStart(arg1) end
        -- Also check for spell damage that might refresh debuffs (like Thunderfury)
        if SpellDB and SPELL_DAMAGE_EVENTS[event] then
            -- Patterns for player and others
            local spell, victim, attacker = nil, nil, nil
            
            -- Your [Spell] hits [Target] for [Amount] [Type] damage.
            for s, v in string_gfind(arg1, "Your (.+) hits (.+) for %d+.") do 
                spell, victim, attacker = s, v, "You" 
            end
            if not spell then
                -- Your [Spell] crits [Target] for [Amount] [Type] damage.
                for s, v in string_gfind(arg1, "Your (.+) crits (.+) for %d+.") do 
                    spell, victim, attacker = s, v, "You" 
                end
            end
            if not spell then
                -- Your [Spell] was resisted by [Target].
                for s, v in string_gfind(arg1, "Your (.+) was resisted by (.+)%.") do 
                    spell, victim, attacker = s, v, "You" 
                end
            end
            
            -- Others' procs
            if not spell then
                -- [Attacker]'s [Spell] hits [Target] for [Amount] [Type] damage.
                for a, s, v in string_gfind(arg1, "(.+)'s (.+) hits (.+) for %d+.") do 
                    spell, victim, attacker = s, v, a 
                end
            end
            if not spell then
                -- [Attacker]'s [Spell] crits [Target] for [Amount] [Type] damage.
                for a, s, v in string_gfind(arg1, "(.+)'s (.+) crits (.+) for %d+.") do 
                    spell, victim, attacker = s, v, a 
                end
            end
            if not spell then
                -- [Attacker]'s [Spell] was resisted by [Target].
                for a, s, v in string_gfind(arg1, "(.+)'s (.+) was resisted by (.+)%.") do 
                    spell, victim, attacker = s, v, a 
                end
            end

            if spell and victim and (spell == "Thunderfury" or spell == "Thunderfury's Blessing") then
                local unitlevel = UnitName("target") == victim and UnitLevel("target") or 0
                local duration = SpellDB:GetDuration("Thunderfury", 0)
                local isOwn = (attacker == "You")
                
                -- Refresh BOTH "Thunderfury" and "Thunderfury's Blessing" as they are usually applied together
                SpellDB:RefreshEffect(victim, unitlevel, "Thunderfury", duration, isOwn)
                SpellDB:RefreshEffect(victim, unitlevel, "Thunderfury's Blessing", duration, isOwn)
                
                -- Clear fallback timers to force refresh on nameplates
                if GudaPlates_Debuffs and GudaPlates_Debuffs.timers then
                    GudaPlates_Debuffs.timers[victim .. "_" .. "Thunderfury"] = nil
                    GudaPlates_Debuffs.timers[victim .. "_" .. "Thunderfury's Blessing"] = nil
                    
                    -- Also clear by GUID if we can find it
                    if superwow_active and UnitExists("target") and UnitName("target") == victim then
                        local guid = UnitGUID and UnitGUID("target")
                        if guid then
                            GudaPlates_Debuffs.timers[guid .. "_" .. "Thunderfury"] = nil
                            GudaPlates_Debuffs.timers[guid .. "_" .. "Thunderfury's Blessing"] = nil
                        end
                    end
                end

                -- Also refresh by GUID if victim is current target (SuperWoW)
                if superwow_active and UnitExists("target") and UnitName("target") == victim then
                    local guid = UnitGUID and UnitGUID("target")
                    if guid then
                        SpellDB:RefreshEffect(guid, unitlevel, "Thunderfury", duration, isOwn)
                        SpellDB:RefreshEffect(guid, unitlevel, "Thunderfury's Blessing", duration, isOwn)
                    end
                end
            elseif spell and victim and GudaPlates_Debuffs then
                -- Check for Judgement refreshes from spells (e.g. Paladin Seal procs)
                GudaPlates_Debuffs:SealHandler(attacker, victim)
            end
        end
    elseif arg1 and COMBAT_EVENTS[event] then
        if GudaPlates.ParseAttackHit then GudaPlates.ParseAttackHit(arg1) end
    end

    if event == "ADDON_LOADED" then
        if arg1 == "GudaPlates" then
            LoadSettings()
            -- Also try to disable pfUI nameplates when our addon is loaded
            DisablePfUINameplates()
        elseif arg1 == "pfUI" then
            -- pfUI just loaded, disable its nameplates
            if DisablePfUINameplates() then
                Print("Disabled pfUI nameplates module")
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Also try to disable pfUI nameplates on world enter (in case it loaded before us)
        DisablePfUINameplates()

        -- Clear trackers on zone/load
        debuffTracker = {}
        castTracker = {}
        castDB = {}
        recentMeleeCrits = {}
        recentMeleeHits = {}
        if SpellDB then SpellDB.objects = {} end
        if SpellDB and SpellDB.ownerBoundCache then SpellDB.ownerBoundCache = {} end
        Print("Initialized. Scanning...")
        if twthreat_active then
            Print("TWThreat detected - full threat colors enabled")
        end
        if superwow_active then
            Print("SuperWoW detected - GUID targeting enabled")
            if Settings.showDebuffTimers then
                Print("Debuff countdowns enabled")
            end
        end

    -- SuperWoW UNIT_CASTEVENT handler (moved to GudaPlates_Castbar.lua)
    elseif event == "UNIT_CASTEVENT" then
        if GudaPlates.HandleUnitCastEvent then
            local shouldReturn = GudaPlates.HandleUnitCastEvent(arg1, arg2, arg3, arg4, arg5)
            if shouldReturn then return end
        end

    -- ShaguPlates-style event handlers
    elseif event == "SPELLCAST_STOP" then
        -- For instant spells that refresh existing debuffs
        -- The "afflicted" message doesn't fire on refresh, only on initial apply
        if SpellDB and SpellDB.pending[3] then
            local effect = SpellDB.pending[3]
            local duration = SpellDB.pending[4]
            local unitName = SpellDB.pending[5]
            local unitlevel = SpellDB.pending[2]

            local hasObject = SpellDB.objects[unitName] and SpellDB.objects[unitName][unitlevel] and SpellDB.objects[unitName][unitlevel][effect]

            -- Check if this debuff already exists on target (refresh case)
            if unitName and hasObject then
                SpellDB:RefreshEffect(unitName, unitlevel, effect, duration, true) -- Mark as own spell
                -- Track OWNER_BOUND_DEBUFFS for ownership inference
                if SpellDB.OWNER_BOUND_DEBUFFS and SpellDB.OWNER_BOUND_DEBUFFS[effect] and SpellDB.TrackOwnerBoundDebuff then
                    SpellDB:TrackOwnerBoundDebuff(unitName, effect, duration)
                    -- Also track by GUID if available
                    if superwow_active and UnitExists("target") and UnitName("target") == unitName then
                        local guid = UnitGUID and UnitGUID("target")
                        if guid then
                            SpellDB:TrackOwnerBoundDebuff(guid, effect, duration)
                        end
                    end
                end
                SpellDB:RemovePending()
            end
            -- If not existing, wait for combat log "afflicted" message
        end

    elseif event == "CHAT_MSG_SPELL_FAILED_LOCALPLAYER" and arg1 then
        -- Remove pending spell on failure
        if SpellDB then
            for _, pattern in pairs(REMOVE_PENDING_PATTERNS) do
                local effect = cmatch(arg1, pattern)
                if effect and SpellDB.pending[3] == effect then
                    SpellDB:RemovePending()
                    return
                end
            end
        end

    elseif event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_AURA" and arg1 == "target") or 
           event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        -- Refresh all nameplates color when group changes to immediately update tapped state
        if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
            for plate, _ in pairs(registry) do
                if plate:IsShown() then
                    UpdateNamePlate(plate)
                end
            end
        end

        -- Add missing debuffs by iteration (ShaguPlates-style)
        if SpellDB and UnitExists("target") then
            local unitname = UnitName("target")
            local unitlevel = UnitLevel("target") or 0
            for i = 1, 16 do
                local effect, rank, texture, stacks, dtype, duration, timeleft = SpellDB:UnitDebuff("target", i)
                if not texture then break end
                if effect and effect ~= "" then
                    -- Don't overwrite existing timers
                    if not SpellDB.objects[unitname] or not SpellDB.objects[unitname][unitlevel] or not SpellDB.objects[unitname][unitlevel][effect] then
                        SpellDB:AddEffect(unitname, unitlevel, effect)
                    end
                end
            end
        end

    elseif event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" or event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE" then
        -- Track debuff applications from combat log (ShaguPlates-style)
        if arg1 and SpellDB then
            -- Pattern: "Unit is afflicted by Spell." or "Unit is afflicted by Spell (N)."
            -- Use hardcoded pattern to avoid conflicts with addons like Cursive that modify AURAADDEDOTHERHARMFUL
            local unit, effect = cmatch(arg1, "%s is afflicted by %s.")
            -- If no match, try pattern with stack count (e.g. "X is afflicted by Y (1).")
            if not unit or not effect then
                for u, e in string_gfind(arg1, "(.+) is afflicted by (.+) %((%d+)%)%.") do
                    unit, effect = u, e
                    break
                end
            end

            -- If we matched with Cursive's format (Debuff (1)), the stack-unaware pattern will capture "(1)" as part of the effect name
            -- Strip any stack counts from the effect name
            if effect then
                effect = StripSpellRank(effect)
                for e, s in string_gfind(effect, "(.+) %((%d+)%)$") do
                    effect = e
                    break
                end
            end

            if unit and effect then
                local unitlevel = UnitName("target") == unit and UnitLevel("target") or 0
                
                -- Support for various Paladin Judgements which might be reported as just "Judgement" in combat log
                -- or differently than their spell names. Wisdom seems to work, others might not.
                if effect == "Judgement of Light" or effect == "Judgement of the Crusader" or effect == "Judgement of Justice" or effect == "Judgement of Wisdom" or effect == "Judgement" then
                    -- If it's just "Judgement", we can't be 100% sure which one it is without target scanning,
                    -- but we can try to refresh all known judgements if they already exist on this unit.
                    local judgementsToRefresh = (effect == "Judgement") and { "Judgement of Wisdom", "Judgement of Light", "Judgement of the Crusader", "Judgement of Justice" } or { effect }
                    
                    for _, effectName in pairs(judgementsToRefresh) do
                        local dbDuration = SpellDB:GetDuration(effectName, 0)
                        if effect == "Judgement" then
                            -- Only refresh if it already exists
                            if SpellDB.objects[unit] and SpellDB.objects[unit][unitlevel] and SpellDB.objects[unit][unitlevel][effectName] then
                                SpellDB:RefreshEffect(unit, unitlevel, effectName, dbDuration, false)
                            end
                        else
                            SpellDB:RefreshEffect(unit, unitlevel, effectName, dbDuration, false)
                        end
                        
                        -- Also refresh by GUID if victim is current target
                        if superwow_active and UnitExists("target") and UnitName("target") == unit then
                            local guid = UnitGUID and UnitGUID("target")
                            if guid then
                                if effect == "Judgement" then
                                    if SpellDB.objects[guid] and SpellDB.objects[guid][unitlevel] and SpellDB.objects[guid][unitlevel][effectName] then
                                        SpellDB:RefreshEffect(guid, unitlevel, effectName, dbDuration, false)
                                    end
                                else
                                    SpellDB:RefreshEffect(guid, unitlevel, effectName, dbDuration, false)
                                end
                            end
                        end
                    end
                end

                local recent = SpellDB.recentCasts and SpellDB.recentCasts[effect]
                local isRecentCast = recent and recent.time and (GetTime() - recent.time) < 3

                -- First try to persist pending spell (this has accurate rank/duration from cast hook)
                if SpellDB.pending[3] == effect then
                    -- Capture duration BEFORE PersistPending clears it
                    local pendingDuration = SpellDB.pending[4] or SpellDB:GetDuration(effect, 0)
                    SpellDB:PersistPending(effect)
                    -- Track OWNER_BOUND_DEBUFFS for ownership inference
                    if SpellDB.OWNER_BOUND_DEBUFFS and SpellDB.OWNER_BOUND_DEBUFFS[effect] and SpellDB.TrackOwnerBoundDebuff then
                        SpellDB:TrackOwnerBoundDebuff(unit, effect, pendingDuration)
                        -- Also track by GUID if available
                        if superwow_active and UnitExists("target") and UnitName("target") == unit then
                            local guid = UnitGUID and UnitGUID("target")
                            if guid then
                                SpellDB:TrackOwnerBoundDebuff(guid, effect, pendingDuration)
                            end
                        end
                    end
                elseif isRecentCast then
                    -- Recent cast - refresh the timer (player reapplied the debuff)
                    SpellDB:RefreshEffect(unit, unitlevel, effect, recent.duration, true)
                    -- Track OWNER_BOUND_DEBUFFS for ownership inference
                    if SpellDB.OWNER_BOUND_DEBUFFS and SpellDB.OWNER_BOUND_DEBUFFS[effect] and SpellDB.TrackOwnerBoundDebuff then
                        SpellDB:TrackOwnerBoundDebuff(unit, effect, recent.duration)
                        -- Also track by GUID if available
                        if superwow_active and UnitExists("target") and UnitName("target") == unit then
                            local guid = UnitGUID and UnitGUID("target")
                            if guid then
                                SpellDB:TrackOwnerBoundDebuff(guid, effect, recent.duration)
                            end
                        end
                    end
                else
                    -- Check for proc via melee heuristic
                    local isProc = false
                    if effect == "Deep Wound" or effect == "Vindication" or
                       string_find(effect, "Poison") then
                        local now = GetTime()
                        local recentTime = nil
                        
                        if effect == "Deep Wound" then
                            recentTime = recentMeleeCrits[unit]
                        else
                            recentTime = recentMeleeHits[unit]
                        end

                        -- Also check by GUID
                        if not recentTime and superwow_active and UnitExists("target") and UnitName("target") == unit then
                            local guid = UnitGUID and UnitGUID("target")
                            if guid then
                                if effect == "Deep Wound" then
                                    recentTime = recentMeleeCrits[guid]
                                else
                                    recentTime = recentMeleeHits[guid]
                                end
                            end
                        end

                        -- If we hit/crit this target recently, assume it is ours
                        if recentTime and (now - recentTime) < 2 then
                            isProc = true
                            local dbDuration = SpellDB:GetDuration(effect, 0) or (effect == "Deep Wound" and 12 or 10)

                            -- Track ownership
                            if SpellDB.TrackOwnerBoundDebuff then
                                SpellDB:TrackOwnerBoundDebuff(unit, effect, dbDuration)
                                if superwow_active and UnitExists("target") and UnitName("target") == unit then
                                    local guid = UnitGUID and UnitGUID("target")
                                    if guid then
                                        SpellDB:TrackOwnerBoundDebuff(guid, effect, dbDuration)
                                    end
                                end
                            end

                            -- Mark as owned in SpellDB
                            SpellDB:RefreshEffect(unit, unitlevel, effect, dbDuration, true)
                        end
                    end

                    if not isProc then
                        -- Not our spell, refresh or add the timer
                        local dbDuration = SpellDB:GetDuration(effect, 0)
                        SpellDB:RefreshEffect(unit, unitlevel, effect, dbDuration, false)
                    end
                end
            end
        end

    elseif event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
        -- Track player's own periodic damage (Deep Wound, etc.) for ownership inference
        -- This event fires when YOUR DoTs tick on enemies
        -- Format: "Your Deep Wound hits Target for X damage." or "Target suffers X damage from your Deep Wound."
        if arg1 and SpellDB then
            local effect, unit, damage

            -- Pattern 1: "Your Spell hits Target for X damage."
            for e, u in string_gfind(arg1, "Your (.+) hits (.+) for %d+") do
                effect, unit = e, u
                break
            end

            -- Pattern 2: "Target suffers X damage from your Spell."
            if not effect then
                for u, e in string_gfind(arg1, "(.+) suffers %d+ .+ from your (.+)%.") do
                    unit, effect = u, e
                    break
                end
            end

            -- Pattern 3: "Your Spell crits Target for X damage."
            if not effect then
                for e, u in string_gfind(arg1, "Your (.+) crits (.+) for %d+") do
                    effect, unit = e, u
                    break
                end
            end

            if effect and unit then
                -- Strip any rank info
                effect = StripSpellRank(effect)

                -- Check if this is an OWNER_BOUND_DEBUFF (like Deep Wound)
                if SpellDB.OWNER_BOUND_DEBUFFS and SpellDB.OWNER_BOUND_DEBUFFS[effect] then
                    local duration = SpellDB:GetDuration(effect, 0) or 12

                    -- Track ownership - the player owns this debuff on this target
                    if SpellDB.TrackOwnerBoundDebuff then
                        SpellDB:TrackOwnerBoundDebuff(unit, effect, duration)

                        -- Also track by GUID if target matches
                        if superwow_active and UnitExists("target") and UnitName("target") == unit then
                            local guid = UnitGUID and UnitGUID("target")
                            if guid then
                                SpellDB:TrackOwnerBoundDebuff(guid, effect, duration)
                            end
                        end
                    end

                    -- Also update SpellDB for timer display
                    local unitlevel = UnitExists("target") and UnitName("target") == unit and UnitLevel("target") or 0
                    SpellDB:RefreshEffect(unit, unitlevel, effect, duration, true)
                end
            end
        end

    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" then
        -- Track melee crits for Deep Wound heuristic
        -- Format: "You crit Target for X damage." or "You hit Target for X damage."
        if arg1 then
            local unit

            -- Pattern: "You crit Target for X damage."
            for u in string_gfind(arg1, "You crit (.+) for %d+") do
                unit = u
                break
            end

            if unit then
                -- Record that we crit this target recently
                recentMeleeCrits[unit] = GetTime()

                -- Also store by GUID if available
                if superwow_active and UnitExists("target") and UnitName("target") == unit then
                    local guid = UnitGUID and UnitGUID("target")
                    if guid then
                        recentMeleeCrits[guid] = GetTime()
                    end
                end
            end
        end

    elseif event == "CHAT_MSG_SPELL_AURA_GONE_OTHER" or event == "CHAT_MSG_SPELL_AURA_GONE_SELF" then
        if arg1 then
            -- Pattern: "Spell fades from Unit."
            for rawSpell, unit in string_gfind(arg1, "(.+) fades from (.+)%.") do
                local spell = StripSpellRank(rawSpell)
                -- Also strip stack count if present (Cursive/SuperWoW might add it)
                for s, c in string_gfind(spell, "(.+) %((%d+)%)$") do spell = s break end

                debuffTracker[unit .. spell] = nil
                -- Remove from SpellDB objects (all levels)
                if SpellDB and SpellDB.objects and SpellDB.objects[unit] then
                    for level, effects in pairs(SpellDB.objects[unit]) do
                        if effects[spell] then effects[spell] = nil end
                    end
                end
                -- Remove from OWNER_BOUND_DEBUFFS cache
                if SpellDB and SpellDB.RemoveOwnerBoundDebuff then
                    SpellDB:RemoveOwnerBoundDebuff(unit, spell)
                end
            end
            for rawSpell, unit in string_gfind(arg1, "(.+) is removed from (.+)%.") do
                local spell = StripSpellRank(rawSpell)
                -- Also strip stack count if present
                for s, c in string_gfind(spell, "(.+) %((%d+)%)$") do spell = s break end

                debuffTracker[unit .. spell] = nil
                if SpellDB and SpellDB.objects and SpellDB.objects[unit] then
                    for level, effects in pairs(SpellDB.objects[unit]) do
                        if effects[spell] then effects[spell] = nil end
                    end
                end
                -- Remove from OWNER_BOUND_DEBUFFS cache
                if SpellDB and SpellDB.RemoveOwnerBoundDebuff then
                    SpellDB:RemoveOwnerBoundDebuff(unit, spell)
                end
            end
        end
    end
end)

-- Slash command to toggle role
SLASH_GUDAPLATES1 = "/gudaplates"
SLASH_GUDAPLATES2 = "/gp"
SlashCmdList["GUDAPLATES"] = function(msg)
    msg = string_lower(msg or "")
    if msg == "tank" then
        playerRole = "TANK"
        Print("Role set to TANK - Blue=you have aggro, Red=need to taunt")
    elseif msg == "dps" or msg == "healer" then
        playerRole = "DPS"
        Print("Role set to DPS/HEALER - Red=mob attacking you, Blue=tank has aggro")
    elseif msg == "toggle" then
        if playerRole == "TANK" then
            playerRole = "DPS"
            Print("Role set to DPS/HEALER")
        else
            playerRole = "TANK"
            Print("Role set to TANK")
        end
    elseif msg == "config" or msg == "options" then
        if GudaPlatesOptionsFrame:IsShown() then
            GudaPlatesOptionsFrame:Hide()
        else
            GudaPlatesOptionsFrame:Show()
        end
    elseif msg == "debug" or msg == "debuffs" then
        -- Show all debuffs on current target using tooltip scanning
        if not UnitExists("target") then
            Print("No target selected. Target a unit with debuffs first.")
            return
        end
        local targetName = UnitName("target") or "target"
        Print("=== Debuffs on " .. targetName .. " ===")
        local found = false
        for i = 1, 40 do
            local texture, count = UnitDebuff("target", i)
            if not texture then break end
            found = true
            -- Use tooltip scanning to get spell name
            local spellName = SpellDB and SpellDB:ScanDebuff("target", i)
            local duration = spellName and SpellDB and SpellDB:GetDuration(spellName, 0)
            local durationStr = duration and (duration .. "s") or "NOT IN DB"
            Print(i .. ": " .. (spellName or "UNKNOWN") .. " (" .. durationStr .. ")")
            -- Check if we have tracked data
            if SpellDB and spellName then
                local tracked = SpellDB:GetTrackedDebuff(targetName, spellName)
                if tracked then
                    local remaining = tracked.duration - (GetTime() - tracked.start)
                    Print("   -> TRACKED: " .. string_format("%.1f", remaining) .. "s left (rank " .. (tracked.rank or 0) .. ")")
                end
            end
        end
        if not found then
            Print("No debuffs found on target.")
        end
        Print("=== End of debuffs ===")
    elseif msg == "tracked" then
        -- Show all tracked debuffs in SpellDB (ShaguPlates-style objects)
        Print("=== Tracked Debuffs ===")
        if SpellDB and SpellDB.objects then
            local count = 0
            for unitName, levels in pairs(SpellDB.objects) do
                for level, debuffs in pairs(levels) do
                    for spellName, data in pairs(debuffs) do
                        if data.start and data.duration then
                            local remaining = data.duration - (GetTime() - data.start)
                            if remaining > 0 then
                                Print(unitName .. " (L" .. level .. "): " .. spellName .. " - " .. string_format("%.1f", remaining) .. "s left")
                                count = count + 1
                            end
                        end
                    end
                end
            end
            if count == 0 then
                Print("No tracked debuffs.")
            end
        else
            Print("SpellDB not loaded or no tracked debuffs.")
        end
        Print("=== End of tracked ===")
    elseif msg == "pending" then
        -- Show pending spell cast (ShaguPlates-style array format)
        Print("=== Pending Spell ===")
        if SpellDB and SpellDB.pending and SpellDB.pending[3] then
            local p = SpellDB.pending
            Print("Unit: " .. (p[1] or "nil"))
            Print("Level: " .. (p[2] or 0))
            Print("Spell: " .. (p[3] or "nil"))
            Print("Duration: " .. (p[4] or "nil") .. "s")
        else
            Print("No pending spell.")
        end
    elseif msg == "spelldb" then
        -- Test SpellDB loading
        Print("=== SpellDB Status ===")
        if SpellDB then
            Print("SpellDB loaded: YES")
            Print("GetDuration: " .. tostring(SpellDB.GetDuration ~= nil))
            Print("ScanDebuff: " .. tostring(SpellDB.ScanDebuff ~= nil))
            -- Test Rend lookup
            local rendDur = SpellDB:GetDuration("Rend", 2)
            Print("Test - Rend Rank 2 -> " .. tostring(rendDur) .. "s")
            local rendMax = SpellDB:GetDuration("Rend", 0)
            Print("Test - Rend default -> " .. tostring(rendMax) .. "s")
        else
            Print("SpellDB loaded: NO")
            Print("GudaPlates_SpellDB: " .. tostring(GudaPlates_SpellDB ~= nil))
        end
    elseif string_find(msg, "^othertank") then
        -- Set OTHER_TANK color: /gp othertank <preset> or /gp othertank r g b
        local args = string_gsub(msg, "^othertank%s*", "")
        local COLOR_PRESETS = {
            lightblue = {0.6, 0.8, 1.0, 1},
            cyan = {0.0, 1.0, 1.0, 1},
            green = {0.0, 0.8, 0.0, 1},
            teal = {0.0, 0.5, 0.5, 1},
            purple = {0.6, 0.4, 0.8, 1},
            pink = {0.376, 0.027, 0.431, 1},
            yellow = {1.0, 1.0, 0.0, 1},
            white = {1.0, 1.0, 1.0, 1},
            gray = {0.5, 0.5, 0.5, 1},
        }
        if args == "" then
            Print("OTHER_TANK color presets: lightblue, cyan, green, teal, purple, pink, yellow, white, gray")
            Print("Usage: /gp othertank <preset> or /gp othertank <r> <g> <b> (0-1 values)")
            local c = THREAT_COLORS.TANK.OTHER_TANK
            Print("Current: " .. string_format("%.2f %.2f %.2f", c[1], c[2], c[3]))
        elseif COLOR_PRESETS[args] then
            THREAT_COLORS.TANK.OTHER_TANK = COLOR_PRESETS[args]
            SaveSettings()
            Print("OTHER_TANK color set to: " .. args)
        else
            -- Try to parse as RGB values
            local r, g, b = string.match(args, "([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
            if r and g and b then
                r, g, b = tonumber(r), tonumber(g), tonumber(b)
                if r and g and b and r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1 then
                    THREAT_COLORS.TANK.OTHER_TANK = {r, g, b, 1}
                    SaveSettings()
                    Print("OTHER_TANK color set to: " .. string_format("%.2f %.2f %.2f", r, g, b))
                else
                    Print("Invalid RGB values. Use values between 0 and 1.")
                end
            else
                Print("Unknown preset: " .. args)
                Print("Available presets: lightblue, cyan, green, teal, purple, pink, yellow, white, gray")
            end
        end
    elseif msg == "finddebuff" then
        if UnitExists("target") then
            Print("=== All Debuffs on Target ===")
            for i = 1, 40 do
                local texture, stacks = UnitDebuff("target", i)
                if not texture then break end

                -- Try to get spell name via tooltip
                local spellName = "Unknown"
                if SpellDB then
                    spellName = SpellDB:ScanDebuff("target", i) or "Unknown"
                end

                Print(i .. ": " .. texture .. " -> " .. spellName)
            end
        else
            Print("No target selected")
        end
    else
        Print("Commands: /gp tank | /gp dps | /gp toggle | /gp config")
        Print("         /gp othertank <color> - Set Other Tank Aggro color")
        Print("         /gp debug - Show target debuffs with tooltip scanning")
        Print("         /gp tracked - Show all tracked debuffs")
        Print("         /gp pending - Show pending spell cast")
        Print("         /gp spelldb - Test SpellDB loading")
        Print("Current role: " .. playerRole)
    end
end

-- Saved Variables (will be loaded from SavedVariables)
GudaPlatesDB = GudaPlatesDB or {}

local function SaveSettings()
    GudaPlatesDB.playerRole = playerRole
    GudaPlatesDB.THREAT_COLORS = THREAT_COLORS
    GudaPlatesDB.nameplateOverlap = nameplateOverlap
    GudaPlatesDB.nameplateClickThrough = clickThrough
    GudaPlatesDB.minimapAngle = minimapAngle
    GudaPlatesDB.Settings = Settings  -- Save entire Settings table

    -- Sync back to GudaPlates global table for consistency
    GudaPlates.playerRole = playerRole
    GudaPlates.THREAT_COLORS = THREAT_COLORS
    GudaPlates.nameplateOverlap = nameplateOverlap
    GudaPlates.nameplateClickThrough = clickThrough
    GudaPlates.minimapAngle = minimapAngle
    GudaPlates.Settings = Settings
end
GudaPlates.SaveSettings = SaveSettings  -- Expose for Options module

-- LoadSettings is forward-declared at the top of the file
LoadSettings = function()
    if GudaPlatesDB.playerRole then
        playerRole = GudaPlatesDB.playerRole
    end
    if GudaPlatesDB.nameplateOverlap ~= nil then
        nameplateOverlap = GudaPlatesDB.nameplateOverlap
    end
    if GudaPlatesDB.nameplateClickThrough ~= nil then
        clickThrough = GudaPlatesDB.nameplateClickThrough
    end
    if GudaPlatesDB.minimapAngle then
        minimapAngle = GudaPlatesDB.minimapAngle
    end
    -- Load Settings table
    if GudaPlatesDB.Settings then
        for key, value in pairs(GudaPlatesDB.Settings) do
            Settings[key] = value
        end
    end
    -- Legacy support: load old individual settings into Settings table
    if GudaPlatesDB.healthbarHeight then Settings.healthbarHeight = GudaPlatesDB.healthbarHeight end
    if GudaPlatesDB.healthbarWidth then Settings.healthbarWidth = GudaPlatesDB.healthbarWidth end
    if GudaPlatesDB.healthFontSize then Settings.healthFontSize = GudaPlatesDB.healthFontSize end
    if GudaPlatesDB.levelFontSize then Settings.levelFontSize = GudaPlatesDB.levelFontSize end
    if GudaPlatesDB.nameFontSize then Settings.nameFontSize = GudaPlatesDB.nameFontSize end
    if GudaPlatesDB.raidIconPosition then Settings.raidIconPosition = GudaPlatesDB.raidIconPosition end
    if GudaPlatesDB.swapNameDebuff ~= nil then Settings.swapNameDebuff = GudaPlatesDB.swapNameDebuff end
    if GudaPlatesDB.showDebuffTimers ~= nil then Settings.showDebuffTimers = GudaPlatesDB.showDebuffTimers end
    if GudaPlatesDB.showOnlyMyDebuffs ~= nil then Settings.showOnlyMyDebuffs = GudaPlatesDB.showOnlyMyDebuffs end
    if GudaPlatesDB.showManaBar ~= nil then Settings.showManaBar = GudaPlatesDB.showManaBar end
    if GudaPlatesDB.castbarHeight then Settings.castbarHeight = GudaPlatesDB.castbarHeight end
    if GudaPlatesDB.castbarWidth then Settings.castbarWidth = GudaPlatesDB.castbarWidth end
    if GudaPlatesDB.castbarIndependent ~= nil then Settings.castbarIndependent = GudaPlatesDB.castbarIndependent end
    if GudaPlatesDB.showCastbarIcon ~= nil then Settings.showCastbarIcon = GudaPlatesDB.showCastbarIcon end
    -- Load THREAT_COLORS
    if GudaPlatesDB.THREAT_COLORS then
        for role, colors in pairs(GudaPlatesDB.THREAT_COLORS) do
            if THREAT_COLORS[role] then
                for colorType, colorVal in pairs(colors) do
                    if THREAT_COLORS[role][colorType] then
                        THREAT_COLORS[role][colorType] = colorVal
                    end
                end
            end
        end
        if GudaPlatesDB.THREAT_COLORS.TAPPED then
            THREAT_COLORS.TAPPED = GudaPlatesDB.THREAT_COLORS.TAPPED
        end
        if GudaPlatesDB.THREAT_COLORS.STUN then
            THREAT_COLORS.STUN = GudaPlatesDB.THREAT_COLORS.STUN
        end
        if GudaPlatesDB.THREAT_COLORS.MANA_BAR then
            THREAT_COLORS.MANA_BAR = GudaPlatesDB.THREAT_COLORS.MANA_BAR
        end
    end

    -- Update global GudaPlates table to reflect loaded settings
    GudaPlates.playerRole = playerRole
    GudaPlates.nameplateOverlap = nameplateOverlap
    GudaPlates.minimapAngle = minimapAngle
    GudaPlates.Settings = Settings
    GudaPlates.THREAT_COLORS = THREAT_COLORS
end

-- Minimap Button
local minimapButton = CreateFrame("Button", "GudaPlatesMinimapButton", Minimap)
minimapButton:SetWidth(32)
minimapButton:SetHeight(32)
minimapButton:SetFrameStrata("LOW")
minimapButton:SetToplevel(true)
minimapButton:SetMovable(true)
minimapButton:EnableMouse(true)
minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local minimapIcon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapIcon:SetTexture("Interface\\Icons\\Spell_Nature_WispSplode")
minimapIcon:SetWidth(20)
minimapIcon:SetHeight(20)
minimapIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
minimapIcon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)

local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetWidth(52)
minimapBorder:SetHeight(52)
minimapBorder:SetPoint("CENTER", minimapButton, "CENTER", 10, -10)

-- Minimap button dragging
local function UpdateMinimapButtonPosition()
    local rad = math.rad(minimapAngle)
    local x = math.cos(rad) * 80
    local y = math.sin(rad) * 80
    minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - x, y - 52)
end
GudaPlates.UpdateMinimapButtonPosition = UpdateMinimapButtonPosition  -- Expose for Options module
UpdateMinimapButtonPosition()

minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
minimapButton:RegisterForDrag("LeftButton", "RightButton")
minimapButton:SetScript("OnDragStart", function()
    this.dragging = true
    this:LockHighlight()
end)

minimapButton:SetScript("OnDragStop", function()
    this.dragging = false
    this:UnlockHighlight()
    SaveSettings()
end)

minimapButton:SetScript("OnUpdate", function()
    if this.dragging then
        local xpos, ypos = GetCursorPosition()
        local xmin, ymin = Minimap:GetLeft() or 400, Minimap:GetBottom() or 400
        local mscale = Minimap:GetEffectiveScale()

        -- TrinketMenu logic:
        -- xpos = xmin - xpos / mscale + 70
        -- ypos = ypos / mscale - ymin - 70
        -- angle = math.deg(math.atan2(ypos, xpos))

        local dx = xmin - xpos / mscale + 70
        local dy = ypos / mscale - ymin - 70
        minimapAngle = math.deg(math.atan2(dy, dx))
        UpdateMinimapButtonPosition()
    end
end)

minimapButton:SetScript("OnClick", function()
    if arg1 == "RightButton" or IsControlKeyDown() then
        if GudaPlatesOptionsFrame:IsShown() then
            GudaPlatesOptionsFrame:Hide()
        else
            GudaPlatesOptionsFrame:Show()
        end
    end
end)

minimapButton:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:AddLine("GudaPlates")
    GameTooltip:AddLine("Left-Drag to move button", 1, 1, 1)
    GameTooltip:AddLine("Right-Click or Ctrl-Left-Click for settings", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Options UI has been moved to GudaPlates_Options.lua

-- Load settings on addon load
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("VARIABLES_LOADED")
loadFrame:SetScript("OnEvent", function()
    LoadSettings()
    UpdateMinimapButtonPosition()
    -- Use global frame name since optionsFrame is now in Options module
    if GudaPlatesOptionsFrame and GudaPlatesOptionsFrame.UpdateBackdrop then
        GudaPlatesOptionsFrame.UpdateBackdrop()
    end
    -- Update font dropdown to reflect loaded setting
    if GudaPlatesFontDropdown then
        UIDropDownMenu_SetSelectedValue(GudaPlatesFontDropdown, Settings.textFont)
        -- Also update the displayed text (fontOptions is now in GudaPlates table)
        if GudaPlates.fontOptions then
            for _, opt in ipairs(GudaPlates.fontOptions) do
                if opt.value == Settings.textFont then
                    UIDropDownMenu_SetText(opt.text, GudaPlatesFontDropdown)
                    break
                end
            end
        end
    end
    Print("Settings loaded.")

    -- Test the spell database
    if SpellDB then
        Print("Spell database loaded successfully")
        -- Quick test with Rend
        local duration = SpellDB:GetDuration("Rend", 2)
        Print("  Test - Rend Rank 2 -> " .. tostring(duration) .. "s (expected: 12)")
    else
        Print("ERROR: Spell database not loaded!")
    end
end)


Print("Loaded. Use /gp tank or /gp dps to set role.")