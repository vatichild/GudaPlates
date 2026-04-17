-- GudaPlates_Marks.lua
-- Client-side target marking for solo players (no party required)
-- Marks are stored by GUID and displayed on nameplates + target frame

GudaPlates_Marks = {}
local Marks = GudaPlates_Marks

-- Local references (UnitGUID NOT cached - it may not exist at load time in TurtleWoW)
local UnitExists = UnitExists
local UnitName = UnitName
local UnitIsPlayer = UnitIsPlayer
local GetRaidTargetIndex = GetRaidTargetIndex
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers

-- Marks storage: guid -> iconIndex (1-8)
local marks = {}
-- Raid icon texture path
local RAID_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local ICON_NAMES = {
    [1] = "Star", [2] = "Circle", [3] = "Diamond", [4] = "Triangle",
    [5] = "Moon", [6] = "Square", [7] = "Cross", [8] = "Skull",
}

local ICON_COLORED = {
    [1] = "|cffFFFF00Star|r",
    [2] = "|cffFF8000Circle|r",
    [3] = "|cffFF00FFDiamond|r",
    [4] = "|cff00FF00Triangle|r",
    [5] = "|cffC0C0FFMoon|r",
    [6] = "|cff0070FFSquare|r",
    [7] = "|cffFF0000Cross|r",
    [8] = "|cffFFFFFFSkull|r",
}

-- ============================================
-- Apply raid icon texture
-- ============================================

-- Atlas is a 4x4 grid (256x256), icons in first 2 rows
-- Matches vanilla WoW's SetRaidTargetIconTexture formula exactly:
--   left  = mod(index-1, 4) * 0.25
--   right = left + 0.25
--   top   = floor((index-1) / 4) * 0.25
--   bot   = top + 0.25
local function ApplyRaidIcon(texture, index)
    if not texture or not index or index < 1 or index > 8 then return end
    texture:SetTexture(RAID_ICON_TEXTURE)
    -- Use SetRaidTargetIconTexture if available (proven to work in ShaguTweaks/pfUI)
    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(texture, index)
    else
        -- Manual fallback: 4x4 grid, 0.25 increments
        local idx = index - 1
        local col = idx - math.floor(idx / 4) * 4  -- safe mod without mod()
        local row = math.floor(idx / 4)
        texture:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
    end
end

-- ============================================
-- Core API
-- ============================================

function Marks.GetMark(guid)
    if not guid then return nil end
    return marks[guid]
end

function Marks.SetMark(guid, iconIndex)
    if not guid then return end
    if iconIndex and iconIndex >= 1 and iconIndex <= 8 then
        marks[guid] = iconIndex
    else
        marks[guid] = nil
    end
end

function Marks.ClearAllMarks()
    for k in pairs(marks) do
        marks[k] = nil
    end
end

-- Get a unique GUID for a unit token, using best available method
local function GetBestGUID(unitToken)
    -- Try SuperWoW's UnitGUID
    -- UnitGUID returns (hi, lo) pair from our DLL or SuperWoW
    if UnitGUID then
        local hi, lo = UnitGUID(unitToken)
        if hi and lo and (hi ~= 0 or lo ~= 0) then
            return string.format("0x%08X%08X", hi, lo)
        end
        -- SuperWoW might return a single value (string or number)
        if hi and not lo then return tostring(hi) end
    end
    -- Try GudaIO_UnitGUID as fallback
    if GudaIO_UnitGUID then
        local hi, lo = GudaIO_UnitGUID(unitToken)
        if hi and lo and (hi ~= 0 or lo ~= 0) then
            return string.format("0x%08X%08X", hi, lo)
        end
    end
    -- Fallback to name-based (same-name units will share marks)
    local name = UnitName(unitToken)
    if name then return "name:" .. name end
    return nil
end

-- ============================================
-- Target Frame Overlay
-- ============================================

local targetIconFrame = nil
local targetIconTexture = nil

