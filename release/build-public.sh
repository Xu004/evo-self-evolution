#!/bin/sh
# ─────────────────────────────────────────────────────────────
# EVO · 生成 GitHub 公开快照
#
# 用法：sh release/build-public.sh [目标目录]
# 默认：<repo>/../EVO-public
#
# 【为什么不用开发仓库的 git】
#   data/backup/journal-*.md 已在 git 追踪里 —— 那是真实账本副本。
#   直接 push = 63 条本机账本（项目名/事故史/决策原话/绝对路径）永久公开。
#   git 历史删不干净：force push 之后 fork、缓存、API 仍可获取。
#   所以：白名单复制 → 全新 git init → 零历史。
#
# 【构建期做三件事，不改开发源码】
#   1. 白名单复制（零泄漏）
#   2. 路径可移植化（否则别人机上跑不起来）
#   3. 独立 git init（单条提交，可复现）
#
# 【仓库名约束】
#   check 的 C0b 要求「目录名 == SKILL.md 的 name」。
#   → GitHub 仓库必须命名为 `EVO自进化`，否则 C0b 红灯。
# ─────────────────────────────────────────────────────────────
set -eu

SRC=$(cd "$(dirname "$0")/.." && pwd)

# 公开快照不能放在 skills/ 下 —— check 的 C0 会把它当成第二个 skill（双真身）。
# 默认落到 skills/ 的上三层（即 /sdcard/Download）旁的兄弟目录。
# --force 必须与输出路径分家：早先直接把 $1 当 OUT，`build-public.sh --force`
# 会把 "--force" 当成目标目录名 → mkdir: unrecognized option '--force/data'。
FORCE=0
OUT=""
for a in "$@"; do
  case "$a" in
    --force) FORCE=1 ;;
    *) OUT="$a" ;;
  esac
done
[ -n "$OUT" ] || OUT="$(cd "$SRC/../../.." && pwd)/EVO-public"

case "$OUT" in
  */skills/*)
    echo "✗ 输出路径不能位于 skills/ 之下：$OUT"
    echo "  check 的 C0 会把公开快照误判为第二个 skill（双真身）。"
    exit 1
    ;;
esac

if [ -e "$OUT" ]; then
  # 发布是高频动作，每次手动 rm 容易变成 rm -rf 手滑；给一个受控的 --force。
  # 守卫：只允许删除名字里带 EVO-public 的目录，且不允许是 /、$HOME、.、.. 这类。
  if [ "$FORCE" = 1 ]; then
    case "$OUT" in
      ""|"/"|"."|".."|"$HOME") echo "✗ 拒绝危险的输出路径：$OUT"; exit 2 ;;
      */EVO-public*) echo "── --force：清理旧产物 $OUT"; rm -rf "$OUT" ;;
      *) echo "✗ --force 只允许用于 */EVO-public* 命名的目标：$OUT"; exit 2 ;;
    esac
  else
    echo "✗ 目标已存在：$OUT"
    echo "  先移走或删除再跑，或加 --force（仅限 */EVO-public* 目标）"
    exit 1
  fi
fi

# 本脚本只产出「工作树」，不建 .git。
# 原因：proot + overlay + FUSE 环境下 git 写对象不可靠（实测 bad object HEAD、
# 自指 symlink、No such file or directory），在此建库只会得到一个坏仓库。
# git 化请在普通 Linux / macOS / Termux 上做，或走 GitHub 网页上传。
DST="$OUT"

echo "源    ：$SRC"
echo "目标  ：$OUT"
echo

mkdir -p "$DST/data"

# ── 1. 规则与代码（必带）────────────────────────────────────
for p in SKILL.md CHANGELOG.md bin lib refs templates; do
  if [ ! -e "$SRC/$p" ]; then echo "✗ 缺少 $p"; exit 1; fi
  cp -r "$SRC/$p" "$DST/$p"
done

