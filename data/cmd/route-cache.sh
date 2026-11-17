#!/bin/sh
# route-cache.sh · ROUTE 会话内检索缓存（v0.16.4-dev P0-D2）
# 目的：同一会话重复主题不再重复付检索成本；TTL 到期自动判定过期，不拿旧结果冒充新检索。
# 用法：
#   sh bin/evo route-cache put "<键>" "<标题1;标题2>" [备注]
#   sh bin/evo route-cache get "<键>"     # exit0=命中可用 / exit2=过期需重检 / exit1=无此键
#   sh bin/evo route-cache find "<词>"    # 键+标题+备注 模糊查
#   sh bin/evo route-cache list           # 最近 20 条
#   sh bin/evo route-cache gc [ttl小时]   # 默认 24h
# 存储：data/route-cache.md，行格式 EPOCH<TAB>时间<TAB>键<TAB>标题<TAB>备注
# TTL 判定只用 epoch 差值，不依赖 date -d（mksh/toybox 与 proot GNU date 行为一致）。
# 为什么不写进记忆库：会话级易失缓存写库会污染检索窗口（Q12/Q13 同类挤占问题）。
cd "$(dirname "$0")/../.." || exit 1
C="data/route-cache.md"
TTL=${ROUTE_CACHE_TTL:-24}
touch "$C"
NOW=$(date +%s)

case "$1" in
put)
  K="$2"; T="$3"; NT="${4:-}"
  [ -n "$K" ] && [ -n "$T" ] || { echo "用法: route-cache.sh put <键> <标题1;标题2> [备注]"; exit 1; }
  case "$T" in *'|'*) echo "标题里禁带 |（会破表，改用 ; 分隔多标题）"; exit 1 ;; esac
  awk -F'\t' -v k="$K" '$3 != k' "$C" > "$C.tmp" 2>/dev/null
  mv "$C.tmp" "$C"
  # 人读时间用 CST(+8)，与 journal 口径一致；date -d 不支持时回退本地时间
  TS_STR=$(date -u -d "@$((NOW + 28800))" '+%Y-%m-%d %H:%M' 2>/dev/null) || TS_STR=$(date '+%Y-%m-%d %H:%M')
  printf '%s\t%s\t%s\t%s\t%s\n' "$NOW" "$TS_STR" "$K" "$T" "$NT" >> "$C"
  echo "缓存已写：$K → $T"
  ;;
get)
  K="$2"
  [ -n "$K" ] || { echo "用法: route-cache.sh get <键>"; exit 1; }
  awk -F'\t' -v k="$K" -v now="$NOW" -v ttl="$TTL" '
    $3 == k {
      age = (now - $1) / 3600
      if (age <= ttl) {
        printf "命中 %s（%s，%.1fh 前）\n标题: %s\n备注: %s\n→ 直接 get_memory_by_title，不必再跑 query_memory\n", $3, $2, age, $4, $5
        f = 1
      } else {
        printf "过期 %s（%s，%.1fh > %sh）\n→ 按正常 ROUTE 重检后 put 覆盖\n", $3, $2, age, ttl
        s = 1
      }
    }
    END { if (f) exit 0; if (s) exit 2; exit 1 }' "$C"
  RC=$?
  [ "$RC" -eq 1 ] && echo "无缓存：$K（首次检索，正常执行）"
  exit "$RC"
  ;;
find)
  W="$2"
  [ -n "$W" ] || { echo "用法: route-cache.sh find <词>"; exit 1; }
  awk -F'\t' -v w="$W" -v now="$NOW" -v ttl="$TTL" '
    index(tolower($3 " " $4 " " $5), tolower(w)) {
      age = (now - $1) / 3600
      printf "%s ｜%s（%s）\n   %s\n", (age <= ttl ? "可用" : "过期"), $3, $2, $4
      n++
    }
    END { if (n == 0) print "未命中缓存：" w }' "$C"
  ;;
list)
  awk -F'\t' '{ printf "%s ｜%s ｜%s\n", $2, $3, $4 }' "$C" | tail -20
  ;;
gc)
  T=${2:-$TTL}
  awk -F'\t' -v now="$NOW" -v ttl="$T" '(now - $1) / 3600 <= ttl' "$C" > "$C.tmp"
  mv "$C.tmp" "$C"
  KEEP=$(wc -l < "$C" | tr -d ' ')
  echo "gc 完成，保留 $KEEP 行（ttl ${T}h）"
  ;;
*)
  sed -n '4,11p' "$0"
  ;;
esac