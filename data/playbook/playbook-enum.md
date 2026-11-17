# playbook-enum · H21 全量枚举协议细则（v0.15 自 SKILL.md 拆出，权威文本）

> 本文件是 H21 执行细则的权威文本。SKILL.md 只引用编号。改本文件 = 改 SKILL.md 同级动作，受 H9 保护（仅用户/指定开发者授权）。

## 三口径枚举（H21 执行动作）

```
# 口径 A：folder_path 枚举
query_memory(folder_path="self-evo", query="*", limit=200) → 只取标题 → data/enum-A-YYYYMMDD.txt
# 口径 B：时间窗枚举（近 N 天，N 默认 7）
query_memory(folder_path="self-evo", start_time=<N天前>) → 只取标题 → data/enum-B-YYYYMMDD.txt
# 口径 C：关键词探测（对当前项目/场景关键词逐个探测）
query_memory(folder_path="self-evo", query="<关键词>") 多次 → 只取标题 → data/enum-C-YYYYMMDD.txt
# 合并去重出数（v0.15 起跑固化脚本，禁止现场拼命令）
sh bin/evo enum_merge
```

## 三方对账（硬性，v0.14）

本次 enum-total 总数 vs 上次 enum-total 总数 vs 期间 journal 新增条数，三者对不上必须在 journal pending 区挂「枚举差异:差N条」——禁止「大概/约/70多条」等表述，禁止静默放过。

## 引用口径

- H8 判定、备份完整性、检索召回一律引用 enum-total 的 wc -l（经验总数按 F 表 N 公式 `grep -c '^经验'`）。
- update/delete 逐字标题获取、title-index 缓存现建一律走此路径，禁止凭记忆估条目数。
- limit 达上限时按 `start_time`/`end_time` 切窗拼接（v0.12 预案）。
- 口径缺陷（v0.12.2 实锤）：folder_path 单口径系统性漏条目（无 self-evo tag 条目必漏），多口径交叉取并集是唯一口径。v0.15 首跑实锤：C 口径捕获「clean_trace.sh 项目：痕迹清理脚本」（无 tag，A/B 均漏）。
- 归因表义务（v0.15.1）：C 口径每捕获一条 A/B 漏掉的条目，追加 `data/enum-gaps.md` 一行（条目/漏检口径/归因/处置），累计看分布决定补 tag / 改口径 / 接受——禁止只并入总数不记归因。
- 平台无 shell 时降级：三次枚举结果手工合并逐行计数，计数写入 journal，三方对账照做（降级写死，不静默失败）。

## 中间文件生命周期（v0.15）

- enum-A/B/C/total-YYYYMMDD.txt：保留当日一组；enum_merge.sh 自动清理过期日期文件。
- expect/actual-*-YYYYMMDD.txt：verify.sh diff 通过后自动删除。