local function CreateTargetFrameIcon()
    if targetIconFrame then return end
    -- Parent to TargetFrame directly so it moves/shows with it
    targetIconFrame = CreateFrame("Frame", "GudaPlatesTargetMarkFrame", TargetFrame)
    targetIconFrame:SetFrameLevel(TargetFrame:GetFrameLevel() + 10)
    targetIconFrame:SetWidth(24)
    targetIconFrame:SetHeight(24)
    targetIconFrame:Hide()

    targetIconTexture = targetIconFrame:CreateTexture(nil, "OVERLAY")
    targetIconTexture:SetAllPoints(targetIconFrame)
    targetIconTexture:SetAlpha(1)
end

local function UpdateTargetFrameIcon()
    if not targetIconFrame then
        CreateTargetFrameIcon()
    end

    -- If DLL is active or server-side mark exists, Blizzard's own icon handles it
    if GetRaidTargetIndex and GetRaidTargetIndex("target") then
        targetIconFrame:Hide()
        return
    end

    -- DLL active: Blizzard's built-in target frame icon shows automatically
    if GudaIO_SetRaidTarget then
        targetIconFrame:Hide()
        return
    end

    if not UnitExists("target") then
        targetIconFrame:Hide()
        return
    end

    -- No DLL: show our custom icon (fallback)
    local guid = GetBestGUID("target")
    local iconIndex = guid and marks[guid]

    if iconIndex then
        ApplyRaidIcon(targetIconTexture, iconIndex)
        targetIconFrame:ClearAllPoints()
        targetIconFrame:SetPoint("CENTER", TargetFrame, "CENTER", 68, 17)
        targetIconFrame:Show()
    else
        targetIconFrame:Hide()
    end
end

Marks.UpdateTargetFrameIcon = UpdateTargetFrameIcon

-- ============================================
-- Nameplate Integration
-- ============================================

local function CreateNameplateMarkIcon(nameplate)
    if nameplate.localMarkTexture then return end
    local iconFrame = CreateFrame("Frame", nil, nameplate.health)
    iconFrame:SetWidth(24)
    iconFrame:SetHeight(24)
    iconFrame:SetFrameLevel(nameplate.health:GetFrameLevel() + 5)
    iconFrame:Hide()

    local tex = iconFrame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(iconFrame)
    tex:SetDrawLayer("ARTWORK")
    tex:SetAlpha(1)

    nameplate.localMarkFrame = iconFrame
    nameplate.localMarkTexture = tex
end

-- Called from UpdateNamePlate in GudaPlates.lua
function Marks.UpdateNameplateIcon(nameplate, frame, unitstr)
    if not nameplate.health then return end

    local iconIndex = nil

    -- 1. Targeted nameplate: DLL precise lookup
    if GudaIO_GetRaidTarget and frame and frame.GetAlpha and frame:GetAlpha() > 0.9 then
        local idx = GudaIO_GetRaidTarget("target")
        if idx and idx > 0 then
            iconIndex = idx
        end
    end

    -- 2. All nameplates: GUID-based lookup
    if not iconIndex and UnitGUID then
        local us = unitstr
        if (not us or us == "") and frame and frame.GetName then
            us = frame:GetName(1)
        end
        if us and us ~= "" then
            local hi, lo = UnitGUID(us)
            if hi and lo and (hi ~= 0 or lo ~= 0) then
                local guid = string.format("0x%08X%08X", hi, lo)
                iconIndex = marks[guid]
            elseif hi and not lo then
                iconIndex = marks[tostring(hi)]
            end
        end
    end

    -- 3. Last resort (no SuperWoW, no DLL): name-based
    if not iconIndex and not UnitGUID and not GudaIO_SetRaidTarget then
        local name = nil
        if nameplate.original and nameplate.original.name and nameplate.original.name.GetText then
            name = nameplate.original.name:GetText()
        end
        if name then
            iconIndex = marks["name:" .. name]
        end
    end

    -- Show addon mark or restore Blizzard raidicon
    if iconIndex then
        if not nameplate.localMarkTexture then
            CreateNameplateMarkIcon(nameplate)
        end

        local iconFrame = nameplate.localMarkFrame
        local tex = nameplate.localMarkTexture
        if nameplate.localMarkIndex ~= iconIndex then
            ApplyRaidIcon(tex, iconIndex)
            nameplate.localMarkIndex = iconIndex

            local Settings = GudaPlates and GudaPlates.Settings
            iconFrame:ClearAllPoints()
            if Settings and Settings.raidIconPosition == "RIGHT" then
                iconFrame:SetPoint("LEFT", nameplate.health, "RIGHT", 5, 0)
            else
                iconFrame:SetPoint("RIGHT", nameplate.health, "LEFT", -5, 0)
            end
        end
        iconFrame:Show()
        -- Hide Blizzard's raidicon to prevent double icon
        if nameplate.original and nameplate.original.raidicon then
            nameplate.original.raidicon:Hide()
        end
    else
        -- No addon mark: hide ours, let Blizzard handle its own raidicon
        if nameplate.localMarkFrame then
            nameplate.localMarkFrame:Hide()
            nameplate.localMarkIndex = nil
        end
    end
