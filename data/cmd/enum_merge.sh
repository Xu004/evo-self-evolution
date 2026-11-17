#!/bin/sh
# enum_merge.sh · H21 三口径枚举合并出数（v0.15 固化，方向5）
# 前置：enum-A/B/C-YYYYMMDD.txt 已按三口径落盘 data/
# 用法：sh bin/evo enum_merge
# 产出：data/enum-total-YYYYMMDD.txt + 出数（total/经验N）+ 三方对账提示
cd "$(dirname "$0")/.." 2>/dev/null || exit 1
D=$(date +%Y%m%d)
sort -u "enum-A-$D.txt" "enum-B-$D.txt" "enum-C-$D.txt" > "enum-total-$D.txt"
TOTAL=$(wc -l < "enum-total-$D.txt")
EXP=$(grep -c '^经验' "enum-total-$D.txt")
PREV=$(ls -1t enum-total-*.txt 2>/dev/null | sed -n 2p)
echo "enum-total-$D.txt: total=$TOTAL 经验=$EXP"
if [ -n "$PREV" ]; then
  PREV_N=$(wc -l < "$PREV")
  DIFF=$((TOTAL - PREV_N))
  echo "三方对账: 本次=$TOTAL 上次($PREV)=$PREV_N 差=$DIFF"
  echo "对照 journal 期间新增 create/update 数：grep -cE '^(create|update) ' journal.md"
  if [ "$DIFF" -ne 0 ]; then
    echo "警告: 差非零，若与 journal 期间新增不一致，按 H21 挂 journal pending 区「枚举差异:差N条」，禁止静默放过"
  fi
else
  echo "三方对账: 首跑锚定 total=$TOTAL 为基线（无上次 enum-total）"
fi
# v0.15 中间文件生命周期：enum-A/B/C 保留当日一组，清理过期日期的
for f in enum-A-*.txt enum-B-*.txt enum-C-*.txt; do
  [ -f "$f" ] || continue
  fdate=$(echo "$f" | grep -oE '[0-9]{8}')
  [ "$fdate" != "$D" ] && rm -f "$f" && echo "清理过期中间文件: $f"
done
