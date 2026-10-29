# Learn

Identity: draft ideas as puzzles from real games: guess first, then the real number, then
one line you can use. Plan 24 Oct 2026, team run 2026-10-24-ui (session play). Mock:
data/team/2026-10-24-ui/mocks/learn.html. Content background: docs/learn-proposal.md.

## Who comes and why

- Curious players: "is that true?" moments (mains win 4 points more than new players;
  winning lane is not winning the game), a few minutes at a time
- Newer players: what the roles are, what a counter is, which champions are early or late
- Riot's reviewer: "ways for players to evaluate and improve" (policy "Please Do")

## What Jacob said (24 Oct)

- "the sentences are sometimes way too confusing, like so hard to understand what its
  asking, but it is cool"
- "the basics is waaaaaay to basic, cant just give every answer and expect that to be fun
  or interesting, maybe give other examples no the exact answer but still have the
  answers be reasonably easy if that makes sense, like quite obvious counters,
  synergies, roles"
- Earlier (20 Oct): "too easy, its gotta make someone think ... the best question was wr
  or switching to counter vs playing what you know"

## What is wrong today (live, 24 Oct)

- Questions carry their setup in the sentence: "Players on a champion they have barely
  played (under 10,000 mastery points) win 47.7% of games. Players with 300,000+ points
  on their champion win how often?" (27 words, two numbers to hold in your head)
- Basics shows the answer then asks it: the Roles lesson lists "Jungle: Viego, Kayn,
  Kha'Zix", then asks "Which role is Viego played in most?"
- Three tabs (Puzzles 0/18, Basics 0/5, Practice Level 1) with three looks and no path
  between them; Practice's 4-option drills have no clear answer (the model's own top
  option in 24 of 71 easy drills, learn-proposal.md)
- The slider starts at 52.5% and scores "Spot on" untouched (ui-audit.md Learn)

## Structure: chapters, one puzzle a screen

Tabs go. Learn becomes a path of chapters; each is 3-6 puzzles of one idea, then its
takeaway. A first visit lands on the first puzzle, not on a map; the map is one tap
away (the chapter strip at the top).

| # | Chapter (tile title, a question) | Puzzles (live today unless new) |
| --- | --- | --- |
| 0 | What does each role do? | Starter: roles, obvious counters, early or late, damage, duos (new, from Basics) |
| 1 | Does knowing your champion matter? | know (mastery bands), newcomer (Rengar vs Vayne) |
| 2 | Whose lead wins games? | fed (other four behind), fed top vs bot, 5k behind at 15, bounty gold |
| 3 | Does winning lane win the game? | lane (Pyke vs Thresh), lean hook (Draven), lean x4 |
| 4 | Counter, or just strong? | counter top, counter mid (bot when one clears) |
| 5 | Myth or measured | split pushers, comp win conditions (only the damage mix shows), luck (Riven) |

