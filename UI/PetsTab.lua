local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
local MIN_TILE_W, TILE_H, PREVIEW_MIN_WIDTH = 190, 48, 760
-- a tile's text starts after its icon; the name leaves the tick room, the line under it does not
local TILE_PAD, NAME_X, CHECK_ROOM = 8, 46, 26
local BANNER_H = 30
local LINE_GAP = 8       -- between the toolbar, the filter line and the rules bar

local Tab = {}
ns.UI.PetsTab = Tab
local state = { search = "", show = "all", sort = "name", filters = {} }
-- the rule open on the list: { set, index (nil for a new rule), weight, original, view }
local editing
local openRule      -- openRule(index) puts the set's rule on the list (below)
local set, page, grid, scrollBox, scrollBar, dataProvider, emptyText, columns = nil, nil, nil, nil, nil, nil, nil, 1
local floatingPreview, gridPreview    -- gridPreview is created once and reused
local tileW = MIN_TILE_W
local shownIDs = {}      -- the filtered pets of the last rebuild, regrouped when the columns change
local gridRows = {}      -- those pets in rows of `columns`, as the list shows them
-- A row is as tall as its tallest tile: a long name wraps onto a second line rather than
-- being cut short. Heights are measured once per pet for the current tile width.
local heights, measure = {}, nil

local function displayName(info) return info.customName or info.name end

local QUALITY_BORDER = "Interface\\Common\\WhiteIconFrame"

-- a tile stands for every copy of the pet, so weights go to all copies
local function weightMenu(owner, root, petID)
    local info = ns.PetCache:GetInfo(petID)
    if not info then return end
    root:CreateTitle(displayName(info))
    for _, lvl in ipairs(ns.Weights.LEVELS) do
        root:CreateRadio(lvl.label, function() return ns.Weights.Nearest((set:GetLevel(petID))) == lvl.value end,
            function() set:SetPetWeights(ns.PetCache:GetCopies(petID), lvl.value) end)
    end
    -- its own setting overrides a rule: offer the rule's level back
    local _, source = set:GetLevel(petID)
    if source == "hand" and set:GetAutoWeight(petID) > 0 then
        root:CreateButton(format(L["Use the rule (%s)"], ns.Weights.Label(set:GetAutoWeight(petID))),
            function() set:UseRule(ns.PetCache:GetCopies(petID)) end)
    end
    -- the rules that pick this pet, to open from here
    local divided = false
    for i, e in ipairs(set.settings.filter or {}) do
        local f = ns.AutoRules.ToFilters(e)
        if f and ns.AutoRules.Match(e, petID) then
            if not divided then root:CreateDivider() divided = true end
            root:CreateButton(format(L["Edit rule: %s"], ns.AutoRules.Sentence(f)), function() openRule(i) end)
        end
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

-- The checkbox leaves the pet (all copies) out, even when a rule picks it: its own
-- setting wins. Ticking it again drops that setting, so the pet comes back as its rule
-- or the set's default say, or at Normal when neither would take it.
local function check_OnClick(self)
    local id = self:GetParent().petID
    if not id then return end
    local copies = ns.PetCache:GetCopies(id)
    local included = set:GetLevel(id) > 0
    if included then
        set:SetPetWeights(copies, ns.Weights.NEVER)
    else
        set:UseRule(copies)
        if set:GetLevel(id) <= 0 then set:SetPetWeights(copies, ns.Weights.NORMAL) end
    end
    PlaySound(included and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

-- leaving a tile lets go of the hover after a moment, so crossing the gap to the next
-- tile does not flash the selected pet in between
local HOVER_GRACE = 0.12
local hoverClear

local function tile_OnEnter(self)
    if not self.petID then return end
    if hoverClear then hoverClear:Cancel() hoverClear = nil end
    self.check.tex:SetAlpha(1)
    if floatingPreview then
        floatingPreview:ShowForPet(ns.PetCache:GetInfo(self.petID), "LEFT", self, "RIGHT", 6, 0)
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
    if self.checkAlpha then self.check.tex:SetAlpha(self.checkAlpha) end
    if floatingPreview then
        floatingPreview:ScheduleHide()
    else
        if hoverClear then hoverClear:Cancel() end
        hoverClear = ns:After(HOVER_GRACE, function() hoverClear = nil ns.UI.Preview:SetHover(nil) end)
    end
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
    t.name:SetJustifyH("LEFT")
    t.sub = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.sub:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -2)
    t.sub:SetJustifyH("LEFT")
    -- a small tick: bright when the pet is in the set, a faint ghost when it is left out
    t.check = CreateFrame("Button", nil, t)
    t.check:SetSize(18, 18)
    t.check:SetPoint("TOPRIGHT", -4, -4)
    t.check.tex = t.check:CreateTexture(nil, "ARTWORK")
    t.check.tex:SetAllPoints()
    t.check.tex:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
    t.check:SetHighlightTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready", "ADD")
    t.check:SetScript("OnClick", check_OnClick)
    ns.Widgets.Tooltip(t.check, L["Include in this set"], function(self)
        local id = self:GetParent().petID
        if id and select(2, ns.PetGridModel.Badge(set, id)) == "auto" then
            return L["A rule puts this pet in the set. Untick it to leave this one out anyway."]
        end
        return L["Unchecked pets are never summoned by this set."]
    end)
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
local measured = {}
ns.Skin:OnLooksChanged(function() measured = {} refreshAccent() Tab:Rebuild() end)    -- the font may change too

