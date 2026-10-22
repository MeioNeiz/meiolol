# Plan: desktop apps

Two editions from one codebase (Jacob 22 Oct, J21): a public app that fits what Riot
reviews, and a private one for the private, admin and owner roles (Jacob's friends and
testers; docs/plan/accounts.md). Paid accounts (later) get extras in the public
edition, within the public rules. Public release: no date, "after Riot's production
review" (J7). How it is built: docs/architecture.md "App" and "Desktop window";
`zig build desktop-shot` for PNGs.

## Two editions

- Build option `-Dedition=public|private`. Private features live in their own modules,
  imported only under a comptime check, so the public exe holds none of their code or
  strings (Riot may look at it; friends' features shouldn't leak through it)
- Both share the poller, the lane card, data files, signing and updates. The private
  edition reads extra data files (e.g. raw model outputs) that only /p/desktop/ serves
- deploy/desktop-release.sh builds, fuzzes and signs both; each has its own update
  channel: public /desktop/ (after the key), private /p/desktop/ (device token, AC4).
  Today's admin-gated exe becomes the private edition
- The public edition is built and shot from now on, for the application's screenshots,
  even while only the private one is downloaded

## Policy line

Riot's general policies apply to every product, whoever its users are
(research/sources/riot-policies-general.md): no unfair advantage, "like a cheating
program or giving some players an advantage that others would not otherwise have"; no
de-anonymising "players who cannot reasonably be identified from visible information";
increase, not decrease, the diversity of decisions; give several choices, don't remove
decisions; every new feature is audited through the product's page. One product per key.

Paid extras are public features behind a payment, so they follow the public rules.
The private tier is "more depth, numbers and unfinished features for testers", not
"information the game hides". Same framing as paid tiers at Porofessor, Blitz,
Mobalytics (research: league-apps-feature-matrix once written).
- No tier, ever: other players' identities or stats in ranked solo/duo champ select
  (the client hides them; reading them anyway is de-anonymising), anything the game
  doesn't show during a game (enemy cooldown or jungle timers), auto pick, ban, lock or
  dodge, MMR calculators
- Private only: win chance as a percentage, "+X%" and single-pick rankings, raw model
  scores, experimental models beside the shipped one, all of Jacob's list in queues
  where names are visible (normals, flex: check in a real capture), player scouting
  from the loading screen on (names are visible there)
- Public: docs/production-key.md "Product rules" (3 to 5 options with reasons, words
  not percentages, no names or stats of others in ranked solo/duo champ select)
- Open (AC0, Jacob): the application should mention a closed tester group with extra
  features, since features are audited and the key covers the described use. Recommend
  yes, worded as testers trying features before they go public

## Jacob's list by edition (19 Oct list)

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
| In game: what each player plays | research question first | from the loading screen |
| In game: reactive advice | no (riot-appreciated-tools C9; players reject it, player-tool-needs C2) | no |

## Steps

Ranked. Ids for team runs and claims ("APP3: taken by <session>" in the run's common.md).

- APP1 Real champ select capture (Jacob, blocks the queue checks and the application's
  screenshots): from C:\Users\jacob\meiolol-desktop-test open meiolol-desktop.exe, run
  `meiolol-app.exe session --save session-real.json` in a ranked solo/duo and a normal
  champ select, copy to testdata/lcu/. Then diff against the mock (`meiolol-app get
  /lol-champ-select/v1/session` on each), fix the mock, and record which identity fields
  each queue gives. Same for a real Live Client Data reply and eog-stats-block. Check in
  a real trade that pick actions keep the first champion (mock and session.zig assume so)
- APP2 Editions in the build: `-Dedition`, module split, both in `zig build ci`, release
  script builds and signs both. Done when the public exe's strings hold no private
  module names (a ci check)
- APP3 Every role and pick order (both editions): the card per role, blind-safe vs
  counter mode with its label, allies still to pick. Builds on lanecard.zig and
  core.score; cardscenes fixture extended per mode. Mock scenarios first, real capture
  after
- APP4 Hovers: picks and bans from hovered champions, live (both editions)
- APP5 Ban options by ban impact (both; private adds pools where names are visible)
- APP6 After picks: comp view (notes, early/late, carry, matchups); public in words,
  private with numbers
- APP7 Private: scouting where names are visible (needs APP1's queue facts and AC6 for
  "me"), percentages, experimental models
- APP8 Champion icons and window icon (Data Dragon art is allowed, logos not)

## Private site

The /p/ pages (accounts.md AC3). First candidates, cheapest first: the draft tester
(admin only today, site.md "Draft tester"), win chance and raw scores beside the public
wording on champion and matchup pages, experimental models (J15's labelled
experiments), all regions and patches without the public page-weight cuts.

## Status (22 Oct)

- Public-shaped lane card for your role, ranked by draft plus your mastery points
  (lanecard.Expertise.fitted; "Rank by your mastery points" box, not kept across
  restarts). Card rules tested over 400 random drafts and ten scenes
  (testdata/cards/scenes.json, `meiolol-app cards [FILE] [--expertise off]`, fixture
  testdata/cards/fixture.txt): run cards before and after a recommender change and diff
- Windows (gpu-box, 14 Oct, Windows 11, 1080p at 100%): per monitor DPI aware, crisp,
  resizes and closes cleanly; idle 0.3% of a core; ~470 MB private with EUW
  recent-curves. Not checked: 150% scaling. From WSL over ssh the window can't open
  (session 0): start it in Jacob's session with a one-off `schtasks /it` task
- Admin download and self-update (J19, signed exe and data, release script only):
  architecture.md "Desktop window", hosting.md "Desktop app files". Exes from before
  the MoveFileExW fix (20 Oct) never swap themselves; a second exe update in one session
  waits for a restart
- Mock champ select on the Mac: `deploy/mock-cs.sh [SCENARIO] [--window]` (scenarios
  `list`; also serves Live Client Data on 2999 and the end of game block; no in-game
  view built). Every scenario runs in `zig build test`

## Later

- Expertise bonus richer (Jacob 20 Oct: "a calculated bonus based on as much stats as
  we can"): per-champion slope shrunk to the role's, recent games and win rate on the
  champion, games in the role, rank, time since last played; keep a term only if
  `meiolol eval --replay` beats the error bar. Notes:
  data/team/2026-10-20-pooltest/notes.md
- Lane gold colour: lanecard.zig colours by sign alone, architecture.md says only 2 SE
  from even; one is wrong (also an open question in decisions.md)
- Your own record in the matchup (concept part 6; LCU match history, needs a real reply)
- Public download, after the key, in order: the public channel (APP2), Authenticode
  signing (SmartScreen warns on unsigned exes, in a zip or an installer alike), per-user
  install (%LOCALAPPDATA%, Start menu entry)
- dvui: pin PR #1012 (0.17.x branch) until it merges
