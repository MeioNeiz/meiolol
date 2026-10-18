# Production key

Researched 2026-10-11. Full answer, 13 rated claims and ~50 quoted sources:
research/questions/riot-production-key.md (josearch store; check it before
re-researching anything here).

## Verdict

Uncertain, leaning approvable; the wait is the real cost.

- Precedent: iTero, LoLDraftAI (neural net on ranked match-v5, live client, updated for
  16.20), Mobalytics, Porofessor, Blitz, U.GG all ship pick suggestions publicly. No
  known case of Riot removing one
- Risk: docs/lol lists "Apps that dictate player decisions" as unapproved; docs/portal
  "products that solve our games". Several options with reasons is explicitly allowed
- Review 3-9 months (2026 reports); editing the application reportedly resets the queue.
  New production keys reportedly start near personal limits; increases are a later
  support ticket (criteria: good standing, community benefit, outgrown the limit)
- One product per key, and the key covers only the described use case. So the data
  hungry part (public stats site) must be part of meiolol's one application, not a
  separate app whose key feeds meiolol

## Application needs

- Working site on an owned domain (no Riot trademarks in it): what it does, screenshots
  or GIFs of champ select, demo video, download page, Privacy Policy, Terms of Service
- `riot.txt` at the site root with the string Riot gives; their checker uses the
  `python-requests/2.11.1` user agent, so the host must not block it
- Boilerplate, visible on site and in app: "meiolol isn't endorsed by Riot Games and
  doesn't reflect the views or opinions of Riot Games or anyone officially involved in
  producing or managing Riot Games properties. Riot Games, and all associated properties
  are trademarks or registered trademarks of Riot Games, Inc."
- Never claim "Riot approved"
- Desktop app and API go on the same application; list the LCU endpoints used
- RSO (Riot Sign On) not needed
- Personal key is not upgraded in place: separate application; ask Riot to link PUUID
  encryption to the personal app

## Product rules (bake into the app and site)

- Ranked Solo/Duo champ select: no other players' names or stats, ever ("Ally 1..5")
- Show 3 to 5 options with reasons, never a single forced pick; no auto pick/ban/lock,
  no dodge advice, no per-teammate judgements
- Avoid "best pick", "solve draft", "+X% win rate" wording; frame as highlighting key
  decisions and champion diversity
- State ML training on match data in the application; support deletion by PUUID
  (Riot sends GDPR deletion lists)
- Free tier if ever monetised
- Until the production key: nothing public on the personal key, "regardless of how
  long the approval process ... takes", open betas included; do not advertise the site.
  Hence the site's preview mode (noindex, banner); research C8

## Registration popup (seen 2026-10-11)

Registering any product first shows "General Policies" with I Agree / I Disagree. Its
"Please Don't" includes: "Utilize a Development or Interim API key to run a project
accessible by the community (Development and Interim API keys are to be used to create a
prototype that we can review before the project is made public)". Its "Please Do" list:
think outside the box; "Think of ways to connect players with their friends"; "Think of
ways for players to evaluate and improve their own gameplay"; use game art assets (not
logos). Gray areas: ask in the application as an App Note.

## Description angles

- "Helps players learn draft: highlights important pick decisions and offers several
  options with the reasons behind each (counters, synergy, comp needs, your pool)"
- "Uses only champion and aggregate statistics; never shows or analyses other players
  in champ select"
- "Increases champion diversity by surfacing viable picks beyond the meta"

## Application text (draft 2026-10-18)

Paste field by field; each paragraph below is one line, no wraps. Field names are a
guess at the form's (description, URL, app note): put the paragraphs where they fit.

**Product description**

meiolol is game review for League of Legends, the way chess.com reviews a chess game. A player types their own Riot ID and gets a review of their recent games (last 60 days; solo/duo, flex, draft and Swiftplay): their team's win chance at every minute, the turning minute (the one minute that moved it most, and what happened in it), what each of their deaths cost (who killed them, the gold the killer got, what the enemy took next, and the win chance it cost), their lane against the typical game in the same matchup at their rank (gold, level 6 and first item), and highlights across their recent games. All of this is after the game, about the player's own games. The win chance by minute is never shown in champ select.

The benchmark behind the review is lane curves: how each lane matchup usually goes minute by minute (gold, XP and cs), from ranked solo/duo games in EUW, Platinum IV and up for now. Champion pages show win rates, every lane opponent and these curves, with the number of games behind each figure and how sure it is; matchups with too few games are marked and greyed out. The win chance model is trained on match and timeline data from ranked games; how the numbers are made is on the site's method page.

