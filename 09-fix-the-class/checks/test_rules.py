#!/usr/bin/env python3
# 证明每条规则抓得住：在 bad.py 上必须报错，在 good.py 上
# 必须不报。样例缺了算失败，不跳过；规则删了、样例还在，
# 也算失败。用法：python3 checks/test_rules.py
import os, sys

from rules import HERE, RULES, hits

EX = os.path.join(HERE, "examples")


def main():
    fails = []
    dirs = (set(os.listdir(EX)) if os.path.isdir(EX)
            else set())
    for name in RULES:
        for kind, want in (("bad.py", True),
                           ("good.py", False)):
            p = os.path.join(EX, name, kind)
            if not os.path.exists(p):
                fails.append("%s 缺少 %s" % (name, kind))
            elif bool(hits(name, p)) != want:
                fails.append("%s 在 %s 上%s" % (
                    name, kind, "没报错" if want else "误报了"))
    for d in sorted(dirs - set(RULES)):
        fails.append("examples/%s 没有对应的规则" % d)
    for f in fails:
        print("证明没过：" + f)
    if fails:
        sys.exit(1)
    print("%d 条规则，证明都过了" % len(RULES))


if __name__ == "__main__":
    main()
