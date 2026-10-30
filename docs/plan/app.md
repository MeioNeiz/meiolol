# Plan: desktop apps

Two editions from one codebase (J21): a public app that fits what Riot
reviews, and a private one for the private, admin and owner roles (Jacob's friends and
testers; docs/plan/accounts.md). Paid accounts (later) get extras in the public
edition, within the public rules. Public release: no date, "after Riot's production
review" (J7). How it is built: docs/arch-app.md "App" and "Desktop window";
`zig build desktop-shot` for PNGs. Once the webview shell takes the exe name, install and
updates (stack.md step 6), delete the dvui window: src/desktop, desktop_main/dev/shot,
the dvui dependency and the desktop-* build steps.

## Two editions

- Build option `-Dedition=public|private`. Private features live in their own modules
  (src/desktop/private/), called only under a comptime check, so the public exe holds
  none of their code or strings (Riot may look at it; friends' features shouldn't leak
  through it). `zig build ci` builds both and runs deploy/check-edition.sh: no
  desktop/private/ path (dvui's @src() leaves one per module with widgets) in the public
  exe, every one in the private exe (else the check is blind). Every `ctx.private()`
  branch sits behind widgets.private_code, comptime false in the public exe
- Both share the poller, the lane card, data files, signing and updates. The private
  edition reads extra data files (e.g. raw model outputs) that only /private/desktop/ serves
- deploy/desktop-release.sh builds, fuzzes, checks and signs both; each has its own
  update channel: public /desktop/ (after the key), private /private/desktop/ (device token,
  accounts.md AC4). Today's downloaded exe is the private edition
- The public edition is built and shot from now on, for the application's screenshots,
  even while only the private one is downloaded

## Policy line

Riot's general policies apply to every product, whoever its users are
(research/sources/riot-policies-general.md): no unfair advantage, "like a cheating
program or giving some players an advantage that others would not otherwise have"; no
de-anonymising "players who cannot reasonably be identified from visible information";
increase, not decrease, the diversity of decisions; give several choices, don't remove
decisions; every new feature is audited through the product's page. One product per key.
The personal key covers "just the developer or a small private community", but no text
exempts it from these rules. Riot removes features by announcement and lets no app keep
them (research/questions/league-tools-riot-removals.md): so far identity in a live
lobby and live in-game help, never champ select suggestions, draft win rates or
post-game review. Anything in game or automated is the likely next cut, private tier
included.

Paid extras are public features behind a payment, so they follow the public rules.
The private tier is "more depth, numbers and unfinished features for testers", not
"information the game hides". Same framing as paid tiers at Porofessor, Blitz,
Mobalytics (research/questions/league-apps-feature-matrix.md); their paid tiers sell
little that is "op" (no ads, favourites, dashboards, high-elo builds, AI review), and
iTero, LoLDraftAI and Team Advisor show draft win % with no Riot pushback so far.
- No tier, ever: other players' identities or stats in ranked solo/duo champ select
  (hidden since 12.22; reading them anyway is de-anonymising), streamer-mode players
  anywhere live, enemy ult timers and all enemy cooldowns, power spike alerts and "gank
  top now" prompts, ads in game, on loading screens or in the client, augment win rates,
  auto accept, pick, ban, lock or dodge, MMR calculators
- Private only: win chance as a percentage, "+X%" and single-pick rankings, raw model
  scores, experimental models beside the shipped one, all of Jacob's list in queues
  where names are visible (normals, flex: check in a real capture), player scouting
  from the loading screen on (names are visible there)
- Public: docs/production-key.md "Product rules" (3 to 5 options with reasons, words
  not percentages, no names or stats of others in ranked solo/duo champ select)
- Open (AC0, Jacob), two ways to cover the private tier: (a) the production
  application mentions a closed tester group trying features before they go public
  (recommended: one product, one key, honest); (b) the private tier is the registered
  personal app (MEIOLOL 890240, "small private community") making its own calls on the
  personal key, so production-key data doesn't feed a product Riot didn't review.
  Riot Sign On needs a production key, so either way the private tier uses our own
  login

## Jacob's list by edition

Champ select, updating live as champions are hovered and locked. P = public, X = private.

| Item | P | X |
| --- | --- | --- |
| Options for every role, not only yours | yes | yes |
| Pick options from hovers | yes | yes |
| Ban options from hovers | yes | yes |
| Bans from what people are likely to play, ranked by core.banimpact (J20), several with games, never auto | champion stats only | plus the enemies' own pools where names are visible |
| Champions and comps from what people play and their recent form | no | where names are visible; ranked solo/duo: no |
| Options from a chosen pool | yes | yes |
| Pick order aware: blind-safe until the enemy picks your lane (J2), then counters; same for allies still to pick; label the mode ("safe blind" / "into Darius") | yes | yes, with the scores |
| After picks: comp notes, strengths, early/late, which champion carries, matchup info | yes, words | yes, with numbers |
| Who (as a player) will carry | no | loading screen on, or where names are visible |
| Team win chance | words, after the held-out look (data-and-model.md step 1) | percentage |
| In game: info panel through the game ("In-game companion" below) | later, after the private one proves it | yes |
| In game: alerts, prompts, enemy cooldowns | no | no |

## Steps

Ranked. Ids for team runs and claims ("APP3: taken by <session>" in the run's common.md).

- APP1 Real champ select capture (Jacob, blocks the queue checks and the application's
  screenshots). On the PC, in a terminal in C:\Users\jacob\meiolol-desktop-test, before
  queueing: `meiolol-app.exe record capture-ranked` (lcu.Record: every champ select
  state, gameflow at each phase, Live Client Data every 30 s in game, end of game block,
  identities as "hidden"), then play a ranked solo/duo game to the end, Ctrl+C;
  `record capture-normal` for a draft normal. Meanwhile open meiolol-desktop.exe and
  screenshot (Win+Shift+S) its card at pick and after locks, and record a short video
  of champ select with it (Win+Alt+R) for the application. A trade if one comes up
  (pick actions keep the first champion: mock and session.zig assume so). A session
  copies the folders to testdata/lcu/, diffs them against the mock, fixes the mock and
  records which identity fields each queue fills in. First real check of Live Client
  Data's certificate: a "live client data: <error>" line in record's output means
  https.get needs another root for port 2999
- APP3 Every role and pick order (both editions). Done: the board (Window layout
  below) with the mode chip and ideas for allies still to pick; in the webview shell a
  click on an ally's seat switches the lane panel to their role (options from everyone
  who plays it, by the draft alone, while they still pick; once they lock their matchup
  only, nothing rating their pick; "Your lane" or my seat goes back; role-less queues
  have no seat clicks). The blind-safe ranking (J2) doesn't pick better than the
  average opponent (model.md "Blind pick ranking (J2)"): the list stays
- APP4 Hovers: picks and bans from hovered champions, live (both editions). The board
  shows ally hovers and intents and counts them in the draft; left: an enemy's hover
  never shows, so nothing to do there; check ban hovers in a real capture (APP1)
- APP5 Ban options: first pass done (board.zig: ban impact in roles the enemy hasn't
  filled, never an ally's hover; the desktop stats file has no ban counts, so impact is
  per all games). Left: ban counts in the desktop stats file, my lane first while my
  opponent is unknown; private adds pools where names are visible
- APP6 After picks: comp view, first pass done (both editions; comp.zig,
  desktop/comp.zig): once all ten are locked, above the lane panel, each team's damage
  split bar and mix (and "teams this one-sided win less often" when Learn's tally is 2
  SE under even), its champions with a clear early or late lean (`meiolol lean`), and
  five mirrored lane rows (ahead, even or behind at 14 min, 2 SE; level 6 sooner or
  later); testers see the magic share, the mix's win rate, lean numbers and lane gold.
  Data: champ-facts.tsv (core/champfacts.zig), written by the site's shared view, listed
  in the desktop manifest, fetched by update.zig (older exes skip it), not a stats file
  bump. Left: comp leans (Malphite into AP teams) after their held-out look
  (data-and-model.md step 1); "who carries" (no shipped carry measure: gold or damage
  share per champion would need a new tally); the loading screen's team pills from the
  same comp; a release so testers get it; the shell: CompView under the
  page once all ten lock, static HTML (ui-app.wasm is at its 40 KB budget)
- APP7 Private: scouting where names are visible (needs APP1's queue facts and AC6 for
  "me"), percentages, experimental models
- APP10 Loading screen cards, first pass done: in GameStart the window shows
  the last champ select's ten seats as cards (loading.zig, desktop/loadscreen.zig): role
  (guessed with ?), pills for strong or weak in the role, few games, ahead, even or
  behind against the same role across (2 SE from even at 14 min), level 6 and first
  item sooner or later (20 s apart); testers also see each role's win rate and both
  teams' draft score. Left: a loading screen with no champ select seen (app started
  late: Live Client Data or the gameflow session), team comp pills; private adds player
  scouting (APP7)
