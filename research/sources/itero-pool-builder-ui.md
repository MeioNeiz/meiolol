---
title: iTero Champion Pool Builder (Oct 2026)
url: https://www.itero.gg/champion-pool-builder
kind: project
commit: 
for: [lol-site-ui]
looked: 2026-10-24
depth: docs (whole wizard run once: top lane, Gold, no mastery; rendered text per step; screenshots desktop and phone)
relevance: high
grade: B/fair
description: iTero's web champion pool builder: a one-question-per-screen wizard that fills seven named slots (2 core, 3 situational, 1 pocket, 1 damage) and ends on a pool-by-"Good vs" portrait grid, no numbers
---
# iTero Champion Pool Builder (Oct 2026)

Why: lol-site-ui, kind 7 (pool and draft tools): how a pool is chosen and how its
coverage is shown. Screenshots in data/team/2026-10-24-ui/refs/pool-draft/ (gitignored):
itero-pool-slots.png, itero-pool-uncountered.png, itero-pool-result.png. Raw is the
rendered text of each wizard step, joined.

## Assessment

- Evidence: B. iTero (GIANTX) claims 500k+ downloads ([[europeangaming-itero-standalone#^f1]]);
  the pool builder is a free web tool beside its Overwolf app.
- Reasoning: fair. Each step says why in a sentence (blind pick first, then a different
  playstyle, then answers to uncountered champions); the scores behind tiers are hidden.
- Interests: vendor; a large "Outdraft, outbuild and outplay" banner sells the app on
  every step.
- Weigh: the slot structure and the coverage grid are the ideas to borrow; the chatty
  narrator copy is what Jacob does not want.

## Findings

- [ux/features] [ux/layout] The pool has a fixed shape shown as a strip of seven slots
  across the top of every step, locked until reached: Core Picks (2), Situational Picks
  (3), Pocket Pick (1), Damage Pick (1) (screenshot 24 Oct, itero-pool-slots.png). ^f1
  > Core Picks ... Situational Picks ... Pocket Pick ... Damage Pick
- [ux/controls] One question per screen: explain the AI (skip), use champion mastery or
  not, Elo bracket dropdown, lane as five role icons, then one slot at a time with Go
  back and Skip or Continue. About 12 screens for a full pool. ^f2
  > With that in mind, would you like me to use your Champion Mastery whilst we're creating a Champion Pool?
  > What lane are we going to be building a pool for?
- [ux/features] First slot asks for a blind pick: strong this patch, hard to counter,
  ideally experienced; suggestions come as three rows of three portraits labelled S+, S,
  A+, with "Select another champion" for any other. ^f3
  > The very first Champion you'll want to add to your pool is someone you'd be happy to take in most situations. A solid blind pick.
  > Don’t like these suggestions?
- [ux/features] Second core slot drops champions too similar to the first. ^f4
  > Here's the same list again, except I removed options that are too similar to your first choice.
- [ux/features] Coverage is shown as a grid of champion portraits the pool has no good
  answer to (16 for two top laners), titled in red; each situational slot then offers
  answers to them, and the grid shrinks after each pick (screenshot
  itero-pool-uncountered.png). ^f5
  > Uncountered Champions
  > Champions we may still struggle against.
- [ux/features] Pocket pick is a check, not a slot to fill: it names one popular champion
  the pool still loses to and offers picks for it. ^f6
  > Your pool covers a huge range of situations already, however, there's one major threat we've missed.
  > I recommend you have one of these pocket picks, in the high likelihood that you face Mordekaiser in your games!
- [ux/features] Damage pick is a pass or fail check on the pool: at least one AP and one
  AD champion. ^f7
  > Checking to see whether your pool contains at least one AP and one AD pick
- [ux/density] Result: one row per pool champion grouped under Core, Situational and
  Pocket, each with up to 16 "Good vs" portraits (two rows of eight, about 60 px each),
  a role picker to switch the opponents' lane; no numbers, win rates or scores anywhere
  on the result (screenshot itero-pool-result.png). ^f8
  > And with that, we're done! What a squad we've built here.
- [ux/uncertainty] Checked, not there: no sample sizes, win rates, difficulty or time to
  learn on any step; tiers (S+, S, A+) are the only strength signal. ^f9
- [ux/layout] Phone: the wizard stacks well at 390 px (slots, text box, a 3x3 portrait
  grid), but the 770 px wide banner and the narrator text push the suggestions below the
  first screen (screenshot 24 Oct). ^f10
- [policy] (inferred) Suggestions as portraits under tier labels with "Good vs" lists
  avoid "best pick" and win rate wording entirely; the same shape fits our 3-5 options
  with reasons rule. ^f11

## Read

- Every wizard step for one run, and the final result.

## Not read

- The "Yes please!" AI explanation; mastery-based runs (needs a Riot ID).
