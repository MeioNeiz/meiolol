# meio.lol as it stands, 17 Oct 2026

Persona walks and an expert review of the live site (deploy 0fa7732 to 6c6631c), merged
into one list of findings with stable ids (R1, R2, ...). Source ids in brackets point into
the team's notes: D, P, A = expert review; T = Draft tester walk; S = public site walk;
M = admin walk. Fix agents update Status; the report agent folds results in.

## 1. Summary

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

Already fixed: R15 champion search (0406809, live).

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
| R1 | Models load up to 3 times at once; race shows a false "lane model didn't load" error | T1, D2 | major | Bug | open |
| R2 | 30 s poll closes the open breakdown and clears the search | D1 | major | Bug | open |
| R3 | Top pick's only reason is "other pairings"; detected cross-role groups lumped | T2, D3 | major | Design | open (Jacob J3) |
| R4 | Unnamed buckets are large and chips do not add up to the row | T7, D8 | minor | Design | open |
| R5 | Search + Enter picks the best-ranked hit, not the name typed (Vi gives Viego) | T3 | minor (major public) | Bug | open |
| R6 | Opening a slot on a phone shows nothing (picker below the fold) | D5 | major on phone | Bug | open |
| R7 | "Best blind lane" tops with picks the Win column calls losing | T4 | minor (major public) | Design | open |
| R8 | "Best for draft" sorts by the low end, shows the middle | D6 | minor | Design | open |
| R9 | Lane gold and matchup line disagree, two game counts for one pair, no word why | T9, D7 | minor | Design | open |
| R10 | Model line: no baseline, no source, jargon; "checks pass" read as quality | T6 | minor (major public) | Design | open |
| R11 | "Random game" and "Random realistic" are the same; random drafts include off-role picks | T8 | minor | Design | open |
| R12 | No "role unknown" for enemy picks; ranges hide the role uncertainty | T5, D9 | major public | Design | open (Jacob J4) |
| R13 | Primary signal (+X points, win bar) is what the public product may not show | D4 | major roadmap | Design | open (Jacob J2) |
| R14 | Copy and small things (a/an, empty board range, button place, 95%, units, bans) | D8, D9, T10 | polish | Bug/Design | open |

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

**R4. Unnamed buckets and chips that do not add up** [T7, D8]
- Evidence: why-top r2: Yone +5.0 with "Small comp leans (shrunk, or not clear)" +2.2
  the second largest part; r3: Vex +3.0, one chip +2.0. Offline (2,000 top-5 rows): small
  comp leans 1 pp or more on 13% of rows and larger than every named part on 8%; chips
  miss the row's number by 1 pp or more on 30%. Lines summing to 3.8 shown as 3.7.
- Fix: rename ("other comp leans, summed"); when unnamed parts reach 1 pp, one muted chip
  for them; footnote "lines rounded".

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

**R11. Random presets** [T8]
- Evidence: r2, r3 asked how Random game, Random realistic and Random generic differ;
  Random game gave Zed jungle, Yorick mid, Camille support. Offline 16% of random
  realistic slots are picks the picker itself hides.
- Code: both buttons call `fillSlots(d, both, realistic)` (admin-draft.js:571, :603);
  `legal` (:547) takes any share > 0, the picker hides under 1% (PICK_MIN_SHARE, :634).
- Fix: one "Random game" button with the realistic tooltip as text; draw from the 1%
  floor; move "Empty board" out of Debug.

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
| R15 | Champion search on Champions, role and champion pages did nothing | S1 | major | Bug | fixed (0406809) |
| R16 | Daily Draft reveal shows a whole-draft win chance and "+X points" per option | P1, S4 | blocker | Design | open (Jacob J1) |
| R17 | "Every rank tier" / "all ranks" while data is Platinum IV+; bracket sentence vs filter | P3, S5 | major | Bug | open |
| R18 | No direct "my pool into their pick" view | S2 | major | Design | open (Jacob J6) |
| R19 | Champion pages: "hardest first" by raw win rate on tiny samples; default shows 1-game rows | P2 | major | Design | open |
| R20 | Learn names single pairs of kinds the data says are not detected | P4 | major | Design | open |
| R21 | Daily lane Edge says "more data needed" when it means "no clear edge" | S4 | minor | Bug | open |
| R22 | Daily: right/wrong guess and "streak" unclear | S8 | minor | Design | open |
| R23 | Daily puzzles draw off-role games, so lane rows teach nothing | P7 | minor | Design | open |
| R24 | Matchups index has no champion search or picker | S3 | minor | Design | open |
| R25 | Game totals differ across pages with no reason given | S6, P8 | minor | Design | open |
| R26 | "Gold at 14": whose lead and what the range is are not on screen | S7, P8 | minor | Design | open |
| R27 | Phone: tables push the answer column off screen | S9 | minor | Design | open |
| R28 | Desktop app reachable only from the footer | S10 | minor | Design | open |
| R29 | Method page has no plain-language summary | S11 | minor | Design | open |
| R30 | Home: lane preview is from a different game than the featured review | P5 | minor | Bug | open |
| R31 | Home: turning minute undone a minute later; "most expensive death" headlined by gold | P6 | minor | Design | open |
| R32 | Home review moment dots are mouse-only | S12 | polish | Bug | open |
| R33 | Privacy page describes the unreleased desktop app in the present tense | S13 | polish | Design | open |
| R34 | Terms/privacy contact is a personal Gmail, not privacy@meio.lol | P8, S13 | polish | Bug (ops) | open (J8) |
| R35 | Matchup pages use ~940 of 1,300 px; icons vanish on long lists (lazy load) | P8 | polish | Design | open |

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

