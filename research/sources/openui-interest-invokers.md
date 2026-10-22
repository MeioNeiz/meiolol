---
title: 'Open UI: Interest Invokers explainer (interestfor)'
url: https://open-ui.org/components/interest-invokers.explainer/
kind: spec
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: skimmed (pitch, introduction, survey, mouse, keyboard, touchscreen)
relevance: medium
grade: B/strong
description: Mason Freed and Keith Cirkel's explainer (updated 16 Oct 2026) for interestfor, declarative hover and focus triggered popovers (hovercards, tooltips), with keyboard and touch designs; still in WHATWG, Chromium only
---
# Open UI: Interest Invokers explainer (interestfor)

Why: can tooltips and hovercards (our champion and stat explanations) go script-free,
and how does that work on phones?

## Assessment

- Evidence: B. Design doc by the Chromium engineer shipping it; survey of the top 50
  sites. Not a standard yet, one engine ([[web-features-3-44#^f5]]).
- Reasoning: strong. Covers every input type and alternatives considered.
- Interests: Google proposer.
- Weigh: the touch story (long-press menu item, opt-in `::interest-button`) is newly
  decided and unshipped outside Chromium.

## Findings

- [web] Still under WHATWG development; Open UI considers the direction settled. ^f1
  > This proposal is still under active development in the WHATWG, but OpenUI has concluded its design discussions and feels that the direction is sound.
- [web] Hover UI is near universal but hand-rolled versions rarely work for keyboard
  and almost never on touch. ^f2
  > Only one of the sites surveyed offered any support for touchscreen users.
- [web] The pitch: `interestfor` on a link or button plus a `popover=hint` target
  gives a hovercard with no script. ^f3
  > This API, `interestfor`, is very similar, in that it also provides a declarative way to invoke actions on a target element.
- [web] Only buttons, links and area elements can be interest invokers; not a div or
  table cell. ^f4
  > The `interestfor` attribute has no effect on other elements, such as `<div>` or `<input type=button>`
- [web] Keyboard: focus shows interest after a delay, Esc dismisses all. ^f5
  > keyboard focus on the element with `interestfor` shows interest after the [start delay]
- [web] Touch: long-press adds a Show details menu item, or the author opts into a
  tappable `::interest-button`; emulated hover from a tap does nothing. ^f6
  > Hover events that come from touch input (e.g. the emulated hover that some browsers generate for a tap) do not show or lose interest.
  > Add an item to the pre-existing long-press context menu (in Chromium on Android, this item is labeled “Show details”)
- [web] (inferred) On iPhones (Safari 27 has no interestfor, [[webkit-safari-27-beta#^f6]])
  a hint-only tooltip is unreachable; meiolol's mobile users need a click path
  (popovertarget button) for any explanation. ^f7

## Read

- Pitch, introduction, survey conclusions, HID sections

## Not read

- Delays (CSS properties), alternatives considered, Other section
