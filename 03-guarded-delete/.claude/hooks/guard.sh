#!/usr/bin/env bash
# PreToolUse hook for Bash; exit 2 blocks the command.
# It reads the command text only, nothing else. Blocks:
# 1. git commands that throw away uncommitted work:
#    stash, restore, clean, reset --hard, checkout or
#    switch with -- . -f --force --discard-changes.
#    Their text names no target; the sandbox lets them
#    through because the working tree must stay
#    writable.
# 2. a delete or move (rm, rmdir, unlink, shred, mv,
#    find -delete) whose text names a protected path:
#    a fallback for when the sandbox is not running.
IN=$(cat)
read -r -d '' PY <<'EOF'
import json, re, sys
PROTECTED = ["records", ".do-not-delete"]  # edit me
ti = json.load(sys.stdin).get("tool_input") or {}
cmd = (ti.get("command") or "").replace("\\\n", " ")
W = r"(?:^|[\s;&|(`'\"/\\])"   # start of a word
E = r"(?=[\s;&|)`'\"]|$)"       # end of a word
G = W + r"git(?:\s+-[cC]\s+\S+|\s+-\S+)*\s+"
A = r"[^;&|\n]*"              # rest of this command
ROLL = re.compile(
    G + r"(?:stash|restore|clean)" + E
    + "|" + G + r"reset" + A + r"\s--hard" + E
    + "|" + G + r"(?:checkout|switch)" + A + r"\s(?:"
    + r"--|\.|-f|--force|--discard-changes)" + E)
DEL = re.compile(W + r"(?:rm|rmdir|unlink|shred|mv)"
                 + E + r"|\s-delete" + E)
why = ""
if ROLL.search(cmd):
    why = "can throw away uncommitted work"
elif DEL.search(cmd) and any(p in cmd for p in PROTECTED):
    why = "deletes or moves a protected path"
if why:
    sys.stderr.write("BLOCKED: this command %s.\n"
                     "Do not retry it another way; "
                     "ask the human.\n" % why)
    sys.exit(2)
EOF
exec python3 -I -c "$PY" <<< "$IN"
