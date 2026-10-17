local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
local Tab = {}
local page, scroll, content, set, model
local frames = ns.Widgets.NewPool()   -- each redraw takes back the frames of the last one
local dots, header = {}, nil                                  -- redrawn in place when condition states change
local drafts = setmetatable({}, { __mode = "k" })             -- entry -> unsaved code text
local results = setmetatable({}, { __mode = "k" })            -- entry -> last "Check" result text

local TEMPLATES = {
    { key = "city", label = L["In a city"] }, { key = "instance", label = L["In a raid or dungeon"] },
    { key = "here", label = L["Here (current place)"] }, { key = "spec", label = L["On my current specialization"] },
    { key = "group", label = L["In a group"] }, { key = "home", label = L["At my house"] },
    { key = "holiday", label = L["During any holiday"] },
}

local function save() set:SetConditionModel(model) end
local function changedInPlace() set:ConditionsChanged() end

local function clear()
    frames:Release()
    wipe(dots)
    header = nil
end

local function chip(parent, text, onRemove)
    local b = frames:Button(parent, text .. "  ×", onRemove, "chip")
    b:SetHeight(20)
    b:SetWidth(b:GetFontString():GetStringWidth() + 20)
    return b
end

local function mapName(id) local i = C_Map.GetMapInfo(id) return i and i.name or tostring(id) end

