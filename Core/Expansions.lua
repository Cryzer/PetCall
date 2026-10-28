local _, ns = ...

local type, tostring, pairs, ipairs = type, tostring, pairs, ipairs

-- The expansion a pet species was added in (0 = Classic), as the game numbers them.
-- Blizzard does not say: Core/ExpansionData.lua carries it, made by tools/gen_expansions.py.
local Expansions = {}
ns.Expansions = Expansions

local data = ns.ExpansionData
local dataNewest = 0
for _, e in ipairs(data.expansions) do if e > dataNewest then dataNewest = e end end

-- the newest expansion the client knows, never older than the data: in a pre-patch the
-- server still runs the old one while the client already holds the next one's pets
local function level(get)
    local n = get and get()
    return type(n) == "number" and n or -1
end
function Expansions.Newest()
    return math.max(dataNewest, level(GetServerExpansionLevel), level(GetClientDisplayExpansionLevel))
end

-- a species newer than the data came with the newest expansion
local ofSpecies = {}  -- speciesID -> expansion, found once: every expansion card asks about every pet
function Expansions.Of(speciesID)
    local e = ofSpecies[speciesID]
    if e then return e end
    if speciesID > data.maxSpecies then return Expansions.Newest() end
    local starts = data.starts
    local lo, hi, found = 1, #starts, 1
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if starts[mid] <= speciesID then found, lo = mid, mid + 1 else hi = mid - 1 end
    end
    e = data.expansions[found]
    ofSpecies[speciesID] = e
    return e
end

-- the expansion of each map (uiMapID), from Core/ZoneExpansionData.lua
local ofMap = {}
for e, ids in pairs(ns.ZoneExpansionData) do
    for _, id in ipairs(ids) do ofMap[id] = e end
end
local HOUSING = 11      -- houses and neighbourhoods came with Midnight

-- a map newer than the data belongs where its parent map does; nil when nothing is known.
-- Every pet of a rebuild asks, so a map's parents are walked once (walked: id -> e or false).
local walked = {}
function Expansions.OfMap(uiMapID)
    if not uiMapID or uiMapID == 0 then return nil end
    if ofMap[uiMapID] then return ofMap[uiMapID] end
    if walked[uiMapID] == nil then
        local e, id = false, uiMapID
        for _ = 1, 20 do
            local info = C_Map.GetMapInfo(id)
            id = info and info.parentMapID
            if not id or id == 0 then break end
            if ofMap[id] then e = ofMap[id] break end
        end
        walked[uiMapID] = e
    end
    return walked[uiMapID] or nil
end

-- the expansion of the land the player is in; nil during a loading screen
function Expansions.Here()
    local e = Expansions.OfMap(C_Map.GetBestMapForUnit("player"))
    if e == nil and C_Housing and C_Housing.IsInsideHouseOrPlot and C_Housing.IsInsideHouseOrPlot() then
        return HOUSING
    end
    return e
end

function Expansions.Name(index)
    local name = _G["EXPANSION_NAME" .. index]
    if type(name) == "string" and name ~= "" then return name end
    return tostring(index)
end

-- every expansion from Classic to the newest
function Expansions.All()
    local out = {}
    for i = 0, Expansions.Newest() do out[#out + 1] = i end
    return out
end
