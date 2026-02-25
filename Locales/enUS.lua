
--[[

Translations are maintained at http://wow.curseforge.com/projects/petcall/localization/

This is the master import file for the localization system.  All changes to this
file need to be updated in the localization system.

--]]

local L = LibStub("AceLocale-3.0"):NewLocale("PetCall", "enUS", true)
if not L then return end

L[" <<< Back "] = true
L["Active Set:"] = true
L["Add Filter"] = true
L["Add Trigger Condition"] = true
L["Allow PetCall to summon pets while in battlegrounds and arenas. Cannot be combined with Dismiss In Battlegrounds."] = true
L["Allow PetCall to summon pets while in dungeons and raids. Cannot be combined with Dismiss In PVE Instances."] = true
L["Any"] = true
L["Auto Summon:"] = true
L["Auto Switch Pet"] = true
L["Auto Switch when changing maps"] = true
L["Automatically dismiss your pet when entering a battleground or arena. Cannot be combined with Enable In Battlegrounds."] = true
L["Automatically dismiss your pet when entering a dungeon or raid. Cannot be combined with Enable In PVE Instances."] = true
L["Automatically dismiss your pet when you enter stealth or use an invisibility effect."] = true
L["Automatically summon a companion pet when entering a new area or when idle. Respects your pet selection, filters, and trigger settings."] = true
L["Automatically switch to a different random pet from your selection after a set amount of time."] = true
L["City"] = true
L["Class Specialization"] = true
L["Copy Current Subzone"] = true
L["Copy Current Zone"] = true
L["Ctrl + Click:"] = true
L["Current Pet:"] = true
L["Disabled"] = true
L["Dismiss In Battlegrounds/Arena"] = true
L["Dismiss In PVE Instances"] = true
L["Dismiss Pet"] = true
L["Dismiss When Stealthed or Invisible"] = true
L["Dismiss your current pet and summon another pet.  Enable summoning if needed."] = true
L["Dismiss your currently summoned pet.  Disable summoning."] = true
L["Edit"] = true
L["Enable In Battlegrounds/Arena"] = true
L["Enable In Combat"] = true
L["Enable In PVE Instances"] = true
L["Enable Timed Auto Switch"] = true
L["Enabled"] = true
L["EXPLAIN_SPECIAL_ITEMS"] = "Certain items act like a companion pet when used, but the UI does not indicate that a companion pet is currently being used.  PetCall can temporarily deactivate when such an item is detected."
L["EXPLAIN_WEIGHTED_CHECKBOX"] = "Click checkbox: toggle on/off  ·  Right-click checkbox: set priority"
L["Extra High Priority"] = true
L["Extra Low Priority"] = true
L["Filters"] = true
L["High Priority"] = true
L["How often (in seconds) to automatically switch to a different pet from your selection."] = true
L["Immediate"] = true
L["Instance"] = true
L["Left-Click:"] = true
L["Low Priority"] = true
L["Lua Code"] = true
L["MACRO_CONDITION_HELP"] = "Enter a macro conditional in a form such as [outdoors,swimming]"
L["Macro Conditional"] = true
L["Never"] = true
L["Normal"] = true
L["Only Enable in Cities"] = true
L["Only Summon After Zoning"] = true
L["Only summon a pet when entering a new area or zone. When disabled, a pet is also summoned after standing still for the configured wait time."] = true
L["Only use Timed Auto Switch in cities"] = true
L["Open Configuration Panel"] = true
L["Open Configuration"] = true
L["Override Pet Battle Loadout"] = true
L["Pet Menu"] = true
L["Pet Selection"] = true
L["Pet Triggers"] = true
L["Pets"] = true
L["Print a message in the chat window each time a pet is summoned or dismissed."] = true
L["Priority"] = true
L["Profiles"] = true
L["Re-summon your PetCall pet after the game auto-summons one via the Pet Battle Loadout screen."] = true
L["Rename to"] = true
L["Reset"] = true
L["Restrict pet summoning to city areas only. Your pet will be dismissed when you leave a city."] = true
L["Restrict timed pet switching to city areas. Automatic switching pauses when you leave a city."] = true
L["Right-Click:"] = true
L["Seconds between switch"] = true
L["Seconds of inactivity before PetCall summons a pet. Only applies when Only Summon After Zoning is disabled."] = true
L["Select Pets"] = true
L["Selected"] = true
L["Show Minimap Button"] = true
L["Show the PetCall icon on the minimap for quick access to the pet selection menu."] = true
L["Special Items"] = true
L["Special Location"] = true
L["MIGRATE_PETLEASH_PROMPT"] = "PetLeash profile data was found.\n\nImport into PetCall?\nThe UI will reload."
L["MIGRATED_FROM_PETLEASH"] = "Your PetLeash profile data has been migrated to PetCall."
L["SUMMONING_MSG"] = "Summoning %s"
L["Summon Another Pet"] = true
L["Switch to a different random pet each time you travel to a new map or zone."] = true
L["Toggle Non-Combat Pet"] = true
L["Unselected"] = true
L["Verbose"] = true
L["Wait Time (Seconds)"] = true
L["You have %d pets"] = true
L["You have no pets"] = true
