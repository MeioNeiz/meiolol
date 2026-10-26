# Plan: move to the Essex VM

Everything off Oracle Cloud onto C01, a VM Ethan (Burnt Water) lent: crawler, builds,
renderer, nginx, Your games API, admin. Visitors reach it through a Cloudflare Tunnel
(meio.lol's DNS is already on Cloudflare; token vault personal/cloudflare), so nothing
opens on Ethan's router. Why: the box fills in about 3 weeks at ~3.6 GB a day (78 GB free
on 26 Oct), and its 2 cores sit at load ~3. The move replaces the Hetzner BX11 order
(ops.md "Storage and hosts").

## C01 today

- ssh alias `essex-vm` (user jacob, key ~/.ssh/essex_vm), Tailscale 100.95.95.44 on
  Jacob's tailnet (MeioNeiz@github), direct from the Mac. Sudo asks for the password
  (from Ethan's note; goes into vault meiolol/essex-vm)
- KVM, 8 vCPU shown as "QEMU Virtual CPU" (no AVX2 until the CPU type is host), 15 GB,
  Ubuntu 24.04 x86_64, 60 GB disk (45 GB free). box.sh builds for `uname -m`, so
  x86_64-linux-musl with no change
- Network shares, CIFS, both mounted `soft`: /mnt/storage (Essex Storage, 192.168.18.12,
  14.5 TB free) and /mnt/jacob (Megatron, 192.168.18.54, 3.1 TB free)
- Measured 26 Oct (Python, O_DIRECT, 2 GB file; SQLite test 2.8 GB WAL db, writer of
  20-game commits with 2 readers, then cold scans):

| | 4 KB random read | seq read | commits/s, p50 | lookups/s beside writer | cold scan |
|---|---|---|---|---|---|
| local disk | 0.2 ms | 766 MB/s | 359, 1.3 ms | 5,528 | 176 MB/s |
| Megatron share | 1.0 ms | 347 MB/s | | | |
| ext4 image on Megatron | 1.15 ms | 270 MB/s | 13-15, 43-54 ms | 170-221 | 61-71 MB/s |
| Essex Storage share | 6.6 ms | 52 MB/s | | | |
| the box (research) | ~0.7 ms | cap 72 MB/s | | | |

- SQLite in WAL (src/store/schema.zig) can't live on a share (its -shm is mapped by every
  process); an ext4 image on a share, loop mounted, works but is no faster than the box

## Steps

### VM0: Jacob's choices

- Disk: (a) Ethan adds ~500 GB on the same storage as C01's own disk (best: ~25x the
  image's lookups) or (b) a loop mounted ext4 image on Megatron with lvmcache on ~35 GB
  of the local disk (VM1b tests it). Asked of Ethan: the disk and CPU type "host"
