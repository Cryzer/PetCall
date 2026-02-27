
local addon_name, addon = ...

local module = addon:NewModule("Broker", "AceEvent-3.0")

local LDB = LibStub("LibDataBroker-1.1", true)
local LibPetJournal = LibStub("LibPetJournal-2.0")
local L	= LibStub("AceLocale-3.0"):GetLocale("PetCall")

local _G = _G
local assert, C_PetJournal, ceil, floor, format, hooksecurefunc,
    IsControlKeyDown, string, tinsert, wipe
    = assert, C_PetJournal, ceil, floor, format, hooksecurefunc,
    IsControlKeyDown, string, tinsert, wipe
local sort = table.sort

-- 3D model preview for broker panel (created lazily on first hover)
local brokerPreviewObj

local function rightRow_OnLeave(rowFrame)
    if not brokerPreviewObj then return end
    -- Same guard as the Options list: skip the hide if a different row is already
    -- the active anchor (e.g. script reassignment during FillRightPane fired a
    -- stale OnLeave after ShowForCreature had already moved to a new row).
    if not brokerPreviewObj.hoverFrame or brokerPreviewObj.hoverFrame == rowFrame then
        brokerPreviewObj:ScheduleHide()
    end
end

--
--
--

-- forward declarations (BrokerMenu_PetRangeString assigned below, after helpers)
local BrokerMenu_PetRangeString
local BuildPageList

function module:OnInitialize()
    if not LDB then
        return
    end

    self.broker = LDB:NewDataObject("PetCall", {
        label = "PetCall",
        type = "launcher",
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01",
        iconR = 1,
        iconG = addon:IsEnabledSummoning() and 1 or 0.3,
        iconB = addon:IsEnabledSummoning() and 1 or 0.3,
        OnClick = function(...) self:Broker_OnClick(...) end,
        OnTooltipShow = function(...) self:Broker_OnTooltipShow(...) end
    })

    LibStub("LibDBIcon-1.0"):Register("PetCall", self.broker, addon.db.profile.minimap)

    self:RegisterMessage("PetCall-EnableState", "OnEnableState")
end

function module:InitializeDropDown()
    self.sorted_petlist = {}
    LibPetJournal.RegisterCallback(self, "PetsUpdated")
    hooksecurefunc(C_PetJournal, "SetCustomName", function() self:PetsUpdated() end)
    self.InitializeDropDown = function() end
end

function module:PetsUpdated()
    wipe(self.sorted_petlist)
    -- close panel if open — data is stale
    if self.bp and self.bp:IsShown() then
        self.bp:Hide()
    end
end

local pet_sort_names = {}

