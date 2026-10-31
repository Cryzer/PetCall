local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local B = {}
ns.UI.Behaviour = B

-- "How PetCall acts": what PetCall does by itself, everywhere. It takes the place of the
-- set header, tabs and pages, as the template page does, and goes when a set is picked.
-- From the top: three sentences, Automatic, Exceptions (one row each, coloured by what
-- it does), Pet-like items (folded) and Use recommended settings.

local MAX_W, SECTION_GAP, ROW_GAP, LABEL_GAP = 680, 18, 10, 16
local BAR_W = 3
local SECONDS = { 1, 2, 3, 5, 10, 15, 20, 30 }
local COLOR = { away = { 1, 0.35, 0.3 }, alone = { 1, 0.7, 0.25 } }
local MUTED = { 0.6, 0.6, 0.6 }

local page, scroll, body, editor
local rows, order = {}, {}       -- exception id -> row; the rows in the order shown
local autoRows = {}                  -- { label, box, items } of Automatic
local expanded, focus                -- the exception whose conditions are open; the one asked for
local itemsOpen = false
B._rows = rows

local function textHeight(fs) return math.ceil(tonumber(fs:GetStringHeight()) or 0) end

local function radios(root, items, get, set)
    for _, it in ipairs(items) do
        root:CreateRadio(it[2], function() return get() == it[1] end, function() set(it[1]) end)
    end
end

local function labels(items)
    local out = {}
    for i, it in ipairs(items) do out[i] = it[2] end
    return out
end

-- a check box with its label as one piece of a row: the box alone is only 24 px wide
local function boxed(parent, cb)
    local holder = CreateFrame("Frame", nil, parent)
    cb:SetParent(holder)
    cb:ClearAllPoints()
    cb:SetPoint("LEFT", holder, "LEFT", 0, 0)
    holder:SetSize(24 + 4 + ns.Widgets.TextWidth(cb.text), 24)
    holder.check = cb
    return holder
end

local function section(title)
    local f = {}
    f.title = ns.Widgets.Label(body, title, "GameFontNormal")
    f.rule = body:CreateTexture(nil, "ARTWORK")
    f.rule:SetHeight(1)
    f.rule:SetColorTexture(1, 1, 1, 0.15)
    return f
end

local function placeSection(sec, y, width)
    sec.title:ClearAllPoints()
    sec.title:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
    sec.title:SetWidth(width)
    y = y + textHeight(sec.title) + 4
    sec.rule:ClearAllPoints()
    sec.rule:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
    sec.rule:SetWidth(width)
    return y + 1 + 10
end

--
-- Automatic
--

local function bringItems()
    return { { false, L["When I stand still"] }, { true, L["Only after a loading screen"] } }
end