# ── 2. data 白名单（不含任何账本实体）──────────────────────
mkdir -p "$DST/data/cmd" "$DST/data/playbook"
cp -r "$SRC/data/cmd/." "$DST/data/cmd/" 2>/dev/null || true
cp -r "$SRC/data/playbook/." "$DST/data/playbook/" 2>/dev/null || true

for f in adversarial-tests.tsv adv-fixture.tsv query-lexicon.md chain.conf; do
  if [ -f "$SRC/data/$f" ]; then cp "$SRC/data/$f" "$DST/data/$f"; fi
done

# 空账本模板（check 的 C6/C7 要求文件存在；内容 0 条目）
if [ -f "$SRC/data/journal.md" ]; then cp "$SRC/data/journal.md" "$DST/data/journal.md"; fi

# 示例账本（10 条通用经验）：开箱可 sync + 可检索 + 可跑评测
if [ -f "$SRC/release/journal.seed.md" ]; then cp "$SRC/release/journal.seed.md" "$DST/data/journal.seed.md"; fi

# 脱敏评测样例（10 题，满足 check C15 的 ≥10 门槛）
if [ -f "$SRC/release/search-evalset-example.tsv" ]; then
  cp "$SRC/release/search-evalset-example.tsv" "$DST/data/search-evalset.tsv"
fi

# ── 3. 文档与工程文件 ──────────────────────────────────────
for f in README.md WHITEPAPER.md LICENSE COMMERCIAL.md CONTRIBUTING.md PUBLISHING.md .gitignore; do
  if [ -f "$SRC/release/$f" ]; then cp "$SRC/release/$f" "$DST/$f"; fi
done
if [ -f "$SRC/.distignore" ]; then cp "$SRC/.distignore" "$DST/.distignore"; fi
if [ -d "$SRC/release/.github" ]; then cp -r "$SRC/release/.github" "$DST/.github"; fi

