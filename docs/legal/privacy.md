# Privacy policy (draft)

Not legal advice: a plain English draft from research/questions/identity-and-privacy.md,
written by Claude. Jacob should read it in full, and ideally have it checked, before it
goes live or into the production application.

## Decisions for Jacob (fill before publishing)

Decided 2026-10-14: controller "Jacob Maschler, trading as meiolol"; contact
privacy@jomify.lol, a forward to jombirds@gmail.com (jomify.lol already uses Namecheap
email forwarding: add the alias there before publishing).

- **EEA representative.** EU GDPR requires one for a UK controller that monitors EU
  players, unless the processing is "occasional" and low risk. A 24/7 crawler is hard to
  call occasional. Paid services cost roughly £100 to £300 a year (not researched). Until
  you decide, the section below stays commented out
- **Retention of crawled match rows.** 24 months (Jacob, 2026-10-13): the crawler blanks
  PUUIDs 24 months after the game, as Counterwatch does. Not built yet, needed before
  going live: deleting archive files at 24 months (gpu-box), and the same sweep over
  backup segments, which are append-only and never rotated, so their PUUIDs and rank
  history outlive 24 months today
- **30-day refresh.** Riot recommends refreshing stored players every 30 days and
  dropping accounts it has erased. Implemented by meiolol-de: ladders refresh daily,
  mastery at least every 30 days, and a 404 for a PUUID deletes the player at once
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

meiolol is run by Jacob Maschler, trading as meiolol, an individual in the United Kingdom,
who is the controller of the data described here. Contact: privacy@jomify.lol.

<!-- EEA representative (if appointed):
Our representative in the European Economic Area is [NAME, ADDRESS, EMAIL]. You can
contact them instead of us about anything in this policy. -->

## The short version

- No accounts, no cookies, no advertising, no analytics trackers
- The public pages show champion and aggregate statistics only, never other players
- To build those statistics we collect ranked match data from the official Riot Games
  API, which includes encrypted player identifiers. We never sell it or share it
- You can object and have your data removed at any time by emailing us at
  privacy@jomify.lol, or using "Remove a Riot ID" on the Your games page

## Data from Riot Games

**What.** For ranked games collected through the Riot Games API: the match (champions,
items, runes, bans, game length, result), each player's per-minute gold, experience,
level, CS and map position (the match timeline), each player's visible rank when the game
was collected, and champion mastery. Players are identified by a PUUID, an identifier
Riot encrypts separately for each application, so it means nothing outside meiolol. Raw
match records from Riot also contain Riot IDs (name and tag). These stay on our server
only until the record is copied to our archive, usually within a few days; the archive
copy has Riot IDs removed and player identifiers replaced by one-way codes.

**Why.** To compute champion level and aggregate statistics: matchup curves, champion
win rates, the Daily Draft. And to show a player their own games when someone looks up
their Riot ID.

**Legal basis.** Legitimate interests (UK GDPR and EU GDPR Article 6(1)(f)). Most players
in our data have never visited this site, so we can't ask for consent; instead we have
weighed our interest against theirs in a written legitimate interests assessment,
available on request. In short: the data is already visible in game and on many
statistics sites, we collect only what the game exposes, we publish only aggregates, we
never contact players, build advertising profiles or sell data, and anyone can object.

**Where.** On a computer in the United Kingdom run by us. The public website is served
from Oracle Cloud in London. Backups and the archive are kept on our own machines, and
erasures are applied to them at the same time as to the live data.

**How long.**
- Raw match records from Riot (which contain Riot IDs): on our server until archived,
  usually a few days
- Archive of raw match records, without Riot IDs and with player identifiers replaced
  by one-way codes: 24 months after the game, then deleted
- Compact match and timeline data used for the statistics: the player identifier
  (PUUID) is removed 24 months after the game; the anonymous match stays for the
  statistics
- Rank history per player: 24 months after the player's most recent rank
- Rank and champion mastery per player: refreshed regularly; removed when the player
  has not appeared in a collected game for 24 months
- We refresh stored players at least every 30 days and delete any account Riot reports
  as not found

## Daily Draft

Each puzzle is a real ranked game with every player identity removed: no names, Riot
IDs, match ids or dates; only champions, bans, patch, an approximate rank tier and team
totals. Your guesses, streak and archive stay in your own browser (local storage). They
are never sent to us; clearing this site's data removes them.

## Your games

When you enter a Riot ID, we ask the Riot Games API for that player's recent Summoner's
Rift games and show their own lane against the typical curve for each matchup. Anyone can
look up any Riot ID, as on other League statistics sites (legal basis: legitimate
interests). The page shows only that player's games: their champion, their lane
opponent's champion and the numbers, never other players' names.

For each player looked up we store the Riot ID, Riot's encrypted player identifier,
server, visible rank, and the games we fetched: champions, positions, results and
per-minute statistics, with no names; the other players in those games are kept only as
one-way hashes of their identifiers. A player nobody has looked up for 30 days is
deleted. We don't record who looked up whom, and lookups are not in our server logs.

To remove your games and stop us collecting them again, use "Remove a Riot ID" on the
Your games page (the profile icon check below); we delete everything about you and keep
only your encrypted identifier on a "do not collect" list.

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
- **Object** to our use of your data, and have it **erased**: email us, or use "Remove a
  Riot ID" on the [Your games](your.html) page, which checks you own the Riot ID and
  removes you within minutes
- **Access** the data we hold about you
- **Correct** it, though match data comes from Riot as it happened
- **Restrict** our use of it while a request is considered

Email privacy@jomify.lol for anything the form doesn't cover. We'll ask you to prove you
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
