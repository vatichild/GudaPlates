-- GudaPlates Spell Database
-- Debuff duration tracking with rank support (ShaguTweaks-style)

GudaPlates_SpellDB = {}

-- ============================================
-- DEBUFF DURATIONS BY SPELL NAME AND RANK
-- Format: ["Spell Name"] = { [rank] = duration, [0] = default/max }
-- ============================================
GudaPlates_SpellDB.DEBUFFS = {
	-- WARRIOR
	["Rend"] = {[1]=9, [2]=12, [3]=15, [4]=18, [5]=21, [6]=21, [7]=21, [0]=21},
	["Thunder Clap"] = {[1]=10, [2]=14, [3]=18, [4]=22, [5]=26, [6]=30, [0]=30},
	["Sunder Armor"] = {[0]=30},
	["Disarm"] = {[0]=10},
	["Hamstring"] = {[0]=15},
	["Demoralizing Shout"] = {[0]=30},
	["Intimidating Shout"] = {[0]=8},
	["Concussion Blow"] = {[0]=5},
	["Mocking Blow"] = {[0]=6},
	["Piercing Howl"] = {[0]=6},
	["Mortal Strike"] = {[0]=10},
	["Deep Wounds"] = {[0]=12},

	-- ROGUE
	["Cheap Shot"] = {[0]=4},
	["Kidney Shot"] = {[0]=1}, -- +1s per combo point, handled dynamically
	["Sap"] = {[1]=25, [2]=35, [3]=45, [0]=45},
	["Blind"] = {[0]=10},
	["Gouge"] = {[0]=4}, -- +0.5s per talent point
	["Rupture"] = {[0]=8}, -- +2s per combo point, handled dynamically
	["Garrote"] = {[1]=18, [2]=18, [3]=18, [4]=18, [5]=18, [0]=18},
	["Expose Armor"] = {[0]=30},
	["Crippling Poison"] = {[0]=12},
	["Deadly Poison"] = {[0]=12},
	["Deadly Poison II"] = {[0]=12},
	["Deadly Poison III"] = {[0]=12},
	["Deadly Poison IV"] = {[0]=12},
	["Deadly Poison V"] = {[0]=12},
	["Mind-numbing Poison"] = {[0]=14},
	["Mind-numbing Poison II"] = {[0]=14},
	["Mind-numbing Poison III"] = {[0]=14},
	["Wound Poison"] = {[0]=15},
	["Wound Poison II"] = {[0]=15},
	["Wound Poison III"] = {[0]=15},
	["Wound Poison IV"] = {[0]=15},
	["Instant Poison"] = {[0]=3},
	["Instant Poison II"] = {[0]=3},
	["Instant Poison III"] = {[0]=3},
	["Instant Poison IV"] = {[0]=3},
	["Instant Poison V"] = {[0]=3},
	["Instant Poison VI"] = {[0]=3},

	-- MAGE
	["Frost Nova"] = {[1]=8, [2]=8, [3]=8, [4]=8, [0]=8},
	["Polymorph"] = {[1]=20, [2]=30, [3]=40, [4]=50, [0]=50},
	["Polymorph: Pig"] = {[0]=50},
	["Polymorph: Turtle"] = {[0]=50},
	["Polymorph: Cow"] = {[0]=50},
	["Frostbolt"] = {[1]=5, [2]=6, [3]=7, [4]=8, [5]=9, [6]=9, [7]=9, [8]=9, [9]=9, [10]=9, [11]=9, [0]=9},
	["Cone of Cold"] = {[0]=8},
	["Frostbite"] = {[0]=5},
	["Counterspell - Silenced"] = {[0]=4},
	["Winter's Chill"] = {[0]=15},
	["Fireball"] = {[0]=8}, -- DoT component
	["Pyroblast"] = {[0]=12}, -- DoT component
	["Ignite"] = {[0]=4},
	["Fire Vulnerability"] = {[0]=30},

	-- WARLOCK
	["Corruption"] = {[1]=12, [2]=15, [3]=18, [4]=18, [5]=18, [6]=18, [7]=18, [0]=18},
	["Immolate"] = {[1]=15, [2]=15, [3]=15, [4]=15, [5]=15, [6]=15, [7]=15, [8]=15, [0]=15},
	["Fear"] = {[1]=10, [2]=15, [3]=20, [0]=20},
	["Howl of Terror"] = {[1]=10, [2]=15, [0]=15},
	["Death Coil"] = {[0]=3},
	["Curse of Agony"] = {[1]=24, [2]=24, [3]=24, [4]=24, [5]=24, [6]=24, [0]=24},
	["Curse of Weakness"] = {[0]=120},
	["Curse of Recklessness"] = {[0]=120},
	["Curse of Tongues"] = {[0]=30},
	["Curse of the Elements"] = {[0]=300},
	["Curse of Shadow"] = {[0]=300},
	["Curse of Exhaustion"] = {[0]=12},
	["Curse of Doom"] = {[0]=60},
	["Siphon Life"] = {[0]=30},
	["Drain Life"] = {[0]=5},
	["Drain Mana"] = {[0]=5},
	["Drain Soul"] = {[0]=15},
	["Banish"] = {[1]=20, [2]=30, [0]=30},
	["Enslave Demon"] = {[0]=300},
	["Seduction"] = {[0]=15},
	["Shadow Vulnerability"] = {[0]=30},

	-- PRIEST
	["Shadow Word: Pain"] = {[1]=18, [2]=18, [3]=18, [4]=18, [5]=18, [6]=18, [7]=18, [8]=18, [0]=18},
	["Psychic Scream"] = {[1]=8, [2]=8, [3]=8, [4]=8, [0]=8},
	["Mind Flay"] = {[0]=3},
	["Mind Control"] = {[0]=60},
	["Silence"] = {[0]=5},
	["Weakened Soul"] = {[0]=15},
	["Devouring Plague"] = {[0]=24},
	["Vampiric Embrace"] = {[0]=60},
	["Blackout"] = {[0]=3},
	["Mana Burn"] = {[0]=0}, -- instant

	-- HUNTER
	["Serpent Sting"] = {[1]=15, [2]=15, [3]=15, [4]=15, [5]=15, [6]=15, [7]=15, [8]=15, [9]=15, [0]=15},
	["Viper Sting"] = {[1]=8, [2]=8, [3]=8, [4]=8, [0]=8},
	["Scorpid Sting"] = {[0]=20},
	["Concussive Shot"] = {[0]=4},
	["Scatter Shot"] = {[0]=4},
	["Wing Clip"] = {[0]=10},
	["Improved Concussive Shot"] = {[0]=3},
	["Hunter's Mark"] = {[0]=120},
	["Counterattack"] = {[0]=5},
	["Wyvern Sting"] = {[0]=12}, -- sleep, then 12s DoT
	["Freezing Trap Effect"] = {[0]=20},
	["Immolation Trap Effect"] = {[0]=15},
	["Intimidation"] = {[0]=3},
	["Entrapment"] = {[0]=5},

	-- DRUID
	["Moonfire"] = {[1]=9, [2]=12, [3]=12, [4]=12, [5]=12, [6]=12, [7]=12, [8]=12, [9]=12, [10]=12, [0]=12},
	["Entangling Roots"] = {[1]=12, [2]=15, [3]=18, [4]=21, [5]=24, [6]=27, [0]=27},
	["Bash"] = {[1]=2, [2]=3, [3]=4, [0]=4},
	["Faerie Fire"] = {[0]=40},
	["Faerie Fire (Feral)"] = {[0]=40},
	["Rake"] = {[1]=9, [2]=9, [3]=9, [4]=9, [0]=9},
	["Rip"] = {[1]=12, [2]=12, [3]=12, [4]=12, [5]=12, [0]=12},
	["Pounce Bleed"] = {[0]=18},
	["Pounce"] = {[0]=3}, -- stun component
	["Insect Swarm"] = {[0]=12},
	["Hibernate"] = {[1]=20, [2]=30, [3]=40, [0]=40},
	["Feral Charge Effect"] = {[0]=4},

	-- PALADIN
	["Hammer of Justice"] = {[1]=3, [2]=4, [3]=5, [4]=6, [0]=6},
	["Turn Undead"] = {[0]=20},
	["Repentance"] = {[0]=6},
	["Judgement of the Crusader"] = {[0]=10},
	["Judgement of Light"] = {[0]=10},
	["Judgement of Wisdom"] = {[0]=10},
	["Judgement of Justice"] = {[0]=10},

	-- SHAMAN
	["Frost Shock"] = {[1]=8, [2]=8, [3]=8, [4]=8, [0]=8},
	["Earth Shock"] = {[0]=2}, -- interrupt
	["Flame Shock"] = {[1]=12, [2]=12, [3]=12, [4]=12, [5]=12, [6]=12, [0]=12},
	["Earthbind"] = {[0]=5}, -- per pulse
	["Stoneclaw Stun"] = {[0]=3},
	["Stormstrike"] = {[0]=12},
}

