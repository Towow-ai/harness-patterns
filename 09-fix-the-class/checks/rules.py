#!/usr/bin/env python3
# 检查规则：一类问题一条。扫整个仓库，同类写法出现在哪都报。
# 每条规则在 checks/examples/<规则名>/ 下配 bad.py（必须报错）
# 和 good.py（必须不报），由 test_rules.py 证明。
# 用法：python3 checks/rules.py
import ast, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
EXCEPTIONS = os.path.join(HERE, "exceptions.txt")
RULES = {}


def rule(name):
    def add(f):
        RULES[name] = f
        return f
    return add


HTTP = {"get", "post", "put", "patch", "delete", "head",
        "request"}


@rule("requests-timeout")
def requests_timeout(tree):
    # 调 requests 不带 timeout：对方不响应，这里就一直等
    for n in ast.walk(tree):
        f = getattr(n, "func", None)
        if (isinstance(n, ast.Call)
                and isinstance(f, ast.Attribute)
                and isinstance(f.value, ast.Name)
                and f.value.id == "requests"
                and f.attr in HTTP
                and not any(k.arg == "timeout"
                            for k in n.keywords)):
            yield n.lineno, "requests 调用没有 timeout"


def hits(name, path):
    # 一条规则在一个文件里的命中：[(行号, 说明)]。
    # 按字节交给 ast，文件头声明了别的编码也照它读
    with open(path, "rb") as f:
        tree = ast.parse(f.read(), path)
    return list(RULES[name](tree))


def files():
    # 仓库里所有没被忽略的 .py，样例目录和已删掉的除外
    out = subprocess.run(
        ["git", "ls-files", "-z", "-co",
         "--exclude-standard", "*.py"],
        cwd=ROOT, capture_output=True, text=True,
        check=True).stdout.split("\0")
    return [p for p in out
            if p and not p.startswith("checks/examples/")
            and os.path.exists(os.path.join(ROOT, p))]


def exceptions():
    # 例外表一行一条：规则名 文件:行号 理由
    out = {}
    if not os.path.exists(EXCEPTIONS):
        return out
    with open(EXCEPTIONS, encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(None, 2)
            if len(parts) < 3:
                sys.exit("exceptions.txt 第 %d 行没写理由" % i)
            out[(parts[0], parts[1])] = parts[2]
    return out


def main():
    allowed, used, bad = exceptions(), set(), []
    for path in files():
        for name in RULES:
            try:
                found = hits(name, os.path.join(ROOT, path))
            except (SyntaxError, ValueError):
                # 读不懂的文件算没过，不当作没问题
                bad.append("%s: 解析失败" % path)
                break
            for line, msg in found:
                key = (name, "%s:%d" % (path, line))
                if key in allowed:
                    used.add(key)
                else:
                    bad.append("%s: [%s] %s"
                               % (key[1], name, msg))
    for key in set(allowed) - used:
        bad.append("例外 %s %s 已经对不上任何一处，删掉它"
                   % key)
    for b in bad:
        print(b)
    if bad:
        print("这一类已经有检查规则。修掉它；确实要放过，"
              "写进 checks/exceptions.txt 并写明理由。")
        sys.exit(1)


if __name__ == "__main__":
    main()
