local _, ns = ...

local L = ns.L
local Tab = {}
local page, set

local function priorityMenu(owner, root)
    for _, lvl in ipairs(ns.Weights.LEVELS) do
        if lvl.value > 0 then
            root:CreateRadio(lvl.priority, function() return set and ns.Weights.Nearest(set:GetPriority()) == lvl.value end,
                function() set:SetPriority(lvl.value) end)
        end
    end
end

function Tab:Refresh(newSet)
    set = newSet
    local default = set:IsDefault()
    page.title:SetText(set:DisplayName())
    for _, w in ipairs(page.editable) do w:SetShown(not default) end
    page.defaultNote:SetShown(default)
    page.enabled:SetChecked(set.settings.enabled)
    page.immediate:SetChecked(set.settings.immediate and true or false)
    page.priority:GenerateMenu()
    page.name:SetText(set.name)
    page.export:ClearAllPoints()
    if default then
        page.export:SetPoint("TOPLEFT", page.defaultNote, "BOTTOMLEFT", 0, -16)
    else
        page.export:SetPoint("TOPLEFT", page.nameLabel, "BOTTOMLEFT", -4, -24)
    end
end

ns.UI.Main:RegisterTab("settings", L["Set settings"], function(p)
    page = p
    page.editable = {}
    page.title = ns.Widgets.Label(page, "", "GameFontNormalLarge")
    page.title:SetPoint("TOPLEFT", 8, -8)

    page.enabled = ns.Widgets.Checkbox(page, L["Enabled"], function() return set and set.settings.enabled end, function(v) set:SetEnabled(v) end)
    page.enabled:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", -2, -12)
    tinsert(page.editable, page.enabled)

    local prioLabel = ns.Widgets.Label(page, L["Priority"])
    prioLabel:SetPoint("TOPLEFT", page.enabled, "BOTTOMLEFT", 4, -14)
    page.priority = ns.Widgets.Dropdown(page, 200, priorityMenu)
    page.priority:SetPoint("LEFT", prioLabel, "RIGHT", 10, 0)
    local prioHelp = ns.Widgets.Label(page, L["When several sets match, the one with the highest priority is used."], "GameFontDisableSmall")
    prioHelp:SetPoint("TOPLEFT", prioLabel, "BOTTOMLEFT", 0, -6)
    for _, w in ipairs({ prioLabel, page.priority, prioHelp }) do tinsert(page.editable, w) end

    page.immediate = ns.Widgets.Checkbox(page, L["Summon immediately when this set becomes active"],
        function() return set and set.settings.immediate end, function(v) set:SetImmediate(v) end)
    page.immediate:SetPoint("TOPLEFT", prioHelp, "BOTTOMLEFT", -4, -12)
    tinsert(page.editable, page.immediate)

    local nameLabel = ns.Widgets.Label(page, L["Name"])
    nameLabel:SetPoint("TOPLEFT", page.immediate, "BOTTOMLEFT", 4, -18)
    page.name = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    page.name:SetSize(200, 20)
    page.name:SetAutoFocus(false)
    page.name:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    ns.Skin:Apply("EditBox", page.name)
    local rename = ns.Widgets.Button(page, L["Rename"], function()
        local ok, err = set:Rename(page.name:GetText())
        if not ok then UIErrorsFrame:AddMessage(err, 1, 0.3, 0.3) PlaySound(SOUNDKIT.IG_PLAYER_INVITE_DECLINE) end
        page.name:ClearFocus()
    end)
    rename:SetPoint("LEFT", page.name, "RIGHT", 8, 0)
    page.name:SetScript("OnEnterPressed", function() rename:Click() end)
    for _, w in ipairs({ nameLabel, page.name, rename }) do tinsert(page.editable, w) end

    page.nameLabel = nameLabel
    page.export = ns.Widgets.Button(page, L["Export"], function() if ns.UI.Share then ns.UI.Share:ShowExport(set.name) end end)
    local export = page.export
    local delete = ns.Widgets.Button(page, L["Delete set"], function()
        StaticPopup_Show("PETCALL_CONFIRM", format(L["Delete \"%s\"? This cannot be undone."], set.name), nil,
            { onAccept = function() set:Delete() end })
    end)
    delete:SetPoint("LEFT", export, "RIGHT", 8, 0)
    tinsert(page.editable, delete)

    page.defaultNote = ns.Widgets.Label(page, L["The default set is used whenever no other set is active. It cannot be renamed, disabled or deleted."], "GameFontHighlight")
    page.defaultNote:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -12)
    page.defaultNote:SetPoint("RIGHT", -8, 0)
    page.defaultNote:SetWordWrap(true)
    return Tab
end, 3)

ns:RegisterCallback(Tab, "SetsChanged", function() if page and page:IsVisible() and set and not set.deleted then Tab:Refresh(set) end end)
