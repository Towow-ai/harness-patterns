#!/usr/bin/env python3
# PreToolUse（matcher Agent|SendMessage）：派子 Agent、续跑
# 子 Agent 之前查失败记录。同一任务失败满两次，拦下转人；
# 上次失败以后仓库没变，也拦下。其余放行，记下派出时的输入。
import hashlib, json, os, subprocess, sys, time

MAX_FAILS = 2
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = (os.environ.get("CLAUDE_PROJECT_DIR")
        or os.path.dirname(HERE))
STATE = os.path.join(ROOT, ".claude", "state")
LOG = os.path.join(STATE, "failures.jsonl")
PENDING = os.path.join(STATE, "pending")
NOTE = ".claude/state/blocked.md"


def sha(b):
    return hashlib.sha256(b).hexdigest()[:16]


def task_of(prompt):
    lines = prompt.strip().splitlines()
    first = lines[0].strip() if lines else ""
    for p in ("任务：", "任务:"):
        if first.startswith(p):
            return first[len(p):].strip()
    return ""


def git(*args):
    # 用单独的索引文件，不碰仓库自己的暂存区
    env = dict(os.environ,
               GIT_INDEX_FILE=os.path.join(STATE, "index"))
    p = subprocess.run(("git",) + args, cwd=ROOT, env=env,
                       capture_output=True)
    return p.stdout


def repo_hash():
    # 输入 = 工作区里所有没被忽略的文件的内容，
    # 提交没提交都一样
    git("add", "-A")
    return git("write-tree").decode().strip()[:16]


def records():
    if not os.path.exists(LOG):
        return []
    with open(LOG, encoding="utf-8") as f:
        return [json.loads(line) for line in f]


def failures(task):
    out = []
    for r in records():
        if r.get("task") == task:
            out = [] if r.get("reset") else out + [r]
    return out


def setup():
    os.makedirs(PENDING, exist_ok=True)
    ignore = os.path.join(STATE, ".gitignore")
    if not os.path.exists(ignore):
        with open(ignore, "w") as f:
            f.write("*\n")


def say(decision, reason):
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}, ensure_ascii=False))
    sys.exit(0)


def check_cap(task):
    fails = failures(task)
    if len(fails) >= MAX_FAILS:
        say("deny", f"任务 {task} 已失败 {len(fails)} 次，"
            f"停下交给人：把缺什么、在等什么写进 {NOTE}。"
            f"人补上后跑 scripts/retry_reset.py {task}"
            f" 才能再派。最近一次：{fails[-1]['summary']}")
    return fails


def resume(to):
    # SendMessage 续跑一个失败过的子 Agent，不经过 Agent
    # 工具；在这里补上次数那道关
    to = to.split(" [")[0].strip()
    for r in records():
        if to and to in (r.get("agent"), r.get("name")):
            check_cap(r["task"])
    sys.exit(0)


def main():
    data = json.load(sys.stdin)
    inp = data.get("tool_input", {})
    if data.get("tool_name") == "SendMessage":
        resume(str(inp.get("to", "")))
    prompt = inp.get("prompt", "")
    task = task_of(prompt)
    if not task:
        say("deny", "派子 Agent 时，说明第一行写"
            "“任务：<短名>”，同一件事一直用同一个短名。")
    setup()
    fails = check_cap(task)
    ih = repo_hash()
    for f in fails:
        if ih in (f["input"], f["after"]):
            say("deny", f"任务 {task} 上次失败以后，"
                "仓库里没有任何变化，再跑多半还是："
                f"{f['summary']}。换个说法不算新信息："
                "把缺的那块写进仓库里的文件（任务说明、"
                "数据、代码），或者停下，把缺什么、"
                f"在等什么写进 {NOTE}。")
    rec = {"task": task, "input": ih,
           "name": inp.get("name"),
           "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
    ph = sha(prompt.encode())
    path = os.path.join(PENDING, ph + ".json")
    with open(path, "w") as f:
        json.dump(rec, f, ensure_ascii=False)
    sys.exit(0)


if __name__ == "__main__":
    main()
