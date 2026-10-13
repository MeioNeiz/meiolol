# Fields: what we fetch, keep and drop

Owner: stats CPU session (meiolol-3c), 2026-10-12. Input for the stats models
(docs/model.md) and the retention decision (Jacob). The GPU session (meiolol-2a) builds
on this list. Field names as Riot sends them.

## Per match today

| Source | Calls | Kept | Where |
| --- | --- | --- | --- |
| match summary | 1 | 41 of 156 participant fields, bans; raw 3 days (~1.9 days in practice) | participants, bans, drafts; raw.db raw_docs |
| timeline | 1, EUW all, others 50% (`--timelines 50`) | compact form forever; raw 0 days | timeline.db; raw.db timeline_docs |
| mastery | per player, platform bucket | off (`--no-mastery`) | mastery |
| ladder | platform bucket | rank per player, history per change | ranks, rank_history |

Sizes: summary 79 KB JSON / 12.8 KB gz; timeline ~730 KB / ~60 KB gz; compact timeline
~8.6 KB; everything raw ~7 GB/day at today's ~165k matches/day (coordinator, 2026-10-12).

## Kept forever

- participants: slot, team, PUUID (blanked at 24 months), champion, teamPosition,
  individualPosition, win, kills, deaths, assists, goldEarned, damage to champions,
  damage taken, vision score, CS (lane + neutral), level, 2 spells, 7 items, full rune
  page and shards, rank snapshot (tier, division), gold10/14/15 (from the timeline)
- matches: id, platform, queue, patch, start, duration; bans (team, slot, champion)
- drafts: 10 champions + roles, bans, median rank, blue win, minutes (no ids)
- compact timeline, per minute per player: total and current gold, xp, level, lane and
  jungle CS, x/y, damage to champions, damage taken, CC dealt (ms)
- compact timeline events: champion kills (killer, victim, x/y, bounty, shutdown,
  assists), item purchased/sold/destroyed/undo, skill level up, level up, ward placed
  and killed (type, no position: Riot sends none), building kill (lane, tower type,
  team, assists), turret plate, elite monster (type, subtype incl. dragon element,
  team, assists), champion transform, dragon soul
- ranks / rank_history: ladder rank, LP, wins, losses per day of change (Platinum IV+)

## Dropped

### Summary, per participant (115 fields + 128 challenges)

Gone after the raw window. Grouped; * = likely useful for the models.

- *damage by type: physical/magic/true dealt to champions and taken, self mitigated,
  to buildings, to objectives, to turrets
- *healing and shielding: totalHeal, totalHealsOnTeammates, totalDamageShieldedOnTeammates,
  timeCCingOthers, totalTimeCCDealt
- *casts: spell1-4Casts, summoner1/2Casts
- *vision detail: wardsPlaced, wardsKilled, detectorWardsPlaced, visionWardsBoughtInGame
- *death and tempo: totalTimeSpentDead, longestTimeSpentLiving, timePlayed
- *flags: firstBloodKill/Assist, firstTowerKill/Assist, gameEndedInSurrender,
  gameEndedInEarlySurrender, teamEarlySurrendered
