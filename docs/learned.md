# What we have learnt about the data

Plain findings from the models and data checks, newest first within each heading. One
line each: the finding, the evidence (docs/model.md section or commit), how sure, and
what the site or app may say because of it. Numbers and method live in docs/model.md;
this file is the summary a new session or Jacob reads first.

Headings are the admin page's model categories (Win, Early game, Items, Objectives,
Playstyle, Player, Data quality): put each line under its category.

Rules: add a line when a result is final (held-out, interval reported), not interim.
Supersede, don't delete: strike a line with ~~ ~~ and add the new one with its date.
Platinum IV+ games only unless stated (crawl floor).

## Win

- 2026-10-11: Win alone from the draft does not beat champion base rates (log loss
  0.6905 vs 0.6902 at 152k games). Evidence: eval, docs/model.md baselines. Sure at
  this size. Continuous outcomes carry more signal per game

## Early game

- 2026-10-12: The lane opponent's champion has its own effect on everyone in your role,
  beyond the matchup cell. Adding it (3c-team2) beats every earlier model on all five
  early outcomes (+0.3-0.7% of base MSE) and ties or beats lane embeddings; the
  embeddings' thin-matchup gain was mostly this. Evidence: model.md "3c-team2". Sure.
  Use: lane curves from the opponent's effect plus the shrunk pair cell, no embeddings
- 2026-10-12: Enemy and ally champions shift your early game (gold@14, lane gold diff,
  CS@10, deaths before 15, first item) additively: the same enemy shifts everyone in a
  role about equally. Own champion sd 270-360 gold@14, lane opponent 74-196, each other
  enemy 15-50, a jungler 20-65. Evidence: model.md "Team effects on early outcomes"
  (118k train / 10.6k test). Sure. Site may say: what your lane matchup and this enemy
  team typically do to your early numbers, with intervals
- 2026-10-12: "Your champion against this team" (class tags or champion pairs) is not
  detectable beyond the lane at 118k games: under ~20 gold@14. Evidence: model.md "Team
  effects" and "Champion embeddings against the enemy team" (two model families agree).
  Sure at this size. Site may not offer team counters or "best pick vs this comp"
- ~~2026-10-12: Real interactions live in the lane. Champion embeddings beat per-pair
  cells only in thin matchups: under 25 train games lanediff14 +2.4%, cs10 +2.2% of base
  MSE; at 100+ games nothing. Evidence: model.md "Champion embeddings", 533d450. Sure.
  Use: embeddings (or a blend by count) for lane curves under ~100 games~~
- 2026-10-12: Most of the variation in early numbers is the game, not the draft: the
  draft explains a few % of gold@14, CS@10 and deaths variance. Sure. Site: show spreads
  and intervals, never single predictions

## Items

- 2026-10-12: Which item a player finishes barely matters for winning beyond when it
  was finished and the lead then: item term ~1 pp sd in top and jungle, none in other
  roles; item on a specific champion none. Evidence: model.md "Items given the state at
  purchase" (2.9M rows). Sure at this size. Site may not rank builds by win rate; item
  timing is fair game

## Objectives

- 2026-10-12: Objectives are worth gold-lead equivalents beyond their own gold: a
  dragon ~1000, soul point ~800 more, soul ~4000, elder ~4800, baron buff 400-1000, an
  inhibitor down 900 at 20 min to 2300 at 30, a grub ~100-150; towers only their gold.
  The same whoever is ahead. Evidence: model.md "Objective value given the state"
  (118k train; held-out gain over the gold and XP lead clear at every minute). Sure as
  description, not cause. Site may say in post-game lessons "that dragon was worth
  about 1000 gold"

## Playstyle

## Player

- 2026-10-12 (dev only, interim): own rank tier predicts gold@14 within Platinum+
  (lab screen r 0.11). Lesson material ("at your rank expect X"), not a pick reason

## Data quality

- 2026-10-12: DRAGON_SOUL_GIVEN with teamId 0 (every game with 2+ dragons, ~12-15 min)
  is the soul's element being announced, not a soul taken; teamId 100/200 is the real
  soul. Evidence: archived raw timelines (1,683 of 2,209 such events are team 0).
  Sure. Models: read soul only from 100/200 (src/objectives.zig)
- 2026-10-12: ~3,400 of 230k games (1.5%) end before 15:00 without the remake flag,
  ~90% by surrender (gameEndedInSurrender true, gameEndedInEarlySurrender false):
  leaver forfeits, real results for LP but decided by the leaver. Plus a few
  endOfGameResult Abort_AntiCheatExit (aborted, no real result). Remakes proper (5,205)
  are flagged. Evidence: snap-20261012T2055Z raw summaries (coordinator check). Models:
  exclude from win and stats; continuous outcomes already need 15:00
- 2026-10-12: Players nearly always finish a legendary before the game ends (top 1.1%,
  support 1.3% never do in games past 15:00), so first-item time is usable for all
  roles. Evidence: model.md "Team effects"
