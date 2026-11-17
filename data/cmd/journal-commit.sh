#!/bin/sh
# journal-commit —— reflect 之后的收尾三件套（sync → index → 七查自检）
#
# 用法:
#   sh data/cmd/journal-commit.sh        # 完整：sync + index + 七查
#   sh data/cmd/journal-commit.sh -q     # 静默：只在失败时输出
#
# 退出码:
#   0  三方一致、七查无违规
#   2  七查有违规（已打印）
#   1  等锁超时 / sync 失败
#
# 设计要点:
#   * flock 全局串行：两个终端实例同时跑也不会撕坏 store.tsv / index.tsv
#   * 自动补齐：sync 与 index 条数不等时重试一轮（幂等）
#   * 只读校验：不做任何账本改写，账本只由 evo_reflect 写

# 注意：本脚本以 /bin/sh (dash) 运行，不含 bash 专有语法（set +H 在 dash 下报 Illegal option）
# 路径解析：脚本在 <EVO>/data/cmd/，库根是 <EVO>，账本在 <Operit>/plugins/（上两级）
SELF=$(cd "$(dirname "$0")" && pwd) || exit 1
ROOT=$(cd "$SELF/../.." && pwd) || exit 1
OP=$(cd "$ROOT/../.." && pwd) || exit 1
cd "$ROOT" || exit 1

LED="$OP/plugins/com.yg.evo/journal.md"
LOCKDIR="$ROOT/data/store/.commit.lock.d"
QUIET=0
[ "$1" = "-q" ] && QUIET=1

say() { [ "$QUIET" = "1" ] || echo "$@"; }

# ---- 1. 取锁（mkdir 原子锁，30s 超时；proot 不实现 flock）----
mkdir -p data/store 2>/dev/null
GOT=0
i=0
# fork-ok: 取锁重试循环，正常路径第 1 次即成功，上限 60 次由 30s 超时保护
while [ "$i" -lt 60 ]; do
    if mkdir "$LOCKDIR" 2>/dev/null; then
        echo $$ > "$LOCKDIR/pid"
        GOT=1
        break
    fi
    # 陈锁检测：持锁进程已不存在则清理
    p=$(cat "$LOCKDIR/pid" 2>/dev/null)
    if [ -n "$p" ] && ! kill -0 "$p" 2>/dev/null; then
        rm -rf "$LOCKDIR"
        continue
    fi
    i=$((i + 1))
    sleep 0.5
done
[ "$GOT" = "1" ] || { echo "FAIL: 等锁超时 30s（确认无进程后 rm -rf $LOCKDIR）"; exit 1; }
trap 'rm -rf "$LOCKDIR" 2>/dev/null' EXIT INT TERM HUP

[ -f "$LED" ] || { echo "FAIL: 账本不存在 $LED"; exit 1; }

cnt() { printf '%s' "$1" | grep -o '[0-9][0-9]* 条' | head -1 | grep -o '[0-9][0-9]*'; }

# ---- 2. sync ----
out1=$(sh bin/evo store sync 2>&1); rc1=$?
n1=$(cnt "$out1")
if [ $rc1 -ne 0 ] || [ -z "$n1" ]; then
    echo "FAIL: store sync 失败"; printf '%s\n' "$out1"; exit 1
fi
say "ok  sync  → $n1 条"

# ---- 3. index ----
out2=$(sh bin/evo index build 2>&1); rc2=$?
n2=$(cnt "$out2")
if [ $rc2 -ne 0 ] || [ -z "$n2" ]; then
    echo "FAIL: index build 失败"; printf '%s\n' "$out2"; exit 1
fi
say "ok  index → $n2 条"

# ---- 4. 条数不等则重试一轮（幂等自愈）----
if [ "$n1" != "$n2" ]; then
    say "warn: sync($n1) ≠ index($n2)，重试一轮"
    sh bin/evo store sync >/dev/null 2>&1
    sh bin/evo index build >/dev/null 2>&1
fi

# ---- 5. 七查（只取查7 结论 + 违规汇总）----
report=$(sh data/cmd/journal-lint.sh -j "$LED" 2>&1)
q7=$(printf '%s\n' "$report" | sed -n '/=== 查7/,$p')
viol=$(printf '%s\n' "$report" | grep -c '^违规')

printf '%s\n' "$q7" | grep -q '一致' && say "ok  查7 三方一致"

if [ "$viol" -gt 0 ]; then
    echo "VIOLATION: 七查共 $viol 条违规"
    printf '%s\n' "$report" | grep -E '^违规|^=== 查' 
    exit 2
fi

say "OK  commit 完成：账本 $n1 / store $n1 / index $n1，七查无违规"
exit 0