- objective counts: baron/dragon/inhibitor/turret kills and takedowns, objectivesStolen
- streaks: doubleKills..pentaKills, largestKillingSpree, largestMultiKill, killingSprees
- pings (14 kinds): allInPings, enemyMissingPings, ... (tilt/communication, unclear use)
- noise for us: champExperience (champion's in-game xp), summonerLevel, profileIcon,
  riotIdGameName/Tagline, summonerName, arena augments and placements, missions,
  PlayerScore0-11, goldSpent, consumablesPurchased, itemsPurchased

challenges (128): Riot-computed, mostly playstyle-shaped. Useful-looking:

- laning: laneMinionsFirst10Minutes, jungleCsBefore10Minutes, maxCsAdvantageOnLaneOpponent,
  maxLevelLeadLaneOpponent, laningPhaseGoldExpAdvantage and earlyLaningPhaseGoldExpAdvantage
  (0/1 flags only), visionScoreAdvantageLaneOpponent, turretPlatesTaken, soloKills,
  quickSoloKills, takedownsFirstXMinutes
- roaming: killsOnOtherLanesEarlyJungleAsLaner, getTakedownsInAllLanesEarlyJungleAsLaner,
  takedownsBeforeJungleMinionSpawn, unseenRecalls
- mechanics: skillshotsHit, skillshotsDodged, landSkillShotsEarlyGame,
  dodgeSkillShotsSmallWindow, abilityUses, enemyChampionImmobilizations
- fighting: killParticipation, teamDamagePercentage, damageTakenOnTeamPercentage,
  outnumberedKills, killsUnderOwnTurret, killsNearEnemyTurret, pickKillWithAlly,
  saveAllyFromDeath, survivedSingleDigitHpCount, effectiveHealAndShielding
- objectives: dragonTakedowns, baronTakedowns, riftHeraldTakedowns, epicMonsterSteals,
  epicMonsterKillsWithin30SecondsOfSpawn, scuttleCrabKills, initialCrabCount,
  buffsStolen, voidMonsterKill, firstTurretKilledTime, kTurretsDestroyedBeforePlatesFall
- vision: visionScorePerMinute, controlWardsPlaced, stealthWardsPlaced, wardTakedowns,
  wardTakedownsBefore20M, wardsGuarded
- items: fastestLegendary (also from timeline events), legendaryCount
- the rest: Arena/ARAM/Swarm modes, cosmetic feats (poroExplosions, fistBumpParticipation)

### Summary, per team

- objectives (baron, dragon, horde = grubs, riftHerald, atakhan, tower, inhibitor,
  champion: first + kills) and feats (FIRST_BLOOD, FIRST_TURRET, EPIC_MONSTER_KILL).
  All derivable from compact timeline events, so only a loss for games without one

### Timeline

- per minute per player, championStats (25): health, healthMax, armor, magicResist,
  attackDamage, abilityPower, attackSpeed, abilityHaste, movementSpeed, lifesteal,
  omnivamp, armorPen, magicPen (flat and %), ccReduction, power (mana), regen. Build
  strength by minute without item maths
- per minute per player, damageStats: physical/magic/true split of dealt, dealt to
  champions and taken (we keep only the two totals). Enemy damage mix as felt
- goldPerSecond (constant, not useful)
- CHAMPION_KILL: victimDamageReceived and victimDamageDealt (each hit in the last
  seconds: who, which spell, physical/magic/true), victimTeamfightDamage*,
  killStreakLength. "How you died" for the post-game view
- CHAMPION_SPECIAL_KILL (first blood, multikills, ace), OBJECTIVE_BOUNTY_PRESTART/FINISH
  (comeback bounty state), GAME_END, PAUSE_END; position of elite monster kills
  and bounty of building kills

## Needs per identity feature

Use-time = what a feature may take when shown in champ select (docs/production-key.md):
champions, roles, the user's own rank and experience, lobby facts. Train-time may use
anything.

| Feature | Fields | Have? | Volume needed |
| --- | --- | --- | --- |
| Your games vs curve | per-minute gold, xp, CS, level of you and lane opponent; kills/deaths with time | yes (compact) | curve per champion-role; pairs 200+ games |
| Lane curves | same, per pair, bracket | yes | pairs 200+ per patch (C8: most pairs need more than a personal key) |
| Champion vs enemy team | 10 champions + roles; outcomes from compact timeline; comp type needs champion classes (champions.tags) or labels; damage mix per enemy champion | mostly; damage by type dropped (can be estimated per champion, not per game) | to be measured (step 3) |
| Picker reasons | champions, roles, own rank (rank_history), own experience | experience weak: mastery off, crawled history only for the 1/16 scan sample | per draft model eval |
| Post-game view | the user's game is fetched live (raw); comparisons need crawled aggregates of whatever we show; "how you died" needs victimDamageReceived | partial | same as curves |
| Items | purchase events with time, per-minute gold of all 10 (gold diff at purchase), enemy team | yes (compact) | to be measured |
| Objectives | elite monster, building, plate events with time; per-minute gold; positions; soul state | yes (compact); bounty state dropped | to be measured |
| Playstyle | positions per minute, kills with x/y, wards (counts), CS; challenges (roams, solo kills, skillshots, vision) | positions yes; challenges dropped | to be measured |

## Measured 2026-10-12

- What carries signal (docs/model.md, `meiolol outcomes`, 118k Platinum+ games): lane
  opponent, bot lane partners, junglers and the rest of both teams each shift gold@14,
  CS@10, deaths before 15 and first item time beyond noise, additively. Own champion x
  enemy class and own champion x enemy champion interactions: not detectable (true
  spread under ~20 gold at 14). Timelines are where the signal is; interactions need
  far more games than one patch gives
- Raw summary, per doc: 11.8 KB gzip as stored; 4.7 KB in a zstd -19 --long stream of
  3,000 docs (2.5x). Raw timeline: 63 KB gzip, 36 KB zstd -19 alone (1.75x); a batch
  likely ~25 KB (to measure on the first archived day)
- Compact timeline additions, from the fixture game (gzip of delta text, rough): per
  minute championStats +3.5 KB, damage split +4 KB, death recaps (victimDamageReceived
  and Dealt) +3-6 KB, on today's 8.6 KB
- Box (2026-10-12 21:30Z, after the WAL fix): 129 GB free, ~172k matches/day, compact
  rows ~1.5 GB/day
- Signal per field (2026-10-13, docs/model.md "Field ranking"): champ select fields
  (spells, keystone, trees, shards, role assignment status) carry draft-time signal on
  every early outcome, a few bytes per player: recommended for compact rows (not yet
  decided). Challenges add almost nothing to win beyond the 14:00 state; whole-game
  ones mostly restate the result

## Decided (Jacob, 2026-10-12)

"We need to keep more data while we figure out what we need"; keep anything per player
that might help training, within the law; "for now keep raw data until we understand it
better". Applied on the box 2026-10-12 ~21:30-21:45Z (crawl.args; the previous one in
crawl.args.bak-20261012):

