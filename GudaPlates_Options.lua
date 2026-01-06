-- GudaPlates Options
GudaPlates = GudaPlates or {}

-- Local references
local Settings = GudaPlates.Settings
local THREAT_COLORS = GudaPlates.THREAT_COLORS
local Print = GudaPlates.Print
local SaveSettings = function() GudaPlates.SaveSettings() end

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

local swatches = {}
local function CreateColorSwatch(parent, x, y, label, colorTable, colorKey)
    local swatchLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    swatchLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    swatchLabel:SetText(label)

    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetWidth(20)
    swatch:SetHeight(20)
    swatch:SetPoint("LEFT", swatchLabel, "RIGHT", 10, 0)

    local swatchBorder = swatch:CreateTexture(nil, "BACKGROUND")
    swatchBorder:SetTexture(0, 0, 0, 1)
    swatchBorder:SetAllPoints()

    local swatchBg = swatch:CreateTexture(nil, "ARTWORK")
    swatchBg:SetTexture(1, 1, 1, 1)
    swatchBg:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
    swatchBg:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)

    local function UpdateSwatch()
        local c = colorTable[colorKey]
        swatchBg:SetVertexColor(c[1], c[2], c[3], 1)
    end
    UpdateSwatch()
    table.insert(swatches, UpdateSwatch)

    swatch:SetScript("OnClick", function()
        local c = colorTable[colorKey]
        ShowColorPicker(c[1], c[2], c[3], function(r, g, b)
            if r then
                colorTable[colorKey] = {r, g, b, 1}
                UpdateSwatch()
                SaveSettings()
                for plate, _ in pairs(GudaPlates.registry) do
                    GudaPlates.UpdateNamePlate(plate)
                end
            end
        end)
    end)
    return swatch
end

-- Function to update mana options enabled/disabled state
local function UpdateManaOptionsState()
    local enabled = Settings.showManaBar
    local alpha = enabled and 1.0 or 0.5
    
    getglobal("GudaPlatesShowManaTextCheckbox"):EnableMouse(enabled)
    getglobal("GudaPlatesShowManaTextCheckbox"):SetAlpha(alpha)
    getglobal("GudaPlatesManaHeightSlider"):EnableMouse(enabled)
    getglobal("GudaPlatesManaHeightSlider"):SetAlpha(alpha)
    getglobal("GudaPlatesManaFormatDropdown"):SetAlpha(alpha)
    getglobal("GudaPlatesManaPosDropdown"):SetAlpha(alpha)
    
    if not enabled then
        OptionsFrame_DisableDropDown(GudaPlatesManaFormatDropdown)
        OptionsFrame_DisableDropDown(GudaPlatesManaPosDropdown)
    else
        OptionsFrame_EnableDropDown(GudaPlatesManaFormatDropdown)
        OptionsFrame_EnableDropDown(GudaPlatesManaPosDropdown)
    end
end

-- Function to update castbar width slider enabled state
local function UpdateCastbarWidthSliderState()
    if Settings.castbarIndependent then
        getglobal("GudaPlatesCastbarWidthSlider"):EnableMouse(true)
        getglobal("GudaPlatesCastbarWidthSlider"):SetAlpha(1.0)
    else
        getglobal("GudaPlatesCastbarWidthSlider"):EnableMouse(false)
        getglobal("GudaPlatesCastbarWidthSlider"):SetAlpha(0.5)
    end
end

