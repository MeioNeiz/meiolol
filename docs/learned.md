# What we have learnt about the data

What the models and data checks have taught us, in plain words, newest first under
each heading. This is the summary Jacob, the admin page's Models tab and a new session
read first; numbers and method live in docs/model.md.

Headings are the admin page's model categories (Win, Early game, Items, Objectives,
Playstyle, Player, Data quality): put each line under its category.

How to write a line:
- First sentence: the finding in plain English a ranked player would follow, with
  numbers in gold, CS, deaths, minutes or percentage points. No MSE, sd, nats, model
  names or column names in it (the admin page shows only this sentence on the overview)
- Then "Sure:" how confident and at what data size; "Site:" what the site or app may
  say because of it; "Evidence:" the docs/model.md section or commit, where technical
  terms are fine
- Add a line when a result is final (held-out games, interval reported); mark dev-only
  results "(early)". Supersede, don't delete: strike the old line with ~~ ~~ and add the
  new one with its date
- Platinum IV+ games unless stated (the crawl's floor)

## Win

- 2026-10-13: The same gold lead is worth more or less depending on the champions:
  at 25 minutes a team with Kayle top wins as often as an average team about 2,900
  gold further ahead, and a team with Pyke support as often as one about 2,600 gold
  further behind. Gold on enchanter supports, Kayle, Aurelion Sol, Smolder and Jinx
  counts for more than it shows; gold taken by Pyke, Camille or Sylas support, Draven,
  Ezreal and Irelia counts for less. Sure: 118k games, better on held-out games at
  every minute from 10 to 30; common picks known to about ±1-3 percentage points.
  Site: lessons such as "on Kayle, 1,500 gold behind at 15 is par", with the
  interval; never a pick reason (who plays the champion isn't held fixed). Evidence:
  docs/model.md "Champion given the state (scaling)"
- 2026-10-13: No champion is measurably better at coming back from behind, or at
  closing out a lead, than at an even game: 2,000 gold behind at 15, a champion makes
  the same difference as at even. A champion's value beyond the gold mostly stays the
  same from minute 10 to 30, with a small real scaling curve (bot laners matter more
  late). Sure: 118k games; any comeback difference is under about 1 percentage point
  per 1,000 gold. Site: no "comeback champion" labels; scaling only as the effect by
  minute with intervals. Evidence: docs/model.md "Champion given the state (scaling)"
- 2026-10-12 (early): Our best draft model picks the winner 53.3% of the time (a coin
  flip is 50%, LoLDraftAI reports 55-56%), and it is still getting better with every
  doubling of games, with no sign of levelling off. Counters and ally synergy don't add
  anything measurable yet; using every region's games beats using EUW's alone; giving
  newer games more weight doesn't help. Sure: dev games only, 90k training games.
  Site: nothing yet; data volume is the lever. Evidence: meiolol-88's lab win runs
  (about -0.0008 log loss and +0.006 AUC per doubling)
- 2026-10-11: Knowing all ten champions does not yet predict the winner better than
  each champion's own win rate. Sure at 152k games. Site: no "this draft wins X%"
  claims. Evidence: meiolol eval, docs/model.md baselines (log loss 0.6905 vs 0.6902)

## Early game

- 2026-10-13 (early): A higher rank means more gold at 14 in the same matchup: going
  from Emerald to Master is worth about 200 gold for a jungler, 145 mid and bot, 90 top
  and 20 support, and Iron to Challenger spans 400-850 gold outside support. Sure: dev
  and one selection check on 85k EUW1 rows, the typical gold miss drops from 823 to 809
  (3% of it, give or take 0.3%); test not touched; the rank is the one recorded after
  the game, not at its start (a small leak, one game rarely changes a tier): hold the
  final until a rerun with rank at game start. Site: lesson material ("at your rank, expect about X gold at 14
  in this matchup"), not a pick reason: it is mostly better players earning more.
  Evidence: lab campaign gold14-a, run 20261012T2322Z-gold14-a-rankfx (effects-rank.tsv),
  selection 20261012T2332Z-gold14-a-rank-sel new-best
- 2026-10-13 (early): For your own gold at 14, it is who the enemy laner is that counts,
  not how your champion matches up against theirs: knowing the enemy laner's champion
  does as well as knowing the exact matchup. Sure: dev only, 80k rows, the two within
  noise of each other; other early numbers (lane gold difference, CS) not checked this
  way. Site: nothing yet. Evidence: lab campaign gold14-a, runs
  20261012T2324Z-gold14-a-nolane and 20261012T2328Z-gold14-a-lanemain
- 2026-10-12: Your lane opponent's champion changes your early game the same way
  whoever you play, on top of the specific matchup; adding that makes every early-game
  prediction better (gold at 14, lane gold difference, CS at 10, deaths before 15, first
  item time). Sure: 118k games, beats every earlier model. Site: lane curves use the
  opponent's general effect plus the specific matchup, which also fixes matchups with
  few games. Evidence: docs/model.md "3c-team2" (+0.3-0.7% of base MSE)
- 2026-10-12: Every champion in the game nudges your early numbers, and the nudges
  simply add up: your own champion moves your gold at 14 by a typical 270-360, your lane
  opponent by 75-200, a jungler by 20-65 and each other enemy by 15-50. Sure: 118k
  games. Site: "what your lane matchup and this enemy team typically do to your early
  game", with ranges. Evidence: docs/model.md "Team effects on early outcomes"
- 2026-10-12: Whether your champion in particular is good or bad against this enemy
  team doesn't show up beyond your lane: any such effect is under about 20 gold at 14.
  Sure: two different model types agree at 118k games. Site: no team counters or "best
  pick against this comp". Evidence: docs/model.md "Team effects", "Champion
  embeddings against the enemy team"
- ~~2026-10-12: Real interactions live in the lane: champion embeddings help only in
  matchups with few games. Superseded the same day by the lane opponent's general
  effect above, which explains most of it~~
- 2026-10-12: Most of what happens in your first 15 minutes comes from the game itself,
  not the draft: the draft explains only a few percent of the spread in gold, CS and
  deaths. Sure. Site: always show ranges, never a single predicted number

## Items

- 2026-10-12: Which item you finish barely changes your chance to win once you account
  for when you bought it and how far ahead you were; "win rate by item" mostly shows
  who was already ahead. Sure: 2.9M first-three-item purchases. Site: no "best build"
  or "this item wins more"; buying time and the lead at purchase are fair lessons.
  Evidence: docs/model.md "Items given the state at purchase"

## Objectives

- 2026-10-12: Teams that take objectives win about as often as teams with this much
  more gold lead: a dragon about 1000, each soul point about 800 more, soul about 4000,
  elder about 4800, baron 400-1000, an inhibitor 900 at 20 minutes to 2300 at 30, a
  grub 100-150; towers are worth only their gold. The values are the same whoever is
  ahead. Sure as a description, not proof the objective caused the win. Site:
  post-game "teams that took this dragon won about as often as teams 1000 gold ahead"
  (Jacob to confirm). Evidence: docs/model.md "Objective value given the state"

## Playstyle

- 2026-10-12: Early aggression, roaming and time in the enemy half look like they win
  games, but almost all of that is just being ahead; once the gold and XP leads at
  14:00 are known, style adds very little. What survives is small: bot laners and mids
  who trade more damage win a bit more (about +2.4 and +1.7 percentage points per step),
  supports who roam and fight and laners who take spare camps a little more. Sure:
  118k games. Site: no "play aggressive to win"; post-game may show your own style
  against your role's spread. Evidence: docs/model.md "Playstyle given the state"

## Player

- 2026-10-12 (early): Higher-ranked players have more gold at 14 in the same matchup,
  as you'd expect. Sure: partly measured with the post-game rank (see Data quality),
  so not yet trustworthy. Site: lesson material ("at your rank, expect X"), never a
  reason to pick. Evidence: lab screen r 0.11 on gold14

## Data quality

- 2026-10-12: The rank we store with each game is taken after the game, so it already
  knows a little about the result. Sure. Models: use the rank at game start (from rank
  history) before trusting any rank effect. Evidence: meiolol-88
- 2026-10-12: Riot's "dragon soul given" event with team 0 only announces which soul is
  coming (in every game with 2+ dragons); only team 100 or 200 means a soul was taken.
  Sure: 1,683 of 2,209 such events are team 0 in archived timelines. Models read soul
  from team 100/200 only (src/objectives.zig)
- 2026-10-12: About 1.5% of games end before 15:00 without being flagged as remakes,
  mostly surrenders after someone left: they count for LP but the leaver decided them.
  A few are anti-cheat aborts with no real result. Real remakes are flagged correctly.
  Sure: 3,400 of 230k games, raw summaries checked. Models: left out of win and stats;
  early-game outcomes already need 15:00
- 2026-10-12: Nearly everyone finishes an item before the game ends (only 1.1% of top
  laners and 1.3% of supports in games past 15:00 never do), so first-item time works
  for every role. Sure. Evidence: docs/model.md "Team effects"
