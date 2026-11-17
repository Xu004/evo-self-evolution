#!/bin/sh
# dist.sh · 从开发态 skill 生成分发态 skill 目录（默认 ../EVO自进化）  [v0.16.7 新增]
# 口径：与 pack.sh 共用 <skill 根>/.distignore（单一真相源），不维护第二份排除清单。
# 叠加四件事：
#   ① 改写 SKILL.md 的 name / 标题版本 → 分发版是独立 skill 身份，不与开发态重名
#   ② 用空模板覆盖运行期账本（journal/waters/route-*/enum-gaps/retrieval-evalset/memory-index）
#      —— 这些文件在开发态是「本机账本 / 我的记忆条目」，原样分发就是泄露
#   ③ 写 release CHANGELOG.md + data/.dist 标记（C9 备份时效转为 N/A、C12 索引下限降到 0）
#   ④ 绝对路径改写为分发目录自身路径（SHELLS.md / SKILL.md）
# 用法：sh bin/evo dist                     → ../EVO自进化 v1.0.0
#       sh bin/evo dist EVO自进化 1.0.1     → 指定名字与版本
# 幂等：每次整目录重建（rm -rf 目标），绝不叠加旧文件
SRC=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
NAME=${1:-EVO自进化}
VER=${2:-1.0.0}
PARENT=$(dirname "$SRC")
DST=$PARENT/$NAME

case "$DST" in
  "$SRC") echo "!! 目标与源相同，拒绝（dist 不允许原地重建）"; exit 2 ;;
esac
[ -f "$SRC/.distignore" ] || { echo "!! 缺 $SRC/.distignore，拒绝分发（无法保证不泄露账本）"; exit 5; }

# ---------- 1. 前置：源必须过全量门禁 ----------
echo "== 前置：源 skill 全量门禁 =="
sh "$SRC/data/cmd/check.sh" || { echo "!! 源未通过门禁，拒绝分发（先修 FAIL）"; exit 4; }

# ---------- 2. 按 .distignore 口径复制 ----------
# case 的 pattern 不做 pathname expansion，$_p 里的 * 直接按 glob 语义匹配（可跨 /），
# 这正是我们想要的（data/patches/* 要能命中 data/patches/a/b.patch）。
is_excluded() {
  _rel=$1
  while IFS= read -r _p || [ -n "$_p" ]; do
    _p=$(printf '%s' "$_p" | sed 's/[[:space:]]*$//')
    case "$_p" in ''|'#'*) continue ;; esac
    case "$_rel" in $_p) return 0 ;; esac
  done < "$SRC/.distignore"
  return 1
}

echo "== 复制（.distignore 口径）=="
rm -rf "$DST" || exit 3
mkdir -p "$DST" || exit 3
# Android 无 /tmp：优先 $TMPDIR，退到 data/patches（.distignore 已排除，不污染分发包）
TMPD=${TMPDIR:-/tmp}
[ -d "$TMPD" ] && [ -w "$TMPD" ] || TMPD=$SRC/data/patches
mkdir -p "$TMPD" 2>/dev/null
LOG=$TMPD/.evo-dist.$$
( cd "$SRC" && find . -type f ) | sed 's|^\./||' > "$LOG.all"
# fork-ok: 需逐个文件按 .distignore 判定并保留目录结构，约 30 文件级固定小迭代
while IFS= read -r f; do
  if is_excluded "$f"; then
    echo "SKIP $f"
  else
    mkdir -p "$DST/$(dirname "$f")" && cp "$SRC/$f" "$DST/$f" && echo "COPY $f"
  fi
done < "$LOG.all" > "$LOG" 2>&1
N=$(grep -c '^COPY' "$LOG" 2>/dev/null || echo 0)
SK=$(grep -c '^SKIP' "$LOG" 2>/dev/null || echo 0)
grep '^SKIP' "$LOG"
rm -f "$LOG" "$LOG.all"
echo "复制 $N 个文件，排除 $SK 个"
[ "$N" -gt 0 ] || { echo "!! 一个文件都没复制，拒绝"; exit 3; }

