local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Bar = {}
ns.UI.AutoRulesBar = Bar

local ROW_H, GAP, CHIP_MAX_W, ADD_W = 24, 6, 260, 110
local bar, set, chips, editor = nil, nil, {}, nil
local lines = 1
local frames = ns.Widgets.NewPool()   -- the editor's controls, taken back each time it opens
Bar._chips = chips      -- for tests

local function list() return set.settings.filter end
local function commit() set:FiltersChanged() Bar:Refresh(set) end

local function chipText(chip)
    local text = chip.legacy and L["Complex rule (previous version)"] or ns.AutoRules.Describe(chip.entry)
    return format("%s · %s", text, ns.Weights.Label(ns.AutoRules.Weight(chip.entry)))
end

local function closeEditor() if editor then editor:Hide() end end
function Bar.GetEditor() return editor end      -- for tests

-- A popover under the chip, part of the main window: it closes with it, takes its
-- scale and skin, and every change applies at once, so it needs no Okay button.
local function buildEditor()
    -- on the window itself: the rules bar clips its children, which would hide it
    editor = CreateFrame("Frame", nil, ns.UI.Main:GetFrame(), "TooltipBackdropTemplate")
    editor:SetFrameStrata("DIALOG")
    editor:SetToplevel(true)
    editor:EnableMouse(true)
    editor:SetClampedToScreen(true)
    ns.Skin:Apply("Panel", editor)
    editor.done = ns.Widgets.Button(editor, L["Done"], closeEditor)
    editor.done:SetWidth(90)
    editor.done:SetPoint("BOTTOMRIGHT", -12, 10)
    editor.content = CreateFrame("Frame", nil, editor)
    editor.content:SetPoint("TOPLEFT", 12, -12)
    editor.content:SetPoint("BOTTOMRIGHT", -12, 40)
    -- the main window closing, or the tab changing, takes the popover with it

    bar:HookScript("OnHide", closeEditor)
end

