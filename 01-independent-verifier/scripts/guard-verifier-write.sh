#!/usr/bin/env bash
# PreToolUse hook; exit 2 blocks. The verifier writes
# only .verdicts/ and temp dirs; the main agent never
# writes .verdicts/. Subagent calls carry agent_id and
# agent_type; the verifier is known by agent_type.
IN=$(cat)
read -r -d '' PY <<'EOF2'
import json, os, re, shlex, sys, tempfile
d = json.load(sys.stdin)
who = d.get("agent_type") or "" if d.get("agent_id") else ""
is_v = who == "verifier"
ti, tool = d.get("tool_input") or {}, d.get("tool_name")
env = os.environ.get("CLAUDE_PROJECT_DIR")
root = os.path.realpath(env or d.get("cwd") or ".")
base = d.get("cwd") or root
HID = re.compile(r"\$[{\w(]|`|(^|/)~")  # $VAR, ~
R = os.path.realpath
def under(p, *dirs):
    q = R(os.path.join(base, p)) + os.sep
    return any(q.startswith(R(x) + os.sep) for x in dirs)
V = os.path.join(root, ".verdicts")
def ok(p):  # inside .verdicts/
    return under(p, V)
def bad_v(p):  # not a place the verifier may write
    if HID.search(p): return True  # can't see it
    if under(p, root): return not ok(p)
    return not under(p, tempfile.gettempdir(), "/tmp")
def deny(why):
    w = who or "main agent"
    sys.stderr.write("BLOCKED (%s): %s\n" % (w, why))
    sys.exit(2)
W = set("rm mv cp tee touch mkdir truncate install dd "
        "chmod ln patch".split())
G = set("commit checkout reset stash add restore clean "
        "merge rebase apply switch push pull rm mv "
        "cherry-pick revert am update-ref".split())
PRE = set("sudo command env xargs nice nohup time "
          "! { do then else if elif while until".split())
OPS, SKIP = "();<>|&\n", ("-", "/dev/null")
def body(cmd):  # drop heredoc bodies
    out, ends = [], []
    for ln in cmd.split("\n"):
        if ends:
            if ln.strip() == ends[0]: ends.pop(0)
            continue
        out.append(ln)
        ends += [m[1] for m in re.findall(
            r"(?<!<)<<-?\s*(['\"]?)(\w+)\1", ln)]
    return "\n".join(out)
def words(cmd):  # a quoted > stays inside its word
    src = body(cmd).replace("\\\n", "")  # joined lines
    src = re.sub(r"(?<=\S)#", "\x01", src)  # in-word #
    s = shlex.shlex(src, posix=True,
                    punctuation_chars=OPS)
    s.whitespace, s.whitespace_split = " \t\r", True
    try: return [w.replace("\x01", "#") for w in s]
    except ValueError: return cmd.split()
def one(t, cur, out):  # one simple command
    while t and ("=" in t[0] or t[0] in PRE):
        t = t[1:]
    if not t: return cur
    c, a = t[0], [x for x in t[1:] if x[:1] != "-"]
    J = lambda xs: out.extend(os.path.join(cur, x)
                              for x in xs)
    if c == "cd":
        nd = os.path.join(cur, a[0]) if a else root
        ok_cd = HID.search(nd) or os.path.isdir(nd)
        return nd if ok_cd else cur  # a failed cd stays
    if c in ("cp", "ln", "install"):
        to = [t[k + 1] for k in range(len(t) - 1)
              if t[k] == "-t"]
        J(to or a[-1:])  # only the destination
    elif c == "sed":
        if any(re.match(r"-[A-Za-z]*i|--in-place", x)
               for x in t):
            e = any(x in ("-e", "-f") or x[:6] in
                    ("--expr", "--file") for x in t)
            fs = [x for x in a if x]  # drop BSD -i ''
            fs = fs if e else fs[1:]  # [0]: the script
            fs = [os.path.join(cur, x) for x in fs]
            out.extend(x for x in fs if HID.search(x)
                       or os.path.isfile(x))
    elif c == "dd":
        J([x[3:] for x in t if x[:3] == "of="])
    elif c in W:
        J(a or ["?"])
    elif c == "git":
        k = 1
        while k < len(t) and t[k][:1] == "-":
            k += 2 if t[k] in ("-C", "-c") else 1
        if k < len(t) and t[k] in G: J(["?"])
    return cur
def targets(cmd):  # paths a command may write
    ws = []
    for w in words(cmd) + [";"]:
        if w and all(ch in OPS for ch in w):
            ws += re.findall(r"&>>|&>|>&|>>|>\||&&|\|\|"
                             r"|<<<|<<|[;()|&<>\n]", w)
        else:
            ws.append(w)
    out, cur, t = [], base, []
    st = []  # cd inside ( ) ends with the subshell
    i = 0
    while i < len(ws):
        w, i = ws[i], i + 1
        op = w != "" and all(ch in OPS for ch in w)
        if op and ">" in w:  # redirect: next word
            n, i = (ws[i] if i < len(ws) else ""), i + 1
            if t and t[-1].isdigit(): t.pop()
            if not n.isdigit() and n not in SKIP:
                out.append(os.path.join(cur, n))
        elif op:  # end of one command
            cur, t = one(t, cur, out), []
            for ch in w:
                if ch == "(": st.append(cur)
                if ch == ")" and st: cur = st.pop()
        else:
            t.append(w)
    return out
if tool in ("Write", "Edit", "MultiEdit"):
    p = ti.get("file_path") or ""
    if is_v and bad_v(p):
        deny("verifier is read-only, cannot write " + p)
    if not is_v and ok(p):
        deny("only the verifier writes .verdicts/")
elif tool == "Bash":
    cmd = ti.get("command", "")
    ts = targets(cmd)
    interp = re.search(
        r"\b(python3?|node|perl|ruby|ba?sh)\b", cmd)
    hid = ".verdicts" in cmd and (
        interp or any(HID.search(p) for p in ts))
    if is_v and [p for p in ts if bad_v(p)]:
        deny("verifier is read-only, writes %s" % ts)
    if not is_v and (any(ok(p) for p in ts) or hid):
        deny("only the verifier writes .verdicts/")
EOF2
exec python3 -I -c "$PY" <<< "$IN"
