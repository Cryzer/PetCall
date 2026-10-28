-- Layout testing on top of tests/uistub.lua: text sizes, frame geometry, the addon's
-- pseudo-locale (/pcall pseudo) and a checker for text that does not fit and controls that overlap.
--
--   local Layout = dofile("tests/layout.lua")
--   local ns, U = Layout.load({ pseudo = true })     -- the whole UI, measured
--   Layout.SetWindowSize(ns, U, 640, 440)
--   local problems = Layout.Check(U, ns.UI.Main:GetFrame())
--
-- Sizes are estimates (average glyph width per font), close enough to see a text that
-- needs twice the room it has; the real fonts are checked in game.
local Layout = {}

local SCREEN_W, SCREEN_H = 1920, 1080
local GLYPH = { small = 5.5, normal = 6.5, large = 8.5 }
local LINE = { small = 12, normal = 14, large = 18 }
local BUTTON_PAD = 8          -- room each side of a button's text
local DROPDOWN_ARROW = 24     -- a dropdown's arrow on the right

local function fontKind(font)
    font = tostring(font or "")
    if font:find("Small") or font:find("Tiny") then return "small" end
    if font:find("Large") or font:find("Huge") then return "large" end
    return "normal"
end

local function utf8len(s)
    local _, n = s:gsub("[^\128-\191]", "")
    return n
end

-- width of the widest line and the number of lines; a texture escape counts as one glyph square
local function measure(text, font)
    local kind = fontKind(font)
    local widest, count = 0, 0
    text = tostring(text or ""):gsub("|n", "\n")
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local icons = 0
        line = line:gsub("|T.-|t", function() icons = icons + 1 return "" end)
        line = line:gsub("|A.-|a", function() icons = icons + 1 return "" end)
        line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        widest = math.max(widest, utf8len(line) * GLYPH[kind] + icons * LINE[kind])
        count = count + 1
    end
    return widest, count
end

-- text size at a given width (wrapping at that width when wrap is on)
function Layout.TextSize(text, font, width, wrap)
    local kind = fontKind(font)
    local w, lines = measure(text, font)
    if wrap ~= false and width and width > 0 and w > width then
        lines = 0
        -- lines break between words, as the game's do, so a line is often not full
        local space = GLYPH[kind]
        for line in (tostring(text or ""):gsub("|n", "\n") .. "\n"):gmatch("(.-)\n") do
            local n, used = 1, 0
            for word in line:gmatch("%S+") do
                local ww = measure(word, font)
                if used > 0 and used + space + ww > width then
                    n, used = n + 1, 0
                end
                while ww > width do                 -- a word longer than the line breaks inside
                    n, ww = n + 1, ww - width
                end
                used = used + (used > 0 and space or 0) + ww
            end
            lines = lines + n
        end
        w = width
    end
    return w, lines * LINE[kind]
end


-- Geometry -----------------------------------------------------------------------------

local function parts(point)
    local h = point:find("LEFT") and "L" or point:find("RIGHT") and "R" or "C"
    local v = point:find("TOP") and "T" or point:find("BOTTOM") and "B" or "C"
    return h, v
end

local function edgeX(r, h) return h == "L" and r.l or h == "R" and r.r or (r.l + r.r) / 2 end
local function edgeY(r, v) return v == "B" and r.b or v == "T" and r.t or (r.b + r.t) / 2 end

local function solve(lo, hi, mid, size)
    if lo and hi then return lo, hi end
    if lo then return lo, lo + size end
    if hi then return hi - size, hi end
    if mid then return mid - size / 2, mid + size / 2 end
end

local function isFontString(f) return rawget(f, "_isFontString") == true end

local function explicit(f, key)
    local v = rawget(f, key)
    if isFontString(f) and v == 0 then return nil end      -- SetWidth(0): no limit, as in the game
    return v
end

-- The frame's rectangle on screen (y grows upwards), or nil when it is not anchored to
-- something placed. Font strings without a width take their text's size.
function Layout.Rect(f, depth)
    depth = (depth or 0) + 1
    if depth > 60 or type(f) ~= "table" then return nil end
    if f == UIParent then return { l = 0, r = SCREEN_W, b = 0, t = SCREEN_H } end
    local points = rawget(f, "_points")
    if not points or next(points) == nil then return nil end
    local parent = rawget(f, "_parent")
    if points.ALL then
        local r = Layout.Rect(points.ALL.rel or parent, depth)
        return r and { l = r.l, r = r.r, b = r.b, t = r.t }
    end
    local xs, ys = {}, {}
    for point, p in pairs(points) do
        local rel = p.rel or parent
        if type(rel) == "string" then rel = _G[rel] end
        local rr = rel and Layout.Rect(rel, depth)
        if not rr then return nil end
        local h, v = parts(point)
        local rh, rv = parts(p.relPoint or point)
        xs[h] = edgeX(rr, rh) + (p.x or 0)
        ys[v] = edgeY(rr, rv) + (p.y or 0)
    end
    local fs = isFontString(f)
    local w = explicit(f, "_w")
    if not w and fs then w = measure(rawget(f, "_text"), rawget(f, "_font")) end
    local l, r = solve(xs.L, xs.R, xs.C, w or 0)
    local h = explicit(f, "_h")
    if not h and fs then
        local _, th = Layout.TextSize(rawget(f, "_text"), rawget(f, "_font"), r - l, rawget(f, "_wrap"))
        h = th
    end
    local b, t = solve(ys.B, ys.T, ys.C, h or 0)
    return { l = l, r = r, b = b, t = t }
