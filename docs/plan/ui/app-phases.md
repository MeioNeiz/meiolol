# App: every phase worth a look (APP16)

Jacob's notes 97, 98, 109, 113, 114, 115 (docs/review/app-review-2026-11-03.md). Plan 3
Nov 2026, team run 2026-11-03-app. Rules: docs/plan/app.md "Policy line".

## What Jacob sees

- Loading cards (113): two to four short pills per card, a few of them playful, all
  from data: "lane bully", "6 first", "scales", "ban magnet", "hipster pick", "lone AP".
  No champion name inside a pill (the card across shows it); no sentence pills
- Comps (109): tips under each team in the comp view, a line each: "All AD: armour
  stacks well", "Late team: get to 30 min", "Lone AP: Ahri"; team pills on the loading
  screen short ("AD heavy", "late team")
- Lobby and queue (97, 98): your recent form (last 20 games as a win/loss strip, KDA,
  win rate) and the champions you play well lately (games, wins, KDA), then your
  mastery top. Your own games only (no other player): public and private alike
- In game (114, 115; private first): your champion's usual build (core items as icons,
  ticked when owned), skill max order and the next level's skill, a tip or two; power
  spikes (level 6 and first item against your lane opponent) only in a sheet the player
  opens, never pushed

## Components

- Reused: LoadScreen pills, CompView, Champ, ResultStrip or Spark for form, ItemPath,
  SkillGrid, KDA, Badge
- ui-app.wasm has no room: the lobby panel and the in-game build sheet render as static
  HTML under the island (the CompView way: the shell reloads the page when it changes),
  the sheet a <details> the player opens. Pills and tips are data, no wasm

## Data

- Comments: stats (role games and win rate, pick share), champ-facts (magic share,
  leans, ban rates), lane curves (gold edge, level 6 and first item timings)
- Lobby: LCU match history of the current summoner
  (/lol-match-history/v1/products/lol/current-summoner/matches), mastery (read
  already); the mock serves a match list
- In game: a small app builds file (per champion and role: top core items, skill max
  order), cut from the box's builds export, in the desktop manifest beside champ-facts

## Slices

1. Comments: loading card and team pills shorter and playful, comp tips
2. Lobby and queue panel from match history (lcu, mock, poller, shell)
3. In game build and levelling (app builds file, then the panel and the sheet)
4. Tips and the power spike sheet