local function secondsItems()
    local cur = ns.db.profile.waitTimer
    local items, found = {}, false
    for _, v in ipairs(SECONDS) do
        items[#items + 1] = { v, format(L["%s s"], format("%g", v)) }
        if v == cur then found = true end
    end
    -- a value set elsewhere (the old slider) is shown as it is
    if not found and cur then table.insert(items, 1, { cur, format(L["%s s"], format("%g", cur)) }) end
    return items
end

local function setProfile(key, v)
    ns:SetProfileValue(key, v)
    ns.Ready:UpdateChecks()
end

local function buildAutomatic()
    page.automatic = section(L["Automatic"])
    page.auto = ns.Widgets.Checkbox(body, L["On"], function() return ns:IsAutoSummon() end, function(v) ns:SetAutoSummon(v) end)
    page.autoBox = boxed(body, page.auto)
    page.paused = ns.Widgets.Label(body, "|cffffb040" .. L["Paused until you change zone"] .. "|r", "GameFontHighlight")
    page.resume = ns.Widgets.Button(body, L["Resume"], function() ns:ResumeAuto() end)

    local bring = bringItems()
    page.bring = ns.Widgets.Dropdown(body, 160, function(_, root)
        radios(root, bring, function() return ns.db.profile.nearPEWOnly end, function(v) setProfile("nearPEWOnly", v) end)
    end)
    ns.Widgets.FitDropdown(page.bring, labels(bring), 120)
    page.seconds = ns.Widgets.Dropdown(body, 80, function(_, root)
        radios(root, secondsItems(), function() return ns.db.profile.waitTimer end, function(v) setProfile("waitTimer", v) end)
    end)
    ns.Widgets.FitDropdown(page.seconds, labels(secondsItems()), 60)
    ns.Widgets.Tooltip(page.seconds, L["When I stand still"], L["Seconds of standing still before a pet comes out."])

    local yesNo = { { true, L["Yes"] }, { false, L["No"] } }
    page.newMap = ns.Widgets.Dropdown(body, 100, function(_, root)
        radios(root, yesNo, function() return ns.db.profile.switchOnNewMap end, function(v) setProfile("switchOnNewMap", v) end)
    end)
    ns.Widgets.FitDropdown(page.newMap, labels(yesNo), 80)
    local battle = { { true, L["Bring back my pet"] }, { false, L["Keep the game's pick"] } }
    page.battle = ns.Widgets.Dropdown(body, 160, function(_, root)
        radios(root, battle, function() return ns.db.profile.overrideSetLoadout end, function(v) setProfile("overrideSetLoadout", v) end)
    end)
    ns.Widgets.FitDropdown(page.battle, labels(battle), 120)

    local function add(label, items)
        local box = CreateFrame("Frame", nil, body)
        for _, item in ipairs(items) do item:SetParent(box) end
        autoRows[#autoRows + 1] = { label = ns.Widgets.Label(body, label), box = box, items = items }
    end
    add(L["Auto-summon"], { page.autoBox, page.paused, page.resume })
    add(L["Bring out a pet"], { page.bring, page.seconds })
    add(L["New pet on a new map"], { page.newMap })
    add(L["After a pet battle"], { page.battle })
end

--
-- Exceptions
--

local function codeDisabled(list)
    for _, e in ipairs(list) do
        if e.disabledByImport or (e.items and codeDisabled(e.items)) then return true end
    end
    return false
end

local refreshNow, refresh

local function newRow(exc)
    local id = exc.id
    local r = { id = id, exc = exc }
    r.frame = CreateFrame("Frame", nil, body)
    r.bg = r.frame:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bar = r.frame:CreateTexture(nil, "ARTWORK")
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMLEFT")
    r.bar:SetWidth(BAR_W)
    r.name = ns.Widgets.Label(r.frame, "", "GameFontNormal")
    r.from = ns.Widgets.Label(r.frame, "", "GameFontDisableSmall")
    r.warn = ns.Widgets.Label(r.frame, "|cffff4040" .. L["Imported code is disabled until you review it."] .. "|r", "GameFontHighlightSmall")
    r.ctl = CreateFrame("Frame", nil, r.frame)
    local labelsAll = {}
    for _, c in ipairs({ false, "alone", "away" }) do labelsAll[#labelsAll + 1] = ns.Exceptions.CHOICE_LABEL[c] end
    r.choice = ns.Widgets.Dropdown(r.ctl, 160, function(_, root)
        for _, c in ipairs(r.exc:Choices()) do
            root:CreateRadio(ns.Exceptions.CHOICE_LABEL[c], function() return r.exc:GetChoice() == c end,
                function() r.exc:SetChoice(c) refreshNow() end)
        end
    end)
    ns.Widgets.FitDropdown(r.choice, labelsAll, 120)
    r.solo = ns.Widgets.Checkbox(r.ctl, L["Also when solo"], function() return r.exc:GetSolo() end,
        function(v) r.exc:SetSolo(v) end)
    ns.Widgets.Tooltip(r.solo, L["Also when solo"], L["Cleared: only while you are in a party or raid group."])
    r.soloBox = boxed(r.ctl, r.solo)
    r.toggle = ns.Widgets.Button(r.ctl, L["Conditions"], function()
        expanded = expanded ~= r.id and r.id or nil
        refreshNow()
    end)
    -- own exceptions only, always at the right end of the row
    r.delete = ns.Widgets.Button(r.ctl, DELETE, function()
        StaticPopup_Show("PETCALL_CONFIRM", format(L["Delete \"%s\"? This cannot be undone."], r.exc:DisplayName()), nil,
            { onAccept = function() r.exc:Delete() expanded = nil refreshNow() end })
    end)
    r.delete:GetFontString():SetTextColor(1, 0.35, 0.3)
    r.delete:Hide()
    r.deleteItem = { frame = r.delete, right = true }
    r.editorHost = page.editorHost
    rows[id] = r
    return r
end

local function paintRow(r)
    local exc = r.exc
    local choice = exc:GetChoice()
    local c = COLOR[choice]
    r.bar:SetShown(c ~= nil)
    r.bg:SetShown(c ~= nil)
    if c then
        r.bar:SetColorTexture(c[1], c[2], c[3], 0.9)
        r.bg:SetColorTexture(c[1], c[2], c[3], focus == r.id and 0.16 or 0.07)
        r.name:SetTextColor(c[1], c[2], c[3])
    else
        r.name:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    end
    r.name:SetText(exc:DisplayName())
    local from = not exc.builtin and exc.entry.from
    r.from:SetText(from and format(L["(was your set %s)"], from) or "")
    r.from:SetShown(from and true or false)
    r.warn:SetShown(not exc.builtin and codeDisabled(exc.trigger))
    local solo = exc:HasSolo() and choice ~= false
    r.soloBox:SetShown(solo)
    r.solo:SetShown(solo)
    r.solo:SetChecked(exc:GetSolo() and true or false)
    r.choice:GenerateMenu()
    ns.Widgets.SetPicked(r.toggle, expanded == r.id)
end

-- the exceptions in order; rows of exceptions that are gone are put away
local function syncRows()
    wipe(order)
    local seen = {}
    for _, exc in ipairs(ns.Exceptions:List()) do
        local r = rows[exc.id] or newRow(exc)
        r.exc = exc
        seen[exc.id] = true
        order[#order + 1] = r
    end
    for id, r in pairs(rows) do
        if not seen[id] then
            r.frame:Hide()
            if expanded == id then expanded = nil end
        end
    end
end

local function buildExceptions()
    page.exceptions = section(L["Exceptions"])
    page.editorHost = CreateFrame("Frame", nil, body)
    page.editorHost:Hide()
    -- the editor redraws itself after a change made in it: the page makes room again
    editor = ns.UI.ConditionEditor.New(page.editorHost, { whole = true, onHeight = function() refresh() end })
    page.add = ns.Widgets.Button(body, L["+ Add exception"], function()
        local exc = ns.Exceptions:Add({}, "away")
        expanded, focus = exc.id, exc.id
        refreshNow()
        B:ScrollTo(exc.id)
    end)
end

--
-- Pet-like items
--

local function buildItems()
    page.items = {}
    page.itemsToggle = CreateFrame("Button", nil, body)
    page.itemsToggle.label = ns.Widgets.Label(page.itemsToggle, "", "GameFontNormal")
    page.itemsToggle.label:SetPoint("LEFT")
    page.itemsToggle:SetScript("OnClick", function() itemsOpen = not itemsOpen refreshNow() end)
    page.itemsRule = body:CreateTexture(nil, "ARTWORK")
    page.itemsRule:SetHeight(1)
    page.itemsRule:SetColorTexture(1, 1, 1, 0.15)
    page.itemsEnable = boxed(body, ns.Widgets.Checkbox(body, ENABLE, function() return ns.SpecialItems:IsEnabled() end,
        function(v) ns.SpecialItems:SetEnabled(v) end))
    page.itemsHelp = ns.Widgets.Label(body, L["EXPLAIN_SPECIAL_ITEMS"], "GameFontDisableSmall")
    for _, item in ipairs(ns.SpecialItems:List()) do
        local key = item.key
        page.items[#page.items + 1] = boxed(body, ns.Widgets.Checkbox(body, item.name,
            function() return ns.SpecialItems.db.profile.items[key] and true or false end,
            function(v) ns.SpecialItems:SetItemEnabled(key, v) end))
    end
end

--
-- Layout
--

local function layout()
    local bodyW = tonumber(scroll:GetWidth()) or 0
    local width = bodyW > 40 and math.min(MAX_W, bodyW - 16) or 560
    body:SetWidth(math.max(10, bodyW))
    local y = 10
    page.intro:SetWidth(width)
    page.intro:ClearAllPoints()
    page.intro:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
    y = y + textHeight(page.intro) + SECTION_GAP

    -- one label column for Automatic and the exceptions, never more than two fifths
    local longest = 0
    for _, row in ipairs(autoRows) do
        row.label:SetWidth(0)
        longest = math.max(longest, ns.Widgets.TextWidth(row.label))
    end
    for _, r in ipairs(order) do
        r.name:SetWidth(0)
        longest = math.max(longest, ns.Widgets.TextWidth(r.name) + BAR_W + 6)
    end
    local labelCol = math.min(math.ceil(longest) + LABEL_GAP, math.floor(width * 0.4))

    y = placeSection(page.automatic, y, width)
    for _, row in ipairs(autoRows) do
        local x, w = labelCol, width - labelCol
        row.label:SetWidth(labelCol - LABEL_GAP)
        row.label:ClearAllPoints()
        row.label:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -(y + 4))
        local labelH = textHeight(row.label) + 4
        local need = 0
        for i, item in ipairs(row.items) do
            if item:IsShown() then
                local iw = item.GetObjectType and item:GetObjectType() == "FontString" and ns.Widgets.TextWidth(item) or (tonumber(item:GetWidth()) or 0)
                need = need + iw + (i > 1 and 8 or 0)
            end
        end
        if need > w then           -- too wide beside the label: under it
            x, w = 0, width
            y = y + labelH + 4
            labelH = 0
        end
        row.box:ClearAllPoints()
        row.box:SetPoint("TOPLEFT", body, "TOPLEFT", 8 + x, -y)
        row.box:SetWidth(w)
        local h = ns.Widgets.Flow(row.box, row.items, { width = w })
        y = y + math.max(h, labelH) + ROW_GAP
    end
    y = y - ROW_GAP + SECTION_GAP

    y = placeSection(page.exceptions, y, width)
    -- the host hides only when nothing is open: hiding it closes the mount picker
    local open = expanded and rows[expanded]
    page.editorHost:SetShown(open and true or false)
    if not open then page.editorHost.target = nil end
    for _, r in ipairs(order) do
        local f = r.frame
        f:Show()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
        f:SetWidth(width)
        local nameW = labelCol - LABEL_GAP - BAR_W - 6
        r.name:SetWidth(nameW)
        r.name:ClearAllPoints()
        r.name:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_W + 6, -8)
        local left = 8 + textHeight(r.name)
        if r.from:IsShown() then
            r.from:SetWidth(nameW)
            r.from:ClearAllPoints()
            r.from:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
            left = left + 2 + textHeight(r.from)
        end
        local cw = width - labelCol - 4
        r.ctl:ClearAllPoints()
        r.ctl:SetPoint("TOPLEFT", f, "TOPLEFT", labelCol, -4)
        r.ctl:SetWidth(cw)
        r.delete:SetShown(not r.exc.builtin)
        local h = 4 + ns.Widgets.Flow(r.ctl, { r.choice, r.soloBox, r.toggle, r.deleteItem }, { width = cw })
        h = math.max(h, left) + 4
        if r.warn:IsShown() then
            r.warn:SetWidth(width - BAR_W - 12)
            r.warn:ClearAllPoints()
            r.warn:SetPoint("TOPLEFT", f, "TOPLEFT", BAR_W + 6, -h)
            h = h + textHeight(r.warn) + 6
        end
        f:SetHeight(h)
        r.top = y
        y = y + h + 4
        if expanded == r.id then
            local host = page.editorHost
            host:ClearAllPoints()
            -- the conditions take the whole width: their rows do not wrap
            host:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
            host:SetWidth(math.max(width, bodyW))
            if host.target ~= r.exc then
                host.target = r.exc
                editor:Refresh(r.exc)
                editor:SetReadOnly(r.exc.builtin)
            end
            local eh = math.max(60, editor:GetHeight() + 4)
            host:SetHeight(eh)
            y = y + eh + 4
        end
    end
    page.add:ClearAllPoints()
    page.add:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -(y + 4))
    y = y + 4 + 22 + SECTION_GAP

    -- Pet-like items, folded until opened
    local t = page.itemsToggle
    t.label:SetText((itemsOpen and "- " or "+ ") .. L["Pet-like items"])
    t.label:SetWidth(math.min(width, ns.Widgets.TextWidth(t.label)))
    t:SetSize(t.label:GetWidth(), math.max(16, textHeight(t.label)))
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
    y = y + t:GetHeight() + 4
    page.itemsRule:ClearAllPoints()
    page.itemsRule:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
    page.itemsRule:SetWidth(width)
    y = y + 1 + 8
    page.itemsEnable:SetShown(itemsOpen)
    page.itemsHelp:SetShown(itemsOpen)
    for _, item in ipairs(page.items) do item:SetShown(itemsOpen) end
    if itemsOpen then
        page.itemsEnable:ClearAllPoints()
        page.itemsEnable:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
        y = y + 26
        page.itemsHelp:SetWidth(width)
        page.itemsHelp:ClearAllPoints()
        page.itemsHelp:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
        y = y + textHeight(page.itemsHelp) + 6
        -- a name longer than the page wraps under itself
        for _, item in ipairs(page.items) do
            local label = item.check.text
            label:SetWordWrap(true)
            label:SetJustifyH("LEFT")
            label:SetWidth(math.max(40, math.min(width - 16 - 28, ns.Widgets.TextWidth(label))))
            local h = math.max(24, textHeight(label) + 6)
            item:SetSize(28 + label:GetWidth(), h)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", body, "TOPLEFT", 24, -y)
            y = y + h + 2
        end
    end
    y = y + SECTION_GAP - 8

    page.foot:ClearAllPoints()
    page.foot:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
    page.foot:SetWidth(width)
    y = y + ns.Widgets.Flow(page.foot, { page.recommend, page.undo }, { width = width }) + 12
    body:SetHeight(y)
