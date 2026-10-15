local W = dofile("tests/wowstub.lua")

describe("Pet menu", function()
    local ns, Menu
    before_each(function()
        W.reset()
        W.world.pets = {
            a1 = { species = 1, name = "Torghast Lurker", level = 5 },
            a2 = { species = 1, name = "Torghast Lurker", level = 25 },
            a3 = { species = 1, name = "Torghast Lurker", custom = "Lurky", level = 1 },
            b = { species = 2, name = "Bombay Cat" },
            c = { species = 3, name = "Ancona Chicken" },
            d = { species = 4, name = "4th of July Firework" },
            e = { species = 5, name = "Xu-Fu" },
            f = { species = 6, name = "Zipao" },
            g = { species = 7, name = "Ýmir" },
        }
        W.world.favorites.a1 = true
        ns = W.load({ ui = { "UI/Menu.lua" } })
        W.login()
        W.advance(1)
        Menu = ns.UI.Menu
    end)

    it("lists each pet once, preferring the favorite copy, keeping renamed ones", function()
        local ids = Menu.UniquePets()
        local names = {}
        for _, id in ipairs(ids) do names[#names + 1] = id end
        assert.same({ "d", "c", "b", "a3", "a1", "e", "f", "g" }, names)
    end)

    it("groups by first letter and merges small neighbours", function()
        local groups = Menu.Groups(Menu.UniquePets(), 3)
        local labels = {}
        for _, g in ipairs(groups) do labels[#labels + 1] = g.label .. ":" .. #g.ids end
        assert.same({ "# – B:3", "L – X:3", "Z – Ý:2" }, labels)
    end)

    it("keeps a big letter on its own", function()
        for i = 1, 30 do W.world.pets["s" .. i] = { species = 100 + i, name = format("Snake %02d", i) } end
        ns.PetCache:Rescan()
        local groups = Menu.Groups(Menu.UniquePets(), 25)
        local labels = {}
        for _, g in ipairs(groups) do labels[#labels + 1] = g.label .. ":" .. #g.ids end
        assert.same({ "# – L:4", "S:30", "T – Ý:4" }, labels)
    end)
end)
