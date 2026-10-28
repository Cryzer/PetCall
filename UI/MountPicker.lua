local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Picker = {}
ns.UI.MountPicker = Picker

-- A window for the Mount condition: the whole collection in one column, ticked for the
-- condition, with search, a filter and a preview of the mount pointed at. It belongs to
-- one condition and closes whenever that condition is out of sight.

local ROW_H = 26
local KINDS = ns.Conditions.MOUNT_KINDS

local win, list, scrollBox, preview, count
local entry, onChange          -- the condition being edited and what to call when it changes
local current                  -- the mount in the preview: the first one, then the last one pointed at
local visible = {}             -- the mounts the list shows now
local state = { search = "", hiddenKinds = {}, hiddenSources = {} }   -- kept while the session lasts

local function chosen(id)
    for _, x in ipairs(entry and entry.mountIDs or {}) do if x == id then return true end end
    return false
end

-- the mounts of `all` the filter lets through; `isChosen(id)` for "chosen only"
function Picker.Filter(all, st, isChosen)
    local out, needle = {}, strlower(st.search or "")
    for _, m in ipairs(all) do
        local ok = needle == "" or strlower(m.name):find(needle, 1, true) ~= nil
        if ok and st.chosenOnly and not isChosen(m.id) then ok = false end
        if ok and st.favoritesOnly and not m.favorite then ok = false end
        if ok and st.usableOnly and not m.usable then ok = false end
        if ok and st.hiddenSources[m.source] then ok = false end
        if ok and next(st.hiddenKinds) and next(m.kinds) then
            -- a mount that both flies and swims stays while one of its kinds is shown;
            -- one the journal put in no kind is never hidden by them
            local any = false
            for _, k in ipairs(KINDS) do if m.kinds[k.key] and not st.hiddenKinds[k.key] then any = true end end
            ok = any
        end
        if ok then out[#out + 1] = m end
    end
    return out
end

local function toggle(id)
    entry.mountIDs = entry.mountIDs or {}
    local found
    for i, x in ipairs(entry.mountIDs) do if x == id then found = i end end
    if found then table.remove(entry.mountIDs, found) else entry.mountIDs[#entry.mountIDs + 1] = id end
    if onChange then onChange() end
    Picker:Redraw()
end
Picker.Toggle = function(_, id) toggle(id) end

-- ticks (or unticks) every mount the list shows now, as one change
function Picker:TickShown(on)
    entry.mountIDs = entry.mountIDs or {}
    local keep = {}
    for _, m in ipairs(visible) do keep[m.id] = on end
    local out = {}
    for _, id in ipairs(entry.mountIDs) do if keep[id] == nil then out[#out + 1] = id end end
    if on then for _, m in ipairs(visible) do out[#out + 1] = m.id end end
    wipe(entry.mountIDs)
    for i, id in ipairs(out) do entry.mountIDs[i] = id end
    if onChange then onChange() end
    self:Redraw()
end

local function showMount(m)
    if not m then
        preview.empty:Show()
        preview.name:SetText("")
        preview.source:SetText("")
        if preview.actor then preview.actor:ClearModel() elseif preview.model.ClearModel then preview.model:ClearModel() end
        return
    end
    preview.empty:Hide()
    preview.name:SetText(m.name)
    local display, _, sourceText, _, _, sceneID = C_MountJournal.GetMountInfoExtraByID(m.id)
    if not display or display == 0 then
        local all = C_MountJournal.GetMountAllCreatureDisplayInfoByID and C_MountJournal.GetMountAllCreatureDisplayInfoByID(m.id)
        display = all and all[1] and all[1].creatureDisplayID
    end
    preview.source:SetText(sourceText or "")
    if preview.scene then
        preview.model:TransitionToModelSceneID(sceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
        preview.actor = preview.model:GetActorByTag("unwrapped")
        if preview.actor and display then preview.actor:SetModelByCreatureDisplayID(display, true) end
        -- the journal's scenes seat the player on the mount; here the mount stands alone
        local rider = preview.model:GetActorByTag("player-rider")
        if rider then rider:ClearModel() end
    elseif display then
        preview.model:SetDisplayInfo(display)
    end
end

-- the preview stays on the mount pointed at last
local function previewMount(m)
    current = m
    showMount(m)
end

local function initRow(row, m)
    if not row.check then
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(22, 22)
        row.check:SetPoint("LEFT", 2, 0)
        ns.Skin:Apply("Checkbox", row.check)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
        row.text = ns.Widgets.Label(row, "")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.text:SetPoint("RIGHT", -6, 0)
        row.text:SetWordWrap(false)
        row.check:SetScript("OnClick", function(self)
            PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            toggle(self:GetParent().mount.id)
        end)
        -- a click anywhere on the row ticks it too
        row:SetScript("OnClick", function(self) self.check:Click() end)
        row:SetScript("OnEnter", function(self) if current ~= self.mount then previewMount(self.mount) end end)
    end
    row.mount = m
    row.icon:SetTexture(m.icon)
    row.text:SetText(m.name)
    row.check:SetChecked(chosen(m.id))
end

local function filterMenu(_, root)
    local function check(text, get, set) root:CreateCheckbox(text, get, function() set() Picker:Redraw() end) end
    check(L["Chosen only"], function() return state.chosenOnly end, function() state.chosenOnly = not state.chosenOnly end)
    check(L["Favorites only"], function() return state.favoritesOnly end, function() state.favoritesOnly = not state.favoritesOnly end)
    check(L["Usable here"], function() return state.usableOnly end, function() state.usableOnly = not state.usableOnly end)
    root:CreateTitle(L["Type"])
    for _, k in ipairs(KINDS) do
        check(k.label, function() return not state.hiddenKinds[k.key] end,
            function() state.hiddenKinds[k.key] = not state.hiddenKinds[k.key] or nil end)
    end
    local sources = root:CreateButton(L["Sources"])
    for i = 1, C_PetJournal.GetNumPetSources and C_PetJournal.GetNumPetSources() or 0 do
        local label = _G["BATTLE_PET_SOURCE_" .. i]
        if label then
            sources:CreateCheckbox(label, function() return not state.hiddenSources[i] end,
                function() state.hiddenSources[i] = not state.hiddenSources[i] or nil Picker:Redraw() end)
        end
    end
    root:CreateDivider()
    root:CreateButton(L["Tick all shown"], function() Picker:TickShown(true) end)
    root:CreateButton(L["Untick all shown"], function() Picker:TickShown(false) end)
    root:CreateDivider()
    root:CreateButton(L["Reset filters"], function()
        state.chosenOnly, state.favoritesOnly, state.usableOnly = nil, nil, nil
        wipe(state.hiddenKinds) wipe(state.hiddenSources)
        Picker:Redraw()
    end)
end

local function build()
    win = CreateFrame("Frame", "PetCallMountPicker", UIParent, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(win)
    ButtonFrameTemplate_HideButtonBar(win)
    win:SetTitle(L["Choose mounts"])
    win:SetSize(600, 500)
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetScript("OnHide", function()
        entry, onChange, current = nil, nil, nil
        ns.UI.Help:HidePicker()
    end)
    tinsert(UISpecialFrames, "PetCallMountPicker")
    ns.Skin:Apply("Shell", win)
    ns.Skin:Apply("CloseButton", win.CloseButton)
    ns.Skin:Apply("Inset", win.Inset)
    local inset = win.Inset
    win.helpButton = ns.UI.Help.NewButton(win, function() ns.UI.Help:TogglePicker(win) end)
    win.helpButton:SetPoint("CENTER", win, "TOPLEFT", 16, -11)
    win.helpButton:SetFrameLevel(win.CloseButton:GetFrameLevel())

    -- over everything, the whole width: the condition does nothing while PetCall waits
    -- for you to dismount
    local warn = CreateFrame("Frame", nil, inset)
    warn:SetPoint("TOPLEFT", 6, -6)
    warn:SetPoint("TOPRIGHT", -6, -6)
    warn:SetHeight(36)
    warn.bg = warn:CreateTexture(nil, "BACKGROUND")
    warn.bg:SetAllPoints()
    warn.bg:SetColorTexture(1, 0.82, 0, 0.12)
    warn.edge = warn:CreateTexture(nil, "ARTWORK")
    warn.edge:SetPoint("TOPLEFT")
    warn.edge:SetPoint("BOTTOMLEFT")
    warn.edge:SetWidth(3)
    warn.edge:SetColorTexture(1, 0.82, 0, 1)
    warn.button = ns.Widgets.Button(warn, L["Turn it off"], function()
        ns.db.profile.noSummonMounted = false
        ns.Ready:UpdateChecks()
        Picker:PaintWarning()
    end)
    warn.button:SetPoint("RIGHT", -6, 0)
    warn.text = ns.Widgets.Label(warn, L["\"Don't summon while mounted\" is on, so PetCall waits until you dismount and these mounts change nothing. Turn it off?"], "GameFontHighlightSmall")
    warn.text:SetTextColor(1, 0.82, 0)
    warn.text:SetPoint("LEFT", 12, 0)
    warn.text:SetPoint("RIGHT", warn.button, "LEFT", -8, 0)
    warn.text:SetWordWrap(true)
    win.warn = warn

    -- the rest: search and list on the left, the preview on the right; it starts under
    -- the warning while that shows
    local body = CreateFrame("Frame", nil, inset)
    body:SetPoint("BOTTOMRIGHT", -6, 40)
    win.body = body

    local search = ns.Widgets.Search(body, function(text) state.search = text Picker:Redraw() end)
    search:SetPoint("TOPLEFT", 6, -2)
    search:SetWidth(200)
    win.search = search
    local filterBtn = CreateFrame("DropdownButton", nil, body, "WowStyle1FilterDropdownTemplate")
    filterBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)
    filterBtn:SetupMenu(filterMenu)
    ns.Skin:Apply("Dropdown", filterBtn)
    win.filterBtn = filterBtn

    preview = ns.Widgets.Inset(body)
    preview:SetPoint("TOPRIGHT")
    preview:SetPoint("BOTTOMRIGHT")
    preview:SetWidth(250)
    win.preview = preview
    local useScene = C_XMLUtil and C_XMLUtil.GetTemplateInfo and C_XMLUtil.GetTemplateInfo("WrappedAndUnwrappedModelScene") ~= nil
    preview.scene = useScene
    preview.model = CreateFrame(useScene and "ModelScene" or "PlayerModel", nil, preview, useScene and "WrappedAndUnwrappedModelScene" or nil)
    -- the model fills the panel, as in the Mount Journal; name and source sit over its foot
    preview.model:SetPoint("TOPLEFT", 4, -4)
    preview.model:SetPoint("BOTTOMRIGHT", -4, 4)
    preview.source = ns.Widgets.Label(preview, "", "GameFontHighlightSmall")
    preview.source:SetPoint("BOTTOMLEFT", 10, 10)
    preview.source:SetPoint("RIGHT", -10, 0)
    preview.source:SetWordWrap(true)
    preview.name = ns.Widgets.Label(preview, "", "GameFontNormal")
    preview.name:SetPoint("BOTTOMLEFT", preview.source, "TOPLEFT", 0, 4)
    preview.name:SetPoint("RIGHT", -10, 0)
    preview.empty = ns.Widgets.Label(preview, L["Point at a mount to see it."], "GameFontDisableSmall")
    preview.empty:SetPoint("CENTER", preview.model, "CENTER")

    scrollBox = CreateFrame("Frame", nil, body, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -6, -6)
    scrollBox:SetPoint("BOTTOMRIGHT", preview, "BOTTOMLEFT", -24, 0)
    win.list = scrollBox
    local bar = CreateFrame("EventFrame", nil, body, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(ROW_H)
    view:SetElementInitializer("Button", initRow)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, bar, view)
    ns.Skin:Apply("ScrollBar", bar)

    count = ns.Widgets.Label(inset, "", "GameFontHighlightSmall")
    count:SetPoint("BOTTOMLEFT", 12, 14)
    local done = ns.Widgets.Button(inset, L["Done"], function() win:Hide() end)
    done:SetPoint("BOTTOMRIGHT", -8, 8)
    win.count, win.done = count, done
end

function Picker:Redraw()
    if not win or not win:IsShown() then return end
    visible = Picker.Filter(list, state, chosen)
    scrollBox:SetDataProvider(CreateDataProvider(visible), ScrollBoxConstants.RetainScrollPosition)
    count:SetText(format(L["%d chosen · %d shown"], #(entry.mountIDs or {}), #visible))
end

-- opens for one Mount condition next to `anchor` (the PetCall window); onChanged runs after each tick
function Picker:Open(e, anchor, onChanged)
    if not win then build() end
    entry, onChange, current = e, onChanged, nil
    list = ns.Conditions.CollectedMounts()
    win:SetScale(ns.db.global.window.scale or 1)
    win:ClearAllPoints()
    if anchor then win:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 0) else win:SetPoint("CENTER") end
    win:Show()
    self:PaintWarning()
    self:Redraw()
    previewMount(visible[1])
end

-- the warning shows while "Don't summon while mounted" is on; the rest moves under it
function Picker:PaintWarning()
    if not win then return end
    local on = ns.db.profile.noSummonMounted and true or false
    win.warn:SetShown(on)
    win.body:ClearAllPoints()
    win.body:SetPoint("BOTTOMRIGHT", -6, 40)
    if on then win.body:SetPoint("TOPLEFT", win.warn, "BOTTOMLEFT", 0, -8) else win.body:SetPoint("TOPLEFT", 6, -8) end
end

function Picker:Close() if win then win:Hide() end end
function Picker:IsShown() return win ~= nil and win:IsShown() end
function Picker:GetPreviewed() return current end

-- the When tab drew its conditions again: close unless ours is still among them
function Picker:CloseIfGone(present)
    if self:IsShown() and not present[entry] then self:Close() end
end

ns:RegisterCallback(Picker, "WindowHidden", function() Picker:Close() end)
ns:RegisterCallback(Picker, "SelectedSetChanged", function() Picker:Close() end)
