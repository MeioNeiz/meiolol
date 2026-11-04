# App: other seats (APP17)

Jacob's notes 99, 100, 111, 112, 121 (docs/review/app-review-2026-11-03.md). Policy:
docs/plan/app.md "Policy line"; docs/production-key.md "Product rules".

## What Jacob sees

- Enemy seats' perspective (100): a click on an enemy seat shows that lane from their
  side in the lane panel, as an ally's does (APP3): their champion against ours, the
  chart in their gold, and while they still pick, what they could pick into us (the
  recommender for their role, from everyone who plays it). A badge says "Enemy"; "Your
  lane" goes back. Once they lock, the matchup only. The Options panel follows (private:
  20 rows of threats). Both editions: champion stats only, nobody's identity
- Ban ideas from hovers (99): ally hovers, intents and locks feed the ban options: a
  champion that beats an ally's champion in their lane, weighted by how often it is
  picked there, ranks up and shows the ally's champion it beats as a chip (icon and
  points private, icon and arrow public). Never an enemy hover (the client hides them)
- Move picks (111): an enemy's role guess is wrong: drag their seat onto another row
  and the two swap. Every guess, lane card, ban option and comp then follows the moved
  roles until champ select ends. Enemies only: allies' roles come from the client
  (assigned positions, and its position swaps update them)
- Bans to guess roles (112): an enemy's ban says something about their role (players ban
  their lane's threats). Before they pick, their empty seat shows the banned champion's
  icon; it breaks ties in the role guess only when the pick fits two roles about evenly.
  No data says how strong this is (match-v5 bans have a pick turn, not a cell), so it
  is a tie-break, never a label. Check in APP1's capture that enemy bans carry their
  cell in the real client and that the client shows bans by seat; private until then
- Players (100, 121): mains, recent picks, streaks and comments only where names are
  visible, private only (APP7). Blocked on APP1 (which queues show names) and a source
  (the client's match history per puuid); not in this run

## Components

Reused: draftboard seats and their `data-act` (bridge.js sends `lane N`), champselect's
lane panel, the reason chip (champselect.effect), the Options island. New: an "Enemy"
badge (the Lane's side instead of `mastery == null`), drag and drop in bridge.js (no
ui-app.wasm bytes: native HTML drag events on the seats, a `swap` message), the ban
option's chip.

## Data

- Enemy lane: board.enemyLane, the lane card's input from their side (their team as
  allies with the board's roles, mine as enemies, their seat's champion as `me`;
  lanecard.Input.ally semantics: no pool, mastery or rank). `state.lane_role` 5 to 9
  for enemy roles (0 to 4 allies, 255 mine)
- Counter bans: core stats' lane matchups (stats.enemy(role, role, ally, them)) and
  role pick rates, in wins per 10,000 games like core.banimpact, added to the
  candidate's own impact
- Moves: a role per enemy cell in state (cleared when champ select ends), set on their
  slots before board.build; inferRoles keeps given roles
- Ban per enemy cell: session.zig keeps the actor cell of each completed ban

## Slices

1. Enemy seats' lanes (100): poller, board, screens, badge, review pages, done
2. Counter bans from ally hovers (99), done
3. Move enemy picks (111), done
4. Bans as a role hint (112), done, private until APP1 checks it
