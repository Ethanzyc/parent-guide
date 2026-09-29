# parent-guide 产品规格 v1

> 日期:2026-09-28 | 状态:M1 收敛稿(依据:HANDOFF.md + 三份调研报告 + 用户红线确认)
> 本文档是产品唯一执行口径;与 HANDOFF/报告冲突时以本文为准,并回改 HANDOFF。

## 1. 产品定位

开源的循证育儿指导系统,形态 = Agent Skills 开放格式的一个 skill 文件夹
(SKILL.md + references/ + scripts/ + data-templates/)。用户自配大模型
(API key 或本地模型)、数据自己填、本地自己管理。建议追踪→回访→档案更新
的闭环是核心资产。GitHub 为真相源,RedSkill 为国内分发镜像(只分发不运行)。
页面 = 本地数据 + 本地后端 + 前端(render.html 渐进增强双模式)。

## 2. 范围(M0-M7)

| 阶段 | 内容 | 产出 |
|---|---|---|
| M0 基建 | git init、目录骨架、demo/ 迁入 | 可提交空仓库 |
| M1 spec | HANDOFF+三报告收敛成规格 | docs/specs/(本文+acceptance-tests-v1) |
| M2 plan | writing-plans 写 M4 计划 | docs/plans/ |
| M3 TDD RED | 15 题无 skill 裸跑逐字记录失败(虚构档案) | docs/test-results/RED-* |
| M4 GREEN | v2 SKILL.md+scripts+最小知识核 → 同题复测 | skill 本体+对比报告 |
| M5 页面正式化 | demo 原生渲染器切 Vue3+Vite+vite-plugin-singlefile | 正式 render+server |
| M6 知识库 v1 | CDC 里程碑中文化+自写综述起步 | knowledge/ |
| M7 分发准备 | README+官网静态页、RedSkill 上架表述研究 | 可发布仓库 |

## 3. 非目标(当前版本明确不做)

1. 不架公共在线服务/API/公共 demo(生成式 AI 备案红线;demo server 仅本地)。
2. 不做付费体系落地(变现后置,现阶段做账号;交付=群文件发 zip 为主+私有仓库拉成员为辅)。
3. 不做 Phase B(MCP server)与 Phase C(独立应用)。
4. 不迁移 yuer 28 篇语料(版权清理后置;M6 起用 CDC/PLH/自写综述)。
5. 不做多用户服务端(数据本地、单用户;页面后端是本地文件读写,不是服务)。
6. 用户真实数据绝不入仓库(见 §5)。

## 4. 架构(仓库结构,来自架构报告 §5)

```
parent-guide/
├── skills/parent-guide/          ← skill 本体(M4)
│   ├── SKILL.md                  # 方法论/分档启动/路由/红线/知识库检测与降级协议
│   ├── references/
│   │   ├── knowledge-index.md    # 最小知识核:索引+红线+高频模板
│   │   ├── blocks-spec.md        # 页面积木规范(面向 LLM)
│   │   └── cases/                # 判例层(半自动聚合+人审合入,带日期)
│   ├── scripts/                  # hot-context.sh 等(路径参数化)
│   └── data-templates/           # child.json 档案模板 + page.json 默认配置
├── render.html                   ← 渲染器(M5 从 demo 迁出正式化)
└── knowledge/                    ← 完整中文循证语料库(M6,独立分发层)

用户侧(本地,绝不入仓库;.gitignore 的 /data/ 规则整目录排除)
└── data/
    ├── child.json                # 单文件全档案:基本档案+追踪+回访+情境日志
    └── page.json                 # 页面积木配置(可选,用户 AI 按 blocks-spec 定制)
```

数据层演进:单 JSON 起步(git 可 diff、agent 直读直写、自进化判例需版本管理);
SQLite 为数据量增大后的后置升级,当前不做。

自进化三层分治:数据层全自动 / 判例层半自动(脚本聚合+人审 git commit)/
方法论层人审为主。红线:未回访闭环的建议不得晋升判例。

## 5. 数据隔离(单一规则,用户拍板 2026-09-28)

1. **用户真实数据 = 用户本地 `data/` 目录(单 JSON 起步),根 `.gitignore`
   的 `/data/` 规则整目录排除,永不入库。** 不设其他审计/校验机制——
   隐私保证完全由这条路径规则承载。