- APP11 Post game view, first pass done (both editions: facts the client's own
  screen shows): verdict and kills, the team gold story in a sentence, my lane at 14 min
  against the matchup and gold earned over the game, award chips (damage, KDA, gold, CS,
  vision), mirrored lane rows with gold earned between, team gold chart (from the
  in-game samples; none when the app missed the game), damage bars. From
  /lol-end-of-game/v1/eog-stats-block (lcu/eog.zig; positions from detectedTeamPosition,
  else the last in-game tick, else inferred). Left: check APP1's real block; tabs
  (fighting, farming, vision); our draft call against the result
- APP12 Practice, first pass done (private; Jacob: "test out different drafts
  and see more of the UI before even getting into a lobby"): arch-app.md "Desktop
  window". Left: Jacob's try on the PC; Data Dragon icons when the client is closed;
  a saved draft or two; the in-game and post game numbers are made up, not a replay
- APP9 In-game companion, private first (below). First pass done (against the mock and
  a synthetic reply): score and team item gold, mirrored lane rows with gold
  differences, your lane's CS and item gold against the matchup at this minute with the
  dot on the gold chart, respawn timers after a kill, team gold through the game. Left:
  check APP1's real reply (item `price` total or combine cost; creepScore exact or in
  tens; KillerName as the Riot ID game name; position blank in any queue), win chance
  by minute (private, statemodel.zig), builds against their comp, a small hotkey panel