- jomove: stays on jomify (free, untouched) or moves too
- Standby: how long the Oracle box stays stopped but kept before it is terminated
- Privacy wording: "a server in the United Kingdom" (src/site/prose.zig "Where it is
  kept"); Ethan has admin on C01 and the shares, so can see player data

### VM1: storage

- (a) New disk: ext4, mounted `noatime,nodiscard` at /srv/meiolol, fstrim.timer weekly
  (hosting.md: online discard starves the crawler's commits)
- (b) Image: first mount the Megatron share `hard` instead of `soft` (a NAS pause must
  stall writes, not fail them into ext4), then VM1b
- VM1b: lvmcache, writethrough, a ~35 GB cache file on the local disk in front of the
  image; rerun the 26 Oct SQLite test (scratch copy in this session; keep it in
  deploy/ if it decides). Done when: within ~2x of local disk on lookups beside the
  writer, else back to (a)
- ~/ml/meiolol lives on that disk (symlink from home). Backups/ to Megatron later (VM8)

### VM2: base host

- Unattended upgrades, lingering for jacob (box.sh's user units), UTC, journald limits,
  ufw: ssh on tailscale0 only. Tailscale on the box (for the copy) and on the gpu-box
  WSL (its mirror and archive pulls)
- Done when: `MEIOLOL_HOST=essex-vm deploy/box.sh status` answers

### VM3: backend on a copy, crawler off

- `MEIOLOL_HOST=essex-vm deploy/box.sh` sync: binary, scripts, units; crawl.args with
  `--proxy 127.0.0.1:8092` (or the API's address) instead of 10.0.0.3
- First copy of data/ from the box over Tailscale, crawler still running there
  (rsync; a live db copy is only for testing), plus .env, contact, riot.txt, host.env,
  desktop-data.key, desktop.token, release/
- Never two crawlers: the key's rate is per key, so meiolol-crawl stays disabled on C01
  until VM6
- Run the web loop, a views write and the renderer on C01; compare times with the box's
  views.log. Done when: pages render on C01 from the copy

### VM4: web side on C01

- nginx with jomify's conf.d/meiolol.conf and its include files
  (meiolol-admin-token.conf, meiolol-api.htpasswd, meiolol-desktop-key.conf,
  meiolol-version.conf), adapted: upstream 127.0.0.1:8091, `geo $meiolol_from_box`
  127.0.0.1, http on localhost behind the tunnel (TLS at Cloudflare)
- limit_req keys on $binary_remote_addr: behind the tunnel every request is 127.0.0.1,
  so real_ip from CF-Connecting-IP first, else one visitor's burst limits everyone
- The jomify users and keys (meiolol-web, meiolol-exchange, meiolol-cache,
  meiolol-accounts, meiolol-training; rrsync and forced commands) recreated on C01 with
  the box's ssh aliases pointing at localhost: no script changes for the move. Folding
  them into plain local calls is Later
- `deploy/jomify.sh install api|traffic|cache-version|training-receive|accounts-send`
  with its host pointed at essex-vm; traffic.sh's system units; logrotate
- cache-warm.sh: `--resolve meio.lol:443:10.0.0.214` becomes the local nginx
- cloudflared as a system service; tunnel on a test name (vm.meio.lol) first
- Done when: on vm.meio.lol every page type, admin login, Your games, a desktop
  download, the training view, traffic counting and an nginx cache STALE/ANY-HIT work

### VM5: mirrors and the Mac

- backup-mirror.sh, archive-pull.sh, accounts-pull.sh: their box aliases on the Mac and
  the gpu-box point at essex-vm over Tailscale; lab-push.sh to C01's training user
- box.sh default HOST, on-push.sh, mac-watch.sh, deploy-events.sh, dev.sh,
  desktop-release.sh: meiolol-cloud becomes essex-vm (grep them)
- Health alerts reach Jacob from C01 (health-loop.sh)

### VM6: cut-over

- Push mode off, no deploys. On the box: stop crawl, web, render, backup, health;
  checkpoint, final rsync of data/ (minutes, deltas only). On C01: enable everything,
  crawler last
- Cloudflare: meio.lol and www to the tunnel (proxied); meiolol.jomify.lol stays on
  jomify or 308s to meio.lol
- Rollback: DNS back to 193.123.180.81, start the box's units; data since the cut-over
  copied back first if C01 crawled
- Done when: a day on C01 with crawl at ~97-100% of the key, a full web round, a backup
  mirrored, the cache-warm run complete

### VM7: docs and policy

- hosting.md rewritten for C01 (this file's C01 today moves there), CLAUDE.md "Hosts",
  docs/data-safety.md, docs/compute.md; privacy page per VM0; privacy-rules.md and the
  production-key text if they name Oracle

### VM8: Oracle wind-down

- Box stopped (not terminated) for VM0's standby, then terminated; the OCI quota and
  budget guards stay. jomify per VM0
- Megatron as the off-site backup target (3.1 TB): the box's ~30-day window plan and
  the Hetzner BX11 order drop

## Risks

- One machine, on Ethan's network and power: an outage takes the site down. The tunnel
  plus Cloudflare caching covers short ones less well than jomify's nginx cache did
- Ethan's hardware and goodwill: keep the Oracle setup restorable until VM8, and the
  gpu-box mirror current

## Later

- `-Dcpu` for C01's real CPU once its type is host
- Plain local calls in place of the localhost ssh aliases (VM4)
