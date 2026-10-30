local _, ns = ...

local L = ns.L
local ipairs, pairs, format, tconcat = ipairs, pairs, string.format, table.concat

local Recommended = ns:NewModule("Recommended")
ns.Recommended = Recommended

Recommended.VALUES = {
    enable = true,
    nearPEWOnly = false,
    waitTimer = 3,
    switchOnNewMap = false,
    overrideSetLoadout = true,
    defaultSwitch = { 30, false },
    defaultAnnounce = "off",
    builtin = { mounted = "alone", bg = "away", arena = "away", dungeon = "away", raid = "away", scenario = false,
        hidden = "away", outsideCities = false },
    solo = { dungeon = true, raid = true, scenario = true },
}
local V = Recommended.VALUES

local PROFILE_KEYS = { "nearPEWOnly", "waitTimer", "switchOnNewMap", "overrideSetLoadout" }
local SOLO_ORDER = { "dungeon", "raid", "scenario" }
local CHOICE_LABEL = ns.Exceptions.CHOICE_LABEL

local function default() return ns.Sets:Get(ns.Sets.DEFAULT) end

local function builtins()
    local out = {}
    for _, exc in ipairs(ns.Exceptions:List()) do
        if exc.builtin then out[exc.id] = exc end
    end
    return out
end

-- every setting Apply can change, as one flat table
local function snapshot()
    local s = { enable = ns:IsAutoSummon(), builtin = {}, solo = {} }
    for _, key in ipairs(PROFILE_KEYS) do s[key] = ns.db.profile[key] end
    local d = default()
    s.minutes, s.citiesOnly = d:GetSwitch()
    s.announce = d:GetAnnounce()
    for id, exc in pairs(builtins()) do
        s.builtin[id] = exc:GetChoice()
        if exc:HasSolo() then s.solo[id] = exc:GetSolo() end
    end
    return s
end

local function same(a, b)
    for k, v in pairs(a) do
        if type(v) == "table" then
            if type(b[k]) ~= "table" or not same(v, b[k]) then return false end
        elseif b[k] ~= v then
            return false
        end
    end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function yesNo(on) return on and L["Yes"] or L["No"] end
local function onOff(on) return on and L["On"] or L["Off"] end

local function bringOut(only, seconds)
    if only then return L["Only after a loading screen"] end
    return format(L["When I stand still, %s s"], format("%g", seconds))
end

local function switchText(minutes, citiesOnly)
    if not minutes or minutes <= 0 then return L["Off"] end
    return format(citiesOnly and L["%d minutes, only in cities"] or L["%d minutes"], minutes)
end

local function soloText(flags)
    local names = {}
    for _, id in ipairs(SOLO_ORDER) do
        if flags[id] then names[#names + 1] = builtins()[id].def.name end
    end
    return #names > 0 and tconcat(names, ", ") or L["None"]
end

local function row(key, label, yours, recommended)
    return { key = key, label = label, yours = yours, recommended = recommended, same = yours == recommended }
end

function Recommended:Rows()
    local p = ns.db.profile
    local rows = {}
    local function add(...) rows[#rows + 1] = row(...) end
    local minutes, cities = default():GetSwitch()
    add("enable", L["Auto-summon"], onOff(ns:IsAutoSummon()), onOff(V.enable))
    add("bringOut", L["Bring out a pet"], bringOut(p.nearPEWOnly, p.waitTimer), bringOut(V.nearPEWOnly, V.waitTimer))
    add("newMap", L["New pet on a new map"], yesNo(p.switchOnNewMap), yesNo(V.switchOnNewMap))
    add("petBattle", L["After a pet battle"],
        p.overrideSetLoadout and L["Bring back my pet"] or L["Keep the game's pick"],
        V.overrideSetLoadout and L["Bring back my pet"] or L["Keep the game's pick"])
    add("defaultSwitch", L["Default set: New pet every"], switchText(minutes, cities), switchText(V.defaultSwitch[1], V.defaultSwitch[2]))
    add("defaultAnnounce", L["Default set: Message on summon"],
        default():GetAnnounce() and L["Always"] or L["Never"], V.defaultAnnounce == "off" and L["Never"] or L["Always"])
    local solo = {}
    for _, exc in ipairs(ns.Exceptions:List()) do
        if exc.builtin then
            add(exc.id, exc:DisplayName(), CHOICE_LABEL[exc:GetChoice()], CHOICE_LABEL[V.builtin[exc.id]])
            if exc:HasSolo() then solo[exc.id] = exc:GetSolo() end
        end
    end
    add("solo", L["Also when solo"], soloText(solo), soloText(V.solo))
    for _, exc in ipairs(ns.Exceptions:List()) do
        if not exc.builtin and exc.entry.from then
            rows[#rows + 1] = { key = exc.id, label = exc:DisplayName(), yours = CHOICE_LABEL[exc:GetChoice()],
                recommended = L["kept"], same = true }
        end
    end
    return rows
end

local before, applied      -- the values before Apply, and the values Apply left

local function drop()
    if not before then return end
    before, applied = nil, nil
    ns:Fire("RecommendedUndoChanged")
end

local function restore(s)
    ns:SetAutoSummon(s.enable)
    for _, key in ipairs(PROFILE_KEYS) do ns:SetProfileValue(key, s[key]) end
    local d = default()
    d:SetSwitch(s.minutes, s.citiesOnly)
    d:SetAnnounce(s.announce)
    for id, exc in pairs(builtins()) do
        exc:SetChoice(s.builtin[id])
        if exc:HasSolo() then exc:SetSolo(s.solo[id]) end
    end
end

function Recommended:Apply()
    local old = snapshot()
    local new = {
        enable = V.enable, minutes = V.defaultSwitch[1], citiesOnly = V.defaultSwitch[2],
        announce = V.defaultAnnounce ~= "off", builtin = V.builtin, solo = V.solo,
    }
    for _, key in ipairs(PROFILE_KEYS) do new[key] = V[key] end
    restore(new)
    before, applied = old, snapshot()
    ns:Fire("RecommendedApplied")
    ns:Fire("RecommendedUndoChanged")
end

function Recommended:CanUndo() return before ~= nil end

function Recommended:Undo()
    if not before then return end
    local old = before
    before, applied = nil, nil
    restore(old)
    ns:Fire("RecommendedUndoChanged")
end

-- a change by hand: the settings no longer are what Apply left
local function check()
    if applied and not same(applied, snapshot()) then drop() end
end

function Recommended:OnInitialize()
    for _, name in ipairs({ "ExceptionsChanged", "AutoSummonChanged", "ProfileValueChanged" }) do
        ns:RegisterCallback(self, name, check)
    end
    ns:RegisterCallback(self, "SetsChanged", function(_, name)
        if name == nil or name == ns.Sets.DEFAULT then check() end
    end)
    ns:RegisterCallback(self, "ProfileChanged", drop)
end
