---
status: answered
priority: now
area: ops
tags: [ops, privacy]
description: What free or very cheap hosting and storage fits meiolol's site, API and data?
---
# What free or very cheap hosting and storage fits meiolol's site, API and data?

Feeds: docs/backlog.md Ops and data (off-site backups, disk runway, site hosting);
docs/data-safety.md Backups. Oracle compute is covered elsewhere

## Answer

Off-site backups and bulk data are mostly the same bytes (append-only segments grow
~50 GB/month), so whatever holds backups must be cheap per TB, with no minimum
retention (erasure deletes early) and client-side encryption. Best fit: a Hetzner
Storage Box, BX11 1 TB for EUR 3.20/month net, unlimited traffic, rsync/SFTP/restic/
Borg, Germany or Finland, no minimum term; BX21 5 TB is EUR 10.90 (C3, C14). It fits
the existing rsync mirror, so `forget --backups` scrubs propagate; encrypt with rclone
crypt (file-for-file, so scrubs still replace files) or restic. Second: Backblaze B2 at
$6.95/TB-month, 10 GB free, no minimum duration, free egress to 3x storage (C2).
Cloudflare R2 has free egress and free deletes but costs $15/TB-month; its 10 GB free
tier only suits the state snapshots alone (C1). Archive tiers are cheaper per TB (AWS
Deep Archive ~$1/TB, OCI Archive ~$2.66, Scaleway Glacier ~EUR 2.54) but carry 90 to
180-day minimums, slow restores and paid egress, so every erased or rotated object
pays out its minimum; Wasabi adds a 1 TB monthly minimum (C4). OCI Always Free gives
only 20 GB object storage (C5).

GitHub is the wrong store: 100 MiB files, repos ideally under 1-5 GB, LFS 10 GiB free;
releases allow unlimited total size but GitHub says Git is not a backup tool, wants
generated files in object storage, and may throttle or delete repos under undue strain
(C7, C8). Erasure from git history needs a rewrite plus GitHub Support and still leaves
forks and cached views (C9). Hugging Face's free 100 GB private is git-backed too
(C6). Verdict C16.

