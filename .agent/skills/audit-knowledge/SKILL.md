---
name: audit-knowledge
description: >
  知识库引用审计调度器。维护者说「审计知识库/全量审核/轮转深审/该轮到谁了/
  审核某个知识文件/重查疫苗或流感口径/审计我的自建库」时使用。按
  docs/knowledge-audit-sop.md 的模式派 subagent 执行(只读审计),修正分级
  报告经用户拍板后落地。不用于:家长向的日常养育问答(那是 parent-guide)。
---

# 知识库引用审计(audit-knowledge)

> 定位:**调度层**——协议/预算/铁律/prompt 模板的 SSOT 是
> `docs/knowledge-audit-sop.md`,轮转状态在 `docs/knowledge-audit-LOG.md`,
> 本 skill 只做路由与编排,不复制正文(两处演进只改 SOP)。
> 沉淀自 2026-10-08~09 三轮实战(约 150 断言、41 处修正全部发布)。

## 启动协议

1. **必读**:SOP 全文 + LOG 台账(判断轮转档期与 watchlist 状态);
2. 按用户指令选模式(说法→模式):

| 用户说 | 模式 | 要点 |
|---|---|---|
| 「审核这个文件」「XX 刚入库」 | **全审**(逐断言) | 新文件入库第 4 道门,不过不全 |
| 「轮转深审」「该轮到谁了」 | **轮转**(逐句级) | 按 LOG 选「下次深审」最早的 1-2 篇;逐句=行文中未标注的断言也算 |
| 「重查疫苗/流感/免疫程序」 | **watchlist** | SOP §5 表逐项快查(1-3 检索/项) |
| 「全量审核」 | **全量** | 12 篇分 5 个并行 subagent(2-3 篇/个)+两轮制 |
| 「审计我的自建库」 | **自建层** | knowledge/user/ 全审(同协议;自建默认 T3,重点核来源真实性与转录准确性) |

3. 派 general-purpose subagent:用 SOP §2 的 prompt 模板填空(目标文件/重点
   断言/预算);**agent 只读不改**;
4. 汇总分级:**A 过时(家长侧已错)/B 偏差(引用错误)/C 待核**——呈报用户拍板
   (改什么、并陈什么、挂什么),不替用户决定;
5. 修正执行走 SOP §3:正文+头注审计行→同源双侧(knowledge-index §2/
   site-src/quickref.md)→对改动的文件**单独跑** audit-citations.sh→
   check-knowledge→site 重建→commit/publish/push;
6. 更新 LOG 台账(判定统计/遗留/下次深审档期)。

## 铁律(SOP §4 全文,此处为执行位常载版)

- **两轮制**:首轮预算耗尽时的非原文级判断只标「待核」,不得触发修改;
- **原文级才能定案**数字/口径;反爬 fallback 阶梯=换路径→PDF 用 curl 下载
  本地解析→Europe PMC REST(PubMed 替代)→官方公告/权威转述(降级明说);
- **fixture 绿≠文件绿**:commit 前对改动的 knowledge 文件单独跑
  audit-citations.sh;
- 修正后**同源双侧必须同步**(速查表与 quickref);
- 新 docs 目录登记 publish EXCLUDE,否则对账门拦。
