I changed nothing. Most of the site is already on the new UI. What is still legacy is ten pages, the shared page shell, and the private admin and tester pages. Some of the old code is already dead and could be deleted today.

## 1. Pages and URLs

Public pages come from `renderPage` (`src/site/root.zig:562`, page list `:542-559`), one copy per view under `/_v/<view>/`. Shared pages come from `renderShared` (`root.zig:588`, `shared_pages` `:405`, `unlisted_pages` `:408`).

| URL | Status | Writer → component / script |
|---|---|---|
| `/` | New | `home.zig:34` → ui.homepage, ui-home + ui-homegame |
| `/champions`, `/champions/<r>` | New | `tierlist.zig:274` → ui.tiers, ui-stats. Leftovers: `earlyNote` (`root.zig:654`, legacy `.note`); a role-icon sprite nothing uses (`tierlist.zig:266`) |
| `/champions/<c>[/<r>]` | New | `champion.zig:48` → ui.champpage, ui-champion/champbuild/champmore |
| `/matchups` | New | `finder.zig:31` → ui.finder, ui-finder + ui-findergrid |
| `/matchups/<r>/<a>-vs-<b>` | New | `matchup.zig:141` → ui.matchpage, ui-matchup/matchmore/champbuild |
| `/pool` | New, one legacy bit | `pool.zig:118` → poolpage + poolgrid; footnote uses the legacy scope chip (`pool.zig:141-151`) |
| `/pickup`, `/pickup/<r>` | Mixed | `pickup.zig:46`: server-only ui, no island; the h1 and scope chip are tpl (`:53`). Its doc says "lean on purpose" |
| `/patch`, `/patch/<cur>` | New | `patch.zig:119` → ui.patchpage, ui-patch. "No earlier patch" fallback is tpl (`:112`); unused role-icon sprite (`:145`) |
| `/learn` | New | `learn.zig:15` → ui.learnpage, ui-learn |
| `/daily`, `/daily/<n>` | New | `daily.zig:23/49` → dailypage + dailydays; "No puzzle today" fallback is legacy (`:36-38`) |
| `/game` (unlisted) | New | `yourgame.zig:75` → ui.gamepage, ui-games/gamemore/gamelane |
| `/games` (unlisted) | New | `yourpage.zig:19` → yourlookup/yourviews/yourtime/YourList, ui-your + ui-yourviews (+ lazy yourtime, yourlookup) |
| **`/your`** | **Legacy** | `your.zig:11` + `review.js` + `your.js` + `chart.wasm` |
| **`/method`** | **Legacy** | `prose.method` + `evalchart.section` (tpl SVG), `root.zig:596,616` |
| **`/download`, `/privacy`, `/terms`** | **Legacy** | `prose.zig` via `root.zig:597-600` |
| **`/login`, `/signup`, `/join`, `/account`** | **Legacy** | `account.zig` + `account.js` (`root.zig:601-604`) |
| **404** | **Legacy** | `root.zig:627` `renderNotFound` (tpl, `.prose`) |
| **`/admin/`** | **Legacy** | `admin.zig:94` → admin.js, admin-nn.js, admin-accounts.js, admin-draft.js, admin-setnet.js, admin.css, data.json. It also writes admin.bin, which no page reads yet |
| `/admin/notes(.html)` | New | `notes.zig:40` → ui.noteslist, ui-notes |
| **`/p/` (index.html)** | **Legacy** | `admin.zig:391` → admin.js PRIVATE mode + admin-draft.js + admin-setnet.js + admin.css, and pv.js |
| `/p/tester.html` | New, unlinked | `tester.zig` → testerpage + testercand. Nothing links to it: `account.js:15,35` and the menu link point at `/p/` |
| `/gallery` | New, dev only | `serve.zig:326` |

**The shared page shell is still legacy on every public page.** `html.zig:134` `head`/`foot` is a tpl template. Only the header bar is new (ui.site, `:186`). Still legacy inside it:
- the champions tabs and the region/period/rank switches (`html.zig:295-389`): tabs on every Champions-section page, switches on `/matchups`, `/pool`, `/pickup`, `/patch`;
- the preview banner, the footer, and three inline scripts (remember, meio_view, admin_link, `:175-258`);
- the link to print.css, and search.js.

`<body>` has no `ui` class.

## 2. `src/site/static/`