function module:LoadSortPets()
    assert(#self.sorted_petlist == 0)
    for _, petid in LibPetJournal:IteratePetIDs() do
        tinsert(self.sorted_petlist, petid)
        pet_sort_names[petid] = addon:GetPetName(petid)
    end
    sort(self.sorted_petlist, function(ida, idb)
        return pet_sort_names[ida] < pet_sort_names[idb]
    end)
    wipe(pet_sort_names)
end

function module:OnEnableState(event, state)
    local notR = state and 1 or 0.3
    self.broker.iconG = notR
    self.broker.iconB = notR
end

function module:Broker_OnTooltipShow(tt)
    tt:AddLine("PetCall")
    tt:AddLine(" ")
    tt:AddDoubleLine(("|cffeeeeee%s|r "):format(L["Auto Summon:"]),
                    addon:IsEnabledSummoning() and ("|cff00ff00%s|r"):format(L["Enabled"])
                                                or ("|cffff0000%s|r"):format(L["Disabled"]))

    local curpetID = C_PetJournal.GetSummonedPetGUID()
    if curpetID ~= 0 and curpetID ~= nil then
        local name = addon:GetPetName(curpetID)
        tt:AddDoubleLine(format("|cffeeeeee%s|r ", L["Current Pet:"]),
                         format("|cffeeeeee%s|r", name))
    end

    local set = addon:GetCurrentSet()
    if set then
        tt:AddDoubleLine(format("|cffeeeeee%s|r ", L["Active Set:"]),
                         format("|cffeeeeee%s|r", set.name))
    end

    tt:AddLine(" ")
    tt:AddLine(("|cff69b950%s|r |cffeeeeee%s|r"):format(L["Left-Click:"], L["Toggle Non-Combat Pet"]))
    tt:AddLine(("|cff69b950%s|r |cffeeeeee%s|r"):format(L["Right-Click:"], L["Pet Menu"]))
    tt:AddLine(("|cff69b950%s|r |cffeeeeee%s|r"):format(L["Ctrl + Click:"], L["Open Configuration Panel"]))

    tt:AddLine(" ")

    local numpets = LibPetJournal:NumPets()
    if numpets > 0 then
        tt:AddLine(("|cff00ff00%s|r"):format(L["You have %d pets"]:format(numpets)))
    else
        tt:AddLine(("|cff00ff00%s|r"):format(L["You have no pets"]))
    end
end

-- Panel layout constants
local BP_W, BP_H    = 360, 340
local BP_ROW_H      = 24
local BP_TITLE_H    = 22
local BP_PANE_W     = 166
local BP_LEFT_X     = 6
local BP_RIGHT_X    = 188   -- BP_W - BP_PANE_W - 6
local BP_PANE_H     = BP_H - BP_TITLE_H - 8
local BP_MAX_ROWS   = 13    -- ceil(BP_PANE_H / BP_ROW_H)

function module:CreateBrokerPanel()
    -- Transparent full-screen catcher: click outside panel → close it
    local catcher = CreateFrame("Frame", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN")
    catcher:EnableMouse(true)
    catcher:Hide()
    catcher:SetScript("OnMouseDown", function()
        self.bp:Hide()
    end)

    -- Main panel
    local panel = CreateFrame("Frame", "PetCallBrokerPanel", UIParent, "BackdropTemplate")
    panel:SetSize(BP_W, BP_H)
    panel:SetFrameStrata("FULLSCREEN_DIALOG")  -- above catcher
    panel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    panel:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    panel:Hide()

    -- Title (top-left)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -7)

    -- Vertical divider between the two panes
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    divider:SetSize(1, BP_PANE_H)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", BP_RIGHT_X - 5, -(BP_TITLE_H + 3))

    -- Helper: create a scrollable pane (clips children, accepts mousewheel)
    local function MakePane(xOff)
        local f = CreateFrame("Frame", nil, panel)
        f:SetPoint("TOPLEFT", panel, "TOPLEFT", xOff, -(BP_TITLE_H + 3))
        f:SetSize(BP_PANE_W, BP_PANE_H)
        f:SetClipsChildren(true)
        f:EnableMouseWheel(true)
        return f
    end

    local leftPane  = MakePane(BP_LEFT_X)
    local rightPane = MakePane(BP_RIGHT_X)

    -- Helper: create page-range rows for left pane (text + arrow)
    local function MakeLeftRows(pane)
        local rows = {}
        for i = 1, BP_MAX_ROWS do
            local row = CreateFrame("Frame", nil, pane)
            row:SetSize(BP_PANE_W, BP_ROW_H)
            row:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(i - 1) * BP_ROW_H)
            row:EnableMouse(true)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")

            local arrow = row:CreateTexture(nil, "ARTWORK")
            arrow:SetSize(16, 16)
            arrow:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")

            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("TOPLEFT",     row, "TOPLEFT",     3, -4)
            lbl:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -20, 4)
            lbl:SetJustifyH("LEFT")
            lbl:SetWordWrap(false)

            row.lbl   = lbl
            row.arrow = arrow
            rows[i] = row
        end
        return rows
    end

    -- Helper: create pet rows for right pane (icon + name)
    local function MakeRightRows(pane)
        local rows = {}
        for i = 1, BP_MAX_ROWS do
            local row = CreateFrame("Frame", nil, pane)
            row:SetSize(BP_PANE_W, BP_ROW_H)
            row:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(i - 1) * BP_ROW_H)
            row:EnableMouse(true)

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")

            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(BP_ROW_H - 4, BP_ROW_H - 4)
            icon:SetPoint("LEFT", row, "LEFT", 2, 0)

            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetPoint("LEFT",  icon, "RIGHT", 3, 0)
            lbl:SetPoint("RIGHT", row,  "RIGHT", -2, 0)
            lbl:SetJustifyH("LEFT")
            lbl:SetWordWrap(false)

            row.icon = icon
            row.lbl  = lbl
            rows[i] = row
        end
        return rows
    end

    local leftRows  = MakeLeftRows(leftPane)
    local rightRows = MakeRightRows(rightPane)

    -- Mousewheel: scroll left pane
    leftPane:SetScript("OnMouseWheel", function(_, delta)
        local maxOff = math.max(0, #(self.bp_pages or {}) - BP_MAX_ROWS)
        self.bp_left_offset = math.max(0, math.min(self.bp_left_offset - delta, maxOff))
        self:FillLeftPane()
    end)

    -- Mousewheel: scroll right pane
    rightPane:SetScript("OnMouseWheel", function(_, delta)
        local maxOff = math.max(0, (self.bp_right_count or 0) - BP_MAX_ROWS)
        self.bp_right_offset = math.max(0, math.min(self.bp_right_offset - delta, maxOff))
        self:FillRightPane()
        -- Rows shifted under a stationary cursor; no OnEnter fires automatically.
        -- Find which row (if any) is now under the cursor and update the preview.
        for _, row in ipairs(self.bp_right_rows) do
            if row:IsShown() and row:IsMouseOver() then
                if row.creatureID and row.creatureID ~= 0 then
                    if not brokerPreviewObj then
                        brokerPreviewObj =
                            addon:CreateModelPreview("PetCallBrokerPreviewContainer")
                    end
                    brokerPreviewObj:ShowForCreature(
                        row.creatureID, "RIGHT", self.bp, "LEFT", -5, 0)
                    brokerPreviewObj.hoverFrame = row  -- same guard as OnEnter
                    return
                end
                break  -- found the hovered row but it had no valid creatureID
            end
        end
        if brokerPreviewObj then brokerPreviewObj:Hide() end
    end)

    -- Auto-close when the cursor leaves the panel
    local hideDelay = 0
    local HIDE_AFTER = 0.75  -- seconds

    panel:SetScript("OnShow", function() hideDelay = 0 end)

    panel:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() then
            hideDelay = 0
        else
            hideDelay = hideDelay + elapsed
            if hideDelay >= HIDE_AFTER then
                self:Hide()
            end
        end
    end)

    -- Cleanup on hide
    panel:SetScript("OnHide", function()
        catcher:Hide()
        hideDelay = 0
        if brokerPreviewObj then brokerPreviewObj:Hide() end
    end)

    self.bp              = panel
    self.bp_catcher      = catcher
    self.bp_title        = title
    self.bp_left_rows    = leftRows
    self.bp_right_rows   = rightRows
    self.bp_left_offset  = 0
    self.bp_right_offset = 0
    self.bp_right_count  = 0
    self.bp_pages        = nil
    self.bp_cur_page     = nil
