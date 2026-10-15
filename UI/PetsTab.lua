local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
local MIN_TILE_W, TILE_H, PREVIEW_MIN_WIDTH = 190, 48, 760

local Tab = {}
local state = { search = "", show = "all", sort = "name" }
local set, page, grid, scrollBox, scrollBar, dataProvider, emptyText, columns = nil, nil, nil, nil, nil, nil, nil, 1
local floatingPreview, gridPreview    -- gridPreview is created once and reused
local tileW = MIN_TILE_W

local function displayName(info) return info.customName or info.name end

local QUALITY_BORDER = "Interface\\Common\\WhiteIconFrame"

-- a tile stands for every copy of the pet, so weights go to all copies
local function weightMenu(owner, root, petID)
    local info = ns.PetCache:GetInfo(petID)
    if not info then return end
    root:CreateTitle(displayName(info))
    for _, lvl in ipairs(ns.Weights.LEVELS) do
        root:CreateRadio(lvl.label, function() return ns.Weights.Nearest(set:GetPetWeight(petID)) == lvl.value end,
            function() set:SetPetWeights(ns.PetCache:GetCopies(petID), lvl.value) end)
    end
    root:CreateDivider()
    root:CreateButton(L["Summon now"], function() ns:SummonPet(petID) end)
    root:CreateButton(info.isFavorite and L["Remove favorite"] or L["Set favorite"], function()
        C_PetJournal.SetFavorite(petID, info.isFavorite and 0 or 1)
    end)
end

local allTiles = {}

local function paintSelection()
    local selected = ns.UI.Preview:GetSelected()
    for _, t in ipairs(allTiles) do t.selected:SetShown(t.petID ~= nil and t.petID == selected) end
end

-- click selects the pet (and pins the preview); a second click releases it
local function tile_OnClick(self, button)
    local id = self.petID
    if not id then return end
    if button == "RightButton" or IsControlKeyDown() then
        MenuUtil.CreateContextMenu(self, function(owner, root) weightMenu(owner, root, id) end)
        return
    end
    ns.UI.Preview:SetSelected(ns.UI.Preview:GetSelected() ~= id and id or nil)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    paintSelection()
end

-- the checkbox includes the pet (all copies) at Normal or excludes it (Never)
local function check_OnClick(self)
    local id = self:GetParent().petID
    if not id then return end
    local included = set:GetPetWeight(id) > 0
    set:SetPetWeights(ns.PetCache:GetCopies(id), included and ns.Weights.NEVER or ns.Weights.NORMAL)
    PlaySound(included and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

local function tile_OnEnter(self)
    if not self.petID then return end
    if floatingPreview then
        floatingPreview:ShowForCreature(ns.PetCache:GetCreatureID(self.petID), "LEFT", self, "RIGHT", 6, 0)
    else
        ns.UI.Preview:SetHover(self.petID)
    end
    if self.name:IsTruncated() then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.name:GetText())
        GameTooltip:Show()
    end
end

local function tile_OnLeave(self)
    GameTooltip:Hide()
    if floatingPreview then floatingPreview:ScheduleHide() else ns.UI.Preview:SetHover(nil) end
end

