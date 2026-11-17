#!/bin/sh
# lib/search.sh · 检索层 v0.19 · 对抗加固版
#
# 为什么单独一个文件：lib/index.sh 里的 index_search 改名为 index_search_legacy 保留，
#   出问题一行改回即可（可回退是本项目硬约束，不允许"只能往前"的重构）。
#
# 加固点（每条在 data/cmd/adv.sh 都有对抗用例，FAIL 即门禁红）：
#   1 空/纯空白查询 → rc=2 + 用法（原实现静默 MISS rc=3：无法区分「没问」和「没找到」）
#   2 纯标点词过滤（`; ls /` 里的 `/` 不得成为检索词）
#   3 单字符词过滤（"A" 会靠 60+40 叠加在任意含 a 条目上拿 100 分，纯噪声）
#   4 词长截断 64 / 词数上限 8（原实现 600 字整串当一词，必然 MISS）
#   5 编号特判：H21 / C13 / T8 / 坑43 走**边界匹配** +120（高于 title 包含 60），
#     且 H2 不再命中 H21（边界后缀 [^0-9] 挡住）
#   6 覆盖度优先排序：hits/n 为主键（3 词命中 2 词不得压过 1 词精确命中）
#   7 短拉丁词（≤3 字符，如 ls）强制边界匹配，不再在 "Tools" 里命中 "ls"
#   8 MISS 时自动 lexicon 展开 + 给出可直接执行的 query_memory 参数
#
# 契约不变：HIT n rc=0 / MISS rc=3 / 无效查询 rc=2（check.sh、adv.sh 依赖）

usage_search() {
  printf '用法: evo search "<词1> [词2 ...]" [--all]\n' >&2
  printf '      --all  输出全部命中（默认 Top5）\n' >&2
}

