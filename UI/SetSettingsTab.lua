local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
local Tab = {}
local page, set
local MAX_W = 680          -- sections stop growing here, so lines stay easy to read
local SECTION_W = 560      -- before the page has a width of its own
local ROW_GAP, LABEL_GAP = 10, 16

-- Every section is a list of rows: a label in the first column and its controls in the
-- second, with an optional hint under the controls; or controls across the whole width.
-- The label column is as wide as the longest label, rows are as tall as what they hold,
-- and controls that do not fit beside their label go under it.

-- a titled block with a thin rule under the title; its rows are laid out by layout()
local function section(title, danger)
    local f = CreateFrame("Frame", nil, page.body)
    f:SetWidth(SECTION_W)
    f.rows = {}
    f.title = ns.Widgets.Label(f, title, "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 4, 0)
    if danger then f.title:SetTextColor(1, 0.35, 0.3) end
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.rule:SetHeight(1)
    if danger then f.rule:SetColorTexture(1, 0.35, 0.3, 0.4) else f.rule:SetColorTexture(1, 1, 1, 0.15) end
    return f
end

local function help(parent, text)
    local fs = ns.Widgets.Label(parent, text, "GameFontDisableSmall")
    fs:SetWordWrap(true)
    return fs
end

-- row = { label = fs or nil, items = { controls for ns.Widgets.Flow }, help = fs or nil,
--         check = a checkbox whose own text wraps, indent = room before the hint }
local function addRow(sec, row)
    row.box = CreateFrame("Frame", nil, sec)
    for _, item in ipairs(row.items) do (item.frame or item):SetParent(row.box) end
    if row.label then row.label:SetWordWrap(true) end
    sec.rows[#sec.rows + 1] = row
    return row
end

-- a dropdown as wide as its longest choice
local function fitDropdown(dd, labels) ns.Widgets.FitDropdown(dd, labels, 120) end

local function textHeight(fs) return math.ceil(tonumber(fs:GetStringHeight()) or 0) end

local function naturalWidth(items)
    local w = 0
    for i, item in ipairs(items) do
        local f = item.frame or item
        if f:IsShown() then
            local fw = f.GetObjectType and f:GetObjectType() == "FontString" and ns.Widgets.TextWidth(f) or (tonumber(f:GetWidth()) or 0)
            w = w + fw + (i > 1 and 8 or 0)
        end
    end
    return w
end

local function layoutSection(sec, width, labelCol)
    sec:SetWidth(width)
    sec.rule:SetWidth(width - 4)
    local y = textHeight(sec.title) + 4 + 1 + 10
    for _, row in ipairs(sec.rows) do
        local x, w = 0, width
        local labelH = 0
        if row.label then
            row.label:SetWidth(labelCol - LABEL_GAP)
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", sec, "TOPLEFT", 0, -(y + 4))
            labelH = textHeight(row.label) + 4
            if naturalWidth(row.items) <= width - labelCol then
                x, w = labelCol, width - labelCol
            else
                y = y + labelH + 4                   -- too wide beside the label: under it
                labelH = 0
            end
        end
        if row.check then
            local text = row.check.text
            text:SetWidth(0)
            local tw = math.min(ns.Widgets.TextWidth(text), w - 32)
            text:SetWidth(tw)
            text:SetWordWrap(true)
            row.check:SetWidth(24)
        end
        row.box:ClearAllPoints()
        row.box:SetPoint("TOPLEFT", sec, "TOPLEFT", x, -y)
        row.box:SetWidth(w)
        local h = ns.Widgets.Flow(row.box, row.items, { width = w })
        if row.check then h = math.max(h, textHeight(row.check.text)) end
        if row.help and row.help:IsShown() then
            local indent = row.indent or 0
            row.help:SetWidth(w - indent)
            row.help:ClearAllPoints()
            row.help:SetPoint("TOPLEFT", row.box, "TOPLEFT", indent, -(h + 4))
            h = h + 4 + textHeight(row.help)
        end
        y = y + math.max(h, labelH) + ROW_GAP
    end
    sec:SetHeight(y - ROW_GAP + 4)
end

-- the label column fits the longest label of every section, but never takes more than
-- two fifths of the width: a longer label wraps
local function layout()
    local bodyW = tonumber(page.body:GetWidth()) or 0
    local width = bodyW > 40 and math.min(MAX_W, bodyW - 16) or SECTION_W
    local longest = 0
    for _, sec in ipairs(page.sections) do
        for _, row in ipairs(sec.rows) do
            if row.label then
                row.label:SetWidth(0)
                longest = math.max(longest, ns.Widgets.TextWidth(row.label))
            end
        end
    end
    local labelCol = math.min(math.ceil(longest) + LABEL_GAP, math.floor(width * 0.4))
    for _, sec in ipairs(page.sections) do layoutSection(sec, width, labelCol) end
end

-- stack the sections that apply to this set from the top; the scrolled body is as
-- tall as they are, so a short window scrolls instead of spilling below its edge
local function stack()
    local prev, height = nil, 10
    for _, s in ipairs(page.sections) do
        s:ClearAllPoints()
        if s:IsShown() then
            if prev then s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -18) else s:SetPoint("TOPLEFT", 8, -10) end
            height = height + (prev and 18 or 0) + s:GetHeight()
            prev = s
        end
    end
    page.body:SetHeight(height + 10)
end

function Tab:Refresh(newSet)
    set = newSet
    local default = set:IsDefault()
    page.defaultNote:SetShown(default)
    page.behaviour:SetShown(not default)
    page.nameSection:SetShown(not default)
    page.danger:SetShown(not default)
    local paused = set:IsPaused()
    page.pauseState:SetText(paused and ("|cff808080" .. ns.UI.SetHeader.PauseText(set) .. "|r") or ("|cff4cd964" .. L["Running"] .. "|r"))
    page.pauseButton:SetText(paused and L["Resume"] or L["Pause"])
    local rank, n = set:GetRank()
    page.order:SetText(format(L["%d of %d"], rank, n - 1))
    page.up:SetEnabled(rank > 1)
    page.down:SetEnabled(rank < n - 1)
    page.onActivate:GenerateMenu()
    page.switch:GenerateMenu()
    page.announce:GenerateMenu()
    page.noPet:SetChecked(set:IsNoPet())
    page.defaultWeight:GenerateMenu()
    local rules = ns.UI.SetHeader.RulesText(set)
    page.rules:SetText(rules ~= "" and rules or ("|cff808080" .. L["None"] .. "|r"))
    page.name:SetText(set.name)
    layout()
    stack()
end

ns.UI.Main:RegisterTab("settings", L["Set settings"], function(p)
    page = p
    ns.UI.SetSettingsPage = page
    page.sections = {}
    local scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", -24, 2)
    page.body = CreateFrame("Frame", nil, scroll)
    page.body:SetSize(10, 10)
    scroll:SetScrollChild(page.body)
    scroll:SetScript("OnSizeChanged", function(_, w)
        page.body:SetWidth(w)
        if set then layout() stack() end
    end)
    ns.Skin:Apply("ScrollBar", scroll.ScrollBar)
    page.scroll = scroll

    -- the default set: what it is, instead of the controls it does not have
    page.defaultNote = section(L["About this set"])
    local note = ns.Widgets.Label(page.defaultNote, L["The default set is used whenever no other set is active. It cannot be renamed, disabled or deleted."], "GameFontHighlight")
    addRow(page.defaultNote, { items = { note } })
    tinsert(page.sections, page.defaultNote)

    -- when and how the set is used
    local b = section(L["Behaviour"])
    page.behaviour = b
    -- running or paused, with the pause choices one click away
    page.pauseState = ns.Widgets.Label(b, "", "GameFontHighlight")
    page.pauseButton = ns.Widgets.Button(b, L["Pause"], function(self)
        if set:IsPaused() then set:Resume() return end
        MenuUtil.CreateContextMenu(self, function(_, root) ns.UI.SetList.PauseMenu(root, set) end)
    end)
    addRow(b, { label = ns.Widgets.Label(b, L["State"]), items = { page.pauseState, page.pauseButton } })
    -- place in the list: the first set that fits is used
    page.order = ns.Widgets.Label(b, "", "GameFontHighlight")
    page.up = ns.Widgets.Button(b, L["Move up"], function() ns.Sets:Move(set, -1) end)
    page.down = ns.Widgets.Button(b, L["Move down"], function() ns.Sets:Move(set, 1) end)
    addRow(b, { label = ns.Widgets.Label(b, L["Order"]), items = { page.order, page.up, page.down },
        help = help(b, L["When several sets fit, the one higher in the list is used. The Default set is always last."]) })
    local function radios(root, items, get, setter)
        for _, it in ipairs(items) do
            root:CreateRadio(it[2], function() return set and get() == it[1] end, function() setter(it[1]) end)
        end
    end
    local function labels(items) local out = {} for i, it in ipairs(items) do out[i] = it[2] end return out end
    local starts = { { "keep", L["Keep the pet that is out"] }, { "fits", L["New pet, unless the one out fits"] },
        { "new", L["Always a new pet"] } }
    page.onActivate = ns.Widgets.Dropdown(b, 260, function(_, root)
        radios(root, starts, function() return set:GetOnActivate() end, function(v) set:SetOnActivate(v) end)
    end)
    fitDropdown(page.onActivate, labels(starts))
    addRow(b, { label = ns.Widgets.Label(b, L["When this set starts"]), items = { page.onActivate } })
    local switches = { { false, L["Like the settings"] } }
    for _, m in ipairs({ 5, 10, 15, 30, 60 }) do switches[#switches + 1] = { m, format(L["%d minutes"], m) } end
    page.switch = ns.Widgets.Dropdown(b, 260, function(_, root)
        radios(root, switches, function() return set.settings.switchMinutes or false end, function(v) set:SetSwitchMinutes(v or nil) end)
    end)
    fitDropdown(page.switch, labels(switches))
    addRow(b, { label = ns.Widgets.Label(b, L["Switch pet every"]), items = { page.switch } })
    local announces = { { false, L["Like the settings"] }, { "on", L["Always"] }, { "off", L["Never"] } }
    page.announce = ns.Widgets.Dropdown(b, 260, function(_, root)
        radios(root, announces, function() return set.settings.announce or false end, function(v) set:SetAnnounce(v or nil) end)
    end)
    fitDropdown(page.announce, labels(announces))
    addRow(b, { label = ns.Widgets.Label(b, L["Chat message on summon"]), items = { page.announce } })
    page.noPet = ns.Widgets.Checkbox(b, L["No pet while this set is used"],
        function() return set and set:IsNoPet() end, function(v) set:SetNoPet(v) end)
    addRow(b, { items = { page.noPet }, check = page.noPet, indent = 28,
        help = help(b, L["Dismisses your pet instead of summoning one, e.g. for raids or arenas."]) })
    tinsert(page.sections, b)

    -- which pets and how often, for pets nobody set by hand
    local pets = section(L["Pets"])
    page.petsSection = pets
    local dwLabel = ns.Widgets.Label(pets, L["Other pets:"])
    page.dwLabel = dwLabel
    page.defaultWeight = ns.Widgets.Dropdown(pets, 180, function(owner, root)
        for _, lvl in ipairs(ns.Weights.LEVELS) do
            root:CreateRadio(lvl.label, function() return set and ns.Weights.Nearest(set.settings.defaultValue) == lvl.value end,
                function() set:SetDefaultWeight(lvl.value) end)
        end
    end)
    local levelLabels = {}
    for i, lvl in ipairs(ns.Weights.LEVELS) do levelLabels[i] = lvl.label end
    fitDropdown(page.defaultWeight, levelLabels)
    addRow(pets, { label = dwLabel, items = { page.defaultWeight },
        help = help(pets, L["Pets no rule picks and you have not set by hand, new pets you collect included. \"Never\" means only the pets you tick or a rule picks are used."]) })
    -- the pet rules live on the Pets tab; say what they are and lead there
    page.rules = ns.Widgets.Label(pets, "", "GameFontHighlight")
    page.editRules = ns.Widgets.Button(pets, L["Edit rules"], function() ns.UI.Main:SelectTab("pets") end)
    addRow(pets, { label = ns.Widgets.Label(pets, L["Pet rules"]), items = { page.rules, page.editRules } })
    page.reset = ns.Widgets.Button(pets, L["Undo all by hand"], function()
        StaticPopup_Show("PETCALL_CONFIRM", L["Give every pet you set by hand back to the rules and to Other pets?"], nil,
            { onAccept = function() set:ClearPetWeights() end })
    end)
    page.export = ns.Widgets.Button(pets, L["Export"], function() if ns.UI.Share then ns.UI.Share:ShowExport(set.name) end end)
    ns.Widgets.Tooltip(page.export, L["Export"], L["Copy this set as text to share it or keep a backup."])
    addRow(pets, { items = { page.reset, page.export } })
    tinsert(page.sections, pets)

    local n = section(L["Name"])
    page.nameSection = n
    page.name = CreateFrame("EditBox", nil, n, "InputBoxTemplate")
    page.name:SetSize(200, 20)
    page.name:SetAutoFocus(false)
    ns.Skin:Apply("EditBox", page.name)
    local rename = ns.Widgets.Button(n, L["Rename"], function()
        local ok, err = set:Rename(page.name:GetText())
        if not ok then UIErrorsFrame:AddMessage(err, 1, 0.3, 0.3) ns.Widgets.ErrorSound() end
        page.name:ClearFocus()
    end)
    page.duplicate = ns.Widgets.Button(n, L["Duplicate"], function()
        local copy = ns.Sets:Duplicate(set)
        if copy then ns.UI.Main:SelectSet(copy.name) ns.UI.Main:SelectTab("settings") end
    end)
    page.name:SetScript("OnEnterPressed", function() rename:Click() end)
    addRow(n, { items = { page.name, rename, page.duplicate } })
    tinsert(page.sections, n)

    -- kept apart and last so it is never clicked on the way to something else
    local d = section(L["Danger zone"], true)
    page.danger = d
    page.delete = ns.Widgets.Button(d, L["Delete set"], function()
        StaticPopup_Show("PETCALL_CONFIRM", format(L["Delete \"%s\"? This cannot be undone."], set.name), nil,
            { onAccept = function() set:Delete() end })
    end)
    page.delete:GetFontString():SetTextColor(1, 0.35, 0.3)
    addRow(d, { items = { page.delete, help(d, L["Removes the set with its conditions, rules and pets."]) } })
    tinsert(page.sections, d)
    return Tab
end, 3)

ns:RegisterCallback(Tab, "SetsChanged", function() if page and page:IsVisible() and set and not set.deleted then Tab:Refresh(set) end end)
