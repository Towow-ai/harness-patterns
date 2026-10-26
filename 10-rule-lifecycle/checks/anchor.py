#!/usr/bin/env python3
# 和"人审过的版本"整体比，不和上一次提交比。只许往严里改，
# 往松里改的挡下来等人看：
#   CLAUDE.md 里人审过的带"必须／不得"的每一行，要原样还在；
#   rules.py 里已有的规则不许不见、stage 不许降、判法不许改，
#     规则以外的代码不许动（加一句也算），新加规则不用人看；
#   baseline.txt 不许多出条目；WHOLE 里的文件改一个字都算。
# 用法：python3 checks/anchor.py
# 人看过、同意了，由人来跑：python3 checks/anchor.py --approve
import ast, difflib, json, os, re, subprocess, sys, time
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TAG = "rules-reviewed"
LINES = ["CLAUDE.md"]
RULES = "checks/rules.py"
BASELINE = "checks/baseline.txt"
WHOLE = [".claude/settings.json", ".githooks/pre-commit",
         "checks/run.py", "checks/anchor.py"]
STRONG = re.compile("必须|不得|不要|不许|不准|禁止|严禁|只许|"
                    "never|always|must|don't|do not", re.I)
ORDER = {"retired": 0, "shadow": 1, "warn": 2, "enforce": 3}
ALL = LINES + [RULES, BASELINE] + WHOLE


def git(*args, env=None):
    return subprocess.run(("git",) + args, cwd=ROOT,
                          env=env, capture_output=True,
                          text=True)


def reviewed(path):
    # 人审过的那一版；当时没有这个文件就当空
    p = git("show", "%s:%s" % (TAG, path))
    return p.stdout if p.returncode == 0 else ""


def current(path):
    p = os.path.join(ROOT, path)
    if not os.path.exists(p):
        return ""
    with open(p, encoding="utf-8") as f:
        return f.read()


def norm(line):
    return " ".join(line.split())


def rule_of(node):
    # @rule("名字", stage="...") 装饰的函数：返回 (名字, stage)
    for d in getattr(node, "decorator_list", []):
        f = getattr(d, "func", None)
        if getattr(f, "id", "") == "rule":
            stage = [ast.literal_eval(k.value)
                     for k in d.keywords
                     if k.arg == "stage"]
            return (ast.literal_eval(d.args[0]),
                    stage[0] if stage else None)
    return None, None


def parts(text):
    # 规则文件拆成两样：每条规则的 (stage, 判法)，和别的语句。
    # 比的是语法树，改注释、改排版不算改
    rules, other = {}, set()
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return rules, other
    for node in tree.body:
        name, stage = rule_of(node)
        if name:
            body = ast.Module(body=node.body,
                              type_ignores=[])
            rules[name] = (stage, ast.dump(body))
        else:
            other.add(ast.dump(node))
    return rules, other


def hits_of(name):
    # 这条规则命中过几处、拦下过几次、最近一次在什么时候。
    # 记录在本机的 hits.jsonl 里，不进 git
    where, stops, last = set(), 0, ""
    p = os.path.join(HERE, "hits.jsonl")
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            for line in f:
                r = json.loads(line)
                if r.get("rule") == name:
                    where.add((r["where"], r["code"]))
                    stops += bool(r.get("blocked"))
                    last = r["at"]
    if not where:
        return "本机没有它的命中记录"
    return "它命中过 %d 处，拦下过 %d 次，最近一次 %s" % (
        len(where), stops, last)


def loosened():
    out = []
    for path in LINES:
        now = [norm(l) for l in current(path).splitlines()]
        for l in reviewed(path).splitlines():
            if STRONG.search(l) and norm(l) not in now:
                near = difflib.get_close_matches(
                    norm(l), now, 1, 0.3)
                new = near[0] if near else "（没有这一行了）"
                out.append("%s 里人审过的这一条变了：\n"
                           "  原来：%s\n  现在：%s"
                           % (path, norm(l), new))
    old, old_other = parts(reviewed(RULES))
    new, new_other = parts(current(RULES))
    for name, (stage, body) in old.items():
        now = new.get(name)
        if now is None:
            out.append("规则 %s 删掉了；%s"
                       % (name, hits_of(name)))
        elif ORDER.get(now[0], -1) < ORDER.get(stage, 0):
            out.append("规则 %s 从 %s 改成了 %s；%s" % (
                name, stage, now[0], hits_of(name)))
        elif now[1] != body:
            out.append("规则 %s 的判法改了" % name)
    if old_other != new_other:
        out.append("%s 里规则以外的代码改了" % RULES)
    added = (Counter(current(BASELINE).splitlines())
             - Counter(reviewed(BASELINE).splitlines()))
    for a in sorted(added.elements()):
        if a.strip():
            out.append("基线多了一条：" + a.replace("\t", "  "))
    for path in WHOLE:
        if reviewed(path) != current(path):
            out.append("%s 和人审过的版本不一样" % path)
    return out


def approve():
    # 把这几个文件现在的样子记成人审过的版本（一个 git tag）
    gd = git("rev-parse", "--absolute-git-dir").stdout
    idx = os.path.join(gd.strip(), TAG + ".index")
    env = dict(os.environ, GIT_INDEX_FILE=idx)
    paths = [p for p in ALL
             if os.path.exists(os.path.join(ROOT, p))]
    git("read-tree", "--empty", env=env)
    git("add", "-f", "--", *paths, env=env)
    tree = git("write-tree", env=env).stdout.strip()
    if not tree or git("tag", "-f", TAG, tree).returncode:
        sys.exit("没能记下人审过的版本")
    print("已记下人审过的版本：" + " ".join(paths))


def main():
    if git("rev-parse", "-q", "--verify", TAG).returncode:
        sys.exit("还没有人审过的版本：人先跑一次 "
                 "python3 checks/anchor.py --approve")
    # 下面比的是工作区里的文件，提交进去的是暂存区：两边先得一样
    d = git("diff", "--name-only", "--exit-code", "--",
            *ALL)
    if d.returncode:
        sys.exit("这几个文件有没暂存的改动，先 git add 再提交："
                 + (" ".join(d.stdout.split()) or d.stderr))
    out = loosened()
    if not out:
        return
    at = time.strftime("%Y-%m-%dT%H:%M:%S")
    with open(os.path.join(HERE, "hits.jsonl"), "a",
              encoding="utf-8") as f:
        for o in out:
            f.write(json.dumps({"rule": "anchor", "at": at,
                                "where": o.split("\n")[0],
                                "code": o, "blocked": True},
                               ensure_ascii=False) + "\n")
    for o in out:
        print(o)
    print("规则往松里改，要人看过。停下，把要改什么、为什么写给"
          "人。人同意的话，在改动还留在工作区时由人跑 "
          "--approve，再提交。")
    sys.exit(1)


if __name__ == "__main__":
    approve() if sys.argv[1:] == ["--approve"] else main()
