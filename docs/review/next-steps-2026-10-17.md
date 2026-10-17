# Next steps for meio.lol, 17 Oct 2026

The first review (docs/review/persona-walk-2026-10-17.md, R and J ids) asked what is
broken. This one asks what is missing for the target user, a normal ranked player on
today's patch in EUW, and what would make them come back. It is a proposal: docs/plan.md
is untouched and Jacob decides what goes in it.

Evidence: five new persona studies (15 runs, sonnet, live site, read-only), a competitor
look (research/questions/competitor-first-visit-returning.md), the first review and its
re-walks after the fixes (team notes rewalk-draft.md and rewalk-site-admin.md; their new
ids are cited as draft N1 to N6 and site N1 to N4). Personas are hypotheses: every
claim about the site below was checked against the code or the live page; what players
"want" is the persona's word, weighed against the research store
(research/questions/player-tool-needs.md, competitor-first-visit-returning.md).

## 1. In short

- The game review is the product. 9 of 9 first-visit answers named it as the thing they
  would come back for, and no competitor has a per-minute review with the turning minute
  and death cost. It is also what Riot's own "Please Do" list asks for ("evaluate and
  improve their own gameplay")
- What keeps people from coming back is not quality but memory: the site forgets them.
  No saved Riot ID, no link to one game, progress per browser, nothing about what changed
  since last time. 3 of 3 returning players said "next week, maybe"; each named one
  memory feature as what would change it
- The picker's missing piece is the player's own pool. 3 of 3 champ select runs could not
  enter it, 3 of 3 asked for it first; only iTero among rivals has it. It is also the
  policy-safe shape ("options from your pool, with reasons")
- The production-key reviewers (3 of 3 "ask for more", none rejected) want to see the
  champ select tool itself (screenshots, video, LCU endpoint list), want the public
  whole-draft win chance explained or gone (R16, J1), and find the application text
  describing a different product from the site (lane curves and squads vs game review)
- The first review's fixes held in the re-walks (Draft tester trust and bans partial to
  success, desktop app one click, every trust answer now Platinum IV+), so what is left
  is mostly product, not bugs: the open items are the J decisions and the gaps below

## 2. Ranked next steps

Three groups. Riot reviews the site when the application reaches the front of the queue
(3 to 9 months), and editing the application then may reset the queue, so the first
group is what to settle before Jacob presses Verify on app 890243; the second is what
helps while it queues (Riot sees the site as it is at review time); the third needs the
key's rate limit or a public launch.

Effort: S under a day for one session, M a few sessions, L a week or more.

### A. Before Jacob presses Verify

**A1. Show the champ select tool: a real run, screenshots, a short video, the endpoint
list.** (M; needs Jacob in a real champ select)
- Evidence: reviewer 3/3 asked for screenshots or video of every champ select state, a
  build, and the LCU endpoints with proof it never writes; r1 and r2 called the
  download page "only claims". docs/production-key.md lists screenshots or GIFs of champ
  select, a demo video and the LCU endpoints as application needs; plan.md "Before the
  production review": "GIFs and a short demo video still to do", the desktop window was
  never run against a real champ select
