#!/bin/sh
# refactor.sh · EVO 结构体检 + 重构草案（v0.16.6-dev P1-D6）
# 档位：L0 只读扫描 + L1 补丁草案。不做 L2 自动应用（理由见 SKILL.md 与 playbook-route.md）
# 用法：
#   sh bin/evo refactor scan           全仓扫描 → data/refactor-report.md
#   sh bin/evo refactor report [all]   读报告（默认摘要 + 前 5 条）
#   sh bin/evo refactor patch <F号>    生成草案到 data/patches/
#   sh bin/evo refactor apply <F号>    仅 .diff 类可应用（备份 → patch → check.sh → 失败回滚）
#   sh bin/evo refactor rollback       回滚最近一次 apply
#   sh bin/evo refactor check          报告新鲜度（供 C13 调用；0=新鲜 3=陈旧 4=无报告 5=被手改）
#   sh bin/evo refactor selfcheck      仅报告自校验（供 check.sh --fast 调用；0=通过 4=无报告 5=被手改）
#   sh bin/evo refactor selftest       故障注入自测（影子副本跑 3 态，断言 C13 未退化）
# 规则：R01 重复块 / R07 循环内 fork / R08 ROOT 定义重复 / R09 log 函数重复 / R11 未使用函数
#       R12 shebang 不一致 / R13 双真相源 / R14 版本号硬编码（非注释行）
#       R20 SKILL 行数预算 / R21 H 条款编号重复 / R23 文档数字漂移
# 阈值：R01 ≥5 行 / R07 循环体 >3 行 / R11 零调用 / R20 450 行 / R08·R09 ≥2 处
# 硬红线（写死在实现里，不提供开关）：
#   1. 不自动重排格式——shell 语义依赖换行与续行，文本级格式化必然改坏语义
#   2. 不跨文件自动抽函数——抽 common.sh 会引入 source 依赖，破坏单文件可跑；R08 只报不出 patch
#   3. 不改 SKILL.md——宪法文本只许人改；R20/R21/R23 只报
#   4. 任何 apply 必须过 check.sh 全量，失败自动回滚
#   5. 自举：本脚本同样受全部 R 规则约束（自己命中 R08/R12 属正常，是「该抽 common.sh」的证据）
ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 1
cd "$ROOT" || exit 1
REP="${EVO_REP:-$(cd "$(dirname "$0")/../.." && pwd)/../.evo-private/refactor-report.md}"
mkdir -p "$(dirname "$REP")" 2>/dev/null
PD="data/patches"
TMP="$PD/.scan.tmp"

usage() { sed -n '5,16p' "$0"; }

