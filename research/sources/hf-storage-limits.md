---
title: Hugging Face Hub storage limits (docs, 2026)
url: https://huggingface.co/docs/hub/storage-limits
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (Storage plans, repo limits, freeing space)
relevance: medium
grade: A/fair
description: Hugging Face storage plans: free accounts get 100 GB private storage, PRO 1 TB then $18/TB-month; repos are git-backed, deletes need history rewrite or super-squash
---
# Hugging Face Hub storage limits (docs, 2026)

Why: could a private HF dataset hold meiolol's backups or bulk data for free?

## Assessment

- Evidence: A. Hugging Face's own docs.
- Reasoning: fair. Explains limits and why (abuse of free storage).
- Interests: vendor.
- Weigh: free private quota is real; the Hub is aimed at ML artefacts useful to the
  community and personal data on it is a GDPR question of its own.

## Findings

- [ops] Free user or org: 100 GB private storage; public best-effort. ^f1
  > | Free user or org | Best-effort\* | 100GB |
- [ops] PRO: 1 TB private then pay as you go at $18/TB-month. ^f2
  > additional private storage is charged to your payment method in Pay-as-you-go mode, at a base price of $18/TB/mo.
- [ops] Abuse mitigations on free storage; uploads should be useful to the community. ^f3
  > We do have mitigations in place to prevent abuse of free public storage, and in general we ask users and organizations to make sure any uploaded large model or dataset is **as useful to the community as possible**
- [ops] Files under 200 GB each; split data into chunks. ^f4
  > | File size | <200GB | split data into chunked files |
- [ops] Git-backed repos degrade after a few thousand commits; not meant as a database. ^f5
  > from our experience, the user experience on the Hub starts to degrade after a few thousand commits.
- [privacy] [ops] Deleting files leaves them in history; reclaiming needs a destructive
  super-squash of the whole history, reflected in quota within 36 hours. ^f6
  > The super-squash operation compresses your entire Git history into a single commit.
  > The effects from the squash operation on your storage quota are not immediate and will be reflected on your quota within 36 hours.
- [ops] Non-git Storage Buckets exist and are exempt from the repo limits section. ^f7
  > This section does not apply to [Storage Buckets]
- [ops] (inferred) 100 GB free private covers encrypted backups for a while (state
  snapshots plus ~23 MB segments) but not 0.6 TB/year of bulk data; past 100 GB it costs
  PRO plus $18/TB, dearer than B2 or R2. ^f8

## Read

- Storage plans, repository limitations, freeing storage

## Not read

- Storage Buckets docs, HF terms of service and content policy
