-- lua/poptest.lua
local print = log.error

local symbolMap = {
    [44] = ',',
    [46] = '.',
    [58] = ':',
    [59] = ';',
    [34] = '"',
    [39] = "'",
    [91] = '[',
    [93] = ']',
    [123] = '{',
    [125] = '}',
    [40] = '(',
    [41] = ')',
    [60] = '<',
    [62] = '>',
    [63] = '?',
    [33] = '!',
    [92] = '\\'
}

local processor = {}
function processor.func(key_event, env)
    local context = env.engine.context

    -- print('keycode:' .. key_event.keycode .. '   ctrl: ' .. tostring(key_event:ctrl()) .. '   release: ' ..
    --           tostring(key_event:release()))
    -- print('key_event:' .. key_event:repr() .. '   latest_text: ' .. context.commit_history:latest_text())
    -- print('commit_history: ' .. context.commit_history:repr())

    local mode = context:get_option("ascii_mode")

    if mode then
        return 2
    end

    -- print(string.format("key: %s", key_event:repr()))
    if context:is_composing() and key_event:repr() == "Shift+Return" then
        -- print('get_commit_text: ' .. context:get_commit_text())
        env.engine:commit_text(context:get_commit_text())
        local entry = DictEntry()
        entry.text = context:get_commit_text()
        entry.custom_code = string.lower(context:get_commit_text()) .. " "
        env.memory:start_session()
        local r = env.memory:update_userdict(entry, 1, "")
        env.memory:finish_session()
        -- print(string.format("强制添加用户词典2：%s, %s, %q", entry.custom_code, entry.text, r))
        context:clear()
        return 1
    end

    local symbol = nil
    symbol = symbolMap[key_event.keycode]
    if symbol ~= nil then
        if context:get_commit_text():match("^[a-zA-Z]+$") or (key_event:ctrl() and not key_event:release()) then
            -- if context:get_commit_text():match("^[a-zA-Z]+$") then
            env.engine:commit_text(context:get_commit_text() .. symbol)
            context:clear()
            return 1
        end
    end
    -- 实现")"的特殊处理
    if key_event:ctrl() and key_event:release() and key_event.keycode == 41 then
        env.engine:commit_text(context:get_commit_text() .. ')')
        context:clear()
        return 1
    end

    return 2
end

function processor.init(env)
    env.memory = Memory(env.engine, env.engine.schema, "melt_eng")
    -- env.notifier = env.engine.context.commit_notifier:connect(function(ctx)
    --     local commit = ctx.commit_history:back()
    --     if commit then
    --         if commit.type:sub(1, 6) == "cloud:" then
    --             local code = commit.type:sub(7)
    --             local entry = DictEntry()
    --             entry.text = commit.text

    --             if (contains_english(commit.text)) then
    --                 entry.custom_code = string.lower(string.gsub(code, " ", "")) .. " "
    --                 env.memory2:start_session()
    --                 local r = env.memory2:update_userdict(entry, 1, "")
    --                 env.memory2:finish_session()
    --                 -- log.error(string.format("添加用户词典2：%s, %s, %q", code, commit.text, r))
    --                 -- log.error(commit.type .. " " .. commit.text .. " " .. entry.custom_code)
    --             else
    --                 entry.custom_code = code .. " "
    --                 env.memory:start_session()
    --                 local r = env.memory:update_userdict(entry, 1, "")
    --                 env.memory:finish_session()
    --                 -- log.error(string.format("添加用户词典：%s, %s, %q", code, commit.text, r))
    --             end
    --         end
    --     end
    -- end)
end
local function contains_english(str)
    -- 匹配中文字符的 Unicode 范围
    return string.match(str, "[a-zA-Z]") ~= nil
end
function processor.fini(env)
    -- env.notifier:disconnect()
    env.memory:disconnect()
    env.memory = nil
    collectgarbage()
end

local function popTranslator(input, seg, env)
    local context = env.engine.context
    -- print('input:' .. input .. ' seg.status:' .. seg.status .. ' seg.start:' .. seg.start .. ' seg._end:' .. seg._end ..
    --   ' seg.length:' .. seg.length .. ' seg.selected_index:' .. seg.selected_index)
    --  if not seg.has_tag('histroy') then
    --      return
    --  end
    -- print(context.commit_history:repr())
    -- print('commit_history: ' .. context.commit_history:latest_text())
    if (input == "date") then
        --- Candidate(type, start, end, text, comment)
        yield(Candidate("date", seg.start, seg._end, os.date("%Y年%m月%d日"), " 日期"))
    end

end

local function popFilter(translation, env)
    local normal_cands = {}
    local symbol_cands = {}
    local single_char_cands = {}
    local context = env.engine.context
    local preedit_code = context.input
    local caret_pos = context.caret_pos
    local commit_history = context.commit_history
    -- print(1)

    -- for r_iter, commit_record in context.commit_history:iter() do
    --     print(commit_record.type)
    --     print(commit_record.text)
    -- end

    -- print(10)
    for cand in translation:iter() do
        -- 符号自动上屏(;[a-z])
        if preedit_code:match("^;%l+$") and not symbol_cands[cand] then
            table.insert(symbol_cands, cand)
        end

        -- 单字全码唯一自动上屏(xy/ab?)
        if (not single_char_cands[cand]) and preedit_code:match("^%l%l/%l%l?$") then
            table.insert(single_char_cands, cand)
        end

        if #normal_cands >= 150 then
            break
        end
        table.insert(normal_cands, cand)
    end
    -- 符号自动上屏(;[a-z]+)
    if preedit_code:match("^;%l+$") and (#symbol_cands == 1) then
        env.engine:commit_text(symbol_cands[1].text)
        context:clear()
        return 1 -- kAccepted
    end
end

function print_table_simple(t)
    for k, v in pairs(t) do
        print(k .. " = " .. tostring(v))
    end
end

return {
    processor = processor,
    translator = {
        func = popTranslator
    },
    filter = {
        func = popFilter
    }
}
