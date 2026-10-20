---
title: 'Coach Rogue: WHY Does League''s Bounty System Seem So BROKEN?'
url: https://www.youtube.com/watch?v=hfjIBR9kbQ4
kind: video
commit: 
for: [coach-stat-claims]
looked: 2026-10-20
depth: listed (whole transcript, description, top 20 comments)
relevance: medium
grade: C/fair
description: 11-minute video (2 Jul 2025, patch 25.13 era) explaining the then-new team-advantage bounty suppression from clips and one tested game, with tips to exploit it
---
# Coach Rogue: WHY Does League's Bounty System Seem So BROKEN?

Why: which of his bounty claims hold under today's rules and in our kill data?

## Assessment

- Evidence: C. Rules worked out from replays of his own solo queue games and a viral
  clip; one deliberate test (a Graves death at level 17). He says himself the maths
  "might not be 100% perfect". Uploaded 2 Jul 2025, a patch after the bounty rework
  (V25.11 in the wiki's history); since then V25.14 and V26.03 changed accrual and
  depreciation rates ([[lol-wiki-champion-gold-bounties#^f6]]). 22.9k views.
- Reasoning: fair. Explains the mechanism, checks one hypothesis (dying while suppressed
  resets the bounty) and drops it when the test fails.
- Interests: Patreon and coaching links in the description; nothing sold in the video.
- Weigh: the mechanism matches the wiki and our kill data; the worked farm numbers
  don't; the "delay the dragon" tip is undercut by the wiki's 5 s deferral (^f7).

## Findings

- [learning] Bounty grows 1 gold per 3 gold earned from kills and assists, plus a share
  of farm, and only goes down on death, back to base (300, a little more with level).
  @1:51 @2:36 ^f1
  > Killing or assisting in a champion kill will increase the gold you are worth by one for every three gold you get from that kill.
  > the only way to make it go down is to die, at which point it is fully reset back to its base amount
- [learning] (inferred) The kill rate matches the wiki (1:3); "fully reset" holds for a
  shutdown bounty but ordinary bounty depreciates 1 per 3.5 gold given since 26.03
  ([[lol-wiki-champion-gold-bounties#^f4]], [[lol-wiki-champion-gold-bounties#^f6]]). ^f2
- [learning] Team advantage (gold, XP, turrets, neutral objectives) decides how much of
  a team's bounties is claimable; a team near even has them suppressed entirely, in
  steps of 30% (the 60% and 90% cuts in his example). @3:11 @4:49 ^f3
  > The bounty system calculates how strong both teams are by using a combination of gold, XP, turrets, and neutral objectives taken by both teams.
  > a team who's considered to be exactly even when compared to the enemy team will have the bounty suppressed entirely
- [learning] A suppressed bounty keeps counting and is not reset by a death while
  suppressed; tested on a level 17 Graves who gave only base gold. @6:33 ^f4
  > 410 gold is the base amount of gold you always give when you die at level 17
  > Bounties while in an inactive state cannot be claimed.
- [data] Worked example: an Irelia with 123 minions and six kills, put at about 900
  bounty from farm plus 675 from kills, 1,575 total, 630 claimable after a 60% cut. He
  flags the maths as approximate. @3:11 @4:01 ^f5
  > This mean Aurelia's bounty would be worth 1,575 gold right now
  > I'm working off imperfect info
- [data] (inferred) The farm part is far too high under the wiki's rates: farm accrues 1
  bounty per 20 gold (17.5 in mid 2025), so 123 minions (about 2,700 gold) add about 150,
  not 900 ([[lol-wiki-champion-gold-bounties#^f4]]). ^f6
- [learning] Exploit tips: activate the Pyke assist item only after buying, and hold a
  dragon's last hit until a dying teammate is dead so the bounty jumps a tier first. A
  top comment (88 likes) cites the wiki: bounty changes wait until 5 s out of combat,
  which voids the dragon tip. @7:36 ^f7
  > always wait until after you recall to buy items before activating the pike item
  > changes to a champion's gold bounty are deferred until 5 seconds after exiting combat with enemy champions
- [learning] His verdict: a good comeback mechanic, rewarding the losing team for killing
  the strongest enemy. Our kill data agrees: killers 3k+ behind get 481 gold a kill and
  a bounty or shutdown in 37% of kills, killers 3k+ ahead 294 and almost never
  ([[kill-gold-by-rank-measured#^f3]]). @10:44 ^f8
  > It rewards you for killing the strongest enemy at a moment where your team is losing the game.
- [needs] Reception: comments like the explanation but find the swings confusing and
  opaque in game; several ask for finer tiers or a smoothed target bounty. ^f9
  > My main issue as a player with these bounties is the lack of transparency within the game
- [learning] Checked, not there: no counts or rates from games, only clips; no patch
  number named. ^f10

## Read

- `raw/coachrogue-bounty-system.md`: everything (auto captions; "Aurelia" is Irelia)

## Not read

- The on-screen scoreboards (only narration is in the transcript)
