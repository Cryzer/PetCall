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

    local function recorder()
        local r = { items = {} }
        local function add(kind, text, a, b)
            local item = recorder()
            item.kind, item.text, item.a, item.b = kind, text, a, b
            r.items[#r.items + 1] = item
            return item
        end
        function r:CreateTitle(t) return add("title", t) end
        function r:CreateDivider() return add("divider") end
        function r:CreateButton(t, f) return add("button", t, f) end
        function r:CreateCheckbox(t, get, set) return add("checkbox", t, get, set) end
        function r:SetScrollMode() end
        function r:SetOnEnter() end
        function r:SetOnLeave() end
        return r
    end

    it("the menu shows Auto-summon as paused", function()
        local function autoItem()
            local root = recorder()
            Menu:Build(nil, root)
            for _, item in ipairs(root.items) do
                if item.kind == "checkbox" and item.text:find("Auto-summon", 1, true) then return item end
            end
        end
        assert.equal("Auto-summon", autoItem().text)
        ns:PauseAuto()
        local item = autoItem()
        assert.is_true(item.text:find("Paused", 1, true) ~= nil, item.text)
        assert.is_true(item.a())
        ns:SetAutoSummon(false)
        assert.equal("Auto-summon", autoItem().text)
        assert.is_false(autoItem().a())
    end)

    it("How PetCall acts opens the window on that page", function()
        local opened = {}
        ns.UI.Main = { Show = function() opened[#opened + 1] = "window" end }
        ns.UI.Behaviour = { Show = function() opened[#opened + 1] = "page" end }
        local root = recorder()
        Menu:Build(nil, root)
        local item
        for _, x in ipairs(root.items) do
            if x.kind == "button" and x.text == "How PetCall acts" then item = x end
        end
        assert.is_not_nil(item)
        item.a()
        assert.same({ "window", "page" }, opened)
    end)
end)
