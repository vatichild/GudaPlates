--------------------------------------------------------------------------------
-- GudaPlates_Options.lua
-- Options UI module for GudaPlates nameplate addon
-- This file contains the CreateOptionsFrame function and all options panel UI
--------------------------------------------------------------------------------

-- Local upvalue aliases for exposed globals from main file
-- Note: Settings/THREAT_COLORS are tables that exist from Settings file load
local Settings = GudaPlates.Settings
local THREAT_COLORS = GudaPlates.THREAT_COLORS

-- These are set during main file execution, access via GudaPlates table to ensure they exist
-- Using wrapper functions to defer the lookup until call time
local function SaveSettings()
    if GudaPlates.SaveSettings then
        GudaPlates.SaveSettings()
    end
end

local function UpdateNamePlate(plate)
    if GudaPlates.UpdateNamePlate then
        GudaPlates.UpdateNamePlate(plate)
    end
end

local function UpdateNamePlateDimensions(plate)
    if GudaPlates.UpdateNamePlateDimensions then
        GudaPlates.UpdateNamePlateDimensions(plate)
    end
end

local function Print(msg)
    if GudaPlates.Print then
        GudaPlates.Print(msg)
    end
end

-- Registry is a table reference, should be safe
local registry = GudaPlates.registry or {}
local fontOptions = GudaPlates.fontOptions or {}

-- Lua built-ins
local math_floor = math.floor
local pairs = pairs
local ipairs = ipairs
local getglobal = getglobal
local table = table

-- Options Frame
local optionsFrame, generalTab, healthbarTab, manaTab, castbarTab, colorsTab
local generalTabBg, healthbarTabBg, manaTabBg, castbarTabBg, colorsTabBg

local function CreateOptionsFrame()
    local UpdateManaOptionsState, UpdateCastbarWidthSliderState
    optionsFrame = CreateFrame("Frame", "GudaPlatesOptionsFrame", UIParent)
    optionsFrame:SetFrameStrata("MEDIUM")
    optionsFrame:SetFrameLevel(20)
    optionsFrame:SetWidth(650)
    optionsFrame:SetHeight(580)
    optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    local function UpdateOptionsBackdrop()
        local edge = "Interface\\DialogFrame\\UI-DialogBox-Border"
        if Settings.hideOptionsBorder then
            edge = nil
        end
        optionsFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = edge,
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        local alpha = Settings.optionsBgAlpha
        if alpha == nil then alpha = 0.9 end
        optionsFrame:SetBackdropColor(0, 0, 0, alpha)
    end

    UpdateOptionsBackdrop()
    optionsFrame.UpdateBackdrop = UpdateOptionsBackdrop

    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    optionsFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    optionsFrame:Hide()

    -- Title
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", optionsFrame, "TOP", 0, -20)
    title:SetText("GudaPlates Settings")

    -- Close Button
    local closeButton = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -5, -5)

    -- Tab Content Frames
    generalTab = CreateFrame("Frame", "GudaPlatesGeneralTab", optionsFrame)
    generalTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -85)
    generalTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)

    healthbarTab = CreateFrame("Frame", "GudaPlatesHealthbarTab", optionsFrame)
    healthbarTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -85)
    healthbarTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)
    healthbarTab:Hide()

    manaTab = CreateFrame("Frame", "GudaPlatesManaTab", optionsFrame)
    manaTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -85)
    manaTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)
    manaTab:Hide()

    castbarTab = CreateFrame("Frame", "GudaPlatesCastbarTab", optionsFrame)
    castbarTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -85)
    castbarTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)
    castbarTab:Hide()

    colorsTab = CreateFrame("Frame", "GudaPlatesColorsTab", optionsFrame)
    colorsTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -85)
    colorsTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)
    colorsTab:Hide()

    -- Tab Buttons
    local generalTabButton = CreateFrame("Button", "GudaPlatesGeneralTabButton", optionsFrame)
    generalTabButton:SetWidth(120)
    generalTabButton:SetHeight(28)
    generalTabButton:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -42)

    local generalTabText = generalTabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    generalTabText:SetPoint("CENTER", generalTabButton, "CENTER", 0, 0)
    generalTabText:SetText("General")

    generalTabBg = generalTabButton:CreateTexture(nil, "BACKGROUND")
    generalTabBg:SetTexture(1, 1, 1, 0.3)
    generalTabBg:SetAllPoints()

    local healthbarTabButton = CreateFrame("Button", "GudaPlatesHealthbarTabButton", optionsFrame)
    healthbarTabButton:SetWidth(120)
    healthbarTabButton:SetHeight(28)
    healthbarTabButton:SetPoint("LEFT", generalTabButton, "RIGHT", 5, 0)

    local healthbarTabText = healthbarTabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    healthbarTabText:SetPoint("CENTER", healthbarTabButton, "CENTER", 0, 0)
    healthbarTabText:SetText("Health")

    healthbarTabBg = healthbarTabButton:CreateTexture(nil, "BACKGROUND")
    healthbarTabBg:SetTexture(1, 1, 1, 0.1)
    healthbarTabBg:SetAllPoints()

    local manaTabButton = CreateFrame("Button", "GudaPlatesManaTabButton", optionsFrame)
    manaTabButton:SetWidth(120)
    manaTabButton:SetHeight(28)
    manaTabButton:SetPoint("LEFT", healthbarTabButton, "RIGHT", 5, 0)

    local manaTabText = manaTabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    manaTabText:SetPoint("CENTER", manaTabButton, "CENTER", 0, 0)
    manaTabText:SetText("Mana")

    manaTabBg = manaTabButton:CreateTexture(nil, "BACKGROUND")
    manaTabBg:SetTexture(1, 1, 1, 0.1)
    manaTabBg:SetAllPoints()

    local castbarTabButton = CreateFrame("Button", "GudaPlatesCastbarTabButton", optionsFrame)
    castbarTabButton:SetWidth(120)
    castbarTabButton:SetHeight(28)
    castbarTabButton:SetPoint("LEFT", manaTabButton, "RIGHT", 5, 0)

    local castbarTabText = castbarTabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    castbarTabText:SetPoint("CENTER", castbarTabButton, "CENTER", 0, 0)
    castbarTabText:SetText("Castbar")

    castbarTabBg = castbarTabButton:CreateTexture(nil, "BACKGROUND")
    castbarTabBg:SetTexture(1, 1, 1, 0.1)
    castbarTabBg:SetAllPoints()

    local colorsTabButton = CreateFrame("Button", "GudaPlatesColorsTabButton", optionsFrame)
    colorsTabButton:SetWidth(120)
    colorsTabButton:SetHeight(28)
    colorsTabButton:SetPoint("LEFT", castbarTabButton, "RIGHT", 5, 0)

    local colorsTabText = colorsTabButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorsTabText:SetPoint("CENTER", colorsTabButton, "CENTER", 0, 0)
    colorsTabText:SetText("Colors")

    colorsTabBg = colorsTabButton:CreateTexture(nil, "BACKGROUND")
    colorsTabBg:SetTexture(1, 1, 1, 0.1)
    colorsTabBg:SetAllPoints()

    local function SelectTab(tabName)
        generalTab:Hide()
        healthbarTab:Hide()
        manaTab:Hide()
        castbarTab:Hide()
        colorsTab:Hide()
        generalTabBg:SetTexture(1, 1, 1, 0.1)
        healthbarTabBg:SetTexture(1, 1, 1, 0.1)
        manaTabBg:SetTexture(1, 1, 1, 0.1)
        castbarTabBg:SetTexture(1, 1, 1, 0.1)
        colorsTabBg:SetTexture(1, 1, 1, 0.1)

        if tabName == "general" then
            generalTab:Show()
            generalTabBg:SetTexture(1, 1, 1, 0.3)
        elseif tabName == "healthbar" then
            healthbarTab:Show()
            healthbarTabBg:SetTexture(1, 1, 1, 0.3)
        elseif tabName == "mana" then
            manaTab:Show()
            manaTabBg:SetTexture(1, 1, 1, 0.3)
        elseif tabName == "castbar" then
            castbarTab:Show()
            castbarTabBg:SetTexture(1, 1, 1, 0.3)
        elseif tabName == "colors" then
            colorsTab:Show()
            colorsTabBg:SetTexture(1, 1, 1, 0.3)
        end
    end

    generalTabButton:SetScript("OnClick", function() SelectTab("general") end)
    healthbarTabButton:SetScript("OnClick", function() SelectTab("healthbar") end)
    manaTabButton:SetScript("OnClick", function() SelectTab("mana") end)
    castbarTabButton:SetScript("OnClick", function() SelectTab("castbar") end)
    colorsTabButton:SetScript("OnClick", function() SelectTab("colors") end)

    -- Color picker helper
    local function ShowColorPicker(r, g, b, callback)
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            callback(r, g, b)
        end
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = {r, g, b}
        ColorPickerFrame.cancelFunc = function()
            local prev = ColorPickerFrame.previousValues
            callback(prev[1], prev[2], prev[3])
        end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end

    -- Create color swatch helper
    local swatches = {}
    local function CreateColorSwatch(parent, x, y, label, colorTable, colorKey)
        local swatchLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        swatchLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        swatchLabel:SetText(label)

        local swatch = CreateFrame("Button", nil, parent)
        swatch:SetWidth(20)
        swatch:SetHeight(20)
        swatch:SetPoint("LEFT", swatchLabel, "RIGHT", 10, 0)

        local border = swatch:CreateTexture(nil, "BACKGROUND")
        border:SetTexture(0, 0, 0, 1)
        border:SetAllPoints()

        local swatchBg = swatch:CreateTexture(nil, "ARTWORK")
        swatchBg:SetTexture(1, 1, 1, 1)
        swatchBg:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
        swatchBg:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)

        local function UpdateSwatchColor()
            local c = colorTable[colorKey]
            swatchBg:SetVertexColor(c[1], c[2], c[3], 1)
        end
        UpdateSwatchColor()

        table.insert(swatches, UpdateSwatchColor)

        swatch:SetScript("OnClick", function()
            local c = colorTable[colorKey]
            ShowColorPicker(c[1], c[2], c[3], function(r, g, b)
                if r then
                    colorTable[colorKey] = {r, g, b, 1}
                    UpdateSwatchColor()
                    SaveSettings()
                    for plate, _ in pairs(registry) do
                        if plate:IsShown() then
                            UpdateNamePlate(plate)
                        end
                    end
                end
            end)
        end)

        swatch:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Click to change color")
            GameTooltip:Show()
        end)

        swatch:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        return swatch
    end

    local function SetupGeneralTab()

