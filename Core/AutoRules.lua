local _, ns = ...

local L = ns.L
local tonumber, tinsert, tremove, ipairs, type, strfind, strlower = tonumber, tinsert, tremove, ipairs, type, strfind, strlower

local AutoRules = {}
ns.AutoRules = AutoRules

local ops = {
    ["=="] = function(a, b) return a == b end,
    [">="] = function(a, b) return a >= b end,
    [">"] = function(a, b) return a > b end,
    ["<="] = function(a, b) return a <= b end,
    ["<"] = function(a, b) return a < b end,
}
AutoRules.OPERATORS = { "==", ">=", ">", "<=", "<" }

local function petTypeValues()
    local out = {}
    for i = 1, C_PetJournal.GetNumPetTypes() do
        out[#out + 1] = { value = i, label = _G["BATTLE_PET_NAME_" .. i] or tostring(i) }
    end
    return out
end

local types = {
    favorites = {
        key = "favorites", label = L["Favorites"], fields = {},
        match = function(e, info) return info.isFavorite end,
        describe = function() return L["Favorites"] end,
        new = function() return { "favorites" } end,
    },
    petType = {
        key = "petType", label = L["Pet Type"],
        fields = { { key = "petTypes", kind = "multiChoice", values = petTypeValues } },
        match = function(e, info)
            if e.petTypes then
                for _, t in ipairs(e.petTypes) do if t == info.petType then return true end end
                return false
            end
            return info.petType == tonumber(e.petType)
        end,
        describe = function(e)
            local names = {}
            local list = e.petTypes or { tonumber(e.petType) }
            for _, t in ipairs(list) do names[#names + 1] = _G["BATTLE_PET_NAME_" .. t] or tostring(t) end
            return L["Type"] .. ": " .. table.concat(names, ", ")
        end,
        new = function() return { "petType", petTypes = { 1 } } end,
    },
    level = {
        key = "level", label = L["Level"],
        fields = { { key = "operator", kind = "operator" }, { key = "level", kind = "number", min = 1, max = 25 } },
        match = function(e, info)
            local cmp, n = ops[e.operator or "?"], tonumber(e.level)
            return cmp ~= nil and n ~= nil and cmp(info.level, n)
        end,
        describe = function(e) return L["Level"] .. " " .. (e.operator or "?") .. " " .. tostring(e.level) end,
        new = function() return { "level", operator = ">=", level = "25" } end,
    },
}
types.rare = {
    key = "rare", label = L["Rare or better"], fields = {},
    match = function(e, info) return (info.quality or 0) >= 4 end,
    describe = function() return L["Rare or better"] end,
    new = function() return { "rare" } end,
}
types.source = {
    key = "source", label = L["Source mentions"],
    fields = { { key = "text", kind = "text" } },
    match = function(e, info)
        local t = strlower(e.text or "")
        return t ~= "" and strfind(ns.PetCache:GetSourceText(info.petID), t, 1, true) ~= nil
    end,
    describe = function(e) return L["Source"] .. ": " .. (e.text or "") end,
    new = function() return { "source", text = "" } end,
}
types.nativeZone = {
    key = "nativeZone", label = L["Native to where I am"], fields = {},
    match = function(e, info)
        local zone = strlower(GetZoneText() or "")
        return zone ~= "" and strfind(ns.PetCache:GetSourceText(info.petID), zone, 1, true) ~= nil
    end,
    describe = function() return L["Native to where I am"] end,
    new = function() return { "nativeZone" } end,
}
local order = { "favorites", "petType", "level", "rare", "source", "nativeZone" }

function AutoRules.Types()
    local out = {}
    for _, k in ipairs(order) do out[#out + 1] = types[k] end
    return out
end

function AutoRules.Label(key) return types[key] and types[key].label or key end

local function matchEntry(e, info)
    local kind = e[1]
    local result
    if kind == "AND" or kind == "OR" then
        result = kind == "AND"
        for _, sub in ipairs(e.items or {}) do
            local m = matchEntry(sub, info)
            if kind == "AND" and not m then result = false break end
            if kind == "OR" and m then result = true break end
        end
    elseif types[kind] then
        result = types[kind].match(e, info) and true or false
    else
        result = false
    end
    if e.negate then result = not result end
    return result
end

function AutoRules.Match(entry, petID)
    local info = ns.PetCache:GetInfo(petID)
    if not info then return false end
    return matchEntry(entry, info)
end

function AutoRules.Weight(entry) return entry[2] or 1 end

local function isLeaf(e) return types[e[1]] ~= nil end

function AutoRules.ToChips(list)
    local chips = {}
    for i, e in ipairs(list or {}) do
        local chip = { index = i, entry = e, legacy = false, match = "all", criteria = {} }
        if isLeaf(e) then
            chip.criteria[1] = e
        elseif e[1] == "AND" or e[1] == "OR" then
            chip.match = e[1] == "AND" and "all" or "any"
            for _, sub in ipairs(e.items or {}) do
                if isLeaf(sub) then chip.criteria[#chip.criteria + 1] = sub else chip.legacy = true end
            end
            if #chip.criteria == 0 then chip.legacy = true end
        else
            chip.legacy = true
        end
        chips[#chips + 1] = chip
    end
    return chips
end

function AutoRules.Describe(e)
    local kind = e[1]
    local text
    if kind == "AND" or kind == "OR" then
        local parts = {}
        for _, sub in ipairs(e.items or {}) do parts[#parts + 1] = AutoRules.Describe(sub) end
        text = "(" .. table.concat(parts, kind == "AND" and (" " .. L["and"] .. " ") or (" " .. L["or"] .. " ")) .. ")"
    elseif types[kind] then
        text = types[kind].describe(e)
    else
        text = L["Unknown rule"]
    end
    if e.negate then text = L["not"] .. " " .. text end
    return text
end

-- Editing helpers. Chips keep the 1.0 shape: a leaf, or AND/OR of leaves.

function AutoRules.AddChip(list, typeKey, weight)
    local e = types[typeKey].new()
    e[2] = weight or 1
    tinsert(list, e)
    return true
end

function AutoRules.RemoveChip(list, index)
    tremove(list, index)
    return true
end

function AutoRules.SetChipWeight(list, index, w)
    list[index][2] = w
    return true
end

function AutoRules.AddCriterion(list, index, typeKey)
    local e = list[index]
    local new = types[typeKey].new()
    if isLeaf(e) then
        local w = e[2]
        e[2] = nil
        list[index] = { "AND", items = { e, new }, w }
    else
        tinsert(e.items, new)
    end
    return true
end

function AutoRules.RemoveCriterion(list, index, ci)
    local e = list[index]
    if isLeaf(e) then
        tremove(list, index)
        return true
    end
    tremove(e.items, ci)
    if #e.items == 1 then
        local only = e.items[1]
        only[2] = e[2]
        list[index] = only
    elseif #e.items == 0 then
        tremove(list, index)
    end
    return true
end

function AutoRules.SetMatch(list, index, match)
    local e = list[index]
    if not isLeaf(e) then e[1] = match == "any" and "OR" or "AND" end
    return true
end

function AutoRules.SetField(leaf, key, value)
    leaf[key] = value
    if key == "petTypes" then leaf.petType = nil end
    return true
end

-- Collapses single-child AND/OR chains; only when the meaning stays identical.
local function collapse(e)
    if (e[1] == "AND" or e[1] == "OR") and not e.negate and e.items and #e.items == 1 then
        return collapse(e.items[1])
    end
    return e
end

function AutoRules.Simplify(list, index)
    local e = list[index]
    local w = e[2]
    local c = collapse(e)
    if c == e then return false end
    c = { unpack(c) }
    for k, v in pairs(collapse(e)) do if type(k) ~= "number" then c[k] = v end end
    c[2] = w
    list[index] = c
    return true
end

-- "native to where I am" depends on the zone: only sets that use it are rebuilt
local function usesNativeZone(list)
    for _, e in ipairs(list or {}) do
        if e[1] == "nativeZone" then return true end
        if (e[1] == "AND" or e[1] == "OR") and usesNativeZone(e.items) then return true end
    end
    return false
end
AutoRules.UsesNativeZone = usesNativeZone
ns.Events.Register(AutoRules, "ZONE_CHANGED_NEW_AREA", function()
    for _, set in ipairs(ns.Sets:List()) do
        if usesNativeZone(set.settings.filter) then set:FiltersChanged() end
    end
end)
