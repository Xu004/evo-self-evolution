# refs · 附录（模板/data 格式/版本历史）

> 自 SKILL.md v1.0.0 主干拆出（v1.0.1 上下文瘦身），内容原样保留、未改写。


### 模板四件套（v0.12 起四件）

- `templates/experience.md`：经验条目（含淘汰评分三字段 + journal 追加义务）
- `templates/capability-map.md`：能力图谱（多条命名 `能力图谱:<领域>`）
- `templates/skill-proposal.md`：新技能提案（含核心自锁与 journal 义务）
- `templates/rule.md`（v0.12 新增）：规则条目（触发条件 / 规则内容 / 来源经验引用，H4 必填字段模板）

### data/ 文件格式

- `title-index.txt`：会话内标题缓存，按 H21 枚举现建，会话结束即弃，腐坏即重建
- `journal.md`：`op | title | 时间 | 摘要 | 验证`，append-only；op 枚举 create/update/fix/move/pack/copy/verify/backup/enum/route/run/delete/link/eval/H1-violation（v0.15 扩充 verify/backup/enum/route/run，v0.16 扩充 delete/link/eval）；时间精确到分（mtime 校准，无法溯源标区间）；验证标记 v✅/v批/v—；60 天截断 = 整文件轮转 mv 归档（v0.12，不删行）；格式六查审计 `sh bin/evo journal-lint`（v0.16.1 起含查6 野行：行首非合法 op 一律报出）
- `waters.md`（v0.12 四段定式，v0.15 镜像化）：水位 / last_dream / 补采账 / 变更历史；由权威条目回读重生成，镜像角色见 L3 单一权威表
- `enum-*.txt`（v0.14 起）：枚举落盘文件——A/B/C 三口径 + 合并的 enum-total；计数一律 `wc -l`/`grep -c` 出数；三方对账差异挂 journal pending 区；保留当日一组，过期由 enum_merge.sh 清理（v0.15）
- `expect-*.txt` / `actual-*.txt`（v0.14 起）：H5 diff 验证落盘文件（字段名|期望值 格式）；verify.sh PASS 后自动清理（v0.15）
- `cmd/*.sh` / `playbook/*.md` / `route-stats.md`（v0.15 起）：脚本五件 / 细则五件 / 命中率累计，职责见 L3 data 层表
- **批次出包闭环（v0.10.4 补丁，硬性）**：版本批次内动作顺序固定——改文件 → stat/date 校准真实时间（super_admin terminal 为 UTC，北京时间 = UTC+8）→ journal 记账（时间戳按校准值写）→ 重打包（批次末位动作）→ 封批后不再改任何文件。若封批后才发现时间戳/内容错误，修正并入下一批次，禁止「打包后改文件再打包」的漂移循环（2026-11-09 教训：初记 03:2x 实为 09:18）。

### 版本历史

见 `VERSION_HISTORY.md`（v0.1~v0.16.3 全链）与 `CHANGELOG.md`（近期批次）。本文件不再维护版本链。