-- Settings Frame Section
local settingsHeader = generalTab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
settingsHeader:SetPoint("TOPLEFT", generalTab, "TOPLEFT", 5, 0)
settingsHeader:SetText("Settings Frame")

-- Background Transparency Slider
local transparencySlider = CreateFrame("Slider", "GudaPlatesOptionsTransparencySlider", generalTab, "OptionsSliderTemplate")
transparencySlider:SetPoint("TOPLEFT", settingsHeader, "BOTTOMLEFT", 0, -20)
transparencySlider:SetWidth(580)
transparencySlider:SetMinMaxValues(0, 1)
transparencySlider:SetValueStep(0.05)
local transparencyText = getglobal(transparencySlider:GetName() .. "Text")
transparencyText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(transparencySlider:GetName() .. "Low"):SetText("0%")
getglobal(transparencySlider:GetName() .. "High"):SetText("100%")
transparencySlider:SetScript("OnValueChanged", function()
    -- Value is transparency (0 = opaque, 1 = transparent)
    -- optionsBgAlpha should be opacity (1 = opaque, 0 = transparent)
    Settings.optionsBgAlpha = 1 - this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Background Transparency: " .. math_floor(this:GetValue() * 100) .. "%")
    SaveSettings()
    if optionsFrame and optionsFrame.UpdateBackdrop then
        optionsFrame.UpdateBackdrop()
    end
end)

-- Hide Border Checkbox
local hideBorderCheckbox = CreateFrame("CheckButton", "GudaPlatesHideBorderCheckbox", generalTab, "UICheckButtonTemplate")
hideBorderCheckbox:SetPoint("TOPLEFT", transparencySlider, "BOTTOMLEFT", 0, -10)
local hideBorderLabel = getglobal(hideBorderCheckbox:GetName().."Text")
hideBorderLabel:SetText("Hide Borders")
hideBorderLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
hideBorderCheckbox:SetScript("OnClick", function()
    Settings.hideOptionsBorder = this:GetChecked() == 1
    SaveSettings()
    if optionsFrame and optionsFrame.UpdateBackdrop then
        optionsFrame.UpdateBackdrop()
    end
end)

-- Separator 1
local separator1 = generalTab:CreateTexture(nil, "ARTWORK")
separator1:SetTexture(1, 1, 1, 0.2)
separator1:SetHeight(1)
separator1:SetWidth(580)
separator1:SetPoint("TOPLEFT", hideBorderCheckbox, "BOTTOMLEFT", 0, -15)

-- Nameplate Settings (formerly General Settings)
local nameplateHeader = generalTab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
nameplateHeader:SetPoint("TOPLEFT", separator1, "BOTTOMLEFT", 0, -15)
nameplateHeader:SetText("Nameplate Settings")

-- Row 1
local overlapCheckbox = CreateFrame("CheckButton", "GudaPlatesOverlapCheckbox", generalTab, "UICheckButtonTemplate")
overlapCheckbox:SetPoint("TOPLEFT", nameplateHeader, "BOTTOMLEFT", 0, -10)
local overlapLabel = getglobal(overlapCheckbox:GetName().."Text")
overlapLabel:SetText("Overlapping")
overlapLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
overlapCheckbox:SetScript("OnClick", function()
    GudaPlates.nameplateOverlap = this:GetChecked() == 1
    SaveSettings()
end)

local clickThroughCheckbox = CreateFrame("CheckButton", "GudaPlatesClickThroughCheckbox", generalTab, "UICheckButtonTemplate")
clickThroughCheckbox:SetPoint("TOPLEFT", overlapCheckbox, "TOPLEFT", 150, 0)
local clickThroughLabel = getglobal(clickThroughCheckbox:GetName().."Text")
clickThroughLabel:SetText("Click-Through")
clickThroughLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
clickThroughCheckbox:SetScript("OnClick", function()
    GudaPlates.nameplateClickThrough = this:GetChecked() == 1
    SaveSettings()
end)
clickThroughCheckbox:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Enable this to let clicks pass through nameplates (default: checked)")
    GameTooltip:Show()
