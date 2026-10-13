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
- "Sure:" names what was measured. A null result is "not detected", with the largest
  effect the data still allows; "under X" only when X is a measured upper bound
- Leaving games out (short games, regions, patches) needs a with/without comparison
  first; until then say which code leaves them out and that it is untested
- Platinum IV+ games unless stated (the crawl's floor)

## Win

- 2026-10-13 (early): Knowing how much each player has played before the game adds a
  little to the draft: with every player's earlier games and wins on their champion and
  their recent form (games, win rate, KDA, lane gold, deaths) on top of the ten
  champions, our model picks the winner 54.1% of the time instead of 53.7% and ranks a
  winning team above a losing one 56% of the time instead of 55%. Sure: dev games only,
  8,500 EUW games scored, 90k training games; the gain is at the edge of noise, and we
  hold only 16 days of history (74% of players have no earlier game on their champion
  in our data), so it should grow. Site: nothing; research only, since other players'
  history isn't for the app. Evidence: docs/model.md "Player experience and everything
  pre-game" (log loss 0.6878 vs 0.6897, -0.0019 ± 0.0018)
- 2026-10-13 (early): We can't yet tell which champions reward a practised player most:
  giving each champion its own gain from earlier games on it predicted worse than one
  gain per role, and every champion's estimate is uncertain by 7-10 percentage points.
  Sure: not detected, dev only; only 0.1% of players have 50+ earlier games on their
  champion in our data. Site: no "champions that reward mastery" list. Evidence:
  docs/model.md "Player experience and everything pre-game"
- 2026-10-13 (early): The rank we store for each player is looked up after the game, and
  with it the model picks the winner 63.8% of the time instead of 53.7%; most of that
  is probably the result leaking into the rank, so it says nothing yet about what rank
  is worth before a game. Sure: dev only; leak and real effect can't be separated until
  rank at game start is recorded (from 2026-10-12). Site: never use the stored rank as a
  pre-game input. Evidence: docs/model.md "Player experience and everything pre-game"

- 2026-10-13: The same gold lead is worth more or less depending on the champions:
  at 25 minutes a team with Kayle top wins as often as an average team about 2,900
  gold further ahead, and a team with Pyke support as often as one about 2,600 gold
  further behind. It holds at equal gold in every role and with the same objectives
  taken, so it is the champion itself (late-game strength, fighting), not where the
  gold sits. Sure: 118k games, better on held-out games at every minute from 10 to
  30; common picks known to about ±1-3 percentage points.
  Site: lessons such as "on Kayle, 1,500 gold behind at 15 is par", with the
  interval; never a pick reason (who plays the champion isn't held fixed). Evidence:
  docs/model.md "Champion given the state (scaling)"
- 2026-10-13: Gold on your support barely moves your team's chances: 1,000 gold more
  on the support is worth 1-3 percentage points, against 6-12 on the bot laner, 4-11
  on jungle and mid and 4-8 on top; the bot laner's gold counts most at every minute.
  Sure: 118k games, better on held-out games at every minute from 10 to 30. Site:
  lessons ("your bot laner's gold lead matters most"); post-game leads may be weighted
  by role. Evidence: docs/model.md "Champion given the state (scaling)", who holds the
  gold
- 2026-10-13: We found no champion that is better at coming back from behind, or at
  closing out a lead, than at an even game: 2,000 gold behind at 15, a champion makes
  the same difference as at even. A champion's value beyond the gold mostly stays the
  same from minute 10 to 30, with a small real scaling curve (bot laners matter more
  late). Sure: 118k games; not detected rather than ruled out: the estimate is zero in
  most roles and minutes, at most about 2 percentage points per 1,000 gold (jungle,
  10-20 min), and modelling it never improved held-out games. Site: no "comeback
  champion" labels; scaling only as the effect by minute with intervals. Evidence:
  docs/model.md "Champion given the state (scaling)"
- ~~2026-10-12 (early): Our best draft model picks the winner 53.3% of the time, still
  getting better with every doubling of games. Withdrawn 2026-10-13: 53.3 was the old
  eval's pick percentile (reported there as no signal), not an accuracy, and the curve
  is flat from 67k to 90k games~~
- 2026-10-13 (early): The ten champions alone predict the winner only slightly better
  than a coin: our best draft model ranks a winning team above a losing one 55% of the
  time (a coin 50%). It improved from 4.5k to 67k training games but not from 67k to
  90k, so whether more games keep helping is open. Counters and ally synergy added
  nothing measurable; every region's games beat EUW's alone; weighting newer games
  didn't help. Sure: dev games only, 90k training games, games ending before 15:00
  still in. Site: nothing yet. Evidence: docs/model.md "Win from the draft" (AUC 0.550,
  log loss 0.6897 vs a coin's 0.6931)
- 2026-10-11: Knowing all ten champions does not yet predict the winner better than
  each champion's own win rate. Sure at 152k games. Site: no "this draft wins X%"
  claims. Evidence: meiolol eval, docs/model.md baselines (log loss 0.6905 vs 0.6902)

## Early game

- 2026-10-13: A higher rank means more gold at 14 in the same matchup: going from
  Emerald to Master is worth about 200 gold for a jungler, 145 mid and bot, 90 top and
  20 support, and Iron to Challenger spans 400-850 gold outside support. Sure: on
  106k held-out test games, adding your rank to the team model (3c-team) makes the
  typical gold miss 811 to 810 (0.3% of the error, give or take 0.1%; dev said 0.6%)
  and CS at 10 1.4% better (as on dev); lane gold difference and deaths unchanged.
  Clear on held-out games with the after-game rank, looked up after the game (sometimes
  days later) so it tracks recent results: the leak is large for win (db: 53.7% to
  63.8% of winners called on dev) and its share here is unknown. To recheck with the
  rank at game start (rank_history, from 12 Oct) before it's settled (see Data
  quality); not yet checked on top of 3c-team2. Site: lesson material ("at your rank,
  expect about X gold at 14 in this matchup"), not a pick reason: it is mostly better
  players earning more. Evidence: lab campaign
  gold14-a (built on 3c-team), run 20261012T2322Z-gold14-a-rankfx (effects-rank.tsv)
  paired vs 20261012T2222Z-gold14-a-ref on dev; final 20261012T2343Z-final-gold14-a,
  its test preds paired vs 3c-team.tsv (`meiolol-lab pairs`)
- 2026-10-13: Carries played off-role really do earn their usual gold at 14: Draven top
  (+840 over the average top laner, 87 games) matches Draven bot (+840), and Twitch,
  Locke and Briar support sit 810-870 above the average support. Sure: on 80k dev rows,
  letting each off-role champion lean on its own level in other roles changes no
  prediction (all five early numbers within 0.02% of the error) and moves these by
  under 70 gold; whether it is the champion or the one-trick players who pick it
  off-role is not separated. Site: the Draft tester keeps champions with 1%+ of the
  role's games. Evidence: dev runs 20261012T235952Z-t2ref-ref and
  20261013T000332Z-champlevel-cl (effects-champ.tsv), paired (`meiolol-lab pairs`)
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
  team doesn't show up beyond your lane. Sure: two different model types agree at 118k
  games; not detected rather than ruled out (the estimate is 0-21 gold at 14 and is
  switched off as noise in 3 of 5 roles). Site: no team counters or "best
  pick against this comp". Evidence: docs/model.md "Team effects", "Champion
  embeddings against the enemy team"
- ~~2026-10-12: Real interactions live in the lane: champion embeddings help only in
  matchups with few games. Superseded the same day by the lane opponent's general
  effect above, which explains most of it~~
- 2026-10-12: Most of what happens in your first 15 minutes comes from the game itself,
  not the draft: the draft explains only a few percent of the spread in gold, CS and
  deaths. Sure. Site: always show ranges, never a single predicted number

## Items

- 2026-10-12: Which item you finish adds almost nothing to predicting the win once you
  know when you bought it and how far ahead you were (a twentieth of what the champion
  adds). Sure: 118k games (2.9M first-three-item purchases); the champion-specific item
  term is not detected; no item-only model was fitted, so how much of "win rate by item"
  is the lead is not measured. Site: no "best build"
  or "this item wins more"; buying time and the lead at purchase are fair lessons.
  Evidence: docs/model.md "Items given the state at purchase"

## Objectives

- 2026-10-12: Teams that take objectives win about as often as teams with this much
  more gold lead: a dragon about 1000, each soul point about 800 more, soul about 4000,
  elder about 4800, baron 400-1000, an inhibitor 900 at 20 minutes to 2300 at 30, a
  grub 100-150; towers are worth only their gold. No difference was detected by who is
  ahead. Sure as a description, not proof the objective caused the win. Site:
  post-game "teams that took this dragon won about as often as teams 1000 gold ahead"
  (Jacob to confirm). Evidence: docs/model.md "Objective value given the state"

## Playstyle

- 2026-10-12: Early aggression, roaming and time in the enemy half look like they win
  games, but almost all of that is just being ahead; once the gold and XP leads at
  14:00 are known, style adds very little. What survives is small: bot laners and mids
  who trade more damage win a bit more (about +2.4 and +1.7 percentage points per step),
  supports who roam and fight and laners who take spare camps a little more. Sure:
  118k games for the overall result; the per-style numbers' intervals treat the ten
  players of a game as independent, so they are too narrow until refitted by game.
  Site: no "play aggressive to win"; post-game may show your own style against your
  role's spread. Evidence: docs/model.md "Playstyle given the state"

## Player

- ~~2026-10-12 (early): Higher-ranked players have more gold at 14 in the same matchup,
  as you'd expect. Sure: partly measured with the post-game rank (see Data quality),
  so not yet trustworthy. Site: lesson material ("at your rank, expect X"), never a
  reason to pick. Evidence: lab screen r 0.11 on gold14. Superseded 2026-10-13 by Early
  game "A higher rank means more gold at 14" (measured on held-out games)~~

## Data quality

- 2026-10-12: The rank we store with each game is taken after the game, so it already
  knows a little about the result. Sure. Models: use the rank at game start (from rank
  history) before trusting any rank effect. Evidence: meiolol-88
- 2026-10-12: Riot's "dragon soul given" event with team 0 only announces which soul is
  coming (in every game with 2+ dragons); only team 100 or 200 means a soul was taken.
  Sure: 1,683 of 2,209 such events are team 0 in archived timelines. Models read soul
  from team 100/200 only (src/objectives.zig)
- 2026-10-13: Leaving out the games that end before 15:00 without a remake flag (about
  1.5%, mostly surrenders after someone left) makes no difference we can detect to
  draft win predictions, and early-game numbers are identical either way, since those
  games never reach 15:00. Sure: dev only, 8,608 games, same code apart from the
  filter; win log loss differs by +0.00003 ± 0.00025 nats per row, so the largest
  effect the data allows is about 0.0003 nats either way. Models: the lab harness and the draft export fit on games that lasted
  15:00 (07564cc, 3500fd3), kept for the cleaner definition; the site's stats and
  meiolol eval still keep them. Evidence: meiolol-db, win-ratings champ_select,
  harness.min_duration_s 900 vs 0 at 4478aeb
- ~~2026-10-12: About 1.5% of games end before 15:00 without being flagged as remakes,
  mostly surrenders after someone left, likely decided by the leaver; a few are
  anti-cheat aborts with no real result. Real remakes are flagged correctly. Sure:
  3,400 of 230k games, raw summaries checked. Models: not settled. The lab harness
  leaves them out of win fitting and scoring (07564cc); the site's stats, meiolol eval
  and the draft export keep them. Whether leaving them out helps is untested: compare
  win runs with and without first. Early-game outcomes need 15:00 by definition.
  Superseded 2026-10-13 by the measured line above~~
- 2026-10-12: Nearly everyone finishes an item before the game ends (only 1.1% of top
  laners and 1.3% of supports in games past 15:00 never do), so first-item time works
  for every role. Sure. Evidence: docs/model.md "Team effects"
