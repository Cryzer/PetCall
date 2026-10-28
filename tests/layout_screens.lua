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
end

local function pets(ns)
    ns.UI.Main:Show()
    ns.UI.Main:SelectSet("$Default")
    ns.UI.Main:SelectTab("pets")
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
}

return Screens
