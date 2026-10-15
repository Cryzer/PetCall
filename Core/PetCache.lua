local _, ns = ...

local C_PetJournal, ipairs, format, strlower, sort, wipe = C_PetJournal, ipairs, format, strlower, table.sort, wipe

local PetCache = ns:NewModule("PetCache")
ns.PetCache = PetCache

local ids, infos, loaded = {}, {}, false

local function readInfo(petID)
    local speciesID, customName, level, _, _, _, isFavorite, name, icon, petType, creatureID =
        C_PetJournal.GetPetInfoByPetID(petID)
    if not speciesID then return nil end
    local _, _, _, _, quality = C_PetJournal.GetPetStats(petID)
    return {
        petID = petID, speciesID = speciesID, customName = customName, level = level or 1,
        name = name or "?", icon = icon, petType = petType, creatureID = creatureID,
        isFavorite = isFavorite and true or false, quality = quality or 2,
        sortKey = format("%s\0%s\0%03d", strlower(name or ""), strlower(customName or ""), level or 0),
    }
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
    loaded = true
    ns:Fire("PetsChanged", listChanged)
end

PetCache.QueueRescan = ns.Debounce(0.5, function() PetCache:Rescan() end)

function PetCache:IteratePetIDs() return ipairs(ids) end
function PetCache:NumPets() return #ids end
function PetCache:IsLoaded() return loaded end
function PetCache:Contains(petID) return infos[petID] ~= nil end
function PetCache:GetInfo(petID) return infos[petID] end
function PetCache:GetSpeciesID(petID) local i = infos[petID] return i and i.speciesID end
function PetCache:GetCreatureID(petID) local i = infos[petID] return i and i.creatureID end
function PetCache:GetSortKey(petID) local i = infos[petID] return i and i.sortKey or "" end

function PetCache:OnEnable()
    self:RegisterEvent("PET_JOURNAL_LIST_UPDATE", "QueueRescan")
    self:RegisterEvent("NEW_PET_ADDED", "QueueRescan")
    self:RegisterEvent("PET_JOURNAL_PET_DELETED", "QueueRescan")
    self:Rescan()
end
