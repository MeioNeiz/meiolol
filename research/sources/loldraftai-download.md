---
title: LoLDraftAI desktop download page (Oct 2026)
url: https://loldraftai.com/download
kind: docs
commit: 
for: [league-apps-feature-matrix]
looked: 2026-10-22
depth: docs (whole page)
relevance: medium
grade: C/fair
description: LoLDraftAI's Windows desktop app page: reads the live draft from the local League client and applies runes, item sets and summoner spells on request; unsigned installer, SmartScreen warning
---
# LoLDraftAI desktop download page (Oct 2026)

Why: what LoLDraftAI's desktop app does per phase and what it touches in the client; the existing notes ([[loldraftai-site]], [[loldraftai-pricing]]) left /download unread.

## Assessment

- Evidence: C. Vendor page, live in Oct 2026 (model updated 17 Oct, patch 16.20).
- Reasoning: fair; plain about what the app touches.
- Interests: vendor.
- Weigh: the scope statement (local client only, applies only when asked) is a self-description worth copying as wording.

## Findings

- [tools/phase] [ux/features] Champ select: the Windows app tracks the live draft and gives draft analysis, rune pages and item builds, applied to the client in one click. ^f1
  > Get draft analysis, rune pages, and item builds during champion select, and apply them to your client in one click.
- [policy] [ux/trust] States the app only talks to the local League client, to read the draft and to apply runes, item sets and summoner spells when the user asks. ^f2
  > The app only talks to your local League client - to read your live draft, and to apply recommended runes, item sets, and summoner spells when you ask it to
- [tools] [ux/trust] Installer is not yet trusted by Windows SmartScreen; users are told to click "More info" then "Run anyway". ^f3
  > Windows SmartScreen might display a prompt during installation
- [tools/accounts] Site has a "Sign in" link and a Dashboard; support via Discord and email. The login page returned HTTP 400 to the fetcher, so the sign-in method is unknown (nav links, unquotable). ^f4
- [tools/phase] Checked, not there: no loading screen, in-game or post-game feature named on the download page; it is champ select only. ^f5

## Read

- Whole page

## Not read

- /auth/login (HTTP 400), /legal
