#include <iostream>
#include <vector>

using namespace std;

struct Rule_body {
    string pre;
    string post;
};

struct Rule {
    string head;
    vector<Rule_body> bodies;
};

struct Conflict {
    vector<Rule> sides;
    int resolved;
    bool done;
};

struct State {
    int id;
    vector<Rule> roots;
    vector<Rule> rules;
};

struct Shift {
    string value;
    int fr;
    int to;
};

struct Follow {
    string head;
    vector<string> bodies;
};

struct LR {
    vector<State> states;
    vector<Shift> shifts;
    int id;
};

struct Solution {
    vector<Conflict> confs;
    bool ok;
};

string del_whitespaces(string rule) {
    string new_rule;
    for (int i = 0 ; i < size(rule) ; i++) {
        if (rule[i] != ' ' && rule[i] != '\t' && rule[i] != '\r' && rule[i] != '\n') {
            new_rule += rule[i];
        }
    }
    return new_rule;
}

vector<Rule> append_rule(vector<Rule> output, string head, vector<Rule_body> bodies) {
    for (int i = 0 ; i < size(output) ; i++) {
        if (output[i].head == head) {
            for (Rule_body b : bodies) {
                output[i].bodies.push_back(b);
            }
            return output;
        }
    }
    Rule n_r;
    n_r.head = head;
    n_r.bodies = bodies;
    output.push_back(n_r);
    return output;
}

vector<Rule> parse_rules(vector<string> rules) {
    vector<Rule> output;
    for (int i = 0 ; i < size(rules) ; i++) {
        int j = 1;
        string new_head;
        while (j < size(rules[i]) && rules[i][j] != ']') {
            new_head += rules[i][j];
            j++;
        }
        j += 3;
        vector<string> bodies;
        string new_body;
        while (j < size(rules[i])) {
            if (rules[i][j] == '|') {
                bodies.push_back(new_body);
                new_body = "";
                j += 1;
                continue;
            }
            new_body += rules[i][j];
            j += 1;
        }
        bodies.push_back(new_body);
        vector<Rule_body> new_bodies;
        for (string b : bodies) {
            Rule_body n_b;
            n_b.pre = "";
            n_b.post = '.' + b + '$';
            new_bodies.push_back(n_b);
        }
        output = append_rule(output, new_head, new_bodies);
    }
    return output;
}

string rule_to_string(Rule rule) {
    string out = '[' + rule.head + "] -> ";
    for (Rule_body b : rule.bodies) {
        out += b.pre + (b.post).substr(0, size(b.post) - 1) + " | ";
    }
    out = out.substr(0, size(out) - 3);
    return out;
}

vector<Rule> filter_rules(vector<Rule> rules) {
    vector<Rule> new_rules;
    for (Rule r : rules) {
        new_rules = append_rule(new_rules, r.head, r.bodies);
    }
    return new_rules;
}

bool contained(string head, vector<string> heads) {
    for (string h : heads) {
        if (h == head) return true;
    }
    return false;
}

bool present(Rule_body a, vector<Rule_body> b) {
    for (Rule_body bb : b) {
        if (a.pre == bb.pre && a.post == bb.post) return true;
    }
    return false;
}

vector<Rule> formalize_roots(vector<Rule> roots) {
    vector<Rule> new_roots;
    for (Rule r : roots) {
        string head = r.head;
        bool done = false;
        for (Rule r1 : new_roots) {
            if (r1.head == head) {
                done = true;
                for (Rule_body b : r.bodies) {
                    if (!present(b, r1.bodies)) {
                        r1.bodies.push_back(b);
                    }
                }
            }
        }
        if (!done) {
            Rule rr;
            rr.head = head;
            rr.bodies = r.bodies;
            new_roots.push_back(r);
        }
    }
    return new_roots;
}

bool same_roots(vector<Rule> roots, vector<Rule> state) {
    int yes = 0;
    for (Rule r : roots) {
        for (Rule s : state) {
            if (rule_to_string(r) == rule_to_string(s)) yes++;
        }
    }
    if (yes == size(roots) && yes == size(state)) return true;
    return false;
}

bool in_body(Rule_body b, vector<Rule_body> bodies) {
    for (Rule_body bb : bodies) {
        if (b.pre == bb.pre && b.post == bb.post) return true;
    }
    return false;
}