| File | Loaded by now | To delete it |
|---|---|---|
| your.js, review.js | `/your` only (`your.zig:87-88`). Home no longer loads review.js | Move `/your` to the new page (§5). Remove them from `root.zig:381-382` and the test at `write.zig:256-257` |
| **table.js** | **Nothing.** Its only user is `learning.zig:103`, which nothing imports | Delete now: `root.zig:383`, `pipeline_test.zig:281,584-587` |
| account.js | The account pages (`account.zig:21,40,60,90`) | Rebuild those pages as ui; `pipeline_test.zig:597` |
| search.js | Every page (`html.zig:166-172`, hashed). Header suggestions plus closing the region picker | A ui island for the header search (ui/champsearch.zig already has the matching logic), and the subbar redone | **Done: S2 (subbar) and S3b ef4d4e13 (ui-sitesearch island); search.js deleted**
| pv.js | Private logins, loaded by `admin_link` (`html.zig:245`), written by `admin.zig:422`. Its champion-page part already targets the new page. **Its matchup part looks for `.hero` (`pv.js:80`), which the new matchup page doesn't render, so it no longer shows** | Fix or port the matchup line. Could stay as private-only JS |
| admin.js, admin-nn.js, admin-accounts.js, admin.css | `/admin/` (`admin.zig:196-226`); admin.js and admin.css also `/p/` (`:401-421`) | A7 plus T6 |
| admin-draft.js, admin-setnet.js | `/admin/` Draft tab and `/p/` | T6 |
| print.css | Every page (`html.zig:145`). The file is only a comment, kept as `deploy/traffic.sh`'s person beacon (`traffic.sh:9,89`) | Move the beacon to something else first |

Related build outputs:
- **`meiolol.wasm`** (`src/wasm.zig`, `root.zig:138,143`, `build.zig:360-372`): **no page or script loads it. Dead now.**
- `chart.wasm` (`chart_wasm.zig`, `build.zig:376-390`, `root.zig:144`): only review.js loads it (`review.js:56`).
- `data/your-example.json`: only your.js reads it (`yourgame.zig:31`).

## 3. Legacy CSS (`static/style.css`, bundled as `@layer legacy` by `style.zig:28`)

**Already dead (no writer emits these):**
- Daily Draft `.dd-*`, `.dd .bans`, `.dd .team`, `:569-728`. Zero references anywhere.
- `table.lanes` (`:342-349`), `.archive`, `.min-games`, `.lane-mini`, `.muted-tag`, `.build-list`, `.hidden-slot`, `.side-0/1`, `.question`/`.choices`, `.stats`, `.card ul.also`, `table.build` and `.tags`/`.key`/`.rx`/`.rc` (`:732-744`).
- `.bx`/`a.box` (`:67-75`; only from `root.champBox`, which only dead `learning.zig` calls).
- `table.tl` and `table.tiers` (`:258-288`, the phone rules `:321-341`). ui/tiers uses `.c-tiers` now; only dead `learning.zig` emits `tl`.
- `svg.ri` and `.tabs a .ri` (`root.roleIcon` has no callers), `.wrc` (`tierlist.wrText`, only learning.zig).
- `.featured` and `.k` legend keys (`:554-568`; `matchup.featured` has no callers).

**Used only by `/your` (goes with the switch):**
- Game review `:380-468` and `:746-764`, Your games `:470-512`, `.mini-list` `:514-518`, the related media rules `:520-542`.
- Shared surfaces `.panel`, `.panel-h`, `.search`, `.sub-links`, `.sec-h` (`:351-378`), `.tabs` (`:136-143`), `.verdict`, `.champ-row`, `button.link`, `.spark`.
- Lane chart `.chart` (`:217-233`), drawn through chart.wasm.

**Still live:**
- `@font-face` (`:1-4`): `style.zig:28` fails to compile without it, so move it into the ui head first.
- The `:root` colours (`:5-50`) duplicate `ui/tokens.zig` and can go.
- Element rules on body, a, h1-h3, table/th/td, input, button (`:51-66`, `:126-149`, `:177-192`).
- `.wrap` and `main.wrap`; `.look-list` (search.js); subbar, switches and region picker (`:91-123`).
- `.note`, `.muted`, `.small`, `.lead`, `.prose`, footer, `.preview`.
- `.scope` (`:543-552`, used by pool and pickup), `.evalchart` (`:305-317`, method page), `.auth-form` and `button.primary` (account pages).

**Watch out:** the layer order is tokens, base, legacy, components. Legacy beats `base.css`, and its unscoped rules also hit new markup that reuses the same names. ui nodes have class `note` (19 places), `tiles` (highlights, learnpage), `team` (gamescreen, loadscreen), `hero` (home), and also `grid`, `lane`, `notes`, `scope`, `card`, `pill`, `num`, `muted`. Deleting a "dead" section can still change how new pages look, so each deletion needs a visual diff.

## 4. Old Zig writers in `src/site/`

**Dead already (nothing calls them):**
- `learning.zig`, the whole file (no importer).
- `matchup.zig:418-670`: featured, summary, amount, signed, chartOne, caption, surrender_minute, and probably `range` (no callers found). Once these go, matchup.zig no longer imports lanechart.
- `root.zig`: `champBox:356`, `roleIcon:686`, `pct:642`, and `roleIcons:675`, whose sprite tierlist and patch still write but nothing uses.
- `tierlist.wrText:95`; `html.zig`: `lookup_submit:310`, `logo:315`, the live branch of `pick()` (`:363`).

**Go with their pages:**
- `/your`: `your.zig`; `lanechart.zig` + `chart_wasm.zig` + chart.wasm; `yourgame.files`' stripped example JSON (`:31`).
- Prose and method pages: `prose.zig`, `evalchart.zig`.
- Account pages: `account.zig`.
- 404: `renderNotFound`.
- Pool and pickup chips: `scope.zig`.
- The shell (`html.zig` head/foot/subbar/switches) once it becomes a ui tree.

