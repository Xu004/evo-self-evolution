# data/archive · 本机运维归档（不外发）

这个目录**不是**废弃箱，是「已完成使命但必须留痕」的脚本归档。

## 为什么留着而不删

1. **可追溯**：这些脚本改过真实账本/真实看板，出了问题要能回看当时到底执行了什么。
2. **不重复造轮子**：同一类补丁三个月后可能还要写一次，先看当时怎么写的。
3. **交付契约**：源码只增不删；归档优于删除，删除优于改写历史。

## 为什么不能待在 `data/cmd/`

`data/cmd/` 是**可运行命令目录**，`SKILL.md` / `SHELLS.md` / `bin/evo` 都从这里取入口。
把一次性补丁放进去会造成三个后果：

- `release/build-public.sh` 用 `cp -r data/cmd/.` 白名单整目录拷贝 → **一次性脚本会跟着进公开仓库**（2026-11-17 实际发生过：6 个脚本外泄到公开快照）。
- 用户以为这些是可执行工具，跑了会二次污染账本（多数是追加型，非幂等）。
- 路径全硬编码本机 `/sdcard/Download/Operit/...`，对任何其他人都是垃圾。

## 内容清单

| 文件 | 性质 | 为什么不能重跑 |
|---|---|---|
| `oneshot/fix-waters-2.py` | 一次性补丁 | 往 waters.md 追加坑 39/40，重跑会重复追加 |
| `oneshot/fix-waters-3.py` | 一次性补丁 | 追加坑 41，同上 |
| `oneshot/fix-waters-koan.py` | 一次性补丁 | 追加坑 31-38，同上 |
| `oneshot/fix-journal.py` | 一次性修复 | 直接改写账本 + 从 `data/backup/` 取旧版回填 |
| `oneshot/status-patch-1117.py` | 一次性补丁 | 改 `status.sh` 显示层，已合入当前版本 |
| `backup.py` | 零引用工具 | 双轨备份（manifest + 分卷），功能已被 `rotate-journal.sh` 覆盖 |
| `plugin-layer/pkg-lint.py` | Operit 插件层检查器 | 检查的是 `plugins/com.yg.evo/*.js`（Operit 插件代码），公开仓库不含插件源码，跑起来只会空转报错 |

## 恢复方式

历史没有丢，`git log --follow` 能看到完整改名记录：

```sh
# 看某个脚本的历史
git log --follow --oneline data/archive/oneshot/fix-waters-2.py

# 需要临时用一次：直接按原路径跑（先读一遍再跑）
sh -c 'python3 data/archive/oneshot/xxx.py'
```

## 纪律

- 新增一次性脚本 → **直接写进 `oneshot/`**，不要放 `data/cmd/`。
- `release/build-public.sh` 有守卫：`data/cmd/` 下若出现 `fix-*.py` / `*-patch-*.py` / `*-NNNN.py`，或正文含「一次性」字样，构建直接 `exit 2`。
- 因此不需要维护「排除清单」——命名即契约。