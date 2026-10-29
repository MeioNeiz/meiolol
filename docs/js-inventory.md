# Front-end JS inventory: what each script does and where it could go (22 Oct 2026)

Builds on docs/frontend-rework.md 1-4 (coupling, duplication, bug classes are not
repeated here). Line numbers are at 2d5b078. Sizes fetched from meio.lol today.

Classes (one per feature):
- H: plain HTML/CSS today (popover, details name, radios/checkboxes + :has, counters,
  form GET, CSS animation)
- S: Zig on the server: at build time, or on request in meiolol-render / the API
  (`meiolol render` already renders any path from data in RAM, docs/hosting.md
  "Rendering on request", so "too many variants to prebuild" is not a blocker)
- W: client logic worth keeping client side; Zig in wasm
- G: browser glue that stays JS (fetch, storage, history, timers, share, combobox keys)

Caveat (research/questions/zig-only-frontend.md C15): radio, checkbox and `:has()` state
hacks fail WCAG 4.1.2, so the H items built that way (tabs, moment picking, Learn
stepping) need real buttons and a line of the generic runtime instead.

Lines are rough (comments and blank lines included in the feature they sit in).

## Public scripts (4,887 lines)

### filters.js (527): champion page filters

- [G] :19-75 (57) fetch filters/<slug>.json, filters.json, champions.json; resolve picks
  from URL, localStorage "champion-filters", "view" and sessionStorage "meio-in";
  :231 history.replaceState; :235 meioView. With S, what stays is the "kept picks"
  redirect for a page opened with none (~15 lines) and meioView
- [S] :76-123, :229-271 (95) snapshot server markup, apply/restore, view-of-picks
- [S] :125-171 (47) sum rows by region, patch, rank: filters.zig data, in RAM in the
  renderer (views file "filter" part)
- [S] :173-191 (19) scope and footer text: load.zig patchMix, root.zig sharedPage
- [S] :193-227 (35) redraw switch links and intercept clicks: with S they are plain links
- [S] :273-465 (193) tiles and opponent rows; copies champion.zig opponentTable, usualCell
  (:358), goldCell (:413), tierlist.zig trackCell (:139); mostly DOM building
- [S] :479-527 (49) fade, usual, points, wrColour, pct, platformName: curvesfile.zig:125,
  champion.zig:227, tierlist.zig:214, html.zig:285
- [H] :74, :467-475 (20) Common/All toggle and "Show them": both row sets in the page,
  checkbox + `:has(:checked) tr[data-rare]`
- Variants for S: region 16 (15 platforms + all) x period 2 x rank 4 = 128 per champion,
  x 173 champions = 22,144 pages (Common/All stays in-page). Page today 294 KB, 33 KB gz:
  ~6.4 GB raw / ~730 MB gz prebuilt, so render on request (4 of 128 are views already
  prebuilt). Removes the 569 KB (183 KB gz) filters/<slug>.json per visit

### table.js (160): every sortable table

- [G] :15-81 (67) sort by column, renumber ranks, keep sort per table id. DOM reorder:
  wasm adds nothing. (H possible with grid `order` from server-written per-column
  ranks, but tab and reader order would not follow: not recommended)
