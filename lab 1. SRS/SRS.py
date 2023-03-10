f = open("TRS.txt", "r")
trs = f.read()

f = open("interpretation.txt", "r")
inter = f.read()

class Term:
    def __init__(self, func, value):
        self.func = func
        self.value = value
        self.child = None

class Rule:
    def __init__(self, left, right):
        self.left = left
        self.right = right

class Expr:
    def __init__(self):
        self.coeff = 1
        self.sign = 1
        self.power = 0

class Interpretation:
    def __init__(self, head, expr):
        self.head = head
        self.expr = expr

class Num:
    def __init__(self, coeff, power):
        self.coeff = coeff
        self.power = power

class Polynom:
    def __init__(self):
        self.exp = []

def sep_trs(trs):
    out = []
    o = ""
    for i in trs:
        if i != '\n':
            if i != ' ':
                o += i
        else:
            out.append(o)
            o = ""
    return out

def parse_left_trs(t, i):
    out = Term(0, 'x')
    head = ""
    while i < len(t) and t[i] != '=':
        if t[i] == '(':
            out.func = 1
            out.value = head
            out.child, i = parse_left_trs(t, i + 1)
            return out, i + 1
        if t[i] == ')':
            if head != 'x':
                print("Синтаксическая ошибка в TRS: x - не самый вложенный элемент")
                exit()
            return out, i
        print('HEAD = ', head, '->', head + t[i])
        head += t[i]
        i += 1
    if i == len(t):
        print("Синтаксическая ошибка в TRS: в выражении отсутствует левая часть")
        exit()
    return out, i

def parse_right_trs(t, i):
    out = Term(0, 'x')
    head = ""
    while i < len(t):
        if t[i] == '(':
            out.value = head
            out.func = 1
            out.child, i = parse_right_trs(t, i + 1)
            return out, i + 1
        if t[i] == ')':
            if head != 'x':
                print("Синтаксическая ошибка в TRS: x - не самый вложенный элемент")
                exit()
            return out, i
        head += t[i]
        i += 1
    if i == len(t):
        print("Синтаксическая ошибка в TRS: в выражении отсутствует правая часть")
        exit()
    return out, i

def parse_trs(trs):
    out = []
    for t in trs:
        print('---------------------------------------')
        print(t)
        left, i = parse_left_trs(t, 0)
        print(
            'func = ', left.func, '\n' +
            'value = ', left.value, '\n',
            '\tchild = ', left.child.func, '\n',
            '\tchild = ', left.child.value, '\n',
            '\t\tchild = ', left.child.child.func, '\n',
            '\t\tchild = ', left.child.child.value, '\n\n',
        )
        if t[i] != '=':
            print("Синтаксическая ошибка в TRS: в выражении отсутствует =")
            exit()
        right, _ = parse_right_trs(t, i + 1)
        out.append(Rule(left, right))
    return out

trs = parse_trs(sep_trs(trs))

def parse_expr(expr, i):
    out = Polynom()
    sign = 1
    coefficient = 1
    o = Expr()
    while i < len(expr):
        while expr[i] != 'x':
            if expr[i] != '-' and expr[i] != '+':
                coeff = ""
                while expr[i] != '*':
                    coeff += expr[i]
                    i += 1
                coefficient = int(coeff)
            if expr[i] == '-':
                sign *= -1
            i += 1
        if i + 1 < len(expr) and expr[i + 1] == '^':
            i += 2
            num = ""
            while i < len(expr) and expr[i] != '-' and expr[i] != '+':
                num += expr[i]
                i += 1
            num = int(num)
            o.coeff = coefficient
            o.sign = sign
            o.power = num
            out.exp.append(o)
            o = Expr()
        else:
            o.coeff = coefficient
            o.sign = sign
            o.power = 1
            out.exp.append(o)
            o = Expr()
            i += 1
        sign = 1
        coefficient = 1
    return out

