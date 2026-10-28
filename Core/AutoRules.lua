local _, ns = ...

local L = ns.L
local tonumber, ipairs, pairs, type, strfind, strlower, sort, concat = tonumber, ipairs, pairs, type, strfind, strlower, table.sort, table.concat

local AutoRules = {}
ns.AutoRules = AutoRules

local ops = {
    ["=="] = function(a, b) return a == b end,
    [">="] = function(a, b) return a >= b end,
    [">"] = function(a, b) return a > b end,
    ["<="] = function(a, b) return a <= b end,
    ["<"] = function(a, b) return a < b end,
}

-- how many journal sources the client has (older clients: none)
function AutoRules.NumSources() return C_PetJournal.GetNumPetSources and C_PetJournal.GetNumPetSources() or 0 end

-- a journal source ("Drop", "Pet Battle"...) as the game names it; nil for a slot it leaves empty
function AutoRules.SourceLabel(i)
    local s = _G["BATTLE_PET_SOURCE_" .. i]
    if type(s) == "string" and s ~= "" and s ~= "BATTLE_PET_SOURCE_" .. i then return s end
end

-- a pet comes from a source when its "where from" text mentions it
local function mentions(petID, text)
    return text ~= "" and strfind(ns.PetCache:GetSourceText(petID), strlower(text), 1, true) ~= nil
end

-- "Level 25", "Level 1–24", "Level 20+"...
local function levelText(operator, level)
    local n = tonumber(level) or 0
    local range = operator == "==" and tostring(n)
        or operator == "<" and ("1–" .. (n - 1))
        or operator == "<=" and ("1–" .. n)
        or operator == ">" and ((n + 1) .. "+")
        or (n .. "+")
    return format(L["Level %s"], range)
end

local function typeName(t) return _G["BATTLE_PET_NAME_" .. t] or tostring(t) end

