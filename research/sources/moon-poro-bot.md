---
title: 'Moon Poro Bot: League Polska Discord bot, profile-icon verification moving to RSO'
url: https://github.com/Ceendi/Moon-Poro-Bot
kind: project
commit: 44410a906b5698788316074a1438f0bf1e44b2f5
for: [identity-and-privacy]
looked: 2026-10-11
depth: code (README, cogs/verification_legacy.py, settings.py, site privacy page)
relevance: high
grade: C/strong
description: EU community Discord bot linking Riot IDs by a temporary profile-icon challenge as a stopgap until RSO, with a short GDPR privacy policy written for a solo operator
---
# Moon Poro Bot

Why: current (2026) prior art for non-RSO ownership checks, Discord linking, and a small
EU operator's privacy policy for Riot data.

## Assessment

- Evidence: C. Discord bot for the League of Legends Polska server; repo since July 2022,
  pushed Aug 2026, 0 stars, 1 contributor, single squashed commit (history not
  visible). Code is polished and heavily structured, possibly agent-assisted.
- Reasoning: strong for its size: privacy page states bases, retention per data type,
  rights and the supervisory authority; code comments explain the icon flow is temporary.
- Interests: none.
- Weigh: shows the shape a solo developer's policy can take; not reviewed by a lawyer
  as far as we know. The icon flow being labelled temporary suggests the author sees RSO
  as the expected end state.

## Findings

- [privacy] [tools] Profile-icon flow is explicitly a temporary stand-in until RSO
  rollout. `moon_poro/cogs/verification_legacy.py` ^f1
  > # The temporary profile-icon flow intentionally parallels the RSO cog so it can
  > # be removed cleanly after the RSO rollout without coupling both implementations.
- [privacy] [tools] Challenge icon chosen with `secrets` from ids 0 to 28 (the default
  icons), excluding the current icon. `moon_poro/cogs/verification_legacy.py` ^f2
  > LEGACY_CHALLENGE_ICON_IDS = tuple(range(29))
  > return secrets.choice(available_icon_ids)
- [privacy] [tools] Check compares summoner-v4 profileIconId by PUUID to the expected
  icon; one Riot account can link to only one Discord account.
  `moon_poro/cogs/verification_legacy.py` ^f3
  > if current_icon_id != self.expected_icon_id:
  > "To konto Riot jest już połączone z innym kontem Discord."
- [privacy] [tools] Default challenge timeout 120 s (30 to 900), cooldown 30 s.
  `moon_poro/settings.py` ^f4
  > verification_timeout: int = Field(default=120, ge=30, le=900)
- [privacy] Privacy page: data is PUUID, Riot ID, platform and public Solo/Duo rank; the
  icon is read only during the check and not retained. `site/src/pages/en/privacy.astro` ^f5
  > Riot PUUID, Riot ID, League platform and public Solo/Duo data: tier, division, LP, wins, losses and inactive status
  > during the current verification we also read the League of Legends profile icon temporarily, but do not retain it in the active link
- [privacy] Legal bases: providing the requested service; legitimate interests for
  moderation, anti-impersonation, auditing. `site/src/pages/en/privacy.astro` ^f6
  > operating moderation, preventing impersonation, protecting the community, auditing administrator actions
- [privacy] Retention: link until the user deletes it (self-service command); backups 90
  days; admin lookup log 90 days. `site/src/pages/en/privacy.astro` ^f7
  > daily and pre-deployment database backups: normally 90 days
  > administrator account-link lookup log: 90 days
- [privacy] Rights by email; self-service unlink is fastest; identity verified through
  Discord; complaint to UODO (Polish regulator). `site/src/pages/en/privacy.astro` ^f8
  > We may verify identity through Discord before fulfilling a request.
  > You may complain to the Polish President of the Personal Data Protection Office (UODO)
- [privacy] Planned RSO use stores no tokens and asks no offline access. `site/src/pages/en/privacy.astro` ^f9
  > We do not persist RSO tokens.
- [policy] README carries the Riot non-endorsement line and points to Riot policies. `README.md` ^f10
  > Moon Poro Bot isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot

## Read

- README, verification_legacy.py (challenge and check), settings.py, en/privacy.astro

## Not read

- RSO cog (verification.py) beyond grep; terms.astro
