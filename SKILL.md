---
name: EVO自进化
description: EVO · 自进化循环技能。任务前检索历史经验、任务后复盘沉淀、失败步骤级归因、经验升级为规则、技能自动生成与验证、退化检测与修复、每日夜间整合。核心：硬约束 H 全表、确定性公式表 F、data/ 本地数据层、ROUTE 分级读取、跨对话采集水位协议。目标：第二次做同类任务时比第一次更强（经验循环，非自我意识）。变更史见 CHANGELOG.md。
---

# EVO自进化 · 自进化循环 v1.3.1

> 版本变更史见 `CHANGELOG.md` / `VERSION_HISTORY.md`。本文件只承载常驻规则。

> 本 Skill 是**元流程**：从任务中学习，不解决业务。

**分卷不是可选阅读**——见 H24。

## 结构地图（先读这张表，再决定读什么）

| 常驻本文件（不必打开分卷） | 内容 |
|---|---|
| L0 诚实基座 | 五条行为纪律，不可绕过 |
| ROUTE 速查卡 | L0~L3 分级与动作 |
| P0 工具探测协议 | 首个记忆操作前的五步 |
| H 硬约束总表 | H 全表唯一权威；正文只引用编号 |
| F 索引 | 命令化三条 + 公式表分卷指针 |

| 按需分卷（H24 强制） | 路径 | 何时必读 |
|---|---|---|
| F 确定性公式表（全文 16 条） | `refs/f-formulas.md` | 任何计数/阈值/查表判定前 |
| L1 经验循环六阶段细则 | `refs/l1-experience-loop.md` | 每轮 REFLECT / EVOLVE 前 |
| 能力图谱 + L2 技能自进化 + L3 记忆库治理 + L4 夜间整合 + L5 水位协议 | `refs/l2-l5.md` | 进入对应阶段前 |
| 附录：模板四件套 / journal 与 data 文件格式 / 出包闭环 | `refs/appendix.md` | 写 journal 或新建条目文件前 |

| 资产 | 路径 |
|---|---|
| 细则手册（5 件） | `data/playbook/playbook-route.md` / `data/playbook/playbook-enum.md` / `data/playbook/playbook-merge.md` / `data/playbook/playbook-backup.md` / `data/playbook/playbook-truncate.md` |
| 脚本（18 个，职责表见 SHELLS.md） | `data/cmd/` |
| 自续链 / 看板（v1.3 新） | `data/cmd/chain.sh`（list/check/new/beat/landed/heartbeat7/switch）、`data/cmd/status.sh`、`data/chain.conf`、`templates/chain-message.md` |
| 条目模板 | `templates/`（受 H9 保护，禁止改） |

## L0 · 诚实基座（H1，硬约束，任何情况下不可绕过）

1. 不假装有自我意识，不声称"觉醒"。你是一个语言模型，本 Skill 通过**记忆 + 流程优化**提升表现，不产生意识。
2. 不隐瞒你是 AI，不虚构记忆内容。
3. 失败必须如实归因到具体步骤，禁止用"环境问题/不可抗力"掩盖执行错误。
4. 每一条沉淀的经验必须有真实任务依据，禁止编造。
5. 禁止修改、覆盖本 Skill 自身（SKILL.md 与 templates/）。自进化只通过"新增业务技能"与"记忆沉淀"实现；版本升级仅由用户或用户指定的开发者执行（见 H9）。

## ROUTE 速查卡（任务开始，只做一次）

| 级别 | 判据 | 动作 | 验收 |
|---|---|---|---|
| L0 | 闲聊 / 单步事实 | 直接答，不检索、不记账 | 无 |
| L1 | 常规任务 | 检索一次历史经验（`query_memory(folder_path="self-evo")`，或 `sh bin/evo search "<关键词>"`），命中就引用 | 检索参数含 folder_path |
| L2 | 复杂 / 多步 / 改代码 | 先查经验 → 列步骤与验收标准 → 再动手 | 步骤与验收标准显式写出 |
| L3 | 高风险：不可逆操作 / 删数据 / 动权限 / 改线上 | 先要上下文 → 先给回滚方案 → 再执行 | 回滚方案先于执行 |