- Do: Jacob's real champ select run (plan.md has the steps: `meiolol-app.exe session
  --save`, the lane card open); then download.html gets 3 to 4 screenshots, a 30 to 60 s
  video, and a plain endpoint list (read-only, which states it reads, when it shows
  what). Say on the page what it shows before and after lock-in and in which queues:
  reviewers r1 to r3 all asked
- Key: directly on the application's needs list. Needs J7 (date or notify) only for
  wording

**A2. Make the application text describe the site.** (S; Jacob writes it)
- Evidence: reviewer matches-application 3/3 (rerun 20261017-203029 with the text in
  the task): squads promised but not found; the site's headline, win chance by minute
  with turning minute and death cost, is not in the text ("flag it for review", r2); the
  desktop app "the most policy-sensitive item, and the application doesn't mention it"
  (r3); XP and cs curves and rank tiers not seen; Learn, builds, flex and Swiftplay
  unmentioned.
  plan.md "Identity draft four" already lists the new text as owed before Verify
  (identity, Platinum+ scope, data kept, desktop app and LCU endpoints, PUUID link)
- Do: rewrite around "game review of your own games" with lane curves as the benchmark;
  name the win chance by minute (own games, after the game) and say it is never shown in
  champ select; desktop app and endpoints; squads only if built (B6) or worded as
  planned
- Key: a mismatch is the first thing reviewers flagged. Needs Q1

**A3. No whole-draft win chance or "+X points" on public pages.** (S)
- Evidence: reviewer r1 and r2 quoted "39 to 61 for blue side" and "+1.1 points in this
  draft" from Daily Draft as the item to justify; champ select r3 found the tester
  saying "the public site never shows a draft's win chance", which Daily contradicts.
  Re-walk: 6 of 6 Daily answers still quote "39 to 61", three now add it "rests on thin
  data" (bot lane on 2 games). R16, J1 (open). Learn's worded practice reveal is the
  shape to copy (first review, "What works well")
- Do: as R16 suggests: "on paper the draft leaned red" only when clear, options as
  reasons without points
- Key: production-key.md product rules. Needs J1

**A4. Daily Draft: show that a puzzle cannot point to a recent game.** (S)
- Evidence: reviewer r1 and r2 read the puzzle's date (17 Oct) as the game's and asked
  whether the full draft, bans, kills, gold and length re-identify a game played that
  day; r2 saw this as a contradiction with privacy.html ("no game dates"). Code: the
  date is the puzzle's day, not the game's (src/daily.zig:77), but the game can be any
  current-patch game (src/daily.zig make), so it may be from the same or previous day
- Do: draw only games at least N days old (7 is safe after a patch's first week; before
  that, the previous patch's or a smaller N), and say on the page "a game from patch
  16.20, at least a week old"
- Key: privacy and the "anonymised past games" wording in the application. Needs Q2 (N)

### B. While the application queues (public, policy-safe, what Riot will see)

**B1. Remember the player, without an account.** (S to M)
- Evidence: return after-game 3/3: open meio.lol "after every game rather than op.gg"
  only if the last game loads without retyping the Riot ID; second-visit 3/3 named a
  memory feature as the one change (own games remembered r1, patterns kept over weeks r2,
  friends r3). Code: the Riot ID lives only in the URL fragment (src/site/static/
  your.js:80-91), nothing in localStorage; there is no link to one game (setUrl only
  writes `id=` or `example`). Competitors: OP.GG favourites and alerts need an account;
  LoLalytics and DraftGap have none (competitors.md gap 3)
- Do: recent Riot IDs in localStorage with "N new games since your last visit" on home
  and Your games; a per-game link (`#id=...&game=...`) so a review can be sent (first
  visit share 3/3 wanted to send one game, "look where we threw at 26:00")
- Key: own games only, no new data kept on the server. Works now: /api/ is open to Riot's
  reviewers since 17 Oct

