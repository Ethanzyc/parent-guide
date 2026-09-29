// Card registry: type whitelist. Adding a block = adding one component here.
import ProfileCard from './ProfileCard.vue'
import MilestoneCard from './MilestoneCard.vue'
import SleepWeekCard from './SleepWeekCard.vue'
import StrategyCard from './StrategyCard.vue'
import FollowupCard from './FollowupCard.vue'
import NotesCard from './NotesCard.vue'
import ErrorCard from '../ErrorCard.vue'

export const REGISTRY = {
  'profile': ProfileCard,
  'milestone': MilestoneCard,
  'sleep-week': SleepWeekCard,
  'strategy-effect': StrategyCard,
  'followup': FollowupCard,
  'note': NotesCard,
}

export function cardFor(type) {
  return REGISTRY[type] || ErrorCard
}
