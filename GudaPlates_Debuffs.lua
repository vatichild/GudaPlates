-- GudaPlates Debuff Logic
GudaPlates_Debuffs = {}

local function round(input, places)
    if not places then places = 0 end
    if type(input) == "number" and type(places) == "number" then
        local pow = 1
        for i = 1, places do pow = pow * 10 end
        return math.floor(input * pow + 0.5) / pow
    end
end

function GudaPlates_Debuffs:FormatTime(remaining)
    if not remaining or remaining < 0 then return "", 1, 1, 1, 1 end
    if remaining > 356400 then -- 99 hours
        return math.floor(remaining / 86400 + 0.5) .. "d", 0.2, 0.2, 1, 1
    elseif remaining > 5940 then -- 99 minutes
        return math.floor(remaining / 3600 + 0.5) .. "h", 0.2, 0.5, 1, 1
    elseif remaining > 99 then
        return math.floor(remaining / 60 + 0.5) .. "m", 0.2, 1, 1, 1
    elseif remaining > 10 then
    -- White: more than 10 seconds
        return math.floor(remaining + 0.5) .. "", 1, 1, 1, 1
    elseif remaining > 5 then
    -- Yellow: 5-10 seconds
        return math.floor(remaining + 0.5) .. "", 1, 1, 0, 1
    elseif remaining > 0 then
    -- Red: less than 5 seconds
        return string.format("%.1f", remaining), 1, 0.2, 0.2, 1
    end
    return "", 1, 1, 1, 1
end

local SpellDB = GudaPlates_SpellDB
local Settings = GudaPlates.Settings
local _, playerClass = UnitClass("player")
playerClass = playerClass or ""

-- Constants
local MAX_DEBUFFS = 16
local DEBUFF_SIZE = 16

-- Debuff timer tracking: stores {startTime, duration} by "targetName_texture" key
GudaPlates_Debuffs.timers = {}
local debuffTimers = GudaPlates_Debuffs.timers

function GudaPlates_Debuffs:GetMaxDebuffs()
    return MAX_DEBUFFS
end

function GudaPlates_Debuffs:GetDebuffSize()
    return DEBUFF_SIZE
end

function GudaPlates_Debuffs:CreateDebuffFrames(nameplate)
    nameplate.debuffs = {}
    for i = 1, MAX_DEBUFFS do
        local debuff = CreateFrame("Frame", nil, nameplate)
        debuff:SetWidth(DEBUFF_SIZE)
        debuff:SetHeight(DEBUFF_SIZE)
        debuff:SetFrameLevel(nameplate.health:GetFrameLevel() + 5)

        debuff.icon = debuff:CreateTexture(nil, "ARTWORK")
        debuff.icon:SetAllPoints()
        debuff.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        debuff.icon:SetDrawLayer("ARTWORK")
        debuff.icon:SetAlpha(1)

        debuff.border = debuff:CreateTexture(nil, "BACKGROUND")
        debuff.border:SetTexture(0, 0, 0, 1)
        debuff.border:SetPoint("TOPLEFT", debuff, "TOPLEFT", -1, 1)
        debuff.border:SetPoint("BOTTOMRIGHT", debuff, "BOTTOMRIGHT", 1, -1)
        debuff.border:SetDrawLayer("BACKGROUND")

        debuff.cdframe = CreateFrame("Frame", nil, debuff)
        debuff.cdframe:SetAllPoints(debuff)
        debuff.cdframe:SetFrameLevel(debuff:GetFrameLevel() + 2)

        debuff.cd = debuff.cdframe:CreateFontString(nil, "OVERLAY")
        debuff.cd:SetFont(Settings.textFont, 10, "OUTLINE")
        debuff.cd:SetPoint("CENTER", debuff.cdframe, "CENTER", 0, 0)
        debuff.cd:SetTextColor(1, 1, 1, 1)
        debuff.cd:SetText("")
        debuff.cd:SetDrawLayer("OVERLAY", 7)

        debuff.count = debuff.cdframe:CreateFontString(nil, "OVERLAY")
        debuff.count:SetFont(Settings.textFont, 9, "OUTLINE")
        debuff.count:SetPoint("BOTTOMRIGHT", debuff, "BOTTOMRIGHT", 1, 0)
        debuff.count:SetTextColor(1, 1, 1, 1)
        debuff.count:SetText("")
        debuff.count:SetDrawLayer("OVERLAY", 7)

        debuff:SetScript("OnUpdate", function()
            local now = GetTime()
            if (this.tick or 0) > now then return else this.tick = now + 0.1 end

            if not this:IsShown() then return end
            if not this.expirationTime or this.expirationTime <= 0 then
                if this.cd then this.cd:SetText("") end
                return
            end

            local timeLeft = this.expirationTime - now
            if timeLeft > 0 then
                local text, r, g, b, a = GudaPlates_Debuffs:FormatTime(timeLeft)
                if this.cd then
                    this.cd:SetText(text)
                    if r then this.cd:SetTextColor(r, g, b, a or 1) end
                    this.cd:SetAlpha(1)
                end
            else
                if this.cd then
                    this.cd:SetText("")
                    this.cd:SetAlpha(0)
                end
                this.expirationTime = 0
            end
        end)

        debuff:Hide()
        nameplate.debuffs[i] = debuff
    end
