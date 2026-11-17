#!/bin/sh
# data/cmd/status.sh · 生成 data/status.md 单页看板（链 / 落地 / 水位 / 账本 / 门禁）
set -u
# 本地时区：容器默认 UTC，凌晨取日期会错一天（坑26）
if TZ=Asia/Shanghai date +%F >/dev/null 2>&1; then
  TZ=Asia/Shanghai
else
  TZ=
fi
export TZ
HERE=$(cd "$(dirname "$0")/../.." && pwd)
CONF="$HERE/data/chain.conf"
[ -f "$CONF" ] && . "$CONF"
WF_DIR=${WF_DIR:-/sdcard/Download/Operit/workflow}
JB=${JOURNAL:-/sdcard/Download/Operit/plugins/com.yg.evo/journal.md}
OUT="$HERE/data/status.md"
NOW=$(date '+%F %T')

{
  echo "# EVO 状态看板"
  echo ""
  echo "生成时间: $NOW"
  echo ""
  echo "## 自续链"
  echo '```'
  sh "$HERE/data/cmd/chain.sh" list
  echo '```'
  echo ""
  echo "## 落地心跳（近 7 天）"
  echo '```'
  sh "$HERE/data/cmd/chain.sh" heartbeat7
  echo '```'
  echo ""
  echo "## 水位 / 时钟（mirror）"
  echo '```'
  grep -E '^last_dream|^complete|^- 当前:|^- 上一跳:|^- 文明跃迁|^- 暗区|^- Kairos|^- 文本提取|^- 友好问候' "$HERE/data/waters.md" 2>/dev/null
  echo '```'
  echo ""
  echo "## 账本"
  echo '```'
  echo "行数: $(wc -l < "$JB" 2>/dev/null)"
  echo "最近 3 条:"
  tail -3 "$JB" 2>/dev/null | cut -c1-160 | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null
  echo '```'
  echo ""
  echo "## 门禁 journal-lint"
  echo '```'
  sh "$HERE/data/cmd/journal-lint.sh" 2>&1 | grep -E '查[1-6]|无缺失|无违规|无游离|无野行|H1-violation|^[0-9]+$' | head -12
  echo '```'
  echo ""
  echo "## 待办坑"
  echo '```'
  if grep -qE '^- 坑[0-9]+' "$HERE/data/waters.md" 2>/dev/null; then
    grep -E '^- 坑[0-9]+' "$HERE/data/waters.md" | cut -c1-140 | head -8
  else
    echo "（本地无坑索引；权威：记忆条目「坑档案:EVO」）"
  fi
  echo '```'
} > "$OUT.tmp" 2>&1

mv "$OUT.tmp" "$OUT"
echo "ok status -> $OUT"