local function buildField(row, e, field, prev)
    local function place(w, gap) w:SetPoint("LEFT", prev, "RIGHT", gap or 6, 0) prev = w return w end
    if field.kind == "multiPlace" then
        local names = {}
        if e.zoneName and e.zoneName ~= "" then names[#names + 1] = { text = e.zoneName, remove = function() e.zoneName = nil end } end
        for i, n in ipairs(e.zoneNames or {}) do names[#names + 1] = { text = n, remove = function() table.remove(e.zoneNames, i) end } end
        for i, id in ipairs(e.mapIDs or {}) do names[#names + 1] = { text = mapName(id), remove = function() table.remove(e.mapIDs, i) end } end
        for _, n in ipairs(names) do place(chip(row, n.text, function() n.remove() changedInPlace() Tab:Refresh(set) end)) end
        local addHere = place(frames:Button(row, L["+ current"], function()
            if ns.Conditions.AddCurrentPlace(e) then changedInPlace() Tab:Refresh(set) end
        end))
        local here = ns.Conditions.HasCurrentPlace(e)
        addHere:SetEnabled(not here)
        ns.Widgets.Tooltip(addHere, L["+ current"], here and L["You are already in one of these places."] or L["Add the place you are in now."])
    elseif field.kind == "multiChoice" then
        local values = field.values()
        local dd = frames:Dropdown(row, 200, function(owner, root)
            for _, v in ipairs(values) do
                root:CreateCheckbox(v.label, function()
                    local cur = e[field.key] or (e[1] == "specialLocation" and ({ city = { "city" }, battleground = { "pvp" }, instance = { "dungeon", "raid" } })[e.loc]) or {}
                    for _, x in ipairs(cur) do if x == v.value then return true end end
                end, function()
                    local cur = e[field.key] or (e[1] == "specialLocation" and ({ city = { "city" }, battleground = { "pvp" }, instance = { "dungeon", "raid" } })[e.loc]) or {}
                    local out, found = {}, false
                    for _, x in ipairs(cur) do if x == v.value then found = true else out[#out + 1] = x end end
                    if not found then out[#out + 1] = v.value end
                    e[field.key], e.loc = out, nil
                    changedInPlace()
                end)
            end
        end)
        place(dd)
    elseif field.kind == "flags" then
        -- each box starts after the label before it, measured, so labels never run into boxes
        local gap = 12
        for _, v in ipairs(field.values()) do
            local cb = frames:Checkbox(row, v.label, function() return e[v.value] end,
                function(on) e[v.value] = on or nil changedInPlace() end)
            cb.text:ClearAllPoints()
            cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            place(cb, gap)
            gap = 2 + (tonumber(cb.text:GetStringWidth()) or 0) + 16
        end
        prev = prev.text or prev          -- what comes next (the remove ×) follows the last label
    elseif field.kind == "class" then
        place(frames:Dropdown(row, 150, function(owner, root)
            root:CreateRadio(L["Any class"], function() return not e.class or e.class == "" end, function() e.class = "" changedInPlace() end)
            for _, c in ipairs(CLASS_SORT_ORDER) do
                root:CreateRadio(LOCALIZED_CLASS_NAMES_MALE[c] or c, function() return e.class == c end, function() e.class = c changedInPlace() end)
            end
        end))
    elseif field.kind == "spec" then
        place(frames:Dropdown(row, 170, function(owner, root)
            root:CreateRadio(L["Any specialization"], function() return not e.spec or e.spec == -1 end, function() e.spec = -1 changedInPlace() end)
            for i = 1, 4 do
                local _, name = C_SpecializationInfo.GetSpecializationInfo(i)
                if name then
                    root:CreateRadio(format("#%d %s", i, name), function() return e.spec == i end, function() e.spec = i changedInPlace() end)
                end
            end
        end))
    elseif field.kind == "text" then
        local eb = frames:EditBox(row, "textBox")
        eb:SetSize(field.optional and 120 or 220, 20)
        eb:SetText(e[field.key] or "")
        eb:SetScript("OnEnterPressed", function(self) e[field.key] = self:GetText() self:ClearFocus() changedInPlace() end)
        eb:SetScript("OnEditFocusLost", function(self) if (e[field.key] or "") ~= self:GetText() then e[field.key] = self:GetText() changedInPlace() end end)
        if field.placeholder then ns.Widgets.Tooltip(eb, field.placeholder) end
        place(eb, 10)
    elseif field.kind == "timeRange" then
        local function timeBox(key)
            local eb = frames:EditBox(row, "timeBox")
            eb:SetSize(50, 20)
            eb:SetText(format("%02d:%02d", math.floor((e[key] or 0) / 60), (e[key] or 0) % 60))
            eb:SetScript("OnEnterPressed", function(self)
                local h, m = self:GetText():match("^(%d%d?):(%d%d)$")
                h, m = tonumber(h), tonumber(m)
                if h and m and h < 24 and m < 60 then e[key] = h * 60 + m changedInPlace() else PlaySound(SOUNDKIT.IG_PLAYER_INVITE_DECLINE) end
                self:ClearFocus()
            end)
            return eb
        end
        place(timeBox("from"), 10)
        local dash = frames:Label(row, "–")
        place(dash, 4)
        place(timeBox("to"), 4)
    elseif field.kind == "code" then
        -- code editor sits under the row; the row grows
        row.codeEditor = true
    end
    return prev
end

local function codeEditor(parent, e, anchor)
    local box = frames:Take("code", parent, function()
        local f = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
        local sf = CreateFrame("ScrollFrame", nil, f, "ScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 6, -6)
        sf:SetPoint("BOTTOMRIGHT", -26, 6)
        f.edit = CreateFrame("EditBox", nil, sf)
        f.edit:SetMultiLine(true)
        f.edit:SetFontObject("ChatFontNormal")
        f.edit:SetWidth(400)
        f.edit:SetAutoFocus(false)
        sf:SetScrollChild(f.edit)
        return f
    end)
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 24, -4)
    box:SetPoint("RIGHT", -8, 0)
    box:SetHeight(120)
    local eb = box.edit
    eb:SetText(drafts[e] or e.code or "")
    -- keep typing across redraws; commit when the box loses focus
    eb:SetScript("OnTextChanged", function(self, userInput) if userInput then drafts[e] = self:GetText() end end)
    eb:SetScript("OnEditFocusLost", function(self)
        if drafts[e] and drafts[e] ~= e.code then e.code = drafts[e] drafts[e] = nil changedInPlace() end
    end)
    local result = frames:Label(parent, "", "GameFontHighlightSmall")
    result:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
    result:SetPoint("RIGHT", -8, 0)
    result:SetText(results[e] or "")
    local check = frames:Button(parent, L["Check"], function()
        e.code = eb:GetText()
        drafts[e] = nil
        local ok, res = ns.Conditions.CheckLua(e.code)
        results[e] = ok and ("|cff40ff40" .. L["OK, current result:"] .. "|r " .. tostring(res)) or ("|cffff4040" .. tostring(res) .. "|r")
        result:SetText(results[e])
        changedInPlace()
    end)
    check:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -2)
    if e.disabledByImport then
        local warn = frames:Label(parent, "|cffff4040" .. L["Imported code is disabled until you review it."] .. "|r")
        warn:SetPoint("TOPLEFT", result, "BOTTOMLEFT", 0, -6)
        local enable = frames:Button(parent, L["Review done – enable"], function()
            e.disabledByImport = nil changedInPlace() Tab:Refresh(set)
        end)
        enable:SetPoint("LEFT", warn, "RIGHT", 8, 0)
        return 190
    end
    return 160
end

local function state(e) return set:GetConditionStates()[e] end

local function paintDot(dot, e)
    local on = state(e) and state(e).value
    dot:SetText(ns.Widgets.Dot(on and "on" or "off"))
end

local function paintHeader()
    if not header then return end
    header:SetText(format("%s   %s", #model.groups > 1 and L["Use this set when ANY of these groups is met:"] or L["Use this set when ALL conditions are met:"],
        set:ConditionsMet() and (ns.Widgets.Dot("on") .. " |cff40ff40" .. L["active"] .. "|r")
            or (ns.Widgets.Dot("off") .. " |cffcccccc" .. L["inactive"] .. "|r")))
end

local function stateDot(row, e)
    local dot = frames:Label(row, "", "GameFontNormal")
    paintDot(dot, e)
    dots[#dots + 1] = { dot = dot, e = e }
    local hit = frames:Frame(row, "hit")
    hit:SetAllPoints(dot)
    hit:EnableMouse(true)
    ns.Widgets.Tooltip(hit, function() return state(e) and state(e).value and L["Met right now"] or L["Not met right now"] end,
        function() return state(e) and state(e).reason end)
    return dot
end

-- condition states changed (zone, group, time…): repaint, keep the editor as it is
local function repaintStates()
    for _, d in ipairs(dots) do paintDot(d.dot, d.e) end
    paintHeader()
end

local function buildRow(parent, group, index, e, y)
    local row = frames:Frame(parent, "row")
    row.codeEditor, row.negate, row.last = nil, nil, nil
    row:SetPoint("TOPLEFT", 8, y)
    row:SetPoint("RIGHT", -8, 0)
    row:SetHeight(26)
    local dot = stateDot(row, e)
    dot:SetPoint("LEFT")
    local height = 28
    if ns.Conditions.IsLegacyNode(e) then
        local text = frames:Label(row, L["Complex rule (previous version)"] .. ": " .. ns.Conditions.Describe(e), "GameFontHighlightSmall")
        text:SetPoint("LEFT", dot, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", -120, 0)
        text:SetWordWrap(true)
        local simplified = ns.Conditions.Simplify(e)
        local simplify = frames:Button(row, L["Simplify"], function()
            table.remove(group.rows, index)
            for k = #simplified, 1, -1 do tinsert(group.rows, index, simplified[k]) end
            save() Tab:Refresh(set)
        end)
        simplify:SetPoint("RIGHT", -28, 0)
        simplify:SetEnabled(simplified ~= nil)
        ns.Widgets.Tooltip(simplify, simplified and L["Rewrite as simple conditions with the same meaning."] or L["This rule cannot be simplified without changing its meaning."])
        height = 40
    else
        local def = ns.Conditions.GetType(e[1])
        local name = frames:Label(row, def.label, "GameFontNormal")
        name:SetPoint("LEFT", dot, "RIGHT", 6, 0)
        name:SetWidth(110)
        -- "is / is not" sits where it is read, between the condition and its values
        local negate = frames:Button(row, "", function(self)
            e.negate = not e.negate or nil
            changedInPlace()
            self:Paint()
        end, "negate")
        negate:SetWidth(64)
        function negate:Paint()
            self:SetText(e.negate and L["is not"] or L["is"])
            self:GetFontString():SetTextColor(e.negate and 1 or 0.82, e.negate and 0.4 or 0.82, e.negate and 0.3 or 0.82)
        end
        negate:Paint()
        ns.Widgets.Tooltip(negate, L["is / is not"], L["Click to turn the condition around."])
        negate:SetPoint("LEFT", name, "RIGHT", 4, 0)
        row.negate = negate
        local prev = negate
        for _, field in ipairs(def.fields) do prev = buildField(row, e, field, prev) end
        row.last = prev
        if row.codeEditor then height = 28 + codeEditor(parent, e, row) end
    end
    local remove = frames:Button(row, "×", function()
        table.remove(group.rows, index)
        save() Tab:Refresh(set)
    end)
    remove:SetWidth(24)
    -- next to what it removes, not at the far edge of a wide window
    if row.last then remove:SetPoint("LEFT", row.last, "RIGHT", 12, 0) else remove:SetPoint("RIGHT") end
    ns.Widgets.Tooltip(remove, L["Remove condition"])
    return height
end

-- the menu asks the player's questions, in the order they think of them
local MENU_GROUPS = {
    { key = "where", label = L["Where I am"] },
    { key = "doing", label = L["What I am doing"] },
    { key = "with", label = L["Who I play with"] },
    { key = "who", label = L["Who I play as"] },
    { key = "when", label = L["When"] },
    { key = "advanced", label = L["Advanced"] },
}

-- ready-made rows for the most common wishes, at the top of their group
local QUICK = {
    where = { { label = L["Here (current place)"], new = function() return { "zone", mapIDs = { C_Map.GetBestMapForUnit("player") } } end },
        { label = L["At my house"], new = function() return { "housing", ownHome = true } end } },
    doing = { { label = L["While swimming"], new = function() return { "activity", swimming = true } end },
        { label = L["While AFK"], new = function() return { "activity", afk = true } end } },
    who = { { label = L["On my current specialization"], new = function()
        local _, class = UnitClass("player")
        return { "specialization", class = class, spec = C_SpecializationInfo.GetSpecialization() or -1 }
    end } },
    when = { { label = L["During any holiday"], new = function() return { "holiday", holidayIDs = { 0 } } end } },
}

local function withHint(item, title, hint)
    if hint and item.SetTooltip then
        item:SetTooltip(function(tooltip)
            tooltip:SetText(title, 1, 1, 1)
            tooltip:AddLine(hint, nil, nil, nil, true)
        end)
    end
    return item
end

local function addMenu(group)
    local function add(row) tinsert(group.rows, row) save() Tab:Refresh(set) end
    return function(owner, root)
        local sub = {}
        for _, g in ipairs(MENU_GROUPS) do
            sub[g.key] = root:CreateButton(g.label)
            for _, q in ipairs(QUICK[g.key] or {}) do
                sub[g.key]:CreateButton(q.label, function() add(q.new()) end)
            end
            if QUICK[g.key] then sub[g.key]:CreateDivider() end
        end
        for _, def in ipairs(ns.Conditions.Types()) do
            local parent = sub[def.group] or sub.advanced
            withHint(parent:CreateButton(def.label, function() add(def.new()) end), def.label, def.hint)
        end
    end
end

local render

function Tab:Refresh(newSet)
    set = newSet
    if not page or set:IsDefault() then return end
    model = set:GetConditionModel()
    render()
end

-- Draws `model`. An empty extra group lives only in this local model until a
-- condition is added to it (FromModel drops empty groups on save).
function render()
    clear()
    local y = -8
    header = frames:Label(content, "", "GameFontNormal")
    header:SetPoint("TOPLEFT", 8, y)
    paintHeader()
    y = y - 24
    if not set:HasConditions() then
        local note = frames:Label(content, "|cffffb040" .. L["Without conditions this set is always active."] .. "|r")
        note:SetPoint("TOPLEFT", 8, y)
        y = y - 22
        local prev
        -- four per row so the row never runs past a narrow window
        for i, t in ipairs(TEMPLATES) do
            local b = frames:Button(content, t.label, function() set:ApplyTemplate(t.key) Tab:Refresh(set) end)
            if i % 4 == 1 then
                if i > 1 then y = y - 26 end
                b:SetPoint("TOPLEFT", 8, y)
            else
                b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
            end
            prev = b
        end
        y = y - 30
        if #model.groups[1].rows == 0 then
            local add = frames:Dropdown(content, 180, addMenu(model.groups[1]), L["+ Add condition"])
            add:SetPoint("TOPLEFT", 8, y)
            y = y - 30
        end
    end
    for gi, group in ipairs(model.groups) do
        if #group.rows == 0 and gi == 1 and not set:HasConditions() then break end
        if gi > 1 then
            -- "OR" and a line to the edge in one frame, so a redraw puts both away
            local orRow = frames:Take("or", content, function()
                local f = CreateFrame("Frame", nil, content)
                f:SetHeight(20)
                f.label = ns.Widgets.Label(f, L["OR"], "GameFontNormalLarge")
                f.label:SetPoint("LEFT")
                f.line = f:CreateTexture(nil, "ARTWORK")
                f.line:SetHeight(1)
                f.line:SetPoint("LEFT", f.label, "RIGHT", 8, 0)
                f.line:SetPoint("RIGHT")
                f.label.line = f.line
                return f
            end)
            orRow:SetPoint("TOPLEFT", 12, y)
            orRow:SetPoint("RIGHT", content, "RIGHT", -8, 0)
            ns.Skin:Divider(orRow.label, orRow.line)
            y = y - 24
        end
        local card = frames:Take("card", content, function() return CreateFrame("Frame", nil, content, "InsetFrameTemplate") end)
        card:SetPoint("TOPLEFT", 4, y)
        card:SetPoint("RIGHT", -4, 0)
        ns.Skin:Card(card)
        local cy = -6
        for ri, e in ipairs(group.rows) do cy = cy - buildRow(card, group, ri, e, cy) end
        local add = frames:Dropdown(card, 180, addMenu(group), L["+ Add condition"])
        add:SetPoint("TOPLEFT", 8, cy - 2)
        if #model.groups > 1 then
            local removeGroup = frames:Button(card, L["Remove group"], function()
                table.remove(model.groups, gi) save() Tab:Refresh(set)
            end)
            removeGroup:SetPoint("LEFT", add, "RIGHT", 8, 0)
        end
        cy = cy - 32
        card:SetHeight(-cy + 4)
        y = y + cy - 10
    end
    if set:HasConditions() then
        local orLink = frames:Button(content, L["+ Or another set of conditions"], function()
            tinsert(model.groups, { rows = {} }) render()
        end)
        orLink:SetPoint("TOPLEFT", 8, y)
        y = y - 30
    end
    content:SetHeight(-y + 10)
end

ns.UI.Main:RegisterTab("when", L["When"], function(p)
    page = p
    scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", -24, 2)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(10, 10)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w) content:SetWidth(w) end)
    ns.Skin:Apply("ScrollBar", scroll.ScrollBar)
    return Tab
end, 2)

local refreshSoon = ns.Debounce(0.1, function()
    if page and page:IsVisible() and set and not set.deleted then repaintStates() end
end)
ns:RegisterCallback(Tab, "ConditionStateChanged", function(_, name) if set and name == set.name then refreshSoon() end end)
