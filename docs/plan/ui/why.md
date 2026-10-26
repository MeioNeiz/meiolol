# Public "why": the reasons behind a pick (design note, no build)

Where it shows: the public desktop app in champ select (CandidateList, ReasonBreakdown);
the same reasons, with points, in Daily Draft's seat panel and the draft tester.
Binding: docs/production-key.md product rules (3 to 5 options with reasons, no "best
pick", no "+X% win rate", no other players' names or stats in ranked solo/duo champ
select). Jacob (README answers 6): reasons, few words, displayed well; no tiers.

Unfinished (run wrapped up 26 Oct 10:00): the contrast rule below is checked only on
three live Daily puzzles' shown rows, not on a role's full field; the pool and damage
reasons are worded but their data isn't in the app yet.

## Reasons that exist

What the model and data can honestly say (docs/learned.md "Win"). The shipped model is
additive v2 with borrowed pair cells: a pick's score is its strength in the role plus one
term per ally and per enemy (src/core/score.zig Reason: base, ally, enemy).

| Reason | Term | Public words | Shown when |
| --- | --- | --- | --- |
| Lane matchup | enemy, same role | Good into X / Hard into X | always a candidate: 1-2.5 points between typical lane matchups |
| Cross-lane | enemy, other role | Good into X / Hard into X | only support vs enemy bot and mid vs enemy bot (0.8-1.1); other cross pairs fold into the rest |
| Bot duo | ally | Works with X / Awkward with X | only bot with support (1.3-1.6); no other ally pairing shows in the data |
| Strength | base | Strong this patch / Weak this patch | its role's average is the reference |
| Your pool (app only) | own mastery, own games | You play it / Your main | the player's own data, allowed publicly |
| Damage mix | comp (not shipped) | Adds magic damage | own team under a fifth magic; waits for damage profiles in the stats file |

Never a reason: early or late champion, carry, comeback, runes or spells, gold leads,
win chance, kit groups ("like other armour tanks": unconfirmed, admin tester only), and
any pair learned.md says is not detected (jungle with support, CC with jungle).

## The contrast rule

Found in the live Daily puzzles: on 25 Oct every support candidate had "into Ezreal" at
+1.5 to +1.9, on 26 Oct "into Jinx" at +1.2 to +1.9. A reason on every row tells the
player nothing about which to pick, and today's chips show it on every row.

Each term's points are measured against leaving the term out, not against the other
options. The pair cells carry what supports in general do into that ADC; the research
calls this the value function of a decomposition (research/questions/
frontier-interactions.md C2, C12: an absent seat is the role's pick-rate-weighted
average).

Rule: a reason's size is this pick's term minus the role's pick-weighted average for the
same slot ("why this one rather than a typical support"). core.recommend already scores
every champion in the role, so the average costs one more pass. Strength is already
relative to the role. Daily, the tester and the private app compute the same centred
terms; their waterfalls keep the role's average as the start, so their totals don't
change. Centring on the shown rows (a stand-in for the role average) turns the
26 Oct "into Jinx" from +1.2..+1.9 into -0.4..+0.3: no reason left on any row.

Reasons every shown option shares (all strong, all into Jinx) collapse into one line
above the list, the seat's context: "Supports do well into Jinx". Rows carry only what
sets them apart.

## Ranking and gates

- Per row, centred terms by size; shown when 0.5 points or more and, for pairs, 100+
  games (shrunk values, so thin pairs are small anyway; the floor keeps a 30-game Annie
  pair out of a public claim)
- Public: at most 2 reasons a row, at most 1 against ("Hard into Lux"); a row with a
  cost is honest and helps diversity. Private and Daily: up to 3 chips, points shown
- Choosing the 3-5 public options: the model's order, but every option needs at least
  one reason over the gate (strength or pool counts); a pool champion within reach of
  the top is preferred over a sixth unfamiliar one
- Order: the model's, unnumbered, no star, no win chance, no tier headings

## Words and look

- A reason is a chip: the other champion's square icon, then 1-3 words, direction by
  word (Good / Hard), colour (hi / lo tokens) and ▲▼ glyph, so colour is never alone.
  Strength and pool chips use the role icon and the player's own mark
- Budget: 2 chips x 3 words, 5 rows: about 30 words for the list, plus the context line
  (about 5)
- Wording follows the product rules: no "best", "counter pick", "solve" or percentages;
  "Good into" not "counters"
- ReasonBreakdown public mode (a row opened): each reason on its own line, a plain bar
  whose length is the centred size (no axis, no numbers, no total), "few games" beside a
  thin one. The waterfall with points stays for Daily, the tester and the private app

### Components (owner cc)

- `reasons.Mode` and CandidateList's `Mode`: `tiers` becomes `words` (rows as above,
  no group headings); `Tier` goes
- CandidateList gets a context line slot above its rows
- `core.Reason` grows the centred size beside `pp`; chips read the centred size, the
  waterfall reads `pp`

## Worked examples (live Daily puzzles, shown rows as the reference)

Puzzle 14, 24 Oct: red bot, played Twitch, into Caitlyn and Lux, with Lulu.

| Option | Centred terms | Public chips |
| --- | --- | --- |
| Xerath | strength +1.2, into Lux +0.7 | Strong this patch, ▲ Good into Lux |
| Vel'Koz | strength +1.4, into Lux +0.6 | Strong this patch, ▲ Good into Lux |
| Twitch | strength +1.0, with Lulu +0.3, into Lux -0.5 | Strong this patch, ▼ Hard into Lux |
| Sivir | strength +1.1, into Lux -1.9 | Strong this patch, ▼ Hard into Lux |

Context line: none (no shared reason). Reads: mages bot do well into Lux, ADCs don't.

Puzzle 15, 25 Oct: blue support, played Braum, into Ezreal and Thresh, with Aphelios.

| Option | Centred terms | Public chips |
| --- | --- | --- |
| Blitzcrank | strength +2.4, with Aphelios +0.4 | (strength only; Aphelios under the gate) |
| Braum | strength +2.6 | |
| Sona | strength +2.6 | |
| Soraka | strength +2.2 | |
| Leona | strength +2.2 | |

Context line: "Strong this patch; supports do well into Ezreal". Rows have nothing
apart: in the app the pool reason is what tells them apart; Daily says "on paper,
close" already.

Puzzle 16, 26 Oct: red support, played Swain, into Jinx and Lulu, with Ezreal.

| Option | Centred terms | Public chips |
| --- | --- | --- |
| Fiddlesticks | strength +2.5 | Strong this patch |
| Braum | strength +2.6, into Jinx -0.4 | Strong this patch |
| Annie | strength +1.3 | Strong this patch |
| Swain | strength -0.6 | ▼ Weak this patch |

Context line: "Supports do well into Jinx". Today's chips would show "into Jinx ▲" on
all nine rows.

## Questions for Jacob

1. Public breakdown: plain bars with no numbers and no axis (lean), or words only?
2. Reasons against in the public list ("Hard into Lux", at most one a row): yes (lean)?
3. Option order in the public list: the model's, unnumbered (lean), or ordered by
   something neutral (your pool first, then the model)?
