#!/bin/sh
# lib/store.sh · 存储层：插件账本 → 结构化镜像
#
# journal.tsv 列（TAB 分隔，无表头）：
#   ts <TAB> type <TAB> obj <TAB> conclusion <TAB> verify
#
# 幂等键 = ts + obj：重复 sync 不产生重复行。
# 单向：插件账本是唯一权威，本文件是只读派生镜像，禁止反向回写账本。

store_sync() {
  J=$(evo_journal)
  [ -f "$J" ] || die "账本不存在: $J（插件未装？可用 EVO_JOURNAL 指定）"
  store_init
  T=$(store_tmp sync)

  awk -F'|' '
    /^\|[[:space:]]*[0-9][0-9][0-9][0-9]-/ {
      n = 0
      for (i = 2; i <= 6; i++) {
        v = $i
        gsub(/^[ \t\r]+|[ \t\r]+$/, "", v)
        gsub(/\t/, " ", v)          # 制表符会破坏 TSV 结构
        f[++n] = v
      }
      if (f[1] == "" || f[3] == "") next
      printf "%s\t%s\t%s\t%s\t%s\n", f[1], f[2], f[3], f[4], f[5]
    }' "$J" > "$T"

  # 去重，保留首次出现（账本按时间顺序追加，首次=最早写入）
  awk -F'\t' '!seen[$1 "|" $3]++' "$T" > "$T.d" && mv -f "$T.d" "$T"

  N=$(grep -c . "$T" 2>/dev/null) || N=0
  if [ "$N" -eq 0 ]; then
    rm -f "$T"
    die "解析出 0 条，拒绝覆盖（检查表头是否为 | 时间 | 类型 | 对象 | 结论 | 验证 |）"
  fi

  store_commit "$T" "$STORE/journal.tsv"
  ok "store sync: $N 条 → $STORE/journal.tsv"
}

store_show() {
  [ -f "$STORE/journal.tsv" ] || die "无镜像，先跑 evo store sync"
  N=${1:-10}
  echo "=== 最近 $N 条 ==="
  tail -n "$N" "$STORE/journal.tsv" | awk -F'\t' '
    { printf "%s ｜%-5s｜%s\n   结论: %s\n", $1, $2, $3, $4 }'
  echo "=== 合计 $(grep -c . "$STORE/journal.tsv" 2>/dev/null) 条 ==="
}

# 表式账本校验：类型白名单 + 三字段非空
journal_lint() {
  J=$(evo_journal)
  [ -f "$J" ] || die "账本不存在: $J"
  awk -F'|' '
    BEGIN { V["exp"] = 1; V["rule"] = 1; V["fail"] = 1; V["state"] = 1 }
    /^\|[[:space:]]*[0-9][0-9][0-9][0-9]-/ {
      n++
      ty = $3; gsub(/^[ \t\r]+|[ \t\r]+$/, "", ty)
      ob = $4; gsub(/^[ \t\r]+|[ \t\r]+$/, "", ob)
      cc = $5; gsub(/^[ \t\r]+|[ \t\r]+$/, "", cc)
      vf = $6; gsub(/^[ \t\r]+|[ \t\r]+$/, "", vf)
      if (!(ty in V)) { printf "违规：第 %d 行类型非法 [%s]\n", NR, ty; bad++ }
      if (ob == "")   { printf "违规：第 %d 行对象为空\n", NR; bad++ }
      if (cc == "")   { printf "违规：第 %d 行结论为空\n", NR; bad++ }
      if (vf == "")   { printf "违规：第 %d 行缺验证证据\n", NR; bad++ }
    }
    END {
      printf "条目 %d ｜违规 %d\n", n + 0, bad + 0
      exit (bad ? 1 : 0)
    }' "$J"
}