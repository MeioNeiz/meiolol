---
title: GitHub Docs: About large files on GitHub
url: https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
kind: docs
commit:
for: [free-hosting-storage]
looked: 2026-10-11
depth: docs (whole page)
relevance: high
grade: A/fair
description: GitHub's file and repository size guidance: 100 MiB block, under 1-5 GB repos, 'Git is not designed to serve as a backup tool', releases for large binaries
---
# GitHub Docs: About large files on GitHub

Why: can meiolol use GitHub to store backups or data, and what are the limits?

## Assessment

- Evidence: A. GitHub's own docs, current on 2026-10-11.
- Reasoning: fair.
- Interests: vendor (platform terms).
- Weigh: binding limits and policy wording.

## Findings

- [ops] Files over 100 MiB are blocked; over 50 MiB warned. ^f1
  > GitHub blocks files larger than 100 MiB.
- [ops] Repositories ideally under 1 GB, under 5 GB strongly recommended; GitHub
  Support may ask for corrective action. ^f2
  > We recommend repositories remain small, ideally less than 1 GB, and less than 5 GB is strongly recommended.
  > If your repository excessively impacts our infrastructure, you might receive an email from GitHub Support asking you to take corrective action.
- [ops] GitHub states Git is not a backup tool and points to backup products. ^f3
  > Git is not designed to serve as a backup tool.
- [ops] Releases: no limit on total binary size or bandwidth; each file under the plan's
  Git LFS file size limit. ^f4
  > We don't limit the total size of the binary files in the release or the bandwidth used to deliver them.
- [ops] Releases are framed as distributing files for other people to use. ^f5
  > Releases allow you to package software, release notes, and links to binary files, for other people to use.

## Read

- whole page

## Not read

- linked removal procedures (see gh-remove-sensitive-data)