end

function GudaPlates_Debuffs:UpdateDebuffs(nameplate, unitstr, plateName, isTarget, hasValidGUID, superwow_active)
-- Reset all debuff icons
    for i = 1, MAX_DEBUFFS do
        nameplate.debuffs[i]:Hide()
        nameplate.debuffs[i].count:SetText("")
        nameplate.debuffs[i].expirationTime = 0
    end

    local debuffIndex = 1
    local now = GetTime()
    local claimedMyDebuffs = {} -- Track which player debuffs are already shown on this nameplate

    if superwow_active and hasValidGUID then
        local effectiveUnit = (isTarget) and "target" or unitstr
        for i = 1, 40 do
            if debuffIndex > MAX_DEBUFFS then break end

            local texture, stacks = UnitDebuff(effectiveUnit, i)
            if not texture then break end
            local effect, duration, timeleft = nil, nil, nil
            local isMyDebuff = false
            if SpellDB then
                effect = SpellDB:ScanDebuff(effectiveUnit, i)

                if (not effect or effect == "") and not isTarget then
                    local targetGUID = UnitGUID and UnitGUID("target")
                    if targetGUID and targetGUID == unitstr then
                        effect = SpellDB:ScanDebuff("target", i)
                    end
                end

                if (not effect or effect == "") and SpellDB.textureToSpell and SpellDB.textureToSpell[texture] then
                    effect = SpellDB.textureToSpell[texture]
                end

                if effect and effect ~= "" then
                    local unitlevel = UnitLevel(unitstr) or 0
                    local data = nil
                    local dataGUID = nil
                    if SpellDB.objects[unitstr] then
                        if SpellDB.objects[unitstr][unitlevel] and SpellDB.objects[unitstr][unitlevel][effect] then
                            dataGUID = SpellDB.objects[unitstr][unitlevel][effect]
                        elseif SpellDB.objects[unitstr][0] and SpellDB.objects[unitstr][0][effect] then
                            dataGUID = SpellDB.objects[unitstr][0][effect]
                        else
                            for lvl, effects in pairs(SpellDB.objects[unitstr]) do
                                if effects[effect] then
                                    dataGUID = effects[effect]
                                    break
                                end
                            end
                        end
                    end

                    local dataName = nil
                    if plateName and SpellDB.objects[plateName] then
                        if SpellDB.objects[plateName][unitlevel] and SpellDB.objects[plateName][unitlevel][effect] then
                            dataName = SpellDB.objects[plateName][unitlevel][effect]
                        elseif SpellDB.objects[plateName][0] and SpellDB.objects[plateName][0][effect] then
                            dataName = SpellDB.objects[plateName][0][effect]
                        else
                            for lvl, effects in pairs(SpellDB.objects[plateName]) do
                                if effects[effect] then
                                    dataName = effects[effect]
                                    break
                                end
                            end
                        end
                    end

                    if dataGUID and dataName then
                        if (dataGUID.start or 0) >= (dataName.start or 0) then
                            data = dataGUID
                        else
                            data = dataName
                        end
                    else
                        data = dataGUID or dataName
                    end

                    if data and data.start and data.duration then

                        if data.start + data.duration > now then
                            duration = data.duration
                            timeleft = data.duration + data.start - now
                            if data.isOwn == true and not claimedMyDebuffs[effect] then
                                isMyDebuff = true
                                claimedMyDebuffs[effect] = true
                            elseif playerClass == "PALADIN" and (string.find(effect, "Judgement of ") or string.find(effect, "Seal of ")) then
                                isMyDebuff = true
                                claimedMyDebuffs[effect] = true
                                -- Simple sync with SpellDB for Paladin debuffs
                                local dbData = SpellDB:FindEffectData(unitstr, 0, effect) or SpellDB:FindEffectData(plateName, 0, effect)
                                
                                if dbData and dbData.start then
                                    duration = dbData.duration
                                    timeleft = dbData.duration + dbData.start - now
                                end
                            end
                        end
                    end

                    -- If effect found but not tracked in SpellDB.objects, add it
                    -- This allows combat log refreshes to work on debuffs seen on nameplates
                    if effect and effect ~= "" and not timeleft then
                        local dbDuration = SpellDB:GetDuration(effect, 0)
                        if dbDuration > 0 then
                            -- Only track important/unique debuffs or our own to avoid table bloat
                            local isUnique = SpellDB.UNIQUE_DEBUFFS and SpellDB.UNIQUE_DEBUFFS[effect]
                            if isUnique or isMyDebuff then
                                SpellDB:AddEffect(unitstr or plateName, unitlevel, effect, dbDuration, isMyDebuff)
                            end
                        end
                    end
                end

                if effect and effect ~= "" and not duration then
                    duration = SpellDB:GetDuration(effect, 0)
                end
            end

            local uniqueClass = effect and SpellDB and SpellDB.UNIQUE_DEBUFFS and SpellDB.UNIQUE_DEBUFFS[effect]
            local isUnique = uniqueClass and (uniqueClass == true or uniqueClass == playerClass)

            -- Redundancy filter: Hide "Thunderfury's Blessing" if "Thunderfury" is also present
            local isRedundant = false
            if effect == "Thunderfury's Blessing" then
            -- Check if "Thunderfury" is also present on this unit
                for j = 1, 40 do
                    local t = UnitDebuff(effectiveUnit, j)
                    if not t then break end
                    local e = SpellDB:ScanDebuff(effectiveUnit, j)
                    if e == "Thunderfury" then
                        isRedundant = true
                        break
                    end
                end
            end

            if (Settings.showOnlyMyDebuffs and not isMyDebuff and not isUnique) or isRedundant then
            -- Skip this debuff
            else
                local debuff = nameplate.debuffs[debuffIndex]
                debuff.icon:SetTexture(texture)

                if stacks and stacks > 1 then
                    debuff.count:SetText(stacks)
                    debuff.count:SetAlpha(1)
                else
                    debuff.count:SetText("")
                    debuff.count:SetAlpha(0)
                end

                local displayTimeLeft = nil
                local debuffKey = (unitstr or plateName) .. "_" .. (effect or texture)

                if timeleft and timeleft > 0 then
                    displayTimeLeft = timeleft
                    debuffTimers[debuffKey] = {
                        startTime = now - (duration - timeleft),
                        duration = duration,
                        lastSeen = now
                    }
                else
                    local fallbackDuration = duration
                    if not fallbackDuration and effect and effect ~= "" and SpellDB then
                        fallbackDuration = SpellDB:GetDuration(effect)
                    end

                    fallbackDuration = (fallbackDuration and fallbackDuration > 0) and fallbackDuration or 1

                    if not debuffTimers[debuffKey] then
                        debuffTimers[debuffKey] = {
                            startTime = now,
                            duration = fallbackDuration,
                            lastStacks = stacks or 0
                        }
                    end
                    local cached = debuffTimers[debuffKey]
                    cached.lastSeen = now

                    -- Sync with SpellDB for Paladin debuffs if SpellDB has a newer start time
                    if playerClass == "PALADIN" and (string.find(effect, "Judgement of ") or string.find(effect, "Seal of ")) then
                        local dbData = SpellDB:FindEffectData(unitstr, 0, effect) or SpellDB:FindEffectData(plateName, 0, effect)

                        if dbData and dbData.start and dbData.start > (cached.startTime or 0) then
                            cached.startTime = dbData.start
                            cached.duration = dbData.duration or fallbackDuration
                        elseif dbData and dbData.start then
                            -- Aggressive fallback: if SpellDB has data, use it for Paladin debuffs
                            -- to prevent timers from getting stuck at 0.
                            cached.startTime = dbData.start
                            cached.duration = dbData.duration or fallbackDuration
                        end
                    end

                    local stacksChanged = stacks and cached.lastStacks and stacks ~= cached.lastStacks
                    if fallbackDuration > 1 and (cached.duration ~= fallbackDuration or (now - cached.startTime) > cached.duration or stacksChanged) then
                        cached.duration = fallbackDuration
                        cached.startTime = now
                    end
                    cached.lastStacks = stacks or 0

                    displayTimeLeft = cached.duration - (now - cached.startTime)
                end

                if Settings.showDebuffTimers and displayTimeLeft and displayTimeLeft > 0 then
                    debuff.expirationTime = now + displayTimeLeft
                    local text, r, g, b, a = GudaPlates_Debuffs:FormatTime(displayTimeLeft)
                    if debuff.cd and text and text ~= "" then
                        debuff.cd:SetText(text)
                        if r then debuff.cd:SetTextColor(r, g, b, a or 1) end
                        debuff.cd:SetAlpha(1)
                        debuff.cd:Show()
                    end
                    if debuff.cdframe then debuff.cdframe:Show() end
                else
                    debuff.expirationTime = 0
                    if debuff.cd then
                        debuff.cd:SetText("")
                        debuff.cd:SetAlpha(0)
                    end
                end

                debuff:Show()
                debuff.icon:SetAlpha(1)
                debuffIndex = debuffIndex + 1
            end
        end
    elseif plateName then
        if isTarget then
            for i = 1, 16 do
                if debuffIndex > MAX_DEBUFFS then break end

                local effect, rank, texture, stacks, dtype, duration, timeleft, isOwn
                if SpellDB then
                    effect, rank, texture, stacks, dtype, duration, timeleft, isOwn = SpellDB:UnitDebuff("target", i)
                else
                    texture, stacks = UnitDebuff("target", i)
                end

                if not texture then break end

                local isMyDebuff = false
                if isOwn == true and not claimedMyDebuffs[effect] then
                    isMyDebuff = true
                    claimedMyDebuffs[effect] = true
                elseif playerClass == "PALADIN" and (string.find(effect, "Judgement of ") or string.find(effect, "Seal of ")) then
                    isMyDebuff = true
                    claimedMyDebuffs[effect] = true
                    
                    -- Simple sync with SpellDB for Paladin debuffs
                    local dbData = SpellDB and SpellDB.objects and (SpellDB:FindEffectData(unitstr, 0, effect) or SpellDB:FindEffectData(plateName, 0, effect))

                    if dbData and dbData.start then
                        duration = dbData.duration
                        timeleft = dbData.duration + dbData.start - now
                    end
                end

                local uniqueClass = effect and SpellDB and SpellDB.UNIQUE_DEBUFFS and SpellDB.UNIQUE_DEBUFFS[effect]
                local isUnique = uniqueClass and (uniqueClass == true or uniqueClass == playerClass)

                -- Redundancy filter: Hide "Thunderfury's Blessing" if "Thunderfury" is also present
                local isRedundant = false
                if effect == "Thunderfury's Blessing" then
                -- Check if "Thunderfury" is also present on this unit
                    for j = 1, 40 do
                        local t = UnitDebuff("target", j)
                        if not t then break end
                        local e = SpellDB:ScanDebuff("target", j)
                        if e == "Thunderfury" then
                            isRedundant = true
                            break
                        end
                    end
                end

                if (Settings.showOnlyMyDebuffs and not isMyDebuff and not isUnique) or isRedundant then
                -- Skip this debuff
                else
                    local debuff = nameplate.debuffs[debuffIndex]
                    debuff.icon:SetTexture(texture)

                    if stacks and stacks > 1 then
                        debuff.count:SetText(stacks)
                        debuff.count:SetAlpha(1)
                    else
                        debuff.count:SetText("")
                        debuff.count:SetAlpha(0)
                    end

                    local displayTimeLeft = nil
                    if timeleft and timeleft > 0 then
                        displayTimeLeft = timeleft
                        local debuffKey = plateName .. "_" .. (effect or texture)
                        debuffTimers[debuffKey] = {
                            startTime = now - (duration - timeleft),
                            duration = duration,
                            lastSeen = now
                        }
                    else
                        local fallbackDuration = duration
                        if not fallbackDuration and effect and effect ~= "" and SpellDB then
                            fallbackDuration = SpellDB:GetDuration(effect)
                        end

                        fallbackDuration = (fallbackDuration and fallbackDuration > 0) and fallbackDuration or 1
                        local debuffKey = plateName .. "_" .. (effect or texture)

                        if not debuffTimers[debuffKey] then
                            debuffTimers[debuffKey] = {
                                startTime = now,
                                duration = fallbackDuration,
                                lastStacks = stacks or 0
                            }
                        end
                        local cached = debuffTimers[debuffKey]
                        cached.lastSeen = now

                        -- Sync with SpellDB for Paladin debuffs if SpellDB has a newer start time
                        if playerClass == "PALADIN" and (effect == "Seal of Wisdom" or effect == "Seal of Light" or effect == "Seal of the Crusader" or effect == "Seal of Justice" or
                            effect == "Judgement of Wisdom" or effect == "Judgement of Light" or effect == "Judgement of the Crusader" or effect == "Judgement of Justice" or effect == "Judgement") then
                            -- Check both GUID and Name records in SpellDB
                            local dbDataGUID = unitstr and SpellDB:FindEffectData(unitstr, 0, effect)
                            local dbDataName = plateName and SpellDB:FindEffectData(plateName, 0, effect)
                            
                            local dbData = nil
                            if dbDataGUID and dbDataName then
                                dbData = (dbDataGUID.start or 0) > (dbDataName.start or 0) and dbDataGUID or dbDataName
                            else
                                dbData = dbDataGUID or dbDataName
                            end

                            if dbData and dbData.start and dbData.start > (cached.startTime or 0) then
                                cached.startTime = dbData.start
                                cached.duration = dbData.duration or fallbackDuration
                            end
                        end

                        local stacksChanged = stacks and cached.lastStacks and stacks ~= cached.lastStacks
                        if fallbackDuration > 1 and (cached.duration ~= fallbackDuration or (now - cached.startTime) > cached.duration or stacksChanged) then
                            cached.duration = fallbackDuration
                            cached.startTime = now
                        end
                        cached.lastStacks = stacks or 0

                        displayTimeLeft = cached.duration - (now - cached.startTime)
                    end

                    if Settings.showDebuffTimers and displayTimeLeft and displayTimeLeft > 0 then
                        debuff.expirationTime = now + displayTimeLeft
                        local text, r, g, b, a = GudaPlates_Debuffs:FormatTime(displayTimeLeft)
                        if debuff.cd and text and text ~= "" then
                            debuff.cd:SetText(text)
                            if r then debuff.cd:SetTextColor(r, g, b, a or 1) end
                            debuff.cd:SetAlpha(1)
                            debuff.cd:Show()
                        end
                        if debuff.cdframe then debuff.cdframe:Show() end
                    else
                        debuff.expirationTime = 0
                        if debuff.cd then
                            debuff.cd:SetText("")
                            debuff.cd:SetAlpha(0)
                        end
                    end

                    debuff:Show()
                    debuff.icon:SetAlpha(1)
                    debuffIndex = debuffIndex + 1
                end
            end
        end
    end

    return debuffIndex - 1
