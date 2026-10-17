local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local Menu = {}
ns.UI.Menu = Menu

local GROUP_SIZE = 25          -- letters are merged until a group would exceed this
local PREVIEW_SIZE = 200
local preview

local function petName(id) local i = ns.PetCache:GetInfo(id) return i and (i.customName or i.name) or "?" end

-- one entry per pet as the player sees it (copies collapse into PetCache's primary copy)
function Menu.UniquePets()
    local ids, key = {}, {}
    for _, id in ns.PetCache:IteratePetIDs() do
        if ns.PetCache:IsPrimary(id) then
            ids[#ids + 1] = id
            key[id] = strlower(petName(id))     -- once per pet, not once per comparison
        end
    end
    table.sort(ids, function(a, b)
        local na, nb = key[a], key[b]
        if na == nb then return a < b end
        return na < nb
    end)
    return ids
end

-- first character of the name: an ASCII letter (upper case), "#" for digits and
-- symbols, any other UTF-8 character as is
local function initial(name)
    local c = name:match("^[%z\1-\127\194-\244][\128-\191]*") or "#"
    if c:match("^%a$") then return c:upper() end
    if #c == 1 then return "#" end
    return c
end

-- { {label = "A", ids = {...}}, {label = "D – F", ids = {...}} }: one group per
-- initial, neighbouring initials merged while the group stays within maxSize;
-- nameOf names the ids (pets by default), which come sorted by that name
function Menu.Groups(ids, maxSize, nameOf)
    nameOf = nameOf or petName
    local letters = {}
    for _, id in ipairs(ids) do
        local c = initial(nameOf(id))
        local last = letters[#letters]
        if not last or last.key ~= c then
            last = { key = c, ids = {} }
            letters[#letters + 1] = last
        end
        last.ids[#last.ids + 1] = id
    end
    local groups, cur = {}, nil
    for _, l in ipairs(letters) do
        if cur and #cur.ids + #l.ids <= maxSize then
            for _, id in ipairs(l.ids) do cur.ids[#cur.ids + 1] = id end
            cur.last = l.key
        else
            cur = { first = l.key, last = l.key, ids = {} }
            for _, id in ipairs(l.ids) do cur.ids[#cur.ids + 1] = id end
            groups[#groups + 1] = cur
        end
    end
    for _, g in ipairs(groups) do
        g.label = g.first == g.last and g.first or format("%s – %s", g.first, g.last)
    end
    return groups
end

-- The preview goes on the side of the pet list away from its parent menu (the one
-- it cascaded from), so it never covers it; the other side when out of room.
function Menu.PreviewSide(itemLeft, itemRight, parentCenterX, screenWidth)
    local roomLeft = itemLeft - PREVIEW_SIZE - 8 >= 0
    local roomRight = itemRight + PREVIEW_SIZE + 8 <= screenWidth
    if parentCenterX and parentCenterX > (itemLeft + itemRight) / 2 then
        return roomLeft and "left" or "right"
    end
    return roomRight and "right" or "left"
end

-- the menu frame holding an item, and the centre x of the frame that menu is anchored to
local function parentMenuCenterX(item)
    local menu = item
    while menu:GetParent() and menu:GetParent() ~= UIParent do menu = menu:GetParent() end
    local ok, _, rel = pcall(menu.GetPoint, menu, 1)
    if not ok or type(rel) ~= "table" or not rel.GetCenter then return nil end
    local x = rel:GetCenter()
    if type(x) ~= "number" then return nil end
    return x * rel:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function showPreview(info, frame)
    preview = preview or ns:CreateModelPreview("PetCallMenuPreview")
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local side = Menu.PreviewSide((frame:GetLeft() or 0) * scale, (frame:GetRight() or 0) * scale,
        parentMenuCenterX(frame), UIParent:GetWidth())
    if side == "left" then
        preview:ShowForPet(info, "RIGHT", frame, "LEFT", -8, 0)
    else
        preview:ShowForPet(info, "LEFT", frame, "RIGHT", 8, 0)
    end
end

-- Our share of a menu that lists every pet, made once until the pets change: the
-- sorted list, its letter groups, the favourites, and each pet's label and handlers.
-- The menu's own entries are made by the game on every opening.
local lists          -- { ids, favorites, groups }
local entries = {}   -- petID -> { label, click, enter }, false when not owned

local function entry(id)
    local e = entries[id]
    if e == nil then
        local info = ns.PetCache:GetInfo(id)
        e = info and {
            label = format("|T%s:16|t %s", info.icon or 0, petName(id)),
            click = function() ns:SummonPet(id) end,
            enter = function(frame) showPreview(info, frame) end,
        } or false
        entries[id] = e
    end
    return e or nil
end

local function petLists()
    if not lists then
        local ids, favorites = Menu.UniquePets(), {}
        for _, id in ipairs(ids) do
            if ns.PetCache:GetInfo(id).isFavorite then favorites[#favorites + 1] = id end
        end
        lists = { ids = ids, favorites = favorites, groups = Menu.Groups(ids, GROUP_SIZE) }
    end
    return lists
end

ns:RegisterCallback(Menu, "PetsChanged", function()
    lists = nil
    wipe(entries)
end)

local function leave() if preview then preview:ScheduleHide() end end

local function addPet(root, id)
    local e = entry(id)
    if not e then return end
    local b = root:CreateButton(e.label, e.click)
    b:SetOnEnter(e.enter)
    b:SetOnLeave(leave)
end

function Menu:Build(owner, root)
    root:CreateTitle("PetCall")
    root:CreateButton(L["Summon another"], function() ns:SummonAnother() end)
    root:CreateButton(L["Dismiss pet"], function() ns:Dismiss() end)
    root:CreateCheckbox(L["Auto-summon"], function() return ns:IsAutoSummon() end, function() ns:SetAutoSummon(not ns:IsAutoSummon()) end)
    local set = ns.Sets:GetCurrent()
    root:CreateButton(format("%s: %s", L["Active"], set and set:DisplayName() or NONE), function()
        ns.UI.Main:Show()
        if set then ns.UI.Main:SelectSet(set.name) end
    end)
    local recent = ns:GetRecentPets()
    if #recent > 0 then
        local r = root:CreateButton(L["Recently summoned"])
        for _, id in ipairs(recent) do addPet(r, id) end
    end
    local pets = petLists()
    if #pets.favorites > 0 then
        local fav = root:CreateButton(L["Favorites"])
        fav:SetScrollMode(20 * 26)
        for _, id in ipairs(pets.favorites) do addPet(fav, id) end
    end
    if #pets.ids > 0 then
        local all = root:CreateButton(L["All pets"])
        for _, g in ipairs(pets.groups) do
            local page = all:CreateButton(format("%s  |cff808080(%d)|r", g.label, #g.ids))
            page:SetScrollMode(20 * 26)
            for _, id in ipairs(g.ids) do addPet(page, id) end
        end
    end
    root:CreateDivider()
    root:CreateButton(L["Open PetCall"], function() ns:OpenWindow() end)
    root:CreateButton(L["Settings"], function() ns:OpenSettings() end)
end

-- Opens at the cursor. The owner is UIParent, not the clicked button: a menu closes
-- when its owner hides, and minimap button collectors (EllesmereUI's flyout) hide
-- their buttons on the very click that picks a menu item.
function Menu:Open()
    MenuUtil.CreateContextMenu(UIParent, function(owner, root) Menu:Build(owner, root) end)
end
