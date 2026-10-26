"""Every recursive delete in this repo goes through here.

It looks at the target, not at who is asking: a
.do-not-delete marker on the target, anywhere inside
it, or on any parent means no, even with force.
Uncommitted or untracked work inside the target needs
force; files git ignores do not count. An empty path,
the current dir, the repo root, home and / are refused.
CLI: python3 tools/guarded.py PATH [--force]
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

MARK = ".do-not-delete"


class Refused(Exception):
    pass


def guarded_rmtree(target, force=False):
    if not str(target).strip():     # "" would mean cwd
        raise Refused("empty path")
    path = os.path.abspath(target)  # what gets deleted
    real = Path(path).resolve()     # what gets checked
    if real in never(real):  # cwd, repo root, home, /
        raise Refused(f"{real} is never deleted")
    for d in (real, *real.parents):
        if (d / MARK).exists():
            raise Refused(f"{d / MARK} protects {real}")
    def stop(e):  # cannot look inside: refuse
        raise Refused(f"cannot scan {real}: {e}")
    for root, dirs, files in os.walk(real, onerror=stop):
        if MARK in dirs + files:
            raise Refused(f"{root}/{MARK} is inside")
    if not force and uncommitted(real):
        raise Refused(f"{real} holds uncommitted work; "
                      "use --force only if you are sure")
    shutil.rmtree(path)  # refuses a symlink


def never(p):  # even with force
    out = {Path.cwd().resolve(), Path.home().resolve(),
           Path(p.anchor)}
    if p.is_dir():
        r = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=p, capture_output=True, text=True)
        if r.returncode == 0:  # p is a repo's root?
            out.add(Path(r.stdout.strip()).resolve())
    return out


def uncommitted(p):  # modified/untracked; no git: yes
    r = subprocess.run(
        ["git", "status", "--porcelain",
         "--untracked-files=all", "--", "."],
        cwd=p, capture_output=True, text=True)
    return r.returncode != 0 or r.stdout.strip() != ""


if __name__ == "__main__":
    args = sys.argv[1:]
    try:
        guarded_rmtree(args[0], "--force" in args)
    except (Refused, OSError, IndexError) as e:
        sys.exit(f"REFUSED: {e}")
    print("deleted", args[0])
