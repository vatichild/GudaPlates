-- GudaPlates for WoW 1.12.1 (Refactored)
GudaPlates = GudaPlates or {}
GudaPlates.registry = GudaPlates.registry or {}

-- Initialize local references from core
local Settings = GudaPlates.Settings
local THREAT_COLORS = GudaPlates.THREAT_COLORS
local Print = GudaPlates.Print or function(msg) DEFAULT_CHAT_FRAME:AddMessage(tostring(msg)) end

-- Event handling frame
local eventFrame = CreateFrame("Frame", "GudaPlatesEventFrame")

function GudaPlates.SaveSettings()
    GudaPlatesDB = GudaPlatesDB or {}
    GudaPlatesDB.playerRole = GudaPlates.playerRole
    GudaPlatesDB.THREAT_COLORS = GudaPlates.THREAT_COLORS
    GudaPlatesDB.nameplateOverlap = GudaPlates.nameplateOverlap
    GudaPlatesDB.minimapAngle = GudaPlates.minimapAngle
    GudaPlatesDB.Settings = GudaPlates.Settings
end

function GudaPlates.LoadSettings()
    GudaPlatesDB = GudaPlatesDB or {}
    if GudaPlatesDB.playerRole then GudaPlates.playerRole = GudaPlatesDB.playerRole end
    if GudaPlatesDB.nameplateOverlap ~= nil then GudaPlates.nameplateOverlap = GudaPlatesDB.nameplateOverlap end
    if GudaPlatesDB.minimapAngle then GudaPlates.minimapAngle = GudaPlatesDB.minimapAngle end
    if GudaPlatesDB.Settings then
        for k, v in pairs(GudaPlatesDB.Settings) do GudaPlates.Settings[k] = v end
    end
    -- Support for migration/legacy if needed
    if GudaPlatesDB.THREAT_COLORS then
        for role, colors in pairs(GudaPlatesDB.THREAT_COLORS) do
            if THREAT_COLORS[role] then
                for colorType, colorVal in pairs(colors) do
                    if THREAT_COLORS[role][colorType] then THREAT_COLORS[role][colorType] = colorVal end
                end
            end
        end
    end
end

-- Minimap Button
local function CreateMinimapButton()
    local btn = CreateFrame("Button", "GudaPlatesMinimapButton", Minimap)
    btn:SetWidth(32) btn:SetHeight(32) btn:SetFrameStrata("LOW") btn:SetToplevel(true) btn:SetMovable(true) btn:EnableMouse(true)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Spell_Nature_WispSplode")
    icon:SetWidth(20) icon:SetHeight(20) icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(52) border:SetHeight(52) border:SetPoint("CENTER", btn, "CENTER", 10, -10)

    local function UpdatePos()
        local rad = math.rad(GudaPlates.minimapAngle)
        local x = math.cos(rad) * 80
        local y = math.sin(rad) * 80
        btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - x, y - 52)
    end
    UpdatePos()
    GudaPlates.UpdateMinimapButtonPosition = UpdatePos

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton", "RightButton")
    btn:SetScript("OnDragStart", function() this.dragging = true this:LockHighlight() end)
    btn:SetScript("OnDragStop", function() this.dragging = false this:UnlockHighlight() GudaPlates.SaveSettings() end)
    btn:SetScript("OnUpdate", function()
        if this.dragging then
            local xpos, ypos = GetCursorPosition()
            local xmin, ymin = Minimap:GetLeft() or 400, Minimap:GetBottom() or 400
            local mscale = Minimap:GetEffectiveScale()
            local dx = xmin - xpos / mscale + 70
            local dy = ypos / mscale - ymin - 70
            GudaPlates.minimapAngle = math.deg(math.atan2(dy, dx))
            UpdatePos()
        end
    end)
    btn:SetScript("OnClick", function()
        if arg1 == "RightButton" or IsControlKeyDown() then
            local frame = getglobal("GudaPlatesOptionsFrame")
            if frame then
                if frame:IsShown() then frame:Hide() else frame:Show() end
            end
        end
    end)
    btn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:AddLine("GudaPlates")
        GameTooltip:AddLine("Left-Drag to move button", 1, 1, 1)
        GameTooltip:AddLine("Right-Click or Ctrl-Left-Click for settings", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Slash Commands
SLASH_GUDAPLATES1 = "/gudaplates"
SLASH_GUDAPLATES2 = "/gp"
SlashCmdList["GUDAPLATES"] = function(msg)
    if msg == "tank" then
        GudaPlates.playerRole = "TANK"
        GudaPlates.SaveSettings()
        Print("Role set to TANK")
    elseif msg == "dps" then
        GudaPlates.playerRole = "DPS"
        GudaPlates.SaveSettings()
        Print("Role set to DPS")
    elseif msg == "config" then
        local frame = getglobal("GudaPlatesOptionsFrame")
        if frame then
            if frame:IsShown() then frame:Hide() else frame:Show() end
        end
    else
        Print("Commands: /gp tank | /gp dps | /gp config")
    end
end

-- Main Event Loop
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("UNIT_CASTEVENT")

local function IsNamePlate(frame)
    if frame:GetName() then return false end
    local region = frame:GetRegions()
    return region and region:GetObjectType() == "Texture" and region:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

-- Handle nameplate scanning
eventFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    if (this.tick or 0) > now then return else this.tick = now + 0.05 end

    local frames = {WorldFrame:GetChildren()}
    for _, frame in ipairs(frames) do
        if IsNamePlate(frame) then
            if not GudaPlates.registry[frame] then
                GudaPlates.HookNamePlate(frame)
            end
            GudaPlates.UpdateNamePlate(frame)
        end
    end
end)

eventFrame:SetScript("OnEvent", function()
    local e = event
    if e == "VARIABLES_LOADED" then
        Print("VARIABLES_LOADED fired.")
        local success, err = pcall(function()
            Print("Loading settings...")
            GudaPlates.LoadSettings()
            Print("Disabling pfUI nameplates...")
            GudaPlates.DisablePfUINameplates()
            if GudaPlates.CreateOptionsFrame then
                Print("Creating options frame...")
                GudaPlates.CreateOptionsFrame()
            else
                Print("Error: CreateOptionsFrame not found!")
            end
            Print("Creating minimap button...")
            CreateMinimapButton()
        end)
        if not success then
            Print("Initialization Error: " .. tostring(err))
        else
            Print("Loaded successfully. Use /gp config for settings.")
        end
    elseif e == "PLAYER_ENTERING_WORLD" then
        -- Refresh settings or state if needed
    end
end)

-- Initial Startup Message
if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[GudaPlates]|r Initializing...")
end
