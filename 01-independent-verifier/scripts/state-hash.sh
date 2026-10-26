#!/usr/bin/env bash
# Print the tree hash of the whole working state:
# HEAD + every edit, new file and deletion. Ignored
# files (.verdicts/, caches) are left out.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 1
tmp=$(mktemp -d)
export GIT_INDEX_FILE="$tmp/index"   # must not exist yet
git read-tree HEAD && git add -A && git write-tree
rc=$?
rm -rf "$tmp"
exit $rc
