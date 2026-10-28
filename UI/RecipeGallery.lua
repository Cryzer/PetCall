local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local G = {}
ns.UI.RecipeGallery = G

-- "+ New > From a recipe...": a page of ready-made sets that takes the place of the
-- set header, tabs and pages; the sets panel and the status bar stay. Cards come in
-- sections, two per row when the window is wide enough. Group buttons, a search and
-- "Only with pets" narrow the list down.

local ROW_H, HEADER_H, TWO_COLUMNS_FROM = 76, 28, 860
local PET_ICONS = 5
local CHIP_H, CHIPS_TOP = 22, 66
-- sections by when a set is used; each belongs to one group button
local SECTIONS = {
    { key = "everyday", label = L["Everyday"], group = "everyday" },
    { key = "town", label = L["Cities and home"], group = "town" },
    { key = "world", label = L["World and instances"], group = "world" },
    { key = "moving", label = L["On the move"], group = "moving" },
    { key = "time", label = L["Time of day"], group = "time" },
    { key = "company", label = L["Company"], group = "company" },
    { key = "families", label = L["Pet families"], group = "collections" },
    { key = "sources", label = L["Where pets come from"], group = "collections" },
    { key = "class", label = L["Your class"], group = "seasons" },
    { key = "holiday", label = L["Holidays"], group = "seasons" },
}
local GROUPS = {
    { key = "all", label = L["All"] },
    { key = "everyday", label = L["Everyday"] },
    { key = "town", label = L["Cities and home"] },
    { key = "world", label = L["World and instances"] },
    { key = "moving", label = L["On the move"] },
    { key = "time", label = L["Time of day"] },
    { key = "company", label = L["Company"] },
    { key = "collections", label = L["Collections"] },
    { key = "seasons", label = L["Class and holidays"] },
}
G.SECTIONS, G.GROUPS = SECTIONS, GROUPS
-- kept while the session lasts
local view = { group = "all", search = "", withPets = false }
G._view = view
local gallery, scrollBox, chips, cards = nil, nil, {}, {}
G._cards, G._chips = cards, chips


local function openOrCreate(card)
    local set = card.existing or ns.Recipes.Create(card.recipe)
    if not set then return end
    G:Hide()
    ns.UI.Main:SelectSet(set.name)
    ns.UI.Main:SelectTab("pets")
end

local function initCard(card, recipe)
    card.recipe = recipe
    card:Show()
    local n, sample = ns.Recipes.Count(recipe)
    local firstPet = sample[1] and ns.PetCache:GetInfo(sample[1])
    if recipe.atlas then
        card.icon:SetAtlas(recipe.atlas)
    elseif not recipe.icon and firstPet then
        card.icon:SetTexture(firstPet.icon)                   -- an event without a picture: one of its pets
        card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        card.icon:SetTexture(recipe.icon or "Interface\\Icons\\INV_Pet_BabyBlizzardBear")
        local c = recipe.iconCoords
        if c then card.icon:SetTexCoord(c[1], c[2], c[3], c[4]) else card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    end
    card.title:SetText(recipe.title)
    card.hint:SetText(recipe.hint)
    -- only real pets: no placeholder icons for the slots a small recipe does not fill
    local last
    for i = 1, PET_ICONS do
        local info = sample[i] and ns.PetCache:GetInfo(sample[i])
        card.pets[i]:SetShown(info ~= nil)
        if info then card.pets[i]:SetTexture(info.icon) last = card.pets[i] end
    end
    card.count:ClearAllPoints()
    if last then card.count:SetPoint("LEFT", last, "RIGHT", 6, 0) else card.count:SetPoint("LEFT", card.pets[1], "LEFT", 0, 0) end
    card.existing = ns.Recipes.Existing(recipe)
    local ok, reason = ns.Recipes.Usable(recipe)
    if card.existing then
        card.count:SetText("|cff4cd964" .. L["You have this set"] .. "|r")
        card.create:SetText(L["Open"])
        card.create:SetEnabled(true)
        card.reason:SetText("")
    else
        card.count:SetText(recipe.noPet and L["No pet"] or n > 0 and ns.Widgets.PetCount(n) or "")
        card.create:SetText(L["Create"])
        card.create:SetEnabled(ok)
        card.reason:SetText(reason or "")
    end
    card:SetAlpha((ok or card.existing) and 1 or 0.55)
end

