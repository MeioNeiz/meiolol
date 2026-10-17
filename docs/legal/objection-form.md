# Objection and removal form (draft: copy and flow)

Not legal advice. A self-service page at /remove that lets any player prove they own a
Riot ID and opt out, with no account and no email. Based on research/questions/
identity-and-privacy.md: icon check prior art (C6: lolsite, Moon Poro), Counterwatch's
objection model (C12), ICO on objections (C9).

## Decisions for Jacob

- Needs the dynamic service (the site is static today); until then the privacy policy
  points to email only. Change the "use the removal form" line in privacy.md to "email
  us" until the form is live
- Whether to also offer "send me a copy of my data" in the form, or by email only
  (proposed: email only for v1; access requests are rare)

## Flow

1. **Enter Riot ID.** Game name, tag and server (EUW, NA, KR...). The server resolves it
   with account-v1 (Riot ID to PUUID) and summoner-v4 (current profile icon)
   - Not found: say so; nothing is stored
2. **Challenge.** Pick a random icon from the free starter icons (ids 0 to 28, which
   every account owns), never the current one, with a secure random generator. Store a
   pending challenge (PUUID, platform, icon, expiry) for 15 minutes, nothing else
   - Moon Poro uses the same 29-icon pool; lolsite's 5 icons let a guess pass 1 in 4
3. **Player sets the icon** in the League client, then presses "Check"
4. **Check.** Re-read summoner-v4 by PUUID, compare icon ids
   - Match: go to 5
   - No match: say so, allow another check; at most 5 checks per challenge, at most 3
     challenges per Riot ID per hour, per-IP rate limit. Riot's profile update can lag
     by a minute or two, so say that
5. **Act, at once,** in one transaction:
   Implemented on branch worktree-data-safety (de62e5b; docs/data-safety.md "Erasure"):
   - Add the PUUID to the `forgotten (puuid, forgotten_at)` table (plain PUUID, needed
     for rekey translation). The crawler skips forgotten players and stores their
     participant rows with a blank PUUID from then on
   - Delete the `players` and `mastery` rows; blank the PUUID in `participants` (match
     stats stay, unlinked)
   - Delete raw summaries and raw timelines of the player's games at once
   - Backups: every backup file on the box is scrubbed at once; the Mac mirror follows
     within a day of its next sync. A restore re-applies `forgotten`
   - Your games cache: delete. Squads: remove from every squad
   - Daily Draft puzzles hold no identity: nothing to do
   - Log the request as (date, hash of PUUID, "objection"), no Riot ID, as proof we acted
6. **Confirm** on screen, with a reference number; remind them they can change their
   icon back. No email needed

**Riot erasure lists** (Riot Channels, and accounts renamed `rtbf(...)` found in the
30-day refresh) run step 5 without the challenge.

**Gotcha: PUUIDs are per app.** When the production key arrives, every PUUID changes
(docs/architecture.md, rekey). Either Riot links the production app's encryption to the
personal app (already planned in the application), or `meiolol rekey` translates
`forgotten` too: old PUUID to Riot ID with the old key (account-v1 by-puuid), then
to the new PUUID with the new key (built 2026-10-12: src/rekey.zig, runbook in
docs/data-safety.md "Key switch").

**Fallback:** someone who can't change their icon (banned, lost account, Riot ID
changed) emails privacy@meio.lol with what they can show; handled by hand within one
month.

**Abuse:** removing someone requires control of their League account, so nobody can
opt out anyone else. The page reveals nothing about whether we hold data on a Riot ID
until the check passes.

---

## Page copy

### Remove my data

Stop meiolol using your League data, and delete what we hold about you.

meiolol builds champion statistics from ranked games collected through the Riot Games
API. Our public pages never show players, but our stored match data includes Riot's
encrypted identifier for every player in those games. *(when live)* Anyone can also look
up a Riot ID to see that player's games against the typical curves.

If you'd rather not be included, enter your Riot ID below. To prove it's yours, you'll
change your profile icon in the League client for a minute. No account or email needed.

**Riot ID** [game name] # [tag]   **Server** [EUW ▾]
[Continue]

### Step 2: prove it's you

Change your profile icon to this one, then press Check. It's a free starter icon every
account has. You can change it back straight afterwards.

[icon image]

In the League client: click your profile icon (top right), choose this icon, and save.

[Check]   This code expires in 15 minutes.

*Not matching yet:* "We still see your old icon. The change can take a minute or two to
reach Riot's servers; try Check again shortly."

### Done

You're removed. Reference: [REF]

- We've deleted your rank and champion mastery, removed your identifier from every
  match we hold, and deleted our raw copies of your games. The matches themselves stay
  in the statistics, with no link to you. Our backups are updated at the same time
- We won't collect your games again: your encrypted identifier stays on a "do not
  collect" list, and that's all we keep
- *(when live)* Your games can no longer be looked up on meiolol, and you've left any
  squads
- Statistics already published hold no identity and are unchanged

You can change your profile icon back now.

Changed your mind, or need something else (a copy of your data, a correction)? Email
privacy@meio.lol. More in our [privacy policy](privacy.html).

### Can't use this form?

If you can't change your icon (for example, your account is banned), email
privacy@meio.lol with your Riot ID and server, and anything that shows it's yours.
We'll reply within one month.
