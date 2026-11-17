#!/bin/sh
# EVO git-bundle.sh v1.0 · git 历史冷备（只读仓库，只写 data/backup/*.bundle）
# 为什么需要：本仓库用 --separate-git-dir 把 .git 实体放在 ext4（/home/evogit），
#   因为 sdcard 是 FUSE 挂载、无法承载 git 对象库（坑40）。
#   代价：proot rootfs 若被重建，/home 下的 .git 会丢 → bundle 是唯一保险。
# 用法：sh data/cmd/git-bundle.sh [--keep N]     默认保留最近 5 个
# 恢复：git clone data/backup/evo-git-YYYYMMDD.bundle /tmp/evo
#       git -C /tmp/evo log --oneline
# 纪律：不 push、不联网、不改工作树。
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 90
OUTDIR="$ROOT/data/backup"
KEEP=5

while [ $# -gt 0 ]; do
    case "$1" in
        --keep) shift; KEEP=${1:-5}; shift ;;
        *) echo "未知参数: $1" >&2; exit 2 ;;
    esac
done
case "$KEEP" in ''|*[!0-9]*) echo "--keep 需正整数" >&2; exit 2 ;; esac
[ "$KEEP" -ge 1 ] || { echo "--keep 需 >= 1" >&2; exit 2; }

command -v git >/dev/null 2>&1 || { echo "FAIL git 不可用" >&2; exit 3; }
git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1 || { echo "FAIL 仓库无 commit（先 git commit）" >&2; exit 3; }

mkdir -p "$OUTDIR" || exit 3
OUT="$OUTDIR/evo-git-$(date +%Y%m%d).bundle"

# 同日重复跑：先删旧文件（bundle create 拒绝覆盖已存在文件）
rm -f "$OUT"
if ! git -C "$ROOT" bundle create "$OUT" --all >/dev/null 2>&1; then
    echo "FAIL bundle create（仓库或磁盘异常）" >&2
    exit 4
fi
if ! git -C "$ROOT" bundle verify "$OUT" >/dev/null 2>&1; then
    echo "FAIL bundle verify（产物损坏，已删除）" >&2
    rm -f "$OUT"
    exit 5
fi

HEADS=$(git -C "$ROOT" bundle list-heads "$OUT" 2>/dev/null | wc -l | tr -d ' ')
SZ=$(wc -c < "$OUT" | tr -d ' ')
echo "OK  $OUT"
echo "    HEAD $(git -C "$ROOT" rev-parse --short HEAD) · refs $HEADS · ${SZ} B"

# 只留最近 KEEP 个（文件名含日期，字典序即时间序）
LIST=$(ls -1 "$OUTDIR"/evo-git-*.bundle 2>/dev/null | sort -r)
n=0
for f in $LIST; do
    n=$((n + 1))
    [ "$n" -le "$KEEP" ] && continue
    rm -f "$f" && echo "    prune $(basename "$f")"
done
exit 0