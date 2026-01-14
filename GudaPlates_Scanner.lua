-- =============================================================================
-- GudaPlates_Scanner.lua
-- =============================================================================
-- Nameplate Detection Module
-- Responsible for scanning WorldFrame children and detecting vanilla nameplates
--
-- Exports:
--   GudaPlates_Scanner.IsNamePlate(frame) - Returns true if frame is a nameplate
--   GudaPlates_Scanner.ScanForNewNameplates(registry, callback) - Scans for new nameplates
--   GudaPlates_Scanner.Reset() - Resets scanner state (call on zone change)
--   GudaPlates_Scanner.GetInitializedCount() - Returns count of scanned children
-- =============================================================================

GudaPlates_Scanner = {}

-- Local state
local initializedChildren = 0
local cachedWorldChildren = {}

-- =============================================================================
-- Detection Functions
-- =============================================================================

-- Helper to check if a region is the nameplate border texture
local function CheckRegionForBorder(r)
    if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.GetTexture then
        return r:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
    end
    return false
end

-- Check if a frame is a vanilla nameplate by looking for the border texture
-- Returns true if nameplate, nil otherwise
function GudaPlates_Scanner.IsNamePlate(frame)
    if not frame then return nil end

    local objType = frame:GetObjectType()
    if objType ~= "Frame" and objType ~= "Button" then return nil end

    -- Check regions for nameplate border texture (no table allocation)
    local r1, r2, r3, r4, r5, r6 = frame:GetRegions()

    if CheckRegionForBorder(r1) then return true end
    if CheckRegionForBorder(r2) then return true end
    if CheckRegionForBorder(r3) then return true end
    if CheckRegionForBorder(r4) then return true end
    if CheckRegionForBorder(r5) then return true end
    if CheckRegionForBorder(r6) then return true end

    return nil
end

-- =============================================================================
-- Scanning Functions
-- =============================================================================

-- Scan WorldFrame for new nameplate children
-- Only scans NEW children since last call (ShaguPlates-style optimization)
--
-- Parameters:
--   registry: Table mapping frame -> nameplate (to skip already registered)
--   callback: Function to call for each new nameplate found (receives frame)
--
-- Returns:
--   didWork: true if new nameplates were found and processed
function GudaPlates_Scanner.ScanForNewNameplates(registry, callback)
    local parentcount = WorldFrame:GetNumChildren()

    -- Only scan if there are NEW children we haven't seen before
    if initializedChildren >= parentcount then
        return false
    end

    -- Refresh cached children only when needed
    cachedWorldChildren = { WorldFrame:GetChildren() }

    local foundNew = false

    -- Only scan the NEW children (from initialized+1 to parentcount)
    for i = initializedChildren + 1, parentcount do
        local plate = cachedWorldChildren[i]
        if plate and not registry[plate] then
            if GudaPlates_Scanner.IsNamePlate(plate) then
                callback(plate)
                foundNew = true
            end
        end
    end

    initializedChildren = parentcount
    return foundNew
end

-- =============================================================================
-- State Management
-- =============================================================================

-- Reset scanner state (call on zone change to re-scan all nameplates)
function GudaPlates_Scanner.Reset()
    initializedChildren = 0
    -- Clear cached children table
    for k in pairs(cachedWorldChildren) do
        cachedWorldChildren[k] = nil
    end
end

-- Get count of initialized (scanned) children
function GudaPlates_Scanner.GetInitializedCount()
    return initializedChildren
end

-- =============================================================================
-- Backward Compatibility
-- =============================================================================
-- Expose IsNamePlate on main GudaPlates table for other modules
if GudaPlates then
    GudaPlates.IsNamePlate = GudaPlates_Scanner.IsNamePlate
end
