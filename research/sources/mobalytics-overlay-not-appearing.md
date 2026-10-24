---
title: Overlay Not Appearing (Mobalytics support, 2020)
url: https://support.mobalytics.gg/hc/en-us/articles/360046144452-Overlay-Not-Appearing
kind: docs
commit:
for: [desktop-toolkit]
looked: 2026-10-24
depth: docs (whole page)
relevance: low
grade: C/weak
description: Mobalytics troubleshooting for its in-game overlay, Overwolf build and standalone build, from July 2020
---
# Overlay Not Appearing (Mobalytics support, 2020)

Why: how does a big League app's standalone (non-Overwolf) overlay get over the game,
and what breaks it? Looked for a Riot primary on window overlays vs injected overlays
first; see Checked, not there.

## Assessment

- Evidence: C. One vendor troubleshooting page, 2020, before Vanguard came to League
  (2024); 65 of 636 readers found it helpful.
- Reasoning: weak. A checklist without explanation.
- Interests: vendor (Mobalytics).
- Weigh: tells us the standalone overlay is fragile with full-screen apps, scaling and
  admin rights; does not say how it draws (window or injection).

## Findings

- [ux/desktop] Two overlay routes: Overwolf (enable per game in Overwolf settings) and a
  standalone app with its own troubleshooting. ^f1
  > If you are using our standalone application (not Overwolf), please try the following:
- [ux/desktop] Standalone overlay needs League and the app at the same privilege level
  (both as admin). ^f2
  > Run both League client and Mobalytics app as Admin.
- [ux/desktop] It breaks with other full-screen apps, overlays and display scaling other
  than 100% at 1080p (2020). ^f3
  > Set native resolution to 1920x1080 and make sure display scale is set to 100%.
  > Make sure any other full-screen applications are not present, such as Discord overlay
- [policy] Checked, not there (2026-10-24, three web searches): no Riot primary source
  separating an always-on-top window from an injected in-game overlay. Riot's portal
  approves overlays with pre-game static data ([[riot-docs-lol#^f9]]), DevRel expects
  overlays on the official APIs to keep working under Vanguard
  ([[riot-vanguard-faq-devrel#^f2]]), and memory access is blocked from Oct 2026
  ([[riot-memory-access-removed#^f1]]); none mentions DLL injection or window type. ^f4
- [gui] (inferred) An always-on-top top-level window touches nothing in the game process,
  so of the two routes it is the one no Riot rule can read as client modification; it
  only shows over League in borderless or windowed mode, which we should verify on
  Windows. ^f5

## Read

- whole page

## Not read

- Mobalytics Vanguard FAQ (see [[mobalytics-app-download#^f4]])
