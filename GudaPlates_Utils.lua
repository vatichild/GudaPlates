-- GudaPlates Utils
GudaPlates = GudaPlates or {}

function GudaPlates.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[GudaPlates]|r " .. tostring(msg))
    end
end

function GudaPlates.DisablePfUINameplates()
    if pfUI then
        -- Disable the module registration
        if pfUI.modules then
            pfUI.modules["nameplates"] = nil
        end
        -- Hide existing pfUI nameplate frame if it exists
        if pfNameplates then
            pfNameplates:Hide()
            pfNameplates:UnregisterAllEvents()
        end
        -- Block pfUI nameplate creation function
        if pfUI.nameplates then
            pfUI.nameplates = nil
        end
        return true
    end
    return false
end

function GudaPlates.IsFriendly(frame)
    local nameplate = frame.nameplate
    if not nameplate or not nameplate.original or not nameplate.original.healthbar then return false end
    local r, g, b = nameplate.original.healthbar:GetStatusBarColor()
    return r < 0.2 and g > 0.9 and b < 0.2
end

function GudaPlates.FormatTime(seconds)
    if seconds >= 60 then
        return string.format("%.0fm", seconds / 60), 1, 1, 1, 1
    elseif seconds >= 5 then
        return string.format("%.0f", seconds), 1, 1, 0, 1 -- Yellow
    else
        return string.format("%.1f", seconds), 1, 0, 0, 1 -- Red
    end
end

function GudaPlates.IsTankClass(unit)
    if not unit or not UnitExists(unit) then return false end
    local _, class = UnitClass(unit)
    return class == "WARRIOR" or class == "PALADIN" or class == "DRUID"
end

function GudaPlates.IsInPlayerGroup(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsUnit(unit, "player") then return true end
    if UnitInParty(unit) or UnitInRaid(unit) then return true end
    return false
end

function GudaPlates.GetHexColor(r, g, b)
    return string.format("%02x%02x%02x", r*255, g*255, b*255)
end