Chapter 0 replaces Basics with puzzles that do not give the answer away: the lesson
screen shows three examples as tiles, the questions ask about other champions that fit
the same idea clearly (Jacob's "other examples ... reasonably easy"):

- Roles: tiles "Jungle: Viego, Kayn, Kha'Zix"; question "Which role is Lee Sin?" Only
  champions with 95%+ of their games in one role and in the top half by games
- Counters: tiles of one known counter ("Malphite into Yasuo"); question on another
  pair whose gap is big and clear (4+ points under usual, 2 SE, 500+ games), both
  popular: "Who wins this lane more often?" with the two icons
- Early or late: tiles Draven (early), Kayle (late); question "Kassadin: early or late?"
  from `meiolol lean` clear rows only
- Damage: "Which of these deals mostly magic?" with three champions not on the tiles
- Duos: bot and support pairs only (the one ally pairing that shows, 1.3-1.6 points,
  learned.md Win); a pair ships only when clear of 2 SE, else the question is dropped

## Questions: short, the setup as a picture

Rule: the question is at most 12 words and holds no numbers; any number the player needs
goes in the setup above it as UI (a StatStrip, a bar with a "?" bar beside it, champion
icons with a gold Chip). Rewrites of the live set:

| Puzzle | Today (words) | New setup | New question (words) |
| --- | --- | --- | --- |
| know | 27 | two bars: "New (<10k)" 47.7%, "Main (300k+)" ? | "How often do mains win?" (5) |
| newcomer | 16 | Vayne bot, Rengar jungle tiles | "New players struggle most on...?" (5) |
| fed | 28 | five lane rows: you +1,000 at 14, the other four behind | "How often does your team win?" (6) |
| fed top/bot | 12 | top +1,000 vs bot +1,000 | "Whose lead wins more?" (4) |
| lane | 27 | Pyke vs Thresh icons, Chip "Pyke ahead at 14: 64%" | "Who wins more of these games?" (6) |
| lean hook | 32 | Draven icon, Chip "+850 gold at 14" | "Even at 20 min: wins more or less?" (7) |
| lean x4 | 10 | champion icon and role | "Early or late?" (3) |
| counter | 19 | Yone top; three opponent icons, each "Yone loses" | "Which is a real counter?" (5) + toggletip "real counter" |
| ff | 21 | StatStrip "−5,000 gold at 15", "/ff" Chip | "How often does it still win?" (6) |
| bounty | 22 | Chip "a kill: ~300 gold" | "Behind by 3,000+: what does a kill pay?" (8) |

## First screen

1280 (content column 720 px, centred with the chapter strip above):

```
Learn   [● ● ● ○ ○ ○] Chapter 1: Does knowing your champion matter?   3/18 ·  ★ 7
┌──────────────────────────────────────────────────────────────┐
│ New (under 10k points)   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░  47.7%          │
│ Main (300k+ points)      ░░░░░░░░░░░░░░░░░░░░  ?              │
│                                                              │
│ How often do mains win?                                      │
│ 40% ───────────────────────────────────────── 65%  (no thumb)│
│                                          [Lock in] (disabled)│
└──────────────────────────────────────────────────────────────┘
```

- Chapter strip: one dot per chapter (done, current, locked never: all open), the
  chapter's question, progress, stars. Tap: the map (ChapterMap sheet, tiles with each
  chapter's question, progress and the tip earned)
- 390: same, the setup bars full width, the slider 358 px, Lock in full width

Words on the first screen: "Learn", chapter title 7, setup labels 6, question 5,
"Lock in" 2 = 21. Today: 46 (title, sub header, tabs, the 27-word question, button).

## After the answer

- GuessSlider shows both markers on the same track ("You 55%", "Real 51.7%") and a
  closeness Badge ("3.3 off", stars 0-3); no orange/green headline sentence
- The setup bars complete themselves: the "?" bar fills to 51.7% with its games, and
  the full table behind it (5 mastery bands) as the Chart preset OutcomeCurve, games
  under each point, the asked one highlighted
- Why: one line, at most 20 words ("4 points from new to main: more than a typical top
  lane counter, 2.5")
- Tip: the Takeaway line (one sentence, accent rule on the left)
- Source: a "from" Toggletip on the games count, not a visible line
- Next: one button; Enter

Pick puzzles reveal in place on the ChoiceCards (right one marked, each with its
number and games), then the same why and tip. Counter puzzles add a ReasonBreakdown-
like pair of bars per opponent: "Yone vs Jax" against "Jax vs everyone".

## Chapter end and the drills

- End of a chapter: the takeaways of its puzzles as a list of Takeaway lines, score,
  "Next chapter"
- Practice drills (4-option drafts) leave the default path: their answers are not clear
  (34% agree with our own model). They come back as one "draft" puzzle per chapter end
  (proposal's boss) only where one option is clearly apart, on the DraftBoard with
  ChoiceCards, revealed with each option's reasons in words (J2), never "+X%"; Learn's
  own short list, not CandidateList (its code put ui-learn.wasm over 40 KB)
  Clearly apart: the four teammates' magic shares average under a fifth (stands in for
  learned.md's team share, Win, Sure), exactly one option brings 60%+ magic (an option
  of unknown share rules the draft out), and it is also the model's best of the four.
  Box pack 27 Oct: 2-3 such drafts a day, each used once, so some chapters end without
  one; the why line ("little magic damage") carries no number (that finding's Site:)
- Daily five (later): one puzzle per finished chapter, same for everyone, ResultStrip (days)

## Components used (register names)

New (requests): PuzzleCard, GuessSlider, ChoiceCards, DraftBoard (drills), ResultStrip
(later). Page-only: ChapterMap (tiles), ChapterStrip (dots) unless another page needs a
progress path. Existing: ChampIcon, Chip, Badge, StatStrip, StatCell, Bar (BarList: Bar rows with
label and games; foundation to say if that is its own entry), Toggletip, Card, Button.

## Interactions

- Slider: no value until touched, its scale and "Tap or drag" shown; drag or arrow keys;
  Lock in enables on first move; Enter commits
- ChoiceCards: choose, then Lock in; keys 1-9
- Chapters aside (mock round 4, in place of the dots and sheet): every chapter with
  its progress, tap to jump; Your tips: this chapter's earned ones
- Progress, stars and tips earned in localStorage (try/catch, as now)

## Data needed

- Every live puzzle: exists (src/site/puzzles.zig, hand-written and generated); the
  rewrite moves numbers into setup fields: new `setup` per puzzle (bars or chips), a
  question rewrite each. Small
- Chapter takeaways: chapters 1-5 have their puzzles' tips; chapter 0 needs its own
  (none written yet). Small
- Chapter 0 (Starter): role shares (exists), clear big matchups (exists: matchup vs usual,
  games, SE), lean rows (exists), damage profile (exists), bot-support duo terms (exists;
  may yield none clear: then no duo questions). Selection rules in learn.zig. Small-medium
- Counter reveal's "vs everyone" bar: exists (the opponent's own rate is computed)
- "Your lane, your game" by role (proposal chapter 3): needs one export from the pack
  (learn-proposal.md "Data each part needs"). Medium, later
- Drills as chapter-end drafts with a clear option: needs a filter on practice.json
  (one option's low end above the others' high ends). Small-medium

## What is cut

- The sub header "Guess first, then see what the games say."
- Tabs Puzzles / Basics / Practice; the Basics lesson text that names the answers; the
  per-question "1 of 18: Play what you know" line (the chapter strip says it)
- Visible source lines ("Ranked solo, Platinum IV and up, every region, 1.92M ...")
- Practice's "Role and your champions" fold and level cards on the default path

## What the desktop could reuse

PuzzleCard and GuessSlider as a "while you queue" card in the app (outside champ select;
no live advice). DraftBoard and ChoiceCards come with the champ select work anyway.

## Questions for Jacob (24 Oct)

1. First visit straight into puzzle 1 (map one tap away), or the map first?
2. Practice drills: drop from the default path and keep only clear chapter-end drafts?
3. Stars for closeness (GeoGuessr style), or just right/wrong marks?

## Jacob's answers (25 Oct)

Override the sections above where they differ.

1. Neither as drawn: "Map + lesson 1 ... feels like too much with that big text first";
   too much shown at once with the scroll down the page. One thing per screen, smaller
   heading; rework in the visual pass
2. Drop Practice drills from the default path; clear chapter-end drafts only
3. Stars 0-3

## Jacob's answers (review v6, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v2-*.

1. v6 first screen "too empty now, doesnt look great" (24 Oct: too much at once): find
   the middle (mocks round 3). Mastery reveal as columns not settled
2. Chapter 0 role rule: not fussed; decided 90% (keeps Lee Sin, 92.7% jungle)

## Jacob's answers (review v7, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v3-*.

1. Mastery reveal: rows ("not really linear along x")
2. Keep it in the site's style; he thinks it is, but is not used to the new style yet

## Jacob's answers (review v9, 25 Oct)

Override the sections above where they differ. Raw: review artifact db, ids v4-*. No re-review: refine while building.

1. Round 4 "lgtm"
