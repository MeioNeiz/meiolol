---
status: answered
priority: now
area: product
tags: [tools, ux/uncertainty, stats, method/dynamics]
description: How do League champ select apps and draft tools make their pick, ban and build advice (inputs, sample rules, patch day, ranges), what do they claim, and where does our measured data say they mislead?
---
# How do League champ select apps and draft tools make their pick, ban and build advice (inputs, sample rules, patch day, ranges), what do they claim, and where does our measured data say they mislead?

Feeds: docs/plan/app.md Steps APP3, APP5, APP10 (what our champ select shows and how thin data reads); docs/production-key.md Product rules (options with reasons); the application's case that our numbers are honest

## Answer

No big companion (Blitz, Porofessor, Mobalytics, OP.GG, U.GG, iTero) publishes a method,
a minimum game count or an accuracy figure for its solo queue champ select advice; the
only accuracy figures in the field are iTero's for pro play and LoLDraftAI's 55%, after a
bug had inflated it (C1). Inputs are a rank bracket (Platinum+ or Emerald+ by default),
region and patch or 30 days; Mobalytics adds "your champion pool", LoLTheory alone
adjusts for the player's experience on a champion (C2, C10). Headline tiers are not win
chances: OP.GG mixes win rate with KDA, gold and damage, Mobalytics' tier lists are
hand-curated (C3).

Uncertainty is where we differ most. The only stated rules: OP.GG greys a champion under
0.5% pick rate in a role (a share, so weakest in narrow filters), DraftGap flags rates
under 1,000 games and filters candidates by games a week, LoLalytics shows matchups from
100 games (C4, C5). Elsewhere thin data is a bare count at best: U.GG showed 2-game best
and worst champions in champ select and never shipped its promised low-sample warning;
nobody shows ranges, though iTero's founder argues for them (C6). Pre-game screens are
moving to fewer numbers (iTero's tags-only default, Blitz's grey chips) (C7). On patch
day, tools go silent, move on expert judgement or explain in articles; DraftGap alone
has a rule, the patch rate pulled to 30 days by 1,000 games, matchups always 30 days
(C8). Players mock tiny-sample builds, call any number without a sample size useless, and
see sites disagree on counters without knowing which is right (C9).

Against our data (C11-C14): raw thin rates mislead in a known direction (rare picks win
about 39%, not 50%); counter and duo lists sorted by raw rate put the thinnest cells on
top while real pairing effects are small; rune and build win rates by option are mostly
noise; and on patch day last month's numbers beat the new patch's own. A rank bracket
filled from ranks looked up after the game inflates high-rank win rates.

## Claims