end

-- ============================================
-- Keybind + Slash Command Handler
-- ============================================

-- Set 3D raid icon via GudaIO DLL (if available and solo)
local function Apply3DRaidIcon(iconIndex)
    if not GudaIO_SetRaidTarget then return end
    local inGroup = (GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)
    if inGroup then return end
    GudaIO_SetRaidTarget("target", iconIndex)
end

function GudaPlates_Marks_SetMarkOnTarget(iconIndex)
    if not UnitExists("target") then return end

    local guid = GetBestGUID("target")
    if not guid then return end
    local targetName = UnitName("target")

    -- Clear any other unit using the same icon (one mob per icon, like Blizzard)
    if iconIndex >= 1 and iconIndex <= 8 then
        for k, v in pairs(marks) do
            if v == iconIndex and k ~= guid then
                marks[k] = nil
            end
        end
    end

    if (iconIndex >= 1 and iconIndex <= 8 and marks[guid] == iconIndex) or iconIndex == 0 then
        -- Clear (toggle off same icon, or explicit clear)
        marks[guid] = nil
        Apply3DRaidIcon(0)
        if GudaPlates and GudaPlates.Print then
            GudaPlates.Print("Mark cleared from " .. (targetName or "target"))
        end
    else
        -- Set
        marks[guid] = iconIndex
        Apply3DRaidIcon(iconIndex)
        local iconName = ICON_NAMES[iconIndex] or tostring(iconIndex)
        if GudaPlates and GudaPlates.Print then
            GudaPlates.Print(iconName .. " mark set on " .. (targetName or "target"))
        end
    end

    UpdateTargetFrameIcon()
end

-- ============================================
-- Right-Click Marks Dropdown (for NPC targets + submenu)
-- ============================================

local markDropdown = CreateFrame("Frame", "GudaPlatesMarkDropdown", UIParent, "UIDropDownMenuTemplate")

-- Icon texcoords for the 4x4 atlas (used for dropdown icon display)
local function GetIconTexCoords(index)
    local idx = index - 1
    local col = idx - math.floor(idx / 4) * 4
    local row = math.floor(idx / 4)
    return col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25
end

-- Get current mark on target
local function GetCurrentMark()
    if not UnitExists("target") then return nil end
    local guid = GetBestGUID("target")
    if guid then return marks[guid] end
    return nil
end

-- Shared delay frame for mark callbacks (avoids creating new frames per click)
local markDelayFrame = CreateFrame("Frame")
markDelayFrame:Hide()
local pendingMarkIndex = nil