# ---------- 3. 改写 SKILL.md：name / 标题版本 / VERSION_HISTORY 引用 ----------
sed -i "s|^name: .*|name: $NAME|" "$DST/SKILL.md" || exit 6
sed -i "s|^# [^ ]* *· *\(.*\) v[0-9][^ ]*$|# $NAME · \1 v$VER|" "$DST/SKILL.md" || exit 6
# 分发态没有 VERSION_HISTORY.md（52KB 开发全链含事故史/原话，.distignore 已排除）→ 引用改写
sed -i 's|^> 版本变更史见 .*|> 版本变更史见 `CHANGELOG.md`。本文件只承载当前生效规则。|' "$DST/SKILL.md"

# ---------- 4. 运行期账本 → 空模板 ----------
mk_tpl() { mkdir -p "$DST/$(dirname "$1")"; printf '%s\n' "$2" > "$DST/$1"; }
mk_tpl data/journal.md        '# 分发版 journal ·初始为空；由 journal-add.sh 追加，勿手改'
mk_tpl data/waters.md         '# 跨对话采集水位 ·初始为空'
mk_tpl data/route-stats.md    '# 路由统计 ·初始为空'
mk_tpl data/route-cache.md    '# 会话级检索缓存 ·易失，初始为空'
mk_tpl data/enum-gaps.md      '# 枚举缺口 ·初始为空'
mk_tpl data/retrieval-evalset.md '# 检索评测集 ·初始为空'
# v1.1：memory-index.md / memory-titles.txt（旧手工索引）已废，改由 bin/evo 从账本派生

# 分发目录里出现任何上一手账本残留 = 泄露，直接拒绝
for _k in journal waters route-stats; do
  _sz=$(wc -c < "$DST/data/$_k.md" 2>/dev/null | tr -d ' ')
  [ "${_sz:-0}" -gt 300 ] && { echo "!! 模板化失败：data/$_k.md 仍有 ${_sz}B 内容"; exit 7; }
done

# ---------- 5. release CHANGELOG + dist 标记 ----------
cat > "$DST/CHANGELOG.md" <<EOF
# CHANGELOG · $NAME

## v$VER (分发版首发)

- 源自开发态 skill 的当前快照（生成器：\`data/cmd/dist.sh\`，口径：\`.distignore\`）
- 功能面：ROUTE 分级读取 / 硬约束 H 表 / 确定性公式 F / journal 账本 / 结构体检 refactor / 门禁 check / 打包 pack
- 分发态差异：
  - 运行期账本为空模板（journal / waters / route-stats / route-cache / enum-gaps / retrieval-evalset）
  - 结构报告未生成 → 首次请跑 \`sh data/cmd/refactor.sh scan\`
  - 备份时效检查 C9 = N/A（\`data/.dist\` 标记）；删掉该标记即恢复强制
  - 检索索引冷启动 0 条；\`sh bin/evo store sync && sh bin/evo index build\` 后自动填充
- 首次上手：
  1. \`sh data/cmd/check.sh\`（应 17/17）
  2. \`sh data/cmd/refactor.sh scan\`
  3. \`sh bin/evo store sync && sh bin/evo index build\`
EOF
printf 'dist\n' > "$DST/data/.dist"

# ---------- 6. 绝对路径改写（指向分发目录自身） ----------
for _d in SKILL.md data/cmd/SHELLS.md; do
  [ -f "$DST/$_d" ] || continue
  sed -i "s|$SRC|$DST|g" "$DST/$_d"
done

# ---------- 7. 生成首份结构报告（开箱即 C13 绿，用户不必先跑 scan） ----------
( cd "$DST" && sh data/cmd/refactor.sh scan > /dev/null 2>&1 )
echo "== 已生成首份 data/refactor-report.md =="

# ---------- 8. 自检：在分发目录里跑门禁 ----------
echo "== 分发目录自检（check.sh 全量）=="
( cd "$DST" && sh data/cmd/check.sh ); RC=$?
if [ "$RC" = "0" ]; then
  echo "== dist 完成：$DST（$N 文件，$VER）ALL GREEN =="
else
  echo "== dist 完成但有 FAIL：$DST（$N 文件，$VER）—— 上面的 FAIL 项需在分发目录里修模板/文档 =="
fi
exit $RC