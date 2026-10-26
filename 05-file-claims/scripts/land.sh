#!/usr/bin/env bash
# Merge task NAME into main. Run it in the main checkout,
# on main, after the agent has committed and stopped.
#   scripts/land.sh NAME [--accept]
# 1. Every file the branch changed must be in NAME's
#    claim and in no one else's. This also catches
#    writes made from the shell, which the hook can't see.
# 2. If main changed one of NAME's files since the claim
#    was made, stop: someone wrote it without a claim.
#    Look at those commits; rerun with --accept if fine.
# 3. Rebase the branch onto main and run the tests there.
# 4. git merge --ff-only. If main moved after step 3,
#    this fails and nothing is merged: run land.sh again.
#    This is the version check.
# After a merge, the claim's base moves to the new main,
# so NAME's next round doesn't count this one as someone
# else's change.
set -euo pipefail
NAME=$1; ACCEPT=${2:-}
TEST=${LAND_TEST:-python3 -m pytest -q}   # edit me
GIT=$(git rev-parse --path-format=absolute \
  --git-common-dir)
CL="$GIT/claims/$NAME"
WT="$(dirname "$GIT")/.claude/worktrees/$NAME"
no() { echo "REFUSED: $*" >&2; exit 1; }

[ -f "$CL" ] || no "no claim for $NAME"
[ "$(git symbolic-ref --short HEAD)" = main ] ||
  no "run this in the main checkout, on main"
[ -z "$(git status --porcelain -uno)" ] ||
  no "the main checkout has uncommitted changes"
[ -z "$(git -C "$WT" status --porcelain)" ] ||
  no "$WT has uncommitted changes"
mine=$(tail -n +2 "$CL" | sed 's/^+ //')
base=$(head -1 "$CL" | cut -d' ' -f2)
late=$(grep '^+ ' "$CL" || true)
[ -z "$late" ] || echo "claimed after the start:" \
  "$late"

# 1. changed files vs claims
bad=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -qxF -- "$f" <<< "$mine" ||
    bad="$bad $f(unclaimed)"
  for o in "$GIT"/claims/*; do
    [ -f "$o" ] && [ "$o" != "$CL" ] || continue
    tail -n +2 "$o" | sed 's/^+ //' |
      grep -qxF -- "$f" &&
      bad="$bad $f(claimed by $(basename "$o"))"
  done
done < <(git diff --no-renames --name-only \
  "$(git merge-base main "$NAME")" "$NAME")
[ -z "$bad" ] || no "changed outside the claim:$bad"

# 2. did main change NAME's files since the claim?
moved=$(git diff --name-only "$base" main -- $mine)
if [ -n "$moved" ] && [ "$ACCEPT" != --accept ]; then
  no "main changed your files since the claim:" \
    "$moved"
fi

# 3. rebase and test; 4. fast-forward only
git -C "$WT" rebase -q main ||
  { git -C "$WT" rebase --abort; no "rebase conflict"; }
(cd "$WT" && sh -c "$TEST") || no "tests fail after rebase"
git merge -q --ff-only "$NAME" ||
  no "main moved during the check; run land.sh again"

L="$GIT/claims/.lock"            # same lock as claim.sh
until mkdir "$L" 2>/dev/null; do sleep 0.2; done
trap 'rmdir "$L"' EXIT
T="$GIT/claims/.$NAME.new"       # dot: hook skips it
{ echo "base $(git rev-parse main)"
  tail -n +2 "$CL"; } > "$T" && mv "$T" "$CL"
echo "landed $NAME at $(git rev-parse --short main)"
