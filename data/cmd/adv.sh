#!/bin/sh
# data/cmd/adv.sh · 检索层对抗测试 harness（v0.19）
#
# 用法：sh bin/evo adv [--quiet]
# 判据：逐条跑 `evo search`，比对 退出码 / 必须含 / 必须不含。任一 FAIL → 非 0 退出。
# 纪律：只读。不改账本、不重建索引、不联网。可直接进 CI 门禁。
#
# 为什么要有这个：检索层的加固（空查询/标点/单字符/编号边界/覆盖度/超长/注入）
#   全是「不测就不知道有没有生效」的行为，靠人工点几下必然回归。
#   每次改 lib/search.sh 或 index.tsv 结构，必须先跑本脚本。

ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
T="$ROOT/data/adversarial-tests.tsv"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

PASS=0
FAIL=0
FAILLIST=""
ok()  { PASS=$((PASS + 1)); [ "$QUIET" = "1" ] || printf 'ok    %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); FAILLIST="$FAILLIST
  - $*"; [ "$QUIET" = "1" ] || printf 'FAIL  %s\n' "$*"; }

[ -f "$T" ] || { echo "缺用例集: $T" >&2; exit 1; }

echo "=== EVO adv.sh · 检索层对抗测试 ==="

# ---------- P0 前置：索引必须健康（结构 + 新鲜度）----------
if sh "$ROOT/bin/evo" index check >/tmp/.adv_idx.$$ 2>&1; then
  ok "P0 index check"
else
  bad "P0 index check 未通过：$(tr '\n' ' ' < /tmp/.adv_idx.$$)"
fi
rm -f /tmp/.adv_idx.$$

# ---------- I0 注入副作用检测（canary）----------
# 用例只能比对输出文本，测不出「命令真被执行了」。canary 文件才测得出。
CN=/tmp/.evo_adv_canary.$$
rm -f "$CN"
sh "$ROOT/bin/evo" search "; touch $CN" >/dev/null 2>&1
if [ -f "$CN" ]; then
  bad "I0 注入被执行（canary 出现：query 里的命令跑了）"
  rm -f "$CN"
else
  ok "I0 注入未执行（canary 未出现）"
fi

# ---------- A33 --all 位置无关（v0.21）----------
# 原实现只认 $1；写在后面时 --all 被并进查询词 → 静默降级 Top5 且污染 n。
# 这个 bug 曾让评测脚本对同一题跑出两个不同 rank，靠它才抓到。
O1=$(sh "$ROOT/bin/evo" search '坑44' --all 2>&1 | grep -c 'get_memory_by_title')
O2=$(sh "$ROOT/bin/evo" search --all '坑44' 2>&1 | grep -c 'get_memory_by_title')
O3=$(sh "$ROOT/bin/evo" search '坑44' 2>&1 | grep -c 'get_memory_by_title')
if [ "$O1" = "$O2" ] && [ "$O1" != "0" ]; then
  ok "A33 --all 位置无关（后置=$O1 前置=$O2）"
else
  bad "A33 --all 位置影响结果（后置=$O1 前置=$O2）"
fi
if [ "$O3" -le 5 ] && [ "$O1" -ge "$O3" ]; then
  ok "A33b 默认仍为 Top5（默认=$O3 --all=$O1）"
else
  bad "A33b 默认 limit 异常（默认=$O3 --all=$O1）"
fi

# ---------- 主循环 ----------
N=0
# fork-ok: 用例必须逐条独立执行——每条要单独捕获退出码与 stdout，合批会丢失单条 rc
while IFS='|' read -r id cat q rc must forbid; do
  case "$id" in ''|'#'*) continue ;; esac
  N=$((N + 1))
  IIDX=""

  # 标记展开
  case "$q" in
    '@LONG600') q=$(awk 'BEGIN{for(i=0;i<600;i++)printf "机制"}') ;;
  esac
  # 数据隔离：凡是「断言这个词不该命中」的用例——即 rc=3 的全部 + A13（不校验 rc
  # 但断言 H2 不得命中 H21）——一律跑固定夹具，不跑真实账本。
  # 理由是已经踩了三次：账本里写进「闪退」→ A22 假红；写进「H2 误吞 H21」→ A13 假红；
  # 写进「; ls /」→ A05 假红。真实账本是会增长的生产数据，不能当测试基线。
  # 新增此类用例只要 rc=3 就自动走夹具；新增「期望 HIT」用例则跑真实账本。
  case "$id:$rc" in
    # v0.21：A31/A32 断言的是一条**指定夹具条目**（must=夹具），必须隔离到夹具，
    # 否则真实账本里也有「检查」类词，命中来源不可判定 = 用例测了个寂寞。
    A13:*|A31:*|A32:*|*:3) IIDX="$ROOT/data/adv-fixture.tsv" ;;
  esac
  q=$(printf '%s' "$q" | sed 's/%PIPE%/|/g')

  OUT=$(EVO_INDEX_TSV="$IIDX" sh "$ROOT/bin/evo" search "$q" 2>&1)
  ARC=$?

  BADN=0
  # 1) 退出码
  if [ -n "$rc" ] && [ "$rc" != "any" ] && [ "$ARC" != "$rc" ]; then
    bad "$id [$cat] rc=$ARC 期望 $rc ｜q=[$q]"
    BADN=1
  fi
  # 2) 必须包含
  if [ -n "$must" ]; then
    printf '%s' "$OUT" | grep -qF -- "$must" || { bad "$id [$cat] 输出缺 [$must] ｜q=[$q]"; BADN=1; }
  fi
  # 3) 必须不含
  if [ -n "$forbid" ]; then
    printf '%s' "$OUT" | grep -qF -- "$forbid" && { bad "$id [$cat] 输出含禁词 [$forbid] ｜q=[$q]"; BADN=1; }
  fi

  [ "$BADN" = "0" ] && ok "$id [$cat] $(printf 'q=[%s]' "$q" | cut -c1-40)"
done < "$T"

# ---------- 汇总 ----------
echo "---"
echo "adv: PASS=$PASS FAIL=$FAIL（用例 $N 条）"
if [ "$FAIL" -gt 0 ]; then
  printf '未通过项:%s\n' "$FAILLIST"
  exit 1
fi
exit 0