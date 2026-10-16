local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local G = {}
ns.UI.RecipeGallery = G

-- "+ New > From a recipe...": ready-made sets drawn over the tab area; the sets
-- panel and the status bar stay visible.

local CARD_H = 64
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
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
        card.icons[i]:SetTexture(info and info.icon or QUESTION)
        card.icons[i]:SetDesaturated(n == 0)
    end
    local ok, reason = ns.Recipes.Usable(recipe)
    card.create:SetEnabled(ok)
    card.reason:SetText(reason or "")
    card:SetAlpha(ok and 1 or 0.55)
end

local function cardTooltip(c)
    local lines = {}
    for _, e in ipairs(c.recipe.conditions) do lines[#lines + 1] = L["When"] .. ": " .. ns.Conditions.Describe(e) end
    if #c.recipe.conditions == 0 then lines[#lines + 1] = L["Used everywhere, before the Default set."] end
    for _, e in ipairs(c.recipe.rules) do lines[#lines + 1] = L["Pets"] .. ": " .. ns.AutoRules.Describe(e) end
    return table.concat(lines, "\n")
end

local function createCard(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetPoint("TOPLEFT", 0, 0)
    c:SetPoint("BOTTOMRIGHT", 0, 4)
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
    c.title = ns.Widgets.Label(c, "", "GameFontNormalLarge")
    c.title:SetPoint("TOPLEFT", 128, -8)
    c.hint = ns.Widgets.Label(c, "", "GameFontHighlightSmall")
    c.hint:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -4)
    c.hint:SetPoint("RIGHT", c.count, "LEFT", -10, 0)
    c.hint:SetWordWrap(false)
    c.reason = ns.Widgets.Label(c, "", "GameFontDisableSmall")
    c.reason:SetPoint("TOPLEFT", c.hint, "BOTTOMLEFT", 0, -3)
    c:EnableMouse(true)
    ns.Widgets.Tooltip(c, function() return c.recipe.title end, function() return cardTooltip(c) end)
    cards[#cards + 1] = c
    return c
end

local function build()
    local f = ns.UI.Main:GetFrame()
    gallery = CreateFrame("Frame", nil, f.Inset)
    -- covers the header, the tab row and the pages
    gallery:SetPoint("TOPLEFT", f.header, "TOPLEFT", 0, 0)
    gallery:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", 0, 0)
    gallery:SetFrameLevel(f.content:GetFrameLevel() + 30)
    gallery:EnableMouse(true)
    gallery.bg = gallery:CreateTexture(nil, "BACKGROUND")
    gallery.bg:SetAllPoints()
    gallery.bg:SetColorTexture(0.05, 0.05, 0.06, 0.97)
    local title = ns.Widgets.Label(gallery, L["New set from a recipe"], "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 10, -8)
    local sub = ns.Widgets.Label(gallery, L["Pick one; afterwards it is an ordinary set and you can change everything."], "GameFontHighlightSmall")
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
        frame.card = frame.card or createCard(frame)
        initCard(frame.card, recipe)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, bar, view)
    ns.Skin:Apply("ScrollBar", bar)
    gallery:Hide()
end

function G:Show()
    if not gallery then build() end
    -- usable first, then greyed; recipe order kept inside each group
    local usable, rest = {}, {}
    for _, r in ipairs(ns.Recipes.List()) do
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
