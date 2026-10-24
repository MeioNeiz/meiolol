---
title: 'Wordle (NYT): first screen, feedback, end (Oct 2026)'
url: https://www.nytimes.com/games/wordle/index.html
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (splash, six guesses to a loss, desktop and phone; rendered text and screenshots)
relevance: high
grade: A/fair
description: Wordle under the NYT: a nine-word splash with Play, a 5x6 grid and on-screen keyboard coloured by feedback, the answer as a toast on a loss, then an account wall for stats and streaks
---
# Wordle (NYT): first screen, feedback, end (Oct 2026)

Why: lol-site-ui, kind 8: the reference daily game; how few words a first screen needs.
Screenshots data/team/2026-10-24-ui/refs/puzzle/ wordle-start.png,
wordle-feedback.png, wordle-phone-interstitial.png, wordle-end-account-wall.png (gitignored).

## Assessment

- Evidence: A. The daily game every other one copies.
- Reasoning: n/a (product).
- Interests: NYT subscriptions and ads (a 250 px ad above the grid on desktop).
- Weigh: the splash and the grid are the model; the account wall is a cost we avoid.

## Findings

- [ux/puzzle] Splash: icon, name, one sentence, three buttons, date and number; nine
  words of instruction (screenshot 24 Oct). ^f1
  > Get 6 chances to guess a 5-letter word.
  > October 24, 2026
- [ux/puzzle] Guess: type on a physical or on-screen keyboard into a 5x6 grid of about
  62 px tiles; each tile turns green, yellow or grey, and the keyboard keys take the same
  colours, so the state of every letter is visible without reading (screenshot
  wordle-feedback.png). ^f2
- [ux/layout] Phone at 390 px: Play first opens a full-screen ad with a "Continue to
  Wordle" bar; the game screen after it fits header icons, the grid and the full keyboard
  with no ad (screenshots wordle-phone-interstitial.png, 24 Oct). ^f3
- [ux/puzzle] On a loss the answer shows as a short toast, then an account wall takes
  the screen: stats and streaks now need a free NYT account. ^f4
  > Create a free account to start tracking your stats and streaks
  > You need one to track your stats online and in our apps.
- [ux/puzzle] Checked, not there: no explanation after the answer; the word is the whole
  reveal. ^f5

## Read

- Splash, play to a loss, desktop and phone.

## Not read

- Stats modal and share text (behind the account wall in this run).