**tpl:** the page templates can all go, but the tpl module can't: `ui/html.zig:6` uses it for escaping and URL checks.

## 5. `/your` (legacy) vs `/games` (new)

`/games` has the list, lookup by `#id=`, polling, Highlights and Over time. To make it `/your`, `renderShared` would serve yourpage for `.your` and drop `.games`. What is still missing or blocking:

1. **Remove my data (`/api/forget`).** `docs/legal/lia.md:136` requires an objection route open to anyone, so this cannot be dropped. Only your.js has it (`your.js:722-790`). The plan's dialog version (your-games.md "Remove my data") isn't built.
2. **Friends** (`/api/friends`): parked as "with D" (notes your.md:66-69). It is the only Friends view.
3. **Check for new games** (`&refresh=1`, `your.js:282`) and **Not you?** (`:793`). PlayerBar has a slot for them (`playerbar.zig:23`) but nothing is wired. The lookup only says "Reload the page to check again".
4. **The `your-recent` localStorage list.** Only your.js writes it (`your.js:119-172`), and Home's recent-ID list reads it (`homepage.zig:410`). The new page must write it or Home's list stops filling.
5. **No Riot ID box on `/games` itself.** The plan moves it to the header search, which already handles Riot IDs, so this may be acceptable.
6. Links and `&game=`: the header (`html.zig:203`), `search.js:149`, `idlookup.zig:120,128` and `gamepage.all_games` (`gamepage.zig:35`) all send `/your#id=…[&game=…]`. That keeps working if `/your` becomes the new page, but `game=` needs handling or ignoring.
7. Review nits 1, 3, 5, 7 and 6a from the cadf5b27 review are open (your.md:173). ui-yourtime has about 2.5 KB of its 40 KB budget left.

Not blockers: the API is on C01 (your.md:134-140), and your.js's preview sign-in path is obsolete because nginx `/api/` has no auth now.

## 6. Admin and Draft tester

**Admin, landed:**
- A1 data: 20db56f4, review fixes 35ed6a91.
- A2 components: AlertBand + ActionButton (030e666b, f293e47b), LogView (5e0dd584), StepTimeline (3e6cc778, ce31b8fe), TimeChart (523cee79, d25b9446, 94fead39, 0371188b), Prose (45c33f8f, 196c3733, 3878a212, 1b7f6f46), toggle events (b3b4e40a).
- Side items: the /admin/notes list (a8dc5af3), the old header's Notes link (97085484).

**Admin, left:**
- Prose leftovers SF4, SF6, SF7 and nits 6-7 (admin.md "Next 0").
- A3 to A7: there is no `ui/adminpage.zig`, no `admin` family in `build.zig:402`, no `/admin/new.html`, no dev route, and no `--training`/training.bin.
- A7 itself: switch over, then delete admin-nn.js, admin-accounts.js, the JSON writers, admin.js and admin.css.

**Tester, landed:**
- T1: e6bbe6a1, 6d8a7773.
- T2: 0abc3578, 4e6c45e8, 77c93dd8.
- T3: 14e82109, e80f952e.
- T4a: b10fa494, a923a57d, plus review fixes 2fb1562a and 810c85bc.
- The 64 KB budget for private families (`build.zig:407-409`).

**Tester, left:**
- T4b (bans, lane pair and seat terms), T4c (lane Gold column), review nits 4 and 7.
- T5 (Compare, set net in wasm, fill presets, undo, phone).
- T6: point `/p/` at the tester; delete admin-draft.js, admin-setnet.js and admin.js PRIVATE mode; make admin's Draft tab a link. Also update `admin.js:2508`, which writes the menu's `admin-link` as `…#models/draft`.

## 7. URLs and remaining .html

**URL4 (302 → 301), due 29 Oct ~06:00 UTC.** Places to change:
- `deploy/nginx/meiolol.conf:131-133`;
- `src/serve.zig:363,407` (`.found`) and `:415` (lowercase fix, also 302);
- `deploy/url-smoke.sh:4,8` (default `STATUS=302`);
- docs: `arch-site.md:19`, `hosting.md:84,88`.

Also, the comment at `serve.zig:361` names `deploy/nginx/meiolol-redirects.conf`, which doesn't exist; the rules are inline in meiolol.conf (`:65-86`).

**nginx:** the only `.html` left is the intended legacy map (`meiolol.conf:65-86`) and `redirect-samples.tsv`.

**`.html` links still in code:**
- `admin.js:610` `/login.html` and `:785` `/account.html`: public pages, they work only through the 302. Change them to `/login` and `/account`.
- Allowed under the plan (admin and `/p/` keep .html): `admin.js:781` `notes.html`, `ui/notes.zig:120` `/admin/notes.html`, `/p/tester.html`, and `index.html` under `/admin/` and `/p/`.
- Stale but harmless: the test fixture `champion/c2.html` (`pickup.zig:218,232`), gallery demo links `game.html#g=0` (`ui/gamerow.zig:243-257`), and doc comments naming game.html/games.html/your.html (yourgame.zig, yourpage.zig, ui/yourlookup.zig, `deploy/web-loop.sh:42,238`).
