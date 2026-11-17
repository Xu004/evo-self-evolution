# -*- coding: utf-8 -*-
"""waters.md 收尾：修正坑34 归因 + 追加坑39/40 + journal-commit 用法"""
import sys

P = '/sdcard/Download/Operit/skills/EVO自进化/data/waters.md'
s = open(P, encoding='utf-8').read()

# ---- 1) 修正坑 34 归因（证据不足，改为如实描述）----
OLD34 = '**34 reflect 与 sync 并行丢写**：sync 是「读-改-写」，与 reflect 的追加并发时用旧快照覆盖，账目直接丢失且无报错（本轮已实测复现一次）。三者必须串行。'
NEW34 = ('**34 reflect 与 sync 并发（归因已修正）**：原判「sync 与 reflect 并发用旧快照覆盖账本」**证据不足**——'
         'sync 只读账本、只写 store，不动账本。实测现象是「首次 reflect 返回 success 但账本未变，retry 才成功」，'
         '更可能归因于 conclusion 超长静默失败（坑 31）。结论：仍然禁止并行，但原因是**工具层静默失败不可自证**，'
         '不是文件竞态。防法：reflect 后跑 `journal-commit`，由条数变化自证落账成功。')

if OLD34 in s:
    s = s.replace(OLD34, NEW34)
    fix34 = True
else:
    fix34 = False

# ---- 2) 追加正文（坑39/40 + 工具用法）----
BODY2 = '''
## 坑39 / 40（journal-commit 落地时新增）

**39 proot 不实现 flock**：`flock -w 30 9` 直接报 `flock: 9: Function not implemented`，且被当成「等锁超时」误报。
对策：改用 `mkdir` 原子锁（mkdir 失败即抢锁失败），锁内写 pid，轮询时用 `kill -0 $pid` 判持锁进程存活以清理陈锁，
`trap 'rm -rf $LOCKDIR' EXIT INT TERM HUP` 保证退出即释放。实测并发 3 个 commit 全部 rc=0、无锁残留。

**40 dash 不支持 set +H**：`sh` 在此环境是 dash，`set +H` 报 `Illegal option -H` 并让脚本异常退出。
脚本内不要用 bash 专有语法；坑 32 的 `set +H` 只用于**交互命令行**（绕 bash 历史展开），不进脚本文件。

## data/cmd/journal-commit.sh（v0.17.1）

reflect 之后的收尾一条命令：**mkdir 原子锁 → store sync → index build → 七查自检**。

```
sh data/cmd/journal-commit.sh      # 完整输出
sh data/cmd/journal-commit.sh -q   # 静默
```

- 退出码：0 一致无违规 / 1 等锁超时或 sync 失败 / 2 七查有违规
- 幂等自愈：sync 与 index 条数不等时自动重试一轮
- 只读校验：绝不改写账本，账本是 `evo_reflect` 的专属写域
- 路径两个根：库根 `<EVO>`（bin/data 在此），账本在 `<Operit>/plugins/com.yg.evo/`（上两级），脚本内 SELF/ROOT/OP 显式解析
- 验收：正常态 27/27/27 rc=0；账本 +1 行模拟忘 sync → 自动补齐 28/28/28；并发 3 个全 rc=0
'''

CHK = '39 proot 不实现 flock'
if CHK in s:
    print('SKIP: 已写入')
    sys.exit(0)

# 索引行追加
lines = s.split('\n')
done = False
for i, l in enumerate(lines):
    if l.startswith('18 ') and '38 terminal 长参数空格注入' in l:
        lines[i] = l.rstrip() + ' / 39 proot 无 flock → mkdir 锁 / 40 dash 不支持 set +H'
        done = True
        break

if not done:
    print('FAIL: 未找到坑38 索引行，未写入')
    sys.exit(1)

s = '\n'.join(lines).rstrip() + '\n' + BODY2
open(P, 'w', encoding='utf-8').write(s)

t = open(P, encoding='utf-8').read()
print('written =', CHK in t, '| fix34 =', fix34, '| lines =', t.count('\n') + 1)