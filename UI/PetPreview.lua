local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Preview = {}
ns.UI.Preview = Preview

local panel, viewer, set, hoverID, selectedID
local shownID
local loadModel        -- assigned above Preview:ShowPet
local MODEL_SHARE = 0.55        -- part of the panel's height given to the model

-- a selected pet stays in the panel; hovering only previews while nothing is selected
local function petToShow()
    return selectedID or hoverID or C_PetJournal.GetSummonedPetGUID()
end

function Preview:Attach(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(240)
    ns.Skin:Apply("Panel", panel, { inset = true })

    viewer = ns.UI.NewModelViewer(panel, { mouse = true })
    local model = viewer.frame
    panel.viewer, panel.model = viewer, model
    model:SetPoint("TOPLEFT", 4, -4)
    model:SetPoint("TOPRIGHT", -4, -4)
    model:SetHeight(260)
    -- the model takes over half of the panel; text and controls sit below it
    panel:SetScript("OnSizeChanged", function(_, _, h) model:SetHeight(math.max(200, (h or 0) * MODEL_SHARE)) end)

    panel.name = ns.Widgets.Label(panel, "", "GameFontNormalLarge")
    panel.name:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 4, -10)
    panel.name:SetPoint("RIGHT", -6, 0)
    panel.sub = ns.Widgets.Label(panel, "", "GameFontHighlightSmall")
    panel.sub:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -2)
    panel.sub:SetPoint("RIGHT", -6, 0)
    panel.source = ns.Widgets.Label(panel, "", "GameFontDisableSmall")
    panel.source:SetPoint("TOPLEFT", panel.sub, "BOTTOMLEFT", 0, -4)
    panel.source:SetPoint("RIGHT", -6, 0)
    panel.source:SetWordWrap(true)
    -- long lists of zones would push the controls into the Summon button: three lines, the rest on hover
    panel.source:SetMaxLines(3)
    local sourceHit = CreateFrame("Frame", nil, panel)
    sourceHit:SetAllPoints(panel.source)
    sourceHit:EnableMouse(true)
    ns.Widgets.Tooltip(sourceHit, function() return panel.name:GetText() end,
        function() return panel.source:GetText() end)

    -- how often: six named steps in two rows instead of an unlabelled slider
    panel.weight = ns.Widgets.Label(panel, L["How often"], "GameFontNormalSmall")
    panel.weight:SetPoint("TOPLEFT", panel.source, "BOTTOMLEFT", 0, -12)
    panel.levels = {}
    for i, lvl in ipairs(ns.Weights.LEVELS) do
        local btn = ns.Widgets.Button(panel, lvl.label, function()
            if shownID and set then set:SetPetWeights(ns.PetCache:GetCopies(shownID), lvl.value) end
        end)
        btn:SetNormalFontObject("GameFontNormalSmall")
        btn:SetHighlightFontObject("GameFontHighlightSmall")
        btn:SetHeight(20)
        btn.value = lvl.value
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        btn:SetPoint("TOPLEFT", panel.weight, "BOTTOMLEFT", col * 76, -4 - row * 22)
        btn:SetWidth(76)
        panel.levels[i] = btn
    end

    -- chance: a bar measured against the most likely pet of the set, and the percentage
    panel.chanceLabel = ns.Widgets.Label(panel, L["Chance in this set"], "GameFontNormalSmall")
    panel.chanceLabel:SetPoint("TOPLEFT", panel.levels[4], "BOTTOMLEFT", 0, -12)
    panel.chanceBar = CreateFrame("StatusBar", nil, panel)
    panel.chanceBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    panel.chanceBar:SetStatusBarColor(1, 0.82, 0)
    panel.chanceBar:SetMinMaxValues(0, 1)
    panel.chanceBar:SetHeight(10)
    panel.chanceBar:SetPoint("TOPLEFT", panel.chanceLabel, "BOTTOMLEFT", 0, -4)
    panel.chanceBar:SetPoint("RIGHT", -52, 0)
    panel.chanceBar.bg = panel.chanceBar:CreateTexture(nil, "BACKGROUND")
    panel.chanceBar.bg:SetAllPoints()
    panel.chanceBar.bg:SetColorTexture(1, 1, 1, 0.08)
    panel.chance = ns.Widgets.Label(panel, "", "GameFontHighlight")
    panel.chance:SetPoint("LEFT", panel.chanceBar, "RIGHT", 6, 0)
    panel.reason = ns.Widgets.Label(panel, "", "GameFontNormalSmall")
    panel.reason:SetPoint("TOPLEFT", panel.chanceBar, "BOTTOMLEFT", 0, -4)
    panel.reason:SetPoint("RIGHT", -6, 0)
    panel.reason:SetTextColor(1, 0.5, 0.25)
    ns.Widgets.Tooltip(panel.chanceBar, L["Chance in this set"], L["The bar compares this pet with the most likely pet of the set."])

    panel.summon = ns.Widgets.Button(panel, L["Summon"], function()
        if shownID then ns:SummonPet(shownID) end
    end)
    panel.summon:SetPoint("BOTTOMLEFT", 6, 8)
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

