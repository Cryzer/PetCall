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

    it("creates the stepper slider as a Frame", function()
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        local found = false
        for _, f in ipairs(U.created) do
            if f._template == "MinimalSliderWithSteppersTemplate" then
                found = true
                assert.equal("Frame", f._type)
            end
        end
        assert.is_true(found)
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

    it("clicking a tile selects it and pins the preview; hovering others does not move it", function()
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
        assert.equal("b", ns.UI.Preview:GetShown())
        tiles.c._scripts.OnLeave(tiles.c)
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

    it("hovering a pet shows its model at once", function()
        W.world.pets.b = { species = 2, name = "B" }
        ns.PetCache:Rescan()
        ns.UI.Main:GetFrame().GetWidth = function() return 900 end
        ns.UI.Main:Show()
        ns.UI.Main:SelectTab("pets")
        ns.UI.Preview:SetHover("b")
        assert.equal(5002, ns.UI.Preview:GetViewer():ModelID())   -- no W.advance: immediate
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
        -- submenus cascaded left of where the menu opened: preview further left
        assert.equal("left", side(600, 400, 900, 1920))
        -- cascading right: preview on the right
        assert.equal("right", side(1100, 900, 700, 1920))
        -- no room on the preferred side: the other one
        assert.equal("right", side(300, 150, 900, 1920))
        assert.equal("left", side(1850, 1650, 700, 1920))
    end)
end)