Since the box moved to Oracle (docs/hosting.md) the data lives on a free VM with at most
~150 GB of free block storage (200 GB tenancy total, less jomify's boot), so storage
is now a hard limit, not a December one. Two levers, best together: keep less on the box
(a rolling window of match-level rows and compact timelines, per-patch aggregates kept
forever; the site reads only the newest patch and 30 days of curves) and move older
segments plus backups off-host to the Storage Box (C18, C19). The home PC's 2 TB NVMe is
free but only reachable while the PC is on, which the move was meant to end.

Static site: keep the Oracle micro (another session) and use Cloudflare Workers static
assets as the fallback: free, unlimited asset requests, 20,000 files of 25 MiB (the
site is ~380 files, 15 MB) (C10, C17). GitHub Pages works (1 GB, 100 GB/month soft)
but bars commercial sites (C11); Vercel Hobby bans ads; Netlify Free's credits run out
on daily deploys (C12). No free VM elsewhere beats Oracle for the API: GCP e2-micro is
US-only with 1 GB egress, AWS and Azure give expiring credits, Fly has no free tier,
Render's free tier loses local SQLite, Koyeb has no free instance (C13).

## Claims

- C1: R2 Standard costs $0.015/GB-month with 10 GB free, no egress fees, no minimum duration and free deletes; Infrequent Access has a 30-day minimum. for: [[cloudflare-r2-pricing#^f1]], [[cloudflare-r2-pricing#^f2]], [[cloudflare-r2-pricing#^f3]], [[cloudflare-r2-pricing#^f5]], [[cloudflare-r2-pricing#^f6]]
- C2: B2 costs $6.95/TB-month, first 10 GB free, no minimum duration or file size fees, egress free up to 3x stored. for: [[backblaze-b2-pricing#^f1]], [[backblaze-b2-pricing#^f2]], [[backblaze-b2-pricing#^f3]], [[backblaze-b2-pricing#^f4]]
- C3: A Hetzner Storage Box is EUR 3.20/month net for 1 TB (5 TB EUR 10.90), unlimited traffic, rsync/SFTP/Borg/restic, no minimum term, Germany or Finland. for: [[hetzner-storage-box-prices#^f1]], [[hetzner-storage-box-prices#^f2]], [[hetzner-storage-box#^f1]], [[hetzner-storage-box#^f2]], [[hetzner-storage-box#^f3]], [[hetzner-storage-box#^f4]], [[hetzner-storage-box#^f5]]
- C4: Cold tiers trade price for minimums: AWS Deep Archive $0.00099/GB with 180 days, OCI Archive $0.0026/GB with 90 days, Scaleway Glacier EUR 0.00254/GB (minimum not stated), Wasabi $7.99/TB with a 1 TB monthly minimum and 90 days. for: [[aws-s3-pricing#^f1]], [[aws-s3-pricing#^f3]], [[oci-storage-pricing#^f3]], [[oci-archive-storage#^f1]], [[scaleway-storage-pricing#^f1]], [[wasabi-pricing-faq#^f1]], [[wasabi-pricing-faq#^f2]], [[wasabi-pricing-faq#^f3]]
- C5: OCI Always Free includes only 20 GB object storage per tenancy. for: [[oci-always-free#^f1]]
- C6: Hugging Face free accounts get 100 GB private storage, but repos are git-backed and reclaiming deleted data needs a destructive super-squash. for: [[hf-storage-limits#^f1]], [[hf-storage-limits#^f5]], [[hf-storage-limits#^f6]]
- C7: GitHub blocks files over 100 MiB, recommends repos under 1-5 GB (10 GB on disk), gives 10 GiB LFS free; releases take 1000 assets of under 2 GiB with no total limit. for: [[gh-large-files#^f1]], [[gh-large-files#^f2]], [[gh-repository-limits#^f1]], [[gh-lfs-billing#^f1]], [[gh-about-releases#^f1]], [[gh-about-lfs#^f1]]
- C8: GitHub says Git is not a backup tool, generated files belong in object storage, and it may throttle or delete repos placing undue strain; no rule bans backups by name. for: [[gh-large-files#^f3]], [[gh-repository-limits#^f2]], [[gh-aup#^f1]], [[gh-aup#^f4]]
- C9: Erasing data from GitHub history leaves copies in forks, cached SHA views and PRs and needs GitHub Support; LFS storage is not credited on mid-month deletes. for: [[gh-remove-sensitive-data#^f1]], [[gh-remove-sensitive-data#^f2]], [[gh-remove-sensitive-data#^f3]], [[gh-lfs-billing#^f4]]
- C10: Cloudflare serves Workers static assets free and unlimited; Free plan allows 20,000 files of up to 25 MiB (Pages the same, 500 builds a month). for: [[cf-workers-static-assets#^f1]], [[cf-workers-limits#^f2]], [[cf-pages-limits#^f1]], [[cf-pages-limits#^f2]], [[cf-pages-limits#^f3]]
- C11: GitHub Pages allows 1 GB sites and 100 GB/month soft bandwidth but not online business, e-commerce or SaaS. for: [[gh-pages-limits#^f1]], [[gh-pages-limits#^f2]], [[gh-pages-limits#^f4]]
- C12: Vercel Hobby is non-commercial and ads count as commercial; Netlify Free has 300 credits a month at 15 per production deploy and 20 per GB. for: [[vercel-hobby#^f3]], [[vercel-fair-use#^f1]], [[vercel-fair-use#^f2]], [[netlify-pricing#^f1]], [[netlify-pricing#^f2]], [[netlify-pricing#^f3]]
- C13: Free VM tiers are weak in 2026: GCP e2-micro US-only with 1 GB egress; AWS up to $200 credits, free plan 6 months; Azure 30-day credit and 12 months; Fly no free tier; Render free loses local SQLite and sleeps; Koyeb no free instance. for: [[gcp-free-tier#^f1]], [[gcp-free-tier#^f2]], [[aws-s3-pricing#^f6]], [[azure-free#^f1]], [[azure-free#^f2]], [[flyio-pricing#^f1]], [[render-free#^f1]], [[render-free#^f2]], [[koyeb-pricing#^f3]]
- C14 (inferred): Off-site backups should go to a Storage Box first (cheapest per TB at our size, no retention fees, rsync scrubs propagate), B2 second, R2 for state snapshots only, all client-side encrypted. from: C1, C2, C3, C4
- C15 (inferred): For bulk growth, a local disk is cheapest; off-site, Storage Box then B2; archive tiers only for data that will never need erasure, which personal data cannot promise. from: C2, C3, C4
- C16 (inferred): GitHub (and Hugging Face) should not hold meiolol backups or data: policy friction, size limits, and erasure from git history is impractical. from: C6, C7, C8, C9
- C17 (inferred): The static site's free fallback is Cloudflare Workers static assets; the API needs a VM, and none of the free VM tiers beats the Oracle micro. from: C10, C11, C12, C13
- C18 (inferred): The site needs far less than everything: stats read the newest patch, curves the last 30 days; only Pool's learning curves read all patches, so a rolling window plus per-patch aggregates covers today's features and minimises personal data kept (our code, docs/architecture.md).
- C19 (inferred): Plan for the Oracle box: A1 with up to ~150 GB, a 60-day window of match rows (~100 GB at full rate), older segments and daily backups encrypted on a BX11 (EUR 3.20/month, ~1.5 years of full-rate segments), erasure by rsync scrub as now. from: C3, C5, C14, C18

## Disagreements

- Wasabi list price: its FAQ says $7.99/TB; secondary blogs say $6.99. The FAQ (A) wins.
- Hetzner Storage Box price is from Hetzner's price feed, not page text (script-rendered);
  aggregators quote the same EUR 3.20 and 10.90.

## Options

| Option | Claims for | Claims against | Would change if |
| --- | --- | --- | --- |
| Hetzner Storage Box (backups + bulk) | C3, C14 | single provider site; encryption is ours | durability or speed proves poor |
| Backblaze B2 | C2 | ~2x Storage Box per TB at 1 TB | Storage Box rejected |
| Cloudflare R2 | C1 | $15/TB-month | data stays under ~10 GB |
| Archive tiers (AWS, OCI, Scaleway) | C4 price | C4 minimums vs erasure | data had no personal fields |
| GitHub / HF | C7 releases size | C8, C9, C6 | never |
| Keep less on the box (rolling window + aggregates) | C18 | code: prune + aggregate files; Pool rework | features need older match rows |
| Home PC NVMe as archive | free, 673 GB unallocated | PC must stay on; needs a tunnel | PC stays on anyway |
| Cloudflare Workers static assets (site) | C10 | API cannot move | Oracle micro lost |

## Open

- Real window size: kept bytes per match on the A1 at full rate, and which features (Pool,
  learning curves, eval) need rows older than 60 days
- Storage Box durability (RAID, single site) and snapshot behaviour under erasure
- Scaleway Glacier minimum duration; IDrive e2 and Storj prices and minimums (leads)
- Git LFS overage price per GiB (not in the docs text)
- R2 EU jurisdiction option; Hetzner Object Storage base price (script-rendered)
- Hugging Face terms of service on private non-ML data (not read)