-- loads at once: responsiveness beats saving loads; a dropped load is retried by ShowPet
function loadModel(info)
    viewer:Load(info)
end

function Preview:ShowPet(petID, forSet)
    set = forSet or set
    if not panel then return end
    local info = petID and ns.PetCache:GetInfo(petID)
    shownID = info and petID or nil
    if not info then
        panel.name:SetText(L["No pet selected"])
        panel.sub:SetText("") panel.source:SetText("") panel.chance:SetText("") panel.reason:SetText("")
        panel.chanceBar:SetValue(0)
        viewer:Clear()
        viewer.creatureID = nil      -- forget it, or the same pet would not be loaded again
        return
    end
    -- (re)load when the pet changed or the client dropped the previous load
    if viewer.creatureID ~= info.creatureID or not viewer:ModelID() then
        viewer.creatureID = info.creatureID
        loadModel(info)
    end
    local r, g, b = ns.Widgets.QualityColor(info.quality)
    panel.name:SetText(info.name)
    panel.name:SetTextColor(r, g, b)
    panel.sub:SetText(format("%s%s · %s %d · %s", info.customName and ("«" .. info.customName .. "» ") or "",
        _G["BATTLE_PET_NAME_" .. (info.petType or 0)] or "", L["Level"], info.level, _G["BATTLE_PET_BREED_QUALITY" .. (info.quality or 2)] or ""))
    local copies = ns.PetCache:GetCopies(petID)
    if #copies > 1 then panel.sub:SetText(panel.sub:GetText() .. " · " .. format(L["%d copies"], #copies)) end
    local _, _, _, _, source = C_PetJournal.GetPetInfoBySpeciesID(info.speciesID)
    panel.source:SetText(source or "")
    if set then
        local current = ns.Weights.Nearest(set:GetPetWeight(petID))
        for _, btn in ipairs(panel.levels) do
            ns.Widgets.SetPicked(btn, btn.value == current)
        end
        -- every copy of the pet is a separate ticket in the draw
        local tbl, sums, top = set:GetWeightTable(), {}, 0
        for i = 1, #tbl, 2 do
            local primary = ns.PetCache:GetCopies(tbl[i + 1])[1]
            sums[primary] = (sums[primary] or 0) + tbl[i]
            if sums[primary] > top then top = sums[primary] end
        end
        local mine = sums[copies[1]] or 0
        local chance = (tbl.total or 0) > 0 and mine / tbl.total or 0
        local reason
        for _, id in ipairs(copies) do reason = reason or select(2, set:GetChance(id)) end
        panel.chanceBar:SetValue(top > 0 and mine / top or 0)
        panel.chance:SetText(format("%.1f%%", chance * 100))
        panel.reason:SetText(reason or "")
    end
    panel.fav:GetNormalTexture():SetDesaturated(not info.isFavorite)
    panel.fav:GetNormalTexture():SetAlpha(info.isFavorite and 1 or 0.4)
end

function Preview:SetHover(petID) hoverID = petID self:ShowPet(petToShow()) end
function Preview:SetSelected(petID) selectedID = petID self:ShowPet(petToShow()) end
function Preview:Refresh() self:ShowPet(petToShow()) end
function Preview:GetPanel() return panel end
function Preview:GetViewer() return viewer end
function Preview:GetYaw() return viewer:GetYaw() end
function Preview:GetSelected() return selectedID end
function Preview:GetShown() return shownID end