## Window layout

Porofessor-style. Research: research/questions/desktop-app-layout.md (17
sources, screenshots of Porofessor, Blitz, Mobalytics, U.GG, OP.GG, iTero, DraftGap).
One window, 1120 x 720, a phase stepper on top (Lobby, Champ select, In game, Post game);
under 900 px one column. `zig build desktop-shot -- --stats F --curves F --icons
data/icons` renders every scene wide, at 150%, narrow and public (icons for the Mac:
CommunityDragon champion-icons/<id>.png into data/icons, gitignored).
- Champ select (built, src/desktop/ui.zig, teams.zig, lane.zig): our seats left, theirs
  right (icon, role or guessed role, state, win rate in the role, "few games" under 1000,
  ideas), the team's draft score on top of each column (private); the lane panel in the
  middle (mode chip, chart, 3 to 5 option cards with reason pills, private team %), then
  the draft bar (private), bans and ban options (first while banning). Narrow: Your team
  / Picks / Enemy team tabs, Picks first
- Colour: win rates on fixed steps (widgets.rateColour), reason pills coloured by meaning
  with the words always on them (green good, red bad, orange caution, grey neutral)
- Loading screen (APP10, built): Porofessor's 2 x 5 cards, ally row over enemy row
  under a team rule, fixed card order (icon, name, role, private rate, pills); narrow:
  one compact row per seat with two pills. Hover for the reason and number later.
  Player pills ("on a streak", "main") private only and only where names are visible
- In game (APP9, built in the main window: src/desktop/private/game.zig): score strip
  and team item gold bar, five mirrored lane rows (our icon, gold delta, their icon)
  left; your lane against the curve, respawns and team gold through the game right.
  Narrow: one column, rows without names. Later a small panel, hidden by default, hotkey
- Post game (APP11, built: desktop/post.zig): verdict card with the gold story, my lane
  and award chips on top; mirrored lane rows left; team gold area (blue over red) and
  damage bars right; detail behind tabs later; no dense tables

## In-game companion

J22: the app shows info that helps throughout the game. A panel the player looks at,
never a notification that tells them what to do: Riot's guidelines ban power spike
alerts ("X champion has hit level 6"), decision prompts ("Gank top lane now!") and
enemy ability or summoner spell cooldowns
(research/sources/overwolf-aug-2025-riot-guidelines.md). Big apps still show objective
timers, gold leads, benchmarks against your tier and teammates' ult timers
(league-apps-feature-matrix C3).

