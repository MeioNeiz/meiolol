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

- 2026-10-14 (early, 2253Z): The champions tell you far more about who wins once you
  know how the game stands than before it starts: with each team's gold, kills and
  objectives at 15 minutes known, the draft adds about five times as much as it does in
  champ select, rising to 20 minutes and easing only slightly by 30. A draft one step
  stronger than usual wins about 4.6 percentage points more often, and none of that was
  found to come through getting ahead early, though we can only rule out more than
  about 2.3 of those points. Sure: snap-20261013T2253Z, 5 forward folds, 100,847 games
  with a 15-minute timeline (dev-val 26,263, every platform agrees), readings
  pre-declared before any run; draft given state at 15 -0.0201 ± 0.0012 nats/game
  (5/5) against draft alone -0.0041 ± 0.0006 (about 4x on dev-val); two shuffled-draft
  controls (across games, within patch x platform) at zero. The early-lead part is "not
  detected": g-computation with the joint state at 10/14/20, |indirect| under 2.3 pp per
  sd of draft score against a total of about 4.6, so only a large part is ruled out;
  bootstrap intervals slightly narrow. The state also carries who plays better, so "at
  equal state" is description, not cause. Dev only, no test look. Site: nothing; no
  "this draft wins late" or win-chance claims from it. Evidence: docs/model.md "How
  drafts win" (Q1, Q3), audited by meiolol-53

- 2026-10-14 (2253Z): How players did in their earlier games (gold, CS and damage per
  minute, how often they played off their role, days since their last game) predicts
  the winner beyond how much they have played: the ten champions alone pick the winner
  53.7% of the time, adding each player's games and wins on their champion and recent
  form lifts it to 55.5%, and a model given these earlier-game averages as well picks
  56.1% against 55.6% for the same model without them (ranking a winning team above a
  losing one 58.5% of the time instead of 57.8%). The
  gain is bigger when more of the ten have earlier games, about twice as big with all
  ten as with four or fewer. Whether players have queued together before adds nothing
  we can detect. Sure: snap-20261013T2253Z, 134,375 games in 5 forward folds, a sealed
  pre-declared check (3 new seeds, two 90% resamples, every fold better, a shuffled-
  feature control at zero); the first player term past the noise floor beyond the
  experience terms; premade not detected (at most ~0.1 milli-nats per game). "Earlier
  games" means games our crawl holds, so how much history a player has follows crawl
  depth, not what a live lobby would know. Dev folds only, no test look. Site: nothing;
  internal only, other players' history is never for the app. Evidence: docs/model.md
  "Prior and premade, sealed confirmation" (history means -0.00195 ± 0.00031 nats/game
  beyond the net on win-exp; win-exp -0.00507 vs ratings), audited by meiolol-53

- 2026-10-14 (2253Z): Who faces whom, and who plays beside whom, matters a little beyond
  each champion's own strength. The lane matchups matter most: top vs top (typical
  difference between matchups about 2.5 percentage points of win chance), mid vs mid
  1.9, support vs support 1.3, bot vs bot 1.2, jungle vs jungle 1.1, mid vs the enemy bot
  0.7-0.9, bot vs the enemy support 0.8-0.9 and top vs the enemy mid 0.4-0.6 (cross-role
  sizes as a range until a planted check settles how to combine the two sides). Among
  allies only the bot laner and support's
  pairing shows (about 1.3 points); the other nine ally pairings show nothing. A
  champion's own strength spreads 1.6-3.4 points by role (support most). Sure: one
  pre-declared test on 134,375 held-out games (5 forward rounds, every platform): a
  shrunk table of champion strength, every ally and enemy role pairing and the damage
  mix predicts better than champion strength plus the damage mix (win-comp) by 1.15 ±
  0.22 mnats per game, better in 5 of 5 rounds and in both 90% resamples; the pairings
  alone add 0.82 ± 0.17 beyond strength and mix; dev-val (reported only) 1.7; no test
  look. Designed on the older pin, whose games overlap the early rounds; the gain is
  largest on the newest games. The sizes are typical spreads across pairs, and lower
  bounds: planted pairs came back at 0.6-0.9x; single pairs have 1-3 games each and are
  not reported. Other ally pairings and the other cross-role matchups not detected, at
  most about 0.3 and 0.7 points as fitted. Site: lane matchup and bot-lane synergy may become
  reasons on the admin draft board once the shipped model switches to this table; no
  numbers for single champion pairs. Evidence: docs/model.md "Effects and the CPU
  model", "Additive model on snap-20261013T2253Z", audited by meiolol-53
