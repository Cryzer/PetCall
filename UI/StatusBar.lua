local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local Bar = {}
ns.UI.StatusBar = Bar

local bar

function Bar:Refresh()
    if not bar or not bar:IsVisible() then return end
    local set = ns.Sets:GetCurrent()
    local pet = ns:GetCurrentPet()
    local info = pet and ns.PetCache:GetInfo(pet)
    bar.left:SetText(format("%s: %s · %s: %s", L["Active"], set and set:DisplayName() or NONE,
        L["Pet"], info and (info.customName or info.name) or L["none"]))
    local blockers = ns.Ready:GetBlockers()
    if #blockers == 0 then
        bar.mid:SetText("|cff40ff40" .. L["Ready"] .. "|r")
    else
        local labels = {}
        for i = 1, math.min(3, #blockers) do labels[i] = blockers[i].label end
        bar.mid:SetText("|cffffb040" .. L["Paused by"] .. ":|r " .. table.concat(labels, ", ") .. (#blockers > 3 and " …" or ""))
    end
    bar.blockers = blockers
    bar.auto:SetText(ns:IsAutoSummon() and L["Auto-summon: ON"] or L["Auto-summon: OFF"])
    bar.auto:SetWidth(bar.auto:GetFontString():GetStringWidth() + 24)
end

ns:RegisterCallback(Bar, "WindowBuilt", function(_, frame)
    bar = frame.status
    bar.left = ns.Widgets.Label(bar, "", "GameFontHighlightSmall")
    bar.left:SetPoint("LEFT")
    bar.left:SetWidth(260)
    bar.left:SetWordWrap(false)
    bar.auto = ns.Widgets.Button(bar, "", function() ns:SetAutoSummon(not ns:IsAutoSummon()) end)
    bar.auto:SetPoint("RIGHT")
    bar.another = ns.Widgets.Button(bar, L["Summon another"], function() ns:SummonAnother() end)
    bar.another:SetPoint("RIGHT", bar.auto, "LEFT", -4, 0)
    bar.mid = ns.Widgets.Label(bar, "", "GameFontHighlightSmall")
    bar.mid:SetPoint("LEFT", bar.left, "RIGHT", 8, 0)
    bar.mid:SetPoint("RIGHT", bar.another, "LEFT", -8, 0)
    bar.mid:SetWordWrap(false)
    local hit = CreateFrame("Frame", nil, bar)
    hit:SetAllPoints(bar.mid)
    hit:EnableMouse(true)
    ns.Widgets.Tooltip(hit, L["Why is no pet summoned?"], function()
        if not bar.blockers or #bar.blockers == 0 then return L["Nothing is blocking PetCall."] end
        local lines = {}
        for _, b in ipairs(bar.blockers) do lines[#lines + 1] = "• " .. b.label end
        return table.concat(lines, "\n")
    end)
    bar:SetScript("OnShow", function() Bar:Refresh() end)
end)

local refresh = ns.Debounce(0.1, function() Bar:Refresh() end)
for _, cb in ipairs({ "ReadyChanged", "CurrentSetChanged", "PetsChanged", "AutoSummonChanged", "SummonedPetChanged", "WindowShown" }) do
    ns:RegisterCallback(Bar, cb, refresh)
end
