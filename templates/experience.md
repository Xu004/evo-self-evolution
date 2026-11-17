# 经验条目模板（v0.10）

> 复制此模板沉淀经验。存储到平台记忆系统，标题格式：`经验:<场景>:<一句话结论>`
> 更新/删除前必须按 H21 枚举取逐字标题：`query_memory(folder_path="self-evo", query="*", limit=100)` 结果中的标题为准（含空格/全角冒号），禁止凭记忆手打。`data/title-index.txt` 为可丢弃缓存，不作为标题来源。

## 条目

- **适用场景**：（何时检索命中，写具体，别写"日常任务"）
- **一句话结论**：（核心经验）
- **关键步骤**：
  1.
  2.
  3.
- **坑 / 反例**：
  -
- **计数**：success: 0 / fail: 0
- **失败教训字段**（仅失败条目填，v0.13 枚举化）：
  - failure_step（枚举）：ROUTE / EXECUTE / REFLECT / ATTRIBUTE / WRITE / EVOLVE / 工具调用 / 其他
  - root_cause（枚举分类 + 一句话）：规则缺陷 / 执行遗漏 / 工具行为 / 口径漂移 / 环境
  - fix_suggestion / retry_note
- **淘汰评分**：access_count: 0 / last_access: YYYY-MM-DD / verified: true|false（唯一时间锚点：每次命中复用后同步更新；连续 60 天 last_access 未更新且非规则类 → 归档删除）
- **状态**：活跃 / [失效]

## 更新规则

- 每次命中复用后：success +1 或 fail +1，access_count +1，更新 last_access。
- 写入/更新后必须回读验证：`get_memory_by_title` 读回，核对必填字段与计数，不符立即补写。
- 写入后向 `data/journal.md` 追加一行（H14 纯审计，append-only）。title-index.txt 为可丢弃缓存，无同步义务，会话内按 H21 枚举现建、结束即弃。
- 连续 success ≥3 → 升级为规则（标题改 `规则:` 前缀）。
- 成功率 <20% → 状态标 `[失效]`，ROUTE 不再采纳。
- 失败经验（fail 计数 > success 计数，或条目内标记失败教训）独立配额（H8/L3）：不参与成功率排序合并，以失败模式为合并单位，合并保留全部 root_cause / fix_suggestion / retry_note，禁止计数相加稀释教训。

## 附：规则条目字段示例

> 标题格式：`规则:<场景>:<规则内容>`。规则由经验升级而来，不单独原创。

- **触发条件**：（什么场景下必须遵守）
- **规则内容**：（一句话可执行指令）
- **来源经验引用**：（`经验:<场景>:<结论>` 标题，≥3 次 success 的升级来源）
- **状态**：活跃 / [失效]