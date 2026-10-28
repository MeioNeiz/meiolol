# Rankings: a page per stat (site note 4)

Plan only. Jacob 27 Oct, on home: "For whole site, I want to have it like league of
graphs where there is just so many cool stat pages ... Like if there was a top aces thing
on a champion page like 1/x champions then i could click and see a page showing the full
ranking and they just had that for so many stats".

## Identity

Every figure we show about a champion has a place in a ranking of all champions (in its
role) by that figure, and the figure links there. The site gets wide (many small
pages, each one ranking), not deep.

## The pattern

- On any page that shows a champion's figure (champion page StatStrip, the charts in
  champion.md "More charts", the champions table's columns): the figure carries its
  place, "3rd of 58", as a link
- The ranking page: one stat, every champion in the role (All: each champion's main
  role), sorted by it, with the games behind each and a faded row under the Games
  floor (champions.md). The champion you came from is highlighted and scrolled to
- One component for every ranking page (StatRanking: DataTable with the stat as the
  answer column, plus win rate and games); a stat is a spec (label, unit, sort, which
  data, min games), not a page of its own
- An index of rankings (one card per stat, its top 3 as icons) from the champions
  section, and home's Champions card lists (Most played, Best win rate, Rising) link
  to their rankings

## Stats, data we have first (arch-stats.md)

| Stat | Source |
| --- | --- |
| Win, pick, ban rate, games | stats (champions table) |
| Change this patch | patchday |
| Gold, XP, CS lead at 14 against the average opponent | lane curves |
| Ahead at 14 and wins from ahead; comeback odds | curves |
| First blood, kills by phase (before 6, 6-14, after 14) | curves |
| Level 2, level 6, first item minute | curves |
| Early or late: team gold at 14, win from even at 20 | lean.tsv |
| Pick-up: win rate in first games against practised | learning.zig |
| Win rate by rank bracket, by game length | stats by rank, curves |
| Players' spread (middle half of own win rates) | spread |

New counting, later: multikills (aces, pentas), damage share, vision, side. Each is a
row in the stats pass, then a spec.

## Rules

- Product rules (docs/production-key.md) bind: champion figures only, never players'
  names or ladders of players
- Each figure with its games and how sure it is (the champions table's fading); a
  ranking never puts a thin row above a solid one
- URLs per the URL plan (docs/plan/urls.md); links through the page path helpers
  (root.championsPath, Site.champHref), never hand-written paths

## Build order

1. StatRanking component and the spec type; first three stats (lane gold at 14, first
   blood, pick-up), the ranking pages and the "Nth of M" links on the champion page
2. The rankings index and home's links into it
3. The rest of the table above; new counting after

## Questions for Jacob

1. Under All: each champion in its main role only, or every champion-role row?
2. Which five stats first?