local function createTile(parent)
    local t = CreateFrame("Button", nil, parent)
    t:SetSize(tileW - 4, TILE_H - 4)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t:SetHighlightAtlas("PetList-ButtonHighlight", "ADD")
    t.bg = t:CreateTexture(nil, "BACKGROUND")
    t.bg:SetAllPoints()
    t.bg:SetAtlas("PetList-ButtonBackground")
    t.selected = t:CreateTexture(nil, "ARTWORK", nil, -1)
    t.selected:SetAllPoints()
    t.selected:SetAtlas("PetList-ButtonSelect")
    t.selected:Hide()
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(36, 36)
    t.icon:SetPoint("LEFT", 4, 0)
    t.border = t:CreateTexture(nil, "OVERLAY")
    t.border:SetTexture(QUALITY_BORDER)
    t.border:SetAllPoints(t.icon)
    t.name = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.name:SetPoint("TOPLEFT", t.icon, "TOPRIGHT", 6, -2)
    t.name:SetPoint("RIGHT", -28, 0)
    t.name:SetJustifyH("LEFT")
    t.name:SetWordWrap(false)
    t.sub = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.sub:SetPoint("BOTTOMLEFT", t.icon, "BOTTOMRIGHT", 6, 2)
    t.sub:SetPoint("RIGHT", -44, 0)
    t.sub:SetJustifyH("LEFT")
    t.sub:SetWordWrap(false)
    t.badge = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.badge:SetPoint("BOTTOMRIGHT", -6, 6)
    t.check = CreateFrame("CheckButton", nil, t, "UICheckButtonTemplate")
    t.check:SetSize(22, 22)
    t.check:SetPoint("TOPRIGHT", -2, -2)
    t.check:SetScript("OnClick", check_OnClick)
    ns.Widgets.Tooltip(t.check, L["Include in this set"], L["Unchecked pets are never summoned by this set."])
    ns.Skin:Apply("Checkbox", t.check)
    allTiles[#allTiles + 1] = t
    t:SetScript("OnClick", tile_OnClick)
    t:SetScript("OnEnter", tile_OnEnter)
    t:SetScript("OnLeave", tile_OnLeave)
    ns.Skin:Apply("SquareIcon", t.icon, t)
    return t
end

local BADGE_COLORS = { never = { 0.6, 0.6, 0.6 }, manual = { 0.4, 1, 0.4 }, auto = { 0.4, 0.8, 1 } }
-- "manual" badges follow the EllesmereUI accent when it is present
local function refreshAccent() if ns.Skin:IsActive() then BADGE_COLORS.manual = { ns.Skin:Accent() } end end
ns.Skin:OnLooksChanged(function() refreshAccent() Tab:Rebuild() end)

local function setupTile(t, petID)
    t.petID = petID
    t:SetShown(petID ~= nil)
    if not petID then return end
    local info = ns.PetCache:GetInfo(petID)
    if not info then t:Hide() t.petID = nil return end    -- released while the grid was rebuilding
    t.icon:SetTexture(info.icon)
    local r, g, b = C_Item.GetItemQualityColor((info.quality or 2) - 1)
    t.border:SetVertexColor(r, g, b)
    t.name:SetText(displayName(info))
    t.name:SetTextColor(r, g, b)
    local copies = #ns.PetCache:GetCopies(petID)
    t.sub:SetText(format("%s %d", L["Level"], info.level) .. (copies > 1 and format("  |cffaaaaaax%d|r", copies) or ""))
    local text, kind = ns.PetGridModel.Badge(set, petID)
    t.badge:SetText(text or "")
    if kind then t.badge:SetTextColor(unpack(BADGE_COLORS[kind])) end
    t.check:SetChecked(set:GetPetWeight(petID) > 0)
    t.selected:SetShown(petID == ns.UI.Preview:GetSelected())
    t:SetAlpha(kind == "never" and 0.45 or 1)
    t.icon:SetDesaturated(kind == "never")
end

local function initRow(row, data)
    row.tiles = row.tiles or {}
    for i = 1, columns do
        local t = row.tiles[i]
        if not t then
            t = createTile(row)
            row.tiles[i] = t
        end
        t:ClearAllPoints()
        t:SetPoint("LEFT", (i - 1) * tileW, 0)
        t:SetWidth(tileW - 4)
        setupTile(t, data[i])
    end
    for i = columns + 1, #row.tiles do row.tiles[i]:Hide() end
end

function Tab:Rebuild()
    if not set or not page:IsVisible() then return end
    refreshAccent()
    local ids = ns.PetGridModel.Filter(set, state)
    local rows = ns.PetGridModel.Rows(ids, columns)
    dataProvider = CreateDataProvider(rows)
    scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
    if ns.PetCache:NumPets() == 0 then
        emptyText:SetText(L["You have no pets yet."])
        page.openJournal:Show()
    elseif #ids == 0 then
        emptyText:SetText(format(L["No pets match \"%s\"."], state.search))
        page.openJournal:Hide()
    else
        emptyText:SetText("")
        page.openJournal:Hide()
    end
    ns.UI.Preview:ShowPet(nil, set)
    ns.UI.Preview:Refresh()
end

local function layout()
    local width = ns.UI.Main:GetContentWidth()
    local narrow = ns.UI.Main:GetFrame():GetWidth() < PREVIEW_MIN_WIDTH
    local previewPanel = ns.UI.Preview:GetPanel()
    previewPanel:SetShown(not narrow)
    if narrow and not floatingPreview then
        gridPreview = gridPreview or ns:CreateModelPreview("PetCallGridPreview")
        floatingPreview = gridPreview
    end
    if not narrow and floatingPreview then floatingPreview:Hide() floatingPreview = nil end
    grid:SetPoint("BOTTOMRIGHT", narrow and page or previewPanel, narrow and "BOTTOMRIGHT" or "BOTTOMLEFT", narrow and -18 or -22, 0)
    local gridWidth = width - (narrow and 18 or (240 + 22))
    -- as many columns as fit, tiles stretched to fill the row
    columns = math.max(1, math.floor(gridWidth / MIN_TILE_W))
    tileW = math.floor(gridWidth / columns)
    Tab:Rebuild()
end

function Tab:Refresh(newSet)
    set = newSet
    page.defaultWeight:GenerateMenu()
    if ns.UI.AutoRulesBar then ns.UI.AutoRulesBar:Refresh(set) end
    layout()
end

local function filterMenu(owner, root)
    local function radio(text, key, value)
        root:CreateRadio(text, function() return state[key] == value end, function() state[key] = value Tab:Rebuild() end)
    end
    root:CreateTitle(L["Show"])
    radio(ALL, "show", "all")
    radio(L["Selected"], "show", "selected")
    radio(L["Unselected"], "show", "unselected")
    root:CreateCheckbox(L["Favorites only"], function() return state.favoritesOnly end,
        function() state.favoritesOnly = not state.favoritesOnly Tab:Rebuild() end)
    local types = root:CreateButton(L["Pet Type"])
    for i = 1, C_PetJournal.GetNumPetTypes() do
        types:CreateCheckbox(_G["BATTLE_PET_NAME_" .. i], function() return state.types and state.types[i] end,
            function() state.types = state.types or {} state.types[i] = not state.types[i] or nil Tab:Rebuild() end)
    end
    root:CreateTitle(L["Sort by"])
    radio(NAME, "sort", "name")
    radio(LEVEL, "sort", "level")
    radio(RARITY, "sort", "rarity")
    radio(L["Chance"], "sort", "chance")
    root:CreateDivider()
    local bulk = root:CreateButton(L["Set weight for all visible"])
    for _, lvl in ipairs(ns.Weights.LEVELS) do
        bulk:CreateButton(lvl.label, function()
            local tiles = ns.PetGridModel.Filter(set, state)
            local ids = {}
            for _, id in ipairs(tiles) do
                for _, copy in ipairs(ns.PetCache:GetCopies(id)) do ids[#ids + 1] = copy end
            end
            if #tiles > 20 then
                StaticPopup_Show("PETCALL_CONFIRM", format(L["Set %s for %d pets?"], lvl.label, #tiles), nil,
                    { onAccept = function() set:SetPetWeights(ids, lvl.value) end })
            else
                set:SetPetWeights(ids, lvl.value)
            end
        end)
    end
end

ns.UI.Main:RegisterTab("pets", L["Pets"], function(p)
    page = p
    local search = ns.Widgets.Search(page, function(text) state.search = strlower(text) Tab:Rebuild() end)
    search:SetPoint("TOPLEFT", 6, -4)
    search:SetWidth(200)

    local filterBtn = CreateFrame("DropdownButton", nil, page, "WowStyle1FilterDropdownTemplate")
    filterBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
    filterBtn:SetupMenu(filterMenu)
    ns.Skin:Apply("Dropdown", filterBtn)

    local clear = ns.Widgets.Button(page, L["Clear"], function()
        StaticPopup_Show("PETCALL_CONFIRM", L["Reset all pet weights in this set?"], nil,
            { onAccept = function() set:ClearPetWeights() end })
    end)
    clear:SetPoint("TOPRIGHT", -6, -2)

    page.defaultWeight = ns.Widgets.Dropdown(page, 150, function(owner, root)
        for _, lvl in ipairs(ns.Weights.LEVELS) do
            root:CreateRadio(lvl.label, function() return set and ns.Weights.Nearest(set.settings.defaultValue) == lvl.value end,
                function() set:SetDefaultWeight(lvl.value) end)
        end
    end)
    page.defaultWeight:SetPoint("RIGHT", clear, "LEFT", -8, 0)
    local dwLabel = ns.Widgets.Label(page, L["Other pets:"])
    dwLabel:SetPoint("RIGHT", page.defaultWeight, "LEFT", -6, 0)

    -- auto-rule chips row is filled by Task 11 (UI/AutoRulesBar.lua) at page.rulesBar
    page.rulesBar = CreateFrame("Frame", nil, page)
    page.rulesBar:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -4, -6)
    page.rulesBar:SetPoint("RIGHT", -6, 0)
    page.rulesBar:SetHeight(24)
    page.rulesBar:SetClipsChildren(true)
    ns.UI.PetsTabRulesBar = page.rulesBar

    local previewPanel = ns.UI.Preview:Attach(page)
    previewPanel:SetPoint("TOPRIGHT", page.rulesBar, "BOTTOMRIGHT", 0, -6)
    previewPanel:SetPoint("BOTTOMRIGHT", 0, 0)

    grid = CreateFrame("Frame", nil, page)
    grid:SetPoint("TOPLEFT", page.rulesBar, "BOTTOMLEFT", 0, -6)
    scrollBox = CreateFrame("Frame", nil, grid, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", grid, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", grid, "BOTTOMRIGHT", 4, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(TILE_H)
    view:SetElementInitializer("Frame", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    ns.Skin:Apply("ScrollBar", scrollBar)

    emptyText = ns.Widgets.Label(grid, "", "GameFontDisableLarge")
    emptyText:SetPoint("CENTER")
    page.openJournal = ns.Widgets.Button(grid, L["Open Pet Journal"], function() ToggleCollectionsJournal(2) end)
    page.openJournal:SetPoint("TOP", emptyText, "BOTTOM", 0, -10)
    page.openJournal:Hide()

    page:SetScript("OnShow", layout)
    return Tab
end, 1)

local rebuildSoon = ns.Debounce(0.05, function() Tab:Rebuild() end)
ns:RegisterCallback(Tab, "PetsChanged", rebuildSoon)
ns:RegisterCallback(Tab, "SetsChanged", function(_, name) if set and (not name or name == set.name) then rebuildSoon() end end)
ns:RegisterCallback(Tab, "WindowResized", function() if page and page:IsVisible() then layout() end end)
