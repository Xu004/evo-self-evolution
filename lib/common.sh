#!/bin/sh
# lib/common.sh · 公共层（路径解析、日志、原子写）
# 约定：必须先设置 ROOT 再 source 本文件。不自行推导路径，避免 $0 歧义。

[ -n "${ROOT:-}" ] || { echo "evo: ROOT 未设置" >&2; exit 90; }

# 账本真身默认位置（插件运行期数据，非 skill 内部文件）
EVO_JOURNAL_DEFAULT=/sdcard/Download/Operit/plugins/com.yg.evo/journal.md

# 派生数据一律落 data/store/，该目录不进分发包
STORE="$ROOT/data/store"

ok()   { printf 'ok   %s\n' "$*"; }
warn() { printf 'warn %s\n' "$*" >&2; }
fail() { printf 'FAIL %s\n' "$*" >&2; }
die()  { fail "$*"; exit 1; }

evo_journal() { printf '%s\n' "${EVO_JOURNAL:-$EVO_JOURNAL_DEFAULT}"; }

store_init() { mkdir -p "$STORE" 2>/dev/null || die "无法创建 $STORE"; }

# 原子写：派生文件一律先写临时文件再 mv。
# 为什么：重建中途被打断会留下半个文件，下一轮检索直接读到脏数据。
store_tmp() {
  store_init
  T="$STORE/.tmp.$$.${1:-x}"
  : > "$T" || die "临时文件创建失败: $T"
  printf '%s\n' "$T"
}

store_commit() { mv -f "$1" "$2" || die "写入失败: $2"; }

now_str() { date '+%Y-%m-%d %H:%M'; }