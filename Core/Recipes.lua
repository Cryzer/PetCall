local _, ns = ...

local L = ns.L
local ipairs, pairs, type, format, tinsert, unpack = ipairs, pairs, type, format, table.insert, unpack
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
-- category = the gallery section, by when a set is used
local FIXED = {
    -- everyday: used everywhere, just above the Default set
    { key = "favfirst", category = "everyday", icon = I .. "Spell_Holy_SealOfSacrifice", title = L["Favorites first"],
      hint = L["Everywhere, before the Default set: favorites very often, every other pet very rarely."],
      conditions = {}, rules = { { "favorites", VERY_OFTEN } }, defaultValue = VERY_RARELY, lowest = true },
    { key = "zone", category = "everyday", icon = I .. "INV_Misc_Map_01", title = L["Pets from this zone"],
      hint = L["Everywhere, before the Default set. Pets native to the zone you are in."],
      conditions = {}, rules = { { "nativeZone", NORMAL } }, lowest = true },
    { key = "here", category = "everyday", icon = I .. "INV_Misc_Map02", title = L["Pets from this expansion"],
      hint = L["Everywhere, before the Default set. Pets from the expansion of the land you are in."],
      conditions = {}, rules = { { "expansionHere", NORMAL } }, lowest = true },
    { key = "rareparade", category = "everyday", icon = I .. "INV_Misc_Gem_Sapphire_02", title = L["Rare parade"],
      hint = L["Everywhere, before the Default set: rare pets very often, the rest rarely."],
      conditions = {}, rules = { { "rare", VERY_OFTEN } }, defaultValue = RARELY, lowest = true },
    { key = "battleready", category = "everyday", icon = I .. "INV_Pet_BattlePetTraining", title = L["Battle-ready team"],
      hint = L["Everywhere, before the Default set: level 25 favorites very often, other level 25 pets often."],
      conditions = {}, rules = { { "AND", VERY_OFTEN, items = { { "level", operator = ">=", level = "25" }, { "favorites" } } },
          { "level", OFTEN, operator = ">=", level = "25" } }, lowest = true },
    { key = "little", category = "everyday", icon = I .. "INV_Egg_03", title = L["Walk the little ones"],
      hint = L["In the open world: pets below level 10 very often, the rest rarely."],
      conditions = { WORLD }, rules = { { "level", VERY_OFTEN, operator = "<", level = "10" } }, defaultValue = RARELY },
    -- cities and home
    { key = "showoff", category = "town", icon = I .. "INV_Misc_Gem_Diamond_01", immediate = true,
      title = L["Where people can see you"], hint = L["In cities or at a friend's house: rare pets very often, summoned the moment you arrive."],
      conditions = anyOf({ CITY }, { { "housing", otherHome = true } }),
      rules = { { "rare", VERY_OFTEN }, { "favorites", NORMAL } } },
    { key = "evening", category = "town", icon = I .. "INV_Misc_Candle_01", title = L["Evening in town"],
      hint = L["In cities from 18:00 to 23:00: favorites often, humanoids now and then."],
      conditions = { CITY, { "timeOfDay", from = 18 * 60, to = 23 * 60 } }, rules = { { "favorites", OFTEN }, types(RARELY, 1) } },
    { key = "tradingpost", category = "town", icon = I .. "INV_Misc_Coin_01", title = L["Trading Post finds"],
      hint = L["In cities. Pets from the Trading Post."],
      conditions = { CITY }, rules = { { "source", NORMAL, sources = { 12 } } } },
    { key = "home", category = "town", icon = I .. "INV_Misc_Rune_01", title = L["At my house"],
      hint = L["At your house and plot. Your favorites."],
      conditions = { { "housing", ownHome = true } }, rules = { { "favorites", NORMAL } } },
    { key = "visit", category = "town", icon = I .. "INV_Misc_Note_01", title = L["Visiting friends"],
      hint = L["At someone else's house: mostly favorites, now and then any other pet."],
      conditions = { { "housing", otherHome = true } }, rules = { { "favorites", VERY_OFTEN } }, defaultValue = VERY_RARELY },
    -- the world and instances
    { key = "outdoors", category = "world", icon = I .. "Ability_Mount_Gryphon_01", title = L["Flyers in the open world"],
      hint = L["Outdoors in the open world. Flying pets."],
      conditions = { WORLD, { "activity", outdoors = true } }, rules = { types(NORMAL, 3) } },
    { key = "instances", category = "world", icon = I .. "INV_Misc_Bone_HumanSkull_01", title = L["Dungeons and raids"],
      hint = L["In dungeons and raids. Your rare level 25 pets."],
      conditions = { { "specialLocation", locs = { "dungeon", "raid" } } },
      rules = { { "AND", NORMAL, items = { { "level", operator = ">=", level = "25" }, { "rare" } } } } },
    { key = "delve", category = "world", icon = I .. "INV_Pick_02", title = L["Delve crew"],
      hint = L["In delves. Mechanical pets often, critters now and then."],
      conditions = { { "specialLocation", locs = { "delve" } } }, rules = { types(OFTEN, 10), types(RARELY, 5) } },
    { key = "scenario", category = "world", icon = I .. "INV_Sword_04", title = L["Scenario sidekicks"],
      hint = L["In scenarios. Humanoids and beasts."],
      conditions = { { "specialLocation", locs = { "scenario" } } }, rules = { types(NORMAL, 1, 8) } },
    { key = "quietraid", category = "world", icon = I .. "Spell_Holy_Silence", title = L["Quiet raid nights"],
      hint = L["In raids: no pet at all."],
      conditions = { { "specialLocation", locs = { "raid" } } }, rules = {}, noPet = true },
    { key = "quietpvp", category = "world", icon = I .. "Achievement_BG_winWSG", title = L["Quiet in PvP"],
      hint = L["In battlegrounds and arenas: no pet at all."],
      conditions = { { "specialLocation", locs = { "pvp" } } }, rules = {}, noPet = true },
    -- on the move
    { key = "swimming", category = "moving", icon = I .. "Spell_Frost_SummonWaterElemental", title = L["Water pets while swimming"],
      hint = L["When you swim. Aquatic pets."],
      conditions = { { "activity", swimming = true } }, rules = { types(NORMAL, 9) } },
    { key = "riding", category = "moving", icon = I .. "Ability_Mount_RidingHorse", title = L["Riding escort"],
      hint = L["While you ride on the ground: flyers and dragonkin keep up with you."],
      conditions = { { "activity", mounted = true } }, rules = { types(NORMAL, 3, 2) }, needsMounted = true },
    { key = "form", category = "moving", icon = I .. "Ability_Druid_TravelForm", title = L["Pack of the wild"],
      hint = L["While in a shapeshift form: beasts run with you."],
      conditions = { { "activity", form = true } }, rules = { types(OFTEN, 8) } },
    { key = "indoors", category = "moving", icon = I .. "INV_Misc_Lantern_01", title = L["Indoor company"],
      hint = L["Indoors. Critters and humanoids that fit under a roof."],
      conditions = { { "activity", indoors = true } }, rules = { types(NORMAL, 5, 1) } },
    { key = "afk", category = "moving", icon = I .. "Spell_Nature_Sleep", title = L["Favorites while AFK"],
      hint = L["While you are AFK. Your favorites."],
      conditions = { { "activity", afk = true } }, rules = { { "favorites", NORMAL } } },
    -- time of day
    { key = "morning", category = "time", icon = I .. "INV_Drink_05", title = L["Morning critters"],
      hint = L["From 06:00 to 10:00. Small critters to start the day."],
      conditions = { { "timeOfDay", from = 6 * 60, to = 10 * 60 } }, rules = { types(NORMAL, 5) } },
    { key = "dusk", category = "time", icon = I .. "Spell_Fire_Elemental_Totem", title = L["Elemental dusk"],
      hint = L["From 18:00 to 21:00. Elemental and magic pets."],
      conditions = { { "timeOfDay", from = 18 * 60, to = 21 * 60 } }, rules = { types(NORMAL, 7, 6) } },
    { key = "night", category = "time", icon = I .. "Spell_Shadow_Twilight", title = L["Night owls"],
      hint = L["From 20:00 to 06:00. Undead and magic pets."],
      conditions = { { "timeOfDay", from = 20 * 60, to = 6 * 60 } }, rules = { types(NORMAL, 4, 6) } },
    { key = "witching", category = "time", icon = I .. "Spell_Shadow_RaiseDead", title = L["Witching hour"],
      hint = L["From midnight to 03:00. Undead very often, magic pets sometimes."],
      conditions = { { "timeOfDay", from = 0, to = 3 * 60 } }, rules = { types(VERY_OFTEN, 4), types(RARELY, 6) } },
    -- company
    { key = "solo", category = "company", icon = I .. "Ability_Hunter_Pathfinding", title = L["Lone wanderer"],
      hint = L["Playing alone in the open world: beasts and flyers keep you company."],
      conditions = { { "groupType", solo = true }, WORLD }, rules = { types(NORMAL, 8, 3) } },
    { key = "party", category = "company", icon = I .. "Spell_Holy_PrayerOfFortitude", title = L["Party mascots"],
      hint = L["In a party or raid: favorites very often, other level 25 pets sometimes."],
      conditions = { { "groupType", party = true, raid = true } },
      rules = { { "favorites", VERY_OFTEN }, { "level", RARELY, operator = ">=", level = "25" } } },
    { key = "raidzoo", category = "company", icon = I .. "INV_Box_PetCarrier_01", title = L["Raid group zoo"],
      hint = L["In a raid group: any pet you own, a new one every 5 minutes."],
      conditions = { { "groupType", raid = true } }, rules = {}, defaultValue = NORMAL, switchMinutes = 5 },
    -- holidays
    { key = "festive", category = "holiday", icon = I .. "INV_Misc_Gift_01", title = L["Festive mood"],
      hint = L["During any holiday. Every world event pet you own."],
      conditions = { { "holiday", holidayIDs = { 0 } } }, rules = { { "source", NORMAL, sources = { 7 } } } },
}

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

