-- GudaPlates Debuff Logic
GudaPlates_Debuffs = {}

-- Performance: Upvalue frequently used globals
local pairs = pairs
local ipairs = ipairs
local string_find = string.find
local string_format = string.format
local string_gsub = string.gsub
local string_sub = string.sub
local math_floor = math.floor
local GetTime = GetTime
local UnitDebuff = UnitDebuff
local UnitGUID = UnitGUID
local CreateFrame = CreateFrame

local SpellDB = GudaPlates_SpellDB
local Settings = GudaPlates.Settings
local _, playerClass = UnitClass("player")
playerClass = playerClass or ""

-- Constants
local MAX_DEBUFFS = 16
local DEBUFF_SIZE = 16

-- Performance: Pre-defined spell lists (avoid creating tables in hot paths)
-- Note: Crusader Strike is NOT a judgement - it's a separate debuff
local JUDGEMENT_EFFECTS = {
    "Judgement of Wisdom", "Judgement of Light", "Judgement of the Crusader",
    "Judgement of Justice", "Judgement"
}

-- Debuff timer tracking: stores {startTime, duration} by "targetName_texture" key
GudaPlates_Debuffs.timers = {}
local debuffTimers = GudaPlates_Debuffs.timers

function GudaPlates_Debuffs:FormatTime(remaining)
    if not remaining or remaining < 0 then return "", 1, 1, 1, 1 end

    if remaining > 3600 then
        return math_floor(remaining / 3600 + 0.5) .. "h", 0.5, 0.5, 0.5, 1
    elseif remaining > 60 then
        return math_floor(remaining / 60 + 0.5) .. "m", 0.5, 0.5, 0.5, 1
    elseif remaining > 10 then
        return math_floor(remaining + 0.5) .. "", 0.7, 0.7, 0.7, 1
    elseif remaining > 5 then
        return math_floor(remaining + 0.5) .. "", 1, 1, 0, 1
    elseif remaining > 0 then
        return string_format("%.1f", remaining), 1, 0, 0, 1
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

-- Debug flag for judgement refresh (toggle with /gp debugjudge)
local DEBUG_JUDGEMENT = false
GudaPlates_Debuffs.DEBUG_JUDGEMENT = DEBUG_JUDGEMENT

