#!/usr/bin/env python3
# 跑 rules.py 里的检查规则，按各自的 stage 处理命中，
# 每次命中追加一行到 checks/hits.jsonl。
# 用法：python3 checks/run.py
# 升 enforce 那天把存量记进基线（只由人来跑）：
#   python3 checks/run.py --baseline 规则名
import ast, json, os, subprocess, sys, time
from collections import Counter

from rules import RULES

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BASELINE = os.path.join(HERE, "baseline.txt")
HITS = os.path.join(HERE, "hits.jsonl")


def files():
    # 仓库里所有没被忽略的 .py，已删掉的除外
    out = subprocess.run(
        ["git", "ls-files", "-z", "-co",
         "--exclude-standard", "*.py"],
        cwd=ROOT, capture_output=True, text=True,
        check=True).stdout.split("\0")
    return [p for p in out
            if p and os.path.exists(os.path.join(ROOT, p))]


def scan(path):
    # 一个文件里所有规则的命中：[(规则, 行号, 说明, 那一行)]
    with open(os.path.join(ROOT, path), "rb") as f:
        src = f.read()
    tree = ast.parse(src, path)
    lines = src.decode("utf-8", "replace").splitlines()
    out = []
    for name, (stage, check) in RULES.items():
        if stage == "retired":
            continue
        for no, msg in check(tree):
            code = (lines[no - 1].strip()
                    if no <= len(lines) else "")
            out.append((name, no, msg, code))
    return out


def baseline():
    # 基线一行一条：规则名<Tab>文件<Tab>那一行的代码。
    # 认的是那一行的内容，不是行号：挪动不算新增，改了就算。
    # 同一个文件里同样的一行有几处，就记几行
    if not os.path.exists(BASELINE):
        return Counter()
    with open(BASELINE, encoding="utf-8") as f:
        rows = [l.rstrip("\n") for l in f]
    return Counter(tuple(l.split("\t", 2)) for l in rows
                   if l.strip() and not l.startswith("#"))


def add_baseline(name):
    old, new = baseline(), []
    for path in files():
        for rule_name, no, msg, code in scan(path):
            key = (rule_name, path, code)
            if rule_name != name:
                continue
            if old[key]:
                old[key] -= 1
            else:
                new.append("\t".join(key))
    with open(BASELINE, "a", encoding="utf-8") as f:
        f.writelines(line + "\n" for line in new)
    print("基线加了 %d 条：%s" % (len(new), name))


def main():
    base, rows, warn, block = baseline(), [], [], []
    for path in files():
        try:
            found = scan(path)
        except (SyntaxError, ValueError):
            # 读不懂的文件算没过，不当作没问题
            block.append("%s: 解析失败" % path)
            continue
        seen = Counter()
        for name, no, msg, code in found:
            stage = RULES[name][0]
            key = (name, path, code)
            seen[key] += 1
            old = seen[key] <= base[key]
            stop = stage == "enforce" and not old
            rows.append({"rule": name, "stage": stage,
                         "where": "%s:%d" % (path, no),
                         "code": code, "baseline": old,
                         "blocked": stop})
            where = "%s:%d: [%s] %s" % (path, no, name, msg)
            if stop:
                if base[key]:
                    where += ("（同样的一行基线记了 %d 处，"
                              "这里是多出来的）" % base[key])
                block.append(where)
            elif stage == "warn":
                warn.append(where)
    at = time.strftime("%Y-%m-%dT%H:%M:%S")
    with open(HITS, "a", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(dict(r, at=at),
                               ensure_ascii=False) + "\n")
    for w in warn:
        print("提醒（不挡提交）：" + w)
    for b in block:
        print(b)
    if block:
        print("这条规则已经在拦了。修掉它；升 enforce 那天"
              "就有的存量才进基线，加基线要人看过。")
        sys.exit(1)


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == "--baseline":
        add_baseline(args[1])
    else:
        main()
