# Plan: the production review

Goal: when Riot opens meio.lol for the queued application (docs/production-key.md), it is
up and shows what the application says, with nothing a reviewer reads as against the
rules. Riot may look from about April 2027 (late-2026 reports: 6-12 months) and checks a
working site with its user flow, ToS and privacy policy (research/questions/
prodkey-review-2026.md). Last reviewer walk of the live site: 13 Nov 2026, 27 page types,
232 links all 200 (data/team/2026-11-13-max/prodkey.md).

## Steps

- PR1 Up when Riot looks: a site down at review got an app rejected after 8 months, its
  re-review still waiting 8 months on (prodkey-review-2026 C5); C01 is one borrowed VM.
  Phone alerts (decisions.md "Open decisions", ntfy topic) plus a probe of / and
  /riot.txt from the gpu-box. Done when a stopped nginx on C01 reaches Jacob's phone
  within 10 min. Blocked on Jacob
- PR2 The app on /download: no screenshot or video of the desktop app anywhere and the
  exe is behind a login, so a reviewer sees no champ select screen (Riot: video or
  screenshots show the user flow). Now the public edition's shots
  (docs/review-shots/mock-*.png, windows-desktop-window.png, marked as previews) on
  /download; after APP1 (app.md) the real card at pick and after locks, and a 60-90 s
  video. Done when /download shows both states. Start: src/site/textpages.zig (download)
- PR3 Preview wording (Jacob's call): every page says "not yet open to the public"
  while sign-up, Your games lookups and "Apply to test" (home card, /download form) are
  open; Riot's registration popup forbids a personal-key project "accessible by the
  community". Proposal: banner "A prototype for Riot's production key review; not
  advertised", no "Apply to test" on the home page, /download's form headed "closed
  test, by invitation". Done when banner, home and /download agree. Start: ui/site.zig
  (banner), ui/homepage.zig, ui/apply.zig
- PR4 /method leads with game review: its opener describes lane curves only, "win
  chance" never appears, and its one model section is draft AUC, though the application
  draft points reviewers there for the win chance model. Add what the win chance model
  is trained on (ranked match and timeline data, ranks, regions), what it shows (turning
  minute, death cost) and that it is never in champ select; the same training line on
  /privacy (Product rules: state ML training); estimates.md E9. Done when /method's
  first screen says game review and both pages name the training data
- PR5 Terms current: 6 lines, updated 12 Oct; add a line each on accounts, Squads,
  testers' applications, the two app editions and preview (src/site/textpages.zig,
  docs/legal/)
- PR6 Small fixes: one name for the removal control ("Remove my data" in ui/forget.zig,
  "Remove a Riot ID" on /privacy and in the draft); a visible line under "Review your
  games" saying what meiolol is (today only the meta description); a Contact link in the
  footer; http://meio.lol answers 200 instead of 301 to https and HSTS is a day (C01
  nginx); icons 16.20.1 on / and /your, /squad hotlinks ddragon 16.21.1 instead of /dd/

## Status

Verified on 13 Nov: no Riot marks in domain or logo; riot.txt 200 for Riot's checker's
user agent; the boilerplate in every footer and in /terms; noindex everywhere; no "best
pick", "solve" or "Riot approved" wording; no Riot IDs in Daily Draft or examples; every
feature the application names reachable. The application draft's scope (EUW, ~210,000
games) no longer matches the site (every region): production-key.md "Check" list.

## Later

- Before pasting the revised application (after Riot's reply): walk the site again
  against it, numbers from /method on the day
