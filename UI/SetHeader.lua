local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Header = {}
ns.UI.SetHeader = Header

-- The strip above the tabs: which set this is, whether it is used right now, and
-- what it does, in one sentence a new player can read without knowing the addon.

local STATUS = {
    active    = { L["Active now"], 0.25, 0.75, 0.30 },
    waiting   = { L["Conditions not met"], 0.45, 0.45, 0.45 },
    empty     = { L["No pets to choose from"], 0.85, 0.45, 0.10 },
    paused    = { L["Paused"], 0.30, 0.30, 0.30 },
    outranked = { L["Another set comes first"], 0.25, 0.45, 0.75 },
    standby   = { L["Standing by"], 0.45, 0.45, 0.45 },   -- the default set while another set is used
}

-- "Paused", "Paused for 47 min", "Paused until logout"
function Header.PauseText(set)
    local _, kind, left = set:IsPaused()
    if kind == "timed" then return format(L["Paused for %d min"], math.max(1, math.ceil(left / 60))) end
    if kind == "session" then return L["Paused until logout"] end
    return L["Paused"]
end

-- "Fits now, but <set> comes first"
function Header.OutrankedText(set)
    local cur = ns.Sets:GetCurrent()
    return format(L["Fits now, but %s comes first"], cur and cur:DisplayName() or "?")
end

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
local function counts(set) return ns.PetGridModel.Counts(set) end

function Header.Counts(set) return counts(set) end

-- the pet rules in words: "Source: Trading Post, Favorites"
function Header.RulesText(set)
    local parts = {}
    for _, e in ipairs(set.settings.filter or {}) do parts[#parts + 1] = ns.AutoRules.Describe(e) end
    return table.concat(parts, ", ")
end

-- a set that takes no pet by default picks only from its rules and its ticks
function Header.RulesOnly(set)
    return (set.settings.defaultValue or 0) == 0 and #(set.settings.filter or {}) > 0
end

function Header.Summary(set)
    local inSet = counts(set)
    local picks = format(L["PetCall picks one of %d checked pets."], inSet)
    if Header.RulesOnly(set) then
        picks = format(L["PetCall picks one of %d pets chosen by rules: %s."], inSet, Header.RulesText(set))
    end
    if set:IsNoPet() then picks = L["While it is used, PetCall keeps your pet away."] end
    if set:IsDefault() then return L["Used when no other set is active."] .. " " .. picks end
    if not set:HasConditions() then
        local text = L["No conditions, so this set is used everywhere."]
        -- with no pets for where you are it is not active: the set below it is used
        if ns.AutoRules.PlaceKey(set.settings.filter) then
            text = text .. " " .. L["Where it has no pets for the place you are in, the set below it is used."]
        end
        return text .. " " .. picks
    end
    return format(L["When: %s."], describeConditions(set)) .. " " .. picks
end

local header
local PAD = 8

-- The set's name with its status beside it, or under it when both do not fit; the
-- summary wraps below them and the header grows to hold it all.
local function layout()
    if not header then return end
    local w = (tonumber(header:GetWidth()) or 0) - 20
    if w <= 0 then return end
    local top = ns.Widgets.Flow(header.top, { header.title, header.pillFrame }, { width = w, gap = 10, rowHeight = 18 })
    header.summary:SetWidth(w)
    header:SetHeight(PAD + top + 4 + math.ceil(tonumber(header.summary:GetStringHeight()) or 0) + PAD)
end

-- the summary counts the set's pets over the whole collection: not worth doing for
-- a closed window, which catches up when it opens (WindowShown)
function Header:Refresh()
    if not header or not header:IsVisible() then return end
    local set = ns.UI.Main:GetSelectedSet()
    if not set or set.deleted then return end
    header.title:SetText(set:DisplayName())
    local status = set:GetStatus()
    if set:IsDefault() and (status == "waiting" or status == "outranked") then status = "standby" end
    local st = STATUS[status] or STATUS.waiting
    local text = st[1]
    if status == "paused" then text = Header.PauseText(set) end
    if status == "outranked" then text = Header.OutrankedText(set) end
    header.status:SetText(text)
    header.pill:SetColorTexture(st[2], st[3], st[4], 0.85)
    header.pillFrame:SetWidth(ns.Widgets.TextWidth(header.status) + 16)
    header.summary:SetText(Header.Summary(set))
    layout()
end

ns:RegisterCallback(Header, "WindowBuilt", function(_, frame)
    header = frame.header
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetColorTexture(1, 1, 1, 0.04)
    header.top = CreateFrame("Frame", nil, header)
    header.top:SetPoint("TOPLEFT", 10, -PAD)
    header.top:SetPoint("RIGHT", -10, 0)
    header.title = ns.Widgets.Label(header.top, "", "GameFontNormalHuge")
    header.pillFrame = CreateFrame("Frame", nil, header.top)
    header.pillFrame:SetHeight(18)
    header.pill = header.pillFrame:CreateTexture(nil, "BACKGROUND")
    header.pill:SetAllPoints()
    header.status = ns.Widgets.Label(header.pillFrame, "", "GameFontHighlightSmall")
    header.status:SetPoint("CENTER")
    header.summary = ns.Widgets.Label(header, "", "GameFontHighlight")
    header.summary:SetPoint("TOPLEFT", header.top, "BOTTOMLEFT", 0, -4)
    header.summary:SetWordWrap(true)
    Header:Refresh()
end)
ns:RegisterCallback(Header, "WindowResized", layout)

local refresh = ns.Debounce(0.05, function() Header:Refresh() end)
for _, cb in ipairs({ "SelectedSetChanged", "SetsChanged", "CurrentSetChanged", "ConditionStateChanged", "PetsChanged", "WindowShown" }) do
    ns:RegisterCallback(Header, cb, refresh)
end
