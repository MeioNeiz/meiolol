# Concept: meiolol, learn your lane

## Framing: game review, like chess.com's (Jacob, 2026-10-13)

The product is "game review for League": look yourself up, each game reviewed like a
chess game. Win chance by minute with an evaluation bar; key moments as move classes
(turning minute, big minutes, swings against you, costly deaths) on the chart and in a
list; death cost; lane against typical; a strip of recent games. Next: the Rift map as
the board (deaths, objectives, your position by minute: timelines have positions, the
API doesn't send them yet). Look: Linear-like (small type, dark, violet accent, data in
colour); Jacob rejected League-site looks (splash art, big condensed type), editorial,
terminal and Wrapped styles. Home leads with the lookup and a review demo. Menu: Your
games, Daily Draft, Learn, Champions (Matchups and Champion pool as its tabs). Code:
static/review.js, your.js, home.js; root.zig writeIndex; html.zig nav

## Identity draft four: scout your own games (Jacob, 2026-10-12)

Supersedes the pitch below where they differ; the parts below stay as the benchmark and
extras. Focus on the player, not the meta.

- Pitch: every ranked game you've played, turned into the stats nobody else shows you:
  fun enough to share, deep enough to learn from. Home page leads with "look yourself
  up" (src/site/root.zig writeIndex); matchup curves are the benchmark behind it
