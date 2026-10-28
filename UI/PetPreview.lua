local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Preview = {}
ns.UI.Preview = Preview

local panel, viewer, set, hoverID, selectedID, lastHoverID
local shownID
local loadModel        -- assigned above Preview:ShowPet
local hovering         -- true while SetHover draws: the model waits for the cursor to rest
-- The text and the controls under the model need this much; the model takes the rest,
-- so a tall window gets a big model and a short one never pushes the controls out.
-- When room runs short the parts go in this order: the source lines (still in the
-- tooltip), the chance bar, then the model. Name, How often and Summon always stay.
-- (each budget keeps an 8 px gap above the Summon button)
local FULL, NO_SOURCE, NO_CHANCE = 222, 176, 122
-- The controls stand on the Summon button, counted up from the panel's bottom edge, so
-- no text above them can push them out of the frame. The source lines get the room
-- between the name and "How often" and are cut there (the whole text is in the tooltip).
local SUMMON_TOP, CHANCE_BOTTOM, SCALE_BOTTOM, SCALE_LOW = 30, 38, 92, 38
local PANEL_W = 240
local SCALE_W = PANEL_W - 14      -- the How often scale and its name
local NAME_LINE_H = 12            -- the budgets count one line for that name

-- "How often: Often" for the picked step, or for the step under the cursor
-- and where the picked one comes from: "· from a rule", or "· by hand" when the pet's own
-- setting stands in for a rule, with the button that gives the rule's level back
local RULE_COLOR = { 0.4, 0.8, 1 }
function Preview.NameWeight(hovered)
    local picked = ns.Weights.LEVELS[panel.scale.index or 0]
    local step = hovered or picked
    local text = L["How often"]
    if step then
        local color = hovered and hovered ~= picked and "|cffaaaaaa" or "|cffffffff"
        text = format(L["How often: %s"], color .. step.label .. "|r")
        if step == picked and panel.levelSource == "rule" then
            text = text .. " · |cff66ccff" .. L["from a rule"] .. "|r"
        elseif step == picked and panel.useRule.ruleW then
            text = text .. " · |cff999999" .. L["by hand"] .. "|r"
        end
    end
    panel.weight:SetText(text)
    -- more lines than the budgets count (a long name, Use the rule under it) come out of
    -- the model's room, so the panel is laid out again when they change
    local before = tonumber(panel.weightRow:GetHeight()) or 0
    ns.Widgets.Flow(panel.weightRow, { panel.weight, { frame = panel.useRule, right = true } },
        { width = SCALE_W, gap = 6, rowHeight = NAME_LINE_H })
    if panel.relayout and (tonumber(panel.weightRow:GetHeight()) or 0) ~= before then panel.relayout() end
end

-- Blizzard's source text: "|n" line breaks, sometimes blank lines and trailing breaks
function Preview.CleanSource(text)
    text = (text or ""):gsub("|n", "\n")
    text = text:gsub("\n%s*\n", "\n")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    return text
end

-- How often and the chance bar, counted up from the bottom edge
local function placeControls(withChance)
    local bottom = withChance and SCALE_BOTTOM or SCALE_LOW
    panel.scale:ClearAllPoints()
    panel.scale:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, bottom)
    panel.weightRow:ClearAllPoints()
    panel.weightRow:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, bottom + panel.scale:GetHeight() + 4)
    -- the source lines end above the scale's name, however many lines that name takes
    panel.source:SetPoint("BOTTOMRIGHT", panel.weightRow, "TOPRIGHT", 0, 8)
end

-- -> model height (0 = no model), show source, show chance; extra: room the controls
-- take beyond the budgets
function Preview.Layout(h, extra)
    h = (h or 0) - (extra or 0)
    if h - FULL >= 110 then return h - FULL, true, true end
    if h - NO_SOURCE >= 80 then return h - NO_SOURCE, false, true end
    if h - NO_CHANCE >= 60 then return h - NO_CHANCE, false, false end
    return 0, false, false
end

-- The model frame is about as tall as it is wide at most. A taller, narrow frame makes
-- the camera back off to keep the pet whole in width, so the pet looked small and
-- jumped back after each load. The spare room goes above and below the model.
local MODEL_MAX_H = 260
Preview.MODEL_MAX_H = MODEL_MAX_H

