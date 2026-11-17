# EVO · 记忆的 CI

**一个零依赖、可审计的 Agent 经验账本。**

[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)
[![Runtime](https://img.shields.io/badge/runtime-POSIX%20sh%20%2B%20mawk-green)]()
[![Dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)]()
[![Gates](https://img.shields.io/badge/gates-19%20%2B%2041%20%2B%2032-success)]()

> 📄 **[完整白皮书 → WHITEPAPER.md](WHITEPAPER.md)**

---

## 问题

2026 年的 Agent 记忆赛道已经很拥挤：Mem0 做托管记忆 API，Zep 做时序知识图谱，Letta 做 OS 式记忆管理。

它们都在回答：**该记住什么、该调出什么。**

没有人回答第二个问题：

> **我记下来的这些东西，到底还对不对？**

记忆库会**污染**（录入错误结论）、会**退化**（早期好条目被后期噪音淹没）、会**不可审计**（三周后说不清当时为什么这么判断）。

这种失败是**静默的**。系统不报错，不崩溃，只是越来越不靠谱。

---

## EVO 做什么

EVO 不是记忆层。EVO 是记忆层的 **CI**。

| 软件工程 | EVO |
|---|---|
| `git` | 明文账本 + 索引 + 结构化视图（三方一致） |
| `lint` | `evo check` — 19 项结构检查 |
| `unit test` | `evo self-test` — 41 条断言 |
| `fuzzing` | `evo adv` — 32 条对抗用例 |
| `benchmark` | `evo search-eval` — 账本口径双评测集 |
| `git diff` | 账本是 Markdown 表格，可读可 diff 可回滚 |

**零依赖**：POSIX sh + mawk。没有 Python，没有向量库，没有服务，没有 embedded API 调用。能跑在手机上、air-gapped 内网、任何有 `sh` 的地方。

---

## 快速开始

```sh
# 1. 门禁（不依赖账本）
sh bin/evo self-test
# → PASS=37 FAIL=0 WARN=3
#   3 条 WARN 是「无账本 / 无 git」，公开仓库属预期，不是故障

# 2. 载入示例账本（10 条通用经验）
cp data/journal.seed.md data/journal.md
export EVO_JOURNAL="$PWD/data/journal.md"
sh bin/evo store sync && sh bin/evo index build
# → ok  store sync: 10 条
# → ok  index build: 10 条

# 3. 检索
sh bin/evo search '中文长句搜不到怎么办'

# 4. 评测（10 题公开样例集）
sh bin/evo search-eval example
```

预期输出：

```
1. [A-MISC] 中文分词策略  score=18  hits=0/1 bg=1/9
   取: get_memory_by_title("中文分词策略")
```

```
N=10  Top1=8/10  Top3=9/10  Top5=9/10  MISS=1  MRR=0.8500
```

注意 `hits=0/1` —— 整词零命中，**全靠中文 2-gram 捞回来**。这就是 v0.21 修的东西。

> 这两处失手（`为什么不用向量库` rank=0、`检索延迟多少算正常` rank=2）的原因很具体：示例条目的正文没写「向量」「延迟」这两个口语词。
>
> **可以把它改到 10/10，但那样评测集就退化成关键词匹配了。** 保留真实值。

---

## 实测（v0.21）

| 用例集 | 优化前 | 优化后 |
|---|---|---|
| 真实问法 20 题（**本机账本，未公开**） | Top-1 **2/19** · MRR **0.1053** · MISS **17** | Top-1 **17/20** · MRR **0.8812** · MISS **1** |
| 关键词回归 20 题（**本机账本，未公开**） | 20/20 | **20/20（不退化）** |
| **公开样例集 10 题（seed 账本，可复现）** | — | **Top-1 8/10 · Top-3 9/10 · MRR 0.8500** |

| 指标 | 值 |
|---|---|
| 检索延迟 | 201 ms（短） / 324 ms（600 字） |
| 检索 token 成本 | **0** |
| 账本条目 | 63（本机） / 10（公开 seed） |
| 门禁（本机） | check 19/19 · self-test 41/0/0 · adv 32 用例 |
| 门禁（公开仓库） | self-test **37 通过 / 0 失败 / 3 警告** |

> ⚠️ **口径声明**：以上全部是「**自有账本口径**」，不是 LOCOMO / LongMemEval。
>
> 我们**没有**跑过公开基准，规模与 Mem0 / Zep 差 4~5 个数量级。**请勿横向对比。**
>
> 表格里只有**公开样例集 10 题**是你 clone 下来能复现的：`cp data/journal.seed.md data/journal.md` → `search-eval example`，结果应当逐字一致。前两行含本机条目标题，评测集不随仓库发布。
>
> 详见 [白皮书 §5.4](WHITEPAPER.md#54-口径声明必读)。

---

## 与现有方案的位置

```
语义召回能力
   高 │   ●Zep      ●Mem0              ☆ 空位
      │            ●LangMem
      │  ●Basic Memory
      │ ●Cline MB
   低 │ ●CLAUDE.md              ●EVO
      └──────────────────────────────────────→ 可审计性
            低                          高
```

| | Mem0 | Zep | Letta | Cline MB | **EVO** |
|---|---|---|---|---|---|
| 依赖 | Python + 云 | 图库 | Postgres | 零 | **零** |
| 可离线 | ❌ | ❌ | ❌ | ✅ | **✅** |
| 检索 | embedding | 时序图 | 语义 | 无 | 词面 2-gram + 平台向量 |
| 可审计 | 弱 | 中 | 中 | 中 | **强** |
| 可复现 | ❌ | ❌ | 中 | ✅ | **✅** |
| **退化防护** | ❌ | ❌ | ❌ | ❌ | **✅** |
| **基准** | LOCOMO | LOCOMO | 自报 | ❌ | 自有双集 |

**右上角（强语义 × 强审计）是空的。** EVO 目前占右下；右上在路线图上。

---

## 四个关键设计决策

1. **零依赖 > 生态** — 放弃 Python，换取"十年后还能跑、air-gap 能部署"。
2. **明文 > 向量** — 放弃语义泛化，换取可 diff、可审计、可复现。
3. **纪律写入 > 自动提取** — 放弃便利，换取审计价值。**自动提取 = 不可复现 = 审计归零。**
4. **门禁 > 能跑就行** — 放弃迭代速度，换取"退化立刻红灯"。

每条都写了放弃什么、代价是什么 → [白皮书 §4](WHITEPAPER.md#4-六个关键决策)

---

## 已知边界

诚实写在这里，不藏：

- **词面检索有硬上限** — 两条已知 MISS 属语义断裂，不修，记档（[§7.1](WHITEPAPER.md#71-两条已知-miss词面检索的硬上限)）
- **规模未验证** — 63 条。500/1000/2000 条没压测过，这是当前最大未知数
- **单机单用户** — 无并发、无多租户，架构上不服务 B2B SaaS
- **写入靠纪律** — 不读文档的人会觉得难用
- **无 SDK / API** — 给人用，不是给程序调
- **无公开基准** — 刻意克制，不虚标

---

## 适用场景

✅ **适合**

- 单机 / 离线 / air-gapped 环境的 AI 助手
- 已经在用 `CLAUDE.md` / Cline Memory Bank，但文件越写越乱
- 需要回答"AI 当时为什么这么判断"的审计场景
- 把"记忆质量"当工程问题而不是功能问题的人

❌ **不适合**

- 需要海量用户会话记忆的 SaaS（→ Mem0）
- 需要语义相似度检索（→ 任何 embedding 方案）
- 需要事实时序演变（→ Zep / Graphiti）
- 想要"装好就自动记住一切"（→ 本项目明确不做自动提取）

---

## 文档

| 文件 | 内容 |
|---|---|
| [WHITEPAPER.md](WHITEPAPER.md) | 完整白皮书：问题、定位、架构、六个决策、数据、对比、边界、路线图 |
| [SKILL.md](SKILL.md) | 常驻规则：硬约束 H 总表、ROUTE 速查、公式索引 |
| [CHANGELOG.md](CHANGELOG.md) | 版本变更史 |
| `refs/` | 分卷规范（按需读，不常驻） |
| `data/playbook/` | 枚举轨 + 语义域轨 |

---

## 许可

**代码与规范** — [AGPL-3.0-or-later](LICENSE)

**判据层**（`data/` 下的评测集、门禁规则、对抗用例）— 另有商业授权。

> 为什么不是 MIT：EVO 的价值不在代码（2-gram 检索约 100 行，谁都能写），而在**踩坑积累的判据**。MIT 意味着云厂商可以包成 SaaS 白嫖且不回馈。AGPL 保留谈授权的可能。

---

<p align="center">
<sub>EVO · 记忆的 CI · 所有可复现数字均由仓库内命令产出</sub>
</p>