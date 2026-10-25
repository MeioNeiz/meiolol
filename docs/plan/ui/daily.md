# Daily Draft

Identity: one real ranked game a day with one champion hidden; guess it and the winner,
then see the whole game laid open on one board. Plan 24 Oct 2026, team run
2026-10-24-ui (session play). Mock: data/team/2026-10-24-ui/mocks/daily.html.

## Who comes and why

- Daily players: a two-minute puzzle, a streak, a share card (once public)
- Learners: after the guess, why the model would have picked something else, seat by seat
- Riot's reviewer: the clearest "options with reasons" page the site has

## What Jacob said (24 Oct)

- "only do games where we have all ranks, ban icons too hard to read, too grey. Again I
  think this UI is lazy, bad use of space like with the 9 champions and the missing one"
- "the sub header text is too long, it kinda explains itself, prob just not needed"
- "cus we cant know what was the last pick we need to give more info perhaps idk, is
  there another game mode where we actually can know the pick order from the api? ...
  Too many sentences explaining itself, in 99% of cases the ui shoud be intuive enough"
- "The game stats should be reusing elements from the other game stat stuff"
- "I really like on on paper stuff but still could be more thoughtfull it its design, use
  space better. Needs much more explanation of why different things could have been
  picked, like maybe each champ suggested can be selected to see details of why"
- "the every pick rated is awesome but again, the ui is too simple, almost limiting, too
  generic"; "game stats so unimaginitve, too generic, basic table"
- "love the lane comparison but agian this ui just doesnt match the data its trying to
  show"; "the how these facts are read is ridiculous, no one is reading all that"

## The idea: one board that grows

Today the page stacks seven blocks (rosters, question, options, result, tiles, on paper,
picks, every pick rated, scoreboard, lanes, method, archive): 3,770 px at 1280. The
same ten seats are drawn four times (rosters, every pick rated, scoreboard, lanes).

New: one `DraftBoard`, the ten seats as five lane rows (blue left, role in the middle,
red right), drawn once. It is the puzzle before the guess and the whole game after it:
each seat grows its stats (K/D/A, CS, gold, damage), its rating (rank among the role's
picks), and the lane row's middle grows the lane duel (gold at 14 against the usual for
that matchup). Every seat is selectable; the side panel shows that seat's candidates
and why. "Every pick rated", the scoreboard and the lanes stop being separate tables.

## First screen (before the guess)

1280 (all of it above 800 px):

```
Daily Draft #14   24 Oct · EUW · Platinum II · 16.21          [■■■■□■■■■■□■■■] streak 3
┌──────────────────────────── board ─────────────────────────┐ ┌─ Who played red bot? ─┐
│ [Malphite]      ⌂top     [Garen]                            │ │ [Yone ] [Vayne ]       │
│ [Lee Sin ]      ⌂jg      [Wukong]                           │ │ [Twitch] [Sivir ]      │
│ [Katarina]      ⌂mid     [A. Sol]                           │ │                        │
│ [Caitlyn ]      ⌂bot     [  ?   ]  ← dashed, pulsing ring   │ │                        │
│ [Lux     ]      ⌂sup     [Lulu  ]                           │ └────────────────────────┘
│ bans ▣▣▣▣▣                ▣▣▣▣                              │
└─────────────────────────────────────────────────────────────┘
```

- Header row: title, number, meta as one line of chips (date, region, the game's median
  rank, patch); the ResultStrip, days variant (last 14 days as squares, result-coloured, tap one opens
  that day) and the streak count right. No sub header sentence
- Board 760 px wide, options column 440 px beside it. Rank under each name (11 px,
  "Plat III"): every seat has one, since only fully ranked games are used
- Bans: full colour ChampIcon s (24 px) per side under that side's column, with a thin
  slash; no greyscale (the "too grey" complaint). Tap: champion name toggletip
- Hidden seat: ChampIcon empty state (dashed ring, "?"), the row's role highlighted
- Options: ChoiceCards, 2x2, 72 px tall, icon 48 and name. Tap commits. Then the same
  question area asks "Who won?" with two side buttons (blue, red) as ChoiceCards
