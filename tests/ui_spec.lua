-- Smoke tests: UI files load and the main flows run without Lua errors.
local U = dofile("tests/uistub.lua")
local W = U.W

describe("UI smoke", function()
    local ns
    before_each(function()
        ns = U.load()
        W.world.pets = { a = { species = 1, name = "A" } }
        W.login()
        W.advance(1)
    end)

    it("opens, switches tabs and closes the main window", function()
        assert.has_no_error(function()
            ns.Commands:Handle("")
            assert.is_true(ns.UI.Main:GetFrame():IsShown())
            ns.UI.Main:SelectTab("pets")
            ns.UI.Main:SelectSet("$Default")
            ns.UI.Main:Toggle()
        end)
        assert.is_false(ns.UI.Main:GetFrame():IsShown())
    end)
    it("pets tab builds, rebuilds and survives resizing", function()
        assert.has_no_error(function()
            ns.UI.Main:Show()
            ns.UI.Main:SelectTab("pets")
            local set = ns.Sets:Get("$Default")
            set:SetPetWeight("a", 0)
            W.advance(1)
            ns:Fire("WindowResized", 700, 500)
            ns:Fire("WindowResized", 900, 600)
            ns.UI.Preview:SetHover("a")
            ns.UI.Preview:SetSelected("a")
            ns.UI.Preview:SetHover(nil)
        end)
    end)
    it("auto rule chips render, open the editor and edit", function()
        assert.has_no_error(function()
            ns.UI.Main:Show()
            ns.UI.Main:SelectTab("pets")
            local set = ns.Sets:Get("$Default")
            set.settings.filter = { { "favorites", 64 }, { "AND", items = { { "OR", items = { { "favorites" } } } }, 1 } }
            ns.UI.AutoRulesBar:Refresh(set)
            local chips = ns.UI.AutoRulesBar._chips
            assert.is_true(chips[1]:IsShown())
            chips[1]:Click()      -- editor for a simple chip
            chips[2]:Click()      -- editor for a legacy chip
            chips[1]:Click()
            -- the editor belongs to the main window, so it closes with it
            local editor = ns.UI.AutoRulesBar.GetEditor()
            assert.equal(ns.UI.Main:GetFrame(), editor:GetParent())
            assert.is_true(editor:IsShown())
            editor.done:Click()
            assert.is_false(editor:IsShown())
            -- adding a condition keeps the editor open on the same rule
            ns.AutoRules.AddCriterion(set.settings.filter, 1, "favorites")
            ns.UI.AutoRulesBar:Refresh(set)
            chips[1]:Click()
            assert.is_true(editor:IsShown())
            chips[1].remove:Click()
            assert.equal(1, #set.settings.filter)
        end)
    end)
    it("sets panel, status bar and set settings tab", function()
        assert.has_no_error(function()
            ns.UI.Main:Show()
            local set = ns.Sets:Create("Town")
            ns.UI.Main:SelectSet("Town")
            ns.UI.Main:SelectTab("settings")
            ns.UI.SetList:Refresh()
            ns.UI.StatusBar:Refresh()
            set:SetEnabled(false)
            set:SetPriority(8)
            ns.UI.Main:SelectSet("$Default")
            ns.UI.Main:SelectTab("settings")
            ns:Fire("WindowResized", 650, 500)
            ns:Fire("WindowResized", 900, 600)
            W.world.combat = true
            W.fire("PLAYER_REGEN_DISABLED")
            W.advance(1)
            ns.UI.StatusBar:Refresh()
            set:Delete()
            W.advance(1)
        end)
    end)
    it("when tab renders every condition kind, groups and legacy blocks", function()
        assert.has_no_error(function()
            ns.UI.Main:Show()
            local set = ns.Sets:Create("Night")
            ns.UI.Main:SelectSet("Night")
            ns.UI.Main:SelectTab("when")
            set:ApplyTemplate("city")
            local m = set:GetConditionModel()
            for _, def in ipairs(ns.Conditions.Types()) do table.insert(m.groups[1].rows, def.new()) end
            table.insert(m.groups[1].rows, { "luacode", code = "return function() return true end", disabledByImport = true })
            table.insert(m.groups[1].rows, { "AND", items = { { "OR", items = { { "zone", zoneName = "A" }, { "groupType", party = true } } } } })
            set:SetConditionModel(m)
            ns.UI.Main:SelectTab("when")
            m = set:GetConditionModel()
            table.insert(m.groups, { rows = { { "zone", zoneName = "Dornogal" } } })
            set:SetConditionModel(m)
            W.advance(1)
            ns.UI.Main:SelectTab("when")
            assert.equal("when", ns.UI.Main:GetSelectedTab())
            assert.equal(2, #set:GetConditionModel().groups)
        end)
    end)
    it("tick boxes in a condition row start after the label before them", function()
        ns.UI.Main:Show()
        local set = ns.Sets:Create("Visits")
        ns.UI.Main:SelectSet("Visits")
        local m = set:GetConditionModel()
        m.groups = { { rows = { { "housing", ownHome = true } } } }
        set:SetConditionModel(m)
        ns.UI.Main:SelectTab("when")
        local boxes = {}
        for _, f in ipairs(U.created) do
            if f._template == "UICheckButtonTemplate" and f:IsShown() and f.text and f.text._points and f.text._points.LEFT then boxes[#boxes + 1] = f end
        end
        assert.is_true(#boxes >= 3)
        local chained = 0
        for i = 2, #boxes do
            local p = boxes[i]._points.LEFT
            if p.rel == boxes[i - 1] then
                chained = chained + 1
                local w = tonumber(boxes[i - 1].text:GetStringWidth()) or 0
                assert.equal(2 + w + 16, p.x)
                assert.equal(boxes[i], boxes[i].text._points.LEFT.rel)
            end
        end
        assert.equal(2, chained)                      -- three boxes, each after the one before
        local last = boxes[#boxes]
        local after = false                           -- the remove × follows the last label, not the box
        for _, f in ipairs(U.created) do
            local lp = f._points and f._points.LEFT
            if lp and lp.rel == last.text then after = true end
        end
        assert.is_true(after)
    end)
    it("the window shows its logo whole in a framed corner tile, gold on Blizzard's look, accent on the dark ones", function()
        ns.UI.Main:Show()
        local f = ns.UI.Main:GetFrame()
        local badge = f.badge
        assert.is_not_nil(badge)
        -- Blizzard's border sits far above the window: the logo must sit above it
        f.NineSlice = CreateFrame("Frame", nil, f)
        f.NineSlice:SetFrameLevel(500)
        badge.Lift()
        assert.is_true(badge:GetFrameLevel() > 500)
        assert.equal("Interface\\AddOns\\PetCall\\Media\\logo", badge.logo._texture)
        assert.is_nil(badge.logo._texCoord, "the logo is never cropped")
        local function ringColour(look)
            ns.db.global.look = look
            ns.Skin._Forget()
            ns.Skin:PaintBadge(badge)
            return badge.ring._vertexColor
        end
        local gold = ringColour("blizzard")
        assert.same({ 1, 0.82, 0 }, { gold[1], gold[2], gold[3] })
        local accent = ringColour("flat")
        local r, g, b = ns.Skin.Flat.Accent()
        assert.same({ r, g, b }, { accent[1], accent[2], accent[3] })
        ns.db.global.look = "auto"
        ns.Skin._Forget()
    end)
    it("condition groups are cards with an accent bar on the dark looks, Blizzard's inset on its own", function()
        local function cardsFor(look)
            ns.db.global.look = look
            ns.Skin._Forget()
            ns.UI.Main:Show()
            local set = ns.Sets:Get("Groups") or ns.Sets:Create("Groups")
            ns.UI.Main:SelectSet("Groups")
            set:SetConditionModel({ groups = { { rows = { { "groupType", party = true } } }, { rows = { { "groupType", raid = true } } } } })
            ns.UI.Main:SelectTab("settings")
            ns.UI.Main:SelectTab("when")
            local cards = {}
            for _, f in ipairs(U.created) do
                if f._template == "InsetFrameTemplate" and f:IsShown() and f._parent and f._parent._parent then cards[#cards + 1] = f end
            end
            return cards
        end
        local flat = cardsFor("flat")
        assert.is_true(#flat >= 2)
        local r, g, b = ns.Skin.Flat.Accent()
        local bar = flat[#flat].pcBar
        assert.is_not_nil(bar)
        assert.same({ r, g, b }, { bar._color[1], bar._color[2], bar._color[3] })
        ns.db.global.look = "auto"
        ns.Skin._Forget()
    end)
    it("share dialog shows export and import", function()
        assert.has_no_error(function()
            ns.Sets:Create("Src")
            ns.UI.Share:ShowExport("Src")
            ns.UI.Share:ShowImport()
            ns.UI.Share:ShowExport("$Default")
        end)
    end)
    it("settings, profiles and opening settings in and out of combat", function()
        assert.has_no_error(function()
            assert.is_not_nil(ns.UI.Settings.category)
            ns:OpenSettings()
            W.world.combat = true
            ns:OpenSettings()
            W.world.combat = false
            W.fire("PLAYER_REGEN_ENABLED")
            ns.DB:Set("Second")
            ns.DB:Set("Default")
            ns.UI.Main:SetScale(1.2)
        end)
    end)
    it("broker tooltip, clicks, pet menu and addon compartment", function()
        assert.has_no_error(function()
            local tt = U.universal()
            ns.UI.Broker:FillTooltip(tt)
            ns.UI.Broker:OnClick(U.universal(), "LeftButton")
            ns.UI.Broker:OnClick(U.universal(), "RightButton")
            ns.UI.Menu:Build(nil, U.universal())
            assert.is_not_nil(U.ldb.objects.PetCall)
            assert.is_false(U.icon.shown.PetCall)          -- hidden by default
            ns.UI.Broker:SetMinimapShown(true)
            assert.is_true(U.icon.shown.PetCall)
            ns.UI.Broker:SetMinimapShown(false)
            PetCall_OnAddonCompartmentEnter(nil, U.universal())
            PetCall_OnAddonCompartmentLeave()
            ns.DB:Set("Other")
            ns.Commands:Handle("help")
        end)
    end)
    it("hovering pets never changes their weights", function()
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local set = ns.Sets:Get("$Default")
        set:SetPetWeight("a", 0)
        ns.UI.Preview:SetSelected("a")
        ns.UI.Preview:SetHover("b")
        ns.UI.Preview:SetHover(nil)
        assert.equal(0, set:GetPetWeight("a"))
        assert.is_false(set:HasManualWeight("b"))
    end)

    it("re-selects the set by name after a profile change with the window closed", function()
        ns.Sets:Create("City")
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("City")
        local old = ns.UI.Main:GetSelectedSet()
        ns.UI.Main:Hide()
        ns.DB:Set("Other")
        ns.UI.Main:Show()
        assert.is_true(ns.UI.Main:GetSelectedSet() ~= old)
        assert.is_false(ns.UI.Main:GetSelectedSet().deleted == true)
    end)
    it("when tab updates state dots without rebuilding the editor", function()
        ns.UI.Main:Show()
        local set = ns.Sets:Create("Here")
        ns.UI.Main:SelectSet("Here")
        ns.UI.Main:SelectTab("when")
        set:ApplyTemplate("city")
        ns.UI.Main:SelectTab("when")
        W.advance(1)
        local before = #U.created
        W.world.resting = false
        W.fire("PLAYER_FLAGS_CHANGED", "player")
        W.advance(1)
        assert.is_false(set:ConditionsMet())
        assert.equal(before, #U.created)
    end)
    it("keeps the tab content above the status bar", function()
        local f = ns.UI.Main:GetFrame()
        local bottom = f.Inset._points and f.Inset._points.BOTTOMRIGHT
        assert.is_true(bottom ~= nil and bottom.y >= 28, "inset must end above the status bar")
    end)

    it("anchors each visible tab to the previous visible one", function()
        ns.Sets:Create("Town")
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("$Default")
        local tabs = ns.UI.Main:GetFrame().Tabs
        assert.is_true(tabs[3]._points.LEFT.rel == tabs[1], "settings tab follows pets when When is hidden")
        ns.UI.Main:SelectSet("Town")
        assert.is_true(tabs[3]._points.LEFT.rel == tabs[2], "settings tab follows When")
    end)
    local function gridTiles()
        local box
        for _, f in ipairs(U.created) do if f._template == "WowScrollBoxList" then box = f end end
        local tiles = {}
        for _, row in ipairs(box._rowFrames or {}) do
            for _, t in ipairs(row.tiles or {}) do if t.petID then tiles[t.petID] = t end end
        end
        return tiles
    end

    it("grid tiles render; the tile checkbox includes or excludes every copy", function()
        W.world.pets.a2 = { species = 1, name = "A", level = 25 }
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local set = ns.Sets:Get("$Default")
        local tiles = gridTiles()
        assert.is_not_nil(tiles.a2)              -- the level-25 copy stands for "A"
        assert.is_nil(tiles.a)
        tiles.a2.check:Click("LeftButton")
        assert.equal(0, set:GetPetWeight("a"))
        assert.equal(0, set:GetPetWeight("a2"))
        gridTiles().a2.check:Click("LeftButton")
        assert.equal(1, set:GetPetWeight("a"))
        assert.has_no_error(function() gridTiles().b:Click("RightButton") end)
    end)

    it("clicking a tile selects it; hovering others previews them and leaving returns to it", function()
        W.world.pets.b = { species = 2, name = "B" }
        W.world.pets.c = { species = 3, name = "C" }
        ns.PetCache:Rescan()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end   -- wide: preview panel, not the floating one
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local set = ns.Sets:Get("$Default")
        local tiles = gridTiles()
        tiles.b:Click("LeftButton")
        assert.equal(1, set:GetPetWeight("b"))          -- a click no longer changes weights
        assert.equal("b", ns.UI.Preview:GetShown())
        tiles = gridTiles()
        assert.is_true(tiles.b.selected:IsShown())
        tiles.c._scripts.OnEnter(tiles.c)
        assert.equal("c", ns.UI.Preview:GetShown())
        tiles.c._scripts.OnLeave(tiles.c)
        W.advance(0.5)
        assert.equal("b", ns.UI.Preview:GetShown())       -- off the tiles: back to the selected pet
        gridTiles().b:Click("LeftButton")                -- second click releases the pin
        tiles = gridTiles()
        tiles.c._scripts.OnEnter(tiles.c)
        assert.equal("c", ns.UI.Preview:GetShown())
    end)

    it("the minimap menu is not owned by the minimap button", function()
        -- EllesmereUI hides its button flyout on any click outside it; a menu owned by a
        -- button inside that flyout closes before the click on a menu item lands
        local button = U.universal()
        ns.UI.Broker:OnClick(button, "RightButton")
        assert.is_true(U.lastMenuOwner == UIParent, "menu owner must outlive the minimap button")
        PetCall_OnAddonCompartmentClick("PetCall", "RightButton", U.universal())
        assert.is_true(U.lastMenuOwner == UIParent)
    end)

    it("every pet menu button does its job", function()
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        W.random = function() return 0.1 end        -- the draw would pick "a" first
        ns:SummonPet("a")
        ns.UI.Menu:Open()
        local menu = U.lastMenu
        menu:Find("Summon another"):Click()
        W.advance(1)
        assert.equal("b", W.world.summoned, "Summon another must pick a different pet")

        ns.UI.Menu:Open()
        local recent = U.lastMenu:Find("Recently summoned")      -- most recent first: b, then a
        recent.items[2]:Click()
        assert.equal("a", W.world.summoned)

        ns.UI.Menu:Open()
        U.lastMenu:Find("All pets").items[1].items[2]:Click()  -- group "A – B": a, b
        assert.equal("b", W.world.summoned)

        ns.UI.Menu:Open()
        U.lastMenu:Find("Dismiss pet"):Click()
        assert.is_nil(W.world.summoned)
        assert.is_false(ns:IsAutoSummon())
        ns.UI.Menu:Open()
        U.lastMenu:Find("Auto-summon"):Click()
        assert.is_true(ns:IsAutoSummon())

        ns.UI.Menu:Open()
        U.lastMenu:Find("Open PetCall"):Click()
        assert.is_true(ns.UI.Main:GetFrame():IsShown())
        ns.UI.Menu:Open()
        assert.has_no_error(function() U.lastMenu:Find("Settings"):Click() end)
        W.random = nil
    end)

    it("Summon another says why it cannot summon right now", function()
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        ns.UI.Menu:Open()
        U.lastMenu:Find("Summon another"):Click()
        assert.is_true(W.world.printed[#W.world.printed]:find("In combat") ~= nil)
    end)
    it("menu explains pets that cannot be summoned and opens the active set", function()
        W.world.cooldowns.a = 30
        ns.UI.Menu:Open()
        U.lastMenu:Find("All pets").items[1].items[1]:Click()
        assert.is_nil(W.world.summoned)
        assert.is_true(W.world.printed[#W.world.printed]:find("cooldown") ~= nil)
        ns.UI.Menu:Open()
        local active = U.lastMenu:Find("Active")
        assert.equal("button", active.kind)
        active:Click()
        assert.is_true(ns.UI.Main:GetFrame():IsShown())
    end)
    it("sets panel starts open with one set; the collapsed rail shows an expand arrow", function()
        local f = ns.UI.Main:GetFrame()
        f.GetWidth = function() return 900 end
        ns:Fire("WindowResized", 900, 600)
        assert.is_true(ns.UI.SetList:IsCollapsed() == false, "one set must not hide + New and Import")
        ns.UI.SetList:SetCollapsed(true, true)
        local rail = ns.UI.SetList:GetRail()
        assert.is_not_nil(rail.arrow)
        assert.is_true(rail.arrow:IsShown())
        rail:Click("LeftButton")
        assert.is_false(ns.UI.SetList:IsCollapsed())
    end)
    it("the preview reloads the model after the grid clears it", function()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        ns.UI.Preview:SetSelected("a")
        W.advance(1)
        local viewer = ns.UI.Preview:GetViewer()
        assert.equal(5001, viewer:ModelID())              -- loaded by the species' display ID
        ns.Sets:Get("$Default"):SetPetWeight("a", 8)      -- grid rebuild clears and redraws the preview
        W.advance(1)
        assert.equal(5001, viewer:ModelID())
    end)

    it("a model that failed to load is requested again", function()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        ns.UI.Preview:SetSelected("a")
        W.advance(1)
        local viewer = ns.UI.Preview:GetViewer()
        viewer:Clear()                                      -- the client dropped the load
        ns.UI.Preview:Refresh()
        W.advance(1)
        assert.equal(5001, viewer:ModelID())
    end)

    it("hovering shows the pet at once and loads its model once the cursor rests", function()
        for i = 1, 5 do W.world.pets["h" .. i] = { species = 20 + i, name = "H" .. i } end
        ns.PetCache:Rescan()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        local viewer = ns.UI.Preview:GetViewer()
        local loads = {}
        local load = viewer.Load
        viewer.Load = function(v, info) loads[#loads + 1] = info.petID return load(v, info) end
        -- a sweep over five tiles: the text follows, only the last model loads
        for i = 1, 5 do
            ns.UI.Preview:SetHover("h" .. i)
            assert.equal("H" .. i, ns.UI.Preview:GetPanel().name:GetText())
            W.advance(0.02)
        end
        assert.same({}, loads)
        W.advance(0.1)
        assert.same({ "h5" }, loads)
        assert.equal(5025, viewer:ModelID())
        -- back on the pet already shown: nothing loads
        ns.UI.Preview:SetHover("h4")
        ns.UI.Preview:SetHover("h5")
        W.advance(0.2)
        assert.same({ "h5" }, loads)
        -- a click loads at once
        ns.UI.Preview:SetHover(nil)
        ns.UI.Preview:SetSelected("h2")
        assert.equal("h2", loads[#loads])
        viewer.Load = load
    end)
    it("a freshly loaded model faces front and holds still before it turns", function()
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local model = ns.UI.Preview:GetPanel().model
        local function tick(sec)
            for _ = 1, sec * 10 do W.advance(0.1) model._scripts.OnUpdate(model, 0.1) end
        end
        ns.UI.Preview:SetSelected("a")
        tick(3)
        assert.is_true(ns.UI.Preview:GetYaw() > 0.3, "turning after a while")
        ns.UI.Preview:SetSelected("b")                -- new model: no jump from the old angle
        if model._scripts.OnModelLoaded then model._scripts.OnModelLoaded(model) end
        tick(0.3)
        assert.equal(0, ns.UI.Preview:GetYaw())
        tick(2)
        assert.is_true(ns.UI.Preview:GetYaw() > 0)
    end)
    it("after a click, frames parented to the minimap button go back under its icon", function()
        -- EllesmereUI's flyout raises every child of a clicked button, including its own
        -- dark backdrop, which then covers the icon for good
        local button = U.universal()
        button:SetFrameLevel(10)
        local backdrop = U.universal()
        backdrop:SetFrameLevel(16)
        button._children = { backdrop }
        U.icon.buttons = { PetCall = button }
        ns.UI.Broker:OnClick(button, "LeftButton")
        W.advance(0.1)
        assert.is_true(backdrop:GetFrameLevel() < button:GetFrameLevel())
    end)
    it("falls back to a PlayerModel when the client has no pet model scenes", function()
        C_PetJournal.GetPetModelSceneInfoBySpeciesID = nil -- luacheck: ignore 122
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        ns.UI.Preview:SetSelected("a")
        W.advance(1)
        local viewer = ns.UI.Preview:GetViewer()
        assert.equal("PlayerModel", viewer.frame._type)
        assert.equal(5001, viewer:ModelID())
    end)
    it("the pet menu preview loads at once and hides on leave", function()
        ns.UI.Menu:Open()
        local item = U.lastMenu:Find("All pets").items[1].items[1]
        item.onEnter(U.universal())
        local preview = ns.UI.previews.PetCallMenuPreview
        assert.is_not_nil(preview.viewer:ModelID())      -- no W.advance: immediate
        item.onLeave()
        W.advance(0.1)
        assert.is_false(preview.frame:IsShown())
    end)

    it("the menu preview goes on the side away from the parent menu", function()
        local side = ns.UI.Menu.PreviewSide
        -- (itemLeft, itemRight, parentCenterX, screenWidth)
        assert.equal("left", side(400, 600, 700, 1920))     -- parent menu on the right
        assert.equal("right", side(900, 1100, 800, 1920))   -- parent menu on the left
        assert.equal("right", side(150, 300, 400, 1920))    -- no room on the left
        assert.equal("left", side(1650, 1850, 1500, 1920))  -- no room on the right
        assert.equal("right", side(400, 600, nil, 1920))    -- parent unknown: right if it fits
    end)
    it("the set header says which set this is, whether it is used and what it does", function()
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        ns.UI.Main:Show()
        local H = ns.UI.SetHeader
        local d = ns.Sets:Get("$Default")
        assert.is_true(H.Summary(d):find("Used when no other set is active") ~= nil)
        assert.is_true(H.Summary(d):find("one of 2 checked pets") ~= nil)
        local town = ns.Sets:Create("Town")
        town:ApplyTemplate("city")
        town:SetPetWeight("a", 1)
        assert.is_true(H.Summary(town):find("^When: ") ~= nil, H.Summary(town))
        ns.UI.Main:SelectSet("Town")
        W.advance(0.1)                                   -- the header refreshes once per burst of changes
        local header = ns.UI.Main:GetFrame().header
        assert.equal("Town", header.title:GetText())
        assert.equal("Active now", header.status:GetText())
        local content = ns.UI.Main:GetFrame().content
        assert.is_true(content._points.TOPLEFT.rel == header, "tabs and pages sit below the header")
    end)
    it("toolbar segments filter the grid and the count line says how many are in and out", function()
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local set = ns.Sets:Get("$Default")
        set:SetPetWeight("b", 0)
        W.advance(1)
        local page = ns.UI.PetsTabPage
        assert.equal("1 in this set · 1 left out", page.count:GetText())
        page.show.buttons[3]:Click()                        -- Left out
        local ids = {}
        for _, t in pairs(gridTiles()) do ids[#ids + 1] = t.petID end
        assert.same({ "b" }, ids)
        page.show.buttons[1]:Click()                        -- All
        page.favorites:Click()
        assert.is_true(ns.UI.PetsTabState().favoritesOnly)
    end)

    it("set settings hold the default weight and the reset that left the main view", function()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("settings")
        local page = ns.UI.SetSettingsPage
        assert.is_not_nil(page.defaultWeight)
        page.reset:Click()
        assert.equal("PETCALL_CONFIRM", W.world.popup)
        assert.is_nil(ns.UI.PetsTabPage.defaultWeight)
    end)
    it("tiles say the pet type and how often, not just the level", function()
        W.world.pets.b = { species = 2, name = "B", type = 3 }
        W.world.pets.c = { species = 3, name = "C" }
        W.world.pets.c2 = { species = 3, name = "C" }
        ns.PetCache:Rescan()
        local set = ns.Sets:Get("$Default")
        set:SetPetWeight("a", 0)
        set:SetPetWeight("b", 8)
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        local tiles = gridTiles()
        assert.is_true(tiles.a.sub:GetText():find("Left out") ~= nil, tiles.a.sub:GetText())
        assert.is_true(tiles.b.sub:GetText():find("BATTLE_PET_NAME_3", 1, true) ~= nil, tiles.b.sub:GetText())
        assert.is_true(tiles.b.sub:GetText():find("Often") ~= nil)
        assert.is_true(tiles.c.sub:GetText():find("x2") ~= nil)
        assert.is_nil(tiles.b.sub:GetText():find("Level"))
    end)
    it("the preview sets how often with named buttons and shows the chance as a bar", function()
        W.world.pets.a2 = { species = 1, name = "A", level = 25 }
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local set = ns.Sets:Get("$Default")
        ns.UI.Preview:SetSelected("a2")
        local panel = ns.UI.Preview:GetPanel()
        assert.equal(6, #panel.levels)
        assert.equal("Often", panel.levels[5]:GetText())
        panel.levels[5]:Click()
        assert.equal(8, set:GetPetWeight("a"))
        assert.equal(8, set:GetPetWeight("a2"))
        ns.UI.Preview:Refresh()
        assert.is_true(panel.levels[5].picked)
        assert.equal(1, panel.chanceBar._value)          -- the most likely pet fills the bar
        ns.UI.Preview:SetSelected("b")
        assert.is_true(panel.chanceBar._value < 1)
    end)
    it("the preview panel sits at the right edge and the count line above the grid", function()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local page = ns.UI.PetsTabPage
        local panel = ns.UI.Preview:GetPanel()
        assert.is_true(panel._points.TOPRIGHT.rel == page, "preview anchored to the page edge")
        assert.is_true(page.count._points.BOTTOMRIGHT.rel == page.emptyBanner, "count sits above the grid area")
    end)

    it("dragging the window size follows every step cheaply: tiles stretch, rows regroup only on a new column count", function()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        local Tab = ns.UI.PetsTab
        local filters, rows, loads = 0, 0, U.modelLoads or 0
        local origF, origR = ns.PetGridModel.Filter, ns.PetGridModel.Rows
        ns.PetGridModel.Filter = function(...) filters = filters + 1 return origF(...) end
        ns.PetGridModel.Rows = function(...) rows = rows + 1 return origR(...) end
        Tab._FitColumns(400)                                  -- 2 columns of 200
        rows = 0
        for w = 401, 560 do Tab._FitColumns(w) end            -- still 2 columns: tiles stretch
        assert.equal(0, rows)
        local second                                          -- tiles in the second column start one tile in
        for _, f in ipairs(U.created) do
            if f._template == "WowScrollBoxList" then second = f._rowFrames[1].tiles[2] end
        end
        assert.equal(280, second._points.LEFT.x)
        Tab._FitColumns(600)                                  -- 3 columns: regrouped once
        assert.equal(1, rows)
        for i = 1, 20 do ns:Fire("WindowResized", 800 + i, 560) end
        W.advance(1)
        ns.PetGridModel.Filter, ns.PetGridModel.Rows = origF, origR
        assert.equal(0, filters, "resizing never filters the pets again")
        assert.equal(loads, U.modelLoads or 0, "resizing never reloads the preview model")
        assert.same({ 3, 200 }, { Tab.Columns(600) })
        assert.same({ 1, 150 }, { Tab.Columns(150) })
    end)
    it("set cards show a pet icon and say in words what each set is doing", function()
        ns.UI.Main:Show()
        local town = ns.Sets:Create("Raid")
        town:ApplyTemplate("instance")
        town:SetPetWeight("a", 1)
        W.advance(1)
        ns.UI.SetList:Refresh()
        local byName = {}
        for _, r in ipairs(ns.UI.SetList._rows) do if r:IsShown() then byName[r.set.name] = r end end
        assert.equal("icon1", byName["$Default"].icon._texture)
        assert.is_true(byName["$Default"].state:GetText():find("Active now") ~= nil, byName["$Default"].state:GetText())
        assert.is_true(byName.Raid.state:GetText():find("Waiting for") ~= nil, byName.Raid.state:GetText())
    end)

    it("the pet out now has a card in the sets panel; the bar says the rest when the panel is folded", function()
        W.world.summoned = "a"
        ns.UI.Main:Show()
        ns.UI.SetList:SetCollapsed(false, true)
        ns.UI.StatusBar:Refresh()
        local card = ns.UI.SetList._nowCard
        assert.equal("A", card.name:GetText())
        assert.is_true(card.from:GetText():find("from") ~= nil)
        local bar = ns.UI.Main:GetFrame().status
        assert.is_nil(bar.left:GetText():find("Now:"))
        assert.is_not_nil(bar.auto)
        card:Click()
        assert.equal("a", ns.UI.Preview:GetSelected())
        ns.UI.SetList:SetCollapsed(true, true)
        assert.is_true(bar.left:GetText():find("^Now: A") ~= nil, bar.left:GetText())
    end)
    it("a set without pets says what to do and can take them all in one click", function()
        local set = ns.Sets:Create("Empty")
        set:SetDefaultWeight(0)
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Empty")
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        local page = ns.UI.PetsTabPage
        assert.is_true(page.emptyBanner:IsShown())
        page.show.buttons[2]:Click()                        -- In this set: nothing to show
        assert.equal("No pets to show with these filters.", page.emptyText:GetText())
        page.show.buttons[1]:Click()
        page.emptyBanner.all:Click()
        W.advance(1)
        assert.equal(1, set:GetPetWeight("a"))
        assert.is_false(page.emptyBanner:IsShown())
    end)
    it("the picked segment and weight step are marked, not only highlighted", function()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        local page = ns.UI.PetsTabPage
        assert.is_true(page.show.buttons[1].picked)
        page.show.buttons[2]:Click()
        assert.is_false(page.show.buttons[1].picked)
        assert.is_true(page.show.buttons[2].picked)
    end)
    it("a dark quality colour is lifted so rare names stay readable", function()
        local item = _G.C_Item
        local orig = item.GetItemQualityColor
        item.GetItemQualityColor = function() return 0, 0.44, 0.87 end
        local r, g, b = ns.Widgets.QualityColor(4)
        item.GetItemQualityColor = orig
        assert.is_true(r > 0.3 and g > 0.6 and b > 0.9)
        assert.equal(1, (ns.Widgets.QualityColor(1)))
    end)
    it("set settings come in sections; the default set has no name or danger zone", function()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("settings")
        local page = ns.UI.SetSettingsPage
        assert.is_true(page.defaultNote:IsShown())
        assert.is_false(page.danger:IsShown())
        assert.is_true(page.petsSection:IsShown())
        ns.Sets:Create("Other")
        ns.UI.Main:SelectSet("Other")
        ns.UI.Main:SelectTab("settings")
        assert.is_false(page.defaultNote:IsShown())
        assert.is_true(page.danger:IsShown())
        assert.is_true(page.behaviour:IsShown())
    end)
    it("the add-condition menu asks where, what, with whom, as whom and when, with quick picks", function()
        local set = ns.Sets:Create("Menu")
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Menu")
        ns.UI.Main:SelectTab("when")
        set:ApplyTemplate("home")
        ns.UI.Main:SelectTab("when")
        local m = set:GetConditionModel()
        assert.equal("housing", m.groups[1].rows[1][1])
        -- build the menu the dropdown would show
        local build
        for _, def in ipairs(ns.Conditions.Types()) do assert.is_not_nil(def.hint, def.key) end
        for _, f in ipairs(U.created) do
            if f._template == "WowStyle1DropdownTemplate" and f:IsVisible() then build = build or f._setupMenu end
        end
        local root = U.newMenu()
        build(nil, root)
        assert.is_not_nil(root:Find("Where I am"))
        assert.is_not_nil(root:Find("What I am doing"):Find("While swimming"))
        assert.is_not_nil(root:Find("Who I play as"):Find("On my current specialization"))
        assert.is_not_nil(root:Find("When"):Find("Holiday"))
        root:Find("When"):Find("During any holiday"):Click()
        assert.equal("holiday", set:GetConditionModel().groups[1].rows[2][1])
    end)
    it("+ New offers a recipe gallery; Create makes the set and closes the gallery", function()
        W.world.pets.fish = { species = 9, name = "Fish", type = 9 }
        ns.PetCache:Rescan()
        ns.UI.Main:Show()
        local G = ns.UI.RecipeGallery
        G:Show()
        assert.is_true(G:IsShown())
        local card
        for _, c in ipairs(G._cards) do if c.recipe.key == "swimming" then card = c end end
        assert.is_not_nil(card)
        assert.equal("1", card.count:GetText():match("%d+"))
        card.create:Click()
        assert.is_false(G:IsShown())
        local set = ns.UI.Main:GetSelectedSet()
        assert.equal(card.recipe.title, set.name)
        assert.equal("pets", ns.UI.Main:GetSelectedTab())
        W.advance(1)
        assert.is_false(ns.UI.PetsTabPage.emptyBanner:IsShown())    -- rule-only pets count as in the set
    end)
    it("a recipe without pets is greyed and cannot be created", function()
        ns.UI.Main:Show()
        ns.UI.RecipeGallery:Show()
        local seen
        for _, c in ipairs(ns.UI.RecipeGallery._cards) do
            if c.recipe.key == "night" then
                seen = true
                assert.is_false(c.create:IsEnabled())
                assert.is_true(c.reason:GetText() ~= "")
            end
        end
        assert.is_true(seen)
    end)
    it("+ New asks: empty set or from a recipe", function()
        ns.UI.Main:Show()
        ns.UI.SetList._newButton:Click()
        local root = U.lastMenu
        root:Find("Empty set"):Click()
        local box = ns.UI.SetList._nameBox
        assert.is_true(box:IsShown())
        box.edit:SetText("Fishing")
        box.create:Click()
        assert.is_false(box:IsShown())
        assert.is_not_nil(ns.Sets:Get("Fishing"))
        assert.equal("when", ns.UI.Main:GetSelectedTab())
        ns.UI.SetList._newButton:Click()
        root = U.lastMenu
        root:Find("From a template"):Click()
        assert.is_true(ns.UI.RecipeGallery:IsShown())
        ns.UI.Main:SelectSet("$Default")
        assert.is_false(ns.UI.RecipeGallery:IsShown())
    end)
    it("the preview uses the pet's own look, not the species-wide one", function()
        W.world.pets.v = { species = 7, name = "Variant", display = 4242 }
        ns.PetCache:Rescan()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        ns.UI.Preview:SetSelected("v")
        assert.equal(4242, ns.UI.Preview:GetViewer():ModelID())
        ns.UI.Preview:SetSelected("a")                     -- no own look: the species display
        assert.equal(5001, ns.UI.Preview:GetViewer():ModelID())
    end)
    it("the preview keeps the last hovered pet after the cursor leaves", function()
        W.world.pets.b = { species = 2, name = "B" }
        W.world.summoned = "a"
        ns.PetCache:Rescan()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        local tile
        for _, t in pairs(gridTiles()) do if t.petID == "b" then tile = t end end
        tile._scripts.OnEnter(tile)
        assert.equal("b", ns.UI.Preview:GetShown())
        tile._scripts.OnLeave(tile)
        W.advance(5)
        assert.equal("b", ns.UI.Preview:GetShown())        -- not back to the summoned pet
    end)
    it("the default set stands by while another set is used", function()
        local town = ns.Sets:Create("Always")
        town:SetPetWeight("a", 1)
        W.advance(1)
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("$Default")
        ns.UI.SetHeader:Refresh()
        assert.equal("Standing by", ns.UI.Main:GetFrame().header.status:GetText())
    end)
    it("+ New opens its menu above the button, not at the cursor", function()
        ns.UI.Main:Show()
        local opened
        local G = _G
        G.MenuVariants = { GetDefaultContextMenuMixin = function() return {} end }
        G.AnchorUtil = { CreateAnchor = function(point, rel, relPoint) return { point = point, rel = rel, relPoint = relPoint } end }
        G.Menu = { GetManager = function() return { OpenMenu = function(_, owner, root, anchor) opened = { owner = owner, root = root, anchor = anchor } end } end }
        G.MenuUtil.CreateRootMenuDescription = function() return U.newMenu() end
        ns.UI.SetList._newButton:Click()
        G.Menu, G.MenuVariants, G.AnchorUtil, G.MenuUtil.CreateRootMenuDescription = nil, nil, nil, nil
        assert.equal(ns.UI.SetList._newButton, opened.anchor.rel)
        assert.equal("BOTTOMLEFT", opened.anchor.point)
        assert.is_not_nil(opened.root:Find("From a template"))
    end)
    it("a pet in the set through a rule has a lit tick that cannot be ticked off", function()
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        local set = ns.Sets:Create("Rules")
        set.settings.defaultValue = 0
        set.settings.filter = { { "favorites", 1 } }
        W.world.favorites.b = true
        ns.PetCache:Rescan()
        set:FiltersChanged()
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Rules")
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        local tile = gridTiles().b
        assert.equal(0.5, tile.checkAlpha)                  -- lit like any included pet, not ghosted
        assert.is_true(tile.sub:GetText():find("via a rule") ~= nil)
        tile.check:Click()
        assert.equal(0, set:GetPetWeight("b"))             -- the click did not add a manual weight
        assert.is_true(set:Contains("b"))
        set:SetPetWeight("b", 0)                            -- a manual Never does not hide a rule pet
        assert.equal("auto", select(2, ns.PetGridModel.Badge(set, "b")))
    end)
    it("recipe cards: sections, no placeholder pet icons, Open for a set you already have", function()
        ns.UI.Main:Show()
        local G = ns.UI.RecipeGallery
        G:Show()
        local swim
        for _, c in ipairs(G._cards) do if c.recipe.key == "swimming" then swim = c end end
        assert.is_false(swim.pets[1]:IsShown())             -- no aquatic pets: no icons at all
        local afk
        for _, c in ipairs(G._cards) do if c.recipe.key == "afk" then afk = c end end
        W.world.favorites.a = true
        ns.PetCache:Rescan()
        local set = ns.Recipes.Create(afk.recipe)
        G:Show()
        for _, c in ipairs(G._cards) do if c.recipe.key == "afk" and c:IsShown() then afk = c end end
        assert.equal("Open", afk.create:GetText())
        afk.create:Click()
        assert.equal(set, ns.UI.Main:GetSelectedSet())
        assert.equal(1, #ns.Sets:List() - 1)                -- no second copy was made
    end)
    it("the recipe page replaces the set pages and Back brings them back", function()
        ns.Sets:Create("Other")
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Other")
        local f = ns.UI.Main:GetFrame()
        ns.UI.RecipeGallery:Show()
        assert.is_false(f.header:IsShown())
        assert.is_false(f.content:IsShown())
        assert.is_false(f.Tabs[1]:IsShown())
        ns.UI.RecipeGallery:Hide()
        assert.is_true(f.header:IsShown())
        assert.is_true(f.content:IsShown())
        assert.is_true(f.Tabs[2]:IsShown())                  -- When is back for a set with conditions
        ns.UI.RecipeGallery:Show()
        ns.UI.Main:SelectSet("$Default")                     -- picking a set also closes the page
        assert.is_true(f.content:IsShown())
        assert.is_false(f.Tabs[2]:IsShown())                 -- the default set has no When tab
    end)
    it("set cards are dragged into order and show their place; settings show the order and the pause state", function()
        local a, b = ns.Sets:Create("A"), ns.Sets:Create("B")       -- B on top, then A
        ns.UI.Main:Show()
        W.advance(1)
        ns.UI.SetList:Refresh()
        local SlotFor = ns.UI.SetList.SlotFor
        assert.equal(1, SlotFor(-30, 2))                    -- held above the list
        assert.equal(1, SlotFor(10, 2))
        assert.equal(2, SlotFor(40, 2))                     -- past half a card: next place
        assert.equal(2, SlotFor(999, 2))                    -- never below the last place
        -- pick up B (first) and carry it one card down: the cursor moves 46 px
        local rowB
        for _, r in ipairs(ns.UI.SetList._rows) do if r:IsShown() and r.set == b then rowB = r end end
        rowB._top = 460                                     -- first card: 40 px below the panel top
        U.cursorY = 450                                     -- grabbed 10 px into the card
        rowB._scripts.OnDragStart(rowB)
        local panel = rowB:GetParent()
        U.cursorY = 450 - 46
        panel._scripts.OnUpdate(panel, 0.1)
        rowB._scripts.OnDragStop(rowB)
        assert.equal(2, b:GetRank())
        assert.equal(1, a:GetRank())
        local rowA
        for _, r in ipairs(ns.UI.SetList._rows) do if r:IsShown() and r.set == a then rowA = r end end
        assert.equal("1", tostring(rowA.rank:GetText()))
        rowA:Click("RightButton")
        U.lastMenu:Find("Pause"):Find("Pause for 1 hour"):Click()
        assert.is_true((a:IsPaused()), "paused")
        ns.UI.SetList:Refresh()
        assert.is_true(rowA.pause:IsShown())                 -- a paused card keeps its resume button
        rowA.pause:Click()
        assert.is_false((a:IsPaused()))
        a:Pause("hour")
        ns.UI.Main:SelectSet("A")
        ns.UI.Main:SelectTab("settings")
        local page = ns.UI.SetSettingsPage
        assert.is_true(page.pauseState:GetText():find("Paused for 60 min") ~= nil, page.pauseState:GetText())
        assert.equal("1 of 2", page.order:GetText())
        page.pauseButton:Click()                            -- Resume
        assert.is_false((a:IsPaused()))
        page.down:Click()
        assert.equal(2, a:GetRank())
        assert.equal(b, ns.Sets:List()[1])
    end)
    it("a big pet moves the camera back so it fits the frame; a small one keeps the journal framing", function()
        local Fit = ns.UI.FitDistance
        assert.is_true(Fit(1, 1, 1, 0.75) > Fit(1, 1, 1, 1.5))      -- a narrow frame needs more room
        assert.is_true(Fit(4, 4, 3, 1) > Fit(1, 1, 1, 1))
        W.world.pets.big = { species = 9, name = "Big" }
        ns.PetCache:Rescan()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local viewer = ns.UI.Preview:GetViewer()
        local cam = { zoom = 3, max = 5 }
        function cam:GetZoomDistance() return self.zoom end
        function cam:SetZoomDistance(d) self.zoom = d end
        function cam:GetMaxZoomDistance() return self.max end
        function cam:SetMaxZoomDistance(d) self.max = d end
        viewer.frame.GetActiveCamera = function() return cam end
        viewer.frame.GetWidth = function() return 230 end
        viewer.frame.GetHeight = function() return 300 end
        ns.UI.Preview:SetSelected("big")
        viewer.actor.GetScale = function() return 1 end
        viewer.actor.GetActiveBoundingBox = function() return -1, -1, 0, 1, 1, 1.5 end    -- a big pet
        viewer:Fit()
        assert.is_true(cam.zoom > 3 and cam.zoom <= 12)              -- moved back, within the limit
        assert.is_true(cam.max >= cam.zoom)
        cam.zoom = 50
        viewer:Fit()
        assert.equal(50, cam.zoom)                                   -- never pulled closer
        -- measured in game: Willie fits by moving back, Murkastrasza is an odd box
        local Fit, MAX = ns.UI.FitDistance, ns.UI.FIT_MAX_BACK
        assert.is_true(Fit(4.38 * 7, 2.98 * 7, 2.09 * 7, 191 / 192) <= 26 * MAX)
        assert.is_true(Fit(15.63 * 3.45, 13.54 * 3.45, 16.27 * 3.45, 191 / 192) > 14 * MAX)
        -- a cube is a stand-in box (Will of Remornia): journal framing, still turning
        assert.is_true(ns.UI.IsStandInBox(7.99, 7.99, 7.99))
        assert.is_false(ns.UI.IsStandInBox(4.38, 2.98, 2.09))
        cam.zoom = 14
        viewer.actor.GetScale = function() return 2.55 end
        viewer.actor.GetActiveBoundingBox = function() return -3.5, -4, -3.97, 4.49, 3.99, 4.02 end
        viewer:Fit()
        assert.equal(14, cam.zoom)
        assert.is_true(viewer.standIn)
        assert.is_true(not viewer.oddBox)
        -- the box changes after the first fit (still loading): back to the journal, fit again
        viewer.standIn, viewer.fitBox, viewer.baseZoom = nil, "1.00 x 1.00 x 3.00", 14
        cam.zoom = 40
        viewer:Recheck(viewer.loadedAt)
        assert.equal(14, cam.zoom)
        assert.is_true(viewer.standIn)
        viewer.actor.GetScale = function() return 1 end
        -- a box mostly made of empty space (Murkastrasza): journal framing, standing still
        ns.UI.Preview:SetSelected("a")
        ns.UI.Preview:SetSelected("big")
        cam.zoom = 3
        viewer.actor.GetActiveBoundingBox = function() return -20, -20, 0, 30, 20, 40 end
        viewer:Fit()
        assert.equal(3, cam.zoom)
        assert.is_true(viewer.oddBox)
        local model = viewer.frame
        for _ = 1, 30 do W.advance(0.1) model._scripts.OnUpdate(model, 0.1) end
        assert.equal(0, viewer:GetYaw())                             -- no idle turn
        local before = #W.world.printed
        SlashCmdList.PETCALL("model")
        assert.is_true(#W.world.printed - before >= 3)
    end)
    it("a set that picks only by rules names them in the header, the rules bar and its settings", function()
        local set = ns.Recipes.Create({ key = "t", title = "Finds", hint = "", conditions = { { "specialLocation", locs = { "city" } } },
            rules = { { "source", 1, text = "Trading Post" } } })
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Finds")
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        assert.is_true(ns.UI.SetHeader.Summary(set):find("chosen by rules: Source: Trading Post") ~= nil, ns.UI.SetHeader.Summary(set))
        assert.equal("Pets from rules:", ns.UI.PetsTabRulesBar.label:GetText())
        ns.UI.Main:SelectTab("settings")
        local page = ns.UI.SetSettingsPage
        assert.equal("Source: Trading Post", page.rules:GetText())
        page.editRules:Click()
        assert.equal("pets", ns.UI.Main:GetSelectedTab())
        ns.UI.Main:SelectSet("$Default")
        assert.equal("More chance for:", ns.UI.PetsTabRulesBar.label:GetText())
    end)
    it("a resize while the window is still being built is not passed on", function()
        local n, ready = 0, false
        ns:RegisterCallback({}, "WindowBuilt", function() ready = true end)
        ns:RegisterCallback({}, "WindowResized", function() if not ready then n = n + 1 end end)
        local real = ns.Widgets.Dropdown
        ns.Widgets.Dropdown = function(...)
            -- a dropdown measuring itself makes the window lay out, as Blizzard's menu does
            local win = ns.UI.Main.GetFrameRaw()
            local s = win and win:GetScript("OnSizeChanged")
            if s then s(win, 800, 500) end
            return real(...)
        end
        assert.has_no_error(function() ns.UI.Main:Show() end)
        ns.Widgets.Dropdown = real
        assert.equal(0, n)
    end)
    it("a long sets list scrolls inside its own area; Out now steps aside in a short window", function()
        for i = 1, 14 do ns.Sets:Create("Set " .. i) end
        ns.UI.Main:Show()
        local SL = ns.UI.SetList
        local list = SL._list
        list.GetHeight = function() return 230 end            -- room for five cards
        SL:Refresh()
        assert.is_true(SL.CanScroll())
        assert.is_true(list.thumb:IsShown())
        SL:ScrollBy(1000)
        local most = SL:GetScroll()
        assert.equal(15 * 46 - 4 - 230, most)                   -- stops at the last card
        list._scripts.OnMouseWheel(list, 1)
        assert.equal(most - 46, SL:GetScroll())
        -- short window: the list keeps at least three cards, Out now goes
        local panel = list:GetParent()
        panel.GetHeight = function() return 250 end
        SL.LayoutPanel()
        assert.is_false(SL._nowCard:IsShown())
        panel.GetHeight = function() return 700 end
        SL.LayoutPanel()
        assert.is_true(SL._nowCard:IsShown())
        list.GetHeight = function() return 2000 end
        SL:Refresh()
        assert.is_false(SL.CanScroll())
        assert.equal(0, SL:GetScroll())
    end)
    it("resizing the set list redraws the cards only when the scroll changes", function()
        ns.UI.Main:Show()
        local SL = ns.UI.SetList
        local list = SL._list
        local n, orig = 0, SL.Refresh
        SL.Refresh = function(...) n = n + 1 return orig(...) end
        for _ = 1, 10 do list._scripts.OnSizeChanged(list) end
        SL.Refresh = orig
        assert.equal(0, n)
    end)
    it("the preview model takes the room the controls leave; a short panel drops the source lines", function()
        local Lay = ns.UI.Preview.Layout
        local big, src, chance = Lay(800)
        assert.is_true(big > 500 and src and chance)
        local m2, s2, c2 = Lay(300)                         -- source goes first
        assert.is_true(m2 >= 80 and not s2 and c2)
        local m3, s3, c3 = Lay(220)                         -- then the chance bar
        assert.is_true(m3 >= 60 and not s3 and not c3)
        assert.equal(0, (Lay(150)))                         -- then the model
        assert.is_true(Lay(700) > Lay(600))
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local panel = ns.UI.Preview:GetPanel()
        panel._scripts.OnSizeChanged(panel, 240, 300)
        assert.is_false(panel.source:IsShown())
        panel._scripts.OnSizeChanged(panel, 240, 150)
        assert.is_false(panel.model:IsShown())
        assert.is_false(panel.chanceBar:IsShown())
        panel._scripts.OnSizeChanged(panel, 240, 700)
        assert.is_true(panel.source:IsShown())
        assert.is_true(panel.model:IsShown())
        assert.is_true(panel.chanceBar:IsShown())
    end)
    it("the preview leads with the pet's own name, as its tile does", function()
        W.world.pets.n = { species = 3, name = "Ageless Bronze Drake", custom = "Hedly" }
        ns.PetCache:Rescan()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        ns.UI.Preview:SetSelected("n")
        local panel = ns.UI.Preview:GetPanel()
        assert.equal("Hedly", panel.name:GetText())
        assert.is_true(panel.sub:GetText():find("^Ageless Bronze Drake · ") ~= nil, panel.sub:GetText())
    end)
    it("the look: EllesmereUI when present, PetCall dark with QUI, or as chosen in the settings", function()
        local R = ns.Skin.Resolve
        assert.equal("eui", R("auto", true, false))
        assert.equal("eui", R("auto", true, true))
        assert.equal("flat", R("auto", false, true))
        assert.equal("blizzard", R("auto", false, false))
        assert.equal("flat", R("flat", true, false))
        assert.equal("blizzard", R("blizzard", false, true))
        -- QUI installed: PetCall dark in QUI's colours
        rawset(_G, "QUI", {
            GetSkinColor = function() return 0.2, 0.6, 1, 1 end,
            GetSkinBgColor = function() return 0.02, 0.03, 0.04, 0.9 end,
        })
        ns.Skin._Forget()
        assert.equal("flat", ns.Skin:Look())
        assert.is_true(ns.Skin:IsActive())
        local r, g, b = ns.Skin:Accent()
        assert.same({ 0.2, 0.6, 1 }, { r, g, b })
        ns.UI.Main:Show()
        local f = ns.UI.Main:GetFrame()
        assert.is_not_nil(f.pcFlat)                         -- the window got the flat body
        assert.is_not_nil(f.Inset.pcFlat)
        ns.UI.Main:SelectTab("pets")
        ns.UI.Main:SelectTab("settings")
        -- the player can opt out
        ns.db.global.look = "blizzard"
        ns.Skin._Forget()
        assert.equal("blizzard", ns.Skin:Look())
        assert.is_false(ns.Skin:IsActive())
        rawset(_G, "QUI", nil)
    end)
    it("with nothing hovered or picked, the preview follows the pet that comes out", function()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local panel = ns.UI.Preview:GetPanel()
        panel:Show()                                        -- a wide window shows the panel
        W.world.summoned = nil
        ns.UI.Preview:Refresh()
        W.world.summoned = "a"
        ns:Fire("SummonedPetChanged")
        assert.equal("A", panel.name:GetText())
    end)
    it("the sets panel redraws once per burst of changes, and not at all while the window is closed", function()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.SetList:SetCollapsed(false)
        W.advance(1)
        local lists = 0
        local list = ns.Sets.List
        ns.Sets.List = function(...) lists = lists + 1 return list(...) end
        for _ = 1, 5 do ns:Fire("ConditionStateChanged", "x") end
        W.advance(0.1)
        assert.equal(1, lists, "one redraw for the burst")
        ns.UI.Main:Hide()
        lists = 0
        for _ = 1, 5 do ns:Fire("ConditionStateChanged", "x") end
        W.advance(0.1)
        assert.equal(0, lists, "nothing is drawn behind a closed window")
        ns.Sets.List = list
        ns.Sets:Create("Late")
        W.advance(0.1)
        local function hasLate()
            for _, r in ipairs(ns.UI.SetList._rows) do
                if r:IsShown() and r.set and r.set.name == "Late" then return true end
            end
            return false
        end
        assert.is_false(hasLate())
        ns.UI.Main:Show()
        W.advance(0.1)
        assert.is_true(hasLate(), "caught up when the window opens")
    end)
    it("the set header is not worked out while the window is closed", function()
        local town = ns.Sets:Create("Town")
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet("Town")
        W.advance(0.1)
        local header = ns.UI.Main:GetFrame().header
        assert.equal("Town", header.title:GetText())
        ns.UI.Main:Hide()
        local counted = 0
        local counts = ns.UI.SetHeader.Counts
        ns.UI.SetHeader.Counts = function(...) counted = counted + 1 return counts(...) end
        local summary = ns.UI.SetHeader.Summary
        ns.UI.SetHeader.Summary = function(...) counted = counted + 1 return summary(...) end
        town:Rename("City")
        W.advance(0.1)
        ns.UI.SetHeader.Counts, ns.UI.SetHeader.Summary = counts, summary
        assert.equal(0, counted)
        assert.equal("Town", header.title:GetText())
        ns.UI.Main:Show()
        W.advance(0.1)
        assert.equal("City", header.title:GetText(), "caught up when the window opens")
    end)
    it("changing a pet's weight does not load its model again", function()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        ns.UI.Preview:SetSelected("a")
        local viewer = ns.UI.Preview:GetViewer()
        assert.is_not_nil(viewer:ModelID())
        local loads, cleared = 0, 0
        local load, clear = viewer.Load, viewer.Clear
        viewer.Load = function(...) loads = loads + 1 return load(...) end
        viewer.Clear = function(...) cleared = cleared + 1 return clear(...) end
        ns.Sets:Get("$Default"):SetPetWeight("a", ns.Weights.LEVELS[5].value)
        W.advance(1)
        viewer.Load, viewer.Clear = load, clear
        assert.equal(0, loads)
        assert.equal(0, cleared)
        assert.equal("a", ns.UI.Preview:GetShown())
    end)
    it("a grid rebuild judges each pet against the rules once, while drawing the set's table", function()
        for i = 1, 6 do W.world.pets["p" .. i] = { species = 10 + i, name = "P" .. i } end
        ns.PetCache:Rescan()
        local set = ns.Sets:Get("$Default")
        set.settings.filter = { { "favorites", 8 } }
        set:FiltersChanged()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        ns.UI.PetsTabState().show = "selected"
        W.advance(1)
        local matches = 0
        local match = ns.AutoRules.Match
        ns.AutoRules.Match = function(...) matches = matches + 1 return match(...) end
        set:SetPetWeight("p1", 0)
        W.advance(1)
        ns.AutoRules.Match = match
        ns.UI.PetsTabState().show = "all"
        assert.equal(ns.PetCache:NumPets(), matches, "one look per pet, when the set's table is drawn again")
    end)
    it("the rule weight of a pet comes from the set's table and follows rule changes", function()
        W.world.favorites = { a = true }
        ns.PetCache:Rescan()
        local set = ns.Sets:Get("$Default")
        assert.equal(0, set:GetAutoWeight("a"))
        ns.AutoRules.AddChip(set.settings.filter, "favorites", 8)
        set:FiltersChanged()
        assert.equal(8, set:GetAutoWeight("a"))
        local inSet, leftOut = ns.UI.SetHeader.Counts(set)
        assert.equal(ns.PetCache:NumPets(), inSet + leftOut)
    end)
    it("hovering pets does not add up the set's whole table each time", function()
        for i = 1, 6 do W.world.pets["p" .. i] = { species = 10 + i, name = "P" .. i } end
        ns.PetCache:Rescan()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        W.advance(1)
        ns.UI.Preview:SetHover("p1")
        local copies = 0
        local get = ns.PetCache.GetCopies
        ns.PetCache.GetCopies = function(...) copies = copies + 1 return get(...) end
        ns.UI.Preview:SetHover("p2")
        ns.PetCache.GetCopies = get
        assert.is_true(copies <= 2, "looked up " .. copies .. " pets")
        assert.equal("p2", ns.UI.Preview:GetShown())
        assert.equal(format("%.1f%%", 100 / ns.PetCache:NumPets()), ns.UI.Preview:GetPanel().chance:GetText())
    end)
    it("drawing the When tab again reuses its frames instead of making new ones", function()
        ns.UI.Main:Show()
        local set = ns.Sets:Create("Reuse")
        ns.UI.Main:SelectSet("Reuse")
        local m = set:GetConditionModel()
        m.groups = { { rows = { { "housing", ownHome = true }, { "zone", zoneName = "Dalaran" } } }, { rows = { { "specialization", class = "MAGE", spec = -1, name = "Jaina" } } } }
        set:SetConditionModel(m)
        ns.UI.Main:SelectTab("when")
        local function shown(template)
            local n = 0
            for _, f in ipairs(U.created) do if f.poolKind and f._template == template and f:IsVisible() then n = n + 1 end end
            return n
        end
        local boxes, buttons = shown("UICheckButtonTemplate"), shown("UIPanelButtonTemplate")
        local before = #U.created
        for _ = 1, 3 do ns.UI.Main:SelectTab("when") end
        assert.equal(before, #U.created, "no new frames for the same conditions")
        assert.equal(boxes, shown("UICheckButtonTemplate"))
        assert.equal(buttons, shown("UIPanelButtonTemplate"))
        -- fewer conditions: the spare frames are put away, not left on screen
        m = set:GetConditionModel()
        m.groups = { { rows = { { "specialization", class = "", spec = -1 } } } }
        set:SetConditionModel(m)
        ns.UI.Main:SelectTab("when")
        assert.equal(before, #U.created)
        assert.equal(0, shown("UICheckButtonTemplate"))
    end)
    it("opening the rule editor again reuses its frames", function()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local set = ns.Sets:Get("$Default")
        set.settings.filter = { { "favorites", 8 }, { "rare", 8 } }
        ns.AutoRules.AddCriterion(set.settings.filter, 1, "level")
        ns.AutoRules.AddCriterion(set.settings.filter, 1, "source")
        ns.AutoRules.AddCriterion(set.settings.filter, 1, "petType")
        ns.UI.AutoRulesBar:Refresh(set)
        local chips = ns.UI.AutoRulesBar._chips
        chips[1]:Click()
        chips[2]:Click()
        local before = #U.created
        for _ = 1, 3 do chips[1]:Click() chips[2]:Click() end
        assert.equal(before, #U.created, "no new frames for the same rules")
        -- the small rule shows only its own controls
        local editor = ns.UI.AutoRulesBar.GetEditor()
        local boxes = 0
        for _, f in ipairs(U.created) do
            if f.poolKind and f._type == "EditBox" and f:IsVisible() then boxes = boxes + 1 end
        end
        assert.equal(0, boxes)
        assert.is_true(editor:IsShown())
    end)
    it("the recipe gallery counts each recipe's pets once until the pets change", function()
        ns.UI.Main:Show()
        ns.PetCache:Rescan()
        local builds = 0
        local build = ns.Weights.Build
        ns.Weights.Build = function(...) builds = builds + 1 return build(...) end
        ns.UI.RecipeGallery:Show()
        local opened = builds
        ns.UI.RecipeGallery:Refresh()
        local refreshed = builds - opened
        ns.UI.RecipeGallery:Hide()
        ns.UI.RecipeGallery:Show()
        local reopened = builds - opened - refreshed
        ns.Weights.Build = build
        local recipes = #ns.Recipes.List() + #ns.Conditions.KnownHolidays()
        assert.is_true(opened <= recipes, opened .. " counts for " .. recipes .. " recipes")
        assert.equal(0, refreshed, "a resize reuses the counts")
        assert.equal(0, reopened, "opening again reuses the counts")
        -- a new pet is counted the next time
        local n = ns.Recipes.Count(ns.Recipes.List()[1])
        W.world.pets.z = { species = 99, name = "Zed", favorite = true }
        W.world.favorites = W.world.favorites or {}
        W.world.favorites.z = true
        ns.PetCache:Rescan()
        assert.is_true(ns.Recipes.Count(ns.Recipes.List()[1]) >= n)
    end)
    it("redrawing the sets panel reads the kept sums and counts: no pass over the pets", function()
        ns.UI.Main:Show()
        ns.UI.SetList:Refresh()
        local passes = 0
        local iterate = ns.PetCache.IteratePetIDs
        ns.PetCache.IteratePetIDs = function(...) passes = passes + 1 return iterate(...) end
        for _ = 1, 5 do ns.UI.SetList:Refresh() end
        ns.PetCache.IteratePetIDs = iterate
        assert.equal(0, passes)
        -- a weight change starts over
        local set = ns.Sets:GetCurrent()
        local before = ns.UI.SetHeader.Counts(set)
        local id
        for _, p in ns.PetCache:IteratePetIDs() do
            if ns.PetCache:IsPrimary(p) and set:GetPetWeight(p) == 0 and set:GetAutoWeight(p) == 0 then id = p break end
        end
        if id then
            set:SetPetWeight(id, ns.Weights.LEVELS[3].value)
            assert.equal(before + 1, (ns.UI.SetHeader.Counts(set)))
        end
    end)
    it("the pet menu sorts and labels the pets once until they change", function()
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        local sorts = 0
        local unique = ns.UI.Menu.UniquePets
        ns.UI.Menu.UniquePets = function(...) sorts = sorts + 1 return unique(...) end
        ns.UI.Menu:Open()
        local first = U.lastMenu:Find("All pets").items[1].items[2]
        ns.UI.Menu:Open()
        local again = U.lastMenu:Find("All pets").items[1].items[2]
        assert.equal(1, sorts)
        assert.equal(first.text, again.text)
        -- a renamed pet shows its new name
        W.world.pets.b.custom = "Bobby"
        ns.PetCache:Rescan()
        ns.UI.Menu:Open()
        assert.equal(2, sorts)
        local names = {}
        for _, item in ipairs(U.lastMenu:Find("All pets").items[1].items) do names[#names + 1] = item.text end
        assert.is_not_nil(table.concat(names, "|"):find("Bobby", 1, true))
        ns.UI.Menu.UniquePets = unique
    end)
end)
