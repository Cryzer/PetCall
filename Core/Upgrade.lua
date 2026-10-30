local _, ns = ...

local pairs, ipairs, type, tonumber, rawget, sort = pairs, ipairs, type, tonumber, rawget, table.sort
local floor, min, max = math.floor, math.min, math.max

-- Moves the settings from before exceptions into exceptions and the Default set, once per
-- profile. Pure table work: it runs before the profile gets its defaults.
local Upgrade = {}
ns.Upgrade = Upgrade

local DONE = 2
local DEFAULT = "$Default"

-- the old keys with the defaults they had: a missing key meant its default
local OLD = {
    enableInBattleground = true,
    dismissInBattleground = false,
    disableOutsideCities = false,
    dismissWhenStealthed = false,
    noSummonMounted = true,
    disableForQuestItems = true,
    enableInPVE = true,
    dismissInPVE = false,
    verbose = true,
    autoSwitch = { timer = false, timerValue = 30 * 60, citiesOnly = false, onZone = false },
}

-- place types a "no pet" set can fold into, and the built-ins they become
local FOLD = { raid = { "raid" }, dungeon = { "dungeon" }, pvp = { "bg", "arena" }, bg = { "bg" }, arena = { "arena" } }
local LOC_LEGACY = { city = { "city" }, battleground = { "bg", "arena" }, instance = { "dungeon", "raid" } }

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

local function old(profile, key)
    local v = rawget(profile, key)
    if v == nil then return OLD[key] end
    return v
end

local function oldSwitch(profile, key)
    local t = rawget(profile, "autoSwitch")
    local v = type(t) == "table" and t[key] or nil
    if v == nil then return OLD.autoSwitch[key] end
    return v
end

-- whole minutes in the range the old slider had
local function minutes(seconds)
    if type(seconds) ~= "number" or seconds ~= seconds then return 30 end
    return max(1, min(60, floor(seconds / 60 + 0.5)))
end

-- false: summon as usual; "alone": don't summon; "away": dismiss
local function pair(enable, dismiss)
    if dismiss then return "away" end
    if not enable then return "alone" end
    return false
end

local function list(t) return type(t) == "table" and t or {} end

-- pets by hand, by pet rules, or every other pet; a weight of 0 brings none
local function hasPets(s)
    if (tonumber(s.defaultValue) or 0) > 0 then return true end
    for _, w in pairs(list(s.pets)) do
        if (tonumber(w) or 0) > 0 then return true end
    end
    for _, rule in ipairs(list(s.filter)) do
        if type(rule) == "table" and (tonumber(rule[2] or 1) or 0) > 0 then return true end
    end
    return false
end

