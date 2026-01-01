-- GudaPlates Spell Database - SIMPLIFIED VERSION
-- This will definitely load and work

GudaPlates_SpellDB = {}

-- SIMPLE texture to duration mapping (no spell IDs for now)
GudaPlates_SpellDB.TEXTURE_DURATIONS = {
	-- Warrior
	["Interface\\Icons\\Ability_Gouge"] = 21, -- Rend (Warrior max rank)
	["Interface\\Icons\\Ability_ShockWave"] = 30, -- Thunder Clap
	["Interface\\Icons\\Ability_Warrior_Sunder"] = 30, -- Sunder Armor
	["Interface\\Icons\\Ability_Warrior_Disarm"] = 10, -- Disarm
	["Interface\\Icons\\Ability_ShieldBash"] = 6, -- Shield Bash

	-- Rogue
	["Interface\\Icons\\Ability_Rogue_Trip"] = 4, -- Cheap Shot
	["Interface\\Icons\\Ability_Rogue_KidneyShot"] = 6, -- Kidney Shot max
	["Interface\\Icons\\Ability_Sap"] = 45, -- Sap max rank

	-- Mage
	["Interface\\Icons\\Spell_Frost_FrostNova"] = 8, -- Frost Nova
	["Interface\\Icons\\Spell_Nature_Polymorph"] = 50, -- Polymorph max

	-- Warlock
	["Interface\\Icons\\Spell_Shadow_AbominationExplosion"] = 18, -- Corruption
	["Interface\\Icons\\Spell_Fire_Immolation"] = 15, -- Immolate
	["Interface\\Icons\\Spell_Shadow_Possession"] = 20, -- Fear

	-- Priest
	["Interface\\Icons\\Spell_Shadow_ShadowWordPain"] = 18, -- Shadow Word: Pain

	-- Hunter
	["Interface\\Icons\\Ability_Hunter_Quickshot"] = 15, -- Serpent Sting

	-- Druid
	["Interface\\Icons\\Spell_Nature_StarFall"] = 12, -- Moonfire
	["Interface\\Icons\\Spell_Nature_StrangleVines"] = 33, -- Entangling Roots max

	-- Paladin
	["Interface\\Icons\\Spell_Holy_FistOfJustice"] = 6, -- Hammer of Justice max

	-- Shaman
	["Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02"] = 45, -- Earthbind Totem
	["Interface\\Icons\\Spell_Frost_FrostShock"] = 8, -- Frost Shock

	-- Default fallbacks for common texture patterns
	["Stun"] = 4,
	["Fear"] = 20,
	["Polymorph"] = 20,
	["Poison"] = 12,
	["Curse"] = 18,
	["Corruption"] = 18,
}

-- Simple function to get duration from texture
function GudaPlates_SpellDB:GetDurationFromTexture(texture)
	if not texture then return nil end

	-- First try exact match
	local duration = self.TEXTURE_DURATIONS[texture]
	if duration then return duration end

	-- Try partial matches for texture patterns
	for texPattern, dur in pairs(self.TEXTURE_DURATIONS) do
		if string.find(texture, texPattern) then
			return dur
		end
	end

	return nil -- Not found
end

-- Make it global (IMPORTANT!)
_G["GudaPlates_SpellDB"] = GudaPlates_SpellDB

-- Debug line to confirm loading
if DEFAULT_CHAT_FRAME then
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[GudaPlates]|r SpellDB loaded successfully!")
end