- 390: header (2 lines), board (5 rows x 52 px, icons 32, names under 12 px rank),
  options 2x2 under the board: the question at ~430 px, options fully visible at 844

Words on the first screen (champion names not counted, they are labels):
"Daily Draft", "24 Oct", "EUW", "Platinum II", "16.21", "streak", "Who played red bot?"
= 12 words. Today: 66 words before the options (sub header 19, last pick note 25).

## After both guesses

The question column turns into the result and the review; the board grows in place.

1280:

```
Daily Draft #14  ...                                                 [ResultStrip] streak 3
┌ result: Pick ✗  Winner ✓   ·  Red won in 26 min · 22–33 kills · 48.9k–57.9k gold ┐
┌──────────────────────── board (grown) ──────────────────────────┐ ┌ selected seat ───┐
│ Malphite 2/6/2 180cs 8.4k ▂  3rd │ top  ●──|── +40   │ 12th Garen │ │ Red bot: Twitch   │
│ Lee Sin  ...              63rd   │ jg   |────● +1.4k │ 1st★ Wukong│ │ 10th of 40        │
│ ...                              │ bot  |──────● +2.7k (usual +300)│ │ RankStrip ·••|•●• │
│                                                                  │ │ CandidateList:    │
│                                                                  │ │ 1 Xerath  +1.0 ▸  │
│ bans ...                                                         │ │ ... Twitch played │
└──────────────────────────────────────────────────────────────────┘ │ ReasonBreakdown   │
┌ On paper ── WinSplit: Blue 41.6% ━━━━━━━━|━━━━━━ 58.4% Red ── Red won ─────────────┐
│ edge by kind: Champions Red +7.0 · Lanes Blue +1.0 · Pairs Red +0.7 · Other Red +1.8 │
└──────────────────────────────────────────────────────────────────────────────────────┘
```

- Result strip: the two marks as Badges (Pick ✗, Winner ✓), then the game line as a
  StatStrip (winner, minutes, kills, gold; later towers and dragons). Replaces "Not this
  time", the 3 tiles and the separate score card; the streak lives in the header
- Board, grown: per seat Kda, CS, gold (StatCell count), damage as a neutral Bar; the
  seat's rating as "3rd" with a star when it is the model's pick; the hidden seat
  outlined. This is the Scoreboard in its versus variant (games session's component:
  same cells, same order, mirrored). Phone: each lane row is two lines (blue seat,
  red seat) with the duel bar between