local types = {
    favorites = {
        key = "favorites",
        match = function(e, info) return info.isFavorite end,
        describe = function() return L["Favorites"] end,
    },
    petType = {
        key = "petType",
        match = function(e, info)
            if e.petTypes then
                for _, t in ipairs(e.petTypes) do if t == info.petType then return true end end
                return false
            end
            return info.petType == tonumber(e.petType)
        end,
        describe = function(e)
            local names = {}
            for _, t in ipairs(e.petTypes or { tonumber(e.petType) }) do names[#names + 1] = typeName(t) end
            return concat(names, ", ")
        end,
    },
    level = {
        key = "level",
        match = function(e, info)
            local cmp, n = ops[e.operator or "?"], tonumber(e.level)
            return cmp ~= nil and n ~= nil and cmp(info.level, n)
        end,
        describe = function(e) return levelText(e.operator, e.level) end,
    },
    rare = {
        key = "rare",
        match = function(e, info) return (info.quality or 0) >= 4 end,
        describe = function() return L["Rare or better"] end,
    },
    -- journal sources by number (sources = { 2, 7 }), or older rules: any text the source mentions
    source = {
        key = "source",
        match = function(e, info)
            if e.sources then
                for _, i in ipairs(e.sources) do
                    local label = AutoRules.SourceLabel(i)
                    if label and mentions(info.petID, label) then return true end
                end
                return false
            end
            return mentions(info.petID, e.text or "")
        end,
        describe = function(e)
            if e.sources then
                local names = {}
                for _, i in ipairs(e.sources) do names[#names + 1] = AutoRules.SourceLabel(i) or tostring(i) end
                return concat(names, ", ")
            end
            local t = e.text or ""
            return L["Source"] .. ": " .. (t ~= "" and t or L["no text yet"])
        end,
    },
    -- the expansion the pet was added in (expansions = { 6, 9 }), whatever its source
    expansion = {
        key = "expansion",
        match = function(e, info)
            local mine = ns.Expansions.Of(info.speciesID)
            for _, i in ipairs(e.expansions or {}) do if i == mine then return true end end
            return false
        end,
        describe = function(e)
            local names = {}
            for _, i in ipairs(e.expansions or {}) do names[#names + 1] = ns.Expansions.Name(i) end
            return concat(names, ", ")
        end,
    },
    nativeZone = {
        key = "nativeZone",
        match = function(e, info)
            local zone = GetZoneText() or ""
            return mentions(info.petID, zone)
        end,
        describe = function() return L["From this zone"] end,
    },
    -- the pet came with the expansion of the land the player is in
    expansionHere = {
        key = "expansionHere",
        match = function(e, info)
            local here = ns.Expansions.Here()
            return here ~= nil and ns.Expansions.Of(info.speciesID) == here
        end,
        describe = function() return L["From this expansion"] end,
    },
}
local order = { "favorites", "petType", "level", "rare", "source", "expansion", "nativeZone", "expansionHere" }

function AutoRules.Types()
    local out = {}
    for _, k in ipairs(order) do out[#out + 1] = types[k] end
    return out
end

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

function AutoRules.Describe(e)
    local kind = e[1]
    local text
    if kind == "AND" or kind == "OR" then
        local parts = {}
        for _, sub in ipairs(e.items or {}) do parts[#parts + 1] = AutoRules.Describe(sub) end
        text = concat(parts, kind == "AND" and (" " .. L["and"] .. " ") or (" " .. L["or"] .. " "))
        if #parts > 1 then text = "(" .. text .. ")" end
    elseif types[kind] then
        text = types[kind].describe(e)
    else
        text = L["Unknown rule"]
    end
    if e.negate then text = L["not"] .. " " .. text end
    return text
end

-- Rules and the pet list's filters are one thing: a rule is the filters it was made from.
-- Filters: { favorites = true, types = { [petType] = true }, sources = { [journal source] = true },
-- sourceText = "older rules' text", level = { operator =, level = }, rare = true,
-- expansions = { [expansion] = true }, nativeZone = true, expansionHere = true }, every group optional. Any choice inside a group will do; every
-- group must match.

local function sortedKeys(set)
    local out = {}
    for k in pairs(set or {}) do out[#out + 1] = k end
    sort(out)
    return out
end

-- the rule (without its weight) the filters make, or nil when no group is set
function AutoRules.FromFilters(f)
    local items = {}
    if f.favorites then items[#items + 1] = { "favorites" } end
    local list = sortedKeys(f.types)
    if #list > 0 then items[#items + 1] = { "petType", petTypes = list } end
    if f.level then items[#items + 1] = { "level", operator = f.level.operator, level = tostring(f.level.level) } end
    if f.rare then items[#items + 1] = { "rare" } end
    list = sortedKeys(f.sources)
    if #list > 0 then items[#items + 1] = { "source", sources = list } end
    if f.sourceText then items[#items + 1] = { "source", text = f.sourceText } end
    list = sortedKeys(f.expansions)
    if #list > 0 then items[#items + 1] = { "expansion", expansions = list } end
    if f.nativeZone then items[#items + 1] = { "nativeZone" } end
    if f.expansionHere then items[#items + 1] = { "expansionHere" } end
    if #items == 0 then return nil end
    if #items == 1 then return items[1] end
    return { "AND", items = items }
end

-- one condition into the filters; false when the group is taken already or cannot be shown
local function addLeaf(f, e)
    if e.negate then return false end
    local k = e[1]
    if k == "favorites" and not f.favorites then
        f.favorites = true
    elseif k == "petType" and not f.types then
        f.types = {}
        for _, t in ipairs(e.petTypes or { tonumber(e.petType) }) do f.types[t] = true end
    elseif k == "level" and not f.level then
        f.level = { operator = e.operator, level = tonumber(e.level) }
    elseif k == "rare" and not f.rare then
        f.rare = true
    elseif k == "source" and e.sources and not f.sources then
        f.sources = {}
        for _, i in ipairs(e.sources) do f.sources[i] = true end
    elseif k == "source" and not e.sources and not f.sourceText then
        f.sourceText = e.text or ""
    elseif k == "expansion" and not f.expansions then
        f.expansions = {}
        for _, i in ipairs(e.expansions or {}) do f.expansions[i] = true end
    elseif k == "nativeZone" and not f.nativeZone then
        f.nativeZone = true
    elseif k == "expansionHere" and not f.expansionHere then
        f.expansionHere = true
    else
        return false
    end
    return true
end

-- the filters a rule is made of, or nil for a rule they cannot show: "any one of these",
-- the same condition twice, "not", or the nested rules of version 1.0
function AutoRules.ToFilters(e)
    local f = {}
    if types[e[1]] then return addLeaf(f, e) and f or nil end
    local items = e.items or {}
    if e.negate or not (e[1] == "AND" or (e[1] == "OR" and #items == 1)) then return nil end
    for _, sub in ipairs(items) do
        if not types[sub[1]] or not addLeaf(f, sub) then return nil end
    end
    return next(f) and f or nil
end

-- what the filters say, one entry per choice in the order the menu has them:
-- { label =, group =, value = } (value is the pet type, source or expansion number)
function AutoRules.Tokens(f)
    local out = {}
    local function add(group, label, value) out[#out + 1] = { group = group, label = label, value = value } end
    if f.favorites then add("favorites", L["Favorites"]) end
    for _, t in ipairs(sortedKeys(f.types)) do add("types", typeName(t), t) end
    if f.level then add("level", levelText(f.level.operator, f.level.level)) end
    if f.rare then add("rare", L["Rare or better"]) end
    for _, i in ipairs(sortedKeys(f.sources)) do add("sources", AutoRules.SourceLabel(i) or tostring(i), i) end
    if f.sourceText then add("sourceText", L["Source"] .. ": " .. (f.sourceText ~= "" and f.sourceText or L["no text yet"])) end
    for _, i in ipairs(sortedKeys(f.expansions)) do add("expansions", ns.Expansions.Name(i), i) end
    if f.nativeZone then add("nativeZone", L["From this zone"]) end
    if f.expansionHere then add("expansionHere", L["From this expansion"]) end
    return out
end

-- the word between two filter choices: "or" inside a group (Beast or Aquatic), "and"
-- between groups (and Rare or better)
function AutoRules.Join(prev, tok) return prev.group == tok.group and L["or"] or L["and"] end

-- the filters as one line: "Beast or Aquatic and Rare or better"
function AutoRules.Sentence(f)
    local out, prev = {}, nil
    for _, tok in ipairs(AutoRules.Tokens(f)) do
        if prev then out[#out + 1] = AutoRules.Join(prev, tok) end
        out[#out + 1] = tok.label
        prev = tok
    end
    return concat(out, " ")
end

-- the same text for two rules that pick the same pets the same way (weight left out)
function AutoRules.Key(e)
    local f = AutoRules.ToFilters(e)
    local parts = {}
    for _, tok in ipairs(f and AutoRules.Tokens(f) or {}) do parts[#parts + 1] = tok.group .. "=" .. tok.label end
    return f and concat(parts, "\n") or AutoRules.Describe(e)
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
