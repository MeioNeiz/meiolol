# Plan: desktop app

No release date: "after Riot's production review" (J7). How it is built:
docs/architecture.md "Desktop window"; `zig build desktop-shot` for PNGs.

## Jacob's list (19 Oct)

Champ select, updating live as champions are hovered and locked:
- Options for every role, not only yours
- Pick options given what people hover
- Ban options from hovers
- Ban options from the champions people are most likely to play: rank them by
  core.banimpact (J20, the site's "Influence" column), several with games, never auto
- Champions and team comps from what people play and how they have done recently
- Options from a chosen pool
- Aware of pick order (Jacob 19 Oct: "they haven't picked top yet, what is good"): when
  the enemy has not picked your lane, blind-safe options (J2: best low end of win
  against an average pick, few hard counters, lane gold as a reason); once they have,
  counters to their pick; same per role for allies still to pick. Show which mode an
  option comes from ("safe blind" / "into Darius")
Once all are picked:
- Team comp: what is strong, notes
- Who is strong, who is good early and late, who will carry, matchup info
In game: the same, plus what each player plays

## Policy check per item (docs/production-key.md "Product rules")

Ranked solo/duo champ select allows no other players' names or stats, no per-teammate
judgements, 3 to 5 options with reasons, no "best pick" or "+X% win rate" wording.
- Fine (champion and aggregate stats): every role, hovers, live updates, bans from
  hovers, your own pool, comp notes, early/late, matchup info, which champion carries
  this comp
- Not in ranked solo/duo champ select: bans from what the enemy players play, comps
  from what your team plays and their recent form, who (as a player) will carry. Maybe
  in normals or flex, and after champ select: check policy before building
- In game: research says reactive in-game advice is now unapproved (research
  riot-appreciated-tools C9) and players reject live help (player-tool-needs C2); a
  loading-screen view of who plays what needs a josearch question first
- Comp win chance: words, not a percentage, while "no public draft win chance" holds;
  comp-lean reasons only once the held-out look passes (data-and-model.md step 1)

## Built and tested

- Lane card built. First Windows run 2026-10-14 on the gpu-box (Windows 11 Pro, two
  1080p screens at 100%; docs/review-shots/windows-desktop-window.png): opens, per
  monitor DPI aware, fonts crisp, resizes and closes cleanly; D3DCOMPILER_47.dll is in
  System32 on Windows 10/11. Idle 0.3% of a core (2911db5). Memory ~470 MB private with
  EUW recent-curves (158 MB; whole files held, the all-region one is 288 MB)
- Admin download (J19): /admin/desktop/meiolol-desktop.zip, button in the admin header
  and, for Jacob (admin page visited in that browser), on the site's download page.
  The zip is the exe and update.key; the app updates itself (Jacob 20 Oct 09:05): at
  start and every 3 h it fetches the current stats and curves and a new exe from
  /admin/desktop/ when their hashes change, swaps data in while open and the exe on the
  next start (architecture.md "Desktop window"). box.sh sync builds the exe for the
  box; each web round (web-loop.sh desktop_files) publishes the files and update.json.
  Behind the admin gate until the key: the zip's key opens that directory only
  (hosting.md)
- Mock champ select from the Mac (20 Oct): `deploy/mock-cs.sh [SCENARIO] [--window]`
  starts a mock League client playing a scripted champ select and game (scenarios:
  full-game, laner-locked-first, trade, dodge, aram, blind-normal; `list`) and runs
  `meiolol-app watch` against it, or with --window the desktop window on the Mac (SDL3
  dev build, `brew install sdl3`). --speed X, --manual (Enter per step), --loop. The
  mock also serves the in-game Live Client Data API (port 2999) and the end of game
  stats block, for whatever comes after champ select; no in-game view is built. Every
  scenario runs in `zig build test`. Shots: docs/review-shots/mock-mid-blind.png, mock-top-vs-darius.png. How it works:
  docs/architecture.md "App"

- Lane card scenes (20 Oct): testdata/cards/scenes.json, ten champ selects (blind,
  counter, locked, guessed positions, bans, pickable, widened pool, no mastery).
  `meiolol-app cards [FILE]` prints each card as text against real stats and curves:
  run it before and after a recommender change and diff. `zig build test` shows the
  same scenes on a synthetic fixture (src/cardscenes.zig) against
  testdata/cards/fixture.txt (a change fails with the diff command; cp to accept), and
  checks 400 random drafts: options from the pool when it has 3+, else widened; 3 to 5
  (fewer only when fewer exist); never banned, taken or unpickable; no "%", "win" or
  "best" in reasons; filled-up options play the role (10%+ of their games)
- Expertise (20 Oct): the pool is ranked by the draft plus the player's own mastery
  points (lanecard.Expertise.fitted, from `meiolol eval --replay`: docs/model.md "Pool
  and expertise replay"); the window's "Rank by your mastery points" box turns it off
  (not kept across restarts yet); `meiolol-app cards --expertise off` for diffs

## Next

- Expertise bonus richer (Jacob 20 Oct: "a calculated bonus based on as much stats as we
  can, not just a simple bonus"): today one fitted beta per tenfold mastery points. Next:
  per-champion slope shrunk to the role's (d1: per-champion gap real, true sd ~2 points),
  recent games and win rate on the champion, games in the role, rank, time since last
  played; each term kept only if `meiolol eval --replay` shows it beats the error bar.
  Open items: data/team/2026-10-20-pooltest/notes.md
- Mock client vs a real capture: once session-real.json comes, diff its shape against
  the mock's (`meiolol-app get /lol-champ-select/v1/session` on each) and fix the mock;
  same for a real Live Client Data reply and eog-stats-block (all synthetic now). Check
  in a real trade that pick actions keep the first champion (the mock and session.zig's
  lock check now assume so)
- Lane gold colour: lanecard.zig colours by sign alone (Sett "-8 gold at 14 min" red in
  the mock run), architecture.md says only 2 SE from even; one of them is wrong

- Jacob, in a real champ select (also needed for the application's screenshots and
  LCU list), from C:\Users\jacob\meiolol-desktop-test (exe, meiolol-app.exe,
  stats-all.bin, v5 recent-curves.bin): open meiolol-desktop.exe and run
  `meiolol-app.exe session --save session-real.json`, then copy that file to
  testdata/lcu/session-real.json (check mastery and ranked replies parse)
- Not checked: 150% scaling (set a display to 150% and open the exe) and the card itself
- Updater checked on Windows (gpu-box, 20 Oct, admin zip in a fresh folder): stats and
  curves arrive and match update.json. The exe swap failed there: std's rename opens the
  source for writing, which a running exe refuses (FileBusy); update.zig renames it with
  MoveFileExW, checked swapping on Windows. A second exe update in one session waits for
  a restart (the running image is then the .old.exe, which Windows won't replace).
  Exes from before the fix never swap themselves: download the zip once more
- Started from WSL (ssh), the exe can't open a window (D3D11 "not currently available",
  session 0) and panics; start it in Jacob's session via a one-off `schtasks /it` task
- Not yet: your own record in the matchup (concept part 6; LCU match history, needs a
  real reply to fix the schema), champion icons, window icon (title bar shows dvui's),
  the public download (after the key, in this order: drop the admin gate and the key,
  and sign the exe, as SmartScreen warns on unsigned ones in a zip or an installer
  alike; then a per-user install, perhaps the exe installing itself to %LOCALAPPDATA%
  with a Start menu entry). A signed exe should also check the new exe's signature
  before swapping, not only the hash from the same server
- dvui: pin PR #1012 (0.17.x branch) until it merges