- Pillars (Jacob's picks from ~60 ideas):
  1. Game rewind: summary story, turning minute (win-chance model, whole game), how you
     died (damage by type: needs death recaps), death cost, jump to the moment (replay)
  2. Highlights / record book: streaks, longest game, best KDA, won from behind, lost
     from ahead, when you play, champion picks, ability use, great games (throw, carry,
     comeback). Recent-game highlights live on your.html; the full-history record book
     only on request by the account owner (icon check), kept while used
  3. Scouting report: fingerprint, role lenses, tilt check, snowball vs comeback,
     spikes (spike window, level spikes), late game (baron calls, sidelane)
  4. Matchup notebook: record per matchup, builds that worked, counter-item timing,
     pool health; public "how to beat X as Y" and "X vs tanks" pages
  5. Before the game (desktop app): pre-game brief from your own notebook
  6. Squads: superlatives, head to head, rewind cards (Riot's Rift Rewind hackathon
     rewarded year-wrapped recaps, personas, friend head-to-heads)
- Not only the first 14 min: lane against the curve; mid and late game judged by what
  followed (deaths before objectives, throws, fights, objective setup); spikes link them
- Raw archive kept until PUUID blanking at 24 months (Jacob); privacy.md not yet updated

Adopted 2026-10-11. Evidence: research/questions/
league-tools-landscape, riot-appreciated-tools, player-tool-needs, riot-api-data-depth
(all answered; claims cited below as question:Cn). Persona runs: summary at the end.

## Pitch

How lane matchups actually unfold, minute by minute, and how your own games compare. From
ranked match timelines across all regions: the typical gold, XP and CS curve of every lane
matchup by rank, and after each game your lane laid over that curve, with your record per
matchup over time. A daily draft puzzle and friend squads make it social. Champion and
aggregate facts only; never other players; never "the best pick".

## Why this and not the pick recommender

- Riot rewards post-game reflection, progress over time, sharing with friends, champion
  discovery and novelty beyond op.gg (appreciated:C1, C2, C3, C8). Registration popup
  "Please Do": connect players with friends; help them evaluate and improve their own
  gameplay. A pick ranker sits on "apps that dictate player decisions"
  (production-key:C3) and Riot keeps closing live-lobby tools (appreciated:C6)
- Gap: big sites use timelines but reduce each matchup to one number (GD@15, lane kill
  rate); none shows the curve or when and why a lane is won (landscape:C2, C3). "Wins
  lane" and "wins game" disagree per matchup (landscape:C8)
- Players want facts about their own finished games, not verdicts; post-game is seen as
  fair, live help not (needs:C1, C2). At low/mid elo champion experience beats counters
  (needs:C3), so the product teaches your champions instead of swapping them
- No daily draft puzzle exists; a draft guess-the-winner game got a production key fast
  once it had traffic (landscape:C9, C12; appreciated:C10)
- Genuinely data-hungry: per-matchup per-bracket curves need millions of timelines per
  patch, beyond one region on a personal key even if every EUW game were fetched
  (data:C8, C9)

## Product, in priority order

1. **Your games** (website; the core loop, every persona except casual ranked it first)
   - Enter a Riot ID. Each recent game: your lane's gold/XP/CS difference by minute laid
     over the typical curve for that matchup at your tier, with the facts that explain the
     gap (deaths, recalls, CS at 10 vs typical, first item minute)
   - Highlight the biggest gap as a fact ("furthest behind typical at 6-8 min; 2 deaths
     then"), never advice ("you should have")
   - Weekly roll-up and per-matchup trend over months ("gold at 10 vs Renekton: -400 to
     -150 since August"): patterns, not single-game anecdotes
   - Tier means visible rank, never inferred MMR (prohibited)
   - Any Riot ID, on legitimate interests (League policy has no consent rule for ranked
     or normal history); an objection/removal form gated by a profile-icon check (set a
     given starter icon, we re-read it). RSO once the production key allows
     (research: identity-and-privacy)
2. **Matchup curves** (website; the benchmark and the public, indexable pages)
   - Every lane matchup: typical gold/XP/CS difference by minute with spread band, kill
     and death chance by phase, level 6 and first-item timing per side, wins lane vs wins
     game. Summaries generated from the numbers and shown next to them
   - Filters: tier bracket, patch (pooled while thin), region (pooled by default),
     experienced players only (by mastery), core item where builds split
   - Every chart shows tier, patch, n and spread; greyed out as "more data needed" below
     ~200 games or when the estimate is mostly the champions' baseline (trust, and the
     honest case for more volume)
   - Method (research: curve-statistics-method): champion baselines plus a matchup effect
     shrunk by k pseudo-games (method of moments), smoothed across minutes; after minute
     15 labelled "among games still running"; spread band and uncertainty of the mean
     shown separately; k per role published as "games to stabilise" on the method page
3. **Daily Draft** (website; the hook and the traffic)
   - One real anonymised ranked draft a day, same for everyone: guess the winner, or which
     of four champions was picked last; the reveal explains with curves and stats
   - Streak, shareable emoji grid, archive; an easy daily for newer players
   - No Riot IDs, match IDs or exact dates; reveal is "what happened and why", never "the
     correct pick". Reuses the current recommender as the scoring engine
4. **Squads** (website; friends, and the coach roster)
   - A group of Riot IDs, each member opting in by proving their ID with the icon check
     (consent). Friends: weekly recap of games played together in ranked, normals, ARAM,
     Arena and rotating modes (not ARAM Mayhem: private in the API), awards measured against the curves ("biggest fall
     below the curve", "best comeback minute"), squad Daily Draft board, Discord image.
     Coaches: the same list as a student roster with one-click weekly reviews and chart
     export (PNG/SVG with tier, patch, n)
5. **Pool** (website)
   - Players who main X also play Y (mastery); champions that cover your main's worst
     matchups (from curves and your record); a ban fallback for one-tricks
6. **Lane card** (desktop app, optional, secondary)
   - In champ select, once you have a champion: the likely lane opponent's matchup curve
     in one sentence plus your own record in it. Opponent labelled as a guess (enemy roles
     are hidden). "From your pool": several options with reasons, never one. Read-only
     LCU, no Overwolf, never other players' names or stats

Added the same day (Jacob and the build sessions):

7. **Learn** (website): plain-language lessons (roles, counters and why your own champion
   matters more, early vs late, damage mix, synergy) with real examples and checks, plus
   unlimited practice drafts by role and difficulty (graded on facts, not model scores);
   for new players, beside the Daily Draft
8. **Learning curves**: win rate and lane gold by games played on a champion ("how many
   games to learn X"), on champion pages and Pool
9. **Comeback odds**: win rate by lane gold lead or deficit at 10 and 15 min per matchup
10. **Patch day** (core built): what moved between patches, champions and matchups, gated
    by significance

Dropped: ranking picks for the whole draft as a headline feature. Kept internally for the
Daily Draft and as the multi-option "from your pool" list.

## Data needs (the rate limit case)

- Aggregate curves: match + timeline per game (~2.2 calls/match), ranked solo, all four
  match regions (americas, asia, europe, sea; limits are per region). Personal key:
  ~33k matches/day per region, ~130k/day total, ~1.8M per patch
- Need, at n = 400 per pair per bracket (3 brackets): 5% x 5% pick-rate pairs 240k matches
  per patch, 2% x 2% pairs 1.5M, 1% x 1% pairs 6M; the experienced-players filter divides
  usable games by ~3. So rare and experienced-only curves need the full ranked volume of
  every region, which only a production key can fetch (data:C8)
- Personal pages: match ids, matches and timelines for each user's games on demand (cached
  by match id; most already in the crawl)
- Mastery: champion-mastery-v4 for crawled players (platform limits, every server)
- Storage: extracted per-minute features, not raw timelines (~2 GB/day gz per region raw)

## Architecture changes

- Crawler: timelines and all regions (meiolol-de, 2026-10-11), per-minute feature table
- `meiolol stats`: curve file per patch/bracket/lane pair/minute, beside the model file
- Site: matchup pages, Daily Draft page (daily JSON from the box, state in localStorage)
- New: a small dynamic service for Your games and Squads (Riot ID lookups need the key
  server-side; the site is static today), on the jomify server behind the same nginx.
  Preview mode until the production key
- App: lane card replaces the pick list as the default view

## Application wording (Riot reviewer persona)

Use: "helps players understand how lane matchups unfold", "compare their own lane with the
typical curve", "teaches draft through play", "several options rather than one pick",
"champion and aggregate data only". Avoid: recommender, ranks picks, best pick, solve
draft, win more, "should". Show the volume maths, the share of curves still too thin, and
that timelines are cached and deduplicated. Bring traffic numbers to the later rate
increase ticket (Daily Draft and curve pages carry that).

## Persona runs (2026-10-11)

| Persona | Comes back for | Ranking | Biggest ask |
| --- | --- | --- | --- |
| New player | Your games, one fact to work on | C > concept > B > A | plain language first, curves behind "show why"; ARAM |
| Ranked climber | Your games, weekly roll-up | concept > C > A > B | n on every chart; roll-up across games |
| One-trick | Your games by matchup over months | concept > C > A > B | experienced-players filter; ban fallback |
| Casual with friends | Daily Draft | B > concept > C > A | Squad page with awards, any queue |
| Coach / creator | Your games for 10 students | concept > C > B > A | roster, chart export with tier/patch/n, grey thin data |
| Riot DevRel | approves 1-4, card with conditions | concept > C > B > A | no MMR, anonymised puzzle, opponent as guess, wording |

A (today's pick recommender) ranked last or third by every persona. C (post-game review
alone) is strong for players but cannot justify a rate increase; B (puzzle alone) brings
traffic but no data need. The combination is the only option every persona ranks first or
second.

## Open

- Settled: match-v5 serves 420/440/400, ARAM 450, Arena 1700/1750, ARURF 900, Clash, all
  with timelines; ARAM Mayhem (2400) and Brawl are private (research: match-v5-queues)
- Draft model on ~6.5k EUW games is no better than a coin flip (docs/model.md, branch
  worktree-draft-model): data is the bottleneck; recheck as all-regions data lands
- Gold-diff spread per role unmeasured: n = 400 is a binomial assumption
- How much regions differ per matchup (pooling bias): measure once all regions crawl
- Incumbents could add curves cheaply; the moat is the personal loop, squads, the puzzle