index_search() {
  LIM=5
  if [ "${1:-}" = "--all" ]; then LIM=999; shift; fi
  if [ $# -lt 1 ]; then usage_search; return 2; fi

  # 索引路径可注入（EVO_INDEX_TSV）：对抗测试 A22 用临时空索引验证 lexicon 展开。
  # 不隔离的话，账本一写进「闪退」这个词，查询就变成真命中，用例假红——
  # 那是用例对数据的隐式依赖，不是检索层的缺陷。
  IDX="${EVO_INDEX_TSV:-$STORE/index.tsv}"
  [ -f "$IDX" ] || die "索引不存在：先跑 evo store sync && evo index build"

  Q="$*"
  # 全空白 / 空串：明确报错，不伪装成 MISS
  if ! printf '%s' "$Q" | grep -q '[^[:space:]]'; then
    printf 'FAIL 空查询（用法: evo search "<词>"）\n' >&2
    return 2
  fi

  OUT=$(awk -F'\t' -v q="$Q" -v lim="$LIM" '
    function isid(w) {
      # 编号形态：H21 / C13 / R07 / T3b / T8 / 坑43
      if (w ~ /^[a-z]{1,4}[0-9]{1,4}[a-z]?$/) return 1
      if (w ~ /^坑[0-9]{1,3}$/) return 1
      return 0
    }
    BEGIN {
      n = 0
      m = split(q, W, " ")
      for (i = 1; i <= m; i++) {
        w = W[i]
        if (w == "") continue
        if (w ~ /^[[:punct:][:space:]]+$/) continue        # 纯标点
        if (length(w) == 1 && w !~ /^[0-9]$/) continue      # 单字符（数字除外）
        if (length(w) > 64) w = substr(w, 1, 64)            # 超长截断
        lw = tolower(w)
        # 编号 + 中文混排拆词："h21枚举" → "h21" + "枚举"
        # 实测：不拆时整词当普通词，index 精确子串匹配必失败 → 编号检索对混排输入完全失效。
        pc = 0
        if (match(lw, /^[a-z]{1,4}[0-9]{1,4}[a-z]?/) > 0 && RLENGTH < length(lw)) {
          PL[++pc] = substr(lw, 1, RLENGTH)
          PL[++pc] = substr(lw, RLENGTH + 1)
        } else {
          PL[++pc] = lw
        }
        for (j = 1; j <= pc; j++) {
          q2 = PL[j]
          if (q2 == "" || (q2 in SEEN)) continue
          SEEN[q2] = 1
          K[++n] = q2
          ID[q2] = isid(q2)
          # 短拉丁词强制边界匹配，否则 "ls" 会在 "Tools" 里命中
          SH[q2] = (!ID[q2] && length(q2) <= 3 && q2 ~ /^[a-z0-9]+$/) ? 1 : 0
          if (n >= 8) break
        }
        if (n >= 8) break                                    # 词数上限
      }
      # 坑44：这里**不能** exit —— awk 在 BEGIN 里 exit 仍会执行 END 块，
      # 会多打一行 COUNT 0，shell 侧拿到 "-1\n0" 后 `[ -gt ]` 直接 Illegal number。
      # 判定挪到 END 开头，全流程只有一个出口。
    }
    {
      lt = tolower($2); la = tolower($3); lg = tolower($4)
      ls = tolower($5); lv = tolower($8)
      score = 0; hits = 0
      for (i = 1; i <= n; i++) {
        k = K[i]; h = 0
        if (ID[k]) {
          # 编号：边界匹配优先给 120，避免 H2 命中 H21、坑4 命中坑43
          ex = "(^|[^a-z0-9])" k "([^0-9]|$)"
          if (lg ~ ex || lt ~ ex) { score += 120; h = 1 }
        } else if (SH[k]) {
          ex = "(^|[^a-z0-9])" k "([^a-z0-9]|$)"
          if (lt ~ ex)      { score += 100; h = 1 }
          else if (lg ~ ex) { score += 45;  h = 1 }
          else if (la ~ ex) { score += 40;  h = 1 }
        } else {
          if (lt == k)               { score += 100; h = 1 }
          else if (index(lt, k) > 0) { score += 60;  h = 1 }
          if (index(la, k) > 0)      { score += 40;  h = 1 }
          if (index(lg, k) > 0)      { score += 25;  h = 1 }
          if (index(ls, k) > 0)      { score += 10;  h = 1 }
          if (index(lv, k) > 0)      { score += 5;   h = 1 }
        }
        if (h) hits++
      }
      if (hits == 0) next
      c++
      R[c] = score; H[c] = hits; CV[c] = hits / n
      D[c] = $1; Tt[c] = $2; Ty[c] = $7
    }
    END {
      if (n == 0) { print "COUNT -1"; exit }
      if (c == 0) { print "COUNT 0"; exit }
      # 覆盖度 → 分数 → 命中数，三级降序（冒泡，数据量 ≤ 数百，够用）
      for (i = 1; i <= c; i++)
        for (j = i + 1; j <= c; j++) {
          sw = 0
          if (CV[j] > CV[i]) sw = 1
          else if (CV[j] == CV[i] && R[j] > R[i]) sw = 1
          else if (CV[j] == CV[i] && R[j] == R[i] && H[j] > H[i]) sw = 1
          if (sw) {
            t = R[i];  R[i]  = R[j];  R[j]  = t
            t = H[i];  H[i]  = H[j];  H[j]  = t
            t = CV[i]; CV[i] = CV[j]; CV[j] = t
            t = D[i];  D[i]  = D[j];  D[j]  = t
            t = Tt[i]; Tt[i] = Tt[j]; Tt[j] = t
            t = Ty[i]; Ty[i] = Ty[j]; Ty[j] = t
          }
        }
      k = (c < lim) ? c : lim
      for (i = 1; i <= k; i++)
        printf "%d. [%s] %s  score=%d hits=%d/%d\n   取: get_memory_by_title(\"%s\")\n", \
               i, D[i], Tt[i], R[i], H[i], n, Tt[i]
      printf "COUNT %d\n", c
    }' "$IDX")

  CNT=$(printf '%s\n' "$OUT" | awk '/^COUNT /{print $2}')
  CNT=${CNT:-0}

  if [ "$CNT" = "-1" ]; then
    printf 'FAIL 查询无效：全部词被过滤（空/纯标点/单字符），原查询 [%s]\n' "$Q" >&2
    return 2
  fi

  if [ "$CNT" -gt 0 ]; then
    printf '%s\n' "$OUT" | sed '$d'
    echo "HIT $CNT（$Q）"
    return 0
  fi

  # ---- MISS：自动 lexicon 展开，把「接下来该干嘛」直接给成可执行参数 ----
  printf 'MISS（%s）\n' "$Q"
  FW=$(printf '%s' "$Q" | awk '{print $1}')
  if [ -f "$ROOT/data/query-lexicon.md" ]; then
    LGX=$(sh "$ROOT/data/cmd/lexicon.sh" "$FW" 2>/dev/null | head -1)
    case "$LGX" in
      ''|词库未收录*)
        printf '  lexicon：未收录 [%s]（建议 append 一条到 data/query-lexicon.md）\n' "$FW" ;;
      *)
        printf '  lexicon 展开：%s\n' "$LGX"
        printf '  建议：query_memory(folder_path="self-evo", query="%s", limit=10)\n' \
               "$(printf '%s' "$LGX" | tr '|' ' ')"
        printf '  注：账本 ≠ 记忆库，两套命名空间；此处 MISS 只代表账本无此行\n' ;;
    esac
  fi
  return 3
}