-- the sets in list order (the first that fits is used), Default left out
local function ordered(sets)
    local out = {}
    for name, s in pairs(sets) do
        if name ~= DEFAULT and type(s) == "table" then out[#out + 1] = { name = name, s = s } end
    end
    local huge = math.huge
    sort(out, function(a, b)
        local oa, ob = a.s.order or huge, b.s.order or huge
        if oa ~= ob then return oa < ob end
        local pa, pb = a.s.priority or 1, b.s.priority or 1
        if pa ~= pb then return pa > pb end
        return a.name < b.name
    end)
    return out
end

-- the built-ins a trigger of exactly one place type stands for, or nil
local function foldTarget(trigger)
    local e = trigger[1]
    if #trigger ~= 1 or type(e) ~= "table" or e[1] ~= "specialLocation" or e.negate then return nil end
    local into, seen = {}, {}
    local locs = e.locs or LOC_LEGACY[e.loc] or {}
    if #locs == 0 then return nil end
    for _, loc in ipairs(locs) do
        if not FOLD[loc] then return nil end
        for _, id in ipairs(FOLD[loc]) do
            if not seen[id] then seen[id], into[#into + 1] = true, id end
        end
    end
    return into
end

local function convertSettings(profile, exc)
    local sets = profile.sets
    local default = rawget(sets, DEFAULT) or {}
    sets[DEFAULT] = default
    default.announce = old(profile, "verbose") and "on" or "off"
    default.switchMinutes = oldSwitch(profile, "timer") and minutes(oldSwitch(profile, "timerValue")) or 0
    local citiesOnly = oldSwitch(profile, "citiesOnly") and true or false
    default.switchCitiesOnly = citiesOnly
    for name, s in pairs(sets) do
        if name ~= DEFAULT and type(s) == "table" and s.switchMinutes ~= nil then s.switchCitiesOnly = citiesOnly end
    end
    profile.switchOnNewMap = oldSwitch(profile, "onZone") and true or false

    local b = exc.builtin
    b.mounted = old(profile, "noSummonMounted") and "alone" or false
    b.hidden = old(profile, "dismissWhenStealthed") and "away" or false
    local pvp = pair(old(profile, "enableInBattleground"), old(profile, "dismissInBattleground"))
    b.bg, b.arena = pvp, pvp
    local pve = pair(old(profile, "enableInPVE"), old(profile, "dismissInPVE"))
    b.dungeon, b.raid, b.scenario = pve, pve, pve
    if pve then
        -- the old check only looked while in a group
        exc.solo.dungeon, exc.solo.raid, exc.solo.scenario = false, false, false
    end
    b.outsideCities = old(profile, "disableOutsideCities") and "alone" or false
    for key in pairs(OLD) do profile[key] = nil end
end

-- "no pet" sets become exceptions (one that always fits turns Auto-summon off); the set
-- stays only when it has pets of its own
local function convertNoPetSets(profile, exc, converted)
    local own = exc.own
    local id = 0
    for _, entry in ipairs(own) do if (entry.id or 0) > id then id = entry.id end end
    local above = {}    -- enabled sets with pets, higher in the list
    for _, item in ipairs(ordered(profile.sets)) do
        local name, s = item.name, item.s
        local trigger = list(s.trigger)
        if s.noPet then
            local forever = s.enabled == false
            local into = not forever and #above == 0 and foldTarget(trigger)
            local fact = { set = name }
            if not forever and #above == 0 and #trigger == 0 then
                -- it kept the pet away everywhere: that is Auto-summon Off
                profile.enable = false
                fact.outcome = "off"
            elseif into then
                for _, key in ipairs(into) do
                    exc.builtin[key] = "away"
                    if key == "dungeon" or key == "raid" then exc.solo[key] = true end
                end
                fact.outcome, fact.into = "folded", into
            else
                local t, never = copy(trigger), false
                local others = {}
                for _, a in ipairs(above) do
                    if #a == 0 then
                        never = true            -- a set that always fits wins everywhere
                    elseif #a == 1 then
                        others[#others + 1] = copy(a[1])
                    else
                        others[#others + 1] = { "AND", items = copy(a) }
                    end
                end
                if #others > 0 then t[#t + 1] = { "OR", negate = true, items = others } end
                local choice = not (forever or never) and "away" or false
                id = id + 1
                own[#own + 1] = { id = id, trigger = t, choice = choice, from = name }
                fact.outcome = choice and "deleted" or "disabled"
            end
            if hasPets(s) then
                s.noPet, s.enabled, s.pausedUntil = nil, false, nil
                if fact.outcome == "deleted" then fact.outcome = "paused" end
            else
                profile.sets[name] = nil
            end
            converted[#converted + 1] = fact
        elseif s.enabled ~= false and hasPets(s) then
            above[#above + 1] = trigger
        end
    end
end

function Upgrade.Profile(profile, global)
    if profile.upgraded == DONE then return end
    profile.upgraded = DONE
    local sets = rawget(profile, "sets")
    local hadOld, hadNoPet = false, false
    for key in pairs(OLD) do if rawget(profile, key) ~= nil then hadOld = true end end
    if type(sets) == "table" then
        for name, s in pairs(sets) do
            if name ~= DEFAULT and type(s) == "table" and s.noPet then hadNoPet = true end
        end
        local default = rawget(sets, DEFAULT)
        if type(default) == "table" then default.noPet = nil end
    end
    if not (hadOld or hadNoPet) then return end

    profile.sets = type(sets) == "table" and sets or {}
    local exc = type(profile.exceptions) == "table" and profile.exceptions or {}
    profile.exceptions = exc
    exc.builtin, exc.solo, exc.own = list(exc.builtin), list(exc.solo), list(exc.own)
    local converted = {}
    convertSettings(profile, exc)
    if hadNoPet then convertNoPetSets(profile, exc, converted) end
    profile.upgradeFacts = { converted = converted }
    if not global.welcomeSeen then global.welcomePending = true end
end
