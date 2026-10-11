# Privacy policy (draft)

Not legal advice: a plain English draft from research/questions/identity-and-privacy.md,
written by Claude. Jacob should read it in full, and ideally have it checked, before it
goes live or into the production application.

## Decisions for Jacob (fill before publishing)

- **Controller name.** A person's name, or a trading name for a sole trader? Shown below
  as `[CONTROLLER]`
- **Contact address.** jombirds@gmail.com is used below. A dedicated address
  (privacy@jomify.lol forwarding to it) reads better and survives a mailbox change
- **ICO fee.** £52 a year (tier 1, micro organisation), or £47 by direct debit. Register
  at ico.org.uk, then put the registration number in `[ICO REG]`. If you don't register,
  the ICO assumes tier 3 (£3,763). No exemption fits a public site that stores match
  histories (research: ico-data-protection-fee, ico-fee-exemptions)
- **EEA representative.** EU GDPR requires one for a UK controller that monitors EU
  players, unless the processing is "occasional" and low risk. A 24/7 crawler is hard to
  call occasional. Paid services cost roughly £100 to £300 a year (not researched). Until
  you decide, the section below stays commented out
- **Retention of crawled match rows.** Today the match tables are kept forever, keyed by
  PUUID. Proposed: drop the PUUID from match rows 24 months after the game (the
  statistics keep the anonymous row), as Counterwatch does. The text below assumes this;
  it needs a `meiolol` job before going live
- **30-day refresh.** Riot recommends refreshing stored players every 30 days and
  dropping accounts it has erased. The text promises this; it needs a crawler sweep
- **Children.** League is played by teenagers. The UK Age Appropriate Design Code may
  apply to a site likely to be used by under-18s. This site has no accounts, ads or
  tracking, which is most of what the code asks for. Not researched beyond that
- **EU transfers.** Data is stored in the UK (home server and Oracle Cloud London). The EU
  treats the UK as adequate, so no extra safeguards are needed; check that this still
  holds when publishing

Sections marked *(when live)* describe planned features: publish each with its feature.

---

# Privacy policy

Last updated [DATE].

meiolol shows how League of Legends lane matchups unfold, minute by minute, and how your
own games compare. This policy explains what data we use, why, how long we keep it, and
what you can ask us to do.

## Who we are

meiolol is run by [CONTROLLER], an individual in the United Kingdom, who is the
controller of the data described here. Contact: jombirds@gmail.com. Registered with the
UK Information Commissioner's Office as [ICO REG].

<!-- EEA representative (if appointed):
Our representative in the European Economic Area is [NAME, ADDRESS, EMAIL]. You can
contact them instead of us about anything in this policy. -->

## The short version

- No accounts, no cookies, no advertising, no analytics trackers
- The public pages show champion and aggregate statistics only, never other players
- To build those statistics we collect ranked match data from the official Riot Games
  API, which includes encrypted player identifiers. We never sell it or share it
- You can object and have your data removed at any time, using the form on this site

## Data from Riot Games

**What.** For ranked games collected through the Riot Games API: the match (champions,
items, runes, bans, game length, result), each player's per-minute gold, experience,
level, CS and map position (the match timeline), each player's visible rank when the game
was collected, and champion mastery. Players are identified by a PUUID, an identifier
Riot encrypts separately for each application, so it means nothing outside meiolol. Raw
match records from Riot also contain Riot IDs (name and tag); we keep those only inside
the raw copy, which is deleted after 30 days.

**Why.** To compute champion level and aggregate statistics: matchup curves, champion
win rates, the Daily Draft. *(when live)* And to show a player their own games when
someone looks up their Riot ID.

**Legal basis.** Legitimate interests (UK GDPR and EU GDPR Article 6(1)(f)). Most players
in our data have never visited this site, so we can't ask for consent; instead we have
weighed our interest against theirs in a written legitimate interests assessment,
available on request. In short: the data is already visible in game and on many
statistics sites, we collect only what the game exposes, we publish only aggregates, we
never contact players, build advertising profiles or sell data, and anyone can object.

**Where.** On a computer in the United Kingdom run by us. The public website is served
from Oracle Cloud in London. Backups are kept on our own machines, rotated within five
weeks, and erasures are applied to them at the same time as to the live data. Raw
records from Riot are not backed up, so the limits below apply to backups too.

**How long.**
- Raw match records from Riot (which contain Riot IDs): 30 days; raw timelines: 7 days
- Compact match and timeline data used for the statistics: the player identifier
  (PUUID) is removed 24 months after the game; the anonymous match stays for the
  statistics
- Rank and champion mastery per player: refreshed regularly; removed when the player
  has not appeared in a collected game for 24 months
- We check stored players against Riot at least every 30 days and delete any account
  Riot reports as erased

## Daily Draft

Each puzzle is a real ranked game with every player identity removed: no names, Riot
IDs, match ids or dates; only champions, bans, patch, an approximate rank tier and team
totals. Your guesses, streak and archive stay in your own browser (local storage). They
are never sent to us; clearing this site's data removes them.

## Your games *(when live)*

When you enter a Riot ID, we ask the Riot Games API for that player's recent games and
show them against the typical curves. Anyone can look up any Riot ID, as on other League
statistics sites; the page shows that player's own games only, never a comparison with
named other players. We keep the Riot ID you entered with the cached results for up to
30 days so repeat visits are fast. We don't record who looked up whom beyond the server
logs below.

## Squads *(when live)*

A squad is a group of players who have each joined themselves. To join you prove you own
your Riot ID by setting a given profile icon in the League client for a few minutes; we
read your icon once to check and don't keep it. For a squad we store: the squad name,
each member's Riot ID and PUUID, and the games members played together. Legal basis:
consent. You can leave a squad at any time, which removes you from it immediately;
a squad with no members is deleted.

## The desktop app *(when released)*

The app reads champ select from the League client on your own PC, read-only, and shows
lane information on screen. It does not send your games, account or any other personal
data anywhere. It downloads updated champion statistics from this site.

## Server logs

Like any website, our web server records each request: IP address, time, page and
browser type. We use these only for security and to fix problems, and delete them after
14 days.

## Your rights

You can ask us to:
- **Object** to our use of your data, and have it **erased**: email us, or *(when live)*
  use the [removal form](remove.html), which checks you own the Riot ID and removes you
  within minutes
- **Access** the data we hold about you
- **Correct** it, though match data comes from Riot as it happened
- **Restrict** our use of it while a request is considered

Email jombirds@gmail.com for anything the form doesn't cover. We'll ask you to prove you
own the Riot ID (the same profile icon check) and reply within one month. If you're
unhappy with our answer, you can complain to the UK Information Commissioner's Office
(ico.org.uk) or, in the EU, to your local data protection authority.

Removing your data takes your identifier out of our stored matches, deletes our raw
copies of your games and stops us showing your games. To keep it that way we keep one
thing: your encrypted identifier on a "do not collect" list, so the crawler skips you in
future. It cannot remove your games from statistics already published, which hold no
identity. It also does not affect Riot Games or other sites: Riot's own privacy requests
go through Riot.

## Changes

We'll update the date above when this policy changes, and describe significant changes
on this page.

meiolol isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot
Games or anyone officially involved in producing or managing Riot Games properties. Riot
Games, and all associated properties are trademarks or registered trademarks of Riot
Games, Inc.
