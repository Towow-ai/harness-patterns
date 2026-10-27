#!/usr/bin/env bash
# Stop hook：拦两种假问法。
# 一、拿“要继续吗”“要不要我”这类问句收尾。
#     真要停，单独写一行 WAITING_FOR: 报出类别。
# 二、说“你之前同意过”，却没有 > 开头的原话，
#     或原话在 DECISIONS.md 人那一栏和你发过的
#     消息里都找不到。
# 同一轮第二次只提醒，不再拦，免得卡死。
IN=$(cat)
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

# 最后那条回复；JSON 里的 \\、\n、\" 换回原样
F='"last_assistant_message": *"(([^"\\]|\\.)*)"'
msg=$(printf '%s' "$IN" | sed -nE "s/.*$F.*/\1/p" |
  awk '{ gsub(/\\\\/, "\001"); gsub(/\\n/, "\n")
         gsub(/\\"/, "\""); gsub(/\001/, "\\"); print }')
[ -n "$msg" ] || exit 0
T=$(printf '%s' "$IN" |
  sed -nE 's/.*"transcript_path": *"([^"]*)".*/\1/p')

# 你定过的事：DECISIONS.md 里谁定一栏是“人”的行
rec() {
  grep -E '^\|[[:space:]]*人[[:space:]]*\|' DECISIONS.md \
    2>/dev/null | grep -qF -- "$1"
}

# 你亲手发过的消息：对话记录里的 user 行，
# 去掉工具结果（tool_use_id）、hook 反馈（isMeta）
# 和上下文压缩留下的摘要（isCompactSummary）
said() {
  [ -f "$T" ] || return 1
  grep -F '"type":"user"' "$T" | grep -v '"isMeta":true' |
    grep -v '"tool_use_id"' |
    grep -v '"isCompactSummary":true' | grep -qF -- "$1"
}

# 先去掉引号里的字：只是提到“要继续吗”不算数
bare=$(printf '%s\n' "$msg" | awk '
  function cut(s, L, R,   i, j, t) {
    while ((i = index(s, L)) > 0) {
      t = substr(s, i + length(L)); j = index(t, R)
      if (j == 0) break
      s = substr(s, 1, i - 1) substr(t, j + length(R))
    }
    return s
  }
  { s = cut($0, "“", "”"); s = cut(s, "‘", "’")
    s = cut(s, "「", "」"); print cut(s, "\"", "\"") }')
last=$(printf '%s\n' "$bare" | grep -v '^[[:space:]]*$' |
  tail -n 1)

why=""
ASK='要继续吗|是否继续|要不要继续|需要我继续'
ASK="$ASK|要不要我|还是你想|或者你想|你想先"
ASK="$ASK|[Ss]hould I |[Ss]hall I "
ASK="$ASK|[Ww]ould you like me|[Dd]o you want me"
if printf '%s\n' "$msg" |
  grep -qE '^WAITING_FOR: *(方向|回不去|推翻)'; then
  :
elif printf '%s\n' "$msg" | grep -q '^WAITING_FOR:'; then
  why="WAITING_FOR 没写是哪一类"
elif printf '%s\n' "$last" | grep -qE "$ASK" &&
  printf '%s\n' "$last" | grep -qE '？|\?'; then
  why="拿问句收尾"
fi

# 认“你之前同意过”这类说法；“不是你说过的”
# “别当作你说过的”是在否认，先删掉再认
CLAIM='你(之前|刚才|已经|上次)(同意|批准|确认|定|说)过'
CLAIM="$CLAIM|你说(之前|刚才|已经|上次)?(同意|批准|确认|定)过"
CLAIM="$CLAIM|你说过|按你(之前|刚才)的意思"
CLAIM="$CLAIM|[Yy]ou (already )?(agreed|approved)"
NOT='(以为|当作|当成|和|不是|没有说|没说)你'
if printf '%s\n' "$bare" | sed -E "s/$NOT//g" |
  grep -qE "$CLAIM"; then
  q=$(printf '%s\n' "$msg" | sed -n 's/^> *//p' |
    sed -E 's/^(“|「|")//; s/[[:space:]]*$//' |
    sed -E 's/(”|」|"|。|\.)+$//')
  [ -n "$q" ] || why="${why}${why:+；}说我同意过，没附原话"
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    rec "$l" || said "$l" ||
      why="${why}${why:+；}原话没找到：${l}"
  done <<< "$q"
fi

[ -n "$why" ] || exit 0
A='"stop_hook_active": *true'
if printf '%s' "$IN" | grep -q "$A"; then
  w=$(printf '%s' "$why" | tr -d '"\\')
  echo "{\"systemMessage\": \"第二次放行：${w}\"}"
  exit 0
fi
{
  echo "先别停：${why}。"
  echo "不属于三类（方向、回不去、推翻）的事，"
  echo "你自己定，记进 DECISIONS.md。没做完就接着做；"
  echo "做完了，结尾写做了什么、没做什么，不用问我。"
  echo "真属于三类之一，最后单独写一行："
  echo "WAITING_FOR: 类别 要我定什么，你倾向哪个，为什么"
  echo "说我同意过，下一行用 > 开头照抄 DECISIONS.md"
  echo "里人那一栏或我发过的原话；找不到，当我没定过。"
} >&2
exit 2
