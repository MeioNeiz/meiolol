---
status: decided
decision: docs/plan/app.md#window-layout
priority: soon
area: ui
tags: [ux/desktop, ux/layout, ux/features, ux/colour, tools/phase]
description: How do League desktop companions lay out champ select, loading screen, in-game and post-game windows, and what makes them readable at a glance?
---
# How do League desktop companions lay out champ select, loading screen, in-game and post-game windows, and what makes them readable at a glance?

Feeds: the desktop app GUI (dvui) per phase, docs/plan/app.md. Extends [[league-apps-feature-matrix]] (which features), here only how windows are laid out.

## Answer

Two board shapes cover almost everything. Champ select is three columns: ally team left,
enemy team right, recommendations in the wider middle (DraftGap 1 : 4 : 1, OP.GG,
LoLDraftAI) (C6). Scouting is a grid of ten equal cards, one row of five per team, ally
first, in Porofessor's loading screen and in-game overlay alike (C1). The comparison phases
(Mobalytics and iTero in game, Mobalytics post game, U.GG champ select) use mirrored lane
rows instead: ally left, enemy right, role icon in a centre column, so each row is one lane
(C7). Every card keeps a fixed order from identity down to tags, so the eye finds the same
thing in the same place on all ten (C2).

Porofessor reads at a glance because of its tags: short outlined pills coloured by meaning
(green strength, orange caution, red weakness, blue pro) at the foot of each card, with the
reason and number on hover (C3). Reviewers rate its scouting "not even close" to the others
(C4). Blitz and Mobalytics use grey chips and colour only the numbers; iTero uses dot meters
(C5). Numbers are coloured on fixed thresholds (DraftGap's six-step scale, blue good and red
bad picks in OP.GG, green and red deltas in game) (C9). DraftGap flags any rate from under
1,000 games inline (C10). Recommendations come as a sorted list with one score column, a
scored icon grid grouped by reason, or 3 to 5 cards with a factor breakdown and a sentence
each (C8).

In game, the panels are small, toggled by hotkey and placed at screen edges. Players like
the subtle ones and want them easy to close; opacity, scale and second-monitor options are
standard (C11). Post game puts charts on top (gold difference as a blue and red area), a
player picker, then tabs. The gold graph is loved and dense advanced tables are not (C12).
Shells use a left rail or top tabs, sometimes a phase stepper (C13). DraftGap's window opens
at 1600 x 850; Porofessor's champ select window is a wide separate window; Facecheck is a
narrow tall panel (C14). Below 1024 px DraftGap shows one column with ally, draft and
opponent tabs in a footer, and players check loading-screen scouting on a phone (C15).
Complaints are about frame drops, ads over content, clutter and silent auto-import, not
density as such (C16).

Searches: the Porofessor tag list and the window sizes of Porofessor and Mobalytics turned
up nothing after three searches (live pages are behind Cloudflare), so the tag set comes
from screenshots.

## Claims

