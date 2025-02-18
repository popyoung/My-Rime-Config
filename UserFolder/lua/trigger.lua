local function make(trig_key, trig_translator)
    local flag = false

    local function processor(key, env)
        local kAccepted = 1
        local kNoop = 2
        local engine = env.engine
        local context = engine.context

        if key:repr() == trig_key then
            if context:is_composing() then
                flag = true
                context:refresh_non_confirmed_composition()
                return kAccepted
            end
        end

        -- log.error(string.format("key: %s", key:repr()))
        if key:repr() == "shift+Rnter" then
        end

        return kNoop
    end
    local translator = {}
    function translator.func(input, seg, env)
        if flag then
            flag = false
            trig_translator(input, seg, env)
        end
    end

    function translator.init(env)
        env.memory = Memory(env.engine, env.engine.schema)
        env.memory2 = Memory(env.engine, env.engine.schema, "melt_eng")
        env.notifier = env.engine.context.commit_notifier:connect(function(ctx)
            local commit = ctx.commit_history:back()
            if commit then
                if commit.type:sub(1, 6) == "cloud:" then
                    local code = commit.type:sub(7)
                    local entry = DictEntry()
                    entry.text = commit.text

                    if (contains_english(commit.text)) then
                        entry.custom_code = string.lower(string.gsub(code, " ", "")) .. " "
                        env.memory2:start_session()
                        local r = env.memory2:update_userdict(entry, 1, "")
                        env.memory2:finish_session()
                        -- log.error(string.format("添加用户词典2：%s, %s, %q", code, commit.text, r))
                        -- log.error(commit.type .. " " .. commit.text .. " " .. entry.custom_code)
                    else
                        entry.custom_code = code .. " "
                        env.memory:start_session()
                        local r = env.memory:update_userdict(entry, 1, "")
                        env.memory:finish_session()
                        -- log.error(string.format("添加用户词典：%s, %s, %q", code, commit.text, r))
                    end
                end
            end
        end)
    end
    function contains_english(str)
        -- 匹配中文字符的 Unicode 范围
        return string.match(str, "[a-zA-Z]") ~= nil
    end
    function translator.fini(env)
        env.notifier:disconnect()
        env.memory:disconnect()
        env.memory = nil
        env.memory2:disconnect()
        env.memory2 = nil
        collectgarbage()
    end

    return {
        processor = processor,
        translator = translator
    }
end

return make
