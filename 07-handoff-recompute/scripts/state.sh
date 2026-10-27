#!/usr/bin/env bash
# 压缩后重算状态。SessionStart（matcher compact）调用它，
# 标准输出进 Claude 的上下文。每个数都是这一刻跑出来的，
# 脚本里不写死任何数。出错也写到标准输出、退出 0：
# SessionStart 的 stderr 只给人看，Claude 读不到。

# 数测试的命令：换成你项目里"只收集、不运行"的那条，要快
TEST_CMD=(python3 -m pytest --collect-only -q)

if ! cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null; then
  echo "状态脚本失败：进不了项目目录。"
  echo "摘要里的测试数、分支、还没提交的改动先别用。"
  exit 0
fi

echo "压缩后重算的状态，以这里为准；摘要里同类的数作废。"
echo "写进任务说明的数，后面跟上算出它的命令。"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  b=$(git branch --show-current)
  [ -n "$b" ] || b="不在任何分支上"
  echo "- 当前分支：${b}（git branch --show-current）"
  n=$(git status --short | wc -l | tr -d ' ')
  echo "- 还没提交的改动：${n} 个（git status --short）"
  git status --short | head -n 20 | sed 's/^/    /'
  if [ "$n" -gt 20 ]; then echo "    ……只列前 20 个"; fi
else
  echo "- 状态脚本失败：这里不是 git 仓库，"
  echo "  分支和还没提交的改动算不出来，摘要里的先别用。"
fi

# NO_COLOR=1：不让颜色控制符混进上下文
out=$(NO_COLOR=1 "${TEST_CMD[@]}" 2>&1)
rc=$?
last=$(printf '%s\n' "$out" | tail -n 1)
if [ "$rc" -eq 0 ]; then
  echo "- 测试：${last}（${TEST_CMD[*]}）"
else
  echo "- 状态脚本失败：数测试的命令退出码 ${rc}，"
  echo "  最后一行是：${last}"
  echo "  摘要里的测试数先别用，自己跑：${TEST_CMD[*]}"
fi
exit 0
