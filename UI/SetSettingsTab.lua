local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
local Tab = {}
local page, set
local SECTION_W = 560


-- a titled block with a thin rule under the title; height is set by its builder
local function section(title, danger)
    local f = CreateFrame("Frame", nil, page)
    f:SetWidth(SECTION_W)
    f.title = ns.Widgets.Label(f, title, "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 4, 0)
    if danger then f.title:SetTextColor(1, 0.35, 0.3) end
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.rule:SetSize(SECTION_W - 4, 1)
    if danger then f.rule:SetColorTexture(1, 0.35, 0.3, 0.4) else f.rule:SetColorTexture(1, 1, 1, 0.15) end
    return f
end

-- a width, not a right anchor: "RIGHT" would also pin the vertical middle and cut wrapped lines
local function help(parent, text, width)
    local fs = ns.Widgets.Label(parent, text, "GameFontDisableSmall")
    fs:SetWordWrap(true)
    fs:SetWidth(width or 380)
    return fs
end

-- labels and their controls share one column, wide enough for the longest label
local LABEL_COL = 210

-- stack the sections that apply to this set from the top
local function stack()
    local prev
    for _, s in ipairs(page.sections) do
        s:ClearAllPoints()
        if s:IsShown() then
            if prev then s:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -18) else s:SetPoint("TOPLEFT", 8, -10) end
            prev = s
        end
    end
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
    page.name:SetText(set.name)
    stack()
end