function GudaPlates.CreateOptionsFrame()
    local optionsFrame = CreateFrame("Frame", "GudaPlatesOptionsFrame", UIParent)
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetFrameLevel(100)
    optionsFrame:SetWidth(650)
    optionsFrame:SetHeight(540)
    optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", function() this:StartMoving() end)
    optionsFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    optionsFrame:Hide()

    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", optionsFrame, "TOP", 0, -20)
    title:SetText("GudaPlates Settings")

    local closeButton = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -5, -5)

    -- Tabs
    local generalTab = CreateFrame("Frame", "GudaPlatesGeneralTab", optionsFrame)
    generalTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -70)
    generalTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)

    local healthbarTab = CreateFrame("Frame", "GudaPlatesHealthbarTab", optionsFrame)
    healthbarTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -70)
    healthbarTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)
    healthbarTab:Hide()

    local manaTab = CreateFrame("Frame", "GudaPlatesManaTab", optionsFrame)
    manaTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -70)
    manaTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)
    manaTab:Hide()

    local castbarTab = CreateFrame("Frame", "GudaPlatesCastbarTab", optionsFrame)
    castbarTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -70)
    castbarTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)
    castbarTab:Hide()

    local colorsTab = CreateFrame("Frame", "GudaPlatesColorsTab", optionsFrame)
    colorsTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 15, -70)
    colorsTab:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -15, 50)
    colorsTab:Hide()

    local function SelectTab(tabName)
        generalTab:Hide() healthbarTab:Hide() manaTab:Hide() castbarTab:Hide() colorsTab:Hide()
        getglobal("GudaPlatesGeneralTabButtonBg"):SetTexture(1, 1, 1, 0.1)
        getglobal("GudaPlatesHealthbarTabButtonBg"):SetTexture(1, 1, 1, 0.1)
        getglobal("GudaPlatesManaTabButtonBg"):SetTexture(1, 1, 1, 0.1)
        getglobal("GudaPlatesCastbarTabButtonBg"):SetTexture(1, 1, 1, 0.1)
        getglobal("GudaPlatesColorsTabButtonBg"):SetTexture(1, 1, 1, 0.1)
        
        if tabName == "general" then generalTab:Show() getglobal("GudaPlatesGeneralTabButtonBg"):SetTexture(1, 1, 1, 0.3)
        elseif tabName == "healthbar" then healthbarTab:Show() getglobal("GudaPlatesHealthbarTabButtonBg"):SetTexture(1, 1, 1, 0.3)
        elseif tabName == "mana" then manaTab:Show() getglobal("GudaPlatesManaTabButtonBg"):SetTexture(1, 1, 1, 0.3) UpdateManaOptionsState()
        elseif tabName == "castbar" then castbarTab:Show() getglobal("GudaPlatesCastbarTabButtonBg"):SetTexture(1, 1, 1, 0.3)
        elseif tabName == "colors" then colorsTab:Show() getglobal("GudaPlatesColorsTabButtonBg"):SetTexture(1, 1, 1, 0.3) end
    end

    local tabNames = {"General", "Healthbar", "Mana", "Castbar", "Colors"}
    local lastTab = nil
    for i, name in ipairs(tabNames) do
        local n = name
        local btn = CreateFrame("Button", "GudaPlates"..n.."TabButton", optionsFrame)
        btn:SetWidth(110) btn:SetHeight(28)
        if i == 1 then btn:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 20, -42) else btn:SetPoint("LEFT", lastTab, "RIGHT", 2, 0) end
        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
        txt:SetText(n == "Healthbar" and "Health" or n)
        local bg = btn:CreateTexture("GudaPlates"..n.."TabButtonBg", "BACKGROUND")
        bg:SetTexture(1, 1, 1, i == 1 and 0.3 or 0.1)
        bg:SetAllPoints()
        btn:SetScript("OnClick", function() SelectTab(string.lower(n)) end)
        lastTab = btn
    end

    -- General Tab Content
    local overlapCheckbox = CreateFrame("CheckButton", "GudaPlatesOverlapCheckbox", generalTab, "UICheckButtonTemplate")
    overlapCheckbox:SetPoint("TOPLEFT", generalTab, "TOPLEFT", 5, -5)
    getglobal(overlapCheckbox:GetName().."Text"):SetText("Overlap Nameplates (Classic)")
    overlapCheckbox:SetScript("OnClick", function()
        GudaPlates.nameplateOverlap = this:GetChecked() == 1
        SaveSettings()
        for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlateDimensions(plate) end
    end)

    local swapCheckbox = CreateFrame("CheckButton", "GudaPlatesSwapCheckbox", generalTab, "UICheckButtonTemplate")
    swapCheckbox:SetPoint("TOPLEFT", generalTab, "TOPLEFT", 5, -35)
    getglobal(swapCheckbox:GetName().."Text"):SetText("Swap Name/Debuffs (Name above, Debuffs below)")
    swapCheckbox:SetScript("OnClick", function()
        Settings.swapNameDebuff = this:GetChecked() == 1
        SaveSettings()
        for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlateDimensions(plate) end
    end)

    local fontLabel = generalTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", generalTab, "TOPLEFT", 10, -75)
    fontLabel:SetText("Text Font:")
    local fontDropdown = CreateFrame("Frame", "GudaPlatesFontDropdown", generalTab, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "TOPRIGHT", -10, 8)
    local fonts = {
        {text = "Arial (Default)", value = "Fonts\\ARIALN.TTF"},
        {text = "Friz Quadrata", value = "Fonts\\FRIZQT__.TTF"},
        {text = "Morpheus", value = "Fonts\\MORPHEUS.TTF"},
        {text = "Skurri", value = "Fonts\\SKURRI.TTF"},
        {text = "BigNoodle", value = "Interface\\AddOns\\GudaPlates\\fonts\\BigNoodleTitling.ttf"},
        {text = "Continuum", value = "Interface\\AddOns\\GudaPlates\\fonts\\Continuum.ttf"},
        {text = "Expressway", value = "Interface\\AddOns\\GudaPlates\\fonts\\Expressway.ttf"},
        {text = "PT Sans Narrow", value = "Interface\\AddOns\\GudaPlates\\fonts\\PT-Sans-Narrow-Bold.ttf"},
    }
    UIDropDownMenu_Initialize(fontDropdown, function()
        for _, f in ipairs(fonts) do
            local info = {} info.text = f.text info.value = f.value
            info.func = function()
                Settings.textFont = this.value
                UIDropDownMenu_SetSelectedValue(GudaPlatesFontDropdown, this.value)
                SaveSettings()
                for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlateDimensions(plate) end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(150, fontDropdown)

    local function CreateSlider(parent, name, label, min, max, step, yOffset, settingKey, updateFunc)
        local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, yOffset)
        s:SetWidth(600) s:SetMinMaxValues(min, max) s:SetValueStep(step)
        getglobal(name.."Text"):SetText(label .. ": " .. Settings[settingKey])
        getglobal(name.."Low"):SetText(min) getglobal(name.."High"):SetText(max)
        s:SetScript("OnValueChanged", function()
            Settings[settingKey] = this:GetValue()
            getglobal(this:GetName().."Text"):SetText(label .. ": " .. Settings[settingKey])
            SaveSettings()
            if updateFunc then updateFunc() end
        end)
        return s
    end

    local function UpdateAllDimensions() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlateDimensions(plate) end end

    CreateSlider(generalTab, "GudaPlatesNameFontSizeSlider", "Name Font Size", 6, 20, 1, -130, "nameFontSize", UpdateAllDimensions)
    CreateSlider(generalTab, "GudaPlatesLevelFontSizeSlider", "Level Font Size", 6, 20, 1, -170, "levelFontSize", UpdateAllDimensions)

    local debuffTimerCheckbox = CreateFrame("CheckButton", "GudaPlatesDebuffTimerCheckbox", generalTab, "UICheckButtonTemplate")
    debuffTimerCheckbox:SetPoint("TOPLEFT", generalTab, "TOPLEFT", 5, -200)
    getglobal(debuffTimerCheckbox:GetName().."Text"):SetText("Show Debuff Timers")
    debuffTimerCheckbox:SetScript("OnClick", function() Settings.showDebuffTimers = this:GetChecked() == 1 SaveSettings() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlate(plate) end end)

    local onlyMyDebuffsCheckbox = CreateFrame("CheckButton", "GudaPlatesOnlyMyDebuffsCheckbox", generalTab, "UICheckButtonTemplate")
    onlyMyDebuffsCheckbox:SetPoint("TOPLEFT", generalTab, "TOPLEFT", 230, -200)
    getglobal(onlyMyDebuffsCheckbox:GetName().."Text"):SetText("Show Only My Debuffs")
    onlyMyDebuffsCheckbox:SetScript("OnClick", function() Settings.showOnlyMyDebuffs = this:GetChecked() == 1 SaveSettings() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlate(plate) end end)

    local targetGlowCheckbox = CreateFrame("CheckButton", "GudaPlatesTargetGlowCheckbox", generalTab, "UICheckButtonTemplate")
    targetGlowCheckbox:SetPoint("TOPLEFT", generalTab, "TOPLEFT", 5, -230)
    getglobal(targetGlowCheckbox:GetName().."Text"):SetText("Show Target Glow")
    targetGlowCheckbox:SetScript("OnClick", function() Settings.showTargetGlow = this:GetChecked() == 1 SaveSettings() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlate(plate) end end)

    -- Health Tab Content
    local enemyHeader = healthbarTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enemyHeader:SetPoint("TOPLEFT", healthbarTab, "TOPLEFT", 5, -5)
    enemyHeader:SetText("|cffff0000Enemy Nameplates:|r")
    CreateSlider(healthbarTab, "GudaPlatesHeightSlider", "Enemy Height", 6, 25, 1, -35, "healthbarHeight", UpdateAllDimensions)
    CreateSlider(healthbarTab, "GudaPlatesWidthSlider", "Enemy Width", 72, 150, 1, -75, "healthbarWidth", UpdateAllDimensions)
    CreateSlider(healthbarTab, "GudaPlatesHealthFontSlider", "Enemy Health Font Size", 6, 20, 1, -115, "healthFontSize", UpdateAllDimensions)

    local friendlyHeader = healthbarTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    friendlyHeader:SetPoint("TOPLEFT", healthbarTab, "TOPLEFT", 5, -160)
    friendlyHeader:SetText("|cff00ff00Friendly Nameplates:|r")
    CreateSlider(healthbarTab, "GudaPlatesFriendlyHeightSlider", "Friendly Height", 2, 20, 1, -190, "friendlyHealthbarHeight", UpdateAllDimensions)
    CreateSlider(healthbarTab, "GudaPlatesFriendlyWidthSlider", "Friendly Width", 50, 150, 1, -230, "friendlyHealthbarWidth", UpdateAllDimensions)
    CreateSlider(healthbarTab, "GudaPlatesFriendlyHealthFontSlider", "Friendly Health Font Size", 4, 16, 1, -270, "friendlyHealthFontSize", UpdateAllDimensions)

    local showFriendlyNPCsCheckbox = CreateFrame("CheckButton", "GudaPlatesShowFriendlyNPCsCheckbox", healthbarTab, "UICheckButtonTemplate")
    showFriendlyNPCsCheckbox:SetPoint("TOPLEFT", healthbarTab, "TOPLEFT", 5, -295)
    getglobal(showFriendlyNPCsCheckbox:GetName().."Text"):SetText("Show Friendly Nameplates")
    showFriendlyNPCsCheckbox:SetScript("OnClick", function() Settings.showFriendlyNPCs = this:GetChecked() == 1 SaveSettings() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlate(plate) end end)

    local otherHealthHeader = healthbarTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    otherHealthHeader:SetPoint("TOPLEFT", healthbarTab, "TOPLEFT", 5, -330)
    otherHealthHeader:SetText("|cff00ffffOther Health Settings:|r")
    local showHealthTextCheckbox = CreateFrame("CheckButton", "GudaPlatesShowHealthTextCheckbox", healthbarTab, "UICheckButtonTemplate")
    showHealthTextCheckbox:SetPoint("TOPLEFT", healthbarTab, "TOPLEFT", 5, -355)
    getglobal(showHealthTextCheckbox:GetName().."Text"):SetText("Show Health Points")
    showHealthTextCheckbox:SetScript("OnClick", function() Settings.showHealthText = this:GetChecked() == 1 SaveSettings() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlate(plate) end end)

    -- Health Text Position and Format Dropdowns
    local hpPosLabel = healthbarTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hpPosLabel:SetPoint("TOPLEFT", healthbarTab, "TOPLEFT", 5, -375)
    hpPosLabel:SetText("Health Text Position:")
    local hpPosDropdown = CreateFrame("Frame", "GudaPlatesHealthPosDropdown", healthbarTab, "UIDropDownMenuTemplate")
    hpPosDropdown:SetPoint("TOPLEFT", hpPosLabel, "TOPRIGHT", -10, 8)
    UIDropDownMenu_Initialize(hpPosDropdown, function()
        for _, pos in ipairs({"LEFT", "CENTER", "RIGHT"}) do
            local p = pos
            local info = {text = p, value = p, func = function()
                Settings.healthTextPosition = this.value
                UIDropDownMenu_SetSelectedValue(GudaPlatesHealthPosDropdown, this.value)
                SaveSettings() UpdateAllDimensions()
            end}
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(100, hpPosDropdown)

    local hpFormatLabel = healthbarTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hpFormatLabel:SetPoint("TOPLEFT", healthbarTab, "TOPLEFT", 5, -410)
    hpFormatLabel:SetText("Health Text Format:")
    local hpFormatDropdown = CreateFrame("Frame", "GudaPlatesHealthFormatDropdown", healthbarTab, "UIDropDownMenuTemplate")
    hpFormatDropdown:SetPoint("TOPLEFT", hpFormatLabel, "TOPRIGHT", -10, 8)
    local hpFormats = {{v=1, t="Percent"}, {v=2, t="Current HP"}, {v=3, t="HP (Percent%)"}, {v=4, t="Current - Max"}, {v=5, t="Current - Max (%)"}}
    UIDropDownMenu_Initialize(hpFormatDropdown, function()
        for _, f in ipairs(hpFormats) do
            local formatData = f
            local info = {text = formatData.t, value = formatData.v, func = function()
                Settings.healthTextFormat = this.value
                UIDropDownMenu_SetSelectedValue(GudaPlatesHealthFormatDropdown, this.value)
                SaveSettings() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlate(plate) end
            end}
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(150, hpFormatDropdown)

    -- Mana Tab Content
    local manaHeader = manaTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    manaHeader:SetPoint("TOPLEFT", manaTab, "TOPLEFT", 5, -5)
    manaHeader:SetText("|cff00ffffMana Bar Settings:|r")
    local manaBarCheckbox = CreateFrame("CheckButton", "GudaPlatesManaBarCheckbox", manaTab, "UICheckButtonTemplate")
    manaBarCheckbox:SetPoint("TOPLEFT", manaTab, "TOPLEFT", 5, -30)
    getglobal(manaBarCheckbox:GetName().."Text"):SetText("Show Mana Bar")
    manaBarCheckbox:SetScript("OnClick", function() Settings.showManaBar = this:GetChecked() == 1 UpdateManaOptionsState() SaveSettings() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlate(plate) end end)
    local showManaTextCheckbox = CreateFrame("CheckButton", "GudaPlatesShowManaTextCheckbox", manaTab, "UICheckButtonTemplate")
    showManaTextCheckbox:SetPoint("TOPLEFT", manaTab, "TOPLEFT", 200, -30)
    getglobal(showManaTextCheckbox:GetName().."Text"):SetText("Show Mana Points")
    showManaTextCheckbox:SetScript("OnClick", function() Settings.showManaText = this:GetChecked() == 1 SaveSettings() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlate(plate) end end)
    CreateSlider(manaTab, "GudaPlatesManaHeightSlider", "Manabar Height", 2, 10, 1, -75, "manabarHeight", UpdateAllDimensions)

    local manaPosLabel = manaTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    manaPosLabel:SetPoint("TOPLEFT", manaTab, "TOPLEFT", 5, -115)
    manaPosLabel:SetText("Mana Text Position:")
    local manaPosDropdown = CreateFrame("Frame", "GudaPlatesManaPosDropdown", manaTab, "UIDropDownMenuTemplate")
    manaPosDropdown:SetPoint("TOPLEFT", manaPosLabel, "TOPRIGHT", -10, 8)
    UIDropDownMenu_Initialize(manaPosDropdown, function()
        for _, pos in ipairs({"LEFT", "CENTER", "RIGHT"}) do
            local p = pos
            local info = {text = p, value = p, func = function()
                Settings.manaTextPosition = this.value
                UIDropDownMenu_SetSelectedValue(GudaPlatesManaPosDropdown, this.value)
                SaveSettings() UpdateAllDimensions()
            end}
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(80, manaPosDropdown)

    local manaFormatLabel = manaTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    manaFormatLabel:SetPoint("TOPLEFT", manaTab, "TOPLEFT", 5, -150)
    manaFormatLabel:SetText("Mana Text Format:")
    local manaFormatDropdown = CreateFrame("Frame", "GudaPlatesManaFormatDropdown", manaTab, "UIDropDownMenuTemplate")
    manaFormatDropdown:SetPoint("TOPLEFT", manaFormatLabel, "TOPRIGHT", -10, 8)
    local manaFormats = {{v=1, t="Percent"}, {v=2, t="Current Mana"}, {v=3, t="Mana (Percent%)"}}
    UIDropDownMenu_Initialize(manaFormatDropdown, function()
        for _, f in ipairs(manaFormats) do
            local formatData = f
            local info = {text = formatData.t, value = formatData.v, func = function()
                Settings.manaTextFormat = this.value
                UIDropDownMenu_SetSelectedValue(GudaPlatesManaFormatDropdown, this.value)
                SaveSettings() for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlate(plate) end
            end}
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetWidth(150, manaFormatDropdown)

    -- Castbar Tab Content
    local castbarHeader = castbarTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    castbarHeader:SetPoint("TOPLEFT", castbarTab, "TOPLEFT", 5, -5)
    castbarHeader:SetText("|cffffff00Castbar Settings:|r")
    local castIconCheckbox = CreateFrame("CheckButton", "GudaPlatesCastbarIconCheckbox", castbarTab, "UICheckButtonTemplate")
    castIconCheckbox:SetPoint("TOPLEFT", castbarTab, "TOPLEFT", 5, -30)
    getglobal(castIconCheckbox:GetName().."Text"):SetText("Show Castbar Icon")
    castIconCheckbox:SetScript("OnClick", function() Settings.showCastbarIcon = this:GetChecked() == 1 SaveSettings() end)
    CreateSlider(castbarTab, "GudaPlatesCastbarHeightSlider", "Castbar Height", 6, 20, 1, -60, "castbarHeight", UpdateAllDimensions)
    local castIndependentCheckbox = CreateFrame("CheckButton", "GudaPlatesCastbarIndependentCheckbox", castbarTab, "UICheckButtonTemplate")
    castIndependentCheckbox:SetPoint("TOPLEFT", castbarTab, "TOPLEFT", 5, -100)
    getglobal(castIndependentCheckbox:GetName().."Text"):SetText("Independent Width from Healthbar")
    CreateSlider(castbarTab, "GudaPlatesCastbarWidthSlider", "Castbar Width", 72, 200, 1, -150, "castbarWidth", UpdateAllDimensions)
    castIndependentCheckbox:SetScript("OnClick", function() Settings.castbarIndependent = this:GetChecked() == 1 UpdateCastbarWidthSliderState() SaveSettings() UpdateAllDimensions() end)

    -- Colors Tab Content
    local tankCheckbox = CreateFrame("CheckButton", "GudaPlatesTankCheckbox", colorsTab, "UICheckButtonTemplate")
    tankCheckbox:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 5, -10)
    getglobal(tankCheckbox:GetName().."Text"):SetText("Tank Mode")
    tankCheckbox:SetScript("OnClick", function() GudaPlates.playerRole = this:GetChecked() == 1 and "TANK" or "DPS" SaveSettings() Print("Role set to " .. GudaPlates.playerRole) end)

    local dpsHeader = colorsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dpsHeader:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 5, -50)
    dpsHeader:SetText("|cff00ff00DPS/Healer Colors:|r")
    CreateColorSwatch(colorsTab, 5, -75, "Aggro (Bad)", THREAT_COLORS.DPS, "AGGRO")
    CreateColorSwatch(colorsTab, 5, -100, "High Threat (Warning)", THREAT_COLORS.DPS, "HIGH_THREAT")
    CreateColorSwatch(colorsTab, 5, -125, "No Aggro (Good)", THREAT_COLORS.DPS, "NO_AGGRO")

    local tankHeader = colorsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tankHeader:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 5, -155)
    tankHeader:SetText("|cff00ffffTank Colors:|r")
    CreateColorSwatch(colorsTab, 5, -180, "Aggro (Good)", THREAT_COLORS.TANK, "AGGRO")
    CreateColorSwatch(colorsTab, 5, -205, "Losing Aggro (Warning)", THREAT_COLORS.TANK, "LOSING_AGGRO")
    CreateColorSwatch(colorsTab, 5, -230, "No Aggro (Bad)", THREAT_COLORS.TANK, "NO_AGGRO")
    CreateColorSwatch(colorsTab, 5, -255, "Other Tank has Aggro", THREAT_COLORS.TANK, "OTHER_TANK")

    local textColorsHeader = colorsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    textColorsHeader:SetPoint("TOPLEFT", colorsTab, "TOPLEFT", 235, -50)
    textColorsHeader:SetText("|cffffff00Text Colors:|r")
    CreateColorSwatch(colorsTab, 235, -75, "Name Text", Settings, "nameColor")
    CreateColorSwatch(colorsTab, 235, -100, "Level Text", Settings, "levelColor")
    CreateColorSwatch(colorsTab, 235, -125, "Health Text", Settings, "healthTextColor")
    CreateColorSwatch(colorsTab, 235, -150, "Mana Text", Settings, "manaTextColor")

    CreateColorSwatch(colorsTab, 235, -180, "Tapped Color", THREAT_COLORS, "TAPPED")
    CreateColorSwatch(colorsTab, 235, -205, "Mana Bar Color", THREAT_COLORS, "MANA_BAR")
    CreateColorSwatch(colorsTab, 235, -230, "Castbar Color", Settings, "castbarColor")
    CreateColorSwatch(colorsTab, 235, -255, "Target Glow", Settings, "targetGlowColor")

    optionsFrame:SetScript("OnShow", function()
        getglobal("GudaPlatesOverlapCheckbox"):SetChecked(GudaPlates.nameplateOverlap)
        getglobal("GudaPlatesSwapCheckbox"):SetChecked(Settings.swapNameDebuff)
        UIDropDownMenu_SetSelectedValue(GudaPlatesFontDropdown, Settings.textFont)
        getglobal("GudaPlatesHeightSlider"):SetValue(Settings.healthbarHeight)
        getglobal("GudaPlatesWidthSlider"):SetValue(Settings.healthbarWidth)
        getglobal("GudaPlatesHealthFontSlider"):SetValue(Settings.healthFontSize)
        getglobal("GudaPlatesFriendlyHeightSlider"):SetValue(Settings.friendlyHealthbarHeight)
        getglobal("GudaPlatesFriendlyWidthSlider"):SetValue(Settings.friendlyHealthbarWidth)
        getglobal("GudaPlatesFriendlyHealthFontSlider"):SetValue(Settings.friendlyHealthFontSize)
        getglobal("GudaPlatesShowFriendlyNPCsCheckbox"):SetChecked(Settings.showFriendlyNPCs)
        getglobal("GudaPlatesShowHealthTextCheckbox"):SetChecked(Settings.showHealthText)
        UIDropDownMenu_SetSelectedValue(GudaPlatesHealthPosDropdown, Settings.healthTextPosition)
        UIDropDownMenu_SetSelectedValue(GudaPlatesHealthFormatDropdown, Settings.healthTextFormat)
        getglobal("GudaPlatesManaBarCheckbox"):SetChecked(Settings.showManaBar)
        getglobal("GudaPlatesShowManaTextCheckbox"):SetChecked(Settings.showManaText)
        UIDropDownMenu_SetSelectedValue(GudaPlatesManaFormatDropdown, Settings.manaTextFormat)
        UIDropDownMenu_SetSelectedValue(GudaPlatesManaPosDropdown, Settings.manaTextPosition)
        getglobal("GudaPlatesManaHeightSlider"):SetValue(Settings.manabarHeight)
        UpdateManaOptionsState()
        getglobal("GudaPlatesCastbarIconCheckbox"):SetChecked(Settings.showCastbarIcon)
        getglobal("GudaPlatesCastbarHeightSlider"):SetValue(Settings.castbarHeight)
        getglobal("GudaPlatesCastbarIndependentCheckbox"):SetChecked(Settings.castbarIndependent)
        getglobal("GudaPlatesCastbarWidthSlider"):SetValue(Settings.castbarWidth)
        UpdateCastbarWidthSliderState()
        getglobal("GudaPlatesTankCheckbox"):SetChecked(GudaPlates.playerRole == "TANK")
        for _, f in ipairs(swatches) do f() end
    end)

    local resetButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    resetButton:SetWidth(120) resetButton:SetHeight(25) resetButton:SetPoint("BOTTOM", optionsFrame, "BOTTOM", 0, 15)
    resetButton:SetText("Reset Defaults")
    resetButton:SetScript("OnClick", function()
        GudaPlates.playerRole = "DPS"
        THREAT_COLORS.DPS.AGGRO = {0.8, 0.2, 0.2, 1}
        THREAT_COLORS.DPS.HIGH_THREAT = {1.0, 0.6, 0.0, 1}
        THREAT_COLORS.DPS.NO_AGGRO = {0.2, 0.8, 0.2, 1}
        THREAT_COLORS.TANK.AGGRO = {0.2, 0.8, 0.2, 1}
        THREAT_COLORS.TANK.OTHER_TANK = {0.4, 0.4, 1, 1}
        THREAT_COLORS.TANK.LOSING_AGGRO = {1.0, 0.6, 0.0, 1}
        THREAT_COLORS.TANK.NO_AGGRO = {0.8, 0.2, 0.2, 1}
        THREAT_COLORS.TAPPED = {0.5, 0.5, 0.5, 1}
        THREAT_COLORS.MANA_BAR = {0.3, 0.4, 0.9, 1}
        Settings.healthbarHeight = 14 Settings.healthbarWidth = 115 Settings.healthFontSize = 10
        Settings.friendlyHealthbarHeight = 4 Settings.friendlyHealthbarWidth = 85 Settings.friendlyHealthFontSize = 6
        Settings.showFriendlyNPCs = true Settings.showHealthText = true Settings.healthTextPosition = "CENTER" Settings.healthTextFormat = 1
        Settings.showManaBar = false Settings.showManaText = true Settings.manaTextFormat = 1 Settings.manaTextPosition = "CENTER" Settings.manabarHeight = 4
        Settings.levelFontSize = 10 Settings.nameFontSize = 10 Settings.textFont = "Fonts\\ARIALN.TTF"
        Settings.castbarHeight = 12 Settings.castbarWidth = 115 Settings.castbarIndependent = false Settings.showCastbarIcon = true Settings.castbarColor = {1, 0.8, 0, 1}
        Settings.raidIconPosition = "LEFT" Settings.swapNameDebuff = true Settings.showDebuffTimers = true Settings.showOnlyMyDebuffs = true
        Settings.showTargetGlow = true Settings.targetGlowColor = {0.4, 0.8, 0.9, 0.4}
        Settings.nameColor = {1, 1, 1, 1} Settings.healthTextColor = {1, 1, 1, 1} Settings.manaTextColor = {1, 1, 1, 1} Settings.levelColor = {1, 1, 1, 1}
        SaveSettings() Print("Settings reset to defaults.")
        GudaPlatesOptionsFrame:Hide() GudaPlatesOptionsFrame:Show()
        for plate, _ in pairs(GudaPlates.registry) do GudaPlates.UpdateNamePlateDimensions(plate) GudaPlates.UpdateNamePlate(plate) end
    end)
end

GudaPlates.Print("Options Module Loaded")
