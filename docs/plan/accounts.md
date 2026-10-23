# Plan: accounts and tiers

Jacob 22 Oct (J21): proper logins. His own owner account; friends get private accounts
below admin, so they can't break anything but get the private app and a fuller site;
paid accounts later.
Two apps follow from it: docs/plan/app.md. Policy lines for the private tier: app.md
"Policy line".

## Roles

Jacob 22 Oct: five, in order, each with everything the one before has.

| Role | Gets | Never |
| --- | --- | --- |
| public | the site, the public app once released (no login; a free signed-in account may come later, same role) | anything below |
| paid | extras in the public site and app, within the public product rules (app.md "Policy line") | private pages, private app |
| private | Jacob's friends and testers: private site pages (/p/), private app, read-only admin views opened to them | actions, logs, accounts, settings, raw data |
| admin | everything private, /admin/ views, manage public, paid and private accounts | the admin page's controls (Jacob 23 Oct), other admins or the owner, irreversible things below |
| owner | Jacob only: everything, plus the admin page's controls (crawl, site build, eval, health check), admins, keys and secrets, billing, data deletion and restores, the Riot application | |

- One capability table in code (e.g. src/auth/roles.zig: view_paid, view_private,
  view_admin, run_actions, manage_accounts, manage_admins, manage_billing, delete_data,
  download_private_app); every route checks a capability, never a role name. Adding or
  splitting a tier is one row
- Accounts change only roles below their own: admins can't make, edit or disable
  admins or the owner. Exactly one owner, changed only with `meiolol account` over ssh
- "Can't break stuff" = no write route below admin at all, not hidden buttons. The box's
  admin API keeps its own token check (hosting.md "Admin API"), which nginx only adds
  for admin and owner sessions
- Paid and private differ in kind, not just level: paid is the paying public, so its
  extras must pass Riot's rules for a public product; private is a closed tester group
  and may hold things not (yet) fit for the public. A paid feature usually starts
  private
- Paid needs the production key first: Riot allows monetising only once the product is
  Approved or Acknowledged, with a free tier (riot-policies-general ^f5)

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
- No second factor (Jacob 23 Oct): passwords only, Jacob sets admins' with `meiolol
  account add`. Revisit if admins grow past friends
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

- AC0 Jacob 23 Oct: go; no TOTP; other admins yes, with the admin views and everything
  private but not the controls (run_actions owner only; "maybe some other stuff" later,
  one line each in roles.zig). Still his: the policy framing (app.md "Policy line"),
  who gets the first private accounts, the nginx OK for AC2
- AC1 Accounts core in `meiolol api`: accounts.db schema and migration, argon2id,
  sessions, invites, /auth/login, /auth/logout, /auth/me, /auth/join, /_auth, the CLI.
  Tests: a route x role matrix (every route, every role, expected status), cookie flags,
  constant-time compares, invite reuse and expiry, lockout; fuzz the login body parser.
  Done when the matrix passes and `meiolol account` works against a scratch DB
  Done 23 Oct (src/api/accounts.zig, roles.zig; `meiolol account add|password|role|
  disable|enable|delete|invite|reset|list`): the check route is /auth/check/CAP (nginx
  maps /_auth to it), tested by route x role and over HTTP; not deployed to jomify yet
- AC2 Owner login live: /login page (src/site, no framework), nginx auth_request on
  /admin/ for admin and owner, "Signed in as" in the admin header, sign out. nginx
  passes X-Meiolol-Role on to the renderer: admin_api.zig refuses action/ unless the
  role has run_actions and admin.js hides the controls. accounts.db joins the web
  server's backup. Done when
  Jacob signs in with his own account and the basic auth is only the fallback
- AC3 Private tier: /p/ space (first pages: app.md "Private site"), invites, account page
  (password, devices, sign out everywhere), admin Accounts tab (list, invite, role,
  disable). Done when a test private account reaches /p/ and gets 403 on every /admin/
  route and action
- AC4 Desktop sign in: login screen in the app, device tokens, update gate by token,
  update.key retired. Done when a fresh install signs in, updates, and a revoked device
  stops updating within one check
- AC5 Private edition channel: /p/desktop/ serves the private exe and its data; the
  release script builds both editions (app.md "Two editions")
- AC6 Later: friends link their Riot ID (profile icon check, as Remove a Riot ID does);
  friends' groups become Squads (backlog.md "Your games and Squads") for the private
  tier first
- AC7 Paid, after the key: payments (a merchant of record such as Paddle or Lemon
  Squeezy handles UK and EU VAT; Stripe leaves that to us), terms and refunds, the
  privacy page's billing section, role set and cleared from the payment webhook, owner
  billing view. Paid extras go in the public exe, unlocked by the signed-in account

## Not doing

- Riot Sign On: not needed for the key (production-key.md) and only for public users;
  revisit if the public site gets accounts
- Third-party login (Discord, Google): another processor in the privacy page for a
  handful of friends; invites are simpler
