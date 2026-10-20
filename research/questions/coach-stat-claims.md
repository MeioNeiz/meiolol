---
status: answered
priority: later
area: stats
tags: [data, learning]
description: Which of Coach Rogue's stats-based claims (split push win rate, objective win rates, bounties, game length, gold leads, carrying when fed) hold in our ranked data?
---
# Which of Coach Rogue's stats-based claims (split push win rate, objective win rates, bounties, game length, gold leads, carrying when fed) hold in our ranked data?

Feeds: Learn content and any "myth check" page (docs/learn-proposal.md); docs/learned.md
lines where a check is final. Companion to [[kill-vs-farm-value]].

## Answer

Most hold, two fail. Eight videos (2023 to 2026) checked against 291k ranked solo
timelines and 364k games, Platinum IV and up (real low elo is not in our data). His
objective order matches ours and the early values agree closely (C2); a fed laner's
result rides on the other four (C3); a fixed gold deficit costs less as the game goes
on, though leads usually keep growing (C5, C6); games shorten as rank rises (C7);
bounties pay the team that is behind far more per kill at every tier (C9); and the
first eight minutes run as his timeline says, kills peaking at 3:00-3:30 and calm at
4-5 (C10). The failures: the "55.64% split push" title is one champion's Iron win
rate and split pushers do not beat other top laners in our ranks (C1), and high-rank
kills do not pay more gold (C8). Smaller misses: first dragon falls mostly 6 to 8
minutes in, not at the 5:00 spawn (C11), and there is no 14-minute break in a mid
tower's worth (C4).

The pattern: when he leans on real data (the objectives study) or on game rules, he
is right; titles that promise a single striking number are where he goes wrong.

## Claims

- C1: The "55.64% split push" figure is Yorick's Iron win rate; in Platinum IV+ neither Yorick (48.9%, 10,175 games) nor six split pushers together beat the average top laner at any rank. for: [[coachrogue-split-push-win-rate#^f1]], [[split-pusher-rank-measured#^f1]], [[split-pusher-rank-measured#^f2]], [[split-pusher-rank-measured#^f3]]
- C2: Objective worth in his order (elder, baron and soul, first dragon, then grubs and herald); first dragon +6.2, grub +1.7, herald +1.5 points over the chance before; soul teams win 88%. for: [[coachrogue-neutral-objectives#^f3]], [[coachrogue-neutral-objectives#^f8]], [[coach-objectives-measured#^f1]], [[coach-objectives-measured#^f3]]
- C3: A laner 1k+ gold up at 14:00 wins 68.6%, but 47.3% when the other four are behind and 27.6% when they are 3k+ behind. for: [[fed-player-win-rate-measured#^f1]], [[fed-player-win-rate-measured#^f2]], [[fed-player-win-rate-measured#^f3]]
- C4: A mid outer tower is followed by about 1.5 points more win chance than a side outer, with no 14-minute threshold. for: [[coach-objectives-measured#^f5]], [[coach-objectives-measured#^f6]] against: [[coachrogue-carry-when-fed#^f5]]
- C5: A fixed deficit costs less later: 5k behind wins 7% at 10 minutes, 13% at 15, 17% at 30. for: [[coachrogue-down-5000-gold#^f3]], [[gold-deficit-comeback-measured#^f1]], [[gold-deficit-comeback-measured#^f2]]
- C6: A 5k lead had shrunk five minutes later in only 32% of games from 15 minutes (47% from 25); comebacks come mostly from those. for: [[gold-deficit-comeback-measured#^f4]], [[gold-deficit-comeback-measured#^f5]]
- C7: Games shorten as lobby rank rises: median 31.3 min in Bronze lobbies, 30.5 Gold, 29.7 Platinum, 27.1 Master, 26.1 Challenger, via more sub-20 games and fewer 35+. for: [[coachrogue-game-length#^f1]], [[game-length-by-rank-measured#^f1]], [[game-length-by-rank-measured#^f2]]
- C8: High-rank kills pay the same gold (about 340 at every tier) and lead to another kill within 30 s as often; high-rank games just have fewer kills. for: [[kill-gold-by-rank-measured#^f1]], [[kill-gold-by-rank-measured#^f2]], [[kill-gold-by-rank-measured#^f6]] against: [[coachrogue-challenger-kill-gold#^f5]]
- C9: Bounties are a comeback mechanic at every tier: killers 3k+ behind get 481 gold a kill, near even 330, 3k+ ahead 294. for: [[kill-gold-by-rank-measured#^f3]], [[kill-gold-by-rank-measured#^f4]], [[coachrogue-bounty-system#^f3]], [[lol-wiki-champion-gold-bounties#^f5]]
- C10: Early kills peak at 3:00-3:30, jungler kills most of all, and dip at 4:00-5:00. for: [[first-8-minutes-measured#^f1]], [[first-8-minutes-measured#^f2]], [[coachrogue-first-8-minutes#^f4]], [[coachrogue-first-8-minutes#^f5]]
- C11: First dragon falls by 6:00 in only 10% of games, 53% by 8:00. for: [[first-8-minutes-measured#^f4]] against: [[coachrogue-first-8-minutes#^f6]]
- C12: Leads come only slightly earlier at Master+: the eventual winner is 1k+ up at 10 minutes in 49.9% of games against 47.5% lower. for: [[kill-gold-by-rank-measured#^f7]] against: [[coachrogue-challenger-kill-gold#^f1]]
- C13 (inferred): His data-backed and rule-based claims hold; single-number titles from unnamed sources do not. from: C1, C2, C8, C9

## Disagreements

- Objective sizes: our minute-level difference puts baron +10, soul +8.9, elder +14.5, above his study's 6.2, 6.15 and 8.29; the lab regression that shares credit within the minute gives 5.6-7.9 and 9.2, close to his. The regression is the fairer number ([[coach-objectives-measured#^f2]], [[coach-objectives-measured#^f3]]).
- Win rates after an event are association, not the event's effect, except where conditioned on the state before (C2, C3, C6 partly).

## Open

- Low elo (Iron to Silver): below our crawl floor; League of Graphs durations and surrender stats are leads.
- Do objectives matter more at higher ranks (his prediction)? Needs a rank split of the objectives regression.
- How much of high-rank games' shortness is early surrenders.
