# Ready-made sets (recipes) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** "+ New → From a recipe…" opens a gallery of ready-made sets built from the player's own pets; one click creates an ordinary, editable set.

**Architecture:** Three new "More chance for" rule kinds in `Core/AutoRules.lua` (source text, native to the current zone, rare or better) give recipes dynamic pet choices. `Core/Recipes.lua` holds recipe data, expands holiday and class recipes, counts matching pets with a throw-away weight table and creates sets. `UI/RecipeGallery.lua` draws the gallery over the tab area; `UI/SetList.lua`'s "+ New" becomes a two-item menu.

**Tech Stack:** WoW 12.1.5 Lua 5.1, Blizzard ScrollBox/MenuUtil, no Ace3. Tests: `python tools/lua.py tests/run.lua` (stubs in `tests/wowstub.lua`, `tests/uistub.lua`), lint: `python tools/luacheck.py .`.

**Spec:** `docs/superpowers/specs/2026-10-16-petcall-set-generator-design.md`

## Global Constraints

- No Ace3, no new libraries (only LibStub, CallbackHandler, LibDataBroker, LibDBIcon exist).
- Native Blizzard widgets; EllesmereUI only as a skin through `ns.Skin:Apply`.
- Every user-visible string goes through `L["..."]` and is added to `Locales/enUS.lua` (`python .superpowers/sdd/2026-10-15-petcall-2.0/keys.py "key" ...`); remove unused ones with `unused_keys.py --remove`.
- Only characters the game font has (`tests/glyphs_spec.lua`): no ●○☆★→•…—, use textures.
- Recipes never modify or delete existing sets.
- Weight names: Never, Very rarely, Rarely, Normal, Often, Very often; set priorities: Lowest … Highest.
- After each task: tests and luacheck green, commit only the task's files, copy changed addon files to `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\PetCall` (keep the game copy's commented `@localization` lines; never copy `Locales/??XX.lua` other than enUS).

## Review Focus

1. A recipe set whose pets come only from rules must count as having pets: header pill, set card state, empty-set banner and grid "In this set" filter (`PetGridModel` already adds `GetAutoWeight`; test it with a created recipe set).
2. Creating the same recipe twice gives "Name 2", never overwrites "Name".
3. Holiday cards with zero matching pets are hidden; other recipes with zero pets are greyed and their Create is disabled.
4. "Native to where I am" re-evaluates after `ZONE_CHANGED_NEW_AREA`, without rebuilding sets that do not use it.
5. The gallery closes when the player selects a set, a tab, or creates a set, and the tab area is usable again.

---

### Task 1: New rule kinds and source text

**Files:**
- Modify: `Core/PetCache.lua` (add `GetSourceText`)
- Modify: `Core/AutoRules.lua` (kinds `source`, `nativeZone`, `rare`; zone invalidation)
- Modify: `UI/AutoRulesBar.lua` (field kind `text`)
- Modify: `Core/Share.lua` (`FIELDS.text = "string"`)
- Modify: `tests/wowstub.lua` (`w.sources`)
- Test: `tests/autorules_spec.lua`

**Interfaces:**
- Produces: `ns.PetCache:GetSourceText(petID) -> string` (lower case, colour codes and `|n` removed, "" when unknown).
- Produces rule leaves: `{ "source", text = "hallow's end" }`, `{ "nativeZone" }`, `{ "rare" }`; weight in `[2]` as for every rule.

- [ ] **Step 1: Stub source texts.** In `tests/wowstub.lua` `defaultWorld()` add `sources = {},`; change `GetPetInfoBySpeciesID` so the 5th return is `w.sources[s] or ("Source " .. s)`.

- [ ] **Step 2: Write the failing tests** (append inside `describe("AutoRules", ...)`):