- [G] :83-98 (16) name search hides rows (no CSS match on a live input value)
- [H] :100-108 (9) show-rare button: checkbox + :has
- [H] :110-159 (50 of which ~15 G persistence) tier list min games / share inputs:
  fixed choices as radios, rows carry the thresholds they fail, `:has(#min-400:checked)
  tr.u400 {display:none}`; the rare count via CSS counters (hidden rows don't count)

### min-games.js (78): matchup index min games

- [H] :24-52 (30) hide rows under the choice, strict "clears chance" from data-strict:
  same radios + classes; "n shown" with counters
- [G] :27-33, :53-61 (25) word search across names, hide and reorder role groups
- [G] :19-22, :64-77 (23) remember the choice, pageshow re-apply

### search.js (337): header search (every page)

- [H] :9-15 (7) region grid closes on outside click / Escape: `popover` gives light
  dismiss and Esc; anchor positioning places it under the chip
- [dead] :38-50 (13) data-keep radio memory: no markup has data-keep any more
- [G] :32-37, :51-86, :151-158 (49) meio-in marker, index fetch on focus, view dir,
  recent Riot IDs
- [W] :88-224 (137) matching: OSA distance, scoring, aliases, "a vs b" and split
  parsing, triangular pair-role lookup. Mostly string maths; search.zig builds the index
  but no Zig matcher exists. Wasm candidate; the same Zig behind a render-server
  `search.html?q=` gives a no-JS submit (today it only does Riot IDs)
- [G] :226-336 (131) combobox DOM, ARIA, arrow keys, submit, "/" shortcut

### home.js (175): home demo (gone: ui.homepage, ui-home.wasm)

- [G] :11-41 (31) "On this device" Riot IDs and forget (localStorage)
- [S] :43-68 (26) fetch your-example.json, build role tabs: the example is build-time data
  (api/example.zig), so render it in home.zig; tabs as [H] radios
- [S] :70-110 (41) pick the most-swung game, render the review; [H] the 2.8 s tour as a
  CSS animation over prerendered states, paused by :hover/:focus-within and
  prefers-reduced-motion (~15 lines of today's logic)
- [S] :112-173 (62) previews: turning-minute spark, three costliest deaths, lane vs
  typical, highlight cards

### review.js (834): game review (Your games, home demo)

Data comes from the Zig API (api/game.zig computes turning, moments, death costs, firsts,
best minute, lane curves); review.js turns it into words and SVG. S here means the API
(or home.zig for the example) renders HTML with tpl, fetched as a fragment.
- [G] :47-61 (15) fetch champions.json, instantiate chart.wasm (both go with S)
- [S] :78-165 (88) moments: turn, fight, objective, death texts, kinds and badges
- [S] :167-285 (119) win chance SVG and spark; DOM/SVG building, like lanechart.zig
- [S] :289-334 (46) result strip; pager links [G] or one fragment per game
- [G] :338-361 (24) share sheet / clipboard
- [S] :363-466 (104) moment list, fold, counts, records
- [S] :468-502 (35) lane chart: already Zig (lanechart.zig through chart_wasm.zig); the
  API renders it directly, three SVGs (gold, XP, CS) with [H] radio tabs (:574-599, 26)
- [S] :504-636 (133) lane table, among, swings, players panel
- [S] :638-753 (116) highlights: aggregates over the report, maths; belongs in
  api/game.zig report beside weeks and matchups
- [H] :759-831 (73) pick a moment or minute: cursor, eval bar, list highlight. One radio
  per moment and per minute (30-45), dots and hit strips as labels, prerendered cursor
  and bar value per radio, `:has(#m7:checked)`; details fold opens via :has instead
- [S] :1-45, :833 (~55) constants and formatters (signed with U+2212, pct, list)

### your.js (742): Your games

- [G] :7-91 (85) API base, preview sign-in (credentials), status, preview note
- [G] :93-190 (98) fragment URL + sessionStorage (Riot ID never in a request URL to the
  site), recent IDs, last player cache. Must stay: privacy design
- [G] :192-269 (78) lookup and poll loop (queued, fetching x of n)
- [G] :271-330 (60) "Check for new games" watch loop, check_at
- [S] :332-380 (49) example per role: 5 build-time pages; role tabs [H]
- [S] :382-500 (119) player header, record and form dots, film strip, new marks, review
- [S] :502-567 (66) highlights tiles, by-week and matchup tables
- [H] :569-579, :710-719 (21) time tabs: radios or `details name`; remembered [G]
- [G] :581-655 (75) Riot ID removal: icon proof, POST, polling
- [G] :657-742 (86) not you, URL parsing, wiring, hashchange, example HEAD

### daily.js (650): Daily Draft

Deleted: the ui.dailypage island (ui-daily.wasm) replaced it.

One puzzle a day, all reveal content fixed per puzzle: daily.zig can write
daily/<n>.html (1 page a day, ~15 KB; 14 so far).
- [G] :1-164 (118) constants, getJson, local-date puzzle choice, ?n= archive, load
- [S] :293-322 (30) board, ranks, bans
- [S] :324-344 (21) option facts (reasons filter, clear(), lane gold): policy wording
  then checked in Zig tests
- [H] :346-412 (66) pick then side: radios; `:has(#pick-k:checked)` turns the cards
  (CSS transition), shows the side question; side radio shows the reveal
- [S] :414-457, :483-557 (119) reveal tiles, on-paper read, scoreboard, lanes at 14
- [H] :459-470 (12) right/wrong marks: the played option is known at build time
- [G] :67-82, :116-137, :471-481, :581-603, :624-640 (92) results, forgiving streak,
  record, archive marks (localStorage; streak maths is 16 lines, not worth wasm)
- [G] :204-262 (59) answer persistence, crowd POST/GET and shares
- [G] :563-579, :605-622, :643-648 (41) back to today, share text, time to midnight
- [S] :45-58, :96-114 (34) helpers rankText, longDate, shortReason, glyphs

### reasons.js (27)

Deleted with daily.js.

- [S] all: which model reasons public pages may show. Moves to the Zig that writes
  Daily and Learn; wasm.zig suggest can apply it for practice pool picks

### learn.js (1,072): Learn

- [H] :60-143 (84) tabs and view memory: radios/`details name`; view memory [G] ~15
- [S] :95-103 (9) glossary term tips: the server already renders them in lessons
- [S] :164-215 (52) puzzle bars and reveal: puzzles.zig already writes them (folded)
- [H] :217-241, :249-321 (95) puzzle flow: pick puzzles (7) as radios + :has, one at a
  time via radios, score with counters on `.right:checked`
- [W] :151-162, :226-246 (36) guess puzzles (4): slider verdict (within 4% / 12% of the
  range). Tiny; or quantise the slider into radios and make it [H]
- [H] :323-513 (191) lessons: question at a time, answer shows right/wrong and why
  (`:has(:checked)`), dots, step bar, "x of n right" via counters. Content is
  server-rendered already
- [G] :60-93, :1051-1072 (56) progress in localStorage, start
- [G] :517-551 (35) meiolol.wasm loader (alloc, load stats.bin, suggest, JSON)
- [G] :598-693 (96) practice setup: role and level buttons [H-able], pool chips list
  in localStorage, datalist
- [W] :695-793 (99) random queue per role and level, pool substitution, brings/lacks by
  magic share, scoring call: logic beside learn.zig Difficulty; Zig in wasm.zig
- [S] :795-924 (130) board, hints (one at a time: nested details [H]), options
- [S] :926-1048 (123) timing facts, summary, reveal notes, lane mini chart. 222 drafts
  prerendered as 15 fragments (role x level, ~70 KB each); a substituted pool option
  needs the same tpl through wasm (the chart_wasm.zig pattern)

### pool.js (285): Champion pool

- [S] :47-223 (177) per-main card: also-play, hard lanes, cover, when banned, learning
  line. 173 mains: prebuilt fragments (~0.7 MB total) or on request
- [S] :224-254 (31) across several mains: combinations of up to 3 of 173, on request
- [H] :256-282 (27) form GET `pool.html?main=garen&main=darius` (today #garen,darius),
  native datalist; the page then works without JS
- [G] :15-45, :55-64 (50) fetches (pool.json 110 KB, learning.json), helpers: go with S

### html.zig inline scripts (7)

- [G] :191 (1) remember the view for shared pages
- [G] :203-204 (2) admin menu link from localStorage (private)
- [G] :211-213 (3) meioView: move data-view links into the last view visited
- [G] :272 (1) lookup forms: Riot ID into the fragment (privacy)
- pool.zig:45 `onsubmit="return false"` goes with the pool form GET

## Admin scripts (3,712 lines, private page, brief)

- admin.js (2,497): G ~600 (polling live/snapshot/traffic/training, shell, tabs,
  storage, action POSTs, log viewer); S ~1,300 (views built from JSON, markdown and
  report tables, bars, tiles: admin.zig already writes the snapshot); W ~550 (SVG
  charts with zoom and range, interval charts)
- admin-draft.js (861): W ~300 draftModel/laneModel/checks (:153-470), a JS copy of
  src/lab/draft.zig and lane.zig Scorer, checked against reference pairs at load: the
  strongest wasm case on the admin side; W/G ~560 draft board and pickers
- admin-setnet.js (174): W, forward pass of lab/setnet.zig
- Since the admin page moved to ui islands, only /private (PRIVATE mode) loads these

## Works without JS today

- Every stats page in its default state: tier lists, role pages, matchups, builds,
  champion page root view, in server order; min-games and tl-mins controls are hidden
  (html.zig:375 renders the default choice)
- Champion page pick links have real hrefs (`?rank=5`, `?region=KR`) but without JS the
  page ignores the query and shows the default view, labelled as such: silently wrong.
  S fixes it. The Common/All nav is hidden; "Show them" does nothing
- Header search: form GET to your.html?id= (Riot IDs only); Your games itself is blank
- Learn: lesson text and puzzles with answers folded (puzzles.zig:5); tabs hidden;
  practice blank
- Home: static parts only, demo hidden. Daily Draft, Pool, Your games: blank skeletons

## Totals (public 4,887 + inline 7)

| class | lines | share |
| --- | --- | --- |
| S | ~2,350 | 48% |
| H | ~650 | 13% |
| W | ~270 | 6% |
| G | ~1,610 | 33% |
| dead | 13 | |

S by file: review 660, filters 450, daily 300, learn 340, pool 235, your 225, home 110,
reasons 27. G by file: your 490, learn 310, daily 290, search 180, table 105, review 70,
filters 57, min-games 43, home 40, pool 25, inline 7.
Admin adds ~1,300 S, ~1,000 W, ~1,400 G.

## Five biggest wins

1. Champion filters rendered on request in meiolol-render (S, ~450 lines). Deletes every
   JS copy of Zig maths the rework doc calls the worst kind, a 183 KB gz JSON per visit,
   and makes filter links real, shareable and correct without JS
2. Game review as Zig tpl (S, ~1,000 lines across review.js, your.js render and
   home.js): the API returns HTML fragments, home.zig renders the example at build time.
   Highlights and moments sit beside api/game.zig, chart.wasm is no longer needed,
   the minus-sign and pct drift disappears. Moment picking as radios + :has (H)
3. Learn lessons and puzzles as HTML (H, ~300 lines): radios, :has, counters. Content
   is already server-rendered, only the stepping and checking is JS
4. Daily Draft prerendered as daily/<n>.html (S+H, ~250 lines plus reasons.js). Policy
   wording (no win rate claims) then lives in Zig where tests can check it
5. Pool as form GET rendered on request (S+H, ~260 lines). Works without JS, no 110 KB
   pool.json download, one shared renderer for single and combined mains

Next after those: search matcher to Zig wasm (W, 137), and the min-games / table
min-games thresholds as radios (H, ~85).

## What stays JS if all S and H are done and W moves to Zig wasm

| piece | lines |
| --- | --- |
| core: fetch and swap a fragment, storage helpers, persist checked radios by name | ~80 |
| one wasm loader (bytes in, JSON or HTML out, as wasm.zig and chart_wasm.zig) | ~40 |
| Your games: lookup, poll and watch loops, sign-in, removal, recent IDs, hash | ~250 |
| Daily: local-date choice, answers and streak storage, crowd, share | ~120 |
| Learn: progress, pool chips, practice queue glue to wasm | ~110 |
| search combobox, keys, index fetch, wasm call | ~130 |
| table sort, name search, sort memory; min-games word search | ~100 |
| champion kept-picks redirect, meioView, view memory, admin link, lookup submit | ~30 |
| home recent Riot IDs | ~25 |
| total | ~885 |

About 18% of today's public JS. A third of it is Your games' polling and removal flows;
server pages with meta refresh and a form POST could take that to ~650, at some cost
to the "Checking every minute" experience. The admin page would keep ~1,400 G unless
admin.zig renders its views.
