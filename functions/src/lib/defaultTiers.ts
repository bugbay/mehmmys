import type { RewardTier } from "../types.js";

export const DEFAULT_TIERS: RewardTier[] = [
  { id: "t3", cost: 3, icon: "☕", title: "Coffee or bakery treat", subtitle: "Latte, pastry or cookie" },
  { id: "t5", cost: 5, icon: "💳", title: "$15 gift card", subtitle: "Your pick of spot" },
  { id: "t7", cost: 7, icon: "🍻", title: "Happy hour or $25 card", subtitle: "First round covered" },
  { id: "t10", cost: 10, icon: "🎁", title: "$50 gift card", subtitle: "The big one" },
];
