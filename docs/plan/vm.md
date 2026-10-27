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
- KVM, 16 vCPU of a Xeon E5-2630 v3 (CPU type host since 27 Oct: AVX2, builds at
  x86_64_v3 from box.sh's host_target), 62 GB, Ubuntu 24.04 x86_64, 60 GB disk (14 GB
  free; data is on /srv/meiolol)
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

## Running it

One dedicated session runs VM1-VM8 back to back, each step starting when the last is
done, without asking (J31); the coordinator (meiolol-8b) watches it and hands it over
when its context fills. Decisions inside a step are the session's; Jacob only for
what needs him off the keyboard (`cc-note needs`): the gpu-box Tailscale login link,
Ethan's CPU type. VM6 runs by itself once VM3's benchmark is under 2x the box.

VM6 done 27 Oct 06:34 UTC: meio.lol and www on C01's tunnel, C01 runs crawl, web loop,
render, backup, health, API; the Oracle box's units stopped and masked (kept, not
terminated); the Mac's scripts default to essex-vm. VM3 results on C01:
~/vm-chain/results.md (core build 1.7x, views write 1.9x the box, render p50 8 ms).
After CPU type host and 62 GB, AVX2 build, crawler and site live (~/vm-chain/bench-after.md):
core build 222 s (box 287), site step 202-230 s, render p50 13 ms p95 22 ms at load 4-13
with the page cache refilling after the reboot (IO pressure ~10%); measure render again.
Left: push mode back to fast (Jacob), the gpu-box step (`deploy/vm-cutover.sh` again
once it is on Tailscale), bench-crawl.sh seed on C01 (base db not created), then VM7-8.

Migration mode, set 26-27 Oct (undo in VM6, from the new host where moved):
- Deploys held: `deploy/push.sh --mode bulk 1440` (sessions queue, check pages on
  deploy/dev.sh). Undo: `--mode fast` once C01 is the deploy target
