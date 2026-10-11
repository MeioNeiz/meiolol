---
title: 'Knots (knots-ui/knots): README and build.zig.zon'
url: https://github.com/knots-ui/knots
kind: project
commit: 88bd83b4dc79f3178c9ca5345d5cb3c1c536f58f
for: [zig-gui-options]
looked: 2026-10-11
depth: code (README, build.zig.zon)
relevance: low
grade: D/fair
description: New Zig immediate-mode GUI (2026); follows Zig master (min 0.17.0), Vulkan by default on Windows
---
# Knots (knots-ui/knots): README and build.zig.zon

Why: newest Zig GUI showcased on Ziggit; credible alternative?

## Assessment

- Evidence: D. GitHub repo created 2026-09-27 (moved from Codeberg, first Ziggit post
  2026-04), 45 stars, 2 contributors, no releases. Its flagship app is AI-coded
  ([[ziggit-knots-gui#^f1]]).
- Reasoning: fair; README lists real limitations (text shaping).
- Interests: author's own project.
- Weigh: too young and on the wrong Zig for us; revisit only if dvui stalls.

## Findings

- [gui] Follows Zig master; minimum Zig 0.17.0, so not usable with 0.16. `README.md`,
  `build.zig.zon` ^f1
  > Knots follows the Zig master branch.
  > .minimum_zig_version = "0.17.0",
- [gui] Default Windows backend is Vulkan (WebGPU optional), needing a Vulkan 1.3 driver;
  heavier than D3D11 for a small window. `README.md` ^f2
  > | Windows             | Vulkan          | WebGPU            |
  > For the Vulkan backend: a Vulkan 1.3 driver with dynamic rendering.
- [gui] Text is one glyph per codepoint, no shaping, kerning or font fallback.
  `README.md` ^f3
  > Text uses one glyph for each Unicode codepoint. There is no complex shaping,

## Read

- README, build.zig.zon

## Not read

- Docs site, source