```lua
    it("source, native zone and rare rules", function()
        W.world.sources[1] = "|cFFFFD200World Event:|r Hallow's End"
        W.world.sources[2] = "|cFFFFD200Pet Battle:|r Elwynn Forest, Stormwind City"
        W.world.pets.a.quality = 4
        ns.PetCache:Rescan()
        assert.equal("world event: hallow's end", ns.PetCache:GetSourceText("a"))
        assert.is_true(AR.Match({ "source", 1, text = "Hallow's End" }, "a"))
        assert.is_false(AR.Match({ "source", 1, text = "Hallow's End" }, "b"))
        assert.is_true(AR.Match({ "nativeZone", 1 }, "b"))        -- stub zone: Stormwind City
        W.world.zone = "Durotar"
        assert.is_false(AR.Match({ "nativeZone", 1 }, "b"))
        assert.is_true(AR.Match({ "rare", 1 }, "a"))
        assert.is_false(AR.Match({ "rare", 1 }, "b"))
        assert.equal("Source: Hallow's End", AR.Describe({ "source", 1, text = "Hallow's End" }))
    end)
    it("a set with a native-zone rule is rebuilt after a zone change, others are not", function()
        W.world.sources[2] = "Pet Battle: Durotar"
        ns.PetCache:Rescan()
        local zoneSet = ns.Sets:Create("Zone")
        zoneSet.settings.defaultValue = 0
        zoneSet.settings.filter = { { "nativeZone", 1 } }
        zoneSet:FiltersChanged()
        local other = ns.Sets:Create("Other")
        assert.is_false(zoneSet:Contains("b"))
        local before = other:GetWeightTable()
        W.world.zone = "Durotar"
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.is_true(zoneSet:Contains("b"))
        assert.is_true(other:GetWeightTable() == before and not other.dirty)
    end)
```

- [ ] **Step 3: Run** `python tools/lua.py tests/autorules_spec.lua` — expect FAIL (`GetSourceText` nil).

- [ ] **Step 4: Implement.**

`Core/PetCache.lua`, below `GetCreatureID`:

```lua
-- the journal's "where from" text, plain and lower case, for rules that search it
local sources = {}      -- speciesID -> text
function PetCache:GetSourceText(petID)
    local i = infos[petID]
    if not i then return "" end
    local s = sources[i.speciesID]
    if not s then
        local _, _, _, _, raw = C_PetJournal.GetPetInfoBySpeciesID(i.speciesID)
        s = strlower((raw or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " "))
        sources[i.speciesID] = s
    end
    return s
end
```

`Core/AutoRules.lua`, add to `types` and append to `order` (`{ "favorites", "petType", "level", "rare", "source", "nativeZone" }`):

```lua
    rare = {
        key = "rare", label = L["Rare or better"], fields = {},
        match = function(e, info) return (info.quality or 0) >= 4 end,
        describe = function() return L["Rare or better"] end,
        new = function() return { "rare" } end,
    },
    source = {
        key = "source", label = L["Source mentions"],
        fields = { { key = "text", kind = "text" } },
        match = function(e, info)
            local t = strlower(e.text or "")
            return t ~= "" and strfind(ns.PetCache:GetSourceText(info.petID), t, 1, true) ~= nil
        end,
        describe = function(e) return L["Source"] .. ": " .. (e.text or "") end,
        new = function() return { "source", text = "" } end,
    },
    nativeZone = {
        key = "nativeZone", label = L["Native to where I am"], fields = {},
        match = function(e, info)
            local zone = strlower(GetZoneText() or "")
            return zone ~= "" and strfind(ns.PetCache:GetSourceText(info.petID), zone, 1, true) ~= nil
        end,
        describe = function() return L["Native to where I am"] end,
        new = function() return { "nativeZone" } end,
    },
```

Add `local strfind, strlower = strfind, strlower` to the file's locals. At the end of `Core/AutoRules.lua`:

```lua
-- "native to where I am" depends on the zone: only sets that use it are rebuilt
local function usesNativeZone(list)
    for _, e in ipairs(list or {}) do
        if e[1] == "nativeZone" then return true end
        if (e[1] == "AND" or e[1] == "OR") and usesNativeZone(e.items) then return true end
    end
    return false
end
AutoRules.UsesNativeZone = usesNativeZone
ns.Events.Register(AutoRules, "ZONE_CHANGED_NEW_AREA", function()
    for _, set in ipairs(ns.Sets:List()) do
        if usesNativeZone(set.settings.filter) then set:FiltersChanged() end
    end
end)
```

`UI/AutoRulesBar.lua` `fieldControl`, new branch before the final `end`:

