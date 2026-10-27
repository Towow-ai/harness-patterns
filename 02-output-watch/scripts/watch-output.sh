#!/usr/bin/env bash
# 巡检：盯产出。列出两样：有提交、却超过 MAX_AGE 秒
# 没合回 BASE 的分支；改了没提交、改动的文件超过
# MAX_AGE 秒没再动过的 worktree（主目录不看）。
# 每轮都在 .watch/log 写一行，查出 0 个也写；
# git 出错就不写，让死人开关发现。
cd "$(dirname "$0")/.." || exit 1
MAX_AGE=${MAX_AGE:-3600}
BASE=${BASE:-main}
export GIT_OPTIONAL_LOCKS=0   # 只读：不替正在干活的 Agent 写 index
refs=$(git for-each-ref --no-merged="$BASE" \
  --format='%(refname:short)' refs/heads) || exit 1
now=$(date +%s); late=""
for b in $refs; do
  t=$(git log -1 --format=%ct "$b" --) || exit 1
  [ $((now - t)) -gt "$MAX_AGE" ] && late="$late $b"
done
wts=$(git worktree list --porcelain) || exit 1
while IFS= read -r w; do
  [ -d "$w" ] || continue
  git -C "$w" status --porcelain -z -uall --no-renames \
    > /dev/null || exit 1
  new=0; dirty=""
  while IFS= read -r -d '' l; do
    dirty=1; f="$w/${l:3}"
    # 文件删了，就往上找还在的目录，看它的修改时间
    until t=$(date -r "$f" +%s 2>/dev/null) || [ "$f" = "$w" ]; do
      f=$(dirname "$f")
    done
    [ -n "$t" ] && [ "$t" -gt "$new" ] && new=$t
  done < <(git -C "$w" status --porcelain -z -uall --no-renames)
  [ -n "$dirty" ] && [ $((now - new)) -gt "$MAX_AGE" ] || continue
  b=$(git -C "$w" rev-parse --abbrev-ref HEAD) || exit 1
  # 没在分支上（比如 rebase 停在半路），写目录名
  [ "$b" = HEAD ] && b=${w##*/} && b=${b// /_}
  case " $late " in *" $b "*) continue ;; esac
  late="$late $b(没提交)"
done <<< "$(printf '%s\n' "$wts" | sed -n '1d;s/^worktree //p')"
n=$(echo $late | wc -w | tr -d ' ')
mkdir -p .watch
echo "$(date '+%F %T') late=$n$late" >> .watch/log
[ "$n" = 0 ] || scripts/alert.sh "没合回 $BASE:$late"