2. 仓库内允许的儿童数据只有两种,均为虚构:
   a) `demo/data.json`——「桃子(示例)」demo 展示数据,自带虚构声明;
   b) `tests/fixtures/` 虚构测试档案(child.json)——验收测试资产,进 git,
      保证 RED/GREEN 两轮跑同一份档案、结果可复现;性质等同测试代码,不是用户数据。
3. 决策文档豁免:HANDOFF.md 与 docs/ 三份报告中出现的自用版主角小名与出生日期
   是决策记录引用(诊断基线、description 草案),允许保留在全量仓;
   M7 公开分发前统一执行发布清理(与语料版权清理同一道发布门)。
4. `~/ai/yuer` 与本项目无依赖(2026-09-28 解除):调研成果已沉淀本仓库,
   后续任何里程碑不读写该路径。

## 6. 跨平台子集约束(M4 SKILL.md 必须遵守,覆盖 47 宿主+RedSkill+Claude App)

1. frontmatter ≤6 字段:name / description / license / compatibility /
   metadata / allowed-tools(claude.ai 上传子集)。
2. 不用 Claude Code 专属语法(如 `` !`command` `` 动态注入)。
3. scripts 路径参数化:不写死绝对路径,接受 data 目录参数,
   云沙箱(Anthropic 服务端)与本地两跑。
4. 渐进披露三阶段:description(What+When+可搜索触发词+负向边界,
   绝不概括工作流)→ SKILL.md 正文 <150 行 → references/scripts 按需加载;
   引用一律一层深;>100 行 reference 顶部加目录。
5. 禁令给正向配方,不列 prohibition 清单(superpowers 实证:禁令反效果)。
6. 确定性操作脚本化("Code is deterministic; language interpretation isn't"),
   正文写明 Run(执行)还是 See(阅读)。

## 7. 页面验收清单(M5 用;demo 已实现项即回归基线)

demo 现状(454 行 render.html + 66 行 server.py,本地服务
`python3 demo/server.py` → http://127.0.0.1:8765/render.html):

- [ ] 6 种积木卡片:profile / milestone / sleep-week / strategy-effect /
      followup / notes(实测自 demo/render.html;page.json v2 网格坐标
      {x,y,w,h},与 grid-layout-plus 同构,12 列)
- [ ] 拖拽换位 + 宽度档位(本地服务模式编辑即保存,防抖写回)
- [ ] JSON 编辑写回(=用户 AI 改配置的通道)
- [ ] fail-soft:坏 block 渲染错误占位卡,不整页崩
- [ ] 单文件报告导出(数据内嵌单 HTML,双击可开、可转发)
- [ ] 文件模式(无服务):双击即开,流式只读,编辑存浏览器
- [ ] server 原子写 + 坏配置校验(拒绝写回非法 JSON)
- [ ] M5 迁移约束:Vue3+Vite+vite-plugin-singlefile(单文件产物不变),
      REGISTRY 逻辑平移为组件;已知坑:GridStack v11 的 load content 走
      textContent(防 XSS),HTML 必须在 load 后手动 innerHTML 注入

## 8. 合规红线

1. 不架在线服务即不触生成式 AI 备案;守住「只分发代码+静态内容」边界。
2. 语料分发:自写综述+索引+购书指引 + CDC(公有领域,署名、不暗示背书)
   + PLH(CC BY,逐份核对);AAP/WHO 正文与 yuer 书摘不公开。
3. 小红书站内交付,不站外导流;AIGC 主动打标(M7 发布时)。
4. RedSkill 上架表述避开医疗建议红线(对标研究 = M7)。

## 9. 验收与质量门

1. 15 题测试集 = docs/specs/acceptance-tests-v1.md,定稿 commit 即锁定,
   RED(M3)/GREEN(M4)两轮之间不改题。
2. GREEN 准入线(不达标不进 M5):触发正确率(A-D 类 12 题)≥90%、
   D 类误触 = 0、L1 输出 ≤150 字、来源 100% 可 grep 对账。
3. TDD:NO SKILL WITHOUT A FAILING TEST FIRST——M3 RED 先行,
   M4 SKILL.md 必须针对 RED 记录的真实失败写。