- 2026-10-14 (2253Z): Beyond which champions are picked, a comp's damage makes a small
  measurable difference, each about 1-2 percentage points for a comp clearly off in that
  way: damage far from half magic loses, magic-heavy teams (60%+ magic) lose about 2
  points more, and physical damage into a team of armour-leaning champions does worse
  while magic damage into it does better. Tanky teams do slightly better, not worse,
  against champions who buy penetration items. No coaching win condition (dive vs peel,
  engage vs disengage, front-to-back, healing vs anti-heal, split vs waveclear) or comp
  archetype was found. Sure: 89,584 unseen held-out games (sealed blocks, every
  platform), 244 traits screened, one pre-declared list of 32 read with Holm: mix -1.1
  pp per team sd (z -9), magic 60%+ -2.1 ± 0.9 pp, AD share x their armour -0.6 ± 0.2
  and tankiness x their pen items +0.6 ± 0.2 pp per team sd. These are associations
  beside champion strength; adding them doesn't measurably improve predictions (-0.34 ±
  0.25 mnats beyond the mix, under the noise floor). The rest not detected (plants on
  2055Z: a true 1.6 pp per team sd found, 1.1 not; this pin's intervals are about half
  as wide, not re-planted). Sustain against poke (-0.6) kept its sign from the screen but
  wasn't declared for that direction; poke against engage (+0.4) showed only on the
  sealed games: leads for the next pin.
  Site: the damage-mix reason as before; "physical damage into armour" may become a
  reason without a number once the production key allows anything public; no tank vs
  pen or win-condition advice. Evidence: docs/model.md "Comp discovery" (rerun on
  snap-20261013T2253Z), audit meiolol-53
- ~~2026-10-14: Screening 252 team traits and team-vs-team matchups beyond champion
  strength finds only the damage mix: lopsided damage (team magic share far from half)
  costs about 0.9 percentage points of win chance per team sd, reproducing win-comp's
  term on games already used for it, and near zero on the newest games alone (-0.1). No
  other trait, win condition or archetype holds: AD share x enemy armour, 4+ ranged and
  2+ catch-and-kill engagers passed the screen but not the sealed games; coaching win
  conditions (front-to-back, dive vs peel, poke vs engage, split vs waveclear, healing vs
  anti-heal) are each within about ±1 point per sd. Sure: sealed blocks 4-5 and dev-val,
  26,242 games, z -4.1, Holm over 27 pre-declared names; not detected rather than ruled
  out: a planted mix effect of 1.6 points per team sd (estimated at about 1) was found,
  1.1 was not; flags one team in ten has need about 3 points estimated, about 5 true if
  flags shrink like the mix. Adding the mix to ratings doesn't measurably improve log
  loss on the sealed games (-0.00028 ± 0.00042 nats). Site: nothing new; good and bad
  comps stay the damage-mix reason only. Evidence: docs/model.md "Comp discovery", audit
  meiolol-33~~ (superseded by the 2253Z line above)
- 2026-10-14: No champion was found to turn its own gold lead into wins better than
  others in its role: what 1,000 gold on your champion is worth depends on the role, at
  15 minutes about 8 percentage points for the bot laner, 4.5-7 for top, jungle and mid
  and about 0 for the support (at 25 minutes: 5, 3-3.5 and 0). Sure: 10,604 held-out
  EUW games, one pre-declared look at 15 and 25 minutes with the team's gold, XP and
  objectives held fixed; not detected, but not ruled out: a planted spread of 2 points
  per 1,000 gold across a role's champions showed in the checks, 1 point didn't, and
  the data allow spreads up to 3-11 points. Site: no "carry champion" or "low-impact
  champion" labels; lessons by role ("your bot laner's lead matters most"). Evidence:
  docs/model.md "Carry and impact" (test +0.00003 ± 0.00007 and +0.00001 ± 0.00008
  nats; audited by meiolol-33)
