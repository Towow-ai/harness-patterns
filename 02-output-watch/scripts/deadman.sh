#!/usr/bin/env bash
# 死人开关：巡检的记录超过 LIMIT 秒没更新，就叫人。
# LIMIT 取两个巡检周期多一点。
cd "$(dirname "$0")/.." || exit 1
LIMIT=${LIMIT:-3900}
if ! last=$(date -r .watch/log +%s 2>/dev/null); then
  scripts/alert.sh "巡检还没有留下过记录"
  exit 0
fi
age=$(( $(date +%s) - last ))
if [ "$age" -gt "$LIMIT" ]; then
  scripts/alert.sh "巡检已经 $age 秒没有新记录"
fi
