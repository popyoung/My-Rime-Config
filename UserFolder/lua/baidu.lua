local json = require("json")

-- 获取当前 Lua 文件的路径
local function getCurrentLuaFilePath()
    local info = debug.getinfo(2, "S")
    if info and info.source then
        local source = info.source
        if source:sub(1, 1) == "@" then
            -- 去掉开头的 @ 符号
            local fullPath = source:sub(2)
            -- 查找最后一个路径分隔符的位置
            local lastSlashIndex = fullPath:match(".*()[/\\]")
            if lastSlashIndex then
                -- 截取目录部分
                return fullPath:sub(1, lastSlashIndex)
            end
        end
    end
    log.error("Failed to get current Lua file path.")
end

-- 获取当前 Lua 文件所在的目录路径
local luaDir = getCurrentLuaFilePath()

package.cpath = package.cpath .. ";" .. luaDir .. "?.dll"

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