markDelayFrame:SetScript("OnUpdate", function()
    if pendingMarkIndex then
        GudaPlates_Marks_SetMarkOnTarget(pendingMarkIndex)
        pendingMarkIndex = nil
    end
    this:Hide()
end)

-- Close all menus then apply mark on next frame
local function MakeMarkCallbackWithClose(index)
    return function()
        if CloseDropDownMenus then
            CloseDropDownMenus()
        elseif HideDropDownMenu then
            HideDropDownMenu(1)
            HideDropDownMenu(2)
        end
        pendingMarkIndex = index
        markDelayFrame:Show()
    end
end

local markCloseCallbacks = {}
for i = 0, 8 do
    markCloseCallbacks[i] = MakeMarkCallbackWithClose(i)
end

-- Add the 8 icon items + None to a dropdown level
local function AddMarkButtons(level)
    local currentMark = GetCurrentMark()

    for i = 1, 8 do
        local info = {}
        info.text = ICON_COLORED[i]
        info.icon = RAID_ICON_TEXTURE
        local l, r, t, b = GetIconTexCoords(i)
        info.tCoordLeft = l
        info.tCoordRight = r
        info.tCoordTop = t
        info.tCoordBottom = b
        info.func = markCloseCallbacks[i]
        info.checked = (currentMark == i)
        UIDropDownMenu_AddButton(info, level)
    end

    -- None option (with checkbox space for alignment, never checked)
    local info = {}
    info.text = "None"
    info.func = markCloseCallbacks[0]
    info.checked = nil
    UIDropDownMenu_AddButton(info, level)
end

local function MarkDropdown_Initialize(level)
    level = level or 1
    if level == 1 then
        -- For NPC right-click (solo): show "Target Icon" with arrow to submenu
        local info = {}
        info.text = "Target Icon"
        info.hasArrow = 1
        info.notCheckable = 1
        info.value = "GUDAPLATES_MARKS"
        UIDropDownMenu_AddButton(info, level)
    elseif level == 2 then
        if UIDROPDOWNMENU_MENU_VALUE == "GUDAPLATES_MARKS" then
            AddMarkButtons(level)
        end
    end
end

UIDropDownMenu_Initialize(markDropdown, MarkDropdown_Initialize, "MENU")

-- ============================================
-- Inject into UnitPopup (for player targets)
-- ============================================

