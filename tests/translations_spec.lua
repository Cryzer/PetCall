-- The translations live in docs/curseforge/<locale>-import.lua, which only a local checkout has:
-- where they are present, each must carry exactly enUS's keys.
local LOCALES = { "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }

local function capture()
    return setmetatable({}, { __newindex = function(t, key, value)
        rawset(t, key, value == true and key or value)
    end })
end

local function enUS()
    local L = capture()
    assert(loadfile("Locales/enUS.lua"))("PetCall", { NewLocale = function() return L end })
    return L
end

local function imports()
    local list = {}
    for _, locale in ipairs(LOCALES) do
        local path = "docs/curseforge/" .. locale .. "-import.lua"
        local f = io.open(path, "rb")
        if f then
            f:close()
            local L = capture()
            setfenv(assert(loadfile(path)), { L = L })()
            list[#list + 1] = { locale = locale, L = L }
        end
    end
    return list
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local function specifiers(text)
    local list = {}
    for spec in text:gmatch("%%[%-%d%.]*[%a%%]") do
        if spec ~= "%%" then list[#list + 1] = spec end
    end
    return table.concat(list, " ")
end

-- a sentence said twice in one text: what an edit that adds to an old translation leaves behind
local function repeated(text)
    text = text:gsub("\n", "\1")
    for _, stop in ipairs({ "%. ", "! ", "%? ", "。", "！", "？" }) do
        text = text:gsub(stop, "%0\1")
    end
    local seen, twice = {}, {}
    for sentence in text:gmatch("[^\1]+") do
        sentence = sentence:match("^%s*(.-)%s*$")
        if #sentence > 3 then
            if seen[sentence] then twice[#twice + 1] = sentence end
            seen[sentence] = true
        end
    end
    return twice
end

describe("Translations", function()
    it("every translation file has exactly enUS's keys", function()
        local en = enUS()
        local problems = {}
        for _, file in ipairs(imports()) do
            for _, key in ipairs(sortedKeys(en)) do
                if file.L[key] == nil then problems[#problems + 1] = file.locale .. " missing: " .. key end
            end
            for _, key in ipairs(sortedKeys(file.L)) do
                if en[key] == nil then problems[#problems + 1] = file.locale .. " extra: " .. key end
            end
        end
        assert.equal("", table.concat(problems, "\n"))
    end)
    it("format specifiers match enUS", function()
        local en = enUS()
        local problems = {}
        for _, file in ipairs(imports()) do
            for _, key in ipairs(sortedKeys(file.L)) do
                if en[key] and specifiers(en[key]) ~= specifiers(file.L[key]) then
                    problems[#problems + 1] = file.locale .. ": " .. key
                end
            end
        end
        assert.equal("", table.concat(problems, "\n"))
    end)
    it("no translation says a sentence twice that enUS says once", function()
        local en = enUS()
        local problems = {}
        for _, file in ipairs(imports()) do
            for _, key in ipairs(sortedKeys(file.L)) do
                if en[key] and #repeated(en[key]) == 0 then
                    for _, sentence in ipairs(repeated(file.L[key])) do
                        problems[#problems + 1] = file.locale .. " " .. key .. ": " .. sentence
                    end
                end
            end
        end
        assert.equal("", table.concat(problems, "\n"))
    end)
end)