**B2. Pool first in the picker (admin Draft tester, then the app).** (M)
- Evidence: champ select own-pool 3/3 partial, timed-pick 3/3 needed it ("Viktor was
  14th in the list", "my champions aren't mid", one-trick: "tells me nothing I don't
  know"); every-game 3/3 listed it in the top three. Competitors: only iTero personalises
  by pool. Research: familiarity beats counters at low and mid ranks (player-tool-needs
  C3; Learn lesson 2 teaches it). download.html already promises "where it shows
  champions from your pool, it lists several with their reasons, never one"
- Do: a saved pool (per role, localStorage) and a "Your pool" block at the top of each
  slot: 3 to 5 of the player's champions, grouped "clear fit / no clear difference / weaker
  here" with one worded reason each, and "no clear difference" when ranges overlap
  (champ select r1 and r3 asked for exactly this; re-walk draft N3: every compare-two
  and deep-read run judged "too close to call" by hand). Then the same block in the desktop
  card (A1's screenshots should show it). First the small tester items the re-walk
  found on the same rows: a name click picks instead of opening the why (draft N1,
  costly inside a 30 s timer), "points" and "±" unexplained (N5), "lock" (N6)
- Key: the policy shape (several options, reasons, the player's own champions). Needs J2
  (the public signal) and J4 (unknown roles) for the public version only

**B3. Ban phase from the pool's hard lanes.** (S once B2 exists)
- Evidence: champ select ban-phase 3/3 partial: the ban box only excludes champions; all
  three asked for the few champions that beat their pool, with games and range, "which
  hard counter is actually popular" (r3). Porofessor, Blitz and U.GG offer ban
  suggestions
- Do: under the pool, "often hard for your pool": 3 to 5 opponents by shrunk lane and win
  numbers (R19's estimate), with play share
- Key: several options, never auto-ban. Needs Q3 (whether ban suggestions are in scope
  for the app)

**B4. What changed this patch.** (M; the code is mostly there)
- Evidence: return whats-new 3/3 partial: no "what's new", only a Patch 16.20 toggle; all
  three expected a patch page or banner. LoLalytics and Blitz lead with patch deltas
  (competitors.md gap 4). plan.md "Patch day": src/patchday.zig built, not wired (main.zig
  and root.zig steps listed there); newchamp r1 also asked how a nerf moved their main
- Do: plan.md's Patch day list as written (patch.html of clear movers, "since patch X"
  on champion pages, dashed previous-patch median on matchup charts), plus a link on home
- Key: aggregate only; shows Riot a living site. Needs the plan's open z choice (1.96 or
  2.58)

**B5. Choosing a champion to learn, in one place.** (M)
- Evidence: newchamp 3/3 succeeded but each asked for a side-by-side of 2 to 3
  candidates (learning cost, worst lanes, win rate); 2/3 for a class or style filter
  ("melee bruiser", "tank or engage"); 3/3 for "about N games to get decent" in words;
  r1 and r3 found the learning table's "usual" win rate (Sett 53.3%, Rammus 57.7%)
  different from the champion page's (51.2%, 53.2%) with no reason given (pool page's
  usual is over the sampled players' games on the champion, src/learning.zig:107;
  same kind as R25). Strength: Pool's "players who main X also play" and first-5-games
  rows did the job for r2 (Soraka to Karma)
- Re-walk: R18 still costs 11 to 15 steps and 2 of 6 runs never compared all three
  pool champions; the fastest route found is the matchup page's "Change champion"; site
  N1 (Back to the matchup index keeps the text but drops the filter, 4 of 6 runs, a
  small fix) and N2 (the search takes one name, "ahri zed" matches nothing) are most of
  the remaining cost and should go first
- Do: a compare view (R18, J6) that takes 2 to 3 champions and shows learning curve, the
  hardest lanes (shrunk) and early/late lean; a class filter on Champions (Data Dragon
  tags); one line naming why the two "usual" rates differ
- Key: champion and aggregate facts, "champion diversity" (an application angle)

**B6. Plain sentences over charts where the answer is one fact.** (S each)
- Evidence: newchamp hard-matchups 3/3 partial: "the site never says the lane turns at
  minute X", read off charts; re-walk site N4: 3/3 matchup-why answers "judged 'even'
  myself"; first visit 3/3 and return 2/3 wanted "one sentence why I
  lost" in the review; champ select 3/3 skipped "unnamed, summed" chips (R4 renamed
  them; still unread)
