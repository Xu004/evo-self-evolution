# -*- coding: utf-8 -*-
# H17 双轨备份：manifest 清单 + 全文分卷（12 条/卷），并冷备 skill zip
import os

B = '/sdcard/Download/Operit/skills/EVO自进化'
J = '/sdcard/Download/Operit/plugins/com.yg.evo/journal.md'
OUT = '/sdcard/Download/self-evo-backup'
TAG = '20261117'
PER = 12

os.makedirs(OUT, exist_ok=True)
lines = open(J, encoding='utf-8').read().splitlines()
recs = [l for l in lines if l.startswith('| 2026-')]
print('records=%d' % len(recs))

vols = [recs[i:i + PER] for i in range(0, len(recs), PER)]
for idx, v in enumerate(vols, 1):
    p = os.path.join(OUT, 'backup-%s-%d.md' % (TAG, idx))
    with open(p, 'w', encoding='utf-8') as f:
        f.write('# EVO 账本备份 %s · 第 %d 卷（%d 条 / 共 %d 卷）\n\n' % (TAG, idx, len(v), len(vols)))
        f.write('| 时间 | 类型 | 对象 | 结论 | 验证 |\n|---|---|---|---|---|\n')
        f.write('\n'.join(v) + '\n')
    print('vol%d=%d bytes=%d' % (idx, len(v), os.path.getsize(p)))

man = os.path.join(OUT, 'manifest-%s.txt' % TAG)
with open(man, 'w', encoding='utf-8') as f:
    for r in recs:
        parts = [x.strip() for x in r.strip().strip('|').split('|')]
        f.write('%s\t%s\t%s\n' % (parts[0], parts[1], parts[2]))
print('manifest lines=%d' % len(recs))

z = os.path.join(B, 'EVO自进化.zip')
data = open(z, 'rb').read()
import hashlib
md5 = hashlib.md5(data).hexdigest()
dst = os.path.join(OUT, 'EVO自进化-%s.zip' % TAG)
open(dst, 'wb').write(data)
print('zip bytes=%d md5=%s' % (len(data), md5))
print('OK manifest=%d records=%d vols=%d' % (len(recs), len(recs), len(vols)))