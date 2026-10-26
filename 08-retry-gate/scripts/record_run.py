#!/usr/bin/env python3
# SubagentStop：子 Agent 收尾后跑验收命令，没过就记一笔。
# 只认验收命令的退出码，不看子 Agent 自己说成了还是没成、
# 为什么没成。不是经 retry_gate 放出去的，一律不管。
import json, os, subprocess, sys, time

from retry_gate import (LOG, MAX_FAILS, PENDING, ROOT,
                        failures, repo_hash, sha)

# 验收命令：换成你项目里判断"这件活做成没有"的那条
CHECK = ["python3", "-m", "pytest", "-q"]


def read_run(path):
    # 子 Agent 运行记录：第一条 user 消息就是派它的说明；
    # 再看它自己有没有派过子 Agent
    prompt, spawned = None, False
    with open(path, encoding="utf-8") as f:
        for line in f:
            r = json.loads(line)
            c = r.get("message", {}).get("content", "")
            if r.get("type") == "user" and prompt is None:
                if isinstance(c, list):
                    c = "".join(b.get("text", "") for b in c
                                if b.get("type") == "text")
                prompt = c
            elif isinstance(c, list):
                spawned = spawned or any(
                    b.get("type") == "tool_use"
                    and b.get("name") == "Agent" for b in c)
    return prompt or "", spawned


def append(rec):
    rec["at"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def main():
    data = json.load(sys.stdin)
    path = os.path.expanduser(
        data.get("agent_transcript_path") or "")
    if not os.path.isfile(path):
        return
    prompt, spawned = read_run(path)
    ph = sha(prompt.encode())
    pend = os.path.join(PENDING, ph + ".json")
    if spawned or not os.path.exists(pend):
        # 把活又派给自己子 Agent 的那一层不记：它中途收工
        # 是在等子 Agent，真正动手的那一层收尾时才记
        return
    with open(pend, encoding="utf-8") as f:
        run = json.load(f)
    env = dict(os.environ, NO_COLOR="1")
    p = subprocess.run(CHECK, cwd=ROOT, env=env,
                       capture_output=True, text=True)
    out = (p.stdout.strip() or p.stderr.strip())
    out = out.splitlines()
    last = out[-1][:160] if out else "（验收命令没有输出）"
    task = run["task"]
    if p.returncode == 0:
        os.remove(pend)
        append({"task": task, "reset": True,
                "why": "验收通过：" + last})
        return
    # 没过就留着 pending：主 Agent 用 SendMessage 续跑
    # 同一个子 Agent，收尾时还能对上，照样记一笔
    n = len(failures(task)) + 1
    append({"task": task, "input": run["input"],
            "after": repo_hash(), "summary": last,
            # 续跑时 SendMessage 填的 to 就是这两样之一
            "agent": data.get("agent_id"),
            "name": run.get("name"),
            "unblock": "仓库变了" if n < MAX_FAILS
            else "人跑 scripts/retry_reset.py"})


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # 只记账：出错也退出 0，不拦子 Agent 收尾
        print("record_run 出错：%s" % e,
              file=sys.stderr)
    sys.exit(0)
