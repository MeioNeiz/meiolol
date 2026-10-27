# Data

Production key details: production-key.md.

## Source: Riot API only

- Personal key: 20 req/s and 100 req/2 min per routing value, no expiry, not for public
  use. Each routing value is its own bucket (~72k req/day): match-v5 uses the 4
  regional ones (americas, asia, europe, sea), league-exp and mastery the 15 platform
  ones. Match ids, details and timelines share their region's bucket
- All 15 platforms are crawled (other regions fill blind spots). Platform -> region:
  NA1 BR1 LA1 LA2 americas; KR JP1 asia; EUW1 EUN1 TR1 RU ME1 europe; OC1 SG2 TW2 VN2
  sea (OC1 verified on sea). PH2/TH2 don't resolve (merged into SG2)
- Timelines (`/matches/{id}/timeline`): 1 frame/min, ~730 KB JSON / ~60-70 KB gz, one
  extra call per match. With timelines a match costs ~2.13 calls (incl. ids), so ~33k
  matches/day per region, ~135k/day total. Stored compact
  (docs/architecture.md, Storage); raw kept 7 days, raw summaries 30 days
- Summary-only alternative (`--timelines 0`): ~63k matches/day per region. The box
  runs `--timelines 50 --timelines-priority 100 --timeline-min-s 900`: 100% EUW
  timelines for the curves benchmark; 50% elsewhere (by match id hash) until the
  production key; games under 15 min skipped
- Matchup-aware sample (`--timelines-sparse N`, sparse.zig, off): replayed in storage
  order over 646k 16.20 games with timelines (all with the 900 s skip),
  non-EUW calls saved | coverage (share of all lanes in a cell with 200+ timelines,
  every game / Diamond+) | champion mix TVD | gold@14 shift: every game 1.6% | .798 /
  .468; flat 50% 50.8% | .726 / .326 | .018 | 18 gold; any lane under 200 in its rank
  cell 8.9% | .798 / .468 | .010 | 4 gold (nearly every game has one rare lane, so it
  saves little); `--timelines 35 --timelines-sparse 200 --timelines-sparse-from
  DIAMOND` 50.8% | .727 / .468 | .026 | 21 gold, median length 1739 s against 1749
  (Diamond+ over-weighted in the every-game view). The last matches flat 50%'s cost and
  every-game coverage and keeps Diamond+ whole; not on yet. Its start-up count reads
  every newest-patch game's participants, untimed on the box. Replay:
  data/team/2026-10-18-waste/mu*.py (gpu-box, backup segments)
- ~33k matches/day is fetch throughput, not games played: a day's fetch spreads over the
  patch's earlier days (backfill), and each past game day keeps growing ~1.5k a day as
  players are rescanned. A settled game day holds ~17-24k EUW solo games
- EUW is the priority (Jacob): the europe bucket scans EUW players first, so its ~33k
  matches/day are nearly all EUW (~20% of EUW's ~150-170k ranked solo games/day,
  lolalytics counts). EUNE, TR, RU and ME get only what EUW leaves (in practice a few
  matches EUW accounts played there)
- Match data kept 2 years (timelines 1 year); a player's match list holds their last
  ~1000 games, older ones only reachable by match id
- Metas differ by region (KR especially): matches.platform lets stats pool or split
- Pick order: in no match-v5 record (420, 400, 440, 480 tested: role order, ban
  `pickTurn` is the slot) nor tournament lobby events; spectator-v5 lists live players in
  a non-role order, maybe champ select order (untested; test in
  research/sources/meiolol-pick-order-queues.md f4); pro games' order is in Leaguepedia;
  LCU has it
- Not available anywhere: rank at match time (participants.tier is the ladder rank when
  we stored the match; rank_history has every Platinum+ player's ladder rank per day it
  changed, refreshed every 12 h, so rank at game time to within a day for games from
  12 Oct 2026 on), mastery at match time
- Production key: 3-8 month review, needs a live site; default limits may be no higher
  than personal. Only worth it for the public app
- One developer account per person and no key sharing (API Terms); one product per key

## Static game data (not the Riot API)

- Data Dragon (Riot's CDN): champion, item and rune names, ids, icons; patchnotes'
  base stats, cooldowns, costs, item gold and texts. Many ability numbers missing or
  blanked to 0
- CommunityDragon (raw.communitydragon.org, a fan mirror of the game files): the
  per-champion bin JSON's spell DataValues, calculations and base stats, for the patch
  page's ability numbers (src/cdragon.zig); rune shard and position icons. Unofficial,
  so optional: without it the notes are Data Dragon's. Per patch (16.21), not per
  build: mid-patch updates count only until the patch is cached. Behaviour changes and
  game-mode overrides (Arena, ARAM) are not read. Checked 27 Oct on 16.20 -> 16.21:
  23 champions changed against Data Dragon's 11; of Riot's notes for the Rift, all
  numbers appear except Vel'Koz Q cooldown 7 -> 6 (7 in both sources) and Varus'
  22 Oct passive and Viktor's shield uptime (not found in the files)

## Dropped, and why

- lolalytics API: response says "private API ... may not be used by third parties".
  Its matchup and synergy rates can be computed from our own matches instead
- Hugging Face / Kaggle dumps: old patches (15.x) or Master+ only; useless for an app
  about today's games
- Leaguepedia / Oracle's Elixir: pro play, not the target players
- op.gg, u.gg etc: scraping against their terms or unclear; nothing we need

## Policy

From Riot's general policies (2025-05-29) and the Overwolf Riot compliance guide:

- Register the product (LCU apps too). Personal key: personal use only
- Show options with reasons; do not remove choices or auto-lock/ban/dodge
- Ranked champ select: never reveal hidden names; non-party players are "Ally 1..5"
- No MMR calculators, no de-anonymising
- At pick time we only know the user's own identity and mastery, so the model can only
  use teammates' and enemies' champions, not their history
