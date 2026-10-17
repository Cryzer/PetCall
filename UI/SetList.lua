local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local SetList = {}
ns.UI.SetList = SetList

local COLLAPSE_BELOW = 700
local panel, rail, rows, newBox, nowCard = nil, nil, {}, nil, nil
local list, scroll = nil, 0      -- the clipped area the cards sit in, and how far it is scrolled
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
    root:CreateButton(L["Duplicate"], function()
        local copy = ns.Sets:Duplicate(set)
        if copy then ns.UI.Main:SelectSet(copy.name) end
    end)
    if ns.UI.Share then root:CreateButton(L["Export"], function() ns.UI.Share:ShowExport(set.name) end) end
    if not set:IsDefault() then
        root:CreateButton(DELETE, function()
            StaticPopup_Show("PETCALL_CONFIRM", format(L["Delete \"%s\"? This cannot be undone."], set.name), nil,
                { onAccept = function() set:Delete() end })
        end)
    end
end

local CARD_H = 42
local STEP = CARD_H + 4
local LIST_TOP = 40          -- below the title and the hint
local FOOT_H = 30            -- + New and Import
local NOW_H = 62 + 22        -- the Out now card and its caption
local FALLBACK_ICON = "Interface\\Icons\\Tracking_WildPet"

-- the pet a set is most likely to summon stands for the set
local function setIcon(set)
    local _, _, best = set:GetTileSums()
    local info = best and ns.PetCache:GetInfo(best)
    return info and info.icon or FALLBACK_ICON
end

-- one line in words: what the set is doing right now
local function stateLine(set)
    local status = set:GetStatus()
    if status == "active" then
        if set:IsNoPet() then return format("|cff4cd964%s|r · %s", L["Active now"], L["no pet"]) end
        return format("|cff4cd964%s|r · %s", L["Active now"], format(L["%d pets"], (ns.UI.SetHeader.Counts(set))))
    elseif status == "paused" then
        return "|cff808080" .. ns.UI.SetHeader.PauseText(set) .. "|r"
    elseif status == "empty" then
        return "|cffff9933" .. L["No pets to choose from"] .. "|r"
    elseif set:IsDefault() then
        return "|cff9d9d9d" .. L["When nothing else fits"] .. "|r"
    elseif status == "outranked" then
        local cur = ns.Sets:GetCurrent()
        return "|cff7fa8e0" .. format(L["Fits, behind %s"], cur and cur:DisplayName() or "?") .. "|r"
    end
    local states = set:GetConditionStates()
    for _, g in ipairs(set:GetConditionModel().groups) do
        for _, e in ipairs(g.rows) do
            local st = states[e]
            if st and not st.value then return "|cff9d9d9d" .. format(L["Waiting for: %s"], ns.Conditions.DescribeShort(e)) .. "|r" end
        end
    end
    return "|cff9d9d9d" .. L["Conditions not met"] .. "|r"
end

local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, list)
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
    r.name:SetPoint("RIGHT", -30, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.state = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.state:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 7, 2)
    r.state:SetPoint("RIGHT", -30, 0)
    r.state:SetJustifyH("LEFT")
    r.state:SetWordWrap(false)
    -- place in the list, on the icon; the default set has none (it is always last)
    r.rank = r:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    r.rank:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, -2)
    -- pause on hover; a paused set keeps its resume button in sight
    r.pause = CreateFrame("Button", nil, r)
    r.pause:SetSize(24, 24)
    r.pause:SetPoint("RIGHT", -4, 0)
    r.pause:SetFrameLevel(r:GetFrameLevel() + 2)
    r.pause:SetScript("OnClick", function(self)
        if r.set:IsPaused() then r.set:Resume() return end
        MenuUtil.CreateContextMenu(self, function(_, root) pauseMenu(root, r.set) end)
    end)
    r.pause:HookScript("OnLeave", function() SetList.PaintPause(r) end)
    ns.Widgets.Tooltip(r.pause, function() return r.set:IsPaused() and L["Resume"] or L["Pause"] end)
    r:HookScript("OnEnter", function() SetList.PaintPause(r, true) end)
    r:HookScript("OnLeave", function() SetList.PaintPause(r) end)
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnDragStart", function(self) SetList.StartDrag(self) end)
    r:SetScript("OnDragStop", function(self) SetList.StopDrag(self) end)
    r:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            MenuUtil.CreateContextMenu(self, function(o, root) setMenu(o, root, self.set) end)
        else
            ns.UI.Main:SelectSet(self.set.name)
        end
    end)
    rows[i] = r
    return r
