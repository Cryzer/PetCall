local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local Menu = {}
ns.UI.Menu = Menu

local PAGE = 25
local preview

local function iterUtf8(s) return s:gmatch("([%z\1-\127\194-\244][\128-\191]*)") end

-- shortest distinguishing prefixes for a page label "Ab – Ca"
local function prefix(a, b)
    if not b then return iterUtf8(a)() end
    local ia, ib, r = iterUtf8(a), iterUtf8(b), ""
    local ca, cb = ia(), ib()
    while ca and cb do
        if ca ~= cb then return r .. ca end
        r = r .. ca
        ca, cb = ia(), ib()
    end
    return r
end

local function petName(id) local i = ns.PetCache:GetInfo(id) return i and (i.customName or i.name) or "?" end

local function addPet(root, id)
    local info = ns.PetCache:GetInfo(id)
    if not info then return end
    local b = root:CreateButton(format("|T%s:16|t %s", info.icon or 0, petName(id)), function() ns:SummonPet(id) end)
    b:SetOnEnter(function(frame)
        preview = preview or ns:CreateModelPreview("PetCallMenuPreview")
        preview:ShowForCreature(info.creatureID, "LEFT", frame, "RIGHT", 8, 0)
    end)
    b:SetOnLeave(function() if preview then preview:ScheduleHide() end end)
end

function Menu:Build(owner, root)
    root:CreateTitle("PetCall")
    root:CreateButton(L["Summon another"], function() ns:SummonAnother() end)
    root:CreateButton(L["Dismiss pet"], function() ns:Dismiss() end)
    root:CreateCheckbox(L["Auto-summon"], function() return ns:IsAutoSummon() end, function() ns:SetAutoSummon(not ns:IsAutoSummon()) end)
    local set = ns.Sets:GetCurrent()
    root:CreateTitle(format("%s: %s", L["Active"], set and set:DisplayName() or NONE))
    local recent = ns:GetRecentPets()
    if #recent > 0 then
        local r = root:CreateButton(L["Recently summoned"])
        for _, id in ipairs(recent) do addPet(r, id) end
    end
    local all = root:CreateButton(L["All pets"])
    local ids = {}
    for _, id in ns.PetCache:IteratePetIDs() do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return strlower(petName(a)) < strlower(petName(b)) end)
    for start = 1, #ids, PAGE do
        local stop = math.min(start + PAGE - 1, #ids)
        local first, last = petName(ids[start]), petName(ids[stop])
        local label = format("%s – %s", prefix(first, start > 1 and petName(ids[start - 1]) or nil),
            prefix(last, stop < #ids and petName(ids[stop + 1]) or nil))
        local page = all:CreateButton(label)
        page:SetScrollMode(20 * 26)
        for i = start, stop do addPet(page, ids[i]) end
    end
    root:CreateDivider()
    root:CreateButton(L["Open PetCall"], function() ns:OpenWindow() end)
    root:CreateButton(L["Settings"], function() ns:OpenSettings() end)
end

function Menu:Open(anchor)
    MenuUtil.CreateContextMenu(anchor, function(owner, root) Menu:Build(owner, root) end)
end
