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
- 2026-10-12: Real interactions live in the lane. Champion embeddings beat per-pair
  cells only in thin matchups: under 25 train games lanediff14 +2.4%, cs10 +2.2% of base
  MSE; at 100+ games nothing. Evidence: model.md "Champion embeddings", 533d450. Sure.
  Use: embeddings (or a blend by count) for lane curves under ~100 games
- 2026-10-12: Most of the variation in early numbers is the game, not the draft: the
  draft explains a few % of gold@14, CS@10 and deaths variance. Sure. Site: show spreads
  and intervals, never single predictions

## Items

## Objectives

## Playstyle

## Player

- 2026-10-12 (dev only, interim): own rank tier predicts gold@14 within Platinum+
  (lab screen r 0.11). Lesson material ("at your rank expect X"), not a pick reason

## Data quality

- 2026-10-12: ~3,400 of 230k games (1.5%) end before 15:00 without the remake flag,
  ~90% by surrender (gameEndedInSurrender true, gameEndedInEarlySurrender false):
  leaver forfeits, real results for LP but decided by the leaver. Plus a few
  endOfGameResult Abort_AntiCheatExit (aborted, no real result). Remakes proper (5,205)
  are flagged. Evidence: snap-20261012T2055Z raw summaries (coordinator check). Models:
  exclude from win and stats; continuous outcomes already need 15:00
- 2026-10-12: Players nearly always finish a legendary before the game ends (top 1.1%,
  support 1.3% never do in games past 15:00), so first-item time is usable for all
  roles. Evidence: model.md "Team effects"
