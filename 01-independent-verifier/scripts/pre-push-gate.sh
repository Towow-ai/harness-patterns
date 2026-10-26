#!/usr/bin/env bash
# git pre-push hook: refuse to push a commit whose tree
# has no verifier pass. Install it once:
#   ln -s ../../scripts/pre-push-gate.sh \
#     .git/hooks/pre-push
# `git push --no-verify` skips it; CI is the hard fence.
cd "$(git rev-parse --show-toplevel)" || exit 1
base=$(git rev-parse -q --verify 'verified^{tree}')
zero=0000000000000000000000000000000000000000
while read -r lref lsha rref rsha; do
  [ "$lsha" = "$zero" ] && continue
  t=$(git rev-parse "$lsha^{tree}")
  [ "$t" = "$base" ] && continue
  python3 -I - ".verdicts/$t.json" <<'PY' && continue
import json, sys
try:
    v = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
good = v.get("verdict") == "pass" \
    and v.get("author") == "verifier"
sys.exit(0 if good else 1)
PY
  echo "push refused: $lref (tree ${t:0:8})" \
       "has no verifier pass" >&2
  exit 1
done
exit 0
