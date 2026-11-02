---
status: answered
priority: soon
area: stats
tags: [draft, method, stats]
description: How safe is each champion to blind pick, how should that be measured (matchup spread, chance of a counter, cost of being countered), and does a safety measure pick better than ranking against the average opponent?
---
# How safe is each champion to blind pick, how should that be measured (matchup spread, chance of a counter, cost of being countered), and does a safety measure pick better than ranking against the average opponent?

Feeds: the app's blind ranking and "safe blind" label (docs/plan/app.md APP3, J2;
docs/model.md "Blind pick ranking (J2)"), champion pages (decisions.md: no blind-safe
score), Learn cards; what a likely competitor (MachineLoLing) will show.

## Answer

Blindability is best defined as the noise-corrected spread of a champion's matchup
win rates once both champions' strength is removed (C1, C2); MachineLoLing's method
and meiolol's give the same scale (typical mid ~1.8-2 points, Ahri 1.1, Yasuo 2.2:
C3). Turning spread into "chance of being countered" (85% Yasuo, 10% Ahri) needs
strong assumptions and gives an upper bound on the chance a counter is available, not
on harm (C5, C6). What players actually lose to the opponents they draw is small,
at most about 0.35 points of win rate for the most counterpicked mid (C7), and
ranking blind picks by a safety measure did not beat ranking against the average
opponent in our held-out test (C8, C9). So safety is a reason to show, not a sort key.

The open lever is the opponent distribution: J2 averaged over the role's meta, but a
champion's base rating already includes the opponents it usually draws (C10). A
counterpick champion (Galio, Vex) has a base rating lifted by favourable draws it won't
get when blinded; subtracting its drawn-opponent gain gives an "as if blind" rating
(C11), untested.

## Claims

- C1: Blindability can be defined as how much a champion's win rate varies with the other champions in the game. for: [[blindability-math-machineloling#^f1]], [[coachrogue-champion-pool#^f4]]
- C2: Matchup spread must be measured above an additive log-odds baseline and with binomial noise removed, or popular champions look safer. for: [[blindability-math-machineloling#^f2]], [[blindability-math-machineloling#^f4]], [[blindability-math-machineloling#^f5]], [[meiolol-blind-j2#^f5]]
- C3: Noise-corrected mid lane matchups spread about 1.7-2.1 points; Ahri 1.1, Yasuo 2.2. for: [[blindability-math-machineloling#^f6]], [[meiolol-blind-j2#^f5]], [[meiolol-blind-j2#^f6]]
- C4: Lane matchups dominate; top cares almost only about its lane, bot and support about each other. Cross-role and ally effects are smaller. for: [[blindability-math-machineloling#^f14]], [[blindability-math-machineloling#^f15]], [[meiolol-blind-j2#^f6]]
- C5: P(countered) = 1 - (1 - q)^N with q the counters' meta share and N ~7 gives Yasuo 85%, Ahri 10% blind. for: [[blindability-math-machineloling#^f9]], [[blindability-math-machineloling#^f10]], [[blindability-math-machineloling#^f11]]
- C6 (inferred): That figure is an upper bound on a counter being available: it assumes the opponent picks after you and always counters, random pools, and the mean of a skewed N; counter lists come from unshrunk cells. from: C5 for: [[blindability-math-machineloling#^f8]], [[blindability-math-machineloling#^f12]]
- C7: The win rate a mid champion gains or loses from the opponents it actually draws runs only about -0.34 to +0.36 points; counterpick champions gain, Yasuo and Ahri lose. for: [[blindability-math-machineloling#^f17]], [[blindability-math-machineloling#^f18]]
- C8: Ranking blind as if the opponent were average is as good as any safer ranking tried. for: [[meiolol-blind-j2#^f1]]
- C9: Low-end and spread rankings partly measure popularity and sample size. for: [[meiolol-blind-j2#^f2]], [[meiolol-blind-j2#^f4]], [[blindability-math-machineloling#^f23]]
- C10: A champion's base rating already averages it over the opponents it really meets, including counterpick selection. for: [[meiolol-blind-j2#^f3]], [[blindability-math-machineloling#^f17]]
- C11 (inferred): An "as if blind" rating (base minus drawn-opponent gain, plus the expected lane term over the meta) is the right blind target for counterpick champions and spreads more (about ±0.35 points) than J2's expected lane term. from: C7, C10
- C13: Among allies only bot and support show beyond noise. for: [[meiolol-blind-j2#^f6]] against: [[blindability-math-machineloling#^f15]]
- C12: Players broadly blind the blindable and counterpick with counterpicks; Yasuo is the exception. for: [[blindability-math-machineloling#^f19]]

## Disagreements

- Ally effects: MachineLoLing's heat map shows mid with its jungler (+28% vs role
  average) and jungle with mid (+24%); our additive v2 finds among allies only bot and
  support (C13). His figures are relative to each role's average pair and may not be
  noise-corrected; ours are fitted and held-out. Settle: additive v2's jungle-mid ally
  term with its interval.
- Mid vs enemy bot: our v2 finds 0.8-1.1 points; his heat map has mid's enemy-bot
  spread 27% below mid's average. Different scales; same check as above.

## Open

- Does the "as if blind" rating (C11) rank blind picks better on held-out games? A J2
  variant, `meiolol eval --blind`.
- Real pool sizes per role from players' recent games (we have histories, he has
  only mastery), and P(counter available) averaged over N's distribution.
- How often is the lane opponent picking after you in solo queue? Needs pick order
  from consenting app users (meiolol-pick-order-check).
- Is the drawn-opponent gain stable across patches and ranks?
