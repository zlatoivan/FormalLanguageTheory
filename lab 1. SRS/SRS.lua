function getInput(fileName)
    local lines = {}
    for line in io.lines(fileName) do
        line = line:gsub('%s+', '')
        table.insert(lines, line)
    end
    return lines
end

function string.mySplit(str, sep)
    local t = {}
    for s in str:gmatch('([^'..sep..']+)') do
        table.insert(t, s)
    end
    return t
end

Term = {}
function Term:new(func, value, child)
    --self.__index = self
    self = setmetatable({}, Term)
    self.func = func
    self.value = value
    self.child = child
    return self
end

function parsePartTrs(part)
    --print(part)
    local out = Term:new(0, 'x')
    --local out = {['func'] = 0, ['value'] = 'x', ['child'] = nil}

    if part == 'x' then
        return out
    end

    out.func = 1
    out.value = part:match('(%a)')  --> g            | f
    --print('\tout.value = ', out.value)
    local inside = part:match('%((.*)%)')  --> f(x)  | x
    if out.value == nil or inside == nil then
        print('Error (syntax) in part of TRS: x is not the most nested element')
    end
    out.child = parsePartTrs(inside)
    --print('\tout.value = ', out.value)
    --print('\tout.child.func = ', out.child.func)
    --print('\tout.child.value = ', out.child.value)

    return out
end

function parseTrs(trs)
    local parsedTrs = {}
    for _, t in ipairs(trs) do
        t = t:mySplit('=')
        if #t ~= 2 then
            print('Error (syntax) in TRS: Related to an arrow')
            os.exit()
        end
        local left = parsePartTrs(t[1])
        --print(
        --    'func = '..left.func..'\n'..
        --    'value = '..left.value..'\n'..
        --    '\tchild = '..left.child.func..'\n'..
        --    '\tchild = '..left.child.value..'\n'..
        --    '\t\tchild = '..left.child.child.func..'\n'..
        --    '\t\tchild = '..left.child.child.value..'\n\n'
        --)
        local right = parsePartTrs(t[2])
        table.insert(parsedTrs, {['left'] = left, ['right'] = right})
    end
    return parsedTrs
end

function parseInter(inter)
    local interpretation = {}

    for _, int in ipairs(inter) do
        --print(int)
        local split = int:mySplit('->')
        if #split ~= 2 then
            print('Error (syntax) in Interpretstion: Related to an arrow')
            os.exit()
        end
        local head, func = split[1], split[2]

        -- Добавить знак в начало значения функции
        if func:match('^[x|%d]') then
            func = '+'..func
        end

        local polynom = {['exp'] = {}}
        -- Получить знак, коэффициент, степень каждого слагаемого
        for t in func:gmatch('[+|-]*[%d]*[%*]*x[%^%d]*') do
            --print(t)
            local sign = t:match('^[+|-]')
            if sign == nil then
                print('Error (syntax): There is no plus or minus sign in ' .. t)
            end
            if sign == '+' then
                sign = 1
            end
            if sign == '-' then
                sign = -1
            end
            --print('sign =', sign)
            local coeff = t:match('^[+|-](%d)')
            if coeff == nil then
                coeff = 1
            end
            --print('coeff =', coeff)
            local power = t:match('[+|-]*[%d]*[%*]*x[%^]+([%d]+)')
            if power == nil then
                power = 1
            end
            --print('power =', power, '\n')
            table.insert(polynom.exp, {['sign'] = sign, ['coeff'] = coeff, ['power'] = power})
        end
        table.insert(interpretation, {['head'] = head, ['expr'] = polynom})
    end
    return interpretation
end

function answ_str(t)
    if t.value ~= 'x' then
        return t.value .. ('(' .. answ_str(t.child) .. ')')
    else
        return 'x'
    end
end

function subtract(left, right)
    for _, r in pairs(right) do
        local saw = 0
        for _, l in pairs(left) do
            if l.power == r.power then
                saw = 1
                l.coeff = l.coeff - r.coeff
            end
            if saw == 0 then
                table.insert(left, {['coeff'] = -1 * r.coeff, ['power'] = r.power})
            end
        end
    end
    return left
