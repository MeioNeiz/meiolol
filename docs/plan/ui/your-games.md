# Your games (player page)

Identity: one player's games, a profile you can read at a glance and dig into: the
games, the records, the friends, how it is going over time. Plan 24 Oct 2026, team run
2026-10-24-ui (session games). One game's screen has its own plan: game-detail.md.
Mocks: data/team/2026-10-24-ui/mocks/your-games-list.html, your-games-more.html
(#highlights, #friends, #over-time). In the list mock only the newest game's items and
CS are real; the API keeps neither yet (Data needed).

## Who comes and why

- After a game: open the newest one (game-detail.md)
- Regulars: the record, the streak, how the last week went, the friends they queue with
- Looking someone up (a friend, a scoreboard name): what they play and how it goes
- Riot's reviewer: the example, which must look like a real profile

## What Jacob said (24 Oct)

- "too many words on main page ... before you use it, there is just way too many words.
  Need to turn this into a more complete ui"
- "The highlights are good, almost still too wordy or atleast a bit hard to read rn"
- "Friends is great, we just need to expand on this overtime, again make it less wordy,
  develop more advanced ui for it"
- "the overtime bit is just a bit shit rn, not actually interesting, doesnt scale well,
  needs a lot of work and not even a real table so it sucks"
- "Too many words in the your data bit too"

## Structure

Today it is one long scroll (lookup, player, strip, review, highlights, friends, over
time, your data), 3,800 px for the example. It becomes a player bar and four views,
each its own URL (#id=..&view=friends), so each gets the whole screen:

- Player bar (always, 64 px): Riot ID at --fs-xl, rank emblem and "Platinum II · 2 LP",
  the record "15-8", win rate, a form strip of the last 20 results (W/L ticks), the
  refresh button with its time ("11:21", spins while checking), a "⋯" menu (Copy link,
  Not you?, Remove my data)
- Views as tabs (`tabs`, the one "pick a view" control): Games, Highlights, Friends,
  Over time. Game detail opens from Games and keeps the bar
- The lookup box moves into the site header search (it already takes Riot IDs) plus
  the home page; the empty page (no Riot ID) is the home page's lookup block with the
  example under it (one component, `id-lookup`), never a flash of it before the example

## Games (default view)

First screen, desktop 1280: player bar, tabs, then two columns:

- Left (3/12), the summary (component `profile-summary`): record and win rate as a ring
  or bar, KDA, then "Champions" as rows (icon, games, W-L, win bar) for the top 5, then
  roles as five role icons with games under each. Pressing a champion or role filters
  the list (the same state as the filter chips)
- Right (9/12), filter row (queue chips: All, Solo, Flex, Draft, Swift; role; champion
  search, the shared `champion-search`) and the list grouped by day ("Today",
  "Yesterday", "21 Oct"), each a `game-row`. The day header carries W-L and time played
  ("3-0 · 1h 52m", deeplol's session line); net LP as dpm has it needs LP per game,
  which we don't store (Data needed)

`game-row`, 56 px, one line at desktop:
result edge (--us win, --them loss, 3 px) | champion 40 px with level and role badge |
"vs" opponent 24 px | K/D/A at --fs-l with KDA under | CS and per minute | items, 7 at
22 px | lane at 14: a mini `bullet-range` (your gold lead against the typical middle
half) | win chance sparkline 120 by 32 with the turn starred | queue and duration and
time ago, right aligned, small. The newest row carries "new" when it arrived since the
last visit (exists: markNew).
Pressing a row opens the game (game-detail.md). Rows without a timeline (older history,
summary only) show what they have and leave the sparkline and lane slots empty, same
widths.

Phone 390: summary collapses to one line under the bar (record, win rate, top 3
champion icons with games) that expands; rows in two lines (champion, K/D/A, result
edge; then items and sparkline).

Words on the first screen (labels only): Games, Highlights, Friends, Over time, All,
Solo, Flex, Draft, Swift, Champions, Today, Yesterday, KDA, CS: ~14. Today the first
screen has ~70 (the status line, "Your games 23 games, newest first. Pick one to review
it", the turning sentence, the chart caption).

Scale: 60 days can be 150+ games. The list pages by day groups ("Show older" at the
foot), filters cut it down, the summary always covers the filtered set.

Open: land on Games, or open the newest game when it ended under 3 hours ago? (I'd say
Games, with the newest row first: one press, and the page never guesses.)

## Highlights

Today: 14 cards, each a figure, a label and a context sentence ("lane gold at 14 min:
Aurelion Sol vs Yasuo, win, 23 Oct"), coloured by category, wrapping into a ragged
third row.

New: `record-tile`s in four labelled groups, each a row of tiles of one size:

- Streaks: current streak, longest win streak, record
- Lane: biggest lead at 14, furthest above typical at 14, lanes without a death before
  14
- Fights: best KDA, kill gold given away per game, deaths the enemy turned into an
  objective
- Games: won from furthest behind, lost from furthest ahead, biggest one-minute swing,
  longest game, fastest win, most played

`record-tile`: the figure at --fs-xl, a label of 1-3 words, and a `game-chip` (your
champion and theirs as 20 px icons, W/L dot, date) in place of the sentence. Pressing
the chip opens that game at the moment (&t=) the record came from. Colour: only where
the figure is good or bad for you (lead, swing) on the diverging scale with its sign;
counts and times in plain ink. Phone: 2 tiles a row.

Words: group titles 4, labels ~2 each, no sentences. The header line "From your last 23
games. A record book across every game you've played is coming." goes; the scope is
the tab's count chip ("23 games").

## Friends

Today: a table whose cells are sentences ("No games apart in the queues you share",
"+21 points (−42 to +84); 11 together, 3 apart"), and a two-line explanation under it.

New, first screen: a summary band (with friends 15-8, 65%; alone 0-0) then
`friend-row`s, a real table (`data-table`, sortable):

| Column | Shows |
| --- | --- |
| Friend | Riot ID (link to their games), their most played champion as the avatar, last played as "1d" |
| Together | W-L and a win bar |
| You with them | `effect-interval`: a dot for the difference in your win rate with them against apart, its 95% range as a line, on one shared axis (−50 to +50 points) with 0 marked; coloured only when the range leaves out 0 |
| Them with you | the same from their games; "Fetch" button until their games are cached |
| Usual pair | two champion icons (yours, theirs) and W-L; two role icons and W-L under it |

Column headers carry the toggletips ("Your win rate with them minus apart, in the same
queues; the line is a 95% range"); the paragraph under the table goes. "Against them"
shows only when any friend has games against.

A row expands (press) to: your games together as `game-row`s, and their champion pairs
with you as a small table. Phone: Friend, Together, You with them (the dot plot
narrows); the rest in the expansion.

How it grows (docs/backlog.md "Your games and Squads"):

1. Now: the table above, then the expansion with games together
2. Duo view: one friend's page section, champion pairs with records, role pairs, how
   your lanes go together (bot/support pairs: the lane duel summed for two)
3. Squads (opt-in, profile-icon join): a squad page with the roster as a row of
   portraits, games together, a weekly recap of record tiles per member ("lane of the
   week"), squad Daily Draft scores. Built from the same record-tile, game-row,
   friend-row components; nothing new but the roster header

## Over time

Today: a "By matchup" table of one row per matchup (23 rows of 1 game each for Jacob)
with a list of gold numbers as text, and a "By week" switch; not sortable, every row
"1".

New, two parts:

1. A chart (`trend-chart`, the shared chart system): every game as a dot by date (60
   days), y the chosen measure, a filled dot for a win and hollow for a loss, a rolling
   mean of 5 as a line. Measure as a segmented control: Gold at 14 vs typical (default),
   KDA, CS per min, Damage share. Pressing a dot opens the game. Filters shared with the
   Games view (queue, role, champion)
2. A real table (`data-table`, sortable, sticky header) grouped by [Champion | Matchup |
   Week] (segmented):
   - Champion (default): champion and role, games, W-L, win rate with a bar, KDA, CS
     per min, gold at 14, vs typical at 14, a sparkline of gold at 14 per game, last
     played. 5 rows for Jacob, not 23
   - Matchup: the same columns with the opponent; rows under 2 games fold into "13 one
     game matchups" at the foot
   - Week: week, games, W-L, the same averages
   Rows press to filter the chart to that champion or matchup

The chart marks patch changes as dashed dividers labelled "16.20", "16.21"
(Mobalytics' LP Gains), so a patch's effect shows without a second chart. Matchup and
Week groupings are mocked: Matchup folds one-game matchups behind an "N one-game
matchups" chip.

Scales because the default grouping has one row per champion, sorting puts the answer
first, and the chart holds any number of games.

A fifth group, Patterns (League of Graphs' Personal Patterns): win rate by game length
(under 25, 25-35, over 35 min) as signed differences from your overall rate with a
small bar each. Client side from the report; not mocked.

## Your data

Today: two paragraphs and a button at the foot of every page.

New: nothing on the page but the "⋯" menu item "Remove my data", which opens a dialog
(`dialog`) with the icon check as three steps in UI: the icon at 64 px, a 15:00
countdown, a Check button; one line "Set this profile icon, then press Check." and a
"What we keep" link to the privacy page, where the paragraphs go. The site footer of
Your games gains "What we keep" next to Privacy.

## Model site (research's refs, refs/README.md kind 2)

| Take | From | Where |
| --- | --- | --- |
| 56-62 px rows, the lane opponent only, not ten names | dpm.lol | game-row (already ours) |
| Two-line phone row, no names | u.gg | game-row phone |
| Day groups with W-L and time played | dpm.lol, deeplol sessions | Games list |
| Patch dividers on the over-time chart | Mobalytics LP Gains | GameTrend |
| Played-with as a real table | u.gg, Mobalytics | Friends (ours already goes further) |
| Signed differences by game length | League of Graphs Personal Patterns | Highlights, Patterns |
| List first on phone | deeplol | page order |

Leave: place pills (MVP, ACE, 3rd) and dpm's score rings (no score of ours to show,
and they grade named teammates), Mobalytics' 10-16 tag chips per row and op.gg's tags,
ten names per row, op.gg's "Strong pick #7" (best-pick wording), op.gg's last-20 vs
season chip (our window is 60 days; revisit with a longer history). Ours alone: the win
chance sparkline per row (no site has one).

## Components used (register names)

PlayerBar, ResultStrip (form), Segmented (tabs variant), IdLookup, ProfileSummary,
FilterBar, ChampSearch, GameHeader (row and chip variants), Versus (band), TimelineSpark,
StatStrip (RecordTile items), DataTable, Delta (dot, the forest plot), Toggletip,
ChampIcon, ItemIcon, Chart preset GameTrend, Dialog, plus the game-detail kit. The
kebab names above map to these (game-row = GameHeader row, game-chip = GameHeader chip,
record-tile = StatStrip RecordTile, effect-interval = Delta dot, bullet-range = Versus
band, trend-chart = GameTrend, form strip = ResultStrip form).

## Data needed

| What | Status |
| --- | --- |
| Games with K/D/A, lane, win chance, records, friends, weeks, matchups | exists |
| CS, gold, damage per game in the row and the trend | new, timeline last frame (small, as game-detail) |
| Items in the row | new Summary fields (medium, as game-detail) |
| LP change per game (dpm's row chip and day net LP) | not stored: league-v4 gives the current LP only; a snapshot per refresh gives a change per refresh, not per game. Medium, and only for games after it ships |
| Rank emblem and LP | exists (league-v4 at refresh); emblem images from Riot's static assets (new asset, small) |
| All 60 days of games in the list (not only those with timelines) | new: the report returns the backlog's summaries too (medium: they are cached, it is a query and a lighter row) |
| Rolling and per-champion aggregates | client side in ui.wasm from the report (no API change) |
| Friend expansion: games together | exists in api.db (intersect match ids), new endpoint field (small) |
| Squads | new (backlog design agreed; large) |

## Cut

Status sentences, section captions, the Friends explanation paragraph, the Highlights
scope sentence, Your data's paragraphs, the "By matchup" one-game rows, the 2-row
120 px game cards (now the strip in game detail and rows here).

## Desktop reuse

game-row and record-tile are the desktop's "last games" list and post-game badges;
player-bar's form strip and record work in the desktop's session view (`meiolol-app
session`). friend-row only on the site.

## Questions for Jacob (24 Oct)

1. Four views as tabs, or keep one long page with the sections tighter? (Recommended:
   tabs; Over time and Friends need the room and scale badly inside a scroll.)
2. Land on the Games list or the newest game (above)
3. Over time's default measure: gold at 14 against typical, or something less
   lane-bound (win chance at 15) so junglers and supports get a fair line?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Tabs, but the page looks empty and not everything should hide behind tabs: the
   Games view keeps a summary of the others (e.g. top highlights, a small Over time
   line) above or beside the list
2. Open the newest game when it ended under 3 hours ago
3. Over time's default measure: win chance at 15 (fair to every role); gold at 14 vs
   typical stays as an option

## Jacob's answers (review v6, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v2-*.

1. Patterns on Over time: keep
2. Game rows tinted by result: keep