# ── 4. 权限（FUSE/sdcard 上常丢可执行位）───────────────────
chmod +x "$DST/bin/evo" 2>/dev/null || true
for f in "$DST"/data/cmd/*.sh; do [ -f "$f" ] && chmod +x "$f"; done
for f in "$DST"/data/cmd/*.py; do [ -f "$f" ] && chmod +x "$f"; done

# ── 4.5 路径可移植化 ──────────────────────────────────────
# 开发机上账本落在宿主插件目录 /sdcard/Download/Operit/plugins/com.yg.evo/。
# 公开包必须改成「$EVO_HOME 可覆盖 + $HOME/.evo 兜底」，否则别人 clone 后
# 所有读写账本的工具都指向一个不存在的路径。
#
# 只改 .sh / .py / bin/evo，不改文档（文档里的路径是说明，不是逻辑）。
echo "── 路径可移植化 ──"
PORT_HITS=0
for f in $(find "$DST" -type f \( -name '*.sh' -o -name '*.py' -o -name '*.conf' -o -name 'evo' \) 2>/dev/null); do
  if grep -q '/sdcard/Download/Operit\|/sdcard/Download/self-evo-backup' "$f" 2>/dev/null; then
    sed -e 's|/sdcard/Download/Operit/plugins/com\.yg\.evo|${EVO_HOME:-$HOME/.evo}|g' \
        -e 's|/sdcard/Download/self-evo-backup|${EVO_HOME:-$HOME/.evo}/backup|g' \
        -e 's|/sdcard/Download/Operit|${EVO_HOME:-$HOME/.evo}|g' \
        "$f" > "$f.evo-port" && mv "$f.evo-port" "$f"
    chmod +x "$f" 2>/dev/null || true
    PORT_HITS=$((PORT_HITS + 1))
    echo "  改写 ${f#"$DST"/}"
  fi
done
echo "  累计 ${PORT_HITS} 个文件"

# ── 5. 泄露校验 ───────────────────────────────────────────
echo "── 泄露校验 ──"
BAD=0

# 5.1 账本实体目录/文件不得存在
for p in data/store data/backup data/waters.md data/route-stats.md \
         data/route-cache.md data/enum-gaps.md data/retrieval-evalset.md \
         VERSION_HISTORY.md data/search-evalset-simple.tsv; do
  if [ -e "$DST/$p" ]; then
    echo "✗ 泄露：$p"
    BAD=1
  fi
done

# 5.2 压缩包 / bundle 不得存在
LEAK_PKG=$(find "$DST" \( -name '*.zip' -o -name '*.bundle' \) 2>/dev/null || true)
if [ -n "$LEAK_PKG" ]; then
  echo "✗ 泄露：压缩包"
  echo "$LEAK_PKG" | sed 's/^/     /'
  BAD=1
fi

# 5.3 journal.md 必须 0 条目
# 注意：grep -c 无匹配时「输出 0 且返回 1」，写成 $(.. || echo 0) 会得到 "0\n0"
JL=$(grep -c '^|' "$DST/data/journal.md" 2>/dev/null) || JL=0
echo "  journal.md 条目标记行：$JL（应为 0）"
if [ "$JL" -ne 0 ]; then
  echo "✗ 账本非空 —— 这是真实数据，禁止发布"
  BAD=1
fi

# 5.4 残留本机路径（改写后应为 0）
LEFT=$(grep -rl '/sdcard/Download/Operit' "$DST" 2>/dev/null | sed "s|$DST/||" || true)
if [ -n "$LEFT" ]; then
  echo "  ⚠ 仍有本机路径残留（文档或注释，确认可接受）："
  echo "$LEFT" | sed 's/^/     /'
fi

# 5.5 一次性补丁脚本不得进入分发包
# 2026-11-17 事故：白名单 `cp -r data/cmd/.` 整目录拷贝，6 个 fix-*.py 随公开快照外泄。
# 判据不用「排除清单」（清单必然漏），改用「命名模式 + 正文自述标记」——命名即契约，
# 新增脚本无需回来登记，写错名字也会被它自己的正文抓住。
ONES=$(find "$DST/data/cmd" -maxdepth 1 -name '*.py' 2>/dev/null | while read -r f; do
  b=$(basename "$f")
  case "$b" in
    fix-*.py|*-patch-*.py|*-[0-9][0-9][0-9][0-9].py) echo "$b"; continue ;;
  esac
  grep -q '一次性' "$f" 2>/dev/null && echo "$b"
  :  # set -e：上一句 grep 未命中时返回 1，会让循环体/管道/赋值连环失败并静默中止构建（实测 rc=1 无报错）
done || true)
if [ -n "$ONES" ]; then
  echo "✗ 一次性补丁混入 data/cmd/（应放 data/archive/oneshot/）："
  echo "$ONES" | sed 's/^/     /'
  BAD=1
fi

# 5.6 归档目录不外发（本机运维史 + 硬编码路径）
if [ -e "$DST/data/archive" ]; then
  echo "✗ 泄露：data/archive（本机运维归档）"
  BAD=1
fi

if [ "$BAD" -ne 0 ]; then
  echo
  echo "✗ 校验未通过，已中止（未创建 git）"
  exit 2
fi

# ── 6. 完成（不建 git）─────────────────────────────────────
cd "$DST"

echo
echo "── 结果 ──"
echo "文件数：$(find . -type f | wc -l | tr -d ' ')"
echo "体积  ：$(du -sh . 2>/dev/null | cut -f1)"
echo
echo "下一步（二选一）："
echo
echo "  A. 有 PC / macOS / Termux（推荐，历史干净、可保留可执行位）"
echo "     cd $OUT"
echo "     git init -b main && git add -A"
echo "     git commit -m 'EVO v1.0 · 记忆的 CI · 首个公开快照'"
echo "     git remote add origin git@github.com:<OWNER>/EVO自进化.git"
echo "     git push -u origin main"
echo
echo "  B. 只有手机 —— GitHub 网页上传"
echo "     建仓库 EVO自进化 → Add file → Upload files → 拖入整个目录"
echo "     ⚠ 网页上传不保留可执行位，clone 后需 chmod +x bin/evo data/cmd/*.sh"
echo
echo "注意：仓库名必须是 EVO自进化（check C0b 校验目录名 == frontmatter name）"