# 源码指纹：所有 .sh + SKILL.md 拼接后 md5（C13 用同一口径）
fp_now() {
  cat data/cmd/*.sh data/*.sh SKILL.md 2>/dev/null | md5sum | cut -d' ' -f1
}

# ---------- 单进程扫描：R01/R07/R11/R12/R14 一次 awk 完成 ----------
scan_sh() {
  awk '
  BEGIN { split("tr grep sed cut cat wc sort uniq basename dirname head tail awk date mkdir rm cp mv ln chmod find zip unzip md5sum xargs", E, " "); for (i in E) EXT[E[i]] = 1 }
  FNR == 1 {
    n = 0; d = 0; st = 0; body = 0; hits = 0
    if ($0 != "#!/bin/sh") { L = $0; gsub(/\|/, "·", L); printf "F|R12|info|%s:1|%s|统一为 #!/bin/sh（toybox 与 proot 均可用）|no\n", FILENAME, L }
  }
  {
    B = $0; gsub(/\|/, "·", B)
    if ($0 !~ /^[[:space:]]*#/ && $0 ~ /v0\.[0-9]/) printf "F|R14|info|%s:%d|%s|版本号收敛到单点（SKILL.md 头 / CHANGELOG）|no\n", FILENAME, FNR, B
    if ($0 !~ /^[[:space:]]*#/) { ln = $0; gsub(/[^A-Za-z0-9_]+/, " ", ln); m = split(ln, P, " "); for (i = 1; i <= m; i++) if (P[i] != "") tok[P[i]]++ }
    if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*\(\)/) { nm = $0; sub(/\(\).*/, "", nm); def[nm] = FILENAME ":" FNR }
    if (d) {
      if ($0 ~ /^[[:space:]]*done/) {
        if (body > 3 && hits > 0) {
          if (ex != "") printf "F|R07|info|%s:%d|循环体 %d 行 · fork %d · 已豁免：%s|豁免理由须可复核，含糊即视为未豁免|no\n", FILENAME, st, body, hits, ex
          else printf "F|R07|P1|%s:%d|循环体 %d 行 · 外部命令 %d 个|交 awk/sed 单进程一次扫完（教训18）；固定小迭代可写 # fork-ok: <理由> 声明豁免|no\n", FILENAME, st, body, hits
        }
        d = 0; ex = ""
      } else {
        body++
        for (i = 1; i <= NF; i++) { t = $i; gsub(/[^A-Za-z0-9_]/, "", t); if (t in EXT) hits++ }
      }
    }
    if (!d && $0 ~ /do[[:space:]]*$/) {
      d = 1; st = FNR; body = 0; hits = 0; ex = ""
      # 豁免：循环头上方 1~2 行内的 # fork-ok: <理由>（理由 <8 字符不认，防占位式豁免）
      if (pv1 ~ /fork-ok:/) { ex = pv1; sub(/.*fork-ok:[[:space:]]*/, "", ex); gsub(/[[:space:]]+$/, "", ex); if (length(ex) < 8) ex = "" }
      if (ex == "" && pv2 ~ /fork-ok:/) { ex = pv2; sub(/.*fork-ok:[[:space:]]*/, "", ex); gsub(/[[:space:]]+$/, "", ex); if (length(ex) < 8) ex = "" }
    }
    if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/ || $0 ~ /^[[:space:]]*(\}|\)|esac|fi|done|;;)/) { n = 0 }
    else {
      win[++n] = $0
      if (n >= 5) {
        k = win[n-4] SUBSEP win[n-3] SUBSEP win[n-2] SUBSEP win[n-1] SUBSEP win[n]
        if (!(k in seen)) seen[k] = FILENAME ":" FNR
        else if (!(k in rpt)) { rpt[k] = 1; L = win[n]; gsub(/\|/, "·", L); printf "F|R01|P1|%s → %s|5 行重复块，末行：%s|抽公共函数（跨文件抽取引入 source 依赖，需人工确认）|no\n", seen[k], FILENAME ":" FNR, L }
      }
    }
    pv2 = pv1; pv1 = $0
  }
  END { for (nm in def) if (tok[nm] <= 1) printf "F|R11|info|%s|函数 %s() 定义后零调用|删死代码|no\n", def[nm], nm }
  ' data/cmd/*.sh data/*.sh 2>/dev/null
}

# ---------- R08 重复的 ROOT/CD 定位 ----------
scan_r08() {
  # 豁免：SHELLS.md 出现 dup-ok 标记 → 整组降 info（理由须可复核，教训 24）
  if grep -q 'dup-ok' data/cmd/SHELLS.md 2>/dev/null; then
    LV=info; NOTE="已豁免：跨文件独立脚本，ROOT 定位重复是「单文件可跑」的代价，见 SHELLS.md 第四节"
  else
    LV=P2; NOTE="抽 common.sh 统一（会引入 source 依赖，只建议不出 patch）"
  fi
  grep -h 'dirname "\$0"' data/cmd/*.sh 2>/dev/null \
    | sed 's/^[[:space:]]*//' | sort | uniq -c | sort -rn \
    | awk -v lv="$LV" -v note="$NOTE" '$1 >= 2 { c = $1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); L = $0; gsub(/\|/, "·", L); printf "F|R08|%s|全仓 %d 处|%s|%s|no\n", lv, c, L, note }'
}

# ---------- R09 重复的 log 函数 ----------
scan_r09() {
  grep -hE '^(ok|fail|info|warn|chk|skip|die)\(\)' data/cmd/*.sh 2>/dev/null \
    | sed 's/^[[:space:]]*//' | sort | uniq -c | sort -rn \
    | awk '$1 >= 2 { c = $1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); L = $0; gsub(/\|/, "·", L); printf "F|R09|info|全仓 %d 处|%s|抽公共函数，注意各脚本输出前缀不同|no\n", c, L }'
}