**R18. "My pool into their pick"** [S2]
- Evidence: every pick-into run used the full budget via Champions, role, enemy's page,
  opponent filter typed per pool champion, then inverted the enemy's win rate ("it only
  shows Zed's win rate, not mine"; "no page where I could just enter 'me Ahri vs Zed'").
- Ideas: a "compare your pool" box on champion pages pinning up to three opponents; a
  "your champion / their champion" jump on the Matchups index. Product call: J6.

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
| R36 | Warning classifier: "mastery: Blocked" as DB busy/locked, 429s as Riot 5xx, real 5xx as Other | M1 | major | Bug | open |
| R37 | Logs sit under "Controls"; 2 of 3 never found them | M2 | major | Design | open |
| R38 | No "games stored today / 24 h"; game-day chart reads as intake | M4 | major | Design | open |
| R39 | Problems banner: cryptic disk line, misses "full in ~6 days" and warning spikes | A1, M9 | major (ops) | Design | open |
| R40 | Log lines in UTC, unlabelled; rest of panel UK time | M3 | minor | Bug | open |
| R41 | Three headline accuracies (AUC 0.564, 54.8%, 54.7%) unreconciled | A2, M6 | minor | Design | open |
| R42 | Win (draft) opens on screens of prose; trend chart far below | M5 | minor | Design | open |
| R43 | Crawler restarts unexplained (deploys, very likely) | M7 | minor | Design | open |
| R44 | Lab campaign "0 runs, 0 confirmed" above confirmed pills | M8 | minor | Bug | open |
| R45 | Site views count automated Chrome as people | A3 | minor | Bug | open |
| R46 | Deploys: subject cut off, steps out of time order, header vs step time | A4, M10 | polish | Design | open |
| R47 | Model and lab copy assumes the reader is the modeller | M11 | polish | Design | open |

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

**R42. Win (draft) layout** [M5]
- Code: winView admin.js:1480-1532 (prose first). Fix: readings line and "Run by run"
  chart first; "What we learnt" collapsed to its newest two items.

**R43. Restarts** [M7]
- Code: markers admin.js:282-288 carry only "crawler started <time>"; pushes at 14:59,
  15:05, 15:07 explain them. Fix: label with the deploy (sha, subject) when one started
  shortly before, else "manual or crash".

**R44. Lab "0 runs"** [M8]
- Code: header counts training/runs.tsv rows tagged with the campaign (admin.js:1623-1626);
  pills are hypothesis statuses (:1628-1631); gold14-a runs untagged, and one "confirmed"
  is the reference. Fix: count from hypotheses when runs.tsv has none; show the
  reference as "reference".

**R45. Site views** [A3]
- 600 "people" views at 06:00 and ~400 at 15:00 on 17 Oct, almost certainly agents
  (headless Chrome with a normal UA). People/bots split shown at admin.js:854, 1877;
  where it is decided was not located. Fix: tag own traffic (header or IP list) or mark
  bursts from one IP. Not tested by the walk.

**R46. Deploys** [A4, M10]
- 3/3 quoted a truncated subject; "Renderer swap" and "Live on site" listed after "Site
  build"; header "live at 19:14" while "Live on site" ended 19:13; cards are `<details>`
  with the marker hidden. Code admin.js:2129-2130, 2213-2215. Fix: sort steps by start,
  wrap subject to two lines, say which track "live at" means, show the disclosure marker.

**R47. Jargon** [M11]
- mde, nats, folds, dev-val, H7/H9, "shrunk"; Neural nets card "better than today's
  model" with no size (src/site/static/admin-nn.js:41-46, 90-104). Fix: one plain gloss
  per finding and the size on the card's pill. Priority depends on J9.

## 4. Decisions for Jacob

Fix agents must not make these.

- **J1 (R16) Daily Draft public win chance.** The reveal shows "about 39 to 61 for blue"
  and "+X points" per option, against plan.md and production-key.md. Keep, drop, or turn
  into words ("on paper the draft leaned red", reasons without points)?
- **J2 (R13, R7) Public picker's primary signal.** What replaces +X points: tiers ("strong
  fits", "also fine") with worded reasons? And what does "safe blind pick" optimise: win
  against an average pick, lane gold at 14, or a floor on both?
- **J3 (R3, R20) Which pairings get named.** learned.md v2 says mid vs their bot, bot vs
  their support and top vs their mid are detected; 89e908f lumped top into their mid on
  purpose. Name them in the tester? And on Learn, may single detected cross-role pairs be
  named (learned.md: "no numbers for single champion pairs")?
- **J4 (R12) Unknown-role enemy shelf** in the admin tester now, as the testbed for the
  public picker's role guess?
- **J5 (R10) Yardstick.** May the model line cite the published 55 to 57% draft-only
  ceiling (docs/model.md Ceiling), and on the public site too?
- **J6 (R18) "My pool into their pick"** on the public site now, or wait for the app?
- **J7 (R28) Desktop app date** or a way to be told?
- **J8 Ops.**
  - Admin basic-auth password was echoed into one agent's transcript (port agent,
    18:55); not rotated: htpasswd on jomove plus `vault set meiolol/local
    MEIOLOL_API_BASIC_AUTH`.
  - gzip for /admin/training/ JSON in nginx on jomove (R1).
  - Box `contact` file to privacy@meio.lol (R34).
  - Disk "full in ~6 days" at the current rate (R39).
  - TW2 champion mastery refused by Riot's edge ~once a minute since ~12:00 (281 in
    24 h): expected, or stop asking?
  - "429 (server)" on match-v5 every few minutes: accepted, and should it count as rate
    limiting (R36)?
- **J9 (R47) Admin audience.** Is the panel for anyone but you (e.g. Riot's reviewers)?
  If not, admin jargon is low priority.

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