end

function refreshNow()
    if not page or not page:IsShown() then return end
    local state = ns:GetAutoState()
    page.auto:SetChecked(state ~= "off")
    page.paused:SetShown(state == "paused")
    page.resume:SetShown(state == "paused")
    page.seconds:SetShown(not ns.db.profile.nearPEWOnly)
    ns.Widgets.FitDropdown(page.seconds, labels(secondsItems()), 60)
    for _, dd in ipairs({ page.bring, page.seconds, page.newMap, page.battle }) do dd:GenerateMenu() end
    page.undo:SetShown(ns.Recommended:CanUndo())
    syncRows()
    for _, r in ipairs(order) do paintRow(r) end
    layout()
end

local function build()
    local f = ns.UI.Main:GetFrame()
    page = CreateFrame("Frame", nil, f.Inset)
    -- the area of the header, the tab row and the pages, which hide while it is open
    page:SetPoint("TOPLEFT", f.header, "TOPLEFT", 0, 0)
    page:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", 0, 0)
    page:Hide()
    page.title = ns.Widgets.Label(page, L["How PetCall acts"], "GameFontNormalHuge")
    page.title:SetPoint("TOPLEFT", 10, -8)
    page.title:SetPoint("RIGHT", -10, 0)
    scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -38)
    scroll:SetPoint("BOTTOMRIGHT", -24, 2)
    body = CreateFrame("Frame", nil, scroll)
    body:SetSize(10, 10)
    scroll:SetScrollChild(body)
    scroll:SetScript("OnSizeChanged", function() if page:IsShown() then layout() end end)
    ns.Skin:Apply("ScrollBar", scroll.ScrollBar)
    page.scroll, page.body = scroll, body

    page.intro = ns.Widgets.Label(body, L["PetCall brings out a pet from the first set that fits. Exceptions keep it away in some places. Your own key presses and clicks always work."], "GameFontHighlight")
    buildAutomatic()
    buildExceptions()
    buildItems()
    page.foot = CreateFrame("Frame", nil, body)
    page.recommend = ns.Widgets.Button(page.foot, L["Use recommended settings"], function()
        ns.UI.Comparison:Open(page, function() refreshNow() end)
    end)
    page.undo = ns.Widgets.Button(page.foot, L["Undo"], function() ns.Recommended:Undo() end)
    ns.Widgets.Tooltip(page.undo, L["Undo"], L["Put back the settings you had before Use recommended."])
    page:SetScript("OnHide", function() ns.UI.Comparison:Close(false) end)
