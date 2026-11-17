# SHELLS.md · 脚本执行口径（v0.16.3-dev+，T3 落地）

实测日期 2026-11-12。环境：
- **android** = `super_admin:shell` → `/system/bin/sh`(mksh) + toybox 0.8.9 + BusyBox 1.36.1
- **proot** = `super_admin:terminal` → Ubuntu 24（/sdcard 经挂载访问，进程启动约 60–130ms）

## 一、按脚本选 shell

| 脚本 | 该用哪个 shell | 实测耗时（android / proot） | 依据 |
|---|---|---|---|
| `journal-lint.sh` | **android 优先** | 92–99 ms / 149–246 ms | 纯 awk，无外部命令依赖 |
| `check.sh` | **android 优先** | full 430–559 / 1079–1472 ms；fast 236–270 / 395–599 ms | C0b 走 inode 分支，结论与 proot 一致 |
| `verify.sh` | 两者皆可 | 147 ms / 330 ms | 已改 `${TMPDIR:-/tmp}` → `/data/local/tmp` 自适应 |
| `enum_merge.sh` | 两者皆可（未改） | — | 只依赖 sort / grep -oE，两边都有 |
| `journal-add.sh` | 两者皆可（未改） | — | `date -d` 在 toybox 0.8.9 已支持（实测 rc=0） |
| `rotate-journal.sh` | proot 优先 | — | heredoc 重写整文件，proot 更稳 |
| `pack.sh` | **只能 proot** | 1280 ms（--fast）/ 2230–4004 ms（三轮） | Android 无 `zip`（toybox 与 BusyBox 1.36 均无） |
| `dist.sh` | **android 优先** | 约 0.3–0.6 s（约 30 文件复制 + 改写 + 自检） | 纯 POSIX（find/cp/sed/awk），不依赖 zip；每次整目录重建，口径同 `.distignore` |
| `eval.sh` | 两者皆可 | — | 纯 grep/awk 记分，无外部依赖 |
| `route-cache.sh` | 两者皆可 | — | 纯 grep/sed 读写缓存 |
| `lexicon.sh` | 两者皆可 | — | 纯 grep 展开词库 |
| `bin/evo`（引擎） | 两者皆可 | build ~0.3 s ｜ search 0.26 s/次 | `store sync` + `index build` 单进程 awk；**取代已删的 index.sh**（旧手工索引）；检索实现见 `lib/search.sh`（v0.19 加固版） |
| `adv.sh`（v0.19 新） | 两者皆可 | 约 6–10 s（29 条用例，每条起 1 个 evo 进程） | 纯 POSIX；只调 `bin/evo search` + `index check`，只读不写；**C17 门禁直接调用** |
| `bridge-journal.sh` | 两者皆可 | — | 跨对话账本桥接；纯 POSIX |
| `journal-commit.sh` | 两者皆可 | — | 账本收尾一次做完：原子锁 + store sync + index build + 七查 |
| `plugin-lint.sh` | **android 优先** | — | 插件包结构校验（dist / pack 前必跑） |
| `refactor.sh` | **proot 优先** | 1.9 s/次（scan） | Android 可用，但 `apply` 需 `patch`（toybox 无） |
| `chain.sh`（v1.3 新） | 两者皆可 | — | 纯 POSIX（grep/sed/date/touch）；内部强制 `TZ=Asia/Shanghai`（坑26） |
| `status.sh`（v1.3 新） | **proot 优先** | — | 调 chain.sh + journal-lint.sh + grep 拼看板；android 下 TZ/zoneinfo 不可靠 |

## 二、调用模板

```sh
# 日常改完脚本/文档（android，约 0.25 s）
cd "<skills 目录>/EVO自进化" && sh bin/evo check --fast

# 封版 / 打包前（android，约 0.5 s）
sh bin/evo check

# 打包（proot，需要 zip）
sh bin/evo pack --fast     # 单轮，约 1.3 s，日常核对内容与体积
sh bin/evo pack            # 三轮等长收敛，发布/报价前必跑
```

## 三、跨 shell 已知差异（只有 C0b 一处，结论相同）

```
proot  : ok    C0b 身份一致：目录名 = name = EVO
android: ok    C0b 身份一致：目录名 = name = EVO
```

