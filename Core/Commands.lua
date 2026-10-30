local _, ns = ...

local L = ns.L
local Commands = ns:NewModule("Commands")
ns.Commands = Commands

local list = {
    { "config", L["Open the PetCall window"], function() ns:OpenWindow() end },
    { "settings", L["Open the settings"], function() ns:OpenSettings() end },
    { "resummon", L["Summon another pet"], function() ns:SummonAnother() end },
    { "dismiss", L["Dismiss your pet; Auto-summon pauses until you change zone"], function() ns:DismissPet() end },
    { "desummon", nil, function() ns:DismissPet() end },
    { "togglePet", L["Summon or dismiss your pet"], function() ns:TogglePet() end },
    { "enable", L["Toggle auto-summon"], function() ns:SetAutoSummon(not ns:IsAutoSummon()) end },
    { "migrate", L["Import PetLeash data"], function() ns.Migrate:Prompt() end },
    { "debugstate", nil, function()
        local state = ns:GetAutoState()
        ns:Printf("%s: %s", L["Auto-summon"], state == "on" and L["On"] or state == "off" and L["Off"] or L["Paused until you change zone"])
        ns.Ready:DumpDebugState()
    end },
    -- names the parts of PetCall that take long, in chat; takes a reload
    { "profile", nil, function()
        ns.db.global.profile = not ns.db.global.profile or nil
        ReloadUI()
    end },
    { "welcome", nil, function() ns.UI.Welcome:Show(true) end },
    { "holidays", nil, function() ns.Conditions.DumpHolidays() end },
    { "model", nil, function() if ns.UI.DumpModel then ns.UI.DumpModel() end end },
    -- longer test texts in the whole window, for checking the layout; takes a reload
    { "pseudo", nil, function()
        ns.db.global.pseudo = not ns.db.global.pseudo or nil
        ReloadUI()
    end },
    { "help", L["List commands"], function()
        for _, line in ipairs(Commands:HelpLines()) do ns:Print(line) end
    end },
}

local byName = {}
for _, c in ipairs(list) do byName[strlower(c[1])] = c end

function Commands:HelpLines()
    local out = { "/pcall, /petcall – " .. L["Open the PetCall window"] }
    for _, c in ipairs(list) do
        if c[2] then out[#out + 1] = format("/pcall %s – %s", c[1], c[2]) end
    end
    return out
end

function Commands:Handle(input)
    input = strtrim(input or "")
    if input == "" then return ns:OpenWindow() end
    local cmd = input:match("^(%S+)")
    local c = byName[strlower(cmd)]
    if c then return c[3]() end
    ns:Printf(L["Unknown command: %s. Type /pcall help."], cmd)
end

function Commands:OnInitialize()
    SLASH_PETCALL1, SLASH_PETCALL2 = "/petcall", "/pcall"
    SlashCmdList.PETCALL = function(msg) Commands:Handle(msg) end
end
