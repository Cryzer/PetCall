std = "lua51"
max_line_length = false
ignore = { "211", "212", "213" }

globals = {
    "PetCall",
    "BINDING_HEADER_PETCALL",
    "BINDING_NAME_PETCALL_SUMMON",
    "BINDING_NAME_PETCALL_DESUMMON",
    "BINDING_NAME_PETCALL_TOGGLE",
    "BINDING_NAME_PETCALL_CONFIG",
}

read_globals = {
    "LibStub",
    "C_PetJournal", "C_Timer", "C_AddOns", "C_Item", "C_Map",
    "C_QuestLog", "C_SettingsUtil", "C_Spell", "C_UnitAuras",
    "CreateFrame", "UIParent", "GameTooltip", "Settings",
    "GetTime", "GetZoneText", "GetSubZoneText", "GetLocale",
    "GetItemCount", "GetItemInfo", "GetNumGroupMembers",
    "HasFullControl", "InCombatLockdown", "IsFalling", "IsFlying",
    "IsInGroup", "IsInInstance", "IsResting", "IsStealthed",
    "IsControlKeyDown", "IsEquippedItem",
    "UnitCastingInfo", "UnitChannelInfo", "UnitClass", "UnitInVehicle",
    "UnitIsDeadOrGhost",
    "SecureCmdOptionParse", "PlaySound", "PlaySoundFile",
    "StaticPopup_Show", "StaticPopupDialogs", "SOUNDKIT",
    "ReloadUI", "SlashCmdList", "SLASH_PETCALL1",
    "strfind", "strlower", "strsub", "strtrim",
    "tinsert", "tremove", "tconcat", "wipe",
    "floor", "ceil", "fastrandom",
    "GENERAL", "DEFAULT_CHAT_FRAME",
    "SearchBoxTemplate_OnEditFocusLost",
    "SearchBoxTemplate_OnTextChanged",
    "BackdropTemplateMixin",
}
