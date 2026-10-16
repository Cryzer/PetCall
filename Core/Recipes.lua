local _, ns = ...

local L = ns.L
local ipairs, pairs, type, format, sort, unpack = ipairs, pairs, type, format, table.sort, unpack
local R = {}
ns.Recipes = R

-- Ready-made sets: conditions plus pet rules. A recipe only ever creates a new,
-- ordinary set; it never touches the sets the player already has.

local NORMAL = 1
local function types(...) return { "petType", NORMAL, petTypes = { ... } } end

-- pet types: 1 Humanoid 2 Dragonkin 3 Flying 4 Undead 5 Critter 6 Magic 7 Elemental 8 Beast 9 Aquatic 10 Mechanical
local CLASS_TYPES = {
    HUNTER = { 8 }, WARLOCK = { 4, 6 }, MAGE = { 7, 6 }, DEATHKNIGHT = { 4 }, DRUID = { 5, 8 }, SHAMAN = { 7 },
    PRIEST = { 6, 1 }, PALADIN = { 1, 6 }, WARRIOR = { 8, 1 }, ROGUE = { 5, 4 }, MONK = { 5, 7 },
    DEMONHUNTER = { 6, 4 }, EVOKER = { 2 },
}

local FIXED = {
    { key = "swimming", title = L["Water pets while swimming"], hint = L["When you swim. Aquatic pets."],
      conditions = { { "activity", swimming = true } }, rules = { types(9) } },
    { key = "outdoors", title = L["Flyers in the open world"], hint = L["Outdoors in the open world. Flying pets."],
      conditions = { { "specialLocation", locs = { "world" } }, { "activity", outdoors = true } }, rules = { types(3) } },
    { key = "zone", title = L["Pets from this zone"], hint = L["Everywhere, before the Default set. Pets native to the zone you are in."],
      conditions = {}, rules = { { "nativeZone", NORMAL } }, lowest = true },
    { key = "home", title = L["At my house"], hint = L["At your house and plot. Favorites and critters."],
      conditions = { { "housing", ownHome = true } }, rules = { { "favorites", NORMAL }, types(5) } },
    { key = "instances", title = L["Dungeons and raids"], hint = L["In dungeons and raids. Your rare level 25 pets."],
      conditions = { { "specialLocation", locs = { "dungeon", "raid" } } },
      rules = { { "AND", NORMAL, items = { { "level", operator = ">=", level = "25" }, { "rare" } } } } },
    { key = "night", title = L["Night owls"], hint = L["From 20:00 to 06:00. Undead and magic pets."],
      conditions = { { "timeOfDay", from = 20 * 60, to = 6 * 60 } }, rules = { types(4, 6) } },
    { key = "afk", title = L["Favorites while AFK"], hint = L["While you are AFK. Your favorites."],
      conditions = { { "activity", afk = true } }, rules = { { "favorites", NORMAL } } },
}

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

-- a recipe without conditions must not take over: it gets the lowest priority
local function finish(r)
    r.priority = r.lowest and ns.Weights.LEVELS[2].value or nil
    return r
end

local function classRecipe()
    local className, class = UnitClass("player")
    local list = CLASS_TYPES[class]
    if not list then return nil end
    return finish({ key = "class", title = format(L["%s theme"], className),
        hint = format(L["On your %s characters. Pets that suit the class."], className),
        conditions = { { "specialization", class = class, spec = -1 } }, rules = { types(unpack(list)) } })
end

local function holidayRecipe(h)
    return finish({ key = "holiday:" .. h.value, title = h.label, holiday = true,
        hint = format(L["During %s. Pets from the event."], h.label),
        conditions = { { "holiday", holidayIDs = { h.value } } }, rules = { { "source", NORMAL, text = h.label } } })
end

-- how many tiles (copies grouped) the set would draw from, and up to four of them, most likely first
function R.Count(r)
    local tbl = ns.Weights.Build({ pets = {}, defaultValue = 0, filter = r.rules })
    local found = {}
    for _, id in ns.PetCache:IteratePetIDs() do
        if ns.PetCache:IsPrimary(id) then
            local w = 0
            for _, c in ipairs(ns.PetCache:GetCopies(id)) do w = w + ns.Weights.Sum(tbl, c) end
            if w > 0 then found[#found + 1] = { id = id, w = w } end
        end
    end
    sort(found, function(a, b)
        if a.w ~= b.w then return a.w > b.w end
        return ns.PetCache:GetSortKey(a.id) < ns.PetCache:GetSortKey(b.id)
    end)
    local sample = {}
    for i = 1, math.min(4, #found) do sample[i] = found[i].id end
    return #found, sample
end

function R.Usable(r)
    if R.Count(r) == 0 then return false, L["You have no pets for this yet."] end
    return true
end

function R.List()
    local out = {}
    for _, r in ipairs(FIXED) do out[#out + 1] = finish(r) end
    local class = classRecipe()
    if class then out[#out + 1] = class end
    for _, h in ipairs(ns.Conditions.KnownHolidays()) do
        local r = holidayRecipe(h)
        if R.Count(r) > 0 then out[#out + 1] = r end   -- weekly events would only add grey cards
    end
    return out
end

function R.UniqueName(base)
    if not ns.Sets:Get(base) then return base end
    local i = 2
    while ns.Sets:Get(base .. " " .. i) do i = i + 1 end
    return base .. " " .. i
end

function R.Create(r)
    local set = ns.Sets:Create(R.UniqueName(r.title))
    if not set then return nil end
    set.settings.defaultValue = 0
    -- fill the set's own tables: its condition watcher already holds the trigger table
    local trigger, filter = set.settings.trigger, set.settings.filter
    wipe(trigger) wipe(filter)
    for _, e in ipairs(r.conditions) do trigger[#trigger + 1] = copy(e) end
    for _, e in ipairs(r.rules) do filter[#filter + 1] = copy(e) end
    if r.priority then set:SetPriority(r.priority) end
    set:FiltersChanged()
    set:ConditionsChanged()
    return set
end