# ---------- R13 双真相源（a: 脚本未登记 SHELLS.md / b: op 枚举两份） ----------
scan_r13() {
  A="$PD/.r13a.txt"; B="$PD/.r13b.txt"
  ls data/cmd/*.sh 2>/dev/null | awk -F/ '{ print $NF }' | sort > "$A"
  # 只认「脚本表」行首单元格 ^| `xxx.sh`：正文里的示例/反例（如「不抽 common.sh」）不算登记
  grep -oE '^\| `[A-Za-z0-9_-]+\.sh`' data/cmd/SHELLS.md 2>/dev/null | sed 's/^| `//; s/`$//' | sort -u > "$B"
  comm -23 "$A" "$B" 2>/dev/null | while read -r s; do
    [ -n "$s" ] && echo "F|R13|P1|data/cmd/SHELLS.md|脚本 $s 存在但 SHELLS.md 未登记|补登（SHELLS.md = 脚本清单单一真相源）|no"
  done
  comm -13 "$A" "$B" 2>/dev/null | while read -r s; do
    [ -n "$s" ] && echo "F|R13|P1|data/cmd/SHELLS.md|SHELLS.md 登记了 $s 但文件不存在|删登记或补文件|no"
  done
  # R13b：journal op 白名单两处定义
  sed -n '/^  create|/p' data/cmd/journal-add.sh 2>/dev/null | tr '|' '\n' | sed 's/[[:space:]);]//g' | grep -v '^$' | sort > "$A"
  sed -n '/split("create/p' data/cmd/journal-lint.sh 2>/dev/null | sed 's/.*split("//; s/", V.*//' | tr ' ' '\n' | grep -v '^$' | sort > "$B"
  D=$(diff "$A" "$B" 2>/dev/null | grep '^[<>]' | tr '\n' ' ')
  [ -n "$D" ] && echo "F|R13|P1|journal-add.sh ↔ journal-lint.sh|op 枚举两份定义不一致：$D|收敛为单点（改两处必有一处漏）|no"
  # R13c：列表长度与循环上限的耦合硬编码（加新值忘改上限 = 新值永远不生效；必须扫全部 for 行，不能 head -1）
  WN=$(grep -o 'split("create[^"]*"' data/cmd/journal-lint.sh 2>/dev/null | sed 's/^split("//; s/"$//' | wc -w | tr -d ' ')
   # fork-ok: 输入为 grep 匹配行（实测 0~3 行），非数据文件全量
  grep 'for (i = 1; i <=' data/cmd/journal-lint.sh 2>/dev/null | grep -v 'NV' | grep -v 'limit' | while read -r ln; do
    LN=$(printf '%s' "$ln" | sed 's/.*<= *//; s/;.*//' | tr -d ' ')
    case "$LN" in
      ''|*[!0-9]*) ;;
      *) if [ "$LN" != "$WN" ]; then echo "F|R13|P1|journal-lint.sh|for 上限写死 $LN，而 split 列表 $WN 项（新值永远不生效）|改为 NV|no"; fi ;;
    esac
  done
  rm -f "$A" "$B"
}

