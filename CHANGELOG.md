# CHANGELOG · EVO自进化
## v1.3.1（2026-11-17 · 检索静默失效修复：awk=gawk 5.x）
- **根因**：`lib/search.sh` 的中文 2-gram 依赖 awk 的**字节**语义（汉字 3 字节，步长 3、取 6 字节 = 2 个汉字）。Ubuntu 26 起 `ubuntu-latest` 的 `awk` 指向 **gawk 5.3**（UTF-8 locale 下 `length/substr` 按**字符**），切片与索引里的 2 汉字对不上 → 中文长句查询 **100% MISS**，退出码/日志无任何异常（静默失效）。本机 `awk=mawk` 一直是好的，所以从未暴露
- **触发条件**：`ubuntu-latest` 自 2026-10-19 起迁移 Ubuntu 26；CI 首跑即 `Top1 8/10 → 0/10`（13 题全 MISS，`index.tsv` 10 行正常）
- **修复**：`lib/common.sh` 新增 `awkb() { LC_ALL=C awk "$@"; }`；`lib/search.sh`(3) / `lib/index.sh`(5) / `data/cmd/search-eval.sh`(2) 统一走 `awkb`。`LC_ALL=C` 强制字节模式，gawk / mawk / busybox awk 行为回归一致
- **验证**：本机装 gawk 5.2.1 并 `PATH` 前置 → `N=20 Top1=17/20 MRR=0.8812`，与 mawk 完全一致；CI 开箱 B 改为**双实现断言**（默认 awk + mawk，两边都必须 `Top1=8/10`）
- **影响面**：仅检索精度，数据无损，`index build` 无需重建；回滚 = `git revert` 本提交
- **教训**：`awk` 不是「一个东西」，是三个实现（mawk / gawk / busybox）。依赖字节语义的代码必须显式 `LC_ALL=C`，且 CI 要用两种实现各跑一遍——单实现 CI 会给出假绿

