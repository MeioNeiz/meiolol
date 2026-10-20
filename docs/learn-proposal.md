# Learn: a proposal (20 Oct 2026)

Learn as a puzzle game where the player works each draft idea out from real games,
then gets the idea named, the numbers behind it and one practical tip. Research:
research/questions/teach-draft.md. Effect sizes: docs/learned.md (sections named below).

## The problem in 5 lines

1. It is a quiz: five lessons state League facts, then ask them back; nothing is found out
2. Practice drills one rule ("add the damage type your team lacks") that is small and rare:
   lopsided teams lose about 3 points and only 1 team in 10 is lopsided (learned.md Win)
3. The drill's "answer" is our own model's top option in only 24 of 71 easy drills (34%,
   chance is 25%); the four options sit a median 1.7 points apart, so there is no answer
4. Coin flips are quizzed ("Yasuo or Yone in mid?") and feel unfair: within noise
5. Feedback restates the rule; the one thing that wowed Jacob (play what you know, 44% vs
   51.5%, beats a counter of 2 to 4 points) is one question buried in lesson 2

Checked 20 Oct on meio.lol: live page text, learn/practice.json (223 drills), learn.js
reveal and hints, src/site/learn.zig lessons.

## Principles

- **Discover, then name.** Each idea opens with a question the player answers from real
  games (predict, compare, find the odd one out); the idea's name and numbers come after
  they have committed to a guess. Hints on request, never the answer up front
- **Only clear, surprising answers.** A puzzle ships only when its answer is clear of
  noise (2 SE, hundreds of games or more) and big enough to matter (3+ points of win
  rate, or 200+ gold at 14, J11). No near-even matchups, no single-game "why it won"
- **Numbers make the reveal.** "You guessed 55%. Real: 41% of 1,820 games." Counts on
  every number (J10). Facts about games, never a pick's "+X% win rate"
- **One idea, then practise it, then mix it in.** Five practice puzzles of the idea just
  found, later ones mixed with earlier ideas (spaced review); a daily set keeps a streak
- **Tips are takeaways.** One line a player can use in their next champ select: "Blind
  pick a champion with few hard lanes"
- **Honest about draft.** The draft decides little (a whole draft rarely leans clearly);
  your champion and your lane matter more. That is itself a chapter

## What the research says (research/questions/teach-draft.md)

- Try first, then teach: attempting before the idea is explained beats explaining first
  for understanding (Kapur meta-analysis, 53 studies); the explanation should contrast
  the player's own answer with the real one (C1, C3)
- Guided, not pure, discovery: a hint on where to look, without the rule, is enough (C2)
- Predict then reveal works only when the guess is committed first and the answer comes
  at once; confident wrong guesses stick best (C4)
- lichess makes puzzles from real games and keeps only those with one clearly best
  answer, after players complained about puzzles with two (C8): our coin-flip problem
- Puzzles and players on one rating scale from attempts picks the next puzzle (C9);
  themes drillable alone, but the default round mixes them so the player has to spot
  which idea applies (C10); Duolingo brings back weak and fading items over days (C11)
- Fun modes (streak, rush) beside learning, unrated; streaks with forgiving breaks (C12,
  C13)
- Chess explains little in words because the moves explain themselves; a draft puzzle
  has no line to replay, so our reveal must say why, with numbers (C14)
- Coaches (weak sources) order solo queue draft as comfort, then team structure, then
  counters, and want blind picks safe (C7): our data agrees on comfort and counters

## Findings big and clear enough for puzzles (ranked by size and surprise)

Each: finding (docs/learned.md section, date); size; surprise; clear?; puzzle.

1. Your own lane in a game: 1,000-1,700 gold ahead at 14 wins 37-51 points more than as
   far behind; 0 deaths before 15: 65-71% won, 4+: 31-39% (Early game, 20 Oct). Huge;
   medium surprise; clear, 878k games. "Guess the win rate" slider
