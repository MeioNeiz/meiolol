---
status: answered
priority: now
area: ops
tags: [ops]
description: Is upgrading the Oracle account to Pay As You Go safe (no surprise charges) and does it get a faster box?
---
# Is upgrading the Oracle account to Pay As You Go safe (no surprise charges) and does it get a faster box?

Feeds: docs/hosting.md (A1 target), docs/plan.md storage and hosting options (3)

## Answer

Safe on cost if we stay inside Always Free sizes: Oracle says in two places that
Always Free resources stay free after the upgrade and only usage beyond them is billed
(C1). The upgrade is one-way (C2). Budgets only email, once a day (C3); quotas are the
hard cap (C4), so set A1 to 2 OCPU / 12 GB, block storage to 200 GB, other shapes to
zero before or right after upgrading.

Faster box: the free A1 is now 2 OCPU / 12 GB (C5), against the micro's 1/8 OCPU and
1 GB. Whether PAYG gets past "Out of host capacity" is not Oracle's word: Oracle only
suggests upgrading and says PAYG has different capacity limits (C6); the "larger pool"
is a vendor guide and community reports (C7). Likely, not certain. Anything bigger
costs: A1 4/24 about $28/month if billed (C8, PAYG exemption hearsay, C9), E5 2/12
about $62, extra disk about $8.50 per 200 GB balanced (C10).

## Claims

- C1: After upgrading, Always Free resources stay free; only usage beyond them is
  charged. for: [[oci-free-faq#^f1]], [[oci-free-faq#^f3]], [[oci-always-free#^f5]]
- C2: No downgrade back to a free account. for: [[oci-free-faq#^f2]]
- C3: Budgets are soft limits with daily email alerts, not caps. for:
  [[oci-budgets#^f1]], [[oci-budgets#^f2]]
- C4: Compartment quotas hard-cap resource counts in the tenancy. for: [[oci-quotas#^f1]]
- C5: Free A1 is 1,500 OCPU-h / 9,000 GB-h a month, 2 OCPU / 12 GB. for:
  [[oci-always-free#^f6]], [[infoq-oci-free-cut#^f1]]
- C6: Oracle suggests PAYG for out-of-capacity errors but does not promise A1 capacity.
  for: [[oci-always-free#^f5]], [[oci-free-faq#^f4]]
- C7: PAYG accounts get A1 more easily. for: [[quantrocket-oracle#^f1]],
  [[infoq-oci-free-cut#^f3]]
- C8: A1 beyond the free allowance costs $0.01 per OCPU-h and $0.0015 per GB-h. for:
  [[oci-storage-pricing#^f5]]
- C9: PAYG may keep the old 4/24 free allowance. for: [[infoq-oci-free-cut#^f2]]
  against: [[oci-always-free#^f6]]
- C10: Paid compute and disk: E5 $0.03/OCPU-h + $0.002/GB-h; block volume $0.0255
  per GB-month + VPUs. for: [[oci-storage-pricing#^f6]], [[oci-storage-pricing#^f7]]

## Disagreements

- PAYG free A1 size: Oracle docs say "all tenancies" 1,500/9,000 (A); support emails
  reported by InfoQ (B, hearsay) say PAYG keeps 4/24. Settle by asking Oracle Support
  after upgrading; until then stay at 2/12.

## Open

- Card authorisation hold size on upgrade (third-party reports $100, released)
- Whether quota names cover every paid shape (Available Quotas by Service not read)