end

function compare(left, right)
    local sub = subtract(left, right)
    local min = 0
    local coeff = 0
    for _, s in pairs(sub) do
        if s.power > min and s.coeff ~= 0 then
            min = s.power
            coeff = s.coeff
        end
    end
    if coeff < 0 then
        return false
    end
    return true
end

-- заменяет название функции на ее содержимое
function get_parts(value, inter)
    for _, i in pairs(inter) do
        if i.head == value then
            return i.expr.exp
        end
    end
    return {}
end

-- складывает подобные слагаемые
function append_Num(psign, pcoeff, ncoeff, npower, out)
    for _, o in pairs(out) do
        if o.power == npower then
            o.coeff = o.coeff + psign * pcoeff * ncoeff
            return out
        end
    end
    table.insert(out, {['coeff'] = psign * pcoeff * ncoeff, ['power'] = npower})
    return out
end


-- вспомогат.; раскрывает скобки по правилу (a+b)^2 = aa+ab+ba+bb
function up_Num(pcoeff, ppower, ncoeff, npower, out)
    --print("( ".. pcoeff.. " * x ^ ".. ppower.. " ) * ( ".. ncoeff.. " * x ^ ".. npower.. ")")
    for _, o in pairs(out) do
        if o.power == (ppower + npower) then
            o.coeff = o.coeff + pcoeff * ncoeff
            return out
        end
    end
    table.insert(out, {['coeff'] = pcoeff * ncoeff, ['power'] = ppower + npower})
    return out
end

-- возводит скобку в степень
function powerup(child, up, power)
    local out = {}
    power = tonumber(power)
    --print('power = ', power)
    if power > 1 then
        for _, n in pairs(child) do
            --print('n = ', n)
            for _, nn in pairs(up) do
                out = up_Num(n.coeff, n.power, nn.coeff, nn.power, out)
            end
        end
        return powerup(child, out, power - 1)
    end
    return up
end

function calc(side, inter)
    --print('--------IN calc---------------------------------')
    if side.child then
        --print(side.value)
        parts = get_parts(side.value, inter)
        --for _, p in pairs(parts) do
        --    print('\tcoeff = ' .. p.coeff .. '  sign = ' .. p.sign .. '  power = ' .. p.power)
        --end

        child = calc(side.child, inter)

        local out = {}
        for _, p in pairs(parts) do
            nchild = powerup(child, child, p.power)
            --print('nchild:')
            --for _, c in pairs(nchild) do
            --    print('\tcoeff = ' .. c.coeff .. '  power = '.. c.power)
            --end

            for _, n in pairs(nchild) do
                out = append_Num(p.sign, p.coeff, n.coeff, n.power, out)
            end
        --print('out:')
        --for _, o in pairs(out) do
        --    print('\tcoeff = ' .. o.coeff .. '  power = ' .. o.power)
        --end
        end
        --print('----------- CALC ----------------')
        return out
    end
    --print('------------ no calc -------------')
    return {{['coeff'] = 1, ['power'] = 1}}
end

function solve(trs, inter)
    local problems = 0
    for _, t in pairs(trs) do
        if not compare(calc(t.left, inter), calc(t.right, inter)) then
            print('The rule ' .. answ_str(t.left) .. ' = ' .. answ_str(t.right) .. ' does not decrease')
            problems = problems + 1
        end
    end
    if problems == 0 then
        print('All rules are decreasing')
    end
end

function main()
    print('\n\n')

    local trs = getInput('TRS.txt')
    --for _, t in ipairs(trs) do
    --    print(t)
    --end
    local inter = getInput('interpretation.txt')
    --for _, t in ipairs(inter) do
    --    print(t)
    --end

    trs = parseTrs(trs)

    inter = parseInter(inter)

    solve(trs, inter)

    print('\n')
end

main()