---
status: answered
priority: soon
area: product
tags: [draft, learning, needs]
description: What does Coach Rogue teach about champion select, counter picks, champion pools, runes and builds, and where does it agree or clash with meiolol's data and recommender?
---
# What does Coach Rogue teach about champion select, counter picks, champion pools, runes and builds, and where does it agree or clash with meiolol's data and recommender?

Feeds: Learn (docs/learn-proposal.md), build pages and matchup pages (docs/plan/site.md);
what a popular coach tells players, so meio.lol can back it with numbers or correct it.

## Answer

Eight videos (draft four, builds four), all C/fair: an ex-pro's rules of thumb backed by
pro pick counts, tooltips and his replays, no win rates. Where our data has measured
the same thing it mostly agrees on what matters by role: counters matter most top and
mid and least in jungle (C1), and bot plus support is the one ally pairing that counts
(C2). It clashes on his favourite synergies: jungler with a CC laner, jungler with
support and immobile mid with mobile ADC are not detected in our games (C3), and he
calls mixed damage surface level while it is one of the few comp effects that held up
(C4). His comp counters through kit point the same way as our kit groups, but at about
a point of win chance a step, far smaller than his framing (C5).

On builds he teaches choices that depend on the lane opponent (runes) and on the game
state (items, boots), as an ordered plan with reasons (C7, C8, C9). That is what
viewers ask for (C10) and what most-played rows don't show; our data says the real
gaps are small (about 0.6 points between runes in a row), so the honest page shows
the split by opponent and lead, not a "best" pick (C11).

## Claims

- C1: Counter picks matter most in top and mid, less in bot and support, least in jungle, so pick jungle and ADC early and counter top and mid last; our matchup sizes by role agree (docs/learned.md, 14 Oct v2 line: top 2.2-2.5 points, mid 1.7-2.1, support 1.2-1.5, bot 1.1-1.3, jungle 1.0-1.4). for: [[coachrogue-champ-select-secrets#^f9]], [[meiolol-learned#^f1]]
- C2: The bot laner and support's fit matters (poke with poke, engage with all-in); in our data bot plus support is the only one of ten ally pairings detected, at 1.3-1.6 points. for: [[coachrogue-champ-select-secrets#^f6]], [[meiolol-learned#^f2]]
- C3: He ranks two-champion synergy first, especially a jungler with crowd-controlling laners and jungler plus support; in our games the other nine ally pairings, mid plus ADC included, are not detected, and a low-CC team's -0.8 ± 0.8 points did not survive. for: [[coachrogue-champ-select-secrets#^f2]], [[coachrogue-champ-select-secrets#^f4]], [[coachrogue-role-meta#^f5]], [[meiolol-learned#^f2]], [[meiolol-learned#^f4]]
- C4: He calls mixed damage surface-level advice; in our data a lopsided damage mix costs about 3 points and under 20% magic damage about 5, confirmed on held-out games. for: [[coachrogue-champ-select-secrets#^f1]], [[meiolol-learned#^f3]]
- C5: Counter picks work through kit and build against the whole enemy comp (anti-auto-attack into auto-attackers, %HP into tanks); our kit groups agree in direction at about a point per step, but his juggernaut-into-range and dash-stopper-into-dive examples are not detected. for: [[coachrogue-counter-picking#^f5]], [[coachrogue-counter-picking#^f6]], [[coachrogue-counter-picking#^f8]], [[meiolol-learned#^f5]], [[meiolol-learned#^f6]]
- C6: A pool should be 3-4 champions good into opposite comp types; "neutral" means fits any ally, "blind-safe" also holds into any enemy comp (Ahri both, Lux only neutral). for: [[coachrogue-champion-pool#^f4]], [[coachrogue-champion-pool#^f6]] against: [[coachrogue-champion-pool#^f10]]
- C7: Rune choices follow the lane opponent: close fights take power runes, won lanes take ones that help allies; Second Wind into ranged, Bone Plating into melee all-in, Aery into short range, Comet into long range. for: [[coachrogue-rune-customisation#^f3]], [[coachrogue-rune-customisation#^f11]], [[coachrogue-rune-customisation#^f13]], [[coachrogue-rune-customisation#^f18]]
- C8: Item and boots choices follow the game state: no defensive items when behind, tankier when ahead, rush boots only with a range gap or a lead. for: [[coachrogue-itemisation-guide#^f10]], [[coachrogue-itemisation-guide#^f11]], [[coachrogue-item-components#^f5]], [[coachrogue-item-components#^f6]]
- C9: A build is an ordered plan (enablers, then a key item; components by the stat abilities scale off), sometimes with two cores chosen by the enemy team. for: [[coachrogue-core-item-build#^f2]], [[coachrogue-core-item-build#^f7]], [[coachrogue-item-components#^f3]]
- C10: Viewers ask for the reason behind a choice and for per-champion cheat sheets (how blindable, strengths and weaknesses); top comments favour comfort over the best pick. for: [[coachrogue-champion-pool#^f9]], [[coachrogue-champ-select-secrets#^f14]], [[coachrogue-core-item-build#^f10]], [[coachrogue-itemisation-guide#^f1]]
- C11 (inferred): meio.lol can add what he teaches and stat pages lack, rune rows split by opponent type and purchases split by lead, while keeping "most played, never best": effects are small. from: C7, C8, C10, [[meiolol-learned#^f7]]

## Disagreements

- Synergy: he puts two-champion synergy first (C3, C grade, pro pick counts); our held-out draft models find only bot plus support (A, our data). His pro-play lens may not carry to solo queue; a direct check of jungler CC times laner CC on early kills would settle it for ranked.
- Damage mix: he dismisses it (C4); our data and a top comment on the role meta video say it matters.

## Open

- Untested rules, all checkable in our data: jungler CC with laner CC; Ahri's win rate flatter across enemy comps than Lux's (blind-safety as low spread); exhaust into burst, Glacial into no-dash teams; Second Wind or Bone Plating by opponent melee or ranged; boots timing by range gap and lead; defensive second item when behind.
- Build page ideas from the builds reader (split rune rows by opponent type, first-three-item order as a sequence, first back and boots timing per matchup, purchases by lead, support item swap rate): for docs/plan/site.md, not decided here.
