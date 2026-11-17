# playbook-route · ROUTE 检索细则 + 命中率管线（v0.15 自 SKILL.md 拆出，方向10，权威文本）

> 改本文件受 H9 保护。触发：每个任务开始（ROUTE 第一步，H19 分级后执行）。

## 检索动作

0. **索引直取优先（v0.16，第一档②落地）**：重任务开工先按主题查「索引:*」条目（get_memory_by_title 直取），拿到索引内相关经验/规则标题清单后逐条直取；索引直取拿不到才走语义检索。活跃项目索引：索引:文明跃迁 / 索引:clean_trace / 索引:EVO / 索引:采集软件（已并入项目状态）。
1. 至少 2 组查询（v0.12 起统一 `limit=5~10`，命中不足再换关键词补查，禁止默认返回 20 条全读省 token）：
   - 场景描述查询（如 "批量重命名 图片 经验"）
   - 关键术语查询（如 "rename|file|photo"）
2. 检索口径（H3 硬性）：一律限定 `folder_path="self-evo"`；全库检索仅用于巡查外部知识，外部条目只参考不采纳。
3. 命中"规则"类 → 严格遵循；命中"经验"类 → 决策参考，任务后更新计数。
4. 无任何命中 → 新任务，复盘走完整沉淀。
5. 已标记失效的经验不采纳。
6. **检索评测集义务（v0.16）**：调整检索策略（threshold/folder/关键词）前先跑 `data/retrieval-evalset.md` 20 题拿当前命中数，调整后重跑对比，只升不降才允许上线；未命中题优先验证 Q12/Q13。

## 检索策略（Triple Fusion 简化版）

1. **语义检索**：场景描述查记忆。
2. **关键词检索**：换关键术语再查一轮，减少漏召回。
3. **时间权重**：优先采纳近 7 天经验；更旧的需交叉验证后才用。

## P0 检索加速三件（v0.16.4-dev，用户「p0和p1一起做吧先从 p0 开始」）

三件都是**降低「检索」本身的成本**，不改召回语义；P1（folder 细分 / 索引扩容）才动结构。

### ① 会话缓存 `bin/evo route-cache`（D2）

- 时机：本轮第 2 次及以后检索**同一主题**时，先查缓存，不重复付 query_memory 成本。
- 键的写法：主题化的短键，如 `selinux安装` / `clean_trace清理` / `AXML重打包`；不要用整句问题。
- 动作序：
  1. `sh bin/evo route-cache get "<键>"`
  2. 退出码 0 → 直接用 `get_memory_by_title` 直取缓存里的标题，**不再跑 query_memory**；
  3. 退出码 2（过期）→ 按正常 ROUTE 重检，然后 `put` 覆盖；
  4. 退出码 1（无）→ 正常检索，检索完 `put "<键>" "标题1;标题2"`。
- TTL：默认 24h，环境变量 `ROUTE_CACHE_TTL` 可调；`gc` 清过期。
- 纪律：缓存只存**标题清单**，不存正文；不写记忆库（写库会污染 top10 窗口，与 Q12/Q13 同类）。

### ② 查询词库 `data/query-lexicon.md` + `bin/evo lexicon`（D3）

- 时机：ROUTE 第 2 组「关键术语查询」不再让 LLM 现编词，改为查表展开。
- 动作：`sh bin/evo lexicon "<现象词>"` → 输出 `a|b|c` 术语并集，直接作为 `query` 参数。
- 未收录（输出「词库未收录」）→ 本轮回退手编关键词，任务结束后 **append 一条新词条**（只增不删）。
- 删除词条 = 检索策略变更 → 必须重跑评测集并记 journal。

### ③ 评测 harness `bin/evo eval`（D1）

- 为什么是「状态机」而不是一条命令跑完：shell 不能调 `query_memory`，检索必须由 agent 执行。
  脚本负责出题 / 记账 / 算分，把 20 次手工调用压成「next → record」循环。
- 动作序：
  1. `sh bin/evo eval start <标签>`（标签如 `p0基线` / `p1后`）
  2. 循环：`next` 出题 → 执行题面给的 query_memory → 看期望标题在返回标题列里的位置 k（1..10）→ `record <id> <k>`，没出现记 0
  3. `report` → 命中率 / MRR / 分域 / 对比基线（18/20）
  4. 收尾把 `report` 打印的「粘贴行」写进 `data/retrieval-evalset.md` 的「策略调整后」节
