-- GudaPlates Logic
GudaPlates = GudaPlates or {}

-- Local references for performance and readability
local Settings = GudaPlates.Settings
local THREAT_COLORS = GudaPlates.THREAT_COLORS
local Print = GudaPlates.Print
local IsFriendly = GudaPlates.IsFriendly
local FormatTime = GudaPlates.FormatTime
local IsTankClass = GudaPlates.IsTankClass
local IsInPlayerGroup = GudaPlates.IsInPlayerGroup
local SpellDB = GudaPlates_SpellDB

function GudaPlates.UpdateNamePlateDimensions(frame)
    local nameplate = frame.nameplate
    if not nameplate then return end

    local isFriendly = IsFriendly(frame)
    local hHeight = isFriendly and Settings.friendlyHealthbarHeight or Settings.healthbarHeight
    local hWidth = isFriendly and Settings.friendlyHealthbarWidth or Settings.healthbarWidth
    local hFontSize = isFriendly and Settings.friendlyHealthFontSize or Settings.healthFontSize

    nameplate.health:SetHeight(hHeight)
    nameplate.health:SetWidth(hWidth)
    
    -- Update castbar dimensions
    nameplate.castbar:SetHeight(Settings.castbarHeight)
    if Settings.castbarIndependent then
        nameplate.castbar:SetWidth(Settings.castbarWidth)
    else
        nameplate.castbar:SetWidth(hWidth)
    end
    
    -- Update castbar icon size
    local iconSize
    if Settings.castbarIndependent and Settings.castbarWidth > hWidth then
        if nameplate.mana and nameplate.mana:IsShown() then
            iconSize = hHeight + Settings.manabarHeight
        else
            iconSize = hHeight
        end
    else
        if nameplate.mana and nameplate.mana:IsShown() then
            iconSize = hHeight + Settings.castbarHeight + Settings.manabarHeight
        else
            iconSize = hHeight + Settings.castbarHeight
        end
    end
    nameplate.castbar.icon:SetWidth(iconSize)
    nameplate.castbar.icon:SetHeight(iconSize)
    
    -- Update mana bar dimensions and text position
    if nameplate.mana then
        nameplate.mana:SetWidth(hWidth)
        nameplate.mana:SetHeight(Settings.manabarHeight)
        
        if nameplate.mana.text then
            nameplate.mana.text:ClearAllPoints()
            if Settings.manaTextPosition == "LEFT" then
                nameplate.mana.text:SetPoint("LEFT", nameplate.mana, "LEFT", 2, 0)
                nameplate.mana.text:SetJustifyH("LEFT")
            elseif Settings.manaTextPosition == "RIGHT" then
                nameplate.mana.text:SetPoint("RIGHT", nameplate.mana, "RIGHT", -2, 0)
                nameplate.mana.text:SetJustifyH("RIGHT")
            else
                nameplate.mana.text:SetPoint("CENTER", nameplate.mana, "CENTER", 0, 0)
                nameplate.mana.text:SetJustifyH("CENTER")
            end
        end
    end

    local healthFont, _, healthFlags = nameplate.healthtext:GetFont()
    nameplate.healthtext:SetFont(healthFont, hFontSize, healthFlags)
    
    nameplate.healthtext:ClearAllPoints()
    if Settings.healthTextPosition == "LEFT" then
        nameplate.healthtext:SetPoint("LEFT", nameplate.health, "LEFT", 2, 0)
        nameplate.healthtext:SetJustifyH("LEFT")
    elseif Settings.healthTextPosition == "RIGHT" then
        nameplate.healthtext:SetPoint("RIGHT", nameplate.health, "RIGHT", -2, 0)
        nameplate.healthtext:SetJustifyH("RIGHT")
    else
        nameplate.healthtext:SetPoint("CENTER", nameplate.health, "CENTER", 0, 0)
        nameplate.healthtext:SetJustifyH("CENTER")
    end

    nameplate.level:SetFont(Settings.textFont, Settings.levelFontSize, "OUTLINE")
    nameplate.name:SetFont(Settings.textFont, Settings.nameFontSize, "OUTLINE")
    nameplate.healthtext:SetFont(Settings.textFont, hFontSize, "OUTLINE")
    if nameplate.mana and nameplate.mana.text then
        nameplate.mana.text:SetFont(Settings.textFont, 7, "OUTLINE")
    end
    if nameplate.castbar then
        nameplate.castbar.text:SetFont(Settings.textFont, 8, "OUTLINE")
        nameplate.castbar.timer:SetFont(Settings.textFont, 8, "OUTLINE")
    end
    if nameplate.debuffs then
        for i = 1, GudaPlates.MAX_DEBUFFS do
            if nameplate.debuffs[i] then
                nameplate.debuffs[i].cd:SetFont(Settings.textFont, 10, "OUTLINE")
                nameplate.debuffs[i].count:SetFont(Settings.textFont, 9, "OUTLINE")
            end
        end
    end

    nameplate.name:SetTextColor(Settings.nameColor[1], Settings.nameColor[2], Settings.nameColor[3], Settings.nameColor[4])
    nameplate.level:SetTextColor(Settings.levelColor[1], Settings.levelColor[2], Settings.levelColor[3], Settings.levelColor[4])
    nameplate.healthtext:SetTextColor(Settings.healthTextColor[1], Settings.healthTextColor[2], Settings.healthTextColor[3], Settings.healthTextColor[4])
    if nameplate.mana and nameplate.mana.text then
        nameplate.mana.text:SetTextColor(Settings.manaTextColor[1], Settings.manaTextColor[2], Settings.manaTextColor[3], Settings.manaTextColor[4])
    end
    
    if nameplate.castbar then
        nameplate.castbar:SetStatusBarColor(Settings.castbarColor[1], Settings.castbarColor[2], Settings.castbarColor[3], Settings.castbarColor[4])
    end

    if nameplate.original.raidicon then
        nameplate.original.raidicon:ClearAllPoints()
        if Settings.raidIconPosition == "LEFT" then
            nameplate.original.raidicon:SetPoint("RIGHT", nameplate.health, "LEFT", -5, 0)
        else
            nameplate.original.raidicon:SetPoint("LEFT", nameplate.health, "RIGHT", 5, 0)
        end
    end
    if frame.raidicon and frame.raidicon ~= nameplate.original.raidicon then
        frame.raidicon:ClearAllPoints()
        if Settings.raidIconPosition == "LEFT" then
            frame.raidicon:SetPoint("RIGHT", nameplate.health, "LEFT", -5, 0)
        else
            frame.raidicon:SetPoint("LEFT", nameplate.health, "RIGHT", 5, 0)
        end
    end

    nameplate.name:ClearAllPoints()
    if nameplate.mana then
        nameplate.mana:ClearAllPoints()
    end
    
    if Settings.swapNameDebuff then
        nameplate.name:SetPoint("BOTTOM", nameplate.health, "TOP", 0, 6)
        if nameplate.mana then
            nameplate.mana:SetPoint("TOP", nameplate.health, "BOTTOM", 0, 0)
        end
        for i = 1, GudaPlates.MAX_DEBUFFS do
            nameplate.debuffs[i]:ClearAllPoints()
            if i == 1 then
                if nameplate.mana and nameplate.mana:IsShown() then
                    nameplate.debuffs[i]:SetPoint("TOPLEFT", nameplate.mana, "BOTTOMLEFT", 0, -1)
                else
                    nameplate.debuffs[i]:SetPoint("TOPLEFT", nameplate.health, "BOTTOMLEFT", 0, -1)
                end
            else
                nameplate.debuffs[i]:SetPoint("LEFT", nameplate.debuffs[i-1], "RIGHT", 1, 0)
            end
        end
        nameplate.castbar:ClearAllPoints()
        if Settings.castbarIndependent and Settings.castbarWidth > Settings.healthbarWidth then
            if Settings.raidIconPosition == "RIGHT" then
                nameplate.castbar:SetPoint("BOTTOMRIGHT", nameplate.health, "TOPRIGHT", 0, 2)
            else
                nameplate.castbar:SetPoint("BOTTOMLEFT", nameplate.health, "TOPLEFT", 0, 2)
            end
        else
            nameplate.castbar:SetPoint("BOTTOM", nameplate.health, "TOP", 0, 2)
        end
        nameplate.level:ClearAllPoints()
        nameplate.level:SetPoint("BOTTOMRIGHT", nameplate.health, "TOPRIGHT", 0, 2)
    else
        nameplate.name:SetPoint("TOP", nameplate.health, "BOTTOM", 0, -6)
        if nameplate.mana then
            nameplate.mana:SetPoint("BOTTOM", nameplate.health, "TOP", 0, 0)
        end
        nameplate.level:ClearAllPoints()
        if nameplate.mana and nameplate.mana:IsShown() then
            nameplate.level:SetPoint("BOTTOMRIGHT", nameplate.mana, "TOPRIGHT", 0, 2)
        else
            nameplate.level:SetPoint("BOTTOMRIGHT", nameplate.health, "TOPRIGHT", 0, 2)
        end
        for i = 1, GudaPlates.MAX_DEBUFFS do
            nameplate.debuffs[i]:ClearAllPoints()
            if i == 1 then
                if nameplate.mana and nameplate.mana:IsShown() then
                    nameplate.debuffs[i]:SetPoint("BOTTOMLEFT", nameplate.mana, "TOPLEFT", 0, 1)
                else
                    nameplate.debuffs[i]:SetPoint("BOTTOMLEFT", nameplate.health, "TOPLEFT", 0, 1)
                end
            else
                nameplate.debuffs[i]:SetPoint("LEFT", nameplate.debuffs[i-1], "RIGHT", 1, 0)
            end
        end
        nameplate.castbar:ClearAllPoints()
        if Settings.castbarIndependent and Settings.castbarWidth > Settings.healthbarWidth then
            if Settings.raidIconPosition == "RIGHT" then
                nameplate.castbar:SetPoint("TOPRIGHT", nameplate.health, "BOTTOMRIGHT", 0, -2)
            else
                nameplate.castbar:SetPoint("TOPLEFT", nameplate.health, "BOTTOMLEFT", 0, -2)
            end
        else
            nameplate.castbar:SetPoint("TOP", nameplate.health, "BOTTOM", 0, -2)
        end
    end

    if not GudaPlates.nameplateOverlap then
        local npWidth = Settings.healthbarWidth * UIParent:GetScale()
        local npHeight = (Settings.healthbarHeight + 20) * UIParent:GetScale()
        frame:SetWidth(npWidth)
        frame:SetHeight(npHeight)
        nameplate:SetAllPoints(frame)
    else
        nameplate:ClearAllPoints()
        nameplate:SetPoint("CENTER", frame, "CENTER", 0, 0)
        nameplate:SetWidth(Settings.healthbarWidth)
        nameplate:SetHeight(Settings.healthbarHeight + 20)
    end
