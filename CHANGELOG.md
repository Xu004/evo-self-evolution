# CHANGELOG · EVO自进化
## v1.3 (2026-11-17 · 平台整合适配 + purge 归档止漏 + 存量清理)
- H25/H26 入库：平台上下文总结参数（`summary_message_count_threshold=16` 等）视为**外部固定条件**，EVO 侧改走「单轮 12 条消息预算 + 第 4 条前首批落盘」；每轮进入先跑重入协议四步，真源优先级 = 心跳文件 > 记忆条目 > 上下文
- purge 归档止漏：`archiveFoldedToMemory()` 在 `dist/main.js` 内短路（`return;/*dsh1:no-memory-archive*/`），`folderPath` 改 `'dsh-purge'` → 发布 v1.0.3（86813B，装机缓存两处标记各 1 命中）
- 存量清理：删除 16 条 dsh-purge 重复归档（3 个 chatId 各留最新 1 条，共留 3 条），台账 `data/backup/purge-archive-prune-20261117.md`
- `.distignore` 增 `data/backup/*`：本机备份目录（真实账本快照 + 清理台账）不随包外发
## v0.17.1 工具线 (2026-11-16 · 收尾工具 journal-commit)
- 新增 `data/cmd/journal-commit.sh`，并注册 `sh bin/evo journal-commit`：**mkdir 原子锁 → store sync → index build → 七查自检**，退出码 0 一致 / 1 等锁超时 / 2 违规
- 幂等自愈（sync 与 index 条数不等自动再跑一轮）；只读校验（绝不改写账本，账本归 `evo_reflect` 专属写域）
- 实测：正常态 27/27/27 rc=0；账本 +1 行模拟忘 sync → 自动补齐 28/28/28；**并发 3 实例全部 rc=0、无锁残留**
- 环境适配三坑：proot 不实现 flock（坑39）→ mkdir 锁 + pid 存活检测 + trap 释放；dash 不支持 `set +H`（坑40）；库根与账本分属两个根（SELF/ROOT/OP 三级解析）
- **归因修正**：坑34「sync 与 reflect 并发覆盖账本」证据不足——sync 只读账本只写 store；真凶更可能是 conclusion 超长静默失败（坑31）
## v0.17.0 工具线 (2026-11-16 · journal-lint 七查重写)
- 老版长期空转：只校验 3 行空模板 `data/journal.md`，真账本从未被检查，且列序解析与真实账本相反（坑37）
- 重写：真实 5 列解析（op|title|时间|摘要|验证）、默认校验权威账本、`-j PATH` 覆盖
- 新增**查7 三方一致**：账本条数/对象名集合 vs `store/journal.tsv` vs `index.tsv`；破坏测试（丢行、改名、污染）均能报警
## v1.2 (2026-11-13 · 20 题评测集 + A/B 负结果 + 调用面全量统一)

- 评测集 12 → 20 题（新增 机制 3 / 经验 2 / 事件 3）→ **18/20（90%），MRR 0.607，Top1 9/20**
- **A/B 负结果**：query 域前缀无效且有害（Q10 返回数 10→1 仍 0 命中）→ 检索加权必须做在数据侧（title 补关键词 + 事件条目归档降噪），不是 query 侧
- 调用面全量统一：SKILL.md 6 处 / playbook 5 处 / refs 3 处 / data 2 处 `sh data/cmd/x.sh` → `sh bin/evo x`；全仓仅余 CHANGELOG 历史与 SHELLS.md 说明行
- 14 个脚本 `# 用法` 头与 usage() 输出统一为 `sh bin/evo <名>`；`check` 用法头「全量 13 项」→ **18 项**
- 修正 SHELLS.md `--fast` 边界：跳过项 10→ **13**（实测 18 槽位：5 通过 + 13 跳过），补齐 C14/C15/C16 名单
- 包体约 97KB / 50 文件

## v1.1 (2026-11-13 · 引擎收口 + 真实检索基线)

- 旧手工索引退役：删 `data/cmd/index.sh` / `data/memory-index.md` / `data/memory-titles.txt`；5 处引用点全部改指 `bin/evo`
- `bin/evo` 增转发子命令：check / pack / dist / eval / refactor / verify / enum_merge / rotate-journal / bridge-journal / plugin-lint / journal-lint / journal-add / route-cache / lexicon → `data/cmd/<名>.sh`；短别名 route / enum / rotate / bridge / journal。旧式 `sh data/cmd/x.sh` 继续可用
- **评测集 v1.2 重建**：账本 ≠ 记忆库（账本 15 条从未 create 进平台，`get_memory_by_title` 全部 Memory not found）；旧 12 题期望的是账本标题 → 真实基线 **0/12**
- 用记忆库真实标题重建 12 题 → **真基线 11/12（91.7%），MRR 0.706，Top1 7/12**；唯一失手 Q10 被事件条目挤出 limit=10 窗口（与 v0.16 首跑 18/20 同根因）
- 包体 100,522 B → **约 97KB / 50 文件**（精确值以 `ls -l EVO自进化.zip` 为准，账本/文档不写精确字节）

