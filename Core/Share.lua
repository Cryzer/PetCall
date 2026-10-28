local _, ns = ...

local L = ns.L
local type, pairs, ipairs = type, pairs, ipairs

local Share = {}
ns.Share = Share

local V1, V2 = "PetCall:1:", "PetCall:2:"

function Share:Export(name)
    local set = ns.Sets:Get(name)
    if not set then return nil, L["Set not found."] end
    local st = set.settings
    local pets = {}
    for petID, w in pairs(st.pets) do
        local species = ns.PetCache:GetSpeciesID(petID)
        if species and type(w) == "number" and (pets[species] == nil or w > pets[species]) then pets[species] = w end
    end
    local data = { enabled = st.enabled, priority = st.priority, defaultValue = st.defaultValue,
        immediate = st.immediate, alwaysNew = st.alwaysNew, noPet = st.noPet, switchMinutes = st.switchMinutes,
        announce = st.announce, pets = pets, filter = st.filter, trigger = st.trigger }
    local cbor = C_EncodingUtil.SerializeCBOR(data)
    return V2 .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(cbor))
end

local function decode(str)
    str = strtrim(str or "")
    if str:sub(1, #V2) == V2 then
        local ok, data = pcall(function()
            local raw = C_EncodingUtil.DecodeBase64(str:sub(#V2 + 1))
            return C_EncodingUtil.DeserializeCBOR(C_EncodingUtil.DecompressString(raw))
        end)
        if ok and type(data) == "table" then return data end
        return nil, L["The import string is damaged."]
    elseif str:sub(1, #V1) == V1 then
        local ok, data = ns.LegacyDeserialize(str:sub(#V1 + 1))
        if ok and type(data) == "table" then return data end
        return nil, L["The import string is damaged."]
    end
    return nil, L["This is not a PetCall export string."]
end

-- Imported data is untrusted: every field must have the type the code expects.
local FIELDS = {
    negate = "boolean", disabledByImport = "boolean", party = "boolean", raid = "boolean", solo = "boolean",
    zoneName = "string", loc = "string", class = "string", name = "string", macro = "string", code = "string",
    operator = "string", petType = "scalar", level = "scalar", spec = "number", from = "number", to = "number",
    zoneNames = "strings", locs = "strings", mapIDs = "numbers", petTypes = "numbers", sources = "numbers", expansions = "numbers",
    text = "string", ownHome = "boolean", otherHome = "boolean", inHouse = "boolean", holidayIDs = "numbers", mountIDs = "numbers", outfitNames = "strings",
    mounted = "boolean", swimming = "boolean", indoors = "boolean", outdoors = "boolean", afk = "boolean", form = "boolean",
}

local function isNumber(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

local function validList(v, itemOk)
    if type(v) ~= "table" then return nil end
    local out = {}
    for _, x in ipairs(v) do if itemOk(x) then out[#out + 1] = x end end
    return out
end

local function cleanField(kind, v)
    if kind == "boolean" then return type(v) == "boolean" and v or nil end
    if kind == "string" then return type(v) == "string" and v or nil end
    if kind == "number" then return isNumber(v) and v or nil end
    if kind == "scalar" then return (type(v) == "string" or isNumber(v)) and v or nil end
    if kind == "strings" then return validList(v, function(x) return type(x) == "string" end) end
    if kind == "numbers" then return validList(v, isNumber) end
end

-- weighted: top-level filter chips carry their weight in [2]
local function sanitize(list, isKnown, info, weighted)
    local out = {}
    if type(list) ~= "table" then return out end
    for _, e in ipairs(list) do
        if type(e) == "table" and type(e[1]) == "string" and (e[1] == "AND" or e[1] == "OR" or isKnown(e[1])) then
            local clean = { e[1] }
            for k, v in pairs(e) do
                if type(k) == "string" and FIELDS[k] then clean[k] = cleanField(FIELDS[k], v) end
            end
            if e[1] == "AND" or e[1] == "OR" then
                clean.items = sanitize(e.items, isKnown, info, false)
            elseif e[1] == "luacode" then
                clean.disabledByImport = true
                info.hasLuaCode = true
            end
            if weighted then clean[2] = (isNumber(e[2]) and e[2] > 0) and e[2] or ns.Weights.NORMAL end
            out[#out + 1] = clean
        else
            info.dropped = info.dropped + 1
        end
    end
    return out
end

local function knownFilter(key)
    for _, def in ipairs(ns.AutoRules.Types()) do if def.key == key then return true end end
    return false
end
local function knownCondition(key) return ns.Conditions.GetType(key) ~= nil end

function Share:Import(str, name)
    local data, err = decode(str)
    if not data then return false, err end
    local okName, nameErr = ns.Sets:ValidateName(name)
    if not okName then return false, nameErr end
    local info = { hasLuaCode = false, dropped = 0 }
    local set = ns.Sets:Create(name)
    local st = set.settings
    st.enabled = data.enabled ~= false
    -- an exported default set has priority -1 and would never win as a normal set
    st.priority = (isNumber(data.priority) and data.priority > 0) and data.priority or 1
    st.defaultValue = (isNumber(data.defaultValue) and data.defaultValue >= 0) and data.defaultValue or 0
    st.immediate = data.immediate and true or nil
    st.alwaysNew = data.alwaysNew == true or nil
    st.noPet = data.noPet == true or nil
    st.switchMinutes = (isNumber(data.switchMinutes) and data.switchMinutes >= 1 and data.switchMinutes <= 60) and data.switchMinutes or nil
    st.announce = (data.announce == "on" or data.announce == "off") and data.announce or nil
    st.filter = sanitize(data.filter, knownFilter, info, true)
    -- fill the existing trigger table in place: the set's watcher holds a reference to it
    local trigger = sanitize(data.trigger, knownCondition, info)
    wipe(st.trigger)
    for i, e in ipairs(trigger) do st.trigger[i] = e end
    ns.Conditions.Normalize(st.trigger)
    wipe(st.pets)
    if type(data.pets) == "table" then
        for _, petID in ns.PetCache:IteratePetIDs() do
            local w = data.pets[ns.PetCache:GetSpeciesID(petID)]
            if isNumber(w) and w >= 0 then st.pets[petID] = w end
        end
    end
    set:ConditionsChanged()
    return true, set.name, info
end