ns.UI.Main:RegisterTab("settings", L["Set settings"], function(p)
    page = p
    ns.UI.SetSettingsPage = page
    page.sections = {}

    -- the default set: what it is, instead of the controls it does not have
    page.defaultNote = section(L["About this set"])
    local note = ns.Widgets.Label(page.defaultNote, L["The default set is used whenever no other set is active. It cannot be renamed, disabled or deleted."], "GameFontHighlight")
    note:SetPoint("TOPLEFT", page.defaultNote.rule, "BOTTOMLEFT", 0, -8)
    note:SetWidth(SECTION_W - 8)
    note:SetWordWrap(true)
    page.defaultNote:SetHeight(48)
    tinsert(page.sections, page.defaultNote)

    -- when and how the set is used
    local b = section(L["Behaviour"])
    page.behaviour = b
    -- running or paused, with the pause choices one click away
    local stateLabel = ns.Widgets.Label(b, L["State"])
    stateLabel:SetPoint("TOPLEFT", b.rule, "BOTTOMLEFT", 0, -14)
    page.pauseState = ns.Widgets.Label(b, "", "GameFontHighlight")
    page.pauseState:SetPoint("LEFT", stateLabel, "LEFT", LABEL_COL, 0)
    page.pauseButton = ns.Widgets.Button(b, L["Pause"], function(self)
        if set:IsPaused() then set:Resume() return end
        MenuUtil.CreateContextMenu(self, function(_, root) ns.UI.SetList.PauseMenu(root, set) end)
    end)
    page.pauseButton:SetPoint("LEFT", page.pauseState, "RIGHT", 12, 0)
    -- place in the list: the first set that fits is used
    local prioLabel = ns.Widgets.Label(b, L["Order"])
    prioLabel:SetPoint("TOPLEFT", stateLabel, "BOTTOMLEFT", 0, -18)
    page.order = ns.Widgets.Label(b, "", "GameFontHighlight")
    page.order:SetPoint("LEFT", prioLabel, "LEFT", LABEL_COL, 0)
    page.up = ns.Widgets.Button(b, L["Move up"], function() ns.Sets:Move(set, -1) end)
    page.up:SetPoint("LEFT", page.order, "LEFT", 60, 0)
    page.down = ns.Widgets.Button(b, L["Move down"], function() ns.Sets:Move(set, 1) end)
    page.down:SetPoint("LEFT", page.up, "RIGHT", 6, 0)
    local prioHelp = help(b, L["When several sets fit, the one higher in the list is used. The Default set is always last."])
    prioHelp:SetPoint("TOPLEFT", page.order, "BOTTOMLEFT", 0, -8)
    -- one row per choice: label in the first column, the control in the second
    local function row(label, anchor, gap, control)
        local l = ns.Widgets.Label(b, label)
        l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
        control:SetPoint("LEFT", l, "LEFT", LABEL_COL, 0)
        return l
    end
    local function radios(root, items, get, setter)
        for _, it in ipairs(items) do
            root:CreateRadio(it[2], function() return set and get() == it[1] end, function() setter(it[1]) end)
        end
    end
    page.onActivate = ns.Widgets.Dropdown(b, 260, function(_, root)
        radios(root, { { "keep", L["Keep the pet that is out"] }, { "fits", L["New pet, unless the one out fits"] },
            { "new", L["Always a new pet"] } }, function() return set:GetOnActivate() end, function(v) set:SetOnActivate(v) end)
    end)
    local startLabel = row(L["When this set starts"], prioLabel, 40, page.onActivate)
    page.switch = ns.Widgets.Dropdown(b, 260, function(_, root)
        radios(root, { { false, L["Like the settings"] }, { 5, format(L["%d minutes"], 5) }, { 10, format(L["%d minutes"], 10) },
            { 15, format(L["%d minutes"], 15) }, { 30, format(L["%d minutes"], 30) }, { 60, format(L["%d minutes"], 60) } },
            function() return set.settings.switchMinutes or false end, function(v) set:SetSwitchMinutes(v or nil) end)
    end)
    local switchLabel = row(L["Switch pet every"], startLabel, 18, page.switch)
    page.announce = ns.Widgets.Dropdown(b, 260, function(_, root)
        radios(root, { { false, L["Like the settings"] }, { "on", L["Always"] }, { "off", L["Never"] } },
            function() return set.settings.announce or false end, function(v) set:SetAnnounce(v or nil) end)
    end)
    local announceLabel = row(L["Chat message on summon"], switchLabel, 18, page.announce)
    page.noPet = ns.Widgets.Checkbox(b, L["No pet while this set is used"],
        function() return set and set:IsNoPet() end, function(v) set:SetNoPet(v) end)
    page.noPet:SetPoint("TOPLEFT", announceLabel, "BOTTOMLEFT", -4, -12)
    local noPetHelp = help(b, L["Dismisses your pet instead of summoning one, e.g. for raids or arenas."])
    noPetHelp:SetPoint("TOPLEFT", page.noPet, "BOTTOMLEFT", 28, 2)
    b:SetHeight(244)
    tinsert(page.sections, b)

    -- which pets and how often, for pets nobody set by hand
    local pets = section(L["Pets"])
    page.petsSection = pets
    local dwLabel = ns.Widgets.Label(pets, L["Pets you haven't set by hand:"])
    dwLabel:SetPoint("TOPLEFT", pets.rule, "BOTTOMLEFT", 0, -14)
    page.dwLabel = dwLabel
    page.defaultWeight = ns.Widgets.Dropdown(pets, 180, function(owner, root)
        for _, lvl in ipairs(ns.Weights.LEVELS) do
            root:CreateRadio(lvl.label, function() return set and ns.Weights.Nearest(set.settings.defaultValue) == lvl.value end,
                function() set:SetDefaultWeight(lvl.value) end)
        end
    end)
    page.defaultWeight:SetPoint("LEFT", dwLabel, "LEFT", LABEL_COL, 0)
    local dwHelp = help(pets, L["New pets you collect get this too. \"Never\" means only the pets you tick are used."])
    dwHelp:SetPoint("TOPLEFT", page.defaultWeight, "BOTTOMLEFT", 0, -4)
    page.reset = ns.Widgets.Button(pets, L["Reset all weights"], function()
        StaticPopup_Show("PETCALL_CONFIRM", L["Reset all pet weights in this set?"], nil,
            { onAccept = function() set:ClearPetWeights() end })
    end)
    page.reset:SetPoint("TOPLEFT", dwLabel, "BOTTOMLEFT", -2, -40)
    page.export = ns.Widgets.Button(pets, L["Export"], function() if ns.UI.Share then ns.UI.Share:ShowExport(set.name) end end)
    page.export:SetPoint("LEFT", page.reset, "RIGHT", 8, 0)
    ns.Widgets.Tooltip(page.export, L["Export"], L["Copy this set as text to share it or keep a backup."])
    pets:SetHeight(102)
    tinsert(page.sections, pets)

    local n = section(L["Name"])
    page.nameSection = n
    page.name = CreateFrame("EditBox", nil, n, "InputBoxTemplate")
    page.name:SetSize(200, 20)
    page.name:SetAutoFocus(false)
    page.name:SetPoint("TOPLEFT", n.rule, "BOTTOMLEFT", 6, -10)
    ns.Skin:Apply("EditBox", page.name)
    local rename = ns.Widgets.Button(n, L["Rename"], function()
        local ok, err = set:Rename(page.name:GetText())
        if not ok then UIErrorsFrame:AddMessage(err, 1, 0.3, 0.3) PlaySound(SOUNDKIT.IG_PLAYER_INVITE_DECLINE) end
        page.name:ClearFocus()
    end)
    rename:SetPoint("LEFT", page.name, "RIGHT", 8, 0)
    page.duplicate = ns.Widgets.Button(n, L["Duplicate"], function()
        local copy = ns.Sets:Duplicate(set)
        if copy then ns.UI.Main:SelectSet(copy.name) ns.UI.Main:SelectTab("settings") end
    end)
    page.duplicate:SetPoint("LEFT", rename, "RIGHT", 8, 0)
    page.name:SetScript("OnEnterPressed", function() rename:Click() end)
    n:SetHeight(50)
    tinsert(page.sections, n)

    -- kept apart and last so it is never clicked on the way to something else
    local d = section(L["Danger zone"], true)
    page.danger = d
    page.delete = ns.Widgets.Button(d, L["Delete set"], function()
        StaticPopup_Show("PETCALL_CONFIRM", format(L["Delete \"%s\"? This cannot be undone."], set.name), nil,
            { onAccept = function() set:Delete() end })
    end)
    page.delete:SetPoint("TOPLEFT", d.rule, "BOTTOMLEFT", -2, -10)
    page.delete:GetFontString():SetTextColor(1, 0.35, 0.3)
    local delHelp = help(d, L["Removes the set with its conditions and weights."])
    delHelp:SetPoint("LEFT", page.delete, "RIGHT", 10, 0)
    d:SetHeight(50)
    tinsert(page.sections, d)
    return Tab
end, 3)

ns:RegisterCallback(Tab, "SetsChanged", function() if page and page:IsVisible() and set and not set.deleted then Tab:Refresh(set) end end)
