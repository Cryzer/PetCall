local _, ns = ...

local C_PetJournal, ipairs, format, strlower, sort, wipe = C_PetJournal, ipairs, format, strlower, table.sort, wipe

local PetCache = ns:NewModule("PetCache")
ns.PetCache = PetCache

local ids, infos, loaded = {}, {}, false

local function readInfo(petID)
    local speciesID, customName, level, _, _, displayID, isFavorite, name, icon, petType, creatureID =
        C_PetJournal.GetPetInfoByPetID(petID)
    if not speciesID then return nil end
    local _, _, _, _, quality = C_PetJournal.GetPetStats(petID)
    return {
        petID = petID, speciesID = speciesID, customName = customName, level = level or 1,
        name = name or "?", icon = icon, petType = petType, creatureID = creatureID,
        -- this pet's own look: species with several looks (Trading Post pets) have no
        -- textures on the species-wide display and render white
        displayID = displayID ~= 0 and displayID or nil,
        isFavorite = isFavorite and true or false, quality = quality or 2,
        sortKey = format("%s\0%s\0%03d", strlower(name or ""), strlower(customName or ""), level or 0),
    }
end

-- Copies: owned pets of one species with the same visible name. The primary copy
-- (favorite, else highest level, else best quality) stands for the group in lists.
local copiesOf = {}     -- petID -> { primary, other copies in list order }

local function better(a, b)
    if a.isFavorite ~= b.isFavorite then return a.isFavorite end
    if a.level ~= b.level then return a.level > b.level end
    return a.quality > b.quality
end

local function groupCopies()
    wipe(copiesOf)
    local groups = {}
    for _, id in ipairs(ids) do
        local info = infos[id]
        local key = info.speciesID .. "\0" .. strlower(info.customName or info.name)
        local g = groups[key]
        if not g then g = {} groups[key] = g end
        g[#g + 1] = id
        copiesOf[id] = g
    end
    for _, g in pairs(groups) do
        local best = 1
        for i = 2, #g do if better(infos[g[i]], infos[g[best]]) then best = i end end
        if best ~= 1 then table.insert(g, 1, table.remove(g, best)) end
    end
end

function PetCache:Rescan()
    local owned = C_PetJournal.GetOwnedPetIDs()
    if not owned then return end
    local old = {}
    for _, id in ipairs(ids) do old[id] = true end
    wipe(ids)
    wipe(infos)
    local listChanged = false
    for _, id in ipairs(owned) do
        if not C_PetJournal.PetNeedsFanfare(id) then
            local info = readInfo(id)
            if info then
                ids[#ids + 1], infos[id] = id, info
                if not old[id] then listChanged = true end
                old[id] = nil
            end
        end
    end
    if next(old) then listChanged = true end
    sort(ids, function(a, b)
        local ka, kb = infos[a].sortKey, infos[b].sortKey
        if ka == kb then return a < b end
        return ka < kb
    end)
    groupCopies()
    loaded = true
    ns:Fire("PetsChanged", listChanged)
end

PetCache.QueueRescan = ns.Debounce(0.5, function() PetCache:Rescan() end)

function PetCache:IteratePetIDs() return ipairs(ids) end
function PetCache:NumPets() return #ids end
function PetCache:IsLoaded() return loaded end
-- GetPetCooldownByGUID returns start, duration: a start time alone does not mean the cooldown is still running
function PetCache:OnCooldown(petID)
    local start, duration = C_PetJournal.GetPetCooldownByGUID(petID)
    return (start or 0) > 0 and (duration or 0) > 0 and start + duration > GetTime()
end

function PetCache:GetCopies(petID) return copiesOf[petID] or { petID } end
function PetCache:IsPrimary(petID) local g = copiesOf[petID] return g ~= nil and g[1] == petID end
function PetCache:Contains(petID) return infos[petID] ~= nil end
function PetCache:GetInfo(petID) return infos[petID] end
function PetCache:GetSpeciesID(petID) local i = infos[petID] return i and i.speciesID end
function PetCache:GetCreatureID(petID) local i = infos[petID] return i and i.creatureID end

-- the journal's "where from" text, plain and lower case, for rules that search it
local sources = {}      -- speciesID -> text
function PetCache:GetSourceText(petID)
    local i = infos[petID]
    if not i then return "" end
    local s = sources[i.speciesID]
    if not s then
        local _, _, _, _, raw = C_PetJournal.GetPetInfoBySpeciesID(i.speciesID)
        s = strlower(((raw or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " ")))
        sources[i.speciesID] = s
    end
    return s
end
function PetCache:GetSortKey(petID) local i = infos[petID] return i and i.sortKey or "" end

function PetCache:OnEnable()
    self:RegisterEvent("PET_JOURNAL_LIST_UPDATE", "QueueRescan")
    self:RegisterEvent("NEW_PET_ADDED", "QueueRescan")
    self:RegisterEvent("PET_JOURNAL_PET_DELETED", "QueueRescan")
    self:Rescan()
end