- C1: None of the big six publishes a method, minimum games or accuracy for solo queue
  champ select advice; the only figures are pro play (iTero) and a corrected 55%
  (LoLDraftAI). for: [[opgg-help-tier-calc#^f5]], [[mobalytics-beginners-guide#^f7]], [[itero-winrate-usefulness#^f8]], [[itero-draft-model#^f6]], [[draftgap#^f36]], [[loltheory-what-is#^f8]], [[loldraftai#^f7]]
- C2: Mobalytics' picks and bans come from the meta and the player's pool, its builds
  from win rate and popularity. for: [[mobalytics-beginners-guide#^f1]], [[mobalytics-beginners-guide#^f3]]
- C3: Headline tiers are not win-chance rankings: OP.GG mixes win, pick and ban rates
  with gold, XP, CC, KDA and damage on Platinum+; Mobalytics' tier lists are curated.
  for: [[opgg-help-tier-calc#^f1]], [[opgg-help-tier-calc#^f2]], [[mobalytics-beginners-guide#^f4]]
- C4: OP.GG's one stated sample rule is a 0.5% pick-rate floor per role, shown as a
  greyscale portrait with no analysis; a share, not a game count. for: [[opgg-help-rip-champion#^f1]], [[opgg-help-rip-champion#^f3]], [[opgg-help-rip-champion#^f5]]
- C5: Where floors exist they sit near 1,000 games (DraftGap's flag, weekly filter and
  prior weight; Riot's Phreak), though LoLalytics shows matchups from 100. for: [[draftgap#^f27]], [[draftgap#^f32]], [[phreak-rumble-jungle-samples#^f1]] against: [[lolalytics-counters-threshold#^f1]]
- C6: Thin data is shown as a bare count at best and never as a range: U.GG's champ
  select listed 2-game best and worst champions, its 2020 promised warning is absent,
  its counter lists put 122-138 game rows on top; iTero shows 0-5 scores without ranges
  though its founder argues for them. for: [[fdg-ugg-app-review#^f3]], [[ugg-garbagemen-reply#^f1]], [[ugg-garbagemen-reply#^f4]], [[ugg-darius-counter#^f13]], [[itero-winrate-usefulness#^f1]], [[itero-winrate-usefulness#^f3]]
- C7: Pre-game screens are moving to fewer numbers: iTero made tags the default (Aug
  2026) because numbers overwhelmed users; Blitz keeps chips grey. for: [[itero-update-v3-10#^f1]], [[itero-update-v3-10#^f2]], [[blitz-lol#^f9]]
- C8: Patch day has no stated rule in the big tools (silence, curated lists, editorial
  caveats); DraftGap shrinks the patch rate to 30 days by 1,000 games and keeps
  matchups and duos on 30 days. for: [[mobalytics-beginners-guide#^f4]], [[ugg-locke-winrate-26-13#^f5]], [[ugg-garbagemen-reply#^f2]], [[draftgap#^f29]], [[draftgap#^f30]]
- C9: Players ridicule tiny-sample builds, call numbers without a sample size useless,
  and see counters differ between sites without knowing why. for: [[reddit-ugg-is-so-bad#^f2]], [[reddit-ugg-is-so-bad#^f3]], [[reddit-ugg-is-so-bad#^f4]], [[reddit-ss-counter-sites-differ#^f1]], [[reddit-ss-counter-sites-differ#^f2]], [[riot-august-ugg-sample-size#^f3]]
- C10: Only LoLTheory adjusts for the player's champion experience (own history or a
  fixed 25 games); others use favourites or ownership at most. for: [[loltheory-what-is#^f4]], [[loltheory-recommendations#^f1]], [[draftgap#^f16]] against: [[draftcoach-about#^f3]]
- C11: A raw thin rate misleads in a known direction: rare champion-roles win about 39%
  the next week, so shrinking to 50% or showing raw both mislead. for: [[meiolol-learned-tools#^f1]]
- C12: Counter and duo lists sorted by raw rate lead with their thinnest, noisiest cells,
  while real pairing effects are small and symmetric. for: [[meiolol-learned-tools#^f2]], [[ugg-darius-counter#^f13]], [[fdg-ugg-app-review#^f3]]
- C13: Per-option rune and build win rates are mostly noise, and the runes and spells set
  in champ select do not detectably move the win. for: [[meiolol-learned-tools#^f3]], [[meiolol-learned-tools#^f4]], [[fdg-ugg-app-review#^f6]]
- C14: On patch day last month's numbers predict better than the new patch's own, so a
  tool that waits for or shows only new-patch data is worse for days. for: [[meiolol-learned-tools#^f6]], [[meiolol-learned-tools#^f8]], [[riot-august-ugg-sample-size#^f2]]
- C15 (inferred): Any bracket filled from ranks looked up after the game inflates
  high-rank win rates; no rival says when it reads rank, and Emerald+ filters may count
  a game when only one side qualifies. for: [[meiolol-learned-tools#^f5]], [[reddit-ugg-is-so-bad#^f5]]

## Disagreements

Floors: 1,000 games (DraftGap, Phreak) vs 100 (LoLalytics) vs a 0.5% share (OP.GG). Our
result (C11) says no floor is right: thin cells should shrink toward what similar thin
cells win, not be hidden or shown raw.

## Open

- How each big app ranks its in-client pick list (Blitz has no docs at all)
- Facecheck and Team Advisor methods (guide 403, no method page)
- Complaints about apps suggesting champions the player never plays: none found (Reddit
  blocked late in the run)