local function SetupUnitPopup()
    if not UnitPopupButtons or not UnitPopupMenus then return end

    -- Check if Blizzard's RAID_TARGET_ICON already exists (patch 1.11+)
    local useBlizzardRaidTarget = UnitPopupButtons["RAID_TARGET_ICON"] ~= nil

    if useBlizzardRaidTarget then
        -- Blizzard's raid target submenu exists - just add it to menus that don't have it
        local menuTypes = {"FRIEND", "SELF"}
        for _, menuType in ipairs(menuTypes) do
            if UnitPopupMenus[menuType] then
                -- Check if already present
                local found = false
                local buttons = UnitPopupMenus[menuType]
                for i = 1, table.getn(buttons) do
                    if buttons[i] == "RAID_TARGET_ICON" then
                        found = true
                        break
                    end
                end
                if not found then
                    for i = 1, table.getn(buttons) do
                        if buttons[i] == "CANCEL" then
                            table.insert(buttons, i, "RAID_TARGET_ICON")
                            break
                        end
                    end
                end
            end
        end

        -- Hook UnitPopup_HideButtons to keep raid target visible when solo
        if UnitPopup_HideButtons then
            local orig_UnitPopup_HideButtons = UnitPopup_HideButtons
            UnitPopup_HideButtons = function()
                orig_UnitPopup_HideButtons()
                local inGroup = (GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)
                if not inGroup then
                    for i = 1, UIDROPDOWNMENU_MAXBUTTONS do
                        local btn = getglobal("DropDownList1Button" .. i)
                        if btn and btn.value == "RAID_TARGET_ICON" then
                            btn:Show()
                            break
                        end
                    end
                end
            end
        end
    else
        -- Blizzard raid target buttons don't exist - use our own with nested submenu
        UnitPopupButtons["GUDAPLATES_RAID_TARGET"] = { text = "Raid Target Icon", nested = 1, dist = 0 }

        for i = 1, 8 do
            UnitPopupButtons["GUDAPLATES_MARK_" .. i] = { text = ICON_COLORED[i], dist = 0 }
        end
        UnitPopupButtons["GUDAPLATES_MARK_NONE"] = { text = "None", dist = 0 }

        UnitPopupMenus["GUDAPLATES_RAID_TARGET"] = {
            "GUDAPLATES_MARK_1", "GUDAPLATES_MARK_2", "GUDAPLATES_MARK_3", "GUDAPLATES_MARK_4",
            "GUDAPLATES_MARK_5", "GUDAPLATES_MARK_6", "GUDAPLATES_MARK_7", "GUDAPLATES_MARK_8",
            "GUDAPLATES_MARK_NONE",
        }

        local menuTypes = {"FRIEND", "ENEMY", "PARTY", "PLAYER", "SELF", "RAID_PLAYER", "RAID"}
        for _, menuType in ipairs(menuTypes) do
            if UnitPopupMenus[menuType] then
                local buttons = UnitPopupMenus[menuType]
                for i = 1, table.getn(buttons) do
                    if buttons[i] == "CANCEL" then
                        table.insert(buttons, i, "GUDAPLATES_RAID_TARGET")
                        break
                    end
                end
            end
        end
    end

    -- ==========================================
    -- "Mark as Tank" button for player targets
    -- ==========================================
    UnitPopupButtons["GUDAPLATES_TANK"] = { text = "Mark as Tank", dist = 0 }

    local tankMenuTypes = {"PARTY", "RAID_PLAYER", "RAID", "FRIEND"}
    for _, menuType in ipairs(tankMenuTypes) do
        if UnitPopupMenus[menuType] then
            local buttons = UnitPopupMenus[menuType]
            for i = 1, table.getn(buttons) do
                if buttons[i] == "CANCEL" then
                    table.insert(buttons, i, "GUDAPLATES_TANK")
                    break
                end
            end
        end
    end

    -- ==========================================
    -- Single consolidated UnitPopup_OnClick hook
    -- Handles: RAID_TARGET_*, GUDAPLATES_MARK_*, GUDAPLATES_TANK
    -- ==========================================
    if UnitPopup_OnClick then
        local orig_UnitPopup_OnClick = UnitPopup_OnClick
        UnitPopup_OnClick = function()
            local button = this.value

            -- Blizzard RAID_TARGET buttons (solo intercept)
            if button and string.find(button, "^RAID_TARGET_") then
                local inGroup = (GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)
                if not inGroup then
                    if button == "RAID_TARGET_NONE" then
                        GudaPlates_Marks_SetMarkOnTarget(0)
                    else
                        local idx = tonumber(string.sub(button, 13))
                        if idx and idx >= 1 and idx <= 8 then
                            GudaPlates_Marks_SetMarkOnTarget(idx)
                        end
                    end
                end
                return orig_UnitPopup_OnClick()
            end

            -- Custom GUDAPLATES_MARK buttons
            if button and string.find(button, "^GUDAPLATES_MARK_") then
                if button == "GUDAPLATES_MARK_NONE" then
                    GudaPlates_Marks_SetMarkOnTarget(0)
                else
                    local idx = tonumber(string.sub(button, 17))
                    if idx and idx >= 1 and idx <= 8 then
                        GudaPlates_Marks_SetMarkOnTarget(idx)
                    end
                end
                return orig_UnitPopup_OnClick()
            end

            -- Tank toggle
            if button == "GUDAPLATES_TANK" then
                local dropdownFrame = getglobal(UIDROPDOWNMENU_INIT_MENU)
                local name = dropdownFrame and dropdownFrame.name
                if name and GudaPlates_Threat and GudaPlates_Threat.SetPlayerTank then
                    local isTank = GudaPlates_Threat.IsPlayerTank(name)
                    GudaPlates_Threat.SetPlayerTank(name, not isTank)
                    if Marks.UpdateTankShieldIcons then
                        Marks.UpdateTankShieldIcons()
                    end
                    if GudaPlates and GudaPlates.Print then
                        if not isTank then
                            GudaPlates.Print(name .. " marked as tank")
                        else
                            GudaPlates.Print(name .. " unmarked as tank")
                        end
                    end
                end
                return orig_UnitPopup_OnClick()
            end

            return orig_UnitPopup_OnClick()
        end
    end

    -- Hook UnitPopup_ShowMenu to update tank button text before menu renders
    if UnitPopup_ShowMenu then
        local prev_UnitPopup_ShowMenu = UnitPopup_ShowMenu
        UnitPopup_ShowMenu = function(a1, a2, a3, a4, a5)
            local pName = a4
            if not pName and a1 and a1.name then
                pName = a1.name
            end
            if pName and GudaPlates_Threat and GudaPlates_Threat.IsPlayerTank then
                local isTank = GudaPlates_Threat.IsPlayerTank(pName)
                UnitPopupButtons["GUDAPLATES_TANK"].text = isTank and "Unmark Tank" or "Mark as Tank"
            end
            return prev_UnitPopup_ShowMenu(a1, a2, a3, a4, a5)
        end
    end