- Compact rows and timelines forever (`--keep-days 0`); raw summaries kept on the box
  until archived (`--raw-match-days 0`); raw timelines likewise (`--raw-timeline-days
  3650`): acked raw is pruned at ack after 2 days (`raw-export --ack`), and the
  crawler's raw prune never passes the acked point
- Every match gets a timeline (`--timelines 100`, coordinator for Jacob): every result
  with signal comes from timelines
- Mastery on. Today that is one snapshot per sampled ladder player (1 in 16), dropped
  and refetched after 30 days; the archive keeps each snapshot, so history builds up.
  Proposal: mastery for match participants near game time (crawler change, not made)
- Tier floor stays Platinum IV+

Raw archive (src/archive.zig box side, src/lab/archive.zig gpu-box side,
deploy/archive-pull.sh, docs/data-safety.md "Raw archive"):

- Box: `meiolol raw-export` writes everything fetched since the last export (raw
  summaries, raw timelines, mastery snapshots) to data/archive-out as stored; real ids
  never leave the box except over this ssh link, and the salt never comes to the box.
  The gpu-box's key may only run deploy/archive-serve.sh (export, list, send, ack,
  forgotten)
- gpu-box, hourly, not while League is open: fetch, pseudonymise with the snapshot salt
  (archive ids = snapshot ids; Riot IDs and names blanked; per-player links kept: the
  same hashed PUUID in every game), zstd -15 --long per kind per export, test, ack.
  Archive at /mnt/wsl/archive (1 TB partition on the NVMe)
- Box drops raw documents only once acked and 2 days old; unacked ones stay, so the PC
  can be off until the box disk runs short (health alert: no ack for 12h)
- Kept until player ids would be blanked anyway: days past 24 months lose every hashed
  PUUID and their mastery (`archive-age`), as the crawler blanks its own rows. Forgotten
  players: left out at ingest, erased from archived days (`archive-forget`) each round
- Size, measured on the first pull (2026-10-12; timelines from 1,744 only, recheck on a
  full day): ~172k summaries/day x 4.3 KB and ~130k timelines/day x 45 KB at -15: ~6.6
  GB/day, ~2.4 TB/year; the 1 TB partition lasts ~5 months, then more disk (Jacob plans
  to buy)

Next, after the models: compact v2 with what they choose. Likely regardless: damage by
type to champions and taken (6 ints in participants); death recaps for the post-game
"how you died" (~+50% compact size); a challenges subset if any carry signal
