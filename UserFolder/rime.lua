
--- 云拼音，Control+t 为云输入触发键
--- 使用方法：
--- 将 "lua_translator@cloud_pinyin_translator" 和 "lua_processor@cloud_pinyin_processor"
--- 分别加到输入方案的 engine/translators 和 engine/processors 中
function GetCurrentLuaFilePath()
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

-- local cloud_pinyin_provider = require("searchEngine")
local cloud_pinyin_provider = require("sougou")
-- local cloud_pinyin_provider = require("baidu")
-- local cloud_pinyin_provider = require("google")
local cloud_pinyin = require("trigger")("Control+t", cloud_pinyin_provider)
cloud_pinyin_translator = cloud_pinyin.translator
cloud_pinyin_processor = cloud_pinyin.processor