-- -> model height, gap above it
function Preview.ModelBox(slot)
    local mh = math.min(slot, MODEL_MAX_H)
    return mh, math.floor((slot - mh) / 2)
end

-- the pet under the cursor wins; off the tiles the panel shows the selected pet, else
-- the last one hovered, else the summoned one
local function petToShow()
    return hoverID or selectedID or lastHoverID or C_PetJournal.GetSummonedPetGUID()
end

function Preview:Attach(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(PANEL_W)
    ns.Skin:Apply("Panel", panel, { inset = true })

    viewer = ns.UI.NewModelViewer(panel, { mouse = true })
    local model = viewer.frame
    panel.viewer, panel.model = viewer, model
    model:SetPoint("TOPLEFT", 4, -4)
    model:SetPoint("TOPRIGHT", -4, -4)
    model:SetHeight(260)
    function panel.relayout(h)
        h = tonumber(h or panel:GetHeight()) or 0
        local extra = math.max(0, (tonumber(panel.weightRow:GetHeight()) or 0) - NAME_LINE_H)
        local slot, withSource, withChance = Preview.Layout(h, extra)
        local mh, gap = Preview.ModelBox(slot)
        model:SetShown(mh > 0)
        model:ClearAllPoints()
        model:SetPoint("TOPLEFT", 4, -4 - gap)
        model:SetPoint("TOPRIGHT", -4, -4 - gap)
        model:SetHeight(math.max(1, mh))
        panel.name:ClearAllPoints()
        if mh > 0 then panel.name:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 4, -10 - gap)
        else panel.name:SetPoint("TOPLEFT", 8, -10) end
        panel.name:SetPoint("RIGHT", -6, 0)
        panel.source:SetShown(withSource)
        panel.sourceHit:SetShown(withSource)
        placeControls(withChance)
        for _, part in ipairs({ panel.chanceLabel, panel.chanceBar, panel.chance, panel.reason }) do
            part:SetShown(withChance)
        end
    end
    panel:SetScript("OnSizeChanged", function(_, _, h)
        if panel.weightRow then panel.relayout(h) end    -- else still being built
    end)

    panel.name = ns.Widgets.Label(panel, "", "GameFontNormalLarge")
    panel.name:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 4, -10)
    panel.name:SetPoint("RIGHT", -6, 0)
    panel.sub = ns.Widgets.Label(panel, "", "GameFontHighlightSmall")
    panel.sub:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -2)
    panel.sub:SetPoint("RIGHT", -6, 0)
    panel.source = ns.Widgets.Label(panel, "", "GameFontDisableSmall")
    panel.source:SetPoint("TOPLEFT", panel.sub, "BOTTOMLEFT", 0, -4)
    panel.source:SetJustifyV("TOP")
    panel.source:SetWordWrap(true)
    -- long lists of zones: three lines at most, cut to the room left, the rest on hover
    panel.source:SetMaxLines(3)
    local sourceHit = CreateFrame("Frame", nil, panel)
    panel.sourceHit = sourceHit
    sourceHit:SetAllPoints(panel.source)
    sourceHit:EnableMouse(true)
    ns.Widgets.Tooltip(sourceHit, function() return panel.name:GetText() end,
        function() return panel.source:GetText() end)

    -- how often: one row of rising steps, named above it; the step under the cursor
    -- names itself there before it is clicked
    panel.weightRow = CreateFrame("Frame", nil, panel)
    panel.weightRow:SetWidth(SCALE_W)
    panel.weight = ns.Widgets.Label(panel.weightRow, "", "GameFontNormalSmall")
    panel.useRule = ns.Widgets.Button(panel.weightRow, L["Use the rule"], function(self)
        if shownID and set then set:UseRule(ns.PetCache:GetCopies(shownID)) end
        self.ruleW = nil
    end)
    ns.Widgets.Tooltip(panel.useRule, L["Use the rule"], function(self)
        return self.ruleW and format(L["The rule gives %s."], ns.Weights.Label(self.ruleW)) or nil
    end)
    panel.useRule:SetNormalFontObject("GameFontNormalSmall")
    panel.useRule:SetHighlightFontObject("GameFontHighlightSmall")
    panel.useRule:SetHeight(18)
    panel.useRule:Hide()
    panel.scale = ns.Widgets.StepScale(panel, ns.Weights.LEVELS, function(value)
        if shownID and set then set:SetPetWeights(ns.PetCache:GetCopies(shownID), value) end
    end, function(step) Preview.NameWeight(step) end)
    panel.scale:SetWidth(SCALE_W)
    panel.scale:Layout()
    Preview.NameWeight()

    -- chance: a bar measured against the most likely pet of the set, and the percentage
    panel.chanceLabel = ns.Widgets.Label(panel, L["Chance in this set"], "GameFontNormalSmall")
    panel.chanceBar = CreateFrame("StatusBar", nil, panel)
    panel.chanceBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    panel.chanceBar:SetStatusBarColor(1, 0.82, 0)
    panel.chanceBar:SetMinMaxValues(0, 1)
    panel.chanceBar:SetHeight(10)
    panel.chanceBar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, CHANCE_BOTTOM + 16)
    panel.chanceBar:SetPoint("RIGHT", -52, 0)
    panel.chanceLabel:SetPoint("BOTTOMLEFT", panel.chanceBar, "TOPLEFT", 0, 4)
    panel.chanceBar.bg = panel.chanceBar:CreateTexture(nil, "BACKGROUND")
    panel.chanceBar.bg:SetAllPoints()
    panel.chanceBar.bg:SetColorTexture(1, 1, 1, 0.08)
    panel.chance = ns.Widgets.Label(panel, "", "GameFontHighlight")
    panel.chance:SetPoint("LEFT", panel.chanceBar, "RIGHT", 6, 0)
    panel.reason = ns.Widgets.Label(panel, "", "GameFontNormalSmall")
    panel.reason:SetPoint("TOPLEFT", panel.chanceBar, "BOTTOMLEFT", 0, -4)
    panel.reason:SetPoint("RIGHT", -6, 0)
    panel.reason:SetWordWrap(false)
    panel.reason:SetTextColor(1, 0.5, 0.25)
    ns.Widgets.Tooltip(panel.chanceBar, L["Chance in this set"], L["The bar compares this pet with the most likely pet of the set."])

    panel.summon = ns.Widgets.Button(panel, L["Summon"], function()
        if shownID then ns:SummonPet(shownID) end
    end)
    panel.summon:SetPoint("BOTTOMLEFT", 6, 8)
    placeControls(true)
    panel.fav = CreateFrame("Button", nil, panel)
    panel.fav:SetSize(22, 22)
    panel.fav:SetPoint("LEFT", panel.summon, "RIGHT", 6, 0)
    panel.fav:SetNormalTexture("Interface\\COMMON\\FavoritesIcon")
    panel.fav:SetHighlightTexture("Interface\\COMMON\\FavoritesIcon", "ADD")
    panel.fav:SetScript("OnClick", function()
        if not shownID then return end
        local info = ns.PetCache:GetInfo(shownID)
        C_PetJournal.SetFavorite(shownID, info.isFavorite and 0 or 1)
    end)
    ns.Widgets.Tooltip(panel.fav, function()
        local info = shownID and ns.PetCache:GetInfo(shownID)
        return info and info.isFavorite and L["Remove favorite"] or L["Set favorite"]
    end)
    return panel
