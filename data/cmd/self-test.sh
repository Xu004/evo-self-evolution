#!/bin/sh
# EVO self-test.sh v1.0 · 脚本存活自测（只读，不改任何数据）
# 用途：每次改动 data/cmd/ 或 bin/evo 前后各跑一次；FAIL 非 0 退出即视为不可提交。
# 用法：sh data/cmd/self-test.sh [--quiet]
# 纪律：本脚本禁止写账本、禁止触发 autoDream、禁止联网。

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CMD="$ROOT/data/cmd"
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

PASS=0
FAIL=0
FAILLIST=""

ok() { PASS=$((PASS + 1)); [ "$QUIET" = "1" ] || printf 'ok    %s\n' "$*"; }
bad() { FAIL=$((FAIL + 1)); FAILLIST="$FAILLIST
  - $*"; [ "$QUIET" = "1" ] || printf 'FAIL  %s\n' "$*"; }

echo "=== EVO self-test.sh · $ROOT ==="

# ---------- T0 环境自检 ----------
command -v git >/dev/null 2>&1 && ok "T0 git 可用" || bad "T0 git 不可用"
command -v python3 >/dev/null 2>&1 && ok "T0 python3 可用" || bad "T0 python3 不可用"

# ---------- T1 shell 脚本语法（sh -n） ----------
for f in "$CMD"/*.sh "$ROOT/bin/evo"; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    if sh -n "$f" 2>/dev/null; then
        ok "T1 语法 $b"
    else
        bad "T1 语法 $b（sh -n 报错）"
    fi
done

# ---------- T2 python 脚本语法（compile，不落 __pycache__） ----------
for f in "$CMD"/*.py; do
    [ -f "$f" ] || continue
    b=$(basename "$f")
    if python3 -c "import sys;compile(open(sys.argv[1],encoding='utf-8').read(),sys.argv[1],'exec')" "$f" 2>/dev/null; then
        ok "T2 语法 $b"
    else
        bad "T2 语法 $b（compile 失败）"
    fi
done

# ---------- T3 入口可执行 ----------
# 注：/sdcard 为 FUSE 挂载，chmod +x 不生效，调用方式固定为 `sh bin/evo`，
# 故判据为「shebang 就位」而非执行位，避免环境性假 FAIL。
if [ -f "$ROOT/bin/evo" ] && head -1 "$ROOT/bin/evo" | grep -q '^#!.*sh'; then
    ok "T3 bin/evo 可调用（shebang 就位）"
else
    bad "T3 bin/evo 缺失或 shebang 非 sh"
fi
if [ -f "$CMD/SHELLS.md" ]; then ok "T3 SHELLS.md 索引存在"; else bad "T3 SHELLS.md 缺失（脚本索引真源）"; fi

# ---------- T4 只读冒烟：check --fast ----------
STLOG=/tmp/.evo_selftest_check.log
if sh "$ROOT/bin/evo" check --fast >"$STLOG" 2>&1; then
    ok "T4 check --fast 通过"
else
    bad "T4 check --fast 未通过（日志 $STLOG）"
fi

# ---------- T5 版本控制就绪 ----------
if [ -e "$ROOT/.git" ] && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    ok "T5 git 仓库就绪"
else
    bad "T5 git 仓库缺失（改动将不可回滚）"
fi

# ---------- T6 一次性补丁脚本不许滞留 ----------
n=$(find "$ROOT/data" -maxdepth 1 -name '.*.py' 2>/dev/null | wc -l | tr -d ' ')
if [ "$n" = "0" ]; then ok "T6 无一次性 .py 残留"; else bad "T6 一次性 .py 残留 $n 个（须转正到 data/cmd/ 或删除）"; fi

# ---------- T7 运行期产物不得入库 ----------
if [ -f "$ROOT/.gitignore" ]; then
    miss=""
    for pat in 'data/heartbeat/' 'data/waters.md' '*.zip' 'data/.*.py'; do
        grep -qF "$pat" "$ROOT/.gitignore" || miss="$miss $pat"
    done
    if [ -z "$miss" ]; then ok "T7 .gitignore 覆盖运行期产物"; else bad "T7 .gitignore 缺规则:$miss"; fi
else
    bad "T7 .gitignore 不存在"
fi

# ---------- 汇总 ----------
echo "---"
echo "self-test: PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
    printf '未通过项:%s\n' "$FAILLIST"
    exit 1
fi
exit 0