vector<Rule> append_r(vector<Rule> out, string head, vector<Rule_body> bodies) {
    for (Rule r : out) {
        if (r.head == head) {
            for (Rule_body b : bodies) {
                if (!in_body(b, r.bodies)) {
                    r.bodies.push_back(b);
                }
            }
            return out;
        }
    }
    Rule n_r;
    n_r.head = head;
    n_r.bodies = bodies;
    out.push_back(n_r);
    return out;
}

LR build_LR(vector<Rule> rules, vector<Rule> roots, vector<State> states, vector<Shift> shifts, int id) {
    vector<Rule> state_rules;
    vector<string> exits;
    for (Rule root : roots) {
        for (Rule_body body : root.bodies) {
            string term;
            if (body.post[1] != '$') {
                if (body.post[1] == '[') {
                    int i = 2;
                    while (body.post[i] != ']') {
                        term += body.post[i];
                        i += 1;
                    }
                }
                else term += body.post[1];
                if (!contained(term, exits)) exits.push_back(term);
            }
            else if (size(body.pre) == 0) {
                if (!contained(term, exits)) exits.push_back(term);
            }
        }
    }
    int j = 0;
    while (j < size(rules)) {
        if (contained(rules[j].head, exits)) {
            state_rules = append_r(state_rules, rules[j].head, rules[j].bodies);
            bool reset = false;
            for (Rule_body body : rules[j].bodies) {
                string term;
                if (body.post[1] != '$') {
                    if (body.post[1] == '[') {
                        int i = 2;
                        while (body.post[i] != ']') {
                            term += body.post[i];
                            i += 1;
                        }
                    }
                    else term += body.post[1];
                    if (!contained(term, exits)) {
                        exits.push_back(term);
                        j = 0;
                        reset = true;
                    }
                }
                else if (size(body.pre) == 0) {
                    if (!contained(term, exits)) exits.push_back(term);
                }
            }
            if (reset) continue;
        }
        j++;
    }
    State new_state;
    new_state.roots = roots;
    new_state.id = id;
    for (Rule rule : state_rules) {
        roots.push_back(rule);
    }
    id++;
    new_state.rules = roots;
    states.push_back(new_state);
    for (string exit : exits) {
        if (!exit.empty()) {
            vector<Rule> new_roots;
            for (Rule rule : roots) {
                for (Rule_body body : rule.bodies) {
                    if (body.post[1] != '$') {
                        bool affected = true;
                        if (body.post[1] == '[') {
                            int i = 2;
                            string cur_ex;
                            while (body.post[i] != ']') {
                                cur_ex += body.post[i];
                                i += 1;
                            }
                            if (exit != cur_ex) affected = false;
                        }
                        else {
                            if (body.post[1] != exit[0]) affected = false;
                        }
                        if (affected) {
                            if (body.post[1] == '[') {
                                int j = 1;
                                while (body.post[j - 1] != ']') j++;
                                vector<Rule_body> temp_bodies;
                                Rule_body temp_body;
                                temp_body.pre = body.pre + body.post.substr(1, j - 1);
                                temp_body.post = "." + body.post.substr(j, size(body.post));
                                temp_bodies.push_back(temp_body);
                                Rule temp_rule;
                                temp_rule.head = rule.head;
                                temp_rule.bodies = temp_bodies;
                                new_roots.push_back(temp_rule);
                            }
                            else {
                                vector<Rule_body> temp_bodies;
                                Rule_body temp_body;
                                temp_body.pre = body.pre + body.post[1];
                                temp_body.post = "." + body.post.substr(2, size(body.post));
                                temp_bodies.push_back(temp_body);
                                Rule temp_rule;
                                temp_rule.head = rule.head;
                                temp_rule.bodies = temp_bodies;
                                new_roots.push_back(temp_rule);
                            }
                        }
                    }
                }
            }
            int new_to = id;
            bool loop = false;
            new_roots = filter_rules(new_roots);
            for (State state : states) {
                if (same_roots(new_roots, state.roots)) {
                    new_to = state.id;
                    loop = true;
                    break;
                }
            }
            if (!loop) {
                new_roots = filter_rules(new_roots);
                Shift new_shift;
                new_shift.value = exit;
                new_shift.fr = new_state.id;
                new_shift.to = id;
                shifts.push_back(new_shift);
                LR temp_LR = build_LR(rules, formalize_roots(new_roots), states, shifts, id);
                states = temp_LR.states;
                shifts = temp_LR.shifts;
                id = temp_LR.id;
                continue;
            }
            else {
                Shift new_shift;
                new_shift.value = exit;
                new_shift.fr = new_state.id;
                new_shift.to = new_to;
                shifts.push_back(new_shift);
                continue;
            }
        }
    }
    LR temp_LR;
    temp_LR.states = states;
    temp_LR.shifts = shifts;
    temp_LR.id = id;
    return temp_LR;
}