end

function SetList:Refresh()
    if not list then return end
    local sets = ns.Sets:List()
    local selected = ns.UI.Main:GetSelectedSet()
    for i, set in ipairs(sets) do
        local r = row(i)
        r.set = set
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 4, -(i - 1) * STEP + scroll)
        r:SetPoint("RIGHT", SetList.CanScroll() and -10 or -4, 0)
        r.icon:SetTexture(setIcon(set))
        local paused = set:IsPaused()
        r.icon:SetDesaturated(paused)
        r.name:SetText(set:DisplayName())
        r.name:SetFontObject(paused and "GameFontDisable" or "GameFontNormal")
        SetList.PaintPause(r)
        r.rank:SetText(set:IsDefault() and "" or i)
        r.state:SetText(stateLine(set))
        r.selected:SetShown(selected == set)
        r.selected:SetVertexColor(ns.Skin:Accent())
        r:Show()
    end
    for i = #sets + 1, #rows do rows[i]:Hide() end
    rail.count:SetText(#sets)
    SetList:PaintScroll()
    list.canScroll = SetList.CanScroll()
end

-- Scrolling: the cards move inside the clipped list; a thin bar shows where you are.
local function contentHeight()
    local n = 0
    for _, r in ipairs(rows) do if r:IsShown() then n = n + 1 end end
    return n * STEP - 4
end
local function listHeight() return tonumber(list and list:GetHeight()) or 0 end
local function maxScroll() return math.max(0, contentHeight() - listHeight()) end
function SetList.CanScroll() return list ~= nil and maxScroll() > 0 end

function SetList:ScrollBy(dy)
    local s = math.max(0, math.min(maxScroll(), scroll + dy))
    if s == scroll then return end
    scroll = s
    self:Refresh()
end
function SetList:GetScroll() return scroll end

function SetList:PaintScroll()
    if not list then return end
    scroll = math.min(scroll, maxScroll())
    local can, h = SetList.CanScroll(), listHeight()
    list.track:SetShown(can)
    list.thumb:SetShown(can)
    if not can then return end
    local total = contentHeight()
    local th = math.max(16, h * h / total)
    list.thumb:SetHeight(th)
    list.thumb:SetPoint("TOPRIGHT", 0, -(h - th) * scroll / (total - h))
end

-- Room for the list: the Out now card goes when it would leave fewer than three cards.
local function layoutPanel()
    if not nowCard then return end
    local h = tonumber(panel:GetHeight()) or 0
    local showNow = h - LIST_TOP - FOOT_H - NOW_H >= 3 * STEP
    nowCard:SetShown(showNow)
    nowCard.caption:SetShown(showNow)
    list:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, FOOT_H + (showNow and NOW_H or 0) + 4)
    SetList:Refresh()
end
SetList.LayoutPanel = layoutPanel

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
    if not panel then return end
    local user = ns.db.global.window.setsCollapsed
    local f = ns.UI.Main:GetFrame()
    if f:GetWidth() < COLLAPSE_BELOW then return SetList:SetCollapsed(true) end
    -- open unless the player closed it: with one set the panel still offers + New and Import
    SetList:SetCollapsed(user == true)
end

function SetList:IsCollapsed() return collapsedNow end

function SetList.PaintPause(r, hover)
    local paused = r.set and r.set:IsPaused()
    local tex = paused and "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" or "Interface\\TimeManager\\PauseButton"
    r.pause:SetNormalTexture(tex)
    r.pause:SetHighlightTexture(tex, "ADD")
    r.pause:SetShown(paused or hover or r:IsMouseOver())
end

-- Drag and drop: the card is lifted and follows the cursor above the others; the
-- other cards slide apart to leave the gap where it will land. Dropping it there
-- moves the set to that place.
local function slotY(pos) return -(pos - 1) * STEP + scroll end

-- the place (1..n) for a card whose top is `top` pixels below the start of the list
function SetList.SlotFor(top, n)
    local pos = math.floor(top / STEP + 0.5) + 1
    return math.max(1, math.min(n, pos))
end

local drag      -- { row, others, n, from, grab, slot }