- Box: meiolol-web and meiolol-render-swap stopped (the render@b of the 8b25a7c deploy's
  predecessor keeps serving; the deploy's new binary is on disk, unswapped), cache-warm
  stopped, archive pack killed. Running: crawl, render@b, health (alerts "site loop not
  running"), backup
- gpu-box: meiolol-archive-pull.timer stopped (backup-mirror runs). Undo: `systemctl
  --user start meiolol-archive-pull.timer`
- Copy: C01 user units meiolol-copy-{meiolol,timeline,raw,rest}, logs ~/copy-*.log
  ("done" last line). The box's key runs rrsync at `ionice -c2 -n7`. The Oracle to
  Essex route is policed to ~5.8 MB/s in total (3% retransmits on cubic, 16% on BBR for
  the same rate; C01's line takes 28 MB/s elsewhere, the box sends 98). meiolol.db and
  timeline.db go through the Mac instead (box to Mac 82 MB/s, Mac to C01 14): C01 alias
  meiolol-box-mac = localhost:2222, a reverse tunnel the Mac holds (a nohup'd caffeinate
  loop re-opening `ssh -N -R 2222:140.238.101.20:22 essex-vm`, pid
  data/vm-cutover/tunnel-pid; kill it once the copy is done), `--bwlimit=6m` each to
  spare Jacob's upload; each retries 30 times, then goes direct
- Chain: C01 unit meiolol-vm-chain runs deploy/vm-chain.sh (copy at
  ~/vm-chain/deploy/): waits for the copy, catch-up and quick_check, then VM3's
  benchmark; ~/vm-chain/results.md ends "VERDICT: ...". C01 has 8b25a7c's x86 build
  (box.sh sync), no unit enabled
- Then deploy/vm-cutover.sh on the Mac (background) waits for that verdict and runs VM6
  and VM5's switches by itself; state and log in data/vm-cutover/, `cc-note needs` when
  it stops or finishes
- Secrets: vault meiolol/essex-vm (SUDO_PASSWORD, NAS_PASSWORD); `head -1 | sudo -S -p ""
  -v` once per ssh command, then plain sudo (sudo -S per call eats the stdin of what
  it runs)

## Steps

### VM0: Jacob's choices

- Decided (J31): all of meiolol moves, jomify stays for jomove; storage is C01's disk
  plus Megatron; benchmarked on the real data before the switch (VM3)
- Open: CPU type "host" (asked of Ethan); how long the Oracle box stays stopped but
  kept before it is terminated; privacy wording "a server in the United Kingdom"
  (src/site/prose.zig "Where it is kept"; Ethan has admin on C01 and the shares)

### VM1: storage

Built: /srv/meiolol (ext4, `noatime,nodiscard`, 492 GB) on LVM meiolol/data: a 500 GB
image on Megatron (/srv/megatron/meiolol/disk.img) with a 30 GB writethrough cache file
on C01's disk (/var/lib/meiolol/cache.img), loops with direct IO.
/srv/megatron is our own fstab mount of Megatron, `hard,nosharesock` (without
nosharesock the kernel reuses Ethan's `soft` /mnt/jacob session and its options);
credentials /etc/meiolol/megatron.cred. meiolol-disk.service (/usr/local/sbin/meiolol-disk)
assembles it at boot. ~/ml links to /srv/meiolol/ml. Writeback was refused by LVM (a
damaged cachevol can't be repaired)

- SQLite test with the cache: commits 11-12/s (p50 ~62 ms), lookups beside the writer
  243-260/s, cold scan 147-171 MB/s, cold row reads 1,450-1,640/s: scans near local
  disk, row reads ~2x the bare image, writes still at Megatron's pace
- Reboot (27 Oct, Ethan's RAM and CPU change): disk back, but the user units start
  before it and fail CHDIR once, then come up on Restart's 60 s. Left: fstrim.timer; backups/ to
  Megatron outside the image (VM8)

### VM2: base host

- Done: lingering, unattended upgrades, UTC, journald 1 GB, ufw (all on tailscale0, ssh
  from 192.168.18.0/24 for Ethan), sqlite3; `box.sh status` answers
- Left: Tailscale on the gpu-box WSL (its sudo password: Jacob), for its mirror and
  archive pulls; its aliases are switched to C01 by the cut-over

### VM3: backend on a copy, crawler off

- `MEIOLOL_HOST=essex-vm deploy/box.sh` sync: binary, scripts, units; crawl.args with
  `--proxy 127.0.0.1:8092` (or the API's address) instead of 10.0.0.3
- First copy: C01 pulls ~/ml/meiolol (bin/ and -shm left out) from the box over the
  internet with alias meiolol-box, key ~/.ssh/meiolol_box, which the box's
  authorized_keys limits to `ionice -c3 nice -n 19 rrsync -ro ~/ml/meiolol`; job
  meiolol-copy (user unit), log ~/copy.log. A live copy is for testing only: check it
  with `PRAGMA quick_check` before timing
- Benchmark against the box before the switch (J31): views write and its phases
  (views.log), core build, renderer load, page render latency under concurrent load,
  deploy/bench-crawl.sh on C01. Box figures from its own logs, never a benchmark run on
  the box. Up to 1.1x the box: no downgrade. Up to 2x (or 5 s): slower but the move
  goes ahead (Jacob 27 Oct: slightly slower pages are fine for now; C01 is tuned for its
  cores, network and disk after the move, and a local 1 TB M.2 is planned). Over 2x or
  a failed step: blocked, retune first, then rerun
- Never two crawlers: the key's rate is per key, so meiolol-crawl stays disabled on C01
  until VM6
- Run the web loop, a views write and the renderer on C01; compare times with the box's
  views.log. Done when: pages render on C01 from the copy

### VM4: web side on C01

Built 27 Oct by deploy/vm-web.sh (repeatable; `data` also copies jomify's site, training
view, traffic history and API data): nginx (deploy/nginx/meiolol.conf) on 127.0.0.1:8080,
cloudflared with tunnel meiolol-c01 (1c7e296d-91e9-4538-8598-10833de3b9b0, token vault
meiolol/essex-vm TUNNEL_TOKEN), vm.meio.lol on it; meiolol-api, traffic timer, user
meiolol with C01's own keys for the meiolol-web/exchange/cache aliases (now 127.0.0.1),
the Mac's training and gpu-box's accounts keys; the gpu-box's archive and backup keys in
jacob's authorized_keys. cache-warm.sh goes to 127.0.0.1:8080. Static pages and the
admin login answer on vm.meio.lol; rendered pages once the chain starts the renderer;
Your games once C01 crawls (its Riot calls go through the crawler's proxy)

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

## C01 tuning

For a fair C01 vs Oracle benchmark: each host tuned for itself first. Code knobs become
host settings (host.env or a flag), defaults = today's values, so the Oracle box later
runs with its own tuned values; the box stays untouched until then.

- Measure: deploy/c01-bench.sh LABEL [N] on C01 (copy at ~/vm-chain/deploy/, run as a
  user unit: `systemd-run --user --collect --unit meiolol-tune bash
  ~/vm-chain/deploy/c01-bench.sh LABEL 3`; it refuses otherwise). It pauses meiolol-web
  (its trap restarts it), times core build, a full views write and a renderer load into
  scratch files, then render latency over every page; one row of medians per setting in
  ~/vm-chain/tune/results.md, log ~/vm-chain/tune/bench.log. Setting under test in the
  environment, over host.env's. Any other step that pauses web runs as a unit too
  (box.sh job run), never from a bare ssh: a dropped one skips the restart. Page cache warmed first (all dbs read once: 60 GB in ~4 min, 50 GB
  buff/cache); record buff/cache with each row
- Order, one at a time against the baseline, a row each (value, median of 3, kept or
  not): 1. views write parallel runs (src/site/filters.zig `runs = 4`): 8, then 16;
  2. reader SQLite cache (schema.zig read_cache_kib 64 MB) and mmap_size (2 GB) up to
  covering the dbs; 3. par.zig users' hard caps; 4. unit limits (web MemoryHigh 30G;
  render, crawl none) so web + render + crawl + page cache fit 62 GB; 5. lvmcache hit
  and miss counters after a views write (likely moot with 62 GB RAM). Writer cache and
  crawler threads only if crawl figures show the database as the limit
- 16 vCPU = E5-2630 v3, 8 cores 16 threads: if one socket they are hyperthreads, so
  measure 8 before 16 and expect little past 8; settled by those runs, not by asking

Medians of 3 (the runs in brackets); render ms: every page (30085) from the live
renderer, 8 at a time; crawl: the crawler's rate at the end.

Daily eval (`meiolol eval --platform all`, in the web loop; no setting touches it):
C01 27 Oct 14:00:25-14:45:46 UTC, 45 min (2.24M games); Oracle 26 Oct 12:46:48-21:43:43,
8 h 57 min (2.11M). Starts at the first round boundary after it falls due (C01: 54 min
late, behind a views round)

| setting | core build s | views write s | renderer load s | render ms p50/p95/p99 | buff/cache GB | crawl matches/day |
|---|---|---|---|---|---|---|
| baseline, serial (27 Oct, host CPU, 62 GB, AVX2 build) | 129 (129 120 132) | 754 (758 750 754) | 44 (44 43 45) | 10/19/25 | 49 | 152121 |
| filter runs 8, serial: not kept (filters 4.8 s vs 6.0 s; views write within noise) | 126 (121 135 126) | 788 (742 788 792) | 45 (45 46 44) | 10/20/27 | 49 | 153775 |
| view loads 4 (95f9063d) | 128 (128 127 128) | 460 (473 433 460) | 44 (44 41 48) | 11/20/26 | 47 | 154216 |
| view loads 2: kept, C01 host.env MEIOLOL_VIEW_LOADS=2; the new baseline | 127 (131 127 123) | 436 (434 438 436) | 45 (45 43 47) | 9/20/25 | 48 | 154666 |
| filter runs 16 at view loads 2: not kept (filters 3.6 s, beside people's 62 s) | 129 (125 129 135) | 453 (454 453 439) | 45 (45 45 44) | 10/20/26 | 47 | 154467 |

Baseline's views write by phase (views.log): stats 371 s (view 2), 144 s (view 3),
75 s (view 0), 29 s (view 1), single-threaded (cpu = wall); people 53 s; filters 6 s,
from the partials. The four views load one after another on one connection, so the
write uses about one of the 16 vCPU: knob 1 can save at most the filters' 6 s, less
than the spread between runs
- Views write on more than one core, in this run (Jacob, 27 Oct: an optimisation the
  Oracle box could have had too, only not worth it on 2 cores, so the benchmark stays
  fair): the four views at once on sibling connections, MEIOLOL_VIEW_LOADS (1-4, default
  1 = serial, the Oracle box's value). Not par inside stats: chunked float sums in
  additive.fit would change the output and the eval. Expected ~400 s against 754 (the
  longest view plus partials). Then a new baseline row at C01's value; the row above
  stays, labelled serial. Built (95f9063d): views at once on par.forEachUpTo, longest
  first; the people tallies behind a mutex (they read stats only for champion ids, so
  any view may make them); the first view to fail stops the others. Checked on C01 (27 Oct,
  crawler and web loop paused): views written at 1 and at 4 match byte for byte in
  every part the clock leaves alone (views 1 and 3 whole, every view's patch day; the
  30-day views' window moved 13 min between the writes); core builds by the old and new
  binary started together match in all 285 files. Views write 769 s at 1, 471 s at 4
  (one run, not the bench). Benched: 2 at once is as fast as 4 (436 s vs 460 s, -42% on
  serial) with less memory beside the renderer and crawler, so C01 runs 2. Its floor is
  the longest view: view 2's stats 396 s (371 s serial; the views slow each other a
  little), the other worker's views 0, 3, 1 fit beside it. Lower only by splitting
  stats, ruled out above
- Knobs 2 (reader cache, mmap) and 5 (lvmcache): not run, nothing waits on reads. Every
  phase of both builds has cpu = wall (core build stats 29.4 s and 86.8 s; views write
  stats 398 s; partials 13.8 s wall vs 13.6 s cpu), with 47-49 GB of page cache warm
- Core build: its two views (29 s, 87 s) load at once too, behind the same
  MEIOLOL_VIEW_LOADS (write.zig: loaded at once, then written in the serial order)
- Hyperthreads: `openssl speed -multi N sha256` 16 KB blocks, 27 Oct, web loop running:
  8 at 2.68 GB/s, 16 at 5.11 GB/s (1.9x): the 16 vCPU act as near 16 cores
- Knob 4 (unit limits): a views write's peak at view loads 2 still to read, from
  meiolol-web's MemoryPeak after its next full round (restarted 27 Oct 17:57). Web was
  down 17:03-17:57 that day: a probe's ssh dropped before its trap restarted it

## Later

- Plain local calls in place of the localhost ssh aliases (VM4)
- Retune for C01 (after VM3's baseline): the box's limits were set for 2 cores and a
  72 MB/s disk. More parallel read runs in the views write (4 today), more reads in
  flight (Megatron's latency hides behind queue depth), bigger SQLite caches and
  MemoryHigh in 15 GB, the hot set kept inside the 30 GB cache
