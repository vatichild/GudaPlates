-- GudaPlates Debuff Logic
GudaPlates_Debuffs = {}

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

function GudaPlates_Debuffs:FormatTime(remaining)
    if not remaining or remaining < 0 then return "", 1, 1, 1, 1 end

    if remaining > 3600 then
        return math.floor(remaining / 3600 + 0.5) .. "h", 0.5, 0.5, 0.5, 1
    elseif remaining > 60 then
        return math.floor(remaining / 60 + 0.5) .. "m", 0.5, 0.5, 0.5, 1
    elseif remaining > 10 then
        return math.floor(remaining + 0.5) .. "", 0.7, 0.7, 0.7, 1
    elseif remaining > 5 then
        return math.floor(remaining + 0.5) .. "", 1, 1, 0, 1
    elseif remaining > 0 then
        return string.format("%.1f", remaining), 1, 0, 0, 1
    end
    return "", 1, 1, 1, 1
end

function GudaPlates_Debuffs:GetSpellData(unit, name, effect, level)
    if not SpellDB or not SpellDB.objects then return nil end
    local dataUnit = unit and SpellDB:FindEffectData(unit, level or 0, effect)
    local dataName = name and SpellDB:FindEffectData(name, level or 0, effect)

    if dataUnit and dataName then
        return (dataUnit.start or 0) >= (dataName.start or 0) and dataUnit or dataName
    end
    return dataUnit or dataName
end

function GudaPlates_Debuffs:IsDebuffRedundant(unit, effect, index)
    if effect ~= "Thunderfury's Blessing" then return false end
    -- Check if "Thunderfury" is also present on this unit
    for j = 1, 40 do
        if j ~= index then
            local t = UnitDebuff(unit, j)
            if not t then break end
            local e = SpellDB:ScanDebuff(unit, j)
            if e == "Thunderfury" then return true end
        end
    end
    return false
end

-- Helper function to parse melee/ranged hits for Paladin Judgement refreshes
function GudaPlates_Debuffs:SealHandler(attacker, victim)
    if not attacker or not victim or playerClass ~= "PALADIN" then return end
    if victim == "you" then victim = "You" end

    local isTarget = UnitExists("target") and (UnitName("target") == victim or (victim == "You" and UnitIsUnit("player", "target")))
    local isOwn = (attacker == "You" or attacker == UnitName("player"))
    if not isOwn then return end

    local judgements = { "Judgement of Wisdom", "Judgement of Light", "Judgement of the Crusader", "Judgement of Justice", "Judgement", "Crusader Strike" }
    local guid = isTarget and UnitGUID and UnitGUID("target")

    for _, effect in pairs(judgements) do
        -- AGGRESSIVE REFRESH for current target or if it exists in DB
        local data = self:GetSpellData(guid, victim, effect, 0)
        if data or isTarget then
            local duration = SpellDB:GetDuration(effect, 0)
            SpellDB:RefreshEffect(victim, 0, effect, duration, true)
            if guid then SpellDB:RefreshEffect(guid, 0, effect, duration, true) end

            -- Clear visual cache
            self.timers[victim .. "_" .. effect] = nil
            if guid then self.timers[guid .. "_" .. effect] = nil end

            -- Handle icon variations
            local iconVar = string.gsub(effect, "Judgement of", "Seal of")
            if iconVar ~= effect then
                self.timers[victim .. "_" .. iconVar] = nil
                if guid then self.timers[guid .. "_" .. iconVar] = nil end
            end
        end
    end
end

function GudaPlates_Debuffs:GetMaxDebuffs()
    return MAX_DEBUFFS
end

function GudaPlates_Debuffs:GetDebuffSize()
    return DEBUFF_SIZE
end

local function DebuffOnUpdate()
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

        debuff:SetScript("OnUpdate", DebuffOnUpdate)

        debuff:Hide()
        nameplate.debuffs[i] = debuff
    end
end