```lua
    elseif field.kind == "text" then
        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetSize(160, 20)
        eb:SetAutoFocus(false)
        eb:SetText(leaf[field.key] or "")
        eb:SetScript("OnEnterPressed", function(self)
            ns.AutoRules.SetField(leaf, field.key, strtrim(self:GetText()))
            self:ClearFocus()
            commit()
        end)
        ns.Skin:Apply("EditBox", eb)
        return eb
```

`Core/Share.lua` `FIELDS`: add `text = "string",`.

Locale keys: `"Rare or better" "Source mentions" "Source" "Native to where I am"`.

- [ ] **Step 5: Run** `python tools/lua.py tests/run.lua` and `python tools/luacheck.py .` — expect all PASS, 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add Core/PetCache.lua Core/AutoRules.lua UI/AutoRulesBar.lua Core/Share.lua Locales/enUS.lua tests/wowstub.lua tests/autorules_spec.lua
git commit -m "feat(rules): source text, native-to-zone and rare-or-better rules"
```

---

### Task 2: Recipes core

**Files:**
- Create: `Core/Recipes.lua` (TOC: after `Core\Sets.lua`)
- Modify: `PetCall.toc`, `tests/run.lua` (add `tests/recipes_spec.lua`)
- Test: `tests/recipes_spec.lua`

**Interfaces:**
- Consumes: `ns.Conditions.KnownHolidays() -> { {value=id, label=title} }`, `ns.Weights.Build(settings)`, `ns.Weights.Sum(tbl, petID)`, `ns.PetCache:IteratePetIDs()`, `:IsPrimary(id)`, `:GetCopies(id)`, `ns.Sets:Create(name) -> set, ok, err`, `ns.Sets:Get(name)`, `set:SetPriority(v)`, `set:ConditionsChanged()`, `set:FiltersChanged()`.
- Produces: `ns.Recipes.List() -> { recipe }` where recipe = `{ key, title, hint, conditions = list, rules = list, priority = number|nil, holiday = bool }`; `ns.Recipes.Count(recipe) -> n, sampleIDs (up to 4 primary petIDs, most likely first)`; `ns.Recipes.Usable(recipe) -> bool, reason|nil`; `ns.Recipes.Create(recipe) -> set`; `ns.Recipes.UniqueName(base) -> string`.

- [ ] **Step 1: Write the failing tests** — new file `tests/recipes_spec.lua`:

```lua
local W = dofile("tests/wowstub.lua")
describe("Recipes", function()
    local ns, R
    before_each(function()
        W.reset()
        W.world.pets = {
            fish = { species = 1, name = "Fish", type = 9 },
            bird = { species = 2, name = "Bird", type = 3 },
            pumpkin = { species = 3, name = "Pumpkin", type = 5 },
        }
        W.world.sources[3] = "World Event: Hallow's End"
        W.world.calEvents[16] = { { eventID = 324, title = "Hallow's End", calendarType = "HOLIDAY" },
            { eventID = 555, title = "Timewalking", calendarType = "HOLIDAY" } }
        ns = W.load()
        W.login()
        W.advance(1)
        R = ns.Recipes
    end)
    local function byKey(key) for _, r in ipairs(R.List()) do if r.key == key then return r end end end

    it("lists fixed recipes and one card per holiday with pets", function()
        assert.is_not_nil(byKey("swimming"))
        assert.is_not_nil(byKey("holiday:324"))
        assert.is_nil(byKey("holiday:555"))                 -- no pet mentions it: hidden
    end)
    it("counts the pets the created set really draws from", function()
        local r = byKey("swimming")
        local n, sample = R.Count(r)
        assert.equal(1, n)
        assert.same({ "fish" }, sample)
        local set = R.Create(r)
        assert.is_true(set:Contains("fish"))
        assert.is_false(set:Contains("bird"))
        assert.equal(0, set.settings.defaultValue)
        assert.is_true(#set.settings.trigger > 0)
    end)
    it("every recipe has conditions or the lowest priority", function()
        for _, r in ipairs(R.List()) do
            assert.is_true(#r.conditions > 0 or r.priority == ns.Weights.LEVELS[2].value, r.key)
        end
    end)
    it("a taken name gets a number and the old set is untouched", function()
        local r = byKey("swimming")
        local first = R.Create(r)
        first:SetPetWeight("bird", 1)
        local second = R.Create(r)
        assert.equal(r.title .. " 2", second.name)
        assert.equal(1, ns.Sets:Get(r.title):GetPetWeight("bird"))
    end)
    it("a recipe without pets is not usable and says why", function()
        local ok, reason = R.Usable(byKey("night"))     -- no undead or magic pets
        assert.is_false(ok)
        assert.is_string(reason)
    end)
end)
```

Add `"tests/recipes_spec.lua",` to `tests/run.lua` after `"tests/sets_spec.lua",`.

- [ ] **Step 2: Run** `python tools/lua.py tests/recipes_spec.lua` — expect FAIL (`ns.Recipes` nil).

- [ ] **Step 3: Implement `Core/Recipes.lua`:**

```lua
local _, ns = ...

local L = ns.L
local ipairs, tinsert, format, sort = ipairs, tinsert, format, table.sort
local R = {}
ns.Recipes = R

local NORMAL = 1
local function types(...) return { "petType", NORMAL, petTypes = { ... } } end

-- pet types: 1 Humanoid 2 Dragonkin 3 Flying 4 Undead 5 Critter 6 Magic 7 Elemental 8 Beast 9 Aquatic 10 Mechanical
local CLASS_TYPES = {
    HUNTER = { 8 }, WARLOCK = { 4, 6 }, MAGE = { 7, 6 }, DEATHKNIGHT = { 4 }, DRUID = { 5, 8 }, SHAMAN = { 7 },
    PRIEST = { 6, 1 }, PALADIN = { 1, 6 }, WARRIOR = { 8, 1 }, ROGUE = { 5, 4 }, MONK = { 5, 7 },
    DEMONHUNTER = { 6, 4 }, EVOKER = { 2 },
}

local FIXED = {
    { key = "swimming", title = L["Water pets while swimming"], hint = L["When you swim. Aquatic pets."],
      conditions = { { "activity", swimming = true } }, rules = { types(9) } },
    { key = "outdoors", title = L["Flyers in the open world"], hint = L["Outdoors in the open world. Flying pets."],
      conditions = { { "specialLocation", locs = { "world" } }, { "activity", outdoors = true } }, rules = { types(3) } },
    { key = "zone", title = L["Pets from this zone"], hint = L["Everywhere, before the Default set. Pets native to the zone you are in."],
      conditions = {}, rules = { { "nativeZone", NORMAL } }, lowest = true },
    { key = "home", title = L["At my house"], hint = L["At your house and plot. Favorites and critters."],
      conditions = { { "housing", ownHome = true } }, rules = { { "favorites", NORMAL }, types(5) } },
    { key = "instances", title = L["Dungeons and raids"], hint = L["In dungeons and raids. Your rare level 25 pets."],
      conditions = { { "specialLocation", locs = { "dungeon", "raid" } } },
      rules = { { "AND", NORMAL, items = { { "level", operator = ">=", level = "25" }, { "rare" } } } } },
    { key = "night", title = L["Night owls"], hint = L["From 20:00 to 06:00. Undead and magic pets."],
      conditions = { { "timeOfDay", from = 20 * 60, to = 6 * 60 } }, rules = { types(4, 6) } },
    { key = "afk", title = L["Favorites while AFK"], hint = L["While you are AFK. Your favorites."],
      conditions = { { "activity", afk = true } }, rules = { { "favorites", NORMAL } } },
}

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

local function finish(r)
    r.priority = r.lowest and ns.Weights.LEVELS[2].value or nil
    return r
end

local function classRecipe()
    local className, class = UnitClass("player")
    local list = CLASS_TYPES[class]
    if not list then return nil end
    return finish({ key = "class", title = format(L["%s theme"], className),
        hint = format(L["On your %s characters. Pets that suit the class."], className),
        conditions = { { "specialization", class = class, spec = -1 } }, rules = { types(unpack(list)) } })
end

local function holidayRecipe(h)
    return finish({ key = "holiday:" .. h.value, title = h.label, holiday = true,
        hint = format(L["During %s. Pets from the event."], h.label),
        conditions = { { "holiday", holidayIDs = { h.value } } }, rules = { { "source", NORMAL, text = h.label } } })
end

-- how many tiles (copies grouped) the set would draw from, and up to four of them, most likely first
function R.Count(r)
    local tbl = ns.Weights.Build({ pets = {}, defaultValue = 0, filter = r.rules })
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

function R.UniqueName(base)
    if not ns.Sets:Get(base) then return base end
    local i = 2
    while ns.Sets:Get(base .. " " .. i) do i = i + 1 end
    return base .. " " .. i
end

function R.Create(r)
    local set = ns.Sets:Create(R.UniqueName(r.title))
    if not set then return nil end
    set.settings.defaultValue = 0
    set.settings.trigger = copy(r.conditions)
    set.settings.filter = copy(r.rules)
    if r.priority then set:SetPriority(r.priority) end
    set:FiltersChanged()
    set:ConditionsChanged()
    return set
end
```

Add `Core\Recipes.lua` to `PetCall.toc` after `Core\Sets.lua`. Add `"unpack"` to `.luacheckrc` read globals only if luacheck complains. Locale keys: every `L["..."]` in the file (use the scratchpad `addkeys.py Core/Recipes.lua` helper or `keys.py`).

Note: `Sets:Get(base)` for the Default set's display name is `$Default`; recipe titles never collide with it.

- [ ] **Step 4: Run** `python tools/lua.py tests/run.lua`, `python tools/luacheck.py .` — PASS, 0 warnings.

- [ ] **Step 5: Commit**

```bash
git add Core/Recipes.lua PetCall.toc tests/run.lua tests/recipes_spec.lua Locales/enUS.lua
git commit -m "feat(recipes): ready-made set recipes with pet counts and safe names"
```

---

### Task 3: Gallery and the "+ New" menu

**Files:**
- Create: `UI/RecipeGallery.lua` (TOC: after `UI\SetList.lua`)
- Modify: `UI/SetList.lua` ("+ New" opens a menu)
- Modify: `PetCall.toc`
- Test: `tests/ui_spec.lua`

**Interfaces:**
- Consumes: `ns.Recipes.List/Count/Usable/Create`, `ns.UI.Main:GetFrame()` (`frame.header`, `frame.content`), `ns.UI.Main:SelectSet(name)`, `ns.UI.Main:SelectTab(key)`, events `SelectedSetChanged`, `WindowHidden`.
- Produces: `ns.UI.RecipeGallery:Show()`, `:Hide()`, `:IsShown()`, `._cards` (for tests), `ns.UI.SetList.OpenNew()` (shows the old name box).

- [ ] **Step 1: Write the failing test** (append in `describe("UI smoke", ...)`):

```lua
    it("+ New offers a recipe gallery; Create makes the set and closes the gallery", function()
        W.world.pets.fish = { species = 9, name = "Fish", type = 9 }
        ns.PetCache:Rescan()
        ns.UI.Main:Show()
        local G = ns.UI.RecipeGallery
        G:Show()
        assert.is_true(G:IsShown())
        local card
        for _, c in ipairs(G._cards) do if c:IsShown() and c.recipe.key == "swimming" then card = c end end
        assert.is_not_nil(card)
        assert.equal("1", card.count:GetText():match("%d+"))
        card.create:Click()
        assert.is_false(G:IsShown())
        local set = ns.UI.Main:GetSelectedSet()
        assert.equal(card.recipe.title, set.name)
        assert.equal("pets", ns.UI.Main:GetSelectedTab())
        assert.is_false(ns.UI.PetsTabPage.emptyBanner:IsShown())    -- rule-only pets count as in the set
    end)
    it("a recipe without pets is greyed and cannot be created", function()
        ns.UI.Main:Show()
        ns.UI.RecipeGallery:Show()
        for _, c in ipairs(ns.UI.RecipeGallery._cards) do
            if c:IsShown() and c.recipe.key == "night" then
                assert.is_false(c.create:IsEnabled())
                assert.is_true(c.reason:GetText() ~= "")
            end
        end
    end)
```

If the stub's Button lacks `IsEnabled`/`SetEnabled`, add to `tests/uistub.lua`: `function Universal:SetEnabled(v) self._enabled = v and true or false end` and `function Universal:IsEnabled() return self._enabled ~= false end`.

- [ ] **Step 2: Run** `python tools/lua.py tests/ui_spec.lua` — expect FAIL (`RecipeGallery` nil).

- [ ] **Step 3: Implement `UI/RecipeGallery.lua`:**

```lua
local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local G = {}
ns.UI.RecipeGallery = G

local CARD_H = 64
local gallery, scrollBox, cards = nil, nil, {}
G._cards = cards

local function initCard(card, recipe)
    card.recipe = recipe
    card.title:SetText(recipe.title)
    card.hint:SetText(recipe.hint)
    local n, sample = ns.Recipes.Count(recipe)
    card.count:SetText(format(L["%d pets"], n))
    for i = 1, 4 do
        local info = sample[i] and ns.PetCache:GetInfo(sample[i])
        card.icons[i]:SetTexture(info and info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        card.icons[i]:SetDesaturated(n == 0)
    end
    local ok, reason = ns.Recipes.Usable(recipe)
    card.create:SetEnabled(ok)
    card.reason:SetText(reason or "")
    card:SetAlpha(ok and 1 or 0.55)
end

local function createCard(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(CARD_H - 4)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.bg:SetAtlas("PetList-ButtonBackground")
    c.icons = {}
    for i = 1, 4 do
        local t = c:CreateTexture(nil, "ARTWORK")
        t:SetSize(26, 26)
        t:SetPoint("LEFT", 6 + (i - 1) * 28, 0)
        ns.Skin:Apply("SquareIcon", t, c)
        c.icons[i] = t
    end
    c.title = ns.Widgets.Label(c, "", "GameFontNormalLarge")
    c.title:SetPoint("TOPLEFT", 128, -8)
    c.hint = ns.Widgets.Label(c, "", "GameFontHighlightSmall")
    c.hint:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
    c.reason = ns.Widgets.Label(c, "", "GameFontDisableSmall")
    c.reason:SetPoint("TOPLEFT", c.hint, "BOTTOMLEFT", 0, -3)
    c.create = ns.Widgets.Button(c, L["Create"], function()
        local set = ns.Recipes.Create(c.recipe)
        if not set then return end
        G:Hide()
        ns.UI.Main:SelectSet(set.name)
        ns.UI.Main:SelectTab("pets")
    end)
    c.create:SetPoint("RIGHT", -8, 0)
    c.count = ns.Widgets.Label(c, "", "GameFontNormal")
    c.count:SetPoint("RIGHT", c.create, "LEFT", -10, 0)
    c.hint:SetPoint("RIGHT", c.count, "LEFT", -10, 0)
    c:EnableMouse(true)
    ns.Widgets.Tooltip(c, function() return c.recipe.title end, function()
        local lines = {}
        for _, e in ipairs(c.recipe.conditions) do lines[#lines + 1] = L["When"] .. ": " .. ns.Conditions.Describe(e) end
        for _, e in ipairs(c.recipe.rules) do lines[#lines + 1] = L["Pets"] .. ": " .. ns.AutoRules.Describe(e) end
        if #c.recipe.conditions == 0 then lines[#lines + 1] = L["Used everywhere, before the Default set."] end
        return table.concat(lines, "\n")
    end)
    cards[#cards + 1] = c
    return c
end

local function build()
    local f = ns.UI.Main:GetFrame()
    gallery = CreateFrame("Frame", nil, f.Inset)
    -- covers the header, the tab row and the pages; the sets panel and status bar stay
    gallery:SetPoint("TOPLEFT", f.header, "TOPLEFT", 0, 0)
    gallery:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", 0, 0)
    gallery:SetFrameLevel(f.content:GetFrameLevel() + 30)
    gallery:EnableMouse(true)
    gallery.bg = gallery:CreateTexture(nil, "BACKGROUND")
    gallery.bg:SetAllPoints()
    gallery.bg:SetColorTexture(0.05, 0.05, 0.06, 0.97)
    local title = ns.Widgets.Label(gallery, L["New set from a recipe"], "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 10, -8)
    local sub = ns.Widgets.Label(gallery, L["Pick one; the set is ordinary afterwards and you can change everything."], "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    local back = ns.Widgets.Button(gallery, L["Back"], function() G:Hide() end)
    back:SetPoint("TOPRIGHT", -8, -8)
    scrollBox = CreateFrame("Frame", nil, gallery, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 6, -54)
    scrollBox:SetPoint("BOTTOMRIGHT", -26, 6)
    local bar = CreateFrame("EventFrame", nil, gallery, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(CARD_H)
    view:SetElementInitializer("Frame", function(frame, recipe)
        if not frame.title then
            local c = createCard(frame)
            c:SetAllPoints()
            frame.card = c
            frame.title = true
        end
        initCard(frame.card, recipe)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, bar, view)
    ns.Skin:Apply("ScrollBar", bar)
    gallery:Hide()
end

function G:Show()
    if not gallery then build() end
    local list = ns.Recipes.List()
    -- usable first, then greyed; keep the recipe order inside each group
    local usable, rest = {}, {}
    for _, r in ipairs(list) do
        if ns.Recipes.Usable(r) then usable[#usable + 1] = r else rest[#rest + 1] = r end
    end
    for _, r in ipairs(rest) do usable[#usable + 1] = r end
    gallery:Show()
    scrollBox:SetDataProvider(CreateDataProvider(usable))
end

function G:Hide() if gallery then gallery:Hide() end end
function G:IsShown() return gallery ~= nil and gallery:IsShown() end

ns:RegisterCallback(G, "SelectedSetChanged", function() G:Hide() end)
ns:RegisterCallback(G, "WindowHidden", function() G:Hide() end)
```

Note: `G:Hide()` on `SelectedSetChanged` also fires during Create (SelectSet) — harmless, it is already hidden.

`UI/SetList.lua`: replace the "+ New" button's handler:

```lua
    local function openNameBox() newBox:Show() newBox:SetFocus() end
    SetList.OpenNew = openNameBox
    local new = ns.Widgets.Button(panel, L["+ New"], function(self)
        MenuUtil.CreateContextMenu(self, function(owner, root)
            root:CreateButton(L["Empty set"], openNameBox)
            root:CreateButton(L["From a recipe..."], function() ns.UI.RecipeGallery:Show() end)
        end)
    end)
```

Use three plain dots in "From a recipe..." (the glyph test forbids the ellipsis character).

Add `UI\RecipeGallery.lua` to `PetCall.toc` after `UI\SetList.lua`. Locale keys: all new `L["..."]` in both files. If `GameFontNormalHuge` is not in `.luacheckrc` it is only a string, nothing to add.

- [ ] **Step 4: Add a menu test** next to the previous ones:

Expose the button for tests in `UI/SetList.lua`: `SetList._newButton = new`. Then:

```lua
    it("+ New asks: empty set or from a recipe", function()
        ns.UI.Main:Show()
        local root
        local orig = MenuUtil.CreateContextMenu
        MenuUtil.CreateContextMenu = function(owner, fn) root = U.newMenu() fn(owner, root) end
        ns.UI.SetList._newButton:Click()
        MenuUtil.CreateContextMenu = orig
        assert.is_not_nil(root:Find("Empty set"))
        root:Find("From a recipe"):Click()
        assert.is_true(ns.UI.RecipeGallery:IsShown())
    end)
```

(If the UI stub already records `MenuUtil.CreateContextMenu` calls, use its recorder instead of the local override.)

- [ ] **Step 5: Run** `python tools/lua.py tests/run.lua`, `python tools/luacheck.py .` — PASS, 0 warnings.

- [ ] **Step 6: Commit and copy to the game**

```bash
git add UI/RecipeGallery.lua UI/SetList.lua PetCall.toc Locales/enUS.lua tests/ui_spec.lua tests/uistub.lua
git commit -m "feat(ui): recipe gallery behind + New"
```

Copy `Core/AutoRules.lua Core/PetCache.lua Core/Share.lua Core/Recipes.lua UI/AutoRulesBar.lua UI/RecipeGallery.lua UI/SetList.lua PetCall.toc Locales/enUS.lua` to the game folder. **New files in the TOC need a full game restart, not /reload** — tell the player.

---

### Task 4: In-game check list (manual, with the player)

- Gallery opens from "+ New", scrolls, cards readable at the smallest window size.
- Holiday card appears for a current holiday when you own one of its pets (e.g. Hallow's End in October); check its source match on enUS.
- "Pets from this zone" changes pets after flying to another zone (Pets tab "In this set").
- Created set lands on the Pets tab with pets, no empty-set banner.
- EUI skin: card background and buttons look like the rest of the window.
