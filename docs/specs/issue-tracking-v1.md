# 问题追踪(Issue Tracking)设计 v1

> 日期:2026-10-09 | 状态:待用户审
> 依据:真实会话 sess_353bbf91(便秘立案)信息散落实证 + 用户 5 点诉求 + 三项拍板
> (入口=卡片+全屏详情覆盖层;关联=AI 自动挂+回复透明;结构化=A 双层方案,
> 对比 demo 见 docs/issue-tracking-demo-2026-10-09/index.html)
> 本功能不改产品定位与既有铁律;与 product-spec-v1 冲突处以本文为准并回改。

## 1. 背景与目标

「问题」是育儿档案的核心资产:便秘、发脾气、戒安抚物这类持续议题,信息天然
散落在 notes(多标签)/strategies/followups/currentFocus 四个区,且问题之间有
交叉(便秘↔喂养↔睡眠夜醒)。现状靠 tags 弱关联,页面只能做平铺列表。

目标:把「问题」立为档案一等实体,做到——
1. 每个问题有病历式详情页(当前状态置顶 + 口径卡 + 时间轴);
2. 对话产生的记录自动归集到问题名下,不遗漏;
3. 问题级分享卡,让全家统一战线(不仅「怎么做」,还有「为什么」);
4. 页面重点信息突出(里程碑同款三色体系,数字是第一语言)。

## 2. 数据层(child.json)

### 2.1 新增 `issues[]`

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `id` | string | ✓ | `P1` 递增,脚本自动续接 |
| `name` | string | ✓ | 问题名,如「功能性便秘」 |
| `status` | enum | ✓ | `active`(进行中)/`watching`(观察中)/`resolved`(已解决) |
| `opened` | MM-DD | ✓ | 立案日 |
| `closed` | MM-DD | resolved 时 | 脚本自动填当天 |
| `summary` | string | ✓ | 当前状态一句话(AI 维护,详情页「当前状态卡」主体+入口卡兜底) |
| `judged` | MM-DD | 可选 | 判定确立日(brief.what 首次写入/实质修订时更新;时间轴渲染「判定」大节点) |
| `pendingCare` | string | 可选 | 待办就医动作描述,如「1-2 周内儿保/儿科评估(T2)」;存在=红(入口卡计数+行内红徽章);完成就医后清除 |
| `brief.what` | string | 可选 | 这是什么问题(判定与现状,1-3 句) |
| `brief.why` | string[] | 可选 | 为什么这么做:每条一个动机+依据(转译人话带机构名) |
| `brief.how` | string[] | 可选 | 现在怎么做:每条一个动作,直接列做什么**不写谁**(全家同一套,谁在场谁执行;2026-10-09 用户拍板取消按人分工) |
| `brief.redline` | string | 可选 | 出现即就医/评估的红线信号 |

brief 是「口径卡」:节的 key 是机械的(页面渲染需要),节内文本自由(AI 写)。
观察类问题(如发脾气)what/why 必有,how/redline 可缺——**不硬凑空节**。

### 2.2 关联模型(反向挂)

- `notes`/`strategies`/`followups` 记录新增可选字段 `issues: ["P1"]`;
- 一条记录可挂多个问题(如「夜奶基线」note 同挂便秘与睡眠);
- 历史记录定位方式:note 按「日期+text 前 8 字前缀」匹配,strategy 按 id,
  followup 按 due+topic(沿用 set-followup-status 的双精确匹配惯例);
- notes 本身不加 id(不改既有契约)。

### 2.3 状态机与颜色映射

```
active(进行中,黄 watch) ⇄ watching(观察巩固,灰蓝 plain)
     ↓(须用户拍板「这个问题算解决了吗」)
resolved(已解决,绿 ok;留档可查,热区/入口卡默认不显示)
```
- `pendingCare` 是正交字段,非状态:active 问题可同时挂就医待办(红 todo);
- active↔watching 由 AI 判断+回复透明(小迁移);resolved 必须用户拍板。

### 2.4 下一步与倒计时(派生,不存储)

入口卡/详情卡的「下一步+倒计时」从该问题名下 **pending followups 中最近 due**
机械派生,不存冗余字段(少一个同步点)。无 pending followup 时入口卡右列显示
summary 截断。

### 2.5 与既有区的关系

| 区 | 处置 |
|---|---|
| `activeConcerns` | **废弃**(结构变更 SOP 四镜像同步):模板删键,check 见旧档案残留则提示迁移,hot-context/focus 卡改读 issues |
| `currentFocus` | 保留(「今天先看什么」的置顶语义,人审排序);顺手修上次会话的断句 bug(set-focus 重写) |
| `strategies` | 不动;策略通过 `issues` 字段归属问题,可独立存在(不挂任何问题的策略照常显示) |
| `set-concern-status` 命令 | 随 activeConcerns 废弃;由 set-issue-status 取代 |

