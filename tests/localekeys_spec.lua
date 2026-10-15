-- Every L["..."] used by Core/ and UI/ must exist in Locales/enUS.lua.
local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local function sourceFiles()
    local list = {}
    for line in io.lines("PetCall.toc") do
        line = line:gsub("\r", ""):gsub("\\", "/")
        if line:match("^Core/") or line:match("^UI/") then list[#list + 1] = line end
    end
    return list
end

describe("Locale keys", function()
    it("every key used in code exists in enUS", function()
        local defined = {}
        for key in read("Locales/enUS.lua"):gmatch('L%["(.-)"%]%s*=') do defined[key] = true end
        local missing = {}
        for _, path in ipairs(sourceFiles()) do
            for key in read(path):gmatch('L%["(.-)"%]') do
                if not defined[key] then missing[#missing + 1] = path .. ": " .. key end
            end
        end
        assert.same({}, missing)
    end)
end)
