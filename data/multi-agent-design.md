# multi-agent-design · 多 Agent 命名空间预留设计（v0.16，未启用）

> 状态：纯设计文档，不参与运行。启用条件：用户拍板「多 Agent 共用记忆」。
> 定位：回答「如果 EVO 要变成多 Agent 记忆系统，迁移路线是什么」——把今天单 Agent 的每一层对应到多 Agent 形态，避免到时候推倒重来。

## 1. 现状（单 Agent）与多 Agent 形态的映射

| 层 | 现状（单 Agent） | 多 Agent 形态 | 迁移代价 |
|---|---|---|---|
| 记忆空间 | folder_path="self-evo" 单一命名空间 | 每 Agent 一个 folder（如 self-evo / agent-x），共享层另设 shared/ | 低——folder 天然隔离，无需改结构 |
| 五层 schema | title 前缀：经验:/规则:/机制:/事件:/项目状态: | 前缀加 Agent 标识或保留前缀 + folder 隔离 | 低——前缀不变，隔离靠 folder |
| 链接层 | 单命名空间内链接 | 跨 Agent 链接需限定 link 两端归属；同 Agent 链接不变 | 中——跨 Agent 链接语义要先定（引用/委托/通知） |
| 检索口径 | H3 限定 folder_path="self-evo" | 先查本 Agent folder，未命中再查 shared/，最后查其他 Agent（需权限） | 低——检索协议加一级 fallback |
| 计数/淘汰 | H8/H21 全局口径 | 按 Agent 各自计数，shared/ 层独立配额 | 低——枚举加 folder 过滤 |
| 状态条目 | 自进化状态单条权威 | 每 Agent 一条「状态:<Agent名>」+ 一条「状态:全局」 | 中——单一权威表要拆两级 |
| journal/waters | 单文件本地 | 每 Agent 一个 data/ 目录 | 低——目录级隔离 |

## 2. 三个必须先拍板的决策（未拍板，本设计不生效）

1. **共享层边界**：哪些经验跨 Agent 共享？默认建议：规则类全部共享（规则是全局基线），经验类默认私有、被 ≥2 个 Agent 命中后才晋升 shared。
2. **写冲突**：两个 Agent 同时更新同一状态条目怎么办？默认建议：状态类条目按「最后写入者 + 时间戳」收敛，冲突挂 journal 裁决——不搞分布式锁，平台没这能力。
3. **身份与权限**：Agent 之间是否可以互相读/删？默认建议：只读共享层，删除一律需用户确认。

## 3. 迁移路线（启用时按序执行）

1. 新建 Agent folder，复制五层 schema 与 H 表/F 表执行框架（EVO 包为共享执行器）。
2. 拆分共享层：规则类条目 move 到 shared/，自进化状态拆「状态:<Agent名>」。
3. 检索协议加 fallback 链：本 Agent → shared/ → 其他 Agent（需权限）。
4. 链接层加跨 Agent 链接类型：REFERENCES（引用）/ DELEGATES（委托）/ NOTIFIES（通知）。
5. 计数与备份改按 folder 分组执行。

## 4. 明确不做的

- 不做分布式一致性：平台记忆库是单点，接受最终一致。
- 不做 Agent 间自动同步：跨 Agent 信息流动一律走 autoDream 式定期整合，不搞实时。
- 不做共享层自动晋升：晋升 shared 必须满足「≥2 个 Agent 命中」公式且由用户确认。

## 5. 回滚

启用前全量备份（H17 双轨制）；任何一步跑不通，删除新 folder 即回到单 Agent 形态，主命名空间零改动。