local function fieldControl(parent, leaf, field)
    if field.kind == "multiChoice" then
        return frames:Dropdown(parent, 160, function(owner, root)
            for _, v in ipairs(field.values()) do
                root:CreateCheckbox(v.label, function()
                    for _, x in ipairs(leaf.petTypes or { tonumber(leaf.petType) }) do if x == v.value then return true end end
                end, function()
                    local cur = leaf.petTypes or { tonumber(leaf.petType) }
                    local out, found = {}, false
                    for _, x in ipairs(cur) do if x == v.value then found = true else out[#out + 1] = x end end
                    if not found then out[#out + 1] = v.value end
                    if #out > 0 then ns.AutoRules.SetField(leaf, "petTypes", out) commit() end
                end)
            end
        end)
    elseif field.kind == "operator" then
        return frames:Dropdown(parent, 60, function(owner, root)
            for _, op in ipairs(ns.AutoRules.OPERATORS) do
                root:CreateRadio(op, function() return leaf.operator == op end, function() ns.AutoRules.SetField(leaf, "operator", op) commit() end)
            end
        end)
    elseif field.kind == "number" then
        local eb = frames:EditBox(parent, "numberBox")
        eb:SetSize(40, 20)
        eb:SetNumeric(true)
        eb:SetText(tostring(leaf[field.key] or ""))
        eb:SetScript("OnEnterPressed", function(self)
            local n = math.max(field.min, math.min(field.max, tonumber(self:GetText()) or field.min))
            ns.AutoRules.SetField(leaf, field.key, tostring(n))
            self:ClearFocus()
            commit()
        end)
        return eb
    elseif field.kind == "text" then
        local eb = frames:EditBox(parent, "textBox")
        eb:SetSize(160, 20)
        eb:SetText(leaf[field.key] or "")
        eb:SetScript("OnEnterPressed", function(self)
            ns.AutoRules.SetField(leaf, field.key, strtrim(self:GetText()))
            self:ClearFocus()
            commit()
        end)
        return eb
    end
end

local openEditor

-- the bar is rebuilt after every change; open the editor again on the same rule
local function reopen(index)
    local b, data = chips[index], set:GetAutoRules()
    if b and b:IsShown() and data[index] then openEditor(b, data[index]) end
end

function openEditor(anchor, chip)
    if not editor then buildEditor() end
    editor:SetSize(460, 120)
    editor:ClearAllPoints()
    editor:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    frames:Release()
    local c = editor.content
    local y = 0
    if chip.legacy then
        local t = frames:Label(c, ns.AutoRules.Describe(chip.entry))
        t:SetPoint("TOPLEFT")
        t:SetPoint("RIGHT")
        t:SetWordWrap(true)
        local simplify = frames:Button(c, L["Simplify"], function()
            if ns.AutoRules.Simplify(list(), chip.index) then commit() closeEditor() end
        end)
        simplify:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
    else
        for ci, leaf in ipairs(chip.criteria) do
            local row = frames:Frame(c, "row")
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("RIGHT")
            row:SetHeight(26)
            local label = frames:Label(row, ns.AutoRules.Label(leaf[1]))
            label:SetPoint("LEFT")
            label:SetWidth(110)
            label:SetWordWrap(false)
            local prev = label
            for _, def in ipairs(ns.AutoRules.Types()) do
                if def.key == leaf[1] then
                    for _, field in ipairs(def.fields) do
                        local ctl = fieldControl(row, leaf, field)
                        ctl:SetPoint("LEFT", prev, "RIGHT", 6, 0)
                        prev = ctl
                    end
                end
            end
            -- a rule with one condition is removed with the × on its chip
            if #chip.criteria > 1 then
                local remove = frames:Take("remove", row, function()
                    return CreateFrame("Button", nil, row, "UIPanelCloseButtonNoScripts")
                end)
                remove:SetSize(18, 18)
                remove:SetPoint("LEFT", prev, "RIGHT", 6, 0)
                remove:SetScript("OnClick", function()
                    ns.AutoRules.RemoveCriterion(list(), chip.index, ci) commit() reopen(chip.index)
                end)
                ns.Widgets.Tooltip(remove, L["Remove this condition"])
            end
            y = y - 28
        end
        -- with several conditions: must a pet meet all of them, or one is enough
        if #chip.criteria > 1 then
            local matchLabel = frames:Label(c, L["Pets must match"])
            matchLabel:SetPoint("TOPLEFT", 0, y - 9)
            matchLabel:SetWidth(110)
            local match = frames:Dropdown(c, 160, function(owner, root)
                root:CreateRadio(L["All of these"], function() return chip.match == "all" end, function() ns.AutoRules.SetMatch(list(), chip.index, "all") commit() reopen(chip.index) end)
                root:CreateRadio(L["Any one of these"], function() return chip.match == "any" end, function() ns.AutoRules.SetMatch(list(), chip.index, "any") commit() reopen(chip.index) end)
            end)
            match:SetPoint("LEFT", matchLabel, "RIGHT", 6, 0)
            y = y - 30
        end
        local add = frames:Dropdown(c, 160, function(owner, root)
            for _, def in ipairs(ns.AutoRules.Types()) do
                root:CreateButton(def.label, function() ns.AutoRules.AddCriterion(list(), chip.index, def.key) commit() reopen(chip.index) end)
            end
        end, L["+ Another condition"])
        add:SetPoint("TOPLEFT", 116, y - 4)
        ns.Widgets.Tooltip(add, L["+ Another condition"], L["Narrow the rule down, for example: source mentions Trading Post and the pet is a Beast."])
        y = y - 30
    end
    local weightLabel = frames:Label(c, L["How often"])
    weightLabel:SetPoint("TOPLEFT", 0, y - 9)
    weightLabel:SetWidth(110)
    local weight = frames:Dropdown(c, 160, function(owner, root)
        for _, lvl in ipairs(ns.Weights.LEVELS) do
            root:CreateRadio(lvl.label, function() return ns.Weights.Nearest(ns.AutoRules.Weight(chip.entry)) == lvl.value end,
                function() ns.AutoRules.SetChipWeight(list(), chip.index, lvl.value) commit() reopen(chip.index) end)
        end
    end)
    weight:SetPoint("LEFT", weightLabel, "RIGHT", 6, 0)
    editor:SetHeight(-y + 84)
    editor:Show()
end

local function chipButton(i)
    local b = chips[i]
    if b then return b end
    b = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    b:SetHeight(20)
    b.remove = CreateFrame("Button", nil, b, "UIPanelCloseButtonNoScripts")
    b.remove:SetSize(16, 16)
    b.remove:SetPoint("RIGHT", -2, 0)
    -- hooked once; Refresh only swaps the text
    ns.Widgets.Tooltip(b, function(self) return self.tooltip end)
    ns.Skin:Apply("Button", b)
    chips[i] = b
    return b
end

-- The label, then the chips and "+ Add" left to right; whatever does not fit goes on
-- the next line, lined up under the first chip. The bar grows by a line each time and
-- the pet grid moves down under it, so nothing runs out of the window.
function Bar:Layout()
    if not bar or not bar.label then return end
    local width = tonumber(bar:GetWidth()) or 0
    if width <= 0 then width = ns.UI.Main:GetContentWidth() - 10 end
    local label = bar.label
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", 0, -(ROW_H - 12) / 2)
    local indent = math.ceil(tonumber(label:GetStringWidth()) or 0) + 8
    local x, line = indent, 0
    local function place(frame, w)
        if x > indent and x + w > width then x, line = indent, line + 1 end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -(line * ROW_H + 2))
        x = x + w + GAP
    end
    for _, b in ipairs(chips) do
        if b:IsShown() then
            local w = math.max(60, math.min(CHIP_MAX_W, width - indent, b.textWidth + 36))
            b:SetWidth(w)
            place(b, w)
        end
    end
    bar.add:SetWidth(ADD_W)
    place(bar.add, ADD_W)
    lines = line + 1
    bar:SetHeight(lines * ROW_H)
    if ns.UI.PetsTab and ns.UI.PetsTab.PlaceBelowRules then ns.UI.PetsTab:PlaceBelowRules() end
end

-- how many lines the chips take now
function Bar:GetLines() return lines end

function Bar:Refresh(newSet)
    set = newSet
    bar = bar or ns.UI.PetsTabRulesBar
    if not bar or not set then return end
    closeEditor()
    local data = set:GetAutoRules()
    local label = bar.label or ns.Widgets.Label(bar, "", "GameFontNormalSmall")
    bar.label = label
    -- rules either add chances on top of the ticked pets, or are where the pets come from
    label:SetText(ns.UI.SetHeader.RulesOnly(set) and L["Pets from rules:"] or L["More chance for:"])
    for i, chip in ipairs(data) do
        local b = chipButton(i)
        b:SetText(chipText(chip))
        b.textWidth = tonumber(b:GetFontString():GetStringWidth()) or 0
        b:SetScript("OnClick", function(self) openEditor(self, chip) end)
        b.remove:SetScript("OnClick", function() ns.AutoRules.RemoveChip(list(), chip.index) commit() end)
        b.tooltip = chipText(chip)
        b:Show()
    end
    for i = #data + 1, #chips do chips[i]:Hide() end
    bar.add = bar.add or ns.Widgets.Dropdown(bar, ADD_W, function(owner, root)
        for _, def in ipairs(ns.AutoRules.Types()) do
            root:CreateButton(def.label, function() ns.AutoRules.AddChip(list(), def.key, ns.Weights.NORMAL) commit() end)
        end
    end)
    bar.add:SetDefaultText(L["+ Add"])
    self:Layout()
end

-- the window got wider or narrower: the chips find their lines again
local relayout = ns.Debounce(0.12, function() if bar and bar:IsVisible() then Bar:Layout() end end)
ns:RegisterCallback(Bar, "WindowResized", relayout)
