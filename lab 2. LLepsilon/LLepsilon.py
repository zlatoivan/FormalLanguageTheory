f = open("Gram.txt", "r")
lls = f.read()

class Rule:
    def __init__(self, head, bodies):
        self.head = head
        self.bodies = bodies

class Counter:
    def __init__(self, value, seen):
        self.value = value
        self.seen = 1

def sep_lls(lls):
    out = []
    o = ""
    for c in lls:
        if c == "\n":
            out.append(o)
            o = ""
            continue
        if c != " ":
            o += c
    return out

def parse_rules(strs):
    out = []
    for str in strs:
        head = ""
        body = ""
        bodies = []
        i = 0
        if str[i] != '[':
            print("Error 1")
            exit()
        i += 1
        while i < len(str) and str[i] != ']':
            head += str[i]
            i += 1
        if i == len(str):
            print("Error 2")
            exit()
        i += 1
        if str[i] != '-':
            print("Error 3")
            exit()
        i += 1
        if str[i] != '>':
            print("Error 4")
            exit()
        i += 1
        while i < len(str):
            if str[i] == '|':
                if body == "":
                    body = "$"
                bodies.append(body)
                body = ""
                i += 1
                continue
            body += str[i]
            i += 1
        if body == "":
            body = "$"
        bodies.append(body)
        out.append(Rule(head, bodies))
    return out

def inside(obj, list):
    for l in list:
        if l == obj:
            return True
    return False

def insert_rule(rule, out, roots):
    head = rule.head
    new_bodies = []
    for body in rule.bodies:
        seen = True
        i = 0
        nterm = ""
        while i < len(body):
            if body[i] == '[':
                i += 1
                while body[i] != ']':
                    nterm += body[i]
                    i += 1
                if not inside(nterm, roots):
                    seen = False
                nterm = ""
                i += 1
                continue
            i += 1
        if seen:
            new_bodies.append(body)
    if len(new_bodies) > 0:
        out.append(Rule(head, new_bodies))
    return out

def filter_rules(filtered):

    roots = []
    for rule in filtered:
        final = False
        for body in rule.bodies:
            i = 0
            while i < len(body):
                if body[i] == '[':
                    while body[i] != ']':
                        i += 1
                    i += 1
                    continue
                final = True
                i += 1
        if not final:
            roots.append(rule.head)
    changed = True
    while changed:
        changed = False
        for rule in filtered:
            candidate = 0
            for body in rule.bodies:
                allroots = True
                i = 0
                head = ""
                while i < len(body):
                    if body[i] == '[':
                        i += 1
                        while body[i] != ']':
                            head += body[i]
                            i += 1
                        if not inside(head, roots):
                            allroots = False
                        i += 1
                        continue
                    i += 1
                if allroots:
                    candidate += 1
            if candidate > 0:
                if not inside(rule.head, roots):
                    roots.append(rule.head)
                    changed = True
    rules = []
    for rule in filtered:
        rules = insert_rule(rule, rules, roots)

    seen = ["S"]
    changed = True
    while changed:
        changed = False
        for rule in rules:
            if inside(rule.head, seen):
                for body in rule.bodies:
                    i = 0
                    nterm = ""
                    while i < len(body):
                        if body[i] == '[':
                            i += 1
                            while body[i] != ']':
                                nterm += body[i]
                                i += 1
                            if not inside(nterm, seen):
                                changed = True
                                seen.append(nterm)
                            nterm = ""
                            i += 1
                            continue
                        i += 1
    filtered = []
    for rule in rules:
        if inside(rule.head, seen):
            filtered.append(rule)

    return filtered

def print_rules(rules):
    for rule in rules:
        out = "[" + rule.head + "] -> "
        for body in rule.bodies:
            out += body + " | "
        out = out[: -3]
        print(out)

rules = filter_rules(parse_rules(sep_lls(lls)))
print("После удаления мусора:")
print_rules(rules)
print("----------------------------")

def del_eps(rules):
    epsed = []
    changed = True
    while changed:
        changed = False
        for rule in rules:
            for body in rule.bodies:
                if body == "$":
                    if not inside(rule.head, epsed):
                        epsed.append(rule.head)
                        changed = True
                else:
                    death = True
                    nt = False
                    i = 0
                    nterm = ""
                    while i < len(body):
                        if body[i] == '[':
                            nt = True
                            i += 1
                            while body[i] != ']':
                                nterm += body[i]
                                i += 1
                            if not inside(nterm, epsed):
                                death = False
                            nterm = ""
                            i += 1
                            continue
                        i += 1
                    if death and nt:
                        if not inside(rule.head, epsed):
                            changed = True
                            epsed.append(rule.head)
    out = []
    for rule in rules:
        new_bodies = []
        for body in rule.bodies:
            if body != "$":
                new_bodies.append(body)
        changed = True
        while changed:
            changed = False
            for body in new_bodies:
                for e in epsed:
                    modified = True
                    seen = 0
                    while modified:
                        modified = False
                        i = 0
                        nterm = ""
                        new_body = ""
                        skip = seen
                        while i < len(body):
                            if body[i] == '[':
                                i += 1
                                while body[i] != ']':
                                    nterm += body[i]
                                    i += 1
                                if nterm == e:
                                    if skip != 0:
                                        new_body += "[" + nterm + "]"
                                    else:
                                        modified = True
                                        seen += 1
                                    skip -= 1
                                else:
                                    new_body += "[" + nterm + "]"
                                i += 1
                                nterm = ""
                                continue
                            new_body += body[i]
                            i += 1
                        if new_body != "" and not inside(new_body, new_bodies):
                            changed = True
                            new_bodies.append(new_body)
        out.append(Rule(rule.head, new_bodies))
    return out

out = del_eps(rules)
print_rules(out)