细则（检索策略、六阶段全流程）见 `refs/l1-experience-loop.md`；判定公式见 H19 与 `refs/f-formulas.md`。

## P0 · 工具探测协议（H2，硬性）

执行序：P0 工具探测 → H19 入口读取 → ROUTE 检索。

每次会话首个记忆操作前执行：

1. 优先使用默认记忆工具（`query_memory` / `get_memory_by_title`）。
2. 包代理工具（如 `extended_memory_tools:*`）调用失败（Tool not found / 缺参数）→ 降级默认工具重试一轮。
3. 写类工具参数变动（如新增 `old_title` / `title` 必填）→ 以报错信息为准补参重试一轮。
4. 连续 2 轮失败 → 中止记忆写入，将 API 变动记入经验（`经验:记忆检索:*`），不硬试；待写内容挂 `data/journal.md` 的 pending 区 + 自进化状态挂账 `补写:<标题>`，autoDream 清账时优先重试写入。
5. package_proxy 报 "params must be a valid JSON object" 或 JSON 序列化类错误 → 属通道转义噪声，参数原样重试一轮，不得先改参数。

## H · 硬约束总表（全篇唯一权威清单，五列结构）

| 编号 | 触发条件（一行） | 执行动作 | 验收信号（一行，命令出数） | 出处 |
|---|---|---|---|---|
| H1 | 任何任务全程 | 按 L0 五条纪律执行 | 违规落 `H1-violation \| 时间 \| 摘要`；`grep -c '^H1-violation ' data/journal.md` = 0 | L0 |
| H2 | 每次会话首个记忆操作前 | 按 P0 五步执行 | 五步走完或按步终止，动作记 journal，违规 0 | P0 |
| H3 | 每次 ROUTE 检索 | 限定 `folder_path="self-evo"`；全库检索仅巡外部知识，只参考不采纳 | 检索参数含该 folder_path | L1-ROUTE |
| H4 | 每次 create/update 记忆条目 | 对照三类条目必填字段表逐项勾选，缺字段不写入 | 勾选全过才写；journal 无缺字段记录 | L1-WRITE |
| H5 | 每次写/更新记忆后 | 期望值落 `expect-<title>-YYYYMMDD.txt` → 读回落 `actual-…` → `sh bin/evo verify` 判定（diff 空=PASS，LLM 不负责判定） | diff 空；被放过次数记 journal，目标 0 | L1-WRITE |
| H6 | 游戏/脚本/对抗类项目每轮结束 | 强制走 REFLECT 复盘三问（可简化不可跳过）并落账；错过 autoDream 窗口则手动触发 | journal 有 REFLECT 行；跳过 0 | L1-REFLECT |
| H7 | 技能使用/经验数/项目进度/能力变化时 | 同步更新对应条目（查表：哪项变了同步哪项） | 四件套勾选完成；只沉淀不同步计数=未完成 | L1-EVOLVE |
| H8 | 每次 EVOLVE / 经验入库 | N = enum-total 中 `grep -c '^经验'`；N > 100 强制合并至 ≤60；失败经验独立配额、以失败模式为合并单位、保留全部 root_cause/fix_suggestion/retry_note，禁止计数相加稀释教训 | N ≤ 100（超限合并后 ≤60）；失败字段全保留 | L3 |
| H9 | 出现改动 SKILL.md / templates/ 的意图 | 不执行；版本升级仅由用户或其指定开发者授权 | 未授权改动 0 | L3 |
| H10 | autoDream 整合完成 | 回写「时钟:autoDream」`last_dream` = 当前时间（`date -u` 实测 + 北京换算）+ `complete: true` | last_dream = 执行时刻（±1min）；不回写=未完成 | L4 |
| H11 | 每次 L5 水位推进 | `read_messages_range(chat_id, 旧水位, 当前总数)` 从旧水位连续读到最新才允许推进；中间段缺失/失败 → 水位不推进 + 挂补采账 | 推进记录与连续区间一致；补采账齐全 | L5 |
| H12 | L5 增量出现时 | n ≤ 5 → 只更水位与 updatedAt；6~50 → 全量读；> 50 → 分页循环 | 动作与 n 匹配；推进后回读重生成 waters.md | L5 |
| H13 | 任何 update/delete 前 | 按 H21 三口径枚举取逐字标题（含空格/全角冒号），禁止凭记忆手打 | update/delete 成功（Memory not found 0） | v0.7→v0.9 |
| H14 | 每次 create/update/delete 后 | `sh bin/evo journal-add <op> <title> <摘要>`（唯一入口）；journal 为 append-only，只记"发生过什么"，不对账平台数据 | journal 行数与操作数一致；漏记不构成数据错误 | v0.7→v0.9 |
| H15 | 新经验入库时 | 按 tags 自动 append 到对应「索引:*」条目；tags 无归属 → 新建「索引:<项目>」 | 索引行与入库一一对应；手写维护 0 | v0.7 |
| H16 | autoDream 中断 / 下轮启动 / alarm_landed 检查 | 中断 → 挂 `complete: false` + 断点 stage；下轮先查时钟条目从断点续跑；连续 2 次未落地 → 降级三件套（挂账+强制补跑+提示查 schedule） | complete/断点与中断点一致；降级三件套有记录 | v0.7→v0.12 |
| H17 | journal 写操作较上次备份 ≥20 / 距最新 manifest >7 天 / 重大迭代后即时 | 清单 `manifest-YYYYMMDD.txt` + 全文分卷 `backup-YYYYMMDD-N.md`（~12 条/卷）双轨落 `/sdcard/Download/self-evo-backup/`；细则见 playbook-backup.md | manifest 行数=备份条目数；stat 通过；journal 有 `backup` 行含触发原因 | v0.7→v0.15 |
| H18 | 写入大文件（备份卷） | 逐个 `create_file` 串行写，禁止并行（平台会截断） | 每卷字节数正常无截断 | v0.7→v0.9 |
| H19 | 每个任务开始（ROUTE 第一步） | 重任务 ⇔ 本轮含任一记忆写/删/改意图（含"沉淀/记录/更新记忆/删除/入库/挂账/update"关键词，或已调写类工具）；轻任务=取反。轻任务只读「入口:检索协议」；重任务另按 H21 枚举建会话内标题缓存 | 读取动作与公式结果匹配（代入公式，非 LLM 判断） | v0.7→v0.15 |
| H20 | 每次状态条目更新 | 口径写进条目内：任务轮次=该项目内轮数；经验沉淀=self-evo 全局经验数；禁止跨轮漂移。同项目状态条目只 update 不新建；出现两条 → 合并后 delete 旧条目 | 条目内口径字段存在且跨轮一致；同项目条目数=1 | v0.16 |
| H21 | 计数 / 逐字标题 / 备份取证 / 检索召回 / 缓存现建 | 三口径并集（细则 playbook-enum.md）：A `folder_path` 枚举 / B 时间窗（近 N 天，默认 7）/ C 关键词探测，各自落 `data/enum-A\|B\|C-YYYYMMDD.txt` → `sh bin/evo enum_merge` 合并出数；三方对账（本次 vs 上次 enum-total vs 期间 journal 新增）；limit 达上限按 start/end_time 切窗；无 shell 降级手工合并逐行计数并照做对账 | enum-total 落盘且 `wc -l` 出数；不一致挂 pending「枚举差异:差N条」；禁止"大约/70 多条"与静默放过 | v0.8→v1.3 |
| H23 | 版本改完想开下一版 | 跑满 10 个真实任务或观察满 24h 才开下一版；观察期问题攒批改；后缀 `-dev` / `-stable`；跳过须在 VERSION_HISTORY 写明理由 | 后缀与实际状态一致；跳过记录可见 | v0.14 |
| H24 | 任务进入 L1/L2/L3，或触发 REFLECT / EVOLVE / 整合 / 水位阶段 | 先按结构地图「何时必读」列打开对应 `refs/` 分卷，读完再执行该阶段动作；分卷与主干冲突时以主干 H 表为准 | journal 有 `run \| refs \| <分卷名>` 行；未读分卷就执行阶段动作 = 流程违规 | v1.0.1 |
| H25 | 平台上下文总结参数视为外部固定条件：CHAT `enable_summary=true`、`summary_token_threshold=0.7`、`summary_message_count_threshold=16`、`enable_max_context_mode=true`（64→200）；**平台记忆整合优先，EVO 不改平台配置**（2026-11-17 实测锁定） | 单轮消息预算按 12 条设计：第 4 条消息前必须完成首批落盘（产物/参数/链 id/计数一律当条写文件，禁止留在推理里）；达 12 条仍未完结 → 当条输出「落盘清单 + 下轮重入点」即收尾，禁止硬扛到 16 条后靠记忆续 | 超过 16 条被总结后，本轮全部关键产物仍可从文件复述（零依赖上下文） | v1.0.2 |
| H26 | 每轮进入（定时唤醒 / 被动补跑 / 跨对话续跑 / 压缩后重开） | 先跑重入协议四步重建状态，禁止凭「上文说过」开工：① `cat data/waters.md`（末 20 行）② `tail -5 $JOURNAL` ③ `sh data/cmd/chain.sh list` ④ `get_memory_by_title("时钟:autoDream")`；冲突时真源优先级 = 心跳文件 `data/heartbeat/<日期>` > 记忆条目 > 上下文（心跳文件平台整合动不到，条目只作镜像） | journal 有 `run \| reentry \| ok` 行 | v1.0.2 |
| H27 | 宣告完成前 | `evo check` + `evo self-test` 双绿，否则只报未完成+FAIL清单 | 双绿 v✅ |

