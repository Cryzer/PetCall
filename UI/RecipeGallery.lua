local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local G = {}
ns.UI.RecipeGallery = G

-- "+ New > From a recipe...": a page of ready-made sets that takes the place of the
-- set header, tabs and pages; the sets panel and the status bar stay. Cards come in
-- sections, two per row when the window is wide enough.

local ROW_H, HEADER_H, TWO_COLUMNS_FROM = 76, 28, 860
local PET_ICONS = 5
local SECTIONS = {
    { key = "places", label = L["Places"] },
    { key = "moments", label = L["Moments"] },
    { key = "company", label = L["Company"] },
    { key = "collections", label = L["Collections"] },
    { key = "class", label = L["Your class"] },
    { key = "holiday", label = L["Holidays"] },
}
local gallery, scrollBox, cards = nil, nil, {}
G._cards = cards

local function petsText(n) return format(n == 1 and L["%d pet"] or L["%d pets"], n) end

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
        card.count:SetText(n > 0 and petsText(n) or "")
        card.create:SetText(L["Create"])
        card.create:SetEnabled(ok)
        card.reason:SetText(reason or "")
    end
    card:SetAlpha((ok or card.existing) and 1 or 0.55)
end

local function cardTooltip(c)
    local lines = {}
    for _, e in ipairs(c.recipe.conditions) do lines[#lines + 1] = L["When"] .. ": " .. ns.Conditions.Describe(e) end
    if #c.recipe.conditions == 0 then lines[#lines + 1] = L["Used everywhere, before the Default set."] end
    local r = c.recipe
    if r.lowest then lines[#lines + 1] = L["Placed last, just above the Default set."] end
    for _, e in ipairs(r.rules) do
        lines[#lines + 1] = format("%s: %s - %s", L["Pets"], ns.AutoRules.Describe(e), ns.Weights.Label(ns.AutoRules.Weight(e)))
    end
    lines[#lines + 1] = format("%s: %s", L["Other pets"], ns.Weights.Label(r.defaultValue or 0))
    if r.immediate then lines[#lines + 1] = L["Summons as soon as the set becomes active."] end
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

-- section headers, then the recipes of each section in rows of one or two cards;
-- inside a section usable recipes come first
local function elements()
    local cols, out = columns(), {}
    local bySection = {}
    for _, r in ipairs(ns.Recipes.List()) do
        bySection[r.category] = bySection[r.category] or { usable = {}, rest = {} }
        local b = bySection[r.category]
        if ns.Recipes.Usable(r) or ns.Recipes.Existing(r) then b.usable[#b.usable + 1] = r else b.rest[#b.rest + 1] = r end
    end
    for _, s in ipairs(SECTIONS) do
        local b = bySection[s.key]
        if b then
            out[#out + 1] = { header = s.label }
            local list = b.usable
            for _, r in ipairs(b.rest) do list[#list + 1] = r end
            for i = 1, #list, cols do
                out[#out + 1] = { items = { list[i], cols == 2 and list[i + 1] or nil }, cols = cols }
            end
        end
    end
    return out
end

local function build()
    local f = ns.UI.Main:GetFrame()
    gallery = CreateFrame("Frame", nil, f.Inset)
    -- the area of the header, the tab row and the pages, which hide while it is open
    gallery:SetPoint("TOPLEFT", f.header, "TOPLEFT", 0, 0)
    gallery:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", 0, 0)
    local title = ns.Widgets.Label(gallery, L["New set from a template"], "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 10, -8)
    local sub = ns.Widgets.Label(gallery, L["Pick one; afterwards it is an ordinary set and you can change everything."], "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    local back = ns.Widgets.Button(gallery, L["Back"], function() G:Hide() end)
    back:SetPoint("TOPRIGHT", -8, -8)
    scrollBox = CreateFrame("Frame", nil, gallery, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", 6, -48)
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
    scrollBox:SetDataProvider(CreateDataProvider(elements()), ScrollBoxConstants.RetainScrollPosition)
end

function G:Show()
    if not gallery then build() end
    ns.UI.Main:SetSetPagesShown(false)
    gallery:Show()
    ns.Recipes.ForgetCounts()      -- favourites and the like may have changed since
    scrollBox:SetDataProvider(CreateDataProvider(elements()))
end

function G:Hide()
    if not gallery or not gallery:IsShown() then return end
    gallery:Hide()
    ns.UI.Main:SetSetPagesShown(true)
end
function G:IsShown() return gallery ~= nil and gallery:IsShown() end

ns:RegisterCallback(G, "SelectedSetChanged", function() G:Hide() end)
ns:RegisterCallback(G, "WindowHidden", function() G:Hide() end)
-- one or two columns follow the window width once a resize settles
local refreshSoon = ns.Debounce(0.12, function() G:Refresh() end)
ns:RegisterCallback(G, "WindowResized", refreshSoon)
