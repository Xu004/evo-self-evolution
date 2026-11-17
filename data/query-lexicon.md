# data/query-lexicon.md · 检索词库（v0.16.4-dev P0-D3）
# 用途：ROUTE 检索前把「现象词」展开成「术语并集」，减少 LLM 现编关键词的命中波动。
# 格式：每行一条，左（现象/别名，别名用 / 分隔） => 右（检索术语，| 分隔，至少 2 个）
# 纪律：只增不删；删除必须先挂 journal 账（词库删条目 = 检索策略变更，需重跑评测集）
# 检索：sh bin/evo lexicon "闪退"  → 输出 crash|dropbox|app_crash|tombstone

# ---------- Android / 构建 ----------
闪退/崩溃/闪退取证 => crash|dropbox|app_crash|tombstone|logcat
日志/抓日志 => logcat|adb logcat|dumpsys|bugreport
SELinux/权限拦截 => selinux|avc|denied|pm install|/data/local/tmp
安装/覆盖安装 => pm install|INSTALL_FAILED|adb install|/data/local/tmp
焦点/抢焦点/干扰 => focus|setsid|抢焦点|后台脚本
真机验证/排障 => 真机|排障|基线|adb|复现
重打包/签名 => AXML|versionCode|重打包|apksigner|zipalign
版本号 => versionCode|versionName|AXML|patch
Root/提权 => root|su|magisk|shizuku|selinux
截图/录屏 => screencap|screenrecord|screenshot|录屏
通知/前台服务 => notification|foreground|channel|常驻
播放/后台被杀 => 后台|保活|foreground|battery|doze

# ---------- Shell / 脚本 ----------
函数报错/未定义 => 函数定义|调用点之前|define before use
跨分区/EXDEV => EXDEV|mv|跨文件系统|垃圾桶|rename
查找慢/提速/扫描 => find|单次扫描|合并关键词|提速
保留目录/清内容 => trace_dir|清内容|保目录本体
分级清理 => clean_trace|L1 L2 L3|分级|清理
误伤/保护规则/豁免 => 豁免|fd|运行中|保护规则|排除
文件锁/并发 => flock|锁|并发|重入
门禁/校验 => check.sh|门禁|FAIL|闸门|自检
打包/体积/收敛 => pack|体积|收敛|N1=N2=N3|zip
日志轮转/膨胀 => rotate|轮转|300行|截断|膨胀

# ---------- 游戏 / 数值 ----------
事件丢失/静默 => tick-worker|转发|白名单|静默丢失
概率事件/确定性 => DEBUG_EVAL|广播|确定性注入|概率|复现
数值爆炸/溢出 => 溢出|乘法|正反馈|对数采样|overflow
冷却/永锁 => 冷却|递减|永锁|cooldown|递减点
弹窗/不显示 => showModal|队列|自刷新|inner|冲突
节流/探针/DOM => 节流|DOM|探针|劫持|vm|签名计算
存档/回档 => save|存档|回档|序列化|reset

# ---------- EVO 自身（元） ----------
记忆淹没/检索污染 => 归档|folder_path|检索污染|self-evo|窗口
召回/命中率 => 召回|命中|评测集|MRR|基线
枚举/计数 => 枚举|三口径|enum|对账|漏网
水位/漏采 => 水位|read_messages_range|漏采|补采
备份/还原 => 备份|还原|restore|snapshot|归档
索引/腐坏 => 索引|派生|腐坏|H15|一致性
引用/断链 => 引用|断链|不存在|悬空
双真身/分叉 => 真身|分叉|权威目录|inode|realpath
更名/残留 => 别名|残留|回滚|grep -rl|替换
账本/journal => journal|账本|append|lint|六查

# ---------- 安全 / 加固 ----------
R8/混淆 => R8|ProGuard|mapping|混淆|Shrinker
符号化 => 符号|build-id|ndk-stack|addr2line|mapping
加固/加壳 => 加固|OLLVM|加壳|控制流平坦化|VMP
Frida/反调试 => frida|hook|反调试|ptrace|检测
签名校验 => 签名校验|公钥|篡改|v2签名|完整性
密钥/硬编码 => 密钥|硬编码|secrets|CI|占位符
抓包/证书 => 抓包|mitm|证书|pinning|代理

# ---------- UI / 商业化 ----------
液态玻璃/模糊 => glass|blur|backdrop|液态玻璃|渐变
掉帧/卡顿 => 掉帧|jank|fps|过度绘制|blur过多
卡密/授权 => 卡密|激活|授权|license|离线校验
采集/监控面板 => 采集|监控|面板|probe|指标