# ---------- R20 / R21 / R23 文档类 ----------
scan_doc() {
  L=$(wc -l < SKILL.md 2>/dev/null || echo 0)
  [ "$L" -gt 450 ] && echo "F|R20|P2|SKILL.md|$L 行 > 450 行预算|拆细到 data/playbook/（SKILL.md 只留规则与指针）|no"
  grep -oE '^\| H[0-9]+ \|' SKILL.md 2>/dev/null | sort | uniq -d | while read -r h; do
    echo "F|R21|P1|SKILL.md|条款 $h 重复定义|合并为一条，编号不复用|no"
  done
  # R23a 门禁项数：实际 = check.sh 结果行里的 C 编号去重数
  ACT=$(grep -oE '(ok|fail|skip) +"C[0-9]+b?' data/cmd/check.sh 2>/dev/null | grep -oE 'C[0-9]+b?' | sort -u | wc -l | tr -d ' ')
  grep -rhoE '[0-9]+[[:space:]]*项门禁' SKILL.md data/cmd/*.md 2>/dev/null | grep -oE '^[0-9]+' | sort -u | while read -r n; do
    [ "$n" != "$ACT" ] && echo "F|R23|P1|文档 vs check.sh|文档称 $n 项门禁，实际 $ACT 项|同步文档数字或补齐门禁|no"
  done
  # R23b 索引条数
  IDXN=$(tail -n +2 data/store/index.tsv 2>/dev/null | grep -c .); [ -n "$IDXN" ] || IDXN=0
  grep -rhoE '[0-9]+[[:space:]]*条(记忆)?条目' SKILL.md data/*.md 2>/dev/null | grep -oE '^[0-9]+' | sort -u | while read -r n; do
    [ "$n" != "$IDXN" ] && echo "F|R23|info|文档 vs index.tsv|文档称 $n 条条目，索引实际 $IDXN 条|同步或改口径|no"
  done
  # R23c --fast 跳过量（SHELLS.md 这类操作文档最容易漂移的数字）
  # 判据必须带量词「项」：H6 验收列写的是「跳过 0」（意为不允许跳过），
  # 只按「跳过+数字」匹配会把它误当成数量声明，报「文档称跳过 0 项」。
  # 数量声明必带量词，规则语气不带 → 用「项」做区分，比维护白名单可靠。
  SK=$(grep -c 'skip "' data/cmd/check.sh 2>/dev/null); [ -n "$SK" ] || SK=0
  grep -rhoE '跳过[[:space:]]*[0-9]+[[:space:]]*项' SKILL.md data/cmd/*.md 2>/dev/null | grep -oE '[0-9]+' | sort -u | while read -r n; do
    [ "$n" != "$SK" ] && echo "F|R23|P1|文档 vs check.sh|文档称 --fast 跳过 $n 项，实际 skip 分支 $SK 个|同步文档数字|no"
  done
}

# ---------- scan ----------
cmd_scan() {
  mkdir -p "$PD" || exit 1
  : > "$TMP"
  TS=$(date -u -d "@$(( $(date +%s) + 28800 ))" '+%Y-%m-%d %H:%M')
  FP=$(fp_now)
  NS=$(ls data/cmd/*.sh 2>/dev/null | wc -l | tr -d ' ')
  { scan_sh; scan_r08; scan_r09; scan_r13; scan_doc; } >> "$TMP" 2>/dev/null
  N=$(grep -c '^F|' "$TMP" 2>/dev/null || echo 0)
  P0=$(awk -F'|' '/^F\|/{if ($3=="P0") c++} END{print c+0}' "$TMP")
  P1=$(awk -F'|' '/^F\|/{if ($3=="P1") c++} END{print c+0}' "$TMP")
  P2=$(awk -F'|' '/^F\|/{if ($3=="P2") c++} END{print c+0}' "$TMP")
  IN=$(awk -F'|' '/^F\|/{if ($3=="info") c++} END{print c+0}' "$TMP")
  # v0.16.7：抬头不再硬编码 EVO + 版本，改从 SKILL.md 的 name / 标题行取（分发态 EVO自进化 才能自洽）
  SKN=$(sed -n 's/^name:[[:space:]]*//p' SKILL.md 2>/dev/null | head -1)
  SKV=$(awk '/^# / { for (i = 1; i <= NF; i++) if ($i ~ /^v[0-9]/) { print $i; exit } }' SKILL.md 2>/dev/null)
  {
    echo "# refactor-report · ${SKN:-EVO} 结构体检（${SKV:-v?} L0+L1）"
    echo ""
    echo "- 生成时间：$TS（UTC+8）"
    echo "- 源码指纹：\`$FP\`（C13 用同口径：\`cat data/cmd/*.sh data/*.sh SKILL.md | md5sum\`）"
    echo "- 扫描范围：$NS 个 shell 脚本 + SKILL.md + data/*.md + data/playbook/*.md"
    echo "- 档位：L0 只读扫描 + L1 补丁草案（无 L2 自动应用）"
    echo ""
    echo "## 一、摘要"
    echo ""
    echo "| 级别 | 数量 | 处理方式 |"
    echo "|---|---|---|"
    echo "| P0 立即修 | $P0 | 阻断性，修完重扫 |"
    echo "| P1 建议修 | $P1 | 本版内消化或挂账 |"
    echo "| P2 排期 | $P2 | 记入 VERSION_HISTORY 待办 |"
    echo "| info 仅记录 | $IN | 知道即可，不强求 |"
    echo ""
    echo "## 二、发现清单（共 $N 条）"
    echo ""
    if [ "$N" = "0" ]; then
      echo "本仓零发现。"
    else
      echo "| 编号 | 规则 | 级别 | 位置 | 证据 | 建议 | 可出 patch |"
      echo "|---|---|---|---|---|---|---|"
      awk -F'|' '/^F\|/{n++; printf "| F%02d | %s | %s | \`%s\` | %s | %s | %s |\n", n, $2, $3, $4, $5, $6, $7}' "$TMP"
    fi
    echo ""
    echo "## 三、规则全集与阈值"
    echo ""
    echo "| 规则 | 检测 | 阈值 | 级别 |"
    echo "|---|---|---|---|"
    echo "| R01 | 重复代码块（跨文件滑动窗口 hash） | ≥5 行非注释非结构行 | P1 |"
    echo "| R07 | 循环体内外部命令（fork 放大） | 循环体 >3 行且外部命令 ≥1；循环头上方写 \`# fork-ok: <理由 ≥8 字符>\` 可降 info | P1 |"
    echo "| R08 | 重复的 ROOT/CD 定位 | ≥2 处逐字相同 | P2 |"
    echo "| R09 | 重复的 log 函数 | ≥2 处逐字相同 | info |"
    echo "| R11 | 函数定义后零调用 | 全仓词频 =1 | info |"
    echo "| R12 | shebang 不统一 | ≠ \`#!/bin/sh\` | info |"
    echo "| R13 | 双真相源（脚本清单 / op 枚举） | 集合不一致 | P1 |"
    echo "| R14 | 版本号硬编码 | 非注释行含 v0.x | info |"
    echo "| R20 | SKILL.md 行数预算 | >450 行 | P2 |"
    echo "| R21 | H 条款编号重复定义 | 同号 >1 次 | P1 |"
    echo "| R23 | 文档数字漂移（门禁项数 / 索引条数） | 文档数 ≠ 实际数 | P1 |"
    echo ""
    echo "## 四、边界声明（写死，不提供开关）"
    echo ""
    echo "1. 不自动重排格式：shell 语义依赖换行与续行，文本级格式化必然改坏语义。"
    echo "2. 不跨文件自动抽函数：抽 \`common.sh\` 会引入 \`source\` 依赖，破坏单文件可跑；R08 只报不出 patch。"
    echo "3. 不改 \`SKILL.md\`：宪法文本只许人改；R20/R21/R23 只报。"
    echo "4. 任何 \`apply\` 必须过 \`check.sh\` 全量 + \`eval.sh\` 基线不回退，失败自动回滚。"
    echo "5. 自举：\`refactor.sh\` 自己同样受全部 R 规则约束——它命中 R08/R12 是正常的，那正是「该抽 common.sh」的证据。"
    echo "6. 报告尾的 \`self-md5\` 只拦**误操作与无意编辑**（手改、编辑器重排、误删行）；有写权限者可连校验行一起改——那由权限与审计解决，校验和解决不了，别把它当防篡改。"
  } > "$REP"
  # 内容自校验：对「除本行外」的全文取 md5，手改任一字符即失配（与「指纹新鲜」是两条独立判据）
  printf '<!-- self-md5: %s -->\n' "$(md5sum "$REP" | cut -d' ' -f1)" >> "$REP"
  rm -f "$TMP"
  echo "扫描完成：$N 条发现（P0=$P0 P1=$P1 P2=$P2 info=$IN）"
  echo "报告：$REP"
  echo "指纹：$FP"
}

