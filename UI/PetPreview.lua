local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Preview = {}
ns.UI.Preview = Preview

local panel, viewer, set, hoverID, selectedID
local shownID, syncing
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

    -- weight label above the slider: the slider's own side label does not fit the panel
    panel.weight = ns.Widgets.Label(panel, "", "GameFontNormal")
    panel.weight:SetPoint("TOPLEFT", panel.source, "BOTTOMLEFT", 0, -12)
    panel.weight:SetPoint("RIGHT", -6, 0)

    local steps = #ns.Weights.LEVELS - 1
    panel.slider = ns.Widgets.Slider(panel, 0, steps, steps, 3, function(v)
        -- the slider also reports our own SetValue calls; only user moves change weights,
        -- and only for the pet the panel is showing
        if syncing or not shownID or not set then return end
        local value = ns.Weights.LEVELS[math.floor(v + 0.5) + 1].value
        if ns.Weights.Nearest(set:GetPetWeight(shownID)) ~= value then set:SetPetWeights(ns.PetCache:GetCopies(shownID), value) end
    end)
    panel.slider:SetPoint("TOPLEFT", panel.weight, "BOTTOMLEFT", -2, -4)
    panel.slider:SetPoint("RIGHT", -6, 0)

    panel.chance = ns.Widgets.Label(panel, "", "GameFontHighlight")
    panel.chance:SetPoint("TOPLEFT", panel.slider, "BOTTOMLEFT", 2, -8)
    panel.chance:SetPoint("RIGHT", -6, 0)

    panel.summon = ns.Widgets.Button(panel, L["Summon"], function()
        if shownID then ns:SummonPet(shownID) end
    end)
    panel.summon:SetPoint("BOTTOMLEFT", 6, 6)
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

-- Model loads are asynchronous and the client drops some when flooded, so a mouse
-- sweep over the grid only loads the pet it stops on.
local HOVER_DELAY = 0.12
local pendingLoad

function loadModel(info, fromHover)
    if pendingLoad then pendingLoad:Cancel() pendingLoad = nil end
    local function load()
        pendingLoad = nil
        if viewer.creatureID ~= info.creatureID then return end   -- moved on meanwhile
        viewer:Load(info)
    end
    if fromHover then pendingLoad = C_Timer.NewTimer(HOVER_DELAY, load) else load() end
end

function Preview:ShowPet(petID, forSet)
    set = forSet or set
    if not panel then return end
    local info = petID and ns.PetCache:GetInfo(petID)
    shownID = info and petID or nil
    if not info then
        panel.name:SetText(L["No pet selected"])
        panel.sub:SetText("") panel.source:SetText("") panel.chance:SetText("") panel.weight:SetText("")
        viewer:Clear()
        viewer.creatureID = nil      -- forget it, or the same pet would not be loaded again
        return
    end
    -- (re)load when the pet changed or the client dropped the previous load
    if viewer.creatureID ~= info.creatureID or not viewer:ModelID() then
        viewer.creatureID = info.creatureID
        loadModel(info, petID ~= selectedID)
    end
    local r, g, b = C_Item.GetItemQualityColor((info.quality or 2) - 1)
    panel.name:SetText(info.name)
    panel.name:SetTextColor(r, g, b)
    panel.sub:SetText(format("%s%s · %s %d · %s", info.customName and ("«" .. info.customName .. "» ") or "",
        _G["BATTLE_PET_NAME_" .. (info.petType or 0)] or "", L["Level"], info.level, _G["BATTLE_PET_BREED_QUALITY" .. (info.quality or 2)] or ""))
    local copies = ns.PetCache:GetCopies(petID)
    if #copies > 1 then panel.sub:SetText(panel.sub:GetText() .. " · " .. format(L["%d copies"], #copies)) end
    local _, _, _, _, source = C_PetJournal.GetPetInfoBySpeciesID(info.speciesID)
    panel.source:SetText(source or "")
    if set then
        local w = set:GetPetWeight(petID)
        panel.weight:SetText(L["Weight"] .. ": |cffffffff" .. ns.Weights.Label(w) .. "|r")
        syncing = true
        for i, lvl in ipairs(ns.Weights.LEVELS) do
            if lvl.value == ns.Weights.Nearest(w) then panel.slider:SetValue(i - 1) end
        end
        syncing = false
        -- every copy of the pet is a separate ticket in the draw
        local chance, reason = 0, nil
        for _, id in ipairs(copies) do
            local c, r = set:GetChance(id)
            chance, reason = chance + c, reason or r
        end
        panel.chance:SetText(format(L["Chance in this set: %.1f%%"], chance * 100) .. (reason and ("\n|cffff8040" .. reason .. "|r") or ""))
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
