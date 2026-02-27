
local addon_name, addon = ...

local L = LibStub("AceLocale-3.0"):GetLocale("PetCall")

local next, pairs, type = next, pairs, type

--
-- PetLeash → PetCall migration
--
-- PetCall is the continuation of PetLeash. The SavedVariables global was
-- renamed from PetLeash3DB to PetCall3DB. If PetLeash is (or was) installed
-- alongside PetCall, this offers a one-time import of the user's sets.
--
-- Flow:
--   1. CheckForPetLeash()  — called in OnInitialize, sets _petLeashPending
--   2. ShowMigratePromptIfNeeded() — called in OnEnable, shows StaticPopup
--   3. DoMigratePetLeash() — called on "Yes": copies data, clears PetLeash3DB,
--      reloads the UI so AceDB picks up the migrated PetCall3DB cleanly
--   4. On the next login the post-reload flag is detected and a success
--      message is printed to chat.
--

StaticPopupDialogs["PETCALL_MIGRATE_PETLEASH"] = {
    text = L["MIGRATE_PETLEASH_PROMPT"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        PetCall:DoMigratePetLeash()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function hasPetLeashData()
    if type(PetLeash3DB) ~= "table" then return false end
    if type(PetLeash3DB.profiles) ~= "table" then return false end
    return next(PetLeash3DB.profiles) ~= nil
end

local function hasUserData(db)
    if type(db) ~= "table" then return false end
    if type(db.profiles) ~= "table" then return false end
    for _, profile in pairs(db.profiles) do
        if type(profile.sets) == "table" then
            for key in pairs(profile.sets) do
                if key ~= "$Default" then
                    return true
                end
            end
        end
    end
    return false
end

-- Called from OnInitialize, before AceDB is set up.
function addon:CheckForPetLeash()
    if hasPetLeashData() and not hasUserData(PetCall3DB) then
        self._petLeashPending = true
    end
end

-- Called from OnEnable, once the game UI is ready.
function addon:ShowMigratePromptIfNeeded()
    if self._petLeashPending then
        StaticPopup_Show("PETCALL_MIGRATE_PETLEASH")
    end

    -- Post-reload: AceDB is already initialised with migrated data.
    -- The flag survived as a top-level key in PetCall3DB (ignored by AceDB).
    if self.db.sv._petleashMigrated then
        self.db.sv._petleashMigrated = nil
        self:Print(L["MIGRATED_FROM_PETLEASH"])
    end
end

-- Called via /pcall migrate — allows manual trigger at any time.
function addon:ManualMigratePrompt()
    if not hasPetLeashData() then
        self:Print("No PetLeash data found.")
        return
    end
    StaticPopup_Show("PETCALL_MIGRATE_PETLEASH")
end

-- Called when the user clicks "Yes" in the dialog.
function addon:DoMigratePetLeash()
    self._petLeashPending = nil
    PetCall3DB = CopyTable(PetLeash3DB)
    PetCall3DB._petleashMigrated = true
    PetLeash3DB = nil
    ReloadUI()
end