end

-- scrolls the page so the exception's row is in view
function B:ScrollTo(id)
    local r = rows[id]
    if not (page and r and r.top) then return end
    local maxScroll = math.max(0, (tonumber(body:GetHeight()) or 0) - (tonumber(scroll:GetHeight()) or 0))
    scroll:SetVerticalScroll(math.min(maxScroll, math.max(0, r.top - 40)))
end

-- focusId: an exception to show; an own one opens its conditions
function B:Show(focusId)
    if not page then build() end
    if ns.UI.RecipeGallery then ns.UI.RecipeGallery:Hide() end
    ns.UI.Main:SetSetPagesShown(false)
    focus = focusId
    if focusId and rows[focusId] == nil then syncRows() end
    if focusId and rows[focusId] and not rows[focusId].exc.builtin then expanded = focusId end
    page:Show()
    refreshNow()
    if focusId then self:ScrollTo(focusId) else scroll:SetVerticalScroll(0) end
    ns:Fire("BehaviourPageShown", true)
end
B.Show = ns.Profile.Wrap("how PetCall acts", B.Show)       -- /pcall profile: opened by a click

function B:Hide()
    if not page or not page:IsShown() then return end
    page:Hide()
    focus = nil
    ns.UI.Main:SetSetPagesShown(true)
    ns:Fire("BehaviourPageShown", false)
end

function B:IsShown() return page ~= nil and page:IsShown() end
function B:GetFrame() return page end

ns:RegisterCallback(B, "SelectedSetChanged", function() B:Hide() end)
ns:RegisterCallback(B, "WindowHidden", function() B:Hide() end)
refresh = ns.Debounce(0.1, refreshNow)
for _, cb in ipairs({ "AutoSummonChanged", "ExceptionsChanged", "ProfileValueChanged", "RecommendedUndoChanged",
    "ProfileChanged", "SpecialItemsChanged", "WindowResized" }) do
    ns:RegisterCallback(B, cb, refresh)
end
