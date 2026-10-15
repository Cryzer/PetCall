local _, ns = ...

local Commands = ns:NewModule("Commands")
ns.Commands = Commands
Commands.handlers = {}

function Commands:Handle(input)
    input = strtrim(input or "")
    if input == "" then return ns:OpenWindow() end
    local cmd, rest = input:match("^(%S+)%s*(.-)$")
    local h = self.handlers[strlower(cmd)]
    if h then return h(rest) end
    ns:Printf(ns.L["Unknown command: %s. Type /pcall help."], cmd)
end

function Commands:OnInitialize()
    SLASH_PETCALL1, SLASH_PETCALL2 = "/petcall", "/pcall"
    SlashCmdList.PETCALL = function(msg) Commands:Handle(msg) end
end
