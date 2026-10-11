# Moon Poro Bot

A modular Discord bot for a League of Legends community, written in Python. It provides Riot
account verification, rank synchronization, configurable roles, moderation warnings, and
moderator statistics.

> Moon Poro Bot isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot
> Games. Riot Games and related properties are trademarks of Riot Games, Inc.

## Features

- Riot Sign On verification and automatic Solo/Duo rank synchronization;
- a private self-service Riot account profile through `/profil` and the verification panel;
- persistent role selection panels;
- versioned moderation warnings with escalation, rollback, and automatic expiration;
- monthly moderation statistics;
- audited administrator lookups for Discord–Riot account links;
- optional account-age protection, member logs, and message filters.

Features, channels, and roles are configured through environment variables. The bot does not
request the privileged `message_content` intent unless optional message filters are enabled.

## Setup

Python 3.12 or 3.13 and PostgreSQL 17+ are required.

```bash
python -m pip install uv==0.12.3
uv sync --frozen
cp .env.example .env
uv run python main.py
```

Complete `.env` before starting the bot. `RSO_PUBLIC_BASE_URL` is required when verification is
enabled. Alembic applies pending migrations during startup, so
create a database backup before the first production deployment. On Linux, keep the secrets file
readable only by the service account (`chmod 600 .env`). The supplied systemd unit writes logs to
`/var/log/moon-poro` and keeps the application directory read-only.

The public Astro site is in `site/`; it builds to static files and does not require Node.js on the
production VM. The isolated RSO callback starts through `rso_main.py` with `.env.rso`. Never place
RSO client credentials in the bot environment. See `docs/DEPLOYMENT_RSO_GCP.md` for deployment
instructions.

## Production updates

The `moon-poro-web` deployment uses a clean Git checkout at `/opt/moon-poro-prod`, systemd, and a
pinned `uv` tool environment. Install the deployment and daily backup helpers once from the checked
out repository:

```bash
sudo /opt/moon-poro-prod/deploy/install-prod-automation.sh
```

After a pull request has passed CI and been merged into `master`, deploy it with:

```bash
sudo /usr/local/sbin/deploy-moon-poro-prod
```

Before the first deployment containing migration `20260824_0007`, confirm the single Discord
channel that contains all existing verification audit messages and add its ID to
`/etc/moon-poro/prod-bot.env` as `LEGACY_AUDIT_CHANNEL_ID`. Do not infer it from the current
`ZWERYFIKOWANI_CHANNEL_ID` if the channel may have changed. If historical messages span multiple
channels, stop and prepare a verified per-record backfill first. This setting lets the bot's startup
migration work safely even while the older installed deployment helper is completing that first
update. Afterward, reinstall `deploy/install-prod-automation.sh` once so future deployments run
migrations before restarting the service.

The deployment refuses local tracked changes and non-fast-forward updates. It records the last
successfully started commit and safely resumes an interrupted deployment. Before changing code it
creates a custom-format dump of `moon_poro_prod`, verifies it with `pg_restore --list`, and writes a
SHA-256 checksum. Daily backups use the same procedure through
`moon-poro-prod-backup.timer`. Daily backup pairs remain for 90 days in
`/var/backups/moon-poro-prod/daily`; cleanup runs only after a new dump and checksum have been
verified. Backups made before deployments remain in `/var/backups/moon-poro-prod/pre-deploy` and
are never deleted automatically.

## Development

```bash
uv sync --frozen --extra dev
uv run ruff format --check .
uv run ruff check .
uv run pytest --cov=moon_poro --cov-branch
uv run mypy moon_poro
uv run bandit -r moon_poro
uv run pylint --disable=all --enable=duplicate-code moon_poro
uv run detect-secrets-hook $(git ls-files)
uv run pip-audit --skip-editable
```

Application code is located in `moon_poro/`, database migrations in `alembic/`, and tests in
`tests/`.

## Rights and Riot Games

This repository is not an open-source project. All rights are reserved; see `LICENSE` for details.
This project is not an official Riot Games product. Usage of the Riot API must comply with the
current [Riot Developer Policies](https://developer.riotgames.com/policies/general).
