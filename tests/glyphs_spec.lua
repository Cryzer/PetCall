-- The game's fonts cover Latin-1 and a few punctuation marks; anything else
-- (stars, circles, arrows, bullets) renders as an empty box.
local ALLOWED = { [0x2013] = true }   -- en dash, used in labels and seen rendering in game

local function codepoints(s)
    local i, n = 1, #s
    return function()
        if i > n then return nil end
        local c = s:byte(i)
        local len = c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or 4
        local cp = c
        if len == 2 then cp = c % 0x20 elseif len == 3 then cp = c % 0x10 elseif len == 4 then cp = c % 0x08 end
        for k = 1, len - 1 do cp = cp * 0x40 + (s:byte(i + k) or 0x80) % 0x40 end
        local start = i
        i = i + len
        return cp, s:sub(start, i - 1)
    end
end

local function files()
    local list = { "Locales/enUS.lua" }
    for line in io.lines("PetCall.toc") do
        line = line:gsub("\r", ""):gsub("\\", "/")
        if line:match("^Core/") or line:match("^UI/") then list[#list + 1] = line end
    end
    return list
end

describe("Glyphs", function()
    it("code and enUS strings use only characters the game font has", function()
        local bad = {}
        for _, path in ipairs(files()) do
            local f = assert(io.open(path, "rb"))
            local lineNo = 0
            for line in f:lines() do
                lineNo = lineNo + 1
                local code = line:gsub("%-%-.*$", "")      -- comments never reach the screen
                for cp, ch in codepoints(code) do
                    local control = cp < 32 and cp ~= 9 and cp ~= 13      -- stray control bytes from broken escapes
                    if control or (cp > 0xFF and not ALLOWED[cp]) then bad[#bad + 1] = path .. ":" .. lineNo .. " U+" .. format("%04X", cp) end
                end
            end
            f:close()
        end
        assert.same({}, bad)
    end)
end)
