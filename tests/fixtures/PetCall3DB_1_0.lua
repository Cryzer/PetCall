-- Realistic 1.0.x saved variables + pet collection + world states.
local pets = {
    ["BattlePet-0-0001"] = { species = 39, name = "Mechanical Squirrel", level = 25, type = 10, quality = 4 },
    ["BattlePet-0-0002"] = { species = 40, name = "Bombay Cat", custom = "Mruczek", level = 1, type = 8 },
    ["BattlePet-0-0003"] = { species = 41, name = "Cornish Rex Cat", level = 12, type = 8 },
    ["BattlePet-0-0004"] = { species = 114, name = "Disgusting Oozeling", level = 5, type = 5 },
    ["BattlePet-0-0005"] = { species = 72, name = "Snowshoe Rabbit", level = 25, type = 5 },
    ["BattlePet-0-0006"] = { species = 74, name = "Mini Diablo", level = 3, type = 6, fanfare = true },
    ["BattlePet-0-0007"] = { species = 75, name = "Murky", level = 25, type = 9 },
}
local favorites = { ["BattlePet-0-0001"] = true, ["BattlePet-0-0007"] = true }

local db = {
    profileKeys = { ["Tester - Realm"] = "Default" },
    profiles = {
        Default = {
            sets = {
                ["$Default"] = {
                    pets = { ["BattlePet-0-0001"] = 8, ["BattlePet-0-0002"] = 0, ["BattlePet-0-0003"] = 0.125 },
                    filter = { { "favorites", 64 } },
                },
                ["City"] = {
                    name = "City", defaultValue = 1, priority = 8,
                    trigger = { { "specialLocation", loc = "city" } },
                    pets = { ["BattlePet-0-0005"] = 64 },
                },
                ["RaidOrZone"] = {
                    name = "RaidOrZone", priority = 64,
                    trigger = { { "OR", items = {
                        { "groupType", party = true, raid = true },
                        { "AND", items = { { "zone", zoneName = "Dornogal" }, { "specialization", class = "HUNTER", spec = 2 } } },
                    } } },
                    filter = { { "level", operator = ">=", level = "25", 1 }, { "OR", items = { { "petType", petType = "8" }, { "favorites" } }, 8 } },
                },
                ["Disabled"] = { name = "Disabled", enabled = false, trigger = {}, pets = { ["BattlePet-0-0007"] = 1 } },
                ["NoTrigger"] = { name = "NoTrigger", priority = 0.125, pets = { ["BattlePet-0-0003"] = 1 } },
                ["Deep"] = {
                    name = "Deep", priority = 1,
                    trigger = { { "AND", items = { { "OR", items = { { "zone", zoneName = "Valdrakken" }, { "AND", items = { { "specialLocation", loc = "instance" }, { "groupType", party = true, raid = true } } } } } } } },
                    pets = { ["BattlePet-0-0002"] = 1 },
                },
            },
        },
    },
}

local worlds = {
    { zone = "Stormwind City", resting = true },
    { zone = "Dornogal", resting = false, spec = 2 },
    { zone = "Dornogal", resting = false, spec = 1 },
    { zone = "Valdrakken", resting = true },
    { zone = "Deadmines", resting = false, instanceType = "party", inGroup = true },
    { zone = "Elwynn Forest", resting = false, inRaid = true },
    { zone = "Elwynn Forest", resting = false },
}

return { db = db, pets = pets, favorites = favorites, worlds = worlds }
