# Architecture: website

The site, its feature pages (Daily Draft, Learn) and the Your games service. Layout,
storage, crawler, model file and packed rows: docs/architecture.md.

## Website (src/site, src/wasm.zig)

Views (html.View), as lolalytics' filters: region (EUW, or every platform) by period
(games started in the last 30 days, or EUW's newest patch). EUW over 30 days is the
default; the others are the same URL with ?region=all, ?period=patch or both, their
files in an internal tree _v/all/, _v/patch/, _v/all-patch/ (nginx maps the query to
it; never in a URL). URLs: src/site/ui/urls.zig spells every page (`Page`, `{f}`) and
reads it back (`parse`); a page's file is its path + ".html" (root.filePath; home
index.html), all hrefs root-relative. Each view has its own stats, pool and curves file
(recent-curves.bin, curves-<patch>.bin, and all- versions from `meiolol curves
--platform all`). Header switches link to the same page in another view (a matchup that
view lacks: the matchups finder); localStorage remembers the last view's query so shared
pages (Daily Draft, Learn, Your games, legal: root only, made from the EUW patch view)
link back into it. Old URLs get no redirects (Jacob, 29 Oct).

Champion pages are the exception: root view only, /champions/<slug> (main role, canonical)
and /champions/<slug>/<role> per role it plays (the main role's canonical to the bare
URL); a thin role (under min_role_share) has no file but renders on request, canonical
to the bare URL. ui.champpage's three islands (Top, Build, More, each its
own ui-*.wasm) with a toolbar for region, period and rank, kept in the fragment
(region=, period=, rank=). Each view's data files sit under its dir
(data/champion/<slug>{,-build,-more}.bin); a rank pick above Platinum+ fetches
<slug>{,-build,-more}-rank{,-patch,-all,-all-patch}.bin (champrank.zig, from
filters.zig's tally of every view's games by region, rank, patch, role and opponent).
A ban counts under its game's rank, the median ladder tier of its players: Riot's ban
order doesn't say reliably which player banned. Cards that stay Platinum+ under a rank
pick say so. Other views link in with their view in the query (html.View.query). The
wasms that opt in (`pub const url_map`, dom.zig UrlMap) keep one virtual fragment and
spread it over the address: role as the path's last segment, region and period in the
query, the rest in the fragment; dom.normalise() turns legacy #role=, #pool=, #p= into
that at start. On the champion page ui-champion.wasm owns the address and the other two
follow it (url_map .follow: window.meioFrag, meioSetHash), so they don't carry the
mapping (ui-champmore's budget); role tabs are links to the role's page.

Matchup pages (matchup.zig, /matchups/<role>/<a>-vs-<b>, each view) are rendered on request, so
ui.matchpage's three islands carry their data in the root's data-bin (base64 of
ui.data; ~7 KB gz for Darius vs Garen's 126 opponents) instead of files: ui-matchup.wasm
(Head) loads ui-champbuild.wasm (champpage.Build, its one pair build) and
ui-matchmore.wasm (More). The head's region and period are links to the page in each
view (Segmented with href), ranks greyed: one view per page, no fragment pick.

Scope chips (site/scope.zig Chip, J23): every block on the build and pool pages says
the region, period and rank its numbers are from in the subbar's words
("EUW · 30 days · Plat+"); a dimension the block doesn't follow is marked against the
page's picks ("Plat+, not by rank", "Patch 16.21, not the 30 days picked"). Each chip
carries its keys (data-region, data-period, data-rank; "*" for a block that follows
every pick). Matchup and build pages: one chip in the hero for the page, its own on a block that
differs (the matchup builds cards are the region's patch). Plain data in, markup out, so
it can move into the frontend rework's ui.zig.

`meiolol site --contact EMAIL` writes static files to data/site, framed as "learn your
lane" for the production review (docs/concept.md "Application wording": no tier list,
draft helper, best pick or recommend wording): landing page, matchup index and pages,
Daily Draft, a page per role (/champions/<role>, most played first, no tier grades), a
page per champion (above), method,
download (desktop app, in development), privacy, terms, robots.txt, optional riot.txt,
data/stats.bin (for the app) + data/champions.json. Champion portraits and item, spell and
rune art are ours, shrunk from Data Dragon's (src/icons.zig, ui.art.local; made in each web
round, Data Dragon's own until then).
Edges use the same maths as the app (score.matchupPp, duoPp). Preview mode by default (noindex,
robots.txt disallow, banner): Riot forbids serving the public on a personal key;
`--public` only once the production key is granted. `meiolol render` serves the pages
and files the static build leaves out from the same code, its data swapped whole on reload
(serve.Rendered; docs/hosting.md "Rendering on request"), read from the views file
that `site --views` writes (below). `--static core` (the web loop's) writes only
core_static (root.zig: robots.txt, riot.txt, the two wasm files) and the front-end
assets, loading no view; the home and root sitemap are rendered like any page;
`--static-min-games N` (Static.all) leaves out thin matchups only. `meiolol serve`
(src/serve.zig) serves a site directory over HTTP with .gz siblings; handy for local
previews.

Code shape (src/site: root.zig the Site, options and router; load.zig, extras.zig and
champs.zig the loading; views.zig `Loaded` and the views file; write.zig the static
build; home.zig, tierlist.zig, champion.zig and the other page files): `load` reads
one view's data from the DB into a `Site` (stats, champions, pool, learning, Learn
facts, data and script files); pages are functions of (path, Site): `renderPage`
routes a path within the view to its page function, `renderShared` the site-root pages
(shared_pages), `pagePaths` lists every page. The
static build writes each listed path through the router (one arena per page), so a page
rendered on request is the same bytes: `Loaded` holds every view (loaded on first
request) and answers any path from the site root (pipeline_test checks every file of
the full build, and that `--static core` writes only its list, each the renderer's
bytes).
Views file (data/views.bin; src/site/flat.zig, `Loaded.writeViews`/`readViews`): the
site options and every loaded view's data in parts (Part in src/site/views.zig): base
(stats file, champions, patches), filter (root view), people (pool, learning, spread),
daily (shared view: Daily Draft, your example, Learn, eval points). Little-endian,
slices length-prefixed; each part is tag, view, key, length, bytes. A part's key hashes
its type's shape (field names and types all the way down) and the source of the code
that makes it (partKeys: stats.zig for base, pool, learning and spread for people...),
so a deploy that changes either loads that part again; parts after the base also keep
the champion ids they were made with and are dropped when those change. The daily part
also keeps its inputs (UTC day, the example file's mtime and size) and is made again on
a reuse write when they change, as deploys can keep it for days otherwise. A change
elsewhere that alters a part's data (loadParts, core, store) bumps data_version. Header:
magic MEIOVIE2, then a hash of every key: `render` reads the file only when it matches
its own (else error.ViewsMismatch, and the database load at start), and
`site --views --reuse` (a deploy's round) keeps the old file's parts with this binary's
keys and loads only the rest. Files that come from the binary or options (wasm,
robots.txt, sitemap, the JSON made from pool and learning) are made on reading, never
stored. Curves, builds and lean files are read by the loading binary as before.
pipeline_test: a views file's Loaded serves every full-build file byte for byte, and a
--reuse write with every part kept, or one part stale, gives the same file.
Views partials (data/partials, src/partials.zig; `site --views` only, `--no-partials`
reads the tables as before): the games and mastery the views write reads, kept between
writes so a write reads only what changed. days/<unix day>.bin: every ranked solo game
(420, no remake) started that UTC day as the views read it (match row, participants by
slot with a 128-bit Wyhash of the PUUID, never the PUUID, bans in key order), other
matches by id, queue, platform and patch; per game, not per-day sums, because the
30-day window starts mid-day, pool mains need each player's games, and filters' byte
order follows match ids. mastery.bin: per mastery row (key, rowid, fetched_at) its pool
contribution (main, one-trick, champions also played) for one champion list.
learning.bin: per player and champion with a game after the player's mastery fetch, the
points bin then, by (rowid, fetched_at, champion); a write decodes only rows not in it
(first build ~all such rows) and keeps only pairs still needed. One read transaction diffs (match_id, rowid) of matches and timeline.timelines
(read first: an attached file's snapshot starts at its first read, and the writer
commits main first) against the files, then reads only new, REPLACEd (new rowid) or
newly timelined matches, by key, or whole tables past 150k (the first build;
the views write sets it in site/extras.zig); mastery
rows likewise by rowid. In-place changes the diff can't see: forgotten PUUIDs (scrubbed
each write from `forgotten`, and at once by `meiolol forget` under the directory's
lock), PUUIDs blanked at 24 months (days near the cutoff read again each write, older
ones keep no keys), and rebuild, rekey and restore, which drop the files (under the
lock; learning.bin too, as rowids may repeat). A migration that rewrites participants or bans in place must drop them too. A
change to partials.zig, pool.zig or riot/mastery.zig, or to the file types, starts them
again. Readers: stats, bans, patches, patch day, filters, pool, spread, learning, and
learn's length and team mix tallies and practice match ids; learn's damage split (raw
JSON) and practice games (kills, gold) stay on the database.
again. pipeline_test checks the views file from the partials against the tables', also
after a late, a REPLACEd, a newly timelined, a forgotten and a pruned game and a mastery
refetch, and that forget leaves no row with the player's key.
`meiolol dev` (deploy/dev.sh) serves `Loaded` from data/snap (`deploy/box.sh snapshot`:
the tables the site reads, PUUIDs replaced, no raw docs) with CSS and JS from
src/site/static, and reloads the open page on an edit: `zig build --watch` rebuilds,
the server replaces itself with the new binary. Measured 2026-10-12 (M-series Mac,
Debug, sqlite at -O2): CSS/JS edit visible at once, a Zig edit in ~20 s (9 s build, 11 s
load), pages render in 1-40 ms.

Hosting:
meio.lol (meiolol.jomify.lol and www.meio.lol 308 to it; DNS on Cloudflare, token in
vault personal/cloudflare; mail to any @meio.lol kept in Cloudflare KV, read with
deploy/mail.sh, and forwarded to Jacob's Gmail), nginx on the jomify server: the static
core uploaded from the box by deploy/web-loop.sh (every 15 min early in a patch, then
hourly; docs/plan.md step 2), and at once on each push to main (deploy/on-push.sh);
every other page from meiolol-render on the box, which reads the new views file after
each upload.

Known gaps: stats.bin is dense (~12 MB raw; brotli helps while sparse), no rank
brackets (statsfile has none), no per-patch history.

## Daily Draft (src/daily.zig, src/site/daily.zig, src/site/ui/dailypage.zig)

One real ranked solo game a day, same for everyone: one slot hidden behind four options
(the played champion plus three from the 20 core.recommend rates highest in that draft),
then guess the winner. The hidden slot is the one with the best fit: its ally and enemy
points plus a quarter of its points in the draft (`hideBestFit`), so the guess is about
the draft, not the meta (`hidden_by`: "fit"; puzzles before 18 Oct 2026 hid a random
slot). Pick order is not in match-v5: the page asks it as the last pick ("treat it
as"). Each seat shows its rank. The reveal is facts plus numbers, never "the correct
pick" nor a draft win chance: result, length, team kills and gold, a scoreboard per
team, and per lane this game's gold difference at 14 beside the lane curves' usual one
(a side only for 200+ gold, 2 SE, 200+ games: J11); each option flips to one fact (a
detected reason that clears chance, else its usual gold at 14 against the enemy).

- Made by every full site load (the web loop's `site --views`, after each upload):
  puzzles for today to today+2 (UTC) that
  do not exist yet, from the site's patches and platforms. Puzzle #1 = 2026-10-11
- data/daily/<n>.json is the public puzzle, written once and never remade (the numbers
  are frozen at that day's data); data/daily/used.txt holds the match ids behind them so
  none repeats. used.txt stays on the box: never under site/
- GDPR: puzzles hold no PUUIDs; used.txt holds match ids, so a deletion that covers a
  match means dropping its line (the puzzle itself stays anonymous)
- A failure here (or a bad curves file) is logged and the rest of the site still builds
- No Riot IDs, PUUIDs, match ids or game dates; recent games (J10 dropped the week
  delay). `players` per seat: rank at match time (participants.tier/division), K/D/A,
  CS, gold, damage to champions, gold14 (null without a timeline; new puzzles prefer
  games with one). Puzzles made before it get `players` from the used.txt game with the
  same ten champions (`backfillPlayers`). `tier` is the median of the known ranks
- Site: daily/index.json ([{n, date}]), daily/<n>.json and daily/<n>.bin (the page's
  data, site/dailydata.zig), up to tomorrow (UTC): today+2's answer stays on the box
  (`daily.published_ahead`). /daily (site/daily.zig, per request) is the island
  (ui.dailypage, ui-daily.wasm) with the newest puzzle up to today (UTC) in its data-bin:
  pick, Lock in, who won, then the board grown, the seat panel and On paper. Answers in
  localStorage meiolol.daily.v1 (object by n, {opt, side, hint, marks, on}; Home reads
  marks). The Range hint (melee or ranged, from Options.ddragon_dir's championFull.json
  attackrange; hidden where unknown or form-changing) costs the clean tick ("Pick, with
  a hint").
- /daily/<n>: puzzle n's own page, the same island; none past tomorrow (UTC), so a
  viewer a day ahead of UTC can play theirs and later ones 404. Rendered on request under
  --static core (the renderer, from the shared view's daily files), written by --static
  all; noindex, not in the sitemap; only the slug as printed ("07" 404s), only puzzles
  whose page data decodes. The head (title, badges) sits outside the puzzle's island with
  its own island, ui.dailydays (ui-dailydays.wasm): the last 14 puzzles out by the
  viewer's date as links (right answers by colour, today ringed, the page's own dashed)
  and the streak (finished on its own day; one miss forgiven; an entry saved before `on`
  existed counts on time). It reads meiolol.daily.v1 again on ui-daily.wasm's window event
  "ui-daily" (after each save), not on a storage event or at the viewer's midnight: a
  second tab's finish or a new day shows on reload. On /daily it
  opens (location.replace) the newest puzzle out by the viewer's date, or ?n= (old
  links), when that isn't the page's.
  Once the page's puzzle is finished, ui.dailydays POSTs its answers to /api/daily the
  first time (localStorage meiolol.daily.sent.v1 lists the newest 200 puzzles sent), else
  GETs, and shows "N played: P% got the pick, S% the winner" under the strip from 2
  players. A failed POST un-marks the puzzle (sent again next load) and GETs; a reply lost
  after the server counted it counts twice. The API refuses puzzles past today + 1.
  Share (once finished, and only on a --public build: a preview may not be advertised):
  "Daily Draft #n: k/2", both teams' seats as squares by role with the hidden one as the
  pick's mark, "Who won?" and its mark, the puzzle's page; the share sheet on phones,
  else the clipboard, else a prompt to copy from.
  Not yet: an archive past the strip's 14

## Your games service (src/api; the page: src/site/yourpage.zig, ui.your*)

`meiolol api` on the jomify server behind nginx at /api/; details, privacy decisions and
deploy steps in docs/your-games.md. Requests answer from api.db (own SQLite file, not
the crawler's) and queue jobs; one fetcher task makes every Riot call, through the
crawler's proxy at priority. Matches cached by id (summary
without names, PUUIDs hashed; compact timeline). Per-game numbers come from curves.zig
`lane()`, compared with `Curves.get` for the player's visible-tier bracket. Objection:
profile-icon check, then delete and block the PUUID. Players not looked up for 30 days
are pruned.

## Notes tool (src/site/notes.zig, ui/notes.zig, ui/noteslist.zig, src/api/notes.zig)

Jacob's notes on the live site: tap an element (or the whole page), type, Save; pins
for a page's open notes. Only for a take_notes login (admin and up); visitors get zero
bytes.

- Gating: an admin's login sets the marker cookie `__Host-meiolol_notes=1` (HttpOnly,
  30 days; logout clears it; Tool on/off on /admin/notes toggles it). nginx sends a page
  request carrying it through `@notes` (deploy/nginx/meiolol.conf): the same request to
  itself without cookies, gzip or validators, then `sub_filter` adds site/notes.zig `tag`
  (keep the two in step) before `</body>`, private, no-store. Status codes go through;
  assets skip the hop. Not a boundary: /p/ (view_private) and the API check the login
- Files: p/notes.{css,js,wasm} (fixed names, no-cache) and admin/notes.html (list mode of
  the same wasm, fetched again every 20 s while shown), written by `meiolol admin`
- Paths: notesdata.canonical drops a trailing index.html, on POST and GET
- API: /api/notes GET/POST/PATCH, ui.notesdata binary, bounds in notesdata.check;
  api.db's notes table. Writes need X-Meiolol-Action. Never cached (nginx or Cloudflare)
- A note's element: nearest c-* component or [data-island], its index on the page, a
  child path and a 60-byte text snippet (ties only); "everywhere" notes pin wherever
  their component shows
- Status: open; fixed (a session dealt with it, reply the commit or plan doc; To check
  on /admin/notes, with Looks good / Not yet; the page GET returns it but pins show
  open ones only); kept (nothing to change, reply why); done (Jacob checked). Not yet
  reopens with his words as the reply
- Commits: `deploy/commit.sh --note N` adds a `Note: N` trailer; deploy/on-push.sh marks
  each trailer's note fixed once the deploy succeeds (a done note stays done)
- Shell: `deploy/notes.sh list [--status S] [--by component] | show N | fixed N REPLY |
  kept N REPLY | done N [REPLY] | reopen N [REPLY] | reply N TEXT` (C01's api.db over
  ssh, its binary installed by `deploy/jomify.sh install api`; `--dev` the dev file)
- Dev: `meiolol dev` answers /api/notes into data/snap/dev-notes.db as user "dev";
  /__notes/on|off sets the marker (meiolol_notes, no __Host- on http)

## Patch changes (src/site/patch.zig, src/patchday.zig, src/patchnotes.zig; ui/patchpage.zig)

/patch in every view: the region's current patch against the one before, whole
patches whatever the period (plan docs/plan/ui/patch.md). ui.patchpage server-rendered
from the view's data/patch.bin (stamped, as the champions board), ui-patch.wasm adopts it.

- Rows: every champion role with 300+ games on both patches (patchday.champions), plus
  the main role of a champion Riot changed that has none yet (patchday.thin). Clear =
  z 2.58; the drawn whisker is the same 99%, so a whisker clear of 0 is coloured
- Riot's changes: patchnotes.load from Options.ddragon_dir (DATA/ddragon), loaded once
  per pair per process (Extras.notesFor); a patch's version comes from the cache when it holds
  all three files, so the renderer and tests never fetch them. CommunityDragon's
  ability numbers (cdragon.zig) are fetched per patch into the same version directory,
  so a patch's later version fetches them again (~170 requests, under a minute, ten
  minutes at most), then replace Data Dragon's effect and blanked lines of the spells it has; without
  them (not published yet, down) the lines are Data Dragon's and the next load tries
  again. Load fails: logged, the page goes without the Riot
  column and chip
- Matchups: those whose win rate (400+ games both) or median gold moved clearly, from
  the side that gained; a row's detail has its 3 biggest matchup moves
- Items and runes Riot changed: server-rendered under the island (patchpage.riotView;
  nothing in them filters), each with the 3 champion roles (300+ games) using it most
  in the view's patch builds file: an item as boots, in the start or first three
  finished items (a floor: the file keeps the commonest only), a rune on the page
- Riot's notes link: league-of-legends-patch-<major+10>-<minor>-notes (patchnotes.officialUrl)
- Older pairs: /patch/<cur> (hyphens: /patch/16-20) and data/patch-<cur>-<prev>.bin in the 30-day
  views (EUW and all), up to 4 adjacent EUW pairs below the newest (main.olderPairs) whose
  patches are both whole: the database's oldest patch was crawled from partway, so a pair
  needs an older patch with games. Win rates only (no curves: no matchups or lane lead),
  Riot's changes per pair (notesFor caches each), no item users (the builds are the
  current patch's). Kept in the views file (Part.older). PatchHead's ‹ › step through
  them from every view's /patch

## Learn (src/site/learn.zig, learnbuild.zig, learnfixed.zig; ui/learnpage.zig)

Chapters of puzzles (plan docs/plan/ui/learn.md): a setup drawn as UI (RateRows, a duel,
role tiles, champion icons with chips), a short question, a guess on a GuessSlider or a
pick, then the reveal (all bands as rows when the puzzle has them), one line why and a
takeaway. A first visit lands on chapter 1; chapter 0 (basics) one tap away.

- /learn is rendered per request: ui.learndata.Data in the island's data-bin,
  ui-learn.wasm runs it. `#p=<id>` links a puzzle
- learnfixed.zig: hand-written puzzles from finished checks (chapters 1, 2, 5); edit
  there, a deploy makes it live
- learnbuild.zig: chapter 0 roles (tiles of each role's top 90%+ champions), chapter 3
  lane (all-ranks curves) and early or late (`meiolol lean`), chapter 4 counters (every
  region, 30 days curves). A puzzle ships only when clear (J11); empty chapters drop
- Progress: stars per puzzle in localStorage meiolol.learn.v2 ("id:n,..."), nothing sent
- src/learn.zig still makes learn/practice.json and learn/champs.json (DailyPart) for
  chapter-end drafts; the page does not read them yet
