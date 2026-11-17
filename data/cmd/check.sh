#!/bin/sh
# check.sh · EVO 硬约束门禁（v0.16.3-dev+：跨 shell 一致 + --fast + 合并 grep）
# 用法：sh bin/evo check           全量 18 项（封版 / pack.sh 前置）
#       sh bin/evo check --fast    快检 4 项（C0 / C0b / C4 / C5，日常编辑后）
# 退出码：0=全过 1=有 FAIL
# 定位：pack.sh 的前置闸门。只做「可机械判定」的检查，不判语义。
#
# v0.16.3-dev+ 三处变更：
#   a) C0b 原用 [ "$ROOT" = "$CANON" ] 字符串比路径：mksh 的 pwd 返回 /storage/emulated/0/...，
#      proot 返回 /sdcard/...，同一目录被判「非权威」→ 同一份代码在两种 shell 下结论相反。
#      改为三重判定：字符串 → inode(stat -c %i) → readlink -f，任一成立即算通过。
#      inode 是「同一目录」的真实判据，与实际路径写法无关。
#   b) C2/C3 合并为一次 grep -oE（原两组各 3 进程），两个 chk 计数保留不变。
#   c) 新增 --fast：只跑真身/版本/description 四项，约 0.2s。
#
# 由来（11-12 事故清单）：
#   ① 双真身——同一 skill 在两处目录各自分叉，一整天改动打在假身上
#   ② 更名残留——lint/rotate 两处旧别名未随回滚清洗
#   ③ 文档引用悬浮——SKILL.md 引用的脚本/细则可能已被删或改名
#   ④ description 膨胀——变更史塞进技能匹配字段，每轮对话都付费
#   ⑤ 版本号漂移——标题版本与 CHANGELOG 首条不一致
#   ⑥ 账本无限增长——无轮转触发信号
cd "$(dirname "$0")/../.." 2>/dev/null || exit 1
ROOT=$(pwd)
# v0.16.7 多实例改造：权威目录 = 本脚本所在 skill 根（自定位），不再硬编码路径。
# 开发态 EVO 与分发态 EVO自进化 并存时，各自以自身根为权威，互不判「非权威」。
SKILLS_ROOT=$(dirname "$ROOT")
FAST=0
case "$1" in --fast|-f) FAST=1 ;; esac
FAIL=0
TOTAL=0
SKIPPED=0

fail() { echo "FAIL  $*"; FAIL=$((FAIL + 1)); }
ok()   { echo "ok    $*"; }
chk()  { TOTAL=$((TOTAL + 1)); }
# 跳过项从分母里扣除并单独计数：--fast 只跑 4 项就报 4/4，不许拿 11/11 充数
skip() { TOTAL=$((TOTAL - 1)); SKIPPED=$((SKIPPED + 1)); echo "skip  $*（--fast 跳过）"; }

MODE="全量"
[ "$FAST" = "1" ] && MODE="--fast 快检"
echo "=== EVO check.sh · $ROOT · $MODE ==="

# ---------- C0 单例（v0.16.7：从「固定假身路径」升级为「skill 根下身份名不得重复」）----------
# 旧判据只抓 11-12 那次事故的特定路径；新判据抓「任何位置的同名副本」。
# 顺带守住分发版：若分发目录忘了改 frontmatter name，这里立刻报重名。
chk
# 无临时文件实现（Android 无 /tmp）：skill 数量是个位数，双重循环成本可忽略，
# 而写 /tmp 失败会让检测静默变成「无重复」——假绿比慢更贵。
DUP=""
# fork-ok: skill 数为个位数；重名检测必须逐个读 SKILL.md 的 name 字段，无法合并为单进程
for _a in "$SKILLS_ROOT"/*/SKILL.md; do
  [ -f "$_a" ] || continue
  _na=$(sed -n 's/^name:[[:space:]]*//p' "$_a" 2>/dev/null | head -1)
  [ -z "$_na" ] && continue
  for _b in "$SKILLS_ROOT"/*/SKILL.md; do
    [ "$_a" = "$_b" ] && continue
    [ -f "$_b" ] || continue
    _nb=$(sed -n 's/^name:[[:space:]]*//p' "$_b" 2>/dev/null | head -1)
    if [ "$_na" = "$_nb" ]; then
      case "$DUP" in *" $_na("*) ;; *) DUP="$DUP $_na($_a ↔ $_b)" ;; esac
    fi
  done
