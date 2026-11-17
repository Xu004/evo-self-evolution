#!/bin/sh
# bridge-journal.sh · 插件账本 → skill 镜像账本（单向导出）
# 主：/sdcard/Download/Operit/plugins/com.yg.evo/journal.md （表式，evo_reflect 写的真身）
# 从：data/journal.md （行式，journal-lint.sh 检查的格式）
# 幂等键：op | 对象 | 时间 —— 重复导入不追加
# 类型映射（插件 4 值 → skill 16 值白名单中的 4 个）：
#   exp → enum   rule → refactor   fail → fix   state → update
# 用法：sh bin/evo bridge-journal [插件账本路径]
# 注：本脚本只读插件账本，绝不写它；镜像方向永远是 插件 → skill。
PJ="${1:-/sdcard/Download/Operit/plugins/com.yg.evo/journal.md}"
cd "$(dirname "$0")/../.." || exit 1
PRIV=${EVO_PRIVATE_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)/.evo-private}
mkdir -p "$PRIV" 2>/dev/null
J="$PRIV/journal.mirror.md"
[ -f "$PJ" ] || { echo "插件账本不存在: $PJ"; exit 1; }
[ -f "$J" ] || printf "%s\n" "# EVO 本机私有镜像 · 由 bridge-journal.sh 从插件账本单向导出，勿手改" > "$J"

TMP="data/.bridge.tmp"
awk -F'|' '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function map(k) {
  if (k == "exp")   return "enum"
  if (k == "rule")  return "refactor"
  if (k == "fail")  return "fix"
  if (k == "state") return "update"
  return ""
}
{
  line = $0
  if (line !~ /^\|/) next
  if (line ~ /^\|[ \t]*时间[ \t]*\|/) next
  if (line ~ /^\|[ \t|:-]+\|$/) next
  if (NF != 7) next
  ts = trim($2); kd = trim($3); ob = trim($4); cc = trim($5); vf = trim($6)
  op = map(kd); if (op == "") next
  gsub(/\|/, "·", ob); gsub(/\|/, "·", cc); gsub(/\|/, "·", vf)
  print op" | "ob" | "ts" | "cc" | "vf
}' "$PJ" > "$TMP" 2>/dev/null || { echo "转换失败"; rm -f "$TMP"; exit 1; }

ADD=0; SKIP=0
while IFS= read -r ln; do
  [ -z "$ln" ] && continue
  key=$(echo "$ln" | cut -d'|' -f1-3)
  if grep -qF "$key" "$J" 2>/dev/null; then
    SKIP=$((SKIP + 1))
  else
    echo "$ln" >> "$J"
    ADD=$((ADD + 1))
  fi
done < "$TMP"
rm -f "$TMP"
echo "导出完成：新增 $ADD 条，已存在 $SKIP 条（幂等键 = op | 对象 | 时间）"