-- Dynamic debuffs that scale with combo points
GudaPlates_SpellDB.COMBO_POINT_DEBUFFS = {
	["Kidney Shot"] = {base = 1, perPoint = 1}, -- 1s + 1s per CP
	["Rupture"] = {base = 8, perPoint = 2},     -- 8s + 2s per CP
}

-- NOTE: Texture-to-spell mapping removed because many spells share icons
-- (e.g., Rend and Gouge both use Ability_Gouge)
-- Instead, we use tooltip scanning to get the actual spell name

-- ============================================
-- DEBUFF TRACKING STATE
-- ============================================
GudaPlates_SpellDB.tracked = {}      -- Tracked debuffs: [unitName][spellName] = {start, duration}
GudaPlates_SpellDB.pending = {}      -- Pending spell cast: {unit, spell, rank, duration}
GudaPlates_SpellDB.lastComboPoints = 0

-- ============================================
-- DURATION LOOKUP FUNCTIONS
-- ============================================

-- Get duration by spell name and rank
function GudaPlates_SpellDB:GetDuration(spellName, rank)
	if not spellName then return nil end

	local spellData = self.DEBUFFS[spellName]
	if not spellData then return nil end

	rank = rank or 0

	-- Try exact rank first, then fall back to [0] (default/max)
	return spellData[rank] or spellData[0]
