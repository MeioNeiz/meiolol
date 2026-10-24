---
title: "Dear ImGui issue #8022: Implement accessibility features?"
url: https://github.com/ocornut/imgui/issues/8022
kind: thread
commit:
for: [desktop-toolkit]
looked: 2026-10-24
depth: listed (issue body opening, all comments; #5833 and #4122 skimmed)
relevance: medium
grade: A/strong
description: Open feature request for screen reader support in Dear ImGui, with the maintainer's 2025 and 2026 replies
---
# Dear ImGui issue #8022: Implement accessibility features?

Why: what is Dear ImGui's stance on screen readers (zgui and sokol routes in
[[zig-gui-options]] use it)?

## Assessment

- Evidence: A. The maintainer (ocornut, OWNER) speaking about his own library; issue open
  since Sep 2024, 10 comments; older requests #5833 (2022, AccessKit) and #4122 (2021)
  also still open.
- Reasoning: strong. The maintainer explains why he hesitates (80% vs 99% coverage) and
  what a fork would need.
- Interests: none beyond the maintainer's workload.
- Weigh: a statement of intent, not a roadmap; nothing shipped.

## Findings

- [gui/a11y] Dear ImGui has no accessibility support for assistive software (issue's
  premise, unchallenged by the maintainer). ^f1
  > ImGui has no current implementation of accessibility for Asistive software
- [gui/a11y] Jan 2025: the maintainer says the request sits idle and he cannot promise it
  short or mid term. ^f2
  > As you noticed it is sitting idle much like many other requests for dear imgui.
  > I am yet unsure if this in particular will be something I can even consider tackling short or mid term.
- [gui/a11y] Apr 2026: basic narration is feasible, but he doubts it can pass about 80%,
  since apps often draw labels apart from their widgets. ^f3
  > I feel it would be decently easy to get 80% narration working, but extremely difficult if not impossible to get it 90-100%.
  > I'm very concerned about providing a 80% solution while knowing that getting to 99% is going to be extremely unlikely if not possible.
- [gui/a11y] His suggested route is a fork that adds narration hooks to core and widgets,
  not an upstream feature. ^f4
  > hacking narration directly as a fork of Dear ImGui
- [gui/a11y] An accessibility user replies that narration is not a screen reader
  integration; AccessKit relations such as labelled-by fit immediate mode. ^f5
  > accesskit has been made with immediate mode UI in mind, which will make implementation significantly easier
- [gui/a11y] (inferred) An ImGui-based meiolol app would be invisible to Narrator and
  NVDA for the foreseeable future. ^f6

## Read

- #8022 body opening and all comments; #5833 (AccessKit request, 2022) maintainer comment

## Not read

- #4122 (focus navigation for accessibility, 2021)
- Microsoft Xbox GDK AccessibilitySample (ImGuiAcc.cpp)
