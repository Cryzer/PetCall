local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local SetList = {}
ns.UI.SetList = SetList

local COLLAPSE_BELOW = 700
local panel, rail, rows, newBox, nowCard = nil, nil, {}, nil, nil
SetList._rows = rows      -- for tests
local RAIL_W, PANEL_W = 34, 190
local collapsedNow = false
local function pauseMenu(root, set)
    root:CreateButton(L["Pause"], function() set:Pause() end)
    root:CreateButton(L["Pause for 1 hour"], function() set:Pause("hour") end)
    root:CreateButton(L["Pause until logout"], function() set:Pause("session") end)
end
SetList.PauseMenu = pauseMenu

local function setMenu(owner, root, set)
    if set:IsPaused() then
        root:CreateButton(L["Resume"], function() set:Resume() end)
    else
        pauseMenu(root:CreateButton(L["Pause"]), set)
    end
    if not set:IsDefault() then
        root:CreateButton(L["Move up"], function() ns.Sets:Move(set, -1) end)
        root:CreateButton(L["Move down"], function() ns.Sets:Move(set, 1) end)
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

local CARD_H = 42
local FALLBACK_ICON = "Interface\\Icons\\Tracking_WildPet"

-- the pet a set is most likely to summon stands for the set
local function setIcon(set)
    local tbl, sums, best, bestW = set:GetWeightTable(), {}, nil, 0
    for i = 1, #tbl, 2 do
        local id = tbl[i + 1]
        sums[id] = (sums[id] or 0) + tbl[i]
        if sums[id] > bestW then best, bestW = id, sums[id] end
    end
    local info = best and ns.PetCache:GetInfo(best)
    return info and info.icon or FALLBACK_ICON
end

-- one line in words: what the set is doing right now
local function stateLine(set)
    local status = set:GetStatus()
    if status == "active" then
        return format("|cff4cd964%s|r · %s", L["Active now"], format(L["%d pets"], (ns.UI.SetHeader.Counts(set))))
    elseif status == "paused" then
        return "|cff808080" .. ns.UI.SetHeader.PauseText(set) .. "|r"
    elseif status == "empty" then
        return "|cffff9933" .. L["No pets to choose from"] .. "|r"
    elseif set:IsDefault() then
        return "|cff9d9d9d" .. L["When nothing else fits"] .. "|r"
    elseif status == "outranked" then
        return "|cff7fa8e0" .. ns.UI.SetHeader.OutrankedText(set) .. "|r"
    end
    local states = set:GetConditionStates()
    for _, g in ipairs(set:GetConditionModel().groups) do
        for _, e in ipairs(g.rows) do
            local st = states[e]
            if st and not st.value then return "|cff9d9d9d" .. format(L["Waiting for: %s"], ns.Conditions.Describe(e)) .. "|r" end
        end
    end
    return "|cff9d9d9d" .. L["Conditions not met"] .. "|r"
end

