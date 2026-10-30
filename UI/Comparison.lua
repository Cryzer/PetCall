local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local C = {}
ns.UI.Comparison = C

-- Your settings beside the recommended ones, one row per setting. A row that differs shows
-- the recommended value in the accent colour; one that matches says "same". The table is
-- as tall as its rows: a column that is too narrow wraps its text.

local GAP, ROW_GAP, PAD = 12, 6, 8
local SHARE = { 0.4, 0.3, 0.3 }       -- the columns' parts of a width too small for all of them

local function textHeight(fs) return math.ceil(tonumber(fs:GetStringHeight()) or 0) end

local function hex(r, g, b) return format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) end

-- Build(parent) -> the table; table:Refresh() reads the rows again, table:Layout(width)
-- places them and returns its height
function C.Build(parent)
    local t = CreateFrame("Frame", nil, parent)
    local pool = ns.Widgets.NewPool()
    local cells = {}            -- { {fs, fs, fs} } per row, the header first
    t.rule = t:CreateTexture(nil, "ARTWORK")
    t.rule:SetColorTexture(1, 1, 1, 0.15)
    t.rule:SetHeight(1)

    function t:Refresh()
        pool:Release()
        wipe(cells)
        local rows = ns.Recommended:Rows()
        C._last = rows
        cells[1] = { pool:Label(t, L["Setting"], "GameFontNormal"), pool:Label(t, L["Yours"], "GameFontNormal"),
            pool:Label(t, L["Recommended"], "GameFontNormal") }
        local accent = hex(ns.Skin:Accent())
        for _, row in ipairs(rows) do
            local rec = row.same and ("|cff808080" .. L["same"] .. "|r") or (accent .. row.recommended .. "|r")
            cells[#cells + 1] = { pool:Label(t, row.label, "GameFontHighlightSmall"),
                pool:Label(t, row.yours, "GameFontHighlightSmall"), pool:Label(t, rec, "GameFontHighlightSmall") }
        end
        return rows
    end

    function t:Layout(width)
        local natural = { 0, 0, 0 }
        for _, line in ipairs(cells) do
            for i, fs in ipairs(line) do
                fs:SetWidth(0)
                natural[i] = math.max(natural[i], ns.Widgets.TextWidth(fs))
            end
        end
        local room = width - 2 * GAP
        local widths
        if natural[1] + natural[2] + natural[3] <= room then
            -- the setting column takes what the values leave
            widths = { room - natural[2] - natural[3], natural[2], natural[3] }
        else
            widths = {}
            for i, part in ipairs(SHARE) do widths[i] = math.min(natural[i], math.floor(room * part)) end
            widths[1] = room - widths[2] - widths[3]
        end
        local y = 0
        for n, line in ipairs(cells) do
            local x, h = 0, 0
            for i, fs in ipairs(line) do
                fs:SetWidth(widths[i])
                fs:SetWordWrap(true)
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", t, "TOPLEFT", x, -y)
                x = x + widths[i] + GAP
                h = math.max(h, textHeight(fs))
            end
            y = y + h + ROW_GAP
            if n == 1 then
                t.rule:ClearAllPoints()
                t.rule:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -(y - ROW_GAP / 2))
                t.rule:SetWidth(width)
                y = y + 2
            end
        end
        local height = math.max(1, y - ROW_GAP)
        t:SetSize(width, height)
        return height
    end

    return t
end

-- The table in a box over `parent`, with the line under it and the two buttons.
-- onDone(applied) runs as it closes.
local box
local BOX_W = 520

local function build()
    box = ns.Widgets.Popover(ns.UI.Main:GetFrame())
    box.title = ns.Widgets.Label(box, L["Use recommended settings"], "GameFontNormalLarge")
    box.table = C.Build(box)
    box.note = ns.Widgets.Label(box, L["Recommended changes only the rows above. Your sets, pets and own exceptions stay as they are."], "GameFontDisableSmall")
    box.note:SetWordWrap(true)
    box.use = ns.Widgets.Button(box, L["Use recommended"], function()
        local changes = false
        for _, row in ipairs(C._last or {}) do if not row.same then changes = true end end
        if changes then ns.Recommended:Apply() end
        C:Close(changes)
    end)
    box.cancel = ns.Widgets.Button(box, L["Cancel"], function() C:Close(false) end)
    box:SetScript("OnHide", function() if box.onDone then C:Close(false) end end)
    C._box = box
end

local function layout()
    local parentW = tonumber(box.parent:GetWidth()) or 0
    local w = parentW > 80 and math.min(BOX_W, parentW - 40) or BOX_W
    local inner = w - 2 * PAD - 8
    box.title:SetWidth(inner)
    box.title:SetPoint("TOPLEFT", PAD + 4, -PAD - 2)
    local y = PAD + 2 + textHeight(box.title) + 10
    box.table:ClearAllPoints()
    box.table:SetPoint("TOPLEFT", PAD + 4, -y)
    y = y + box.table:Layout(inner) + 10
    box.note:SetWidth(inner)
    box.note:ClearAllPoints()
    box.note:SetPoint("TOPLEFT", PAD + 4, -y)
    y = y + textHeight(box.note) + 10
    box.cancel:ClearAllPoints()
    box.cancel:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD - 4, -y)
    box.use:ClearAllPoints()
    box.use:SetPoint("RIGHT", box.cancel, "LEFT", -6, 0)
    box:SetSize(w, y + 22 + PAD + 4)
    box:ClearAllPoints()
    box:SetPoint("CENTER", box.parent, "CENTER", 0, 0)
end

function C:Open(parent, onDone)
    if not box then build() end
    box.parent, box.onDone = parent or ns.UI.Main:GetFrame(), onDone
    box.table:Refresh()
    box:Show()
    layout()
end

function C:Close(applied)
    if not box then return end
    local done = box.onDone
    box.onDone = nil
    box:Hide()
    if done then done(applied) end
end

function C:IsShown() return box ~= nil and box:IsShown() end

ns:RegisterCallback(C, "WindowHidden", function() C:Close(false) end)
