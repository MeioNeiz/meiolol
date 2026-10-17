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
