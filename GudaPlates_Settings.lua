-- GudaPlates_Settings.lua
-- Contains default settings and configuration tables for GudaPlates

GudaPlates = GudaPlates or {}

-- Default Settings
GudaPlates.Settings = {
    -- Healthbar (Enemy)
    healthbarHeight = 14,
    healthbarWidth = 115,
    healthFontSize = 10,
    healthTextPosition = "CENTER",  -- "LEFT", "RIGHT", "CENTER"
    healthTextFormat = 1,  -- 0=None, 1=Percent, 2=Current HP, 3=Health (%), 4=Current-Max, 5=Current-Max (%), 6=Name - %, 7=Name - HP(%), 8=Name
    -- Healthbar (Friendly)
    friendHealthbarHeight = 4,
    friendHealthbarWidth = 85,
    friendHealthFontSize = 10,
    friendHealthTextPosition = "CENTER",
    friendHealthTextFormat = 1,
    -- Manabar (Enemy)
    showManaBar = false,
    manaTextFormat = 1,  -- 0=None, 1=Percent, 2=Current Mana, 3=Current Mana (%)
    manaTextPosition = "CENTER",  -- "LEFT", "RIGHT", "CENTER"
    manabarHeight = 4,
    -- Manabar (Friendly)
    friendShowManaBar = false,
    friendManaTextFormat = 1,
    friendManaTextPosition = "CENTER",
    friendManabarHeight = 4,
    -- Castbar (Enemy)
    castbarHeight = 12,
    castbarWidth = 115,
    castbarIndependent = false,
    showCastbarIcon = true,
    -- Castbar (Friendly)
    friendCastbarHeight = 6,
    friendCastbarWidth = 85,
    friendCastbarIndependent = false,
    friendShowCastbarIcon = true,
    -- Colors
    castbarColor = {1, 0.8, 0, 1},  -- Gold/Yellow color
    -- Fonts
    levelFontSize = 10,
    nameFontSize = 10,
    friendLevelFontSize = 8,
    friendNameFontSize = 8,
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
    -- Debuffs
    debuffIconSize = 16,
    -- Text Colors
    nameColor = {1, 1, 1, 1},
    healthTextColor = {1, 1, 1, 1},
    manaTextColor = {1, 1, 1, 1},
    levelColor = {1, 1, 0.6, 1},
    -- UI Settings
    optionsBgAlpha = 0.9,
    hideOptionsBorder = false,
    -- Filtering
    showCritterNameplates = false,  -- Hide critter/ambient mob nameplates by default
}

-- Critter names list (from ShaguPlates) for fallback detection
GudaPlates.Critters = {
    ["adder"] = true,
    ["beetle"] = true,
    ["belfry bat"] = true,
    ["biletoad"] = true,
    ["black rat"] = true,
    ["brown prairie dog"] = true,
    ["caged rabbit"] = true,
    ["caged sheep"] = true,
    ["caged squirrel"] = true,
    ["caged toad"] = true,
    ["cat"] = true,
    ["chicken"] = true,
    ["cleo"] = true,
    ["core rat"] = true,
    ["cow"] = true,
    ["cured deer"] = true,
    ["cured gazelle"] = true,
    ["deeprun rat"] = true,
    ["deer"] = true,
    ["dog"] = true,
    ["effsee"] = true,
    ["enthralled deeprun rat"] = true,
    ["fang"] = true,
    ["fawn"] = true,
    ["fire beetle"] = true,
    ["fluffy"] = true,
    ["frog"] = true,
    ["gazelle"] = true,
    ["hare"] = true,
    ["horse"] = true,
    ["huge toad"] = true,
    ["infected deer"] = true,
    ["infected squirrel"] = true,
    ["jungle toad"] = true,
    ["krakle's thermometer"] = true,
    ["lady"] = true,
    ["larva"] = true,
    ["lava crab"] = true,
    ["maggot"] = true,
    ["moccasin"] = true,
    ["mouse"] = true,
    ["mr. bigglesworth"] = true,
    ["nibbles"] = true,
    ["noarm"] = true,
    ["old blanchy"] = true,
    ["parrot"] = true,
    ["pig"] = true,
    ["pirate treasure trigger mob"] = true,
    ["plagued insect"] = true,
    ["plagued maggot"] = true,
    ["plagued rat"] = true,
    ["plagueland termite"] = true,
    ["polymorphed chicken"] = true,
    ["polymorphed rat"] = true,
    ["prairie dog"] = true,
    ["rabbit"] = true,
    ["ram"] = true,
    ["rat"] = true,
    ["riding ram"] = true,
    ["roach"] = true,
    ["salome"] = true,
    ["school of fish"] = true,
    ["scorpion"] = true,
    ["sheep"] = true,
    ["shen'dralar wisp"] = true,
    ["sickly deer"] = true,
    ["sickly gazelle"] = true,
    ["snake"] = true,
    ["spider"] = true,
    ["spike"] = true,
    ["squirrel"] = true,
    ["swine"] = true,
    ["tainted cockroach"] = true,
    ["tainted rat"] = true,
    ["toad"] = true,
    ["transporter malfunction"] = true,
    ["turtle"] = true,
    ["underfoot"] = true,
    ["voice of elune"] = true,
    ["waypoint (only gm can see it)"] = true,
    ["wisp"] = true,
}

-- Plater-style threat colors
GudaPlates.THREAT_COLORS = {
    -- DPS/Healer colors
    DPS = {
        AGGRO = {0.41, 0.35, 0.76, 1},       -- Blue: mob attacking you (BAD)
        HIGH_THREAT = {1.0, 0.6, 0.0, 1},  -- Orange: high threat, about to pull (WARNING)
        NO_AGGRO = {0.85, 0.2, 0.2, 1},  -- Red: tank has aggro (GOOD)
    },
    -- Tank colors
    TANK = {
        AGGRO = {0.41, 0.35, 0.76, 1},       -- Blue (matching DPS AGGRO)
        LOSING_AGGRO = {1.0, 0.6, 0.0, 1}, -- Orange (matching DPS LOSING_AGGRO)
        NO_AGGRO = {0.85, 0.2, 0.2, 1},  -- Red (matching DPS NO_AGGRO)
        OTHER_TANK = {0.6, 0.8, 1.0, 1},   -- Light Blue: another tank has it
    },
    -- Misc colors
    TAPPED = {0.5, 0.5, 0.5, 1},  -- Gray: unit tapped by others
    STUN = {0.376, 0.027, 0.431, 1},    -- Pink: unit is stunned
    MANA_BAR = {0.07, 0.58, 1.0, 1},  -- Cyan: mana bar color
}

-- Other global-like variables that are used as settings
GudaPlates.playerRole = "DPS"
GudaPlates.minimapAngle = 220
GudaPlates.nameplateOverlap = true
GudaPlates.nameplateClickThrough = true  -- When true, clicks pass through nameplates
