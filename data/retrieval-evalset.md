# 检索评测集 · v1.2 重建（20 题，期望标题取自**记忆库实际标题**）
#
# 判据（与 `bin/evo eval` 一致）：期望标题出现在
#   query_memory(folder_path="self-evo", limit=10) 返回的标题列 → 记 1-based 位置；否则 0。
#
# ⚠️ 铁律：期望标题必须与**记忆库**实际标题逐字一致（含 `/`、全角冒号、空格）。
#   v1.1 的 12 题取自账本（本地日志）标题，与记忆库命名空间不交集 —— 2026-11-13 首轮真实基线
#   实测 0/12，全部 `Memory not found`，故整表废弃重建。教训：账本 ≠ 记忆库，两套命名空间。
#   账本口径的检索效率用 `sh bin/evo search "<词>"` 评测，不走本 harness。
#
# 用法：`sh bin/evo eval start <label>` → `next` → `record <id> <rank>` → `report`
#
# 真实基线：2026-11-13 real-baseline2 = **11/12（91.7%）**，MRR 0.706，Top1 7/12
# 20 题基线：2026-11-13 baseline-20q = **18/20（90%）**，MRR 0.607，Top1 9/20
#   失手 Q10（UI DSL 契约）/ Q15（备份预算机制）—— 均为「被事件类条目挤出 limit=10」
#   Q6 rank=7 / Q17 rank=5 是次弱项（同主题多条并存时相互稀释）
#
# A/B 负结果（同日实测）：query 加域前缀【事实|机制|…】**无效且有害**
#   裸 query Q10=0 → 加前缀后返回数 10→1 仍 0；Q15=0 → 加前缀仍 0
#   结论：平台检索不认域前缀，加泛词只稀释具体词权重 → 加权必须做在数据侧
#   （条目 title 补关键词 + 事件类归档降噪），不是 query 侧
#   唯一失手 Q10：ToolPkg UI DSL 契约条被 7 条 EVO 版本/打包事件挤出 limit=10 窗口
#   （与历史 v0.16 首跑 18/20 同根因：事件类条目占窗口）
#
# A/B 负结果2（2026-11-18，v1.3 实测）：条目侧加权**无效**
#   假设：Q13 排第 4 是因为期望条目缺 query 词。于是给「机制：EVO 打包默认产物名带版本号」
#   补 tags（+toolpkg / +退役 / +产物名）并在正文首行加「检索锚点」把 4 个 query 词堆齐。
#   结果：rank **4 → 4，完全不变**；挡路的仍是两条只靠 toolpkg / 打包 命中的事件类条目。
#   结论：平台检索由**向量语义**主导，条目侧 tags / 词频微调不参与排序 —— 数据侧加权到此为止，
#   不要再往条目正文堆关键词（无收益且污染条目）。
#
#   唯一已知有效手段是把竞争条目移出 folder 窗口（归档降噪），但那等于**主动制造检索盲区**，
#   与 v1.3 的 folder_path 硬约束直接冲突（主动漏归属 = 主动制造「搜不到」缺口）→
#   **归档降噪路线否决**。Q13 rank 4 不作缺陷处理，保留为「向量检索行为标定样本」。
#
# | id | query | 期望标题 | 域 |
# |---|---|---|---|
| 1 | 闪退取证看哪个文件 dropbox | 经验:Android:dropbox 是闪退取证金矿——data_app_crash@*.txt | 经验 |
| 2 | pm install 失败 权限 SELinux | 经验:Android:pm install 读 /sdcard 被 SELinux 拦截——安装一律走 /data/local/tmp | 经验 |
| 3 | 打包字节 不收敛 振荡 | 经验:EVO:pack 字节精确记录会与压缩输出奇偶振荡——账本内不写精确字节 | 经验 |
| 4 | release 探针 不生效 DEBUGGABLE | 经验:Android:release 无 FLAG_DEBUGGABLE 导致 DEBUG_EVAL 不注册——验证必须走 debug 变体 | 经验 |
| 5 | folder_path 枚举 漏条目 | 经验:EVO:H21枚举folder_path=self-evo口径缺陷——漏无self-evo tag条目 | 经验 |
| 6 | refactor 自动应用 改代码 L2 | 决策：EVO refactor 只做 L0+L1 不做 L2 自动应用 | 决策 |
| 7 | 分发版打包 账本 模板 清空 | 事件：EVO 分发态打包 pack.sh 增加 .dist 分支并产出 EVO自进化 v1.0.0 zip | 事件 |
| 8 | distignore 开发态 分发态 排除清单 混用 | 经验：EVO .distignore 是开发态清单，与分发态打包语义相反不可混用 | 经验 |
| 9 | ToolPkg 安装 广播 参数 extras | 事件：EVO ToolPkg 安装链路打通与 0.17.2 读链路修复 | 事件 |
| 10 | 屏幕 尺寸 API 宽度 没有 | 事实：Operit ToolPkg UI DSL 真实契约（组件集合 / 点击绑定 / Modifier / Text 属性 / 屏幕尺寸与宽度 API 缺口） | 事实 |
| 11 | api_version 版本 门槛 hook 失效 | 事件：dsh-purge 1.0.2 修复 registerChatRuntimeHook 的 API 门槛 | 事件 |
| 12 | fps 计算公式 帧 窗口 | 经验:性能统计:300 帧窗口 fps 公式——fps×frameMs≈1000 自检 | 经验 |
| 13 | 打包产物名 版本号 toolpkg 退役 | 机制：EVO 打包默认产物名带版本号（EVO.toolpkg 已退役） | 机制 |
| 14 | token 开销审计 标题索引 分级读取 | 机制:self-evo-agent token 开销审计结论 | 机制 |
| 15 | 备份 双轨制 经验预算 硬顶 100 条 | 机制:记忆库备份恢复（双轨制 manifest+全文卷）与经验预算制（100 条硬顶） | 机制 |
| 16 | Skill 插件 作用域 跨对话不收集 | 经验：Skill 形态插件的作用域边界——仅在本对话加载，跨对话不自动收集 | 经验 |
| 17 | apply 白名单 C13 指纹 必然回滚冲突 | 经验：EVO refactor.sh apply 与 C13 指纹检查存在必然回滚冲突 | 经验 |
| 18 | 跨对话漏采 文明跃迁 v9 零沉淀 | 事件：跨对话漏采确认——「文明跃迁游戏开发回顾」对话完成 v9 引擎基座版但零沉淀 | 事件 |
| 19 | v0.16 六线落地 检索评测集 18/20 | 事件：EVO v0.16-dev 批次第二档+第三档六线落地封批 | 事件 |
| 20 | refactor 落地 L0 L1 R01 R07 规则 | 事件：EVO refactor.sh 落地（L0 扫描 + L1 补丁草案） | 事件 |