#!/usr/bin/env bash
# PreToolUse hook for Edit|Write; exit 2 blocks the call.
# Claims live in <git common dir>/claims/ (see
# scripts/claim.sh); a worktree is known by its folder
# name, taken from the hook's cwd. Blocks a write when
# the file is claimed by another task, or when this
# worktree has a claim and the file is not in it.
# Writes made from the shell never reach this hook;
# scripts/land.sh checks every changed file instead.
IN=$(cat)
read -r -d '' PY <<'EOF'
import json, os, subprocess, sys
d = json.load(sys.stdin)
path = (d.get("tool_input") or {}).get("file_path")
cwd = d.get("cwd") or os.getcwd()
def git(*a):
    r = subprocess.run(["git", "-C", cwd, *a],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""
top = git("rev-parse", "--show-toplevel")
common = git("rev-parse", "--path-format=absolute",
             "--git-common-dir")
claims = os.path.join(common, "claims")
if not (path and top and os.path.isdir(claims)):
    sys.exit(0)                  # no claims in use here
me = os.path.basename(top)
full, top = os.path.realpath(path), os.path.realpath(top)
root = os.path.realpath(os.path.dirname(common))
def under(p, d):
    return os.path.commonpath([p, d]) == d
if not under(full, root):
    sys.exit(0)                  # outside the repo
def block(msg):
    sys.stderr.write("BLOCKED: %s\n" % msg)
    sys.exit(2)
rel = os.path.relpath(full, top)
if rel.startswith(("..", ".claude/worktrees/")):
    block(path + " is outside your worktree " + top)
own, other = None, {}
for n in os.listdir(claims):
    f = os.path.join(claims, n)
    if n.startswith(".") or not os.path.isfile(f):
        continue
    with open(f) as h:
        held = {l[2:] if l.startswith("+ ") else l
                for l in h.read().splitlines()[1:] if l}
    if n == me:
        own = held
    else:
        other.update(dict.fromkeys(held, n))
if rel in other:
    block("%s is claimed by task %s. Do not edit it; "
          "finish the rest, commit, and tell the human."
          % (rel, other[rel]))
if own is not None and rel not in own:
    block("%s is not in your claim. If no one holds it, "
          "run: scripts/claim.sh %s %s  then retry."
          % (rel, me, rel))
EOF
exec python3 -I -c "$PY" <<< "$IN"
