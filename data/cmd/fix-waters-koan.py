# -*- coding: utf-8 -*-
"""waters.md 坑 31-38 追加（2026-11-16 体检轮）
背景：本轮前半段用 str.replace(key) 插入坑 30-33，因 key 与文件实际文本不符全部静默失败，
      但脚本无条件 print('waters+3x') → 假成功。已确认 waters 中不存在 31-38，本次重写。
"""
import sys

P = '/sdcard/Download/Operit/skills/EVO自进化/data/waters.md'
s = open(P, encoding='utf-8').read()

IDX_ADD = (
    ' / 31 conclusion 超长静默截断 / 32 命令含 ! 触发 bash 历史展开 / '
    '33 evo_reflect 不自动 store sync / 34 reflect 与 sync 并行丢写 / '
    '35 批量替换误改历史记录 / 36 查1 只遍历白名单致统计隐形 / '
    '37 journal-lint 查空模板（最贵） / 38 terminal 长参数空格注入'
)

BODY = '''
## 坑31-38（11-16 数据体检轮）

**31 conclusion 超长静默截断**：evo_reflect 的 conclusion 超上限会被截断且不报错，账本行结论残缺。长结论分批写，或落 waters/记忆。

**32 命令含 `!` 触发 bash 历史展开**：报 `event not found`（非交互 shell 也会）。命令前置 `set +H`。

**33 evo_reflect 不自动 store sync**：reflect 后不补 sync+index，账本必然比 store 多 1 条。落账顺序固定：reflect → sync → index。

**34 reflect 与 sync 并行丢写**：sync 是「读-改-写」，与 reflect 的追加并发时用旧快照覆盖，账目直接丢失且无报错（本轮已实测复现一次）。三者必须串行。

**35 批量替换误改历史记录**：`| state |`→`| fix |` 一次改掉 3 处（2 处是历史 op）。任何批量改写前先 grep 出命中行号与条数，改完逐行复核；只改目标行用行号定位，不用全局 replace。

**36 查1 只遍历白名单致统计隐形**：白名单外 op（exp/fail/rule 占 26 条中 22 条）在分布里完全不显示，等于统计失灵。改为输出全部 op 并按条数降序，非白名单项标 `<-非白名单`。

**37 journal-lint 查空模板（最贵）**：旧版 `cd "$(dirname "$0")/.."` 落到 data/，只检查 3 行空模板 data/journal.md，真账本 26 条从未被 lint 过；同时解析假设 op 在首列（真实格式时间在首列），空文件把格式错完全掩盖——「六查全过」长期是空转。v0.17.0 已重写：默认查权威账本、`-j PATH` 可覆盖、按真实 5 列解析、表头/分隔行豁免。

**38 terminal 长参数空格注入**：超长中文命令经 terminal 传输会被插入随机空格（如「静默 截断」「白 名单」），导致后续按字符串 key 匹配全部失效。对策：内容用 create_file 落成脚本再执行，不把长文本塞进 shell 参数。

**查7（v0.17.0 新增）**：账本 / store / index 三方一致性，条数 + 对象名集合双比对，破坏测试两项均能报警并定位到具体对象名。
'''

CHK = '37 journal-lint 查空模板'

if CHK in s:
    print('SKIP: 已写入过')
    sys.exit(0)

# 1) 坑索引行追加编号（定位含「## 坑索引」的下一行）
lines = s.split('\n')
done_idx = False
for i, l in enumerate(lines):
    if l.startswith('## 坑索引'):
        for j in range(i + 1, min(i + 4, len(lines))):
            if lines[j].startswith('18 '):
                lines[j] = lines[j].rstrip() + IDX_ADD
                done_idx = True
                break
        break

if not done_idx:
    print('FAIL: 未找到坑索引正文行「18 ...」，未写入')
    sys.exit(1)

s2 = '\n'.join(lines).rstrip() + '\n' + BODY
open(P, 'w', encoding='utf-8').write(s2)

# 2) 回读校验
t = open(P, encoding='utf-8').read()
ok = (CHK in t) and ('38 terminal 长参数空格注入' in t) and ('31 conclusion 超长静默截断' in t)
print('written =', ok, '| lines =', t.count('\n') + 1)
