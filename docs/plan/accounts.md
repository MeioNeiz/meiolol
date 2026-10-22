# Plan: accounts and tiers

Jacob 22 Oct (J21): proper logins. His own admin account; friends get accounts a tier
below admin, so they can't break anything but get the private app and a fuller site.
Two apps follow from it: docs/plan/app.md. Policy lines for the private tier: app.md
"Policy line".

## Roles

| Role | Gets | Never |
| --- | --- | --- |
| public (no login) | the site, the public app once released | anything below |
| friend | private site pages (/p/), private app download and updates, read-only admin views Jacob opens to them | actions, logs, accounts, settings, raw data |
| admin | everything: /admin/, actions, accounts, releases | |

- One capability table in code (e.g. src/auth/roles.zig: view_private, view_admin,
  run_actions, manage_accounts, download_private_app), every route checks a capability,
  never a role name. Adding a tier later is one row
- "Can't break stuff" = friends have no write route at all, not hidden buttons. The box's
  admin API keeps its own token check (hosting.md "Admin API"), which nginx only adds
  for admin sessions

## Design (recommended; AC0 confirms)

- Where: `meiolol api` on jomify (already the dynamic service, behind nginx), own file
  accounts.db beside api.db (backups, erasure and migrations stay separate from Riot
  data)
- Accounts: username, argon2id hash (std.crypto.pwhash.argon2; params sized for
  jomify's 400 MB cap, one hash at a time), role, created, last seen, optional linked
  PUUID. No email: invites go by chat, so nothing to mail and less personal data
- Invites: admin makes a one-use link (/join#TOKEN, 7 days); the friend picks a username
  and password. Admin can change roles, reset (new invite link) and disable
- Sessions: 32 random bytes in cookie `__Host-meiolol` (Secure, HttpOnly, SameSite=Lax),
  stored as SHA-256 with expiry (30 days, renewed on use). Sign out everywhere on the
  account page. Writes need header X-Meiolol-Action: 1, as the admin API does today
- Admin second factor: TOTP (std HMAC; works with any authenticator app); passkeys later
  if wanted
- Login limits in memory: per username and overall, slower after 5 fails. No IPs stored
  (traffic logs keep none either)
- nginx: `auth_request /_auth` on /admin/ (needs view_admin) and /p/ (needs
  view_private); /_auth answers 204 plus role, or 401, which becomes a redirect to
  /login?next=. Pages stay cached per URI (everyone with access sees the same page;
  "you" bits come from /auth/me in JS). The renderer serves /p/ only with a header
  nginx adds after auth, like X-Meiolol-Admin today; warm-up and the public cache never
  hold /p/ pages. noindex and robots.txt cover /p/
- Desktop: the app signs in once and gets a device token (named, revocable, listed on
  the account page), sent as `Authorization: Bearer`; nginx checks it with the same
  /_auth. Replaces the shared update.key (hosting.md "Desktop app files"), which is
  rotated out once every install has a device token
- Break-glass: `meiolol account add|role|invite|reset|disable|list` on jomify over ssh;
  the old basic auth stays on /admin/ for a week after AC2, then goes
- Privacy: friends are data subjects; the privacy page gets an accounts section before
  anyone outside Jacob has one (what is kept, deletion on request: `meiolol account
  delete` also drops the linked PUUID link)

## Steps

Each step ends tested and deployed; nginx and systemd changes on jomify need Jacob's OK
(how-we-work.md).

- AC0 Jacob decides: the policy framing (app.md "Policy line"), role names (friend?
  tester?), TOTP for admin yes or no, who gets the first friend accounts
- AC1 Accounts core in `meiolol api`: accounts.db schema and migration, argon2id,
  sessions, invites, /auth/login, /auth/logout, /auth/me, /auth/join, /_auth, the CLI.
  Tests: a route x role matrix (every route, every role, expected status), cookie flags,
  constant-time compares, invite reuse and expiry, lockout; fuzz the login body parser.
  Done when the matrix passes and `meiolol account` works against a scratch DB
- AC2 Admin login live: /login page (src/site, no framework), nginx auth_request on
  /admin/ with admin role, "Signed in as" in the admin header, sign out. Done when Jacob
  signs in with his own account and the basic auth is only the fallback
- AC3 Friend tier: /p/ space (first pages: app.md "Private site"), invites, account page
  (password, devices, sign out everywhere), admin Accounts tab (list, invite, role,
  disable). Done when a test friend account reaches /p/ and gets 403 on every /admin/
  route and action
- AC4 Desktop sign in: login screen in the app, device tokens, update gate by token,
  update.key retired. Done when a fresh install signs in, updates, and a revoked device
  stops updating within one check
- AC5 Private edition channel: /p/desktop/ serves the private exe and its data; the
  release script builds both editions (app.md "Two editions")
- AC6 Later: friends link their Riot ID (profile icon check, as Remove a Riot ID does);
  friends' groups become Squads (backlog.md "Your games and Squads") for the private
  tier first

## Not doing

- Riot Sign On: not needed for the key (production-key.md) and only for public users;
  revisit if the public site gets accounts
- Third-party login (Discord, Google): another processor in the privacy page for a
  handful of friends; invites are simpler
