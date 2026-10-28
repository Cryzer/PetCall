-- The layout checker itself: it must see text that does not fit and frames that cover
-- each other, and stay quiet when they do not.
local Layout = dofile("tests/layout.lua")

describe("Layout", function()
    it("the pseudo-locale lengthens text and keeps escapes and format specifiers", function()
        local ns = Layout.load()
        local Pseudo = ns.Pseudo
        local p = Pseudo("Often")
        assert.is_true(#p > #"Often" * 2, p)
        local f = Pseudo("%d in this set · %d left out")
        assert.is_true(string.format(f, 3, 4):find("3") ~= nil and string.format(f, 3, 4):find("4") ~= nil, f)
        local c = Pseudo("|cffffd100Finding pets|r\nSearch by name.")
        assert.is_true(c:find("|cffffd100", 1, true) ~= nil and c:find("|r", 1, true) ~= nil and c:find("\n", 1, true) ~= nil)
    end)

    it("measures text and wraps it at a width", function()
        local w, h = Layout.TextSize("Abcdefghij", "GameFontNormal")
        assert.equal(65, w)
        assert.equal(14, h)
        local _, wrapped = Layout.TextSize("Abcdefghij", "GameFontNormal", 40, true)
        assert.equal(28, wrapped)
    end)

    it("reports text wider than its button, frames leaving their parent and overlaps", function()
        local ns, U = Layout.load()
        local box = CreateFrame("Frame", nil, UIParent)
        box:SetSize(300, 100)
        box:SetPoint("CENTER")
        local fits = ns.Widgets.Button(box, "Fits", function() end)
        fits:SetPoint("TOPLEFT", 4, -4)
        local tight = ns.Widgets.Button(box, "A label far too long for it", function() end)
        tight:SetWidth(60)
        tight:SetPoint("TOPLEFT", 4, -40)
        local over = ns.Widgets.Button(box, "Over", function() end)
        over:SetPoint("LEFT", fits, "LEFT", 10, 0)
        local out = ns.Widgets.Button(box, "Out", function() end)
        out:SetPoint("LEFT", box, "RIGHT", -20, 0)
        local problems = Layout.Check(U, box)
        local text = table.concat(problems, "\n")
        assert.is_true(text:find('"A label far too long for it" needs') ~= nil, text)
        assert.is_true(text:find('"Out" leaves') ~= nil, text)
        assert.is_true(text:find('overlaps') ~= nil, text)
        assert.is_nil(text:find('"Fits" needs'), text)
        assert.equal(3, #problems, text)
    end)

    it("Flow puts controls in rows that fit, the right ones at the end, and wraps a long label", function()
        local ns, U = Layout.load()
        local box = CreateFrame("Frame", nil, UIParent)
        box:SetSize(200, 10)
        box:SetPoint("CENTER")
        local a = ns.Widgets.Button(box, "First one", function() end)
        local b = ns.Widgets.Button(box, "Second one", function() end)
        local c = ns.Widgets.Button(box, "End", function() end)
        local label = ns.Widgets.Label(box, string.rep("word ", 20))
        local h = ns.Widgets.Flow(box, { a, b, { frame = c, right = true }, label })
        assert.same({}, Layout.Check(U, box))
        local ra, rb, rc, rl = Layout.Rect(a), Layout.Rect(b), Layout.Rect(c), Layout.Rect(label)
        assert.equal(ra.t, rb.t, "both buttons fit on the first row")
        assert.is_true(rc.t < ra.b, "the third goes to the next row")
        assert.equal(Layout.Rect(box).r, rc.r, "at the right end")
        assert.is_true(rl.t < rc.b and rl.r - rl.l <= 200, "the long label wraps under them")
        assert.equal(h, Layout.Rect(box).t - Layout.Rect(box).b)
    end)
    it("FitButton makes a button as wide as its text", function()
        local ns = Layout.load()
        local b = ns.Widgets.Button(UIParent, "x", function() end)
        assert.equal(64, b:GetWidth(), "short text: the least width")
        b:SetText(string.rep("w", 30))
        ns.Widgets.FitButton(b, 10)
        assert.equal(30 * 6.5 + 24 + 10, b:GetWidth())
    end)

    it("places the main window and everything in it", function()
        local ns, U = Layout.load()
        U.W.world.pets = { a = { species = 1, name = "A" } }
        U.W.login()
        ns.UI.Main:Show()
        Layout.SetWindowSize(ns, U, 940, 640)
        local _, checked = Layout.Check(U, ns.UI.Main:GetFrame())
        assert.is_true(checked > 40, "placed " .. checked)
    end)

    it("a set card with a long name grows to show all of it; the tabs and the header fit their text", function()
        local ns, U = Layout.load()
        U.W.world.pets = { a = { species = 1, name = "A" } }
        U.W.login()
        ns.Sets:Create("Short")
        ns.Sets:Create("Town and capital cities on a long evening")
        ns.UI.Main:Show()
        Layout.SetWindowSize(ns, U, 940, 640)
        local byName = {}
        for _, r in ipairs(ns.UI.SetList._rows) do if r:IsShown() then byName[r.set.name] = r end end
        local long, short = byName["Town and capital cities on a long evening"], byName["Short"]
        assert.is_true(long.cardH > short.cardH, "two lines of name")
        assert.is_true(Layout.Rect(short).t <= Layout.Rect(long).b - 4, "below the taller card")
        -- the list, + New and Import right under it, then Out now at the foot
        local SL = ns.UI.SetList
        local list, new, now = Layout.Rect(SL._list), Layout.Rect(SL._newButton), Layout.Rect(SL._nowCard)
        assert.is_true(new.t <= list.b and now.t < new.b, "list, buttons, Out now")
        ns.UI.Main:SelectSet("Town and capital cities on a long evening")
        Layout.Settle(U)
        assert.same({}, Layout.Check(U, ns.UI.Main:GetFrame().header))
        for _, b in ipairs(ns.UI.Main:GetTabButtons()) do assert.same({}, Layout.Check(U, b)) end
    end)

    it("a pet tile with a long name makes its row taller; the other rows stay as they were", function()
        local ns, U = Layout.load()
        U.W.world.pets = {
            a = { species = 1, name = "Mechanical Pandaren Dragonling of the Endless Western Plains", level = 25, type = 7 },
            b = { species = 2, name = "Ant", type = 8 }, c = { species = 3, name = "Bee", type = 8 },
            d = { species = 4, name = "Cat", type = 8 }, e = { species = 5, name = "Dog", type = 8 },
            f = { species = 6, name = "Eel", type = 8 }, g = { species = 7, name = "Fox", type = 8 },
        }
        U.W.login()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        Layout.SetWindowSize(ns, U, 940, 640)
        local rows
        for _, f in ipairs(U.created) do
            if f._template == "WowScrollBoxList" and f:IsVisible() then rows = f._rowFrames end
        end
        local tall, short
        for _, row in ipairs(rows) do
            for _, t in ipairs(row.tiles or {}) do
                if t:IsShown() and t.petID == "a" then tall = row end
            end
            if row ~= tall and row.tiles and row.tiles[1]:IsShown() then short = row end
        end
        local h = tall.tiles[1]:GetHeight()
        assert.is_true(h > 44, "two lines of name: " .. h)
        for _, t in ipairs(tall.tiles) do if t:IsShown() then assert.equal(h, t:GetHeight(), "one height per row") end end
        assert.equal(44, short.tiles[1]:GetHeight())
        assert.same({}, Layout.Check(U, ns.UI.PetsTabPage.grid))
    end)

    it("a template card with a long hint wraps it and makes its row taller", function()
        local ns, U = Layout.load({ pseudo = true })
        U.W.login()
        ns.UI.Main:Show()
        Layout.SetWindowSize(ns, U, 640, 440)
        ns.UI.RecipeGallery:Show()
        Layout.Settle(U)
        local tall, short = 0, math.huge
        for _, c in ipairs(ns.UI.RecipeGallery._cards) do
            if c:IsVisible() then
                local h = c:GetHeight()
                tall, short = math.max(tall, h), math.min(short, h)
            end
        end
        assert.is_true(tall > short, "rows differ: " .. short .. " / " .. tall)
        assert.is_true(short >= 70, "never below the old height: " .. short)
        assert.same({}, Layout.Check(U, ns.UI.RecipeGallery:GetFrame()))
    end)

    it("set settings rows stack by what they hold, and labels and controls share a column", function()
        local ns, U = Layout.load({ pseudo = true })
        U.W.login()
        local set = ns.Sets:Create("Town")
        set.settings.filter = { { "favorites", 64 }, { "petType", 8, petTypes = { 7 } } }
        set:FiltersChanged()
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Town")
        ns.UI.Main:SelectTab("settings")
        Layout.SetWindowSize(ns, U, 640, 440)
        local page = ns.UI.SetSettingsPage
        local placed = 0
        for _, sec in ipairs(page.sections) do
            if sec:IsShown() then
                local above
                for _, row in ipairs(sec.rows) do
                    local r = Layout.Rect(row.box)
                    assert.is_not_nil(r, "every row is placed")
                    placed = placed + 1
                    local bottom = r.b
                    if row.help then bottom = math.min(bottom, Layout.Rect(row.help).b) end
                    if row.label then bottom = math.min(bottom, Layout.Rect(row.label).b) end
                    if above then assert.is_true(r.t <= above, "a row starts below the one before") end
                    above = bottom
                end
            end
        end
        assert.is_true(placed >= 10, "rows placed: " .. placed)
        assert.same({}, Layout.Check(U, page))
    end)

    it("the How often scale and its name fit in a longer language", function()
        local ns, U = Layout.load({ pseudo = true })
        U.W.world.pets = { a = { species = 1, name = "A" } }
        U.W.login()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        Layout.SetWindowSize(ns, U, 940, 640)
        local panel = ns.UI.Preview:GetPanel()
        ns.UI.Preview:SetSelected("a")
        Layout.Settle(U)
        assert.same({}, Layout.Check(U, panel))
    end)

    it("wrapped text keeps its lines even instead of leaving one word on the last", function()
        local ns, U = Layout.load()
        local box = CreateFrame("Frame", nil, UIParent)
        box:SetSize(300, 100)
        box:SetPoint("CENTER")
        local fs = ns.Widgets.Label(box, "No pets to choose from", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT")
        ns.Widgets.BalanceText(fs, 108)
        local _, oneLine = Layout.TextSize("x", "GameFontHighlightSmall")
        assert.equal(2 * oneLine, fs:GetStringHeight(), "still two lines")
        assert.is_true(fs:GetWidth() < 108 and fs:GetWidth() >= ns.Widgets.TextWidth(fs) / 2, "narrower: " .. fs:GetWidth())
        ns.Widgets.BalanceText(fs, 300)
        assert.equal(oneLine, fs:GetStringHeight(), "one line when it fits")
        assert.same({}, Layout.Check(U, box))
    end)
end)