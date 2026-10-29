# What we have learnt about the data

What the models and data checks have taught us, in plain words. The summary Jacob, the
admin page's Models tab and a new session read first; numbers and method live in
docs/model.md.

Headings are the admin page's model categories (Win, Early game, Items, Objectives,
Playstyle, Player, Data quality): put each line under its category, most useful first
(the admin overview shows a category's first two).

How to write a line:
- First sentence: the finding in plain English a ranked player would follow, with
  numbers in gold, CS, deaths, minutes or percentage points. No MSE, sd, nats, model
  names or column names in it (the admin page shows only this part on the overview)
- Then "Sure:" how confident and at what data size (name the snapshot); "Site:" what
  the site or app may say because of it; "Evidence:" the docs/model.md section name.
  Keep each entry to a few lines: the detail is in the section
- Add a line when a result is final (held-out games, interval reported); start
  dev-only results "(early)". docs/nn-results/*.tsv name lines by their start, so
  keep a line's start when editing it
- A newer result replaces the old line in place; the commit message says what changed.
  No struck-through lines, no dates in front
- "Sure:" names what was measured. A null result is "not detected", with the largest
  effect the data still allows; "under X" only when X is a measured upper bound
- Leaving games out (short games, regions, patches) needs a with/without comparison
  first; until then say which code leaves them out and that it is untested
- Platinum IV+ games unless stated (the crawl's floor)

## Win

- A counter is mostly about the two champions, not the roles they play: what one
  champion does to another in one role pairing (say Malphite top against Yasuo mid)
  carries over to their other meetings, and judging rare pairings by it, plus a little
  by kit class, predicts games better. Sure: beats additive v2 by 0.53 ± 0.14
  milli-nats a game on 195k dev games of 1007Z, and the frozen shipped form beats the
  previous site model by 0.99 ± 0.12 on 521k unseen games of 2004Z, every block better,
  controls clean. Site: live for the draft helper, Daily Draft, Learn, lane cards and
  suggestions; the desktop app still scores with counts until its stats file keeps the
  fitted model. Evidence: docs/model.md "Pair cells that borrow strength (A4)", "A4 on
  the new pin, shipped form"
- Before your lane opponent picks, ranking as if they were average is as good as any
  safer ranking we tried: favouring champions whose estimated matchups vary less is a
  hair better by one measure and a hair worse by another. Sure: 86k held-out games (29
  Oct snap), no enemy known: winners' picks rank a little higher (at most 7% of the
  ranking's link to winning; not seen on 57k dev games), winner-loser pairs are ordered
  slightly worse on both. The safer lists push popular champions down, so they partly
  measure popularity, not safety. Site: the app keeps its blind ranking; "safe blind"
  stays a label, not a different list. Evidence: docs/model.md "Blind pick ranking (J2)"
- (early) The draft alone has a little more to give than our best model takes: knowing
  exactly how every pair of champions does together and against each other would call
  about 56.5% of games right, against about 55.4% now. Most of what is left sits in
  pairings too thin to read one at a time (cross-role enemy pairs most, then lane
  matchups, then duos), so it needs models that share strength, or more games. Sure:
  754k held-out games of 2004Z, method checked on planted effects, every model lands
  on the same ceiling (4.8 ± 0.9 milli-nats above the set net). Site: nothing.
  Evidence: docs/model.md "Draft ceiling (B1) rerun on 2004Z"
- (early) More games still make every draft model better, and the deeper models gain
  the most: the last doubling (to about 1.2M games) added 0.4 points of accuracy to
  the pair model and 0.7 to the largest net, while champion strength alone has stopped
  improving; nets only help past about 300k games. Sure: dev only, five sizes, the
  same 754k held-out games; "the net becomes best with twice the games" is an
  extrapolation. Site: a reason to keep crawling. Evidence: docs/model.md "A1: scaling
  curves"
- (early) Within a patch, the newest games predict no better than the same number of
  games from up to two weeks earlier: what wins drafts barely moves day to day, so
  older games are worth keeping and more games is what helps. Sure: dev only, 297k fit
  games each way, 754k held-out, newest vs oldest within 0.1 milli-nats (± 0.15); one
  patch, not yet across a big one. Site: supports pooling old days in the tier list's
  estimates. Evidence: docs/model.md "E1: drift or noise at equal N"
- (early) Half of what the pair model gains over champion strength is each team's
  damage mix, and a small net on top adds a little more: 54.9% of games called right
  by the pair model, 55.1% with the damage mix, 55.3% with the net. Sure: dev only,
  754k held-out games, each step better in all six blocks. Site: the damage mix waits
  for per-champion damage profiles in the stats file. Evidence: docs/model.md "P2:
  same-split head-to-head"
- (early) Blending several draft models predicts a little better than the best one
  alone: a weighted mix beats the best single model (a set net on additive v2) by
  0.49 ± 0.09 milli-nats a game in every block; a plain average barely helps. Sure:
  320k dev games of 1320Z, weights fitted on older blocks. Site: nothing yet.
  Evidence: docs/model.md "Lab frontier wave 1"
- A matchup's win rate over the site's usual 30 days and ~80 games is about a third
  real and two thirds luck; it takes ~300 games to be half real and ~800 for two
  thirds. Duos are the same; a champion's own rate in a role is 0.77 real at 500-2,000
  games and 0.93 above. Sure: split halves of 800k games (1320Z) agree with the method
  of moments in every band. Site: matchup "vs usual" and sorting shrink by a k
  estimated this way and fade under 10 games. Evidence: docs/model.md "Lab frontier
  wave 1"
- Once the two champions' own win rates are allowed for, lane matchups still differ by
  about 2 points in top and mid, 1.2 in bot, 1.0 in support and 0.7 in jungle. Sure:
  method of moments on the live pages' tables (269k EUW games, 30 days). Site: the
  champion page's "vs usual" shrinks by usualK (about 750 games top and mid, the 2,500
  cap elsewhere); a 10% gap to a Python re-derivation is unexplained. Evidence:
  src/site/champion.zig usualK
- (early) What a comp and its champion pairs add beyond each champion's strength does
  not show in how the game stands at 10 to 20 minutes, only in who wins, so the in-game
  win chance can't stand in for the result when testing draft effects. Sure: 16 model
  pairs on 100,847 games of 2253Z; additive v2 over ratings -0.00175 ± 0.00035 nats on
  results, +0.00010 ± 0.00021 against the win chance at 15:00. Site: nothing.
  Evidence: docs/model.md "Scoring draft models against the in-game win chance"
- (early) A neural network now predicts the winner from the draft better than additive
  v2: it reads what each team's champions typically do (damage type, tankiness, crowd
  control, healing, range) on top of the pair model, accuracy 54.7% to 55.0%, and moves
  a typical draft by about 1 point. A large net reading only the picks is level with
  the pair model. Sure: dev only, -0.00078 ± 0.00012 nats a game over additive v2 on
  300,113 games of 1320Z, sealed seeds, 5 of 5 rounds, permuted profiles zero. Site:
  the admin Draft tester shows it beside additive v2. Evidence: docs/model.md "Nets on
  the shipped model, 2026-10-18"
- (early) Kit groups lean as their kits say, beyond the draft model: champions that
  punish basic attacks (Rammus, Jax, Teemo, Shen, Malphite) about 0.9 points better per
  step towards an auto-attack team; armour kits about 1.2-1.5 worse into magic damage;
  lethality assassins about 0.8 worse and true or %HP damage about 0.7 better into
  tanky teams. A member's lean is best guessed as its group's, its own games moving it
  from there (Rammus jungle into auto-attackers: +0.9, nothing of his own). What counts
  is the whole enemy team's damage share, not its single biggest threat. Sure: dev
  only, 13 groups declared before the run, 6 detected at 5% FDR on 1320Z; leaving each
  member out, its group predicted its lean on newer games (slope 0.86 ± 0.28); not yet
  a fresh test. Not detected: stealth into wards, poke into engage, hyper-scalers into
  early teams. Site: admin Draft tester only, "like other ..." reasons marked
  unconfirmed. Evidence: docs/model.md "Kit groups and a property scan", "Kit groups
  into champcomp"
- (early) Beyond the matchups and duos the site uses, about half the team-comp effects
  remain, all about magic damage and tankiness: Malphite (top, mid) about 1.1 points
  less per step towards a magic-damage team, Galio and Kassadin mid about 1 more;
  Lillia jungle, Brand and Senna support about 1 more into tanky teams, Nautilus 0.8
  less; AD carries (Yone, Yasuo, Qiyana, Zed, Viego) about 0.7-1 more with
  magic-damage allies. Dive and melee effects were matchups already counted. Sure: dev
  only, offset the shipped model, -0.00068 ± 0.00012 nats a game, 5 of 5 folds, 8 of 8
  replicated on newer games; a single champion's effect shows from about 3 points at
  10k games, 1 at 90k. Site: admin draft picker first, champion pages after a held-out
  look. Evidence: docs/model.md "Champions into comps", "Beyond the shipped model"
- Rammus jungle does not clearly do better into AD-heavy or melee-heavy teams: about
  0.5 points per step towards AD (-0.4 to +1.3 allowed) and 0.6 towards melee (2.4
  allowed); his real lean is into auto-attackers (above). Malphite, Wukong jungle, Jax
  top and Braum are clearly worse into AP teams (1-1.8 per step, Malphite mid and
  jungle 3-4). Sure: one pre-declared look on 125k fresh games for melee; 1320Z dev
  games for AD. Site: the tester's Malphite, Galio and Kassadin leans stay; nothing for
  Rammus. Evidence: docs/model.md "Armour tanks into AD"
- A whole draft rarely leans clearly to one side: none of 9 Daily Draft puzzles on
  16.20 is clear of even at 95%; a lean needs about 38/62 or wider. Sure: shipped
  model on 191k 16.20 games, SE of the draft's log-odds ~0.25 (score.draftSe). Site:
  Daily Draft says "on paper, close" unless the range excludes even
- (early) Most champions lean early or late, and it holds champion by champion:
  Draven's team is about 900 gold ahead at 14 but from an even game at 20 wins about 8
  points less; Kayle top's team is about 800 behind and wins about 14 more from even.
  About a third of champion-roles with 200+ games are clearly one or the other; the two
  parts mostly cancel in their win rates. Sure: dev only, 236k games of 2253Z,
  predicted newer games better in every fold (calibration 1.02 ± 0.03). Site: one line
  per role on champion pages, numbers only where clear, never a pick reason. Evidence:
  docs/model.md "Early and late champions"
- (early) During a game, who wins is read much better from every player's gold, XP,
  items and death timers plus the champions than from team gold and objectives: at 15
  minutes 85% against 83% of winners ranked above losers, honest to about 1 point
  through 30 minutes. A champion is worth most between 10 and 20 minutes and little
  after 35. Sure: 2253Z, 100,848 games with a timeline, every fold better. Site: Your
  games' win chance by minute (post-game only), never in champ select. Evidence:
  docs/model.md "Rich state and champions (richc)"
- Champion pairs help a tiny bit once each champion is described by how it usually
  plays rather than by name: about half of what the damage mix adds, and nothing with
  shuffled descriptions. Sure: rule declared before the runs, passed at its margin;
  2253Z, 134,375 games, 5 of 5 folds; -0.00026 ± 0.00014 nats vs win-comp. Site:
  nothing; too small to claim or to name pairs. Evidence: docs/model.md "Interactions
  on pretrained embeddings"
- (early) The champions tell you far more about who wins once you know how the game
  stands: with gold, kills and objectives at 15 minutes known, the draft adds four to
  five times as much as in champ select. A draft one sd stronger wins about 4.6 points
  more often, and none of that was found to come through an early lead (only more than
  2.3 points is ruled out). Sure: dev only, 2253Z, 100,847 games, readings declared
  before any run; the state also carries who plays better, so description, not cause.
  Site: no "this draft wins late" claims. Evidence: docs/model.md "How drafts win"
- How players did in their earlier games (gold, CS and damage per minute, off-role
  games, days since last game) predicts the winner beyond how much they have played:
  56.1% of winners against 55.6% without, and 53.7% from the champions alone. The gain
  doubles when all ten have earlier games and levels off past five; queuing together
  before adds nothing detected. Sure: 2253Z, 134,375 games, sealed pre-declared check;
  "earlier games" means games our crawl holds. Site: nothing; other players' history
  is never for the app. Evidence: docs/model.md "Prior and premade, sealed
  confirmation", "History means as hand-made terms"
- Who faces whom, and who plays beside whom, matters a little beyond each champion's
  strength. Lane matchups most: top 2.2-2.5 points between typical matchups, mid
  1.7-2.1, support 1.2-1.5, bot 1.1-1.3, jungle 1.0-1.4; mid vs enemy bot and bot vs
  enemy support 0.8-1.1. Among allies only bot and support show (1.3-1.6). A champion's
  own strength spreads 1.6-3.4 points by role. Sure: pre-declared, 134,375 held-out
  games of 2253Z, 1.24 ± 0.26 milli-nats over win-comp, 5 of 5 rounds; ranges run from
  the model's estimate to a simulation-calibrated one; single pairs not reported.
  Site: matchup and bot-lane synergy reasons on the draft board; no numbers for single
  pairs. Evidence: docs/model.md "Additive model v2: identified matchups"
- Beyond which champions are picked, a comp's damage makes a small difference, about
  1-2 points for a comp clearly off: damage far from half magic loses, magic-heavy
  teams (60%+) about 2 points more, and physical damage into an armour-leaning team does
  worse. Tankier teams did a little better into penetration items (+0.6 points per sd,
  against theory). No coaching win condition (dive vs peel, engage vs disengage,
  front-to-back, healing vs anti-heal, split vs waveclear) or archetype was found among
  244 traits. Sure: 89,584 sealed games of 2253Z, 32 pre-declared with Holm;
  associations beside champion strength, not a measurable prediction gain. Site: the
  damage-mix reason; "physical damage into armour" may become a reason without a
  number; Learn's myth card (damage mix showed, no win condition or archetype did).
  Evidence: docs/model.md "Comp discovery"
- A team that deals under a fifth of its damage as magic wins about 5 points less often
  than its champions suggest, and lopsided teams (that, or over 60% magic) about 3 less
  than balanced ones; tankiness and crowd control make a point at most. Sure: 44,353
  dev games in five blocks (-3.0 ± 1.1, every block), one pre-declared test look on
  10,604 EUW games (-2.7 ± 2.2). Site: as a reason without a number ("mixed damage
  tends to do better", never "+X% win rate"); no frontline or CC warnings. Evidence:
  docs/model.md "Comp features from champion profiles"
- Knowing that a team's damage is lopsided makes win predictions only a little better
  overall, because only about one team in ten is lopsided. Sure: 10,604 EUW test games,
  +0.00002 ± 0.00048 nats; a gain over a fifth of the champions' own is ruled out.
  Site: the admin Draft tester may show the term. Evidence: docs/model.md "Model:
  win-comp ablation"
- No champion was found to turn its own gold lead into wins better than others in its
  role: 1,000 gold on your champion at 15 minutes is worth about 8 points for the bot
  laner, 4.5-7 for top, jungle and mid and about 0 for support. Sure: 10,604 held-out
  EUW games, pre-declared; not detected, spreads up to 3-11 points allowed. Site: no
  "carry champion" labels; lessons by role. Evidence: docs/model.md "Carry and impact"
- (early) A small neural network that reads what each team's champions typically do
  finds mostly the damage-mix effect again (up to two-thirds of the hand-made term), and
  nothing confirmed on top of it. Sure: dev only, 44,353 games, -0.00037 ± 0.00021 nats.
  Site: nothing. Evidence: docs/model.md "Set net: DeepSets on champion profiles"
- (early) Knowing how each champion plays in its role (gold, CS, deaths, damage, early
  lead) does not measurably improve win predictions beyond its own win record. Sure:
  not detected, dev only, 44,353 games, at most 0.0007 nats a game. Site: nothing.
  Evidence: docs/model.md "Pretrained champion-role embeddings"
- What you set in champ select for yourself (summoner spells, runes, shards, being
  autofilled, account level) does not detectably change your chance of winning on the
  same champion and role. Sure: 10,604 held-out games; the largest single options about
  1.5 points either way, within noise. Site: no win claims for runes, spells or
  autofill. Evidence: docs/model.md "Field ranking" (A1)
- Once you know each team's gold at 14:00 and the game length, Riot's early-game stats
  (first tower, early takedowns, laning-phase lead) barely help tell the winner: the
  best adds under half a percent. Sure: 10,604 held-out EUW games. Site: no "take first
  tower to win"; post-game may show them as what happened. Evidence: docs/model.md
  "Field ranking" (B)
- The same gold lead is worth more or less depending on the champions: at 25 minutes a
  team with Kayle top wins as often as an average team about 2,900 gold further ahead,
  one with Pyke support as one about 2,600 further behind, in every role and with the
  same objectives. Sure: 118k games, better on held-out games at every minute 10-30;
  common picks to ±1-3 points. Site: lessons ("on Kayle, 1,500 behind at 15 is par"),
  never a pick reason. Evidence: docs/model.md "Champion given the state (scaling)"
- Gold on your support barely moves your team's chances: 1,000 gold more is worth 1-3
  points on the support, 6-12 on the bot laner, 4-11 on jungle and mid, 4-8 on top.
  Sure: 118k games, held-out at every minute 10-30; confirmed with team gold, XP and
  objectives held. Site: lessons ("your bot laner's gold lead matters most").
  Evidence: docs/model.md "Champion given the state (scaling)", "Carry and impact"
- No champion is better at coming back from behind, or closing out a lead, than at an
  even game. Sure: 118k games; not detected, at most 2-3.5 points per 1,000 gold at
  15:00. Site: no "comeback champion" labels. Evidence: docs/model.md "Champion given
  the state (scaling)"

## Early game

- (early) Being ahead of your lane opponent goes with winning your own game, but a
  matchup where one side is usually ahead is not a matchup that side usually wins: in a
  game, the player 1,000-1,700 gold ahead at 14 wins 37-51 points more often (0 deaths
  before 15: 65-71% won, 4+: 31-39%), while a matchup's average lead moves its win rate
  by -2.6 to +2.3 points per 1,000 gold. Sure: raw associations on 877,814 games of
  1007Z, matchups with 300+ games, noise taken out. Site: colour a game's own leads
  (Your games), not a matchup's average lead. Evidence: docs/design-ideas.md "What to
  colour"
- Your lane opponent's champion changes your early game the same way whoever you play,
  on top of the specific matchup; adding that improves every early-game prediction.
  Sure: 118k games. Site: lane curves use the opponent's general effect plus the
  matchup, which also fixes thin matchups. Evidence: docs/model.md "3c-team2"
- Every champion in the game nudges your early numbers, and the nudges add up: your own
  champion moves your gold at 14 by a typical 270-360, your lane opponent 75-200, a
  jungler 20-65 and each other enemy 15-50. Sure: 118k games. Site: "what your matchup
  and this enemy team typically do to your early game", with ranges. Evidence:
  docs/model.md "Team effects on early outcomes"
- Whether your champion in particular is good against this enemy team doesn't show
  beyond your lane. Sure: two model types at 118k games; not detected, at most 35-45
  gold at 14 per pairing. Site: no team counters or "best pick against this comp".
  Evidence: docs/model.md "Team effects", "Champion embeddings against the enemy team"
- Most of your first 15 minutes comes from the game itself: the draft explains only a
  few percent of the spread in gold, CS and deaths. Site: always ranges, never a single
  predicted number
- On the same champion and role, runes and spells go with different early games: First
  Strike about 120 more gold at 14, Teleport with Ignite about 100 more gold and 2 more
  CS at 10; autofilled players die about 0.2 more before 15. Sure: 10,604 held-out
  games; who picks what, not cause. Site: "players who take X tend to". Evidence:
  docs/model.md "Field ranking" (A1)
- A higher rank means more gold at 14 in the same matchup: Emerald to Master is about
  200 gold for a jungler, 145 mid and bot, 90 top, 20 support. Sure: 106k held-out
  games, but with the after-game rank (see Data quality); recheck with the rank at game
  start. Site: lesson material, never a pick reason. Evidence: lab campaign gold14-a
- Carries played off-role earn their usual gold at 14: Draven top (+840 over the
  average top laner) matches Draven bot. Sure: 80k dev rows. Site: the Draft tester
  keeps champions with 1%+ of the role's games
- (early) For your gold at 14 it is who the enemy laner is that counts, not how your
  champion matches theirs. Sure: dev only, 80k rows. Site: nothing yet

## Items

- What players build changes with rank: Master+ players' shares of each slot's options
  differ from the rest of Platinum+ by 8-17 points (root of summed squares; rune pages
  most, the top page 12 points less used) against 2-4.5 points of chance, but the most
  played option is the same in 78-96% of champion roles. A thin slice is mostly a few
  players: a player's games on a champion-role, weighted by games, average 4.5 at
  Master+ (3.1 at Platinum+). Sure: 16.21, every region, method of moments; chance
  doubles at most for one-tricks, still well short. Site: the rank filter applies to
  builds, a rank under 400 games falling back to the next wider one. Evidence:
  data/team/2026-10-25-ui-build/notes/data.md "G4"
- (early) Within one champion and role, options differ in win rate far less than raw
  rates suggest: about 0.6 points between runes in a row and stat shards, 0.7 for
  spells, 0.8 starting items, 1.0 skill order, 1.4 rune pages, 1.5-2 boots and first
  items. A rune's own games count for little until it has thousands (k about 6,000; 600
  to 1,000 for items). Sure: method of moments over 858 champion roles (274k EUW games,
  16.20); not causal. Site: "highest win rate" pulled toward the average by k, 100+
  games only, never "best". Evidence: src/builds.zig Spread
- Which item you finish adds almost nothing to predicting the win once you know when
  you bought it and how far ahead you were. Sure: 118k games, 2.9M purchases; an item
  better on one champion than others not detected (at most about 3 points). Site: no
  "best build" or "this item wins more". Evidence: docs/model.md "Items given the state
  at purchase"

## Objectives

- What a team gains at an objective barely depends on the draft (under 0.2 points).
  Given gold and objectives so far, a dragon adds about 4-4.5 points of win chance
  (5-5.5 after 30), baron 5.6-7.9, elder 9, an outer tower 1.5-3.2, a kill 2.5-3.8. A
  stolen dragon or herald is followed by the stealing team winning 8-10 points less
  than expected. Sure: 236,227 dev games of 2253Z, cross-fitted, description not cause.
  Site: post-game only, once the production key allows anything public ("teams that
  took this won about X points more often"). Evidence: docs/model.md "In-game events on
  the draft-aware state"
- Teams that take objectives win about as often as teams with this much more gold: a
  dragon about 1000, soul about 4000, elder about 4800, baron 400-1000, an inhibitor
  900-2300; towers only their gold. Sure as description. Site: post-game wording, to
  confirm with Jacob. Evidence: docs/model.md "Objective value given the state"

## Playstyle

- Your champion decides most of how many skillshots you land, spells you cast and how
  much crowd control you deal (70-82%); your lane opponent about a third of how many
  skillshots you dodge and wards you clear. Sure: 10,604 held-out games. Site: a lesson
  may forecast these from the matchup; they don't measure skill. Evidence:
  docs/model.md "Field ranking" (A2)
- Beyond the gold, XP and objectives at 14:00, how you play adds almost nothing: about
  0.7 points of win chance on average, and no distinct playstyle types. Sure: 10,604
  held-out games; types and a sequence net not detected. Site: no "play aggressive to
  win" or "you are a type X player"; post-game may show your style against your role's
  spread. Evidence: docs/model.md "Playstyle clusters and sequence net"

## Player

- Every champion is harder when you're new to it, some much more: under 10k mastery
  points win 47.7%, 300k+ 51.7%. New Rengar players win 39% against 51% practised, Yuumi
  43% against 51%; new Leona, Milio, Braum and Caitlyn players do about as well as
  practised ones. Sure: 1.92M player-games with mastery from before the game; single
  champions are rough (split-half r 0.33), so only the clearest 10 harder and 18 easier
  get a label. Site: "harder or easier to pick up" with both win rates and games, never
  a gain. Evidence: src/learning.zig
- Ranking your own champions by your mastery as well as the draft helps: a player wins
  about 3.7 points more from 10k to 300k points on a champion, even against their own
  other champions; the lane card then shows the champion actually picked 47% of the
  time instead of 39%. Sure: 944k held-out player-games, -0.00052 ± 0.00007 nats.
  Site: the app ranks the pool with it and says only "150k mastery points". Evidence:
  docs/model.md "Pool and expertise replay"
- (early) Part of a champion's win rate is how practised its players are: a new
  champion looks up to 1.6 points weaker (Locke, Corki top) and one-trick favourites up
  to 1 stronger (Katarina mid, Shaco jungle). The lane card's mastery bonus counts this
  twice: it should compare against that champion's usual mastery. Sure: 1.37M games,
  held-out gain 0.30 ± 0.13 milli-nats. Site: nothing until the lane card fix is
  measured on the replay. Evidence: docs/model.md "Strength at fixed mastery (D1)"
- How widely players' win rates on a champion spread (46% to 64% for the middle half
  with 10+ games) is almost all luck: no real difference between players beyond it was
  detected, at most a 3-point sd. Sure: 6,952 player-champion pairs, EUW. Site:
  champion pages show the spread with a luck note. Evidence: src/spread.zig

## Data quality

- The rank we store with each game is looked up after it, so it knows the result: with
  it a model calls 63.8% of winners instead of 53.7%. Models: use the rank at game
  start (rank history, from 12 Oct), never the stored rank, as a pre-game input
- In a new patch's first days, last month's numbers predict the next week better than
  the new patch's own games: win rates and items catch up after 2-3 days, matchups,
  duos and lane gold still trail after a week. Sure: two patch boundaries replayed day
  by day. Site: keep 30 days as the default; an estimate must beat it. Evidence:
  docs/plan/estimates.md "E2 baseline"
- A new patch moves champions' win rates beyond noise, mostly the changed ones: 0.75 pp
  RMS on 16.21's first day, 1.9 pp for the 12 changed champions; last patch's numbers
  unchanged cost about 1 milli-nat a game on day one. Sure: 52k games, day one only.
  Evidence: docs/model.md "Patch 16.21's first day"
- On a patch's first day most players have not played it: 75-89% of players checked
  had no game on it; players just seen in a new game give 3.1-3.5 new games per call.
  Crawler: snowball and patch-start reset. Evidence:
  research/sources/patch-day-discovery-measured.md
- In the newest snapshot (2004Z) every game has end-of-game stats, but all ten
  players' mastery from before the game in only 1 game in 15 (1 in 3 of the newest
  days), and all ten ranks at game start in about half the games since 13 Oct; every
  16.21 game is in the test days. Models: seat-level mastery is usable. Evidence:
  docs/model.md "The new pin, snap-20261023T2004Z"
- Most lane matchups in a patch have a handful of games: of 166.5k matchup curves on
  EUW 16.20, 58% had under 5 games, only 9% 50+. Site: `meiolol curves` writes
  matchups from 10 games (docs/arch-stats.md "Lane curves")
- Leaving out games that end before 15:00 without a remake flag (about 1.5%, mostly
  surrenders after a leaver) makes no detectable difference to draft predictions.
  Sure: 8,608 dev games, +0.00003 ± 0.00025 nats. Models: the lab harness and draft
  export fit on games past 15:00; the site's stats and meiolol eval keep them
- Riot's "dragon soul given" event with team 0 only announces the coming soul; only
  team 100 or 200 means a soul was taken. Models read soul from those (src/objectives.zig)
- Nearly everyone finishes an item (98.7%+ in games past 15:00, every role), so
  first-item time works for every role
