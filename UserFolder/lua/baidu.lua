local json = require("json")
local http = require("simplehttp")
http.TIMEOUT = 0.5

local function make_url(input, bg, ed)
    return 'https://olime.baidu.com/py?input=' .. input .. '&inputtype=py&bg=' .. bg .. '&ed=' .. ed ..
               '&result=hanzi&resultcoding=utf-8&ch_en=0&clientinfo=web&version=1'
end

local function translator(input, seg)
    local url = make_url(input, 0, 5)
    local reply = http.request(url)
    local _, j = pcall(json.decode, reply)
    if j.status == "T" and j.result and j.result[1] then
        for i, v in ipairs(j.result[1]) do
            local code = string.gsub(v[3].pinyin, "'", " ")
            -- log.error("translator: " .. code .. "; " .. v[1] .. "; " .. v[2] .. "; " .. input)

            local c = Candidate("cloud:" .. code, seg.start, seg._end, v[1], "☁️")
            c.quality = 2
            if string.gsub(v[3].pinyin, "'", "") == string.sub(input, 1, v[2]) then
                c.preedit = code
            end
            yield(c)
        end
    end
end

return translator
