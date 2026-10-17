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

function M.Filter(set, state)
    state = state or {}
    local search = strlower(state.search or "")
    local out = {}
    for _, id in ns.PetCache:IteratePetIDs() do
        local info = ns.PetCache:GetInfo(id)
        local ok = ns.PetCache:IsPrimary(id)
        if search ~= "" and not strfind(info.sortKey, search, 1, true) then ok = false end
        if ok and state.show == "selected" and not isSelected(set, id) then ok = false end
        if ok and state.show == "unselected" and isSelected(set, id) then ok = false end
        if ok and state.types and next(state.types) and not state.types[info.petType] then ok = false end
        if ok and state.favoritesOnly and not info.isFavorite then ok = false end
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

-- tiles in the set and left out, in one pass (copies grouped, no filters)
function M.Counts(set)
    local inSet, all = 0, 0
    for _, id in ns.PetCache:IteratePetIDs() do
        if ns.PetCache:IsPrimary(id) then
            all = all + 1
            if isSelected(set, id) then inSet = inSet + 1 end
        end
    end
    return inSet, all - inSet
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
