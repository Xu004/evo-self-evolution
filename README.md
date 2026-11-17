# EVO自进化 · 记忆的 CI

**一个零依赖、可审计的 Agent 经验账本。** POSIX sh + mawk，没有 Python，没有向量库，没有服务，没有 embedded API 调用。

> ⚠️ **这是源码树，不是分发快照。**
> 可直接运行的分发快照由 `release/build-public.sh` 产出（白名单收敛 + 路径可移植化 + 泄漏校验，60 文件 / 479K）。
> 分发快照的**用户文档**在 [`release/README.md`](release/README.md)；完整白皮书在 [`release/WHITEPAPER.md`](release/WHITEPAPER.md)。
> 📖 **安装与使用说明书 → [`docs/使用说明.md`](docs/使用说明.md)**（环境要求 / 三条安装通道 / 命令全表 / 数据备份迁移 / 8 条实测排查）

---

## 它解决什么

记忆库会**污染**（录入错误结论）、会**退化**（早期好条目被后期噪音淹没）、会**不可审计**（三周后说不清当时为什么这么判断）。这种失败是静默的——系统不报错，只是越来越不靠谱。

EVO 不提供记忆，EVO 提供记忆的 **CI**：

| 软件工程 | EVO |
|---|---|
| `git` | 明文账本 + 索引 + 结构化视图（三方一致） |
| `lint` | `evo check` |
| `unit test` | `evo self-test` |
| `fuzzing` | `evo adv` |
| `benchmark` | `evo search-eval` |
| `git diff` | 账本本身是 Markdown 表格，可读、可 diff、可回滚 |

---

## 目录

| 路径 | 内容 |
|---|---|
| `bin/evo` | 唯一入口（dispatch 到 18 个命令） |
| `lib/common.sh` | 账本三级解析、路径与输出约定 |
| `data/cmd/` | 18 个命令脚本（职责表见 `SHELLS.md`） |
| `data/playbook/` | 枚举轨 + 语义域轨细则手册 |
| `refs/` | 分卷规范（按需读，不常驻——见 H24） |
| `templates/` | 条目模板四件套（受 H9 保护，禁改） |
| `release/` | 发布线：README / WHITEPAPER / LICENSE / COMMERCIAL / CONTRIBUTING / PUBLISHING / `build-public.sh` / `ci.yml` / seed 账本 / 评测集 |
| `.githooks/` | `pre-commit` 密钥守门 |
| `SKILL.md` | 常驻规则：H 硬约束总表、ROUTE 速查、F 公式索引 |
| `CHANGELOG.md` / `VERSION_HISTORY.md` | 版本变更史 |

---

## 快速开始

### A. 在插件宿主目录下（本机形态，源码树）

```sh
sh bin/evo self-test
# PASS=33 FAIL=0 WARN=1
# WARN 是 T8「bundle 落后 HEAD」，跑 sh bin/evo bundle 刷新即可
```

> 项数会随 `data/cmd/` 下脚本数量变化，**不要把 PASS 数当不变量**；判据是 `FAIL=0`。

### B. 生成可移植的分发快照（给别处用，推荐）

```sh
sh release/build-public.sh /tmp/EVO-public
cd /tmp/EVO-public

cp data/journal.seed.md data/journal.md
sh bin/evo store sync        # ok  store sync: 10 条
sh bin/evo index build       # ok  index build: 10 条
sh bin/evo search-eval example
# N=10  Top1=8/10  Top3=9/10  Top5=9/10  MISS=1  MRR=0.8500
sh bin/evo self-test
# PASS=30 FAIL=0 WARN=3
# 3 条 WARN =「无账本 / 无 git / 无 bundle」，公开快照态属预期，不是故障
```

---

## 已知边界（诚实版，不藏）

- **源码树不可移植** — 源码树里有 17 处 `/sdcard/Download/...` 绝对路径（9 个文件，含 `lib/common.sh` L8 的默认账本路径）。只有 `release/build-public.sh` 的**产物**做了替换。**不要把源码树 clone 到别的路径当成品用**，走上面的 B 路线。
- **分发快照的文档仍有 4 处 `/sdcard/Download/self-evo-backup/`** — 路径可移植化只覆盖了脚本、没覆盖 `.md`。非 Android 机器上属错指引，命令执行不受影响（已记档，未修）。
- **不跑公开基准** — 唯一可复现的是 10 题样例集（Top1 8/10）。没有 LOCOMO / LongMemEval，本机账本规模几十条，500+ 未压测。
- **单机单用户** — 无并发、无多租户，不服务 B2B SaaS。
- **写入靠纪律** — 不自动提取经验（自动提取 = 不可复现 = 审计归零）。
- **无 SDK / API** — 给人用，不是给程序调。

---

## 门禁与 CI

两层，各管一头，不重复：

| 文件 | 在哪跑 | 守什么 |
|---|---|---|
| `.github/workflows/source-gates.yml` | **本仓库**（源码树） | `sh -n` 全量语法 + `py_compile` + `build-public.sh` 实跑 + 产物断言（`FAIL=0` / `Top1=8/10` / 无账本实体泄漏） |
| `release/.github/workflows/ci.yml` | **分发快照**（产物形态） | self-test / smoke / frontmatter 完整性 |

> `release/` 下那份是随快照一起发布的，**GitHub 不会读它**——它只在别人 clone 产物快照后生效。源码树的门禁在 `.github/workflows/`。

---

## 密钥守门

`.githooks/pre-commit` 拦：私钥头、`ghp_`、`github_pat_`、`sk-`、`AKIA`、`xox[baprs]-`、JWT 三段式；占位符（`YOUR_` / `EXAMPLE` / `PLACEHOLDER` / `REDACTED` / `xxxx` / `<...>`）自动放行。

Git **不会**自动信任仓库内钩子，clone 后需手动启用。

**情况一：普通文件系统（PC / Linux / Termux）**

```sh
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

**情况二：本仓库的宿主环境（Android / sdcard）**

sdcard 是 FUSE 挂载，`chmod` 无效（`core.filemode=false` 就是这么来的），仓库内钩子拿不到执行位，git 会**静默跳过**它。此时在 git-dir 里放一个转调壳，唯一真源仍是仓库内那份：

```sh
GITDIR=$(git rev-parse --git-dir)
printf '#!/bin/sh\nT=$(git rev-parse --show-toplevel 2>/dev/null || true)\nexec sh "$T/.githooks/pre-commit"\n' > "$GITDIR/hooks/pre-commit"
chmod +x "$GITDIR/hooks/pre-commit"
git config --unset core.hooksPath
```

> 踩坑记录：钩子不可执行时 git **不报错、不告警，直接放行**。本仓库第一次尝试就因此把一个假 token 提交进了历史（已用 `git reset --soft` 摘掉、未推送）。

---

## 许可

**代码与规范** — [AGPL-3.0-or-later](release/LICENSE)
**判据层**（`data/` 下的评测集、门禁规则、对抗用例）— 另有商业授权，见 [COMMERCIAL.md](release/COMMERCIAL.md)

> 为什么不是 MIT：EVO 的价值不在代码（2-gram 检索约 100 行，谁都能写），而在**踩坑积累的判据**。MIT 意味着云厂商可以包成 SaaS 白嫖且不回馈。