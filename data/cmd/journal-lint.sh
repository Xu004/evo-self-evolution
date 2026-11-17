#!/bin/sh
# journal-lint.sh · journal 七查（v0.17.0）
# 真实账本行格式：| 时间 | 类型 | 对象 | 结论 | 验证 |   ← 行首带 |，5 列
# 查1 op 分布；查1b 非法 op；查2 时间戳；查3 create 验证标记；查4 H1-violation 计数；
# 查5 游离账本；查6 野行；查7 三方一致性（账本 / store / index）
#
# v0.17.0 变更（重要）：
#   旧版按 `op | 时间 | 对象 | ...` 解析（无前置管道），与真实账本格式相反 ——
#   结果是「检查空模板 data/journal.md 时全通过，检查真账本时全判野行」。
#   本版：① 按真实 5 列解析（$2=时间 $3=op $4=对象）；② 表头/分隔行豁免；
#          ③ 默认检查权威账本 plugins/com.yg.evo/journal.md，-j PATH 可覆盖；
#          ④ 新增查7：账本/store/index 三方条数 + 对象名集合比对（python3，缺失则跳过）。
#
# 输出契约（check.sh C6 依赖）：违规行一律以 `<行号>: ` 或 `违规：` 开头。
# 用法：sh bin/evo journal-lint  |  sh data/cmd/journal-lint.sh [-j /path/to/journal.md]
cd "$(dirname "$0")/.." 2>/dev/null || cd "$(dirname "$0")" || exit 1

J=""
if [ "$1" = "-j" ]; then J="$2"; fi
if [ -z "$J" ]; then
  if [ -f "../../../plugins/com.yg.evo/journal.md" ]; then
    J="../../../plugins/com.yg.evo/journal.md"
  else
    J="journal.md"
  fi
fi
[ -f "$J" ] || { echo "违规：账本不存在 $J"; exit 1; }

ST="store/journal.tsv"
IX="store/index.tsv"

if [ -f "../journal.md" ]; then
  FREE="违规：存在游离账本 ../journal.md（落账必须走 evo_reflect）"
else
  FREE="无游离账本"
fi

awk -F'|' -v free="$FREE" -v jp="$J" '
function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function bad(arr, n, limit,   i) { for (i = 1; i <= n && i <= limit; i++) print arr[i] }
BEGIN {
  # v0.17.1：补入账本长期在用的 exp / fail / rule / state / decision / project
  #（旧白名单只照 journal-add.sh 的 op 枚举写，导致 exp 等 20+ 条主力记录被判「非法 op」）
  NV = split("create update fix move pack copy verify backup enum route run delete link eval refactor H1-violation exp fail rule state decision project", V, " ")
  for (i = 1; i <= NV; i++) valid[V[i]] = 1
}
{
  line = $0
  if (line ~ /^[ \t]*$/ || line ~ /^#/) next
  if (line ~ /^\|[- \t|:]+\|?[ \t]*$/) next
  if (index(line, "| 时间 |") == 1 || index(line, "|时间|") == 1) next

  if (line !~ /^\|[ \t]*[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][ \t]/) {
    wild[++wn] = NR": "substr(line, 1, 100); next
  }

  ts = trim($2); op = trim($3)
  cnt[op]++
  if (ts != "") rec++

  if (!(op in valid)) { if (!(op in seenop)) { seenop[op] = 1; badop[++bn] = NR": op=" op " | " substr(line, 1, 80) } }

  if (ts !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]$/ &&
      ts !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] \([0-9][0-9]:[0-9][0-9]~[0-9][0-9]:[0-9][0-9]\)$/)
    badts[++tn] = NR": "substr(line, 1, 100)

  if (op == "create")
    if (index(line, "v✅") == 0 && index(line, "v批") == 0 && index(line, "v—") == 0)
      nomark[++mn] = NR": " substr(line, 1, 100)

  if (op == "H1-violation") h1++

  if (trim($5) == "") emptyc[++en] = NR": 结论为空"
}
END {
  printf "=== 查1: op 枚举分布（%d 条记录 / %s）===\n", rec + 0, jp
  # v0.17.1：改为输出「全部出现的 op」并按条数降序（旧版只遍历白名单，
  # 白名单外的 op 在分布里完全隐形，等于统计失灵）
  no = 0
  for (k in cnt) { no++; ks[no] = k }
  for (i = 1; i <= no; i++)
    for (j = i + 1; j <= no; j++)
      if (cnt[ks[j]] > cnt[ks[i]] || (cnt[ks[j]] == cnt[ks[i]] && ks[j] < ks[i])) { t = ks[i]; ks[i] = ks[j]; ks[j] = t }
  for (i = 1; i <= no; i++) printf "%7d %s%s\n", cnt[ks[i]], ks[i], (ks[i] in valid ? "" : "   <-非白名单")
  printf "=== 查1b: 非法 op ===\n"
  if (bn == 0) print "无违规"; else bad(badop, bn, 10)
  printf "=== 查2: 时间戳格式（第2字段应 YYYY-MM-DD HH:MM 或区间形式）===\n"
  if (tn == 0) print "无违规"; else bad(badts, tn, 10)
  printf "=== 查3: create 行验证标记（应含 v✅/v批/v—）===\n"
  if (mn == 0) print "无缺失"; else bad(nomark, mn, 10)
  printf "=== 查4: H1-violation 计数（H1 验收信号，目标 0）===\n%d\n", h1 + 0
  printf "=== 查5: 游离账本检查（skills 根 journal.md 不应存在）===\n%s\n", free
  printf "=== 查6: 野行检查（非空/非注释/非合法记录行 = 格式污染）===\n"
  if (wn == 0 && en == 0) print "无野行"
  else { bad(wild, wn, 20); bad(emptyc, en, 10) }
}
' "$J"

