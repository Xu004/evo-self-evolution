【EVO autoDream 定时唤醒 {T}】按 SKILL.md L4 执行六阶段：
⓪ 先 `date '+%F %T'` 核对：若实际日期已晚于 {T} 的日期（调度延迟跨日），⑧ 的目标时间改为「实际日期+1 03:00」，绝不可建过去时间的链（坑28）。
① 先跑 `sh data/cmd/chain.sh landed`：若今日已有心跳，说明重复触发 → 直接跳到⑧并自删，不重复整合。
② 读「时钟:autoDream」比对 last_dream（应 = 上一跳日期或更晚）。
③ 六阶段：冗余扫描 / 同场景合并 / 失效标记 / 索引一致性 / 链接噪音抽查（链接数校准用 query_memory_links limit=200 读 totalCount）。
④ 简报 ≤200 字写入「自进化状态」简报段。
⑤ 更新「时钟:autoDream」：last_dream={T}、complete=true、alarm_landed 追加本轮、自续链 id 换成⑧新建的。
⑥ 水位回读比对，同步 data/waters.md（中文 md 一律 delete_file + create_file 全篇重写，禁用 sed -i —— 坑23）。
⑦ 记账一律 evo_tools:evo_reflect（禁用 sh bin/evo journal-add —— 坑22）；随后：
   `sh data/cmd/chain.sh beat`（写心跳）
   `sh data/cmd/journal-lint.sh`（六查，结果写进简报）
   `sh data/cmd/status.sh`（刷新看板）
⑧ 建次日链：先 `sh data/cmd/chain.sh new "{NEXT_T}"` 查重（坑24 防双触发），通过才 create_workflow，并 patch 自删节点（on_success + on_failure 两条连线）。
异常：本消息若未在 {T} +10min 前落地，次日按心跳缺失记 ❌；连续 2 次按 H16 降级被动通道。
取证：${EVO_HOME:-$HOME/.evo} 为唯一真身；所有文件核对走 super_admin:terminal（坑19：read_file 在中文路径会误报）。