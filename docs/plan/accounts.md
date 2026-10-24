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
- Break-glass: `meiolol account` on jomify over ssh (hosting.md "Logins"); the basic auth
  went with AC2 (23 Oct), as the CLI can reset any login
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
  Done 23 Oct: live on meio.lol (owner: Jacob's email); admins join through a sign-up
  link (email plus a shared password, Jacob 23 Oct; `meiolol account link admin`),
  tested live: logged out redirects, admin sees /admin/ and live data but gets 403 on
  actions, owner runs them, the desktop key still opens /admin/desktop/. accounts.db
  is backed up to the gpu-box every 6 h since 23 Oct (data-safety.md "Logins backup")
- AC3 Private tier: /p/ space (first pages: app.md "Private site"), invites, account page
  (password, devices, sign out everywhere), admin Accounts tab (list, invite, role,
  disable). Done when a test private account reaches /p/ and gets 403 on every /admin/
  route and action
  23 Oct: /auth/password, /auth/accounts, invite, role, disable, reset (route x role
  tests); /account.html (password, log out everywhere; devices wait for AC4); the admin
  Accounts tab. /p/: the Draft tester in private mode (shipped models only, no box data,
  no lab files), built and uploaded by the web loop once nginx gates /p/ (hosting.md
  "Private site"). Done 23 Oct: nginx gates /p/ (Jacob's OK); a test private login got
  /p/ and its models, and 403 on every /admin/ page, data file, API route and action and
  on /auth/accounts and invite (deleted after). /admin/desktop/ stays open to it
  (download_private_app). Still Jacob's: who gets the first private accounts
- AC4 Desktop sign in: login screen in the app, device tokens, update gate by token,
  update.key retired. Done when a fresh install signs in, updates, and a revoked device
  stops updating within one check
  24 Oct, server side: POST /auth/device (a login, throttled the same, for roles with
  download_private_app) gives a token the app sends as Authorization: Bearer; accounts.db
  devices table (hash only, 90 days unused, 10 per account); /auth/check/CAP takes it
  for Capability.forDevices only (download_private_app: a copied token opens no page), as
  do /auth/me and /auth/logout; the account page lists and removes them; log out
  everywhere, password changes, reset, disable and delete end them. nginx needs no change:
  /admin/desktop/'s key check falls through to /auth/check/download_private_app with the
  request's headers. Next: the app's side (sign-in form, device.token), then the
  cut-over (Jacob: release, then the key leaves nginx and the zip)
  App side: device.zig (POST /auth/device, device.token beside the exe), signin.zig (the
  form: the whole window on a first start with no data, else a line under the content);
  update checks send the token, else update.key until the cut-over; a 401 on the token
  removes it and the form comes back, so a removed device stops at its next check (3 h,
  or the next start). A release installs itself without a key. `meiolol-app signin DIR`
  does the same from a terminal (then `meiolol-app update DIR`)
  Cut-over (Jacob's, in order):
  1. Release an exe that carries sign in (deploy/desktop-release.sh). Installed apps
     still update with update.key and get it; the zip still bundles the key
  2. Each tester signs in from the app (a private account: the form says why not
     otherwise); check with the account page or `meiolol account devices NAME` on jomify
  3. When everyone is on a sign in: on jomify back up /etc/nginx/conf.d/meiolol.conf,
     drop the `include /etc/nginx/meiolol-desktop-key.conf;` line from location
     /_meiolol_desktop_key, `sudo nginx -t`, reload. An app still on the key gets 401
     and shows the form
  4. A session commits web-loop.sh desktop_files without the key (no desktop.token, no
     update.key in the zip, nothing appended to the exe), then removes the box's
     ml/meiolol/desktop.token and jomify's meiolol-desktop-key.conf; hosting.md
     "Desktop app files" follows. The privacy page's desktop app paragraph says the app
     signs in (with step 1)
- AC5 Private edition channel: /p/desktop/ serves the private exe and its data; the
  release script builds both editions (app.md "Two editions"). 24 Oct: the release
  script builds, checks (check-edition, desktop-shots, desktop-smoke on both) and signs
  both editions; private to the box's release/ as before, public to release/public/
  (served nowhere yet); `--dry-run` stops before signing. The web loop puts the same
  files in p/desktop/ as admin/desktop/; nginx location /p/desktop/ has
  /admin/desktop/'s gate (the app's key or device token, or a private login; 401, no
  login redirect, as the app reads 401). The app's update base (update.zig
  default_base) is /p/desktop/ from 24 Oct, so the release with sign in moves there.
  Left: once every installed app runs it (the account page's devices, or nginx's log for
  /admin/desktop/update.signed), admin/desktop/ and its location go
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