local function orderRows()
    local out = {}
    for _, r in ipairs(rows) do if r:IsShown() and r.set and not r.set:IsDefault() then out[#out + 1] = r end end
    return out
end

-- how far below the top of the list's content (scrolled away part included) the cursor is
local function cursorBelowTop()
    local _, y = GetCursorPosition()
    return (list:GetTop() or 0) - y / list:GetEffectiveScale() + scroll
end

local function place(r, y)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 4, y)
    r:SetPoint("RIGHT", -4, 0)
end

local function follow()
    -- held near the edge of a long list: scroll it along
    local _, y = GetCursorPosition()
    y = y / list:GetEffectiveScale()
    if y > (list:GetTop() or 0) - 12 then scroll = math.max(0, scroll - 4)
    elseif y < (list:GetBottom() or 0) + 12 then scroll = math.min(maxScroll(), scroll + 4) end
    local top = cursorBelowTop() - drag.grab
    top = math.max(0, math.min((drag.n - 1) * STEP, top))
    place(drag.row, -top + scroll)
    drag.slot = SetList.SlotFor(top, drag.n)
    local pos = 1
    for _, r in ipairs(drag.others) do
        if pos == drag.slot then pos = pos + 1 end
        place(r, slotY(pos))
        pos = pos + 1
    end
end

