# Legacy UI removal (28 Oct): coordinator meiolol-4b (was d6, 6a), 2 workers

Goal: every page on the new UI, then delete the `legacy` CSS layer, style.css and the old
templates. What's legacy and where: inventory.md here (read your sections, cite its lines
but re-check, the tree moves).

## Jacob's calls (28 Oct)
- Token efficiency first: 2 workers, short messages, no waiting on review
- Your games: /your switches to the new page only once Friends, Remove my data, Check
  for new games, Not you? and the your-recent list are all in (no regression)
- Tester: /p switches to the new tester only after T5 (not at T4b)
- Private URLs: /admin (no .html, /admin/notes etc.) and /p renamed /private (no
  .html); old paths 301 (URL5)

## Rules
- Before a page: docs/frontend.md, its docs/plan/ui/<page>.md, and the old run's notes
  (data/team/2026-10-25-ui-build/notes/<page>.md, page-<page>.md)
- Shared checkout: edit only your files; commit by path (deploy/commit.sh), push the
  tested sha (deploy/push.sh <sha>, run_in_background), never wait-deployed. Check pages
  on deploy/dev.sh (localhost:8080), 1800 wide dark and 360
- Deleting old CSS: legacy rules hit new markup through shared class names (note, team,
  card, tiles, grid, lane, scope, pill, num, muted): screenshot affected pages before and
  after
- Plan docs say what is true now: update the page's plan doc as stages land
- Messages to the coordinator: "done: <sha> <one line>", "blocked: <why>, <path>",
  "question: <path>". Details in notes/<you>.md. Coordinator reads commits; findings
  come back as a message, fix in a follow-up, don't stop for it
- Context: hand over at ~200k at a natural break (step committed): notes/<you>.md, then
  `cc-handover --new`. Tell the coordinator the new name. A successor reads notes/<you>.md
  and only the docs its next step needs, not the predecessor transcript (lean start)

## Ownership
- Coordinator: lane 0 dead code (table.js, meiolol.wasm, learning.zig, dead matchup.zig
  and root.zig fns, dead style.css sections, inventory §3/§4 "dead"), URL4 (29 Oct
  06:00 UTC), the final delete of the legacy layer
- W1 (meiolol-03, was 95, 31) public: (1) Your games to /your (inventory §5; Friends parked "with D" in
  notes/your.md: build it), delete your.js, review.js, chart.wasm, lanechart.zig,
  chart_wasm.zig and the Your games CSS; (2) shell as ui (html.zig head/foot, tabs,
  switches, banner, footer, inline scripts, a header search island replacing search.js;
  ui/champsearch.zig has the matching), then method, download, privacy, terms, 404,
  login/signup/join/account onto it (account.js, prose.zig, account.zig, evalchart.zig
  go); pool/pickup scope chips; (3) Daily notes 33 (gap under the days strip) and 34
  (guess card onto new components; ui-daily.wasm is ~40.9 of 40.96 KB gz: split the
  family first). Owns html.zig, style.css (after lane 0 lands), account.js
- W2 (meiolol-3a, was da, 52) private: admin prose leftovers then A3-A7 (notes/admin.md) and the switch-over;
  tester T4b, T4c, T5, then T6 (notes/tester.md); pv.js matchup line (looks for .hero,
  pv.js:80); URL5 (/admin, /private, 301s, admin.js .html links; /p/ links in
  account.js and html.zig admin_link: ask W1 or send a patch path). Owns admin.zig,
  tester.zig, admin*.js/css, pv.js, the admin and tester ui families

## Log
- 28 Oct 16:5x: W1 = meiolol-95 (pane 1469), W2 = meiolol-da (1470), both --effort high; d6 on lane 0
- 28 Oct 17:xx: W2 adds .bin twins to src/api/accounts.zig + src/site/ui/accountsdata.zig (A3); W1's account pages extend the same (login, join, signup, password, devices, revoke). W2 c9e836bf prose leftovers
- 28 Oct (W2): /auth/NAME.bin (ui.data in and out, errors JSON) for me, logout, accounts, invite, role, disable, reset; wire types src/site/ui/accountsdata.zig. W1's login/join/signup/account pages extend it (add the route to the .bin switch in accounts.zig route(), its types to accountsdata.zig)
- 28 Oct 17:xx: ctx check (scratchpad ctx.sh): 95 190k, da 237k. Rule: hand over at ~200k. W2 handed over: meiolol-52 (pane 1483)
- 28 Oct 17:xx: lane 0 committed from a clean worktree (shared tree has W1/W2 WIP that breaks the build: test your commits the same way when the tree is red)
- 28 Oct 18:xx: 9597fa50 lane 0 dead code (on top of W1 ee28f6be), pushing. W1: style.css free for you now
- 28 Oct 18:xx: W1 handed over: meiolol-31; Y2 (Remove my data, ui-forget) WIP in the tree
- 28 Oct 18:2x: box rebooted 15:51, Megatron CIFS mount failed at boot (host unreachable) so /srv/meiolol never came up; every deploy since 17:17 failed. d6 started srv-megatron mounts + meiolol-disk, re-ran deploy/on-push.sh. 367b9388 (W1 Remove my data) noted
- 29 Oct: e105ad85 (W2 A3 /admin/new.html, .bin twins in accounts.zig) accepted on a read (auth path unchanged; session cookie SameSite=Lax covers cross-site .bin posts). 52 at 273k: told to hand over
- 29 Oct: W2 handed over: meiolol-3a (pane 1501). ctx: 31 166k
- 29 Oct 08:3x: d6 at 182k, handing the coordinator role over (notes/coord.md); URL4 next
- 29 Oct 08:4x: coordinator now meiolol-6a. URL4 679c3c00: nginx installed on C01 (backup /etc/nginx/meiolol.conf.bak-20261029-url4), url-smoke all 301, /p/ gate still 302; serve.zig part ships with the push
- 29 Oct 09:1x: e3e6147d (W2 A4a admincharts island) accepted on a read. deploy/admin-get.sh is stale: /admin is now account login (302 to /login), the script sends basic auth; no check account in the vault. Asked Jacob
- 29 Oct 09:2x: 93b5b15c (W1 Friends, /api/friends.bin: same opt-out checks as the JSON) and 1ec06cf2, 42b5e91a (W2 A4b) accepted on a read. W1 = meiolol-03 (pane 1516), on Y4. W2 = meiolol-3a (fresh session, same name), on A4c Traffic (own family ui-admintraffic)
- 29 Oct: Jacob: sessions test admin pages themselves. Account meiolol-check (admin) on C01, password vault meiolol/local MEIOLOL_CHECK_PASSWORD; deploy/admin-get.sh PATH now signs in with it (runs curl on C01). Use it for logged-in box checks
- 29 Oct 10:4x: coordinator now meiolol-4b (Jacob via 5a: one team). Run continues in
  data/team/2026-10-29-next/common.md (W3 added; next lanes for W1 and W2 there)
- 29 Oct 09:3x: 424e198e admin-get.sh signs in as meiolol-check, pushed. Jacob: one team; meiolol-4b coordinates everything incl. this run (workers meiolol-03, meiolol-3a). 6a handed over (notes/coord.md)
