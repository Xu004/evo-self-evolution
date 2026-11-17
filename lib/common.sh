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

# 账本路径解析（唯一真相源：所有走 common.sh 的命令都从这取）
# 优先级：EVO_JOURNAL 显式 → 宿主插件目录（开发态真账本）→ 包内 data/journal.md → 默认值
#
# 为什么要有第 3 级：构建期已把默认值改写为 ${EVO_HOME:-$HOME/.evo}/journal.md，
# 但公开快照/本地克隆根本没有宿主插件目录，账本就在包内 data/journal.md。
# 只认两级的话，clone 后第一条 `evo store sync` 就报「账本不存在: /root/.evo/journal.md」
# —— 开箱即坏，且报错信息会把人引向「插件未装」的错误结论。
# 开发态真账本存在时永远命中第 2 级，行为不变。
evo_journal() {
  if [ -n "${EVO_JOURNAL:-}" ]; then
    printf '%s\n' "$EVO_JOURNAL"
  elif [ -f "$EVO_JOURNAL_DEFAULT" ]; then
    printf '%s\n' "$EVO_JOURNAL_DEFAULT"
  elif [ -f "$ROOT/data/journal.md" ]; then
    printf '%s\n' "$ROOT/data/journal.md"
  else
    printf '%s\n' "$EVO_JOURNAL_DEFAULT"
  fi
}

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

# ---- awk 口径（v1.1.1 修，2026-11）----
# 为什么必须有 awkb：`awk` 在不同发行版指向不同实现。
#   Ubuntu 24 = mawk（length/substr 按**字节**）
#   Ubuntu 26 起 ubuntu-latest = gawk 5.3（UTF-8 locale 下按**字符**）
# lib/search.sh 的中文 2-gram 依赖字节语义（汉字 3 字节，每步取 6 字节 = 2 个汉字）。
# 在 gawk 下变成「取 6 个字符」，切片与索引里的 2 汉字对不上 → 中文长句查询 100% MISS。
# 2026-11 CI 实测：Top1 8/10 → 0/10，13 题全 MISS，退出码与日志没有任何异常（静默失效）。
# 修法：LC_ALL=C 强制字节模式，gawk / mawk / busybox awk 行为回归一致。
# 约定：检索链路（lib/search.sh、lib/index.sh、data/cmd/search-eval.sh）的 awk 一律走 awkb。
awkb() { LC_ALL=C awk "$@"; }