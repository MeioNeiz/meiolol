# meio.lol as it stands, 17 Oct 2026

**Status 17 Oct 20:40 (main b0ed63a):** 37 of the first 47 findings fixed (31 confirmed
by re-walk or script), 4 partly (R4, R25, R45, R47); open are the 6 that wait on Jacob
(R3, R12, R13, R16, R18, R34; decisions J1 to J9) and the re-walks' new findings R48 to
R62, of which 3 are fixed and a polish round (fix3) is on 8 more. No known bug left in
code; R45 waits on an install on jomove. Next steps for normal ranked players:
docs/review/next-steps-2026-10-17.md (Q1 to Q4).

Persona walks and an expert review of the live site (deploy 0fa7732 to 6c6631c), merged
into one list of findings with stable ids (R1, R2, ...). Source ids in brackets point into
the team's notes: D, P, A = expert review; T = Draft tester walk; S = public site walk;
M = admin walk; draft N, site N, AN = re-walks after the fixes. Fix agents update Status;
the report agent folds results in.

## After the fixes

Three fix rounds (17 Oct 19:48 to 20:37, 0406809 to 921520c), then the same studies,
personas and model re-walked on the live site (draft 20:18, site 20:16, admin 20:35):
runs meiolol-draft/20261017-201851, meiolol-draft-extra/20261017-201853,
meiolol-site/20261017-201656, meiolol-site-phone/20261017-201659,
meiolol-admin/20261017-203531. Only the studies' hidden check texts changed (the trust
checks expect Platinum IV+ and the new model line; persona-walk c2d7c42, b0d385c,
7447230), so runs compare. Times vary with model and server speed: read them loosely.

Success, median steps, median time (before / after):

| area | task | success | steps | time |
| --- | --- | --- | --- | --- |
| draft | best-pick | 3/3 / 3/3 | 21 / 19 | 75 / 45 s |
| draft | why-top | 3/3 / 3/3 | 4 / 4 | 21 / 18 s |
| draft | compare-two | 3/3 / 3/3 | 8 / 7 | 30 / 20 s |
| draft | blind-pick | 3/3 / 3/3 | 2 / 1 | 18 / 9 s |
| draft | counter | 3/3 / 3/3 | 4 / 4 | 19 / 16 s |
| draft | trust | 1/3 / 3/3 | 1 / 1 | 15 / 13 s |
| draft | presets | 3/3 / 3/3 | 2 / 2 | 16 / 12 s |
| draft | bans | 1/3 / 3/3 | 7 / 6 | 29 / 23 s |
| draft | flex (roles unknown) | 2/3 / 2/3 | 16 / 17 | 57 / 64 s |
| draft | deep-read | 3/3 / 3/3 | 5 / 4 | 30 / 23 s |
| site d | pick-into | 1/3 / 1/3 (check 3/3) | 15 / 12 | 49 / 52 s |
| site d | matchup-why | 3/3 / 3/3 | 8 / 5 | 23 / 25 s |
| site d | daily-draft | 3/3 / 3/3 | 4 / 4 | 13 / 15 s |
| site d | learn | 3/3 / 3/3 | 4 / 4 | 12 / 12 s |
| site d | trust | 3/3 misled / 3/3 right | 2 / 2 | 14 / 8 s |
| site d | desktop-app | 3/3 / 3/3 | 3 / 1 | 14 / 6 s |
| site d | privacy | 3/3 / 3/3 | 3 / 3 | 11 / 10 s |
| site p | pick-into | 2/3 / 1/3 (check 3/3) | 13 / 14 | 50 / 61 s |
| site p | daily-draft | 3/3 / 3/3 | 5 / 5 | 20 / 15 s |
| site p | trust | 3/3 misled / 3/3 right | 2 / 2 | 12 / 8 s |
| site p | desktop-app | 2/3 / 3/3 | 5 / 1 | 19 / 7 s |
| admin | crawler-health | 3/3 / 3/3 | 0 / 0 | 6 / 6 s |
| admin | games-today | 0/3 / 3/3 | 1 / 0 | 9 / 3 s |
| admin | last-deploy | 3/3 / 3/3 | 1 / 1 | 7 / 7 s |
| admin | model-quality | 3/3 / 3/3 | 2 / 2 | 11 / 10 s |
| admin | log-errors | 1/3 / 2/3 | 3 / 2 | 15 / 12 s |
| admin | lab-results | 3/3 adequate / 3/3 (self-rated 0/3) | 2 / 2 | 13 / 11 s |

Success is self-report read against the study's check; site and admin rows give the
judged result, with self-rating in brackets where they differ.