- 2026-10-14 (early): A small neural network that reads what each team's champions
  typically do in games (damage type, tankiness, crowd control, healing, range) finds
  mostly the same thing as the lopsided-damage line below: up to about two-thirds of
  what the one hand-made damage-mix term gives, from the same lopsided teams; adding the
  enemy's champions didn't help, and on top of the damage-mix term it is not confirmed
  to add more. Sure: dev only, 5 rounds of held-out games (44,353; 44-89k training games
  a round), confirmed with fresh seeds and two resamples by the narrowest margin
  (-0.00037 ± 0.00021 nats per game, honest size about 0.00015-0.0004, a quarter to
  two-thirds of the term's), nothing on the 8,500 dev-val games; on top of the
  damage-mix term -0.00025 ± 0.00017, not confirmed. As a pipeline check (first seeds,
  default net) shuffled profiles or shuffled results gave nothing. Site: nothing, the
  recommender keeps the ratings and the damage-mix term. Evidence: docs/model.md "Set
  net: DeepSets on champion profiles", audit meiolol-33
- 2026-10-13 (early): A large neural network that reads the whole draft predicts wins no
  better than each champion's own win record in its role: one trained copy is worse, and
  only averaging ten or more copies brings it level; tuning its settings didn't help.
  Sure: not detected, dev only (5 rounds of held-out games, 44,353, plus 8,500 dev-val;
  44-89k training games a round): sealed confirmation copies -0.00012 ± 0.00036 nats per
  game and a resample -0.00010 ± 0.00035; 20 copies -0.00034, which with the noise floor
  (± 0.00042) leaves at most about 0.0008 nats per game of real gain; every single copy
  is worse (+0.0006 to +0.0035); the best of 32 settings by validation -0.00009 ±
  0.00046. Site: nothing, the recommender keeps the ratings. Evidence: docs/model.md "Big
  net: tuning, seed ensembles, confirmation", audit meiolol-4b
- 2026-10-13 (early): Knowing how each champion plays in its role (gold, CS, deaths,
  damage and early lead, learnt from past games) does not measurably improve win
  predictions beyond each champion's own win record; any help is in rarely played
  picks, and even there it is within noise. Sure: not detected, dev only (5 rounds of
  held-out games, 44,353, plus 8,500 dev-val), better in every round but by at most
  about 0.0007 nats per game the data still allows (-0.00024 ± 0.00048 with resample
  noise); random vectors and shuffled labels give nothing. Site: nothing, the
  recommender keeps the ratings. Evidence: docs/model.md "Pretrained champion-role
  embeddings", audit meiolol-4b
- 2026-10-13: Knowing that a team's damage is lopsided makes win predictions only a
  little better overall, because only about one team in ten is lopsided: the gain was at
  the edge of noise over five rounds of held-out games and not detected on the test set.
  Sure: 10,604 EUW test games, game by game against the champions-only model; a gain
  larger than about a fifth of what the champions themselves add is ruled out (the
  rounds' estimate sits at that edge). The effect itself holds (the lopsided-damage line
  below); it is the prediction gain that is small. Site: the admin Draft tester may show
  the term with its interval; lessons quote the effect line. Evidence: docs/model.md
  "Model: win-comp ablation" (test log loss 0.69065 vs 0.69064, +0.00002 ± 0.00048;
  rounds -0.00057 ± 0.00028)
- 2026-10-13: A team that deals under a fifth of its damage as magic wins about
  5 percentage points less often than its champions alone suggest, and lopsided teams
  (that, or over 60% magic) about 3 points less than balanced ones; how many
  tanky champions a team has and how much crowd control it brings make about a point of
  difference at most. Sure: 44,353 games from every region in five forward time blocks
  (dev), each team's mix from its champions' averages over the games before
  its block, beyond a champion-strength model fitted on the same older games. Lopsided
  minus balanced -3.0 ± 1.1 points, in every block (-2.4 to -3.6); on 10,604 held-out
  EUW test games (one pre-declared look) -2.7 ± 2.2, consistent; the 3% of teams under
  20% magic damage -5.3 ± 1.7. In iTero's rarer extremes (under 20% or over 80%
  physical, 1% of teams) -10 ± 5 and -8 ± 4, like iTero's unadjusted -9 and -6, so their
  gap is not just which champions sit in those comps. About one team in ten is
  lopsided. EUW alone -2.6 ± 2.1 in the blocks, not different from other regions
  (+0.5 ± 2.5; the 8,500 newest EUW games showed -0.3 ± 2.5). No frontline -0.4 ± 0.8;
  weakest-frontline quarter -0.9 ± 0.8 and least-CC quarter -0.8 ± 0.8, just past zero
  but not once seven tests are allowed for; armour-heavy picks into magic damage not
  detected (-2.5 ± 2.6); these and the <20% size are from the blocks only, the test
  checked lopsided minus balanced alone. Site: the admin Draft tester may show the size
  (about 3 points); the public site and app may give it only as a reason without a number
  ("your team's damage is almost all physical; mixed damage tends to do better", never
  "+X% win rate", docs/production-key.md), once the production key allows anything
  public; no frontline or CC warnings. Evidence: docs/model.md "Comp features
  from champion profiles", model-free cross-check (folds and test look)