end

-- ============================================
-- Hook TargetFrame right-click for NPC targets
-- ============================================

local function HookTargetFrameClick()
    local origOnClick = TargetFrame:GetScript("OnClick")
    TargetFrame:SetScript("OnClick", function()
        local button = arg1
        if button == "RightButton" and UnitExists("target") then
            local inGroup = (GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)
            -- Only show our dropdown for NPC targets when solo
            if not inGroup and not UnitIsPlayer("target") then
                ToggleDropDownMenu(1, nil, markDropdown, "cursor", 0, 0)
                return
            end
        end
        -- Default behavior (in group, player targets, left clicks)
        if origOnClick then
            origOnClick()
        end
    end)
end

-- ============================================
-- Debug: test texture rendering
-- ============================================

function Marks.DebugTest()
    local Print = (GudaPlates and GudaPlates.Print) or function() end

    -- Toggle off
    if Marks._debugFrame1 then
        Marks._debugFrame1:Hide()
        Marks._debugFrame1 = nil
        if Marks._debugFrame2 then
            Marks._debugFrame2:Hide()
            Marks._debugFrame2 = nil
        end
        Print("Debug icons hidden.")
        return
    end

    -- LEFT: Skull texture (KNOWN to render in this addon - see GudaPlates.lua:1285)
    local f1 = CreateFrame("Frame", "GudaPlatesDbg1", UIParent)
    f1:SetFrameStrata("TOOLTIP")
    f1:SetWidth(64)
    f1:SetHeight(64)
    f1:SetPoint("CENTER", UIParent, "CENTER", -40, 0)
    local t1 = f1:CreateTexture(nil, "ARTWORK")
    t1:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    t1:SetAllPoints(f1)
    t1:SetAlpha(1)
    f1:Show()
    Marks._debugFrame1 = f1

    -- RIGHT: Raid icon Star (the texture we're testing)
    local f2 = CreateFrame("Frame", "GudaPlatesDbg2", UIParent)
    f2:SetFrameStrata("TOOLTIP")
    f2:SetWidth(64)
    f2:SetHeight(64)
    f2:SetPoint("CENTER", UIParent, "CENTER", 40, 0)
    local t2 = f2:CreateTexture(nil, "ARTWORK")
    t2:SetAllPoints(f2)
    t2:SetAlpha(1)
    ApplyRaidIcon(t2, 1)
    f2:Show()
    Marks._debugFrame2 = f2

    Print("LEFT = Skull (known working), RIGHT = Raid Star (testing)")
    Print("Raid texture: " .. RAID_ICON_TEXTURE)
    Print("SetRaidTargetIconTexture API: " .. tostring(SetRaidTargetIconTexture ~= nil))
    Print("Type /gp markdebug again to hide.")
end

-- ============================================
-- Tank Shield Icons on Party/Raid Frames
-- ============================================

local SHIELD_TEXTURE = "Interface\\AddOns\\GudaPlates\\Assets\\shield"
local shieldIcons = {}  -- [frameName] = texture

local function GetOrCreateShield(parentFrame)
    local name = parentFrame:GetName()
    if shieldIcons[name] then return shieldIcons[name] end

    local icon = parentFrame:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(SHIELD_TEXTURE)
    icon:SetWidth(10)
    icon:SetHeight(10)
    -- Position before the level number in the raid frame
    local levelText = getglobal(parentFrame:GetName() .. "Level")
    if levelText then
        icon:SetPoint("RIGHT", levelText, "LEFT", -1, 0)
    else
        icon:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 1, -1)
    end
    icon:Hide()
    shieldIcons[name] = icon
    return icon