end

-- Get duration from texture - DEPRECATED, use ScanDebuff + GetDuration instead
function GudaPlates_SpellDB:GetDurationFromTexture(texture)
	-- Texture mapping removed - textures can be shared by multiple spells
	-- Use tooltip scanning instead
	return nil
end

-- Get spell name from texture - DEPRECATED, use ScanDebuff instead
function GudaPlates_SpellDB:GetSpellFromTexture(texture)
	-- Texture mapping removed - textures can be shared by multiple spells
	-- Use tooltip scanning instead
	return nil
end

-- ============================================
-- DEBUFF TRACKING FUNCTIONS
-- ============================================

-- Add a pending spell (called when player starts casting)
function GudaPlates_SpellDB:AddPending(unitName, spellName, rank, duration)
	if not unitName or not spellName then return end

	-- Store combo points for combo-point-based abilities
	if self.COMBO_POINT_DEBUFFS[spellName] then
		self.lastComboPoints = GetComboPoints("player", "target") or 0
	end

	self.pending = {
		unit = unitName,
		spell = spellName,
		rank = rank or 0,
		duration = duration,
		time = GetTime()
	}
end

-- Clear pending spell
function GudaPlates_SpellDB:ClearPending()
	self.pending = {}
end

-- Confirm pending spell was applied (called on combat log confirmation)
function GudaPlates_SpellDB:ConfirmPending(unitName, spellName)
	local p = self.pending
	if not p.spell then return false end

	-- Check if this matches our pending spell (within 2 seconds)
	if p.unit == unitName and p.spell == spellName and (GetTime() - p.time) < 2 then
		self:AddTrackedDebuff(unitName, spellName, p.rank, p.duration)
		self:ClearPending()
		return true
	end

	return false
