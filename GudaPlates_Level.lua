-- =============================================================================
-- GudaPlates_Level.lua
-- =============================================================================
-- Level Display Module
-- Handles level text display, difficulty colors, elite suffixes, and skull icons
--
-- Exports:
--   GudaPlates_Level.GetDifficultyColor(targetLevel) - Get color based on level difference
--   GudaPlates_Level.UpdatePlayerLevel() - Update cached player level
--   GudaPlates_Level.GetEliteSuffix(classification) - Get elite suffix string
--   GudaPlates_Level.ApplyLevelColor(nameplate, levelText) - Apply appropriate color
--   GudaPlates_Level.UpdateLevel(nameplate, original, frame) - Full level update
--   GudaPlates_Level.IsSkullLevel(levelText, unitLevel) - Check if skull level
-- =============================================================================

GudaPlates_Level = {}

-- =============================================================================
-- Upvalues for Performance
-- =============================================================================

local UnitLevel = UnitLevel
local UnitExists = UnitExists
local UnitClassification = UnitClassification
local tonumber = tonumber
local unpack = unpack
local math_floor = math.floor

-- =============================================================================
-- Constants
-- =============================================================================

-- Level difficulty color definitions (WoW standard)
local LEVEL_DIFF_COLORS = {
    TRIVIAL = {0.6, 0.6, 0.6, 1},    -- Grey: much lower level
    EASY = {0.1, 1.0, 0.1, 1},       -- Green: lower level
    NORMAL = {1.0, 1.0, 0.0, 1},     -- Yellow: same level
    DIFFICULT = {1.0, 0.5, 0.0, 1},  -- Orange: higher level
    IMPOSSIBLE = {1.0, 0.1, 0.1, 1}, -- Red: much higher level
}

-- Elite indicator strings (appended to level text)
local ELITE_STRINGS = {
    ["elite"] = "+",
    ["rareelite"] = "R+",
    ["rare"] = "R",
    ["worldboss"] = "B"
}

-- =============================================================================
-- Player Level Cache
-- =============================================================================

-- Cache player level (updated on level up and world enter)
local cachedPlayerLevel = UnitLevel("player") or 60

-- Update cached player level (call on PLAYER_LEVEL_UP and PLAYER_ENTERING_WORLD)
function GudaPlates_Level.UpdatePlayerLevel()
    cachedPlayerLevel = UnitLevel("player") or 60
end

-- Get cached player level
function GudaPlates_Level.GetPlayerLevel()
    return cachedPlayerLevel
end

-- =============================================================================
-- Grey Level Calculation (Vanilla WoW Formula)
-- =============================================================================

-- Calculate the grey level threshold based on player level
local function GetGreyLevel(playerLevel)
    if playerLevel <= 5 then
        return 0
    elseif playerLevel <= 39 then
        return playerLevel - math_floor(playerLevel / 10) - 5
    elseif playerLevel <= 59 then
        return playerLevel - math_floor(playerLevel / 5) - 1
    else
        return playerLevel - 9  -- Level 60: grey at 51 and below
    end
end

-- =============================================================================
-- Difficulty Color
-- =============================================================================

-- Get the difficulty color for a target level relative to player
-- Returns r, g, b, a values
function GudaPlates_Level.GetDifficultyColor(targetLevel)
    local Settings = GudaPlates and GudaPlates.Settings

    if not targetLevel or targetLevel <= 0 then
        -- Fallback to default level color
        if Settings and Settings.levelColor then
            return unpack(Settings.levelColor)
        end
        return 1, 1, 0.6, 1
    end

    local playerLevel = cachedPlayerLevel
    local diff = targetLevel - playerLevel
    local greyLevel = GetGreyLevel(playerLevel)

    if targetLevel <= greyLevel then
        -- Trivial (grey) - much lower level
        return unpack(LEVEL_DIFF_COLORS.TRIVIAL)
    elseif diff >= 5 then
        -- Impossible (red) - 5+ levels higher
        return unpack(LEVEL_DIFF_COLORS.IMPOSSIBLE)
    elseif diff >= 3 then
        -- Difficult (orange) - 3-4 levels higher
        return unpack(LEVEL_DIFF_COLORS.DIFFICULT)
    elseif diff >= -2 then
        -- Normal (yellow) - within 2 levels
        return unpack(LEVEL_DIFF_COLORS.NORMAL)
    else
        -- Easy (green) - 3+ levels lower but not grey
        return unpack(LEVEL_DIFF_COLORS.EASY)
    end
end

-- =============================================================================
-- Elite Detection
-- =============================================================================

-- Get elite suffix string for a unit classification
function GudaPlates_Level.GetEliteSuffix(classification)
    if classification and ELITE_STRINGS[classification] then
        return ELITE_STRINGS[classification]
    end
    return ""
end

