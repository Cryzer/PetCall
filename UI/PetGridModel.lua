local _, ns = ...

local strfind, strlower, sort, ipairs = strfind, strlower, table.sort, ipairs
local M = {}
ns.PetGridModel = M

-- a tile stands for all copies of a pet: it is selected when any copy can be drawn
local function isSelected(set, id)
    for _, copy in ipairs(ns.PetCache:GetCopies(id)) do
        if set:GetPetWeight(copy) > 0 or set:GetAutoWeight(copy) > 0 then return true end
    end
    return false
end

-- state: { search, show = "all" | "selected" | "unselected", sort, filters, editing }.
-- filters are the groups a rule is made of (see AutoRules.FromFilters), so the list shows
-- what a rule made from them would pick. While a rule is being edited, search and the
-- segment are left out: the list shows exactly the rule's pets.
function M.Filter(set, state)
    state = state or {}
    local editing = state.editing ~= nil
    local search = editing and "" or strlower(state.search or "")
    local show = editing and "all" or state.show
    local rule = state.filters and ns.AutoRules.FromFilters(state.filters)
    local out = {}
    for _, id in ns.PetCache:IteratePetIDs() do
        local info = ns.PetCache:GetInfo(id)
        local ok = ns.PetCache:IsPrimary(id)
        if search ~= "" and not strfind(info.sortKey, search, 1, true) then ok = false end
        if ok and show == "selected" and not isSelected(set, id) then ok = false end
        if ok and show == "unselected" and isSelected(set, id) then ok = false end
        if ok and rule and not ns.AutoRules.Match(rule, id) then ok = false end
        if ok then out[#out + 1] = id end
    end
    local key = state.sort or "name"
    if key ~= "name" then
        -- chance is proportional to a tile's summed weight (copies add up on their tile)
        local sums = key == "chance" and set:GetTileSums() or {}
        local function value(id)
            local info = ns.PetCache:GetInfo(id)
            if key == "level" then return info.level end
            if key == "rarity" then return info.quality end
            return sums[id] or 0
        end
        sort(out, function(a, b)
            local va, vb = value(a), value(b)
            if va == vb then return ns.PetCache:GetSortKey(a) < ns.PetCache:GetSortKey(b) end
            return va > vb
        end)
    end
    return out
end

-- tiles in the set and left out, in one pass (copies grouped, no filters); kept with
-- the draw table, which is rebuilt whenever the set or the pets change
function M.Counts(set)
    local tbl = set:GetWeightTable()
    if not tbl.counts then
        local inSet, all = 0, 0
        for _, id in ns.PetCache:IteratePetIDs() do
            if ns.PetCache:IsPrimary(id) then
                all = all + 1
                if isSelected(set, id) then inSet = inSet + 1 end
            end
        end
        tbl.counts = { inSet, all - inSet }
    end
    return tbl.counts[1], tbl.counts[2]
end

-- how many tiles (copies grouped) a rule picks
function M.CountMatching(entry)
    local n = 0
    for _, id in ns.PetCache:IteratePetIDs() do
        if ns.PetCache:IsPrimary(id) and ns.AutoRules.Match(entry, id) then n = n + 1 end
    end
    return n
end

-- pets (one per tile) from each journal source the game names, whatever the other filters say
function M.SourceCounts()
    local counts = {}
    for i = 1, ns.AutoRules.NumSources() do
        if ns.AutoRules.SourceLabel(i) then counts[i] = M.CountMatching({ "source", sources = { i } }) end
    end
    return counts
end

-- each filter choice, as AutoRules.Tokens names it, with clear() that turns it off
function M.Tokens(state)
    local f = state.filters or {}
    local out = ns.AutoRules.Tokens(f)
    for _, tok in ipairs(out) do
        tok.clear = function()
            if tok.value ~= nil then
                f[tok.group][tok.value] = nil
                if not next(f[tok.group]) then f[tok.group] = nil end
            else
                f[tok.group] = nil
            end
        end
    end
    return out
end

-- true when the list shows fewer pets than the set has: search, segment or filters
function M.IsNarrowed(state)
    return (state.search or "") ~= "" or (state.show or "all") ~= "all" or next(state.filters or {}) ~= nil
end

-- back to every pet; the sort order stays
function M.ClearFilters(state)
    state.search, state.show, state.filters = "", "all", {}
end

function M.Rows(ids, columns)
    local rows = {}
    for i, id in ipairs(ids) do
        local r = math.floor((i - 1) / columns) + 1
        rows[r] = rows[r] or {}
        rows[r][#rows[r] + 1] = id
    end
    return rows
end

-- rules add their tickets whatever the weight says, so a pet a rule matches is never
-- "left out", even when its own weight is Never
function M.Badge(set, id)
    local w = set:GetPetWeight(id)
    if w > 0 then return ns.Weights.Short(w), "manual" end
    if set:GetAutoWeight(id) > 0 then return ns.L["auto"], "auto" end
    return ns.Weights.Short(0), "never"
end
