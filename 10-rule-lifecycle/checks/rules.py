# 检查规则：一类问题一条，每条带一个 stage。
#   shadow  只记命中，不出声。新规则先这样跑一阵
#   warn    报出来，不挡提交
#   enforce 报出来，挡下提交；baseline.txt 里的存量不挡
#   retired 不再跑，命中记录留着
# 新规则可以直接加，要用的东西写在规则函数里面。已有规则的
# 判法、往低里改的 stage、规则以外的代码，提交时都会被
# anchor.py 挡下来等人看。由 run.py 来跑。
import ast

RULES = {}


def rule(name, stage):
    def add(f):
        RULES[name] = (stage, f)
        return f
    return add


HTTP = {"get", "post", "put", "patch", "delete", "head",
        "request"}


@rule("requests-timeout", stage="enforce")
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


@rule("bare-except", stage="shadow")
def bare_except(tree):
    # except: 不写异常类型，连 Ctrl-C 和拼错的变量名一起吞掉
    for n in ast.walk(tree):
        if (isinstance(n, ast.ExceptHandler)
                and n.type is None):
            yield n.lineno, "except: 没写异常类型"