-- Helper function to refresh judgements on the current target (ShaguPlates-style)
-- Only refreshes judgements that ALREADY EXIST on the target
-- This is called on ANY melee hit - we refresh judgements on current target
local function RefreshJudgementsOnTarget()
    local showDebug = DEBUG_JUDGEMENT or GudaPlates_Debuffs.DEBUG_JUDGEMENT
    if playerClass ~= "PALADIN" then return end
    if not UnitExists("target") then
        if showDebug then
            DEFAULT_CHAT_FRAME:AddMessage("[Judge] No target exists")
        end
        return
    end
    if not SpellDB or not SpellDB.objects then
        if showDebug then
            DEFAULT_CHAT_FRAME:AddMessage("[Judge] SpellDB or SpellDB.objects not available")
        end
        return
    end

    local name = UnitName("target")
    local level = UnitLevel("target") or 0
    local guid = UnitGUID and UnitGUID("target")

    -- Check if we have any data for this target
    local hasNameData = name and SpellDB.objects[name]
    local hasGuidData = guid and SpellDB.objects[guid]

    if showDebug then
        DEFAULT_CHAT_FRAME:AddMessage(string_format("[Judge] Target: %s, lvl=%d, hasName=%s, hasGuid=%s",
            name or "nil", level, tostring(hasNameData ~= nil), tostring(hasGuidData ~= nil)))
        -- Dump what levels we have for this target
        if hasNameData then
            local levels = ""
            for lvl, _ in pairs(SpellDB.objects[name]) do
                levels = levels .. tostring(lvl) .. " "
            end
            DEFAULT_CHAT_FRAME:AddMessage("[Judge] Name data levels: " .. levels)
        end
        if hasGuidData then
            local levels = ""
            for lvl, _ in pairs(SpellDB.objects[guid]) do
                levels = levels .. tostring(lvl) .. " "
            end
            DEFAULT_CHAT_FRAME:AddMessage("[Judge] GUID data levels: " .. levels)
        end
    end

    if not hasNameData and not hasGuidData then return end

    for _, effect in ipairs(JUDGEMENT_EFFECTS) do
        local found = false
        local duration = SpellDB:GetDuration(effect, 0) or 10

        -- Check by name: first try exact level, then level 0, then search all levels
        if hasNameData then
            if SpellDB.objects[name][level] and SpellDB.objects[name][level][effect] then
                SpellDB.objects[name][level][effect].start = GetTime()
                SpellDB.objects[name][level][effect].duration = duration
                found = true
                if showDebug then
                    DEFAULT_CHAT_FRAME:AddMessage(string_format("[Judge] Refreshed %s on %s (name+lvl=%d)", effect, name, level))
                end
            elseif SpellDB.objects[name][0] and SpellDB.objects[name][0][effect] then
                SpellDB.objects[name][0][effect].start = GetTime()
                SpellDB.objects[name][0][effect].duration = duration
                found = true
                if showDebug then
                    DEFAULT_CHAT_FRAME:AddMessage(string_format("[Judge] Refreshed %s on %s (name+0)", effect, name))
                end
            else
                -- Fallback: search all levels (in case stored at different level)
                for lvl, effects in pairs(SpellDB.objects[name]) do
                    if effects[effect] then
                        effects[effect].start = GetTime()
                        effects[effect].duration = duration
                        found = true
                        if showDebug then
                            DEFAULT_CHAT_FRAME:AddMessage(string_format("[Judge] Refreshed %s on %s (name+anylvl=%d)", effect, name, lvl))
                        end
                        break
                    end
                end
            end
        end

        -- Check by GUID: first try exact level, then level 0, then search all levels
        if hasGuidData and not found then
            if SpellDB.objects[guid][level] and SpellDB.objects[guid][level][effect] then
                SpellDB.objects[guid][level][effect].start = GetTime()
                SpellDB.objects[guid][level][effect].duration = duration
                found = true
                if showDebug then
                    DEFAULT_CHAT_FRAME:AddMessage(string_format("[Judge] Refreshed %s on GUID (guid+lvl=%d)", effect, level))
                end
            elseif SpellDB.objects[guid][0] and SpellDB.objects[guid][0][effect] then
                SpellDB.objects[guid][0][effect].start = GetTime()
                SpellDB.objects[guid][0][effect].duration = duration
                found = true
                if showDebug then
                    DEFAULT_CHAT_FRAME:AddMessage(string_format("[Judge] Refreshed %s on GUID (guid+0)", effect))
                end
            else
                -- Fallback: search all levels
                for lvl, effects in pairs(SpellDB.objects[guid]) do
                    if effects[effect] then
                        effects[effect].start = GetTime()
                        effects[effect].duration = duration
                        found = true
                        if showDebug then
                            DEFAULT_CHAT_FRAME:AddMessage(string_format("[Judge] Refreshed %s on GUID (guid+anylvl=%d)", effect, lvl))
                        end
                        break
                    end
                end
            end
        end

        -- Clear visual cache if we refreshed
        if found then
            GudaPlates_Debuffs.timers[name .. "_" .. effect] = nil
            if guid then GudaPlates_Debuffs.timers[guid .. "_" .. effect] = nil end

            -- Handle icon variations (Seal of X icons for Judgement of X)
            local iconVar = string_gsub(effect, "Judgement of", "Seal of")
            if iconVar ~= effect then
                GudaPlates_Debuffs.timers[name .. "_" .. iconVar] = nil
                if guid then GudaPlates_Debuffs.timers[guid .. "_" .. iconVar] = nil end
            end
        end
    end
end

-- Function to toggle judgement debug
function GudaPlates_Debuffs:ToggleJudgeDebug()
    DEBUG_JUDGEMENT = not DEBUG_JUDGEMENT
    GudaPlates_Debuffs.DEBUG_JUDGEMENT = DEBUG_JUDGEMENT
    DEFAULT_CHAT_FRAME:AddMessage("[GudaPlates] Judgement debug: " .. (DEBUG_JUDGEMENT and "ON" or "OFF"))
end

