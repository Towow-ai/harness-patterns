#!/usr/bin/env bash
# 告警出口：记进 .watch/alerts，再把这句话交给
# ALERT_CMD（在 crontab 里设，换成你自己的通知）。
cd "$(dirname "$0")/.." || exit 1
mkdir -p .watch
echo "$(date '+%F %T') $*" >> .watch/alerts
if [ -n "$ALERT_CMD" ]; then
  printf '%s\n' "$*" | sh -c "$ALERT_CMD"
fi
