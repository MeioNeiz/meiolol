# App: pictures over words (APP14)

Jacob's notes 94, 95, 101, 102, 107 (docs/review/app-review-2026-11-03.md). Plan 3 Nov
2026, team run 2026-11-03-app. Rules: docs/plan/app.md "Policy line"; product rules
in docs/production-key.md (public: no "+X%", words or signs instead of win numbers).

## What Jacob sees

- First start (94, 95): the note screens before data (sign in, downloading, failed, no
  data) become one picture: the app mark with a slow pulse, a three step track (Sign in,
  Download, Open League) with the current step lit, and while downloading a real bar
  (bytes of the files this check fetches) with "12.4 / 38 MB". One short line at most;
  a failure turns the bar red with its reason and the retry minutes as small text
- Reason chips (101): a reason about a champion is that champion's icon plus a signed
  figure: private the pp ("+1.4"), public a green or red arrow (no number, policy).
  The words go to the chip's title. Mastery stays "120k" with a mastery mark; "strong
  in mid now" becomes the role icon plus the arrow (private pp)
- Board (102): a seat's fact is no sentence: public an arrow by the name (title "strong
  in top now"), private "53.0%" with the games faint. The lane panel's sentence and
  chart caption shrink to a figure: "-150 gold @14" big, coloured by lean, the band
  games in the title; option lane facts the same ("+210 @14")
- Icons (107): board seats 40 to 48 px, ideas and bans 20 to 32, options 40 to 48, ban
  options 32 to 40

## Components reused

Champ (icon sizes it already has), Chip (reason variant gains an icon child), Role,
Badge, DraftBoard's app variant, Bar (ui/bar.zig) for the download bar if it fits the
budget, else a plain div width. No new island: the changes are small; each slice checks
`deploy/zb.sh ui-app-size` (1408 B gz shared with APP13, 15, 16)

## Data

- Reasons: lanecard's reasons gain a structured mark beside the text (kind, champion,
  pp), the shell maps it to the chip; words kept for the title and the dvui window
- Download progress: update.zig counts bytes written into a shared atomic (done, total
  of the files this check fetches); the poller wakes the shell at most twice a second
  while it moves. state.Note.downloading carries it

## Slices

1. Bigger icons (107): sizes only
2. Reason chips as champion and number (101)
3. Fewer words on the board (102): seat facts, lane sentence and option facts as figures
4. First start as a picture (95): the note screens' track and pulse, no backend change
5. Download bar (94): progress from update.zig through the poller to the bar
