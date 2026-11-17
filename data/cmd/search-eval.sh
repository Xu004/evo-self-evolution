#!/bin/sh
# data/cmd/search-eval.sh · 账本口径检索评测（只读：不动账本、不动索引、不写账本）
#
# 为什么需要这个文件：bin/evo eval 测的是**平台 query_memory（向量检索）**，我们改不了它的排序；
#   而 lib/search.sh 是我们自己的账本检索，之前**没有任何基准**。
#   没有基准就改评分函数 = 凭感觉优化，分不清「变好」和「碰巧」。
#   （历史教训：v1.3 的 Q13 条目侧加权就是没基准瞎改，rank 4→4 白干。）
#
# 两个用例集，必须**同时**跑：
#   data/search-evalset.tsv        真实问法集（自然语言问句，基线 2/19 —— 测真缺陷）
#   data/search-evalset-simple.tsv 关键词集（基线 20/20 —— 防过拟合回归）
#   只优化前者会让关键词检索退化；只看后者则看不见缺陷。
#
# 判据：index_search --all 输出里，期望片段首次出现的 1-based 排名 = rank；未出现 = 0。
# 指标：Top1 / Top3 / Top5 / MISS / MRR。
#
# 用法: sh data/cmd/search-eval.sh [label] [evalset路径]
# 产物: data/store/search-eval-<label>.txt（派生数据，不进 git）

set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 90
. "$ROOT/lib/common.sh"
. "$ROOT/lib/index.sh"
. "$ROOT/lib/search.sh"

LABEL=${1:-adhoc}
ES=${2:-$ROOT/data/search-evalset.tsv}
[ -f "$ES" ] || die "无评测集：$ES"
store_init
# 无索引时每题都必然 rank=0 —— 静默输出 0/10 和「检索真的退化了」在报告里长得一模一样。
# 这是「满分基线」的对称病：零分基线同样是假信号，宁可直接拦。
[ -s "$STORE/index.tsv" ] || die "无索引：先跑 sh bin/evo index build（否则每题都 rank=0，看起来像检索退化）"
REP="$STORE/search-eval-$LABEL.txt"
TAB=$(printf '\t')
: > "$REP"

TOT=0; H1=0; H3=0; H5=0; MISS=0

# 用整行读 + 手工拆列：read 两个变量时，末行无换行符会丢失整条用例（实测丢第 20 题）。
# fork-ok: 每条用例必须独立起一次 index_search —— 评测对象就是「单次调用」这条路径，
# 合并成一次批处理会让被测对象从 CLI 变成内部函数，测出来的分不再对应真实用法。20 题固定迭代。
while IFS= read -r LINE <&3 || [ -n "${LINE:-}" ]; do
  [ -n "${LINE:-}" ] || { LINE=""; continue; }
  Q=${LINE%%"$TAB"*}
  EXP=${LINE#*"$TAB"}
  LINE=""
  case "${Q:-}" in ''|'#'*) continue ;; esac
  [ -n "${EXP:-}" ] || continue
  [ "$EXP" = "$Q" ] && continue   # 无 TAB 行，跳过

  OUT=$(index_search --all "$Q" 2>/dev/null)
  RANK=$(printf '%s\n' "$OUT" | awk -v e="$EXP" '
    /^[0-9]+\./ { if (index($0, e) > 0) { split($1, a, "."); print a[1]; exit } }')
  RANK=${RANK:-0}

  TOT=$((TOT + 1))
  [ "$RANK" = "1" ] && H1=$((H1 + 1))
  if [ "$RANK" -ge 1 ] 2>/dev/null; then
    [ "$RANK" -le 3 ] && H3=$((H3 + 1))
    [ "$RANK" -le 5 ] && H5=$((H5 + 1))
  else
    MISS=$((MISS + 1))
  fi
  printf 'rank=%-2s  %s\n' "$RANK" "$Q" >> "$REP"
done 3< "$ES"

MRR=$(awk '
  /^rank=/ { r = substr($0, 6) + 0; if (r > 0) s += 1 / r; n++ }
  END { printf "%.4f", (n > 0) ? s / n : 0 }' "$REP")

{
  echo "=== 账本检索评测 · $LABEL · $(basename "$ES") ==="
  cat "$REP"
  echo "---"
  printf 'N=%d  Top1=%d/%d  Top3=%d/%d  Top5=%d/%d  MISS=%d  MRR=%s\n' \
         "$TOT" "$H1" "$TOT" "$H3" "$TOT" "$H5" "$TOT" "$MISS" "$MRR"
} | tee "$STORE/.se.$$"
mv -f "$STORE/.se.$$" "$REP" 2>/dev/null || true
echo "报告已落 $REP"