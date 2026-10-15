local _, ns = ...

local strfind, strlower, sort, ipairs = strfind, strlower, table.sort, ipairs
local M = {}
ns.PetGridModel = M

local function isSelected(set, id)
    return set:GetPetWeight(id) > 0 or set:GetAutoWeight(id) > 0
end

function M.Filter(set, state)
    state = state or {}
    local search = strlower(state.search or "")
    local out = {}
    for _, id in ns.PetCache:IteratePetIDs() do
        local info = ns.PetCache:GetInfo(id)
        local ok = true
        if search ~= "" and not strfind(info.sortKey, search, 1, true) then ok = false end
        if ok and state.show == "selected" and not isSelected(set, id) then ok = false end
        if ok and state.show == "unselected" and isSelected(set, id) then ok = false end
        if ok and state.types and next(state.types) and not state.types[info.petType] then ok = false end
        if ok and state.favoritesOnly and not info.isFavorite then ok = false end
        if ok then out[#out + 1] = id end
    end
    local key = state.sort or "name"
    if key ~= "name" then
        local tbl = key == "chance" and set:GetWeightTable() or nil
        local function value(id)
            local info = ns.PetCache:GetInfo(id)
            if key == "level" then return info.level end
            if key == "rarity" then return info.quality end
            return ns.Weights.Chance(tbl, id)
        end
        sort(out, function(a, b)
            local va, vb = value(a), value(b)
            if va == vb then return ns.PetCache:GetSortKey(a) < ns.PetCache:GetSortKey(b) end
            return va > vb
        end)
    end
    return out
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

function M.Badge(set, id)
    local w = set:GetPetWeight(id)
    if set:HasManualWeight(id) or set:GetAutoWeight(id) == 0 then
        if w == 0 then return ns.Weights.Short(0), "never" end
        return ns.Weights.Short(w), "manual"
    end
    if w == 0 then return ns.L["auto"], "auto" end
    return ns.Weights.Short(w), "manual"
end
