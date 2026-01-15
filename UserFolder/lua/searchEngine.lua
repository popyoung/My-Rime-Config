local json = require("json")

-- 获取当前 Lua 文件所在的目录路径
local luaDir = GetCurrentLuaFilePath()

package.cpath = package.cpath .. ";" .. luaDir .. "?.dll"

local http = require("simplehttp")
http.TIMEOUT = 0.5



local function reqBaidu(input)
    return 'https://www.baidu.com/sugrec?pre=1&p=3&ie=utf-8&json=1&prod=pc&from=pc_web&wd=' .. input
end

local function reqBilibili(input)
    return 'https://api.bilibili.com/x/web-interface/suggest?term=' .. input
end

local function find_shortest_sug_q(json_text)
    local shortest_length = math.huge
    local result_list = {}  -- 存储所有并列最短的q值
    -- 单次遍历完成所有逻辑
    for _, item in ipairs(json_text or {}) do
        -- 只处理type为sug且q字段非空的项
        if item.type == "sug" and item.q then
            local current_len = utf8.len(item.q)
            -- 跳过长度计算失败的情况
            if  current_len then
            
                -- 核心逻辑：一次遍历处理三种情况
                if current_len < shortest_length then
                    -- 找到更短的项：清空旧结果，更新最短长度，加入当前项
                    shortest_length = current_len
                    result_list = {item.q}  -- 重置数组，只保留当前更短的项
                elseif current_len == shortest_length then
                    -- 找到等长的项：直接加入数组
                    table.insert(result_list, item.q)
                end
                print(item.q, current_len, shortest_length)
            end
        end
        
    end
    
    return result_list, shortest_length
end

local function translator(input, seg)
    local url = reqBaidu(input)
    -- log.error('url:'..url)
    local reply = http.request(url)
    -- log.error('reply:'..reply)
    local baidu_json_data, decode_err
    -- 捕获解析错误（rxi的json.decode出错会直接抛异常，需用pcall包裹）
    local ok = pcall(function()
        baidu_json_data = json.decode(reply)
    end)
    
    if not ok or not baidu_json_data then
        log.error("JSON解析失败：", decode_err or "未知错误")
        return
    end

    local reply, _ = find_shortest_sug_q(baidu_json_data.g)

    -- url=reqBilibili(input)
    -- reply = http.request(url)
    -- local bilibili_json_data, decode_err
    -- -- 捕获解析错误（rxi的json.decode出错会直接抛异常，需用pcall包裹）
    -- local ok = pcall(function()
    --     bilibili_json_data = json.decode(reply)
    -- end)
    
    -- if not ok or not bilibili_json_data then
    --     log.error("JSON解析失败：", decode_err or "未知错误")
    --     return
    -- end
    -- reply, _ = find_shortest_sug_q(bilibili_json_data.data)
    for _, value in ipairs(reply) do
        local c = Candidate("cloud:"..input, seg.start, seg._end, value, "☁️")
        c.quality = 2
        yield(c)
    end
    -- if j.status == "T" and j.result and j.result[1] then
    --     for i, v in ipairs(j.result[1]) do
    --         local code = string.gsub(v[3].pinyin, "'", " ")
    --         log.error("translator: " .. code .. "; " .. v[1] .. "; " .. v[2] .. "; " .. input)

    --         local c = Candidate("cloud:" .. code, seg.start, seg._end, v[1], "☁️")
    --         c.quality = 2
    --         if string.gsub(v[3].pinyin, "'", "") == string.sub(input, 1, v[2]) then
    --             c.preedit = code
    --         end
    --         yield(c)
    --     end
    -- end
end

return translator
