#!/bin/sh
# eval.sh · 检索评测集 harness（v0.16.4-dev P0-D1）
# 定位：shell 不能直接调 query_memory，本脚本只管「出题 / 记账 / 算分」，检索由 agent 执行。
#       把「20 题手动点 20 次」压成「一条命令出题 → record → 一条命令算分」。
# 用法：
#   sh bin/evo eval start [label]        开一轮（生成 data/eval-runs/<ts>-<label>.tsv）
#   sh bin/evo eval next                 打印下一道未记录题（含 query 参数）
#   sh bin/evo eval record <id> <rank>   rank=1..10 命中位置，0=未命中
#   sh bin/evo eval status               进度
#   sh bin/evo eval report               命中率 / MRR / 分域 / 对比基线
#   sh bin/evo eval abort                丢弃本轮
#   sh bin/evo eval list                 历史轮次
# 判据（与 data/retrieval-evalset.md 一致）：期望标题出现在
#   query_memory(folder_path="self-evo", limit=10) 返回的标题列 → 记其 1-based 位置；否则 0。
cd "$(dirname "$0")/../.." || exit 1
S="data/retrieval-evalset.md"
RUNDIR="data/eval-runs"
mkdir -p "$RUNDIR" 2>/dev/null

parse_set() {
  awk -F'|' '
    /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
      id = $2; q = $3; t = $4; d = $5
      gsub(/^[ \t]+|[ \t]+$/, "", id)
      gsub(/^[ \t]+|[ \t]+$/, "", q)
      gsub(/^[ \t]+|[ \t]+$/, "", t)
      gsub(/^[ \t]+|[ \t]+$/, "", d)
      if (id ~ /^[0-9]+$/) print id "\t" d "\t" q "\t" t
    }' "$S"
}

cur_run() {
  [ -f "$RUNDIR/.current" ] || return 1
  _r=$(sed -n 1p "$RUNDIR/.current")
  [ -n "$_r" ] && [ -f "$_r" ] || return 1
  printf '%s\n' "$_r"
}

require_run() {
  RUN=$(cur_run) || { echo "无进行中的评测轮次：先 sh data/cmd/eval.sh start"; exit 1; }
}

usage() { sed -n '5,14p' "$0"; }

case "$1" in
start)
  LBL="${2:-run}"
  LBL=$(printf '%s' "$LBL" | tr -c 'A-Za-z0-9_-' '_')
  N=$(parse_set | wc -l | tr -d ' ')
  [ "$N" -ge 1 ] || { echo "评测集解析失败：$S 表格行数为 0"; exit 1; }
  RUN="$RUNDIR/$(date +%Y%m%d-%H%M)-$LBL.tsv"
  : > "$RUN"
  printf '%s\n' "$RUN" > "$RUNDIR/.current"
  echo "评测轮次已开：$RUN"
  echo "题数 $N ｜ 判据：期望标题出现在 limit=10 标题列 → 记 1-based 位置，否则 0"
  echo "执行：eval.sh next → query_memory → eval.sh record <id> <rank>；收尾 eval.sh report"
  ;;
next)
  require_run
  REM=$(parse_set | cut -f1 | while read -r i; do cut -f1 "$RUN" | grep -qx "$i" || echo x; done | wc -l | tr -d ' ')
  if [ "$REM" -eq 0 ]; then
    echo "全部已记录（$RUN）→ sh data/cmd/eval.sh report"
    exit 0
  fi
  parse_set | awk -F'\t' -v RUN="$RUN" -v REM="$REM" '
    BEGIN { while ((getline l < RUN) > 0) { split(l, a, "\t"); done[a[1]] = 1 } }
    !($1 in done) {
      printf "Q%s ｜域 %s ｜未记录 %s 题\n问：%s\n期望：%s\n查：query_memory(folder_path=\"self-evo\", query=\"%s\", limit=10)\n", $1, $2, REM, $3, $4, $3
      exit
    }'
  ;;
record)
  require_run
  ID="$2"; RK="$3"
  [ -n "$ID" ] && [ -n "$RK" ] || { echo "用法: eval.sh record <id> <rank 0-10>"; exit 1; }
  case "$RK" in ''|*[!0-9]*) echo "rank 必须是 0-10 整数（0=未命中）"; exit 1 ;; esac
  [ "$RK" -le 10 ] || { echo "rank 必须 0-10"; exit 1; }
  parse_set | awk -F'\t' -v id="$ID" '$1 == id { f = 1 } END { exit f ? 0 : 1 }' \
    || { echo "题号 $ID 不在评测集"; exit 1; }
  if cut -f1 "$RUN" | grep -qx "$ID"; then
    echo "Q$ID 已记录，不覆盖（要重记请 abort 重开本轮）"
    exit 1
  fi
  printf '%s\t%s\n' "$ID" "$RK" >> "$RUN"
  DONE=$(wc -l < "$RUN" | tr -d ' ')
  echo "记录 Q$ID rank=$RK ｜已记录 $DONE"
  ;;
status)
  require_run
  TOT=$(parse_set | wc -l | tr -d ' ')
  DONE=$(wc -l < "$RUN" | tr -d ' ')
  echo "轮次 $RUN ｜已记录 $DONE/$TOT"
  [ "$DONE" -gt 0 ] && { cut -f1 "$RUN" | tr '\n' ' '; echo; }
  ;;
report)
  require_run
  TMP="$RUNDIR/.set.$$"
  parse_set > "$TMP"
  OUT=$(awk -F'\t' '
    FNR == NR { d[$1] = $2; order[++n] = $1; next }
    { r[$1] = $2 }
    END {
      rec = 0; hit = 0; mr = 0; top1 = 0
      for (i = 1; i <= n; i++) {
        id = order[i]
        if (!(id in r)) continue
        rec++
        x = r[id] + 0
        cnt[d[id]]++
        if (x > 0) { hit++; mr += 1.0 / x; if (x == 1) top1++; hc[d[id]]++ }
      }
      if (rec == 0) { print "本轮 0 题记录，先 record"; exit 1 }
      printf "题数 %d/%d ｜命中 %d（%.1f%%）｜未命中 %d\n", rec, n, hit, hit * 100.0 / rec, rec - hit
      printf "MRR %.3f ｜Top1 %d\n", mr / rec, top1
      for (k in cnt) printf "分域 %-8s %d/%d\n", k, hc[k] + 0, cnt[k]
      printf "--SUM-- %d %d\n", hit, rec
    }' "$TMP" "$RUN")
  printf '%s\n' "$OUT" | grep -v '^--SUM--'
  rm -f "$TMP"
  HITN=$(printf '%s\n' "$OUT" | awk '/^--SUM--/ { print $2 }')
  RECN=$(printf '%s\n' "$OUT" | awk '/^--SUM--/ { print $3 }')
  BASE=$(grep -oE '首跑命中数：[0-9]+ / [0-9]+' "$S" | head -1)
  [ -n "$BASE" ] && echo "对照基线：$BASE"
  echo "粘贴行：$(date +%Y-%m-%d) | $(basename "$RUN") | 命中 $HITN/$RECN | 结论：___"
  ;;
abort)
  require_run
  rm -f "$RUN" "$RUNDIR/.current"
  echo "已丢弃轮次：$RUN"
  ;;
list)
  ls -1 "$RUNDIR"/*.tsv 2>/dev/null | while read -r f; do
    echo "$(wc -l < "$f" | tr -d ' ') 题  $f"
  done
  ;;
*)
  usage
  ;;
esac
