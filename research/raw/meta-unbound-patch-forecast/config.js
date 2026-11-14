// Central tuning knobs. Every number here is surfaced in the dashboard's Audit tab
// so you can see exactly what the model assumed.
export default {
  api: 'https://api.deadlock-api.com',
  cacheDir: 'data/cache',
  cacheTtlHours: 6,          // re-fetch analytics after this long
  requestDelayMs: 350,       // be polite to the community API

  // Situational contexts. Badge = tier*10 + subtier (e.g. 81 = Oracle 1).
  contexts: {
    all:   { label: 'All ranked',          params: {} },
    high:  { label: 'High rank (Oracle+)', params: { min_average_badge: 81 } },
    low:   { label: 'Low rank (≤ Ritualist)', params: { max_average_badge: 56 } },
    short: { label: 'Short games (< 25 min)', params: { max_duration_s: 1500 } },
    long:  { label: 'Long games (> 38 min)',  params: { min_duration_s: 2280 } },
  },

  // How much a hero's pre-patch record counts as "games of evidence" in the prior.
  // Changed heroes get a weaker prior so post-patch data overrides it quickly.
  priorGames: { unchanged: 15000, changed: 4000 },
  shrinkGames: 400,          // shrinkage pseudo-games toward 50% for raw win rates
  pairShrinkGames: 600,      // shrinkage for matchup / synergy lift

  // Patch-impact model. k (pp of win rate per unit of change score) is fitted by
  // backtesting past patches; this is only the fallback if too little history.
  impact: { fallbackK: 6, maxBacktestPatches: 10, windowDays: 10 },

  // Expert claims: 1 rating point ≈ this many pp of prior shift, before weighting.
  expert: { ppPerPoint: 0.6, halfLifeDays: 21, maxShiftPp: 2.5 },

  // Optional LLM pass over patch lines (run with --llm; needs ANTHROPIC_API_KEY).
  llm: {
    model: 'claude-opus-5-5',
    effort: 'medium',
    mode: 'uncertain',   // 'uncertain' = only replace lines the rules weren't sure about; 'all' = replace every hero/item line
    replaceBelow: 0.7,   // rule confidence below this counts as "uncertain"
    batchSize: 80,       // lines per request
  },

  tiers: [ // thresholds on z-score of posterior win rate
    { tier: 'S', z: 1.25 }, { tier: 'A', z: 0.5 }, { tier: 'B', z: -0.5 }, { tier: 'C', z: -1.25 }, { tier: 'D', z: -Infinity },
  ],
};
