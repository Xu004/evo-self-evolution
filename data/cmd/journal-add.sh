#!/bin/sh
# journal-add.sh · journal 唯一追加入口（v0.15.1 止血，方向①；v0.16.1 加 TS_OVERRIDE）
# 用法：sh bin/evo journal-add <op> <对象> <内容> [标记]
# 补记历史动作：TS_OVERRIDE='2026-11-10 06:15' sh bin/evo journal-add pack ...（显式指定实际发生时间）
# 路径写死 data/journal.md（杜绝靠记忆拼路径写错文件）；时间戳自动生成；内容含 | 拒绝（防破表）
cd "$(dirname "$0")/../.." || exit 1
J="data/journal.md"
[ -f "$J" ] || { echo "账本不存在: $J"; exit 1; }
OP="$1"; OBJ="$2"; MSG="$3"; MARK="${4:-v✅}"
[ -n "$OP" ] && [ -n "$OBJ" ] && [ -n "$MSG" ] || { echo "用法: journal-add.sh <op> <对象> <内容> [标记]"; exit 1; }
echo "$MSG" | grep -q '|' && { echo "内容含 | 会破坏表结构，请改用·"; exit 1; }
case "$OP" in
  create|update|fix|move|pack|copy|verify|backup|enum|route|run|delete|link|eval|refactor|H1-violation) ;;
  *) echo "非法 op: $OP（合法: create/update/fix/move/pack/copy/verify/backup/enum/route/run/delete/link/eval/refactor/H1-violation）"; exit 1 ;;
esac
if [ -n "$TS_OVERRIDE" ]; then
  TS="$TS_OVERRIDE"
else
  TS=$(date -u -d "@$(( $(date +%s) + 28800 ))" '+%Y-%m-%d %H:%M')
fi
echo "$OP | $OBJ | $TS | $MSG | $MARK" >> "$J"
echo "已落账，尾行："; tail -1 "$J"