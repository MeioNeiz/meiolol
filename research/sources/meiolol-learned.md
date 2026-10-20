---
title: 'meiolol docs/learned.md: draft-relevant results (our held-out tests)'
url: 
kind: docs
commit: 84acd5b
for: [coach-draft-advice]
looked: 2026-10-20
depth: docs (docs/learned.md, the comp, matchup, kit group, runes and history lines)
relevance: high
grade: A/strong
description: Our own plain-language findings from pre-declared held-out tests on ranked games, quoted here so draft-advice claims can cite them
---
# meiolol docs/learned.md: draft-relevant results (our held-out tests)

Why: the Coach Rogue draft claims compare his advice with our results; this note makes
those results citable evidence.

## Assessment

- Evidence: A. Pre-declared tests on 10k to 134k held-out ranked games, forward time
  blocks, every platform; method and numbers in docs/model.md.
- Reasoning: strong. Each line says how sure, at what size, and what the site may say.
- Interests: ours; we built the models. Results are measured, not claimed.
- Weigh: "not detected" is not "zero": the ally-pairing and CC results bound the effect
  at about a point. Ranked solo, Platinum IV and up.

## Findings

- [draft] Lane matchups matter most top and mid, least jungle: typical difference between matchups top 2.2-2.5 points, mid 1.7-2.1, support 1.2-1.5, bot 1.1-1.3, jungle 1.0-1.4. `docs/learned.md` 2026-10-14 v2 ^f1
  > The lane matchups matter most: top vs top (typical
  > mid vs mid 1.7-2.1, support vs support 1.2-1.5, bot vs bot 1.1-1.3, jungle vs jungle 1.0-1.4
- [draft] Among ally pairings only bot laner plus support is detected (1.3-1.6 points); the other nine show nothing. ^f2
  > Among allies only the bot laner and support's pairing shows (1.3-1.6 points); the other nine ally pairings show nothing.
- [draft] Damage mix matters: under a fifth magic damage about 5 points less, lopsided teams about 3 less than balanced, confirmed on held-out games. 2026-10-13 ^f3
  > A team that deals under a fifth of its damage as magic wins about 5 percentage points less often than its champions alone suggest, and lopsided teams
  > (that, or over 60% magic) about 3 points less than balanced ones
- [draft] A team's crowd control makes about a point of difference at most; the least-CC quarter's -0.8 ± 0.8 does not survive seven tests. ^f4
  > how much crowd control it brings make about a point of difference at most
  > least-CC quarter -0.8 ± 0.8, just past zero but not once seven tests are allowed for
- [draft] Kit groups lean as their kits say, at about a point per step: anti-auto-attack kits 0.7-0.9 better into auto-attackers, lethality assassins 0.9 worse into tanky teams, true or %HP damage 0.7 better, armour kits 1.5 worse into magic damage. 2026-10-18 ^f5
  > Champions whose kits punish
  > basic attacks (Rammus, Jax, Teemo, Shen, Malphite) do about 0.7-0.9 better per step
- [draft] Checked, not detected: dash stoppers into dive, juggernauts into long-range teams, long-range poke into engage. ^f6
  > dash stoppers into
  > dive, hyper-scalers into early teams, juggernauts into long-range teams
- [draft] Runes, spells and shards set in champ select don't detectably change win chance on the same champion and role (largest effects about 1.5 points, within noise). 2026-10-13 ^f7
  > What you set in champ select for yourself (summoner spells, runes, stat
  > does not detectably change your chance of winning on the same champion and role
- [draft] Players' earlier games add a little: the ten champions alone pick the winner 53.2% of the time, with player history 54.5%. 2026-10-13 ^f8
  > the ten champions alone pick the winner 53.2% of
  > that to 54.5%; it ranks a winning team above a losing one 56% of the time

## Read

- `docs/learned.md`: the lines quoted above (snapshot at 84acd5b)