Data: Live Client Data API (127.0.0.1:2999, read-only, every few seconds) plus our
curves, stats and builds files. Shown, updated as the game goes:
- Your lane against the typical game in this matchup at this minute (gold, XP, cs from
  the curves; the site's matchup chart with a "you are here" line): our own angle,
  nobody else has per-minute matchup benchmarks
- Team gold and kill lead; objective timers (dragon, baron, herald, grubs, inhibitors)
  from the event feed
- Win chance by minute: private as a percentage, public in words or not at all
  (riot-appreciated-tools C9: reactive advice unapproved; check before public)
- Builds: what usually works against their comp and your lane opponent's items so far
  (private with win rates, public as options); your items vs the usual path
- Static reference opened by the player, not pushed: the matchup's level 6 and item
  spikes, cooldown sheet at ranks (knowledge, not tracking)
- Teammates' ult timers only if the API gives them (allowed; enemy ones are not)
After the game, the same panel becomes the review: the turning minute, deaths and what
they cost, spikes and windows compared with the curve (Your games already does most of
this on the site)

## Private site

The /private pages (accounts.md "Status"); /private itself is an index of them. Live: the
Draft tester (/private/tester, draft-tester.md) with the live model and the Lab's comp
model (jomify's training-receive.sh puts only the tester's model files in private/lab);
the old JS tester at /private/old until the new one has compare (bans, Random/Fill/Undo,
the lane model's Gold column and the set net done). Then /private/old, admin.js, admin-draft.js,
admin-setnet.js and admin.css go, and pv.js becomes an island. The shipped model's
win chances on the public champion and matchup pages for private logins (/private/pv.js,
loaded by the header script in browsers that opened /admin/ or /private, data
private/models/champ/<id>.json from `meiolol draft-model`): a line in the hero and a last line
on every opponent and duo tile. The app review pages, /private/app (arch-app.md "Review
pages"): every screen the app can show, from the mock scenarios, in both editions, for
Jacob's notes. Next: the tester ports above; all regions and patches without the public
page-weight cuts.

Private ideas from the feature survey (league-apps-feature-matrix), after the above:
loading-screen scouting of the lane opponent and the rest (mainstream; names are
visible there), the group's pooled stats and leaderboard, a Discord bot, game-start
alerts for friends, model-driven post-game review. Public counterparts: opt-in sharing
of your own stats (OP.GG's verified link), post-game review as facts, progress between
games.

## Status

- Icons: champion icons from the client (desktop/icons.zig; Data Dragon art is allowed,
  Riot logos not); the app's own is the site favicon's M (exe, shortcut and window)
- Champ select board around the lane card (Window layout); lane card for your role,
  ranked by draft plus your mastery points
  (lanecard.Expertise.fitted; "Count your mastery points" box, not kept across
  restarts). Card rules tested over 400 random drafts and ten scenes
  (testdata/cards/scenes.json, `meiolol-app cards [FILE] [--expertise off]`, fixture
  testdata/cards/fixture.txt): run cards before and after a recommender change and diff
- Windows (gpu-box, Windows 11, 1080p at 100%): per monitor DPI aware, crisp,
  resizes and closes cleanly; idle 0.3% of a core; ~470 MB private with EUW
  recent-curves. Not checked: 150% scaling. From WSL over ssh the window can't open
  (session 0): start it in Jacob's session with a one-off `schtasks /it` task
- Admin download and self-update (J19, signed exe and data, release script only):
  arch-app.md "Desktop window", hosting.md "Desktop app files". A second exe update
  in one session waits for a restart
- Installs itself: the zip's exe moves into %LOCALAPPDATA%\Programs\meiolol
  with a Start menu shortcut (Windows search finds it) and an Apps list entry with
  Uninstall; one copy at a time. Checked on the gpu-box: install, second start, install
  over an open copy, uninstall
- Mock champ select on the Mac: `deploy/mock-cs.sh [SCENARIO] [--window]` (scenarios
  `list`; also serves Live Client Data on 2999, item gold per player, and the end of
  game block). Every scenario runs in `zig build test`

## Later

- Expertise bonus richer (Jacob: "a calculated bonus based on as much stats as we
  can"): per-champion slope shrunk to the role's, recent games and win rate on the
  champion, games in the role, rank, time since last played; keep a term only if
  `meiolol eval --replay` beats the error bar. Notes:
  data/team/2026-10-20-pooltest/notes.md
- Lane gold colour: lanecard.zig colours by sign alone, arch-app.md says only 2 SE
  from even; one is wrong (also an open question in decisions.md)
- Your own record in the matchup (concept part 6; LCU match history, needs a real reply)
- Public download, after the key, in order: the public channel ("Two editions"),
  Authenticode signing (SmartScreen warns on unsigned exes, in a zip or an installer
  alike)
- dvui: pin PR #1012 (0.17.x branch) until it merges
