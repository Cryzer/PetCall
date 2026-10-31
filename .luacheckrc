std = "lua51"
max_line_length = false

-- 211/212/213: unused var/arg/loop var
-- 411: variable re-defined in same scope
-- 421/422/431/432/433/443: shadowing upvalue / arg / definition / loop var
-- 611/612/613/614: trailing whitespace / whitespace-only line / whitespace in string or comment
ignore = { "211", "212", "213", "411", "421", "422", "431", "432", "433", "443", "611", "612", "613", "614" }

-- Locales are auto-generated from CurseForge and may contain Lua 5.3 \uXXXX escapes.
-- Libs are vendored third-party libraries; not our code to lint.
exclude_files = { "Locales/", "Libs/", "tests/lib/", "tools/", "docs/" }

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
    "SLASH_PETCALL1", "SLASH_PETCALL2", "SlashCmdList",
    "PetCall_OnAddonCompartmentClick", "PetCall_OnAddonCompartmentEnter", "PetCall_OnAddonCompartmentLeave",
}

read_globals = {
    -- PetCall 2.0
    "C_XMLUtil", "CAMERA_TRANSITION_TYPE_IMMEDIATE", "CAMERA_MODIFICATION_TYPE_DISCARD", "Enum", "IsMouseButtonDown",
    "AddonCompartmentFrame", "IsControlKeyDown",
    "SettingsPanel",
    "ButtonFrameTemplate_HidePortrait",
    "NONE", "DELETE",
    "IsInRaid",
    "ERR_MUST_BE_STANDING", "SPELL_FAILED_NOT_STANDING",
    "GetCursorPosition", "GetCurrentKeyBoardFocus", "ScrollBoxConstants", "NAME", "RARITY", "ToggleCollectionsJournal",
    "ButtonFrameTemplate_HideButtonBar", "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "PanelTemplates_TabResize",
    "GetScreenWidth", "GetScreenHeight", "MinimalSliderWithSteppersMixin", "SOUNDKIT", "EllesmereUI", "MenuUtil", "ScrollUtil",
    "CreateDataProvider", "CreateScrollBoxListLinearView", "Settings", "CreateSettingsListSectionHeaderInitializer",
    "CreateSettingsButtonInitializer", "GameTooltip", "UIErrorsFrame", "StaticPopup_Show",
    "C_EncodingUtil", "C_PartyInfo", "GetGameTime", "UnitName", "GetRealmName", "UISpecialFrames", "geterrorhandler",

    -- libraries
    "LibStub",

    -- WoW C_ namespaces
    "C_PetJournal", "C_Timer", "C_AddOns", "C_Item", "C_Map", "C_Housing", "C_MountJournal", "C_TransmogOutfitInfo", "MountJournal", "MOUNT_JOURNAL_FILTER_GROUND", "MOUNT_JOURNAL_FILTER_FLYING",
    "MOUNT_JOURNAL_FILTER_AQUATIC", "MOUNT_JOURNAL_FILTER_DRAGONRIDING", "MOUNT_JOURNAL_FILTER_RIDEALONG", "C_Calendar", "C_DateAndTime",
    "C_QuestLog", "C_SettingsUtil", "C_Spell", "C_UnitAuras", "issecretvalue",
    "C_ChatInfo", "C_SpecializationInfo", "C_PetBattles",

    -- WoW UI
    "CreateFrame", "UIParent", "GameTooltip", "Settings",
    "StaticPopup_Show",
    "SearchBoxTemplate_OnEditFocusLost", "SearchBoxTemplate_OnTextChanged",
    "BackdropTemplateMixin",
    "MenuUtil", "Menu", "MenuVariants", "AnchorUtil",
    "UIErrorsFrame",

    -- WoW fonts
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalLarge",
    "ChatFontNormal", "SystemFont_Tiny",

    -- WoW API functions
    "GetTime", "GetServerTime", "GetZoneText", "GetServerExpansionLevel", "GetClientDisplayExpansionLevel", "GetSubZoneText", "GetLocale",
    "GetNumGroupMembers", "GetBuildInfo",
    "GetSpecialization", "GetSpecializationInfo",
    "GetBindingKey",
    "HasFullControl", "InCombatLockdown", "IsFalling", "IsFlying",
    "IsInGroup", "IsInInstance", "IsResting", "IsStealthed",
    "IsControlKeyDown", "IsMounted", "IsSwimming", "IsSubmerged", "IsIndoors", "IsOutdoors", "GetShapeshiftFormID",
    "UnitCastingInfo", "UnitChannelInfo", "UnitClass", "UnitFactionGroup", "UnitInVehicle",
    "UnitIsDeadOrGhost", "UnitIsAFK", "SendChatMessage",
    "SecureCmdOptionParse", "PlaySound", "PlaySoundFile", "HelpPlate", "HelpPlateTooltip", "MAIN_HELP_BUTTON_TOOLTIP",
    "ReloadUI",
    "hooksecurefunc", "CopyTable", "debugstack", "debugprofilestop",

    -- WoW stdlib aliases (globals in WoW environment)
    "format", "max",
    "strfind", "strlower", "strsub", "strtrim",
    "tinsert", "tremove", "tconcat", "wipe",
    "floor", "ceil", "fastrandom",

    -- WoW locale strings (global constants)
    "GENERAL", "DEFAULT_CHAT_FRAME",
    "DELETE", "CANCEL", "SAVE", "ENABLE", "ALL", "DEFAULT", "FILTER",
    "YES", "NO", "LEVEL", "FAVORITES",
    "SOUNDKIT",

    -- WoW pet/class/specialization constants
    "PET_TYPE_SUFFIX", "TOOLTIP_WILDBATTLEPET_LEVEL_CLASS",
    "CLASS_SORT_ORDER", "LOCALIZED_CLASS_NAMES_MALE", "C_UI", "QUI", "GetNumClasses", "GetClassInfo", "GetSpecializationInfoForClassID",

    -- Trigger type locale strings (WoW globals used as display names)
    "ZONE", "BATTLEGROUND", "TYPE", "GROUP", "PARTY", "RAID",
    "CLASS", "SPECIALIZATION", "ITEMS",
}

files["tests/"] = { std = "+busted", globals = { "PetCall3DB", "PetLeash3DB", "PetCall", "assert", "issecretvalue",
    -- game functions a test swaps for its own
    "C_Housing", "C_Map", "C_PetJournal", "GetClientDisplayExpansionLevel", "GetServerExpansionLevel", "GetZoneText", "ReloadUI",
    "Settings", "CreateSettingsButtonInitializer", "CreateSettingsListSectionHeaderInitializer", "SettingsPanel",
    "GetCurrentKeyBoardFocus", "SetItemRef", "DoEmote", "SitStandOrDescendStart" }, allow_defined_top = true }
-- the stub exists to define WoW globals
files["tests/wowstub.lua"] = { ignore = { "1" } }
files["tests/uistub.lua"] = { ignore = { "1" } }