-- second line: what kind of pet, and how often it is drawn when that is not "Normal"
local function subText(petID, info)
    local _, kind = ns.PetGridModel.Badge(set, petID)
    local w, source = set:GetLevel(petID)
    local byHand = source == "hand" and (editing or set:GetAutoWeight(petID) > 0)
    local parts = { _G["BATTLE_PET_NAME_" .. (info.petType or 0)] or "" }
    if editing and not byHand then
        -- every pet shown is one the open rule picks: say what the rule gives it
        parts[#parts + 1] = "|cff66ccff" .. ns.Weights.Label(editing.weight) .. "|r"
    elseif byHand then
        -- its own setting wins over the rules that pick it
        local label = w > 0 and ns.Weights.Label(w) or L["Left out"]
        parts[#parts + 1] = "|cffffffff" .. label .. "|r |cff999999" .. L["by hand"] .. "|r"
    elseif kind == "never" and source == "hand" then
        -- a pet nothing picks is greyed already; one taken out by hand says so
        parts[#parts + 1] = "|cff999999" .. L["Left out"] .. "|r"
    elseif kind == "auto" then
        parts[#parts + 1] = "|cff66ccff" .. L["via a rule"] .. "|r"
    elseif ns.Weights.Nearest(w) ~= ns.Weights.NORMAL then
        local c = BADGE_COLORS.manual
        parts[#parts + 1] = format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, ns.Weights.Label(w))
    end
    local copies = #ns.PetCache:GetCopies(petID)
    if copies > 1 then parts[#parts + 1] = format("|cffaaaaaax%d|r", copies) end
    return table.concat(parts, " · ")
end

local function nameWidth() return tileW - 4 - NAME_X - CHECK_ROOM end
local function subWidth() return tileW - 4 - NAME_X - 6 end
local function textHeight(fs) return math.ceil(tonumber(fs:GetStringHeight()) or 0) end

-- the height a text takes at a width, measured once: most tiles share the line under the
-- name, and names stay the same from one rebuild to the next
local function measuredHeight(which, text, width)
    local m = measured[which]
    if not m or m.width ~= width then
        m = { width = width, heights = {} }
        measured[which] = m
    end
    local h = m.heights[text]
    if not h then
        local fs = measure[which]
        fs:SetWidth(width)
        fs:SetText(text)
        h = textHeight(fs)
        m.heights[text] = h
    end
    return h
end

-- how tall a pet's tile needs to be for its name and the line under it
local function tileHeight(petID)
    if heights[petID] then return heights[petID] end
    local h = TILE_H - 4
    local info = ns.PetCache:GetInfo(petID)
    if info then
        h = math.max(h, 2 * TILE_PAD + measuredHeight("name", displayName(info), nameWidth()) + 2
            + measuredHeight("sub", subText(petID, info), subWidth()))
    end
    heights[petID] = h
    return h
end

-- a row's height in the list, the gap under it included
local function rowExtent(data)
    local h = TILE_H - 4
    for i = 1, columns do if data[i] then h = math.max(h, tileHeight(data[i])) end end
    return h + 4
end

local function setupTile(t, petID, height)
    t.petID = petID
    t:SetShown(petID ~= nil)
    if not petID then return end
    local info = ns.PetCache:GetInfo(petID)
    if not info then t:Hide() t.petID = nil return end    -- released while the grid was rebuilding
    t:SetHeight(height)
    t.icon:SetTexture(info.icon)
    local r, g, b = ns.Widgets.QualityColor(info.quality)
    t.border:SetVertexColor(r, g, b)
    t.name:SetWidth(nameWidth())
    t.name:SetText(displayName(info))
    t.name:SetTextColor(r, g, b)
    t.sub:SetWidth(subWidth())
    t.sub:SetText(subText(petID, info))
    -- the text sits in the middle of a tile its row made taller
    local text = textHeight(t.name) + 2 + textHeight(t.sub)
    t.name:ClearAllPoints()
    t.name:SetPoint("TOPLEFT", NAME_X, -math.max(TILE_PAD, math.floor((height - text) / 2)))
    local _, kind = ns.PetGridModel.Badge(set, petID)
    local included = set:GetLevel(petID) > 0
    -- hundreds of identical bright ticks are noise: quiet until the tile is hovered;
    -- pets that are in through a rule get the rule colour
    t.check.tex:SetDesaturated(not included)
    if kind == "auto" then t.check.tex:SetVertexColor(0.4, 0.8, 1) else t.check.tex:SetVertexColor(1, 1, 1) end
    t.checkAlpha = included and 0.5 or 0.2
    t.check.tex:SetAlpha(t:IsMouseOver() and 1 or t.checkAlpha)
    t.selected:SetShown(petID == ns.UI.Preview:GetSelected())
    t:SetAlpha(kind == "never" and 0.45 or 1)
    t.icon:SetDesaturated(kind == "never")
end

local function initRow(row, data)
    row.tiles = row.tiles or {}
    local height = rowExtent(data) - 4
    for i = 1, columns do
        local t = row.tiles[i]
        if not t then
            t = createTile(row)
            row.tiles[i] = t
        end
        t.col = i
        t:ClearAllPoints()
        t:SetPoint("LEFT", (i - 1) * tileW, 0)
        t:SetWidth(tileW - 4)
        setupTile(t, data[i], height)
    end
    for i = columns + 1, #row.tiles do row.tiles[i]:Hide() end
end

function Tab:Rebuild()
    if not set or not page:IsVisible() then return end
    refreshAccent()
    local ids = ns.PetGridModel.Filter(set, state)
    shownIDs = ids
    heights = {}         -- names, weights and the open rule may all have changed
    gridRows = ns.PetGridModel.Rows(ids, columns)
    dataProvider = CreateDataProvider(gridRows)
    scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
    if ns.PetCache:NumPets() == 0 then
        emptyText:SetText(L["You have no pets yet."])
        page.openJournal:Show()
    elseif #ids == 0 then
        emptyText:SetText(state.search ~= "" and format(L["No pets match \"%s\"."], state.search) or L["No pets to show with these filters."])
        page.openJournal:Hide()
    else
        emptyText:SetText("")
        page.openJournal:Hide()
    end
    local inSet, leftOut = ns.UI.SetHeader.Counts(set)
    page.count:SetText(format(L["%d in this set · %d left out"], inSet, leftOut))
    Tab:RefreshFilterBar(#ids, inSet + leftOut)
    -- a set nobody picked pets for yet says what to do instead of only "0 in this set"
    -- a "no pet" set says so instead; the pets below are not used while it is
    local noPet = set:IsNoPet()
    local empty = noPet or (inSet == 0 and ns.PetCache:NumPets() > 0)
    page.emptyBanner.text:SetText(noPet and L["This set keeps your pet away. The pets below are not used while it is."]
        or L["No pets in this set yet. Tick the ones you want, or include them all."])
    page.emptyBanner.all:SetShown(not noPet)
    page.emptyBanner:SetShown(empty)
    Tab:PlaceBelowFilters()
    page.show:Refresh()
    -- the same pet stays in the preview: its weight and chance change, its model does not reload
    ns.UI.Preview:SetSet(set)
    ns.UI.Preview:Refresh()
end

-- The toolbar and the filter line each take one line or more; the banner, the grid and
-- the preview start under them.
local function contentTop()
    local top = 4 + (page.toolbarHeight or 24) + LINE_GAP
    if page.filterBar:IsShown() then top = top + (page.filterBarHeight or 22) + LINE_GAP end
    return top
end

-- the toolbar and the filter line flow onto more lines when their controls do not fit;
-- hidden controls (the other mode's) take no room
local function layoutToolbar()
    ns.Widgets.FitButton(page.filterBtn, 16)
    page.toolbarHeight = ns.Widgets.Flow(page.toolbar, { page.search, page.show, page.favorites, page.filterBtn,
        page.rulesBtn, { frame = page.count, right = true } }, { rowHeight = 24 })
    local bar = page.filterBar
    if bar:IsShown() then
        -- an open rule reads as a sentence: Editing rule · pets [Beast] or [Aquatic]
        -- [+ Condition] come out [Very often] ... 109 pets; its buttons on the row below
        local items = { bar.shown, bar.petsWord }
        for _, b in ipairs(bar.chips) do
            items[#items + 1] = b.join
            items[#items + 1] = b
        end
        for _, f in ipairs({ bar.addCondition, bar.comeOut, bar.weight, bar.clear }) do items[#items + 1] = f end
        for _, f in ipairs({ bar.ruleCount, bar.bulk, bar.makeRule }) do items[#items + 1] = { frame = f, right = true } end
        items[#items + 1] = { frame = bar.delete, right = true, newRow = true }
        items[#items + 1] = { frame = bar.cancel, right = true }
        items[#items + 1] = { frame = bar.save, right = true }
        page.filterBarHeight = ns.Widgets.Flow(bar, items)
    end
end

function Tab:PlaceBelowFilters()
    if not page then return end
    local top = contentTop()
    ns.UI.Preview:GetPanel():SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -top)
    page.emptyBanner:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -top)
    grid:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -top - (page.emptyBanner:IsShown() and BANNER_H + 6 or 0))
end

function ns.UI.PetsTabState() return state end

-- Resizing is followed frame by frame and kept cheap: the pets are not filtered again
-- and the preview is left alone. Within the same number of columns the tiles only
-- stretch; a new number of columns regroups the pets already shown into rows.

-- as many columns as fit, tiles stretched to fill the row -> columns, tile width
function Tab.Columns(width)
    local n = math.max(1, math.floor(width / MIN_TILE_W))
    return n, math.floor(width / n)
end

-- the first pet of the row at the top of the view, with the rows as they are now
local function firstShownPet()
    local offset = tonumber(scrollBox.GetDerivedScrollOffset and scrollBox:GetDerivedScrollOffset()) or 0
    local y = 0
    for i, data in ipairs(gridRows) do
        y = y + rowExtent(data)
        if y > offset then return (i - 1) * columns + 1 end
    end
    return 1
end

-- regroup into rows, keeping the pet at the top of the view at the top
local function regroup(firstPet)
    gridRows = ns.PetGridModel.Rows(shownIDs, columns)
    dataProvider = CreateDataProvider(gridRows)
    scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.DiscardScrollPosition)
    local row = math.floor((firstPet - 1) / columns) + 1
    if row > 1 and scrollBox.ScrollToElementDataIndex then
        scrollBox:ScrollToElementDataIndex(row, ScrollBoxConstants.AlignBegin, nil, ScrollBoxConstants.NoScrollInterpolation)
    end
end

-- Fit the tiles to the grid's width; true when the columns changed. Tiles only stretch
-- while the count stays; the rows are laid out again only when a name's lines change.
local function fitColumns(width)
    width = tonumber(width) or 0
    if width <= 0 then return false end
    local oldColumns, oldW = columns, tileW
    local firstPet = dataProvider and firstShownPet() or 1
    columns, tileW = Tab.Columns(width)
    if columns ~= oldColumns then
        heights = {}
        if dataProvider then regroup(firstPet) end
        return true
    end
    if tileW == oldW then return false end
    local old = heights
    heights = {}
    local changed = false
    for id, h in pairs(old) do
        if tileHeight(id) ~= h then changed = true break end
    end
    if changed and dataProvider then
        scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
        return false
    end
    for _, t in ipairs(allTiles) do
        if t.col then
            t:SetPoint("LEFT", (t.col - 1) * tileW, 0)
            t:SetWidth(tileW - 4)
            if t.petID then
                t.name:SetWidth(nameWidth())
                t.sub:SetWidth(subWidth())
            end
        end
    end
    return false
end
Tab._FitColumns = fitColumns      -- for tests

-- the preview beside the grid, or a floating one over it when the window is narrow
local function placeGrid()
    local narrow = (tonumber(ns.UI.Main:GetFrame():GetWidth()) or 0) < PREVIEW_MIN_WIDTH
    local previewPanel = ns.UI.Preview:GetPanel()
    previewPanel:SetShown(not narrow)
    if narrow and not floatingPreview then
        gridPreview = gridPreview or ns:CreateModelPreview("PetCallGridPreview")
        floatingPreview = gridPreview
    end
    if not narrow and floatingPreview then floatingPreview:Hide() floatingPreview = nil end
    grid:SetPoint("BOTTOMRIGHT", narrow and page or previewPanel, narrow and "BOTTOMRIGHT" or "BOTTOMLEFT", narrow and -18 or -22, 0)
    return narrow
end

local function layout()
    local narrow = placeGrid()
    -- measure the grid itself; before the first frame it has no size yet, so derive it
    local gridWidth = tonumber(grid:GetWidth()) or 0
    if gridWidth <= 0 then
        gridWidth = ns.UI.Main:GetContentWidth() - (narrow and 18 or (240 + 22))
    end
    columns, tileW = Tab.Columns(gridWidth)
    Tab:Rebuild()
end

-- Rules are made on the list itself: filter it down to the pets a rule is for, Make a
-- rule, pick how often. Editing a rule loads its filters, so the list shows exactly the
-- pets it picks; search and the segment wait until the rule is saved or put away.
local function rulesOf(s)
    s.settings.filter = s.settings.filter or {}
    return s.settings.filter
end

-- next to ticked pets a rule is there to add chance, so it starts at Often; where rules
-- are all a set has, Normal already means "these pets"
local function newRuleWeight()
    if ns.UI.SetHeader.RulesOnly(set) then return ns.Weights.NORMAL end
    for _, lvl in ipairs(ns.Weights.LEVELS) do
        if lvl.key == "HIGH" then return lvl.value end
    end
end

local function copyFilters(f)
    local out = {}
    for k, v in pairs(f) do
        if type(v) == "table" then
            local t = {}
            for a, b in pairs(v) do t[a] = b end
            out[k] = t
        else
            out[k] = v
        end
    end
    return out
end

local function ruleKey(entry, weight) return ns.AutoRules.Key(entry) .. "\n" .. tostring(weight) end

local function startEditing(index, filters, weight)
    editing = { set = set, index = index, weight = weight,
        view = { search = state.search, show = state.show, filters = state.filters } }
    if index then editing.original = ruleKey(rulesOf(set)[index], weight) end
    state.filters, state.editing = copyFilters(filters), editing
    Tab:Rebuild()
end

-- the rule the filters make now, with its weight; nil without any filter
local function currentRule()
    local entry = ns.AutoRules.FromFilters(state.filters)
    if entry then entry[2] = editing.weight end
    return entry
end

local function unsaved()
    local entry = currentRule()
    return not editing.original or not entry or ruleKey(entry, editing.weight) ~= editing.original
end

local function stopEditing()
    local view = editing.view
    editing, state.editing = nil, nil
    state.search, state.show, state.filters = view.search, view.show, view.filters
    page.search:SetText(view.search)
    Tab:Rebuild()
end

-- true when saved: a rule needs at least one filter
local function saveRule()
    local entry = currentRule()
    if not entry then
        UIErrorsFrame:AddMessage(L["Pick at least one filter for the rule."], 1, 0.82, 0)
        ns.Widgets.ErrorSound()
        return false
    end
    local list = rulesOf(editing.set)
    if editing.index then list[editing.index] = entry else list[#list + 1] = entry end
    editing.set:FiltersChanged()
    stopEditing()
    return true
end

local function deleteRule()
    if editing.index then
        table.remove(rulesOf(editing.set), editing.index)
        editing.set:FiltersChanged()
    end
    stopEditing()
end

StaticPopupDialogs["PETCALL_RULE_UNSAVED"] = {
    text = L["Save the changes to this rule?"], button1 = SAVE, button2 = L["Discard"],
    timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) data.onAccept() end,
    OnCancel = function(_, data) data.onCancel() end,
}

-- leaving an open rule (another set, another tab, the window closing) asks first when it
-- has changes; then() runs once the rule is put away
local function leaveEditing(after)
    after = after or function() end
    if not editing then return after() end
    if not unsaved() then stopEditing() return after() end
    StaticPopup_Show("PETCALL_RULE_UNSAVED", nil, nil, {
        onAccept = function() if not saveRule() then stopEditing() end after() end,
        onCancel = function() stopEditing() after() end,
    })
end

function openRule(i)
    leaveEditing(function()
        local e = rulesOf(set)[i]
        startEditing(i, ns.AutoRules.ToFilters(e), ns.AutoRules.Weight(e))
    end)
end

local PENCIL = "|TInterface\\Buttons\\UI-GuildButton-PublicNote-Up:14:14|t "

-- every rule of the set: picking one opens it on the list; rules the filters cannot show
-- (from older versions) can be read and deleted. Last: a new rule from the filters on now.
local function rulesMenu(owner, root)
    local list = rulesOf(set)
    root:CreateTitle(ns.UI.SetHeader.RulesOnly(set) and L["Pets from rules"] or L["Rules"])
    if #list > 0 then root:CreateTitle(L["Pick a rule to change it."]) end
    for i, e in ipairs(list) do
        local f = ns.AutoRules.ToFilters(e)
        local weight = ns.AutoRules.Weight(e)
        local text = format("%s: %s  |cff9d9d9d%s|r", ns.Weights.Label(weight), f and ns.AutoRules.Sentence(f) or L["Complex rule"],
            ns.Widgets.PetCount(ns.PetGridModel.CountMatching(e)))
        if f then
            root:CreateButton(PENCIL .. text, function() openRule(i) end)
        else
            local sub = root:CreateButton(text)
            sub:CreateTitle(ns.AutoRules.Describe(e))
            sub:CreateButton(DELETE, function()
                table.remove(list, i)
                set:FiltersChanged()
            end)
        end
    end
    root:CreateDivider()
    if next(state.filters) and not editing then
        root:CreateButton(L["New rule from the current filters"], function() startEditing(nil, state.filters, newRuleWeight()) end)
    elseif not editing then
        root:CreateTitle(L["Filter the list, then Make a rule."])
    end
end

function Tab:Refresh(newSet)
    if editing and editing.set ~= newSet then leaveEditing() end
    set = newSet
    layout()
end

-- one weight for every pet the list shows, all copies included
local function setWeightForShown(lvl)
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
end

local function weightLevelsMenu(menu)
    for _, lvl in ipairs(ns.Weights.LEVELS) do
        menu:CreateButton(lvl.label, function() setWeightForShown(lvl) end)
    end
end

-- a filter choice on or off: a whole group (value nil) or one pet type or source in it
local function toggle(group, value)
    local f = state.filters
    if value == nil then
        f[group] = not f[group] or nil
    else
        f[group] = f[group] or {}
        f[group][value] = not f[group][value] or nil
        if not next(f[group]) then f[group] = nil end
    end
    Tab:Rebuild()
end

local function levelLabel(operator, level) return ns.AutoRules.Tokens({ level = { operator = operator, level = level } })[1].label end

-- what a filter or a rule can ask of a pet; the star is on the toolbar, so the rule line's
-- + Condition also offers Favorites
local function conditionItems(root, withFavorites)
    local f = state.filters
    if withFavorites then
        root:CreateCheckbox(L["Favorites"], function() return f.favorites end, function() toggle("favorites") end)
    end
    local types = root:CreateButton(L["Pet Type"])
    for i = 1, C_PetJournal.GetNumPetTypes() do
        types:CreateCheckbox(_G["BATTLE_PET_NAME_" .. i], function() return f.types and f.types[i] end,
            function() toggle("types", i) end)
    end
    -- sources none of your pets come from are left out, unless one is still ticked
    local sources = root:CreateButton(L["Sources"])
    local counts = ns.PetGridModel.SourceCounts()
    for i = 1, ns.AutoRules.NumSources() do
        local ticked = f.sources and f.sources[i]
        if counts[i] and (counts[i] > 0 or ticked) then
            sources:CreateCheckbox(format("%s (%d)", ns.AutoRules.SourceLabel(i), counts[i]),
                function() return f.sources and f.sources[i] end, function() toggle("sources", i) end)
        end
    end
    -- the same for expansions, the newest first
    local expansions = root:CreateButton(L["Expansion"])
    local perExpansion, all = ns.PetGridModel.ExpansionCounts(), ns.Expansions.All()
    for n = #all, 1, -1 do
        local i = all[n]
        if perExpansion[i] > 0 or (f.expansions and f.expansions[i]) then
            expansions:CreateCheckbox(format("%s (%d)", ns.Expansions.Name(i), perExpansion[i]),
                function() return f.expansions and f.expansions[i] end, function() toggle("expansions", i) end)
        end
    end
    -- a level from an older rule that is neither of these shows as a third choice
    local level = root:CreateButton(L["Level"])
    local function levelRadio(text, operator, n)
        level:CreateRadio(text, function()
            local cur = f.level
            if not operator then return cur == nil end
            return cur ~= nil and cur.operator == operator and cur.level == n
        end, function()
            f.level = operator and { operator = operator, level = n } or nil
            Tab:Rebuild()
        end)
    end
    levelRadio(L["Any level"])
    levelRadio(levelLabel("==", 25), "==", 25)
    levelRadio(levelLabel("<", 25), "<", 25)
    local cur = f.level
    if cur and not ((cur.operator == "==" or cur.operator == "<") and cur.level == 25) then
        levelRadio(levelLabel(cur.operator, cur.level), cur.operator, cur.level)
    end
    root:CreateCheckbox(L["Rare or better"], function() return f.rare end, function() toggle("rare") end)
    root:CreateCheckbox(L["From this zone"], function() return f.nativeZone end, function() toggle("nativeZone") end)
    root:CreateCheckbox(L["From this expansion"], function() return f.expansionHere end, function() toggle("expansionHere") end)
end

local function filterMenu(owner, root)
    local function radio(text, key, value)
        root:CreateRadio(text, function() return state[key] == value end, function() state[key] = value Tab:Rebuild() end)
    end
    conditionItems(root)
    root:CreateTitle(L["Sort by"])
    radio(NAME, "sort", "name")
    radio(LEVEL, "sort", "level")
    radio(RARITY, "sort", "rarity")
    radio(L["Chance"], "sort", "chance")
end

-- While anything narrows the list, a line under the toolbar says how many pets it shows,
-- names each filter with a button that removes it, and offers one weight for every pet
-- shown or a rule made of these filters. While a rule is open, the same line is the rule:
-- its weight, its filters, how many pets it picks, and Save. Filter buttons look like the
-- picked segment.
-- a chip, and the word ("or", "and") before it
local function filterChip(i)
    local bar = page.filterBar
    local b = bar.chips[i]
    if b then return b end
    b = ns.Widgets.Button(bar, "", function(self) self.clear() Tab:Rebuild() end)
    b:SetHeight(20)
    ns.Widgets.SetPicked(b, true)
    ns.Widgets.Tooltip(b, L["Remove this filter"])
    b.join = ns.Widgets.Label(bar, "", "GameFontDisable")
    bar.chips[i] = b
    return b
end

-- search and the segment do not go into a rule; while one is open they wait
local function paintViewControls()
    local tip = editing and L["Rules do not use search or this choice. Save or cancel the rule first."] or nil
    if editing then page.search:Disable() else page.search:Enable() end
    ns.Widgets.Tooltip(page.search, tip)
    for _, b in ipairs(page.show.buttons) do
        b:SetEnabled(not editing)
        ns.Widgets.Tooltip(b, tip)
    end
end

function Tab:RefreshFilterBar(shown, all)
    local bar = page.filterBar
    local tokens = ns.PetGridModel.Tokens(state)
    local rules = #rulesOf(set)
    page.rulesBtn:SetText(rules > 0 and format(L["Rules (%d)"], rules) or L["Rules"])
    ns.Widgets.FitButton(page.rulesBtn)
    paintViewControls()
    page.favorites:Paint()
    local narrowed = editing ~= nil or (ns.PetGridModel.IsNarrowed(state) and all > 0)
    bar:SetShown(narrowed)
    bar.bg:SetShown(editing ~= nil)
    if narrowed then
        bar.shown:SetText(editing and L["Editing rule"] or format(L["Showing %d of %d"], shown, all))
        for i, tok in ipairs(tokens) do
            local b = filterChip(i)
            b:SetText(tok.label .. " |TInterface\\Buttons\\UI-StopButton:12:12|t")
            ns.Widgets.FitButton(b)
            b.clear = tok.clear
            b:Show()
            b.join:SetText(i > 1 and ns.AutoRules.Join(tokens[i - 1], tok) or "")
            b.join:SetShown(i > 1)
        end
        for i = #tokens + 1, #bar.chips do bar.chips[i]:Hide() bar.chips[i].join:Hide() end
        bar.petsWord:SetShown(editing ~= nil)
        bar.addCondition:SetShown(editing ~= nil)
        bar.comeOut:SetShown(editing ~= nil)
        bar.weight:SetShown(editing ~= nil)
        bar.ruleCount:SetShown(editing ~= nil)
        bar.delete:SetShown(editing ~= nil and editing.index ~= nil)
        bar.cancel:SetShown(editing ~= nil)
        bar.save:SetShown(editing ~= nil)
        bar.clear:SetShown(not editing)
        bar.bulk:SetShown(not editing and shown > 0)
        bar.makeRule:SetShown(not editing and #tokens > 0)
        if editing then
            bar.weight:SetDefaultText(ns.Weights.Label(editing.weight))
            if bar.weight.GenerateMenu then bar.weight:GenerateMenu() end
            ns.Widgets.FitButton(bar.weight, 24)
            -- the rule's pets, and how many of them keep their own setting instead
            local byHand = 0
            for _, id in ipairs(shownIDs) do if set:HasManualWeight(id) then byHand = byHand + 1 end end
            local count = ns.Widgets.PetCount(shown)
            if byHand > 0 then count = count .. " · " .. format(L["%d by hand"], byHand) end
            bar.ruleCount:SetText(count)
        else
            bar.bulk:SetText(format(L["How often for %d shown"], shown))
            ns.Widgets.FitButton(bar.bulk)
        end
    end
    layoutToolbar()
end

ns.UI.Main:RegisterTab("pets", L["Pets"], function(p)
    page = p
    ns.UI.PetsTabPage = page
    -- search, what to show, the star, Filter and the count; placed by layoutToolbar
    page.toolbar = CreateFrame("Frame", nil, page)
    page.toolbar:SetPoint("TOPLEFT", 6, -4)
    page.toolbar:SetPoint("RIGHT", -6, 0)
    local search = ns.Widgets.Search(page, function(text) state.search = strlower(text) Tab:Rebuild() end)
    search:SetWidth(180)
    page.search = search

    -- what to show, on the surface instead of inside a menu
    page.show = ns.Widgets.Segmented(page, {
        { value = "all", label = ALL }, { value = "selected", label = L["In this set"] }, { value = "unselected", label = L["Left out"] },
    }, function() return state.show end, function(v) state.show = v Tab:Rebuild() end)

    page.favorites = CreateFrame("Button", nil, page)
    page.favorites:SetSize(22, 22)
    page.favorites:SetNormalTexture("Interface\\COMMON\\FavoritesIcon")
    page.favorites:SetHighlightTexture("Interface\\COMMON\\FavoritesIcon", "ADD")
    -- the star is the Favorites filter, so a rule can be for favorites too
    function page.favorites:Paint()
        self:GetNormalTexture():SetDesaturated(not state.filters.favorites)
        self:GetNormalTexture():SetAlpha(state.filters.favorites and 1 or 0.45)
    end
    page.favorites:SetScript("OnClick", function() toggle("favorites") end)
    page.favorites:Paint()
    ns.Widgets.Tooltip(page.favorites, L["Favorites only"])

    local filterBtn = CreateFrame("DropdownButton", nil, page, "WowStyle1FilterDropdownTemplate")
    filterBtn:SetupMenu(filterMenu)
    ns.Skin:Apply("Dropdown", filterBtn)
    page.filterBtn = filterBtn
    page.rulesBtn = ns.Widgets.Button(page, L["Rules"], function(self) MenuUtil.CreateContextMenu(self, rulesMenu) end)
    ns.Widgets.Tooltip(page.rulesBtn, L["Rules"], L["Rules say how often whole groups of pets come out, including pets you collect later. Filter the list and Make a rule, or pick a rule here to change it."])

    page.filterBar = CreateFrame("Frame", nil, page)
    local bar = page.filterBar
    bar:SetPoint("TOPLEFT", page.toolbar, "BOTTOMLEFT", -4, -LINE_GAP)
    bar:SetPoint("RIGHT", -6, 0)
    bar.chips = {}
    -- tinted while a rule is open, so the line reads as the rule and not as filters
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetPoint("TOPLEFT", -4, 4)
    bar.bg:SetPoint("BOTTOMRIGHT", 4, -4)
    local r, g, b = 1, 0.82, 0
    if ns.Skin:IsActive() then r, g, b = ns.Skin:Accent() end
    bar.bg:SetColorTexture(r, g, b, 0.12)
    bar.shown = ns.Widgets.Label(bar, "", "GameFontNormal")
    local function small(text, onClick)
        local btn = ns.Widgets.Button(bar, text, onClick)
        btn:SetHeight(20)
        return btn
    end
    bar.clear = small(L["Clear filters"], function()
        ns.PetGridModel.ClearFilters(state)
        search:SetText("")
        page.show:Refresh()
        Tab:Rebuild()
    end)
    bar.bulk = small("", function(self) MenuUtil.CreateContextMenu(self, function(_, root) weightLevelsMenu(root) end) end)
    bar.makeRule = small(L["Make a rule"], function() startEditing(nil, state.filters, newRuleWeight()) end)
    ns.Widgets.Tooltip(bar.makeRule, L["Make a rule"], L["These pets come out as often as you pick, from now on, including pets you collect later that match."])
    bar.petsWord = ns.Widgets.Label(bar, L["pets"], "GameFontDisable")
    bar.addCondition = small(L["+ Condition"], function(self)
        MenuUtil.CreateContextMenu(self, function(_, root) conditionItems(root, true) end)
    end)
    bar.comeOut = ns.Widgets.Label(bar, L["come out"], "GameFontDisable")
    bar.weight = ns.Widgets.Dropdown(bar, 120, function(_, root)
        for _, lvl in ipairs(ns.Weights.LEVELS) do
            root:CreateRadio(lvl.label, function() return editing and ns.Weights.Nearest(editing.weight) == lvl.value end,
                function() editing.weight = lvl.value Tab:Rebuild() end)
        end
    end)
    ns.Widgets.Tooltip(bar.weight, L["How often"])
    bar.ruleCount = ns.Widgets.Label(bar, "", "GameFontDisable")
    bar.delete = small(L["Delete rule"], deleteRule)
    bar.cancel = small(CANCEL, stopEditing)
    bar.save = small(L["Save rule"], saveRule)
    bar:Hide()

    page.count = ns.Widgets.Label(page, "", "GameFontDisable")
    page.count:SetJustifyH("RIGHT")

    local previewPanel = ns.UI.Preview:Attach(page)
    -- grid and preview share the row below the filter line; the preview owns the right edge
    previewPanel:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -contentTop())
    previewPanel:SetPoint("BOTTOMRIGHT", 0, 0)

    grid = CreateFrame("Frame", nil, page)
    grid:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -contentTop())
    grid:SetClipsChildren(true)
    grid:SetScript("OnSizeChanged", function(_, w) if page:IsVisible() then fitColumns(w) end end)
    page.grid = grid
    scrollBox = CreateFrame("Frame", nil, grid, "WowScrollBoxList")
    scrollBox:SetAllPoints()
    scrollBar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", grid, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", grid, "BOTTOMRIGHT", 4, 0)
    -- hidden text the tiles' heights are measured with
    measure = CreateFrame("Frame", nil, page)
    measure:Hide()
    measure.name = measure:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measure.sub = measure:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, data) return rowExtent(data) end)
    view:SetElementInitializer("Frame", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    ns.Skin:Apply("ScrollBar", scrollBar)

    page.emptyBanner = CreateFrame("Frame", nil, page)
    page.emptyBanner:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -contentTop())
    page.emptyBanner:SetPoint("RIGHT", grid, "RIGHT", 0, 0)
    page.emptyBanner:SetHeight(BANNER_H)
    page.emptyBanner.bg = page.emptyBanner:CreateTexture(nil, "BACKGROUND")
    page.emptyBanner.bg:SetAllPoints()
    page.emptyBanner.bg:SetColorTexture(1, 0.6, 0.2, 0.15)
    page.emptyBanner.icon = page.emptyBanner:CreateTexture(nil, "ARTWORK")
    page.emptyBanner.icon:SetSize(16, 16)
    page.emptyBanner.icon:SetPoint("LEFT", 8, 0)
    page.emptyBanner.icon:SetTexture("Interface\\COMMON\\Indicator-Yellow")
    page.emptyBanner.all = ns.Widgets.Button(page.emptyBanner, L["Include all pets"], function()
        set:SetDefaultWeight(ns.Weights.NORMAL)
    end)
    page.emptyBanner.all:SetPoint("RIGHT", -4, 0)
    page.emptyBanner.text = ns.Widgets.Label(page.emptyBanner, L["No pets in this set yet. Tick the ones you want, or include them all."], "GameFontHighlight")
    page.emptyBanner.text:SetPoint("LEFT", page.emptyBanner.icon, "RIGHT", 6, 0)
    page.emptyBanner.text:SetPoint("RIGHT", page.emptyBanner.all, "LEFT", -8, 0)
    page.emptyBanner.text:SetWordWrap(false)
    page.emptyBanner:Hide()

    emptyText = ns.Widgets.Label(grid, "", "GameFontDisableLarge")
    page.emptyText = emptyText
    emptyText:SetPoint("CENTER")
    page.openJournal = ns.Widgets.Button(grid, L["Open Pet Journal"], function() ToggleCollectionsJournal(2) end)
    page.openJournal:SetPoint("TOP", emptyText, "BOTTOM", 0, -10)
    page.openJournal:Hide()

    page:SetScript("OnShow", layout)
    -- another tab or the window closing puts an open rule away (asking first when it changed)
    page:SetScript("OnHide", function() leaveEditing() end)
    return Tab
end, 1)

local rebuildSoon = ns.Debounce(0.05, function() Tab:Rebuild() end)
ns:RegisterCallback(Tab, "PetsChanged", rebuildSoon)
ns:RegisterCallback(Tab, "SetsChanged", function(_, name) if set and (not name or name == set.name) then rebuildSoon() end end)
-- the window being dragged to a new size: the preview may come or go and the toolbar
-- finds its lines again; the grid's own size handler fits the tiles
ns:RegisterCallback(Tab, "WindowResized", function()
    if page and page:IsVisible() then
        placeGrid()
        layoutToolbar()
        Tab:PlaceBelowFilters()
    end
end)