验收口径：
- `check.sh` → 比**状态序列**（ok/FAIL/skip 顺序）与**结论行**，不做逐字 diff
- `journal-lint.sh` / `verify.sh` → 逐字 diff，必须为空

## 四、不做的优化及理由

- `pack.sh` 不搬 Android：`zip` 缺失，BusyBox 1.36 只带 unzip 不带 zip
- 不给 shell 脚本加缓存/预编译：proot 每进程 60–130 ms 是 fork 开销，与脚本长度无关。唯一有效手段是**减少进程数**（T6 已做：journal-lint 10→1，check C2/C3 两组→1 次 grep）
- `description` 长度检查保留 `wc -m`：`awk length()` 在部分实现返回字节数，含中文时会比字符数大 3 倍，C5 的 400 字符阈值会误判
- **`dup-ok:` R08 报的 8 处 ROOT 定位重复（3 种写法 / 8 个文件）保持重复，不抽 `common.sh`**：每个脚本必须能独立运行，抽公共库会引入 `source` 依赖与加载顺序问题 → 违背「单文件可跑」边界；该行每脚本只执行**一次**（启动成本，非热点），为消除报告而改写法的收益为零、风险为正。实测边界见第六节

## 五、`--fast` 的边界

`check.sh --fast` 做 C0（双真身）/ C0b（权威目录）/ C4（版本一致）/ C5（description 长度）/ C13（**仅自校验**，跳过指纹比对）五项。
**跳过 14 项**：C1 更名残留、C2 脚本引用、C3 细则引用、C6 账本格式、C7 账本规模、C8 pack 源、C9 备份时效、C10 P0 脚本自检、C11 词库规模、C12 索引、C14 主干体积、C15 评测集、C16 refs 无孤儿、C17 检索对抗。
C13 为何不跳：自校验是 1 次全文 md5（成本≈0），跳过它等于「跑快检就没人查报告是否被手改」。能降级成轻量版就别跳过。
结论行如实报 `5/5 通过，FAIL=0，跳过 14`——跳过项从分母扣除，不冒充 15/15。
封版、打包、报价前必须跑无参数全量，`pack.sh` 无参数时自动跑全量闸门。

## 六、cwd 契约（2026-11-13 实测，R08 豁免的证据基础）

所有脚本用 `cd "$(dirname "$0")/.."` 自定位 ROOT，**不依赖调用者的 cwd**。实测样本 `bin/evo index stats`：

| 调用形态 | 命令 | 结果 |
|---|---|---|
| cwd=ROOT，相对路径 | `cd $ROOT && sh bin/evo index stats` | OK |
| cwd=ROOT/data，相对路径 | `cd $ROOT/data && sh ../bin/evo index stats` | OK |
| 任意 cwd，绝对路径 | `cd /sdcard && sh $ROOT/bin/evo index stats` | OK |
| 裸文件名 + 同目录 | `cd $ROOT/bin && sh evo index stats` | OK |
| 裸文件名 + 异目录 | `cd /tmp && sh evo index stats` | **FAIL（exit 1，安全拒绝）** |

`check.sh --fast` 对照组同样：cwd=ROOT OK / cwd=data/cmd 裸名 OK。

最后一行是理论边界而非缺陷：`$0` 无斜杠时 `dirname` 返回 `.`，`cd ./../..` 落到 `/` 后找不到 `data/` → **干净 exit 1**，不会产生错乱输出或误写文件。`readlink -f` 也无解（裸名不含路径信息），且**不需要解**——调用脚本要么给路径、要么先 cd。

> 修订规则时不要为了「让 R08 归零」去改这 8 处定位：改写法 = 绕过规则，不解决问题（教训 25）。
| `self-test.sh` | 脚本存活自测：sh 语法 / py 编译 / 入口 / check --fast 冒烟 / git 就绪 / 一次性脚本残留 / .gitignore 覆盖 | 改脚本前后各跑一次，FAIL 即禁止提交 |
| `git-bundle.sh` | git 历史冷备：`bundle create --all` → `bundle verify` 校验 → 只留最近 5 个 | 每次 commit 后、发布打包前（`sh bin/evo bundle`） |
