# Legitimate interests assessment (draft)

Not legal advice: a draft by Claude following the ICO's three-part test (purpose,
necessity, balancing), from research/questions/identity-and-privacy.md (claims cited as
C1 to C13) and research/questions/streamer-mode-names.md (cited as S1 to S5). The
privacy policy says this assessment is available on request, so it is written to be
shown. Jacob should check it, sign it off and date it.

## Decisions for Jacob

- Same list as docs/legal/privacy.md: controller name,
  24-month PUUID retention, 30-day refresh, children
- Review date: proposed every 12 months and whenever a feature changes what is shown
  about a player (Your games, Squads, RSO)
- Names (J18, 20 Oct 2026): other players' Riot IDs now show in Your games. Balancing
  rewritten below; check "Names of other players" and the Daily Draft line (still no
  names there)

---

# Legitimate interests assessment: meiolol

Controller: Jacob Maschler, trading as meiolol. Assessed: [DATE]. Next review: [DATE + 12 months].

## Processing covered

1. **Crawl.** Collecting ranked League of Legends match data from the official Riot Games
   API (match summaries, timelines, visible rank, champion mastery) for players chosen at
   random from every tier and region, identified by Riot's per-app encrypted PUUID
2. **Statistics.** Turning that data into champion level and aggregate statistics
   (matchup curves, win rates) and the Daily Draft (one real game a day: per seat rank
   and scoreboard, no names, Riot IDs, match ids or dates), published without player
   names or identifiers
3. **Your games**. Showing a player's own recent games, against those statistics, when
   anyone enters their Riot ID. Each game lists its ten players with their champion,
   kills, deaths and assists and their Riot ID as at that game, as lookup sites do

Squads are out of scope: they rely on consent (each member proves their Riot ID and
joins themselves).

## 1. Purpose test: is there a legitimate interest?

- **Our interest:** run a free learning tool that shows players how lane matchups
  unfold and how their own games compare. Individual and, potentially, commercial
  interests both count (ICO; C9)
- **Players' and the public's interest:** learning from finished games is what players
  ask for and what Riot encourages third-party developers to build (research:
  player-tool-needs, riot-appreciated-tools)
- **Riot's terms allow it:** League policy has no consent rule for showing a player's
  ranked or normal match history; only custom games need opt-in (C1). The developer
  terms require apps not to violate privacy rights or law and not to de-anonymise
  players the game hides (C3), which this assessment addresses
- **Lawful and clear:** yes

## 2. Necessity test: is the processing needed for that purpose?

- **Crawl:** matchup curves need millions of games across ranks and regions; there is no
  aggregate source of per-minute lane data (research: riot-api-data-depth). PUUIDs are
  needed during collection: they are how the API finds players' matches, avoids double
  counting and attaches rank and mastery
- **Less intrusive alternatives considered:**
  - The crawl keeps no Riot IDs beyond the 30-day raw copy
  - Published output holds no identifiers
  - PUUIDs are dropped from match rows after 24 months, when they no longer help
    statistics
  - Consent is impossible for players who have never visited the site
- **Your games:** showing someone their own games needs their match history; looking
  it up on demand by Riot ID is how every League statistics site works. Requiring
  proof of ownership before showing anything (as VALORANT does through Riot Sign On,
  C2) is not yet possible without a production key (C4, C5, C6), and would stop players
  checking a friend's or student's games, which coaches and squads do
- **Names in Your games:** a game review is about a team game; who was on each side
  is what lets a player recognise the game, find their duo partner or check how a
  teammate or opponent played, the reason players use lookup sites. Champions alone
  repeat across games and say less. The Riot ID is the identifier Riot itself shows
  for every player in a finished game, in the client's match history and on every
  lookup site (C1, S1). Less intrusive alternatives considered: champions only (the
  rule until 20 Oct 2026; it hides who played, which is the information the feature
  is for); names only of the looked-up player's team (opponents are as relevant for a
  review). Kept: names appear only inside a lookup's answer, never on a static page,
  and only for finished games
- **Data minimisation:** only fields the game itself exposes; no contact details, real
  names, payment, special category data or anything outside League