What moved:
- Trust, everywhere: Draft tester trust 1/3 to 3/3 (all quote Platinum IV+, 825k games,
  54.8% against a coin's 50%); 6/6 site trust answers now say Platinum IV and above, none
  "every rank"; admin model answers lead with one accuracy, no AUC.
- Draft tester: bans 1/3 to 3/3 (R7 sort names); no false lane error in 6 runs (R1);
  "Vi" gives Vi (R5); breakdown and search survive the poll, picker in view on a phone
  (R2, R6, by script).
- Site: desktop app one click from home on every run (was 3 to 5, one gave up);
  matchup-why 8 to 5 steps (index search); Daily words, guess tags and phone tables read
  cleanly.
- Admin: games-today 0/3 to 3/3 with no click; Logs found first click 3/3; restart
  markers, spike lines and UK times landed where personas looked first.

What did not:
- Pick-into still spends its budget: the route moved to the matchup index search, and
  the cost moved to Back losing the filter and one-name search (R54, R55, both since
  fixed in 9f5fe61, not re-walked). The real gap is R18 (J6).
- Flex is unchanged (R12, J4); every tester persona still reads +X points and the win
  bar as the answer (R13, J2); the top pick's lump is still unexplained (R3, J3).
- Lab results self-rated partial 3/3 for a new reason: nothing says what to act on (R58).
- Not reached by any task: R19, R20, R30, R31, R35, R45.

New findings from the re-walks, R48 to R62 (sections 3.1 to 3.3 hold the details):

| id | finding | source | sev | type | status |
| --- | --- | --- | --- | --- | --- |
| R48 | Tester: name click picks; nothing shows the row opens the why | draft N1 | minor | Design | open (fix3) |
| R49 | Tester: model line's open fold is jargon; ticks read as quality | draft N2 | minor | Design | open (fix3) |
| R50 | Tester: no "too close to call" when top ranges overlap | draft N3 | minor | Design | open (fix3; rule J2) |
| R51 | Tester: random drafts at 58 to 65% look broken; the spread is right | draft N4 | polish | Design | open (not a bug) |
| R52 | Tester: "points" and "±0.4" never say what they are | draft N5 | polish | Design | open (fix3) |
| R53 | Tester: "lock" explained only in a tooltip | draft N6 | polish | Design | open (fix3) |
| R54 | Site: Back restores the search text but not the filter | site N1 | major | Bug | fixed (9f5fe61) |
| R55 | Site: matchup index search takes one champion; Mid below Top and Jungle | site N2 | minor | Design | fixed (9f5fe61) |
| R56 | Site: "Desktop app" page vs "champ select helper" link | site N3 | polish | Design | fixed (07ab3c2) |
| R57 | Site: matchup pages give no plain even / ahead / behind verdict | site N4 | minor | Design | open (next steps) |
| R58 | Admin: Models and Lab don't say what to act on | AN1 | minor | Design | open |
| R59 | Admin: "116% of the way there" beside 54.8% vs published 55 to 57% | AN2 | minor | Design | needs Jacob (J5) |
| R60 | Admin: 429/403 spikes and 97% key use without saying if they matter | AN3 | minor | Design | open (fix3) |
| R61 | Admin: logs one file at a time; no per-file error counts | AN4 | minor | Design | open (fix3) |
| R62 | Admin: "better than today's model (-0.0003 a game)" reads backwards | AN5 | polish | Design | open (fix3) |

## 1. Summary (first walk, before the fixes)

For a normal ranked player on today's patch, the public site is fast, honest about its
limits and good at "how sure is this" (matchup pages, ranges, game counts, Learn's
mastery-beats-counters lesson). It is weak at the question every walk started with,
"what should I pick into their champion": there is no direct route, and until 0406809 the
champion search was dead. The Draft tester (admin, the future public picker) is quick to
enter a draft and its numbers add up, but it breaks trust on load (a false "lane model
didn't load" banner), its most common top reason is an unnamed lump, and its main signal
(+X points of win chance) is one the public product may not show. Two public pages state
things that are not so: Method says players come from every rank tier (the data is
Platinum IV and up), and the Daily Draft headline gives a whole-draft win chance the
project's own rules exclude.

Top ten issues, all sources:

1. R16 Public Daily Draft shows a whole-draft win chance and "+X points" per option, the
   most-read number on the page (blocker; Jacob decides)
2. R17 Method and data labels say "every rank tier" / "all ranks"; the crawl is Platinum
   IV and up; 6 of 6 trust answers repeated it (major Bug)
3. R1 Draft tester loads its models up to three times at once; the race shows a false
   "lane model didn't load" error in every walk run (major Bug)
4. R3 The tester's top pick's only reason is "other pairings"; detected cross-role
   groups are lumped (major; naming is Jacob's call, learned.md supports it)
5. R13 The tester's primary signal (+X points, win bar) cannot go public; the public
   picker needs another one before more UI is built on it (major, roadmap; Jacob)
6. R18 No direct "my pool into their pick" view on the public site; every pick task used
   its whole step budget (major Design; Jacob)
7. R19 Champion pages rank "hardest" opponents by raw win rate on 10 to 20 games (major)
8. R2 The admin poll every 30 s closes the open breakdown and clears the search (major
   Bug; walks did not stay long enough to see it)
9. R36 Admin warning classifier: TW2 mastery "Blocked" counted as DB busy, 429s counted
   as Riot 5xx (major Bug)
10. R20 Learn's practice reveal names single cross-role pairs the data says are not
    detectable (major Design)

Since then: all of these but R16, R3, R13 and R18 (Jacob's) are fixed; see "After the
fixes" and the status columns.

## 2. Method

**Persona walks.** The persona-walk tool (personal copy at ~/personal/persona-walk,
ported from the Digital Five tool for remote, read-only use) drives Chrome with a model
playing a persona who thinks aloud, gets a task and a step budget, and reports done,
partial or gave up with `unsure` notes. Each run is then verified: a second pass checks
the persona's findings against the page and the code. Studies (studies/ in that repo):

| study | personas | tasks | runs | folder (runs/...) |
| --- | --- | --- | --- | --- |
| meiolol-site, desktop 1440x900 | Sam (Silver mid), Lena (Emerald top, sceptic), Kai (new) | 7 | 3 | meiolol-site/20261017-193101 |
| meiolol-site-phone, 390x844 | Sam, Kai | 4 | 3 | meiolol-site-phone/20261017-193103 |
| meiolol-admin | Alex, Jordan (back after a week) | 6 | 3 | meiolol-admin/20261017-193055 |
| meiolol-draft (Draft tester) | Mia (Gold mid, 30 s timer), Theo (coach), Rosa (Diamond support, sceptic) | 7 | 3 | meiolol-draft/20261017-193055 |
| meiolol-draft-extra | as above | 3 (bans, unknown roles, slow reading) | 3 | meiolol-draft-extra/20261017-194351 |

All runs model sonnet, live https://meio.lol, GET/HEAD only, no /api/ lookups, no admin
actions; no blocked requests and no secret leaks in any run. Draft tester numbers were
also checked offline against the live model files (team walk-draft-tools and
expert-tools: the live admin-draft.js run in Node over 300 to 2,000 random drafts).

**What a persona finding is worth.** A hypothesis. Personas rarely flag problems; the
signal is in `unsure`, backtracks, dead ends and gave-up tasks. Their paths barely vary
(the best-pick task took the same 21 clicks in the same order in all three runs), so
"3 of 3" means one path three times, not three users; the "new player" persona read as
competently as the others, so its results are optimistic. Every finding below was
checked against the code or the live page by the walk or expert agent; where it was not,
it says so.

**Expert review.** A product designer and ranked player's pass with the code open,
scripted read-only Chrome plus offline model checks, 17 Oct 18:45 to 19:30. Screenshots
in the team folder's expert-shots/ (temporary scratchpad).

Severity: blocker (fix before Riot looks or before going public), major (misleads or
breaks the task), minor (confusing, workaround exists), polish. Bug = code does not do
what it means to; Design = works as written, wrong call.

## 3. Areas

### 3.1 Draft tester (admin, https://meio.lol/admin/#models/draft)

Task success (persona self-report, judged against the study's check):

| task | success | median steps | median time | where they stalled |
| --- | --- | --- | --- | --- |
| best-pick | 3/3 | 21 | 75 s | "Vi" + Enter gave Viego (R5); top pick's only reason "other pairings" (R3) |
| why-top | 3/3 | 4 | 21 s | lumped lines not explainable (R4) |
| compare-two | 3/3 | 8 | 30 s | none |
| blind-pick | 3/3 | 2 | 18 s | which column means "safe" (R7) |
| counter | 3/3 | 4 | 19 s | Best for draft and Best into Fiora disagree (R7) |
| trust | 1/3 (2 partial) | 1 | 15 s | no baseline for 54.7%, no rank or region, jargon (R10) |
| presets | 3/3 | 2 | 16 s | Random game vs Random realistic (R11) |
| bans | 1/3 (2 partial) | 7 | 29 s | bans right 3/3; "blind" meaning (R7) |
| flex (roles unknown) | 2/3 (1 partial) | 16 | 57 s | no way to enter "role unknown" (R12) |
| deep-read | 3/3 | 5 | 30 s | big unnamed buckets; lane gold vs matchup line (R4, R9) |

Code: `admin-draft.js` = src/site/static/admin-draft.js, `admin.js` likewise.

| id | finding | sources | sev | type | status |
| --- | --- | --- | --- | --- | --- |
| R1 | Models load up to 3 times at once; race shows a false "lane model didn't load" error | T1, D2 | major | Bug | fixed, verified by re-walk (7b4e07e); gzip on jomove J8 |
| R2 | 30 s poll closes the open breakdown and clears the search | D1 | major | Bug | fixed, verified by script (c7f4003) |
| R3 | Top pick's only reason is "other pairings"; detected cross-role groups lumped | T2, D3 | major | Design | needs Jacob (J3); still seen 3/3 |
| R4 | Unnamed buckets are large and chips do not add up to the row | T7, D8 | minor | Design | partly fixed (c8df953): lumps still carry most of some scores |
| R5 | Search + Enter picks the best-ranked hit, not the name typed (Vi gives Viego) | T3 | minor (major public) | Bug | fixed, verified by re-walk (66ce721) |
| R6 | Opening a slot on a phone shows nothing (picker below the fold) | D5 | major on phone | Bug | fixed, verified by script (c7f4003) |
| R7 | "Best blind lane" tops with picks the Win column calls losing | T4 | minor (major public) | Design | fixed, verified by re-walk (7314d73) |
| R8 | "Best for draft" sorts by the low end, shows the middle | D6 | minor | Design | fixed (7314d73); 2 of 6 only half follow it |
| R9 | Lane gold and matchup line disagree, two game counts for one pair, no word why | T9, D7 | minor | Design | fixed, verified by re-walk (7314d73) |
| R10 | Model line: no baseline, no source, jargon; "checks pass" read as quality | T6 | minor (major public) | Design | fixed, verified by re-walk (99b8785, 2e63f08, 5c8936a); fold: R49 |
| R11 | "Random game" and "Random realistic" are the same; random drafts include off-role picks | T8 | minor | Design | fixed (a24b4b1); the Fill… menu now confuses 2 of 3 |
| R12 | No "role unknown" for enemy picks; ranges hide the role uncertainty | T5, D9 | major public | Design | needs Jacob (J4); still seen |
| R13 | Primary signal (+X points, win bar) is what the public product may not show | D4 | major roadmap | Design | needs Jacob (J2); still seen |
| R14 | Copy and small things (a/an, empty board range, button place, 95%, units, bans) | D8, D9, T10 | polish | Bug/Design | fixed, verified by re-walk (eaa0e9e); ± and lock: R52, R53 |
| R48 | Name click picks; nothing shows the row opens the why | draft N1 | minor | Design | open (fix3) |
| R49 | Model line's open fold is jargon; ticks read as quality | draft N2 | minor | Design | open (fix3) |
| R50 | No "too close to call" when the top rows' ranges overlap | draft N3 | minor | Design | open (fix3; a "safe" rule is J2) |
| R51 | Random drafts at 58 to 65% look broken; the spread is right | draft N4 | polish | Design | open (not a bug) |
| R52 | "points" and "±0.4" never say what they are | draft N5 | polish | Design | open (fix3) |
| R53 | "lock" on each slot explained only in a tooltip | draft N6 | polish | Design | open (fix3) |

**R1. Concurrent model loads, false lane error** [T1, D2]
- Evidence: red banner "The lane model didn't load: Cannot read properties of null
  (reading 'value')" in 3/3 draft runs (meiolol-draft/20261017-193055 r1 steps/001.jpg,
  r2 037.jpg, r3 051.jpg); it also drops "checks pass". Personas then doubted the lane
  column, which was fine. draft-model.json fetched 3 times in 3 of 4 page loads (4.6 MB
  gzip each); training/ files served uncompressed (lane-model.json 4.3 MB); expected
  404s on models/draft-comp.json and models/lane-model.json log as console errors.
- Code: draftView calls loadDraftModel on every render while DRAFT.model is undefined
  (admin-draft.js:420); load A sets DRAFT.lane (:58) and awaits lane-ref.json (:60), load
  B sets DRAFT.lane = null (:54), A resumes into laneCheck(null) (:61) and its catch sets
  DRAFT.laneErr (:62). DRAFT.from and DRAFT.cc race the same way.
- Fix: one in-flight load (`DRAFT.loading ||= loadDraftModel()`), build each model in
  locals and assign DRAFT.* once at the end; fetch the fallback without logging the
  expected 404 as an error. gzip for /admin/training/ in nginx is on jomove (J8).
- After (7b4e07e): each model file fetched once, draft-comp.json asked of training/ only
  (no 404); re-walk: lane error banner in 0 of 6 runs (was 3 of 3). gzip is still J8.

**R2. Poll wipes the open breakdown and search** [D1]
- Evidence: expert, scripted: opened Blue mid, typed "a", opened a row; at 30 s the
  breakdown was closed and the search empty (expert-tools/s5.mjs). Walks did not
  reproduce: no persona stayed on one row 30 s. Fatal inside a 30 s pick timer.
- Code: admin.js:2298 polls every 30 s on Models; refreshView (admin.js:706-719)
  re-renders unless an input has focus; the open row is a local (`opened`,
  admin-draft.js:660), the query is never saved.
- Fix: keep `opened` and the query in DRAFT state so a re-render restores them (inside
  admin-draft.js); or skip the re-render for the draft view (admin.js, package B owns it).

**R3. "Other pairings" as the top reason** [T2, D3]
- Evidence: best-pick 3/3: Malzahar +3.9 tops Blue mid with sole chip "other pairings
  +3.6" (r1 snapshots/022.yaml); offline it is into Darius (top) +1.0, into Caitlyn
  (bot) +0.9, into Thresh (support) +0.5. Over 300 random drafts, top 5 rows per slot:
  first chip is "other pairings" on 25% of rows, 1 pp or more on 38%.
- Code: `botLane` (admin-draft.js:199, 238) names only bot/support pairs. docs/learned.md
  Win v2 line: mid vs the enemy bot and bot vs the enemy support (0.8-1.1 points) and top
  vs the enemy mid (0.5-1.0) are detected; commit 89e908f chose to lump "top into their
  mid" on purpose. Hence J3.
- Fix (after J3): name the detected groups from one shared list (also used by Learn,
  R20); never use the lump as a chip; describe it in plain words.
- After: still seen 3/3 in best-pick (Malzahar +3.8, sole chip "unnamed, summed +3.6").
  Its largest part is "into Kai'Sa (bot) +1.5", mid into the enemy bot: a detected
  pairing (learned.md) still lumped. Waits on J3.

**R4. Unnamed buckets and chips that do not add up** [T7, D8]
- Evidence: why-top r2: Yone +5.0 with "Small comp leans (shrunk, or not clear)" +2.2
  the second largest part; r3: Vex +3.0, one chip +2.0. Offline (2,000 top-5 rows): small
  comp leans 1 pp or more on 13% of rows and larger than every named part on 8%; chips
  miss the row's number by 1 pp or more on 30%. Lines summing to 3.8 shown as 3.7.
- Fix: rename ("other comp leans, summed"); when unnamed parts reach 1 pp, one muted chip
  for them; footnote "lines rounded".
- After (c8df953): one muted "unnamed, summed" chip from 1 pp, "lines rounded"; chips
  miss the row by 1 pp+ on 6% of top-5 rows (was 23% on that sample). Re-walk: the
  chip is used by name in 4 answers, but lumps still carry most of some scores (+2.3 of
  +4.6) and sub-1 pp parts are left out, so chips can still miss the row. Partly fixed.

**R5. Enter picks by rank, not by match** [T3]
- Evidence: 3/3 typed "Vi", Enter, got Viego (r1 steps/005.jpg, 007.jpg) and had to
  redo it. Any partial ("ka", "ve") picks by rank.
- Code: substring filter admin-draft.js:694, sorted by current sort :695, Enter clicks
  first row :715. The ban box (:501) already prefers prefix matches.
- Fix: while searching order hits exact name, prefix, substring (rank within each).

**R6. Phone: opening a slot shows nothing** [D5]
- Evidence: 390x844, tap Blue top: picker top at y=1208, below the fold
  (expert-shots/p-d7-after-open.png); red slots worse; on 1000 px desktop first row at
  ~800 px. Not walked (draft study is desktop).
- Code: picker appended after both team cards, input focused with `preventScroll: true`
  (admin-draft.js:723).
- Fix: `scrollIntoView({block: "start"})` on open, or a sheet over the board on narrow
  screens.

**R7. "Best blind lane" sort** [T4]
- Evidence: every run that pressed it: Irelia first (+792 to +812 gold at 14) with Win
  -1.8; Mel -4.6 fourth (r1 steps/036.jpg; extra r1 steps/008.jpg). All six answers made
  their own compromise. counter: "Best into Fiora" tops with Tryndamere, "Best for draft"
  with Malphite (-39 gold); r3 unsure which list to follow. Verifier: the sort does what
  its label says; the label is the problem.
- Fix: rename to what it is ("Most gold at 14"); a sub-line "gold at 14 and win can
  disagree (lane bullies vs scalers)". What "safe blind" means publicly is J2.

**R8. Sort by low end, show the middle** [D6]
- Evidence: empty board, Blue top: Kayle +1.0 after Olaf +0.9 (5% of top-5 lists); 3
  personas noticed, no wrong answer.
- Code: admin-draft.js:695 sorts by `lo`, :704 shows `change`.
- Fix: say "ordered by how sure" in the column header, or show what is sorted by.
- After (7314d73): "Surest win" with a header marker; 6 of 6 answers say it sorts by
  the low end, 2 only half follow why.

**R9. Lane gold vs matchup line** [T9, D7]
- Evidence: deep-read: Lux +607 gold into Kassadin but "Into their Kassadin -0.3"; Vex
  into Irelia "543 games of the pair" then "488 games of the matchup" (draft and lane
  models fitted on different snapshots).
- Fix: label the source of each count (draft model / lane model, games to date); one line
  "Lane is gold at 14; Win is the whole game".

**R10. Model line** [T6; relates to R41]
- Evidence: trust 3/3 quoted "right 54.7% of 82k practice games" and could not say if
  that is good, what practice games are, or which ranks, region and patch; jargon:
  milli-nats, held-out, snap-20261017T1320Z, largest gap 1.1e-16. Good: "matchups nudge
  the numbers rather than decide them" landed 3/3 (r2 steps/049.jpg).
- Fix: source on the line ("EUW ranked solo, Platinum IV and up, games to <date>"),
  "games it wasn't fitted on" for practice games, "page matches the box's export" for
  checks, jargon behind a details fold. The yardstick figure (55 to 57% published
  ceiling) is J5.
- After (99b8785, 2e63f08, 5c8936a): "ranked solo, Platinum IV and up, mostly EUW",
  "54.8% of 82k games it wasn't fitted on (a coin: 50%)", labelled as not the Models
  tab's test set; the 55 to 57% figure removed until J5. Trust 3/3 (was 1/3). The open
  fold is still jargon: R49.

**R11. Random presets** [T8]
- Evidence: r2, r3 asked how Random game, Random realistic and Random generic differ;
  Random game gave Zed jungle, Yorick mid, Camille support. Offline 16% of random
  realistic slots are picks the picker itself hides.
- Code: both buttons call `fillSlots(d, both, realistic)` (admin-draft.js:571, :603);
  `legal` (:547) takes any share > 0, the picker hides under 1% (PICK_MIN_SHARE, :634).
- Fix: one "Random game" button with the realistic tooltip as text; draw from the 1%
  floor; move "Empty board" out of Debug.
- After (a24b4b1): one Random game, 1% floor, Empty board in the fill bar; nobody asked
  how presets differ. New: 2 of 3 flag the Fill… menu (collapsed, no hint, a "Debug"
  group: All tanks, All assassins, Mirror); one called Random game unrealistic (Ambessa,
  Locke, Zyra; not checked per champion, the draw uses the 1% floor).

**R12. Enemy role unknown** [T5, D9]
- Evidence: flex 3/3: Yasuo and Yone locked, lanes unknown; personas built both layouts by
  hand (16 clicks, ~1 min); Vex +4.4 (55.5% to 56.9%) one way, +7.0 (58.0% to 59.6%) the
  other, non-overlapping ranges, nothing warns. download.html already promises the
  opponent is "labelled as a guess".
- Fix: an unknown-role shelf scored over role assignments weighted by likelihood, showing
  the spread. Whether to build it now is J4.

**R13. Primary signal cannot go public** [D4]
- Evidence: win bar "Blue 51.4%, range 49.3% to 53.6%" and Win column "+4.6" points,
  sorted by it; every persona used the points as the signal. docs/production-key.md: no
  "+X% win rate" wording, several options with reasons, never one forced pick.
- Fix: design the public variant (3 to 5 options grouped as "strong fits" / "also fine",
  worded reasons, no points, no win bar); Learn's practice reveal is close to that shape.
  J2.

**R14. Copy and small things** [D8, D9, T10]
- "a AD-heavy team" (admin-draft.js:258 hardcodes "a"); empty board "Blue 50.0%, range
  50.0% to 50.0%" (say "No picks yet"); "Prefer lab picks" floats mid-header
  (expert-shots/d1-initial.png: group with "Reload model"); "likely" range never says 95%;
  Blind/Lane unit (gold at 14) only in caption and tooltip; one shared ban list, no side;
  Enter in the ban box takes the first prefix match silently (show the match first);
  Random game overwrites the board with no undo.
- After (eaa0e9e): a/an, "no picks yet: the blue side alone", 95% on every range, Gold
  header with unit, Prefer and Reload together, shared ban list said, ban box shows
  what Enter bans, Undo after a fill; seen in the re-walk. Left: R52, R53.

**R48. Name picks, row opens, no cue** [draft N1]
- Evidence: draft r1 clicked Galio's name to see why, the pick landed on the board ("I
  never found an 'open the row' detail view"); r2: "a plain table row with no expand
  cue".
- Code: admin-draft.js:752 the name is a link-styled button that picks; :753 the rest
  of the row opens the breakdown, no marker; the breakdown ends in "Pick X" (:735).
- Fix: name opens the row; pick from the breakdown or a small pick button; or a ▸/▾
  marker. Inside a 30 s timer a mis-click pick costs more than a missed breakdown.

**R49. Model line fold: jargon, ticks read as quality** [draft N2]
- Evidence: 3/3 trust runs opened the fold and named "reference drafts", "largest gap
  1.1e-16", "(-0.68 ± 0.12)", "3c-team2"; r3: the ticks "only show the page matches its
  own exported files". All worked out "gaps of 1 to 2 points are noise" themselves.
- Code: admin-draft.js:126, :389, :433 check texts; :473 to :475 comp-lean line.
- Fix: open on one plain sentence (54.8% against a coin's 50%: a 1 or 2 point gap is
  within noise); ticks as "page matches the model files (a software check)"; the rest
  behind Details.

**R50. No "too close to call"** [draft N3]
- Evidence: every compare-two and deep-read answer judged "tie" by checking range overlap
  by hand; best-pick: Malzahar and Twisted Fate both +3.8. Win against Gold disagreeing
  is the other half.
- Fix: when the top rows sit within the top row's range, say so above the list, worded
  as a hint (the picks share the board, so overlap is a loose test). Grouping as "strong
  fits" / "also fine" is the public form, J2.

**R51. Random drafts at 58 to 65% look broken** [draft N4]
- Evidence: personas saw blue 59.2%, 64.9%, 36.5% and called them "extreme".
- Check: live admin-draft.js in Node, 3,000 random drafts as Random game draws them:
  median 50.0%, 5th to 95th percentile 39.8% to 59.9%, 10% beyond 40/60, consistent with
  54.8% accuracy for a calibrated model. Not a bug.
- Fix (optional): a line under the win bar, "1 random draft in 10 lands beyond 40/60".

**R52. Units: "points", "±"** [draft N5]
- Evidence: "'points' is never explained as win-chance percentage points"; 3 runs did not
  know what ± means. Code: :241 and :276 (95% half-widths).
- Fix: "percentage points" once in the sub-line; "±0.4 (95%)".

**R53. "lock" unexplained** [draft N6]
- Code: admin-draft.js:510, meaning only in the title "Lock (random keeps it)". Fix:
  visible text ("keep", or "locked slots stay" on the Random game line).

### 3.2 Public site

Task success, desktop (d) and phone (p), 3 runs each:

| study | task | self-rated | meets check | median steps | median time | where they stalled |
| --- | --- | --- | --- | --- | --- | --- |
| d | pick-into | 1/3 (2 partial) | 3/3 | 15 (budget) | 49 s | Matchups index, dead search (R15), opponent filter per champion (R18) |
| d | matchup-why | 3/3 | 3/3 | 8 | 23 s | no plain "even / ahead / behind" verdict |
| d | daily-draft | 3/3 | 3/3 | 4 | 13 s | lane Edge all "more data needed" (R21); right/wrong, streak (R22) |
| d | learn | 3/3 | 3/3 | 4 | 12 s | none |
| d | trust | 3/3 | 3/3 but misled | 2 | 14 s | repeated "every rank tier" (R17); totals differ (R25) |
| d | desktop-app | 3/3 | 3/3 | 3 | 14 s | footer-only link (R28) |
| d | privacy | 3/3 | 3/3 | 3 | 11 s | none |
| p | pick-into | 2/3 | 3/3 | 13 (budget) | 50 s | as desktop; Games column off screen (R27) |
| p | daily-draft | 3/3 | 3/3 | 5 | 20 s | Edge column clipped (R27) |
| p | trust | 3/3 | 3/3 but misled | 2 | 12 s | as desktop |
| p | desktop-app | 2/3 | 2/3 | 5 | 19 s | p3 never reached the footer, gave up (R28) |

Runs: meiolol-site/20261017-193101/rN (d), meiolol-site-phone/20261017-193103/rN (p).

| id | finding | sources | sev | type | status |
| --- | --- | --- | --- | --- | --- |
| R15 | Champion search on Champions, role and champion pages did nothing | S1 | major | Bug | fixed, verified by re-walk (0406809, 9f5fe61) |
| R16 | Daily Draft reveal shows a whole-draft win chance and "+X points" per option | P1, S4 | blocker | Design | needs Jacob (J1); still quoted 6/6 |
| R17 | "Every rank tier" / "all ranks" while data is Platinum IV+; bracket sentence vs filter | P3, S5 | major | Bug | fixed, verified by re-walk (f8f3060, 8b5014f, 921520c); Your games label on jomove's next api install |
| R18 | No direct "my pool into their pick" view | S2 | major | Design | needs Jacob (J6); still 11 to 15 steps |
| R19 | Champion pages: "hardest first" by raw win rate on tiny samples; default shows 1-game rows | P2 | major | Design | fixed (8b5014f); not reached by the re-walk |
| R20 | Learn names single pairs of kinds the data says are not detected | P4 | major | Design | fixed (2f349ca, 82c22cd); not reached; Daily reveal reasons wait on J1 |
| R21 | Daily lane Edge says "more data needed" when it means "no clear edge" | S4 | minor | Bug | fixed, verified by re-walk (d88f6c6) |
| R22 | Daily: right/wrong guess and "streak" unclear | S8 | minor | Design | fixed, verified by re-walk (d88f6c6) |
| R23 | Daily puzzles draw off-role games, so lane rows teach nothing | P7 | minor | Design | fixed (3d21f70); live #7 predates it, shows on new puzzles |
| R24 | Matchups index has no champion search or picker | S3 | minor | Design | fixed, verified by re-walk (6bf848d); then R54, R55 |
| R25 | Game totals differ across pages with no reason given | S6, P8 | minor | Design | partly fixed (f8f3060): Method bullet unread, per-page period unclear |
| R26 | "Gold at 14": whose lead and what the range is are not on screen | S7, P8 | minor | Design | fixed, verified by re-walk on phone (8b5014f) |
| R27 | Phone: tables push the answer column off screen | S9 | minor | Design | fixed, verified by re-walk (1911314, 7ef3a20) |
| R28 | Desktop app reachable only from the footer | S10 | minor | Design | fixed, verified by re-walk (8b5014f, 07ab3c2) |
| R29 | Method page has no plain-language summary | S11 | minor | Design | fixed, verified by re-walk (f8f3060) |
| R30 | Home: lane preview is from a different game than the featured review | P5 | minor | Bug | fixed (31bf94c); not reached |
| R31 | Home: turning minute undone a minute later; "most expensive death" headlined by gold | P6 | minor | Design | death headline fixed (31bf94c), not reached; turning minute open (needs a measurement) |
| R32 | Home review moment dots are mouse-only | S12 | polish | Bug | fixed, verified by re-walk (31bf94c) |
| R33 | Privacy page describes the unreleased desktop app in the present tense | S13 | polish | Design | fixed, verified by re-walk (f8f3060) |
| R34 | Terms/privacy contact is a personal Gmail, not privacy@meio.lol | P8, S13 | polish | Bug (ops) | needs Jacob (J8) |
| R35 | Matchup pages use ~940 of 1,300 px; icons vanish on long lists (lazy load) | P8 | polish | Design | fixed (7ef3a20); icons not reproduced (capture artefact); not reached |
| R54 | Back to the matchup index restores the search text but not the filter | site N1 | major | Bug | fixed (9f5fe61), not re-walked |
| R55 | Matchup index search takes one champion; Mid rows sit below Top and Jungle | site N2 | minor | Design | fixed (9f5fe61), not re-walked |
| R56 | "Desktop app" page vs "champ select helper" link | site N3 | polish | Design | fixed (07ab3c2) |
| R57 | Matchup pages give no plain "even / ahead / behind" verdict | site N4 | minor | Design | open (product call; next steps) |

**R15. Champion search** [S1] fixed (0406809)
- 6/6 pick-into runs typed in it and got an unfiltered table, losing 3 to 4 steps each;
  page error "Cannot read properties of null (reading 'tBodies')" per keystroke. table.js
  found the table by sibling order, broken since the gradient svg (acac138). Fix: each
  input names its table's id; pipeline test checks every target exists. Live.

**R16. Daily Draft win chance** [P1, S4]
- Evidence: daily.html #7: "the two drafts rate about 39 to 61 for blue side", options
  "Garen +1.1 points in this draft" (expert-shots/daily-reveal.png). All 9 Daily answers
  quoted "39 to 61"; d2 called it confident next to all-"more data needed" lanes. The
  39/61 rests mostly on Rengar bot (269 games).
- Code: src/site/static/daily.js:244-259, option lines nearby (from 1a98f3b, 11 Oct).
- Against docs/plan.md "no public draft win chance" and production-key.md wording. J1.
  Suggestion: drop the number; "on paper the draft leaned red" only when clear; options
  as reasons without points.
- After: unchanged (J1). Re-walk: 6/6 Daily answers still quote "39 to 61"; 3 now add it
  "rests on thin data" because the lanes say "few games".

**R17. Rank wording** [P3, S5]
- Evidence: method.html "chosen at random from every rank tier"; champion and matchup
  pages "all ranks"; 6/6 trust answers repeated it, none saw Platinum IV+. Method says
  rank is in three brackets (Iron to Silver, Gold to Emerald, Diamond and above) while
  the champion Rank filter offers ten cumulative tiers. The box crawls with
  `--min-tier PLATINUM` (docs/architecture.md); Daily and Learn already say "mostly
  Platinum players".
- Code: src/site/prose.zig:68 and :116-117; "all ranks" in src/site/builds.zig:135,
  src/site/matchup.zig:233 and :572; Rank filter src/site/root.zig:1937 with tiers in
  src/site/filters.zig:22-24.
- Fix: "players sampled at random from Platinum IV and above"; default label
  "Platinum+ games"; bracket sentence matching the filter; drop or grey Iron to Gold
  options (their slices are lower-ranked teammates in Platinum-area games). Also the
  persona study's trust check text (persona-walk repo).
- After (f8f3060, 8b5014f): Method, headers and Rank filter say Platinum+ (filter from
  Platinum, default "All (Platinum+ games)"); 6/6 trust answers say Platinum IV and
  above. Your games and the app's lane card said "All ranks" from core
  curvesfile Bracket.label: "All games" in 921520c, live on Your games only after the
  next by-hand api install on jomove (docs/your-games.md).

**R18. "My pool into their pick"** [S2]
- Evidence: every pick-into run used the full budget via Champions, role, enemy's page,
  opponent filter typed per pool champion, then inverted the enemy's win rate ("it only
  shows Zed's win rate, not mine"; "no page where I could just enter 'me Ahri vs Zed'").
- Ideas: a "compare your pool" box on champion pages pinning up to three opponents; a
  "your champion / their champion" jump on the Matchups index. Product call: J6.
- After: still 11 to 15 steps, 2 of 6 never compared all three. Fastest route seen: a
  matchup page's "Change champion". The index search helps (R24) but is not the answer.

**R19. Hardest-first by raw rate** [P2]
- Evidence: champion/malphite.html "164, hardest first": Qiyana 27.8% (18 games), Zed
  32.7% (52) top the list, Nasus 41.0% on 290 games 8th
  (expert-shots/fold-champion_malphite_html*.png); lane model shrinks Malphite into
  Qiyana to -295 gold where the page says -694. Default "All" lists 1-game rows. Walks
  did not read this order (untested, not contradicted).
- Code: src/site/static/filters.js:236-243 (10+ games, raw rate); default min "0"
  (src/site/root.zig:1986).
- Fix: sort by a shrunk estimate (the n/(n+k) the curves use, or the model's matchup
  cell), show the raw rate with its games; default floor e.g. 50+ games or 1%+ seen.
- After (8b5014f): sorted by n/(n+k) toward the champion's own rate, k per role by
  method of moments; default 1%+ of the champion's games, rarer behind "Show them";
  table search also finds hidden rows (9f5fe61). Malphite top: Mundo, Sion, Nasus first.

**R20. Learn names undetected single pairs** [P4]
- Evidence: learn.html practice reveal for mid: "Tends to struggle against Soraka
  (support, 327 games)", "Tends to win more with Lulu (support, 761 games)". learned.md
  Win: among allies only bot+support shows; cross-role matchups other than mid vs their
  bot, bot vs their support and top vs their mid not detected.
- Code: src/site/static/learn.js:31, 33 (MIN_REASON_PP 0.3, MIN_REASON_GAMES 50),
  651-657 (reason lines).
- Fix: keep only lane matchups and the detected kinds (one list, shared idea with R3);
  drop the rest. Whether single detected cross-role pairs are named publicly at all is
  part of J3.
- After (2f349ca): reasons name only lane matchups and the detected kinds; 82c22cd
  also draws practice games only where all ten picks are 1%+ of their role. Left: the
  Daily reveal's option reasons still list any pairing (part of J1's rework).

**R21. "More data needed"** [S4]
- Evidence: all 9 Daily answers saw it on every lane; Top Garen vs Darius has 769 games.
- Code: daily.js:23 `clear` hides edges under 400 games or within 1.96 SE; :278 labels
  both "more data needed".
- Fix: under PAIR_GAMES "few games"; above it "no clear edge".

**R22. Daily guess and streak** [S8]
- Evidence: right guess shows only "played" (smoke, d1, p2); 4 runs got "streak 1" with
  one of two right and did not know what it counts.
- Code: daily.js:227-230 ("your guess" tag only when wrong); :360-367 streak = days
  played in a row.
- Fix: tag "your guess, right" / "your guess"; rename to "days in a row".

**R23. Off-role puzzles** [P7]
- Evidence: #7 has Rengar bot (2 games of the bot matchup) and Ivern support; every lane
  row "more data needed"; d2 and d3 noticed Bot on 2 games.
- Code: puzzle choice in src/daily.zig.
- Fix: draw puzzles whose ten champion-roles each have 1%+ play share.
- After (3d21f70): done (smallest pick share 1.2 to 2.0% on remade puzzles). Live #7
  predates it, so the re-walk still saw Rengar bot; new puzzles carry it.

**R24. Matchups index search** [S3]
- Evidence: all 6 pick-into runs opened /matchup/index.html and left the next step; the
  page lists ~3,900 matchups with only a Min games select.
- Code: src/site/matchup.zig:91-146; filter pattern in src/site/static/table.js.
- Fix: a champion filter (data-filter with a target id, as 0406809) or two selects.

**R25. Game totals** [S6, P8]
- Evidence: 204,918 (home), 202,151 (Champions), 184,776 (Daily, footer), 738,011
  (Method table); Ahri vs Syndra 988 games (win rate) vs 961 (curves), the split only in
  hover titles. 3 desktop runs could not reconcile them.
- Fix: one line on Method (and a short note where totals show): "30 days: ...; this
  patch: ...; lane curves need a full timeline, so slightly fewer".
- After (f8f3060): Method has a Game counts bullet, but personas read only its top
  ("I only read the top half"); d1 still "numbers differ slightly between pages", d2
  "can't see which patch each page's count covers". Partly fixed: a short note where
  the totals show is left.

**R26. Gold at 14 column** [S7, P8]
- Evidence: 4 of 6 pick-into runs: "whether it shows Zed's gold lead or mine"; "+836 next
  to '-900 to +2572'". Row "-694 -2785 to +1397": second range unlabelled.
- Code: src/site/root.zig:2020: sign only in header hover title; range only
  `title="8 games in 10"`.
- Fix: header "Zed's gold lead at 14"; label the range ("8 in 10 games") in the header or
  a legend line.

**R27. Phone tables** [S9]
- Evidence: p1 Daily Edge clipped ("more data n...", p1 steps/021.jpg); p3 had to scroll
  sideways for Games on a champion page. No page overflow (sideways wrappers).
- Code: src/site/daily.zig:40 `.table-scroll`; champion opponents table in
  src/site/root.zig; src/site/static/style.css.
- Fix: on narrow screens drop names beside icons in the Daily table or stack Blue/Red;
  keep Edge and Games visible.

**R28. Desktop app link** [S10]
- Evidence: p3 gave up after one scroll of home; 8 of 9 found it, all via the footer;
  five asked for a date or a way to be told.
- Fix: a line on home or in Learn ("Coming: a champ select helper") linking to
  download.html. Date or notify: J7.
- After (8b5014f, 07ab3c2): home link "Coming: a champ select helper for Windows"; the
  page heading is now "Champ select helper (desktop app)" (R56). 6/6 in one step.

**R29. Method summary** [S11]
- Evidence: 5 trust answers called the estimate section unreadable ("n/(n+k)", "games to
  stabilise"); all still found the source facts above it.
- Fix: a 3 to 4 line "In short" box at the top of method.html (src/site/prose.zig).

**R30. Home lane preview** [P5]
- Evidence: hero reviews Lulu vs Soraka (won from -1,038 at 14) while "Your lane against
  typical" shows +751 from another game, unlabelled.
- Code: src/site/static/home.js:76 `games.find(...)` instead of the featured `g`.
- Fix: use `g` when it has a curve, else label the game shown.

**R31. Turning minute and costliest death** [P6]
- Evidence: turning minute 25:00 (+35%) then 26:00 "Swing against you" (-32%); record
  book "Most expensive death: 177 gold" beside a 275 gold death.
- Code: turning minute from src/winchance.zig (also used by Your games); death ranking
  src/site/static/review.js:456 (by objectives lost, headlined by gold).
- Fix: headline the costliest death by what followed ("then Baron and 3 towers"). A
  "largest lasting change" turning minute changes Your games output: measure first
  (winchance.zig already reports how often definitions differ); not packaged.
- After (31bf94c): the death card leads with what followed (objectives). Turning minute
  unchanged, still needs the measurement.

**R32. Moment dots** [S12]
- Code: src/site/static/review.js:174-178 click listener on `<circle class="mo">`; no role
  or tabindex. Fix: role="button", tabindex="0", Enter/Space.

**R33. Privacy tense** [S13]
- Code: src/site/prose.zig:273 onward "The desktop app ... reads champ select".
  Fix: "When released, the desktop app ...".

**R34. Contact address** [P8, S13]
- terms and privacy show jombirds@gmail.com; docs/plan.md (14 Oct) chose
  privacy@meio.lol. It comes from the box's `contact` file (deploy/box.sh:240,
  deploy/web-loop.sh:252), not the code: an ops change, J8.

**R35. Matchup width, lazy icons** [P8]
- Matchup pages leave the right third empty at 1,300 px; icons disappear partway down
  long opponent lists in full-page captures (check they load on scroll on slow phones).
  src/site/static/style.css.
- After (7ef3a20): captions beside charts from 1,100 px; icons all load when scrolled
  into view (the gaps were a full-page capture artefact).

**R54. Back loses the search filter** [site N1]
- Evidence: 4 of 6 pick-into runs went Ahri vs Zed, then Back, and found all 4,029
  matchup links under a box still reading "Zed" (p1 009.yaml, p3 008.yaml); 2 to 4
  steps each to retype. Most of why pick-into did not get shorter.
- Code: min-games.js and table.js filtered at load and on `input`; the browser restores
  the value after the script ran, with no event.
- Fixed in 9f5fe61: both filter again on `pageshow`. Checked in headless Chrome on live
  pages with the local JS routed in; not re-walked.

**R55. One-name index search** [site N2]
- Evidence: personas type "Zed" for "Ahri vs Zed", then scroll past Top 2 and Jungle 27
  rows to Mid's 51; p3 wrongly concluded Annie vs Zed has no page (it has 162 games).
- Fixed in 9f5fe61: each word must match one side ("ahri zed", "Ahri vs Zed"); while
  searching, roles with no match hide and the role with most matches comes first.

**R56. Desktop app naming** [site N3]
- Fixed in 07ab3c2: page heading "Champ select helper (desktop app)", title "Champ
  select helper"; the footer keeps "Desktop app".

**R57. No matchup verdict** [site N4; seen in the first walk too]
- Evidence: 3/3 matchup-why answers: "no verdict label, so I judged 'even' myself"; all
  still read it right.
- Idea: one generated line over the chart ("About even at 14 min ...; drifts toward
  Syndra after 15"). Product call, close to telling players what to expect;
  next-steps doc.

### 3.3 Admin panel (rest)

Task success:

| task | persona outcome | judged | median steps | median time | where they stalled |
| --- | --- | --- | --- | --- | --- |
| crawler-health | 3/3 | 3/3 | 0 | 6 s | why it restarted at 15:02 and 15:19 (R43) |
| games-today | 3/3 partial | 0/3 | 1 | 9 s | no "stored today"; misread the game-day chart (R38) |
| last-deploy | 3/3 | 3/3 | 1 | 7 s | subject cut off (R46) |
| model-quality | 3/3 | 3/3, none found the trend chart | 2 | 11 s | AUC vs 54.8% (R41); chart far down (R42) |
| log-errors | 1/3 (2 partial) | 1/3 | 3 | 15 s | logs under "Controls" (R37); UTC read as stale (R40) |
| lab-results | 1/3 (2 partial) | 3/3 adequate | 2 | 13 s | jargon (R47); "0 runs" header (R44) |

Run: meiolol-admin/20261017-193055/rN. Personas were fast and over-competent (0 to 3
actions per task), so this walk tests first screens, not deep navigation.

| id | finding | sources | sev | type | status |
| --- | --- | --- | --- | --- | --- |
| R36 | Warning classifier: "mastery: Blocked" as DB busy/locked, 429s as Riot 5xx, real 5xx as Other | M1 | major | Bug | fixed, verified by re-walk (9ae1f49); crawl questions J8 |
| R37 | Logs sit under "Controls"; 2 of 3 never found them | M2 | major | Design | fixed, verified by re-walk (0f708c4) |
| R38 | No "games stored today / 24 h"; game-day chart reads as intake | M4 | major | Design | fixed, verified by re-walk (53f3db6) |
| R39 | Problems banner: cryptic disk line, misses "full in ~6 days" and warning spikes | A1, M9 | major (ops) | Design | fixed, verified by re-walk (d880ace); the rate J8 |
| R40 | Log lines in UTC, unlabelled; rest of panel UK time | M3 | minor | Bug | fixed, verified by re-walk (0f708c4) |
| R41 | Three headline accuracies (AUC 0.564, 54.8%, 54.7%) unreconciled | A2, M6 | minor | Design | fixed, verified by re-walk (f730089, 2e63f08); see R59 |
| R42 | Win (draft) opens on screens of prose; trend chart far below | M5 | minor | Design | fixed, verified by re-walk (bfd3f1a) |
| R43 | Crawler restarts unexplained | M7 | minor | Design | fixed, verified by re-walk (2039880) |
| R44 | Lab campaign "0 runs, 0 confirmed" above confirmed pills | M8 | minor | Bug | fixed, verified by re-walk (6340ec9) |
| R45 | Site views count automated Chrome as people | A3 | minor | Bug | partly fixed (804d85f): install on jomove and browser-tool commit, J8 |
| R46 | Deploys: subject cut off, steps out of time order, header vs step time | A4, M10 | polish | Design | fixed, verified by re-walk (ef2247c, 37fbf1c) |
| R47 | Model and lab copy assumes the reader is the modeller | M11 | polish | Design | partly fixed (b738323): glosses wait on J9; R62 |
| R58 | Models and Lab don't say what to act on | AN1 | minor | Design | open |
| R59 | "116% of the way there" beside 54.8% vs published 55 to 57% | AN2 | minor | Design | needs Jacob (J5) |
| R60 | 429/403 spikes and 97% key use flagged without saying if they matter | AN3 | minor | Design | open (fix3) |
| R61 | Logs one file at a time; personas check only crawl.log | AN4 | minor | Design | open (fix3) |
| R62 | Neural nets "better than today's model (-0.0003 a game)" reads backwards | AN5 | polish | Design | open (fix3) |

**R36. Warning classifier** [M1]
- Evidence: Crawler > Warning messages (r1 steps/012.jpg): `twN mastery: Blocked` (281 in
  24 h) labelled DB busy/locked; the matching Riot edge 403 is Other; "N (server) on ...,
  waiting Ns" rows labelled Riot 5xx are 429s (r3 steps/012.jpg).
- Code: `classify` src/admin.zig:874-885 tests "(server)" then "locked" (matches
  "Blocked"); test at :924 uses an old "503 (server)" format; the client logs 5xx as
  `{d} on {s}, retrying` and 429 as `429 ({limit_type}) on ...` (src/riot/client.zig:94,
  227); digits normalised to N lose the status. The "Riot 5xx, 24 h" tile
  (src/site/static/admin.js:1010) counts 429s.
- Fix: match whole phrases ("database is locked", "database busy"); kinds "Riot edge 403
  (blocked)" and "Riot 429 (server)"; keep the status class through normalise; tests in
  today's format. Whether 429 (server) counts as rate limiting: J8.
- After (9ae1f49): statuses survive normalise; kinds Riot 429 (server), Riot 5xx, Riot
  edge 403 (blocked), DB busy only on "database is locked/busy", Network for connection
  errors; tests from the box's last 24 h of log. Re-walk: 3/3 name the 429 and 403
  counts right, no "DB busy".

**R37. Logs tab** [M2]
- Code: TABS admin.js:22-26 (`["ops", "Controls"]`); `logViewer` admin.js:2231.
- Fix: a "Logs" tab, or "Controls and logs"; a "Raw log" link beside Warning messages.

**R38. Games today** [M4]
- Evidence: 3/3 answered "about 22k today, looks low" from Ingest > Games by game day
  (r1 steps/003.jpg); none reconciled it with Overview's 136k/day.
- Code: newest 1,000,000 drafts rows bucketed by game day (src/admin.zig:44, 320-329;
  subtitle admin.js:1178); Overview's 136k is an hourly rate of all matches stored.
- Fix: Overview tile "Stored, last 24 h" with the 7-day daily average; Ingest subtitle
  "by the day the game was played; last days fill in; first days cut by the window"; grey
  partial days.

**R39. Problems banner** [A1, M9]
- Evidence: banner "box disk: 76 GB free for 45 GB of raw" while the Disk tile says "full
  in ~6 days" (expert-shots/adm-overview.png); warnings 10 to 30 per 10 min since ~12:00
  not in the banner. Checked 19:2x: 77 GB free of 145, raw valve stops raw at 10 GB free,
  so not an outage risk.
- Code: deploy/health.sh:133 (banner line), admin.js:867 (days to full), :873 (banner).
- Fix: "box disk full in ~N days at the current rate"; a line when one warning kind runs
  well above its 7-day normal (after R36). The rate itself: J8.

**R40. Log time zone** [M3]
- Evidence: r3 read the newest line 18:34 (UTC) as 40 min stale at 19:14 BST.
- Code: admin.js:2240-2252. Fix: rewrite leading timestamps with `uk()`, or "times in
  UTC" in the subtitle.

**R41. Three accuracies** [A2, M6]
- Overview "Model AUC 0.564, best: shrunk, 786k games"; Models "right 54.8%"; tester
  "right 54.7% of 82k practice games". Fix: one headline metric and definition across
  the panel; "shrunk" explained once.
- After (f730089, 2e63f08): Overview shows the Models headline (54.8% of 118k, coin
  50%); the tester's line says its 82k test set is not the Models tab's. Re-walk: no AUC
  quoted. The "116%" beside it is R59.

**R42. Win (draft) layout** [M5]
- Code: winView admin.js:1480-1532 (prose first). Fix: readings line and "Run by run"
  chart first; "What we learnt" collapsed to its newest two items.

**R43. Restarts** [M7]
- Code: markers admin.js:282-288 carry only "crawler started <time>". Fix: label with
  the cause.
- Correction (fix agent): deploys do not restart the crawler; they restart only the
  site loop. A deploy that changes the crawler is followed by a by-hand `box.sh start`.
  Today's 15:02 and 15:19 starts were those: 29 s after 39dd00d (raw valve) and 9 min
  after 2bbe2ed (riot client), clean systemd restarts, no crash.
- After (2039880): markers say "restarted from Controls", or how long after which deploy
  (sha, subject), else "manual restart or crash". Re-walk 3/3 explain the dips.

**R44. Lab "0 runs"** [M8]
- Code: header counts training/runs.tsv rows tagged with the campaign (admin.js:1623-1626);
  pills are hypothesis statuses (:1628-1631); gold14-a runs untagged, and one "confirmed"
  is the reference. Fix: count from hypotheses when runs.tsv has none; show the
  reference as "reference".

**R45. Site views** [A3]
- 600 "people" views at 06:00 and ~400 at 15:00 on 17 Oct, almost certainly agents
  (headless Chrome with a normal UA). People/bots split shown at admin.js:854, 1877.
  Not tested by the walk.
- Correction (fix agent): the split is decided by deploy/traffic.sh on jomove. The
  persona-walk tool's HeadlessChrome already counted as a bot; the people were the
  `browse` tool (~/personal/browser-tool), which sends a normal Chrome UA.
- After (804d85f): traffic.sh counts the token "browser-tool" as a bot, and browser-tool
  now appends it to its UA on meio.lol. Not live: traffic.sh is not installed on jomove
  and the browser-tool change is uncommitted (that repo has no commits). Both J8.

**R46. Deploys** [A4, M10]
- 3/3 quoted a truncated subject; "Renderer swap" and "Live on site" listed after "Site
  build"; header "live at 19:14" while "Live on site" ended 19:13; cards are `<details>`
  with the marker hidden. Code admin.js:2129-2130, 2213-2215. Fix: sort steps by start,
  wrap subject to two lines, say which track "live at" means, show the disclosure marker.
- After (ef2247c, 37fbf1c): steps in run order, subject wraps; on-push.sh kept only 200
  characters of a subject, now 2,000. Re-walk 3/3 quote the whole subject.

**R47. Jargon** [M11]
- mde, nats, folds, dev-val, H7/H9, "shrunk"; Neural nets card "better than today's
  model" with no size (src/site/static/admin-nn.js:41-46, 90-104). Fix: one plain gloss
  per finding and the size on the card's pill. Priority depends on J9.
- After (b738323): pills give the gain's size. 3/3 lab answers still list mde,
  H-numbers, diagnose and dev-val as unexplained; the negative gain reads backwards
  (R62). Partly fixed; glosses wait on J9.

**R58. Nothing says what to act on** [AN1]
- Evidence: 3/3 lab answers recommend shipping "tuned + term weights" (beats the site's
  model by 0.0017 log loss) and the confirmed rank term, and cannot tell if either is
  live or planned; self-rated partial 3/3 for this.
- Code: Models > Win (draft) charts the site's model beside "tuned + weights"
  (admin.js:1556) with no shipped/next line; Lab lists confirmed ideas with no status.
- Fix: one status per confirmed idea and per better-than-site model: shipped, next, or
  not worth shipping (why).

**R59. "116% of the way there"** [AN2]
- Evidence: r2, r3: "published models reach about 55 to 57%, and the page says we are
  116% of the way there by log loss", next to our 54.8%. Reads as a contradiction.
- Code: admin.js:1467 builds the share from log loss after a sentence on accuracy.
- Fix: drop it or name the yardstick. J5.

**R60. Spikes and key use without a verdict** [AN3]
- Evidence: r2, r3 "can't tell whether the 429 and 403 spikes are harmful"; r3 "key use
  98.5%, right at the limit". All still judge the crawler fine.
- Code: banner spike line admin.js:924; key tile admin.js:810.
- Fix: the effect beside the spike ("matches still stored at the usual rate"); on the
  key tile whether near 100% is by design, with the threshold used.

**R61. Logs one file at a time** [AN4]
- Evidence: 3/3 checked only crawl.log of seven; r2, r3 filtered "error" there and got 0.
- Code: logViewer admin.js:2328-2364. Fix: error and warning counts per file in the
  picker, or an "all logs" choice. Also polish: a "since midnight" figure beside "last
  24 h".

**R62. Negative gain reads backwards** [AN5; part of R47]
- Evidence: r1, r2: "-0.0003 a game" better is "confusing because the number is
  negative". Fix: "log loss 0.0003 lower a game (better)".

## 4. Decisions for Jacob

Fix agents must not make these.

- **J1 (R16) Daily Draft public win chance.** The reveal shows "about 39 to 61 for blue"
  and "+X points" per option, against plan.md and production-key.md. Keep, drop, or turn
  into words ("on paper the draft leaned red", reasons without points)? The rework would
  also limit the option reasons to detected pairings, as Learn now does (R20).
- **J2 (R13, R7) Public picker's primary signal.** What replaces +X points: tiers ("strong
  fits", "also fine") with worded reasons? And what does "safe blind pick" optimise: win
  against an average pick, lane gold at 14, or a floor on both?
- **J3 (R3, R20) Which pairings get named.** learned.md v2 says mid vs their bot, bot vs
  their support and top vs their mid are detected; 89e908f lumped top into their mid on
  purpose. Name them in the tester? And on Learn, may single detected cross-role pairs be
  named (learned.md: "no numbers for single champion pairs")?
- **J4 (R12) Unknown-role enemy shelf** in the admin tester now, as the testbed for the
  public picker's role guess?
- **J5 (R10, R59) Yardstick.** May the model line cite the published 55 to 57% draft-only
  ceiling (docs/model.md Ceiling), and on the public site too? The tester's line no longer
  cites it (5c8936a). Admin Models' "116% of the way there" (log loss) beside 54.8%
  against 55 to 57% (accuracy) reads as a contradiction: drop it or name the yardstick?
- **J6 (R18) "My pool into their pick"** on the public site now, or wait for the app?
- **J7 (R28) Desktop app date** or a way to be told?
- **J8 Ops.**
  - Admin basic-auth password was echoed into two agents' transcripts (port agent
    18:55, fix agent around 20:00, both via a curl prompt); not rotated. Rotation
    recommended: htpasswd on jomove plus `vault set meiolol/local
    MEIOLOL_API_BASIC_AUTH`.
  - R45 install: scp deploy/traffic.sh to jomove, then `sudo install -m 755 traffic.sh
    /usr/local/bin/meiolol-traffic` (units unchanged); summaries already cached keep
    their old counts.
  - ~/personal/browser-tool has no commits; its UA token change (R45) waits on your
    initial commit.
  - Your games API on jomove runs an 809669c-era build: the "All games" label (921520c,
    R17) shows after the next by-hand api install (docs/your-games.md). Label only, not
    worth a restart on the 1 GB box by itself.
  - gzip for /admin/training/ JSON in nginx on jomove (R1).
  - Box `contact` file to privacy@meio.lol (R34).
  - Disk "full in ~6 days" at the current rate (R39); 77 GB free of 145 at 19:2x and the
    raw valve stops raw at 10 GB free, so not an outage risk, but the rate wants a look.
  - TW2 champion mastery refused by Riot's edge ~once a minute since ~12:00 (281 in
    24 h): expected, or stop asking?
  - "429 (server)" on match-v5 every few minutes: accepted, and should it count as rate
    limiting (R36)?
- **J9 (R47) Admin audience.** Is the panel for anyone but you (e.g. Riot's reviewers)?
  If not, admin jargon is low priority.

The next-steps review adds Q1 (application text and squads), Q2 (Daily game age), Q3
(ban suggestions in scope) and Q4 (crawl floor below Platinum):
docs/review/next-steps-2026-10-17.md.

## 5. What works well (keep)

- Speed: every public page 1.4 to 2.7 s to network idle; tester opens in ~1.7 s, picker
  in 40 to 90 ms. No console errors on public pages, no page overflow at 390 px.
- Matchup pages answer "how sure": 3/3 matchup-why runs quoted games, the 8 in 10 spread
  and the win-when-ahead/behind split unprompted; lane numbers agree between model and
  page (Irelia vs Yone: +1,337 vs +1,308).
- Learn lesson 2 (mastery beats counters, 44% vs 51.5%) was the take-away in 3/3 runs and
  changed one pick-into answer. Learn's worded practice reveal is the right shape for
  public reasons.
- Desktop app, privacy and terms pages: clear and honest (Windows only, not released,
  read-only, never picks for you, the removal flow).
- Tester: entering a full draft 3/3 without help; search forgiving, bans 3/3 right;
  every breakdown adds up exactly; ranges do their job (3/3 called Syndra vs Orianna
  noise unprompted); the model line's "nudge rather than decide" led every persona to
  "a tiebreaker, not a verdict"; model checks against references pass.
- Admin: Overview answers crawler health in one glance (~6 s); Deploys answers "did it go
  live, when, which commit" in one click; tabs and sub-tabs found at once; the "Live,
  updated N s ago" stamp is trusted.
- Preview banner and footer boilerplate on every page.

## 6. Work packages

All five packages are done (17 Oct 20:00 to 20:37; statuses above). Round 3 (fix3) takes
the re-walks' polish: R48, R49, R50, R52, R53 (admin-draft.js) and R60, R61, R62
(admin.zig, admin.js). As planned:

Open Bug and clear Design findings, Jacob decisions left out. Each package owns its
files; a fix agent needing a file outside its list asks the coordinator first. Shared:
src/pipeline_test.zig is owned by package D; C and E ask the coordinator for a turn
(edit, test, commit straight away). src/site/static/style.css likewise owned by D.

**A. Draft tester** (src/site/static/admin-draft.js only)
- R1 single in-flight load, locals, quiet expected 404s (first: it breaks trust)
- R2 keep the open row and query in DRAFT state across re-renders (no admin.js edit)
- R5 search order exact, prefix, substring
- R6 scroll the picker into view on open
- R4 rename unnamed buckets, muted chip so chips add up, "lines rounded"
- R7 rename the lane sort, add the gold-vs-win sub-line (no public "safe" rule)
- R8 header says what it sorts by
- R9 source labels on counts, one line on lane vs win
- R10 source and plain words on the model line (no yardstick figure: J5)
- R11 one Random button, 1% floor, Empty board out of Debug
- R14 copy and small things
- Not here: R3 (J3), R12 (J4), R13 (J2)

**B. Admin panel** (src/admin.zig, src/site/static/admin.js, src/site/static/admin-nn.js,
src/site/static/admin.css, deploy/health.sh)
- R36 classifier and tests (first: it misdirects ops)
- R38 stored-last-24-h tile, Ingest subtitle
- R39 banner wording and warning-spike line
- R37 Logs tab or link; R40 log times
- R41 one headline accuracy; R42 Win (draft) order
- R43 restart labels; R44 lab header counts; R46 deploys
- R45 if the people/bots split can be found and tagged cleanly, else report back
- R47 last, low priority until J9

**C. Public copy and trust** (src/site/prose.zig, src/site/builds.zig,
src/site/matchup.zig, src/site/static/table.js)
- R17 copy part: Method sentence and bracket sentence, "all ranks" labels in builds.zig
  and matchup.zig (the Rank filter options are D's)
- R29 "In short" box on Method
- R25 totals line on Method
- R33 privacy tense
- R24 champion filter on the Matchups index (matchup.zig plus table.js)

**D. Champion pages and home links** (src/site/root.zig, src/site/html.zig,
src/site/filters.zig, src/site/static/filters.js, src/site/static/style.css,
src/pipeline_test.zig)
- R19 shrunk sort and default floor on Lane opponents
- R26 gold-at-14 header and range label
- R17 filter part: Rank filter options and default label (root.zig:1937, filters.zig)
- R28 desktop app line on home (no date: J7)
- R27 champion opponents table on phones (Games visible)
- R35 matchup width and icon loading

**E. Daily, Learn and home review** (src/site/static/daily.js, src/site/daily.zig,
src/daily.zig, src/site/static/learn.js, src/site/learn.zig, src/site/static/home.js,
src/site/static/review.js)
- R21 "few games" vs "no clear edge"
- R22 guess tags and "days in a row"
- R23 puzzle choice with 1%+ play share per champion-role
- R27 Daily lane table on phones (CSS through D or the coordinator)
- R20 drop undetected pair kinds from Learn reasons (naming detected single pairs: J3)
- R30 lane preview from the featured game
- R31 costliest-death headline only (turning minute rule needs a measurement, not here)
- R32 keyboard access for moment dots
- Not here: R16 (J1)