end

local function UpdateTankShieldIcons()
    if not GudaPlates_Threat or not GudaPlates_Threat.IsPlayerTank then return end

    -- Party frames (1-4)
    for i = 1, 4 do
        local frame = getglobal("PartyMemberFrame" .. i)
        if frame and frame:IsShown() then
            local unitId = "party" .. i
            if UnitExists(unitId) then
                local name = UnitName(unitId)
                local icon = GetOrCreateShield(frame)
                if name and GudaPlates_Threat.IsPlayerTank(name) then
                    icon:Show()
                else
                    icon:Hide()
                end
            end
        end
    end

    -- Raid frames (1-40)
    for i = 1, 40 do
        local frame = getglobal("RaidGroupButton" .. i)
        if frame and frame:IsShown() then
            local unitId = "raid" .. i
            if UnitExists(unitId) then
                local name = UnitName(unitId)
                local icon = GetOrCreateShield(frame)
                if name and GudaPlates_Threat.IsPlayerTank(name) then
                    icon:Show()
                else
                    icon:Hide()
                end
            end
        end
    end
end

Marks.UpdateTankShieldIcons = UpdateTankShieldIcons

-- ============================================
-- Event Frame
-- ============================================

local eventFrame = CreateFrame("Frame", "GudaPlatesMarksFrame")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function()
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateTargetFrameIcon()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Marks.ClearAllMarks()
        if targetIconFrame then targetIconFrame:Hide() end
        UpdateTankShieldIcons()
    elseif event == "ADDON_LOADED" and arg1 == "GudaPlates" then
        CreateTargetFrameIcon()
        SetupUnitPopup()
        HookTargetFrameClick()
    elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        UpdateTankShieldIcons()
    end
end)

-- ============================================
-- Binding Header and Names
-- ============================================

BINDING_HEADER_GUDAPLATESHEADER = "GudaPlates"
BINDING_NAME_GUDAPLATES_MARK_1 = "Set Star"
BINDING_NAME_GUDAPLATES_MARK_2 = "Set Circle"
BINDING_NAME_GUDAPLATES_MARK_3 = "Set Diamond"
BINDING_NAME_GUDAPLATES_MARK_4 = "Set Triangle"
BINDING_NAME_GUDAPLATES_MARK_5 = "Set Moon"
BINDING_NAME_GUDAPLATES_MARK_6 = "Set Square"
BINDING_NAME_GUDAPLATES_MARK_7 = "Set Cross"
BINDING_NAME_GUDAPLATES_MARK_8 = "Set Skull"
BINDING_NAME_GUDAPLATES_MARK_0 = "Clear Mark"