## 3. update-child.py 新命令

| 命令 | 参数 | 说明 |
|---|---|---|
| `add-issue` | `--name --status(active\|watching) --summary [--what --why(可重复) --how(可重复) --redline] [--pending-care] [--judged MM-DD]` | 自动 P{n};brief 整组写入 |
| `set-issue-status` | `--id --status` | resolved 自动 closed=今天;转回时清空 |
| `set-issue-brief` | `--id [--summary --what --why(可重复) --how(可重复) --redline --pending-care --judged]` | 传哪个改哪个;why/how 整组覆盖(先读全量再写,避免 patch 语义);`--pending-care none` 清除 |
| `link-issue` | `--id [--note "YYYY-MM-DD:前缀"] [--strategy S4] [--followup "MM-DD:topic"]`(可多组) | 回顾补挂;note 前缀匹配多条时报错并列出候选,加长前缀重试;加 `--remove` 变体做误挂纠正 |
| `add-note` / `add-strategy` / `add-followup` | 各加 `--issue`(可重复) | 记录侧写入 `issues[]` |

**check 扩展**:issues id 唯一/status 枚举/日期格式;记录的 `issues[]` 引用
必须存在(挂不存在的 P 号=FAIL,防手改档案错引)。

## 4. hot-context.sh(写入协议的眼睛)

`[活跃问题]` 段(现读 activeConcerns)改为读 issues:

```
[问题] 2 在管(P1 active / P2 watching)
- P1 功能性便秘 [active] 第1天 —— <summary 截断>
  就医待办:<pendingCare> | 下一回访 10-20(剩 11 天)
```

热区带出问题清单是「AI 自动挂」的前提:每次对话开头 AI 先看到在管问题,
写记录时才挂得上。resolved 不显示。

## 5. skill 协议层

### 5.1 conversation.md §2 写入协议,新增「问题归属」小节

1. **开题**:L2/E 判定类议题首次明确为持续问题时,建议开题(家长认领后
   `add-issue`;判定已明确时带 --what/--judged);
2. **默认挂**:此后该问题相关记录(add-note/add-strategy/add-followup)默认带
   `--issue`;一条记录涉及多个问题就多挂;
3. **透明话术**:回复中一句「已记到 P1 功能性便秘下」——用户可当场纠正,
   不单独提问确认;
4. **回顾补挂**:写记录时对照热区 [问题] 段,发现与既有问题相关而未挂的,
   `link-issue` 补上;
5. **状态迁移**:active↔watching AI 判断+透明;**resolved 须用户拍板**
   (「这个问题算解决了吗」),AI 不自行关闭;pendingCare 的设置/清除须用户知情
   (约了医生/完成就医);
6. **口径卡维护**:方案变更/判定修订/依据升级时 `set-issue-brief` 同步
   (brief 是分享卡的唯一素材源,过期=给家人的话过期)。

### 5.2 templates.md 新增「问题分享卡(家人版)」节

纯文本结构(微信场景):情况一句话 → 为什么这么做(逐条带依据转译)→
怎么做(直接列动作)→ 出现什么情况直接就医 → 截至日期。去内部黑话规则沿用
(P 号/T 级字母不进家人内容)。

### 5.3 blocks-spec.md

新增功能卡类型:

| type | 名称 | props | 建议宽度 |
|---|---|---|---|
| `issue` | 问题追踪 | `status`(active\|watching\|resolved\|all,默认空=在管:active+watching) | w 6-12 |

并注明:点击问题行打开**详情覆盖层**(前端组件,非卡类型、无路由——
file mode/单文件导出/打印链路全保持)。

## 6. 页面层(web/)

### 6.1 IssueCard.vue(type `issue`)

- 顶部三色大数字(demo 已验证):进行中(**active+watching 合计**,黄)/ 待就医
  (pendingCare 计数,红)/ 已解决(resolved 计数,绿),`.num-serif` 同款;
- 问题行:状态徽章(.st 描边式)+ 名称 + 第 N 天 + 右列(pendingCare 红徽章
  优先,否则派生 next「10-20 · 剩 11 天」);
- 点行 → IssueDetail;行 hover 无动效(图纸风格)。

### 6.2 IssueDetail.vue(全屏覆盖层,Teleport,无路由)

自上而下(demo A 版已验证):

