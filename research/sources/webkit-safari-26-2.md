---
title: WebKit Features for Safari 26.2
url: https://webkit.org/?p=17640
kind: docs
commit: 
for: [zig-only-frontend]
looked: 2026-10-22
depth: skimmed (button commands, details, field-sizing, anchor positioning)
relevance: high
grade: A/fair
description: WebKit team's Safari 26.2 release post (Dec 2025): command and commandfor invoker buttons, find-in-page opening details, field-sizing, anchor positioning refinements
---
# WebKit Features for Safari 26.2

Why: when did Safari and iOS get invoker commands and field-sizing, and what exactly
do they cover?

## Assessment

- Evidence: A. Engine vendor's release notes.
- Reasoning: fair. Explains what replaces JS; no caveats.
- Interests: vendor.
- Weigh: trust the lists of supported values.

## Findings

- [web] Safari 26.2 frames its release as replacing JS with HTML or CSS for common UI:
  auto-growing fields and buttons that open and close dialogs and popovers. ^f1
  > You’ll find simpler ways to create common UI patterns with just a few lines of HTML or CSS, and no JavaScript
- [web] Invoker commands: `commandfor` points at an id, `command` picks one of six
  built-in actions; before this a button needed JS for any client-side action. ^f2
  > Before, using a `button` on a web page to trigger a client-side action required JavaScript.
  > For[`dialog`](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dialog)elements: `show-modal`, `close`, and `request-close`.
  > `show-popover`, `hide-popover`, and `toggle-popover`.
- [web] Custom commands (`command="--foo"`) still need JS to observe the event; only
  the six built-ins are script-free. ^f3
  > Custom commands are named using `--foobar` syntax, and used declaratively in HTML as `command="--foobar"`.
- [web] Find in page and text fragments now open a closed `<details>` in Safari, so
  content hidden in accordions stays findable. ^f4
  > if the search result is hidden inside a closed `details` element, the element will automatically expand to reveal the text.
- [web] `field-sizing: content` makes inputs and textareas grow with their content,
  replacing JS resizing. ^f5
  > This eliminates the need for JavaScript to resize form fields dynamically.
- [web] Anchor positioning first shipped in Safari 26.0; 26.2 adds flip-x and flip-y
  fallbacks and position-visibility. ^f6
  > Safari 26.2 adds several refinements to Anchor Positioning, which originally shipped in Safari 26.0.

## Read

- Intro, Button commands, details, field-sizing, anchor positioning, view transitions

## Not read

- Bug fix lists beyond CSS and forms