local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, panel)
    r:SetHeight(CARD_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetHighlightAtlas("PetList-ButtonHighlight", "ADD")
    r.bg = r:CreateTexture(nil, "BACKGROUND", nil, -2)
    r.bg:SetAllPoints()
    r.bg:SetAtlas("PetList-ButtonBackground")
    r.selected = r:CreateTexture(nil, "BACKGROUND")
    r.selected:SetAllPoints()
    r.selected:SetAtlas("PetList-ButtonSelect")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(32, 32)
    r.icon:SetPoint("LEFT", 5, 0)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 7, -2)
    r.name:SetPoint("RIGHT", -24, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.state = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.state:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 7, 2)
    r.state:SetPoint("RIGHT", -6, 0)
    r.state:SetJustifyH("LEFT")
    r.state:SetWordWrap(false)
    r.prio = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.prio:SetPoint("TOPRIGHT", -6, -5)
    -- on hover: move up / down and pause, so the order and pausing are one click away
    r.controls = {}
    local function control(texture, tip, onClick)
        local b = CreateFrame("Button", nil, r)
        b:SetSize(16, 16)
        b:SetNormalTexture(texture)
        b:SetHighlightTexture(texture, "ADD")
        b:SetScript("OnClick", function(self) onClick(self) end)
        b:HookScript("OnLeave", function() if not r:IsMouseOver() then SetList.ShowControls(r, false) end end)
        ns.Widgets.Tooltip(b, tip)
        b:Hide()
        r.controls[#r.controls + 1] = b
        return b
    end
    r.up = control("Interface\\Buttons\\Arrow-Up-Up", L["Move up"], function() ns.Sets:Move(r.set, -1) end)
    r.up:SetPoint("TOPRIGHT", -3, -3)
    r.down = control("Interface\\Buttons\\Arrow-Down-Up", L["Move down"], function() ns.Sets:Move(r.set, 1) end)
    r.down:SetPoint("BOTTOMRIGHT", -3, 3)
    r.pause = control("Interface\\TimeManager\\PauseButton", L["Pause or resume"], function(self)
        if r.set:IsPaused() then r.set:Resume() return end
        MenuUtil.CreateContextMenu(self, function(_, root) pauseMenu(root, r.set) end)
    end)
    r.pause:SetPoint("RIGHT", r.up, "LEFT", -2, -8)
    r:HookScript("OnEnter", function() SetList.ShowControls(r, true) end)
    r:HookScript("OnLeave", function() if not r:IsMouseOver() then SetList.ShowControls(r, false) end end)
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MenuUtil.CreateContextMenu(self, function(o, root) setMenu(o, root, self.set) end)
        else
            ns.UI.Main:SelectSet(self.set.name)
        end
    end)
    ns.Widgets.Tooltip(r, function(self) return self.set:DisplayName() end, function(self) return stateLine(self.set) end)
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
        r:SetPoint("TOPLEFT", 4, -28 - (i - 1) * (CARD_H + 4))
        r:SetPoint("RIGHT", -4, 0)
        r.icon:SetTexture(setIcon(set))
        local paused = set:IsPaused()
        r.icon:SetDesaturated(paused)
        r.name:SetText(set:DisplayName())
        r.name:SetFontObject(paused and "GameFontDisable" or "GameFontNormal")
        r.pause:SetNormalTexture(paused and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" or "Interface\\TimeManager\\PauseButton")
        r.state:SetText(stateLine(set))
        r.prio:SetText("")
        r.selected:SetShown(selected == set)
        r.selected:SetVertexColor(ns.Skin:Accent())
        r:Show()
    end
    for i = #sets + 1, #rows do rows[i]:Hide() end
    rail.count:SetText(#sets)
end

function SetList:SetCollapsed(collapsed, user)
    local f = ns.UI.Main:GetFrame()
    collapsedNow = collapsed and true or false
    panel:SetShown(not collapsed)
    rail:SetShown(collapsed)
    f.left:SetWidth(collapsed and RAIL_W or PANEL_W)
    if user then ns.db.global.window.setsCollapsed = collapsed end
    if ns.UI.StatusBar then ns.UI.StatusBar:Refresh() end
end

local function autoCollapse()
    local user = ns.db.global.window.setsCollapsed
    local f = ns.UI.Main:GetFrame()
    if f:GetWidth() < COLLAPSE_BELOW then return SetList:SetCollapsed(true) end
    -- open unless the player closed it: with one set the panel still offers + New and Import
    SetList:SetCollapsed(user == true)
end

function SetList:IsCollapsed() return collapsedNow end

-- arrows only where a move is possible; the default set has none
function SetList.ShowControls(r, on)
    local set = r.set
    if not set then return end
    local rank, n = set:GetRank()
    r.pause:SetShown(on)
    r.up:SetShown(on and not set:IsDefault() and rank > 1)
    r.down:SetShown(on and not set:IsDefault() and rank < n - 1)
end

-- the pet that is out right now, large, at the foot of the sets panel
function SetList:RefreshNow(blockers)
    if not nowCard then return end
    local pet = ns:GetCurrentPet()
    local info = pet and ns.PetCache:GetInfo(pet)
    local set = ns.Sets:GetCurrent()
    nowCard.petID, nowCard.setName = info and pet or nil, set and set.name
    if info then
        local r, g, b = ns.Widgets.QualityColor(info.quality)
        nowCard.icon:SetTexture(info.icon)
        nowCard.icon:SetDesaturated(false)
        nowCard.border:SetVertexColor(r, g, b)
        nowCard.border:Show()
        nowCard.name:SetText(info.customName or info.name)
        nowCard.name:SetTextColor(r, g, b)
        nowCard.from:SetText(format(L["from %s"], set and set:DisplayName() or NONE))
    else
        nowCard.icon:SetTexture("Interface\\Icons\\Tracking_WildPet")
        nowCard.icon:SetDesaturated(true)
        nowCard.border:Hide()
        nowCard.name:SetText(L["No pet out"])
        nowCard.name:SetTextColor(0.6, 0.6, 0.6)
        nowCard.from:SetText(set and format(L["next from %s"], set:DisplayName()) or "")
    end
    blockers = blockers or ns.Ready:GetBlockers()
    if #blockers == 0 then
        nowCard.state:SetText("|cff4cd964" .. L["Ready"] .. "|r")
    else
        nowCard.state:SetText("|cffffb040" .. format(L["Paused: %s"], blockers[1].label) .. "|r")
    end
end

local function buildNowCard()
    local c = CreateFrame("Button", nil, panel)
    c:SetHeight(62)
    c:SetPoint("BOTTOMLEFT", 4, 58)
    c:SetPoint("BOTTOMRIGHT", -4, 58)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.bg:SetAtlas("PetList-ButtonBackground")
    c:SetHighlightAtlas("PetList-ButtonHighlight", "ADD")
    c.caption = ns.Widgets.Label(panel, L["Out now"], "GameFontNormal")
    c.caption:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 2, 4)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(42, 42)
    c.icon:SetPoint("LEFT", 8, 0)
    c.border = c:CreateTexture(nil, "OVERLAY")
    c.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    c.border:SetAllPoints(c.icon)
    c.name = ns.Widgets.Label(c, "", "GameFontNormalLarge")
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, 1)
    c.name:SetPoint("RIGHT", -6, 0)
    c.name:SetWordWrap(false)
    c.from = ns.Widgets.Label(c, "", "GameFontHighlightSmall")
    c.from:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    c.from:SetPoint("RIGHT", -6, 0)
    c.from:SetWordWrap(false)
    c.state = ns.Widgets.Label(c, "", "GameFontNormalSmall")
    c.state:SetPoint("TOPLEFT", c.from, "BOTTOMLEFT", 0, -3)
    c.state:SetPoint("RIGHT", -6, 0)
    c.state:SetWordWrap(false)
    -- open the set it came from with the pet selected
    c:SetScript("OnClick", function(self)
        if not self.petID then return end
        if self.setName then ns.UI.Main:SelectSet(self.setName) end
        ns.UI.Main:SelectTab("pets")
        ns.UI.Preview:SetSelected(self.petID)
    end)
    ns.Widgets.Tooltip(c, function(self) return self.name:GetText() end, function(self)
        local lines = { self.from:GetText(), self.state:GetText() }
        if self.petID then lines[#lines + 1] = L["Click to show this pet in its set."] end
        return table.concat(lines, "\n")
    end)
    return c
end
function SetList:GetRail() return rail end

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

    local function openNameBox() newBox:Show() newBox:SetFocus() end
    SetList.OpenNew = openNameBox
    local new = ns.Widgets.Button(panel, L["+ New"], function(self)
        ns.Widgets.OpenMenuAbove(self, function(owner, root)
            root:CreateButton(L["Empty set"], openNameBox)
            root:CreateButton(L["From a recipe..."], function() ns.UI.RecipeGallery:Show() end)
        end)
    end)
    SetList._newButton = new
    new:SetPoint("BOTTOMLEFT", 4, 4)
    local import = ns.Widgets.Button(panel, L["Import"], function() if ns.UI.Share then ns.UI.Share:ShowImport() end end)
    import:SetPoint("LEFT", new, "RIGHT", 4, 0)

    nowCard = buildNowCard()
    SetList._nowCard = nowCard

    rail = CreateFrame("Button", nil, frame.left)
    rail:SetAllPoints()
    rail:Hide()
    -- looks clickable: a tinted strip, an expand arrow and a hover highlight
    rail.bg = rail:CreateTexture(nil, "BACKGROUND")
    rail.bg:SetAllPoints()
    rail.bg:SetColorTexture(1, 1, 1, 0.06)
    rail:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    rail:GetHighlightTexture():SetAlpha(0.35)
    rail.arrow = rail:CreateTexture(nil, "ARTWORK")
    rail.arrow:SetSize(20, 20)
    rail.arrow:SetPoint("TOP", 0, -6)
    rail.arrow:SetAtlas("common-icon-forwardarrow")
    rail.label = ns.Widgets.Label(rail, L["Sets"], "GameFontNormalSmall")
    rail.label:SetPoint("TOP", rail.arrow, "BOTTOM", 0, -4)
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
