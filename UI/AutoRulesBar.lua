local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Bar = {}
ns.UI.AutoRulesBar = Bar

local bar, set, chips, editor = nil, nil, {}, nil
Bar._chips = chips      -- for tests

local function list() return set.settings.filter end
local function commit() set:FiltersChanged() Bar:Refresh(set) end

local function chipText(chip)
    local text = chip.legacy and L["Complex rule (previous version)"] or ns.AutoRules.Describe(chip.entry)
    return format("%s: %s", text, ns.Weights.Label(ns.AutoRules.Weight(chip.entry)))
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
    -- the main window closing, or the tab changing, takes the popover with it

    bar:HookScript("OnHide", closeEditor)
end

local function fieldControl(parent, leaf, field)
    if field.kind == "multiChoice" then
        return ns.Widgets.Dropdown(parent, 160, function(owner, root)
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
        return ns.Widgets.Dropdown(parent, 60, function(owner, root)
            for _, op in ipairs(ns.AutoRules.OPERATORS) do
                root:CreateRadio(op, function() return leaf.operator == op end, function() ns.AutoRules.SetField(leaf, "operator", op) commit() end)
            end
        end)
    elseif field.kind == "number" then
        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetSize(40, 20)
        eb:SetAutoFocus(false)
        eb:SetNumeric(true)
        eb:SetText(tostring(leaf[field.key] or ""))
        eb:SetScript("OnEnterPressed", function(self)
            local n = math.max(field.min, math.min(field.max, tonumber(self:GetText()) or field.min))
            ns.AutoRules.SetField(leaf, field.key, tostring(n))
            self:ClearFocus()
            commit()
        end)
        ns.Skin:Apply("EditBox", eb)
        return eb
    elseif field.kind == "text" then
        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetSize(160, 20)
        eb:SetAutoFocus(false)
        eb:SetText(leaf[field.key] or "")
        eb:SetScript("OnEnterPressed", function(self)
            ns.AutoRules.SetField(leaf, field.key, strtrim(self:GetText()))
            self:ClearFocus()
            commit()
        end)
        ns.Skin:Apply("EditBox", eb)
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
    if editor.content then editor.content:Hide() end
    local c = CreateFrame("Frame", nil, editor)
    c:SetPoint("TOPLEFT", 12, -12)
    c:SetPoint("BOTTOMRIGHT", -12, 40)
    editor.content = c
    local y = 0
    if chip.legacy then
        local t = ns.Widgets.Label(c, ns.AutoRules.Describe(chip.entry))
        t:SetPoint("TOPLEFT")
        t:SetPoint("RIGHT")
        t:SetWordWrap(true)
        local simplify = ns.Widgets.Button(c, L["Simplify"], function()
            if ns.AutoRules.Simplify(list(), chip.index) then commit() closeEditor() end
        end)
        simplify:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
    else
        for ci, leaf in ipairs(chip.criteria) do
            local row = CreateFrame("Frame", nil, c)
            row:SetPoint("TOPLEFT", 0, y)
            row:SetPoint("RIGHT")
            row:SetHeight(26)
            local label = ns.Widgets.Label(row, ns.AutoRules.Label(leaf[1]))
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
                local remove = CreateFrame("Button", nil, row, "UIPanelCloseButtonNoScripts")
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
            local matchLabel = ns.Widgets.Label(c, L["Pets must match"])
            matchLabel:SetPoint("TOPLEFT", 0, y - 9)
            matchLabel:SetWidth(110)
            local match = ns.Widgets.Dropdown(c, 160, function(owner, root)
                root:CreateRadio(L["All of these"], function() return chip.match == "all" end, function() ns.AutoRules.SetMatch(list(), chip.index, "all") commit() reopen(chip.index) end)
                root:CreateRadio(L["Any one of these"], function() return chip.match == "any" end, function() ns.AutoRules.SetMatch(list(), chip.index, "any") commit() reopen(chip.index) end)
            end)
            match:SetPoint("LEFT", matchLabel, "RIGHT", 6, 0)
            y = y - 30
        end
        local add = ns.Widgets.Dropdown(c, 160, function(owner, root)
            for _, def in ipairs(ns.AutoRules.Types()) do
                root:CreateButton(def.label, function() ns.AutoRules.AddCriterion(list(), chip.index, def.key) commit() reopen(chip.index) end)
            end
        end)
        add:SetDefaultText(L["+ Another condition"])
        add:SetPoint("TOPLEFT", 116, y - 4)
        ns.Widgets.Tooltip(add, L["+ Another condition"], L["Narrow the rule down, for example: source mentions Trading Post and the pet is a Beast."])
        y = y - 30
    end
    local weightLabel = ns.Widgets.Label(c, L["How often"])
    weightLabel:SetPoint("TOPLEFT", 0, y - 9)
    weightLabel:SetWidth(110)
    local weight = ns.Widgets.Dropdown(c, 160, function(owner, root)
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
    label:SetPoint("LEFT")
    local prev = label
    for i, chip in ipairs(data) do
        local b = chipButton(i)
        b:SetText(chipText(chip))
        b:SetWidth(math.min(260, b:GetFontString():GetStringWidth() + 36))
        b:ClearAllPoints()
        b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        b:SetScript("OnClick", function(self) openEditor(self, chip) end)
        b.remove:SetScript("OnClick", function() ns.AutoRules.RemoveChip(list(), chip.index) commit() end)
        b.tooltip = chipText(chip)
        b:Show()
        prev = b
    end
    for i = #data + 1, #chips do chips[i]:Hide() end
    bar.add = bar.add or ns.Widgets.Dropdown(bar, 110, function(owner, root)
        for _, def in ipairs(ns.AutoRules.Types()) do
            root:CreateButton(def.label, function() ns.AutoRules.AddChip(list(), def.key, ns.Weights.NORMAL) commit() end)
        end
    end)
    bar.add:SetDefaultText(L["+ Add"])
    bar.add:ClearAllPoints()
    bar.add:SetPoint("LEFT", prev, "RIGHT", 8, 0)
end
