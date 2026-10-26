# Working in parallel

- Each task runs in its own worktree,
  `.claude/worktrees/<name>`, and has a claim: the files
  it may change. See yours: `scripts/claim.sh <name>`.
- Before you edit, make sure the claim covers everything
  the task must change: the code itself, the place it is
  wired in (a registry, router or main), its tests, and
  sibling or generated files. Claim a missing one with
  `scripts/claim.sh <name> <path>` (path from repo root).
- A file claimed by another task is not yours. Do not
  edit it, not even from the shell. Finish the rest,
  commit, and tell the human which file you need.
- Commit in your worktree when done. Never merge into
  main; the human runs `scripts/land.sh <name>`.
