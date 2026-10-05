// Card registry: type whitelist, split into two groups.
//   BUILTIN (功能卡): data-bound cards reading child.json -- product-managed,
//            each pairs with skill write-actions; empty state = guide back to chat.
//   CUSTOM  (自定义卡): self-contained cards whose content lives in page.json
//            blocks (props only, never child.json -- that's the script contract).
// Adding a builtin block = adding one component here + blocks-spec.md entry.
import ProfileCard from './ProfileCard.vue'
import MilestoneCard from './MilestoneCard.vue'
import GrowthCard from './GrowthCard.vue'
import SleepWeekCard from './SleepWeekCard.vue'
import StrategyCard from './StrategyCard.vue'
import FollowupCard from './FollowupCard.vue'
import NotesCard from './NotesCard.vue'
import FocusCard from './FocusCard.vue'
import TimelineCard from './TimelineCard.vue'
import ReminderCard from './ReminderCard.vue'
import TextCard from './TextCard.vue'
import ListCard from './ListCard.vue'
import ErrorCard from '../ErrorCard.vue'

export const REGISTRY = {
  'profile': ProfileCard,
  'milestone': MilestoneCard,
  'growth': GrowthCard,
  'sleep-week': SleepWeekCard,
  'strategy-effect': StrategyCard,
  'followup': FollowupCard,
  'note': NotesCard,
  'focus': FocusCard,
  'timeline': TimelineCard,
  'reminder': ReminderCard,
  'text': TextCard,
  'list': ListCard,
}

// Single source of truth for the add-panel, spec docs and validation.
// w/h = sensible defaults when instantiated from the panel.
export const CARD_META = {
  'profile':        { group: 'builtin', name: '孩子档案',   desc: '小名/月龄/画像/当前重点一览', w: 6, h: 8 },
  'focus':          { group: 'builtin', name: '当前重点',   desc: '正在关注的事+观察中的问题', w: 6, h: 4 },
  'milestone':      { group: 'builtin', name: '里程碑',     desc: '发育盘点结果(按月龄档)', w: 6, h: 6 },
  'growth':         { group: 'builtin', name: '生长曲线',   desc: '身高体重记录对照参考区间', w: 6, h: 6 },
  'strategy-effect':{ group: 'builtin', name: '策略效果',   desc: '在跑的计划与回访证据', w: 6, h: 6 },
  'followup':       { group: 'builtin', name: '待回访',     desc: '到期要看效果的事', w: 4, h: 4 },
  'reminder':       { group: 'builtin', name: '前瞻提醒',   desc: '疫苗/报名/季节节点', w: 4, h: 3 },
  'note':           { group: 'builtin', name: '成长速记',   desc: '最近的事件笔记', w: 6, h: 5 },
  'timeline':       { group: 'builtin', name: '事件时间线', desc: '按标签过滤的事件流', w: 6, h: 5 },
  'sleep-week':     { group: 'builtin', name: '睡眠一周',   desc: '逐日睡眠表(默认不记,需手动添加)', w: 6, h: 5 },
  'text':           { group: 'custom', name: '文本卡',     desc: '标题+自由文本(奶奶须知/黑名单)', w: 4, h: 4 },
  'list':           { group: 'custom', name: '清单卡',     desc: '可勾选清单(出门清单/待办)', w: 4, h: 5 },
}

export function cardFor(type) {
  return REGISTRY[type] || ErrorCard
}
export function isCustom(type) {
  return CARD_META[type]?.group === 'custom'
}