end

local function size(f)
    local r = Layout.Rect(f)
    if r then return r.r - r.l, r.t - r.b end
    local w, h = explicit(f, "_w"), explicit(f, "_h")
    if isFontString(f) then
        local tw, th = measure(rawget(f, "_text"), rawget(f, "_font"))
        w, h = w or tw, h or th
    end
    return w or 0, h or 0
end

-- Stub methods -------------------------------------------------------------------------

local fontStrings

local function newFontString(U, parent, font)
    local t = U.universal()
    t._parent, t._shown, t._isFontString, t._type, t._font = parent, true, true, "FontString", font
    fontStrings[#fontStrings + 1] = t
    return t
end

-- a template's own label: a font string in the middle (buttons) or left of an arrow
-- (dropdowns), kept in step with SetText / SetDefaultText
local function boundLabel(U, f)
    local fs = rawget(f, "_label")
    if fs then return fs end
    fs = newFontString(U, f, "GameFontNormal")
    local template = rawget(f, "_template") or ""
    if template:find("Dropdown") then
        fs._points = { LEFT = { rel = f, relPoint = "LEFT", x = BUTTON_PAD, y = 0 },
            RIGHT = { rel = f, relPoint = "RIGHT", x = -DROPDOWN_ARROW, y = 0 } }
        fs._wrap = false
    else
        fs._points = { CENTER = { rel = f, relPoint = "CENTER", x = 0, y = 0 } }
        fs._wrap = false
    end
    fs._text = rawget(f, "_text")
    f._label = fs
    return fs
end

local function install(U)
    local Universal = U.Universal
    fontStrings = {}
    Layout.fontStrings = fontStrings
    function Universal:SetWidth(w) self._w = w end
    function Universal:SetHeight(h) self._h = h end
    function Universal:SetSize(w, h) self._w, self._h = w, h end
    function Universal:GetWidth() return (size(self)) end
    function Universal:GetHeight() return select(2, size(self)) end
    function Universal:GetSize() return size(self) end
    function Universal:GetLeft() local r = Layout.Rect(self) return r and r.l end
    function Universal:GetRight() local r = Layout.Rect(self) return r and r.r end
    function Universal:GetTop() local r = Layout.Rect(self) return r and r.t or 500 end
    function Universal:GetBottom() local r = Layout.Rect(self) return r and r.b end
    function Universal:SetFontObject(font) self._font = font end
    function Universal:SetWordWrap(v) self._wrap = v and true or false end
    function Universal:SetFrameStrata(s) self._strata = s end
    function Universal:SetClipsChildren(v) self._clips = v and true or false end
    -- a scroll frame shows its child from the top left, and cuts off what scrolls past it
    function Universal:SetScrollChild(child)
        child._points = { TOPLEFT = { rel = self, relPoint = "TOPLEFT", x = 0, y = 0 } }
        self._clips = true
    end
    function Universal:CreateFontString(_, _, font) return newFontString(U, self, font) end
    function Universal:SetText(t)
        self._text = t
        local fs = rawget(self, "_label")
        if fs then fs._text = t end
    end
    function Universal:SetDefaultText(t) self:SetText(t) end
    function Universal:GetFontString() return boundLabel(U, self) end
    function Universal:GetStringWidth() return (measure(rawget(self, "_text"), rawget(self, "_font"))) end
    Universal.GetUnboundedStringWidth = Universal.GetStringWidth
    function Universal:GetStringHeight()
        local w = size(self)
        local _, h = Layout.TextSize(rawget(self, "_text"), rawget(self, "_font"), w, rawget(self, "_wrap"))
        return h
    end
    -- list rows go under each other at the view's row height, as a ScrollBox puts them;
    -- rows past the bottom are the part scrolled away
    function Universal:SetElementExtent(e) self._extent = e end
    function Universal:SetElementExtentCalculator(fn) self._extentFn = fn end
    local setData = Universal.SetDataProvider
    function Universal:SetDataProvider(dp, ...)
        setData(self, dp, ...)
        local view, y = rawget(self, "_view"), 0
        for i, row in ipairs(rawget(self, "_rowFrames") or {}) do
            local data = dp._elements[i]
            local h = view and (view._extentFn and view._extentFn(i, data) or view._extent) or 20
            row._points = { TOPLEFT = { rel = self, relPoint = "TOPLEFT", x = 0, y = -y },
                TOPRIGHT = { rel = self, relPoint = "TOPRIGHT", x = 0, y = -y } }
            row._h, row._scrollRow = h, true
            y = y + h
        end
    end
    local create = _G.CreateFrame
    _G.CreateFrame = function(frameType, name, parent, template)
        local f = create(frameType, name, parent, template)
        template = template or ""
        if template:find("FilterDropdown") then
            -- the Filter button's own size; its label sits between the edges and the reset ×
            f._w, f._h = 93, 22
            f.Text = boundLabel(U, f)
            f.Text._points.RIGHT.x = -16
        elseif template:find("Dropdown") then
            f._h = 22
            f.Text = boundLabel(U, f)
        elseif template:find("UIPanelButton") then
            f._h = 22
            f.Text = boundLabel(U, f)
        end
        if template == "ButtonFrameTemplate" then
            -- the template's inset under the title, and the close button in the corner
            f.Inset._points = { TOPLEFT = { rel = f, relPoint = "TOPLEFT", x = 4, y = -60 },
                BOTTOMRIGHT = { rel = f, relPoint = "BOTTOMRIGHT", x = -6, y = 26 } }
            f.CloseButton._points = { TOPRIGHT = { rel = f, relPoint = "TOPRIGHT", x = 0, y = 0 } }
            f.CloseButton._w, f.CloseButton._h = 24, 24
        end
        if template == "MinimalSliderWithSteppersTemplate" then
            -- the track between the two stepper arrows
            f.Slider._points = { TOPLEFT = { rel = f, relPoint = "TOPLEFT", x = 19, y = 0 },
                BOTTOMRIGHT = { rel = f, relPoint = "BOTTOMRIGHT", x = -19, y = 0 } }
        end
        return f
    end
end

-- The whole UI with measured text; opts.pseudo turns on /pcall pseudo, saved as the game
-- would have it before the addon loads.
function Layout.load(opts)
    opts = opts or {}
    local U = dofile("tests/uistub.lua")
    local ns = U.load({
        prepare = function(stub)
            install(stub)
            if opts.pseudo then PetCall3DB = { global = { pseudo = true } } end
        end,
    })
    return ns, U
end

-- Gives every frame that reacts to its size the size it has now, a few rounds, as the
-- game does over the next frames.
function Layout.Settle(U)
    for _ = 1, 4 do
        local changed = false
        for _, f in ipairs(U.created) do
            local fn = f._scripts.OnSizeChanged
            if fn and f:IsVisible() and Layout.Rect(f) then
                local w, h = size(f)
                local last = rawget(f, "_lastSize")
                if not last or last[1] ~= w or last[2] ~= h then
                    f._lastSize = { w, h }
                    fn(f, w, h)
                    changed = true
                end
            end
        end
        if not changed then return end
    end
end

function Layout.SetWindowSize(ns, U, w, h)
    local frame = ns.UI.Main:GetFrame()
    frame:SetSize(w, h)
    ns:Fire("WindowResized", w, h)
    Layout.Settle(U)
    U.W.advance(1)
    Layout.Settle(U)
end

-- Checker ------------------------------------------------------------------------------

-- controls may share a border (segmented buttons overlap by 2 px), so 2 px is not a problem
local SLACK = 2
local CONTROL = { Button = true, CheckButton = true, EditBox = true, DropdownButton = true, Slider = true }

local function textOf(f)
    local t = rawget(f, "_text")
    if type(t) ~= "string" or t == "" then return nil end
    return t
end

-- the field a frame is kept in on its parent (page.count, frame.left...), if any
local function fieldName(f)
    local p = rawget(f, "_parent")
    if type(p) ~= "table" then return nil end
    for k, v in pairs(p) do
        if v == f and type(k) == "string" and not k:match("^_") then return k end
    end
end

local function describe(f)
    local text = textOf(f)
    if not text and rawget(f, "_label") then text = textOf(f._label) end
    local kind = rawget(f, "_type") or "Frame"
    if rawget(f, "_template") then kind = kind .. "<" .. f._template .. ">" end
    local field = fieldName(f)
    if field then kind = kind .. " ." .. field end
    if text then
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\n", " ")
        if #text > 48 then text = text:sub(1, 45) .. "..." end
        return kind .. ' "' .. text .. '"'
    end
    return kind
end

local function inside(f, root)
    local p = f
    while p do
        if p == root then return true end
        p = rawget(p, "_parent")
    end
    return false
end

local function isPopup(f)
    local s = rawget(f, "_strata")
    return s == "DIALOG" or s == "FULLSCREEN" or s == "FULLSCREEN_DIALOG" or s == "TOOLTIP"
end

-- a top and a bottom anchor give a font string its height, whatever its text needs
local function heightFixed(points)
    local top, bottom = false, false
    for point in pairs(points) do
        local _, v = parts(point)
        if v == "T" then top = true elseif v == "B" then bottom = true end
    end
    return top and bottom
end

local function fmt(n) return string.format("%d", math.floor(n + 0.5)) end

-- Problems inside root (a window or a page): text that does not fit, frames that leave
-- their parent, controls and labels that cover each other. Each problem is a string.
-- Returns problems and how many visible objects could be placed.
function Layout.Check(U, root)
    local problems, checked = {}, 0
    local objects = {}
    for _, f in ipairs(U.created) do objects[#objects + 1] = f end
    for _, f in ipairs(fontStrings) do objects[#objects + 1] = f end
    local placed, byParent = {}, {}
    for _, f in ipairs(objects) do
        if f ~= root and f:IsVisible() and inside(f, root) then
            local r = Layout.Rect(f)
            if r then
                checked = checked + 1
                placed[f] = r
                local p = rawget(f, "_parent")
                byParent[p] = byParent[p] or {}
                table.insert(byParent[p], f)
            end
        end
    end
    local function add(msg) problems[#problems + 1] = msg end
    for f, r in pairs(placed) do
        local text = textOf(f)
        if isFontString(f) and text then
            local need = measure(text, rawget(f, "_font"))
            local width = r.r - r.l
            if rawget(f, "_wrap") == false and need > width + 1 then
                add(describe(f) .. " needs " .. fmt(need) .. " px, has " .. fmt(width))
            elseif explicit(f, "_h") or heightFixed(rawget(f, "_points")) then
                local _, needH = Layout.TextSize(text, rawget(f, "_font"), width, true)
                if needH > (r.t - r.b) + 1 then
                    add(describe(f) .. " needs " .. fmt(needH) .. " px of height, has " .. fmt(r.t - r.b))
                end
            end
        end
        local parent = rawget(f, "_parent")
        local pr = parent and (placed[parent] or (parent == root and Layout.Rect(root)))
        -- scrolled rows run past their list; a window's ornaments (badge, help button) hang
        -- over its edge on purpose
        local exempt = rawget(f, "_scrollRow") or isPopup(f)
            or (not text and rawget(parent, "_template") == "ButtonFrameTemplate")
        -- what a scroll frame holds may run past its bottom: it scrolls into view
        local scrolls = parent and rawget(parent, "_clips")
        local outV = pr and not scrolls and (r.b < pr.b - SLACK or r.t > pr.t + SLACK)
        if pr and not exempt and (r.l < pr.l - SLACK or r.r > pr.r + SLACK or outV) then
            if isFontString(f) and text and (r.l < pr.l - SLACK or r.r > pr.r + SLACK) then
                -- a centred label wider than its control: say how much room it needs
                add(describe(f) .. " needs " .. fmt(r.r - r.l) .. " px, " .. describe(parent) .. " has " .. fmt(pr.r - pr.l))
            else
                add(describe(f) .. " leaves " .. describe(parent))
            end
        end
        if isPopup(f) and (r.l < -1 or r.r > SCREEN_W + 1 or r.b < -1 or r.t > SCREEN_H + 1) then
            add(describe(f) .. " leaves the screen")
        end
    end
    for _, list in pairs(byParent) do
        for i = 1, #list do
            local a = list[i]
            local ca = CONTROL[rawget(a, "_type")] or (isFontString(a) and textOf(a))
            if ca and not rawget(a, "_points").ALL then
                for j = i + 1, #list do
                    local b = list[j]
                    local cb = CONTROL[rawget(b, "_type")] or (isFontString(b) and textOf(b))
                    if cb and not rawget(b, "_points").ALL then
                        local ra, rb = placed[a], placed[b]
                        local ox = math.min(ra.r, rb.r) - math.max(ra.l, rb.l)
                        local oy = math.min(ra.t, rb.t) - math.max(ra.b, rb.b)
                        if ox > SLACK and oy > SLACK then add(describe(a) .. " overlaps " .. describe(b)) end
                    end
                end
            end
        end
    end
    table.sort(problems)
    return problems, checked
end

return Layout