done
if [ -n "$DUP" ]; then
  fail "C0 双真身：$SKILLS_ROOT 下 skill 名重复 → $DUP"
else
  ok "C0 单例检查：skill 名无重复，无重复副本"
fi

# ---------- C0b 目录名 = 身份名（v0.16.7 取代「ROOT 必须等于硬编码路径」）----------
# 旧判据要求 ROOT 必等于硬编码路径：多实例一建就 FAIL；现改为「目录名=name」校验。
# 新判据：目录名必须等于 SKILL.md 的 name —— 防「复制目录改名、frontmatter 没换」，那正是真身分叉的起点。
chk
MYNAME=$(sed -n 's/^name:[[:space:]]*//p' SKILL.md 2>/dev/null | head -1)
BNAME=$(basename "$ROOT")
if [ -z "$MYNAME" ]; then
  fail "C0b 无法解析 SKILL.md 的 name 字段"
elif [ "$MYNAME" = "$BNAME" ]; then
  ok "C0b 身份一致：目录名 = name = $MYNAME"
else
  fail "C0b 目录名($BNAME) ≠ SKILL.md name($MYNAME)：改名须同步 frontmatter"
fi

# ---------- C1 更名残留（只查活动文件，历史三件豁免）----------
chk
if [ "$FAST" = "1" ]; then skip "C1 更名残留"
else
  BAD="莫"; BAD="${BAD}离"
  # v0.16.5：memory-index.md / memory-titles.txt 是平台条目标题的逐字镜像（含历史事件标题里的该词），
  # 不是本仓撰写的文本，故与历史三件同等豁免；豁免范围必须写在这里，不许宽化成「data/ 全豁免」。
  # v1.1：data/store/ 是账本正文的派生镜像（C 档引擎产出），同样是「数据的镜像」而非本仓文本，
  # 且已在 .distignore 中排除、不进分发包，属运行期数据，不参与命名残留扫描。
  # v1.2：data/backup/ 是账本与 waters 的历史快照（H17 双轨产物），逐字复制历史行，
  # 必然携带历史用词，性质等同 data/store/ 的镜像，不参与扫描；豁免精确到目录，不宽化。
  RESID=$(grep -rl "$BAD" . 2>/dev/null | grep -vE '\./(journal\.md|data/journal\.md|data/waters\.md|data/route-cache\.md|data/memory-index\.md|data/memory-titles\.txt|CHANGELOG\.md|VERSION_HISTORY\.md)$|^\./data/(store|backup)/')
  if [ -n "$RESID" ]; then
    fail "C1 更名残留（$BAD）在活动文件：$(echo "$RESID" | tr '\n' ' ')"
  else
    ok "C1 更名残留检查：活动文件干净"
  fi
fi

# ---------- C2/C3 SKILL.md 引用的脚本与细则必须存在（一次扫描，两个计数）----------
REFS=$(grep -oE 'data/(cmd/[A-Za-z0-9_-]+\.sh|playbook/[A-Za-z0-9_-]+\.md)' SKILL.md 2>/dev/null | sort -u)

