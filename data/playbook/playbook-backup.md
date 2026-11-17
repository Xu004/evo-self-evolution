# playbook-backup · H17/H18 备份双轨制细则（v0.15 自 SKILL.md 拆出，权威文本）

> 改本文件受 H9 保护。触发条件见 H17（v0.15 起信号化，见下）。

## H17 触发信号化（v0.15，方向9）

触发条件（公式判定，不再靠记日子）：
1. journal 写操作累计数（`grep -cE '^(create|update) ' data/journal.md`）较上次备份时 ≥ 20，或
2. 距最新 manifest 备份 > 7 天（`stat -c %Y` 对比最新 manifest-*.txt），或
3. 重大迭代后即时（P0 治理级/版本升级）。

任一满足 → 双轨同时执行。备份完成后 journal 追加 `backup` 行（含触发原因）。

## 双轨制动作

1. **清单级快照**：标题/类型/创建时间/来源，存 `/sdcard/Download/self-evo-backup/manifest-YYYYMMDD.txt`
2. **全文级导出**：全部条目全文落盘，按 ~12 条/卷分卷存 `backup-YYYYMMDD-N.md`，每卷末尾附完整性核对表
3. **写入纪律（H18）**：大文件必须逐个 `create_file` 串行写入，禁止并行（平台会截断）
4. **恢复演练**：清单核对条目数 + 全文比对双重校验；缺条用 `get_memory_by_title` 逐条确认
5. **备份范围（v0.9）**：平台记忆全文卷 + manifest + journal + waters；`data/title-index.txt` 属可重建缓存，不纳入备份。v0.15 起 data/cmd/ 与 data/playbook/ 纳入备份（属 SKILL 资产）；enum/expect/actual 中间文件不纳入。