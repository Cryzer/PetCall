local _, ns = ...

local type, tostring = type, tostring

-- The expansion a pet species was added in (0 = Classic), as the game numbers them.
-- Blizzard does not say: Core/ExpansionData.lua carries it, made by tools/gen_expansions.py.
local Expansions = {}
ns.Expansions = Expansions

local data = ns.ExpansionData
local dataNewest = 0
for _, e in ipairs(data.expansions) do if e > dataNewest then dataNewest = e end end

-- the newest expansion the client knows, never older than the data
function Expansions.Newest()
    local level = GetServerExpansionLevel and GetServerExpansionLevel()
    if type(level) == "number" and level > dataNewest then return level end
    return dataNewest
end

-- a species newer than the data came with the newest expansion
function Expansions.Of(speciesID)
    if speciesID > data.maxSpecies then return Expansions.Newest() end
    local starts = data.starts
    local lo, hi, found = 1, #starts, 1
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if starts[mid] <= speciesID then found, lo = mid, mid + 1 else hi = mid - 1 end
    end
    return data.expansions[found]
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