Rule get_rule(vector<Rule> rules, string head) {
    for (Rule rule : rules) {
        if (rule.head == head) {
            return rule;
        }
    }
    Rule v;
    return v;
}

vector<string> first_k(vector<Rule> rules, Rule rule, int k, int have1, int cycle, vector<string> seen) {
    vector<string> out;
    int j = 0;
    while (j < size(rule.bodies)) {
        Rule_body body = rule.bodies[j];
        //cout << "looking at " << body.pre << body.post << endl;
        int have = have1;
        string n_char;
        bool terminal = true;
        int i = 1;
        int danger = 0;
        while (body.post[i] != '$' && i - 1 < k) {
            if (body.post[i] == '[') {
                if (i == 1) danger = 1;
                terminal = false;
                i += 1;
                string cha;
                while (body.post[i] != ']') {
                    cha += body.post[i];
                    i++;
                }
                i++;
                Rule new_rule = get_rule(rules, cha);
                //cout << "will get firsts from " << rule_to_string(new_rule) << endl;
                if (contained(new_rule.head, seen) && danger == 1) {
                    danger = 2;
                    cycle++;
                }
                if ((!contained(new_rule.head, seen) || have < k) && (danger != 2 || cycle <= k)) {
                    seen.push_back(rule.head);
                    vector<string> pref = first_k(rules, new_rule, k, have, cycle, seen);
                    //cout << rule_to_string(new_rule) << " returned: " << endl;
                    //for (string s : pref) {
                    //  cout << s << endl;
                    //}
                    for (string p : pref) {
                        Rule_body b;
                        b.pre = body.pre;
                        b.post = "." + n_char + p + body.post.substr(i, size(body.post) - i);
                        rule.bodies.push_back(b);
                    }
                    break;
                }
            }
            else {
                n_char += body.post[i];
                have += 1;
                i++;
            }
        }
        if (terminal) {
            if (!contained(n_char, out)) {
                out.push_back(n_char);
            }
        }
        j++;
    }
    return out;
}

vector<Follow> append_follow(string head, vector<string> follows, vector<Follow> out) {
    for (Follow p : out) {
        if (p.head == head) {
            for (string f : follows) {
                if (!contained(f, p.bodies)) p.bodies.push_back(f);
            }
            return out;
        }
    }
    Follow new_follow;
    new_follow.head = head;
    new_follow.bodies = follows;
    out.push_back(new_follow);
    return out;
}

vector<Follow> append_follows(string to_head, string from_head, vector<Follow> out, int k) {
    for (Follow p : out) {
        if (p.head == to_head) {
            for (Follow p1 : out) {
                if (p1.head == from_head) {
                    vector<string> new_bodies;
                    for (string b : p.bodies) {
                        for (string b1 : p1.bodies) {
                            string new_body;
                            int i = 0;
                            while (i < k && i < size(b)) {
                                new_body += b[i];
                                i++;
                            }
                            int j = 0;
                            while (i + j < k && j < size(b1)) {
                                new_body += b1[j];
                                j += 1;
                            }
                            new_body += '$';
                            if (!contained(new_body, new_bodies)) new_bodies.push_back(new_body);
                        }
                    }
                    p.bodies = new_bodies;
                    break;
                }
            }
        }
    }
    return out;
}

bool full(vector<Follow> out, string head, int k) {
    for (Follow o : out) {
        if(o.head == head) {
            for (string body : o.bodies) {
                if (size(body) < k) {
                    bool passed = false;
                    int i = 0;
                    while (i < size(body)) {
                        if (body[i] == '$') passed = true;
                        i += 1;
                    }
                    if (!passed) return false;
                }
            }
        }
    }
    return true;
}

