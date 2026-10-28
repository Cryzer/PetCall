local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local Bar = {}
ns.UI.StatusBar = Bar

local bar

-- one sentence: which pet is out and from which set, then whether PetCall can act
function Bar:Refresh()
    if not bar or not bar:IsVisible() then return end
    local set = ns.Sets:GetCurrent()
    local pet = ns:GetCurrentPet()
    local info = pet and ns.PetCache:GetInfo(pet)
    bar.icon:SetTexture(info and info.icon or "Interface\\Icons\\Tracking_WildPet")
    local now
    if info then
        now = format(L["Now: %s, from %s"], info.customName or info.name, set and set:DisplayName() or NONE)
    else
        now = L["Now: no pet out"]
    end
    local blockers = ns.Ready:GetBlockers()
    local state
    if #blockers == 0 then
        state = "|cff40ff40" .. L["ready"] .. "|r"
    else
        local labels = {}
        for i = 1, math.min(2, #blockers) do labels[i] = blockers[i].label end
        state = "|cffffb040" .. L["paused"] .. ":|r " .. table.concat(labels, ", ") .. (#blockers > 2 and " ..." or "")
    end
    -- the sets panel shows the pet in its "Out now" card; the bar then only says
    -- whether PetCall can act. With the panel folded away the bar says it all.
    local cardShown = ns.UI.SetList and not ns.UI.SetList:IsCollapsed()
    bar.icon:SetShown(not cardShown)
    if cardShown then
        bar.left:SetPoint("LEFT", bar, "LEFT", 4, 0)
        bar.left:SetText(L["Auto-summon"] .. ": " .. state)
    else
        bar.left:SetPoint("LEFT", bar.icon, "RIGHT", 6, 0)
        bar.left:SetText(now .. "  ·  " .. state)
    end
    bar.blockers = blockers
    if ns.UI.SetList then ns.UI.SetList:RefreshNow(blockers) end
    bar.auto:SetChecked(ns:IsAutoSummon())
end

ns:RegisterCallback(Bar, "WindowBuilt", function(_, frame)
    bar = frame.status
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(18, 18)
    bar.icon:SetPoint("LEFT", 2, 0)
    bar.auto = ns.Widgets.Checkbox(bar, L["Auto-summon"], function() return ns:IsAutoSummon() end,
        function(v) ns:SetAutoSummon(v) end)
    bar.auto:SetPoint("RIGHT", -ns.Widgets.TextWidth(bar.auto.text) - 6, 0)
    ns.Widgets.Tooltip(bar.auto, L["Auto-summon"], L["Automatically summon a companion pet when entering a new area or when idle."])
    bar.another = ns.Widgets.Button(bar, L["Summon another"], function() ns:SummonAnother() end)
    bar.another:SetPoint("RIGHT", bar.auto, "LEFT", -12, 0)
    bar.left = ns.Widgets.Label(bar, "", "GameFontHighlightSmall")
    bar.left:SetPoint("LEFT", bar.icon, "RIGHT", 6, 0)
    bar.left:SetPoint("RIGHT", bar.another, "LEFT", -8, 0)
    bar.left:SetWordWrap(false)
    local hit = CreateFrame("Frame", nil, bar)
    hit:SetAllPoints(bar.left)
    hit:EnableMouse(true)
    ns.Widgets.Tooltip(hit, L["Why is no pet summoned?"], function()
        if not bar.blockers or #bar.blockers == 0 then return L["Nothing is blocking PetCall."] end
        local lines = {}
        for _, b in ipairs(bar.blockers) do lines[#lines + 1] = "- " .. b.label end
        return table.concat(lines, "\n")
    end)
    bar:SetScript("OnShow", function() Bar:Refresh() end)
end)

local refresh = ns.Debounce(0.1, function() Bar:Refresh() end)
for _, cb in ipairs({ "ReadyChanged", "CurrentSetChanged", "PetsChanged", "AutoSummonChanged", "SummonedPetChanged", "WindowShown" }) do
    ns:RegisterCallback(Bar, cb, refresh)
end
