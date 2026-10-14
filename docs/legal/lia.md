# Legitimate interests assessment (draft)

Not legal advice: a draft by Claude following the ICO's three-part test (purpose,
necessity, balancing), from research/questions/identity-and-privacy.md (claims cited as
C1 to C13). The privacy policy says this assessment is available on request, so it is
written to be shown. Jacob should check it, sign it off and date it.

## Decisions for Jacob

- Same list as docs/legal/privacy.md: controller name, ICO fee, EEA representative,
  24-month PUUID retention, 30-day refresh, children
- Review date: proposed every 12 months and whenever a feature changes what is shown
  about a player (Your games, Squads, RSO)

---

# Legitimate interests assessment: meiolol

Controller: Jacob Maschler, trading as meiolol. Assessed: [DATE]. Next review: [DATE + 12 months].

## Processing covered

1. **Crawl.** Collecting ranked League of Legends match data from the official Riot Games
   API (match summaries, timelines, visible rank, champion mastery) for players chosen at
   random from every tier and region, identified by Riot's per-app encrypted PUUID
2. **Statistics.** Turning that data into champion level and aggregate statistics
   (matchup curves, win rates, the anonymised Daily Draft), published without any player
   identity
3. **Your games** *(planned)*. Showing a player's own recent games, against those
   statistics, when anyone enters their Riot ID

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
  - Riot IDs are not kept beyond the 30-day raw copy
  - Published output holds no identifiers
  - PUUIDs are dropped from match rows after 24 months, when they no longer help
    statistics
  - Consent is impossible for players who have never visited the site
- **Your games:** showing someone their own games needs their match history; looking
  it up on demand by Riot ID is how every League statistics site works. Requiring
  proof of ownership before showing anything (as VALORANT does through Riot Sign On,
  C2) is not yet possible without a production key (C4, C5, C6), and would stop players
  checking a friend's or student's games, which coaches and squads do
- **Data minimisation:** only fields the game itself exposes; no contact details, real
  names, payment, special category data or anything outside League

## 3. Balancing test: do players' interests override ours?

**Nature of the data.** Game statistics: champions, items, gold, positions on the map,
visible rank. Already visible to every player in the game, in the client's match
history, and on op.gg, u.gg, League of Graphs and similar sites (C8). Not sensitive. Some
players will be children.

**Reasonable expectations.** League players widely know their match history is public on
statistics sites; that is the norm Riot's own policy permits (C1, C8). A player would not
expect their name to appear beside statistics on a site they never visited: meiolol's
public pages never show one. Under Your games, a looked-up player's own games appear
only to whoever entered their exact Riot ID, as on every lookup site.

**Likely impact.** Low. No public profile, ranking of players, comparison with named
players, contact, advertising profile or sale. The worst plausible case is someone
seeing a player's recent games, which those sites already show. Children: the same
low-impact processing, no profiling or tracking, and the same right to object.

**Safeguards.**
- Aggregates only on public pages; the Daily Draft strips all identity (no names, Riot
  IDs, match ids or dates)
- Riot IDs kept 30 days at most; PUUIDs are per-app encrypted and meaningless outside
  meiolol; PUUIDs dropped from match rows after 24 months
- Riot's erasure lists honoured, and stored players refreshed every 30 days (C7)
- Objection open to anyone, without an account: a self-service form proves ownership by
  a profile icon check and removes the player within minutes, then keeps them on a "do
  not collect" list (C9, C12)
- No cookies, ads or analytics; server logs kept 14 days
- Data held in the UK; never sold or shared
- Never infer hidden matchmaking rating, never show players hidden by the game (C3)

**Outcome.** The balance favours processing. Players' interests are protected by the
safeguards, and the impact is no greater than on the statistics sites they already
expect. Any player who disagrees can opt out at once.

## Decision

Legitimate interests (UK GDPR and EU GDPR Article 6(1)(f)) is the lawful basis for the
crawl, the statistics and Your games. Squads use consent.

Revisit when: Your games launches, Squads launch, RSO becomes available (consider
requiring it for Your games), a feature starts showing players to anyone other than the
person who looked them up, or a complaint or regulator view suggests a different balance.

Signed: Jacob Maschler, trading as meiolol, [DATE]
