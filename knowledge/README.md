# 完整中文循证语料库

## 现状(M6 v1,2026-09-29)

| 文件 | 性质 | 状态 |
|------|------|------|
| `milestones.md` | CDC「Learn the Signs. Act Early.」检查表中文化(公有领域,署名 CDC) | ✅ 11 个检查点逐条经 CDC 官网核对;15 月检查点官方页当前不可达,以 12/18 月联查说明代替,**M6.1 补齐** |
| `sleep.md` | 自写综述(AAP/AASM 口径) | ✅ v1 |
| `nutrition.md` | 自写综述(膳食指南/AAP/WHO/sDOR 口径) | ✅ v1 |
| `emotion.md` | 情绪与管教专题 | ⏳ M6.1 待写 |
| `activities.md` | 活动与绘本专题 | ⏳ M6.1 待写 |

结构断言:`bash tests/check-knowledge.sh`。

## 使用方式

skill(skills/parent-guide)按 references/knowledge-index.md §4 路由表按需 See 本目录;
本目录缺失时 skill 走降级协议(只用内置最小知识核)。
知识核速查表与本库口径一致,专题深度以本库为准。

## 版权红线(分发规则)

- CDC 内容:公有领域,署名 CDC、不暗示背书 ✅
- 自写综述:只引口径数字,不搬运机构原文 ✅
- PLH(CC BY 4.0,逐份核对后引入)、AAP/WHO 正文(不可入库,仅引用)——后续扩充时执行
- yuer 28 篇语料的书摘不公开分发(M7 发布前清理审查)
