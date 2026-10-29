# Privacy policy (draft)

Not legal advice: a plain English draft from research/questions/identity-and-privacy.md,
written by Claude. Jacob should read it in full, and ideally have it checked, before it
goes live or into the production application.

## Decisions for Jacob (fill before publishing)

Decided 2026-10-14: controller "Jacob Maschler, trading as meiolol"; contact
privacy@meio.lol (Cloudflare Email Routing to Jacob's inbox, 17 Oct; the only address
published: no personal email on the site).

- **Retention of crawled match rows.** 24 months (Jacob, 2026-10-13): the crawler blanks
  PUUIDs 24 months after the game, as Counterwatch does. Backup segments get the same
  sweep (18 Oct, backup.sweepAged on the box and both mirrors: PUUIDs of games over 24
  months old, rank history whose newest row is), and the gpu-box's mastery history
  files go 24 months after their window. The raw archive's 24-month step
  (meiolol-lab archive-age) removes the hashed PUUIDs and mastery files; the matches
  stay, linked to no one (checked 24 Oct: it deletes no match files)
- **30-day refresh.** Riot recommends refreshing stored players every 30 days and
  dropping accounts it has erased. Implemented by meiolol-de: ladders refresh daily,
  mastery at least every 30 days, and a 404 for a PUUID deletes the player at once
- **Mail.** privacy@ mail is kept in Cloudflare KV with no end (deploy/mail-worker.js)
  and forwarded to Gmail: needs a retention length, and Cloudflare is outside the UK
- **Children.** League is played by teenagers. The UK Age Appropriate Design Code may
  apply to a site likely to be used by under-18s. This site has no public accounts, ads or
  tracking, which is most of what the code asks for (logins are for invited testers and
  admins only). Not researched beyond that
- **EU transfers.** Data is stored in the UK (C01 in Essex; backup mirrors and the
  archive on our own machines in the UK); Cloudflare (US) carries the site's traffic. The EU
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
who is the controller of the data described here. Contact: privacy@meio.lol.

## The short version

- No public accounts, no advertising, no analytics trackers; logins (one session cookie)
  only for people we invite: email or username, password hash, role, created and last
  used, deleted on request (`meiolol account delete`); backups (gpu-box, 14 days)
  age it out within 14 days
- The public pages show champion and aggregate statistics, and Daily Draft games with
  players shown only as seats (no names); a player's games, with the Riot IDs of the
  players in them, appear only when someone looks up their Riot ID
- To build those statistics we collect ranked match data from the official Riot Games
  API, which includes encrypted player identifiers. We never sell it or share it
- You can object and have your data removed at any time by emailing us at
  privacy@meio.lol, or using "Remove a Riot ID" on the Your games page

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
statistics sites, we collect only what the game exposes, we publish no names or player
identifiers outside a looked-up player's own games, we never contact players, build
advertising profiles or sell data, and anyone can object.

**Where.** On a server in Essex, England, lent to us and run by us alone, with its
storage on a file server beside it. Further copies of the backups and the archive are
kept on our own machines in the United Kingdom, and erasures are applied to them at the
same time as to the live data. Visitors reach the site through Cloudflare, which
carries the traffic and caches public pages, so it sees IP addresses. Mail to privacy@meio.lol passes through Cloudflare's
email routing, which keeps a copy, and reaches a Gmail inbox.

**How long.**
- Raw match records from Riot (which contain Riot IDs): on our server until archived,
  usually a few days
- Archive of raw match records, without Riot IDs and with player identifiers replaced
  by one-way codes: the codes are removed 24 months after we collected the game; the
  matches stay, linked to no one
- Compact match and timeline data used for the statistics: the player identifier
  (PUUID) is removed 24 months after the game; the anonymous match stays for the
  statistics
- Rank history per player: 24 months after the player's most recent rank
- Rank and champion mastery per player: refreshed at least every 30 days; removed when
  no ranked ladder or collected game has shown the player for 30 days
- We refresh stored players at least every 30 days and delete any account Riot reports
  as not found

## Daily Draft