end

function GudaPlates_Debuffs:UpdateDebuffPositions(nameplate, numDebuffs)
    if numDebuffs > 0 then
        for i = 1, numDebuffs do
            local debuff = nameplate.debuffs[i]
            if debuff then
                debuff:ClearAllPoints()

                if i == 1 then
                -- Anchor the first debuff to the left
                    if Settings.swapNameDebuff then
                        if nameplate.mana and nameplate.mana:IsShown() then
                            debuff:SetPoint("TOPLEFT", nameplate.mana, "BOTTOMLEFT", 0, -1)
                        else
                            debuff:SetPoint("TOPLEFT", nameplate.health, "BOTTOMLEFT", 0, -1)
                        end
                    else
                        if nameplate.mana and nameplate.mana:IsShown() then
                            debuff:SetPoint("BOTTOMLEFT", nameplate.mana, "TOPLEFT", 0, 1)
                        else
                            debuff:SetPoint("BOTTOMLEFT", nameplate.health, "TOPLEFT", 0, 1)
                        end
                    end
                else
                -- Anchor subsequent debuffs to the previous one
                    debuff:SetPoint("LEFT", nameplate.debuffs[i-1], "RIGHT", 1, 0)
                end
            end
        end
    end
end

local lastDebuffCleanup = 0
local lastFullCacheRefresh = 0

function GudaPlates_Debuffs:CleanupTimers()
    local now = GetTime()
    
    -- Full cache refresh every 1 seconds to force re-sync with SpellDB
    -- This ensures that any background database updates are reflected visually
    if now - lastFullCacheRefresh > 1 then
        lastFullCacheRefresh = now
        for key in pairs(self.timers) do
            self.timers[key] = nil
        end
    end

    -- Cleanup stale debuff timers every 0.5 seconds
    if now - lastDebuffCleanup > 0.5 then
        lastDebuffCleanup = now
        for key, data in pairs(self.timers) do
            if data.lastSeen and (now - data.lastSeen > 1) then
                self.timers[key] = nil
            end
        end
    end
end