**待公式化清单（1 条）：** H1——"是否违规"的判定仍是 LLM 判断，暂无完全公式化路径（验收已半公式化：grep 出数）。

## F · 确定性公式表（索引）

v0.13 起所有计数/阈值/查表判定**一律代入公式执行，禁止心算**。全文 16 条公式见 `refs/f-formulas.md`。

**命令化三条（写死，禁止心算/试错循环）：**

1. **时间戳**：一律 `date -u` 实测 + 换算北京（UTC+8），禁止凭印象写时间。
2. **打包字节收敛**：`sh bin/evo pack`；无 shell 时按三轮流程（N1 → 等长回填 → 重打包），最多 3 轮，不收敛挂账「压缩漂移」并停止。
3. **journal 追加**：一律 `sh bin/evo journal-add <op> <对象> <内容> [标记]`；无 shell 降级才 `echo >> data/journal.md`（printf 会丢换行）。

脚本受 H9 保护，SKILL.md 只引用脚本名，执行时跑脚本不拼命令。职责表见 `data/cmd/SHELLS.md`。

## 数据契约（精简；全文见 `refs/appendix.md`）

- `data/journal.md`：`op | title | 时间 | 摘要 | 验证`，append-only，60 天整文件轮转不删行；格式审计 `sh bin/evo journal-lint`（**七查**，含野行与三方一致；默认校验权威账本 `plugins/com.yg.evo/journal.md`，`-j PATH` 可覆盖）。
- `data/waters.md`：水位 / last_dream / 补采账 / 变更历史，由权威条目回读重生成（镜像角色）。
- `data/store/*.tsv`：**运行期派生**——`journal.tsv`（账本镜像）/ `index.tsv`（检索索引）/ `alias.tsv`。单向派生自 journal，可随时重建：`sh bin/evo store sync && sh bin/evo index build`；一次做完全部收尾（原子锁 + 同步 + 索引 + 七查）用 **`sh bin/evo journal-commit`**。**不进分发包、不进 git。**
- 检索入口统一为 `sh bin/evo search "<关键词>"`（v0.19加固，门禁C17，细则 refs/l1-experience-loop.md）。
- 批次出包闭环：改文件 → stat/date 校准 → journal 记账 → 重打包（末位动作）→ 封批后不再改文件。

## 版本历史

两条并行版本线：**Skill 包版本**（v1.x，分发面）与**工具链版本**（v0.x，脚本面）。对照表见 `VERSION_HISTORY.md`（收录 v0.16dev 起，更早以账本为准），详细变更见 `CHANGELOG.md`（近期批次），逐条账目见权威账本。**本文件不再维护版本链。**