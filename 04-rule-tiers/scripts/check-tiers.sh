#!/usr/bin/env bash
# 查三样：常驻档里没标档的“必须／不要”；标了硬拦、
# settings 里却找不到落点的；写进按需档的红线。
# 在仓库根目录跑。报出一处就退出 1。
cd "${1:-.}" || exit 2
n=0
say() { printf '%s  %s\n' "$1" "$2"; n=$((n + 1)); }

KW="必须|不要|不许|不准|禁止|严禁|只许|never|always"
KW="$KW|must|don't|do not"
ITEM='^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]'

# 规则文件开头的 --- 块里有 paths: 的，是按需加载的
has_paths() {
  awk 'NR == 1 && $0 != "---" { exit 1 }
       NR > 1 && $0 == "---" { exit 1 }
       /^paths:/ { f = 1; exit }
       END { exit !f }' "$1"
}

landed() {
  for s in .claude/settings.json \
    .claude/settings.local.json; do
    [ -f "$s" ] && grep -qF -- "$1" "$s" && return 0
  done
  return 1
}

check_resident() {
  grep -nE "$ITEM" "$1" | grep -iE "$KW" |
    while IFS= read -r l; do
      case "$l" in
        *"[硬拦:"* | *"[抽查:"*) ;;
        *) echo "没标档	$1:$l" ;;
      esac
    done
  grep -nE "$ITEM" "$1" | grep -F '[硬拦:' |
    while IFS= read -r l; do
      x=$(printf '%s\n' "$l" |
        sed -n 's/.*\[硬拦: *\([^]]*\)\].*/\1/p' |
        sed 's/ *$//')
      landed "$x" || echo "硬拦没落点	$1:$l"
    done
}

check_ondemand() {
  grep -nE '\[硬拦|红线' "$1" |
    while IFS= read -r l; do
      echo "红线在按需档	$1:$l"
    done
}

out=$(
  for f in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md; do
    [ -f "$f" ] && check_resident "$f"
  done
  find .claude/rules -name '*.md' 2>/dev/null |
    while IFS= read -r f; do
      if has_paths "$f"; then check_ondemand "$f"
      else check_resident "$f"; fi
    done
  find .claude/skills -name '*.md' 2>/dev/null |
    while IFS= read -r f; do check_ondemand "$f"; done
  # 子目录里的 CLAUDE.md 碰到那个目录才加载，也算按需
  find . -mindepth 2 -name CLAUDE.md \
    -not -path './.claude/*' -not -path './.git/*' \
    -not -path '*/node_modules/*' |
    while IFS= read -r f; do check_ondemand "${f#./}"; done
)

if [ -n "$out" ]; then
  while IFS=$'\t' read -r kind where; do
    say "$kind" "$where"
  done <<< "$out"
  echo "check-tiers：$n 处"
  exit 1
fi
echo "check-tiers：没有发现问题"
