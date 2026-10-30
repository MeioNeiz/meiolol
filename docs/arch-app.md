# Architecture: app

`meiolol-app`, the webview shell and the desktop window. Layout, storage, crawler, model
file and packed rows: docs/architecture.md.

## App (src/app_main.zig, src/lcu)

- Finds the client via --lockfile, MEIOLOL_LOCKFILE, the install path, then the process
  list. Polls the champ select session every second; read-only GETs only
- Redacts identity fields (gameName, puuid, ...) from anything it prints or saves
- Never shows other players' names or stats (Riot policy, docs/production-key.md)
- Known gaps: no network timeouts in Zig 0.16 Threaded IO; refused connect on Windows
  surfaces as error.Unexpected (mapped to ClientNotRunning)
- Mock client (src/lcu/mock.zig, src/mocklcu_main.zig): `deploy/mock-cs.sh [SCENARIO]
  [--window] [--speed X] [--manual] [--loop]` plays a scenario from
  testdata/lcu/scenarios (`list`) and runs `meiolol-app watch` (or the window) against
  it. Serves the LCU paths the app reads (gameflow phase and session, champ select
  session, pickable, owned, mastery, ranked, current summoner, end of game stats block)
  and the in-game Live Client Data API on 127.0.0.1:2999 (`curl -s
  127.0.0.1:2999/liveclientdata/allgamedata`); `meiolol-app get PATH` probes the rest.
  Plain HTTP: the app takes it only from an override lockfile ending `:http`
  (Credentials.plain); the install path and process list stay HTTPS pinned to Riot's
  root. Shapes from the community schema, as session-synthetic.json; check them against
  a real capture. `zig build test` plays every scenario through lcu.Watch and checks
  each step's `expect` (keys in mock.zig's header)

### Webview shell (src/shell, deploy/shell.sh)

- Beside the dvui window until it takes the exe name, install and updates (docs/plan/ui/
  stack.md Order step 6); every client state already has its ui screen
- win.zig drives WebView2 through its COM API (translate-c of the vendored WebView2.h,
  src/shell/wv2); environment via the runtime's own dll, else the embedded
  WebView2Loader.dll; no runtime: a message offering Microsoft's bootstrapper
- Pages are served from memory on https://meiolol.app/ (embedded, or `--dir` on disk);
  navigation stays on that origin, links to meio.lol and Riot open in the browser.
  bridge.js (injected) turns channel.zig messages into `meiolol` events and back
- screens.zig: the poller's state as ui.app.Data in the edition's words (notes,
  ChampSelect, LoadScreen, GameScreen private only, PostGame), rendered per page load
  and encoded at app.bin; the App island (ui-app.wasm) patches from it on each `app`
  message and keeps the charts' state. Once all ten lock, and on the loading screen,
  CompView after the island as static HTML (no interaction; when it comes or changes
  the shell sends `reload`, which bridge.js turns into a page load); on the loading
  screen without "win less" or win rates, as picks are locked. The Mac build's `--dump DIR --seconds N` writes
  each change to DIR/<seq>/ for a look against the mock client
- Review pages (src/site/appreview.zig, /private/app; the dev server makes them on the first
  request): each scenario in testdata/lcu/scenarios (embedded through its all.zig, which
  lists them) played through the poller's own tick (poller.Replay: the mock client on
  free local ports), a page per change it would publish; full-game's champ select from
  each seat too, each ally's lane once all ten lock, the no-client, sign-in and update
  states, and practice (testers only). Rendered by screens.renderIn in both editions with
  the site's icons, the island and CSS under /private/app/, at the window's 1120 px or
  420; a fake bridge shows what the page sends the shell, and a seat click opens that
  lane's page. URLs /private/app/<edition>/<slug>, app.bin under <slug>/ (review.js
  points the island's relative fetch there: nginx sends base-uri 'none'). A navigator of
  every group and state on the left (a drawer when the frame leaves no room), the
  group's steps above the frame, arrow keys between states (left, right) and groups (up,
  down); /private/app opens the last edition's first state (nav.js)
- Lane panel: a click on an ally's seat shows their lane: the shell writes the board's
  seats' data-act as "lane <role>" (255 mine; only seats with a role, as allyLane finds
  the ally by role; ui/draftboard.zig Seat.act, the shown one Seat.sel) and bridge.js
  sends `lane`, so ui-app.wasm carries no handler and no new field (ui-app.wasm's
  budget: a Lane bool cost 760 B gz; Lane.mastery null marks an ally's lane). The poller
  then builds the card from that ally's side (board.allyLane: their champion, no pool,
  mastery or rank; lanecard.Input.ally: once they lock no options, the matchup only, and
  their hover never gets a forced row) beside my own card's board and bans
  (state.lane_role, back to mine when champ select ends). Not under practice, whose seat
  clicks place champions
- Page to shell: ui/toshell.zig's Out, written by ui-app.wasm through bridge.js. The
  sign-in form (ui/signin.zig: the screen until there is data, else a line under it)
  sends `signin`, which the shell hands to the poller (device.zig); never logged