-- Get elite suffix using SuperWoW API or fallback
function GudaPlates_Level.DetectEliteSuffix(frame, original, superwow_active)
    local eliteSuffix = ""

    -- Method 1: SuperWoW UnitClassification (most accurate)
    if superwow_active and UnitClassification and frame and frame.GetName then
        local unitstr = frame:GetName(1)
        if unitstr and unitstr ~= "" then
            local classification = UnitClassification(unitstr)
            if classification and ELITE_STRINGS[classification] then
                eliteSuffix = ELITE_STRINGS[classification]
            end
        end
    end

    -- Method 2: Fallback - levelicon visibility (vanilla method)
    if eliteSuffix == "" and original and original.levelicon then
        if original.levelicon.IsShown and original.levelicon:IsShown() then
            eliteSuffix = "+"
        end
    end

    return eliteSuffix
end

-- =============================================================================
-- Skull Level Detection
-- =============================================================================

-- Check if unit is skull level (boss or too high level)
function GudaPlates_Level.IsSkullLevel(levelText, frame, superwow_active)
    -- Method 1: SuperWoW UnitLevel returns -1 for skull level units
    if superwow_active and frame and frame.GetName then
        local unitstr = frame:GetName(1)
        if unitstr and unitstr ~= "" and UnitLevel and UnitExists(unitstr) then
            local unitLevel = UnitLevel(unitstr)
            if unitLevel and unitLevel == -1 then
                return true
            end
        end
    end

    -- Method 2: Check level text for skull indicators
    if levelText then
        if levelText == "-1" or levelText == "??" then
            return true
        end
    end

    return false
end

-- =============================================================================
-- Level Text Extraction
-- =============================================================================

-- Get level text from original nameplate or ShaguTweaks
function GudaPlates_Level.GetLevelText(original, frame)
    local levelText = nil

    -- Try original nameplate level
    if original and original.level and original.level.GetText then
        levelText = original.level:GetText()
    end

    -- Fallback: ShaguTweaks stores level on frame.level
    if not levelText and frame and frame.level and frame.level.GetText then
        levelText = frame.level:GetText()
    end

    return levelText
end

-- =============================================================================
-- Color Application
-- =============================================================================

-- Apply appropriate color to level text
function GudaPlates_Level.ApplyLevelColor(nameplate, levelText)
    if not nameplate or not nameplate.level then return end

    local Settings = GudaPlates and GudaPlates.Settings
    if not Settings then return end

    if Settings.useLevelDiffColors and levelText and levelText ~= "" then
        local targetLevel = tonumber(levelText)
        if targetLevel then
            nameplate.level:SetTextColor(GudaPlates_Level.GetDifficultyColor(targetLevel))
        else
            nameplate.level:SetTextColor(Settings.levelColor[1], Settings.levelColor[2], Settings.levelColor[3], Settings.levelColor[4])
        end
    else
        nameplate.level:SetTextColor(Settings.levelColor[1], Settings.levelColor[2], Settings.levelColor[3], Settings.levelColor[4])
    end
end

-- =============================================================================
-- Full Level Update
-- =============================================================================

-- Update level display (text, color, skull icon)
-- Returns: levelText for use by caller
function GudaPlates_Level.UpdateLevel(nameplate, original, frame, superwow_active)
    if not nameplate or not nameplate.level then return nil end

    -- Get level text
    local levelText = GudaPlates_Level.GetLevelText(original, frame)

    -- Detect elite status
    local eliteSuffix = GudaPlates_Level.DetectEliteSuffix(frame, original, superwow_active)

    -- Check for skull level
    local isSkullLevel = GudaPlates_Level.IsSkullLevel(levelText, frame, superwow_active)

    if isSkullLevel then
        -- Skull level unit - show skull icon, hide level text
        nameplate.level:SetText("")
        nameplate.level:Hide()
        if nameplate.skullIcon then
            nameplate.skullIcon:Show()
        end
    else
        -- Normal level - show level text with elite suffix, hide skull icon
        if nameplate.skullIcon then
            nameplate.skullIcon:Hide()
        end

        -- Set the level text
        local displayLevel = (levelText and levelText ~= "") and (levelText .. eliteSuffix) or ""
        nameplate.level:SetText(displayLevel)
        nameplate.level:Show()

        -- Apply difficulty color
        GudaPlates_Level.ApplyLevelColor(nameplate, levelText)
    end

    return levelText
end

-- =============================================================================
-- Initialization Helper
-- =============================================================================

-- Initialize level display on nameplate creation
function GudaPlates_Level.InitializeLevel(nameplate, original)
    if not nameplate or not nameplate.level then return end

    -- Get initial level text and apply color
    local levelText = nil
    if original and original.level and original.level.GetText then
        levelText = original.level:GetText()
    end

    GudaPlates_Level.ApplyLevelColor(nameplate, levelText)
end

-- =============================================================================
-- Backward Compatibility
-- =============================================================================

if GudaPlates then
    GudaPlates.Level = GudaPlates_Level
    -- Keep the old function name for compatibility
    GudaPlates.GetLevelDifficultyColor = GudaPlates_Level.GetDifficultyColor
    GudaPlates.UpdateCachedPlayerLevel = GudaPlates_Level.UpdatePlayerLevel
end