# ---------- selftest：故障注入自测（影子副本，绝不碰真报告） ----------
cmd_selftest() {
  [ -f "$REP" ] || { echo "无报告，先 scan"; exit 4; }
  T="/tmp/evo-selftest.$$"
  mkdir -p "$T" || exit 1
  cp "$REP" "$T/clean" || exit 1
  sed '1s/$/ /' "$REP" > "$T/tampered" || exit 1
  F=0
  O=$(EVO_REP="$T/clean" sh "$0" check 2>&1); RC=$?
  [ "$RC" = "0" ] && echo "PASS 态1 未改动 → rc=0" || { echo "FAIL 态1 期望 0 实得 $RC（$O）"; F=1; }
  O=$(EVO_REP="$T/tampered" sh "$0" check 2>&1); RC=$?
  [ "$RC" = "5" ] && echo "PASS 态2 注入 1 空格 → rc=5" || { echo "FAIL 态2 期望 5 实得 $RC（$O）"; F=1; }
  rm -rf "$T"
  O=$(sh "$0" check 2>&1); RC=$?
  [ "$RC" = "0" ] && echo "PASS 态3 真报告仍新鲜 → rc=0" || { echo "FAIL 态3 期望 0 实得 $RC（$O）"; F=1; }
  [ "$F" = "0" ] && { echo "selftest：3/3 通过"; exit 0; }
  echo "selftest：FAIL——机制已退化，先修 C13 再动别的"
  exit 1
}
# ---------- report ----------
cmd_report() {
  [ -f "$REP" ] || { echo "无报告，先跑 scan"; exit 4; }
  if [ "$1" = "all" ]; then
    cat "$REP"
  else
    sed -n '1,20p' "$REP"
    echo ""
    echo "--- 前 5 条发现 ---"
    grep '^| F[0-9]' "$REP" | head -5
    echo ""
    echo "（全量：sh data/cmd/refactor.sh report all）"
  fi
}