function GudaPlates_Debuffs:UpdateDebuffs(nameplate, unitstr, plateName, isTarget, hasValidGUID, superwow_active)
    -- Reset all debuff icons
    for i = 1, MAX_DEBUFFS do
        local debuff = nameplate.debuffs[i]
        debuff:Hide()
        debuff.count:SetText("")
        debuff.expirationTime = 0
    end

    local debuffIndex = 1
    local now = GetTime()
    local claimedMyDebuffs = {}

    local effectiveUnit = (isTarget) and "target" or (superwow_active and hasValidGUID and unitstr) or nil
    -- If no effective unit (not target and not superwow guid), we can't reliably scan real-time debuffs
    -- however, we might still want to show tracked ones if we are looking at a nameplate by name.
    -- But Vanilla UnitDebuff needs a unit token.
    if not effectiveUnit and not plateName then return 0 end

    -- Use "target" as fallback for scanning if names match
    local scanUnit = effectiveUnit
    if not scanUnit and plateName and UnitExists("target") and UnitName("target") == plateName then
        scanUnit = "target"
    end

    if scanUnit then
        for i = 1, 40 do
            if debuffIndex > MAX_DEBUFFS then break end

            local texture, stacks = UnitDebuff(scanUnit, i)
            if not texture then break end

            local effect = SpellDB and SpellDB:ScanDebuff(scanUnit, i)
            if (not effect or effect == "") and SpellDB and SpellDB.textureToSpell then
                effect = SpellDB.textureToSpell[texture]
            end

            local isMyDebuff = false
            local duration, timeleft = nil, nil
            local unitlevel = (scanUnit == "target") and UnitLevel("target") or (unitstr and UnitLevel(unitstr)) or 0

            if effect and effect ~= "" then
                local data = self:GetSpellData(unitstr, plateName, effect, unitlevel)
                if data and data.start and data.duration then
                    if data.start + data.duration > now then
                        duration = data.duration
                        timeleft = data.duration + data.start - now
                        if data.isOwn == true and not claimedMyDebuffs[effect] then
                            isMyDebuff = true
                            claimedMyDebuffs[effect] = true
                        end
                    end
                end

                -- Paladin special handling
                if playerClass == "PALADIN" and (string.find(effect, "Judgement of ") or string.find(effect, "Seal of ") or effect == "Crusader Strike") then
                    isMyDebuff = true
                    claimedMyDebuffs[effect] = true
                    -- Sync with SpellDB
                    local dbData = self:GetSpellData(unitstr, plateName, effect, 0)
                    if dbData and dbData.start then
                        duration = dbData.duration
                        timeleft = dbData.duration + dbData.start - now
                    end
                end

                -- Auto-track if seen but not in DB
                if not timeleft then
                    local dbDuration = SpellDB:GetDuration(effect, 0)
                    if dbDuration > 0 then
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

            -- Filters
            local uniqueClass = effect and SpellDB and SpellDB.UNIQUE_DEBUFFS and SpellDB.UNIQUE_DEBUFFS[effect]
            local isUnique = uniqueClass and (uniqueClass == true or uniqueClass == playerClass)
            local isRedundant = self:IsDebuffRedundant(scanUnit, effect, i)

            if (Settings.showOnlyMyDebuffs and not isMyDebuff and not isUnique) or isRedundant then
                -- Skip
            else
                local debuff = nameplate.debuffs[debuffIndex]
                debuff.icon:SetTexture(texture)
                debuff.count:SetText((stacks and stacks > 1) and stacks or "")
                debuff.count:SetAlpha((stacks and stacks > 1) and 1 or 0)

                local debuffKey = (unitstr or plateName) .. "_" .. (effect or texture)
                local displayTimeLeft = nil

                if timeleft and timeleft > 0 then
                    displayTimeLeft = timeleft
                    debuffTimers[debuffKey] = {
                        startTime = now - (duration - timeleft),
                        duration = duration,
                        lastSeen = now
                    }
                else
                    local fallbackDuration = duration or (effect and effect ~= "" and SpellDB:GetDuration(effect)) or 1
                    if not debuffTimers[debuffKey] then
                        debuffTimers[debuffKey] = { startTime = now, duration = fallbackDuration, lastStacks = stacks or 0 }
                    end
                    
                    local cached = debuffTimers[debuffKey]
                    cached.lastSeen = now

                    -- Sync with SpellDB for Paladin
                    if playerClass == "PALADIN" and effect and (string.find(effect, "Judgement of ") or string.find(effect, "Seal of ")) then
                        local dbData = self:GetSpellData(unitstr, plateName, effect, 0)
                        if dbData and dbData.start then
                            cached.startTime = dbData.start
                            cached.duration = dbData.duration or fallbackDuration
                        end
                    end

                    local stacksChanged = stacks and cached.lastStacks and stacks ~= cached.lastStacks
                    local isPaladin = playerClass == "PALADIN" and effect and (string.find(effect, "Judgement of ") or string.find(effect, "Seal of "))

                    if fallbackDuration > 1 and (cached.duration ~= fallbackDuration or (now - cached.startTime) > cached.duration or stacksChanged) then
                        if not isPaladin or (now - cached.startTime) > cached.duration then
                            cached.duration = fallbackDuration
                            cached.startTime = now
                        end
                    end
                    cached.lastStacks = stacks or 0
                    displayTimeLeft = cached.duration - (now - cached.startTime)
                end

                if Settings.showDebuffTimers and displayTimeLeft and displayTimeLeft > 0 then
                    debuff.expirationTime = now + displayTimeLeft
                    local text, r, g, b, a = self:FormatTime(displayTimeLeft)
                    debuff.cd:SetText(text)
                    if r then debuff.cd:SetTextColor(r, g, b, a) end
                    debuff.cd:SetAlpha(1)
                    debuff.cdframe:Show()
                else
                    debuff.expirationTime = 0
                    debuff.cd:SetText("")
                end

                debuff:Show()
                debuffIndex = debuffIndex + 1
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

    -- Full cache wipe every 2 seconds to force re-sync with SpellDB
    if now - lastFullCacheRefresh > 2 then
        lastFullCacheRefresh = now
        for key in pairs(self.timers) do
            self.timers[key] = nil
        end
    end

    -- Cleanup stale (unseen) debuff timers every 0.5 seconds
    if now - lastDebuffCleanup > 0.5 then
        lastDebuffCleanup = now
        for key, data in pairs(self.timers) do
            if data.lastSeen and (now - data.lastSeen > 1) then
                self.timers[key] = nil
            end
        end
    end
end