# ── 查7 三方一致性 ─────────────────────────────────────────────
printf "=== 查7: 三方一致性（账本 / store / index）===\n"
if command -v python3 >/dev/null 2>&1; then
python3 - "$J" "$ST" "$IX" <<'PY'
import sys
md, st, ix = sys.argv[1], sys.argv[2], sys.argv[3]

def md_recs(p):
    out = []
    for ln in open(p, encoding='utf-8'):
        if not ln.startswith('|'):
            continue
        f = [x.strip() for x in ln.split('|')]
        if len(f) < 6 or not f[1][:4].isdigit():
            continue
        out.append(f[3])
    return out

def tsv_recs(p, col):
    out = []
    try:
        for ln in open(p, encoding='utf-8'):
            if not ln.strip():
                continue
            f = ln.rstrip('\n').split('\t')
            if len(f) > col:
                out.append(f[col])
    except FileNotFoundError:
        return None
    return out

M = md_recs(md)
S = tsv_recs(st, 2)
I = tsv_recs(ix, 0)
a = len(M)
b = len(S) if S is not None else -1
c = len(I) if I is not None else -1
tag = '一致' if (b == a and c == a) else '不一致'
print(f"账本={a}  store={b}  index={c}  → {tag}")

if S is None:
    print("违规：store/journal.tsv 不存在（先跑 evo store sync）")
else:
    ms, ss = set(M), set(S)
    only_md = [x for x in M if x not in ss][:5]
    only_st = [x for x in S if x not in ms][:5]
    probs = []
    if b != a:
        probs.append(f"账本 {a} ≠ store {b}")
    if c != a:
        probs.append(f"账本 {a} ≠ index {c}")
    if set(M) != set(S):
        probs.append("对象名集合不同")
    if probs:
        print("违规：三方不一致（" + "；".join(probs) + "）")
        if only_md:
            print("违规：仅账本有 → " + " ; ".join(only_md))
        if only_st:
            print("违规：仅store有 → " + " ; ".join(only_st))
        if not only_md and not only_st:
            if b == a and c != a:
                print(f"违规：index 与账本差 {abs(c - a)} 条（store 正常）→ 重跑 evo index build")
            elif b != a:
                print("违规：账本/store 对象名相同但条数不同 → 疑似账本有重复对象名")
    else:
        print("无违规")
PY
else
  echo "跳过（无 python3）"
fi