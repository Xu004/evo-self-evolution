# -*- coding: utf-8 -*-
"""waters.md 追加坑41（usage() 硬编码行号）"""
import sys

P = '/sdcard/Download/Operit/skills/EVO自进化/data/waters.md'
s = open(P, encoding='utf-8').read()

if '41 usage() 硬编码行号' in s:
    print('SKIP: 已写入')
    sys.exit(0)

ADD = ('**41 usage() 硬编码行号**：`bin/evo` 的 `usage()` 用 `sed -n \'12,19p\'` 取用法块，文件一改行号就漂。'
       '实测把 `set -u` 误打成用法末行——用法清单实际在 10–17 行，**从头就错位一行**，只是平时没人调 `evo` 裸命令所以没暴露。'
       '对策：脚本头注释区按语义块读取，`awk \'/^# 用法:/{f=1} /^set -u/{exit} f\'`，彻底去掉行号依赖（呼应 H9：SKILL 只引用脚本名）。')

lines = s.split('\n')
anchor = None
for i, l in enumerate(lines):
    if l.startswith('## data/cmd/journal-commit.sh'):
        anchor = i
        break
if anchor is None:
    print('FAIL: 未找到锚点 ## data/cmd/journal-commit.sh')
    sys.exit(1)

lines.insert(anchor, ADD)
lines.insert(anchor + 1, '')

idx_ok = False
for i, l in enumerate(lines):
    if l.startswith('18 ') and '40 dash' in l and '41 ' not in l:
        lines[i] = l.rstrip() + ' / 41 usage() 硬编码行号'
        idx_ok = True
        break

open(P, 'w', encoding='utf-8').write('\n'.join(lines))

t = open(P, encoding='utf-8').read()
print('written =', '41 usage()硬编码行号' in t, '| index =', idx_ok, '| lines =', t.count('\n') + 1)