end

function GudaPlates.UpdateNamePlate(frame)
    local nameplate = frame.nameplate
    if not nameplate then return end

    local original = nameplate.original
    if not original.healthbar then return end

    original.healthbar:SetStatusBarTexture("")
    original.healthbar:SetAlpha(0)

    for i, region in ipairs({frame:GetRegions()}) do
        if region and region.GetObjectType then
            local otype = region:GetObjectType()
            if otype == "Texture" then
                if region ~= nameplate.original.raidicon and region ~= frame.raidicon then
                    region:SetAlpha(0)
                end
            elseif otype == "FontString" then
                region:SetAlpha(0)
            end
        end
    end

    for i, child in ipairs({frame:GetChildren()}) do
        if child and child ~= nameplate and child ~= original.healthbar then
            if child.SetAlpha then child:SetAlpha(0) end
            if child.Hide then child:Hide() end
        end
    end

    if frame.new then
        frame.new:SetAlpha(0)
        for _, region in ipairs({frame.new:GetRegions()}) do
            if region and region ~= frame.raidicon then
                if region.SetTexture then region:SetTexture("") end
                if region.SetAlpha then region:SetAlpha(0) end
                if region.SetWidth and region.GetObjectType and region:GetObjectType() == "FontString" then
                    region:SetWidth(0.001)
                end
            end
        end
    end

    local hp = original.healthbar:GetValue() or 0
    local hpmin, hpmax = original.healthbar:GetMinMaxValues()
    if not hpmax or hpmax == 0 then hpmax = 1 end

    nameplate.health:SetMinMaxValues(hpmin, hpmax)
    nameplate.health:SetValue(hp)

    local hpText = ""
    if Settings.showHealthText then
        local perc = (hp / hpmax) * 100
        local format = Settings.healthTextFormat
        if format == 1 then
            hpText = string.format("%.0f%%", perc)
        elseif format == 2 then
            if hp > 1000 then hpText = string.format("%.1fK", hp / 1000) else hpText = string.format("%d", hp) end
        elseif format == 3 then
            if hp > 1000 then hpText = string.format("%.1fK (%.0f%%)", hp / 1000, perc) else hpText = string.format("%d (%.0f%%)", hp, perc) end
        elseif format == 4 then
            if hpmax > 1000 then hpText = string.format("%.1fK - %.1fK", hp / 1000, hpmax / 1000) else hpText = string.format("%d - %d", hp, hpmax) end
        elseif format == 5 then
            if hpmax > 1000 then hpText = string.format("%.1fK - %.1fK (%.0f%%)", hp / 1000, hpmax / 1000, perc) else hpText = string.format("%d - %d (%.0f%%)", hp, hpmax, perc) end
        end
    end
    nameplate.healthtext:SetText(hpText)

    local levelText = nil
    if original.level and original.level.GetText then levelText = original.level:GetText() end
    if not levelText and frame.level and frame.level.GetText then levelText = frame.level:GetText() end
    if levelText then nameplate.level:SetText(levelText) end

    local isFriendly = IsFriendly(frame)
    if isFriendly ~= nameplate.isFriendly then
        nameplate.isFriendly = isFriendly
        GudaPlates.UpdateNamePlateDimensions(frame)
    end

    local r, g, b = original.healthbar:GetStatusBarColor()
    local isHostile = r > 0.9 and g < 0.2 and b < 0.2
    local isNeutral = r > 0.9 and g > 0.9 and b < 0.2

    local unitstr = nil
    local plateName = nil
    if original.name and original.name.GetText then plateName = original.name:GetText() end

    if GudaPlates.superwow_active and frame and frame.GetName then unitstr = frame:GetName(1) end

    local isAttackingPlayer = false
    local hasValidGUID = unitstr and unitstr ~= ""

    local hasAggroGlow = false
    if original.glow and original.glow.IsShown and original.glow:IsShown() then hasAggroGlow = true end

    if hasValidGUID then
        local mobTarget = unitstr .. "target"
        if UnitIsUnit(mobTarget, "player") then
            isAttackingPlayer = true
            nameplate.isAttackingPlayer = true
            nameplate.lastAttackTime = GetTime()
        else
            if nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime < 2) then
                isAttackingPlayer = true
            else
                nameplate.isAttackingPlayer = false
            end
        end
    else
        if plateName then
            if hasAggroGlow then
                isAttackingPlayer = true
                nameplate.isAttackingPlayer = true
                nameplate.lastAttackTime = GetTime()
            end
            if not isAttackingPlayer and nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime < 5) then
                isAttackingPlayer = true
            end
            if UnitExists("target") and UnitName("target") == plateName then
                if frame:GetAlpha() > 0.9 then
                    if UnitExists("targettarget") and UnitIsUnit("targettarget", "player") then
                        nameplate.isAttackingPlayer = true
                        nameplate.lastAttackTime = GetTime()
                        isAttackingPlayer = true
                    elseif UnitExists("targettarget") and not UnitIsUnit("targettarget", "player") then
                        nameplate.isAttackingPlayer = false
                        nameplate.lastAttackTime = nil
                        isAttackingPlayer = false
                    end
                end
            end
            if nameplate.isAttackingPlayer and nameplate.lastAttackTime and (GetTime() - nameplate.lastAttackTime > 5) then
                nameplate.isAttackingPlayer = false
                nameplate.lastAttackTime = nil
                isAttackingPlayer = false
            end
        end
    end

    local threatPct = 0
    local isTanking = false
    local threatStatus = 0

    if GudaPlates.twthreat_active and unitstr and isHostile then
        local tanking, status, pct = UnitThreat("player", unitstr)
        if tanking ~= nil then
            isTanking = tanking
            threatStatus = status or 0
            threatPct = pct or 0
        end
    end

    local isFriendlyUnit = IsFriendly(frame)
    if isFriendlyUnit then
        nameplate.health:SetStatusBarColor(0.27, 0.63, 0.27, 1)
    elseif isNeutral and not isAttackingPlayer then
        nameplate.health:SetStatusBarColor(0.9, 0.7, 0.0, 1)
    elseif isHostile or (isNeutral and isAttackingPlayer) then
        local mobInCombat = false
        local mobTargetUnit = nil

        if hasValidGUID then
            mobTargetUnit = unitstr .. "target"
            mobInCombat = UnitExists(mobTargetUnit)
        else
            mobInCombat = isAttackingPlayer or (GudaPlates.twthreat_active and threatPct > 0) or hasAggroGlow
            if plateName and UnitExists("target") and UnitName("target") == plateName and frame:GetAlpha() > 0.9 then
                mobTargetUnit = "targettarget"
            end
        end

        local isTappedByOthers = false
        if mobInCombat then
            local isMobTargetingGroup = false
            if mobTargetUnit and UnitExists(mobTargetUnit) then
                isMobTargetingGroup = IsInPlayerGroup(mobTargetUnit)
            else
                isMobTargetingGroup = isAttackingPlayer or hasAggroGlow
            end
            isTappedByOthers = not isMobTargetingGroup
        end

        if not mobInCombat then
            nameplate.health:SetStatusBarColor(0.85, 0.2, 0.2, 1)
        elseif isTappedByOthers then
            nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TAPPED))
        elseif hasValidGUID and GudaPlates.twthreat_active then
            if GudaPlates.playerRole == "TANK" then
                if isTanking or isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.AGGRO))
                elseif threatPct > 80 then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.LOSING_AGGRO))
                else
                    if IsTankClass(mobTargetUnit) then
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.OTHER_TANK))
                    else
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.NO_AGGRO))
                    end
                end
            else
                if isAttackingPlayer or isTanking then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.AGGRO))
                elseif threatPct > 80 then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.HIGH_THREAT))
                else
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.NO_AGGRO))
                end
            end
        elseif hasValidGUID then
            if GudaPlates.playerRole == "TANK" then
                if isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.AGGRO))
                elseif IsTankClass(mobTargetUnit) then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.OTHER_TANK))
                else
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.NO_AGGRO))
                end
            else
                if isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.AGGRO))
                else
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.NO_AGGRO))
                end
            end
        else
            if GudaPlates.playerRole == "TANK" then
                if isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.AGGRO))
                else
                    local otherTankHasAggro = false
                    if plateName and UnitExists("target") and UnitName("target") == plateName then
                        if frame:GetAlpha() > 0.9 and UnitExists("targettarget") then
                            otherTankHasAggro = IsTankClass("targettarget")
                        end
                    end
                    if otherTankHasAggro then
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.OTHER_TANK))
                    else
                        nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.TANK.NO_AGGRO))
                    end
                end
            else
                if isAttackingPlayer then
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.AGGRO))
                else
                    nameplate.health:SetStatusBarColor(unpack(THREAT_COLORS.DPS.NO_AGGRO))
                end
            end
        end
    else
        nameplate.health:SetStatusBarColor(r, g, b, 1)
    end

    if original.name and original.name.GetText then
        local name = original.name:GetText()
        if name then nameplate.name:SetText(name) end
    end

    if isFriendlyUnit and not Settings.showFriendlyNPCs then
        nameplate:SetAlpha(0)
    else
        nameplate:SetAlpha(1)
    end

    if Settings.showManaBar and GudaPlates.superwow_active and hasValidGUID then
        local mana = UnitMana(unitstr) or 0
        local manaMax = UnitManaMax(unitstr) or 0
        local powerType = UnitPowerType and UnitPowerType(unitstr) or 0
        
        if manaMax > 0 and powerType == 0 then
            nameplate.mana:SetMinMaxValues(0, manaMax)
            nameplate.mana:SetValue(mana)
            nameplate.mana:SetStatusBarColor(unpack(THREAT_COLORS.MANA_BAR))
            
            local manaText = ""
            if Settings.showManaText then
                local manaPerc = (mana / manaMax) * 100
                if Settings.manaTextFormat == 1 then
                    manaText = string.format("%.0f%%", manaPerc)
                elseif Settings.manaTextFormat == 2 then
                    if mana > 1000 then manaText = string.format("%.1fK", mana / 1000) else manaText = string.format("%d", mana) end
                elseif Settings.manaTextFormat == 3 then
                    local manaStr
                    if mana > 1000 then manaStr = string.format("%.1fK", mana / 1000) else manaStr = string.format("%d", mana) end
                    manaText = string.format("%s (%.0f%%)", manaStr, manaPerc)
                end
            end
            if nameplate.mana.text then nameplate.mana.text:SetText(manaText) end
            nameplate.mana:Show()
        else
            nameplate.mana:Hide()
        end
    else
        if nameplate.mana then nameplate.mana:Hide() end
    end

    local isTarget = false
    if UnitExists("target") and plateName then
        local targetName = UnitName("target")
        if targetName and targetName == plateName then
            if frame:GetAlpha() == 1 then isTarget = true end
        end
    end

    if isTarget then
        local topAnchor = nameplate.health
        local bottomAnchor = nameplate.health
        
        if nameplate.mana and nameplate.mana:IsShown() then
            if Settings.swapNameDebuff then
                topAnchor = nameplate.health
                bottomAnchor = nameplate.mana
            else
                topAnchor = nameplate.mana
                bottomAnchor = nameplate.health
            end
        end
        
        nameplate.targetBracket.leftVert:ClearAllPoints()
        nameplate.targetBracket.leftVert:SetPoint("TOPRIGHT", topAnchor, "TOPLEFT", -1, 2)
        nameplate.targetBracket.leftVert:SetPoint("BOTTOMRIGHT", bottomAnchor, "BOTTOMLEFT", -1, -2)
        nameplate.targetBracket.leftVert:Show()
        
        nameplate.targetBracket.leftTop:ClearAllPoints()
        nameplate.targetBracket.leftTop:SetPoint("TOPLEFT", nameplate.targetBracket.leftVert, "TOPRIGHT", 0, 0)
        nameplate.targetBracket.leftTop:Show()
        
        nameplate.targetBracket.leftBottom:ClearAllPoints()
        nameplate.targetBracket.leftBottom:SetPoint("BOTTOMLEFT", nameplate.targetBracket.leftVert, "BOTTOMRIGHT", 0, 0)
        nameplate.targetBracket.leftBottom:Show()
        
        nameplate.targetBracket.rightVert:ClearAllPoints()
        nameplate.targetBracket.rightVert:SetPoint("TOPLEFT", topAnchor, "TOPRIGHT", 1, 2)
        nameplate.targetBracket.rightVert:SetPoint("BOTTOMLEFT", bottomAnchor, "BOTTOMRIGHT", 1, -2)
        nameplate.targetBracket.rightVert:Show()
        
        nameplate.targetBracket.rightTop:ClearAllPoints()
        nameplate.targetBracket.rightTop:SetPoint("TOPRIGHT", nameplate.targetBracket.rightVert, "TOPLEFT", 0, 0)
        nameplate.targetBracket.rightTop:Show()
        
        nameplate.targetBracket.rightBottom:ClearAllPoints()
        nameplate.targetBracket.rightBottom:SetPoint("BOTTOMRIGHT", nameplate.targetBracket.rightVert, "BOTTOMLEFT", 0, 0)
        nameplate.targetBracket.rightBottom:Show()
        
        if Settings.showTargetGlow then
            if nameplate.targetGlowTop then
                nameplate.targetGlowTop:SetVertexColor(Settings.targetGlowColor[1], Settings.targetGlowColor[2], Settings.targetGlowColor[3], 0.4)
                nameplate.targetGlowTop:SetWidth(Settings.healthbarWidth)
                nameplate.targetGlowTop:Show()
            end
            if nameplate.targetGlowBottom then
                nameplate.targetGlowBottom:SetVertexColor(Settings.targetGlowColor[1], Settings.targetGlowColor[2], Settings.targetGlowColor[3], 0.4)
                nameplate.targetGlowBottom:SetWidth(Settings.healthbarWidth)
                nameplate.targetGlowBottom:Show()
            end
        end
        nameplate:SetFrameStrata("TOOLTIP")
    else
        nameplate.targetBracket.leftVert:Hide()
        nameplate.targetBracket.leftTop:Hide()
        nameplate.targetBracket.leftBottom:Hide()
        nameplate.targetBracket.rightVert:Hide()
        nameplate.targetBracket.rightTop:Hide()
        nameplate.targetBracket.rightBottom:Hide()
        if nameplate.targetGlowTop then nameplate.targetGlowTop:Hide() end
        if nameplate.targetGlowBottom then nameplate.targetGlowBottom:Hide() end
        if GudaPlates.nameplateOverlap then
            if nameplate.isAttackingPlayer then nameplate:SetFrameStrata("HIGH") else nameplate:SetFrameStrata("MEDIUM") end
        end
    end

    local casting = nil
    local now = GetTime()

    if hasValidGUID and GudaPlates.castDB[unitstr] then
        local cast = GudaPlates.castDB[unitstr]
        if cast.startTime + (cast.duration / 1000) > now then casting = cast else GudaPlates.castDB[unitstr] = nil end
    end

    if not casting and GudaPlates.superwow_active and hasValidGUID then
        if UnitCastingInfo then
            local spell, nameSubtext, text, texture, startTime, endTime = UnitCastingInfo(unitstr)
            if spell then casting = { spell = spell, startTime = startTime / 1000, duration = endTime - startTime, icon = texture } end
        end
        if not casting and UnitChannelInfo then
            local spell, nameSubtext, text, texture, startTime, endTime = UnitChannelInfo(unitstr)
            if spell then casting = { spell = spell, startTime = startTime / 1000, duration = endTime - startTime, icon = texture } end
        end
    end

    if not casting and plateName and GudaPlates.castTracker[plateName] and not hasValidGUID then
        local i = 1
        while i <= table.getn(GudaPlates.castTracker[plateName]) do
            local cast = GudaPlates.castTracker[plateName][i]
            if now > cast.startTime + (cast.duration / 1000) then table.remove(GudaPlates.castTracker[plateName], i) else
                if not casting then casting = cast end
                i = i + 1
            end
        end
    end

    if casting and casting.spell then
        local start = casting.startTime
        local duration = casting.duration
        if now < start + (duration / 1000) then
            nameplate.castbar:SetMinMaxValues(0, duration)
            nameplate.castbar:SetValue((now - start) * 1000)
            nameplate.castbar.text:SetText(casting.spell)
            nameplate.castbar.timer:SetText(string.format("%.1fs", (start + (duration / 1000)) - now))

            if casting.icon and Settings.showCastbarIcon then
                nameplate.castbar.icon:SetTexture(casting.icon)
                local iconSize
                if Settings.castbarIndependent and Settings.castbarWidth > Settings.healthbarWidth then
                    iconSize = (nameplate.mana and nameplate.mana:IsShown()) and (Settings.healthbarHeight + Settings.manabarHeight) or Settings.healthbarHeight
                else
                    iconSize = Settings.healthbarHeight + Settings.castbarHeight + ((nameplate.mana and nameplate.mana:IsShown()) and Settings.manabarHeight or 0)
                end
                nameplate.castbar.icon:SetWidth(iconSize)
                nameplate.castbar.icon:SetHeight(iconSize)
                nameplate.castbar.icon:ClearAllPoints()
                if Settings.castbarIndependent and Settings.castbarWidth > Settings.healthbarWidth then
                    if Settings.raidIconPosition == "RIGHT" then
                        nameplate.castbar.icon:SetPoint("TOPRIGHT", nameplate.health, "TOPLEFT", -4, 0)
                    else
                        nameplate.castbar.icon:SetPoint("TOPLEFT", nameplate.health, "TOPRIGHT", 4, 0)
                    end
                else
                    if Settings.raidIconPosition == "RIGHT" then
                        nameplate.castbar.icon:SetPoint(Settings.swapNameDebuff and "TOPRIGHT" or "BOTTOMRIGHT", nameplate.castbar, Settings.swapNameDebuff and "TOPLEFT" or "BOTTOMLEFT", -4, 0)
                    else
                        nameplate.castbar.icon:SetPoint(Settings.swapNameDebuff and "TOPLEFT" or "BOTTOMLEFT", nameplate.castbar, Settings.swapNameDebuff and "TOPRIGHT" or "BOTTOMRIGHT", 4, 0)
                    end
                end
                nameplate.castbar.icon:Show()
                if nameplate.castbar.icon.border then nameplate.castbar.icon.border:Show() end
            else
                nameplate.castbar.icon:Hide()
                if nameplate.castbar.icon.border then nameplate.castbar.icon.border:Hide() end
            end
            nameplate.castbar:Show()
        else nameplate.castbar:Hide() end
    else nameplate.castbar:Hide() end

    for i = 1, GudaPlates.MAX_DEBUFFS do
        nameplate.debuffs[i]:Hide()
        nameplate.debuffs[i].count:SetText("")
        nameplate.debuffs[i].expirationTime = 0
    end

    local debuffIndex = 1
    if GudaPlates.superwow_active and hasValidGUID then
        for i = 1, 40 do
            if debuffIndex > GudaPlates.MAX_DEBUFFS then break end
            local texture, stacks = UnitDebuff(unitstr, i)
            if not texture then break end
            local effect = nil
            if SpellDB then
                effect = SpellDB:ScanDebuff(unitstr, i)
                if (not effect or effect == "") and UnitGUID("target") == unitstr then effect = SpellDB:ScanDebuff("target", i) end
                if (not effect or effect == "") and SpellDB.textureToSpell[texture] then effect = SpellDB.textureToSpell[texture] end
            end
            local duration, timeleft = nil, nil
            local isMyDebuff = false
            if effect and SpellDB and SpellDB.objects and SpellDB.objects[plateName] then
                local level = UnitLevel(unitstr) or 0
                if SpellDB.objects[plateName][level] and SpellDB.objects[plateName][level][effect] then
                    local data = SpellDB.objects[plateName][level][effect]
                    duration = data.duration
                    timeleft = duration - (now - data.start)
                    isMyDebuff = true
                end
            end
            if not isMyDebuff and (not effect or effect == "") and GudaPlates.debuffTimers[plateName .. "_" .. texture] then
                local data = GudaPlates.debuffTimers[plateName .. "_" .. texture]
                if now < data.start + data.duration then
                    duration = data.duration
                    timeleft = (data.start + data.duration) - now
                    isMyDebuff = true
                end
            end
            if Settings.showOnlyMyDebuffs and not isMyDebuff then -- continue
            else
                local debuff = nameplate.debuffs[debuffIndex]
                debuff.icon:SetTexture(texture)
                if timeleft and timeleft > 0 and Settings.showDebuffTimers then debuff.expirationTime = now + timeleft else debuff.expirationTime = 0 end
                debuff.count:SetText((stacks and stacks > 1) and stacks or "")
                debuff:Show()
                debuffIndex = debuffIndex + 1
            end
        end
    elseif plateName and GudaPlates.debuffTracker[plateName] then
        for texture, data in pairs(GudaPlates.debuffTracker[plateName]) do
            if debuffIndex > GudaPlates.MAX_DEBUFFS then break end
            if now < data.start + data.duration then
                local debuff = nameplate.debuffs[debuffIndex]
                debuff.icon:SetTexture(texture)
                if Settings.showDebuffTimers then debuff.expirationTime = data.start + data.duration else debuff.expirationTime = 0 end
                debuff.count:SetText((data.stacks and data.stacks > 1) and data.stacks or "")
                debuff:Show()
                debuffIndex = debuffIndex + 1
            end
        end
    end