## 3. Balancing test: do players' interests override ours?

**Nature of the data.** Game statistics: champions, items, gold, positions on the map,
visible rank. Already visible to every player in the game, in the client's match
history, and on op.gg, u.gg, League of Graphs and similar sites (C8). Not sensitive. Some
players will be children.

**Reasonable expectations.** League players widely know their match history is public on
statistics sites, names included: op.gg, u.gg, League of Graphs and the client's own
match history list every player of a finished game by Riot ID; that is the norm Riot's
own policy permits (C1, C8, S1). A Riot ID is a gaming handle the player chose, not a
real name, though some players use their real name or a handle known elsewhere
(streamers, pros). Under Your games, a game appears only to whoever entered the exact
Riot ID of one of its players, as on every lookup site; the static pages (champions,
matchups, Daily Draft, Learn) name nobody.

**Streamer mode.** Riot's streamer mode hides a player's Riot ID from other players and
third-party apps during a match; Riot says match history and replays are not affected,
and match-v5 (finished games, our only source for names) neither blanks nor marks
those players (S2, S3). meiolol shows no live games and no champ select, so it never
shows a player while the game is hiding them. Riot's rule against identifying players
"deliberately hidden by the game" (C3) is met by not reading or showing live games;
finished games are not hidden by the game (S5). Large lookup sites name players by Riot
ID and hide streamer-mode players only on live game pages (S1, S4).

**Names of other players.** Listing teammates and opponents by Riot ID links them to
the looked-up player's games: someone can see who a player queued with and how each
played. Risks: flaming or harassing a teammate after a loss, or following a known
player's games. Both are already possible from the client's match history and every
lookup site, which show the same names for the same games, so meiolol adds no new
exposure; and it shows only finished games (listed by Riot minutes after the end), so
it cannot be used to find a player in a live game. Each name links only to that
player's own lookup, the same page anyone could reach by typing it.

**Likely impact.** Low. No profile pages, ranking or leaderboard of players, search by
anything but an exact Riot ID, live games, contact, advertising profile or sale. The
worst plausible case is someone seeing a player's recent games and who was in them,
which those sites already show. Children: the same low-impact processing, no
profiling or tracking, and the same right to object.

**Safeguards.**
- Public pages show aggregates, and the Daily Draft shows one game a day with players
  only as seats (no names, Riot IDs, match ids or dates). Its per-seat ranks and
  scoreboard could be matched to the same game on lookup sites, which already show it
  with names, so it adds no exposure beyond what those sites publish
- Riot IDs of other players appear only in Your games answers, for finished games,
  never on a page search engines index (the API is excluded in robots.txt)
- Crawl: Riot IDs kept 30 days at most. Your games: a game's Riot IDs go with the game,
  30 days after nobody has looked up any of its players. PUUIDs are per-app encrypted
  and meaningless outside meiolol; PUUIDs dropped from match rows after 24 months
- Riot's erasure lists honoured, and stored players refreshed every 30 days (C7)
- Objection open to anyone, without an account: a self-service form proves ownership by
  a profile icon check and removes the player within minutes, their Riot ID in other
  players' games included, then keeps them on a "do not collect" list, so their name is
  never stored again (C9, C12)
- No ads or analytics; a session cookie only for invited logins; server logs kept 14 days
- Data held in the UK; never sold or shared
- Never infer hidden matchmaking rating, never show players hidden by the game: no live
  games, no champ select names (C3)

**Outcome.** The balance favours processing, names in Your games included. Players'
interests are protected by the safeguards, and the impact is no greater than on the
statistics sites and the client match history they already expect. Any player who
disagrees can opt out at once, and their name goes from every game we hold.

## Decision

Legitimate interests (UK GDPR and EU GDPR Article 6(1)(f)) is the lawful basis for the
crawl, the statistics and Your games. Squads use consent.

Revisit when: Squads launch, RSO becomes available (consider requiring it for Your
games), a feature names players outside a lookup's answer (Daily Draft names, profile
pages, leaderboards, live games), Riot changes streamer mode to cover finished games, or
a complaint or regulator view suggests a different balance.

Signed: Jacob Maschler, trading as meiolol, [DATE]
