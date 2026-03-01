-- 获取当前 Lua 文件所在的目录路径
local luaDir = GetCurrentLuaFilePath()

package.cpath = package.cpath .. ";" .. luaDir .. "?.dll"

local http = require("simplehttp")
local iconv = require("iconv")

http.TIMEOUT = 0.5

-- Algorithm from https://github.com/wanghuafeng/common_utils/blob/master/rong_tools/sogou_cloud_words.py

local function rc(x)
    local start = 0
    for i = 1, #x do
        start = start ~ string.byte(x, i)
    end
    return string.char(start)
end

local function serial_keys(keys)
    local token = "\0\5\0\0\0\0\1"
    local total_len = #token + #keys + 3
    local data = string.char(total_len) .. token .. string.char(#keys) .. keys
    return data .. rc(data)
end

local function key_from_serial(data)
    local token = "\0\5\0\0\0\0\1"
    local total_len = string.byte(data, 1)
    local key_len = total_len - #token - 3
    return string.sub(data, -key_len - 1, -2)
end

local function open_sogou(keys, durtot, version)
    durtot = durtot or 0
    version = version or "3.7"
    local url = string.format(
        "http://shouji.sogou.com/web_ime/mobile.php?durtot=%d&h=000000000000000&r=store_mf_wandoujia&v=%s", durtot,
        version)
    local data = serial_keys(keys)
    -- 输出请求数据
    -- log.error(string.format("[sougou] 请求搜狗云拼音：url=%s, data=%s", url, data))
    return http.request(url, data)
end

local function parse_result(result)
    local words = {}

    if string.byte(result, 1) + 2 ~= #result then
        log.error("[sougou] invalid size, expected", string.byte(result, 1) + 2, "got", #result)
        return words
    end

    local num_words = string.unpack("<H", string.sub(result, 0x12 + 1, 0x12 + 2))
    if num_words == 0 or num_words > 32 then
        log.warning("[sougou] strange words num", num_words)
    end

    local pos = 0x14 -- data packet starts at 0x14

    for i = 1, num_words do
        local str_len = string.unpack("<H", string.sub(result, pos + 1, pos + 2))
        if str_len == 0 or str_len > 0xFF then
            log.error("[sougou] Invalid string length")
        end
        pos = pos + 2

        if str_len == 0 then
            -- Skip empty string
        else
            local word = string.sub(result, pos + 1, pos + str_len)
            local cd, err = iconv.new("utf-8", "utf-16le")
            if not cd then
                log.error(string.format("[sougou] word %s can't convert to utf-8: %s", word, err))
            else
                word, err = cd:iconv(word)
                if not word then
                    log.error(string.format("[sougou] word can't convert to utf-8: %s", err))
                end
            end
            table.insert(words, word)
        end
        pos = pos + str_len

        -- unknown part, like 0x12c, 0x12b, etc.
        str_len = string.unpack("<H", string.sub(result, pos + 1, pos + 2))
        pos = pos + str_len + 2

        -- unknown part, like 0x01, 0x02, etc.
        str_len = string.unpack("<H", string.sub(result, pos + 1, pos + 2))
        pos = pos + str_len + 2 + 1
    end

    if pos ~= #result then
        log.warning("[sougou] buffer not exhausted!")
    end

    return words
end

local function get_cloud_words(keys)
    local resp, code = open_sogou(keys)
    if code ~= 200 then
        log.error(string.format("[sougou] invalid response for input <%s>, status code: %d", keys, code))
        return {}
    end

    return parse_result(resp)
end

-- 核心函数：枚举所有 en→eng/in→ing 的组合（修复版）
local function enum_en_in_combinations(input)
    if type(input) ~= "string" then
        return {}
    end

    -- 步骤1：拆分字符串为单词（按空格分割）
    local words = {}
    for word in input:gmatch("%S+") do -- %S+ 匹配非空单词（按空格分割）
        table.insert(words, word)
    end
    if #words == 0 then
        return { input }
    end

    -- 步骤2：为每个单词生成替换变体（原词 + 替换后的词）
    local word_variants = {}    -- 存储每个单词的变体列表
    for _, word in ipairs(words) do
        local variants = { word } -- 先加入原词
        -- 匹配单词末尾的 en → 生成 eng 变体
        if word:sub(-2) == "en" then
            local new_word = word:sub(1, -3) .. "eng"
            table.insert(variants, new_word)
        end
        -- 匹配单词末尾的 in → 生成 ing 变体
        if word:sub(-2) == "in" then
            local new_word = word:sub(1, -3) .. "ing"
            table.insert(variants, new_word)
        end
        table.insert(word_variants, variants)
    end

    -- 步骤3：递归组合所有单词的变体（核心：笛卡尔积）
    local function combine(variants_list, idx, current)
        local result = {}
        current = current or {}
        if idx > #variants_list then
            -- 组合当前路径的单词为字符串
            table.insert(result, table.concat(current, " "))
            return result
        end
        -- 遍历当前单词的所有变体
        for _, variant in ipairs(variants_list[idx]) do
            table.insert(current, variant)
            -- 递归组合下一个单词
            local sub_result = combine(variants_list, idx + 1, current)
            for _, s in ipairs(sub_result) do
                table.insert(result, s)
            end
            table.remove(current) -- 回溯
        end
        return result
    end

    -- 生成所有组合并返回
    local all_combinations = combine(word_variants, 1)
    return all_combinations
end

local function translator(input, seg, env)
    -- local list = get_cloud_words(input)
    local map = {}
    local script_text_list = enum_en_in_combinations(env.script_text)


    for _, script_text in ipairs(script_text_list) do
        local list = get_cloud_words(script_text:gsub("%s+", ""))
        local yielded_candidates = 0
        local max_candidates = 5
        for _, v in ipairs(list) do
            if yielded_candidates >= max_candidates then
                break
            end
            local c = Candidate("cloud:" .. script_text, seg.start, seg._end, v, "☁️")
            c.quality = 2
            c.preedit = script_text:gsub("%s+", "")
            yield(c)

            yielded_candidates = yielded_candidates + 1
        end
    end
end

return translator
