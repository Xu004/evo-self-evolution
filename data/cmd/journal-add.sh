#!/bin/sh
# journal-add.sh · 插件账本（表式）唯一追加入口 · v1.0
# 格式：| 时间 | 类型 | 对象 | 结论 | 验证 |   —— 与 plugin-lint.sh / check.sh C6 同源
# 用法：sh bin/evo journal-add <类型> <对象> <结论> [验证标记]
# 补记：TS_OVERRIDE='2026-11-10 06:15' sh bin/evo journal-add ...（显式指定实际发生时间）
# 纪律：
#   1) 类型枚举取自 data/cmd/ledger-enum.conf，本文件不写死（单一真源）
#   2) 结论含 | 一律拒绝（防破表）
#   3) 默认验证标记为「未验证」——没有可核验证据就不许自封 v✅（H 挂账纪律）
#   4) 只写插件账本（真身）；data/journal.md 已于坑22 废弃，不再写入
cd "$(dirname "$0")/../.." || exit 1

CONF="data/cmd/ledger-enum.conf"
[ -f "$CONF" ] || { echo "类型真源缺失: $CONF"; exit 1; }
. "./$CONF"

J="${EVO_PLUGIN_JOURNAL:-/sdcard/Download/Operit/plugins/com.yg.evo/journal.md}"
# 公开快照/本地克隆：宿主插件目录不存在时回落到包内账本 data/journal.md
# （仅当用户未显式指定时生效；开发态真账本存在则此块不动）
if [ -z "${EVO_PLUGIN_JOURNAL:-}" ] && [ ! -f "$J" ]; then
  _r=$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)
  [ -f "$_r/data/journal.md" ] && J="$_r/data/journal.md"
  :
fi

[ -f "$J" ] || { echo "账本不存在: $J"; exit 1; }

OP="$1"
OBJ="$2"
MSG="$3"
MARK="${4:-未验证}"

[ -n "$OP" ] && [ -n "$OBJ" ] && [ -n "$MSG" ] || {
    echo "用法: journal-add.sh <类型> <对象> <结论> [验证标记]"
    echo "可用类型: $LEDGER_ENUM"
    exit 1
}

case " $LEDGER_ENUM " in
    *" $OP "*) ;;
    *) echo "非法类型: $OP（合法: $LEDGER_ENUM）"; exit 1 ;;
esac

echo "$MSG" | grep -q '|' && { echo "结论含 | 会破坏表结构，请改用 ·"; exit 1; }

if [ -n "${TS_OVERRIDE:-}" ]; then
    TS="$TS_OVERRIDE"
else
    TS=$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M')
fi

printf '| %s | %s | %s | %s | %s |\n' "$TS" "$OP" "$OBJ" "$MSG" "$MARK" >> "$J"
echo "已落账，尾行："
tail -1 "$J"