- C1: Porofessor's scouting is ten equal cards in two rows of five, ally row over enemy row with a blue or red rule, and the same grid is used on the loading screen and in the in-game overlay (beside a build column). for: [[porofessor-download#^f12]], [[overwolf-porofessor#^f9]], [[overwolf-porofessor#^f11]]
- C2: Player cards keep one fixed order: identity, champion record (KDA, win rate, games), rank, recent form, then tags; Blitz and U.GG cards follow the same order. for: [[porofessor-download#^f12]], [[blitz-lol#^f8]], [[ugg-app#^f6]], [[overwolf-itero#^f12]]
- C3: Porofessor's tags are short outlined pills coloured by meaning (green good, orange watch out, red weakness, blue pro), one to six per card, with hover tooltips giving the reason and number; team comp tags use the same pills. for: [[porofessor-download#^f13]], [[porofessor-download#^f14]], [[overwolf-porofessor#^f10]], [[porofessor-download#^f19]], [[porofessor-download#^f15]]
- C4: Players credit tags and scouting as Porofessor's winning feature. for: [[fdg-porofessor-vs-blitz#^f1]], [[reddit-porofessor-vs-mobalytics#^f6]], [[reddit-porofessor-desktop-launch#^f1]]
- C5: Blitz and Mobalytics use neutral grey tag chips (colour only on numbers, "+2" overflow); iTero rates attributes with ten-dot meters. for: [[blitz-lol#^f9]], [[blitz-lol#^f8]], [[overwolf-mobalytics-desktop#^f14]], [[overwolf-itero#^f12]]
- C6: Champ select boards are three columns, ally left, enemy right, recommendations in a wider centre. for: [[draftgap#^f20]], [[draftgap-site#^f5]], [[overwolf-opgg#^f9]], [[loldraftai-draft#^f6]]
- C7: Lane comparison uses mirrored rows (ally left, enemy right, role icons in a centre column) in champ select, in game and post game. for: [[overwolf-mobalytics-desktop#^f13]], [[overwolf-mobalytics-desktop#^f15]], [[overwolf-mobalytics-desktop#^f16]], [[overwolf-itero#^f13]], [[ugg-app#^f5]]
- C8: Recommendations are one of: a sorted list with a single score column, two lists (good / bad picks), a scored icon grid grouped by reason, or 3 to 5 cards with score, factor table and one-sentence reasons. for: [[draftgap#^f25]], [[overwolf-opgg#^f9]], [[overwolf-facecheck#^f10]], [[overwolf-itero#^f11]], [[blitz-lol#^f11]]
- C9: Numbers are coloured on fixed thresholds: DraftGap six steps from red under 45% to orange over 55%, OP.GG blue good and red bad, green up and red down deltas in game. for: [[draftgap#^f26]], [[overwolf-opgg#^f9]], [[porofessor-download#^f17]], [[overwolf-opgg#^f13]], [[blitz-lol#^f13]]
- C10: Thin data is flagged inline: DraftGap puts a warning triangle with the sample size on any rate from under 1,000 games. for: [[draftgap#^f27]]
- C11: In-game panels are small, hotkey toggled, at screen edges, with opacity, scale and second-monitor options; players praise subtle panels and worry about closing them. for: [[porofessor-download#^f17]], [[overwolf-opgg#^f13]], [[fdg-porofessor-vs-blitz#^f4]], [[reddit-porofessor-vs-mobalytics#^f3]], [[reddit-porofessor-vs-mobalytics#^f8]], [[mobalytics-live-companion#^f12]], [[reddit-porofessor-desktop-launch#^f4]], [[reddit-porofessor-v2#^f2]], [[overwolf-facecheck#^f12]]
- C12: Post game leads with charts (gold difference area blue over red, damage bars by player), then a player picker and tabs; award cards and a one-sentence verdict are the at-a-glance layer; players love the gold graph and reject dense tables. for: [[porofessor-download#^f18]], [[overwolf-mobalytics-desktop#^f16]], [[blitz-lol#^f12]], [[ugg-app#^f8]], [[fdg-blitz-review#^f5]], [[fdg-blitz-review#^f6]], [[fdg-blitz-review#^f2]], [[fdg-porofessor-vs-blitz#^f3]], [[reddit-porofessor-vs-mobalytics#^f9]]
- C13: Shells: a left icon rail or top tabs, a phase stepper (iTero, Mobalytics), and Mobalytics docks a cheat sheet column beside every phase. for: [[overwolf-mobalytics-desktop#^f11]], [[overwolf-opgg#^f10]], [[overwolf-itero#^f10]], [[overwolf-porofessor#^f13]], [[fdg-blitz-review#^f1]]
- C14: Window sizes: DraftGap 1600 x 850 resizable; Porofessor's champ select window is a separate wide window (about 1.8 : 1) beside the client; Facecheck is a narrow tall panel. for: [[draftgap#^f19]], [[overwolf-porofessor#^f8]], [[overwolf-facecheck#^f10]]
- C15: Narrow views: DraftGap under 1024 px shows one column and switches ally, draft and opponent from footer tabs; players use a phone or second screen for scouting. for: [[draftgap#^f21]], [[reddit-porofessor-v2#^f5]], [[mobalytics-live-companion#^f14]]
- C16: UI complaints are frame drops, ads over content, clutter of extra windows and silent auto-import. for: [[fdg-porofessor-vs-blitz#^f5]], [[reddit-porofessor-vs-mobalytics#^f10]], [[reddit-porofessor-vs-mobalytics#^f11]], [[fdg-blitz-review#^f7]], [[fdg-porofessor-vs-blitz#^f9]], [[reddit-porofessor-v2#^f4]]
- C17 (inferred): Champ select board for meiolol: three columns, our five slots left, theirs right, 3 to 5 suggestion rows centre with one coloured score, a reason pill or two, and a thin-data mark; no other players' stats in ranked solo/duo champ select ([[riot-champ-select-anon-apps-1222#^f4]]). from: C6, C8, C9, C10
- C18 (inferred): Loading screen: Porofessor's 2 x 5 card grid with fixed card order and coloured meaning pills, hover for the reason. from: C1, C2, C3, C4
- C19 (inferred): In game: one small edge panel on a hotkey, mirrored lane rows with deltas, closable, opacity setting. from: C7, C11
- C20 (inferred): Post game: verdict line and award chips first, gold difference chart, then mirrored lane rows; detail behind tabs. from: C12, C7
- C21 (inferred): At about 440 px, one column with a team / picks / enemy switcher, cards as one row each. from: C15, C1

## Layout patterns to borrow

All inferred (C17 to C21). The main window is about 1100 x 700, with a 40 px top bar (phase
stepper: Lobby, Champ select, Loading, In game, Post game, plus settings).

- Champ select (C17): columns 240 / 620 / 240. Team columns show five slots (role icon,
  champion splash strip, name, locked or hover state greyed), with the team's draft score
  in big type on top. The centre shows "For you, mid": 3 to 5 rows of icon, name, one
  score coloured on fixed steps, two reason pills (counter, synergy, comfort) and a
  thin-data mark. Under the rows sit a short "why" sentence for the selected row and the
  damage split bar for both teams. Bans go in a strip under each team column.
- Loading screen (C18): 2 x 5 cards at about 210 x 300, a blue rule on our row and red on
  theirs. Each card, top down: champion icon and name, champion record (games, win %),
  rank, recent form ring, then up to four pills (green, orange, red, blue) and "+n". Hover
  shows the reason with its number. Team comp pills go in a footer band.
- In game (C19): an optional overlay or second-window panel about 360 x 300. It shows five
  mirrored lane rows (our icon, gold delta chip, their icon), a team gold bar, and a CS/min
  line against the tier. It is hidden by default, toggled by hotkey, and has an opacity
  setting.
- Post game (C20): a verdict sentence and 3 to 5 award chips on top, then the gold
  difference area chart (blue over red). Below are ten mirrored lane rows (KDA, CS, KP,
  items) and tabs for Fighting, Farming, Vision. Our draft call against the result is a
  short line.
- Narrow, about 440 px (C21): one column with a three-way switcher (Us / Picks / Them) in
  champ select, defaulting to Picks. On the loading screen, the ten cards become ten
  compact rows (icon, name, rank, two pills) under team headers. The in-game panel already
  fits, and the post game stacks verdict, chart and rows.

## Disagreements

Grey chips or coloured pills: one reviewer prefers Mobalytics' tags ([[reddit-porofessor-vs-mobalytics#^f7]], C/strong) while others single out Porofessor's "big bold" tags ([[fdg-porofessor-vs-blitz#^f1]], C/fair). Colour by meaning fits Jacob's preference and our colour rules; testing both on a real loading screen would settle it. On win % wording, DraftGap shows raw win rates as the score. That conflicts with meiolol's cautious rule against "+X%" ([[league-apps-feature-matrix]] Disagreements).

## Open

- Porofessor and Mobalytics window sizes in pixels (Overwolf manifests not public); the full
  Porofessor tag list and thresholds (live pages Cloudflare-walled)
- How tags read for colour-blind players (green and red pills); pair colour with words or icons
- Users' views on density in 2025 to 2026 apps (most reviews here are 2019 to 2022)
- Riot's view of loading-screen tags that judge players ("Vulnerable Laner") for the public app
