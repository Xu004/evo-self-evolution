# playbook-truncate · journal 60 天截断动作序列（v0.15 自 SKILL.md 拆出 + 脚本化，权威文本）

> 改本文件受 H9 保护。首批到期：12 月底。

## 动作序列（v0.11 定稿，v0.12 改整文件轮转，v0.15 脚本化）

1. **T-7**：核对备份覆盖——无卷级快照先补 H17 双轨备份（按 playbook-backup.md）。
2. **T0**：截断窗口行与 waters.md/记忆库关键条目交叉比对，确认信息已双写无缺口。
3. **执行（脚本化）**：`sh bin/evo rotate-journal`——journal.md 整体 `mv` 为 `/sdcard/Download/self-evo-backup/journal-archive-YYYYMM.txt`，新建含头部规则的空 journal.md 续写；禁止「删除部分行」——append-only 原则下截断 = 整文件轮转，不 = 删行。
4. **回写**：waters.md 追加截断审计行 + 自进化状态挂账清账。
5. **防膨胀**：不建记忆库归档条目（备份文件即归档，H8 口径只统计 `经验:` 前缀）。