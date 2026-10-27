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

## Running it

One dedicated session runs VM1-VM8 back to back, each step starting when the last is
done, without asking (J31); the coordinator (meiolol-8b) watches it and hands it over
when its context fills. Decisions inside a step are the session's; Jacob only for
what needs him off the keyboard (`cc-note needs`): the gpu-box Tailscale login link,
Ethan's CPU type. VM6 runs by itself once VM3's benchmark shows no downgrade.

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
  meiolol-box-mac = localhost:2222, a reverse tunnel the Mac holds (`caffeinate -i ssh -N
  -R 2222:140.238.101.20:22 essex-vm`), `--bwlimit=6m` each to spare Jacob's upload
- Chain: C01 unit meiolol-vm-chain runs deploy/vm-chain.sh (copy at
  ~/vm-chain/deploy/): waits for the copy, catch-up and quick_check, then VM3's
  benchmark; ~/vm-chain/results.md ends "VERDICT: ...". C01 has 8b25a7c's x86 build
  (box.sh sync), no unit enabled
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
- Left: a reboot test (disk back, services after it); fstrim.timer; backups/ to
  Megatron outside the image (VM8)

### VM2: base host

- Lingering for jacob: done. Left: unattended upgrades, UTC, journald limits, ufw (ssh
  on tailscale0 only), Tailscale on the gpu-box WSL (its mirror and archive pulls)
- Done when: `MEIOLOL_HOST=essex-vm deploy/box.sh status` answers

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
  the box. No downgrade = C01 at or under the box's times, or over by under 10% where
  retuning (Later) can't close it. A downgrade: retune first, then rerun
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
- Retune for C01 (after VM3's baseline): the box's limits were set for 2 cores and a
  72 MB/s disk. More parallel read runs in the views write (4 today), more reads in
  flight (Megatron's latency hides behind queue depth), bigger SQLite caches and
  MemoryHigh in 15 GB, the hot set kept inside the 30 GB cache
