-- GudaPlates Combo Points Module
-- Displays combo points for Rogues and Druids on nameplates
GudaPlates_ComboPoints = {}

-- Performance: Upvalue frequently used globals
local pairs = pairs
local GetComboPoints = GetComboPoints
local UnitExists = UnitExists
local UnitClass = UnitClass
local CreateFrame = CreateFrame

local Settings = GudaPlates.Settings

-- Constants
local MAX_COMBO_POINTS = 5
local COMBO_POINT_SIZE = 12

-- Combo point colors (yellow to red gradient as points increase)
local COMBO_COLORS = {
    {1.0, 0.8, 0.0, 1},  -- 1 point: Yellow
    {1.0, 0.6, 0.0, 1},  -- 2 points: Orange-Yellow
    {1.0, 0.4, 0.0, 1},  -- 3 points: Orange
    {1.0, 0.2, 0.0, 1},  -- 4 points: Red-Orange
    {1.0, 0.0, 0.0, 1},  -- 5 points: Red
}

-- Check if player class can use combo points
local _, playerClass = UnitClass("player")
playerClass = playerClass or ""
local canUseComboPoints = (playerClass == "ROGUE" or playerClass == "DRUID")

function GudaPlates_ComboPoints:CanUseComboPoints()
    return canUseComboPoints
end

function GudaPlates_ComboPoints:GetComboPointSize()
    return Settings.comboPointsSize or COMBO_POINT_SIZE
end

function GudaPlates_ComboPoints:CreateComboPointFrames(nameplate)
    if not canUseComboPoints then return end

    nameplate.comboPoints = {}
    local plateName = nameplate:GetName() or "UnknownPlate"
    local size = self:GetComboPointSize()

    for i = 1, MAX_COMBO_POINTS do
        local cp = CreateFrame("Frame", plateName .. "ComboPoint" .. i, nameplate)
        cp:SetWidth(size)
        cp:SetHeight(size)
        cp:SetFrameLevel(nameplate.health:GetFrameLevel() + 6)
        cp:EnableMouse(false)

        -- Border texture (changes based on rounded setting)
        cp.border = cp:CreateTexture(nil, "BACKGROUND")
        cp.border:SetPoint("CENTER", cp, "CENTER", 0, 0)
        cp.border:SetDrawLayer("BACKGROUND")
        cp.border:SetVertexColor(0, 0, 0, 1)

        -- Main combo point texture (changes based on rounded setting)
        cp.icon = cp:CreateTexture(nil, "ARTWORK")
        cp.icon:SetPoint("CENTER", cp, "CENTER", 0, 0)
        cp.icon:SetDrawLayer("ARTWORK")
        cp.icon:SetVertexColor(0.3, 0.3, 0.3, 1)  -- Inactive: dark gray

        cp.active = false
        cp:Hide()
        nameplate.comboPoints[i] = cp
    end
end

function GudaPlates_ComboPoints:UpdateComboPoints(nameplate, isTarget)
    if not canUseComboPoints then return 0 end
    if not nameplate.comboPoints then return 0 end
    if not Settings.showComboPoints then
        -- Hide all combo points if disabled
        for i = 1, MAX_COMBO_POINTS do
            local cp = nameplate.comboPoints[i]
            if cp then cp:Hide() end
        end
        return 0
    end

    local numPoints = 0

    -- Only show combo points on current target
    if isTarget and UnitExists("target") then
        numPoints = GetComboPoints("player", "target") or 0
    end

    local size = self:GetComboPointSize()

    -- Update each combo point frame
    for i = 1, MAX_COMBO_POINTS do
        local cp = nameplate.comboPoints[i]
        if cp then
            cp:SetWidth(size)
            cp:SetHeight(size)

            -- Update texture based on rounded setting
            if Settings.comboPointsRounded then
                -- Rounded mode: circular textures
                cp.icon:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                cp.icon:SetWidth(size)
                cp.icon:SetHeight(size)
                cp.border:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                cp.border:SetWidth(size + 2)
                cp.border:SetHeight(size + 2)
            else
                -- Square mode: square textures
                cp.icon:SetTexture("Interface\\Buttons\\WHITE8X8")
                cp.icon:SetWidth(size)
                cp.icon:SetHeight(size)
                cp.border:SetTexture("Interface\\Buttons\\WHITE8X8")
                cp.border:SetWidth(size + 2)
                cp.border:SetHeight(size + 2)
            end

            if i <= numPoints then
                -- Active combo point
                local color = COMBO_COLORS[i] or COMBO_COLORS[MAX_COMBO_POINTS]
                cp.icon:SetVertexColor(color[1], color[2], color[3], color[4])
                cp.active = true
                cp:Show()
            elseif numPoints > 0 then
                -- Inactive combo point (show as gray placeholder when we have some points)
                cp.icon:SetVertexColor(0.2, 0.2, 0.2, 0.5)
                cp.active = false
                cp:Show()
            else
                -- No combo points at all, hide everything
                cp:Hide()
            end
        end
    end

    return numPoints
end

function GudaPlates_ComboPoints:UpdateComboPointPositions(nameplate, numDebuffs)
    if not canUseComboPoints then return end
    if not nameplate.comboPoints then return end
    if not Settings.showComboPoints then return end
    if not nameplate.name then return end

    local numPoints = 0
    for i = 1, MAX_COMBO_POINTS do
        if nameplate.comboPoints[i] and nameplate.comboPoints[i]:IsShown() then
            numPoints = MAX_COMBO_POINTS  -- Show all 5 positions when any are visible
            break
        end
    end

    if numPoints == 0 then return end

    local size = self:GetComboPointSize()
    local spacing = 2
    local totalWidth = (size * MAX_COMBO_POINTS) + (spacing * (MAX_COMBO_POINTS - 1))
    local startOffset = -totalWidth / 2 + size / 2

    for i = 1, MAX_COMBO_POINTS do
        local cp = nameplate.comboPoints[i]
        if cp then
            cp:ClearAllPoints()

            local xOffset = startOffset + (i - 1) * (size + spacing)

            if Settings.swapNameDebuff then
                -- Name is below health bar -> combo points go above the name
                cp:SetPoint("BOTTOM", nameplate.name, "TOP", xOffset, 2)
            else
                -- Name is above health bar -> combo points go below the name
                cp:SetPoint("TOP", nameplate.name, "BOTTOM", xOffset, -2)
            end
        end
    end
end

-- Hide all combo points on a nameplate
function GudaPlates_ComboPoints:HideComboPoints(nameplate)
    if not nameplate.comboPoints then return end
    for i = 1, MAX_COMBO_POINTS do
        local cp = nameplate.comboPoints[i]
        if cp then cp:Hide() end
    end
end
