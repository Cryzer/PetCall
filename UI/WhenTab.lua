local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
local Tab = {}
local page, scroll, content, set, model
local pool = {}          -- reusable row/group frames are rebuilt on each Refresh (sets have few rows)
local dots, header = {}, nil                                  -- redrawn in place when condition states change
local drafts = setmetatable({}, { __mode = "k" })             -- entry -> unsaved code text
local results = setmetatable({}, { __mode = "k" })            -- entry -> last "Check" result text

local TEMPLATES = {
    { key = "city", label = L["In a city"] }, { key = "instance", label = L["In a raid or dungeon"] },
    { key = "here", label = L["Here (current place)"] }, { key = "spec", label = L["On my current specialization"] },
    { key = "group", label = L["In a group"] },
}

local function save() set:SetConditionModel(model) end
local function changedInPlace() set:ConditionsChanged() end

local function clear()
    for _, f in ipairs(pool) do f:Hide() f:SetParent(nil) end
    wipe(pool)
    wipe(dots)
    header = nil
end

local function track(f) pool[#pool + 1] = f return f end

local function chip(parent, text, onRemove)
    local b = track(CreateFrame("Button", nil, parent, "UIPanelButtonTemplate"))
    b:SetText(text .. "  ×")
    b:SetHeight(20)
    b:SetWidth(b:GetFontString():GetStringWidth() + 20)
    b:SetScript("OnClick", onRemove)
    ns.Skin:Apply("Button", b)
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
        place(track(ns.Widgets.Button(row, L["+ current"], function()
            e.mapIDs = e.mapIDs or {}
            local id = C_Map.GetBestMapForUnit("player")
            if id then tinsert(e.mapIDs, id) changedInPlace() Tab:Refresh(set) end
        end)))
    elseif field.kind == "multiChoice" then
        local values = field.values()
        local dd = track(ns.Widgets.Dropdown(row, 200, function(owner, root)
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
        end))
        place(dd)
    elseif field.kind == "flags" then
        for _, v in ipairs(field.values()) do
            local cb = track(ns.Widgets.Checkbox(row, v.label, function() return e[v.value] end,
                function(on) e[v.value] = on or nil changedInPlace() end))
            place(cb, 8)
            prev = cb.text
        end
    elseif field.kind == "class" then
        place(track(ns.Widgets.Dropdown(row, 150, function(owner, root)
            root:CreateRadio(L["Any class"], function() return not e.class or e.class == "" end, function() e.class = "" changedInPlace() end)
            for _, c in ipairs(CLASS_SORT_ORDER) do
                root:CreateRadio(LOCALIZED_CLASS_NAMES_MALE[c] or c, function() return e.class == c end, function() e.class = c changedInPlace() end)
            end
        end)))
    elseif field.kind == "spec" then
        place(track(ns.Widgets.Dropdown(row, 170, function(owner, root)
            root:CreateRadio(L["Any specialization"], function() return not e.spec or e.spec == -1 end, function() e.spec = -1 changedInPlace() end)
            for i = 1, 4 do
                local _, name = C_SpecializationInfo.GetSpecializationInfo(i)
                if name then
                    root:CreateRadio(format("#%d %s", i, name), function() return e.spec == i end, function() e.spec = i changedInPlace() end)
                end
            end
        end)))
    elseif field.kind == "text" then
        local eb = track(CreateFrame("EditBox", nil, row, "InputBoxTemplate"))
        eb:SetSize(field.optional and 120 or 220, 20)
        eb:SetAutoFocus(false)
        eb:SetText(e[field.key] or "")
        eb:SetScript("OnEnterPressed", function(self) e[field.key] = self:GetText() self:ClearFocus() changedInPlace() end)
        eb:SetScript("OnEditFocusLost", function(self) if (e[field.key] or "") ~= self:GetText() then e[field.key] = self:GetText() changedInPlace() end end)
        if field.placeholder then ns.Widgets.Tooltip(eb, field.placeholder) end
        ns.Skin:Apply("EditBox", eb)
        place(eb, 10)
    elseif field.kind == "timeRange" then
        local function timeBox(key)
            local eb = track(CreateFrame("EditBox", nil, row, "InputBoxTemplate"))
            eb:SetSize(50, 20)
            eb:SetAutoFocus(false)
            eb:SetText(format("%02d:%02d", math.floor((e[key] or 0) / 60), (e[key] or 0) % 60))
            eb:SetScript("OnEnterPressed", function(self)
                local h, m = self:GetText():match("^(%d%d?):(%d%d)$")
                h, m = tonumber(h), tonumber(m)
                if h and m and h < 24 and m < 60 then e[key] = h * 60 + m changedInPlace() else PlaySound(SOUNDKIT.IG_PLAYER_INVITE_DECLINE) end
                self:ClearFocus()
            end)
            ns.Skin:Apply("EditBox", eb)
            return eb
        end
        place(timeBox("from"), 10)
        local dash = track(ns.Widgets.Label(row, "–"))
        place(dash, 4)
        place(timeBox("to"), 4)
    elseif field.kind == "code" then
        -- code editor sits under the row; the row grows
        row.codeEditor = true
    end
    return prev
end

local function codeEditor(parent, e, anchor)
    local box = track(CreateFrame("Frame", nil, parent, "InsetFrameTemplate"))
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 24, -4)
    box:SetPoint("RIGHT", -8, 0)
    box:SetHeight(120)
    local sf = CreateFrame("ScrollFrame", nil, box, "ScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -26, 6)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetFontObject("ChatFontNormal")
    eb:SetWidth(400)
    eb:SetAutoFocus(false)
    eb:SetText(drafts[e] or e.code or "")
    sf:SetScrollChild(eb)
    -- keep typing across redraws; commit when the box loses focus
    eb:SetScript("OnTextChanged", function(self, userInput) if userInput then drafts[e] = self:GetText() end end)
    eb:SetScript("OnEditFocusLost", function(self)
        if drafts[e] and drafts[e] ~= e.code then e.code = drafts[e] drafts[e] = nil changedInPlace() end
    end)
    local result = track(ns.Widgets.Label(parent, "", "GameFontHighlightSmall"))
    result:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4)
    result:SetPoint("RIGHT", -8, 0)
    result:SetText(results[e] or "")
    local check = track(ns.Widgets.Button(parent, L["Check"], function()
        e.code = eb:GetText()
        drafts[e] = nil
        local ok, res = ns.Conditions.CheckLua(e.code)
        results[e] = ok and ("|cff40ff40" .. L["OK, current result:"] .. "|r " .. tostring(res)) or ("|cffff4040" .. tostring(res) .. "|r")
        result:SetText(results[e])
        changedInPlace()
    end))
    check:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -2)
    if e.disabledByImport then
        local warn = track(ns.Widgets.Label(parent, "|cffff4040" .. L["Imported code is disabled until you review it."] .. "|r"))
        warn:SetPoint("TOPLEFT", result, "BOTTOMLEFT", 0, -6)
        local enable = track(ns.Widgets.Button(parent, L["Review done – enable"], function()
            e.disabledByImport = nil changedInPlace() Tab:Refresh(set)
        end))
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
    local dot = track(ns.Widgets.Label(row, "", "GameFontNormal"))
    paintDot(dot, e)
    dots[#dots + 1] = { dot = dot, e = e }
    local hit = track(CreateFrame("Frame", nil, row))
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
    local row = track(CreateFrame("Frame", nil, parent))
    row:SetPoint("TOPLEFT", 8, y)
    row:SetPoint("RIGHT", -8, 0)
    row:SetHeight(26)
    local dot = stateDot(row, e)
    dot:SetPoint("LEFT")
    local height = 28
    if ns.Conditions.IsLegacyNode(e) then
        local text = track(ns.Widgets.Label(row, L["Complex rule (previous version)"] .. ": " .. ns.Conditions.Describe(e), "GameFontHighlightSmall"))
        text:SetPoint("LEFT", dot, "RIGHT", 6, 0)
        text:SetPoint("RIGHT", -120, 0)
        text:SetWordWrap(true)
        local simplified = ns.Conditions.Simplify(e)
        local simplify = track(ns.Widgets.Button(row, L["Simplify"], function()
            table.remove(group.rows, index)
            for k = #simplified, 1, -1 do tinsert(group.rows, index, simplified[k]) end
            save() Tab:Refresh(set)
        end))
        simplify:SetPoint("RIGHT", -28, 0)
        simplify:SetEnabled(simplified ~= nil)
        ns.Widgets.Tooltip(simplify, simplified and L["Rewrite as simple conditions with the same meaning."] or L["This rule cannot be simplified without changing its meaning."])
        height = 40
    else
        local def = ns.Conditions.GetType(e[1])
        local label = track(ns.Widgets.Label(row, def.label, "GameFontNormal"))
        label:SetPoint("LEFT", dot, "RIGHT", 6, 0)
        label:SetWidth(120)
        local prev = label
        for _, field in ipairs(def.fields) do prev = buildField(row, e, field, prev) end
        local negate = track(ns.Widgets.Checkbox(row, L["not"], function() return e.negate end, function(v) e.negate = v or nil changedInPlace() end))
        negate:SetPoint("RIGHT", -60, 0)
        if row.codeEditor then height = 28 + codeEditor(parent, e, row) end
    end
    local remove = track(ns.Widgets.Button(row, "×", function()
        table.remove(group.rows, index)
        save() Tab:Refresh(set)
    end))
    remove:SetWidth(24)
    remove:SetPoint("RIGHT")
    return height
end

local function addMenu(group)
    return function(owner, root)
        local groups = { place = L["Place"], party = L["Group and character"], time = L["Time"], advanced = L["Advanced"] }
        local sub = {}
        for _, def in ipairs(ns.Conditions.Types()) do
            sub[def.group] = sub[def.group] or root:CreateButton(groups[def.group])
            sub[def.group]:CreateButton(def.label, function()
                tinsert(group.rows, def.new())
                save() Tab:Refresh(set)
            end)
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
    header = track(ns.Widgets.Label(content, "", "GameFontNormal"))
    header:SetPoint("TOPLEFT", 8, y)
    paintHeader()
    y = y - 24
    if not set:HasConditions() then
        local note = track(ns.Widgets.Label(content, "|cffffb040" .. L["Without conditions this set is always active."] .. "|r"))
        note:SetPoint("TOPLEFT", 8, y)
        y = y - 22
        local prev
        for _, t in ipairs(TEMPLATES) do
            local b = track(ns.Widgets.Button(content, t.label, function() set:ApplyTemplate(t.key) Tab:Refresh(set) end))
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 8, y) end
            prev = b
        end
        y = y - 30
        if #model.groups[1].rows == 0 then
            local add = track(ns.Widgets.Dropdown(content, 180, addMenu(model.groups[1])))
            add:SetDefaultText(L["+ Add condition"])
            add:SetPoint("TOPLEFT", 8, y)
            y = y - 30
        end
    end
    for gi, group in ipairs(model.groups) do
        if #group.rows == 0 and gi == 1 and not set:HasConditions() then break end
        if gi > 1 then
            local orLabel = track(ns.Widgets.Label(content, L["OR"], "GameFontNormalLarge"))
            orLabel:SetPoint("TOPLEFT", 12, y)
            y = y - 24
        end
        local card = track(CreateFrame("Frame", nil, content, "InsetFrameTemplate"))
        card:SetPoint("TOPLEFT", 4, y)
        card:SetPoint("RIGHT", -4, 0)
        ns.Skin:Apply("Inset", card)
        local cy = -6
        for ri, e in ipairs(group.rows) do cy = cy - buildRow(card, group, ri, e, cy) end
        local add = track(ns.Widgets.Dropdown(card, 180, addMenu(group)))
        add:SetDefaultText(L["+ Add condition"])
        add:SetPoint("TOPLEFT", 8, cy - 2)
        if #model.groups > 1 then
            local removeGroup = track(ns.Widgets.Button(card, L["Remove group"], function()
                table.remove(model.groups, gi) save() Tab:Refresh(set)
            end))
            removeGroup:SetPoint("LEFT", add, "RIGHT", 8, 0)
        end
        cy = cy - 32
        card:SetHeight(-cy + 4)
        y = y + cy - 10
    end
    if set:HasConditions() then
        local orLink = track(ns.Widgets.Button(content, L["+ Or another set of conditions"], function()
            tinsert(model.groups, { rows = {} }) render()
        end))
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
