-- GudaPlates Core
-- Global table to share across files
GudaPlates = GudaPlates or {}

GudaPlates.superwow_active = (SpellInfo ~= nil) or (UnitGUID ~= nil) or (SUPERWOW_VERSION ~= nil)
GudaPlates.twthreat_active = UnitThreat ~= nil

GudaPlates.DEBUG_DURATION = false
GudaPlates.initialized = 0
GudaPlates.parentcount = 0
GudaPlates.platecount = 0
GudaPlates.registry = {}
GudaPlates.REGION_ORDER = { "border", "glow", "name", "level", "levelicon", "raidicon" }

-- Debuff settings
GudaPlates.MAX_DEBUFFS = 16
GudaPlates.DEBUFF_SIZE = 16

-- Tracking tables
GudaPlates.debuffTracker = {}
GudaPlates.debuffTimers = {}
GudaPlates.castDB = {}
GudaPlates.castTracker = {}

-- State
GudaPlates.playerRole = "DPS"
GudaPlates.minimapAngle = 220
GudaPlates.nameplateOverlap = true

-- Settings table
GudaPlates.Settings = {
    -- Healthbar
    healthbarHeight = 14,
    healthbarWidth = 115,
    healthFontSize = 10,
    -- Friendly Healthbar
    friendlyHealthbarHeight = 4,
    friendlyHealthbarWidth = 85,
    friendlyHealthFontSize = 6,
    showFriendlyNPCs = true,
    showHealthText = true,
    healthTextPosition = "CENTER",  -- "LEFT", "RIGHT", "CENTER"
    healthTextFormat = 1,  -- 1=Percent, 2=Current HP, 3=Health (%), 4=Current-Max, 5=Current-Max (%)
    -- Manabar
    showManaBar = false,
    showManaText = true,
    manaTextFormat = 1,  -- 1=Percent, 2=Current Mana, 3=Current Mana (%)
    manaTextPosition = "CENTER",  -- "LEFT", "RIGHT", "CENTER"
    manabarHeight = 4,
    -- Castbar
    castbarHeight = 12,
    castbarWidth = 115,
    castbarIndependent = false,
    showCastbarIcon = true,
    castbarColor = {1, 0.8, 0, 1},  -- Gold/Yellow color
    -- Fonts
    levelFontSize = 10,
    nameFontSize = 10,
    textFont = "Fonts\\ARIALN.TTF",  -- Default WoW font
    -- Layout
    raidIconPosition = "LEFT",
    swapNameDebuff = true,
    -- Features
    showOnlyMyDebuffs = true,
    showDebuffTimers = true,
    -- Target Glow
    showTargetGlow = true,
    targetGlowColor = {0.4, 0.8, 0.9, 0.4},  -- Dragonflight3-style cyan glow
    -- Text Colors
    nameColor = {1, 1, 1, 1},
    levelColor = {1, 1, 1, 1},
    healthTextColor = {1, 1, 1, 1},
    manaTextColor = {1, 1, 1, 1},
}

-- Threat colors
GudaPlates.THREAT_COLORS = {
    TANK = {
        AGGRO = {0.2, 0.8, 0.2, 1},      -- Green
        LOSING_AGGRO = {1, 0.6, 0, 1},   -- Orange
        NO_AGGRO = {0.8, 0.2, 0.2, 1},    -- Red
        OTHER_TANK = {0.4, 0.4, 1, 1},    -- Blue
    },
    DPS = {
        AGGRO = {0.8, 0.2, 0.2, 1},      -- Red
        HIGH_THREAT = {1, 0.6, 0, 1},    -- Orange
        NO_AGGRO = {0.2, 0.8, 0.2, 1},   -- Green
    },
    TAPPED = {0.5, 0.5, 0.5, 1},         -- Gray
    MANA_BAR = {0.3, 0.4, 0.9, 1},       -- Blue
}
