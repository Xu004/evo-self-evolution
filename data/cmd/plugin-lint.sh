#!/bin/sh
# plugin-lint.sh · 插件账本（表式）格式体检
# 起因：技能账本 data/journal.md 是行式（op | 对象 | 时间 | 内容 | 标记），
#       而插件 com.yg.evo 写出的是表式（| 时间 | 类型 | 对象 | 结论 | 验证 |）。
#       两套格式互不兼容，journal-lint.sh 会把表式行全判成「野行」。
#       本脚本只负责「表式」这一侧，输出契约与 journal-lint.sh 保持一致，
#       使 check.sh 的 C6 可以用同一个 grep 消费。
# 输出契约（check.sh C6 依赖，勿改）：违规行以 "违规：" 或 "<行号>: " 开头
# 退出码：0=通过 1=有违规
# 用法：sh bin/evo plugin-lint [账本路径]
PJ="${1:-/sdcard/Download/Operit/plugins/com.yg.evo/journal.md}"
[ -f "$PJ" ] || { echo "违规：插件账本不存在（$PJ）"; exit 1; }

awk -F'|' '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
BEGIN {
  # 插件侧类型白名单 4 值，与 com.yg.evo manifest / evo_reflect 对齐
  NV = split("exp rule fail state", V, " ")
  for (i = 1; i <= NV; i++) valid[V[i]] = 1
  n = 0; cnt = 0
}
{
  line = $0
  if (line ~ /^[ \t]*$/) next                    # 空行豁免
  if (line ~ /^#/) next                          # 注释豁免
  if (line ~ /^\|[ \t]*时间[ \t]*\|/) next       # 表头豁免
  if (line ~ /^\|[ \t|:-]+\|$/) next             # 分隔行豁免
  if (line !~ /^\|/) { bad[++n] = NR": 野行（表式账本每行须以 | 开头）"; next }

  if (NF != 7) { bad[++n] = NR": 字段数 " (NF - 2) "（应为 5：时间/类型/对象/结论/验证）"; next }

  ts = trim($2); kd = trim($3); ob = trim($4); cc = trim($5); vf = trim($6)

  if (ts !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]$/)
    bad[++n] = NR": 时间戳格式错（应 YYYY-MM-DD HH:MM）→ "ts
  if (!(kd in valid))
    bad[++n] = NR": 类型非法（合法: exp/rule/fail/state）→ "kd
  if (ob == "") bad[++n] = NR": 对象为空"
  if (cc == "") bad[++n] = NR": 结论为空"
  if (vf == "") bad[++n] = NR": 验证为空"

  cnt++
}
END {
  printf "=== 插件账本体检：%s ===\n", FILENAME
  printf "条目 %d 条\n", cnt + 0
  if (n == 0) { print "无违规"; exit 0 }
  for (i = 1; i <= n && i <= 20; i++) print bad[i]
  if (n > 20) printf "...（另有 %d 条未显示）\n", n - 20
  exit 1
}' "$PJ"
