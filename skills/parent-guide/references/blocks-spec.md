# blocks-spec(页面积木规范)

> 这份文档写给**用户的大模型**看:用户的 AI 读它来修改 `data/page.json`,为家长定制成长视图。
> 设计原则:AI 只改 JSON,不生成代码;渲染器负责校验与兜底。

## 数据文件位置

- `data/child.json` — 孩子档案(单文件,含档案/追踪/回访/速记;键名任意,页面自动取第一个非 `_meta` 键)
- `data/page.json` — 页面配置(本文件讨论的对象)

## page.json 结构(v2:网格坐标布局)

```json
{
  "version": 2,
  "title": "页面标题",
  "child": "child.json 里的孩子键名(可省略,默认取第一个)",
  "layout": { "cols": 12, "rowHeight": 72, "margin": 12 },
  "blocks": [ ...卡片数组,x/y 决定位置,w/h 决定宽高(网格单位)... ]
}
```

布局模型与 grid-layout-plus 同构(`{x, y, w, h}`,12 列网格)。本地服务模式下家长可拖拽/拉伸直接改这些值;AI 改这些值的效果与之完全等价。

## 卡片通用字段

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | string | 必填,页面内唯一 | 稳定标识,改配置时保留 |
| `type` | string | 必填,白名单(见下) | 未知 type 渲染为错误占位卡,不会崩溃 |
| `x` | number | 0..cols-w | 左起第几列 |
| `y` | number | ≥0 | 上起第几行(松手自动压缩,不必精确) |
| `w` | number | 1..12 | 宽度(列数) |
| `h` | number | 1..20 | 高度(行数,rowHeight=72px) |
| `props` | object | 按 type 定义的键 | 卡片参数,未知键忽略 |

注:文件模式(无本地服务)下忽略 x/y/h,按 blocks 顺序 + w 流式排版——报告转发场景仍美观。

## 卡片类型白名单

### `profile` — 孩子档案摘要
props:无。显示:姓名、月龄、当前关注点、活跃问题。建议 w 3-4。

### `milestone` — 月龄里程碑(CDC 检查表)
props:`months`(number,默认取孩子实际月龄就近档)。建议 w 4-6。

### `sleep-week` — 一周睡眠
props:无。显示:近 7 天入睡/夜醒/总时长条形图。建议 w 4-6。

### `strategy-effect` — 策略效果追踪
props:`status`(`"all" | "effective" | "partial"`,默认 all)。建议 w 6-12。

### `followup` — 待回访清单
props:无。建议 w 4-6。

### `note` — 成长速记
props:`limit`(number,默认 5)。建议 w 3-4 或整行。

## 修改规则(给 AI)

1. 只增删改 `blocks` 数组与 `props`,不发明新 type、不改 `version` 与 `layout`
2. 每次修改输出完整 page.json(整文件替换,不做局部 patch)
3. 新卡片给合理的 x/y/w/h(可参考同页面既有卡片的取值;y 不必精确,渲染器会自动压缩)
4. 卡片建议总数 4-8 张;同屏不超过 12 张
5. 修改前向用户确认意图;「重置默认」可回滚(本地服务模式下重置会写回文件)

## 渲染器契约

- 两种模式:本地服务(`python3 server.py --open`)= GridStack 编辑器(拖拽/拉角/编辑即保存);文件模式(双击 `web/dist/render.html`)= CSS grid 流式只读
- 未知 type / 坏 props → 错误占位卡(fail-soft),整页照常渲染
- JSON 解析失败 → 保持上一版配置并提示,不白屏
- 服务端 POST 校验:缺 blocks 数组拒绝写入;原子写(tmp+rename)防半截文件
