local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Header = {}
ns.UI.SetHeader = Header

-- The strip above the tabs: which set this is, whether it is used right now, and
-- what it does, in one sentence a new player can read without knowing the addon.

local STATUS = {
    active       = { L["Active now"], 0.25, 0.75, 0.30 },
    waiting      = { L["Conditions not met"], 0.45, 0.45, 0.45 },
    empty        = { L["No pets to choose from"], 0.85, 0.45, 0.10 },
    noConditions = { L["Always active"], 0.85, 0.45, 0.10 },
    disabled     = { L["Disabled"], 0.30, 0.30, 0.30 },
}

local function describeConditions(set)
    local groups = {}
    for _, g in ipairs(set:GetConditionModel().groups) do
        local rows = {}
        for _, e in ipairs(g.rows) do rows[#rows + 1] = ns.Conditions.Describe(e) end
        if #rows > 0 then groups[#groups + 1] = table.concat(rows, ", ") end
    end
    return table.concat(groups, " " .. L["or"] .. " ")
end

-- counts tiles (one per pet, copies grouped), as the grid shows them
local function counts(set)
    local inSet = #ns.PetGridModel.Filter(set, { show = "selected" })
    local all = #ns.PetGridModel.Filter(set, {})
    return inSet, all - inSet
end

function Header.Counts(set) return counts(set) end

function Header.Summary(set)
    local inSet = counts(set)
    local picks = format(L["PetCall picks one of %d checked pets."], inSet)
    if set:IsDefault() then return L["Used when no other set is active."] .. " " .. picks end
    if not set:HasConditions() then return L["No conditions yet, so this set is always active."] .. " " .. picks end
    return format(L["When: %s."], describeConditions(set)) .. " " .. picks
end

local header

function Header:Refresh()
    if not header then return end
    local set = ns.UI.Main:GetSelectedSet()
    if not set or set.deleted then return end
    header.title:SetText(set:DisplayName())
    local st = STATUS[set:GetStatus()] or STATUS.waiting
    header.status:SetText(st[1])
    header.pill:SetColorTexture(st[2], st[3], st[4], 0.85)
    header.pillFrame:SetWidth(header.status:GetStringWidth() + 16)
    header.summary:SetText(Header.Summary(set))
end

ns:RegisterCallback(Header, "WindowBuilt", function(_, frame)
    header = frame.header
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(1, 1, 1, 0.04)
    header.title = ns.Widgets.Label(header, "", "GameFontNormalHuge")
    header.title:SetPoint("TOPLEFT", 10, -8)
    header.title:SetWordWrap(false)
    header.pillFrame = CreateFrame("Frame", nil, header)
    header.pillFrame:SetHeight(18)
    header.pillFrame:SetPoint("LEFT", header.title, "RIGHT", 10, 0)
    header.pill = header.pillFrame:CreateTexture(nil, "BACKGROUND")
    header.pill:SetAllPoints()
    header.status = ns.Widgets.Label(header.pillFrame, "", "GameFontHighlightSmall")
    header.status:SetPoint("CENTER")
    header.summary = ns.Widgets.Label(header, "", "GameFontHighlight")
    header.summary:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -4)
    header.summary:SetPoint("RIGHT", -10, 0)
    header.summary:SetWordWrap(false)
    ns.Widgets.Tooltip(header, nil, function() return header.summary:GetText() end)
    Header:Refresh()
end)

local refresh = ns.Debounce(0.05, function() Header:Refresh() end)
for _, cb in ipairs({ "SelectedSetChanged", "SetsChanged", "CurrentSetChanged", "ConditionStateChanged", "PetsChanged", "WindowShown" }) do
    ns:RegisterCallback(Header, cb, refresh)
end
