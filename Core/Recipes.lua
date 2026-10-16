local _, ns = ...

local L = ns.L
local ipairs, pairs, type, format, sort, unpack = ipairs, pairs, type, format, table.sort, unpack
local R = {}
ns.Recipes = R

-- Ready-made sets: conditions plus pet rules. A recipe only ever creates a new,
-- ordinary set; it never touches the sets the player already has.

-- weights by name, so recipes read like the buttons in the preview
local function weight(key)
    for _, lvl in ipairs(ns.Weights.LEVELS) do if lvl.key == key then return lvl.value end end
end
local NORMAL, OFTEN, VERY_OFTEN, RARELY, VERY_RARELY =
    weight("NORMAL"), weight("HIGH"), weight("EXTRA_HIGH"), weight("LOW"), weight("EXTRA_LOW")

local function types(w, ...) return { "petType", w, petTypes = { ... } } end
-- several condition groups, any of which is enough ("or")
local function anyOf(...)
    local items = {}
    for i, g in ipairs({ ... }) do items[i] = { "AND", items = g } end
    return { { "OR", items = items } }
end
local CITY = { "specialLocation", locs = { "city" } }
local WORLD = { "specialLocation", locs = { "world" } }

-- pet types: 1 Humanoid 2 Dragonkin 3 Flying 4 Undead 5 Critter 6 Magic 7 Elemental 8 Beast 9 Aquatic 10 Mechanical
local CLASS_TYPES = {
    HUNTER = { 8 }, WARLOCK = { 4, 6 }, MAGE = { 7, 6 }, DEATHKNIGHT = { 4 }, DRUID = { 5, 8 }, SHAMAN = { 7 },
    PRIEST = { 6, 1 }, PALADIN = { 1, 6 }, WARRIOR = { 8, 1 }, ROGUE = { 5, 4 }, MONK = { 5, 7 },
    DEMONHUNTER = { 6, 4 }, EVOKER = { 2 },
}