chk
if [ "$FAST" = "1" ]; then skip "C2 脚本引用"
else
  MISS=""; N=0
  for f in $REFS; do
    case "$f" in data/cmd/*) N=$((N + 1)); [ -f "$f" ] || MISS="$MISS $f" ;; esac
  done
  if [ -z "$MISS" ]; then
    ok "C2 脚本引用全部落地（$N 个引用 / $(ls data/cmd/*.sh 2>/dev/null | wc -l) 个脚本）"
  else
    fail "C2 SKILL.md 引用但不存在:$MISS"
  fi
fi

chk
if [ "$FAST" = "1" ]; then skip "C3 细则引用"
else
  MISS=""; N=0
  for f in $REFS; do
    case "$f" in data/playbook/*) N=$((N + 1)); [ -f "$f" ] || MISS="$MISS $f" ;; esac
  done
  if [ -z "$MISS" ]; then
    ok "C3 细则引用全部落地（$N 个引用）"
  else
    fail "C3 SKILL.md 引用但不存在:$MISS"
  fi
fi

# ---------- C4 标题版本 vs CHANGELOG 首条 ----------
chk
SV=""; CV=""
[ -f SKILL.md ] && SV=$(awk '/^# / { for (i = 1; i <= NF; i++) if ($i ~ /^v[0-9]/) { print $i; exit } }' SKILL.md)
[ -f CHANGELOG.md ] && CV=$(awk '/^## v[0-9]/ { print $2; exit }' CHANGELOG.md)
SVB="${SV%-dev}"; CVB="${CV%-dev}"
if [ -z "$SV" ] || [ -z "$CV" ]; then
  fail "C4 版本号解析失败（SKILL='$SV' CHANGELOG='$CV'）"
elif [ "$SVB" = "$CVB" ]; then
  ok "C4 版本一致：$SV（CHANGELOG 首条 $CV）"
else
  fail "C4 版本漂移：SKILL.md=$SV / CHANGELOG.md=$CV"
fi

# ---------- C5 description 长度上限（防变更史回灌）----------
# 保留 wc -m 口径：字符数，不随 awk 实现（字节数/字符数）漂移
chk
DL=$(sed -n 's/^description: //p' SKILL.md | head -1 | wc -m)
if [ "$DL" -gt 400 ]; then
  fail "C5 description $DL 字符 > 400（变更史应进 CHANGELOG.md，不许塞技能匹配字段）"
else
  ok "C5 description $DL 字符（上限 400）"
fi

# ---------- C6 账本格式（v1.1：真身优先 —— 插件账本 > skill 镜像）----------
# 起因（11-13）：原 C6 只查 skill 内的 data/journal.md（分发态是 1 行模板），
#   而真实沉淀在插件 com.yg.evo 的 journal.md（表式）。空文件报绿 = 零信息量。
# 规则：① 插件账本有数据 → plugin-lint.sh（表式）
#       ② 否则 skill 镜像有数据 → journal-lint.sh（行式）
#       ③ 两者都空 → n/a（不再 ok），分母同步减 1
na() { TOTAL=$((TOTAL - 1)); SKIPPED=$((SKIPPED + 1)); echo "n/a   $*"; }
chk
PJ="${EVO_PLUGIN_JOURNAL:-/sdcard/Download/Operit/plugins/com.yg.evo/journal.md}"
PJ_ROWS=0
[ -f "$PJ" ] && PJ_ROWS=$(grep -cE '^[|][[:space:]]*[0-9][0-9][0-9][0-9]-' "$PJ" 2>/dev/null | head -1)
PJ_ROWS=${PJ_ROWS:-0}
PRIV=${EVO_PRIVATE_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)/.evo-private}; MIRROR_ROWS=$(grep -c " | " "$PRIV/journal.mirror.md" 2>/dev/null)
MIRROR_ROWS=${MIRROR_ROWS:-0}
if [ "$FAST" = "1" ]; then skip "C6 账本格式"
elif [ "$PJ_ROWS" -gt 0 ] && [ -f data/cmd/plugin-lint.sh ]; then
  LO=$(sh data/cmd/plugin-lint.sh "$PJ" 2>&1)
  if echo "$LO" | grep -qE '^违规：|^[0-9]+: '; then
    fail "C6 插件账本报问题（真身 $PJ_ROWS 条）：$(echo "$LO" | grep -E '^违规：|^[0-9]+: ' | head -3 | tr '\n' ';')"
  else
    ok "C6 账本格式通过｜真身=插件账本 $PJ_ROWS 条"
  fi
elif [ "$MIRROR_ROWS" -gt 0 ] && [ -f data/cmd/journal-lint.sh ]; then
  LO=$(sh data/cmd/journal-lint.sh 2>&1)
  if echo "$LO" | grep -qE '^违规：|^[0-9]+: '; then
    fail "C6 journal-lint 报问题：$(echo "$LO" | grep -E '^违规：|^[0-9]+: ' | head -3 | tr '\n' ';')"
  else
    ok "C6 账本格式通过｜来源=skill 镜像 $MIRROR_ROWS 行"
  fi
elif [ ! -f data/journal.md ] || [ ! -f data/waters.md ]; then
  fail "C6 账本文件缺失（journal.md / waters.md 必须在包内，空模板也算文件）"
else
  na "C6 无运行期账本（插件账本未挂载，镜像是分发空模板）"
fi

# ---------- C7 账本规模 → 轮转提醒（v1.1：跟 C6 同源）----------
chk
if [ "$FAST" = "1" ]; then skip "C7 账本规模"
elif [ "$PJ_ROWS" -gt 0 ]; then
  if [ "$PJ_ROWS" -ge 300 ]; then
    fail "C7 插件账本 $PJ_ROWS 条 ≥300：该轮转（人工核对 H17 备份后跑 rotate-journal.sh）"
  else
    ok "C7 账本规模 $PJ_ROWS 条（真身=插件账本，阈值 300）"
  fi
elif [ ! -f data/journal.md ]; then
  fail "C7 data/journal.md 缺失，无法判规模"
else
  JL=$(wc -l < data/journal.md | tr -d ' ')
  if [ "$MIRROR_ROWS" -gt 0 ]; then
    if [ "$JL" -ge 300 ]; then
      fail "C7 journal $JL 行 ≥300：该轮转（人工核对 H17 备份后跑 rotate-journal.sh）"
    else
      ok "C7 账本规模 $JL 行（来源=skill 镜像，阈值 300）"
    fi
  else
    na "C7 无运行期账本（镜像 $JL 行，分发空模板）"
  fi
fi

# ---------- C8 pack.sh 打包源必须指向权威目录 ----------
chk
if [ "$FAST" = "1" ]; then skip "C8 pack 源"
elif grep -q '^ROOT=$(cd "$(dirname "$0")/../.." && pwd)' data/cmd/pack.sh 2>/dev/null \
  && grep -q '^OUT_DIR=$ROOT' data/cmd/pack.sh 2>/dev/null; then
  ok "C8 pack.sh 自定位（ROOT 由 \$0 推导，OUT_DIR=\$ROOT）"
else
  fail "C8 pack.sh 未自定位：SKILL_DIR / OUT_DIR 必须由 ROOT 推导"
fi

# ---------- C9 备份时效（H17 触发信号：>7 天告警）----------
chk
if [ "$FAST" = "1" ]; then skip "C9 备份时效"
elif [ -f data/.dist ]; then
  if [ "$PJ_ROWS" -gt 0 ]; then
    na "C9 备份时效（dist 分发态：H17 对本 skill data/ 不适用；运行期账本真身 $PJ_ROWS 条在插件里，归档需人工确认）"
  else
    na "C9 备份时效（dist 分发态 + 无运行期账本）"
  fi
else
  # v0.16.3-dev：原写死 self-evo-backup 单一路径（旧流水线遗留，已随 1113 清理删除）
  # 改为扫全部备份根：self-evo-backup + backup-*，任一有 7 天内文件即通过
  BKDIRS=""
  for _d in /sdcard/Download/self-evo-backup /sdcard/Download/backup-*; do
    [ -d "$_d" ] && BKDIRS="$BKDIRS $_d"
  done
  if [ -z "$BKDIRS" ]; then
    fail "C9 无任何备份根（self-evo-backup / backup-* 均不存在）"
  else
    OLD=$(find $BKDIRS -maxdepth 2 -type f -mtime -7 2>/dev/null | wc -l)
    if [ "$OLD" -gt 0 ]; then
      ok "C9 7 天内备份 $OLD 个（$(echo $BKDIRS | wc -w) 个备份根）"
    else
      fail "C9 备份超过 7 天未更新（H17 触发信号）"
    fi
  fi
fi

# ---------- C10 P0 检索脚本：语法可解析 + playbook 引用落地 ----------
# 为什么造这条：v0.16.4 新增三个脚本，若 SKILL/playbook 引用了不存在的文件，
# 只是文档悬浮；语法错则是「门禁自己都跑不起来」，比文档悬浮更致命。
chk
if [ "$FAST" = "1" ]; then skip "C10 P0 脚本自检"
else
  MISS=""; SYN=""; N=0
  for f in data/cmd/eval.sh data/cmd/route-cache.sh data/cmd/lexicon.sh; do
    if [ ! -f "$f" ]; then MISS="$MISS $f"; continue; fi
    sh -n "$f" 2>/dev/null || SYN="$SYN $f"
    N=$((N + 1))
  done
  REFS2=$(grep -oE 'data/cmd/[A-Za-z0-9_-]+\.sh' data/playbook/playbook-route.md 2>/dev/null | sort -u)
  for f in $REFS2; do [ -f "$f" ] || MISS="$MISS $f(playbook引用)"; done
  if [ -z "$MISS" ] && [ -z "$SYN" ]; then
    ok "C10 P0 脚本语法通过（$N 个）＋ playbook 引用落地"
  else
    fail "C10 P0 脚本缺/语法错:$MISS$SYN"
  fi
fi

chk
if [ "$FAST" = "1" ]; then skip "C11 词库规模"
else
  LO=$(sh data/cmd/lexicon.sh --check 2>&1); RC=$?
  if [ "$RC" = "0" ]; then
    ok "C11 词库达标：$LO"
  else
    fail "C11 词库不达标：$LO"
  fi
fi

# ---------- C12 检索索引：结构 + 新鲜度（v1.1 改指新引擎）----------
# 为什么造这条：索引一旦陈旧（新条目入库没 rebuild），search 会「查得到旧条目、查不到新条目」，
# 比没有索引更危险——因为它看起来正常。故用条数比对把「陈旧」变成机械可判。
# v1.1：真相源从 memory-index.md + memory-titles.txt（手工清单）改为 bin/evo 的 index.tsv
# （自动派生自账本 journal.tsv）——手工清单必然漂移，实测改造前索引条数 = 0。
chk
if [ "$FAST" = "1" ]; then skip "C12 索引"
else
  IO=$(sh bin/evo index check 2>&1); IRC=$?
  case "$IRC" in
    0) ok "C12 索引通过：$IO" ;;
    4) ok "C12 无索引（派生数据可重建，分发态空账本属正常）" ;;
    6) fail "C12 $IO" ;;
    *) fail "C12 索引不达标：$IO" ;;
  esac
fi
# ---------- C13 结构报告新鲜度 ----------
# 为什么造这条：refactor-report.md 是按源码指纹生成的快照，源码一改报告就过期。
# 过期报告比没有报告更危险——它看起来还在，却描述的是上一版结构。故把「陈旧」变机械可判。
# 口径（双判据）：① 报告内源码指纹 == 当前 `cat data/cmd/*.sh data/*.sh SKILL.md | md5sum`（新鲜）
#                ② 报告 self-md5 == 去掉该行后的全文 md5（未被手改）；② 只拦误操作，不拦有写权限的主体。
chk
if [ "$FAST" = "1" ]; then
    # fast 也要跑自校验：1 次全文 md5，成本≈0，但能抓住「报告被手改」——跳过它等于给 fast 模式留后门
    RO=$(sh data/cmd/refactor.sh selfcheck 2>&1); RRC=$?
    case "$RRC" in
      0) ok "C13 报告自校验通过（fast 跳过指纹比对）" ;;
      4) ok "C13 无结构报告" ;;
      *) fail "C13 $RO" ;;
    esac
  else
  RO=$(sh data/cmd/refactor.sh check 2>&1); RRC=$?
  if [ "$RRC" = "0" ]; then
    ok "C13 结构报告新鲜（$RO）"
  elif [ "$RRC" = "3" ]; then
    fail "C13 结构报告陈旧（$RO）"
  elif [ "$RRC" = "5" ]; then
    fail "C13 报告自校验不符（$RO）"
  else
    ok "C13 无结构报告（首次使用请跑 refactor.sh scan）"
  fi
fi
# ---------- C14 主干体积上限（v1.0.1 上下文瘦身）----------
# 为什么造这条：SKILL.md 是每轮常驻上下文，体积直接决定 token 成本与「关键规则被淹没」的概率。
# 42.6KB → 12.2KB 靠分卷达成；没有上限，下一个版本会一路加回去。
chk
if [ "$FAST" = "1" ]; then skip "C14 主干体积"
else
  SB=$(wc -c < SKILL.md 2>/dev/null | tr -d ' '); SB=${SB:-0}
  if [ "$SB" -le 14336 ]; then
    ok "C14 主干体积 $SB B（上限 14336）"
  else
    fail "C14 SKILL.md $SB B > 14336 B —— 新增长内容应进 refs/，不要堆主干"
  fi
fi

# ---------- C15 检索评测集有效题数（v1.1）----------
# 为什么造这条：没有评测集，「检索变强了」永远只是感觉。
# 逐字口径与 eval.sh 的 parse_set 一致：每题一行表格数据行 `| id | query | 期望标题 | 域 |`。
chk
if [ "$FAST" = "1" ]; then skip "C15 评测集"
elif [ -f data/.dist ]; then
  # 分发态：题库的「期望标题」逐字等于账本标题，随包外发＝泄漏；且冷启动没有账本可评 → 语义上 n/a。
  # 与 C9 同型豁免：豁免由 data/.dist 标记驱动，删标记即恢复强制。
  ok "C15 分发态：评测集不随包外发（n/a）"
else
  EV=data/retrieval-evalset.md
  # 判据与 eval.sh 的 parse_set 保持一致：表格数据行 `| 数字 | ...`，不是 `Q:` 前缀。
  QN=$(grep -cE '^\| [0-9]+ \|' "$EV" 2>/dev/null | head -1); QN=${QN:-0}
  if [ "$QN" -ge 10 ]; then
    ok "C15 评测集 $QN 题"
  else
    fail "C15 评测集不足：$QN 题（需 ≥10，格式见文件头）"
  fi
fi

# ---------- C16 refs 分卷无孤儿（v1.1）----------
# 双向判据：SKILL.md 引用的分卷必须存在；refs/ 下每个分卷必须被 SKILL.md 引用。
# 后者防「拆出去就再也没人读」——那是知识的坟墓，不是瘦身。
chk
if [ "$FAST" = "1" ]; then skip "C16 refs 无孤儿"
else
  RMISS=""
  for f in $(grep -oE 'refs/[A-Za-z0-9._-]+\.md' SKILL.md 2>/dev/null | sort -u); do
    [ -f "$f" ] || RMISS="$RMISS $f"
  done
  ORPH=""
  for f in $(ls refs/*.md 2>/dev/null); do
    grep -q "$f" SKILL.md 2>/dev/null || ORPH="$ORPH $f"
  done
  if [ -n "$RMISS" ]; then
    fail "C16 SKILL.md 引用但不存在的分卷:$RMISS"
  elif [ -n "$ORPH" ]; then
    fail "C16 孤儿分卷（未被 SKILL.md 引用，等于死文件）:$ORPH"
  else
    ok "C16 refs 分卷 $(ls refs/*.md 2>/dev/null | wc -l) 个，引用闭环"
  fi
fi

# ---------- C17 检索层对抗测试（v0.19）----------
# 为什么造这条：检索加固（空查询/纯标点/单字符/编号边界/覆盖度/注入）全是
#   「不测就不知道有没有生效」的行为，人工点几下必然回归。
#   lib/search.sh 或 index.tsv 结构任何改动，这里必须保持全绿，否则视为回归。
chk
if [ "$FAST" = "1" ]; then
  skip "C17 检索对抗"
elif [ -f data/.dist ]; then
  # 分发态：data/store/ 不进包，无账本即无索引，对抗测试无对象 → 与 C15 同型豁免。
  ok "C17 分发态：无账本无索引，对抗测试 n/a"
else
  if sh data/cmd/adv.sh --quiet >/tmp/.evo_c17.$$ 2>&1; then
    ok "C17 检索对抗 $(grep -oE '用例 [0-9]+ 条' /tmp/.evo_c17.$$ | head -1) 全绿"
    rm -f /tmp/.evo_c17.$$
  else
    fail "C17 检索对抗未通过（$(grep -c '^FAIL' /tmp/.evo_c17.$$) 项，日志 /tmp/.evo_c17.$$）"
  fi
fi

echo "=== 结果：$((TOTAL - FAIL))/$TOTAL 通过，FAIL=$FAIL，跳过 $SKIPPED（$MODE）==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0