- ~~2026-10-13 (early, to be updated with the larger held-out check and the win-comp
  model): Whether a team's damage is mostly magic or mostly physical, how many tanky
  champions it has, or how much crowd control it brings does not detectably change its
  chance of winning beyond which champions are in it. Sure: 8,500 dev EUW games, each
  team's mix from its champions' averages over ~89k older games; not detected: a
  lopsided damage mix is within about 3 percentage points of a balanced one, no
  frontline at most 2 points worse, low crowd control at most 1 point worse;
  armour-heavy picks into magic damage too uncertain to bound under 6 points. The same
  check finds the 11-point gap between the strongest and weakest quarter of drafts by
  champion strength. Teams whose champions average under 20% or over 80% physical
  damage are under 0.5% of teams, so "all-AD comps lose" can't be tested this way. Site:
  no "your comp lacks AP / a frontline" warnings as fact. Evidence: docs/model.md "Comp
  features from champion profiles", model-free cross-check~~
- 2026-10-13: Once you know each team's gold at 14:00 and how long the game ran, the
  early-game stats Riot records (first tower, takedowns in the first minutes, the
  laning-phase gold and XP lead) barely help tell the winner: the best adds under half a
  percent. Sure: 10,604 held-out EUW games, fields picked on dev before one test look;
  first tower, early takedowns and the laning-phase lead clear zero after correcting for
  the many fields tested; lane CS and jungle CS before 10 and the early-laning lead not
  detected. Whole-game stats (towers, barons, level, biggest kill deficit) explain far
  more but mostly record who won. Site: no "take first tower to win"; post-game may show
  them as what happened, not why. Evidence: docs/model.md "Field ranking" (B)
- 2026-10-13: What you set in champ select for yourself (summoner spells, runes, stat
  shards, being autofilled, account level) does not detectably change your chance of
  winning on the same champion and role. Sure: 10,604 held-out games; none improved
  held-out win predictions; the largest single-option effects were about 1.5 percentage
  points either way, within noise. Site: no win claims for runes, spells or autofill.
  Evidence: docs/model.md "Field ranking" (A1)