local I = "Interface\\Icons\\"
local FIXED = {
    -- places
    { key = "showoff", category = "places", icon = I .. "INV_Misc_Gem_Diamond_01", immediate = true,
      title = L["Where people can see you"], hint = L["In cities or at a friend's house: rare pets very often, summoned the moment you arrive."],
      conditions = anyOf({ CITY }, { { "housing", otherHome = true } }),
      rules = { { "rare", VERY_OFTEN }, { "favorites", NORMAL } } },
    { key = "outdoors", category = "places", icon = I .. "Ability_Mount_Gryphon_01", title = L["Flyers in the open world"],
      hint = L["Outdoors in the open world. Flying pets."],
      conditions = { WORLD, { "activity", outdoors = true } }, rules = { types(NORMAL, 3) } },
    { key = "zone", category = "places", icon = I .. "INV_Misc_Map_01", title = L["Pets from this zone"],
      hint = L["Everywhere, before the Default set. Pets native to the zone you are in."],
      conditions = {}, rules = { { "nativeZone", NORMAL } }, lowest = true },
    { key = "home", category = "places", icon = I .. "INV_Misc_Rune_01", title = L["At my house"],
      hint = L["At your house and plot. Favorites and critters."],
      conditions = { { "housing", ownHome = true } }, rules = { { "favorites", NORMAL }, types(NORMAL, 5) } },
    { key = "visit", category = "places", icon = I .. "INV_Misc_Note_01", title = L["Visiting friends"],
      hint = L["At someone else's house: mostly favorites, now and then any other pet."],
      conditions = { { "housing", otherHome = true } }, rules = { { "favorites", VERY_OFTEN } }, defaultValue = VERY_RARELY },
    { key = "instances", category = "places", icon = I .. "INV_Misc_Bone_HumanSkull_01", title = L["Dungeons and raids"],
      hint = L["In dungeons and raids. Your rare level 25 pets."],
      conditions = { { "specialLocation", locs = { "dungeon", "raid" } } },
      rules = { { "AND", NORMAL, items = { { "level", operator = ">=", level = "25" }, { "rare" } } } } },
    { key = "delve", category = "places", icon = I .. "INV_Pick_02", title = L["Delve crew"],
      hint = L["In delves. Mechanical pets often, critters now and then."],
      conditions = { { "specialLocation", locs = { "delve" } } }, rules = { types(OFTEN, 10), types(RARELY, 5) } },
    -- moments
    { key = "swimming", category = "moments", icon = I .. "Spell_Frost_SummonWaterElemental", title = L["Water pets while swimming"],
      hint = L["When you swim. Aquatic pets."],
      conditions = { { "activity", swimming = true } }, rules = { types(NORMAL, 9) } },
    { key = "morning", category = "moments", icon = I .. "INV_Drink_05", title = L["Morning critters"],
      hint = L["From 06:00 to 10:00. Small critters to start the day."],
      conditions = { { "timeOfDay", from = 6 * 60, to = 10 * 60 } }, rules = { types(NORMAL, 5) } },
    { key = "night", category = "moments", icon = I .. "Spell_Shadow_Twilight", title = L["Night owls"],
      hint = L["From 20:00 to 06:00. Undead and magic pets."],
      conditions = { { "timeOfDay", from = 20 * 60, to = 6 * 60 } }, rules = { types(NORMAL, 4, 6) } },
    { key = "witching", category = "moments", icon = I .. "Spell_Shadow_RaiseDead", title = L["Witching hour"],
      hint = L["From midnight to 03:00. Undead very often, magic pets sometimes."],
      conditions = { { "timeOfDay", from = 0, to = 3 * 60 } }, rules = { types(VERY_OFTEN, 4), types(RARELY, 6) } },
    { key = "indoors", category = "moments", icon = I .. "INV_Misc_Lantern_01", title = L["Indoor company"],
      hint = L["Indoors. Critters and humanoids that fit under a roof."],
      conditions = { { "activity", indoors = true } }, rules = { types(NORMAL, 5, 1) } },
    { key = "form", category = "moments", icon = I .. "Ability_Druid_TravelForm", title = L["Pack of the wild"],
      hint = L["While in a shapeshift form: beasts run with you."],
      conditions = { { "activity", form = true } }, rules = { types(OFTEN, 8) } },
    { key = "afk", category = "moments", icon = I .. "Spell_Nature_Sleep", title = L["Favorites while AFK"],
      hint = L["While you are AFK. Your favorites."],
      conditions = { { "activity", afk = true } }, rules = { { "favorites", NORMAL } } },
    -- company
    { key = "solo", category = "company", icon = I .. "Ability_Hunter_Pathfinding", title = L["Lone wanderer"],
      hint = L["Playing alone in the open world: beasts and flyers keep you company."],
      conditions = { { "groupType", solo = true }, WORLD }, rules = { types(NORMAL, 8, 3) } },
    { key = "party", category = "company", icon = I .. "Spell_Holy_PrayerOfFortitude", title = L["Party mascots"],
      hint = L["In a party or raid: favorites very often, other level 25 pets sometimes."],
      conditions = { { "groupType", party = true, raid = true } },
      rules = { { "favorites", VERY_OFTEN }, { "level", RARELY, operator = ">=", level = "25" } } },
    -- collections
    { key = "favfirst", category = "collections", icon = I .. "Spell_Holy_SealOfSacrifice", title = L["Favorites first"],
      hint = L["Everywhere, before the Default set: favorites very often, every other pet very rarely."],
      conditions = {}, rules = { { "favorites", VERY_OFTEN } }, defaultValue = VERY_RARELY, lowest = true },
    { key = "little", category = "collections", icon = I .. "INV_Egg_03", title = L["Walk the little ones"],
      hint = L["In the open world: pets below level 10 very often, the rest rarely."],
      conditions = { WORLD }, rules = { { "level", VERY_OFTEN, operator = "<", level = "10" } }, defaultValue = RARELY },
    { key = "tradingpost", category = "collections", icon = I .. "INV_Misc_Coin_01", title = L["Trading Post finds"],
      hint = L["In cities. Pets from the Trading Post."],
      conditions = { CITY }, rules = { { "source", NORMAL, text = "Trading Post" } } },
    { key = "festive", category = "collections", icon = I .. "INV_Misc_Gift_01", title = L["Festive mood"],
      hint = L["During any holiday. Every world event pet you own."],
      conditions = { { "holiday", holidayIDs = { 0 } } }, rules = { { "source", NORMAL, text = "World Event" } } },
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
    r.category = r.category or "places"
    return r
end

local function classRecipe()
    local className, class = UnitClass("player")
    local list = CLASS_TYPES[class]
    if not list then return nil end
    return finish({ key = "class", category = "class", atlas = "classicon-" .. strlower(class), title = format(L["%s theme"], className),
        hint = format(L["On your %s characters. Pets that suit the class."], className),
        conditions = { { "specialization", class = class, spec = -1 } }, rules = { types(NORMAL, unpack(list)) } })
end

local function holidayRecipe(h)
    -- calendar art has a frame around it; the event picture is the top-left part
    return finish({ key = "holiday:" .. h.value, category = "holiday", icon = h.icon, iconCoords = { 0, 0.7109375, 0, 0.7109375 },
        title = h.label, holiday = true,
        hint = format(L["During %s. Pets from the event."], h.label),
        conditions = { { "holiday", holidayIDs = { h.value } } }, rules = { { "source", NORMAL, text = h.label } } })
end

-- how many tiles (copies grouped) the set would draw from, and up to four of them, most likely first
function R.Count(r)
    local tbl = ns.Weights.Build({ pets = {}, defaultValue = r.defaultValue or 0, filter = r.rules })
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

-- the set this recipe made earlier, found by its name
function R.Existing(r) return ns.Sets:Get(r.title) end

function R.UniqueName(base)
    if not ns.Sets:Get(base) then return base end
    local i = 2
    while ns.Sets:Get(base .. " " .. i) do i = i + 1 end
    return base .. " " .. i
end

function R.Create(r)
    local set = ns.Sets:Create(R.UniqueName(r.title))
    if not set then return nil end
    set.settings.defaultValue = r.defaultValue or 0
    -- fill the set's own tables: its condition watcher already holds the trigger table
    local trigger, filter = set.settings.trigger, set.settings.filter
    wipe(trigger) wipe(filter)
    for _, e in ipairs(r.conditions) do trigger[#trigger + 1] = copy(e) end
    for _, e in ipairs(r.rules) do filter[#filter + 1] = copy(e) end
    if r.priority then set:SetPriority(r.priority) end
    if r.immediate then set:SetImmediate(true) end
    set:FiltersChanged()
    set:ConditionsChanged()
    return set
end
