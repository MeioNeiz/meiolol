# Hosting the backend (the box)

Moved off the gpu-box PC on 2026-10-11 so Jacob's PC and laptop can be off. Everything
runs on Oracle Cloud Always Free, home region uk-london-1 (tenancy `jacobmaschler`; free
accounts may use Always Free only in the home region).

## Hosts

| alias | what | shape | disk |
|---|---|---|---|
| meiolol-cloud | the box: crawler, site build + upload, backups, health | stopgap VM.Standard.E2.1.Micro (1/8 OCPU, 1 GB + 2 GB swap), 141.147.117.32 | 50 GB boot |
| (jomify) | nginx: site, Your games service, jomove | E2.1.Micro, 193.123.180.81 | 47 GB boot |

- Target: VM.Standard.A1.Flex 2 OCPU / 12 GB (the account's limit; "LIMITED_FREE", free
  up to 1500 OCPU-h + 9000 GB-h a month). London has been out of A1 capacity; a retry
  loop launches it (2/12, else 1/6; AD-1 and AD-2; 50 GB boot to fit the quota). Then
  move the box there (stop services, rsync data, `deploy/box.sh start` etc.), terminate
  the micro and grow the A1 boot volume. Pay-as-you-go (Jacob, card) gets A1
  capacity sooner (reported, not promised) and allows paid disk; still free within the
  limits (research/questions/oci-payg-upgrade.md)
- Block storage: 200 GB free in total. In use: jomify boot 47, micro boot 50, and an
  unattached 47 GB "Jomify (Boot Volume)" from April (reclaim with Jacob's OK)
- Ssh: `meiolol-cloud` in ~/.ssh/config (user ubuntu, key oci_instance-20260714-1317).
  On the box, ~/.ssh/config has meiolol-web and meiolol-exchange (rrsync users on jomify)
- OCI CLI on the Mac: ~/.oci/config, API key ~/.oci/oci_api_key.pem (Jacob's user). The
  console login is in jodrive (`jodrive oracle login`, .env.oracle incl. the TOTP key)

## On the box

- ~/ml/meiolol: bin/ (deployed by deploy/box.sh, built for the host's CPU), data/,
  backups/, .env (copied from the Mac), contact, riot.txt, crawl.args, host.env
  (MEIOLOL_BACKUPS, MEIOLOL_NO_EVAL=1 on the micro)
- systemd --user services, lingering: meiolol-crawl, meiolol-web, meiolol-backup,
  meiolol-health (deploy/systemd). `systemctl --user status meiolol-crawl`; logs in data/
- crawl.args on the micro: `--reserve 5 --no-mastery --raw-timeline-days 0
  --raw-match-days 3 --keep-days 60 --ladder-per-hour 40 --player-sample 16 --min-tier
  PLATINUM` (raw retention cut for the 50 GB disk; Platinum IV and up only)

## Known problems on the micro

- Slow: ~11k matches/day vs ~135k on the PC with 19 writing threads (153 lock waits in
  27 min); memory tight. Single writer thread since branch worktree-writer (1.5x matches,
  4x mastery in a 1/8-CPU emulation, docs/architecture.md); the A1 fixes the rest
- `meiolol backup` holds the DB for 10+ minutes here and starves the crawler of writes
  ("database is locked"), so the first run was killed; backups need rework (off-host
  target too: they sit on the same disk). gpu-box keeps its data and the 2026-10-11 D:
  backup as the restore point until Jacob retires it
- Disk: ~1.6 GB/day kept forever at the full all-region rate: weeks on this disk