end

function GudaPlates.HookNamePlate(frame)
    if not frame or GudaPlates.registry[frame] then return end
    GudaPlates.platecount = GudaPlates.platecount + 1
    local platename = "GudaPlate" .. GudaPlates.platecount
    local nameplate = CreateFrame("Button", platename, frame)
    nameplate.platename = platename
    nameplate:EnableMouse(false)
    nameplate.parent = frame
    nameplate.original = {}
    nameplate:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    nameplate:SetScript("OnClick", function() if arg1 == "LeftButton" or arg1 == "RightButton" then this.parent:Click() end end)

    if frame.healthbar then nameplate.original.healthbar = frame.healthbar else nameplate.original.healthbar = frame:GetChildren() end
    local regions = {frame:GetRegions()}
    for i, region in ipairs(regions) do
        if region and region.GetObjectType then
            local rtype = region:GetObjectType()
            if i == 2 then nameplate.original.glow = region elseif i == 6 then nameplate.original.raidicon = region elseif rtype == "FontString" then
                local text = region:GetText()
                if text then if tonumber(text) then nameplate.original.level = region else nameplate.original.name = region end end
            end
        end
    end
    if frame.new then
        for _, region in ipairs({frame.new:GetRegions()}) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                local text = region:GetText()
                if text and not tonumber(text) and not nameplate.original.name then nameplate.original.name = region end
            end
        end
    end

    nameplate:SetAllPoints(frame)
    nameplate:SetFrameLevel(frame:GetFrameLevel() + 10)
    nameplate.health = CreateFrame("StatusBar", nil, nameplate)
    nameplate.health:SetFrameLevel(frame:GetFrameLevel() + 11)
    nameplate.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    nameplate.health:SetHeight(Settings.healthbarHeight)
    nameplate.health:SetWidth(Settings.healthbarWidth)
    nameplate.health:SetPoint("CENTER", nameplate, "CENTER", 0, 0)
    nameplate.health.bg = nameplate.health:CreateTexture(nil, "BACKGROUND")
    nameplate.health.bg:SetTexture(0, 0, 0, 0.8)
    nameplate.health.bg:SetAllPoints()
    nameplate.health.border = nameplate.health:CreateTexture(nil, "OVERLAY")
    nameplate.health.border:SetTexture(0, 0, 0, 1)
    nameplate.health.border:SetPoint("TOPLEFT", nameplate.health, "TOPLEFT", -1, 1)
    nameplate.health.border:SetPoint("BOTTOMRIGHT", nameplate.health, "BOTTOMRIGHT", 1, -1)
    nameplate.health.border:SetDrawLayer("BACKGROUND", -1)

    if nameplate.original.raidicon then
        nameplate.original.raidicon:SetParent(nameplate.health)
        nameplate.original.raidicon:ClearAllPoints()
        nameplate.original.raidicon:SetPoint("RIGHT", nameplate.health, "LEFT", -5, 0)
        nameplate.original.raidicon:SetWidth(24)
        nameplate.original.raidicon:SetHeight(24)
        nameplate.original.raidicon:SetDrawLayer("OVERLAY")
    end
    if frame.raidicon and frame.raidicon ~= nameplate.original.raidicon then
        frame.raidicon:SetParent(nameplate.health)
        frame.raidicon:ClearAllPoints()
        frame.raidicon:SetPoint("RIGHT", nameplate.health, "LEFT", -5, 0)
        frame.raidicon:SetWidth(24)
        frame.raidicon:SetHeight(24)
        frame.raidicon:SetDrawLayer("OVERLAY")
    end

    nameplate.targetBracket = {}
    local bracketParts = {"leftVert", "leftTop", "leftBottom", "rightVert", "rightTop", "rightBottom"}
    for _, part in ipairs(bracketParts) do
        nameplate.targetBracket[part] = nameplate.health:CreateTexture(nil, "OVERLAY")
        nameplate.targetBracket[part]:SetTexture(1, 1, 1, 0.5)
        if string.find(part, "Vert$") then nameplate.targetBracket[part]:SetWidth(1) else nameplate.targetBracket[part]:SetHeight(1) nameplate.targetBracket[part]:SetWidth(6) end
        nameplate.targetBracket[part]:Hide()
    end

    nameplate.targetGlowTop = nameplate:CreateTexture(nil, "BACKGROUND")
    nameplate.targetGlowTop:SetTexture("Interface\\AddOns\\-Dragonflight3\\media\\tex\\generic\\nocontrol_glow.blp")
    nameplate.targetGlowTop:SetWidth(Settings.healthbarWidth)
    nameplate.targetGlowTop:SetHeight(20)
    nameplate.targetGlowTop:SetPoint("BOTTOM", nameplate.health, "TOP", 0, 0)
    nameplate.targetGlowTop:SetVertexColor(Settings.targetGlowColor[1], Settings.targetGlowColor[2], Settings.targetGlowColor[3], 0.4)
    nameplate.targetGlowTop:Hide()

    nameplate.targetGlowBottom = nameplate:CreateTexture(nil, "BACKGROUND")
    nameplate.targetGlowBottom:SetTexture("Interface\\AddOns\\-Dragonflight3\\media\\tex\\generic\\nocontrol_glow.blp")
    nameplate.targetGlowBottom:SetTexCoord(0, 1, 1, 0)
    nameplate.targetGlowBottom:SetWidth(Settings.healthbarWidth)
    nameplate.targetGlowBottom:SetHeight(20)
    nameplate.targetGlowBottom:SetPoint("TOP", nameplate.health, "BOTTOM", 0, 0)
    nameplate.targetGlowBottom:SetVertexColor(Settings.targetGlowColor[1], Settings.targetGlowColor[2], Settings.targetGlowColor[3], 0.4)
    nameplate.targetGlowBottom:Hide()

    nameplate.name = nameplate:CreateFontString(nil, "OVERLAY")
    nameplate.name:SetFont(Settings.textFont, 9, "OUTLINE")
    nameplate.name:SetTextColor(Settings.nameColor[1], Settings.nameColor[2], Settings.nameColor[3], Settings.nameColor[4])
    nameplate.name:SetJustifyH("CENTER")

    nameplate.level = nameplate:CreateFontString(nil, "OVERLAY")
    nameplate.level:SetFont(Settings.textFont, 9, "OUTLINE")
    nameplate.level:SetPoint("BOTTOMRIGHT", nameplate.health, "TOPRIGHT", 0, 2)
    nameplate.level:SetTextColor(Settings.levelColor[1], Settings.levelColor[2], Settings.levelColor[3], Settings.levelColor[4])
    nameplate.level:SetJustifyH("RIGHT")

    nameplate.healthtext = nameplate.health:CreateFontString(nil, "OVERLAY")
    nameplate.healthtext:SetFont(Settings.textFont, 8, "OUTLINE")
    nameplate.healthtext:SetPoint("CENTER", nameplate.health, "CENTER", 0, 0)
    nameplate.healthtext:SetTextColor(Settings.healthTextColor[1], Settings.healthTextColor[2], Settings.healthTextColor[3], Settings.healthTextColor[4])

    nameplate.mana = CreateFrame("StatusBar", nil, nameplate)
    nameplate.mana:SetFrameLevel(frame:GetFrameLevel() + 11)
    nameplate.mana:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    nameplate.mana:SetStatusBarColor(unpack(THREAT_COLORS.MANA_BAR))
    nameplate.mana:SetHeight(Settings.manabarHeight)
    nameplate.mana:SetWidth(Settings.healthbarWidth)
    nameplate.mana:SetPoint("TOP", nameplate.health, "BOTTOM", 0, 0)
    nameplate.mana:Hide()
    nameplate.mana.bg = nameplate.mana:CreateTexture(nil, "BACKGROUND")
    nameplate.mana.bg:SetTexture(0, 0, 0, 0.8)
    nameplate.mana.bg:SetAllPoints()
    nameplate.mana.border = nameplate.mana:CreateTexture(nil, "OVERLAY")
    nameplate.mana.border:SetTexture(0, 0, 0, 1)
    nameplate.mana.border:SetPoint("TOPLEFT", nameplate.mana, "TOPLEFT", -1, 1)
    nameplate.mana.border:SetPoint("BOTTOMRIGHT", nameplate.mana, "BOTTOMRIGHT", 1, -1)
    nameplate.mana.border:SetDrawLayer("BACKGROUND", -1)
    nameplate.mana.text = nameplate.mana:CreateFontString(nil, "OVERLAY")
    nameplate.mana.text:SetFont(Settings.textFont, 7, "OUTLINE")
    nameplate.mana.text:SetTextColor(Settings.manaTextColor[1], Settings.manaTextColor[2], Settings.manaTextColor[3], Settings.manaTextColor[4])

    nameplate.castbar = CreateFrame("StatusBar", nil, nameplate)
    nameplate.castbar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    nameplate.castbar:SetHeight(Settings.castbarHeight)
    nameplate.castbar:SetStatusBarColor(Settings.castbarColor[1], Settings.castbarColor[2], Settings.castbarColor[3], Settings.castbarColor[4])
    nameplate.castbar:Hide()
    nameplate.castbar.bg = nameplate.castbar:CreateTexture(nil, "BACKGROUND")
    nameplate.castbar.bg:SetTexture(0, 0, 0, 1.0)
    nameplate.castbar.bg:SetAllPoints()
    nameplate.castbar.border = nameplate.castbar:CreateTexture(nil, "OVERLAY")
    nameplate.castbar.border:SetTexture(0, 0, 0, 1)
    nameplate.castbar.border:SetPoint("TOPLEFT", nameplate.castbar, "TOPLEFT", -1, 1)
    nameplate.castbar.border:SetPoint("BOTTOMRIGHT", nameplate.castbar, "BOTTOMRIGHT", 1, -1)
    nameplate.castbar.border:SetDrawLayer("BACKGROUND", -1)
    nameplate.castbar.text = nameplate.castbar:CreateFontString(nil, "OVERLAY")
    nameplate.castbar.text:SetFont(Settings.textFont, 8, "OUTLINE")
    nameplate.castbar.text:SetPoint("LEFT", nameplate.castbar, "LEFT", 2, 0)
    nameplate.castbar.text:SetTextColor(1, 1, 1, 1)
    nameplate.castbar.timer = nameplate.castbar:CreateFontString(nil, "OVERLAY")
    nameplate.castbar.timer:SetFont(Settings.textFont, 8, "OUTLINE")
    nameplate.castbar.timer:SetPoint("RIGHT", nameplate.castbar, "RIGHT", -2, 0)
    nameplate.castbar.timer:SetTextColor(1, 1, 1, 1)
    nameplate.castbar.icon = nameplate.castbar:CreateTexture(nil, "OVERLAY")
    nameplate.castbar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    nameplate.castbar.icon.border = nameplate.castbar:CreateTexture(nil, "BACKGROUND")
    nameplate.castbar.icon.border:SetTexture(0, 0, 0, 1)
    nameplate.castbar.icon.border:SetPoint("TOPLEFT", nameplate.castbar.icon, "TOPLEFT", -1, 1)
    nameplate.castbar.icon.border:SetPoint("BOTTOMRIGHT", nameplate.castbar.icon, "BOTTOMRIGHT", 1, -1)

    nameplate.debuffs = {}
    for i = 1, GudaPlates.MAX_DEBUFFS do
        local debuff = CreateFrame("Frame", nil, nameplate)
        debuff:SetWidth(GudaPlates.DEBUFF_SIZE)
        debuff:SetHeight(GudaPlates.DEBUFF_SIZE)
        debuff:SetFrameLevel(nameplate.health:GetFrameLevel() + 5)
        debuff.icon = debuff:CreateTexture(nil, "ARTWORK")
        debuff.icon:SetAllPoints()
        debuff.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        debuff.border = debuff:CreateTexture(nil, "BACKGROUND")
        debuff.border:SetTexture(0, 0, 0, 1)
        debuff.border:SetPoint("TOPLEFT", debuff, "TOPLEFT", -1, 1)
        debuff.border:SetPoint("BOTTOMRIGHT", debuff, "BOTTOMRIGHT", 1, -1)
        debuff.cdframe = CreateFrame("Frame", nil, debuff)
        debuff.cdframe:SetAllPoints(debuff)
        debuff.cdframe:SetFrameLevel(debuff:GetFrameLevel() + 2)
        debuff.cd = debuff.cdframe:CreateFontString(nil, "OVERLAY")
        debuff.cd:SetFont(Settings.textFont, 10, "OUTLINE")
        debuff.cd:SetPoint("CENTER", debuff.cdframe, "CENTER", 0, 0)
        debuff.cd:SetTextColor(1, 1, 1, 1)
        debuff.count = debuff.cdframe:CreateFontString(nil, "OVERLAY")
        debuff.count:SetFont(Settings.textFont, 9, "OUTLINE")
        debuff.count:SetPoint("BOTTOMRIGHT", debuff, "BOTTOMRIGHT", 1, 0)
        debuff.count:SetTextColor(1, 1, 1, 1)
        debuff:SetScript("OnUpdate", function()
            local now = GetTime()
            if (this.tick or 0) > now then return else this.tick = now + 0.1 end
            if not this.expirationTime or this.expirationTime == 0 then
                if this.cd and this.cd:GetAlpha() > 0 then this.cd:SetText("") this.cd:SetAlpha(0) end
                return
            end
            local timeLeft = this.expirationTime - now
            if timeLeft > 0 then
                local text, r, g, b, a = FormatTime(timeLeft)
                if this.cd and text and text ~= "" then
                    this.cd:SetText(text)
                    if r then this.cd:SetTextColor(r, g, b, a or 1) end
                    if this.cd:GetAlpha() < 1 then this.cd:SetAlpha(1) end
                end
            else
                if this.cd then this.cd:SetText("") this.cd:SetAlpha(0) end
                this.expirationTime = 0
            end
        end)
        debuff:Hide()
        nameplate.debuffs[i] = debuff
    end

    GudaPlates.UpdateNamePlateDimensions(frame)
    frame.nameplate = nameplate
    GudaPlates.registry[frame] = nameplate
end
