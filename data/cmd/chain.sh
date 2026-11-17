#!/bin/sh
# data/cmd/chain.sh · EVO 自续链管理（查重 / 建链参数 / 心跳 / 调度开关）
#   sh chain.sh list                      列出全部 workflow
#   sh chain.sh check "2026-11-16 03:00"  查同时间任务（重复则 exit 1）
#   sh chain.sh new   "2026-11-16 03:00"  查重 + 输出建链步骤与参数
#   sh chain.sh beat                      写今日心跳
#   sh chain.sh landed                    查今日是否落地
#   sh chain.sh heartbeat7                最近 7 天落地表
#   sh chain.sh switch interval|specific  切调度模式（默认 specific_time）
set -u
# 本地时区：容器默认 UTC，凌晨 03:00 用 UTC 取日期会错一天（坑26）
if TZ=Asia/Shanghai date +%F >/dev/null 2>&1; then
  TZ=Asia/Shanghai
else
  TZ=
fi
export TZ
HERE=$(cd "$(dirname "$0")/../.." && pwd)
CONF="$HERE/data/chain.conf"
[ -f "$CONF" ] && . "$CONF"
WF_DIR=${WF_DIR:-/sdcard/Download/Operit/workflow}
HB_DIR="$HERE/data/heartbeat"
TODAY=$(date +%F)

jget() { grep -o "\"$1\": \"[^\"]*\"" "$2" 2>/dev/null | head -1 | sed 's/.*: "//; s/"$//'; }

case "${1:-help}" in
list)
  echo "== workflow ($WF_DIR) =="
  found=0
  for f in "$WF_DIR"/*.json; do
    [ -f "$f" ] || continue
    found=1
    id=$(basename "$f" .json)
    n=$(jget name "$f")
    t=$(jget specific_time "$f")
    e=$(jget enabled "$f")
    [ -n "$e" ] || e=$(grep -o '"enabled": [a-z]*' "$f" | head -1 | sed 's/.*: //')
    s=$(jget lastExecutionStatus "$f")
    echo "$id | ${t:---} | enabled=${e:-?} | ${s:-未执行} | ${n:-?}"
  done
  [ "$found" = 0 ] && echo "(空)"
  echo "-- MODE=${MODE:-?} TRIGGER=${TRIGGER_TIME:-?} INTERVAL=${INTERVAL_MIN:-?}m --"
  ;;
check|new)
  T="${2:-}"
  [ -n "$T" ] || { echo "用法: sh chain.sh $1 \"2026-11-16 03:00\""; exit 2; }
  dup=""
  for f in "$WF_DIR"/*.json; do
    [ -f "$f" ] || continue
    if [ "$(jget specific_time "$f")" = "$T" ]; then
      dup="$dup $(basename "$f" .json)"
    fi
  done
  if [ -n "$dup" ]; then
    echo "DUPLICATE $T ->$dup"
    echo "处置: 确认后 workflow:delete_workflow 清掉旧的，再建新的"
    exit 1
  fi
  echo "OK 无重复: $T"
  if [ "$1" = "new" ]; then
    echo ""
    echo "下一步:"
    echo "1) workflow:create_workflow name=\"一次性定时任务 $T\" trigger=specific_time:$T"
    echo "   chat_id=$CHAT_ID role_card_id=$ROLE_CARD_ID sender_name=$SENDER_NAME"
    echo "   message: 用 templates/chain-message.md 模板，把 {T} 替换成 $T"
    echo "2) workflow:patch_workflow 追加自删节点"
    echo "   add ExecuteNode{actionType:delete_workflow, actionConfig.workflow_id=<新建的 id>}"
    echo "   add connection{source:send_xxx, target:delete_xxx, condition:on_success}"
    echo "   add connection{source:send_xxx, target:delete_xxx, condition:on_failure}  # 失败也删，防残留双触发"
    echo "3) evo_reflect kind=state 更新「时钟:autoDream」自续链 id"
  fi
  ;;
beat)
  mkdir -p "$HB_DIR"
  touch "$HB_DIR/$TODAY"
  # v1.3 2026-11-17：心跳必须可读。原实现只 touch，文件恒 0 字节 ->
  # H26 把心跳当最高真源，却 cat 不出任何东西，等于真源失效。
  printf '%s beat mode=%s\n' "$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S')" "${MODE:-unknown}" >> "$HB_DIR/$TODAY"
  echo "ok heartbeat $HB_DIR/$TODAY"
  ;;
landed)
  if [ -f "$HB_DIR/$TODAY" ]; then echo "LANDED $TODAY"; else echo "MISSING $TODAY"; fi
  ;;
heartbeat7)
  mkdir -p "$HB_DIR"
  i=0
  while [ "$i" -lt 7 ]; do
    d=$(date -d "-$i day" +%F 2>/dev/null)
    [ -z "$d" ] && d=$(date -v-${i}d +%F 2>/dev/null)
    if [ -f "$HB_DIR/$d" ]; then echo "$d OK"; else echo "$d --"; fi
    i=$((i + 1))
  done
  ;;
switch)
  M="${2:-}"
  case "$M" in
  interval | specific)
    grep -v '^MODE=' "$CONF" > "$CONF.tmp"
    echo "MODE=$M" >> "$CONF.tmp"
    mv "$CONF.tmp" "$CONF"
    echo "ok MODE=$M"
    echo "注意: MODE=interval 需重建链为 schedule_type=interval + 窗口过滤 03:00~05:00，否则不生效"
    ;;
  *)
    echo "用法: sh chain.sh switch interval|specific"
    exit 2
    ;;
  esac
  ;;
help | *)
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  ;;
esac