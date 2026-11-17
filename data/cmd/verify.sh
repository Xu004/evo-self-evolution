#!/bin/sh
# verify.sh · H5 回读验证 diff 判定（v0.15 固化，方向5；首跑修订：支持多对 expect/actual）
# 前置：expect-<title>-YYYYMMDD.txt 与 actual-<title>-YYYYMMDD.txt 已落盘 data/
# 用法：sh bin/evo verify
# 判定：每对 diff 空=通过（并按 v0.15 清理中间文件）；非空=输出差异行，补写后重跑；任一 FAIL 则 exit 2
cd "$(dirname "$0")/.." 2>/dev/null || exit 1
# v0.16.3-dev+：临时目录自适应——Android 无 /tmp（实测 `ls -ld /tmp` → No such file or directory），
# 原版写死 /tmp/exp.tmp 会让本脚本在 Android shell 下整段失败。proot 有 /tmp，行为不变。
TMPD="${TMPDIR:-/tmp}"
[ -d "$TMPD" ] || TMPD=/data/local/tmp
[ -d "$TMPD" ] || TMPD="$(pwd)"
D=$(date +%Y%m%d)
FOUND=0
FAILED=0
   # fork-ok: expect 文件对实测 0~2 对，每轮 PASS 后即删
for E in expect-*-"$D".txt; do
  [ -f "$E" ] || continue
  FOUND=1
  A=$(echo "$E" | sed 's/^expect-/actual-/')
  if [ ! -f "$A" ]; then
    echo "FAIL: $(basename "$E") 缺对应 actual 文件"
    FAILED=1
    continue
  fi
  sort "$E" > "$TMPD/exp.tmp"
  sort "$A" > "$TMPD/act.tmp"
  if diff "$TMPD/exp.tmp" "$TMPD/act.tmp" >/dev/null 2>&1; then
    echo "PASS: $(basename "$E")（diff 空，一致性由 diff 判定）"
    rm -f "$E" "$A"
  else
    echo "FAIL: $(basename "$E") diff 非空，按差异行补写后重跑（禁止放过）"
    diff "$TMPD/exp.tmp" "$TMPD/act.tmp"
    FAILED=1
  fi
done
rm -f "$TMPD/exp.tmp" "$TMPD/act.tmp"
if [ "$FOUND" -eq 0 ]; then
  echo "FAIL: 无 expect 文件（需先按 H5 落盘）"
  exit 1
fi
if [ "$FAILED" -eq 1 ]; then
  echo "结论: 存在 FAIL，按差异行补写后重跑本脚本"
  exit 2
fi
echo "结论: 全部 PASS，中间文件已按 v0.15 生命周期清理"