end)
clickThroughCheckbox:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local raidMarkCheckbox = CreateFrame("CheckButton", "GudaPlatesRaidMarkCheckbox", generalTab, "UICheckButtonTemplate")
raidMarkCheckbox:SetPoint("TOPLEFT", overlapCheckbox, "TOPLEFT", 300, 0)
local raidMarkLabel = getglobal(raidMarkCheckbox:GetName().."Text")
raidMarkLabel:SetText("Raid Mark Right")
raidMarkLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
raidMarkCheckbox:SetScript("OnClick", function()
    if this:GetChecked() == 1 then
        Settings.raidIconPosition = "RIGHT"
    else
        Settings.raidIconPosition = "LEFT"
    end
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

local swapCheckbox = CreateFrame("CheckButton", "GudaPlatesSwapCheckbox", generalTab, "UICheckButtonTemplate")
swapCheckbox:SetPoint("TOPLEFT", overlapCheckbox, "TOPLEFT", 450, 0)
local swapLabel = getglobal(swapCheckbox:GetName().."Text")
swapLabel:SetText("Swap Name/Debuffs")
swapLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
swapCheckbox:SetScript("OnClick", function()
    Settings.swapNameDebuff = this:GetChecked() == 1
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

local onlyMyDebuffsCheckbox = CreateFrame("CheckButton", "GudaPlatesOnlyMyDebuffsCheckbox", generalTab, "UICheckButtonTemplate")
onlyMyDebuffsCheckbox:SetPoint("TOPLEFT", overlapCheckbox, "BOTTOMLEFT", 0, -10)
local onlyMyDebuffsLabel = getglobal(onlyMyDebuffsCheckbox:GetName().."Text")
onlyMyDebuffsLabel:SetText("Only My Debuffs")
onlyMyDebuffsLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
onlyMyDebuffsCheckbox:SetScript("OnClick", function()
    Settings.showOnlyMyDebuffs = this:GetChecked() == 1
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end)

local targetGlowCheckbox = CreateFrame("CheckButton", "GudaPlatesTargetGlowCheckbox", generalTab, "UICheckButtonTemplate")
targetGlowCheckbox:SetPoint("TOPLEFT", onlyMyDebuffsCheckbox, "TOPLEFT", 150, 0)
local targetGlowLabel = getglobal(targetGlowCheckbox:GetName().."Text")
targetGlowLabel:SetText("Target Glow")
targetGlowLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
targetGlowCheckbox:SetScript("OnClick", function()
    Settings.showTargetGlow = this:GetChecked() == 1
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end)

local debuffTimerCheckbox = CreateFrame("CheckButton", "GudaPlatesDebuffTimerCheckbox", generalTab, "UICheckButtonTemplate")
debuffTimerCheckbox:SetPoint("TOPLEFT", onlyMyDebuffsCheckbox, "TOPLEFT", 300, 0)
local debuffTimerLabel = getglobal(debuffTimerCheckbox:GetName().."Text")
debuffTimerLabel:SetText("Debuff Timers")
debuffTimerLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
debuffTimerCheckbox:SetScript("OnClick", function()
    Settings.showDebuffTimers = this:GetChecked() == 1
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end)

local showCrittersCheckbox = CreateFrame("CheckButton", "GudaPlatesShowCrittersCheckbox", generalTab, "UICheckButtonTemplate")
showCrittersCheckbox:SetPoint("TOPLEFT", onlyMyDebuffsCheckbox, "TOPLEFT", 450, 0)
local showCrittersLabel = getglobal(showCrittersCheckbox:GetName().."Text")
showCrittersLabel:SetText("Show Critters")
showCrittersLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
showCrittersCheckbox:SetScript("OnClick", function()
    Settings.showCritterNameplates = this:GetChecked() == 1
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end)
showCrittersCheckbox:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Show nameplates for critters and ambient mobs (default: unchecked)")
    GameTooltip:Show()
end)
showCrittersCheckbox:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

local debuffSizeSlider = CreateFrame("Slider", "GudaPlatesDebuffSizeSlider", generalTab, "OptionsSliderTemplate")
debuffSizeSlider:SetPoint("TOPLEFT", onlyMyDebuffsCheckbox, "BOTTOMLEFT", 0, -35)
debuffSizeSlider:SetWidth(580)
debuffSizeSlider:SetMinMaxValues(8, 32)
debuffSizeSlider:SetValueStep(1)
local debuffSizeText = getglobal(debuffSizeSlider:GetName() .. "Text")
debuffSizeText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(debuffSizeSlider:GetName() .. "Low"):SetText("8")
getglobal(debuffSizeSlider:GetName() .. "High"):SetText("32")
debuffSizeSlider:SetScript("OnValueChanged", function()
    Settings.debuffIconSize = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Debuff Icon Size: " .. math_floor(this:GetValue()) .. " px")
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end)

-- Separator 2
local separator2 = generalTab:CreateTexture(nil, "ARTWORK")
separator2:SetTexture(1, 1, 1, 0.2)
separator2:SetHeight(1)
separator2:SetWidth(580)
separator2:SetPoint("TOPLEFT", debuffSizeSlider, "BOTTOMLEFT", 0, -20)

-- Font Section
local fontHeader = generalTab:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
fontHeader:SetPoint("TOPLEFT", separator2, "BOTTOMLEFT", 0, -15)
fontHeader:SetText("Font Settings")

local fontLabel = generalTab:CreateFontString("GudaPlatesFontLabel", "OVERLAY", "GameFontNormal")
fontLabel:SetPoint("TOPLEFT", fontHeader, "BOTTOMLEFT", 0, -15)
fontLabel:SetText("Nameplates Font:")

local fontDropdown = CreateFrame("Frame", "GudaPlatesFontDropdown", generalTab, "UIDropDownMenuTemplate")
fontDropdown:SetPoint("TOPLEFT", fontLabel, "TOPRIGHT", -10, 8)

local function FontDropdown_OnClick()
    Settings.textFont = this.value
    UIDropDownMenu_SetSelectedValue(GudaPlatesFontDropdown, this.value)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end

local function FontDropdown_Initialize()
    for _, opt in ipairs(fontOptions) do
        local info = {}
        info.text = opt.text
        info.value = opt.value
        info.func = FontDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(fontDropdown, FontDropdown_Initialize)
UIDropDownMenu_SetWidth(180, fontDropdown)
UIDropDownMenu_SetSelectedValue(fontDropdown, Settings.textFont)
    end

    local function SetupHealthbarTab()

local scrollFrame = CreateFrame("ScrollFrame", "GudaPlatesHealthScrollFrame", healthbarTab, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", healthbarTab, "TOPLEFT", 0, -5)
scrollFrame:SetPoint("BOTTOMRIGHT", healthbarTab, "BOTTOMRIGHT", -25, 5)

local scrollContent = CreateFrame("Frame", "GudaPlatesHealthScrollContent", scrollFrame)
scrollContent:SetWidth(580)
scrollContent:SetHeight(780)
scrollFrame:SetScrollChild(scrollContent)

-- Enemy Section Header
local enemyHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
enemyHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 5, -5)
enemyHeader:SetText("Enemy Nameplates")

-- PvP Enemy No Class Colors Checkbox (inline with header)
local pvpNoClassColorsCheckbox = CreateFrame("CheckButton", "GudaPlatesPvPNoClassColorsCheckbox", scrollContent, "UICheckButtonTemplate")
pvpNoClassColorsCheckbox:SetPoint("LEFT", enemyHeader, "RIGHT", 20, 0)
pvpNoClassColorsCheckbox:SetWidth(24)
pvpNoClassColorsCheckbox:SetHeight(24)
local pvpNoClassColorsLabel = getglobal(pvpNoClassColorsCheckbox:GetName().."Text")
pvpNoClassColorsLabel:SetText("No class colors for PvP enemies")
pvpNoClassColorsLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
pvpNoClassColorsCheckbox:SetScript("OnClick", function()
    Settings.pvpEnemyNoClassColors = (this:GetChecked() == 1)
    SaveSettings()
end)
pvpNoClassColorsCheckbox:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Disable Class Colors for PvP Enemies")
    GameTooltip:AddLine("When enabled, PvP-flagged enemy players will have", 1, 1, 1)
    GameTooltip:AddLine("red healthbar instead of class colors.", 1, 1, 1)
    GameTooltip:AddLine("Requires SuperWoW for player detection.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
pvpNoClassColorsCheckbox:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Healthbar Height Slider
local heightSlider = CreateFrame("Slider", "GudaPlatesHeightSlider", scrollContent, "OptionsSliderTemplate")
heightSlider:SetPoint("TOPLEFT", enemyHeader, "BOTTOMLEFT", 0, -20)
heightSlider:SetWidth(560)
heightSlider:SetMinMaxValues(4, 25)
heightSlider:SetValueStep(1)
local heightText = getglobal(heightSlider:GetName() .. "Text")
heightText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(heightSlider:GetName() .. "Low"):SetText("4")
getglobal(heightSlider:GetName() .. "High"):SetText("25")
heightSlider:SetScript("OnValueChanged", function()
    Settings.healthbarHeight = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Healthbar Height: " .. Settings.healthbarHeight)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Healthbar Width Slider
local widthSlider = CreateFrame("Slider", "GudaPlatesWidthSlider", scrollContent, "OptionsSliderTemplate")
widthSlider:SetPoint("TOPLEFT", heightSlider, "BOTTOMLEFT", 0, -30)
widthSlider:SetWidth(560)
widthSlider:SetMinMaxValues(72, 150)
widthSlider:SetValueStep(1)
local widthText = getglobal(widthSlider:GetName() .. "Text")
widthText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(widthSlider:GetName() .. "Low"):SetText("72")
getglobal(widthSlider:GetName() .. "High"):SetText("150")
widthSlider:SetScript("OnValueChanged", function()
    Settings.healthbarWidth = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Healthbar Width: " .. Settings.healthbarWidth)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Health Font Size Slider
local healthFontSlider = CreateFrame("Slider", "GudaPlatesHealthFontSlider", scrollContent, "OptionsSliderTemplate")
healthFontSlider:SetPoint("TOPLEFT", widthSlider, "BOTTOMLEFT", 0, -30)
healthFontSlider:SetWidth(560)
healthFontSlider:SetMinMaxValues(6, 20)
healthFontSlider:SetValueStep(1)
local healthFontText = getglobal(healthFontSlider:GetName() .. "Text")
healthFontText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(healthFontSlider:GetName() .. "Low"):SetText("6")
getglobal(healthFontSlider:GetName() .. "High"):SetText("20")
healthFontSlider:SetScript("OnValueChanged", function()
    Settings.healthFontSize = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Health Font Size: " .. Settings.healthFontSize)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Level Font Size Slider (Enemy)
local levelFontSlider = CreateFrame("Slider", "GudaPlatesLevelFontSlider", scrollContent, "OptionsSliderTemplate")
levelFontSlider:SetPoint("TOPLEFT", healthFontSlider, "BOTTOMLEFT", 0, -30)
levelFontSlider:SetWidth(560)
levelFontSlider:SetMinMaxValues(6, 20)
levelFontSlider:SetValueStep(1)
local levelFontText = getglobal(levelFontSlider:GetName() .. "Text")
levelFontText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(levelFontSlider:GetName() .. "Low"):SetText("6")
getglobal(levelFontSlider:GetName() .. "High"):SetText("20")
levelFontSlider:SetScript("OnValueChanged", function()
    Settings.levelFontSize = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Level Font Size: " .. Settings.levelFontSize)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Name Font Size Slider (Enemy)
local nameFontSlider = CreateFrame("Slider", "GudaPlatesNameFontSlider", scrollContent, "OptionsSliderTemplate")
nameFontSlider:SetPoint("TOPLEFT", levelFontSlider, "BOTTOMLEFT", 0, -30)
nameFontSlider:SetWidth(560)
nameFontSlider:SetMinMaxValues(6, 20)
nameFontSlider:SetValueStep(1)
local nameFontText = getglobal(nameFontSlider:GetName() .. "Text")
nameFontText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(nameFontSlider:GetName() .. "Low"):SetText("6")
getglobal(nameFontSlider:GetName() .. "High"):SetText("20")
nameFontSlider:SetScript("OnValueChanged", function()
    Settings.nameFontSize = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Name Font Size: " .. Settings.nameFontSize)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Health Text Position Dropdown
local healthPosLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
healthPosLabel:SetPoint("TOPLEFT", nameFontSlider, "BOTTOMLEFT", 0, -15)
healthPosLabel:SetText("Health Text Position:")

local healthPosDropdown = CreateFrame("Frame", "GudaPlatesHealthPosDropdown", scrollContent, "UIDropDownMenuTemplate")
healthPosDropdown:SetPoint("TOPLEFT", healthPosLabel, "TOPRIGHT", -10, 8)

local healthPosOptions = {"LEFT", "CENTER", "RIGHT"}
local healthPosLabels = {LEFT = "Left", CENTER = "Center", RIGHT = "Right"}

local function HealthPosDropdown_OnClick()
    Settings.healthTextPosition = this.value
    UIDropDownMenu_SetSelectedValue(GudaPlatesHealthPosDropdown, this.value)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end

local function HealthPosDropdown_Initialize()
    for _, pos in ipairs(healthPosOptions) do
        local info = {}
        info.text = healthPosLabels[pos]
        info.value = pos
        info.func = HealthPosDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(healthPosDropdown, HealthPosDropdown_Initialize)
UIDropDownMenu_SetWidth(100, healthPosDropdown)
UIDropDownMenu_SetSelectedValue(healthPosDropdown, Settings.healthTextPosition)

-- Health Text Format Dropdown
local healthFormatLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
healthFormatLabel:SetPoint("LEFT", healthPosDropdown, "RIGHT", 10, 0)
healthFormatLabel:SetText("Health Text Format:")

local healthFormatDropdown = CreateFrame("Frame", "GudaPlatesHealthFormatDropdown", scrollContent, "UIDropDownMenuTemplate")
healthFormatDropdown:SetPoint("LEFT", healthFormatLabel, "RIGHT", -10, -3)

local healthFormatOptions = {
    {value = 0, text = "None"},
    {value = 1, text = "Percent"},
    {value = 2, text = "Current HP"},
    {value = 3, text = "HP (Percent%)"},
    {value = 4, text = "Current - Max"},
    {value = 5, text = "Current - Max (%)"},
    {value = 6, text = "Name - %"},
    {value = 7, text = "Name - HP(%)"},
    {value = 8, text = "Name"},
}

local function HealthFormatDropdown_OnClick()
    Settings.healthTextFormat = this.value
    UIDropDownMenu_SetSelectedValue(GudaPlatesHealthFormatDropdown, this.value)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end

local function HealthFormatDropdown_Initialize()
    for _, opt in ipairs(healthFormatOptions) do
        local info = {}
        info.text = opt.text
        info.value = opt.value
        info.func = HealthFormatDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(healthFormatDropdown, HealthFormatDropdown_Initialize)
UIDropDownMenu_SetWidth(150, healthFormatDropdown)
UIDropDownMenu_SetSelectedValue(healthFormatDropdown, Settings.healthTextFormat)

-- Separator Line
local separator = scrollContent:CreateTexture(nil, "ARTWORK")
separator:SetTexture(1, 1, 1, 0.2)
separator:SetHeight(1)
separator:SetWidth(560)
separator:SetPoint("TOPLEFT", healthPosLabel, "BOTTOMLEFT", 0, -35)

-- Friendly Section Header
local friendlyHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
friendlyHeader:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -15)
friendlyHeader:SetText("Friendly Nameplates")

-- PvP Enemy As Friendly Checkbox (inline with header)
local pvpAsFriendlyCheckbox = CreateFrame("CheckButton", "GudaPlatesPvPAsFriendlyCheckbox", scrollContent, "UICheckButtonTemplate")
pvpAsFriendlyCheckbox:SetPoint("LEFT", friendlyHeader, "RIGHT", 20, 0)
pvpAsFriendlyCheckbox:SetWidth(24)
pvpAsFriendlyCheckbox:SetHeight(24)
local pvpAsFriendlyLabel = getglobal(pvpAsFriendlyCheckbox:GetName().."Text")
pvpAsFriendlyLabel:SetText("Use for PvP enemies")
pvpAsFriendlyLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
pvpAsFriendlyCheckbox:SetScript("OnClick", function()
    Settings.pvpEnemyAsFriendly = (this:GetChecked() == 1)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)
pvpAsFriendlyCheckbox:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("PvP Enemies Use Friendly Style")
    GameTooltip:AddLine("When enabled, PvP-flagged enemy players will use", 1, 1, 1)
    GameTooltip:AddLine("the friendly nameplate style.", 1, 1, 1)
    GameTooltip:AddLine("Requires SuperWoW for player detection.", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
pvpAsFriendlyCheckbox:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Friend Healthbar Height Slider
local friendHeightSlider = CreateFrame("Slider", "GudaPlatesFriendHeightSlider", scrollContent, "OptionsSliderTemplate")
friendHeightSlider:SetPoint("TOPLEFT", friendlyHeader, "BOTTOMLEFT", 0, -20)
friendHeightSlider:SetWidth(560)
friendHeightSlider:SetMinMaxValues(4, 25)
friendHeightSlider:SetValueStep(1)
local friendHeightText = getglobal(friendHeightSlider:GetName() .. "Text")
friendHeightText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(friendHeightSlider:GetName() .. "Low"):SetText("4")
getglobal(friendHeightSlider:GetName() .. "High"):SetText("25")
friendHeightSlider:SetScript("OnValueChanged", function()
    Settings.friendHealthbarHeight = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Healthbar Height: " .. Settings.friendHealthbarHeight)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Friend Healthbar Width Slider
local friendWidthSlider = CreateFrame("Slider", "GudaPlatesFriendWidthSlider", scrollContent, "OptionsSliderTemplate")
friendWidthSlider:SetPoint("TOPLEFT", friendHeightSlider, "BOTTOMLEFT", 0, -30)
friendWidthSlider:SetWidth(560)
friendWidthSlider:SetMinMaxValues(72, 150)
friendWidthSlider:SetValueStep(1)
local friendWidthText = getglobal(friendWidthSlider:GetName() .. "Text")
friendWidthText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(friendWidthSlider:GetName() .. "Low"):SetText("72")
getglobal(friendWidthSlider:GetName() .. "High"):SetText("150")
friendWidthSlider:SetScript("OnValueChanged", function()
    Settings.friendHealthbarWidth = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Healthbar Width: " .. Settings.friendHealthbarWidth)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Friend Health Font Size Slider
local friendHealthFontSlider = CreateFrame("Slider", "GudaPlatesFriendHealthFontSlider", scrollContent, "OptionsSliderTemplate")
friendHealthFontSlider:SetPoint("TOPLEFT", friendWidthSlider, "BOTTOMLEFT", 0, -30)
friendHealthFontSlider:SetWidth(560)
friendHealthFontSlider:SetMinMaxValues(6, 20)
friendHealthFontSlider:SetValueStep(1)
local friendHealthFontText = getglobal(friendHealthFontSlider:GetName() .. "Text")
friendHealthFontText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(friendHealthFontSlider:GetName() .. "Low"):SetText("6")
getglobal(friendHealthFontSlider:GetName() .. "High"):SetText("20")
friendHealthFontSlider:SetScript("OnValueChanged", function()
    Settings.friendHealthFontSize = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Health Font Size: " .. Settings.friendHealthFontSize)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Friend Level Font Size Slider
local friendLevelFontSlider = CreateFrame("Slider", "GudaPlatesFriendLevelFontSlider", scrollContent, "OptionsSliderTemplate")
friendLevelFontSlider:SetPoint("TOPLEFT", friendHealthFontSlider, "BOTTOMLEFT", 0, -30)
friendLevelFontSlider:SetWidth(560)
friendLevelFontSlider:SetMinMaxValues(6, 20)
friendLevelFontSlider:SetValueStep(1)
local friendLevelFontText = getglobal(friendLevelFontSlider:GetName() .. "Text")
friendLevelFontText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(friendLevelFontSlider:GetName() .. "Low"):SetText("6")
getglobal(friendLevelFontSlider:GetName() .. "High"):SetText("20")
friendLevelFontSlider:SetScript("OnValueChanged", function()
    Settings.friendLevelFontSize = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Level Font Size: " .. Settings.friendLevelFontSize)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Friend Name Font Size Slider
local friendNameFontSlider = CreateFrame("Slider", "GudaPlatesFriendNameFontSlider", scrollContent, "OptionsSliderTemplate")
friendNameFontSlider:SetPoint("TOPLEFT", friendLevelFontSlider, "BOTTOMLEFT", 0, -30)
friendNameFontSlider:SetWidth(560)
friendNameFontSlider:SetMinMaxValues(6, 20)
friendNameFontSlider:SetValueStep(1)
local friendNameFontText = getglobal(friendNameFontSlider:GetName() .. "Text")
friendNameFontText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(friendNameFontSlider:GetName() .. "Low"):SetText("6")
getglobal(friendNameFontSlider:GetName() .. "High"):SetText("20")
friendNameFontSlider:SetScript("OnValueChanged", function()
    Settings.friendNameFontSize = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Name Font Size: " .. Settings.friendNameFontSize)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Friend Health Text Position Dropdown
local friendHealthPosLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
friendHealthPosLabel:SetPoint("TOPLEFT", friendNameFontSlider, "BOTTOMLEFT", 0, -15)
friendHealthPosLabel:SetText("Health Text Position:")

local friendHealthPosDropdown = CreateFrame("Frame", "GudaPlatesFriendHealthPosDropdown", scrollContent, "UIDropDownMenuTemplate")
friendHealthPosDropdown:SetPoint("TOPLEFT", friendHealthPosLabel, "TOPRIGHT", -10, 8)

local function FriendHealthPosDropdown_OnClick()
    Settings.friendHealthTextPosition = this.value
    UIDropDownMenu_SetSelectedValue(GudaPlatesFriendHealthPosDropdown, this.value)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end

local function FriendHealthPosDropdown_Initialize()
    for _, pos in ipairs(healthPosOptions) do
        local info = {}
        info.text = healthPosLabels[pos]
        info.value = pos
        info.func = FriendHealthPosDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(friendHealthPosDropdown, FriendHealthPosDropdown_Initialize)
UIDropDownMenu_SetWidth(100, friendHealthPosDropdown)
UIDropDownMenu_SetSelectedValue(friendHealthPosDropdown, Settings.friendHealthTextPosition)

-- Friend Health Text Format Dropdown
local friendHealthFormatLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
friendHealthFormatLabel:SetPoint("LEFT", friendHealthPosDropdown, "RIGHT", 10, 0)
friendHealthFormatLabel:SetText("Health Text Format:")

local friendHealthFormatDropdown = CreateFrame("Frame", "GudaPlatesFriendHealthFormatDropdown", scrollContent, "UIDropDownMenuTemplate")
friendHealthFormatDropdown:SetPoint("LEFT", friendHealthFormatLabel, "RIGHT", -10, -3)

local function FriendHealthFormatDropdown_OnClick()
    Settings.friendHealthTextFormat = this.value
    UIDropDownMenu_SetSelectedValue(GudaPlatesFriendHealthFormatDropdown, this.value)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end

local function FriendHealthFormatDropdown_Initialize()
    local healthFormatOptions = {
        {value = 0, text = "None"},
        {value = 1, text = "Percent"},
        {value = 2, text = "Current HP"},
        {value = 3, text = "HP (Percent%)"},
        {value = 4, text = "Current - Max"},
        {value = 5, text = "Current - Max (%)"},
        {value = 6, text = "Name - %"},
        {value = 7, text = "Name - HP(%)"},
        {value = 8, text = "Name"},
    }
    for _, opt in ipairs(healthFormatOptions) do
        local info = {}
        info.text = opt.text
        info.value = opt.value
        info.func = FriendHealthFormatDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(friendHealthFormatDropdown, FriendHealthFormatDropdown_Initialize)
UIDropDownMenu_SetWidth(150, friendHealthFormatDropdown)
UIDropDownMenu_SetSelectedValue(friendHealthFormatDropdown, Settings.friendHealthTextFormat)
    end

    local function SetupManaTab()
local scrollFrame = CreateFrame("ScrollFrame", "GudaPlatesManaScrollFrame", manaTab, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", manaTab, "TOPLEFT", 0, -5)
scrollFrame:SetPoint("BOTTOMRIGHT", manaTab, "BOTTOMRIGHT", -25, 5)

local scrollContent = CreateFrame("Frame", "GudaPlatesManaScrollContent", scrollFrame)
scrollContent:SetWidth(580)
scrollContent:SetHeight(650)
scrollFrame:SetScrollChild(scrollContent)

-- Enemy Section Header
local enemyHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
enemyHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 5, -5)
enemyHeader:SetText("Enemy Nameplates")

-- Show Mana Bar Checkbox
local manaBarCheckbox = CreateFrame("CheckButton", "GudaPlatesManaBarCheckbox", scrollContent, "UICheckButtonTemplate")
manaBarCheckbox:SetPoint("TOPLEFT", enemyHeader, "BOTTOMLEFT", 0, -10)
local manaBarLabel = getglobal(manaBarCheckbox:GetName().."Text")
manaBarLabel:SetText("Show Mana Bar")
manaBarLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)

-- Manabar Height Slider
local manaHeightSlider = CreateFrame("Slider", "GudaPlatesManaHeightSlider", scrollContent, "OptionsSliderTemplate")
manaHeightSlider:SetPoint("TOPLEFT", manaBarCheckbox, "BOTTOMLEFT", 0, -30)
manaHeightSlider:SetWidth(560)
manaHeightSlider:SetMinMaxValues(2, 10)
manaHeightSlider:SetValueStep(1)
local manaHeightText = getglobal(manaHeightSlider:GetName() .. "Text")
manaHeightText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(manaHeightSlider:GetName() .. "Low"):SetText("2")
getglobal(manaHeightSlider:GetName() .. "High"):SetText("10")
manaHeightSlider:SetScript("OnValueChanged", function()
    Settings.manabarHeight = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Manabar Height: " .. Settings.manabarHeight)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Mana Text Position Dropdown
local manaPosLabel = scrollContent:CreateFontString("GudaPlatesManaPosLabel", "OVERLAY", "GameFontNormal")
manaPosLabel:SetPoint("TOPLEFT", manaHeightSlider, "BOTTOMLEFT", 0, -15)
manaPosLabel:SetText("Mana Text Position:")

local manaPosDropdown = CreateFrame("Frame", "GudaPlatesManaPosDropdown", scrollContent, "UIDropDownMenuTemplate")
manaPosDropdown:SetPoint("TOPLEFT", manaPosLabel, "TOPRIGHT", -10, 8)

local function ManaPosDropdown_OnClick()
    Settings.manaTextPosition = this.value
    UIDropDownMenu_SetSelectedValue(GudaPlatesManaPosDropdown, this.value)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end

local function ManaPosDropdown_Initialize()
    local opts = {
        {value = "LEFT", text = "Left"},
        {value = "CENTER", text = "Center"},
        {value = "RIGHT", text = "Right"},
    }
    for _, opt in ipairs(opts) do
        local info = {}
        info.text = opt.text
        info.value = opt.value
        info.func = ManaPosDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(manaPosDropdown, ManaPosDropdown_Initialize)
UIDropDownMenu_SetWidth(80, manaPosDropdown)
UIDropDownMenu_SetSelectedValue(manaPosDropdown, Settings.manaTextPosition)

-- Mana Text Format Dropdown
local manaFormatLabel = scrollContent:CreateFontString("GudaPlatesManaFormatLabel", "OVERLAY", "GameFontNormal")
manaFormatLabel:SetPoint("LEFT", manaPosDropdown, "RIGHT", 10, 0)
manaFormatLabel:SetText("Mana Text Format:")

local manaFormatDropdown = CreateFrame("Frame", "GudaPlatesManaFormatDropdown", scrollContent, "UIDropDownMenuTemplate")
manaFormatDropdown:SetPoint("LEFT", manaFormatLabel, "RIGHT", -10, -3)

local function ManaFormatDropdown_OnClick()
    Settings.manaTextFormat = this.value
    UIDropDownMenu_SetSelectedValue(GudaPlatesManaFormatDropdown, this.value)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end

local function ManaFormatDropdown_Initialize()
    local opts = {
        {value = 0, text = "None"},
        {value = 1, text = "Percent"},
        {value = 2, text = "Current Mana"},
        {value = 3, text = "Mana (Percent%)"},
    }
    for _, opt in ipairs(opts) do
        local info = {}
        info.text = opt.text
        info.value = opt.value
        info.func = ManaFormatDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(manaFormatDropdown, ManaFormatDropdown_Initialize)
UIDropDownMenu_SetWidth(150, manaFormatDropdown)
UIDropDownMenu_SetSelectedValue(manaFormatDropdown, Settings.manaTextFormat)

-- Separator Line
local separator = scrollContent:CreateTexture(nil, "ARTWORK")
separator:SetTexture(1, 1, 1, 0.2)
separator:SetHeight(1)
separator:SetWidth(560)
separator:SetPoint("TOPLEFT", manaPosLabel, "BOTTOMLEFT", 0, -35)

-- Friendly Section Header
local friendlyHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
friendlyHeader:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -15)
friendlyHeader:SetText("Friendly Nameplates")

-- Friend Show Mana Bar Checkbox
local friendManaBarCheckbox = CreateFrame("CheckButton", "GudaPlatesFriendManaBarCheckbox", scrollContent, "UICheckButtonTemplate")
friendManaBarCheckbox:SetPoint("TOPLEFT", friendlyHeader, "BOTTOMLEFT", 0, -10)
local friendManaBarLabel = getglobal(friendManaBarCheckbox:GetName().."Text")
friendManaBarLabel:SetText("Show Mana Bar")
friendManaBarLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)

-- Friend Manabar Height Slider
local friendManaHeightSlider = CreateFrame("Slider", "GudaPlatesFriendManaHeightSlider", scrollContent, "OptionsSliderTemplate")
friendManaHeightSlider:SetPoint("TOPLEFT", friendManaBarCheckbox, "BOTTOMLEFT", 0, -30)
friendManaHeightSlider:SetWidth(560)
friendManaHeightSlider:SetMinMaxValues(2, 10)
friendManaHeightSlider:SetValueStep(1)
local friendManaHeightText = getglobal(friendManaHeightSlider:GetName() .. "Text")
friendManaHeightText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(friendManaHeightSlider:GetName() .. "Low"):SetText("2")
getglobal(friendManaHeightSlider:GetName() .. "High"):SetText("10")
friendManaHeightSlider:SetScript("OnValueChanged", function()
    Settings.friendManabarHeight = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Manabar Height: " .. Settings.friendManabarHeight)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Friend Mana Text Position Dropdown
local friendManaPosLabel = scrollContent:CreateFontString("GudaPlatesFriendManaPosLabel", "OVERLAY", "GameFontNormal")
friendManaPosLabel:SetPoint("TOPLEFT", friendManaHeightSlider, "BOTTOMLEFT", 0, -15)
friendManaPosLabel:SetText("Mana Text Position:")

local friendManaPosDropdown = CreateFrame("Frame", "GudaPlatesFriendManaPosDropdown", scrollContent, "UIDropDownMenuTemplate")
friendManaPosDropdown:SetPoint("TOPLEFT", friendManaPosLabel, "TOPRIGHT", -10, 8)

local function FriendManaPosDropdown_OnClick()
    Settings.friendManaTextPosition = this.value
    UIDropDownMenu_SetSelectedValue(GudaPlatesFriendManaPosDropdown, this.value)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end

local function FriendManaPosDropdown_Initialize()
    local opts = {
        {value = "LEFT", text = "Left"},
        {value = "CENTER", text = "Center"},
        {value = "RIGHT", text = "Right"},
    }
    for _, opt in ipairs(opts) do
        local info = {}
        info.text = opt.text
        info.value = opt.value
        info.func = FriendManaPosDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(friendManaPosDropdown, FriendManaPosDropdown_Initialize)
UIDropDownMenu_SetWidth(80, friendManaPosDropdown)
UIDropDownMenu_SetSelectedValue(friendManaPosDropdown, Settings.friendManaTextPosition)

-- Friend Mana Text Format Dropdown
local friendManaFormatLabel = scrollContent:CreateFontString("GudaPlatesFriendManaFormatLabel", "OVERLAY", "GameFontNormal")
friendManaFormatLabel:SetPoint("LEFT", friendManaPosDropdown, "RIGHT", 10, 0)
friendManaFormatLabel:SetText("Mana Text Format:")

local friendManaFormatDropdown = CreateFrame("Frame", "GudaPlatesFriendManaFormatDropdown", scrollContent, "UIDropDownMenuTemplate")
friendManaFormatDropdown:SetPoint("LEFT", friendManaFormatLabel, "RIGHT", -10, -3)

local function FriendManaFormatDropdown_OnClick()
    Settings.friendManaTextFormat = this.value
    UIDropDownMenu_SetSelectedValue(GudaPlatesFriendManaFormatDropdown, this.value)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end

local function FriendManaFormatDropdown_Initialize()
    local opts = {
        {value = 0, text = "None"},
        {value = 1, text = "Percent"},
        {value = 2, text = "Current Mana"},
        {value = 3, text = "Mana (Percent%)"},
    }
    for _, opt in ipairs(opts) do
        local info = {}
        info.text = opt.text
        info.value = opt.value
        info.func = FriendManaFormatDropdown_OnClick
        UIDropDownMenu_AddButton(info)
    end
end

UIDropDownMenu_Initialize(friendManaFormatDropdown, FriendManaFormatDropdown_Initialize)
UIDropDownMenu_SetWidth(150, friendManaFormatDropdown)
UIDropDownMenu_SetSelectedValue(friendManaFormatDropdown, Settings.friendManaTextFormat)

-- Function to update mana options enabled state
function UpdateManaOptionsState()
    -- Enemy
    local enabled = Settings.showManaBar
    local manaFmtLbl = getglobal("GudaPlatesManaFormatLabel")
    local manaPosLbl = getglobal("GudaPlatesManaPosLabel")
    local manaHtSliderText = getglobal("GudaPlatesManaHeightSliderText")
    if enabled then
        if manaFmtLbl then manaFmtLbl:SetTextColor(1, 0.82, 0) end
        if manaPosLbl then manaPosLbl:SetTextColor(1, 0.82, 0) end
        if manaHtSliderText then manaHtSliderText:SetTextColor(1, 0.82, 0) end
    else
        if manaFmtLbl then manaFmtLbl:SetTextColor(0.5, 0.5, 0.5) end
        if manaPosLbl then manaPosLbl:SetTextColor(0.5, 0.5, 0.5) end
        if manaHtSliderText then manaHtSliderText:SetTextColor(0.5, 0.5, 0.5) end
    end

    -- Friendly
    local fEnabled = Settings.friendShowManaBar
    local fManaFmtLbl = getglobal("GudaPlatesFriendManaFormatLabel")
    local fManaPosLbl = getglobal("GudaPlatesFriendManaPosLabel")
    local fManaHtSliderText = getglobal("GudaPlatesFriendManaHeightSliderText")
    if fEnabled then
        if fManaFmtLbl then fManaFmtLbl:SetTextColor(1, 0.82, 0) end
        if fManaPosLbl then fManaPosLbl:SetTextColor(1, 0.82, 0) end
        if fManaHtSliderText then fManaHtSliderText:SetTextColor(1, 0.82, 0) end
    else
        if fManaFmtLbl then fManaFmtLbl:SetTextColor(0.5, 0.5, 0.5) end
        if fManaPosLbl then fManaPosLbl:SetTextColor(0.5, 0.5, 0.5) end
        if fManaHtSliderText then fManaHtSliderText:SetTextColor(0.5, 0.5, 0.5) end
    end
end

-- Mana Bar Checkbox OnClick
manaBarCheckbox:SetScript("OnClick", function()
    Settings.showManaBar = this:GetChecked() == 1
    UpdateManaOptionsState()
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end)
manaBarCheckbox:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Show Mana Bar (Enemy)")
    GameTooltip:AddLine("Shows a mana bar below the health bar", 1, 1, 1, 1)
    GameTooltip:AddLine("for units with mana. Requires SuperWoW.", 1, 1, 1, 1)
    GameTooltip:Show()
end)
manaBarCheckbox:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Friend Mana Bar Checkbox OnClick
friendManaBarCheckbox:SetScript("OnClick", function()
    Settings.friendShowManaBar = this:GetChecked() == 1
    UpdateManaOptionsState()
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end)
friendManaBarCheckbox:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Show Mana Bar (Friendly)")
    GameTooltip:AddLine("Shows a mana bar below the health bar", 1, 1, 1, 1)
    GameTooltip:AddLine("for units with mana. Requires SuperWoW.", 1, 1, 1, 1)
    GameTooltip:Show()
end)
friendManaBarCheckbox:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
    end

    local function SetupCastbarTab()
local scrollFrame = CreateFrame("ScrollFrame", "GudaPlatesCastScrollFrame", castbarTab, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", castbarTab, "TOPLEFT", 0, -5)
scrollFrame:SetPoint("BOTTOMRIGHT", castbarTab, "BOTTOMRIGHT", -25, 5)

local scrollContent = CreateFrame("Frame", "GudaPlatesCastScrollContent", scrollFrame)
scrollContent:SetWidth(580)
scrollContent:SetHeight(500)
scrollFrame:SetScrollChild(scrollContent)

-- Enemy Section Header
local enemyHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
enemyHeader:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 5, -5)
enemyHeader:SetText("Enemy Nameplates")

-- Show Spell Icon Checkbox
local castbarIconCheckbox = CreateFrame("CheckButton", "GudaPlatesCastbarIconCheckbox", scrollContent, "UICheckButtonTemplate")
castbarIconCheckbox:SetPoint("TOPLEFT", enemyHeader, "BOTTOMLEFT", 0, -10)
local castbarIconLabel = getglobal(castbarIconCheckbox:GetName().."Text")
castbarIconLabel:SetText("Show Spell Icon")
castbarIconLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
castbarIconCheckbox:SetScript("OnClick", function()
    Settings.showCastbarIcon = this:GetChecked() == 1
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end)

-- Castbar Height Slider
local castbarHeightSlider = CreateFrame("Slider", "GudaPlatesCastbarHeightSlider", scrollContent, "OptionsSliderTemplate")
castbarHeightSlider:SetPoint("TOPLEFT", castbarIconCheckbox, "BOTTOMLEFT", 0, -30)
castbarHeightSlider:SetWidth(560)
castbarHeightSlider:SetMinMaxValues(6, 20)
castbarHeightSlider:SetValueStep(1)
local castbarHeightText = getglobal(castbarHeightSlider:GetName() .. "Text")
castbarHeightText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(castbarHeightSlider:GetName() .. "Low"):SetText("6")
getglobal(castbarHeightSlider:GetName() .. "High"):SetText("20")
castbarHeightSlider:SetScript("OnValueChanged", function()
    Settings.castbarHeight = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Castbar Height: " .. Settings.castbarHeight)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Independent Castbar Width Checkbox
local castbarIndependentCheckbox = CreateFrame("CheckButton", "GudaPlatesCastbarIndependentCheckbox", scrollContent, "UICheckButtonTemplate")
castbarIndependentCheckbox:SetPoint("TOPLEFT", castbarHeightSlider, "BOTTOMLEFT", 0, -15)
local castbarIndependentLabel = getglobal(castbarIndependentCheckbox:GetName().."Text")
castbarIndependentLabel:SetText("Independent Width from Healthbar")
castbarIndependentLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)

-- Castbar Width Slider
local castbarWidthSlider = CreateFrame("Slider", "GudaPlatesCastbarWidthSlider", scrollContent, "OptionsSliderTemplate")
castbarWidthSlider:SetPoint("TOPLEFT", castbarIndependentCheckbox, "BOTTOMLEFT", 0, -30)
castbarWidthSlider:SetWidth(560)
castbarWidthSlider:SetMinMaxValues(72, 200)
castbarWidthSlider:SetValueStep(1)
local castbarWidthText = getglobal(castbarWidthSlider:GetName() .. "Text")
castbarWidthText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(castbarWidthSlider:GetName() .. "Low"):SetText("72")
getglobal(castbarWidthSlider:GetName() .. "High"):SetText("200")
castbarWidthSlider:SetScript("OnValueChanged", function()
    Settings.castbarWidth = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Castbar Width: " .. Settings.castbarWidth)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Function to update castbar width slider enabled state
function UpdateCastbarWidthSliderState()
    if Settings.castbarIndependent then
        castbarWidthSlider:EnableMouse(true)
        castbarWidthSlider:SetAlpha(1.0)
    else
        castbarWidthSlider:EnableMouse(false)
        castbarWidthSlider:SetAlpha(0.5)
    end

    if Settings.friendCastbarIndependent then
        getglobal("GudaPlatesFriendCastbarWidthSlider"):EnableMouse(true)
        getglobal("GudaPlatesFriendCastbarWidthSlider"):SetAlpha(1.0)
    else
        getglobal("GudaPlatesFriendCastbarWidthSlider"):EnableMouse(false)
        getglobal("GudaPlatesFriendCastbarWidthSlider"):SetAlpha(0.5)
    end
end

castbarIndependentCheckbox:SetScript("OnClick", function()
    Settings.castbarIndependent = this:GetChecked() == 1
    UpdateCastbarWidthSliderState()
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Separator Line
local separator = scrollContent:CreateTexture(nil, "ARTWORK")
separator:SetTexture(1, 1, 1, 0.2)
separator:SetHeight(1)
separator:SetWidth(560)
separator:SetPoint("TOPLEFT", castbarWidthSlider, "BOTTOMLEFT", 0, -15)

-- Friendly Section Header
local friendlyHeader = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
friendlyHeader:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 0, -15)
friendlyHeader:SetText("Friendly Nameplates")

-- Friend Show Spell Icon Checkbox
local friendCastbarIconCheckbox = CreateFrame("CheckButton", "GudaPlatesFriendCastbarIconCheckbox", scrollContent, "UICheckButtonTemplate")
friendCastbarIconCheckbox:SetPoint("TOPLEFT", friendlyHeader, "BOTTOMLEFT", 0, -10)
local friendCastbarIconLabel = getglobal(friendCastbarIconCheckbox:GetName().."Text")
friendCastbarIconLabel:SetText("Show Spell Icon")
friendCastbarIconLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
friendCastbarIconCheckbox:SetScript("OnClick", function()
    Settings.friendShowCastbarIcon = this:GetChecked() == 1
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlate(plate)
    end
end)

-- Friend Castbar Height Slider
local friendCastbarHeightSlider = CreateFrame("Slider", "GudaPlatesFriendCastbarHeightSlider", scrollContent, "OptionsSliderTemplate")
friendCastbarHeightSlider:SetPoint("TOPLEFT", friendCastbarIconCheckbox, "BOTTOMLEFT", 0, -30)
friendCastbarHeightSlider:SetWidth(560)
friendCastbarHeightSlider:SetMinMaxValues(6, 20)
friendCastbarHeightSlider:SetValueStep(1)
local friendCastbarHeightText = getglobal(friendCastbarHeightSlider:GetName() .. "Text")
friendCastbarHeightText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(friendCastbarHeightSlider:GetName() .. "Low"):SetText("6")
getglobal(friendCastbarHeightSlider:GetName() .. "High"):SetText("20")
friendCastbarHeightSlider:SetScript("OnValueChanged", function()
    Settings.friendCastbarHeight = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Castbar Height: " .. Settings.friendCastbarHeight)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Friend Independent Castbar Width Checkbox
local friendCastbarIndependentCheckbox = CreateFrame("CheckButton", "GudaPlatesFriendCastbarIndependentCheckbox", scrollContent, "UICheckButtonTemplate")
friendCastbarIndependentCheckbox:SetPoint("TOPLEFT", friendCastbarHeightSlider, "BOTTOMLEFT", 0, -15)
local friendCastbarIndependentLabel = getglobal(friendCastbarIndependentCheckbox:GetName().."Text")
friendCastbarIndependentLabel:SetText("Independent Width from Healthbar")
friendCastbarIndependentLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
friendCastbarIndependentCheckbox:SetScript("OnClick", function()
    Settings.friendCastbarIndependent = this:GetChecked() == 1
    UpdateCastbarWidthSliderState()
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)

-- Friend Castbar Width Slider
local friendCastbarWidthSlider = CreateFrame("Slider", "GudaPlatesFriendCastbarWidthSlider", scrollContent, "OptionsSliderTemplate")
friendCastbarWidthSlider:SetPoint("TOPLEFT", friendCastbarIndependentCheckbox, "BOTTOMLEFT", 0, -30)
friendCastbarWidthSlider:SetWidth(560)
friendCastbarWidthSlider:SetMinMaxValues(72, 200)
friendCastbarWidthSlider:SetValueStep(1)
local friendCastbarWidthText = getglobal(friendCastbarWidthSlider:GetName() .. "Text")
friendCastbarWidthText:SetFont("Fonts\\FRIZQT__.TTF", 12)
getglobal(friendCastbarWidthSlider:GetName() .. "Low"):SetText("72")
getglobal(friendCastbarWidthSlider:GetName() .. "High"):SetText("200")
friendCastbarWidthSlider:SetScript("OnValueChanged", function()
    Settings.friendCastbarWidth = this:GetValue()
    getglobal(this:GetName() .. "Text"):SetText("Castbar Width: " .. Settings.friendCastbarWidth)
    SaveSettings()
    for plate, _ in pairs(registry) do
        UpdateNamePlateDimensions(plate)
    end
end)
    end

    local function SetupColorsTab()

-- Tank Mode Checkbox
local tankCheckbox = CreateFrame("CheckButton", "GudaPlatesTankCheckbox", colorsTab, "UICheckButtonTemplate")
tankCheckbox:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 5, -10)
local tankLabel = getglobal(tankCheckbox:GetName().."Text")
tankLabel:SetText("Tank Mode")
tankLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
tankCheckbox:SetScript("OnClick", function()
    if this:GetChecked() == 1 then
        GudaPlates.playerRole = "TANK"
    else
        GudaPlates.playerRole = "DPS"
    end
    SaveSettings()
    Print("Role set to " .. GudaPlates.playerRole)
    -- Broadcast to raid/party (with 5 sec debounce to prevent spam)
    if GudaPlates.BroadcastTankMode then
        GudaPlates.BroadcastTankMode()
    end
end)
tankCheckbox:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Tank Mode")
    GameTooltip:AddLine("If unchecked, you are in DPS/Healer mode.", 1, 1, 1, 1)
    GameTooltip:AddLine("Setting is shared with raid/party members.", 0.7, 0.7, 0.7, 1)
    GameTooltip:Show()
end)
tankCheckbox:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- DPS Colors Section
local dpsHeader = colorsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dpsHeader:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 5, -50)
dpsHeader:SetText("|cff00ff00DPS/Healer Colors:|r")

CreateColorSwatch(colorsTab, 5, -75, "Aggro (Bad)", THREAT_COLORS.DPS, "AGGRO")
CreateColorSwatch(colorsTab, 5, -100, "High Threat (Warning)", THREAT_COLORS.DPS, "HIGH_THREAT")
CreateColorSwatch(colorsTab, 5, -125, "No Aggro (Good)", THREAT_COLORS.DPS, "NO_AGGRO")

-- Tank Colors Section
local tankHeader = colorsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tankHeader:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 320, -50)
tankHeader:SetText("|cff00ff00Tank Colors:|r")

CreateColorSwatch(colorsTab, 320, -75, "Has Aggro (Good)", THREAT_COLORS.TANK, "AGGRO")
CreateColorSwatch(colorsTab, 320, -100, "Other Tank Aggro", THREAT_COLORS.TANK, "OTHER_TANK")
CreateColorSwatch(colorsTab, 320, -125, "Losing Aggro (Warning)", THREAT_COLORS.TANK, "LOSING_AGGRO")
CreateColorSwatch(colorsTab, 320, -150, "No Aggro (Bad)", THREAT_COLORS.TANK, "NO_AGGRO")

-- Misc Colors Section
local miscHeader = colorsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
miscHeader:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 5, -200)
miscHeader:SetText("|cff00ff00Other Colors:|r")

CreateColorSwatch(colorsTab, 5, -225, "Unit Tapped", THREAT_COLORS, "TAPPED")
CreateColorSwatch(colorsTab, 5, -250, "Stun", THREAT_COLORS, "STUN")
CreateColorSwatch(colorsTab, 5, -275, "Mana Bar", THREAT_COLORS, "MANA_BAR")

-- Target Glow Color Swatch (uses Settings table directly)
local targetGlowSwatchLabel = colorsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
targetGlowSwatchLabel:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 5, -305)
targetGlowSwatchLabel:SetText("Target Glow")

local targetGlowSwatch = CreateFrame("Button", nil, colorsTab)
targetGlowSwatch:SetWidth(20)
targetGlowSwatch:SetHeight(20)
targetGlowSwatch:SetPoint("LEFT", targetGlowSwatchLabel, "RIGHT", 10, 0)

local targetGlowSwatchBorder = targetGlowSwatch:CreateTexture(nil, "BACKGROUND")
targetGlowSwatchBorder:SetTexture(0, 0, 0, 1)
targetGlowSwatchBorder:SetAllPoints()

local targetGlowSwatchBg = targetGlowSwatch:CreateTexture(nil, "ARTWORK")
targetGlowSwatchBg:SetTexture(1, 1, 1, 1)
targetGlowSwatchBg:SetPoint("TOPLEFT", targetGlowSwatch, "TOPLEFT", 2, -2)
targetGlowSwatchBg:SetPoint("BOTTOMRIGHT", targetGlowSwatch, "BOTTOMRIGHT", -2, 2)

local function UpdateTargetGlowSwatchColor()
    local c = Settings.targetGlowColor
    targetGlowSwatchBg:SetVertexColor(c[1], c[2], c[3], 1)
end
UpdateTargetGlowSwatchColor()
table.insert(swatches, UpdateTargetGlowSwatchColor)

targetGlowSwatch:SetScript("OnClick", function()
    local c = Settings.targetGlowColor
    ShowColorPicker(c[1], c[2], c[3], function(r, g, b)
        if r then
            Settings.targetGlowColor = {r, g, b, 0.4}
            UpdateTargetGlowSwatchColor()
            SaveSettings()
            for plate, _ in pairs(registry) do
                if plate:IsShown() then
                    UpdateNamePlate(plate)
                end
            end
        end
    end)
end)

targetGlowSwatch:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Click to change target glow color")
    GameTooltip:Show()
end)

targetGlowSwatch:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Castbar Color Swatch
local castbarSwatchLabel = colorsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
castbarSwatchLabel:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 5, -330)
castbarSwatchLabel:SetText("Castbar")

local castbarSwatch = CreateFrame("Button", nil, colorsTab)
castbarSwatch:SetWidth(20)
castbarSwatch:SetHeight(20)
castbarSwatch:SetPoint("LEFT", castbarSwatchLabel, "RIGHT", 10, 0)

local castbarSwatchBorder = castbarSwatch:CreateTexture(nil, "BACKGROUND")
castbarSwatchBorder:SetTexture(0, 0, 0, 1)
castbarSwatchBorder:SetAllPoints()

local castbarSwatchBg = castbarSwatch:CreateTexture(nil, "ARTWORK")
castbarSwatchBg:SetTexture(1, 1, 1, 1)
castbarSwatchBg:SetPoint("TOPLEFT", castbarSwatch, "TOPLEFT", 2, -2)
castbarSwatchBg:SetPoint("BOTTOMRIGHT", castbarSwatch, "BOTTOMRIGHT", -2, 2)

local function UpdateCastbarSwatchColor()
    local c = Settings.castbarColor
    castbarSwatchBg:SetVertexColor(c[1], c[2], c[3], 1)
end
UpdateCastbarSwatchColor()
table.insert(swatches, UpdateCastbarSwatchColor)

castbarSwatch:SetScript("OnClick", function()
    local c = Settings.castbarColor
    ShowColorPicker(c[1], c[2], c[3], function(r, g, b)
        if r then
            Settings.castbarColor = {r, g, b, 1}
            UpdateCastbarSwatchColor()
            SaveSettings()
            for plate, _ in pairs(registry) do
                if plate:IsShown() and plate.nameplate and plate.nameplate.castbar then
                    plate.nameplate.castbar:SetStatusBarColor(r, g, b, 1)
                end
            end
        end
    end)
end)

castbarSwatch:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Click to change castbar color")
    GameTooltip:Show()
end)

castbarSwatch:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Text Colors Section
local textColorsHeader = colorsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
textColorsHeader:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 320, -200)
textColorsHeader:SetText("|cff00ff00Text Colors:|r")

CreateColorSwatch(colorsTab, 320, -225, "Health Text", Settings, "healthTextColor")
CreateColorSwatch(colorsTab, 320, -250, "Mana Text", Settings, "manaTextColor")
CreateColorSwatch(colorsTab, 320, -275, "Name", Settings, "nameColor")
CreateColorSwatch(colorsTab, 320, -300, "Level", Settings, "levelColor")

end

-- OnShow handler
optionsFrame:SetScript("OnShow", function()
    -- General tab
    local currentAlpha = Settings.optionsBgAlpha
    if currentAlpha == nil then currentAlpha = 0.9 end
    local currentTransparency = 1 - currentAlpha
    getglobal("GudaPlatesOptionsTransparencySlider"):SetValue(currentTransparency)
    getglobal("GudaPlatesOptionsTransparencySliderText"):SetText("Background Transparency: " .. math_floor(currentTransparency * 100) .. "%")
    getglobal("GudaPlatesHideBorderCheckbox"):SetChecked(Settings.hideOptionsBorder)
    getglobal("GudaPlatesOverlapCheckbox"):SetChecked(GudaPlates.nameplateOverlap)
    getglobal("GudaPlatesClickThroughCheckbox"):SetChecked(GudaPlates.nameplateClickThrough)
    getglobal("GudaPlatesLevelFontSlider"):SetValue(Settings.levelFontSize)
    getglobal("GudaPlatesLevelFontSliderText"):SetText("Level Font Size: " .. Settings.levelFontSize)
    getglobal("GudaPlatesNameFontSlider"):SetValue(Settings.nameFontSize)
    getglobal("GudaPlatesNameFontSliderText"):SetText("Name Font Size: " .. Settings.nameFontSize)
    getglobal("GudaPlatesRaidMarkCheckbox"):SetChecked(Settings.raidIconPosition == "RIGHT")
    getglobal("GudaPlatesSwapCheckbox"):SetChecked(Settings.swapNameDebuff)
    getglobal("GudaPlatesDebuffTimerCheckbox"):SetChecked(Settings.showDebuffTimers)
    getglobal("GudaPlatesShowCrittersCheckbox"):SetChecked(Settings.showCritterNameplates)
    getglobal("GudaPlatesOnlyMyDebuffsCheckbox"):SetChecked(Settings.showOnlyMyDebuffs)
    getglobal("GudaPlatesDebuffSizeSlider"):SetValue(Settings.debuffIconSize)
    getglobal("GudaPlatesDebuffSizeSliderText"):SetText("Debuff Icon Size: " .. Settings.debuffIconSize .. " px")
    getglobal("GudaPlatesTargetGlowCheckbox"):SetChecked(Settings.showTargetGlow)
    UIDropDownMenu_SetSelectedValue(getglobal("GudaPlatesFontDropdown"), Settings.textFont)
    -- Health/Mana tab
    getglobal("GudaPlatesPvPNoClassColorsCheckbox"):SetChecked(Settings.pvpEnemyNoClassColors)
    getglobal("GudaPlatesPvPAsFriendlyCheckbox"):SetChecked(Settings.pvpEnemyAsFriendly)
    getglobal("GudaPlatesHeightSlider"):SetValue(Settings.healthbarHeight)
    getglobal("GudaPlatesHeightSliderText"):SetText("Healthbar Height: " .. Settings.healthbarHeight)
    getglobal("GudaPlatesWidthSlider"):SetValue(Settings.healthbarWidth)
    getglobal("GudaPlatesWidthSliderText"):SetText("Healthbar Width: " .. Settings.healthbarWidth)
    getglobal("GudaPlatesHealthFontSlider"):SetValue(Settings.healthFontSize)
    getglobal("GudaPlatesHealthFontSliderText"):SetText("Health Font Size: " .. Settings.healthFontSize)
    UIDropDownMenu_SetSelectedValue(getglobal("GudaPlatesHealthPosDropdown"), Settings.healthTextPosition)
    UIDropDownMenu_SetSelectedValue(getglobal("GudaPlatesHealthFormatDropdown"), Settings.healthTextFormat)

    -- Friendly nameplates
    getglobal("GudaPlatesFriendHeightSlider"):SetValue(Settings.friendHealthbarHeight)
    getglobal("GudaPlatesFriendHeightSliderText"):SetText("Healthbar Height: " .. Settings.friendHealthbarHeight)
    getglobal("GudaPlatesFriendWidthSlider"):SetValue(Settings.friendHealthbarWidth)
    getglobal("GudaPlatesFriendWidthSliderText"):SetText("Healthbar Width: " .. Settings.friendHealthbarWidth)
    getglobal("GudaPlatesFriendHealthFontSlider"):SetValue(Settings.friendHealthFontSize)
    getglobal("GudaPlatesFriendHealthFontSliderText"):SetText("Health Font Size: " .. Settings.friendHealthFontSize)
    getglobal("GudaPlatesFriendLevelFontSlider"):SetValue(Settings.friendLevelFontSize)
    getglobal("GudaPlatesFriendLevelFontSliderText"):SetText("Level Font Size: " .. Settings.friendLevelFontSize)
    getglobal("GudaPlatesFriendNameFontSlider"):SetValue(Settings.friendNameFontSize)
    getglobal("GudaPlatesFriendNameFontSliderText"):SetText("Name Font Size: " .. Settings.friendNameFontSize)
    UIDropDownMenu_SetSelectedValue(getglobal("GudaPlatesFriendHealthPosDropdown"), Settings.friendHealthTextPosition)
    UIDropDownMenu_SetSelectedValue(getglobal("GudaPlatesFriendHealthFormatDropdown"), Settings.friendHealthTextFormat)
    -- Mana settings
    getglobal("GudaPlatesManaBarCheckbox"):SetChecked(Settings.showManaBar)
    UIDropDownMenu_SetSelectedValue(getglobal("GudaPlatesManaFormatDropdown"), Settings.manaTextFormat)
    UIDropDownMenu_SetSelectedValue(getglobal("GudaPlatesManaPosDropdown"), Settings.manaTextPosition)
    getglobal("GudaPlatesManaHeightSlider"):SetValue(Settings.manabarHeight)
    getglobal("GudaPlatesManaHeightSliderText"):SetText("Manabar Height: " .. Settings.manabarHeight)

    getglobal("GudaPlatesFriendManaBarCheckbox"):SetChecked(Settings.friendShowManaBar)
    UIDropDownMenu_SetSelectedValue(getglobal("GudaPlatesFriendManaFormatDropdown"), Settings.friendManaTextFormat)
    UIDropDownMenu_SetSelectedValue(getglobal("GudaPlatesFriendManaPosDropdown"), Settings.friendManaTextPosition)
    getglobal("GudaPlatesFriendManaHeightSlider"):SetValue(Settings.friendManabarHeight)
    getglobal("GudaPlatesFriendManaHeightSliderText"):SetText("Manabar Height: " .. Settings.friendManabarHeight)

    UpdateManaOptionsState()
    if optionsFrame and optionsFrame.UpdateBackdrop then
        optionsFrame.UpdateBackdrop()
    end
    -- Castbar tab
    getglobal("GudaPlatesCastbarIconCheckbox"):SetChecked(Settings.showCastbarIcon)
    getglobal("GudaPlatesCastbarHeightSlider"):SetValue(Settings.castbarHeight)
    getglobal("GudaPlatesCastbarHeightSliderText"):SetText("Castbar Height: " .. Settings.castbarHeight)
    getglobal("GudaPlatesCastbarIndependentCheckbox"):SetChecked(Settings.castbarIndependent)
    getglobal("GudaPlatesCastbarWidthSlider"):SetValue(Settings.castbarWidth)
    getglobal("GudaPlatesCastbarWidthSliderText"):SetText("Castbar Width: " .. Settings.castbarWidth)

    getglobal("GudaPlatesFriendCastbarIconCheckbox"):SetChecked(Settings.friendShowCastbarIcon)
    getglobal("GudaPlatesFriendCastbarHeightSlider"):SetValue(Settings.friendCastbarHeight)
    getglobal("GudaPlatesFriendCastbarHeightSliderText"):SetText("Castbar Height: " .. Settings.friendCastbarHeight)
    getglobal("GudaPlatesFriendCastbarIndependentCheckbox"):SetChecked(Settings.friendCastbarIndependent)
    getglobal("GudaPlatesFriendCastbarWidthSlider"):SetValue(Settings.friendCastbarWidth)
    getglobal("GudaPlatesFriendCastbarWidthSliderText"):SetText("Castbar Width: " .. Settings.friendCastbarWidth)
    UpdateCastbarWidthSliderState()
    -- Colors tab
    getglobal("GudaPlatesTankCheckbox"):SetChecked(GudaPlates.playerRole == "TANK")
    -- Update color swatches
    for _, updateFunc in ipairs(swatches) do
        updateFunc()
    end
end)

-- Reset to defaults button
local resetButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
resetButton:SetWidth(120)
resetButton:SetHeight(25)
resetButton:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 15)
resetButton:SetText("Reset Defaults")
resetButton:SetScript("OnClick", function()
    GudaPlates.playerRole = "DPS"
    THREAT_COLORS.DPS.AGGRO = {0.41, 0.35, 0.76, 1}
    THREAT_COLORS.DPS.HIGH_THREAT = {1.0, 0.6, 0.0, 1}
    THREAT_COLORS.DPS.NO_AGGRO = {0.85, 0.2, 0.2, 1}
    THREAT_COLORS.TANK.AGGRO = {0.41, 0.35, 0.76, 1}
    THREAT_COLORS.TANK.OTHER_TANK = {0.6, 0.8, 1.0, 1}
    THREAT_COLORS.TANK.LOSING_AGGRO = {1.0, 0.6, 0.0, 1}
    THREAT_COLORS.TANK.NO_AGGRO = {0.85, 0.2, 0.2, 1}
    THREAT_COLORS.TAPPED = {0.5, 0.5, 0.5, 1}
    THREAT_COLORS.STUN = {0.376, 0.027, 0.431, 1}
    THREAT_COLORS.MANA_BAR = {0.07, 0.58, 1.0, 1}
    Settings.optionsBgAlpha = 0.9
    Settings.hideOptionsBorder = false
    Settings.healthbarHeight = 14
    Settings.healthbarWidth = 115
    Settings.healthFontSize = 10
    Settings.healthTextPosition = "CENTER"
    Settings.healthTextFormat = 1
    Settings.friendHealthbarHeight = 4
    Settings.friendHealthbarWidth = 85
    Settings.friendHealthFontSize = 10
    Settings.friendHealthTextPosition = "CENTER"
    Settings.friendHealthTextFormat = 1
    Settings.debuffIconSize = 16
    Settings.showManaBar = false
    Settings.manaTextFormat = 1
    Settings.manaTextPosition = "CENTER"
    Settings.manabarHeight = 4
    Settings.friendShowManaBar = false
    Settings.friendManaTextFormat = 1
    Settings.friendManaTextPosition = "CENTER"
    Settings.friendManabarHeight = 4
    Settings.levelFontSize = 10
    Settings.nameFontSize = 10
    Settings.friendLevelFontSize = 8
    Settings.friendNameFontSize = 8
    Settings.textFont = "Fonts\\ARIALN.TTF"
    Settings.castbarHeight = 12
    Settings.castbarWidth = 115
    Settings.castbarIndependent = false
    Settings.showCastbarIcon = true
    Settings.friendCastbarHeight = 6
    Settings.friendCastbarWidth = 85
    Settings.friendCastbarIndependent = false
    Settings.friendShowCastbarIcon = true
    Settings.castbarColor = {1, 0.8, 0, 1}
    Settings.raidIconPosition = "LEFT"
    Settings.swapNameDebuff = false
    Settings.showDebuffTimers = true
    Settings.showOnlyMyDebuffs = true
    Settings.showTargetGlow = true
    Settings.targetGlowColor = {0.4, 0.8, 0.9, 0.4}
    Settings.nameColor = {1, 1, 1, 1}
    Settings.healthTextColor = {1, 1, 1, 1}
    Settings.manaTextColor = {1, 1, 1, 1}
    Settings.levelColor = {1, 1, 0.6, 1}
    SaveSettings()
    Print("Settings reset to defaults.")
    -- Update color swatches
    for _, updateFunc in ipairs(swatches) do
        updateFunc()
    end
    -- Re-show options frame to refresh all UI elements
    GudaPlatesOptionsFrame:Hide()
    GudaPlatesOptionsFrame:Show()
    -- Force refresh of all visible nameplates
    for plate, _ in pairs(registry) do
        if plate:IsShown() then
            UpdateNamePlateDimensions(plate)
            UpdateNamePlate(plate)
        end
    end
end)

    SetupGeneralTab()
    SetupHealthbarTab()
    SetupManaTab()
    SetupCastbarTab()
    SetupColorsTab()
end

CreateOptionsFrame()
