#!/bin/sh
# rotate-journal.sh · journal 60 天截断整文件轮转（v0.15 固化，方向8）
# 前置（硬性，按 playbook-truncate.md）：T-7 已核对 H17 双轨备份覆盖；T0 截断窗口行与
#   waters.md/记忆库关键条目交叉比对完成
# 用法：sh bin/evo rotate-journal
# 轮转后手动回写：waters.md 追加截断审计行 + 自进化状态挂账清账
cd "$(dirname "$0")/.." 2>/dev/null || cd "$(dirname "$0")" || exit 1
TS=$(date +%Y%m)
BK=/sdcard/Download/self-evo-backup
[ -d "$BK" ] || mkdir -p "$BK"
mv journal.md "$BK/journal-archive-$TS.txt"
cat > journal.md <<'HEAD'
# journal.md · EVO 变更流水（append-only）
# 规则（H14，v0.10.3 严谨化，v0.15 op 枚举扩充）：
#   1. 每次 create/update/fix/move/pack/copy/verify/backup/enum/route/run/delete/link/eval 后追加一行；只追加，不改写历史行
#   2. 时间戳统一 `YYYY-MM-DD HH:MM`（北京时间，精确到分）
#   3. op 枚举：create / update / fix / move / pack / copy / verify / backup / enum / route / run / delete / link / eval / refactor / H1-violation（v0.16.6 定稿 16 值，delete 独立成 op）
#   4. 摘要末尾附验证标记：v✅=H5 回读验证逐条通过；v批=整批验证未逐条记录；v—=未单独记录
#   5. 时间校准锚点：优先用文件系统 mtime（stat -c '%y'），其次用记忆记录时间，均无则标区间
#   6. 60 天截断 = 整文件轮转（本脚本）；与 append-only 原则一致，禁止删除部分行
#   7. 恢复粒度：单条定位，配合卷级快照使用；本文件仅审计、不对账
HEAD
echo "轮转完成: $BK/journal-archive-$TS.txt"
echo "新 journal.md 已含头部规则；下一步（手动）：waters.md 截断审计行 + 自进化状态挂账清账"