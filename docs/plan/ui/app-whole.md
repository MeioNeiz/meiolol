# App: a whole app (APP13)

Jacob's notes 97, 104, 105, 108 (docs/review/app-review-2026-11-03.md). Plan 3 Nov
2026, team run 2026-11-03-app. Rules: docs/plan/app.md "Policy line".

## What Jacob sees

- The site's header on every app screen (ui/site.zig SiteHeader, same look, menu under
  860 px): logo, a first link for the live screen named for the phase ("Lobby", "Champ
  select", "In game"), then the site's own pages (Your games, Champions, Matchups, Daily
  Draft, Learn; the menu adds Patch changes, Rankings, Champion pool, Squads; private:
  Draft tester), Practice (private) and a settings button. Same in every phase
- Settings, a popover from the bar: count mastery, practice (private), sign in or the
  signed-in line, the update line, links (meio.lol, download, privacy, terms)
- A site link opens that page in the app window, the site as it is (its components and
  style, logged in as in a browser); the site's header there gains the live link first,
  back to the app. When champ select, the loading screen or a game starts, the window
  goes back to the live screen
- Champ select fits the window, no page scroll: our team's column, the centre, theirs
  (ui/app.zig grid). Each column heads with its team's draft win chance (private); seats
  are cards whose portrait ring is the state (hovered dashed, picking amber, locked the
  team's colour), no state words. The centre: your lane's head (you vs them, lane gold),
  a switch (Options | Lane | Comps, radios in the shell's static HTML, no island byte),
  then that view with its own scroll: Options the picks table (private: one list, pool
  rows marked; public: the lane panel's 5 and 5 more, two lists per product rules), Lane
  the gold chart, Comps the comp view once all ten lock. Full screen widens the centre;
  under 820 px one column, everything stacked
- Review pages: a third width, Full (the browser's width and height), and the window
  frame at its real 720 px height, scrolling inside, so what fits shows

## Components reused

SiteHeader (site.zig view, menu, its popover style for settings), Chip, Button, the
site's page CSS. No ui-app.wasm bytes: the bar and settings are static HTML before the
island, rebuilt with the page (the shell reloads it when they change, as the comp view);
the island loses its own header (saves bytes for APP14-16). Settings clicks go through
bridge.js (`data-shell` JSON on the element, as seat clicks' `lane`)

## Data

- Shell: the phase (from the poller's status), the edition, sign-in state, mastery and
  practice flags, the foot line: all there now
- Site base: https://meio.lol, MEIOLOL_SITE for the dev server (http://localhost:8080)
- Shell navigation: meio.lol pages stay in the window (other hosts open in the browser);
  messages from any origin but the app's are dropped; a phase change into champ select,
  loading or a game navigates back to the app page

## Slices

1. Done. Bar and settings: the header and settings popover as static HTML, island
   header out, page height and the review pages' Full width and real window height
2. Built, not yet tried in a real Windows window. Site in the window: shell navigation
   to meio.lol, bridge.js's live link on site pages, back to the app on a phase change,
   message origin check
3. Champ select three columns (meionotes 132-135); in game and lobby grids done;
   loading and post game fill the window at 1120 x 720 as they are
4. Done. Lobby home: what the live screen shows with no champ select, beside APP16's form
   panel: tiles into the site's features (draft tester, patch, pool) with a line of data
   each from the app's own files
