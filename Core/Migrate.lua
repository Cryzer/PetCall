local _, ns = ...

local L = ns.L
local Migrate = ns:NewModule("Migrate")
ns.Migrate = Migrate

local function hasUserSets(db)
    if type(db) ~= "table" or type(db.profiles) ~= "table" then return false end
    for _, profile in pairs(db.profiles) do
        if type(profile.sets) == "table" then
            for key in pairs(profile.sets) do
                if key ~= "$Default" then return true end
            end
        end
    end
    return false
end

function Migrate:HasPetLeashData()
    return type(PetLeash3DB) == "table" and type(PetLeash3DB.profiles) == "table" and next(PetLeash3DB.profiles) ~= nil
end

StaticPopupDialogs.PETCALL_MIGRATE_PETLEASH = {
    text = L["MIGRATE_PETLEASH_PROMPT"], button1 = YES, button2 = NO,
    OnAccept = function() Migrate:Run() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

function Migrate:Prompt()
    if not self:HasPetLeashData() then return ns:Print(L["No PetLeash data found."]) end
    StaticPopup_Show("PETCALL_MIGRATE_PETLEASH")
end

function Migrate:Run()
    PetCall3DB = CopyTable(PetLeash3DB)
    PetCall3DB._petleashMigrated = true
    PetLeash3DB = nil
    ReloadUI()
end

function Migrate:OnEnable()
    if ns.db.sv._petleashMigrated then
        ns.db.sv._petleashMigrated = nil
        ns:Print(L["MIGRATED_FROM_PETLEASH"])
    elseif self:HasPetLeashData() and not hasUserSets(ns.db.sv) then
        StaticPopup_Show("PETCALL_MIGRATE_PETLEASH")
    end
end
