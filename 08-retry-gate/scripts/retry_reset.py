#!/usr/bin/env python3
# 人补上新信息以后，放行一个被拦下的任务：
#   python3 scripts/retry_reset.py <任务短名> [补了什么]
# 只记一笔 reset，之前的失败不再算数；不删任何记录。
import json, sys, time

from retry_gate import LOG, setup

if len(sys.argv) < 2:
    sys.exit("用法：retry_reset.py <任务短名> [补了什么]")
setup()
rec = {"task": sys.argv[1], "reset": True,
       "why": " ".join(sys.argv[2:]) or "人放行",
       "at": time.strftime("%Y-%m-%dT%H:%M:%S")}
with open(LOG, "a", encoding="utf-8") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
print("已放行：" + sys.argv[1])