local function cardTooltip(c)
    local lines = { c.recipe.hint, " " }
    for _, e in ipairs(c.recipe.conditions) do lines[#lines + 1] = L["When"] .. ": " .. ns.Conditions.Describe(e) end
    if #c.recipe.conditions == 0 then lines[#lines + 1] = L["Used everywhere, before the Default set."] end
    local r = c.recipe
    if r.lowest then lines[#lines + 1] = L["Placed last, just above the Default set."] end
    for _, e in ipairs(r.rules) do
        lines[#lines + 1] = format("%s: %s - %s", L["Pets"], ns.AutoRules.Describe(e), ns.Weights.Label(ns.AutoRules.Weight(e)))
    end
    lines[#lines + 1] = format("%s: %s", L["Other pets"], ns.Weights.Label(r.defaultValue or 0))
    if r.immediate then lines[#lines + 1] = L["Summons as soon as the set becomes active."] end
    if r.noPet then lines[#lines + 1] = L["No pet while this set is used"] end
    if r.switchMinutes then lines[#lines + 1] = format(L["A new pet every %d minutes."], r.switchMinutes) end
    if r.needsMounted and ns.db.profile.noSummonMounted then
        lines[#lines + 1] = "|cffffd100" .. L["Turn off \"Don't summon while mounted\" in the settings, or this set never brings a pet."] .. "|r"
    end
    return table.concat(lines, "\n")
end

local function createCard(parent)
    local c = CreateFrame("Frame", nil, parent)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.bg:SetAtlas("PetList-ButtonBackground")
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(44, 44)
    c.icon:SetPoint("LEFT", 8, 0)
    c.create = ns.Widgets.Button(c, L["Create"], function() openOrCreate(c) end)
    c.create:SetPoint("RIGHT", -8, 0)
    c.title = ns.Widgets.Label(c, "", "GameFontNormalLarge")
    c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, 2)
    c.title:SetPoint("RIGHT", c.create, "LEFT", -8, 0)
    c.title:SetWordWrap(false)
    c.hint = ns.Widgets.Label(c, "", "GameFontHighlightSmall")
    c.hint:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -3)
    c.hint:SetPoint("RIGHT", c.create, "LEFT", -8, 0)
    c.hint:SetWordWrap(false)
    c.pets = {}
    for i = 1, PET_ICONS do
        local t = c:CreateTexture(nil, "ARTWORK")
        t:SetSize(20, 20)
        t:SetPoint("TOPLEFT", c.hint, "BOTTOMLEFT", (i - 1) * 22, -5)
        c.pets[i] = t
    end
    c.count = ns.Widgets.Label(c, "", "GameFontNormalSmall")
    c.reason = ns.Widgets.Label(c, "", "GameFontDisableSmall")
    c.reason:SetPoint("TOPLEFT", c.hint, "BOTTOMLEFT", 0, -8)
    c:EnableMouse(true)
    ns.Widgets.Tooltip(c, function() return c.recipe.title end, function() return cardTooltip(c) end)
    cards[#cards + 1] = c
    return c
end

local function columns() return gallery:GetWidth() >= TWO_COLUMNS_FROM and 2 or 1 end

local function initRow(frame, data)
    if data.header then
        frame.label = frame.label or ns.Widgets.Label(frame, "", "GameFontNormalMed2")
        frame.label:SetPoint("BOTTOMLEFT", 4, 4)
        frame.label:SetText(data.header)
        frame.label:Show()
        for _, c in ipairs(frame.cards or {}) do c:Hide() end
        return
    end
    if frame.label then frame.label:Hide() end
    frame.cards = frame.cards or {}
    local n = #data.items
    for i = 1, 2 do
        local c = frame.cards[i]
        if data.items[i] then
            c = c or createCard(frame)
            frame.cards[i] = c
            c:ClearAllPoints()
            c:SetPoint("TOP", 0, 0)
            c:SetPoint("BOTTOM", 0, 6)
            if n == 1 and data.cols == 1 then
                c:SetPoint("LEFT", 0, 0) c:SetPoint("RIGHT", 0, 0)
            elseif i == 1 then
                c:SetPoint("LEFT", 0, 0) c:SetPoint("RIGHT", frame, "CENTER", -3, 0)
            else
                c:SetPoint("LEFT", frame, "CENTER", 3, 0) c:SetPoint("RIGHT", 0, 0)
            end
            initCard(c, data.items[i])
        elseif c then
            c:Hide()
        end
    end
end

-- does the recipe pass the group, the search and "Only with pets"?
function G.Matches(r, sectionGroup, v)
    if v.group ~= "all" and v.group ~= sectionGroup then return false end
    if v.withPets and not ns.Recipes.Usable(r) then return false end
    local needle = strlower(v.search or "")
    if needle ~= "" and not (strlower(r.title):find(needle, 1, true) or strlower(r.hint or ""):find(needle, 1, true)) then
        return false
    end
    return true
end

-- section headers, then the recipes of each section in rows of one or two cards;
-- inside a section: new sets you can make, then the ones you have, then grey ones
local function elements()
    local cols, out = columns(), {}
    local bySection = {}
    for _, r in ipairs(ns.Recipes.List()) do
        bySection[r.category] = bySection[r.category] or { new = {}, have = {}, rest = {} }
        local b = bySection[r.category]
        local into = ns.Recipes.Existing(r) and b.have or ns.Recipes.Usable(r) and b.new or b.rest
        into[#into + 1] = r
    end
    for _, s in ipairs(SECTIONS) do
        local b, list = bySection[s.key], {}
        for _, part in ipairs(b and { b.new, b.have, b.rest } or {}) do
            for _, r in ipairs(part) do
                if G.Matches(r, s.group, view) then list[#list + 1] = r end
            end
        end
        if #list > 0 then
            out[#out + 1] = { header = s.label }
            for i = 1, #list, cols do
                out[#out + 1] = { items = { list[i], cols == 2 and list[i + 1] or nil }, cols = cols }
            end
        end
    end
    if #out == 0 then out[1] = { header = L["No template matches."] } end
    G._elements = out
    return out
end

-- group buttons left to right, onto a new line when the next one does not fit;
-- the list starts under the last line
local function layoutChips()
    local width = math.max(1, (tonumber(gallery:GetWidth()) or 0) - 18)
    local x, y = 0, 0
    for _, b in ipairs(chips) do
        local w = b:GetWidth()
        if x > 0 and x + w > width then x, y = 0, y + CHIP_H + 4 end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", gallery, "TOPLEFT", 10 + x, -(CHIPS_TOP + y))
        x = x + w + 4
        ns.Widgets.SetPicked(b, b.group == view.group)
    end
    scrollBox:SetPoint("TOPLEFT", 6, -(CHIPS_TOP + y + CHIP_H + 8))
end

local function build()
    local f = ns.UI.Main:GetFrame()
    gallery = CreateFrame("Frame", nil, f.Inset)
    -- the area of the header, the tab row and the pages, which hide while it is open
    gallery:SetPoint("TOPLEFT", f.header, "TOPLEFT", 0, 0)
    gallery:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", 0, 0)
    local title = ns.Widgets.Label(gallery, L["New set from a template"], "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 10, -8)
    local back = ns.Widgets.Button(gallery, L["Back"], function() G:Hide() end)
    back:SetPoint("TOPRIGHT", -8, -8)
    local search = ns.Widgets.Search(gallery, function(text) view.search = text G:Refresh() end)
    search:SetPoint("TOPLEFT", 16, -38)
    search:SetWidth(200)
    G._search = search
    local withPets = ns.Widgets.Checkbox(gallery, L["Only with pets"], function() return view.withPets end,
        function(v) view.withPets = v G:Refresh() end)
    withPets:SetPoint("LEFT", search, "RIGHT", 10, 0)
    G._withPets = withPets
    for _, g in ipairs(GROUPS) do
        local b = ns.Widgets.Button(gallery, g.label, function() view.group = g.key G:Refresh() end)
        b.group = g.key
        chips[#chips + 1] = b
    end
    scrollBox = CreateFrame("Frame", nil, gallery, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 6, -(CHIPS_TOP + CHIP_H + 8))
    scrollBox:SetPoint("BOTTOMRIGHT", -26, 6)
    local bar = CreateFrame("EventFrame", nil, gallery, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, data) return data.header and HEADER_H or ROW_H end)
    view:SetElementInitializer("Frame", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, bar, view)
    ns.Skin:Apply("ScrollBar", bar)
    gallery:Hide()
end

function G:Refresh()
    if not self:IsShown() then return end
    layoutChips()
    scrollBox:SetDataProvider(CreateDataProvider(elements()), ScrollBoxConstants.RetainScrollPosition)
end

function G:Show()
    if not gallery then build() end
    ns.UI.Main:SetSetPagesShown(false)
    gallery:Show()
    layoutChips()
    scrollBox:SetDataProvider(CreateDataProvider(elements()))
end

function G:Hide()
    if not gallery or not gallery:IsShown() then return end
    gallery:Hide()
    ns.UI.Main:SetSetPagesShown(true)
end
function G:IsShown() return gallery ~= nil and gallery:IsShown() end
function G:GetFrame() return gallery end

ns:RegisterCallback(G, "SelectedSetChanged", function() G:Hide() end)
ns:RegisterCallback(G, "WindowHidden", function() G:Hide() end)
-- one or two columns follow the window width once a resize settles
local refreshSoon = ns.Debounce(0.12, function() G:Refresh() end)
ns:RegisterCallback(G, "WindowResized", refreshSoon)
