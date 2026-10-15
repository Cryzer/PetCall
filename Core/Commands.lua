local _, ns = ...

local L = ns.L
local Commands = ns:NewModule("Commands")
ns.Commands = Commands

local list = {
    { "config", L["Open the PetCall window"], function() ns:OpenWindow() end },
    { "settings", L["Open the settings"], function() ns:OpenSettings() end },
    { "resummon", L["Summon another pet; turns auto-summon on"], function() ns:ResummonPet(true, true) end },
    { "dismiss", L["Dismiss your pet; turns auto-summon off"], function() ns:DismissPet(true) end },
    { "desummon", nil, function() ns:DismissPet(true) end },
    { "togglePet", L["Toggle your pet and auto-summon"], function() ns:TogglePet() end },
    { "enable", L["Toggle auto-summon"], function() ns:SetAutoSummon(not ns:IsAutoSummon()) end },
    { "dismissWhenStealthed", L["Toggle dismissing in stealth"], function()
        ns.db.profile.dismissWhenStealthed = not ns.db.profile.dismissWhenStealthed
        ns.Ready:UpdateChecks()
        ns:Printf("%s: %s", L["Dismiss When Stealthed or Invisible"], ns.db.profile.dismissWhenStealthed and L["On"] or L["Off"])
    end },
    { "migrate", L["Import PetLeash data"], function() ns.Migrate:Prompt() end },
    { "debugstate", nil, function()
        ns:Printf("%s: %s", L["Auto-summon"], ns:IsAutoSummon() and L["On"] or L["Off"])
        ns.Ready:DumpDebugState()
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
