# 发布手册

给维护者看的。**发到 GitHub 之前逐条走一遍，尤其第 0 步。**

---

## 0. 前置审计（最关键，别跳）

### 0.1 确认账本没进 git

```sh
cd <开发仓库>
git ls-files | grep -E 'journal|waters|store/|backup/'
```

**如果有输出 —— 停止。** 说明真实账本已被 git 追踪。此时**不能**从本仓库 push 任何分支，包括孤儿分支之外的历史。

本项目的历史里确实有：

```
data/backup/journal-2026-11-16.md
data/backup/journal-2026-11-17.md
data/backup/journal-20261117-prelint.md
data/backup/waters.bak.1116
```

所以发布流程**必须**走 `release/build-public.sh` 的干净快照，**禁止** `git push` 开发仓库。

### 0.2 为什么不能用 `git filter-branch` 洗历史

可以洗，但：

- 洗过的仓库所有 commit hash 变化，已有 clone 全部失效
- GitHub 侧被 fork / 被 API 抓取 / 被缓存的内容**洗不掉**
- 洗历史本身是一次高风险操作，容易误删正常提交

**成本对比**：重新 init 一个干净仓库 = 5 分钟且零风险；洗历史 = 半天且不可逆。选前者。

---

## 1. 生成公开快照

```sh
cd <开发仓库>
sh release/build-public.sh
```

默认输出到 `<repo>/../EVO-public`，并自动完成：

| 步骤 | 动作 |
|---|---|
| 1 | 白名单复制（`SKILL.md` `bin` `lib` `refs` `templates` `CHANGELOG.md`） |
| 2 | `data/` 只带 `cmd/` `playbook/` `adversarial-tests.tsv` `adv-fixture.tsv` `query-lexicon.md` `chain.conf` |
| 3 | 空账本模板 `data/journal.md`（0 条目） |
| 4 | 脱敏评测样例 `data/search-evalset.tsv`（10 题，满足 C15） |
| 5 | 文档五件套 + `LICENSE` + `.github/` |
| 6 | 泄露校验（见下） |
| 7 | `git init` + 单条提交（历史数 = 1） |

### 泄露校验的判定

**致命（中止，不建 git）**

- `data/store/`、`data/backup/`、`data/waters.md`、`data/route-stats.md`、`data/route-cache.md`、`data/enum-gaps.md`、`data/retrieval-evalset.md` 存在
- `*.zip` / `*.bundle` 存在
- `data/journal.md` 条目数 ≠ 0

**警告（人工确认）**

- 含 `/sdcard`、`Download/Operit`、`com.yg.evo` —— 多为脚本里的平台默认值（如 `check.sh` 的 `EVO_PLUGIN_JOURNAL` 默认路径）。发布前确认这些默认值可公开。

---

## 2. 仓库命名（硬约束）

```
仓库名必须是：EVO自进化
```

原因：`check` 的 **C0b** 校验「当前目录名 == `SKILL.md` frontmatter 的 `name`」。GitHub 仓库名决定 clone 后的目录名。

改名的话必须同步改 `SKILL.md` 第 1 行 `name:`，否则 C0b 红灯。

---

## 3. 推送

```sh
cd ../EVO-public
git remote add origin git@github.com:<OWNER>/EVO自进化.git
git push -u origin main
```

推完立刻验证：

```sh
git ls-remote origin
# 只应有 1 个 commit
```

---

## 4. 推送后验证清单

| # | 检查 | 命令 / 位置 |
|---|---|---|
| 1 | 历史只有 1 个 commit | GitHub 页面 commit 数 |
| 2 | 没有账本 | 仓库内搜 `journal.md` → 应是模板（4 行注释） |
| 3 | 没有 zip | 文件列表无 `*.zip` |
| 4 | CI 绿灯 | Actions → `gates` → `self-test` 通过 |
| 5 | clone 后可跑 | 见下 |
| 6 | LICENSE 可识别 | 仓库页右上角显示 AGPL-3.0 |

```sh
# 陌生环境验证（模拟新用户）
git clone git@github.com:<OWNER>/EVO自进化.git /tmp/verify && cd /tmp/verify
chmod +x bin/evo data/cmd/*.sh
sh bin/evo self-test        # 应 41 通过 / 0 失败
```

---

## 5. 误推了账本怎么办

**立刻做，别等。**

1. 仓库 Settings → 设为 private（阻断抓取）
2. 删掉远端仓库，重新用干净快照建
3. 若已公开超过数小时：假设已被抓取，**轮换账本里出现过的所有敏感信息**（绝对路径不算秘密，但项目名、密钥、内部域名算）
4. 记录事故到 `CHANGELOG.md`（这个可以写，不涉密）

**不要**在公开仓库开 issue 讨论泄露细节。

---

## 6. 版本发布

```sh
# 打 tag（在公开仓库里）
git tag -a v1.0.0 -m "EVO v1.0 · 记忆的 CI"
git push origin v1.0.0
```

Release 说明模板：

```markdown
## EVO v1.0.0 · 记忆的 CI

零依赖、可审计的 Agent 经验账本首个公开版本。

### 本版内容
- 中文 2-gram 检索（真实问法集 Top-1 2/19 → 17/20）
- 三级门禁：check 19 / self-test 41 / adv 32
- 账本口径双评测集框架

### 可复现范围
`self-test` 41 条断言可在任意环境复现。
`check` / `adv` 依赖本地账本条目，公开仓库中不完整（预期行为）。

### 已知边界
见 WHITEPAPER §7。
```

---

## 7. 每次发版前 checklist

- [ ] `sh bin/evo check` 在开发机全绿
- [ ] `sh bin/evo self-test` **FAIL=0**（PASS 数随环境变：开发机有账本/git/bundle，公开快照只有 30 项，别对数字做断言）
- [ ] `sh bin/evo adv` 全绿
- [ ] `CHANGELOG.md` 已更新且版本号与 `SKILL.md` 一致（C4）
- [ ] `sh release/build-public.sh --force` 泄露校验 0 致命（含两项新断言：`data/cmd/` 不得有一次性补丁、`data/archive/` 不得外发）
- [ ] **公开快照开箱验证**（回归哨，别跳）：
      ```sh
      cd <公开快照>
      cp data/journal.seed.md data/journal.md
      sh bin/evo store sync        # 不设 EVO_JOURNAL / EVO_HOME
      sh bin/evo search-eval example
      ```
      期望 `Top1=8/10`。若报「账本不存在: ~/.evo/journal.md」，说明 `evo_journal()` 的第三级回退被改坏了。
- [ ] 公开快照 `git rev-list --count HEAD` == 1
- [ ] `WHITEPAPER.md` / `README.md` 里的数字与实际一致
- [ ] 新增的评测集**没有**误入公开包

---

<p align="center"><sub>EVO · 发布手册</sub></p>