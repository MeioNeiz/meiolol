# Plan: professional URLs (J32)

Every page on clean, extensionless URLs (done: URL1-URL5). Jacob chose the hierarchy and
approved the five additions below (J32). Old URLs get no redirects and never shape a new
one (Jacob, 29 Oct: no URL made worse to match an old one, no complexity for them).
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

## Steps

- URL1-URL4 (done 28-29 Oct): ui/urls.zig spells every page's URL and reads it back;
  the generator, wasm, nginx and serve.zig on the scheme; old-URL redirects removed 29 Oct
- URL5 (done 29 Oct): /admin and /private (was /p/) without .html, no redirects from
  the old paths
- URL6 (done 30 Oct): /p/desktop/ and /admin/desktop/ gone, no release first (Jacob: no
  one uses the app yet; an old install reinstalls from the private site). Released exes
  (last 0453f11, 23 Oct) still check /admin/desktop/ and now get 404, which they only
  log. From the next release (checks /private/desktop/), a 404, 410 or redirect says to
  get the new version at meio.lol/download; other failures back off 5 min to 3 h
- Checked 30 Oct from C01: the application text (submitted and revised) and
  production-key.md quote only meio.lol and privacy@meio.lol; every page they name
  (/, /your, /daily, /learn, /pool, /champions, /matchups, /patch, /method, /privacy,
  /terms, /download) answers 200

## Risks

- Shared desktop shell test paths (shell/channel.zig) and qa.mjs page list
- The production key application must quote today's URLs
