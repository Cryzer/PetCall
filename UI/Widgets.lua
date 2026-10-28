local _, ns = ...

local CreateFrame, C_Timer = CreateFrame, C_Timer
local Widgets = {}
ns.Widgets = Widgets

-- Generic confirmation: StaticPopup_Show("PETCALL_CONFIRM", text, nil, { onAccept = fn })
StaticPopupDialogs["PETCALL_CONFIRM"] = {
    text = "%s", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) data.onAccept() end,
}

-- Inline status dot; the game fonts have no circle glyphs. kind: "on" | "off" | "warn"
local DOTS = { on = "Interface\\COMMON\\Indicator-Green", off = "Interface\\COMMON\\Indicator-Gray",
    warn = "Interface\\COMMON\\Indicator-Yellow" }
function Widgets.Dot(kind) return "|T" .. DOTS[kind] .. ":12:12|t" end

-- Layout follows the text, in every language: controls take the width their text needs
-- and rows of controls continue on the next line instead of running out of the window.
local BUTTON_MIN_W, BUTTON_PAD = 64, 12
-- a dropdown's text sits between its left inset and the arrow
local DROPDOWN_PAD = 48

-- the width a font string's text needs on one line, whatever width it was given
function Widgets.TextWidth(fs)
    if not fs then return 0 end
    local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    return math.ceil(tonumber(w) or 0)
end

-- Wraps fs within width with its lines about even ("No pets to / choose from", not
-- "No pets to choose / from"): the narrowest width that keeps the same number of lines.
function Widgets.BalanceText(fs, width)
    fs:SetWidth(width)
    local height = tonumber(fs:GetStringHeight()) or 0
    local lo, hi = math.ceil(Widgets.TextWidth(fs) / 2), width
    if lo >= hi then return end
    while hi - lo > 2 do
        local mid = math.floor((lo + hi) / 2)
        fs:SetWidth(mid)
        if (tonumber(fs:GetStringHeight()) or 0) > height then lo = mid else hi = mid end
    end
    fs:SetWidth(hi)
end

