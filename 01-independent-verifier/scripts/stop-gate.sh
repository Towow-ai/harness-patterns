#!/usr/bin/env bash
# Stop hook: no "done" without a verifier pass.
# Pass = state equals the `verified` tag, or
# .verdicts/<state-hash>.json says pass by verifier.
here=$(cd "$(dirname "$0")" && pwd)
IN=$(cat)
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
active=$(python3 -I -c '
import json, sys
print(json.load(sys.stdin).get("stop_hook_active"))
' <<< "$IN" 2>/dev/null)

hash=$("$here"/state-hash.sh) || hash=unknown  # 算不出就拦
base=$(git rev-parse -q --verify 'verified^{tree}')
[ "$hash" = "$base" ] && exit 0
file=".verdicts/$hash.json"
missing=$(python3 -I - "$file" 2>&1 <<'PY'
import json, os, sys
p = sys.argv[1]
if not os.path.exists(p):
    sys.exit("- no verdict file for the current state")
try:
    v = json.load(open(p))
except Exception as e:
    sys.exit(f"- verdict file is not valid JSON ({e})")
if v.get("verdict") != "pass":
    print(f"- verdict is {v.get('verdict')!r}, not 'pass'")
if v.get("author") != "verifier":
    a = v.get("author")
    print(f"- author is {a!r}, not 'verifier'")
PY
)
[ -z "$missing" ] && exit 0

if [ "$active" = "True" ]; then
  # Second stop: let go (no endless loop), but say so.
  mkdir -p .verdicts
  echo "$(date '+%F %T') $hash" >> .verdicts/unverified.log
  printf '{"systemMessage": "%s（状态 %s）"}\n' \
    "本轮改动没有通过独立验收就收工了" "${hash:0:8}"
  exit 0
fi
{
  echo "Stop blocked: state $hash is not verified."
  echo "$missing"
  echo "Run the verifier subagent on the current state."
  echo "Never write .verdicts/ yourself."
} >&2
exit 2
