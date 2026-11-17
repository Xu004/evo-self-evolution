#!/bin/sh
# bridge-journal.sh · 插件账本 → skill 镜像账本（单向导出）
# 主：/sdcard/Download/Operit/plugins/com.yg.evo/journal.md （表式，evo_reflect 写的真身）
# 从：data/journal.md （行式，journal-lint.sh 检查的格式）
# 幂等键：op | 对象 | 时间 —— 重复导入不追加
# 类型映射（插件 4 值 → skill 16 值白名单中的 4 个）：
#   exp → enum   rule → refactor   fail → fix   state → update   fix → fix
# 用法：sh bin/evo bridge-journal [插件账本路径]
# 注：本脚本只读插件账本，绝不写它；镜像方向永远是 插件 → skill。
PJ="${1:-/sdcard/Download/Operit/plugins/com.yg.evo/journal.md}"
# 公开快照/本地克隆：宿主插件目录不存在时回落到包内账本 data/journal.md
# （仅当用户未显式指定时生效；开发态真账本存在则此块不动）
if [ $# -eq 0 ] && [ ! -f "$PJ" ]; then
  _r=$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)
  [ -f "$_r/data/journal.md" ] && PJ="$_r/data/journal.md"
  :
fi

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
  # v0.20：主账本有 fix 类型（当前 7 条），无映射时会在下游 op=="" 被静默丢弃
  if (k == "fix")   return "fix"
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

# v0.20：原实现逐条 grep + cut（约 3 fork/条），52 条账本 ≈ 156 fork。
# 改单 awk 两文件一次算差集（教训 18）：幂等键仍是 op|对象|时间，输出保留原行格式。
# SUBSEP 作分隔符比 "|" 拼接更稳——字段内即使含 | 也不会串键。
awk -F'|' '
NR == FNR {
  k = $1 SUBSEP $2 SUBSEP $3; gsub(/^[ \t]+|[ \t]+$/, "", k); have[k] = 1; next
}
{
  k = $1 SUBSEP $2 SUBSEP $3; gsub(/^[ \t]+|[ \t]+$/, "", k)
  if (!(k in have)) { have[k] = 1; print $0 }
}' "$J" "$TMP" > "$TMP.new" 2>/dev/null

ADD=$(wc -l < "$TMP.new" 2>/dev/null || echo 0)
TOT=$(wc -l < "$TMP" 2>/dev/null || echo 0)
SKIP=$((TOT - ADD))
[ "$ADD" -gt 0 ] && cat "$TMP.new" >> "$J"
rm -f "$TMP" "$TMP.new"
echo "导出完成：新增 $ADD 条，已存在 $SKIP 条（幂等键 = op | 对象 | 时间）"