-- a button, dropdown or chip as wide as its text, plus extra for an arrow or a ×; the
-- templates keep their label as .Text (a dropdown's is not its button font string)
function Widgets.FitButton(b, extra)
    local fs = b.Text or (b.GetFontString and b:GetFontString())
    b:SetWidth(math.max(BUTTON_MIN_W, Widgets.TextWidth(fs) + 2 * BUTTON_PAD + (extra or 0)))
end

-- Places items left to right in container, like words in a line: an item that does not
-- fit starts a new row. { frame, right = true } puts an item at the right end of its row,
-- { frame, newRow = true } starts a row with it; a label wider than a whole row wraps at
-- the row's width. Hidden items take no room.
-- opts: width (else the container's), gap (8), rowGap (4), rowHeight (the least, 22).
-- Sets the container's height and returns it.
function Widgets.Flow(container, items, opts)
    opts = opts or {}
    local width = opts.width or tonumber(container:GetWidth()) or 0
    if width <= 0 then width = math.huge end      -- not laid out yet: one row
    local gap, rowGap, minHeight = opts.gap or 8, opts.rowGap or 4, opts.rowHeight or 22
    local rows, row = {}, nil
    local function newRow()
        row = { left = {}, right = {}, used = 0, height = minHeight }
        rows[#rows + 1] = row
    end
    newRow()
    for _, item in ipairs(items) do
        local f = item.frame or item
        if f:IsShown() then
            local w
            if f.GetObjectType and f:GetObjectType() == "FontString" then
                w = Widgets.TextWidth(f)
                f:SetWordWrap(w > width)
                if w > width then w = width end
                f:SetWidth(w)
            else
                w = tonumber(f:GetWidth()) or 0
            end
            if row.used > 0 and (item.newRow or row.used + gap + w > width) then newRow() end
            row.used = row.used + (row.used > 0 and gap or 0) + w
            local h = tonumber(f.GetStringHeight and f:GetStringHeight() or f:GetHeight()) or 0
            row.height = math.max(row.height, h)
            local side = item.right and row.right or row.left
            side[#side + 1] = { f = f, w = w }
        end
    end
    local y = 0
    for _, r in ipairs(rows) do
        local mid, x = -(y + r.height / 2), 0
        for _, e in ipairs(r.left) do
            e.f:ClearAllPoints()
            e.f:SetPoint("LEFT", container, "TOPLEFT", x, mid)
            x = x + e.w + gap
        end
        x = 0
        for i = #r.right, 1, -1 do
            local e = r.right[i]
            e.f:ClearAllPoints()
            e.f:SetPoint("RIGHT", container, "TOPRIGHT", -x, mid)
            x = x + e.w + gap
        end
        y = y + r.height + rowGap
    end
    local height = y - rowGap
    container:SetHeight(height)
    return height
end

-- "1 pet", "35 pets"
function Widgets.PetCount(n) return format(n == 1 and ns.L["%d pet"] or ns.L["%d pets"], n) end

function Widgets.Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

function Widgets.Button(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetText(text)
    b:SetHeight(22)
    Widgets.FitButton(b)
    b.onClick = onClick                -- a field, so a reused button can be given a new one
    b:SetScript("OnClick", function(self, button) self.onClick(self, button) end)
    ns.Skin:Apply("Button", b)
    return b
end

-- the "no" sound for a refused input; some SOUNDKIT names are gone in newer clients,
-- and PlaySound(nil) is an error
function Widgets.ErrorSound()
    local id = SOUNDKIT.IG_PLAYER_INVITE_DECLINE or SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST
    if id then PlaySound(id) end
end

-- Quality colour lifted towards white when it is dark: the stock rare blue is hard to read
-- on dark backgrounds
function Widgets.QualityColor(quality)
    local r, g, b = C_Item.GetItemQualityColor((quality or 2) - 1)
    if 0.3 * r + 0.59 * g + 0.11 * b < 0.6 then
        r, g, b = r + (1 - r) * 0.35, g + (1 - g) * 0.35, b + (1 - b) * 0.35
    end
    return r, g, b
end

-- Marks a button as the picked one of a group: accent tint, accent underline, white text
function Widgets.SetPicked(b, on)
    if not b.pickBg then
        b.pickBg = b:CreateTexture(nil, "OVERLAY", nil, -1)
        b.pickBg:SetPoint("TOPLEFT", 2, -2)
        b.pickBg:SetPoint("BOTTOMRIGHT", -2, 2)
        b.pickLine = b:CreateTexture(nil, "OVERLAY")
        b.pickLine:SetPoint("BOTTOMLEFT", 2, 2)
        b.pickLine:SetPoint("BOTTOMRIGHT", -2, 2)
        b.pickLine:SetHeight(2)
    end
    local r, g, bl = ns.Skin:Accent()
    b.pickBg:SetColorTexture(r, g, bl, 0.18)
    b.pickLine:SetColorTexture(r, g, bl, 1)
    b.pickBg:SetShown(on)
    b.pickLine:SetShown(on)
    b.picked = on and true or false
    b:GetFontString():SetTextColor(1, on and 1 or 0.82, on and 1 or 0)   -- white when picked, gold otherwise
end

-- Lifts a box that floats over the window (a popover, a dialog) off what is under it.
-- The stock look's frames already stand out; the dark looks style them like the window
-- itself, often see-through, so there the box gets an opaque base, a lighter shade, an
-- accent edge and a shadow around it. Call it after the skin has styled the frame: the
-- flat look hides a frame's textures when it styles it.
local raised = {}
local function paintRaised(f)
    local r, g, b = ns.Skin:Accent()
    for _, e in ipairs(f.pcEdges) do e:SetColorTexture(r, g, b, 0.9) end
end
ns.Skin:OnLooksChanged(function() for _, f in ipairs(raised) do paintRaised(f) end end)

-- four strips on the frame's sides: inside (edges) or just outside (shadow)
local function strips(f, layer, sublevel, size, outside)
    local out = {}
    local o = outside and size or 0
    for _, side in ipairs({
        { "BOTTOMLEFT", "TOPLEFT", -o, 0, "BOTTOMRIGHT", "TOPRIGHT", o, 0, "h" },
        { "TOPLEFT", "BOTTOMLEFT", -o, 0, "TOPRIGHT", "BOTTOMRIGHT", o, 0, "h" },
        { "TOPRIGHT", "TOPLEFT", 0, 0, "BOTTOMRIGHT", "BOTTOMLEFT", 0, 0, "w" },
        { "TOPLEFT", "TOPRIGHT", 0, 0, "BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, "w" },
    }) do
        local t = f:CreateTexture(nil, layer, nil, sublevel)
        if outside then
            t:SetPoint(side[1], f, side[2], side[3], side[4])
            t:SetPoint(side[5], f, side[6], side[7], side[8])
        else
            -- the same sides, inside the frame
            t:SetPoint(side[2], f, side[2])
            t:SetPoint(side[6], f, side[6])
        end
        if side[9] == "h" then t:SetHeight(size) else t:SetWidth(size) end
        out[#out + 1] = t
    end
    return out
end

function Widgets.Raise(f)
    if ns.Skin:Look() == "blizzard" or f.pcEdges then return end
    f.pcBase = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.pcBase:SetAllPoints()
    f.pcBase:SetColorTexture(0.05, 0.05, 0.06, 1)
    f.pcLift = f:CreateTexture(nil, "BACKGROUND", nil, -6)
    f.pcLift:SetAllPoints()
    f.pcLift:SetColorTexture(1, 1, 1, 0.05)
    for _, t in ipairs(strips(f, "BACKGROUND", -8, 6, true)) do t:SetColorTexture(0, 0, 0, 0.6) end
    f.pcEdges = strips(f, "OVERLAY", 7, 1)
    paintRaised(f)
    raised[#raised + 1] = f
end

-- A box above the window (naming a new set), on the tooltip frame
function Widgets.Popover(parent)
    local f = CreateFrame("Frame", nil, parent, "TooltipBackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:Hide()
    if ns.Skin:Look() ~= "blizzard" then ns.Skin:Apply("Panel", f) end
    Widgets.Raise(f)
    return f
end

-- An ordered choice on Blizzard's slider with steppers, a notch for every step: drag it,
-- click an arrow or turn the mouse wheel to move one step. The name of the step is shown
-- by the owner, once, so the slider is as wide in every language.
-- steps = { {value =, label =} }; onPick(value) for a step the player moved to;
-- SetIndex(i) shows the picked step, nil none (then the slider cannot be moved).
-- The dark looks draw their own track: a thin line filled up to the thumb.
local SLIDER_H, THUMB_W, NOTCH_H = 20, 8, 5
function Widgets.StepSlider(parent, steps, onPick)
    local f = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    f:SetHeight(SLIDER_H)
    f:Init(1, 1, #steps, #steps - 1, {})
    local bar = f.Slider
    local thumb = bar:GetThumbTexture()
    local flat = ns.Skin:Look() ~= "blizzard"
    if flat then
        for _, region in ipairs({ bar:GetRegions() }) do
            if region ~= thumb and region.GetObjectType and region:GetObjectType() == "Texture" then region:SetAlpha(0) end
        end
        thumb:SetSize(THUMB_W, SLIDER_H - 6)
        thumb:SetColorTexture(0.9, 0.9, 0.9, 1)
        f.track = bar:CreateTexture(nil, "BACKGROUND")
        f.track:SetPoint("LEFT")
        f.track:SetPoint("RIGHT")
        f.track:SetHeight(2)
        f.track:SetColorTexture(1, 1, 1, 0.15)
        f.fill = bar:CreateTexture(nil, "ARTWORK", nil, -1)
        f.fill:SetPoint("LEFT")
        f.fill:SetPoint("RIGHT", thumb, "CENTER")
        f.fill:SetHeight(2)
    end
    f.notches = {}
    for i = 1, #steps do
        local n = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
        n:SetSize(1, NOTCH_H)
        n:SetColorTexture(1, 1, 1, flat and 0.35 or 0.5)
        f.notches[i] = n
    end
    -- the thumb's centre runs from half a thumb in at the left to half a thumb in at the right
    function f:Layout()
        local w, tw = tonumber(bar:GetWidth()) or 0, tonumber(thumb:GetWidth()) or 0
        for i, n in ipairs(self.notches) do
            n:ClearAllPoints()
            n:SetPoint("TOP", bar, "BOTTOMLEFT", math.floor(tw / 2 + (i - 1) * (w - tw) / math.max(1, #steps - 1) + 0.5), 3)
        end
    end
    bar:HookScript("OnSizeChanged", function() f:Layout() end)
    f:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v)
        local i = math.floor(v + 0.5)
        if f.setting or not f.index or i == f.index or not steps[i] then return end
        f.index = i
        onPick(steps[i].value)
    end, f)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        if f.index then f:SetValue(math.max(1, math.min(#steps, f.index + delta))) end
    end)
    function f:Paint()
        local r, g, b = ns.Skin:Accent()
        if self.color then r, g, b = unpack(self.color) end
        if self.fill then
            self.fill:SetColorTexture(r, g, b, 1)
            self.fill:SetShown(self.index ~= nil)
        elseif self.color then
            thumb:SetVertexColor(r, g, b)
        else
            thumb:SetVertexColor(1, 1, 1)
        end
    end
    function f:SetIndex(i)
        self.index = i
        self.setting = true
        if i then self:SetValue(i) end
        self.setting = nil
        self:SetEnabled(i ~= nil)
        self:Paint()
    end
    -- { r, g, b } for the fill (on the stock look, the thumb) instead of the accent, or nil
    function f:SetColor(color)
        self.color = color
        self:Paint()
    end
    f:Paint()
    return f
end

-- Row of joined buttons, one selected: items = { {value =, label =} }, get() -> value
function Widgets.Segmented(parent, items, get, onPick)
    local f = CreateFrame("Frame", nil, parent)
    f.buttons = {}
    local x = 0
    for i, item in ipairs(items) do
        local b = Widgets.Button(f, item.label, function() onPick(item.value) f:Refresh() end)
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() - 2       -- joined: each button covers its neighbour's border
        b.value = item.value
        f.buttons[i] = b
    end
    f:SetSize(math.max(1, x + 2), 22)
    function f:Refresh()
        local cur = get()
        for _, b in ipairs(self.buttons) do
            Widgets.SetPicked(b, b.value == cur)
        end
    end
    f:Refresh()
    return f
end

function Widgets.Checkbox(parent, label, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.text:SetText(label)
    cb.text:SetFontObject("GameFontHighlight")
    cb.getter, cb.setter = get, set    -- fields, so a reused box can be given new ones
    cb:SetScript("OnShow", function(self) self:SetChecked(self.getter() and true or false) end)
    cb:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        self.setter(self:GetChecked())
    end)
    cb:SetChecked(get() and true or false)
    ns.Skin:Apply("Checkbox", cb)
    return cb
end

-- buildMenu(owner, rootDescription) uses MenuUtil description API (CreateRadio/CreateButton/...)
function Widgets.Dropdown(parent, width, buildMenu)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetWidth(width)
    dd:SetupMenu(buildMenu)
    ns.Skin:Apply("Dropdown", dd)
    return dd
end

-- widens a dropdown to its longest text (its choices, or the text it shows without one);
-- never narrower than width
local ddMeasure
function Widgets.FitDropdown(dd, labels, width)
    ddMeasure = ddMeasure or UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local w = width or 0
    for _, text in ipairs(labels) do
        ddMeasure:SetText(text)
        w = math.max(w, Widgets.TextWidth(ddMeasure) + DROPDOWN_PAD)
    end
    dd:SetWidth(math.ceil(w))
end

function Widgets.Search(parent, onChanged)
    local eb = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    eb:SetHeight(20)
    eb:SetAutoFocus(false)
    local timer
    eb:HookScript("OnTextChanged", function(self, userInput)
        if timer then timer:Cancel() end
        timer = C_Timer.NewTimer(userInput and 0.15 or 0, function()
            timer = nil
            onChanged(self:GetText())
        end)
    end)
    ns.Skin:Apply("EditBox", eb, { padInput = true })
    return eb
end

function Widgets.Inset(parent)
    local f = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    ns.Skin:Apply("Inset", f)
    return f
end

-- Setting it again replaces the text (hooked once per frame), and nil title and body
-- turn it off, so frames that are reused do not stack up tooltips.
function Widgets.Tooltip(frame, title, body)
    frame.tipTitle, frame.tipBody = title, body
    if frame.tipHooked then return end
    frame.tipHooked = true
    frame:HookScript("OnEnter", function(self)
        local t, b = self.tipTitle, self.tipBody
        if not t and not b then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        t = type(t) == "function" and t(self) or t
        if t then GameTooltip:SetText(t, 1, 1, 1) end
        if b then GameTooltip:AddLine(type(b) == "function" and b(self) or b, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function(self) if self.tipTitle or self.tipBody then GameTooltip:Hide() end end)
end

local function noop() end

-- Frames for a view that is drawn again from scratch: Release() puts every one away and
-- Take (or Label, Button...) gives back one of that kind, or makes it the first time.
-- The game never frees frames, so a redraw must not make new ones each time.
function Widgets.NewPool()
    local pool, used, free = {}, {}, {}

    -- make() builds a new frame; whoever takes it sets it up for its new use
    function pool:Take(kind, parent, make)
        local list = free[kind]
        if not list then list = {} free[kind] = list end
        local f = table.remove(list)
        if f then
            f:SetParent(parent)
            f:Show()
        else
            f = make()
            f.poolKind = kind
        end
        used[#used + 1] = f
        return f
    end

    function pool:Release()
        for _, f in ipairs(used) do
            f:Hide()
            f:ClearAllPoints()
            if f.tipHooked then Widgets.Tooltip(f, nil) end
            local list = free[f.poolKind]
            list[#list + 1] = f
        end
        wipe(used)
    end

    function pool:Label(parent, text, font)
        local fs = self:Take("label", parent, function() return Widgets.Label(parent) end)
        fs:SetFontObject(font or "GameFontHighlight")
        fs:SetWidth(0)
        fs:SetWordWrap(true)
        fs:SetText(text or "")
        return fs
    end

    -- kind: buttons a view changes further (colours, sizes) are kept apart from plain ones
    function pool:Button(parent, text, onClick, kind)
        local b = self:Take(kind or "button", parent, function() return Widgets.Button(parent, "", noop) end)
        b:SetText(text)
        b:SetHeight(22)
        Widgets.FitButton(b)
        b:SetEnabled(true)
        b.onClick = onClick
        return b
    end

    function pool:Dropdown(parent, width, buildMenu, defaultText)
        local dd = self:Take(defaultText and "textDropdown" or "dropdown", parent, function() return Widgets.Dropdown(parent, width, noop) end)
        dd:SetWidth(width)
        dd:SetupMenu(buildMenu)
        if defaultText then
            dd:SetDefaultText(defaultText)
            Widgets.FitDropdown(dd, { defaultText }, width)
        end
        return dd
    end

    function pool:Checkbox(parent, text, get, set)
        local cb = self:Take("checkbox", parent, function() return Widgets.Checkbox(parent, "", noop, noop) end)
        cb.text:SetText(text)
        cb.getter, cb.setter = get, set
        cb:SetChecked(get() and true or false)
        return cb
    end

    -- kind keeps boxes with different scripts apart; the caller sets size, text and scripts
    function pool:EditBox(parent, kind)
        return self:Take(kind, parent, function()
            local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
            eb:SetAutoFocus(false)
            ns.Skin:Apply("EditBox", eb)
            return eb
        end)
    end

    function pool:Frame(parent, kind)
        return self:Take(kind, parent, function() return CreateFrame("Frame", nil, parent) end)
    end

    return pool
end
