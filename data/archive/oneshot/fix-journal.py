# -*- coding: utf-8 -*-
"""账本一致化与数据体检修复（一次性脚本，2026-11-16）"""
import os, shutil

P = '/sdcard/Download/Operit/plugins/com.yg.evo/journal.md'
BK = '/sdcard/Download/Operit/skills/EVO自进化/data/backup/journal-2026-11-16.md'

os.makedirs(os.path.dirname(BK), exist_ok=True)
if not os.path.exists(BK):
    shutil.copy2(P, BK)
    print('backup ->', BK)

s = open(P, encoding='utf-8').read()
lines = s.split('\n')

NEW = ('| 2026-11-16 06:42 | exp | EVO autoDream 2026-11-16 落地：11-15 跳空复盘 + 双链清理 | '
       '11-15 03:00 那一跳完全跳空（无心跳/无执行/链仍 RUNNING），11-16 06:40 才延迟 27h40m 落地，'
       '按 H16 记 ❌ 第 1 次。根因未定位（非 CANCELLATION、非 180s 超时），不下结论。'
       '实操三条：①目标时间必须回算，禁建过期链（坑28）；②terminal heredoc 失效改 printf 单行（坑29）；'
       '③建链后 list 复核揪出同名重复 6a3a9ce2 与残留 fe356aea，备份后均删。'
       '六阶段：账本 24 条无重复 title、store/index 一致、链接 132、无垃圾文件，lint 六查 rc=0。'
       '（本行原文被 conclusion 长度上限截断，已补全并统一坑号） | 未验证 |')

fixed = False
for i, l in enumerate(lines):
    if l.startswith('| 2026-11-16 06:42') and 'store/index 2 |' in l:
        lines[i] = NEW
        fixed = True

CORR = ('| 2026-11-16 06:55 | state | 账本一致化与数据体检 | '
        '三方 24/24/24 一致无缺多；06:42 行结论曾被 conclusion 长度上限截断，已补全并统一坑号'
        '（28 跨日过期链 / 29 heredoc）；06:41 行引用的 6a3a9ce2 已删，现行唯一活跃链=0b251aa8（11-17 03:00）；'
        '清理插件根 0 字节 waters.md 与空目录 data/patches；data/journal.md 标注废弃（坑22）；'
        '新增坑30：evo_reflect conclusion 超长静默截断，长结论须分批或落 waters/记忆。 '
        '| 24/24/24 一致 + 清理完成 + 下轮 lint 六查须 rc=0 |')

if not any('账本一致化与数据体检' in l for l in lines):
    lines.append(CORR)
    print('appended correction row')

open(P, 'w', encoding='utf-8').write('\n'.join(lines))
print('truncation fixed =', fixed)

W = '/sdcard/Download/Operit/plugins/com.yg.evo/waters.md'
if os.path.exists(W) and os.path.getsize(W) == 0:
    os.remove(W)
    print('removed empty plugins/waters.md')

PD = '/sdcard/Download/Operit/skills/EVO自进化/data/patches'
if os.path.isdir(PD) and not os.listdir(PD):
    os.rmdir(PD)
    print('removed empty data/patches/')

J = '/sdcard/Download/Operit/skills/EVO自进化/data/journal.md'
t = open(J, encoding='utf-8').read()
if '废弃' not in t:
    open(J, 'w', encoding='utf-8').write(
        '<!-- 废弃：本文件是 v1.0 分发模板残留。记账唯一入口 = evo_reflect -> '
        'plugins/com.yg.evo/journal.md。journal-add 写本文件属坑22 读写不同源，禁止使用。 -->\n' + t)
    print('data/journal.md marked deprecated')

print('done')
