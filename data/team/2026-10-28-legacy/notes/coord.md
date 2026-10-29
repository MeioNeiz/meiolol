# Coordinator notes

Read common.md first (rules, Jacob's calls, ownership, log). This file: what the
coordinator does next and how.

## Next
Coordinator: meiolol-4b (one team, Jacob 29 Oct). Workers: W1 meiolol-03 (Y4: /your onto
yourpage, /games to /your, legacy Your games files out), W2 meiolol-3a (A4c Traffic: own
lazy family ui-admintraffic, /admin/api/traffic.bin).
1. Reviews: everything up to 424e198e read and accepted; no findings outstanding.
   Watch-items: W2's ui-admincharts is 61.0 of 64 KB (private budget); the shared tree
   was red at 09:5x (W1's Y4 WIP: static/your.js gone, site/root.zig still embeds it), so
   :8080 can serve an old build until Y4 lands. Left for W2's URL5: admin.js /login.html,
   /account.html links (work via the 301)
2. Admin checks on the box: Jacob says sessions test it themselves. deploy/admin-get.sh
   PATH signs in as meiolol-check (role admin: /admin yes, owner controls no), password
   in vault meiolol/local MEIOLOL_CHECK_PASSWORD, curl runs on C01. Tell W2 it can do
   the logged-in A3/A4 box checks now
3. Lane 0 is done (9597fa50). URL4 done (679c3c00; nginx on C01, backup
   /etc/nginx/meiolol.conf.bak-20261029-url4, url-smoke all 301)
4. Final lane, once W1 and W2 are done: delete the legacy CSS layer and style.css (move
   @font-face into the ui head first: style.zig fails without it), html.zig head/foot,
   prose.zig, account.zig. Screenshot pages before and after (shared class names)
5. Context: hand over at 25-33% (CLAUDE.md now; a hook reminds)

## How
- Shared tree is often red with worker WIP. Commit from a clean worktree: `git diff HEAD
  -- <my paths>` > patch (drop other sessions' hunks), `git worktree add --detach` at
  main, `git apply --index`, run deploy/commit.sh there, then in the main checkout
  `git update-ref refs/heads/main <new> <old>`, `git reset -q -- <paths>`, `git checkout
  -- src/testdata/site-files.txt`; push with deploy/push.sh <sha>
- Deploy failing with `cd: ml/meiolol/data: No such file`: the box rebooted and the
  Megatron CIFS mount failed at boot. Fix: `vault get meiolol/essex-vm SUDO_PASSWORD |
  ssh essex-vm 'sudo -S -p "" systemctl start srv-megatron.mount
  srv-megatron\\x2dbackups.mount meiolol-disk.service'`, then deploy/on-push.sh. Jacob
  was offered a durable retry fix (box change, not done)
- Context per session: `data/team/2026-10-28-legacy/ctx.sh meiolol-31 meiolol-3a <you>`
