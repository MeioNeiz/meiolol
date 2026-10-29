# W4: desktop shell parity, then APP3 (team run 2026-10-29-next)

You are W4 in a team run; coordinator meiolol-4b. Read data/team/2026-10-29-next/common.md
first (rules, messages, commits from a clean worktree when the tree is red), then
CLAUDE.md "Git and deploys". Notes: data/team/2026-10-29-next/notes/w4.md (yours, keep
state there). Messages to meiolol-4b: "done: <sha> <line>", "blocked: <why>, <path>",
"question: <path>".

Goal: the webview shell (src/shell, docs/arch-app.md "Webview shell") replaces the dvui
window (src/desktop) as the released app. Everything Mac-checkable is done except:

1. Comp view after picks (docs/plan/app.md APP6) is in the dvui app (src/comp.zig,
   src/desktop/comp.zig) but not in the shell: once all ten are locked, each team's
   damage split bar and mix ("teams this one-sided win less often" when Learn's tally is
   2 SE under even), champions with a clear early or late lean, five mirrored lane rows.
   Build it as a ui component (src/site/ui/, gallery entry, both editions' words: the
   public edition shows words, no win chances, docs/production-key.md) and feed it from
   src/shell/screens.zig. Check on the Mac against the mock client (deploy/mock-cs.sh;
   the shell's mac build `--dump DIR`, arch-app.md), screenshots before and after
2. Then APP3 (app.md): the lane panel switches to any ally's role on a seat click, then
   the blind-safe ranking (J2: options that hold up against the role's likely picks, not
   the average). Build it in the shell; shared logic in src/board.zig so dvui keeps
   working until cut-over. Measure any ranking change with `meiolol eval` first
   (docs/model.md) if it changes which picks are suggested

Not now (gpu-box off): install, exe name, self-update, release script, real-window checks.
Files: src/shell/, new ui component files, src/board.zig and src/comp.zig (shared logic),
docs/plan/app.md APP3/APP6, docs/arch-app.md. Not yours: src/site/ui/site.zig, html.zig,
style.css (W1), admin*/tester* (W2), champion files (W3), Learn files (W5).
Hand over at 25-33% context with `cc-handover --new` once a step is committed.

## Change (29 Oct 14:4x, Jacob): review pages after APP3 (Jacob 14:5x: carry on with APP3 first)

Jacob: he hasn't reviewed the desktop app yet, the existing app was poor and not in line
with what he asked (app.md "Jacob's list by edition"), so don't spend long on features.
He wants to review it on his Mac the way he reviews the site: in a browser with the
notes tool (docs/arch-site.md "Notes tool"). The shell is web now, so:

- App review pages, private (/p/, view_private): every screen the app can show, from
  the mock scenarios (testdata/lcu/scenarios) played offline through the poller and
  src/shell/screens.zig (as the mac build's --dump does): champ select at each stage
  and seat (bans, hovers, my pick, all ten locked with the comp view), loading, in
  game, post game, sign-in, practice. Both editions (public | private) as a switch. Each
  state its own URL so notes pin to it; the same ui-app island and CSS as the shell, at
  a window-sized frame (the app's real width, plus narrow), a fake bridge where the page
  sends to the shell
- Works on the dev server (localhost:8080, notes into dev-notes.db) and on meio.lol/p/
  (live notes in api.db; sessions read /admin/notes)
- An index page listing the states with a one-line description each
- Keep it cheap: reuse the dump path and existing components; no new app features. Then
  stop and send "done:"; Jacob's notes decide what comes next (APP3 waits)
