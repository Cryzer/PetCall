std = "lua51"
max_line_length = false

-- 211/212/213: unused var/arg/loop var
-- 411: variable re-defined in same scope
-- 421/422/431/432/433/443: shadowing upvalue / arg / definition / loop var
-- 611/612/613/614: trailing whitespace / whitespace-only line / whitespace in string or comment
ignore = { "211", "212", "213", "411", "421", "422", "431", "432", "433", "443", "611", "612", "613", "614" }

-- Locales are auto-generated from CurseForge and may contain Lua 5.3 \uXXXX escapes.
-- Libs are vendored third-party libraries; not our code to lint.
exclude_files = { "Locales/", "Libs/" }

globals = {
    -- Addon globals
    "PetCall",
    "BINDING_HEADER_PETCALL",
    "BINDING_NAME_PETCALL_SUMMON",
    "BINDING_NAME_PETCALL_DESUMMON",
    "BINDING_NAME_PETCALL_TOGGLE",
    "BINDING_NAME_PETCALL_CONFIG",

    -- SavedVariables (written at top level by WoW, read/written by addon)
    "PetCall3DB",
    "PetLeash3DB",

    -- WoW tables we write into (e.g. StaticPopupDialogs["PETCALL_..."] = {...})
    "StaticPopupDialogs",
}

read_globals = {
    -- Ace libraries
    "LibStub",

    -- WoW C_ namespaces
    "C_PetJournal", "C_Timer", "C_AddOns", "C_Item", "C_Map",
    "C_QuestLog", "C_SettingsUtil", "C_Spell", "C_UnitAuras",

    -- WoW UI
    "CreateFrame", "UIParent", "GameTooltip", "Settings",
    "StaticPopup_Show",
    "SearchBoxTemplate_OnEditFocusLost", "SearchBoxTemplate_OnTextChanged",
    "BackdropTemplateMixin",
    "MenuUtil",
    "UIErrorsFrame",

    -- WoW fonts
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge",
    "ChatFontNormal", "SystemFont_Tiny",

    -- WoW API functions
    "GetTime", "GetZoneText", "GetSubZoneText", "GetLocale",
    "GetItemCount", "GetItemInfo", "GetNumGroupMembers",
    "GetSpecialization", "GetSpecializationInfo",
    "GetBindingKey",
    "HasFullControl", "InCombatLockdown", "IsFalling", "IsFlying",
    "IsInGroup", "IsInInstance", "IsResting", "IsStealthed",
    "IsControlKeyDown", "IsEquippedItem", "IsMounted",
    "UnitCastingInfo", "UnitChannelInfo", "UnitClass", "UnitInVehicle",
    "UnitIsDeadOrGhost", "UnitIsAFK",
    "SecureCmdOptionParse", "PlaySound", "PlaySoundFile",
    "ReloadUI", "SlashCmdList", "SLASH_PETCALL1",
    "hooksecurefunc", "CopyTable",

    -- WoW stdlib aliases (globals in WoW environment)
    "format", "max",
    "strfind", "strlower", "strsub", "strtrim",
    "tinsert", "tremove", "tconcat", "wipe",
    "floor", "ceil", "fastrandom",

    -- WoW locale strings (global constants)
    "GENERAL", "DEFAULT_CHAT_FRAME",
    "DELETE", "CANCEL", "ENABLE", "ALL", "DEFAULT", "FILTER",
    "YES", "NO", "LEVEL", "FAVORITES",
    "SOUNDKIT",

    -- WoW pet/class/specialization constants
    "PET_TYPE_SUFFIX", "TOOLTIP_WILDBATTLEPET_LEVEL_CLASS",
    "CLASS_SORT_ORDER", "LOCALIZED_CLASS_NAMES_MALE",

    -- Trigger type locale strings (WoW globals used as display names)
    "ZONE", "BATTLEGROUND", "TYPE", "GROUP", "PARTY", "RAID",
    "CLASS", "SPECIALIZATION", "ITEMS",
}