-- Debug function to show tracked judgements on current target
function GudaPlates_Debuffs:ShowJudgements()
    if not UnitExists("target") then
        DEFAULT_CHAT_FRAME:AddMessage("[GudaPlates] No target selected")
        return
    end

    local name = UnitName("target")
    local level = UnitLevel("target") or 0
    local guid = UnitGUID and UnitGUID("target")

    DEFAULT_CHAT_FRAME:AddMessage("[GudaPlates] === Judgements on " .. (name or "target") .. " ===")

    if not SpellDB or not SpellDB.objects then
        DEFAULT_CHAT_FRAME:AddMessage("[GudaPlates] SpellDB not available")
        return
    end

    -- Check by name
    if SpellDB.objects[name] then
        DEFAULT_CHAT_FRAME:AddMessage("[GudaPlates] Data exists for name: " .. name)
        for lvl, effects in pairs(SpellDB.objects[name]) do
            for eff, data in pairs(effects) do
                if string_find(eff, "Judgement") then
                    local timeLeft = data.duration - (GetTime() - data.start)
                    DEFAULT_CHAT_FRAME:AddMessage(string_format("  [%s] lvl=%d: %s %.1fs left", name, lvl, eff, timeLeft))
                end
            end
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage("[GudaPlates] No data for name: " .. name)
    end

    -- Check by GUID
    if guid and SpellDB.objects[guid] then
        DEFAULT_CHAT_FRAME:AddMessage("[GudaPlates] Data exists for GUID: " .. guid)
        for lvl, effects in pairs(SpellDB.objects[guid]) do
            for eff, data in pairs(effects) do
                if string_find(eff, "Judgement") then
                    local timeLeft = data.duration - (GetTime() - data.start)
                    DEFAULT_CHAT_FRAME:AddMessage(string_format("  [GUID] lvl=%d: %s %.1fs left", lvl, eff, timeLeft))
                end
            end
        end
    elseif guid then
        DEFAULT_CHAT_FRAME:AddMessage("[GudaPlates] No data for GUID: " .. guid)
    end

    DEFAULT_CHAT_FRAME:AddMessage("[GudaPlates] === End of judgements ===")
end

-- Helper function to parse melee/ranged hits for Paladin Judgement refreshes
-- ShaguPlates-style: On ANY melee hit, refresh judgements on CURRENT TARGET
function GudaPlates_Debuffs:SealHandler(attacker, victim)
    if playerClass ~= "PALADIN" then return end

    -- Only process our own hits
    local isOwn = (attacker == "You" or attacker == UnitName("player"))
    if not isOwn then return end

    if DEBUG_JUDGEMENT or GudaPlates_Debuffs.DEBUG_JUDGEMENT then
        DEFAULT_CHAT_FRAME:AddMessage(string_format("[Judge] SealHandler: attacker=%s, victim=%s", attacker or "nil", victim or "nil"))
    end

    -- Refresh judgements on current target (ShaguPlates approach)
    RefreshJudgementsOnTarget()
end

-- TurtleWoW: Holy Strike also refreshes judgements (custom Paladin ability)
-- Called from CHAT_MSG_SPELL_SELF_DAMAGE when Holy Strike hits
function GudaPlates_Debuffs:HolyStrikeHandler(msg)
    if not msg or playerClass ~= "PALADIN" then return end

    -- Check if this is a Holy Strike hit (pattern from ShaguPlates turtle-wow module)
    -- "Your Holy Strike hits X for Y."
    local holyStrike = string_find(string_sub(msg, 6, 17), "Holy Strike")
    if not holyStrike then return end

    -- Only refresh if the spell actually hit (not a miss/resist)
    -- In the combat log, a successful hit will have damage in it
    if not string_find(msg, "%d+") then return end

    RefreshJudgementsOnTarget()
end

function GudaPlates_Debuffs:GetMaxDebuffs()
    return MAX_DEBUFFS
end