# ---------- patch ----------
cmd_patch() {
  F="$1"
  [ -n "$F" ] || { usage; exit 4; }
  [ -f "$REP" ] || { echo "无报告，先跑 scan"; exit 4; }
  ROW=$(grep "^| $F " "$REP" 2>/dev/null | head -1)
  [ -n "$ROW" ] || { echo "报告里没有 $F"; exit 4; }
  mkdir -p "$PD" || exit 1
  RULE=$(printf '%s' "$ROW" | awk -F'|' '{gsub(/ /,"",$3); print $3}')
  OUT="$PD/$F-$RULE.proposal.md"
  {
    echo "# $F · $RULE 草案"
    echo ""
    echo "来源报告：data/refactor-report.md"
    echo "报告指纹：$(sed -n 's/^- 源码指纹：`\([0-9a-f]*\)`.*/\1/p' "$REP" | head -1)"
    echo ""
    echo "## 原始发现行"
    echo ""
    echo "$ROW"
    echo ""
    echo "## 处置建议"
    echo ""
    case "$RULE" in
      R12) echo "把 shebang 统一为 \`#!/bin/sh\`。真正的可应用 diff 见 $PD/$F-R12.diff（\`apply $F\` 使用）。" ;;
      R08) echo "抽 \`data/cmd/common.sh\` 统一 ROOT 定位。**本规则不出 diff**：抽公共文件会引入 \`source\` 依赖，破坏「单文件可独立跑」；要做必须人工逐个改并同步 SHELLS.md。" ;;
      R13) echo "把两份定义收敛为单点：优先让 \`journal-lint.sh\` 从 \`journal-add.sh\` 的 case 行提取，而不是各写一份。（与 SKILL.md H9「脚本不重复真相源」同源）」" ;;
      R23) echo "改文档数字，或补代码。二选一，不允许两边都不动。" ;;
      *) echo "按上表「建议」列人工处理；本规则不出自动 diff。" ;;
    esac
  } > "$OUT"
  echo "草案：$OUT"
  if [ "$RULE" = "R12" ]; then
    LOC=$(printf '%s' "$ROW" | awk -F'|' '{gsub(/[\\` ]/,"",$5); print $5}')
    FILE=${LOC%:*}
    if [ -f "$FILE" ]; then
      sed '1s|^#!.*|#!/bin/sh|' "$FILE" > "$PD/.new.tmp"
      diff -u "$FILE" "$PD/.new.tmp" 2>/dev/null \
        | sed "1s#^--- .*#--- a/$FILE#; 2s#^+++ .*#+++ b/$FILE#" > "$PD/$F-R12.diff"
      rm -f "$PD/.new.tmp"
      if [ -s "$PD/$F-R12.diff" ]; then
        echo "可应用 diff：$PD/$F-R12.diff（proot 环境跑 apply）"
      else
        rm -f "$PD/$F-R12.diff"
        echo "!! 未生成 diff：$FILE 首行可能已是 #!/bin/sh"
      fi
    else
      echo "!! 定位文件不存在：$FILE（报告可能已过期，重跑 scan）"
    fi
  fi
}