end

-- Each load sets up the whole model scene (3-30 ms). Sweeping the cursor over the grid
-- would load every tile it crosses, so a hover loads once the cursor rests on a tile;
-- the text changes at once. A click loads at once. A dropped load is retried by ShowPet.
local HOVER_DELAY = 0.08
local pending

local function cancelLoad()
    if pending then pending:Cancel() pending = nil end
end

function loadModel(info, later)
    cancelLoad()
    if not later then
        viewer.creatureID = info.creatureID
        viewer:Load(info)
        return
    end
    pending = ns:After(HOVER_DELAY, function()
        pending = nil
        if ns.PetCache:GetInfo(shownID) == info then loadModel(info) end
    end)
end

function Preview:ShowPet(petID, forSet)
    set = forSet or set
    if not panel then return end
    local info = petID and ns.PetCache:GetInfo(petID)
    shownID = info and petID or nil
    if not info then
        cancelLoad()
        panel.name:SetText(L["No pet selected"])
        panel.sub:SetText("") panel.source:SetText("") panel.chance:SetText("") panel.reason:SetText("")
        panel.chanceBar:SetValue(0)
        panel.scale:SetIndex(nil)
        panel.useRule.ruleW = nil
        panel.useRule:Hide()
        Preview.NameWeight()
        viewer:Clear()
        viewer.creatureID = nil      -- forget it, or the same pet would not be loaded again
        return
    end
    -- (re)load when the pet changed or the client dropped the previous load
    if viewer.creatureID ~= info.creatureID or not viewer:ModelID() then
        loadModel(info, hovering)
    else
        cancelLoad()      -- back on the pet already shown: a load on the way is not wanted
    end
    local r, g, b = ns.Widgets.QualityColor(info.quality)
    -- the name the player gave it, as on its tile; the species goes on the line below
    panel.name:SetText(info.customName or info.name)
    panel.name:SetTextColor(r, g, b)
    panel.sub:SetText(format("%s%s · %s %d · %s", info.customName and (info.name .. " · ") or "",
        _G["BATTLE_PET_NAME_" .. (info.petType or 0)] or "", L["Level"], info.level, _G["BATTLE_PET_BREED_QUALITY" .. (info.quality or 2)] or ""))
    local copies = ns.PetCache:GetCopies(petID)
    if #copies > 1 then panel.sub:SetText(panel.sub:GetText() .. " · " .. format(L["%d copies"], #copies)) end
    local _, _, _, _, source = C_PetJournal.GetPetInfoBySpeciesID(info.speciesID)
    panel.source:SetText(Preview.CleanSource(source))
    if set then
        -- what the pet gets: its own setting, else its strongest rule, else the default
        local w, source = set:GetLevel(petID)
        local current, ruleW = ns.Weights.Nearest(w), set:GetAutoWeight(petID)
        for i, lvl in ipairs(ns.Weights.LEVELS) do
            if lvl.value == current then panel.scale:SetIndex(i) end
        end
        panel.levelSource = source
        panel.scale:SetColor(source == "rule" and RULE_COLOR or nil)
        panel.useRule.ruleW = source == "hand" and ruleW > 0 and ruleW or nil
        panel.useRule:SetShown(panel.useRule.ruleW ~= nil)
        Preview.NameWeight()
        -- every copy of the pet is a separate ticket in the draw
        local tbl = set:GetWeightTable()
        local sums, top = set:GetTileSums()
        local mine = sums[copies[1]] or 0
        local chance = (tbl.total or 0) > 0 and mine / tbl.total or 0
        local reason
        for _, id in ipairs(copies) do reason = reason or set:Unavailable(id) end
        panel.chanceBar:SetValue(top > 0 and mine / top or 0)
        panel.chance:SetText(format("%.1f%%", chance * 100))
        panel.reason:SetText(reason or "")
    end
    panel.fav:GetNormalTexture():SetDesaturated(not info.isFavorite)
    panel.fav:GetNormalTexture():SetAlpha(info.isFavorite and 1 or 0.4)
end

-- the set whose weights and chances the panel shows; the next ShowPet or Refresh draws them
function Preview:SetSet(forSet) set = forSet end
function Preview:SetHover(petID)
    hoverID = petID
    if petID then lastHoverID = petID end
    hovering = true
    self:ShowPet(petToShow())
    hovering = false
end
function Preview:SetSelected(petID) selectedID = petID self:ShowPet(petToShow()) end
function Preview:Refresh() self:ShowPet(petToShow()) end
function Preview:GetPanel() return panel end

-- with nothing hovered or picked the panel shows the pet that is out: follow it
ns:RegisterCallback(Preview, "SummonedPetChanged", function()
    if panel and panel:IsVisible() then Preview:Refresh() end
end)
function Preview:GetViewer() return viewer end
function Preview:GetYaw() return viewer:GetYaw() end
function Preview:GetSelected() return selectedID end
function Preview:GetShown() return shownID end