### 教训（1 条）

- 评测集的期望标题必须取自**被测检索空间**。账本（本地日志）与记忆库（平台条目）是两套命名空间，混用会得到 0% 的「看起来像全线崩」的假红——实际是题出错了，不是检索坏了。

## v1.0.1 (2026-11-13 · C 档引擎化 + 上下文瘦身)

- **上下文瘦身**：SKILL.md 42,589 B → 12,494 B（-70.7%）。F 表 / L1 六阶段 / L2~L5 / 附录拆至 `refs/` 四卷，主干保留 L0 + ROUTE 速查卡 + P0 + H 总表 + 数据契约。
- **新增 H24**（分卷强制读取）与门禁 **C14**（主干 ≤14,336 B）——没有这两条，瘦身会在下个版本被加回去。
- **C 档引擎**：`bin/evo` + `lib/common.sh` / `lib/store.sh` / `lib/index.sh`。账本 `journal.md` → `data/store/journal.tsv` → `index.tsv` **单向派生**，取代手工 `memory-titles.txt`（改造前索引实测 0 条）。
- **索引 8 列**，新增 `verify` 证据列（只出现在日志里的术语现在可搜）；分域改判**类型列**而非标题前缀（修复 10/10 全落 `S-STATE`）。
- **C12 改指新引擎**：`bin/evo index check`（结构 8 列 + 新鲜度 index 条数 == journal.tsv 条数），退出码 4=无索引(可重建) / 6=陈旧(必须 rebuild)。
- **新增 C15**（评测集 ≥10 题）与 **C16**（refs 分卷无孤儿，双向校验）；评测集建 12 题，全部取自真实账本。
- **打包门禁**：分发态内联排除清单补 `data/store/*`（实测漏包 journal.tsv 6,704 B + index.tsv 11,261 B 被 guard 抓住）；`guard_pkg` 判据补 `*.tsv`。
- **备份/回档**：`restore.sh`（verify/cold/git/commit/diff/bundle/list）+ 冷备/热备/bundle 三轨。git 仓库移至 proot `/root/evo-git`（`/sdcard` 为 FUSE，git 写 objects 必失败），bundle 单向回写磁盘。

## v1.0.0 (分发版首发)

- 源自开发态 skill 的当前快照（生成器：`data/cmd/dist.sh`，口径：`.distignore`）
- 功能面：ROUTE 分级读取 / 硬约束 H 表 / 确定性公式 F / journal 账本 / 结构体检 refactor / 门禁 check / 打包 pack
- 分发态差异：
  - 运行期账本为空模板（journal / waters / route-stats / route-cache / enum-gaps / retrieval-evalset / memory-index）
  - 结构报告未生成 → 首次请跑 `sh data/cmd/refactor.sh scan`
  - 备份时效检查 C9 = N/A（`data/.dist` 标记）；删掉该标记即恢复强制
  - 记忆索引下限 0 条（冷启动）；`index.sh build` 后自动填充
- 首次上手：
  1. `sh data/cmd/check.sh`（应 15/15）
  2. `sh data/cmd/refactor.sh scan`
  3. `sh data/cmd/index.sh build`

## v1.3 (2026-11-14 · 自续链 v1.1 硬化 + 可观测层)
- 修坑25：send→delete 增挂 `on_failure`（send 失败也删除，防任务残留导致次日双触发）
- 修坑26：容器默认 TZ=UTC → 脚本内 `TZ=Asia/Shanghai; export TZ`（凌晨 03:00 用 UTC 取日期会错一天，心跳/landed 全错位）
- 新增 `data/cmd/chain.sh`（list / check / new / beat / landed / heartbeat7 / switch）+ `data/chain.conf`（CHAT_ID / ROLE_CARD 外置）
- 新增 `data/cmd/status.sh` → `data/status.md` 单页看板
- 新增 `templates/chain-message.md` 标准 message 模板（①心跳去重 ⑥禁 sed ⑦beat+lint+status ⑧chain new 查重）
- 心跳机制落地 `data/heartbeat/YYYY-MM-DD`，补记 11-13 / 11-14
- 时钟条目瘦身 2.5KB → 250B，坑全集拆至记忆「坑档案:EVO」
- workflow `fe356aea` message 改版生效（patch op=update 可用，记入坑档案）