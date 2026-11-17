#!/bin/sh
# lexicon.sh · 查询词库展开（v0.16.4-dev P0-D3）
# 目的：把「LLM 现编关键词」换成「查表拿术语并集」，降低同题不同轮命中波动。
# 用法：
#   sh bin/evo lexicon "<现象词>"   # 输出术语并集 a|b|c（去重、保序）
#   sh bin/evo lexicon --list       # 全部条目
#   sh bin/evo lexicon --check      # 条目数 + 格式自检（check.sh C11 复用同一判据）
# 词库格式（data/query-lexicon.md）：左（现象/别名，别名用 / 分隔） => 右（检索术语，| 分隔）
cd "$(dirname "$0")/../.." || exit 1
L="data/query-lexicon.md"
[ -f "$L" ] || { echo "缺词库：$L"; exit 1; }

case "$1" in
--list)
  grep -n '=>' "$L" | sed 's/=>/ -> /'
  ;;
--check)
  N=$(grep '=>' "$L" | grep -vc '^[[:space:]]*#')
  BAD=$(grep '=>' "$L" | grep -v '^[[:space:]]*#' | grep -vc '|')
  echo "条目 $N ｜格式不合格（右侧无 | 分隔）$BAD"
  if [ "$N" -ge 30 ] && [ "$BAD" -eq 0 ]; then exit 0; else exit 1; fi
  ;;
*)
  W="$1"
  [ -n "$W" ] || { echo "用法: lexicon.sh <现象词> ｜ --list ｜ --check"; exit 1; }
  awk -v w="$W" '
    {
      if ($0 ~ /^[ \t]*#/) next
      if (index($0, "=>") == 0) next
      split($0, part, "=>")
      left = part[1]
      gsub(/^[ \t]+|[ \t]+$/, "", left)
      if (index(tolower(left), tolower(w)) == 0) next
      m = 0
      n = split(part[2], a, "|")
      for (i = 1; i <= n; i++) {
        t = a[i]
        gsub(/^[ \t]+|[ \t]+$/, "", t)
        if (t == "") continue
        if (!(t in seen)) { seen[t] = 1; out[++m] = t }
      }
      if (m == 0) next
      res = ""
      for (i = 1; i <= m; i++) res = res (i > 1 ? "|" : "") out[i]
      print res
      cnt++
    }
    END { if (cnt == 0) print "词库未收录：" w "（建议 append 一条到 data/query-lexicon.md）" }' "$L"
  ;;
esac