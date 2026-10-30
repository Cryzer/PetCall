local _, ns = ...

local L = ns.L
local Tab = {}
local editor

function Tab:Refresh(set)
    if editor then editor:Refresh(set) end
end

ns.UI.Main:RegisterTab("when", L["When"], function(page)
    editor = ns.UI.ConditionEditor.New(page)
    return Tab
end, 2)