end

function module:FillLeftPane()
    local pages  = self.bp_pages or {}
    local offset = self.bp_left_offset
    local rows   = self.bp_left_rows
    local cur    = self.bp_cur_page

    self.bp_title:SetText(string.format("%s (%d)", L["Pets"], #self.sorted_petlist))

    for i, row in ipairs(rows) do
        local pageIdx = offset + i
        local page    = pages[pageIdx]
        if page then
            row.lbl:SetText(string.format("%s (%s)", L["Pets"], page[3]))
            -- Active page highlighted in gold
            if pageIdx == cur then
                row.lbl:SetTextColor(1, 0.82, 0)
            else
                row.lbl:SetTextColor(1, 1, 1)
            end
            row:SetScript("OnEnter", function()
                self.bp_cur_page     = pageIdx
                self.bp_right_offset = 0
                self:FillLeftPane()   -- refresh active-page highlight
                self:FillRightPane()
                if brokerPreviewObj then brokerPreviewObj:Hide() end
            end)
            row:Show()
        else
            row:SetScript("OnEnter", nil)
            row:Hide()
        end
    end
end

function module:FillRightPane()
    local pages  = self.bp_pages
    local cur    = self.bp_cur_page
    local offset = self.bp_right_offset
    local rows   = self.bp_right_rows

    if not pages or not cur or not pages[cur] then
        for _, row in ipairs(rows) do row:Hide() end
        return
    end

    local page  = pages[cur]
    local s, e  = page[1], page[2]
    self.bp_right_count = e - s + 1

    for i, row in ipairs(rows) do
        local listIdx = s + offset + i - 1
        local petid   = (listIdx <= e) and self.sorted_petlist[listIdx]
        if petid then
            local _, customName, _, _, _, _, _, petName, icon, _, creatureID =
                C_PetJournal.GetPetInfoByPetID(petid)
            row.icon:SetTexture(icon)
            row.lbl:SetText(customName or petName)
            row.creatureID = creatureID
            row:SetScript("OnEnter", function(rowFrame)
                if rowFrame.creatureID and rowFrame.creatureID ~= 0 then
                    if not brokerPreviewObj then
                        brokerPreviewObj = addon:CreateModelPreview("PetCallBrokerPreviewContainer")
                    end
                    brokerPreviewObj:ShowForCreature(
                        rowFrame.creatureID, "RIGHT", self.bp, "LEFT", -5, 0)
                    -- Override hoverFrame to the row so rightRow_OnLeave can guard
                    -- against stale OnLeave events (visual anchor stays self.bp).
                    brokerPreviewObj.hoverFrame = rowFrame
                end
            end)
            row:SetScript("OnLeave", rightRow_OnLeave)
            row:SetScript("OnMouseUp", function()
                C_PetJournal.SummonPetByGUID(petid)
                self.bp:Hide()
            end)
            row:Show()
        else
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
            row:SetScript("OnMouseUp", nil)
            row:Hide()
        end
    end
end

function module:Broker_OnClick(frame, button)
    self:InitializeDropDown()

    if(IsControlKeyDown()) then
        addon:OpenOptions()
    elseif(button == "LeftButton") then
        if addon:IsEnabledSummoning() then
            addon:DismissPet(true)
        else
            addon:ResummonPet(true)
        end
        local tt = LibStub("LibDBIcon-1.0").tooltip
        if tt and tt:IsShown() then
            tt:ClearLines()
            self:Broker_OnTooltipShow(tt)
            tt:Show()
        end
    else
        -- Right-click: custom two-pane panel with alphabetical pages and 3D model preview
        local ncritters = LibPetJournal:NumPets()
        if ncritters > 0 and #self.sorted_petlist == 0 then
            self:LoadSortPets()
        end
        if not self.bp then self:CreateBrokerPanel() end
        if self.bp:IsShown() then
            self.bp:Hide()
        else
            if ncritters == 0 then
                self.bp_title:SetText(L["You have no pets"])
                self.bp_pages    = {}
                self.bp_cur_page = nil
                for _, row in ipairs(self.bp_left_rows)  do row:Hide() end
                for _, row in ipairs(self.bp_right_rows) do row:Hide() end
            else
                self.bp_pages        = BuildPageList(self.sorted_petlist)
                self.bp_cur_page     = 1
                self.bp_left_offset  = 0
                self.bp_right_offset = 0
                self:FillLeftPane()
                self:FillRightPane()
            end
            self.bp:ClearAllPoints()
            self.bp:SetPoint("TOPRIGHT", frame, "BOTTOMLEFT", 0, -5)
            self.bp_catcher:Show()
            self.bp:Show()
        end
    end
end

local function iter_utf8(s)
    -- Src: http://lua-users.org/wiki/LuaUnicode
    return string.gmatch(s, "([%z\1-\127\194-\244][\128-\191]*)")
end

local function str_range_diff(a,b)
    if(not b) then return iter_utf8(a)() end
    if(not a) then return nil, iter_utf8(b)() end

    local iter_a = iter_utf8(a)
    local iter_b = iter_utf8(b)
    local char_a, char_b = iter_a(), iter_b()
    local r = ""
    while char_a and char_b do
        if(char_a ~= char_b) then
            return r..char_a, r..char_b
        end

        r = r .. char_a

        char_a = iter_a()
        char_b = iter_b()
    end

    return r, r
end

local function safe_GetCritterName(id)
    local petid = module.sorted_petlist[id]
    if petid then
        return addon:GetPetName(petid)
    end
end

-- for two pet ids, forming a span from "a" to "b", generate a string
-- representing this span.  For example:  A - Z
BrokerMenu_PetRangeString = function(a, b)
    local _, part_a = str_range_diff(safe_GetCritterName(a-1), safe_GetCritterName(a))
    local part_b = str_range_diff(safe_GetCritterName(b), safe_GetCritterName(b+1))
    return string.format("%s - %s", part_a, part_b)
end

-- Build array of {startIdx, endIdx, rangeLabel} pages (25 pets each)
BuildPageList = function(list)
    local pages = {}
    local n = #list
    if n == 0 then return pages end
    local numPages = ceil(n / 25)
    local pageSize = n / numPages
    for p = 1, numPages do
        local s = floor(pageSize * (p - 1) + 1)
        local e = floor(pageSize * p)
        pages[p] = {s, e, BrokerMenu_PetRangeString(s, e)}
    end
    return pages
end