## v1.3 (2026-11-17 · 平台整合适配 + purge 归档止漏 + 存量清理)
- H25/H26 入库：平台上下文总结参数（`summary_message_count_threshold=16` 等）视为**外部固定条件**，EVO 侧改走「单轮 12 条消息预算 + 第 4 条前首批落盘」；每轮进入先跑重入协议四步，真源优先级 = 心跳文件 > 记忆条目 > 上下文
- purge 归档止漏：`archiveFoldedToMemory()` 在 `dist/main.js` 内短路（`return;/*dsh1:no-memory-archive*/`），`folderPath` 改 `'dsh-purge'` → 发布 v1.0.3（86813B，装机缓存两处标记各 1 命中）
- 存量清理：删除 16 条 dsh-purge 重复归档（3 个 chatId 各留最新 1 条，共留 3 条），台账 `data/backup/purge-archive-prune-20261117.md`
- `.distignore` 增 `data/backup/*`：本机备份目录（真实账本快照 + 清理台账）不随包外发
- 校验口径统一 + 自检体系（同日补）：类型枚举收敛为单一真源 `data/cmd/ledger-enum.conf`（plugin-lint / journal-add 均改为读它，不再各写一份）；新增 `data/cmd/self-test.sh`（34 项：sh 语法 / py 编译 / 入口 / check --fast 冒烟 / git 就绪 / 一次性脚本残留 / .gitignore 覆盖）并注册 `sh bin/evo self-test`
- H27 入库：任何「完成」宣告前必须 `evo check` + `evo self-test` 双绿，否则只能报未完成 + FAIL 清单
- `journal-add` 重写：从写已废弃的 `data/journal.md` 改为写插件账本真身（表式 5 列），默认验证标记改为「未验证」
- 账本存量修 8 处：`run`/`backup` → `state`、一行两条记录拆行、2 行补验证列、`fix` 纳入枚举
- 版本控制上线：sdcard 为 FUSE 挂载、无法承载 `.git` 实体，故 `git init --separate-git-dir=/home/evogit`，工作树仍在原目录
- **GitHub 发布线**：新增 `release/`（README / WHITEPAPER / LICENSE(AGPL-3.0) / COMMERCIAL / CONTRIBUTING / PUBLISHING / `.github/workflows/ci.yml` / `build-public.sh` / `journal.seed.md` / `search-evalset-example.tsv`）。构建期做三件事：白名单复制（零泄漏）、路径可移植化（`/sdcard/Download/Operit/...` → `${EVO_HOME:-$HOME/.evo}`，15 个文件）、泄露校验（账本实体 / 压缩包 / 账本非空 三项致命）。**公开快照不得放 `skills/` 下**（check C0 判双真身）；仓库名必须为 `EVO自进化`（C0b 校验目录名 == frontmatter name）
- `self-test` T4/T5/T8 由 FAIL 降级为 WARN：T4 判「存在 `journal.seed.md`（公开快照态）或无 store 镜像」；T5/T8 判「无 `.git`」（工作树交付属正常）。本机开发环境（有账本、无 seed）仍走 FAIL，严格性不变
- **公开包实测**：`self-test` **37 通过 / 0 失败 / 3 警告**（注：项数随 `data/cmd/*.py` 数量变化，后于发布线收敛归档 7 个 py → 变 30，勿把 PASS 数当不变量）；seed 10 条 → `search-eval example` **Top1 8/10 · Top3 9/10 · MRR 0.8500**。CI 的 `smoke` job 直接 grep 该数字，文档漂移即红
- SHELLS.md 补登 `search-eval.sh`（refactor F16 清零）；`.distignore` 增 `release/`（发布资产不进 Skill 分发包）
- **构建环境限制（记档）**：proot + overlay + FUSE 下 git 写对象不可靠（实测 `bad object HEAD`、自指 symlink、`unable to index file`），故 `build-public.sh` 只产工作树、**不建 `.git`**；git 化须在普通 Linux/macOS/Termux 或 GitHub 网页上传完成
- **发布线收敛 · 一次性补丁外泄（v1.0.4，2026-11-17）**：`build-public.sh` 用 `cp -r data/cmd/.` 白名单整目录拷贝 → `data/cmd/` 下 **6 个一次性补丁随公开快照外泄**（`fix-waters-2/3/koan.py` 会向 `waters.md` 重复追加、`fix-journal.py` 直接改写账本、`status-patch-1117.py`）。处置：`git mv` 归入 `data/archive/`（另收 `backup.py`、插件层 `pkg-lint.py`），**保留源码与改名历史**（`git log --follow` 可追），不删不改写历史。`data/cmd/` 从此只放 skill 自身可运行命令
- **排除清单 → 命名契约**：`build-public.sh` 新增两项致命断言（5.5 / 5.6）——`data/cmd/*.py` 若匹配 `fix-*.py|*-patch-*.py|*-NNNN.py` 或正文含「一次性」即 `exit 2`；`data/archive/` 存在即 `exit 2`。理由：排除清单必漏（`.distignore` 曾有 11 项遗漏的旧账），**命名模式 + 正文自述**才兜得住，新增脚本无需回来登记
- **开箱缺陷修复 · 账本三级解析**：构建期把默认值改写为 `${EVO_HOME:-$HOME/.evo}` 是对的，但公开快照没有宿主插件目录 → clone 后第一条 `evo store sync` 报「账本不存在: /root/.evo/journal.md」，且报错会把用户引向「插件未装」的错误结论。`lib/common.sh` 的 `evo_journal()` 改为三级：`EVO_JOURNAL` → 宿主插件目录 → **包内 `data/journal.md`**；另给 5 个绕过该函数、各自复制默认值的脚本（`journal-add` / `check` / `status` / `bridge-journal` / `plugin-lint`）补同构回退，**仅在用户未显式指定时生效**，开发态真账本存在则此块不动
- **CI 改真开箱**：`smoke` job 删掉 `export EVO_JOURNAL="$PWD/data/journal.md"` —— 那行正好把上述缺陷盖住（本地能跑、clone 就坏）。现在不设任何环境变量跑 seed → sync → index → eval，再 `grep 'Top1=8/10'`。README 同步删掉 `export`，补三级解析表与「第 3 级不是可选项」；`PUBLISHING.md` checklist 增「公开快照开箱验证」回归哨
- **`build-public.sh --force`**：发布是高频动作，原「目标已存在即拒跑」逼人手动 `rm -rf`（手滑风险）。改受控 `--force`，守卫「仅允许删 `*/EVO-public*` 且非 `/`、`$HOME`、`.`、`..`」。首版踩了参数解析坑：`OUT=${1:-...}` 把 `--force` 当目录名 → `mkdir: unrecognized option '--force/data'`；修成 `FORCE` 与 `OUT` 两个变量分别解析
- **公开包终态**：**60 文件 / 479K** · `self-test` **30 / 0 / 3**（30 = 归档 7 个 py 后的项数）· `store sync` 10 条 · `search-eval example` **Top1 8/10 · MRR 0.8500**（与文档逐字一致）
## v0.21 工具线 (2026-11-18 · 检索中文 2-gram + 账本口径评测)
- **中文长句检索修复**：mawk 的 `length`/`substr` 按**字节**（汉字 3 字节一字），故每 3 字节取 6 字节 = 2 个汉字做 bigram。原实现把「中文长句查询老是搜不到」整串当一个词做子串匹配 → 必然 MISS。纯 ASCII 切片（`route-stats` → rou/te-/sta）跳过；切到半截 UTF-8 的片在完整文本里天然匹配不到，无害。bigram 命中计入覆盖度分母 `(hits+bh)/(n+bn)`，不并入 hits（两个量纲混算会互相稀释）
- **新增账本口径评测**：此前**完全没有基准**——改评分函数等于凭感觉优化，分不清「变好」和「碰巧」（v1.3 的 Q13 就是这么白干的）。新增 `data/cmd/search-eval.sh` + 注册 `sh bin/evo search-eval`；**双用例集必须同时跑**：`search-evalset.tsv` 真实问法集 20 题（自然语言问句，测真缺陷）+ `search-evalset-simple.tsv` 关键词回归集 20 题（防过拟合）
- **成绩**：真实问法集 Top1 **2/19 → 17/20**，MRR **0.1053 → 0.8812**，MISS **17 → 1**；关键词回归集 **20/20 不退化**
- **修 `--all` 位置 bug**：原实现只认 `$1`，调用方写成 `index_search "$Q" --all` 时 `--all` 被并进查询词 → 静默降级 Top5 且污染覆盖度分母 n。评测脚本首版就踩了：同一题两次跑出不同 rank（15/20 与 17/20 的差就是这个）
- adv 增 A31/A32（bigram 命中夹具，query 与文本**词序不同、无整词重叠**）+ A33/A33b（`--all` 位置无关 / 默认仍 Top5）→ **32 用例 36 断言全绿**；夹具增一行专用条目
- **已知边界（不可修，记档）**：`提交前要跑哪些检查` 仍 MISS——期望条目正文写「收尾 sync→index→七查」，与用户口语「提交 / 检查」无词面重叠；词面检索不做词义映射。`中文长句查询老是搜不到` 词面零重叠（条目写「必然 MISS」），属语义检索范畴，应走平台 `query_memory`

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