function GudaPlates_Debuffs:GetDebuffSize()
    return Settings.debuffIconSize or 16
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
    local plateName = nameplate:GetName() or "UnknownPlate"
    for i = 1, MAX_DEBUFFS do
        local debuff = CreateFrame("Frame", plateName .. "Debuff" .. i, nameplate)
        debuff:SetWidth(DEBUFF_SIZE)
        debuff:SetHeight(DEBUFF_SIZE)
        debuff:SetFrameLevel(nameplate.health:GetFrameLevel() + 5)
        debuff:EnableMouse(false)

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
        debuff.cdframe:EnableMouse(false)

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
    local size = self:GetDebuffSize()
    for i = 1, MAX_DEBUFFS do
        local debuff = nameplate.debuffs[i]
        debuff:SetWidth(size)
        debuff:SetHeight(size)
        
        -- Scale fonts proportionally
        local cdFontSize = math_floor(size * 0.625 + 0.5) -- 10 for 16px
        local countFontSize = math_floor(size * 0.5625 + 0.5) -- 9 for 16px
        
        debuff.cd:SetFont(Settings.textFont, cdFontSize, "OUTLINE")
        debuff.count:SetFont(Settings.textFont, countFontSize, "OUTLINE")

        debuff:Hide()
        debuff.count:SetText("")
        debuff.count:SetTextColor(1, 1, 1, 1) -- Reset to white
        debuff.expirationTime = 0
    end

    local now = GetTime()
    local claimedMyDebuffs = {}

    local effectiveUnit = (isTarget) and "target" or (superwow_active and hasValidGUID and unitstr) or nil
    if not effectiveUnit and not plateName then return 0 end

    local scanUnit = effectiveUnit
    if not scanUnit and plateName and UnitExists("target") and UnitName("target") == plateName then
        scanUnit = "target"
    end

    if not scanUnit then return 0 end

    -- ============================================
    -- PHASE 1: Collect all debuffs and count OWNER_BOUND instances
    -- ============================================
    local collectedDebuffs = {}  -- Array of debuff data
    local ownerBoundCounts = {}  -- Count of instances per OWNER_BOUND spell name
    local ownerBoundFirst = {}   -- First occurrence data for each OWNER_BOUND spell

    for i = 1, 40 do
        local texture, stacks = UnitDebuff(scanUnit, i)
        if not texture then break end

        local effect = SpellDB and SpellDB:ScanDebuff(scanUnit, i)
        if (not effect or effect == "") and SpellDB and SpellDB.textureToSpell then
            effect = SpellDB.textureToSpell[texture]
        end

        local isOwnerBound = effect and SpellDB and SpellDB.OWNER_BOUND_DEBUFFS and SpellDB.OWNER_BOUND_DEBUFFS[effect]

        -- Count OWNER_BOUND_DEBUFFS instances
        if isOwnerBound then
            ownerBoundCounts[effect] = (ownerBoundCounts[effect] or 0) + 1
            if not ownerBoundFirst[effect] then
                ownerBoundFirst[effect] = { index = i, texture = texture, stacks = stacks }
            end
        end

        -- Store all debuff data for phase 2
        table.insert(collectedDebuffs, {
            index = i,
            texture = texture,
            stacks = stacks,
            effect = effect,
            isOwnerBound = isOwnerBound
        })
    end

    -- ============================================
    -- PHASE 2: Display debuffs with filtering at render time
    -- ============================================
    local debuffIndex = 1
    local displayedOwnerBound = {}  -- Track which OWNER_BOUND spells we've displayed
    local unitlevel = (scanUnit == "target") and UnitLevel("target") or (unitstr and UnitLevel(unitstr)) or 0

    for _, debuffData in ipairs(collectedDebuffs) do
        if debuffIndex > MAX_DEBUFFS then break end

        local effect = debuffData.effect
        local texture = debuffData.texture
        local stacks = debuffData.stacks
        local isOwnerBound = debuffData.isOwnerBound

        -- Rogue poisons: Early detection for visibility exception
        -- Poisons are weapon procs with no ownership data, must be force-allowed for Rogues
        -- Check both effect name AND texture (texture-based detection for when tooltip scanning fails)
        local isRoguePoison = false
        if playerClass == "ROGUE" then
            -- Check by effect name first
            if effect and SpellDB.ROGUE_POISONS and SpellDB.ROGUE_POISONS[effect] then
                isRoguePoison = true
            -- Fallback: check by texture if effect name is missing or unknown
            elseif texture and SpellDB.ROGUE_POISON_TEXTURES and SpellDB.ROGUE_POISON_TEXTURES[texture] then
                isRoguePoison = true
                -- Also set effect name from texture for timer tracking
                if not effect or effect == "" then
                    effect = SpellDB.ROGUE_POISON_TEXTURES[texture]
                end
            end
        end

        -- Hunter traps: Show for Hunter players only when "Only My Debuffs" is enabled
        -- Traps are placed on ground and triggered by enemies, so ownership can't be tracked reliably
        -- Check both effect name AND texture (texture-based detection for when tooltip scanning fails)
        local isHunterTrap = false
        if playerClass == "HUNTER" then
            -- Check by effect name first
            if effect and SpellDB.HUNTER_TRAPS and SpellDB.HUNTER_TRAPS[effect] then
                isHunterTrap = true
            -- Fallback: check by texture if effect name is missing or unknown
            elseif texture and SpellDB.HUNTER_TRAP_TEXTURES and SpellDB.HUNTER_TRAP_TEXTURES[texture] then
                isHunterTrap = true
                -- Always use the correct effect name from texture mapping for timer tracking
                -- This overrides potentially incorrect tooltip-scanned names
                effect = SpellDB.HUNTER_TRAP_TEXTURES[texture]
            end
        end

        -- Hunter stings: For Hunter players, ensure reliable display
        -- Ownership tracking can sometimes fail, so we force-detect these
        local isHunterSting = false
        if playerClass == "HUNTER" then
            -- Check by effect name first
            if effect and SpellDB.HUNTER_STINGS and SpellDB.HUNTER_STINGS[effect] then
                isHunterSting = true
            -- Fallback: check by texture if effect name is missing or unknown
            elseif texture and SpellDB.HUNTER_STING_TEXTURES and SpellDB.HUNTER_STING_TEXTURES[texture] then
                isHunterSting = true
                -- Always use the correct effect name from texture mapping for timer tracking
                effect = SpellDB.HUNTER_STING_TEXTURES[texture]
            end
        end

        -- Determine ownership
        local isMyDebuff = false
        local duration, timeleft = nil, nil

        -- Force Rogue poisons as "mine" - they bypass all ownership checks
        if isRoguePoison then
            isMyDebuff = true
        end

        -- Force Hunter traps as "mine" for Hunter players - for timer tracking
        if isHunterTrap and playerClass == "HUNTER" then
            isMyDebuff = true
        end

        -- Force Hunter stings as "mine" for Hunter players - ensures reliable display
        if isHunterSting then
            isMyDebuff = true
        end

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
            if playerClass == "PALADIN" and (string_find(effect, "Judgement of ") or string_find(effect, "Seal of ") or effect == "Crusader Strike" or effect == "Hammer of Justice" or effect == "Repentance") then
                isMyDebuff = true
                claimedMyDebuffs[effect] = true
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
                    local isUnique = SpellDB.SHARED_DEBUFFS and SpellDB.SHARED_DEBUFFS[effect]
                    if isUnique or isMyDebuff then
                        -- Store by BOTH name and GUID for reliable lookup
                        SpellDB:AddEffect(plateName, unitlevel, effect, dbDuration, isMyDebuff)
                        if unitstr and unitstr ~= plateName then
                            SpellDB:AddEffect(unitstr, unitlevel, effect, dbDuration, isMyDebuff)
                        end
                    end
                end
            end
        end

        if effect and effect ~= "" and not duration then
            duration = SpellDB:GetDuration(effect, 0)
        end

        -- ============================================
        -- OWNER_BOUND_DEBUFFS: Special display logic
        -- Show at most ONE icon per spell name when filtering is enabled
        -- ============================================
        if isOwnerBound then
            -- Skip if we've already displayed this OWNER_BOUND spell
            if displayedOwnerBound[effect] then
                -- Skip duplicate - do not display
            else
                -- Check if player owns this debuff
                local ownerCheckUnit = unitstr or plateName
                local isMyOwnerBound = false

                if SpellDB.IsOwnerBoundDebuffMine then
                    isMyOwnerBound = SpellDB:IsOwnerBoundDebuffMine(ownerCheckUnit, effect)
                    if not isMyOwnerBound and plateName and plateName ~= ownerCheckUnit then
                        isMyOwnerBound = SpellDB:IsOwnerBoundDebuffMine(plateName, effect)
                    end
                end

                -- Also check isMyDebuff from SpellDB tracking
                if isMyDebuff then
                    isMyOwnerBound = true
                end

                if isMyOwnerBound then
                    -- Display ONE icon for this OWNER_BOUND debuff
                    displayedOwnerBound[effect] = true

                    local debuff = nameplate.debuffs[debuffIndex]
                    debuff.icon:SetTexture(texture)

                    -- Show instance count as blue overlay if multiple instances exist
                    local instanceCount = ownerBoundCounts[effect] or 1
                    if instanceCount > 1 then
                        debuff.count:SetText(instanceCount)
                        debuff.count:SetTextColor(0.3, 0.7, 1, 1) -- Blue color for instance count
                        debuff.count:SetAlpha(1)
                    elseif stacks and stacks > 1 then
                        debuff.count:SetText(stacks)
                        debuff.count:SetTextColor(1, 1, 1, 1) -- White for normal stacks
                        debuff.count:SetAlpha(1)
                    else
                        debuff.count:SetText("")
                        debuff.count:SetAlpha(0)
                    end

                    -- Timer handling
                    local debuffKey = (unitstr or plateName) .. "_" .. effect
                    local displayTimeLeft = nil

                    if timeleft and timeleft > 0 then
                        displayTimeLeft = timeleft
                        debuffTimers[debuffKey] = {
                            startTime = now - (duration - timeleft),
                            duration = duration,
                            lastSeen = now
                        }
                    else
                        local fallbackDuration = duration or SpellDB:GetDuration(effect, 0)
                        if fallbackDuration <= 0 then fallbackDuration = 30 end
                        
                        if not debuffTimers[debuffKey] then
                            debuffTimers[debuffKey] = { startTime = now, duration = fallbackDuration, lastStacks = stacks or 0 }
                        end
                        local cached = debuffTimers[debuffKey]
                        cached.lastSeen = now
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
                -- If not owned, skip entirely (don't display)
            end
        else
            -- ============================================
            -- Non-OWNER_BOUND debuffs: Normal filtering
            -- ============================================
            local uniqueClass = effect and SpellDB and SpellDB.SHARED_DEBUFFS and SpellDB.SHARED_DEBUFFS[effect]
            local isUnique = uniqueClass and (uniqueClass == true or uniqueClass == playerClass)
            local isRedundant = self:IsDebuffRedundant(scanUnit, effect, debuffData.index)

            -- Rogue poisons: Force-allow at acceptance stage
            -- Bypass redundancy and treat as owned
            if isRoguePoison then
                isRedundant = false
            end

            -- Hunter traps: Force-allow, bypass redundancy check
            if isHunterTrap then
                isRedundant = false
            end

            local shouldDisplay = true
            if Settings.showOnlyMyDebuffs and not isMyDebuff and not isUnique and not isOwnerBound and not isHunterTrap then
                shouldDisplay = false
            end
            if isRedundant then
                shouldDisplay = false
            end

            if shouldDisplay then
                local debuff = nameplate.debuffs[debuffIndex]
                debuff.icon:SetTexture(texture)
                debuff.count:SetText((stacks and stacks > 1) and stacks or "")
                debuff.count:SetTextColor(1, 1, 1, 1) -- White for normal stacks
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
                    local fallbackDuration = duration or (effect and effect ~= "" and SpellDB:GetDuration(effect, 0)) or 12
                    if not debuffTimers[debuffKey] then
                        debuffTimers[debuffKey] = { startTime = now, duration = fallbackDuration, lastStacks = stacks or 0 }
                    end

                    local cached = debuffTimers[debuffKey]
                    cached.lastSeen = now

                    -- Sync with SpellDB for Paladin (only if SpellDB data is not expired)
                    local isPaladin = playerClass == "PALADIN" and effect and (string_find(effect, "Judgement of ") or string_find(effect, "Seal of "))
                    local syncedFromSpellDB = false
                    if isPaladin then
                        local dbData = self:GetSpellData(unitstr, plateName, effect, 0)
                        if dbData and dbData.start and dbData.duration then
                            -- Only sync if SpellDB data is NOT expired
                            local spellDBTimeLeft = dbData.duration - (now - dbData.start)
                            if spellDBTimeLeft > 0 then
                                cached.startTime = dbData.start
                                cached.duration = dbData.duration
                                syncedFromSpellDB = true
                            end
                        end
                    end

                    local stacksChanged = stacks and cached.lastStacks and stacks ~= cached.lastStacks

                    -- For Paladins: don't auto-reset expired judgements - let RefreshJudgementsOnTarget handle it
                    -- For other classes: reset timer if expired or duration changed
                    if not isPaladin then
                        if fallbackDuration > 1 and (cached.duration ~= fallbackDuration or (now - cached.startTime) > cached.duration or stacksChanged) then
                            cached.duration = fallbackDuration
                            cached.startTime = now
                        end
                    elseif not syncedFromSpellDB then
                        -- Paladin judgement with expired SpellDB - don't reset, but cap at 0
                        -- The timer will show as expired; if we're hitting the target,
                        -- RefreshJudgementsOnTarget will update SpellDB with fresh data
                        if (now - cached.startTime) > cached.duration then
                            -- Timer expired - show 0 or let it disappear naturally
                            -- Don't reset to 10 - that causes the "stuck" issue
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
local lastOwnerBoundCleanup = 0

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

    -- Cleanup expired OWNER_BOUND_DEBUFFS cache every 5 seconds
    if now - lastOwnerBoundCleanup > 5 then
        lastOwnerBoundCleanup = now
        if SpellDB and SpellDB.CleanupOwnerBoundCache then
            SpellDB:CleanupOwnerBoundCache()
        end
    end
end