function SetList.StartDrag(r)
    if not r.set or r.set:IsDefault() then return end
    local order = orderRows()
    drag = { row = r, others = {}, n = #order }
    for k, x in ipairs(order) do
        if x == r then drag.from = k else drag.others[#drag.others + 1] = x end
    end
    drag.slot = drag.from
    -- where on the card it was picked up, so it does not jump to the cursor
    drag.grab = cursorBelowTop() - ((list:GetTop() or 0) - (r:GetTop() or 0) + scroll)
    r:SetFrameLevel(list:GetFrameLevel() + 20)
    r:LockHighlight()
    r.selected:Show()
    list:SetScript("OnUpdate", follow)
end

function SetList.StopDrag(r)
    if not drag or drag.row ~= r then return end
    local slot, from = drag.slot, drag.from
    drag = nil
    list:SetScript("OnUpdate", nil)
    r:UnlockHighlight()
    r:SetFrameLevel(list:GetFrameLevel() + 1)
    -- MoveTo counts places with the card still in its old one
    ns.Sets:MoveTo(r.set, slot > from and slot + 1 or slot)
    SetList:Refresh()
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
    c:SetPoint("BOTTOMLEFT", 4, FOOT_H + 4)
    c:SetPoint("BOTTOMRIGHT", -4, FOOT_H + 4)
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
    local hint = ns.Widgets.Label(panel, L["The top one that fits is used. Drag to reorder."], "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    hint:SetPoint("RIGHT", -6, 0)
    hint:SetWordWrap(false)
    local collapse = CreateFrame("Button", nil, panel)
    collapse:SetSize(20, 20)
    collapse:SetPoint("TOPRIGHT", -2, -2)
    collapse:SetNormalAtlas("common-icon-backarrow")
    collapse:SetScript("OnClick", function() SetList:SetCollapsed(true, true) end)
    ns.Widgets.Tooltip(collapse, L["Collapse"])

    list = CreateFrame("Frame", nil, panel)
    list:SetPoint("TOPLEFT", 0, -LIST_TOP)
    list:SetPoint("BOTTOMRIGHT", 0, FOOT_H + NOW_H + 4)
    list:SetClipsChildren(true)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) SetList:ScrollBy(-delta * STEP) end)
    -- a new height only moves the scroll bar; the cards are redrawn only when the
    -- scroll position or the room for the bar changes, not on every step of a resize
    list:SetScript("OnSizeChanged", function()
        local could, was = list.canScroll, scroll
        SetList:PaintScroll()
        if SetList.CanScroll() ~= could or scroll ~= was then SetList:Refresh() end
    end)
    list.track = list:CreateTexture(nil, "BACKGROUND")
    list.track:SetColorTexture(1, 1, 1, 0.06)
    list.track:SetPoint("TOPRIGHT")
    list.track:SetPoint("BOTTOMRIGHT")
    list.track:SetWidth(4)
    list.thumb = list:CreateTexture(nil, "ARTWORK")
    list.thumb:SetColorTexture(1, 1, 1, 0.35)
    list.thumb:SetWidth(4)
    SetList._list = list

    -- naming a new set: a popover above "+ New", on the window so no card covers it
    newBox = CreateFrame("Frame", nil, frame, "TooltipBackdropTemplate")
    newBox:SetSize(PANEL_W + 40, 86)
    newBox:SetFrameStrata("DIALOG")
    newBox:SetToplevel(true)
    newBox:EnableMouse(true)
    newBox:Hide()
    ns.Skin:Apply("Panel", newBox)
    newBox.title = ns.Widgets.Label(newBox, L["Name the new set"], "GameFontNormal")
    newBox.title:SetPoint("TOPLEFT", 12, -10)
    newBox.edit = CreateFrame("EditBox", nil, newBox, "InputBoxTemplate")
    newBox.edit:SetHeight(20)
    newBox.edit:SetPoint("TOPLEFT", newBox.title, "BOTTOMLEFT", 4, -6)
    newBox.edit:SetPoint("RIGHT", -12, 0)
    newBox.edit:SetAutoFocus(false)
    ns.Skin:Apply("EditBox", newBox.edit)
    local function closeNameBox() newBox.edit:SetText("") newBox.edit:ClearFocus() newBox:Hide() end
    local function create()
        local set, ok, err = ns.Sets:Create(newBox.edit:GetText())
        if not ok then
            UIErrorsFrame:AddMessage(err, 1, 0.3, 0.3)
            PlaySound(SOUNDKIT.IG_PLAYER_INVITE_DECLINE)
            return
        end
        closeNameBox()
        ns.UI.Main:SelectSet(set.name)
        ns.UI.Main:SelectTab("when")
    end
    newBox.edit:SetScript("OnEscapePressed", closeNameBox)
    newBox.edit:SetScript("OnEnterPressed", create)
    newBox.create = ns.Widgets.Button(newBox, L["Create"], create)
    newBox.create:SetWidth(80)
    newBox.create:SetPoint("BOTTOMRIGHT", -12, 10)
    newBox.cancel = ns.Widgets.Button(newBox, L["Cancel"], closeNameBox)
    newBox.cancel:SetWidth(80)
    newBox.cancel:SetPoint("RIGHT", newBox.create, "LEFT", -6, 0)
    newBox:SetScript("OnHide", function() newBox.edit:ClearFocus() end)
    SetList._nameBox = newBox

    local function openNameBox()
        newBox:ClearAllPoints()
        newBox:SetPoint("BOTTOMLEFT", SetList._newButton, "TOPLEFT", 0, 6)
        newBox:Show()
        newBox.edit:SetFocus()
    end
    SetList.OpenNew = openNameBox
    local new = ns.Widgets.Button(panel, L["+ New"], function(self)
        ns.Widgets.OpenMenuAbove(self, function(owner, root)
            root:CreateButton(L["Empty set"], openNameBox)
            root:CreateButton(L["From a template..."], function() ns.UI.RecipeGallery:Show() end)
        end)
    end)
    SetList._newButton = new
    new:SetPoint("BOTTOMLEFT", 4, 4)
    local import = ns.Widgets.Button(panel, L["Import"], function() if ns.UI.Share then ns.UI.Share:ShowImport() end end)
    import:SetPoint("LEFT", new, "RIGHT", 4, 0)

    nowCard = buildNowCard()
    SetList._nowCard = nowCard
    panel:SetScript("OnSizeChanged", layoutPanel)
    -- changes made while it was hidden (window closed, panel folded) are drawn now
    panel:SetScript("OnShow", function() SetList:Refresh() end)

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
    layoutPanel()
    autoCollapse()
end)

-- Each card works out its pets from the set's draw table, so redraws are batched
-- and skipped while nobody can see the panel; showing it catches up (OnShow, WindowShown).
local refresh = ns.Debounce(0.05, function()
    if panel and panel:IsVisible() then SetList:Refresh() end
end)
for _, cb in ipairs({ "SetsChanged", "CurrentSetChanged", "ConditionStateChanged", "SelectedSetChanged", "PetsChanged", "WindowShown" }) do
    ns:RegisterCallback(SetList, cb, refresh)
end
ns:RegisterCallback(SetList, "WindowResized", autoCollapse)
ns.Skin:OnLooksChanged(function() SetList:Refresh() end)
