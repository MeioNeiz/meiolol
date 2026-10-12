# Data

Researched 2026-10-11. Production key details: production-key.md.

## Source: Riot API only

- Personal key: 20 req/s and 100 req/2 min per routing value, no expiry, not for public
  use. Each routing value is its own bucket (~72k req/day): match-v5 uses the 4
  regional ones (americas, asia, europe, sea), league-exp and mastery the 15 platform
  ones. Match ids, details and timelines share their region's bucket
- Crawled since 2026-10-11 (Jacob: other regions fill blind spots): all 15 platforms.
  Platform -> region: NA1 BR1 LA1 LA2 americas; KR JP1 asia; EUW1 EUN1 TR1 RU ME1
  europe; OC1 SG2 TW2 VN2 sea (OC1 verified on sea). PH2/TH2 no longer resolve (merged
  into SG2). All 15 answered league-exp on 2026-10-11
- Timelines (`/matches/{id}/timeline`): 1 frame/min, ~730 KB JSON / ~60-70 KB gz, one
  extra call per match. With timelines a match costs ~2.13 calls (incl. ids), so ~33k
  matches/day per region, ~135k/day total (was ~60k EUW summaries only). Stored compact
  (docs/architecture.md, Storage); raw kept 7 days, raw summaries 30 days
- Summary-only alternative (`--timelines 0`): ~63k matches/day per region. The box
  runs `--timelines 50`: EUW keeps every timeline (priority platforms always do), the
  other regions get ~43k matches/day each, half with one
- EUW is the priority (Jacob): the europe bucket scans EUW players first, so its ~33k
  matches/day are nearly all EUW (~20% of EUW's ~150-170k ranked solo games/day,
  lolalytics counts). EUNE, TR, RU and ME get only what EUW leaves (in practice a few
  matches EUW accounts played there)
- Match data kept 2 years (timelines 1 year); a player's match list holds their last
  ~1000 games, older ones only reachable by match id
- Metas differ by region (KR especially): matches.platform lets stats pool or split
- Not available anywhere: pick order (ban `pickTurn` is slot order, not real order),
  rank at match time (participants.tier is the ladder rank when we stored the match;
  since 2026-10-12 rank_history has every Platinum+ player's ladder rank per day they
  changed, refreshed every 12 h, so rank at game time to within a day from then on),
  mastery at match time
- Production key: 3-8 month review, needs a live site; default limits may be no higher
  than personal. Only worth it for the public app
- One developer account per person and no key sharing (API Terms); one product per key

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