Between games there is Daily Draft (one real ranked draft a day from a past game, with no player names; guess who won), Learn (five short lessons, then practice drafts) and Champion pool (pick your main, or up to three, and see which champions those players also play and which do well in your main's hard lanes, several options with the numbers behind each).

A desktop app for Windows is in development and not released. Once you have picked your champion in champ select, it shows how your lane matchup usually goes and your own record in it; where it suggests champions from your pool it lists several with their reasons, never one. It never picks, bans, locks or dodges, and never shows other players' names or statistics. It reads the League client read-only (GET requests only, nothing written) from these LCU endpoints: /lol-gameflow/v1/gameflow-phase (to know when champ select starts), /lol-champ-select/v1/session (the picks and bans), /lol-champ-select/v1/pickable-champion-ids and /lol-champions/v1/owned-champions-minimal (which champions you can play), /lol-champion-mastery/v1/local-player/champion-mastery and /lol-ranked/v1/current-ranked-stats (your own pool and rank). Nothing about your games leaves your computer.

Riot API use: account-v1 (Riot ID to PUUID, and the region), match-v5 with timelines, league-exp-v4 and league-v4 (rank), champion-mastery-v4, and summoner-v4 (profile icon, only to check that someone removing their data owns the Riot ID). I need many games to cover specific matchups and less played champions: a curve needs a few hundred games per matchup per rank tier per patch, so that's millions of matches with timelines each patch. Today the site is built on about 210,000 EUW games from the last 30 days, Platinum IV and up; with a production key I'd lower the floor to Gold, then Silver, and add regions. Each match is fetched once and stored by match ID.

Data kept: raw match records (which contain Riot IDs) stay on our server only until archived, usually a few days; the archive has Riot IDs removed and player identifiers replaced by one-way codes, and is deleted 24 months after the game. Player identifiers in stored matches are removed 24 months after the game. A Riot ID nobody has looked up for 30 days is deleted. Stored players are refreshed at least every 30 days and deleted when Riot reports them gone, and Riot's deletion lists are honoured. Anyone can remove their data with "Remove a Riot ID" on the Your games page (a profile icon check) or by mailing privacy@meio.lol. Data is stored in the UK. Privacy policy and terms are linked from every page.

**Product URL**

https://meio.lol

**App note**

Please link PUUID encryption to my personal app MEIOLOL (890240), so the PUUIDs stored under the personal key stay valid with the production key.

What changed from 11 Oct and what to check:

- Rewritten around game review of your own games (the site's headline), lane curves as
  the benchmark, Platinum IV+ scope, Pool, the desktop app with its six read-only LCU
  endpoints (src/lcu/session.zig, me.zig), data kept and for how long (privacy.md)
- Squads left out: not on the site, and "squads promised but not found" was the first
  mismatch reviewers flagged (A2). Once built, a support ticket or edit can add them
- Check: privacy.md's 24-month PUUID and archive deletion is "not built yet" (its notes);
  build it or soften that sentence before pasting. Deletion lists: `meiolol forget
  --list FILE` exists (docs/data-safety.md)
- Check: the download page doesn't yet say queues or before/after lock-in (A1); the app
  text matches it as is. Update both together after the real champ select run
- Check: the game count (about 210,000) against the home page on the day you paste

## Application text (draft 2026-10-11, Jacob's voice; application started same day)

Meiolol is a learning tool for League of Legends. It shows how lane matchups usually go
minute by minute. Showing gold, XP and cs curves per matchup and rank tier. Players can
look up their own games and compare their lane with the typical curve after a game, and
see how they do in each matchup over time.

There is also a daily draft puzzle made from anonymised past games, and friends can group
up to see recaps of the games they played together.

I use match-v5 (with timelines), league-exp-v4, champion-mastery-v4 and account-v1. The
site only shows champion and aggregate data, and a player's own games when they look
themselves up. It never shows other players' names or stats in champ select, never
auto-locks or dodges, and doesn't tell players what to pick.

I need a lot of games across regions to cover specific matchups and less played
champions. A curve needs a few hundred games per matchup per rank tier per patch, so
that's millions of matches with timelines each patch. Each match is only fetched once and
stored by match ID. Matchups without enough games are marked on the site.

Data is stored privately and deletion requests will be honoured.

The site is meio.lol.

App note: please link PUUID encryption to my personal app MEIOLOL (890240).