Daily Draft puzzles are real ranked games shown without names, Riot IDs, player
identifiers, match ids or game dates: at most champions, bans, patch, game length,
and each player's rank and game statistics (kills, gold and the like); the date
shown is the puzzle's, not the game's.

The Daily Draft keeps your guesses, streak and archive in your own browser (local
storage), and clearing site data removes them. When you finish a puzzle, its two answers
(which champion, which side) are sent once with nothing that identifies you; we keep
only each puzzle's totals, to show what share of players picked each answer, and these
requests are not in our server logs.

## Your games

When you enter a Riot ID, we ask the Riot Games API for that player's recent Summoner's
Rift games and show their own lane against the typical curve for each matchup. Anyone can
look up any Riot ID, as on other League statistics sites (legal basis: legitimate
interests). The page shows that player's finished games, and lists the ten players in
each with their champion, kills, deaths and assists and their Riot ID as at that game, as
the League client's match history and other statistics sites do. Friends lists the
players on the same team in three or more of those games, with the player's record with
and without each. Riot's streamer mode
hides names only during a game, and we show no live games.

For each player looked up we store the Riot ID, Riot's encrypted player identifier,
server, visible rank, and the games we fetched: champions, positions, results,
per-minute statistics and each player's Riot ID as at that game; the other players'
identifiers are kept only as one-way hashes. A player nobody has looked up for 30 days
is deleted, with games no remaining player is in. We don't record who looked up whom,
and lookups are not in our server logs.

Your games remembers the last five Riot IDs you looked up, and the newest game it saw for
each, in your own browser (local storage) to offer them again and count new games, and
the last player's games as last shown, to open them straight away when you come back;
they are never sent to us. "Not you?" by the player's name stops that; "Forget on this
device" under the lookup, or clearing site data, removes them all. Pages also keep view
settings there (filters, sort orders, tabs).

To remove your games and stop us collecting them again, use "Remove a Riot ID" on the
Your games page (the profile icon check below); we delete everything about you, your
Riot ID in other players' games included, and keep only your encrypted identifier on a
"do not collect" list, so we never store your name again.

## Squads *(when live)*

A squad is a group of players who have each joined themselves. To join you prove you own
your Riot ID by setting a given profile icon in the League client for a few minutes; we
read your icon once to check and don't keep it. For a squad we store: the squad name,
each member's Riot ID and PUUID, and the games members played together. Legal basis:
consent. You can leave a squad at any time, which removes you from it immediately;
a squad with no members is deleted.

## The desktop app *(when released)*

The app reads champ select from the League client on your own PC, read-only, and during
and after a game the game's own live data and end of game totals, and shows lane
information on screen. It does not send your games or any other personal data
anywhere. Apart from the League client it connects only to this site, every few hours, to
download newer champion statistics and updates to itself; those requests carry nothing
about you except, while the app is for invited testers, its sign-in: a token of its own
from the account's login, stored by us only as a one-way hash with when it was made and
last used, ended on the account page, by logging out everywhere, a new password or 90
days unused. The server logs them like any page visit (below).

## Server logs

Our web server records each request to meio.lol without the IP address: time, page,
status, referring page and browser type. Failed requests are recorded with the IP
address. We use these only for
security, fixing problems and counting visits, and delete them after 14 days; hourly
totals of visits by page and browser type, which identify no one, are kept 90 days.

## Your rights

You can ask us to:
- **Object** to our use of your data, and have it **erased**: email us, or use "Remove a
  Riot ID" on the [Your games](your.html) page, which checks you own the Riot ID and
  removes you within minutes
- **Access** the data we hold about you
- Have it in a **machine-readable** form
- **Correct** it, though match data comes from Riot as it happened
- **Restrict** our use of it while a request is considered

Email privacy@meio.lol for anything the form doesn't cover. We'll ask you to prove you
own the Riot ID (the same profile icon check) and reply within one month. You can
complain to us at the same address, and to the UK Information Commission (ico.org.uk;
the Information Commissioner's Office until 30 Sep 2026) or, in the EU, to your local
data protection authority.

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
