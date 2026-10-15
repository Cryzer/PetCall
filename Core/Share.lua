local _, ns = ...

local L = ns.L
local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring

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
        immediate = st.immediate, pets = pets, filter = st.filter, trigger = st.trigger }
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

local function sanitize(list, isKnown, info)
    local out = {}
    if type(list) ~= "table" then return out end
    for _, e in ipairs(list) do
        if type(e) == "table" and type(e[1]) == "string" then
            if e[1] == "AND" or e[1] == "OR" then
                e.items = sanitize(e.items, isKnown, info)
                out[#out + 1] = e
            elseif isKnown(e[1]) then
                if e[1] == "luacode" then
                    e.disabledByImport = true
                    info.hasLuaCode = true
                end
                out[#out + 1] = e
            else
                info.dropped = info.dropped + 1
            end
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
    st.priority = type(data.priority) == "number" and data.priority or 1
    st.defaultValue = type(data.defaultValue) == "number" and data.defaultValue or 0
    st.immediate = data.immediate and true or nil
    st.filter = sanitize(data.filter, knownFilter, info)
    -- fill the existing trigger table in place: the set's watcher holds a reference to it
    local trigger = sanitize(data.trigger, knownCondition, info)
    wipe(st.trigger)
    for i, e in ipairs(trigger) do st.trigger[i] = e end
    ns.Conditions.Normalize(st.trigger)
    wipe(st.pets)
    if type(data.pets) == "table" then
        for _, petID in ns.PetCache:IteratePetIDs() do
            local w = data.pets[ns.PetCache:GetSpeciesID(petID)]
            if type(w) == "number" then st.pets[petID] = w end
        end
    end
    set:ConditionsChanged()
    return true, set.name, info
end
