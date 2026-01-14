-- =============================================================================
-- GudaPlates_Hide.lua
-- =============================================================================
-- Element Hiding Module
-- Responsible for hiding original Blizzard nameplate elements
--
-- Exports:
--   GudaPlates_Hide.DisableObject(object) - Set alpha to 0
--   GudaPlates_Hide.HideVisual(object) - Hide with texture/text clear
--   GudaPlates_Hide.HideOriginalElements(frame, options) - Hide all original elements
--   GudaPlates_Hide.HideHealthbar(healthbar) - Hide healthbar specifically
--   GudaPlates_Hide.HideRegions(frame, skipRaidIcon) - Hide frame regions
--   GudaPlates_Hide.HideShaguTweaksFrame(frame) - Hide ShaguTweaks .new frame
-- =============================================================================

GudaPlates_Hide = {}

-- =============================================================================
-- Basic Hide Helpers
-- =============================================================================

-- Simple alpha hide
function GudaPlates_Hide.DisableObject(object)
    if not object then return end
    if object.SetAlpha then object:SetAlpha(0) end
end

-- Hide with texture/text color clear
function GudaPlates_Hide.HideVisual(object)
    if not object then return end
    if object.SetAlpha then object:SetAlpha(0) end
    if object.GetObjectType then
        local otype = object:GetObjectType()
        if otype == "Texture" then
            object:SetTexture("")
        elseif otype == "FontString" then
            object:SetTextColor(0, 0, 0, 0)
        end
    end
end

-- =============================================================================
-- Nameplate Element Hiding
-- =============================================================================

-- Hide healthbar
function GudaPlates_Hide.HideHealthbar(healthbar)
    if not healthbar then return end
    if healthbar.SetStatusBarTexture then healthbar:SetStatusBarTexture("") end
    if healthbar.SetAlpha then healthbar:SetAlpha(0) end
end

-- Hide a single region (texture or fontstring)
local function HideRegion(region, isRaidIcon)
    if not region then return end

    if region.SetAlpha then region:SetAlpha(0) end

    if region.GetObjectType then
        local otype = region:GetObjectType()
        if otype == "FontString" then
            if region.SetTextColor then region:SetTextColor(0, 0, 0, 0) end
            if region.Hide then region:Hide() end
        elseif otype == "Texture" and not isRaidIcon then
            -- Don't clear raid icon texture
            if region.SetTexture then region:SetTexture("") end
        end
    end
end

-- Hide all regions on a frame
-- Vanilla order: border(1), glow(2), name(3), level(4), levelicon(5), raidicon(6)
function GudaPlates_Hide.HideRegions(frame, skipRaidIcon)
    if not frame then return end

    local r1, r2, r3, r4, r5, r6 = frame:GetRegions()

    -- r1 = border texture
    if r1 and r1.SetAlpha then r1:SetAlpha(0) end

    -- r2 = glow texture
    if r2 and r2.SetAlpha then r2:SetAlpha(0) end

    -- r3 = name FontString
    if r3 then
        if r3.SetAlpha then r3:SetAlpha(0) end
        if r3.SetTextColor then r3:SetTextColor(0, 0, 0, 0) end
        if r3.Hide then r3:Hide() end
    end

    -- r4 = level FontString
    if r4 then
        if r4.SetAlpha then r4:SetAlpha(0) end
        if r4.SetTextColor then r4:SetTextColor(0, 0, 0, 0) end
        if r4.Hide then r4:Hide() end
    end

    -- r5 = level icon texture
    if r5 and r5.SetAlpha then r5:SetAlpha(0) end

    -- r6 = raid icon - only hide if not skipping
    if r6 and not skipRaidIcon then
        if r6.SetAlpha then r6:SetAlpha(0) end
    end
end

-- Hide ShaguTweaks .new frame if present
function GudaPlates_Hide.HideShaguTweaksFrame(frame)
    if not frame or not frame.new then return end

    if frame.new.SetAlpha then frame.new:SetAlpha(0) end
    if frame.new.Hide then frame.new:Hide() end

    -- Also hide regions in the .new frame
    local nr1, nr2, nr3, nr4 = frame.new:GetRegions()
    if nr1 and nr1.SetTextColor then nr1:SetTextColor(0, 0, 0, 0) end
    if nr2 and nr2.SetTextColor then nr2:SetTextColor(0, 0, 0, 0) end
    if nr3 and nr3.SetTextColor then nr3:SetTextColor(0, 0, 0, 0) end
    if nr4 and nr4.SetTextColor then nr4:SetTextColor(0, 0, 0, 0) end
end

-- =============================================================================
-- Main Hide Function
-- =============================================================================

-- Hide all original nameplate elements on a frame
-- Options:
--   skipRaidIcon: boolean (default true) - Don't hide raid icon (we reparent it)
--   hideChildren: boolean (default false) - Hide all children except our overlay
--   nameplate: our GudaPlates overlay frame (needed for hideChildren)
--   healthbar: cached healthbar reference (optional, will find if not provided)
function GudaPlates_Hide.HideOriginalElements(frame, options)
    if not frame then return end

    options = options or {}
    local skipRaidIcon = options.skipRaidIcon ~= false  -- default true

    -- Hide healthbar
    local healthbar = options.healthbar or frame.healthbar or frame:GetChildren()
    GudaPlates_Hide.HideHealthbar(healthbar)

    -- Hide all regions
    GudaPlates_Hide.HideRegions(frame, skipRaidIcon)

    -- Hide ShaguTweaks .new frame
    GudaPlates_Hide.HideShaguTweaksFrame(frame)

    -- Hide children if requested (for UpdateNamePlate)
    if options.hideChildren and options.nameplate then
        local childCount = frame:GetNumChildren()
        local children = {frame:GetChildren()}
        for i = 1, childCount do
            local child = children[i]
            -- Skip our overlay and the original healthbar
            if child and child ~= options.nameplate and child ~= healthbar then
                if child.SetAlpha then child:SetAlpha(0) end
                if child.Hide then child:Hide() end
            end
        end
    end
end

-- =============================================================================
-- Backward Compatibility
-- =============================================================================
-- Expose on main GudaPlates table for other modules
if GudaPlates then
    GudaPlates.DisableObject = GudaPlates_Hide.DisableObject
    GudaPlates.HideVisual = GudaPlates_Hide.HideVisual
end
