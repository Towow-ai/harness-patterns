#!/usr/bin/env bash
# PreToolUse hook：PROTECT 目录下已经提交过的文件，
# 只许新增，不许改。退出码 2 拦下这次 Edit/Write，
# stderr 那句话交给 Claude。
PROTECT=${PROTECT:-migrations}

f=$(grep -o '"file_path" *: *"[^"]*"' | head -n 1 |
  sed 's/^"file_path" *: *"//; s/"$//')
[ -n "$f" ] || exit 0

dir=$(dirname "$f")
# 新目录里的新文件：git 进不去，肯定没提交过，放行
pre=$(git -C "$dir" rev-parse --show-prefix 2>/dev/null) ||
  exit 0
case "$pre" in
  "$PROTECT"/*) ;;
  *) exit 0 ;;
esac

rel="$pre$(basename "$f")"
# 只认 HEAD 里有的；新建、只 git add 过的放行
if git -C "$dir" cat-file -e "HEAD:$rel" 2>/dev/null; then
  echo "$rel 已经提交过，只许新增，不许改。" >&2
  echo "别换办法改它；要改，停下来问人。" >&2
  exit 2
fi
exit 0
