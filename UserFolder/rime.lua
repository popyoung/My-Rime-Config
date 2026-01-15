
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

-- 通用对象转字符串函数（兼容userdata、方法、嵌套table、普通值）
function ObjectToString(obj, indent, visited, result)
    -- 初始化参数（递归调用时复用）
    indent = indent or 0
    visited = visited or {}
    result = result or {}  -- 用table拼接字符串，效率更高
    
    local prefix = string.rep("  ", indent)

    -- 标记已访问的对象/ud，防止递归死循环
    if visited[obj] then
        table.insert(result, prefix .. "[递归引用] (" .. type(obj) .. ")\n")
        return table.concat(result)
    end
    visited[obj] = true

    local obj_type = type(obj)
    -- 1. 处理非table类型（包括userdata）
    if obj_type ~= "table" then
        local val_str = ""
        if obj_type == "userdata" then
            -- 特殊处理userdata：尝试获取元表信息
            local mt = getmetatable(obj)
            val_str = "[userdata] " .. tostring(obj)
            -- 如果有元表，补充元表标识（比如__name字段）
            if mt and mt.__name then
                val_str = val_str .. " (元表：" .. mt.__name .. ")"
            end
        elseif obj_type == "string" then
            val_str = "\"" .. obj .. "\""
        elseif obj_type == "function" then
            val_str = "[方法] " .. tostring(obj)
        else
            val_str = tostring(obj)
        end
        table.insert(result, prefix .. val_str .. " (" .. obj_type .. ")\n")
        visited[obj] = false
        return table.concat(result)
    end

    -- 2. 处理table类型（空table）
    if next(obj) == nil then
        table.insert(result, prefix .. "{} (空table)\n")
        visited[obj] = false
        return table.concat(result)
    end

    -- 3. 遍历table的所有键值对
    table.insert(result, prefix .. "{\n")
    for key, value in pairs(obj) do
        -- 格式化键（字符串键直接显示，数字键加[]）
        local key_str = type(key) == "string" and key or "[" .. key .. "]"
        table.insert(result, prefix .. "  " .. key_str .. ": ")
        
        -- 递归处理值（会自动处理userdata/函数/嵌套table等）
        ObjectToString(value, indent + 2, visited, result)
    end
    table.insert(result, prefix .. "}\n")
    visited[obj] = false

    -- 拼接最终字符串并返回
    return table.concat(result)
end


-- local cloud_pinyin_provider = require("searchEngine")
local cloud_pinyin_provider = require("sougou")
-- local cloud_pinyin_provider = require("baidu")
-- local cloud_pinyin_provider = require("google")
local cloud_pinyin = require("trigger")("Control+t", cloud_pinyin_provider)
cloud_pinyin_translator = cloud_pinyin.translator
cloud_pinyin_processor = cloud_pinyin.processor