2. A matchup where one side is usually ahead at 14 is not one it usually wins: -2.6 to
   +2.3 points per 1,000 gold across matchups (same line). No effect, which is the
   point; high surprise; clear. "Ahead in lane, so wins?"
3. Early and late champions: Draven's team ~900 gold up at 14 but from an even game at 20
   wins ~8 points less; Kayle top ~800 behind and ~14 more (Win, 14 Oct). 8-14 points;
   high surprise; 153 of 429 champion-roles clear. "Who wins the long game?"
4. Play what you know: new to a champion 44%, known 51.5% (external, 1M games); our
   model: 10 games vs none ~+4 points for one player (model.md "Player experience");
   counters 2 to 4. 4-7.5 points; high surprise; external clear, ours see caveat. The
   mastery vs counter duel Jacob liked
5. Your win rate over 10-20 games is mostly luck: it swings ~15 points by chance, real
   spread between players at most ~3 (Player, 15 Oct). High surprise; clear, 6,952
   player-champion pairs. "Is this player good on Riven?"
6. The bot laner's gold counts most: 1,000 gold is 6-12 points on bot, 1-3 on support
   (Win, 13 Oct). Medium surprise; clear, 118k games. "Whose lead matters?"
7. Almost no magic damage: under a fifth magic loses ~5 points, lopsided ~3, extremes ~10
   (Win, 13 Oct). Low surprise; clear only for real extremes (1 team in 10 lopsided).
   Spot the problem draft
8. Counters are real but mostly the enemy's own strength: matchups spread ~2 points in
   top and mid, ~1 in jungle and support; 40-90% of that is the opponent being strong or
   weak (Win, 20 Oct, early). High surprise; clear by role, single matchups only far
   from usual. "Counter or just strong?"
9. A whole draft rarely leans: none of 9 Daily Drafts clear of even, a lean needs about
   38/62; champions alone pick the winner ~55% (Win, 18 and 13 Oct). High surprise.
   "Myth or measured"
10. Not found in solo queue: dive vs peel, engage vs disengage, split vs waveclear, team
    counters beyond lane, comeback champions (Win 14 Oct, Early game 13 Oct). Bounded
    nulls; high surprise. "Myth or measured"
11. Bot and support pairing 1.3-1.6 points, no other ally pairing shows (Win, 14 Oct).
    Later
12. Kit leans (Malphite into magic damage, Rammus into auto-attackers): 1-2 per step, dev
    only, no held-out look. After the held-out look

Not puzzle material: single close matchups, damage mix on teams that are not lopsided,
runes, any one game's "why".

Caveat on 4: our own learning curves (pool page "How long champions take to learn")
show no first-games gap (median first 5 games minus usual -0.1 points, 90 champions),
because the 16-day crawl window counts returning players as new (src/learning.zig). Use
the external number with its source until pre-game mastery (mastery_pre.tsv) gives ours.

## The new flow, screen by screen

**Home: the map.** Chapters as a path (5 to start), each a tile with its question, not its
name ("Does winning lane win the game?"). Done chapters show the tip earned. A "Today's
5" tile: one puzzle each from chapters done, same for everyone, streak count. No tabs.

**Chapter, screen 1: the hook.** One question with a commitment: a slider ("What share of
games does the team win when its mid laner is 1,500 gold up at 14?") or a two-way pick.
Nothing else on screen.

**Screen 2: the evidence.** Three or four real cases as tiles: champion icons, a small
lane curve or a win bar with games. The player sorts, compares or picks the odd one out
("Two of these matchups are counters, one is just a weak champion: which?"). "Show a
hint" reveals one nudge at a time ("Look at each enemy's win rate against everyone").

**Screen 3: the reveal.** Their guess beside the real number with its count, one chart (a
lane curve, a win bar by gold lead), then the idea named in five words and the tip in a
coloured box. Closeness scored like GeoGuessr (a guess within 3 points: 3 stars).

**Screens 4-8: practice.** Five puzzles of the same shape on new cases, each with a clear
answer (filter: 2 SE, size floor), quick: tap, see the number, next. Difficulty rises by
how close the cases sit, still clear. Wrong answers come back later.

**Chapter end: the boss.** One real draft where the idea is the deciding fact: "Your top
laner picks Kayle into Darius. Your team's plan?" Options in J2 tiers (strong fit, also
fine, weaker here) with reasons; no "correct pick".

