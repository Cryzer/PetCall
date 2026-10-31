-- The screens the layout checker looks at, each brought into a state with plenty of text:
-- long pet names, several rules, active filters. Every screen is a function(ns, U) that
-- opens it; the checker then looks at everything shown.
local Screens = {}

-- pets with long names and every kind of detail, the same for every screen
function Screens.World(W)
    W.world.pets = {
        a = { species = 1, name = "Mechanical Pandaren Dragonling", level = 25, type = 7, quality = 4 },
        b = { species = 2, name = "Sun-Darter Hatchling", custom = "Sir Featherington the Third", level = 3, type = 3, quality = 2 },
        c = { species = 3, name = "Spectral Tiger Cub", level = 10, type = 8, quality = 3 },
        d = { species = 4, name = "Lil' Ragnaros", level = 1, type = 5 },
        e = { species = 5, name = "Tiny Snowman", level = 25, type = 6, quality = 4 },
        f = { species = 6, name = "Celestial Calf", level = 12, type = 8 },
    }
    W.world.favorites.c = true
    W.world.sources[1] = "Drop: Hogger"
    W.world.sources[2] = "Pet Battle: Elwynn Forest"
    -- Pet-like items longer than the game's longest names, in any language
    W.world.itemName = function(id) return "Orb of the Sin'dorei, Gnomish Gravity Well and Unusually Long Translated Item Name " .. id end
    W.world.questTitle = function(q) return "Stampeding Spirits of the Wandering Isle and Other Long Quest Titles, part " .. q end
end

local function pets(ns)
    ns.UI.Main:Show()
    ns.UI.Main:SelectSet("$Default")
    ns.UI.Main:SelectTab("pets")
end

-- every setting away from the recommended one, and an own exception beside them
local function everyRowDifferent(ns)
    ns:SetAutoSummon(false)
    ns.db.profile.nearPEWOnly, ns.db.profile.switchOnNewMap, ns.db.profile.overrideSetLoadout = true, true, false
    local default = ns.Sets:Get("$Default")
    default:SetSwitch(5, true)
    default:SetAnnounce(true)
    local other = { mounted = "away", bg = "alone", arena = "alone", dungeon = "alone", raid = "alone",
        scenario = "away", hidden = false, outsideCities = "away" }
    for _, exc in ipairs(ns.Exceptions:List()) do
        exc:SetChoice(other[exc.id])
        if exc:HasSolo() then exc:SetSolo(false) end
    end
    ns.Exceptions:Add({ { "groupType", raid = true } }, "away", nil, "Raid group zoo")
end