- Lane duel, the board's middle column: `Versus` in its inline single-measure
  form: a diverging axis around 0 gold at 14, a tick for the matchup's usual lead with
  its range band, a dot for this game, the dot's label ("+2.7k"). Blue side's lead
  goes left, red's right, so the axis reads like the board. Tap: toggletip with games
  and "favoured: Twitch 52.2%". Replaces the pill pairs ("Blue +2,742 at 14", "usually
  blue +300", "Twitch favoured 52.2%", "317 games") that Jacob said don't match the data
- Selected seat panel (the "why" Jacob asked for): opens on the hidden seat; tap any
  other seat to switch. Shows:
  - the seat's `RankStrip`: every champion with enough games in that role as a dot by
    team win chance, the played one ringed, the model's pick starred, "10th of 40"
  - `CandidateList`: the model's top 5 for the seat plus the played one at its rank;
    each row ChampIcon, name, team win chance Bar with range whisker, "+1.0 vs
    played", up to three reason Chips
  - tap a row: `ReasonBreakdown` under it: from the role's average to this pick, one
    waterfall step per term ("strength as a bot", "into Caitlyn", "with Lulu",
    "rest") with points and games, the total with its 95% range. Two rows open at once
    compare (played vs model's pick)
  - "Show the board as if": tap "Pick" on a candidate swaps it into the board and the
    WinSplit moves (client side, the puzzle JSON carries the terms); "Reset" undoes.
    Later, needs the per-seat terms in the JSON (Data needed)
- On paper (under the board, beside the seat panel): `WinSplit`, the bar with blue and red shares,
  the 95% range as a whisker around the split, the result as a flag on the winner's end;
  then the edge by kind as one row of four diverging mini bars (DivergingBars variant of
  Bar). Words: "On paper", the four kind labels, numbers
- No method block. Toggletips on: "the model's pick" (which model, ModelBadge), the
  range, "rank" ("among champions with 100+ games in the role on this patch"), lane
  usual. The ones today's "How these facts are read" explains, a line each
- 390: result strip, board grown (two-line lanes), selected seat panel as a sheet that
  opens on seat tap (hidden seat open by default under the board), On paper last

Words after the reveal (visible, not counting names and numbers): result 4, StatStrip
labels 4, panel head 4 ("Red bot", "10th of 40"), candidate reason chips ~3 each (15),
On paper 2 + kinds 8 = ~37. Today after the reveal: ~420 words.

## The last pick problem

Research's answer (data/team/2026-10-24-ui/refs/pick-order.md, 24 Oct): no match-v5
queue records pick order. Ranked solo, flex and normal draft list players by role and
ban pickTurn is the slot; swiftplay, blind and ARAM have no order to record; tournament
lobby events stop at champ select start. Fixed by rule in every draft: blue picks first,
red picks last (1-2-2-2-2-1), so the last pick is always one of red's five, but which
one is unknown, and swaps reorder players. Only LCU (our app, the user's own games) and
pro games (Leaguepedia) carry the real order. One lead: spectator-v5 lists live
players in a per-game order that may be the champ select cells; untested (a few hours
of light calls, best with the production key).

Question for Jacob, four options (research recommends none outright; mine: 4 now, 1 if
the spectator test passes):

| Option | What the board changes | Cost |
| --- | --- | --- |
| 1. Spectator order (if the test passes): poll live ranked games, keep the seat order | Seats show a 1-10 pick number; the hidden seat is red's real last pick; "last pick" wording stays | Small poller on the box, rate limit shared with the crawler (easy with the production key); swaps make it "as seated", mostly the pick order |
| 2. App users' games (LCU, with consent) | As 1, exact order | Few games until the app has users |
| 3. Pro games (Leaguepedia) | As 1, plus team names; game stats only from Leaguepedia's scoreboards (no timeline: no lane duel, Scoreboard versus cells reduced) | Different population, names not match ids, CC BY-SA licence to check |
| 4. Ranked as now, no order | No pick numbers; the question is "Who played red bot?" (any of red's five can be hidden); "last pick" appears nowhere, the rank toggletip says "with the other nine fixed" | None |

The board is built for both: option 4 is today's board; options 1-3 add a pick number
(11 px, top-left of each seat) and keep the hidden seat on red's last pick. Nothing
else moves, so the choice can change later without a redesign.

Jacob's "give more info", for option 4: hints, one tap each, costing the "spot on"
mark: (1) the player's rank and their role's most played champions at that rank
(exists: role shares), (2) "this player has N games on one of these" (needs pre-game
mastery per seat: mastery_pre.tsv has it for crawled players; new, small), (3) lane
outcome: who was ahead at 14 (exists, gold14). The hidden seat is chosen as today
(hidden_by "fit": a seat whose options are clear).

## Components used (register names)

New (requests in components.md): DraftBoard, ChoiceCards, CandidateList,
ReasonBreakdown, WinSplit, RankStrip (Chart preset), ResultStrip (days), ModelBadge (Badge variant).
RankStrip dots other than the top 5 and the played one are illustrative in the mock
until the per-seat export exists. Existing: ChampIcon (empty, banned), Badge, Chip, StatCell, Bar, Kda, StatStrip, Scoreboard
(versus variant), Versus (inline single-measure), Toggletip, Card, SectionHead.

## Interactions

- Tap an option: commits (no confirm), all four flip to their facts in place (pick share
  Bar, fact StatCell), the winner question takes the same box. Keyboard 1-4 and Enter
- Tap a seat (after the reveal): selected ring, panel switches; arrow keys move seats
- Tap a candidate row: ReasonBreakdown opens under it (two at most)
- Candidate "Pick" (later): try it in the board; WinSplit and the seat's rank update
- ResultStrip square: opens that day's puzzle (the archive; replaces 14 "not played" rows)
- Share (once public): the board as emoji rows plus marks

## Data needed

- Fully ranked games only: exists (#14 itself has 3 of 10 ranks; the mock fills the
  other seven as illustration). Every participant row carries the stored tier;
  in the last 3 days 56,035 of 83,645 EUW ranked solo games (67%) have all ten.
  daily.zig's candidate query adds the filter; old puzzles keep theirs. Small
- Per seat: today `review.seats` has rank, of, win, top, top_win, range; `review.picks`
  (top 5 with reasons) only for the hidden seat. New: top 5 with reasons for every seat
  (the same `core.recommend` call per seat, already run for the rank) and each seat's
  candidates' win values for the RankStrip (~40-80 numbers a seat). JSON grows from
  ~9 KB to ~40 KB per puzzle. Small, daily.zig
- ReasonBreakdown terms per candidate: picks[].reasons has kind, id, role, pp, games
  (base, enemy, ally). Enough for the breakdown; the "rest" (unnamed pairs summed) needs
  a field. Small
- Lane duel: exists (lanes[].gold: game gold14 diff, usual gold and games, pp)
- Result strip towers and dragons: not stored in the puzzle; from the timeline (games
  session's finding: objective totals per team from compact timeline events). Medium,
  shared with Your games
- Try-a-pick in the board: needs the model's pair terms for the game's champions in the
  JSON (10 seats x their candidates' pairs: too big naively; ship only the top 5 per
  seat's terms with the nine others). Later, medium
- Hint 2 (mastery on the hidden seat's options): mastery_pre for the hidden player.
  New, small where it exists, and the hint hides itself where it does not

## What is cut

- The sub header and the "Treat it as the last pick..." line
- The two roster cards with coloured top borders; the three tiles; the separate score
  card (folded into the result strip and header)
- "Every pick, rated" as its own two-table block, the scoreboard tables and the lanes
  table: all now the board
- "How these facts are read"; the bottom note "Each pick as if it were the last..."
- Archive list of 14 rows (ResultStrip days)
- Win chance percentages on the option cards before the reveal (they never showed; keep)

## What the desktop could reuse

DraftBoard is the champ select board (the app's suggest screen: five lane rows, the
player's seat open); CandidateList and ReasonBreakdown are its suggestion list and "why"
(public app in tiers mode: "strong fit / also fine / weaker here" with worded reasons,
no points, production-key.md product rules); WinSplit stays private (the private app).
ChoiceCards and ResultStrip: not on desktop.

## Questions for Jacob (24 Oct)

1. Pick order (The last pick problem): option 4 now and run the spectator test for 1,
   or another? With 4, "Who played red bot?" as the question
2. Hints that cost the "spot on" mark: wanted, or keep the puzzle pure?
3. "Try this pick in the board" (moves the on-paper bar): worth the bigger puzzle file?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Pick order wanted, and the hidden seat is always the last pick. Pro games
   (Leaguepedia, option 3) now; app users' games (LCU, option 2) once there are enough.
   The first-screen matchup board is still space-inefficient and "doesnt look cool
   enough": redesign in the visual pass
2. Hints that cost the "spot on" mark: yes
3. "Try this pick in the board": yes, later (medium)

## Jacob's answers (review v6, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v2-*.

1. Seats: team and role only, no player or team names; if teams are shown the puzzle
   must be harder (people will know). A pro game "every now and again", not the default
2. Loading-art seats and the all-in-a-row lineup: no. Stay in the site's style (square
   icons); matchups and comps must read (teams facing); v6 "really empty now"; white
   champion names vs a white player name inconsistent
3. "Solo queue view" label: meant nothing to him; "idk about this direction" of v6.
   Mocks round 3 reworks it

## Jacob's answers (review v7, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v3-*.

1. Pro games only until the app records pick orders; then solo (v3-daily-1)
2. Pro difficulty (six options, no Pool hint, no event or date) is enough; keep ranks and
   patch visible
3. Looks good, but "the focus of the page doesn't pull me towards picking" (mocks round 4)

## Jacob's answers (review v9, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v4-*. No re-review: refine while building.

1. Phone: the pick as a bottom sheet (Jacob: not his priority; coordinator took the
   lean). Round 4 "lgtm"
