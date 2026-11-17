#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
status.sh 显示层三修（幂等，只改 data/cmd/status.sh，不碰门禁逻辑）
D1 查4 数值被 grep 关键词过滤 -> 看板 H1-violation 永远看不见（实际是 0）
D2 待办坑 取数源错：坑索引在记忆条目「坑档案:EVO」，waters.md 里没有 ^- 坑NN 行 -> 恒空
D3 账本摘要 cut -c1-160 按字节切 UTF-8 -> 末字乱码（reflect 之后�）
用法: python3 status-patch-1117.py [SKILL_HOME]
"""
import os
import shutil
import sys
import time

HOME = sys.argv[1] if len(sys.argv) > 1 else '/sdcard/Download/Operit/skills/EVO自进化'
P = os.path.join(HOME, 'data/cmd/status.sh')
BAK = os.path.join(HOME, 'data/backup/status.sh.bak.%s' % time.strftime('%m%d-%H%M'))

s = open(P, encoding='utf-8').read()
orig = s
applied = []

# --- D1: grep 放行纯数字行（H1-violation 的 0） ---
a1 = "grep -E '查[1-6]|无缺失|无违规|无游离|无野行|H1-violation' | head -12"
b1 = "grep -E '查[1-6]|无缺失|无违规|无游离|无野行|H1-violation|^[0-9]+$' | head -12"
if a1 in s:
    s = s.replace(a1, b1); applied.append('D1')
elif b1 in s:
    applied.append('D1:skip')

# --- D2: 待办坑 改为「本地有则列，无则指向权威条目」 ---
a2 = """grep -E '^- 坑(2[0-9])' "$HERE/data/waters.md" 2>/dev/null | cut -c1-140"""
b2 = """if grep -qE '^- 坑[0-9]+' "$HERE/data/waters.md" 2>/dev/null; then
    grep -E '^- 坑[0-9]+' "$HERE/data/waters.md" | cut -c1-140 | head -8
  else
    echo "（本地无坑索引；权威：记忆条目「坑档案:EVO」）"
  fi"""
if a2 in s:
    s = s.replace(a2, b2); applied.append('D2')
elif '本地无坑索引' in s:
    applied.append('D2:skip')

# --- D3: 账本摘要去残缺字节（截断后 iconv -c 丢弃半个字符） ---
a3 = 'tail -3 "$JB" 2>/dev/null | cut -c1-160'
b3 = 'tail -3 "$JB" 2>/dev/null | cut -c1-160 | iconv -f UTF-8 -t UTF-8 -c 2>/dev/null'
if a3 in s:
    s = s.replace(a3, b3); applied.append('D3')
elif 'iconv -f UTF-8' in s:
    applied.append('D3:skip')

if s != orig:
    os.makedirs(os.path.dirname(BAK), exist_ok=True)
    shutil.copy2(P, BAK)
    open(P, 'w', encoding='utf-8').write(s)
    print('PATCHED %s  backup=%s' % (','.join(applied), BAK))
else:
    print('NOCHANGE %s' % (','.join(applied) or 'no-match'))
