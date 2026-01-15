local json = require("json")

-- 获取当前 Lua 文件所在的目录路径
local luaDir = GetCurrentLuaFilePath()

package.cpath = package.cpath .. ";" .. luaDir .. "?.dll"

local http = require("simplehttp")
http.TIMEOUT = 0.5

-- 标准化搜索引擎返回数据为字符串数组
local function normalize_search_result(json_data, engine)
    local result_array = {}
    
    if engine == "baidu" then
        -- 百度数据结构：json_data.g 数组，包含 type 和 q 字段
        if json_data and json_data.g then
            for _, item in ipairs(json_data.g) do
                if item.type == "sug" and item.q then
                    table.insert(result_array, item.q)
                end
            end
        end
    elseif engine == "bilibili" then
        -- 哔哩哔哩数据结构：json_data.data.result.tag 数组，包含 term 字段
        if json_data and json_data.data and json_data.data.result and json_data.data.result.tag then
            for _, item in ipairs(json_data.data.result.tag) do
                if item.value then
                    table.insert(result_array, item.value)
                end
            end
        end
    elseif engine == "taobao" then
        -- 淘宝数据结构：json_data.result 数组，每个元素是 [关键词, 权重] 格式
        if json_data and json_data.result then
            for _, item in ipairs(json_data.result) do
                if item[1] then  -- 第一个元素是关键词
                    table.insert(result_array, item[1])
                end
            end
        end
    else
        log.error("不支持的搜索引擎类型：", engine or "nil")
    end
    
    return result_array
end

-- 从字符串数组中筛选最短的文字数组
local function find_shortest_strings(string_array)
    local shortest_length = math.huge
    local result_list = {}
    
    for _, str in ipairs(string_array or {}) do
        local current_len = utf8.len(str)
        if current_len then
            if current_len < shortest_length then
                shortest_length = current_len
                result_list = {str}
            elseif current_len == shortest_length then
                table.insert(result_list, str)
            end
        end
    end
    
    return result_list, shortest_length
end

-- 获取搜索引擎建议并标准化为字符串数组
local function get_search_suggestions(input, engine)
    local url
    local engine_name
    
    -- 根据引擎类型选择对应的请求函数
    if engine == "baidu" then
        url = 'https://www.baidu.com/sugrec?pre=1&p=3&ie=utf-8&json=1&prod=pc&from=pc_web&wd=' .. input
        engine_name = "百度"
    elseif engine == "bilibili" then
        url = 'https://api.bilibili.com/x/web-interface/suggest?term=' .. input
        engine_name = "哔哩哔哩"
    elseif engine == "taobao" then
        url = 'https://suggest.taobao.com/sug?code=utf-8&q=' .. input
        engine_name = "淘宝"
    else
        log.error("不支持的搜索引擎：", engine or "nil")
        return {}
    end
    
    local reply = http.request(url)
    local json_data, decode_err
    
    -- 捕获解析错误
    local ok = pcall(function()
        json_data = json.decode(reply)
    end)
    
    if not ok or not json_data then
        log.error(engine_name .. "JSON解析失败：", decode_err or "未知错误")
        return {}
    end
    
    return normalize_search_result(json_data, engine)
end

local function merge_arrays_ignore_dup(...)
    local seen = {}  -- 记录已出现的元素，用于去重
    local result = {} -- 合并去重后的结果数组
    
    -- 遍历所有传入的数组
    for _, arr in ipairs({...}) do
        -- 遍历当前数组的每个元素
        for _, value in ipairs(arr) do
            -- 生成唯一键：用tostring兼容非字符串元素（数字/布尔等）
            local key = tostring(value)
            if not seen[key] then
                seen[key] = true  -- 标记为已出现
                table.insert(result, value)  -- 加入结果数组
            end
        end
    end
    
    return result
end

local function translator(input, seg)
    -- 获取百度、哔哩哔哩和淘宝的建议，都标准化为字符串数组
    local baidu_suggestions = get_search_suggestions(input, "baidu")
    local bilibili_suggestions = get_search_suggestions(input, "bilibili")
    -- local taobao_suggestions = get_search_suggestions(input, "taobao")
    
    log.error(string.format("百度建议：%s", table.concat(baidu_suggestions, ", ")))
    log.error(string.format("哔哩哔哩建议：%s", table.concat(bilibili_suggestions, ", ")))
    -- log.error(string.format("淘宝建议：%s", table.concat(taobao_suggestions, ", ")))
    
    local all_suggestions = merge_arrays_ignore_dup(baidu_suggestions, bilibili_suggestions)
    -- local all_suggestions = merge_arrays_ignore_dup(baidu_suggestions, bilibili_suggestions, taobao_suggestions)
   
    -- 如果没有获取到任何建议，直接返回
    if #all_suggestions == 0 then
        return
    end
    
    -- 统一处理：筛选最短的文字数组
    local shortest_suggestions, _ = find_shortest_strings(all_suggestions)
    
    -- 生成候选词
    for _, value in ipairs(shortest_suggestions) do
        local c = Candidate("cloud:"..input, seg.start, seg._end, value, "☁️")
        c.quality = 2
        c.preedit = input
        yield(c)
    end
end

return translator