- Do: a matchup page headline ("Behind from the start, about 800 gold by 14" or "Even
  until 14, then decided by who is ahead"), from the curve and the win-when-ahead split;
  champion shape labels (plan.md "Curves next"); in the review, the turning minute's
  sentence first. Facts, not advice (player-tool-needs C1)
- Key: none directly; it is what "learning tool" in the application means

**B7. Example reviews for every role.** (S to M)
- Evidence: first visit 3/3 noted the example is a Lulu support game: the ADC wanted
  item and damage, the jungler pathing and objectives, the support vision and roams. The
  example is the main first-visit hook (no rival has one, competitors.md edge 4)
- Do: the box's your-example run keeps one example per role and the page offers a role
  switch; jungle-specific review content (objectives, clear) is a separate, larger item
- Key: lets reviewers see the product without a lookup

**B8. Squads, if the application keeps them.** (M to L)
- Evidence: return r3 (flex friends): a shared score or small group board is the one
  thing that brings him back tomorrow; first visit r3 (duo) asked for a duo review.
  U.GG's squad bot is paid (competitors.md gap 5). Design agreed in plan.md "Your games and
  Squads"; the application text promises it
- Do: start with the cheapest loop: a squad page with the Daily Draft results of members
  and games played together; recaps later
- Key: in the application text today (A2 decides). Needs plan.md's open Squads decision

### C. After the key

**C1. Data for Silver and Gold.** (M; crawl change, needs the rate)
- Evidence: Gold and Silver personas doubted every number: "Win chance as in Platinum+
  is unclear, I'm Gold 3" (first visit r1), "I wanted the numbers for Silver" (newchamp
  r2), "built on Platinum IV and up, can't tell if it's right for my elo" (champ select
  r1), "Platinum+ win chance would puzzle a Silver player" (return r1). The identity
  targets Silver to Emerald; the crawl is Platinum IV+ (plan.md "Tier floor", Jacob "for
  now"). Every competitor has rank filters
- Do: lower the floor when the key allows, rank brackets as plan.md "Curves next"
- Key: the application's "per rank tier" claim. Needs Q4

**C2. The desktop app public, filling the board itself.** (L)
- Evidence: champ select every-game 3/3 put "reads picks from the client" first:
  "typing ten champions in the last 30 seconds is impossible". DraftGap, LoLDraftAI,
  iTero all sync with LCU
- Do: B2's pool block and the lane card in the app; release after the key
- Key: needs the key (no public product on a personal key)

**C3. Progress that follows the player.** (M to L)
- Evidence: return learn-continue 3/3: Learn and Daily progress lost on another browser;
  all asked for a code or optional sign-in. r2: "something that builds up my own
  knowledge over time". Mobalytics sells progress tracking (Plus). Learn lessons read as
  beginner level to Silver and Platinum (return r1, r2)
- Do: progress keyed to a Riot ID the player has proven (the profile-icon check already
  used for removal), optional; deeper lessons from comp leans and lane matchups (plan.md
  "Where the app goes next" step 5); trends across own games (concept pillar 3)
- Key: needs privacy.md text for what is kept. After the key because it stores state per
  player

## 3. Questions for Jacob (new; J1 to J9 are in the first review)

- **Q1 (A2)** Rewrite the application text before Verify around game review, and keep
  or drop squads in it?
- **Q2 (A4)** Minimum age of a Daily Draft game (proposed 7 days, or the previous patch
  early in a patch)?
- **Q3 (B3)** Are ban suggestions (several, from the pool's hard lanes) in scope for
  the app in ranked champ select?
- **Q4 (C1)** Lower the crawl floor below Platinum once the key's rate allows?

## 4. Study notes

Studies in ~/personal/persona-walk/studies, runs in runs/<study>/20261017-202218:

| study | personas | tasks | outcome |
| --- | --- | --- | --- |
| meiolol-next-firstvisit (public, 1440) | Jonas (Gold ADC, Reddit), Elif (Emerald jungle, Discord, lolalytics user), Ben (Silver support, duo) | first-look, example-review, what-for, share | 12/12 success; review is the hook 3/3; share wants one game's link 3/3 |
| meiolol-next-champselect (admin tester) | Mia (Gold mid, 30 s), Noah (Platinum jungle, autofilled), Ines (Emerald Camille one-trick) | timed-pick, own-pool, ban-phase, every-game | own-pool 0/3, ban-phase 0/3 (partial); 12 findings, verified |
| meiolol-next-return (public, storage kept per run) | Sam (Silver mid), Priya (Platinum support), Tom (Gold top, flex friends) | daily-today, learn-continue, whats-new, after-game, second-visit | whats-new 0/3, after-game 0/3 (partial); return verdicts "tomorrow for Daily only", "next week", "next week unless friends" |
| meiolol-next-newchamp (public) | Ola (Platinum top), Kai (Silver support), Marc (Diamond jungle) | shortlist, learning-cost, hard-matchups, decide | hard-matchups 0/3 (partial); picks Sett, Karma, Rammus with reasons |
| meiolol-next-reviewer (public) | Dana (Riot reviewer), Rowan (integrity), Sasha (5 minutes) | matches-application, policy-check, champ-select, player-data, verdict | 3/3 "ask for more"; asks ranked in A1 to A4 |

Caveats: first-visit personas answered after 0 to 3 actions per task, so their
"would come back" rests on the home page and the example; the return study cannot fake
a week's gap, only a new browser. The reviewer study's application text sat in the
persona background, which variants replace: r2 and r3 had no text for
matches-application (study fixed, that task rerun for all three in 20261017-203029).
Verifier: 18 findings checked, 15 confirmed, 3 false (Share gives no feedback: it says
"Copied" or opens the share sheet; the home tour "stuck": it stops on any click; a
gold-column complaint already covered).
