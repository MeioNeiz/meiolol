# Plan: professional URLs (J32)

Every page moves to clean, extensionless URLs; every old URL 301s straight to its new
one. Jacob chose the hierarchy and approved the five additions below (J32). Build after
the notes run (data/team/2026-10-27-notes), one owner: every page's hrefs change.
Evidence: research/questions/site-url-scheme.md (Google docs, RFC 9110, six LoL sites'
filter URLs and canonicals). Any URL work follows this file; change it here first.

## Scheme

- Lowercase, hyphens, no .html, no trailing slash (strip with 301), 301 not 308 (equal
  for Google; nginx `permanent`)
- /, /champions, /champions/<champ>/<role>, /matchups, /matchups/<role>/<a>-vs-<b>,
  /daily, /patch, /learn, /pool
- Bare champion = main role: /champions/karthus serves the main role, self canonical
  (u.gg, mobalytics); /champions/karthus/<main role> 200s with canonical to the bare
  URL, other roles self canonical. Canonical, not redirect: the main role moves between
  patches and browsers cache 301s forever. A thin role (under min_role_share, linked from
  tier rows and role tabs) has no file: rendered on request, canonical to the bare URL,
  not in the sitemap; a role with no games 404s
- State: query = which data (region, period; rank, queue later): shareable, the server
  can serve a prerendered view, canonical drops it (op.gg, u.gg, mobalytics, Blitz).
  Fragment = in-page state (sort, tab, slot, puzzle) and identities that must not reach
  the server or logs (Riot IDs on /your, /game). Google ignores fragments
- Role lists /champions/<role>; a test that no champion slug is a role name
- Patch diffs /patch/<cur> with hyphens (/patch/26-21): a dot reads as an extension to
  std.fs.path.extension (serve.zig) and the notes-hop asset map
- Views leave the path: /patch/, /all/, /all/patch/ prefixes become ?period=patch,
  ?region=all
- Not taken: lolalytics' trailing slash and self-canonical filters; League of Graphs'
  filters as path segments; matchups under the champion (/matchups is its own section,
  `a-vs-b` mirrors the search)

## Old to new

| Old | New |
| --- | --- |
| / and /index.html | / |
| /champions.html, /role/<r>.html | /champions, /champions/<r> |
| /champion/<c>.html (#role=r) | /champions/<c>; wasm turns #role=r into /champions/<c>/<r> |
| /build/index.html, /build/<c>-<r>.html | /champions, /champions/<c>/<r> |
| /matchup/index.html, /matchup/<r>/<a>-vs-<b>.html | /matchups, /matchups/<r>/<a>-vs-<b> |
| /daily.html, /daily/<n>.html | /daily, /daily/<n> |
| /patch.html, /patches/<cur>-<prev>.html | /patch, /patch/<cur> |
| /pool.html#pool=X | /pool; wasm turns #pool=X into ?champs=X |
| /learn.html#p=id | /learn; wasm turns #p=id into #id |
| /pickup.html, /pickup/<r>.html | /pickup, /pickup/<r> |
| your, games, game, method, download, privacy, terms, login, signup, join, account .html | same name, no .html; #id=, #game=, ?next= kept |
| /patch/X, /all/X, /all/patch/X (old views) | new(X) + ?period=patch, ?region=all, both |
| /sitemap.xml per view | one /sitemap.xml, canonical URLs only |

/admin/ and /p/ (private, noindex) keep .html for now (not in URL2). The server never
sees fragments; a 301 keeps them (RFC 9110 10.2.2), so the new page's wasm translates
legacy keys with replaceState.

## Steps

- URL1 (done) src/site/ui/urls.zig (in ui: ui/*.zig and the wasm spell hrefs too; site
  reaches it as ui.urls): `Page` spelt with `{f}` and read back by `parse`, `Data` the
  query, `legacy(old) ?new`; the pipeline test maps every page the fixture site writes;
  loadChamps refuses a champion slug that is a role name. Nothing calls it yet
- URL2 (done 28 Oct) one push, done when every old URL on dev.sh lands on the right
  page with its state:
  - Generator: root-relative hrefs (drop toRoot, toShared, toSite, View.up/dir/query;
    the 404's ../); canonical absolute without query; one sitemap with lastmod;
    per-role champion files; view copies in an internal /_v/<view>/ tree; every ui/*.zig
    href; pipeline_test.zig page list and hrefs
  - wasm and JS: url.zig/island.zig query keys beside the fragment; champion.zig fold
    inverted (fragment to query); legacy translation (champion, pool, learn); pv.js
    matchup regex, search.js, gamesrc.zig, dailydays.zig, your.js; champpage's
    `pool.html#slug` (no pool= key)
  - nginx: redirect include before try_files (regex rules mirrored by urls.legacy); slash
    strip; `location = /index.html` becomes internal; `map $arg_region:$arg_period` to
    the view tree; proxy_cache_key adds the view (else @render serves the wrong view);
    host 308 stays
  - serve.zig: drop the add-a-slash dir 301; lowercase 301 on a miss when that page
    exists
  - Smoke script: curl old samples on C01, expect each Location
- URL3 (done) notes: notesdata.canonical = urls.legacy then the index strip; migrate
  stored rows once through the Zig function (not SQL LIKE), legacy hash keys too
  (urls.moveState). traffic.sh joins old and new paths through the map (`meiolol urls`)
- URL4 (done): old URLs and the lowercase fix 301

## Risks

- Relative links count depth: a partial move breaks data-src ../; all at once (URL2)
- Shared desktop shell test paths (shell/channel.zig) and qa.mjs page list
- The production key application quotes meio.lol URLs: they keep working via 301;
  update the text only if it is resubmitted. noindex in preview: no ranking at risk
