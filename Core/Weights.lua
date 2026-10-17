local _, ns = ...

local L = ns.L
local C_PetJournal, rawget, abs = C_PetJournal, rawget, math.abs

local Weights = {}
ns.Weights = Weights

local W8 = 8
-- label: how often a pet is drawn; priority: the same steps used to rank sets
Weights.LEVELS = {
    { value = 0,       key = "NEVER",      label = L["Never"],       short = L["Never"], priority = nil },
    { value = W8 ^ -2, key = "EXTRA_LOW",  label = L["Very rarely"], short = "-2",       priority = L["Lowest"] },
    { value = W8 ^ -1, key = "LOW",        label = L["Rarely"],      short = "-1",       priority = L["Low"] },
    { value = 1,       key = "NORMAL",     label = L["Normal"],      short = nil,        priority = L["Normal"] },
    { value = W8,      key = "HIGH",       label = L["Often"],       short = "+1",       priority = L["High"] },
    { value = W8 ^ 2,  key = "EXTRA_HIGH", label = L["Very often"],  short = "+2",       priority = L["Highest"] },
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
function Weights.PriorityLabel(value) return level(value).priority or level(1).priority end
function Weights.Short(value) return level(value).short end

function Weights.PetWeight(settings, petID)
    local v = rawget(settings.pets, petID)
    if v ~= nil then return v end
    local species = ns.PetCache:GetSpeciesID(petID)
    if species and Weights.IGNORE_SPECIES[species] then return 0 end
    return settings.defaultValue or 0
end

-- out.auto: petID -> the tickets its rules would give it (summonable or not), so the UI
-- can tell "in through a rule" without judging every pet against the rules again
function Weights.Build(settings, out)
    out = out or {}
    local auto = out.auto
    wipe(out)
    if auto then wipe(auto) else auto = {} end
    out.total, out.auto = 0, auto
    local filters = settings.filter
    local hasFilters = filters and #filters > 0
    for _, petID in ns.PetCache:IteratePetIDs() do
        -- a pet the game will not summon gets no tickets from anywhere: drawing it would
        -- summon nothing (1.x let rules give it tickets)
        local summonable = C_PetJournal.PetIsSummonable(petID)
        local value = Weights.PetWeight(settings, petID)
        if value > 0 and summonable then
            out[#out + 1], out[#out + 2] = value, petID
            out.total = out.total + value
        end
        if hasFilters then
            for _, entry in ipairs(filters) do
                if ns.AutoRules.Match(entry, petID) then
                    local w = ns.AutoRules.Weight(entry)
                    if summonable then
                        out[#out + 1], out[#out + 2] = w, petID
                        out.total = out.total + w
                    end
                    auto[petID] = (auto[petID] or 0) + w
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
