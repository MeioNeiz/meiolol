# App: more options in champ select (APP15)

Jacob's notes 103, 106, 110, 116-120 (docs/review/app-review-2026-11-03.md). Policy:
docs/plan/app.md "Policy line"; findings that bound what we may claim: docs/learned.md.

## What Jacob sees

An Options panel under the board in champ select, its own island (ui-picks.wasm,
picks.bin; ui-app.wasm has no room), for the lane the panel shows (mine or a clicked
ally's while they pick; nothing once an ally locks).
- Private: every champion played in the role, ranked by the recommender (pool ones
  marked), 20 rows. Each row: icon, name, the champion's win rate in the role (110), team
  win chance % (116), lane gold vs the opponent, and its effects as champion icon +
  signed points (an ally pair, an enemy matchup, strong in the role) (106). Sort by team
  win, win rate or lane gold. A click opens the row: each effect in one line with its
  games, the most picked rune page and summoners, keystone and summoner icons from the
  client (120)
- Public: 5 more options from everyone who plays the role, past the 5 from your pool
  that the lane panel shows (3 to 5 per list, product rules); effects as champion icon
  with a good or bad colour, no numbers; win rate in the role (an aggregate fact, as the
  site); no team win chance
- Draft win chance in words in public ("about even", "leans your way", 2 SE) once the
  held-out look allows it (app.md table: words after data-and-model.md step 1); private
  keeps the %
- After all ten lock, in the comp view (APP16 owns compview.zig: coordinate): win rate
  by game length for each team (118) from the champions' length tallies, private as a
  chart in %, public as "your champions win more in long games"; main damage per team
  (117, below); runes and summoners on the loading cards later
- Region: EUW or all regions (103), a chip on the panel once the app has an all-regions
  stats file

## What the data allows (learned.md)

- Who carries (117): no champion turns its own lead into wins better than others in its
  role, so no "carry champion" label. What is true: whose gold matters most by role (bot
  ~8 points per 1000 gold, support ~0) and who deals the team's damage (CH10's tally).
  Shown as "most damage: Jinx" and the role lesson, not "Jinx carries"
- Objective value per comp (119): what a team gains at an objective barely depends on
  the draft (under 0.2 points): a dragon is worth about the same to both. Answer to
  Jacob in words; nothing per comp on screen
- Runes and summoners (120): what you set does not detectably change your chance on the
  same champion, so most picked only, no win rates

## Components

Reused: champ (icon), chip, badge, role, segmented (tabs, sort), fmt.wrColour, data.zig
encoding, island.zig. New: ui/picks.zig (Picks: list and open row) and an Effect chip
(icon + number), shared with APP14's chip-as-champion-and-number (101) if theirs lands
first.

## Data

- src/picks.zig: the role's players ranked by core.recommend with every reason (other
  champion, pp, games), champion win rate in the role, lane fact; built beside the lane
  card (poller, practice) into state.Select.picks
- Runes and summoners: new champ-facts.tsv kinds (`runes`, `spells`: champion, role,
  ids, share) from the builds tally; readers skip unknown kinds, no version bump
- Game length: champ-facts.tsv kind `length CHAMPION ROLE G W ...` from stats.zig's
  length buckets; a team's curve sums its champions' shrunk logit shifts per bucket
- Main damage: kind `dpm CHAMPION ROLE DPM` from the view's trend end sums (damage to
  champions a minute); the team's top and its share of the five's sum
- All regions: a second stats file in the desktop manifest; the poller loads both

## Slices

1. Picks island with many options, effects and win rates (106, 110, 116 private)
2. Public draft words (116) if the held-out look allows, else stays private
3. Runes and summoners in an open row (120)
4. Win rate by game length per team (118)
5. Main damage per team (117)
6. All regions (103): done. The box ships the all-regions 30-day view's stats as
   all-stats.bin; the Options panel's chip ("EUW | All regions", data-shell `regions`,
   state.all_regions) swaps champ select's stats (lane card, board, Options, comp);
   lane gold stays EUW's curves and says so. Loading, in game and post game stay EUW's
