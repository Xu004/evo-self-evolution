#!/bin/sh
# lib/index.sh · 检索层：加权精确检索
#
# index.tsv 列（TAB 分隔，无表头）：
#   domain <TAB> title <TAB> alias <TAB> triggers <TAB> summary <TAB> ts <TAB> type
#
# triggers = 对象全串 + 结论正文。不做分词：中文无空格，且无可靠词典，
#            子串匹配在这种数据规模（几十~几百条）上召回更高。
# alias 独立存 alias.tsv（title <TAB> 词1·词2），索引重建不丢别名。
#
# 打分：标题精确 100 ｜标题包含 60 ｜别名 40 ｜触发词 25 ｜结论 10
# 多词时按「每词至少命中一个字段」计 hits，hits 少的不因分数高而排前。

index_build() {
  [ -f "$STORE/journal.tsv" ] || die "无账本镜像，先跑 evo store sync"
  store_init
  AL="$STORE/alias.tsv"
  [ -f "$AL" ] || : > "$AL"
  T=$(store_tmp idx)

  awk -F'\t' '
    # 分域以「类型列」为主判据，不依赖标题前缀：
    # 真实账本的对象列是自由文本（如"多副本 / 双真身（同一项目两份独立目录）"），
    # 按标题前缀匹配会让 100% 条目落到 S-STATE（实测 10/10），分域形同虚设。
    function dom(ty, t) {
      if (ty == "rule")  return "R-RULE"
      if (ty == "fail")  return "F-FAIL"
      if (ty == "state") return "S-STATE"
      if (t ~ /Android/)      return "A-ANDROID"
      if (t ~ /Shell/)        return "A-SHELL"
      if (t ~ /GAME|游戏/)    return "A-GAME"
      if (t ~ /逆向/)         return "A-REVERSE"
      if (t ~ /EVO/)          return "A-EVO"
      if (t ~ /机制/)         return "M-MECH"
      if (t ~ /决策/)         return "D-DECISION"
      if (t ~ /^事件|^项目:/) return "E-EVENT"
      if (t ~ /^入口:/)       return "X-ENTRY"
      return "A-MISC"
    }
    # 用 FILENAME 判文件，不用 NR==FNR：
    # 第一个文件为空时，NR==FNR 在第二个文件里恒成立（两者同步递增），
    # 会把全部数据行当成 alias 行吞掉，索引变空表。
    FILENAME == ARGV[1] { if ($1 != "") AL[$1] = $2; next }
    {
      ob = $3; cc = $4
      a = (ob in AL) ? AL[ob] : "-"
      # 第 8 列 verify：日志原文/哈希等证据，低权重召回用。
      # 缺这一列时，只出现在证据里的术语（日志、路径、报错）永远搜不到。
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", dom($2, ob), ob, a, ob " " cc, cc, $1, $2, $5
    }' "$AL" "$STORE/journal.tsv" > "$T"

  store_commit "$T" "$STORE/index.tsv"
  ok "index build: $(grep -c . "$STORE/index.tsv" 2>/dev/null) 条 → $STORE/index.tsv"
}

index_stats() {
  [ -f "$STORE/index.tsv" ] || die "索引不存在，先跑 evo index build"
  echo "=== 分域 ==="
  cut -f1 "$STORE/index.tsv" | sort | uniq -c | sort -rn | sed 's/^ */  /'
  echo "=== 合计 $(grep -c . "$STORE/index.tsv" 2>/dev/null) 条 ==="
  awk -F'\t' '$3 != "-" && $3 != "" { c++ } END { printf "=== 别名已填 %d 条 ===\n", c + 0 }' "$STORE/index.tsv"
}