def parse_inter(inter):
    out = []
    for t in inter:
        head = ""
        i = 0
        while i < len(t) and t[i] != '-':
            head += t[i]
            i += 1
        if i == len(t):
            print("Синтаксическая ошибка в интерпретации: в интерпретации отсутствует правая часть")
            exit()
        i += 1
        if t[i] != '>':
            print("Синтаксическая ошибка в интерпретации: знак разделения не равен ->")
            exit()
        i += 1
        expr = parse_expr(t, i)
        out.append(Interpretation(head, expr))
    return out

def print_inter(inter):
    print(inter.head, inter.expr.sign, inter.expr.coeff, inter.expr.power)

inter = parse_inter(sep_trs(inter))

def answ_str(t):
    return t.value + ('(' + answ_str(t.child) + ')' if t.value != 'x' else '')

def subtract(left, right):
    for r in right:
        saw = 0
        for l in left:
            if l.power == r.power:
                saw = 1
                l.coeff -= r.coeff
        if saw == 0:
            left.append(Num(-1 * r.coeff, r.power))
    return left

def compare(left, right):
    sub = subtract(left, right)
    min = 0
    coeff = 0
    for s in sub:
        if s.power > min and s.coeff != 0:
            min = s.power
            coeff = s.coeff
    if coeff < 0:
        return False
    return True

# заменяет название функции на ее содержимое
def get_parts(value, inter):
    for i in inter:
        if i.head == value:
            return i.expr.exp
    return []

# складывает подобные слагаемые
def append_Num(psign, pcoeff, ncoeff, npower, out):
    for o in out:
        if o.power == npower:
            o.coeff += psign * pcoeff * ncoeff
            return out
    out.append(Num(psign * pcoeff * ncoeff, npower))
    return out

# вспомогат.; раскрывает скобки по правилу (a+b)^2 = aa+ab+ba+bb
def up_Num(pcoeff, ppower, ncoeff, npower, out):
    print("(", pcoeff, "* x ^", ppower, ") * (", ncoeff, "* x ^", npower, ")")
    for o in out:
        if o.power == ppower + npower:
            o.coeff += pcoeff * ncoeff
            return out
    out.append(Num(pcoeff * ncoeff, ppower + npower))
    return out

# возводит скобку в степень
def powerup(child, up, power):
    out = []
    if power > 1:
        for n in child:
            # print('NNN = ', n)
            for nn in up:
                out = up_Num(n.coeff, n.power, nn.coeff, nn.power, out)
        return powerup(child, out, power - 1)
    return up


def calc(side, inter):
    print('-----------------------------------------------')
    if side.child is not None:
        print(side.value, ' (side.value)')

        parts = get_parts(side.value, inter)
        # print('parts:')
        # for p in parts:
        #     print('\tcoeff = ', p.coeff, 'sign = ', p.sign, 'power = ', p.power)

        child = calc(side.child, inter)
        # print(side.child.value, ' (side.child.value)')
        # print('calc:')
        # for c in child:
        #     print('\tcoeff = ', c.coeff, 'power = ', c.power)

        out = []
        for p in parts:
            # print('\n***** for parts ***********')
            nchild = powerup(child, child, p.power)
            print('nchild:')
            for c in nchild:
                print('\tcoeff = ', c.coeff, 'power = ', c.power)

            for n in nchild:
                out = append_Num(p.sign, p.coeff, n.coeff, n.power, out)
            print('out:')
            for o in out:
                print('\tcoeff = ', o.coeff, 'power = ', o.power)

        # print('#################\n')
        print('-------- new calc ---------------------\n')
        return out
    print('-------calc = 1,1 ----------------------\n')
    return [Num(1, 1)]

problems = 0
for t in trs:
    if not compare(calc(t.left, inter), calc(t.right, inter)):
        print("Правило", answ_str(t.left), '=', answ_str(t.right), "не убывает")
        problems += 1
if problems == 0:
    print("Все правила убывают")

print('\n\n\n')
calc(trs[0].left, inter)