Screens.list = {
    { name = "Pets", open = pets },
    { name = "Pets with rules and filters", open = function(ns)
        local set = ns.Sets:Get("$Default")
        set.settings.filter = { { "AND", items = { { "favorites" }, { "nativeZone" } }, 8 },
            { "source", 64, text = "Trading Post" } }
        set:FiltersChanged()
        pets(ns)
        local state = ns.UI.PetsTabState()
        state.filters = { types = { [7] = true, [8] = true }, sources = { [1] = true }, rare = true }
        state.search = "a"
        ns.UI.PetsTab:Rebuild()
    end },
    { name = "Pets, a rule open", open = function(ns, U)
        local set = ns.Sets:Get("$Default")
        set.settings.filter = { { "AND", items = { { "level", operator = ">=", level = "20" },
            { "petType", petTypes = { 7, 8 } }, { "favorites" }, { "nativeZone" } }, 8 } }
        set:FiltersChanged()
        pets(ns)
        ns.UI.PetsTabPage.rulesBtn:Click()
        U.lastMenu.items[3]:Click()
    end },
    { name = "Pets, a pet by hand over its rule", open = function(ns)
        local set = ns.Sets:Get("$Default")
        set.settings.filter = { { "favorites", 64 } }
        set:SetPetWeight("c", 0)
        pets(ns)
        ns.UI.Preview:SetSelected("c")
    end },
    { name = "When", open = function(ns)
        local town = ns.Sets:Create("Town and capital cities")
        town:ApplyTemplate("city")
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Town and capital cities")
        ns.UI.Main:SelectTab("when")
    end },
    { name = "Set settings", open = function(ns)
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("$Default")
        ns.UI.Main:SelectTab("settings")
    end },
    { name = "Set settings of a paused set with rules", open = function(ns)
        local town = ns.Sets:Create("Town and capital cities")
        town:ApplyTemplate("city")
        town.settings.filter = { { "favorites", 64 }, { "petType", 8, petTypes = { 7 } } }
        town:FiltersChanged()
        town:Pause("hour")
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Town and capital cities")
        ns.UI.Main:SelectTab("settings")
    end },
    { name = "New set", open = function(ns)
        pets(ns)
        ns.UI.SetList._newButton:Click()
    end },
    { name = "Import", open = function(ns)
        pets(ns)
        ns.UI.Share:ShowImport()
        local d = _G.PetCallShareDialog
        d.status:SetText("This text is not a PetCall export string. Copy the whole string and try again.")
    end },
    { name = "Template gallery", open = function(ns)
        ns.UI.Main:Show()
        ns.UI.RecipeGallery:Show()
    end },
    { name = "Mount picker", open = function(ns)
        ns.UI.Main:Show()
        ns.UI.MountPicker:Open({ "mount", mountIDs = {} }, nil, function() end)
    end },
    { name = "How PetCall acts, every exception set, one own exception open", open = function(ns)
        for _, exc in ipairs(ns.Exceptions:List()) do exc:SetChoice("away") end
        ns.Exceptions:Add({ { "zone", zoneName = "Stormwind City" }, { "groupType", raid = true } }, "alone", nil, "Raid group zoo")
        ns.Exceptions:Add({ { "luacode", code = "return true", disabledByImport = true } }, "away", "Shared from a friend")
        local own = ns.Exceptions:Add({ { "zone", zoneName = "Valdrakken" }, { "timeOfDay", from = 1080, to = 1380 } }, "away")
        ns:PauseAuto()
        ns.UI.Main:Show()
        ns.UI.Behaviour:Show(own.id)
        ns.UI.Behaviour:GetFrame().itemsToggle:Click()
    end },
    { name = "How PetCall acts, While mounted conditions open", open = function(ns)
        ns.UI.Main:Show()
        ns.UI.Behaviour:Show()
        ns.UI.Behaviour._rows.mounted.toggle:Click()
    end },
    { name = "When, a row of tick boxes and many places", open = function(ns)
        local set = ns.Sets:Create("Out and about")
        local m = set:GetConditionModel()
        m.groups = { { rows = { { "activity", swimming = true, mounted = true },
            { "zone", zoneNames = { "Stormwind City", "Orgrimmar", "Valdrakken", "Dornogal", "Oribos" } } } } }
        set:SetConditionModel(m)
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Out and about")
        ns.UI.Main:SelectTab("when")
    end },
    { name = "Comparison, every row different", open = function(ns)
        everyRowDifferent(ns)
        ns.UI.Main:Show()
        ns.UI.Behaviour:Show()
        ns.UI.Comparison:Open(ns.UI.Behaviour:GetFrame())
    end },
    { name = "Welcome with every row different", open = function(ns)
        everyRowDifferent(ns)
        ns.UI.Main:Show()
        ns.UI.Welcome:Show(true)
    end },
    { name = "Set settings with Like Default values", open = function(ns)
        local default = ns.Sets:Get("$Default")
        default:SetSwitch(30, true)
        default:SetAnnounce(false)
        local town = ns.Sets:Create("Town and capital cities")
        town:ApplyTemplate("city")
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Town and capital cities")
        ns.UI.Main:SelectTab("settings")
    end },
    { name = "Out now with an exception cause", open = function(ns, U)
        U.W.world.summoned = "b"
        U.W.fire("COMPANION_UPDATE", "CRITTER")
        U.W.world.mounted = true
        U.W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        pets(ns)
        ns.UI.StatusBar:Refresh()
    end },
}

return Screens
