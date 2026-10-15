local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local SetList = {}
ns.UI.SetList = SetList

local COLLAPSE_BELOW = 700
local panel, rail, rows, newBox = nil, nil, {}, nil
local STATUS = {
    active = { "●", 0.3, 1, 0.3, L["Active now"] },
    waiting = { "○", 0.8, 0.8, 0.8, L["Conditions not met"] },
    empty = { "●", 1, 0.55, 0.1, L["No pets to choose from"] },
    noConditions = { "●", 1, 0.55, 0.1, L["No conditions: this set is always active"] },
    disabled = { "◌", 0.5, 0.5, 0.5, L["Disabled"] },
}

local function setMenu(owner, root, set)
    if not set:IsDefault() then
        root:CreateButton(set.settings.enabled and L["Disable"] or L["Enable"], function() set:SetEnabled(not set.settings.enabled) end)
        root:CreateButton(L["Rename"], function() ns.UI.Main:SelectSet(set.name) ns.UI.Main:SelectTab("settings") end)
    end
    if ns.UI.Share then root:CreateButton(L["Export"], function() ns.UI.Share:ShowExport(set.name) end) end
    if not set:IsDefault() then
        root:CreateButton(DELETE, function()
            StaticPopup_Show("PETCALL_CONFIRM", format(L["Delete \"%s\"? This cannot be undone."], set.name), nil,
                { onAccept = function() set:Delete() end })
        end)
    end
end

local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, panel)
    r:SetHeight(24)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetHighlightAtlas("PetList-ButtonHighlight", "ADD")
    r.selected = r:CreateTexture(nil, "BACKGROUND")
    r.selected:SetAllPoints()
    r.selected:SetAtlas("PetList-ButtonSelect")
    r.dot = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.dot:SetPoint("LEFT", 6, 0)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.name:SetPoint("LEFT", r.dot, "RIGHT", 6, 0)
    r.name:SetPoint("RIGHT", -34, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.prio = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.prio:SetPoint("RIGHT", -6, 0)
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MenuUtil.CreateContextMenu(self, function(o, root) setMenu(o, root, self.set) end)
        else
            ns.UI.Main:SelectSet(self.set.name)
        end
    end)
    ns.Widgets.Tooltip(r, function(self) return self.set:DisplayName() end, function(self) return STATUS[self.set:GetStatus()][5] end)
    rows[i] = r
    return r
end

function SetList:Refresh()
    if not panel then return end
    local sets = ns.Sets:List()
    local selected = ns.UI.Main:GetSelectedSet()
    for i, set in ipairs(sets) do
        local r = row(i)
        r.set = set
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, -28 - (i - 1) * 26)
        r:SetPoint("RIGHT")
        local st = STATUS[set:GetStatus()]
        r.dot:SetText(st[1])
        r.dot:SetTextColor(st[2], st[3], st[4])
        r.name:SetText(set:DisplayName() .. (set.settings.enabled and "" or (" (" .. L["off"] .. ")")))
        r.name:SetFontObject(set.settings.enabled and "GameFontHighlight" or "GameFontDisable")
        r.prio:SetText(set:IsDefault() and "" or (ns.Weights.Short(set:GetPriority()) or ""))
        r.selected:SetShown(selected == set)
        r.selected:SetVertexColor(ns.Skin:Accent())
        r:Show()
    end
    for i = #sets + 1, #rows do rows[i]:Hide() end
    rail.count:SetText(#sets)
end

function SetList:SetCollapsed(collapsed, user)
    local f = ns.UI.Main:GetFrame()
    panel:SetShown(not collapsed)
    rail:SetShown(collapsed)
    f.left:SetWidth(collapsed and 28 or 190)
    if user then ns.db.global.window.setsCollapsed = collapsed end
end

local function autoCollapse()
    local user = ns.db.global.window.setsCollapsed
    local f = ns.UI.Main:GetFrame()
    if f:GetWidth() < COLLAPSE_BELOW then return SetList:SetCollapsed(true) end
    if user ~= nil then return SetList:SetCollapsed(user) end
    SetList:SetCollapsed(#ns.Sets:List() <= 1)
end

ns:RegisterCallback(SetList, "WindowBuilt", function(_, frame)
    panel = CreateFrame("Frame", nil, frame.left)
    panel:SetAllPoints()
    local title = ns.Widgets.Label(panel, L["Sets"], "GameFontNormal")
    title:SetPoint("TOPLEFT", 6, -6)
    local collapse = CreateFrame("Button", nil, panel)
    collapse:SetSize(20, 20)
    collapse:SetPoint("TOPRIGHT", -2, -2)
    collapse:SetNormalAtlas("common-icon-backarrow")
    collapse:SetScript("OnClick", function() SetList:SetCollapsed(true, true) end)
    ns.Widgets.Tooltip(collapse, L["Collapse"])

    newBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    newBox:SetHeight(20)
    newBox:SetPoint("BOTTOMLEFT", 8, 32)
    newBox:SetPoint("BOTTOMRIGHT", -4, 32)
    newBox:SetAutoFocus(false)
    newBox:Hide()
    newBox:SetScript("OnEscapePressed", function(self) self:SetText("") self:Hide() end)
    newBox:SetScript("OnEnterPressed", function(self)
        local set, ok, err = ns.Sets:Create(self:GetText())
        if not ok then
            UIErrorsFrame:AddMessage(err, 1, 0.3, 0.3)
            PlaySound(SOUNDKIT.IG_PLAYER_INVITE_DECLINE)
            return
        end
        self:SetText("") self:Hide()
        ns.UI.Main:SelectSet(set.name)
        ns.UI.Main:SelectTab("when")
    end)
    ns.Skin:Apply("EditBox", newBox)

    local new = ns.Widgets.Button(panel, L["+ New"], function() newBox:Show() newBox:SetFocus() end)
    new:SetPoint("BOTTOMLEFT", 4, 4)
    local import = ns.Widgets.Button(panel, L["Import"], function() if ns.UI.Share then ns.UI.Share:ShowImport() end end)
    import:SetPoint("LEFT", new, "RIGHT", 4, 0)

    rail = CreateFrame("Button", nil, frame.left)
    rail:SetAllPoints()
    rail:Hide()
    rail.label = ns.Widgets.Label(rail, L["Sets"], "GameFontNormalSmall")
    rail.label:SetPoint("TOP", 0, -8)
    rail.count = ns.Widgets.Label(rail, "", "GameFontHighlightSmall")
    rail.count:SetPoint("TOP", rail.label, "BOTTOM", 0, -4)
    rail:SetScript("OnClick", function() SetList:SetCollapsed(false, true) end)
    ns.Widgets.Tooltip(rail, L["Show sets"])
    autoCollapse()
end)

local refresh = function() SetList:Refresh() end
for _, cb in ipairs({ "SetsChanged", "CurrentSetChanged", "ConditionStateChanged", "SelectedSetChanged", "PetsChanged", "WindowShown" }) do
    ns:RegisterCallback(SetList, cb, refresh)
end
ns:RegisterCallback(SetList, "WindowResized", autoCollapse)
ns.Skin:OnLooksChanged(function() SetList:Refresh() end)