# v0.19：改名保留。实际生效的是 lib/search.sh 里的 index_search（加固版）。
# 回退方法：把下面这一行改回 index_search()（并注释掉 bin/evo 里的 lib/search.sh source）
index_search_legacy() {
  [ $# -ge 1 ] || die '用法: evo search "词1 词2"'
  [ -f "$STORE/index.tsv" ] || die "索引不存在：先跑 evo store sync && evo index build"

  # 单参数含空格 → 按空格拆成多词（用户习惯连打 "find 提速"）
  if [ $# -eq 1 ]; then
    case $1 in *[[:space:]]*) set -- $1 ;; esac
  fi

  KWS=$(printf '%s\n' "$@" | awkb 'NF { print tolower($0) }')

  OUT=$(awkb -F'\t' -v kws="$KWS" '
    BEGIN {
      m = split(kws, T, "\n"); n = 0
      for (i = 1; i <= m; i++) {
        v = tolower(T[i]); gsub(/[[:space:]]/, "", v)
        if (v != "") K[++n] = v
      }
      if (n == 0) n = 1
    }
    {
      lt = tolower($2); la = tolower($3); lg = tolower($4); ls = tolower($5); lv = tolower($8)
      score = 0; hits = 0
      for (i = 1; i <= n; i++) {
        k = K[i]; h = 0
        if (k == "") continue
        if (lt == k)               { score += 100; h = 1 }
        else if (index(lt, k) > 0) { score += 60;  h = 1 }
        if (index(la, k) > 0)      { score += 40;  h = 1 }
        if (index(lg, k) > 0)      { score += 25;  h = 1 }
        if (index(ls, k) > 0)      { score += 10;  h = 1 }
        if (index(lv, k) > 0)      { score += 5;   h = 1 }
        if (h) hits++
      }
      if (hits == 0) next
      c++
      R[c] = score; H[c] = hits; D[c] = $1; Tt[c] = $2; Ty[c] = $7; Ts[c] = $6
    }
    END {
      # 冒泡排序：数据量 ≤ 数百条，O(n^2) 可接受，省掉 fork sort
      for (i = 1; i <= c; i++)
        for (j = i + 1; j <= c; j++)
          if (R[j] > R[i] || (R[j] == R[i] && H[j] > H[i])) {
            t = R[i];  R[i]  = R[j];  R[j]  = t
            t = H[i];  H[i]  = H[j];  H[j]  = t
            t = D[i];  D[i]  = D[j];  D[j]  = t
            t = Tt[i]; Tt[i] = Tt[j]; Tt[j] = t
            t = Ty[i]; Ty[i] = Ty[j]; Ty[j] = t
            t = Ts[i]; Ts[i] = Ts[j]; Ts[j] = t
          }
      lim = (c < 5) ? c : 5
      for (i = 1; i <= lim; i++)
        printf "%d. [%s] %s  score=%d hits=%d/%d\n   取: get_memory_by_title(\"%s\")\n", \
               i, D[i], Tt[i], R[i], H[i], n, Tt[i]
      printf "COUNT %d\n", c + 0
    }' "$STORE/index.tsv")

  CNT=$(printf '%s\n' "$OUT" | tail -1 | awkb '{ print $2 + 0 }')
  if [ "${CNT:-0}" -gt 0 ]; then
    printf '%s\n' "$OUT" | sed '$d'
    echo "HIT $CNT（$*）"
    return 0
  fi
  echo "MISS（$*）→ 走 lexicon 展开 + query_memory"
  return 3
}

# ---------- index_check：门禁 C12 用（v1.1 新增）----------
# 判据：① 索引存在 ② 每行 8 列 ③ 索引条数 == journal.tsv 条数（新鲜度）
# 退出码：0 ok / 4 无索引（未 build，派生数据可重建） / 5 结构坏 / 6 陈旧（必须 rebuild）
# 为什么条数要跳过表头：journal.tsv 首行是列名，直接 wc -l 会多算 1 → 永远误报陈旧。
index_check() {
  local idx="$STORE/index.tsv" jtv="$STORE/journal.tsv"
  [ -f "$idx" ] || { echo "无索引（未 build）"; return 4; }
  local ST
  ST=$(awkb -F'\t' '
    NR==1 && ($2=="title" || $1=="domain") {next}
    NF==0 {next}
    { n++; if (NF!=8) bad++ }
    END { printf "%d %d\n", n+0, bad+0 }' "$idx") || { echo "索引读取失败"; return 5; }
  set -- $ST
  local IN=$1 BAD=$2
  [ "$BAD" = "0" ] || { echo "列数异常 ${BAD} 行（应为 8 列）"; return 5; }
  local JN=0
  if [ -f "$jtv" ]; then
    JN=$(awkb -F'\t' 'NR==1 && ($2=="title" || $1=="type") {next} NF==0 {next} {n++} END{print n+0}' "$jtv")
  fi
  # journal.tsv 缺失（分发态空账本）→ 只做结构校验
  if [ "$JN" != "0" ] && [ "$IN" != "$JN" ]; then
    echo "索引陈旧：index $IN 条 ≠ journal.tsv $JN 条（跑 bin/evo index build）"
    return 6
  fi
  echo "index ok: $IN 条（journal $JN 条）"
  return 0
}