## 修复：gawk 环境下中文检索 100% 静默失效（P0）

**现象**：CI 里 `search-eval` 得到 `Top1=0/10`、13 题全 MISS，但 `index.tsv` / `journal.tsv` 都正常，退出码 0、日志无异常——查不到也不报错。

**根因**：`lib/search.sh` 的中文 2-gram 依赖 awk 的**字节**语义（汉字 3 字节，步长 3、取 6 字节 = 2 字）。Ubuntu 26 起 `ubuntu-latest` 的 `awk` 指向 **gawk 5.3**，UTF-8 locale 下 `length/substr` 按**字符**计算，切片与索引里的 2 汉字对不上 → 中文长句查询 100% MISS。本机 `awk=mawk` 一直是好的，所以从未暴露。

**修复**：`lib/common.sh` 新增 `awkb()`（`LC_ALL=C awk`），检索链路 10 处（search 3 / index 5 / search-eval 2）统一走字节口径。

## 修复：C4 版本号提取吞掉全角括号（门禁假红）

`awk '{print $2}'` 在 `## v1.3.1（2026-11-17 …` 上得到 `v1.3.1（2026-11-17`，与 `SKILL.md` 的 `v1.3.1` 永不相等。改用 `match($2, /v[0-9][0-9.]*/)` 只截版本号本体。

## 验证

- 本机：`evo check` **19/19 通过**、`evo self-test` **PASS=34 FAIL=0 WARN=0**
- CI：lint / 开箱A / 开箱B（**gawk 与 mawk 双实现**各自断言）/ 开箱C / zip 全绿
- 本机另装 gawk 5.2.1 前置 PATH 复现：修复前 `Top1=0`，修复后 `Top1=17/20 MRR=0.8812`，与 mawk 完全一致

## 资产

| 文件 | 说明 |
|---|---|
| `EVO自进化-<tag>.tar.gz` | 公开快照（白名单复制，无 `data/store` / `data/backup` / `data/archive`，`journal.md` 为 0 条空表，含 10 条示例账本与 10 题评测集） |
| `SHA256SUMS` | 资产校验和 |

## 使用

```sh
tar -xzf EVO自进化-v1.3.1.tar.gz -C ~/EVO自进化
cd ~/EVO自进化
chmod +x bin/evo data/cmd/*.sh
sh bin/evo self-test
```

账本默认落在 `$EVO_HOME`（未设置则 `$HOME/.evo`），可用环境变量覆盖。
