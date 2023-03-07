function symbKostil(str)
    for _, r in ipairs({'%[', '%(', '%)', '%.'}) do  -- костыль) чтоб искались эти символы. Для find и gsub. С '^' и '$' не помогает, как ни добавляй. В них зашито начало и конец строки
        str = str:gsub(r, '%'..r)  -- так работает все, кроме '%'
        --local pos = str:find(r)  -- частично работает для '%%'
        --if pos ~= nil then
        --    str = str:sub(1, pos - 1) .. r .. str:sub(pos + 1)
        --end
    end
    return str
end

function string.myGsub(str, subStr, newStr, to)
    return str:gsub(symbKostil(subStr), newStr, to)
end

function string.myFind(str, subStr, to)
    return str:find(symbKostil(subStr), to)
end

function string.myReplace(str, pos, len, newStr)
    if pos == 1 then
        return newStr .. str:sub(pos + len)
    end
    return str:sub(1, pos - 1) .. newStr .. str:sub(pos + len)
end

function string.mySplit(str, sep)
    local t = {}
    for s in str:gmatch('([^'..sep..']+)') do
        table.insert(t, s)
    end
    return t
end

function shiftTable(tbl, t)
    local tblShift = {table.unpack(tbl, t + 1, #tbl)}
    for _, b in pairs({table.unpack(tbl, 1, t)}) do
        table.insert(tblShift, b)
    end
    return tblShift
end

function getInput(fileName)
    local lines = {}
    for line in io.lines(fileName) do
        line = line:gsub('%s+', '')
        table.insert(lines, line)
    end
    return lines
end

function getRules(rulesInput)
    local rules = {}
    for _, r in ipairs(rulesInput) do
        table.insert(rules, r)
    end
    return rules
end

function getSyntax(syntaxInput)
    local syntax = {}
    for _, si in ipairs(syntaxInput) do
        local name = si:match('^[^=]+')  -- [^=] - класс символов, кот. соотв-ет всему, кроме =
        local val = si:match('\"(.+)\"')
        syntax[name] = val
    end
    return syntax
end

function indexInListRBNF(rule, br, listRBNF)
    local type
    if br == '{' then type = 'Iter' end
    if br == '[' then type = 'Opt' end
    if br == '(' then type = 'Nes' end
    for i, _ in ipairs(listRBNF) do
        if (listRBNF[i].nonParsedRule == rule) and (listRBNF[i].type == type) then
            return i
        end
    end
    return nil
end

function parseRight(right, brArr, changed, listRBNF, count, syntax)
    if right:myFind(brArr[1]) then
        --print('\n')
        local endT = right:myFind(brArr[2])
        local startT = endT - right:sub(1, endT - 1):reverse():myFind(brArr[1]:reverse()) - #brArr[1] + 1 -- ищет позицию последнего '[' перед первым ']'
        --print(string.format("startT = %s   endT = %s", startT, endT))
        local change = right:sub(startT + #brArr[1], endT - 1)
        --print(string.format('change = %s', change))
        if (not change:myFind(brArr[4])) and (not change:myFind(brArr[7])) then
            local changeWithBr = right:sub(startT, endT + #brArr[2] - 1)
            --print(string.format('chang2 = %s', changeWithBr))
            local newNonTerm
            -- Если выражение в обязательно, т.е. в () скобках и внутри нет никаких скобок, то его не надо заменять на новый нетерм.
            if (brArr[1] == syntax['necessaryStart']) and (not change:myFind(brArr[1])) then
                newNonTerm = change
            else
                local index = indexInListRBNF(change, brArr[1], listRBNF)
                if not index then
                    local newRBNF = {
                        ['name'] = 'Nt' .. tostring(count),
                        ['type'] = brArr[3],
                        ['nonParsedRule'] = change
                    }
                    table.insert(listRBNF, newRBNF)
                    index = count
                    count = count + 1
                end
                newNonTerm = syntax['nonTerminalStart'] .. 'Nt' .. tostring(index) .. syntax['nonTerminalEnd']
            end
            changed = true
            print(string.format('\t\t%s     change: %s -> %s', right, changeWithBr, newNonTerm))
            right = right:myGsub(changeWithBr, newNonTerm)  --   [__S__]  ->  __Nonterm1__
            print('\t\t'..right..'\n')
        end
    end
    return right, changed, listRBNF, count
end

function parseRBNF(rules, syntax)
    local listRBNF = {}
    local count = 1
    for _, r in ipairs(rules) do
        local split = r:mySplit(syntax['arrow'])
        local left, right = split[1], split[2]
        print(string.format('\t%s := %s\n', left, right))
        local bracketsArr = {syntax['iterStart'], syntax['iterEnd'], 'Iter',
                             syntax['optionalStart'], syntax['optionalEnd'], 'Opt',
                             syntax['necessaryStart'], syntax['necessaryEnd'], 'Nes'}
        -- ! Пока в правой части правила есть хоть какие-то скобки, заменять каждую из них на новый нетерминал изнутри наружу.
        while (right:myFind(syntax['necessaryStart'])) or (right:myFind(syntax['iterStart'])) or (right:myFind(syntax['optionalStart'])) do
            local changed = false
            right, changed, listRBNF, count = parseRight(right, bracketsArr, changed, listRBNF, count, syntax)
            if not changed then
                bracketsArr = shiftTable(bracketsArr, 3)
            end
        end

        -- если такое правило уже есть - обработать, но не здесь, а в getGram()
        --ifindexInListRBNF(right, '(', listRBNF) == nil then
        --
        --end
        local leftNew = left:myGsub(syntax['nonTerminalStart'], ''):myGsub(syntax['nonTerminalEnd'], '')
        table.insert(listRBNF, {['name'] = leftNew, ['type'] = 'Nes', ['nonParsedRule'] = right})
    end
    return listRBNF
end

function getGram(listRBNF, syntax, syntaxCF)
    -- Отказался от этой идеи, так как не учел, что надо удалять не только правило, но и то, где оно используется, но не везде(
    -- Удаление [N]->[S]|$ , так как оно входит в [N]->[S][N]|$
    --for i, r in ipairs(listRBNF) do
    --    if r.type == 'Iter' then
    --        if i > 1 and listRBNF[i - 1].type == 'Opt' and listRBNF[i - 1].nonParsedRule == r.nonParsedRule then
    --            table.remove(listRBNF, i - 1)
    --        end
    --        if i < #listRBNF and listRBNF[i + 1].type == 'Opt' and listRBNF[i + 1].nonParsedRule == r.nonParsedRule then
    --            table.remove(listRBNF, i + 1)
    --        end
    --    end
    --end
    -- [N]->[S][N]|$  +  [N]->[S]  =>  [N]->[S][N]|[S]
    --for _, r in ipairs(listRBNF) do
    --    if r.type == 'Iter' then
    --        for j, rj in ipairs(listRBNF) do
    --            if rj.type == 'Nes' and rj.nonParsedRule == r.nonParsedRule then
    --                table.remove(listRBNF, j)
    --                r.type = 'Iter+'
    --            end
    --        end
    --    end
    --end

    local gram = {}
    for _, r in ipairs(listRBNF) do
        -- Заменяем синтаксис РБНФ на синтаксис КС
        local name = syntaxCF['nonTerminalStart'] .. r.name .. syntaxCF['nonTerminalEnd']
        local rule = r.nonParsedRule
        if syntax['nonTerminalStart'] ~= syntaxCF['nonTerminalStart'] then
            while rule:myFind(syntax['nonTerminalStart']) do
                rule = rule:myGsub(syntax['nonTerminalStart'], syntaxCF['nonTerminalStart'], 1)
                           :myGsub(syntax['nonTerminalEnd'],   syntaxCF['nonTerminalEnd'], 1)
            end
        end
        if syntax['alternative'] ~= syntaxCF['alternative'] then
            while rule:myFind(syntax['alternative']) do
                rule = rule:myGsub(syntax['alternative'], syntaxCF['alternative'], 1)
            end
        end
        if syntax['epsilon'] ~= syntaxCF['epsilon'] then
            while rule:myFind(syntax['epsilon']) do
                rule = rule:myGsub(syntax['epsilon'], syntaxCF['epsilon'], 1)
            end
        end

        -- Приводим к КС-виду
        if r.type == 'Opt' then
            rule = rule .. syntaxCF['alternative'] .. syntaxCF.epsilon
        end
        if r.type == 'Iter' then
            rule = rule .. name .. syntaxCF['alternative'] .. syntaxCF.epsilon
        end
        --if r.type == 'Iter+' then
        --    rule = rule .. name .. syntaxCF['alternative'] .. rule
        --end
        --rule = addSpaces(rule)
        rule = rule:myGsub(syntaxCF['alternative'], ' ' .. syntaxCF['alternative'] .. ' ')
        table.insert(gram, name .. ' ' .. syntaxCF['arrow'] .. ' ' .. rule)
    end
    return gram
end

function checkRegex(rules, syntax)
    local file = io.open('input/regex.txt')
    local regexNT = file:read('*line'):match('.+::=%s*(.+)%s*')
    local regexT = file:read('*line'):match('.+::=%s*(.+)%s*')
    local ok = true
    for _, r in ipairs(rules) do
        local split = r:mySplit(syntax['arrow'])
        local left, right = split[1], split[2]
        -- Левая часть правила. Нетерминалы
        if left ~= left:match(symbKostil(syntax['nonTerminalStart'])..regexNT..symbKostil(syntax['nonTerminalEnd'])) then
            print('Error (regex): '..left..' <- Left nonterm doesn\'t match to it\'s regex')
            ok = false
        end

        -- Правая часть правила.
        local terms = right:gsub(symbKostil(syntax['nonTerminalStart'])..regexNT..symbKostil(syntax['nonTerminalEnd']), syntax['alternative'])  -- Заменяем нетерминалы на '|'
                           :myGsub(syntax['optionalStart'], syntax['alternative']):myGsub(syntax['optionalEnd'], syntax['alternative'])
                           :myGsub(syntax['necessaryStart'], syntax['alternative']):myGsub(syntax['necessaryEnd'], syntax['alternative'])
                           :myGsub(syntax['iterStart'], syntax['alternative']):myGsub(syntax['iterEnd'], syntax['alternative'])
                           -- Не уверен, тут круглые скобки или квадратные:
                           :gsub('('..syntax['alternative']..'+)', syntax['alternative'])  -- Сворачиваем все много '|' в одну
                           --:gsub('%s', '')  -- Удаляем пробелы
                           :mySplit(syntax['alternative'])  -- Забираем терминалы между '|'
        --print('terms = '..terms)
        for _, term in ipairs(terms) do
            --print('term = '..term)
            if term ~= term:match(regexT) then
                -- Если эл-т не подходит, как терминал, то проверим, окажется ли он неправильным нтеерминалом:
                local rNterm = term:match(syntax['nonTerminalStart']..'(.+)'..syntax['nonTerminalEnd'])
                if rNterm then
                    -- Нетерминалы
                    --print('rNterm = '..rNterm)
                    print('Error (regex): '..term..' <- Right nonterm doesn\'t match to it\'s regex')
                else
                    -- Терминалы
                    print('Error (regex): '..term..' <- Term doesn\'t match to it\'s regex')
                end
                ok = false
            end
        end
    end
    return ok
end

function checkRightSyntax(right, br, changed, ok)
    local endT = right:myFind(br[2])
    local startT = right:myFind(br[1])
    --print('startT =', startT, 'end =', endT)
    -- Есть '[', нет ']'
    if startT and not endT then
        print('Error (syntax): ' .. br[2] .. ' <- not found in : ' .. right)
        ok = false
    end
    -- Есть ']', нет '['
    if not startT and endT then
        print('Error (syntax): ' .. br[1] .. ' <- not found in : ' .. right)
        ok = false
    end
    -- Есть '[' и ']'
    if startT and endT then
        -- Проверка, что в скобках есть выражение
        if endT - startT == 1 then
            print('Error (syntax): No expression in brackets')
            ok = false
        end
        -- Проверка количества других скобок внутри этих скобок
        local _, nb3 = right:myGsub(br[3], '')
        local _, nb4 = right:myGsub(br[4], '')
        local _, nb5 = right:myGsub(br[5], '')
        local _, nb6 = right:myGsub(br[6], '')
        --print(nb3, nb4, nb5, nb6)
        if nb3 ~= nb4 then
            print('Error (syntax): Not equal number of ' .. br[3] .. ' and ' .. br[4] .. '   in: ' .. right)
            ok = false
        end
        if nb5 ~= nb6 then
            print('Error (syntax): Not equal number of ' .. br[5] .. ' and ' .. br[6] .. '    in: ' .. right)
            ok = false
        end
        -- Если все норм, то удаляет правильную пару скобок
        startT = endT - right:sub(1, endT - 1):reverse():myFind(br[1]:reverse()) - #br[1] + 1 -- ищет позицию последнего '[' перед первым ']'
        right = right:myGsub(right:sub(startT, endT + #br[2] - 1), 't')
        changed = true
    end
    --print(right)
    return right, changed, ok
end

function checkSyntax(rules, syntax)
    local ok = true
    for i = 1, 3 do
        -- __X__ := {([)(])}   Тут количество скобок правильное, но порядок неверный. => Проверяем, начиная с со всех вариантов скобок
        local br = {syntax['iterStart'], syntax['iterEnd'],
                    syntax['optionalStart'], syntax['optionalEnd'],
                    syntax['necessaryStart'], syntax['necessaryEnd']}
        br = shiftTable(br, 2 * i)
        for _, r in ipairs(rules) do
            if not r:match(syntax['arrow']) then
                print('Error (syntax): Not right arrow: ' .. r)
                ok = false
            end
            local split = r:mySplit(syntax['arrow'])
            local _, right = split[1], split[2]
            -- Проверка правлиьности правой части
            while ok and (right:myFind(syntax['necessaryStart']) or (right:myFind(syntax['iterStart'])) or (right:myFind(syntax['optionalStart'])) or
                    right:myFind(syntax['necessaryEnd']) or (right:myFind(syntax['iterEnd'])) or (right:myFind(syntax['optionalEnd']))) do
                local changed = false
                right, changed, ok = checkRightSyntax(right, br, changed, ok)
                if not changed then
                    br = shiftTable(br, 2)
                end
            end
            if not ok then break end
        end
    end
    return ok
end

function main()
    print('\n\n')
    -- Ввод синтаксиса РБНФ
    local syntaxInput = getInput('input/syntaxRBNF.txt')
    local syntax = getSyntax(syntaxInput)
    --print('\nsyntax:')
    --for name, val in pairs(syntax) do
    --    print(string.format("\t%s\t=\t%s", val, name))
    --end

    -- Ввод правил
    local rulesInput = getInput('input/RBNF.txt')
    local rules = getRules(rulesInput)
    --print('\nrules:')
    --for _, r in pairs(rules) do
    --    print('\t' .. r:myGsub(syntax['arrow'], ' '..syntax['arrow']..' '))
    --end

    -- Проверка синтаксиса правил
    if not checkSyntax(rules, syntax) then
        return
    end

    -- Проверка, удовлетворяют ли терм. и нетерм. регуляркам
    if not checkRegex(rules, syntax) then
        return
    end

    -- Парсер
    print('\nParser:')
    local listRBNF = parseRBNF(rules, syntax)
    --print('\nlistRBNF:')
    --for _, rbnf in ipairs(listRBNF) do
    --    print(string.format("\t%s  %s  %s", rbnf['name'], rbnf['type'], rbnf['nonParsedRule']))
    --end

    -- Ввод синтаксиса КС грамматики
    local syntaxCfInput = getInput('input/syntaxCF.txt')
    local syntaxCF = getSyntax(syntaxCfInput)
    --print('\nsyntaxCF:')
    --for name, val in pairs(syntaxCF) do
    --    print(string.format("\t%s\t=\t%s", val, name))
    --end

    -- Оформление КС грамматики
    local gram = getGram(listRBNF, syntax, syntaxCF)
    --print('\nlistRBNF:')
    --for _, rbnf in ipairs(listRBNF) do
    --    print(string.format("\t%s  %s  %s", rbnf['name'], rbnf['type'], rbnf['nonParsedRule']))
    --end
    print('\nCF grammar:')
    for _, g in ipairs(gram) do
        print('\t' .. g)
    end
end

main()