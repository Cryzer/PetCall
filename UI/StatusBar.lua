local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local Bar = {}
ns.UI.StatusBar = Bar

local bar
local BAR_H = 22

-- The sentence wraps when the window is narrow; the bar, and the window's inset above
-- it, grow to hold it.
local function fit()
    if not bar then return end
    local h = math.max(BAR_H, math.ceil(tonumber(bar.left:GetStringHeight()) or 0) + 6)
    if h == tonumber(bar:GetHeight()) then return end
    bar:SetHeight(h)
    local frame = ns.UI.Main:GetFrame()
    frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, h + 10)
end

-- every cause that holds PetCall back right now, one per line, for the tooltips
function Bar.CauseText()
    local lines = {}
    for _, b in ipairs(ns.Ready:GetBlockers()) do lines[#lines + 1] = "- " .. b.label end
    local auto = ns.Gate:AutoCause()
    if auto then lines[#lines + 1] = "- " .. auto.label end
    for _, exc in ipairs(ns.Exceptions:InForce()) do
        lines[#lines + 1] = format("- %s: %s", exc:DisplayName(), ns.Exceptions.CHOICE_LABEL[exc:GetChoice()])
    end
    if #lines == 0 then return L["Nothing is blocking PetCall."] end
    return table.concat(lines, "\n")
end

-- the cause in short: "Paused: While mounted", "Paused: you dismissed your pet"
local function stateText(why)
    local kind = why.kind
    if kind == "game" or kind == "exception" then return "|cffffb040" .. format(L["Paused: %s"], why.label) .. "|r" end
    if kind == "paused" then return "|cffffb040" .. format(L["Paused: %s"], L["you dismissed your pet"]) .. "|r" end
    if kind == "off" then return "|cffff6040" .. L["Off"] .. "|r" end
    return "|cff40ff40" .. L["ready"] .. "|r"
end

-- the check box says Paused next to it while your dismissal pauses Auto-summon
local function paintAuto()
    local paused = ns:GetAutoState() == "paused"
    bar.auto:SetChecked(ns:IsAutoSummon())
    bar.auto.text:SetText(paused and L["Auto-summon (Paused)"] or L["Auto-summon"])
    bar.auto:ClearAllPoints()
    bar.auto:SetPoint("RIGHT", -ns.Widgets.TextWidth(bar.auto.text) - 6, 0)
end

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
    local why = ns.Gate:Explain()
    local state = stateText(why)
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
    paintAuto()
    bar.undo:SetShown(ns.Recommended:CanUndo())
    fit()
    if ns.UI.SetList then ns.UI.SetList:RefreshNow(why) end
    -- "Next new pet in N min" counts down: draw again when N changes
    if Bar.tick then Bar.tick:Cancel() Bar.tick = nil end
    if why.seconds then
        local s = why.seconds
        Bar.tick = ns:After(math.max(0.5, s - (math.ceil(s / 60) - 1) * 60 + 0.1), function()
            Bar.tick = nil
            Bar:Refresh()
        end)
    end
end

ns:RegisterCallback(Bar, "WindowBuilt", function(_, frame)
    bar = frame.status
    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetSize(18, 18)
    bar.icon:SetPoint("LEFT", 2, 0)
    bar.auto = ns.Widgets.Checkbox(bar, L["Auto-summon"], function() return ns:IsAutoSummon() end,
        function(v) ns:SetAutoSummon(v) end)
    bar.auto:SetPoint("RIGHT", -ns.Widgets.TextWidth(bar.auto.text) - 6, 0)
    ns.Widgets.Tooltip(bar.auto, L["Auto-summon"], function()
        local text = L["Automatically summon a companion pet when entering a new area or when idle."]
        if ns:GetAutoState() == "paused" then
            text = "|cffffb040" .. L["Paused until you change zone"] .. "|r (" .. L["you dismissed your pet"] .. ")\n" .. text
        end
        return text
    end)
    bar.another = ns.Widgets.Button(bar, L["Summon another"], function() ns:SummonAnother() end)
    bar.another:SetPoint("RIGHT", bar.auto, "LEFT", -12, 0)
    -- after Use recommended, until a reload or a change by hand
    bar.undo = ns.Widgets.Button(bar, L["Undo"], function() ns.Recommended:Undo() end)
    bar.undo:SetPoint("RIGHT", bar.another, "LEFT", -6, 0)
    ns.Widgets.Tooltip(bar.undo, L["Undo"], L["Put back the settings you had before Use recommended."])
    bar.undo:Hide()
    bar.left = ns.Widgets.Label(bar, "", "GameFontHighlightSmall")
    bar.left:SetPoint("LEFT", bar.icon, "RIGHT", 6, 0)
    bar.left:SetPoint("RIGHT", bar.another, "LEFT", -8, 0)
    -- the sentence makes room for Undo while it is there
    bar.undo:SetScript("OnShow", function() bar.left:SetPoint("RIGHT", bar.undo, "LEFT", -8, 0) end)
    bar.undo:SetScript("OnHide", function() bar.left:SetPoint("RIGHT", bar.another, "LEFT", -8, 0) end)
    bar.left:SetWordWrap(true)
    local hit = CreateFrame("Frame", nil, bar)
    hit:SetAllPoints(bar.left)
    hit:EnableMouse(true)
    ns.Widgets.Tooltip(hit, L["Why is no pet summoned?"], Bar.CauseText)
    bar:SetScript("OnShow", function() Bar:Refresh() end)
end)
ns:RegisterCallback(Bar, "WindowResized", fit)

local refresh = ns.Debounce(0.1, function() Bar:Refresh() end)
for _, cb in ipairs({ "ReadyChanged", "CurrentSetChanged", "SetsChanged", "PetsChanged", "AutoSummonChanged", "SummonedPetChanged", "WindowShown",
    "ExceptionsChanged", "RecommendedUndoChanged" }) do
    ns:RegisterCallback(Bar, cb, refresh)
end
