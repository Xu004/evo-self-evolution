#!/bin/sh
# pack.sh · zip 打包字节收敛（v0.15 固化；v0.16.3-dev+ 加 --fast；v0.16.3-dev++ 加 .distignore + 产物自检）
# v0.16.7：全路径自定位 —— ROOT 由 $0 推导，开发态(EVO) 与分发态(EVO自进化) 打包互不干扰，产物名随目录名
# 前置：SKILL.md/文档已改完落盘；zip 在 PATH
#   ⚠ 必须在 proot(Ubuntu) 里跑：Android shell 无 zip（已实测 toybox 0.8.9 不含 zip）
# 用法：sh bin/evo pack        三轮等长收敛（约 3.5s）—— 发布/报价前必跑
#       sh bin/evo pack --fast 单轮打包（约 1.2s）—— 日常核对内容与体积
# 收敛判定：最多 3 轮等长回填；N2=N3 时取最后一轮
# 排除清单：<skill 根>/.distignore（单一真相源）；产物自检 guard_pkg 硬编码兜底
ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
SKILL_DIR=$(dirname "$ROOT")
NAME=$(basename "$ROOT")
OUT_DIR=$ROOT
FAST=0
case "$1" in --fast|-f) FAST=1 ;; esac

# v0.16.3 前置闸门（P2）：check.sh 未过即拒绝打包，避免「改了没生效/带着污染发布」
if [ "$FAST" = "1" ]; then
  sh "$(dirname "$0")/check.sh" --fast || { echo "!! check.sh --fast 未通过，拒绝打包（见上一条输出）"; exit 4; }
else
  sh "$(dirname "$0")/check.sh" || { echo "!! check.sh 未通过，拒绝打包（见上一条输出）"; exit 4; }
fi

# ---------- v0.16.3-dev++：分发排除清单 ----------
# 背景：旧版把 data/journal.md(33KB) 等本机账本打进包 → 绝对路径/项目名/事故史随包外发。
# 做法：.distignore 每行 → -x '<NAME>/<glob>'；子 shell 里 set -f，防 shell 抢先展开通配。
DIST_IGNORE="$ROOT/.distignore"
XOPTS=""
if [ -f "$ROOT/data/.dist" ]; then
  # v0.16.8 分发态打包：账本是空模板（30~75 B），必须随包 ——
  # 否则解压后 journal.md / waters.md 缺失，C6/C7 直接拿不到文件（装完就不绿）。
  # 清单内联，不复用 .distignore：后者为开发态而写，它的职责是「绝不外发真实账本」，
  # 两者语义相反，混用哪边都会错。
  echo "模式: 分发态（data/.dist 存在）→ 分发包排除清单（保留空账本模板）"
  # v1.1：data/store/* 是 C 档引擎的运行期派生镜像（journal.tsv / index.tsv / alias.tsv），
  # 与开发态 .distignore 各自维护一套清单 —— 两处都必须列，少一处就会把账本正文打进包。
  # 实测：只加 .distignore 时，guard_pkg 抓到 journal.tsv(6704B) + index.tsv(11261B) 漏进包。
  # v1.1：分发态排除清单补齐「本机现场」三类 —— 它们的『空模板』没有任何运行价值：
  #   retrieval-evalset.md 的期望标题就是账本标题（随包=泄漏）；memory-titles.txt 是旧手工清单（已废）；
  #   route-cache.md 是会话级检索现场。三者分发后首跑由脚本自建。
  # 同一个目录还在开发态根 .distignore 里维护，两处都必须列（实测只加一处时 guard 抓到 1554B 题库漏包）。
  for _l in 'data/eval-runs/*' 'data/patches/*' 'data/store/*' 'data/retrieval-evalset.md' 'data/memory-titles.txt' 'data/route-cache.md' '*.zip' '*.zip.bak*' '*.bak-*' '.DS_Store' 'data/route-cache.md.tmp'; do
    XOPTS="$XOPTS -x $NAME/$_l"
  done
  echo "排除项: 5 条（内置分发包清单）"
else
  if [ ! -f "$DIST_IGNORE" ]; then
    echo "!! 缺 $DIST_IGNORE —— 无法保证不泄露账本，拒绝打包"
    exit 5
  fi
  while IFS= read -r _l || [ -n "$_l" ]; do
    _l=$(printf '%s' "$_l" | sed 's/[[:space:]]*$//')
    case "$_l" in ''|'#'*) continue ;; esac
    XOPTS="$XOPTS -x $NAME/$_l"
  done < "$DIST_IGNORE"
  echo "排除项: $(printf '%s' "$XOPTS" | grep -o ' -x ' | wc -l) 条（来自 .distignore）"
fi

pack_zip() {
  ( cd "$SKILL_DIR" && set -f && zip -q -r "$OUT_DIR/$NAME.zip" "$NAME" $XOPTS )
}

# ---------- 产物自检：运行期账本兜底（不依赖 .distignore 内容）----------
# v0.16.7：判据从「出现即失败」改成「非空即失败」——分发态带的是空模板（几行注释），
# 不该被当成泄露；开发态的真实账本（数万字）依然会被抓住。
guard_pkg() {
  # v1.1：C 档引擎把账本派生成 data/store/*.tsv，原判据只认 .md，
  # tsv 镜像（含全部结论正文）即使漏进包也不会被抓 → 补齐扩展名。
  CAND=$(unzip -l "$OUT_DIR/$NAME.zip" 2>/dev/null | awk '{print $4}' \
         | grep -E '(^|/)(journal|waters|route-stats|enum-gaps|retrieval-evalset)\.md$|(^|/)(journal|index|alias)\.tsv$')
  BAD=""
  for _f in $CAND; do
    _sz=$(unzip -p "$OUT_DIR/$NAME.zip" "$_f" 2>/dev/null | wc -c | tr -d ' ')
    [ "${_sz:-0}" -gt 300 ] && BAD="$BAD $_f(${_sz}B)"
  done
  if [ -n "$BAD" ]; then
    echo "!! 产物自检 FAIL：包内出现非空运行期账本 ->"
    echo "$BAD"
    rm -f "$OUT_DIR/$NAME.zip"
    echo "!! 已删除该 zip，拒绝交付（查 .distignore / XOPTS 是否生效）"
    exit 5
  fi
  echo "guard: $(unzip -l "$OUT_DIR/$NAME.zip" | tail -1 | awk '{print $2}') files / $(stat -c %s "$OUT_DIR/$NAME.zip") B，非空账本 0 项 OK"
}

# v0.15 首跑教训：zip -r + -x 不会删除 zip 内旧条目（残留文件带进包），必须先 rm 全新打包
rm -f "$OUT_DIR/$NAME.zip"

# 第1轮
pack_zip
N1=$(stat -c %s "$OUT_DIR/$NAME.zip")
echo "N1=$N1"
guard_pkg

if [ "$FAST" = "1" ]; then
  echo "fast: 单轮打包完成 $N1 B（未做等长收敛校验；发布/报价前请跑无参数三轮）"
  exit 0
fi

# 第2轮（等长回填）
pack_zip
N2=$(stat -c %s "$OUT_DIR/$NAME.zip")
echo "N2=$N2"
# 第3轮
pack_zip
N3=$(stat -c %s "$OUT_DIR/$NAME.zip")
echo "N3=$N3"

if [ "$N2" = "$N3" ]; then
  echo "收敛: 最终 $N3 B（N1=$N1 N2=$N2 N3=$N3）"
else
  echo "警告: 3 轮未收敛，按命令化三条挂账记「压缩漂移」并停止迭代（N1=$N1 N2=$N2 N3=$N3）"
  exit 3
fi