- Window place in window.txt and the webview's data in webview/, both beside the exe
- deploy/shell.sh: gpu-box smoke (both loaders), measure (memory, CPU, push delay,
  League's processes), run; refuses while a League game runs unless IN_GAME=1

### Desktop window (src/desktop_main.zig, src/desktop, src/lanecard.zig)

- The data and the poller are backend-free (desktop/poller.zig); desktop_main.zig is the
  Windows window around them, desktop_dev.zig the same on macOS or Linux through dvui's
  SDL3 backend, for the mock client: `zig build desktop-dev -Ddev-window -fsys=sdl3
  --search-prefix /opt/homebrew` (`brew install sdl3`; dvui's SDL3 source build fails on
  0.17, a config header mismatch). Not shipped; reads MEIOLOL_LOCKFILE

- `zig build desktop`: zig-out/bin/meiolol-desktop.exe (~3 MB;
  dvui pinned to PR #1012, lazy so the box never fetches it). Reads the newest
  stats-*.bin and recent-curves.bin (else curves-<patch>.bin) from data/export or next
  to the exe (src/datafiles.zig, shared with `meiolol-app`), and champ-facts.tsv when
  there (core/champfacts.zig: damage split, team mix tally and early or late leans, which
  the site's shared view writes as data/champ-facts.tsv; the comp view's, src/comp.zig)
- A detached poller thread does what `watch` does once a second and publishes a
  ui.Status (with the lane card) under a mutex, waking the window with a WM_NULL; the
  UI thread only draws, and sleeps between messages (own main loop: dvui's dx11 App
  main draws every vsync, ~10% of a core idle). Detached because a request to a hung
  client cannot be interrupted. Per champ select it also reads pickable and owned champions, the
  player's own mastery and visible solo tier (lcu/me.zig)
- Releases (21 Oct): only deploy/desktop-release.sh ships an exe; a push never does.
  On a clean checkout of a pushed commit it runs `zig build desktop-check` (core and app
  tests under ThreadSanitizer) and `zig build desktop-fuzz --fuzz=N` (fuzz tests of what
  the app reads: stats, curves and the lane card, champ select, mastery and ranked
  replies, the signed manifest; core/fuzz.zig mutates good files), builds both editions
  ReleaseSafe with `-Ddesktop-version=<unix seconds>`, signs them and copies the private
  one to the box's release/, the public one to release/public/ (`--dry-run`: no signing
  or copying).
  Plain `zig build test` runs each fuzz test once. Two more checks (24 Oct):
  deploy/desktop-shots.sh check renders every desktop-shot state from pinned inputs
  (data/desktop-shots/inputs, gitignored) and compares them pixel for pixel with the
  approved set there (`--compare`; NAME.diff.png marks changes red; `approve` after a
  look, `pin` for new inputs); deploy/desktop-smoke.sh EXE runs `meiolol-desktop
  --self-test` (desktop/selftest.zig: data files load, a lane card per role, no window
  or install) in the gpu-box's %LOCALAPPDATA%\meiolol-smoke from WSL
- Signatures (desktop/sign.zig, Ed25519, public keys built in): the release key (vault
  meiolol/desktop only) signs each exe's version, SHA-256 and size (`meiolol
  desktop-sign exe`); the data key (box ml/meiolol/desktop-data.key, copy in the same
  vault group) signs the manifest each web round (`desktop-sign manifest`). The app
  refuses an unsigned manifest, an exe not signed by the release key, and an exe whose
  release is not newer than its own. A new key needs a new download
- Updates (desktop/update.zig, J19): once the app is signed in (device.zig: POST
  /auth/device, the token in device.token beside the exe; until accounts.md AC4's
  cut-over, update.key beside it also works), a detached thread reads
  https://meio.lol/private/desktop/update.signed
  at start and every 3 h (MEIOLOL_UPDATE_URL elsewhere), and at once after a sign in,
  checks its signature, and fetches each listed
  file whose SHA-256 differs from the local copy: stats.bin as stats-<patch>.bin (older stats-*.bin
  deleted), recent-curves.bin, champ-facts.tsv, meiolol-desktop.exe (names it doesn't
  know are skipped, so a new data file needs no version bump). Each goes to NAME.part (gzip on the
  wire, nginx's .gz copies), is checked against hash and size, then renamed over the
  old. The running exe is renamed to meiolol-desktop.old.exe (kept for a manual
  rollback) and the new one takes its name: next start runs it, and the footer says
  so. New data: the poller loads it between ticks, publishes a status built from it,
  then frees the old. The token goes as Authorization: Bearer (the key in
  X-Meiolol-Desktop) with redirects off (std 0.17's privileged_headers are never sent). A
  401 on the token deletes it and the sign-in form comes back (signin.zig: the whole
  window with no data yet, else a line under the content). A failed check waits 5 min,
  doubling to 3 h (a success or a sign in starts again), logs the error, and without
  data the window says why in plain words (update.why). The update list at 404, 410 or
  a redirect is error.Moved: a line under every screen says this version can't update
  itself, get the new one at meio.lol/download. `meiolol-app signin DIR` and
  `meiolol-app update DIR` do the same on a folder. Box side: web-loop.sh desktop_files; gate: hosting.md
- Install (desktop/install.zig, setup.zig; 23 Oct): a release, or an exe with an update
  key (the zip's exe carries it after its image, as Explorer runs an exe inside a zip
  without the files beside it; else update.key beside it), started outside
  %LOCALAPPDATA%\Programs\meiolol writes itself there without the key, any key as
  update.key (a device.token there stays), copies data files the install lacks, writes the Start menu shortcut (what
  Windows search finds) and an Apps list entry under HKCU (Uninstall runs `--uninstall`,
  `--quiet` skips the question), starts the installed copy and exits. No admin rights,
  and the updater can replace the exe there. The installed copy runs once (a Local
  mutex; a second start brings its window forward) and a new install closes it first
  (WM_CLOSE to the window class "meiolol"). `--portable` skips all of it, as does a dev
  build without a key. Icon: src/desktop/meiolol.ico (the site's favicon) via meiolol.rc,
  for the exe, shortcut and window
- Lane card (lanecard.zig, docs/concept.md part 6): the enemy shown in my position, else
  the one core.score.inferRoles puts there (labelled a guess); gold at 14 min one
  sentence and a chart (estimate line, middle half of games shaded) from the player's
  bracket once it has 200 games, else all ranks; thin as the site. "From your pool":
  up to 15 most-mastered pickable champions with role games, ranked by the recommender,
  widened to every pickable champion below 3 options; 3-5 shown, each with lane gold vs
  the opponent (green/red only when 2 SE from even and not mostly baseline), mastery and
  team-fit facts, never win-chance numbers. Riot boilerplate in the footer
- In game (APP9, private edition; ingame.zig, desktop/private/game.zig): in InProgress
  the poller reads Live Client Data (lcu/live.zig: 127.0.0.1:2999 allgamedata, Riot's
  root, plain for the mock) each tick. Rows by position (blank ones inferred as in champ
  select), gold from each player's item prices (the game shows only your own), score and
  respawns from the event feed (dragon 5 min, elder 6, Baron 6, inhibitor 5, only after
  a kill), my lane's CS and item gold against the matchup's curve at this whole minute
  (p10/p25/p75/p90 in words). The poller keeps the team gold every 20 s of game time for
  the chart (new game: game time goes back)
- Loading screen (APP10; loading.zig, desktop/loadscreen.zig): the poller keeps the
  last champ select's seats and draft (seats_arena) and in GameStart builds ten cards
  from them, and the comp of the same ten (comp.build): each team's pills, damage mix
  and early or late lean counts, neutral (comp.pills); nothing shows when it saw no
  champ select
- Post game (APP11; postgame.zig, desktop/post.zig, rows.zig as in game): in
  PreEndOfGame and EndOfGame the poller reads the end of game block (lcu/eog.zig) and
  builds the view with the game's gold samples and the positions the last in-game tick
  saw; tier and mastery are kept from champ select through the game until the next lobby
- Practice (private edition; practice.zig, desktop/private/practice.zig): the header's
  Practice button, whenever the client is not in champ select or a game, gives a bar to
  set screen (champ select, loading, in game, post game), stage, role, pick place, a
  random draft (locked, champions by games in each role), bans, minute, lead and result.
  Seats and bans open a champion picker (search, most played in the role first); a lane
  option hovers it as my pick, a second click locks; an idea fills that ally; a ban
  option is my ban. The setup (under the poller's mutex) becomes a mock client state
  (lcu/mock.zig's reply builders, no server) read back through session/live/eog parse
  and the same builders, so hidden enemy hovers and turns behave as in a real select; in
  picks it is always my turn (locked seats picked before me). Game numbers are made up
  from the minute and lead. Each change bumps a counter the poller waits on
  (futexWaitTimeout, else 1 s), so a click redraws without a client round trip. A real
  champ select or game takes over until it ends. Icons need the client open, else
  initials
- `zig build desktop-shot -- --stats F --curves F [--out DIR] [--min-games N] [--compare
  DIR]`: the
  window's states (fixture champ selects in desktop_shot.zig, the loading screen
  from one, in game and post
  game from testdata/lcu/live-allgamedata.json and eog-stats-block.json, practice from a
  seeded random draft, picker open in one) as PNGs at 100%, 150% and
  full height, drawn by desktop/raster.zig (premultiplied "over" blending, top-left
  fill rule); no screen or client needed. `zig build ci` compiles both. Test data
  (data/desktop, gitignored): `deploy/box.sh run stats --platform all --out FILE` on the
  box (3 s, 171k games on 2026-10-12) plus data/export/all-recent-curves.bin, copied down