1. **头部**:名称 + 状态徽章 + 第 N 天 + meta(立案日/关联计数);
2. **当前状态卡**(最重要信息第一屏):summary 大字 + 动作条(就医待办红徽章/
   最近 pending followup 倒计时);
3. **口径卡**:what(节标题带 judged 日期)→ why 逐条 → how 逐条;
4. **redline 红框**(存在时);
5. **时间轴**:聚合该问题名下全部记录,按日期排序:
   - 大节点(机械事件,见 §6.3):立案(opened)/判定(judged)/方案(strategy.started);
   - 普通行:notes(行尾显示原 tags 的 chip);
   - followups:pending=虚线未来节点+倒计时;done/skipped=小字历史节点;
6. 底部:「分享问题卡」按钮(开 ShareModal level=issue)+ 关闭。

### 6.3 时间轴节点分级纪律(铁律对齐)

大节点只由**机械事件**驱动(何时立案/何时判定/何时立方案——都是字段的写入),
AI 不给内容定级。「Rome IV 达标」这类判定 note 显示为普通行,判定信息由
judged 日期 + brief.what 承载——语义归一留读侧的页面侧镜像。

### 6.4 ShareModal.vue 加 issue 级

- level='issue':头(孩子+月龄+问题名+第 N 天+截至)→ 现在的情况(what)→
  为什么这么做(why 逐条+来源行)→ 全家怎么做(how 逐条,「中文冒号前 ≤4 字」
  做照顾者高亮,纯机械规则)→ 红线红框 → 署名;
- 勾选 chips=why/how 条目级(沿用现有机制);
- 匿名化/署名开关沿用。

### 6.5 FocusCard.vue

数据源 activeConcerns → issues(status≠resolved);currentFocus 部分不动。

## 7. 迁移(真实档案,一次性)

实施时在用户 data/(不进 git)执行,命令序列:

1. `add-issue --name 功能性便秘 --status active --summary "..." --what ... --why×4 --how×3 --redline ... --judged 10-09 --pending-care "1-2 周内儿保/儿科评估(T2,非急诊)"`;
2. `add-issue` 戒安抚物(active,简版 brief)+ 发脾气(watching,简版 brief);
3. `link-issue` 收编:S2→发脾气、S3→戒安抚物、S4→便秘;如厕/喂养/夜奶
   相关 notes 按定位规则挂 P1(疫苗 note 不挂——非持续问题);
4. followups 挂靠:10-11→S3、10-13→S1(作息前移暂不开题,S1 留独立)、
   10-14→发脾气、10-20→便秘;
5. `set-focus` 重写修断句:功能性便秘、戒安抚物、发脾气、吃饭要喂;
6. `check` 通过。

「吃饭要喂」在 focus 里但未开题(V1 不强迁,下次相关对话时按协议开题)。
demo 内嵌数据(桃子)同步加 1-2 个虚构 issue 示例。

## 8. 测试与门禁

| 项 | 内容 |
|---|---|
| test-update-child.sh | 新命令正反例:id 续接/link 定位失败报错/--remove/check 引用完整性红(brief 整组覆盖语义) |
| test-hot-context.sh | [问题] 段断言(计数/待办/倒计时行) |
| check-card-style.sh | IssueCard/IssueDetail/ShareModal 新样式过(颜色只用 CSS 变量等七条) |
| 结构变更 SOP | 四镜像同步:模板/hot-context/update-child(web 渲染层)+ 两测试套件全绿后 publish |

## 9. 非目标(V1 明确不做)

1. 回访结果文本进时间轴(mark-revisited 的 strategy.followup 不回灌;回访节点
   由 followups done 承载);
2. 问题间关联图谱(yuer「问题链条」概念)——V1 靠一条记录多挂表达;
3. 给医生的「就医视图」专用排版(详情页本身可出示,五事实清单在 brief.what);
4. severity/评分/权重类字段(铁律禁);
5. activeConcerns 自动迁移脚本(真实档案为空,只做模板清理+check 提示);
6. IssueDetail 内编辑(查看/分享 only,内容变更一律回对话)。

## 10. 风险与取舍记录

| 取舍 | 理由 |
|---|---|
| 大节点只认机械事件 | 尊重「结构化只给机械操作」铁律;判定信息不丢(judged+what 承载) |
| next 派生不存储 | 少一个同步源;代价=无 followup 时右列退化为 summary 截断 |
| brief why/how 整组覆盖 | 避免 patch 语义复杂化;AI 更新前先读全量 |
| activeConcerns 直接废弃不迁移 | 真实档案为空,零成本窗口期;错过则补迁移脚本(风险低) |
| 不做页面内编辑 | 内容生产唯一路径=对话(既有边界);覆盖层只读+分享 |
