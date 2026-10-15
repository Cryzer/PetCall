local _, ns = ...

local L = ns.L
local C_PetJournal, rawget, abs = C_PetJournal, rawget, math.abs

local Weights = {}
ns.Weights = Weights

local W8 = 8
Weights.LEVELS = {
    { value = 0,       key = "NEVER",      label = L["Never"],               short = L["Never"] },
    { value = W8 ^ -2, key = "EXTRA_LOW",  label = L["Extra Low Priority"],  short = "-2" },
    { value = W8 ^ -1, key = "LOW",        label = L["Low Priority"],        short = "-1" },
    { value = 1,       key = "NORMAL",     label = L["Normal"],              short = nil },
    { value = W8,      key = "HIGH",       label = L["High Priority"],       short = "+1" },
    { value = W8 ^ 2,  key = "EXTRA_HIGH", label = L["Extra High Priority"], short = "+2" },
}
Weights.NEVER, Weights.NORMAL = 0, 1
Weights.IGNORE_SPECIES = { [114] = true, [280] = true, [281] = true, [282] = true, [283] = true }

function Weights.Nearest(value)
    local best, dist = 1, math.huge
    for _, lvl in ipairs(Weights.LEVELS) do
        local d = abs(lvl.value - (value or 0))
        if d < dist then best, dist = lvl.value, d end
    end
    return best
end

local function level(value)
    local v = Weights.Nearest(value)
    for _, lvl in ipairs(Weights.LEVELS) do
        if lvl.value == v then return lvl end
    end
end

function Weights.Label(value) return level(value).label end
function Weights.Short(value) return level(value).short end

function Weights.PetWeight(settings, petID)
    local v = rawget(settings.pets, petID)
    if v ~= nil then return v end
    local species = ns.PetCache:GetSpeciesID(petID)
    if species and Weights.IGNORE_SPECIES[species] then return 0 end
    return settings.defaultValue or 0
end

function Weights.Build(settings, out)
    out = out or {}
    wipe(out)
    out.total = 0
    local filters = settings.filter
    local hasFilters = filters and #filters > 0
    for _, petID in ns.PetCache:IteratePetIDs() do
        local value = Weights.PetWeight(settings, petID)
        if value > 0 and C_PetJournal.PetIsSummonable(petID) then
            out[#out + 1], out[#out + 2] = value, petID
            out.total = out.total + value
        end
        if hasFilters then
            for _, entry in ipairs(filters) do
                if ns.AutoRules.Match(entry, petID) then
                    local w = ns.AutoRules.Weight(entry)
                    out[#out + 1], out[#out + 2] = w, petID
                    out.total = out.total + w
                end
            end
        end
    end
    return out
end

-- r in [0, 1); exclude (optional) leaves one pet out, e.g. the one already summoned
function Weights.Pick(tbl, r, exclude)
    local total = (tbl.total or 0) - (exclude and Weights.Sum(tbl, exclude) or 0)
    if total <= 0 then return nil end
    local remaining, last = r * total, nil
    for i = 1, #tbl, 2 do
        if tbl[i + 1] ~= exclude then
            last = tbl[i + 1]
            remaining = remaining - tbl[i]
            if remaining <= 0 then return last end
        end
    end
    return last
end

function Weights.Sum(tbl, petID)
    local s = 0
    for i = 1, #tbl, 2 do
        if tbl[i + 1] == petID then s = s + tbl[i] end
    end
    return s
end

function Weights.Chance(tbl, petID)
    if not tbl.total or tbl.total <= 0 then return 0 end
    return Weights.Sum(tbl, petID) / tbl.total
end