# ---------- apply ----------
cmd_apply() {
  F="$1"
  [ -n "$F" ] || { usage; exit 4; }
  D="$PD/$F-R12.diff"
  [ -f "$D" ] || { echo "无可应用 diff（只有 R12 出真 diff；其余规则见 .proposal.md）"; exit 4; }
  command -v patch >/dev/null 2>&1 || { echo "本环境无 patch 命令（Android toybox 无），请在 proot 环境跑"; exit 4; }
  mkdir -p "$PD/bak" || exit 1
  TS=$(date '+%Y%m%d-%H%M%S')
  BK="$PD/bak/$TS"
  mkdir -p "$BK" || exit 1
  FILE=$(grep '^+++ b/' "$D" | sed 's|^+++ b/||' | head -1)
  # 白名单：diff 只能改仓库内脚本（防 diff 被篡改成写 /sdcard 别处或 ../ 逃逸）
  case "$FILE" in
    ''|*..*|/*) echo "!! 非法路径（$FILE）：只允许仓库内相对路径"; exit 4 ;;
    data/cmd/*.sh|data/*.sh|SKILL.md) : ;;
    *) echo "!! 路径不在白名单（data/cmd/*.sh data/*.sh SKILL.md）：$FILE"; exit 4 ;;
  esac
  patch -p1 --dry-run < "$D" >/dev/null 2>&1 || { echo "!! dry-run 失败：diff 与当前文件不匹配，拒绝应用"; exit 5; }
  cp "$FILE" "$BK/" || { echo "备份失败，中止"; exit 4; }
  echo "备份：$BK/$FILE"
  patch -p1 < "$D" || { echo "patch 应用失败，未改动"; exit 5; }
  if [ "${FILE%.sh}" != "$FILE" ] && ! sh -n "$FILE" 2>/dev/null; then
    echo "!! 语法检查失败，立即回滚"
    cp "$BK/$(basename "$FILE")" "$FILE"
    exit 6
  fi
  echo "已应用，重扫报告对齐源码指纹（否则 C13 必陈旧）..."
  sh data/cmd/refactor.sh scan >/dev/null 2>&1
  echo "跑 check.sh 全量..."
  if sh data/cmd/check.sh; then
    echo "check.sh 通过，apply 结束"
    echo "$TS $FILE" > "$PD/.last-apply"
  else
    echo "check.sh 未通过，自动回滚"
    cp "$BK/$(basename "$FILE")" "$FILE"
    sh data/cmd/refactor.sh scan >/dev/null 2>&1
    echo "已回滚 $FILE，报告已同步回滚后源码"
    exit 6
  fi
}

# ---------- rollback ----------
cmd_rollback() {
  [ -f "$PD/.last-apply" ] || { echo "无 apply 记录"; exit 4; }
  read -r TS FILE < "$PD/.last-apply"
  BK="$PD/bak/$TS/$(basename "$FILE")"
  [ -f "$BK" ] || { echo "备份缺失：$BK"; exit 4; }
  cp "$BK" "$FILE" || exit 5
  echo "已回滚 $FILE ← $BK"
  rm -f "$PD/.last-apply"
  sh data/cmd/refactor.sh scan >/dev/null 2>&1
  echo "报告已同步回滚后源码"
}

# ---------- check（C13 调用） ----------
# ---------- 自校验内核（check / selfcheck 共用） ----------
self_verify() {
  [ -f "$REP" ] || { echo "无报告"; return 4; }
  SELF=$(sed -n 's/^<!-- self-md5: \([0-9a-f]*\) -->$/\1/p' "$REP" | head -1)
  [ -n "$SELF" ] || { echo "旧格式报告（无自校验行），跑 scan 补"; return 0; }
  NOW=$(grep -v '^<!-- self-md5:' "$REP" | md5sum | cut -d' ' -f1)
  if [ "$SELF" != "$NOW" ]; then
    echo "报告自校验不符（记录 $SELF ≠ 实算 $NOW）——内容被外部修改，跑 scan 重生成"
    return 5
  fi
  return 0
}
# ---------- check（C13 调用） ----------
cmd_check() {
  self_verify; RV=$?
  [ "$RV" = "0" ] || exit "$RV"
  OLD=$(sed -n 's/^- 源码指纹：`\([0-9a-f]*\)`.*/\1/p' "$REP" | head -1)
  NEW=$(fp_now)
  if [ "$OLD" = "$NEW" ]; then
    echo "$NEW"
    exit 0
  fi
  echo "报告 $OLD ≠ 当前 $NEW（跑 refactor.sh scan 重扫）"
  exit 3
}

case "$1" in
  scan)     cmd_scan ;;
  report)   cmd_report "$2" ;;
  patch)    cmd_patch "$2" ;;
  apply)    cmd_apply "$2" ;;
  rollback) cmd_rollback ;;
  check)     cmd_check ;;
  selfcheck) self_verify; exit $? ;;
  selftest)  cmd_selftest ;;
  *)         usage; exit 4 ;;
esac