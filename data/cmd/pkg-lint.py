#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pkg-lint.py —— ToolPkg 源码静态检查（只读，不修改任何文件）

用法：python3 pkg-lint.py [源码目录，默认 /sdcard/Download/文件/evo-pkg]

检查项：
  C1 语法           node --check 每个 js
  C2 manifest       toolpkg_id / version / main / entry 一致性
  C3 版本三处对齐   manifest.version vs main.js EVO_VERSION vs ui fallback
  C4 工具声明/导出  METADATA.tools[] vs exports.<name>
  C5 桥接导出/调用  main.js exports.uiX vs ui.js api.uiX(...)
  C6 跨文件重复     3 行归一化指纹，跨文件命中即报（重构候选）
  C7 危险模式       --- 过滤、空 catch、硬编码版本、零调用函数

退出码：0 无 FAIL；1 有 FAIL；2 无法运行
"""
import hashlib
import json
import os
import re
import subprocess
import sys

PKG = sys.argv[1] if len(sys.argv) > 1 else '/sdcard/Download/文件/evo-pkg'
DIST = os.path.join(PKG, 'dist')

fails, warns, infos = [], [], []


def read(p):
    return open(p, encoding='utf-8', errors='replace').read()


def js_files():
    out = []
    for root, _, fs in os.walk(DIST):
        for f in fs:
            if f.endswith('.js'):
                out.append(os.path.join(root, f))
    return sorted(out)


if not os.path.isdir(PKG):
    print('[FAIL] 目录不存在: ' + PKG)
    sys.exit(2)

JSS = js_files()
if not JSS:
    print('[FAIL] dist/ 下没有 js: ' + PKG)
    sys.exit(2)

# ---------- C1 语法 ----------
for p in JSS:
    r = subprocess.run(['node', '--check', p], capture_output=True, text=True)
    if r.returncode != 0:
        fails.append('C1 语法: %s\n%s' % (p, (r.stderr or '').strip()[:300]))

# ---------- C2 manifest ----------
man_path = os.path.join(PKG, 'manifest.json')
try:
    man = json.load(open(man_path, encoding='utf-8'))
except Exception as e:
    print('[FAIL] manifest.json 解析失败: %s' % e)
    sys.exit(1)

tid = man.get('toolpkg_id', '')
ver = man.get('version', '')
if not re.match(r'^\d+\.\d+\.\d+$', ver or ''):
    fails.append('C2 version 格式异常: %r' % ver)
main_rel = man.get('main', '')
if not os.path.isfile(os.path.join(PKG, main_rel)):
    fails.append('C2 manifest.main 不存在: %s' % main_rel)
for sp in man.get('subpackages', []):
    e = sp.get('entry', '')
    if not os.path.isfile(os.path.join(PKG, e)):
        fails.append('C2 子包 entry 不存在: %s → %s' % (sp.get('id'), e))

# ---------- C3 版本三处 ----------
main_txt = read(os.path.join(PKG, main_rel)) if os.path.isfile(os.path.join(PKG, main_rel)) else ''
m = re.search(r'EVO_VERSION\s*=\s*"([^"]+)"', main_txt)
ev_ver = m.group(1) if m else None
if not ev_ver:
    fails.append('C3 main.js 未找到 EVO_VERSION')
elif ev_ver != ver:
    fails.append('C3 版本不一致: manifest=%s main.EVO_VERSION=%s' % (ver, ev_ver))

ui_path = os.path.join(DIST, 'ui', 'evo_dashboard.ui.js')
ui_txt = read(ui_path) if os.path.isfile(ui_path) else ''
for v in sorted(set(re.findall(r'"(\d+\.\d+\.\d+)"', ui_txt))):
    if v != ver:
        warns.append('C3 ui.js 出现版本字面量 %s ≠ manifest %s（fallback 需人工确认）' % (v, ver))

# ---------- C4 工具声明 vs 导出 ----------
tools_path = os.path.join(DIST, 'packages', 'evo_tools.js')
tools_txt = read(tools_path) if os.path.isfile(tools_path) else ''
decl = []
meta = re.search(r'/\* METADATA\s*(\{.*?\})\s*\*/', tools_txt, re.S)
if meta:
    try:
        md = json.loads(meta.group(1))
        decl = [t.get('name') for t in md.get('tools', [])]
    except Exception as e:
        fails.append('C4 METADATA JSON 解析失败: %s' % e)
else:
    warns.append('C4 未找到 /* METADATA { } */ 块')
exports_t = set(re.findall(r'exports\.([A-Za-z_$][\w$]*)\s*=', tools_txt))
for t in decl:
    if t not in exports_t:
        fails.append('C4 工具已声明未导出: %s' % t)
for e in sorted(exports_t - set(decl)):
    warns.append('C4 导出未声明: %s' % e)

# ---------- C5 main 导出 vs ui 调用 ----------
main_exports = set(re.findall(r'exports\.([A-Za-z_$][\w$]*)\s*=', main_txt))
ui_calls = set(re.findall(r'\bapi\.([A-Za-z_$][\w$]*)\s*\(', ui_txt))
for c in sorted(ui_calls):
    if c not in main_exports:
        warns.append('C5 ui.js 调用 api.%s 但 main.js 未导出' % c)

# ---------- C6 跨文件重复 3 行块 ----------
def norm(l):
    return re.sub(r'\s+', ' ', l.strip())


fp = {}
for p in JSS:
    lines = [norm(x) for x in read(p).split('\n')]
    for i in range(len(lines) - 2):
        w = lines[i:i + 3]
        if sum(1 for x in w if x and not x.startswith('//')) < 3:
            continue
        h = hashlib.md5('§'.join(w).encode()).hexdigest()[:10]
        fp.setdefault(h, set()).add((p, i + 1))
cross = [(h, v) for h, v in fp.items() if len({x[0] for x in v}) > 1]
if cross:
    infos.append('C6 跨文件重复 3 行块: %d 处' % len(cross))
    for h, v in sorted(cross, key=lambda x: -len(x[1]))[:8]:
        infos.append('   ' + ' | '.join('%s:%d' % (os.path.basename(p), ln) for p, ln in sorted(v)))

# ---------- C7 危险模式 ----------
for p in JSS:
    t = read(p)
    name = os.path.basename(p)
    # 逐行扫描，注释行不算（注释里提到坏模式不该报警）
    for ln, line in enumerate(t.split('\n'), 1):
        s = line.strip()
        if s.startswith('//') or s.startswith('*') or s.startswith('/*'):
            continue
        if 'indexOf("---")' in line or "indexOf('---')" in line:
            fails.append('C7 %s:%d 用 indexOf("---") 过滤分隔行 → 结论里含 --- 的数据行会被整行丢弃' % (name, ln))
        if re.search(r'（v\d+\.\d+\.\d+）', line):
            warns.append('C7 %s:%d 文案里写死版本号（与 EVO_VERSION 脱钩）' % (name, ln))
    for mm in re.finditer(r'catch\s*\([^)]*\)\s*\{\s*\}', t):
        warns.append('C7 %s:%d 空 catch（异常被完全吞掉）' % (name, t[:mm.start()].count('\n') + 1))
    for d in re.findall(r'^(?:async )?function ([A-Za-z_$][\w$]*)', t, re.M):
        # 总引用次数 <= 1 = 只有定义、没人引用（exports.X = X / function: X 都算引用）
        refs = len(re.findall(r'(?<![\w$])' + re.escape(d) + r'(?![\w$])', t))
        if refs <= 1:
            warns.append('C7 %s: 函数 %s() 零引用（死代码候选）' % (name, d))

# ---------- 汇总 ----------
print('== pkg-lint · %s ==' % PKG)
print('   %s v%s · %d 个 JS · %d FAIL / %d WARN' % (tid, ver, len(JSS), len(fails), len(warns)))
print()
if fails:
    print('[FAIL] %d' % len(fails))
    for f in fails:
        print('  - ' + f)
if warns:
    print('[WARN] %d' % len(warns))
    for w in warns:
        print('  - ' + w)
if infos:
    print('[INFO]')
    for i in infos:
        print('  ' + i)
if not fails and not warns and not infos:
    print('[CLEAN] 全部通过')

sys.exit(1 if fails else 0)