- 硬性：**任何 threshold / folder_path / 关键词策略调整前后都必须各跑一轮**，只升不降才允许上线（H9 保护下的既有义务，v0.16.4 起有了工具，不再有「手工太累所以跳过」的借口）。
- 轮次记录落 `data/eval-runs/*.tsv`，不入分发包；`abort` 丢弃当前轮。

## P1 分区检索与本地索引（v0.16.5-dev，用户「直接做p1然后再一起跑基线」）


### ④ 分区检索：不迁移 folder，用「域」做逻辑分区（D4）

- 硬事实：平台 `folder_path` 是扁平命名空间字符串，78 条 self-evo 条目全部同级。真按域拆 folder = 78 次 update + H21 枚举口径归零 + 迁移期检索断层。
- 因此分区落在**索引层**：12 个域（A-ANDROID / A-SHELL / A-GAME / A-REVERSE / A-EVO / A-MISC / R-RULE / M-MECH / D-DECISION / S-STATE / E-EVENT / X-ENTRY），由 `bin/evo index build` 按账本类型列自动归类，**不改任何记忆条目**。
- 检索按域收窄：先搜目标域再放大。事件类条目（E-EVENT 24 条，占 31%）不再挤占结果窗口——这正是 Q12/Q13 未命中的结构性原因。
- 域码含义固定；新增域必须同步 `lib/index.sh` 的 `DOMAINS` 白名单，否则 C12 FAIL。


### ⑤ 本地检索索引 `data/store/index.tsv` + `bin/evo`（v1.1 重写）

- 三条命令：`evo search "<词>"`（大小写不敏感，先 AND 后 OR，单进程 awk，0.26s/次）→ HIT 直接打印可粘的 `get_memory_by_title("…")`；`evo index stats` 看分域计数；`evo store sync && evo index build` 从账本重建（**不再有手工标题清单**）。
- 索引只登记 self-evo 条目，`get_memory_by_title` 是逐字精确取而非语义检索 → **不违反 H3**。
- 扩容：`index.tsv` 是派生文件，条目上限由账本决定（设计支持 1000+，体积线性）；超 500 条按域拆表，search 改为遍历目录。
- 维护：**零手工同步**——账本一变跑一次 `evo store sync && evo index build`；条数与账本不一致时 C12 FAIL（防「索引陈旧但看起来正常」）。无账本（分发后新环境）时 C12 只校验结构。
## ROUTE 命中率管线（v0.15 新增，方向10）

- 每次 ROUTE 结束（重任务）向 `data/route-stats.md` 追加一行：`YYYY-MM-DD HH:MM | 查询词 | 命中数 | 实际采纳标题`。
- 轻任务（H19 判定：无记忆写意图）豁免记录。
- 攒满 20 行：计算命中率 = 采纳次数 / 检索次数，写入「能力图谱:ROUTE检索命中统计」条目；然后清空 route-stats.md 重新累计（旧数据保留在能力图谱条目里）。
- 命中率 < 50% → 挂 journal pending 区「检索召回低:XX%」，下次 autoDream 分析关键词策略。
## P1-D6 结构体检（v0.16.6）

- 入口：`sh bin/evo refactor scan` → `data/refactor-report.md`（全仓 1.9s，11 条规则）。
- 档位：**L0 只读 + L1 草案**。`patch F号` 出 `data/patches/*.proposal.md`；只有 R12（shebang）出真 `.diff`，`apply F号` 会先备份 → `patch -p1` → 跑全量 `check.sh` → 失败自动回滚。
- 为什么不做 L2 自动应用：全仓 11 个脚本 / 465KB，重复代码主要是 ROOT 定位与 log 函数，能省 40~60 行；文本级自动改 shell 的风险成本远大于收益，且自动改代码必须留人工审查断点（与「加固必留可调试通道」同一条原则）。
- 三条硬红线：不重排格式（shell 语义依赖换行/续行）、不跨文件自动抽函数（抽 common.sh 引入 source 依赖，破坏单文件可跑）、不改 SKILL.md（宪法文本只许人改）。
- 自举：`refactor.sh` 自己也受全部 R 规则扫描，它命中 R08/R12 属正常——那正是「该抽 common.sh」的证据。
- 新鲜度：报告内嵌源码 md5（`cat data/cmd/*.sh data/*.sh SKILL.md | md5sum`），源码一改即陈旧 → **C13 FAIL**。
- 首跑实证：16 条发现，其中 R23 抓到 `SHELLS.md 写「跳过 7」，实际 skip 分支 10 个`——文档数字漂移类错误人眼几乎无法覆盖。