end

-- Add/update a tracked debuff
function GudaPlates_SpellDB:AddTrackedDebuff(unitName, spellName, rank, duration)
	if not unitName or not spellName then return end

	-- Calculate duration
	if not duration then
		-- Check for combo point scaling
		local cpData = self.COMBO_POINT_DEBUFFS[spellName]
		if cpData then
			local cp = self.lastComboPoints or 0
			duration = cpData.base + (cpData.perPoint * cp)
		else
			duration = self:GetDuration(spellName, rank)
		end
	end

	if not duration then return end

	-- Initialize tracking table for this unit
	if not self.tracked[unitName] then
		self.tracked[unitName] = {}
	end

	-- Store the debuff
	self.tracked[unitName][spellName] = {
		start = GetTime(),
		duration = duration,
		rank = rank or 0
	}
end

-- Get tracked debuff info
function GudaPlates_SpellDB:GetTrackedDebuff(unitName, spellName)
	if not unitName or not spellName then return nil end
	if not self.tracked[unitName] then return nil end

	local debuff = self.tracked[unitName][spellName]
	if not debuff then return nil end

	-- Check if expired
	local elapsed = GetTime() - debuff.start
	if elapsed >= debuff.duration then
		self.tracked[unitName][spellName] = nil
		return nil
	end

	return debuff
end

-- Get time remaining on a tracked debuff
function GudaPlates_SpellDB:GetTimeRemaining(unitName, spellName)
	local debuff = self:GetTrackedDebuff(unitName, spellName)
	if not debuff then return nil end

	return debuff.duration - (GetTime() - debuff.start)
end

-- Clean up expired debuffs
function GudaPlates_SpellDB:CleanupExpired()
	local now = GetTime()
	for unitName, debuffs in pairs(self.tracked) do
		for spellName, debuff in pairs(debuffs) do
			if (now - debuff.start) >= debuff.duration then
				debuffs[spellName] = nil
			end
		end
		-- Remove empty unit tables
		local hasDebuffs = false
		for _ in pairs(debuffs) do hasDebuffs = true; break end
		if not hasDebuffs then
			self.tracked[unitName] = nil
		end
	end
end

-- ============================================
-- TOOLTIP SCANNER (for getting spell name from debuff)
-- ============================================
GudaPlates_SpellDB.scanner = nil

function GudaPlates_SpellDB:InitScanner()
	if self.scanner then return end

	-- Create hidden tooltip for scanning
	self.scanner = CreateFrame("GameTooltip", "GudaPlatesDebuffScanner", UIParent, "GameTooltipTemplate")
	self.scanner:SetOwner(UIParent, "ANCHOR_NONE")
end

function GudaPlates_SpellDB:ScanDebuff(unit, index)
	if not self.scanner then self:InitScanner() end

	self.scanner:ClearLines()
	self.scanner:SetUnitDebuff(unit, index)

	local textLeft = getglobal("GudaPlatesDebuffScannerTextLeft1")
	if textLeft then
		local text = textLeft:GetText()
		return text
	end

	return nil
end

-- ============================================
-- INITIALIZATION
-- ============================================
_G["GudaPlates_SpellDB"] = GudaPlates_SpellDB

if DEFAULT_CHAT_FRAME then
	local count = 0
	for _ in pairs(GudaPlates_SpellDB.DEBUFFS) do count = count + 1 end
	DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[GudaPlates]|r SpellDB loaded with " .. count .. " spells")
end