vector<Follow> follow_k(vector<Rule> rules, int k) {
    vector<Follow> out;
    Follow S;
    S.head = "S";
    S.bodies.push_back("$");
    out.push_back(S);
    S.head = "#";
    S.bodies.push_back("$");
    out.push_back(S);
    for (Rule rule : rules) {
        for (Rule r : rules) {
            for (Rule_body body : r.bodies) {
                int i = 1;
                while (body.post[i] != '$') {
                    int danger = 0;
                    if (body.post[i] == '[') {
                        danger = i;
                        string new_head;
                        i++;
                        while (body.post[i] != ']') {
                            new_head += body.post[i];
                            i++;
                        }
                        Rule n_r;
                        n_r.head = r.head;
                        Rule_body n_r_b;
                        n_r_b.pre = "";
                        n_r_b.post = body.post.substr(i, size(body.post) - i);
                        n_r.bodies.push_back(n_r_b);
                        out = append_follow(new_head, first_k(rules, n_r, k, 0, 0, vector<string> {rule.head}), out);
                        continue;
                    }
                    i++;
                }
            }
        }
    }
    for (Rule rule : rules) {
        for (Rule_body body : rule.bodies) {
            int i = 1;
            while (body.post[i] != '$') {
                if (body.post[i] == '[') {
                    string new_head;
                    i++;
                    while (body.post[i] != ']') {
                        new_head += body.post[i];
                        i++;
                    }
                    i++;
                    if (rule.head != new_head || !full(out, rule.head, k)) out = append_follows(new_head, rule.head, out, k);
                    continue;
                }
                i++;
            }
        }
    }
    return out;
}

vector<Follow> filter (vector<Follow> follows, int k) {
    vector<Follow> new_follows;
    for (Follow follow : follows) {
        if (follow.head == "S") {
            new_follows.push_back(follow);
            continue;
        }
        Follow new_follow;
        new_follow.head = follow.head;
        vector<string> new_bodies;
        for (string body : follow.bodies) {
            int i = 0;
            string new_body;
            while (i < k && i < size(body) && body[i] != '$') {
                new_body += body[i];
                i++;
            }
            new_body += '$';
            if (!contained(new_body, new_bodies)) new_bodies.push_back(new_body);
        }
        new_follow.bodies = new_bodies;
        new_follows.push_back(new_follow);
    }
    return new_follows;
}

vector<Rule> collect_roots(State state) {
    vector<Rule> roots;
    for (Rule root : state.rules) {
        for (Rule_body body : root.bodies) {
            Rule new_rule;
            new_rule.head = root.head;
            vector<Rule_body> bodies;
            bodies.push_back(body);
            new_rule.bodies = bodies;
            roots.push_back(new_rule);
        }
    }
    return roots;
}

vector<Conflict> get_conflicts(vector<State> states) {
    vector<Conflict> conflicts;
    for (State state : states) {
        if (size(state.rules) > 1 || size(state.rules[0].bodies) > 1) {
            for (Rule root : state.rules) {
                for (Rule_body body : root.bodies) {
                    if (body.post[1] == '$') {
                        vector<Rule> new_conflict = collect_roots(state);
                        Conflict conf;
                        conf.sides = new_conflict;
                        conf.resolved = -1;
                        conf.done = false;
                        conflicts.push_back(conf);
                    }
                }
            }
        }
    }
    return conflicts;
}

vector<string> get_follows(vector<Follow> follows, string head) {
    for (Follow follow : follows) {
        if (follow.head == head) {
            return follow.bodies;
        }
    }
    vector<string> v;
    return v;
}

vector<string> filter_strs(vector<string> list, int k) {
    vector<string> new_list;
    for (string l : list) {
        string new_l;
        int i = 0;
        while (i < k && l[i] != '$') {
            new_l += l[i];
            i += 1;
        }
        new_list.push_back(new_l);
    }
    return new_list;
}

int equal(vector<string> f1, vector<string> f2) {
    for (string f : f1) {
        bool danger = true;
        for (string ff : f2) {
            if (f == ff) danger = false;
        }
        if (danger) return 0;
    }
    for (string f : f2) {
        bool danger = true;
        for (string ff : f1) {
            if (f == ff) danger = false;
        }
        if (danger) return 0;
    }
    return 1;
}