### Puzzle types (all with a clear answer, hints on request, numbers on reveal)

- **Guess the number**: slider, scored by closeness ("Teams 1,500 up at 14 win ?%")
- **Duel**: two options, one clearly better on the numbers (mastery vs counter-pick)
- **What do they share?**: four real cases, e.g. four teams behind 1,000 at 14 that won;
  pick the common clue (all had a late champion). A pattern over cases, never one game
- **Odd one out / counter or just strong**: three matchups, find the one that is a true
  counter once the enemy's own win rate is allowed for
- **Spot the problem**: a real draft with one measured flaw (under a fifth magic damage,
  a counter-pick on a champion the player has never played); tap the champion or the gap
- **Myth or measured**: a coaching claim, real or myth, then the size or the bound

### First five chapters (order: most usable first)

1. **Play what you know** (finding 4): duel puzzles: "You: 3 games on the counter
   pick, or 80 games on your main into a bad matchup?" Tip: keep 2-3 champions per role
   you have 10+ games on; counter-pick with one of them
2. **Winning lane is not winning the game** (2, 3): "Draven's team is usually 900 up at
   14. From even at 20, more or fewer wins than an average bot laner?" Practice: early or
   late, from champion lean lines. Tip: against a late champion, end it before 30
3. **Your lane, your game** (1, 6): guess win rate by gold lead and deaths before 15;
   whose lead matters. Tip: dying twice before 15 costs more than most counters
4. **Counters: real, small, mostly the enemy** (8): "counter or just strong?" from
   matchup tables with vs usual. Tip: blind pick a champion with few hard lanes; counter
   where it pays most (top and mid)
5. **Myth or measured** (7, 9, 10): ten coaching claims, swipe real or myth, reveal with
   the measured size or the "not found, at most X" bound. Tip per myth

Later: **luck** (5, "is this player good?"), bot duo (11), kit leans (12) once held out.

## First version, buildable in a day

Chapters 2, 4 and 5, each hook, evidence, reveal and five practice puzzles, plus the map
with progress in localStorage (try/catch as now). Chapter 1 as one hand-written
chapter from its current lesson text (external source cited). No adaptive rating, no
daily set, no boss yet. JS over existing exports, plus hand-written myth cards.

## Data each part needs

- Play what you know: mastery vs win rate (external number now; our pre-game mastery
  not yet, mastery_pre.tsv filling); matchup sizes (have)
- Winning lane is not winning: champion lean per role, gold at 14 and win from even at
  20 (have: `meiolol lean`, champion page lines)
- Your lane, your game: win rate by gold lead at 14 and deaths before 15, by role
  (learned.md only; needs one small export from the snapshot pack, method in
  data/team/2026-10-19-night/design-impact.py)
- Counters: per-champion matchup rows with vs usual, games, SE (have: champion pages'
  opponents tables, usualK)
- Myth or measured: claims with sizes and bounds (hand-written from learned.md)
- Boss drafts: real drafts where one idea is clearly the deciding fact (partly:
  practice.json drafts, needs a filter per idea)
- Today's 5 and ratings: a shared daily seed (have, Daily Draft's); per-puzzle difficulty
  from answer rates (needs a server count, later)

## Rules

- Learn is outside champ select: no live advice, no auto pick (production-key.md
  "Product rules")
- Numbers with counts are fine (J10); facts about games, never a single pick's "+X% win
  rate" or "best pick"; draft puzzles keep options in tiers with reasons (J2)
- Real games show champions, ranks and patch; no player names (not needed to teach)