-- a recipe without conditions must not take over: R.Create puts its set at the bottom (r.lowest)
local function finish(r)
    r.category = r.category or "everyday"
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

-- one set per pet family and per source, used everywhere just above the Default set
local function familyRecipe(t)
    local name = _G["BATTLE_PET_NAME_" .. t] or tostring(t)
    local suffix = PET_TYPE_SUFFIX and PET_TYPE_SUFFIX[t]
    return finish({ key = "family:" .. t, category = "families", icon = suffix and (I .. "Pet_Type_" .. suffix) or nil,
        title = format(L["%s pets"], name), hint = format(L["Everywhere, before the Default set. Pet type: %s."], name),
        conditions = {}, rules = { types(NORMAL, t) }, lowest = true })
end

local function sourceRecipe(i)
    local label = ns.AutoRules.SourceLabel(i)
    if not label then return nil end
    return finish({ key = "source:" .. i, category = "sources",
        title = format(L["%s pets"], label), hint = format(L["Everywhere, before the Default set. Source: %s."], label),
        conditions = {}, rules = { { "source", NORMAL, sources = { i } } }, lowest = true })
end

-- a picture of each expansion: the game's own expansion icons, then a land of each newer
-- one as its Explore achievement shows it (Battle for Azeroth's by faction); a later
-- expansion than these gets the plain WoW token until it has one
local EXPANSION_ICONS = {
    [0] = "ExpansionIcon_Classic", [1] = "ExpansionIcon_BurningCrusade", [2] = "ExpansionIcon_WrathoftheLichKing",
    [3] = "ExpansionIcon_Cataclysm", [4] = "ExpansionIcon_MistsofPandaria", [5] = "ExpansionIcon_Draenor",
    [6] = "Achievements_Zone_BrokenShore", [8] = "INV_Bastion", [9] = "Achievement_Zone_WakingShores",
    [10] = "Achievement_Zone_IsleofDorn", [11] = "INV_Achievement_Zone_ZulAman",
}
local function expansionIcon(i)
    if i == 7 then return UnitFactionGroup("player") == "Horde" and "INV_Zuldazar" or "INV_TiragardeSound" end
    return EXPANSION_ICONS[i] or "INV_Misc_Token_Boost_Generic"
end

-- one set per expansion, used everywhere just above the Default set
local function expansionRecipe(i)
    local name = ns.Expansions.Name(i)
    return finish({ key = "expansion:" .. i, category = "expansions", icon = I .. expansionIcon(i),
        title = format(L["%s pets"], name), hint = format(L["Everywhere, before the Default set. Expansion: %s."], name),
        conditions = {}, rules = { { "expansion", NORMAL, expansions = { i } } }, lowest = true })
end

local function holidayRecipe(h)
    -- calendar art has a frame around it; the event picture is the top-left part
    return finish({ key = "holiday:" .. h.value, category = "holiday", icon = h.icon, iconCoords = { 0, 0.7109375, 0, 0.7109375 },
        title = h.label, holiday = true,
        hint = format(L["During %s. Pets from the event."], h.label),
        conditions = { { "holiday", holidayIDs = { h.value } } }, rules = { { "source", NORMAL, text = h.label } } })
end

-- how many tiles (copies grouped) the set would draw from, and up to four of them, most likely first
local function count(r)
    local tbl = ns.Weights.Build({ pets = {}, defaultValue = r.defaultValue or 0, filter = r.rules })
    -- one pass over the draw table: tickets add up on the primary copy
    local sums = {}
    for i = 1, #tbl, 2 do
        local primary = ns.PetCache:GetCopies(tbl[i + 1])[1]
        sums[primary] = (sums[primary] or 0) + tbl[i]
    end
    -- the four likeliest, then by name: kept in order while going over the tiles once
    -- (a card shows four of maybe a thousand)
    local n, sample = 0, {}
    local function before(a, b)
        if sums[a] ~= sums[b] then return sums[a] > sums[b] end
        local ka, kb = ns.PetCache:GetSortKey(a), ns.PetCache:GetSortKey(b)
        if ka ~= kb then return ka < kb end
        return a < b
    end
    for id in pairs(sums) do
        n = n + 1
        local at = #sample + 1
        while at > 1 and before(id, sample[at - 1]) do at = at - 1 end
        if at <= 4 then
            tinsert(sample, at, id)
            sample[5] = nil
        end
    end
    return n, sample
end

-- recipe key -> { n, sample, place }: the gallery asks about each recipe several times per
-- drawing, and every answer goes over all pets. Kept until the pets change (a new
-- favourite or level comes with PetsChanged too), or for a card about where you are,
-- until you are somewhere else.
local counts = {}

function R.Count(r)
    if not r.key then return count(r) end
    local c = counts[r.key]
    local place = ns.AutoRules.PlaceKey(r.rules)
    if not c or c.place ~= place then
        local n, sample = count(r)
        c = { n = n, sample = sample, place = place }
        counts[r.key] = c
    end
    return c.n, c.sample
end

function R.ForgetCounts() wipe(counts) end
ns:RegisterCallback(R, "PetsChanged", R.ForgetCounts)

function R.Usable(r)
    if r.noPet then return true end                         -- a set for no pet needs none
    if R.Count(r) == 0 then return false, L["You have no pets for this yet."] end
    return true
end

-- every card there could be; the ones marked ifPets are shown only when you have pets for them
-- (a weekly event or a family you have none of would only add grey cards)
function R.Candidates()
    local out = {}
    local function add(r, ifPets)
        if r then
            r.ifPets = ifPets
            out[#out + 1] = r
        end
    end
    for _, r in ipairs(FIXED) do add(finish(r)) end
    for t = 1, 10 do add(familyRecipe(t), true) end
    local sources = C_PetJournal.GetNumPetSources and C_PetJournal.GetNumPetSources() or 0
    for i = 1, sources do add(sourceRecipe(i), true) end
    for _, i in ipairs(ns.Expansions.All()) do add(expansionRecipe(i), true) end
    add(classRecipe())
    for _, h in ipairs(ns.Conditions.KnownHolidays()) do add(holidayRecipe(h), true) end
    return out
end

function R.List()
    local out = {}
    for _, r in ipairs(R.Candidates()) do
        if not r.ifPets or R.Count(r) > 0 then out[#out + 1] = r end
    end
    return out
end

-- Counts list[from], list[from + 1]... until budgetMs have gone by; the next index, or nil
-- when all are counted. Every card goes over all pets: counted a few per frame while the
-- window is open, the templates then open at once.
function R.CountSome(list, from, budgetMs)
    local start = debugprofilestop()
    for i = from, #list do
        R.Count(list[i])
        if debugprofilestop() - start >= budgetMs and i < #list then return i + 1 end
    end
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
    if r.lowest then ns.Sets:MoveToBottom(set) end
    if r.immediate then set:SetImmediate(true) end
    if r.noPet then set:SetNoPet(true) end
    if r.switchMinutes then set:SetSwitchMinutes(r.switchMinutes) end
    set:FiltersChanged()
    set:ConditionsChanged()
    return set
end