int intersect(vector<string> f1, vector<string> f2) {
    for (string f : f1) {
        for (string ff : f2) {
            if (f == ff) return 1;
        }
    }
    return 0;
}

Solution resolve(vector<Rule> rules, vector<Follow> follows, vector<Conflict> conflicts, int k) {
    bool ok = true;
    for (int jj = 0 ; jj < size(conflicts) ; jj++) {
        Conflict conflict = conflicts[jj];
        vector<vector<string>> comp;
        for (Rule side : conflict.sides) {
            string head = side.head;
            for (Rule_body body : side.bodies) {
                if (body.post[1] == '$') {
                    vector<string> cands;
                    vector<string> temp = get_follows(follows, head);
                    for (string f1 : temp) {
                        if (!contained(f1, cands)) cands.push_back(f1);
                    }
                    cands = filter_strs(cands, k);
                    comp.push_back(cands);
                }
                else {
                    vector<string> firsts = first_k(rules, side, k, 0, 0, vector<string> {side.head});
                    vector<string> cands;
                    for (string f : firsts) {
                        vector<string> temp = get_follows(follows, head);
                        for (string f1 : temp) {
                            if (!contained(f + f1, cands)) cands.push_back(f + f1);
                        }
                        cands = filter_strs(cands, k);
                        comp.push_back(cands);
                    }
                }
            }
        }
        int equality = 0;
        int intersection = 0;
        for (int i = 0 ; i < size(comp) ; i++) {
            for (int j = i + 1 ; j < size(comp); j++) {
                equality += equal(comp[i], comp[j]);
                intersection += intersect(comp[i], comp[j]);
            }
        }
        if (intersection == 0) {
            if (!conflict.done) conflict.resolved = k;
            conflict.done = true;
            conflicts[jj] = conflict;
        } else if (equality == size(comp)) {
            conflict.resolved = k;
            ok = false;
            conflicts[jj] = conflict;
            continue;
        } else {
            conflict.resolved = -1;
            conflict.done = false;
            ok = false;
            conflicts[jj] = conflict;
        }
    }
    Solution out;
    out.confs = conflicts;
    out.ok = ok;
    return out;
}

int main() {
    vector<Rule> rules;
    vector<string> str_rules;
    string n_str;
    string inp;
    getline(cin, n_str);
    while (true) {
        getline(cin, inp);
        if (inp.empty()) {
            break;
        }
        str_rules.push_back(inp);
    }
    for (int i = 0 ; i < size(str_rules) ; i++) {
        str_rules[i] = del_whitespaces(str_rules[i]);
    }
    rules = parse_rules(str_rules);

    vector<Shift> shifts;
    vector<State> states;
    Rule_body starter_body;
    starter_body.pre = "";
    starter_body.post = ".[S]$";
    vector<Rule_body> starter_bodies;
    starter_bodies.push_back(starter_body);
    Rule starter;
    starter.head = "#";
    starter.bodies = starter_bodies;
    vector<Rule> starter_rules;
    starter_rules.push_back(starter);
    LR SLR = build_LR(rules, starter_rules, states, shifts, 1);
    states = SLR.states;
    shifts = SLR.shifts;

    rules.push_back(starter);
    vector<Conflict> conflicts = get_conflicts(states);
    for (int i = 1; i < 1 + stoi(n_str); i++) {
        vector<Follow> follows = filter(follow_k(rules, i), i);
        Solution sln = resolve(rules, follows, conflicts, i);
        conflicts = sln.confs;
        if (sln.ok) break;
    }

    int happy = 0;
    for (Conflict conflict : conflicts) {
        cout << "Conflict between" << endl;
        for (Rule side : conflict.sides) cout << '\t' << rule_to_string(side) << endl;
        if (conflict.done) {
            cout << "resolved when k = " << conflict.resolved << endl;
            happy++;
        } else if (conflict.resolved != -1) cout << "in a suspended state when k = " << conflict.resolved << endl;
        else cout << "was not resolved when k = " << stoi(n_str) << endl;
        cout << endl;
    }
    if (size(conflicts) == happy) cout << "There are no conflicts (or all have been resolved)" << endl;
    return 0;
}
