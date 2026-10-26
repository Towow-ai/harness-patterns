#!/usr/bin/env bash
# Claim the files a task will change, before an agent
# starts on it. Paths are relative to the repo root.
#   scripts/claim.sh NAME PATH...   claim PATHs for NAME.
#     The first call also makes the worktree
#     .claude/worktrees/NAME on a new branch NAME from
#     main. Later calls add paths, marked "+ ".
#   scripts/claim.sh NAME           show NAME's claim
#   scripts/claim.sh --release NAME drop NAME's claim
# A path another task holds is refused. Claims live in
# the shared .git dir, outside every worktree; line 1
# of a claim is the main commit it was made on.
set -euo pipefail
[ $# -ge 1 ] || { sed -n 4,9p "$0"; exit 2; }
GIT=$(git rev-parse --path-format=absolute \
  --git-common-dir)
TOP=$(dirname "$GIT")            # the main checkout
DIR="$GIT/claims"
mkdir -p "$DIR"
until mkdir "$DIR/.lock" 2>/dev/null; do sleep 0.2; done
trap 'rmdir "$DIR/.lock"' EXIT   # one writer at a time

if [ "$1" = --release ]; then
  rm -f "$DIR/$2"; echo "released $2"; exit 0
fi
NAME=$1; shift
if [ $# -eq 0 ]; then cat "$DIR/$NAME"; exit 0; fi

held() {  # paths in claim file $1, without "+ "
  tail -n +2 "$1" | sed 's/^+ //'
}
for p in "$@"; do
  for f in "$DIR"/*; do
    [ -f "$f" ] || continue
    [ "$(basename "$f")" = "$NAME" ] && continue
    if held "$f" | grep -qxF -- "$p"; then
      echo "REFUSED: $p is claimed by" \
        "$(basename "$f")" >&2
      exit 1
    fi
  done
done

mark=""
if [ -f "$DIR/$NAME" ]; then
  mark="+ "                      # added after the start
  base=$(head -1 "$DIR/$NAME" | cut -d' ' -f2)
  if git -C "$TOP" merge-base --is-ancestor main "$NAME"
  then                           # branch has all of main
    T="$DIR/.$NAME.new"          # dot: hook skips it
    { echo "base $(git -C "$TOP" rev-parse main)"
      tail -n +2 "$DIR/$NAME"; } > "$T"
    mv "$T" "$DIR/$NAME"
  elif [ -n "$(git -C "$TOP" diff --name-only \
      "$base" main -- "$@")" ]; then
    echo "REFUSED: main changed these since your claim;" \
      "rebase your worktree on main, then claim again" >&2
    exit 1
  fi
else
  git -C "$TOP" worktree add -q \
    ".claude/worktrees/$NAME" -b "$NAME" main
  echo "base $(git -C "$TOP" rev-parse main)" \
    > "$DIR/$NAME"
fi
for p in "$@"; do
  held "$DIR/$NAME" | grep -qxF -- "$p" ||
    echo "$mark$p" >> "$DIR/$NAME"
done
cat "$DIR/$NAME"