- 2026-10-13 (early): Games where more of the ten players have earlier games on their
  champion in our data gain more from knowing that history, then the gain levels off:
  none when no player has such history, about 2 milli-nats per game with one or two such
  players, about 4 with three or more, and nothing extra beyond five. Not causal:
  players with history are the more active, crawled ones, and this can't separate that;
  our crawl finds games through known players, so a random lobby has less history than
  our games. Sure: snap-20261012T2055Z (52,853 games, folds + dev-val pooled, one row
  per game); win-exp vs win-ratings, both deterministic, so no seed spread; far past the
  ~0.5 milli-nat noise floor; the same gradient with each time block weighted equally
  (4b). A snapshot two days longer (snap-20261013T1954Z, 89,519 games) gives the same
  buckets and more games with history, so the average gain rose from 2.5 to 4.0. Site:
  internal only; it's player data, check production-key.md before any public use.
  Evidence: f7's player-exp-cal and player-rat-cal preds (gpu-box
  ~/ml/runs/*-player-{exp,rat}-cal-*), ~/ml/analysis/histgain-4a.py; audited by
  meiolol-4b
- 2026-10-13: On games we held back, the ten champions alone pick the winner 53.2% of
  the time, and adding how much each player has played before the game (earlier games
  and wins on their champion, recent games, win rate, KDA, lane gold and deaths) lifts
  that to 54.5%; it ranks a winning team above a losing one 56% of the time instead of
  54%. Sure: 10,604 held-out EUW games, one look each, models picked on dev; the gain is
  just beyond noise. We hold only 16 days of history (74% of players have no earlier
  game on their champion in our data); the gain may grow as history builds up (not yet
  tested). A random split of the same games, as LoLDraftAI reports, flatters the
  champions-only model by about half a point (54.2% on dev). Site: nothing; research
  only, since other players' history isn't for the app. Evidence: docs/model.md
  "Player experience and everything pre-game" (test log loss 0.6906 and 0.6883, paired
  -0.0023 ± 0.0022)
- ~~2026-10-13 (early): Knowing how much each player has played before the game adds a
  little to the draft: with every player's earlier games and wins on their champion and
  their recent form (games, win rate, KDA, lane gold, deaths) on top of the ten
  champions, our model picks the winner 54.1% of the time instead of 53.7% and ranks a
  winning team above a losing one 56% of the time instead of 55%. Sure: dev games only,
  8,500 EUW games scored, 90k training games; the gain is at the edge of noise, and we
  hold only 16 days of history (74% of players have no earlier game on their champion
  in our data), so it should grow. Site: nothing; research only, since other players'
  history isn't for the app. Evidence: docs/model.md "Player experience and everything
  pre-game" (log loss 0.6878 vs 0.6897, -0.0019 ± 0.0018). Superseded the same day by
  the held-out result above~~
- 2026-10-14: We can't tell which champions reward experience more than others: how
  much a player's earlier games on a champion add to the win chance looked the same for
  every champion in a role. Sure: 10,604 held-out EUW games, one pre-declared look; not
  detected, and only a large difference would show: experience here is the earlier
  ranked games we stored (16 days; 76% of player-games have none), and a planted
  difference of about 10 percentage points from 0 to 10 earlier games, for a champion
  one typical step from its role, showed on the rounds of older games (about three
  times the test's size) but not on the smaller dev games. Site: no "champions that
  reward mastery" list. Evidence: docs/model.md "Carry and impact" (test -0.00001 ±
  0.00004 nats; audited by meiolol-33)
- ~~2026-10-13 (early): We can't yet tell which champions reward a practised player most:
  giving each champion its own gain from earlier games on it predicted worse than one
  gain per role, and every champion's estimate is uncertain by 7-10 percentage points.
  Sure: not detected, dev only; only 0.1% of players have 50+ earlier games on their
  champion in our data. Site: no "champions that reward mastery" list. Evidence:
  docs/model.md "Player experience and everything pre-game". Superseded 2026-10-14 by
  the held-out line above~~
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
  gold; confirmed with team gold, XP and objectives held fixed: splitting gold by role
  beat team gold on the test at 15 and 25, the bot-most ordering from the training fit
  (docs/model.md "Carry and impact", audited by meiolol-33)
- 2026-10-13: We found no champion that is better at coming back from behind, or at
  closing out a lead, than at an even game: 2,000 gold behind at 15, a champion makes
  the same difference as at even. A champion's value beyond the gold mostly stays the
  same from minute 10 to 30, with a small real scaling curve (bot laners matter more
  late). Sure: 118k games; not detected, and bounded: at 15:00 a typical champion's
  comeback differs from its role's average by at most 2-3.5 percentage points per
  1,000 gold (1.5-4.5 across roles and minutes 10-30), so at most ~4-7 points from
  2,000 behind; modelling it never improved held-out games. Site: no "comeback
  champion" labels; scaling only as the effect by minute with intervals. Evidence:
  docs/model.md "Champion given the state (scaling)"
- ~~2026-10-13: We found no champion that is better at coming back from behind, or at
  closing out a lead, than at an even game: 2,000 gold behind at 15, a champion makes
  the same difference as at even. A champion's value beyond the gold mostly stays the
  same from minute 10 to 30, with a small real scaling curve (bot laners matter more
  late). Sure: 118k games; not detected rather than ruled out: the estimate is zero in
  most roles and minutes, at most about 2 percentage points per 1,000 gold (jungle,
  10-20 min), and modelling it never improved held-out games. Site: no "comeback
  champion" labels; scaling only as the effect by minute with intervals. Evidence:
  docs/model.md "Champion given the state (scaling)"~~
- ~~2026-10-12 (early): Our best draft model picks the winner 53.3% of the time, still
  getting better with every doubling of games. Withdrawn 2026-10-13: 53.3 was the old
  eval's pick percentile (reported there as no signal), not an accuracy, and the curve
  is flat from 67k to 90k games~~
- 2026-10-13 (early): The ten champions alone predict the winner only slightly better
  than a coin: our best draft model ranks a winning team above a losing one 55% of the
  time (a coin 50%). It improved from 4.5k to 67k training games but not from 67k to
  90k, so whether more games keep helping is open. Counters and ally synergy added
  nothing measurable (superseded for counters and synergy by the 2026-10-14 (2253Z)
  matchup line); every region's games beat EUW's alone; weighting newer games
  didn't help. Sure: dev games only, 90k training games, games ending before 15:00
  still in. Site: nothing yet. Evidence: docs/model.md "Win from the draft" (AUC 0.550,
  log loss 0.6897 vs a coin's 0.6931)
- 2026-10-11: Knowing all ten champions does not yet predict the winner better than
  each champion's own win rate. Sure at 152k games. Site: no "this draft wins X%"
  claims. Evidence: meiolol eval, docs/model.md baselines (log loss 0.6905 vs 0.6902)

## Early game

- 2026-10-13: On the same champion and role, rune and spell choices go with different
  early games: First Strike players have about 120 more gold at 14, Inspiration with
  Domination about 150 more, Teleport with Ignite about 100 more gold and 2 more CS at
  10; autofilled players die about 0.2 more times before 15, and players who queue as
  Fill first end lane about 100 gold behind their opponent at 14. Sure: 10,604
  held-out games; runes, shards and spells each explain 0.2-1% of the spread in gold at
  14, CS at 10 and first item time, also on top of the best draft model; single-option
  numbers are shrunk estimates without their own intervals. Who-picks-what, not cause:
  players who take First Strike may play differently anyway. Site: no advice until
  docs/production-key.md is checked; lesson wording "players who take X tend to".
  Evidence: docs/model.md "Field ranking" (A1)
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
- 2026-10-13: Whether your champion in particular is good or bad against this enemy
  team doesn't show up beyond your lane. Sure: two different model types agree at 118k
  games; not detected, and bounded: a typical champion-against-enemy-champion pairing
  moves your gold at 14 by at most 35-45 gold, and against the enemy's classes by at
  most 50-85 (your lane opponent alone moves it 75-200). Site: no team counters or
  "best pick against this comp". Evidence: docs/model.md "Team effects", "Champion
  embeddings against the enemy team"
- ~~2026-10-12: Whether your champion in particular is good or bad against this enemy
  team doesn't show up beyond your lane. Sure: two different model types agree at 118k
  games; not detected rather than ruled out (the estimate is 0-21 gold at 14 and is
  switched off as noise in 3 of 5 roles). Site: no team counters or "best
  pick against this comp". Evidence: docs/model.md "Team effects", "Champion
  embeddings against the enemy team"~~
- ~~2026-10-12: Real interactions live in the lane: champion embeddings help only in
  matchups with few games. Superseded the same day by the lane opponent's general
  effect above, which explains most of it~~
- 2026-10-12: Most of what happens in your first 15 minutes comes from the game itself,
  not the draft: the draft explains only a few percent of the spread in gold, CS and
  deaths. Sure. Site: always show ranges, never a single predicted number

## Items

- 2026-10-13: Which item you finish adds almost nothing to predicting the win once you
  know when you bought it and how far ahead you were (a twentieth of what the champion
  adds). Sure: 118k games (2.9M first-three-item purchases); an item being better on one
  champion than on others in its role is not detected, and is at most about 3
  percentage points for a typical champion-item pair; no item-only model was fitted, so
  how much of "win rate by item" is the lead is not measured. Site: no "best build" or
  "this item wins more"; buying time and the lead at purchase are fair lessons.
  Evidence: docs/model.md "Items given the state at purchase"
- ~~2026-10-12: Which item you finish adds almost nothing to predicting the win once you
  know when you bought it and how far ahead you were (a twentieth of what the champion
  adds). Sure: 118k games (2.9M first-three-item purchases); the champion-specific item
  term is not detected; no item-only model was fitted, so how much of "win rate by item"
  is the lead is not measured. Site: no "best build"
  or "this item wins more"; buying time and the lead at purchase are fair lessons.
  Evidence: docs/model.md "Items given the state at purchase"~~

## Objectives

- 2026-10-12: Teams that take objectives win about as often as teams with this much
  more gold lead: a dragon about 1000, each soul point about 800 more, soul about 4000,
  elder about 4800, baron 400-1000, an inhibitor 900 at 20 minutes to 2300 at 30, a
  grub 100-150; towers are worth only their gold. No difference was detected by who is
  ahead. Sure as a description, not proof the objective caused the win. Site:
  post-game "teams that took this dragon won about as often as teams 1000 gold ahead"
  (Jacob to confirm). Evidence: docs/model.md "Objective value given the state"

## Playstyle

- 2026-10-13: Your champion decides most of how many skillshots you land, spells you
  cast and how much crowd control you deal (70-82% of the spread); your lane opponent
  decides about a third of how many skillshots you dodge, how often you survive three
  stuns in a fight and how many wards you clear before 20 minutes (likely because some
  champions' traps count as wards), and about a tenth of the magic and true damage you
  take. Sure: 10,604 held-out games, all clear. Site: a champ-select lesson can forecast
  these from the matchup ("against X expect to dodge more"); they don't measure skill.
  Evidence: docs/model.md "Field ranking" (A2)
- 2026-10-13: Beyond the gold, XP and objectives at 14:00, how you play adds almost
  nothing measurable: your early style moves your win chance by about 0.7 percentage
  points on average (under 1.6 for nine players in ten). There are no distinct
  "playstyle types" once champion and state are known, and a neural net reading play
  minute by minute found nothing more. Sure: 10,604 held-out games, one look; the style
  measures together are clear but tiny; types and the net: not detected (the net could
  not have seen effects quite this small). Single directions (say, farming rather than
  fighting) look clear in the training games but don't hold up on held-out games. Site:
  no "play aggressive to win", no "you are a type X player" and no per-style win
  claims; post-game may show your own style against your role's spread, as description
  only. Evidence: docs/model.md "Playstyle clusters and sequence net"
- ~~2026-10-13: Early aggression, roaming and time in the enemy half look like they win
  games, but almost all of that is just being ahead; once the gold and XP leads at
  14:00 are known, style adds very little. What survives is small: bot laners and mids
  who trade more damage win a bit more (about +2.4 and +1.7 percentage points per step),
  supports who roam and fight and laners who take spare camps a little more. Sure:
  118k games; each style number is within about 0.2-0.35 percentage points either way
  (counting a game's ten players together), and the ones above clear zero. Site: no
  "play aggressive to win"; post-game may show your own style against your role's
  spread. Evidence: docs/model.md "Playstyle given the state". Superseded 2026-10-13 by
  the line above (objectives in the state too)~~
- ~~2026-10-12: Early aggression, roaming and time in the enemy half look like they win
  games, but almost all of that is just being ahead; once the gold and XP leads at
  14:00 are known, style adds very little. What survives is small: bot laners and mids
  who trade more damage win a bit more (about +2.4 and +1.7 percentage points per step),
  supports who roam and fight and laners who take spare camps a little more. Sure:
  118k games for the overall result; the per-style numbers' intervals treat the ten
  players of a game as independent, so they are too narrow until refitted by game.
  Site: no "play aggressive to win"; post-game may show your own style against your
  role's spread. Evidence: docs/model.md "Playstyle given the state"~~

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
