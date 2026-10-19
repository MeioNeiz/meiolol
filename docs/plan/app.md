# Plan: desktop app

No release date: "after Riot's production review" (J7). How it is built:
docs/architecture.md "Desktop window"; `zig build desktop-shot` for PNGs.

## Jacob's list (19 Oct)

Champ select, updating live as champions are hovered and locked:
- Options for every role, not only yours
- Pick options given what people hover
- Ban options from hovers
- Ban options from the champions people are most likely to play
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
- Admin download: /admin/desktop/meiolol-desktop.zip (8f47b90)
- Mock champ select from the Mac (20 Oct): `deploy/mock-cs.sh [SCENARIO] [--window]`
  starts a mock League client playing a scripted champ select and game (scenarios:
  full-game, laner-locked-first, trade, dodge, aram, blind-normal; `list`) and runs
  `meiolol-app watch` against it, or with --window the desktop window on the Mac (SDL3
  dev build, `brew install sdl3`). --speed X, --manual (Enter per step), --loop. The
  mock also serves the in-game Live Client Data API (port 2999) and the end of game
  stats block, for whatever comes after champ select; no in-game view is built. Every
  scenario runs in `zig build test`. Shots: docs/review-shots/mock-mid-blind.png, mock-top-vs-darius.png. How it works:
  docs/architecture.md "App"

## Next

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
- Not yet: your own record in the matchup (concept part 6; LCU match history, needs a
  real reply to fix the schema), champion icons, window icon (title bar shows dvui's),
  the download page shipping the exe with stats and curves
- dvui: pin PR #1012 (0.17.x branch) until it merges
