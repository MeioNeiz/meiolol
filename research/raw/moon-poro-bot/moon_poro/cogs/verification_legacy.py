# The temporary profile-icon flow intentionally parallels the RSO cog so it can
# be removed cleanly after the RSO rollout without coupling both implementations.
# pylint: disable=duplicate-code
from __future__ import annotations

import logging
import math
import secrets
import time
from collections import deque
from collections.abc import Callable
from contextlib import suppress
from typing import Any

import discord
from discord import app_commands
from discord.ext import commands
from sqlalchemy.exc import IntegrityError

from moon_poro.bot import MoonPoroBot
from moon_poro.cogs.verification import (
    VerificationCog,
    _apply_verified_roles,
    _get_leagues,
    _reconcile_applied_roles,
    _reconcile_cached_role_change,
    _remove_verified_marker,
    _request_rank_refresh_from_panel,
    _restore_cached_roles_on_join,
    _run_active_link_role_update,
    _show_account_profile,
    _show_delete_confirmation,
    _verification_legal_links,
)
from moon_poro.permissions import administrator_only
from moon_poro.rank_refresh import solo_rank_snapshot
from moon_poro.riot import (
    API_SERVERS,
    SERVER_TRANSLATION,
    RiotAPIUnavailable,
    get_rank_from_leagues,
    profile_icon_url,
    riot_api_call,
)
from moon_poro.roles import member_has_role

logger = logging.getLogger("moon_poro.verification_legacy")

type RiotPayload = dict[str, Any]

RIOT_GAME_NAME_MIN_LENGTH = 3
RIOT_GAME_NAME_MAX_LENGTH = 16
RIOT_TAG_LINE_MIN_LENGTH = 3
RIOT_TAG_LINE_MAX_LENGTH = 5
LEGACY_CHALLENGE_ICON_IDS = tuple(range(29))


def _profile_icon_id(summoner: RiotPayload | None) -> int | None:
    if summoner is None:
        return None
    profile_icon_id = summoner.get("profileIconId")
    if (
        not isinstance(profile_icon_id, int)
        or isinstance(profile_icon_id, bool)
        or profile_icon_id < 0
    ):
        return None
    return profile_icon_id


def _choose_legacy_challenge_icon(current_icon_id: int) -> int:
    available_icon_ids = tuple(
        icon_id for icon_id in LEGACY_CHALLENGE_ICON_IDS if icon_id != current_icon_id
    )
    return secrets.choice(available_icon_ids)


class LegacyVerificationRateLimiter:
    def __init__(
        self,
        *,
        global_rate: int,
        global_period_seconds: float,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self.global_rate = global_rate
        self.global_period_seconds = global_period_seconds
        self._clock = clock
        self._user_limits: dict[tuple[str, int], float] = {}
        self._global_requests: deque[float] = deque()

    def update_rate_limit(
        self,
        scope: str,
        user_id: int,
        *,
        user_cooldown_seconds: float,
    ) -> float | None:
        now = self._clock()
        self._user_limits = {
            key: expires_at for key, expires_at in self._user_limits.items() if expires_at > now
        }
        global_cutoff = now - self.global_period_seconds
        while self._global_requests and self._global_requests[0] <= global_cutoff:
            self._global_requests.popleft()

        user_retry_after = max(0.0, self._user_limits.get((scope, user_id), now) - now)
        global_retry_after = 0.0
        if len(self._global_requests) >= self.global_rate:
            global_retry_after = max(
                0.0,
                self._global_requests[0] + self.global_period_seconds - now,
            )
        retry_after = max(user_retry_after, global_retry_after)
        if retry_after > 0:
            return retry_after

        self._user_limits[(scope, user_id)] = now + user_cooldown_seconds
        self._global_requests.append(now)
        return None


def _rate_limit_message(retry_after: float) -> str:
    return f"Za dużo prób. Spróbuj ponownie za {math.ceil(retry_after)} s."


def _normalize_riot_id_parts(game_name: str, tag_line: str) -> tuple[str, str]:
    normalized_name = game_name.strip()
    normalized_tag = tag_line.strip().removeprefix("#").strip()
    return normalized_name, normalized_tag


def _riot_id_validation_error(game_name: str, tag_line: str) -> str | None:
    if not RIOT_GAME_NAME_MIN_LENGTH <= len(game_name) <= RIOT_GAME_NAME_MAX_LENGTH:
        return "Nazwa w Riot ID musi mieć od 3 do 16 znaków."
    if "#" in game_name:
        return "W polu „Nazwa” wpisz tylko część Riot ID przed znakiem #."
    if not RIOT_TAG_LINE_MIN_LENGTH <= len(tag_line) <= RIOT_TAG_LINE_MAX_LENGTH:
        return "Tag musi mieć od 3 do 5 znaków."
    if not tag_line.isalnum():
        return "Tag może zawierać tylko litery i cyfry."
    return None


async def _get_account(
    bot: MoonPoroBot, game_name: str, tag_line: str, platform: str
) -> RiotPayload | None:
    return await riot_api_call(
        lambda: bot.riot_client.get_account_v1_by_riot_id(
            game_name=game_name.strip(),
            tag_line=tag_line.replace("#", "").strip(),
            region=API_SERVERS[platform],
        ),
        not_found=None,
    )


async def _get_summoner(bot: MoonPoroBot, platform: str, puuid: str) -> RiotPayload | None:
    return await riot_api_call(
        lambda: bot.riot_client.get_lol_summoner_v4_by_puuid(region=platform, puuid=puuid),
        not_found=None,
    )


class LegacyVerificationStartView(discord.ui.View):
    def __init__(self, bot: MoonPoroBot, rate_limiter: LegacyVerificationRateLimiter) -> None:
        super().__init__(timeout=None)
        self.bot = bot
        self.rate_limiter = rate_limiter
        self.cooldowns: commands.CooldownMapping[discord.Interaction] = (
            commands.CooldownMapping.from_cooldown(
                1.0,
                bot.settings.verification_cooldown,
                lambda interaction: interaction.user.id,
            )
        )

    @discord.ui.button(
        label="Zweryfikuj konto",
        style=discord.ButtonStyle.green,
        custom_id="verification:start:profile-icon:v1",
    )
    async def start(
        self,
        interaction: discord.Interaction,
        _button: discord.ui.Button[LegacyVerificationStartView],
    ) -> None:
        await self.begin_verification(interaction)

    async def begin_verification(self, interaction: discord.Interaction) -> None:
        if interaction.guild_id != self.bot.settings.guild_id:
            await interaction.response.send_message(
                "Weryfikację możesz rozpocząć tylko na serwerze Moon Poro.", ephemeral=True
            )
            return
        retry_after = self.cooldowns.update_rate_limit(interaction)
        if retry_after:
            await interaction.response.send_message(
                f"Spróbuj ponownie za {math.ceil(retry_after)} s.", ephemeral=True
            )
            return
        if not isinstance(interaction.user, discord.Member):
            await interaction.response.send_message(
                "Weryfikację rozpocznij na serwerze Discord.", ephemeral=True
            )
            return
        existing_link = await self.bot.verifications.get_by_user(
            interaction.guild_id, interaction.user.id
        )
        if (
            existing_link is not None
            and getattr(existing_link, "deletion_requested_at", None) is not None
        ):
            await interaction.response.send_message(
                "Usuwanie poprzedniego powiązania jeszcze trwa. Spróbuj ponownie za chwilę.",
                ephemeral=True,
            )
            return
        if existing_link is not None and not getattr(existing_link, "puuid", None):
            await interaction.response.send_message(
                "Najpierw usuń poprzednie powiązanie w sekcji „Moje konto”.",
                ephemeral=True,
            )
            return
        if (
            member_has_role(
                interaction.user,
                self.bot.settings.verified_role_name,
                self.bot.settings,
            )
            or existing_link is not None
        ):
            await interaction.response.send_message(
                "Masz już połączone konto Riot. Aby połączyć inne, najpierw usuń "
                "obecne powiązanie w sekcji „Moje konto”.",
                ephemeral=True,
            )
            return
        await interaction.response.send_modal(LegacyVerificationModal(self.bot, self.rate_limiter))

    @discord.ui.button(
        label="Moje konto",
        style=discord.ButtonStyle.secondary,
        custom_id="verification:account-profile:v1",
    )
    async def account_profile(
        self,
        interaction: discord.Interaction,
        _button: discord.ui.Button[LegacyVerificationStartView],
    ) -> None:
        await _show_account_profile(
            self.bot,
            interaction,
            start_verification=self.begin_verification,
        )

    @discord.ui.button(
        label="Odśwież rangę",
        style=discord.ButtonStyle.blurple,
        custom_id="verification:rank-refresh:v1",
    )
    async def refresh_rank(
        self,
        interaction: discord.Interaction,
        _button: discord.ui.Button[LegacyVerificationStartView],
    ) -> None:
        await _request_rank_refresh_from_panel(self.bot, interaction)

    @discord.ui.button(
        label="Usuń powiązanie",
        style=discord.ButtonStyle.red,
        custom_id="verification:delete:v1",
    )
    async def remove_verification(
        self,
        interaction: discord.Interaction,
        _button: discord.ui.Button[LegacyVerificationStartView],
    ) -> None:
        await _show_delete_confirmation(self.bot, interaction)


class LegacyVerificationModal(discord.ui.Modal, title="Weryfikacja konta Riot"):
    def __init__(
        self,
        bot: MoonPoroBot,
        rate_limiter: LegacyVerificationRateLimiter,
        *,
        game_name: str = "",
        tag_line: str = "",
        platform: str | None = None,
    ) -> None:
        super().__init__(
            timeout=bot.settings.verification_timeout,
            custom_id="verification:legacy-account:v2",
        )
        self.bot = bot
        self.rate_limiter = rate_limiter
        self.game_name: discord.ui.TextInput[LegacyVerificationModal] = discord.ui.TextInput(
            custom_id="verification:riot-game-name:v2",
            placeholder="np. Moon Poro",
            default=game_name or None,
            min_length=RIOT_GAME_NAME_MIN_LENGTH,
            max_length=RIOT_GAME_NAME_MAX_LENGTH,
        )
        self.tag_line: discord.ui.TextInput[LegacyVerificationModal] = discord.ui.TextInput(
            custom_id="verification:riot-tag-line:v2",
            placeholder="np. EUNE",
            default=tag_line or None,
            min_length=RIOT_TAG_LINE_MIN_LENGTH,
            # Six characters let us tolerate an accidentally pasted leading '#'.
            max_length=RIOT_TAG_LINE_MAX_LENGTH + 1,
        )
        self.platform: discord.ui.Select[LegacyVerificationModal] = discord.ui.Select(
            custom_id="verification:platform:v2",
            placeholder="Wybierz region",
            min_values=1,
            max_values=1,
            required=True,
            options=[
                discord.SelectOption(
                    label="EUNE",
                    value="EUN1",
                    description="Europa Północna i Wschodnia",
                    default=platform == "EUN1",
                ),
                discord.SelectOption(
                    label="EUW",
                    value="EUW1",
                    description="Europa Zachodnia",
                    default=platform == "EUW1",
                ),
                discord.SelectOption(
                    label="NA",
                    value="NA1",
                    description="Ameryka Północna",
                    default=platform == "NA1",
                ),
            ],
        )
        self.add_item(
            discord.ui.Label(
                text="Nazwa",
                description="Część Riot ID przed #",
                component=self.game_name,
            )
        )
        self.add_item(
            discord.ui.Label(
                text="Tag",
                description="Część Riot ID po # (3-5 liter lub cyfr)",
                component=self.tag_line,
            )
        )
        self.add_item(
            discord.ui.Label(
                text="Region",
                component=self.platform,
            )
        )

    def _retry_view(
        self, interaction: discord.Interaction, game_name: str, tag_line: str, platform: str
    ) -> LegacyVerificationRetryView:
        return LegacyVerificationRetryView(
            self.bot,
            self.rate_limiter,
            owner_id=interaction.user.id,
            game_name=game_name,
            tag_line=tag_line,
            platform=platform,
        )

    async def on_submit(self, interaction: discord.Interaction) -> None:
        if interaction.guild_id != self.bot.settings.guild_id:
            await interaction.response.send_message(
                "Weryfikację możesz rozpocząć tylko na serwerze Moon Poro.",
                ephemeral=True,
            )
            return
        if len(self.platform.values) != 1 or self.platform.values[0] not in SERVER_TRANSLATION:
            await interaction.response.send_message(
                "Wybierz jeden z dostępnych regionów League of Legends.", ephemeral=True
            )
            return

        platform = self.platform.values[0]
        game_name, tag_line = _normalize_riot_id_parts(
            self.game_name.value,
            self.tag_line.value,
        )
        validation_error = _riot_id_validation_error(game_name, tag_line)
        if validation_error is not None:
            await interaction.response.send_message(
                validation_error,
                view=self._retry_view(interaction, game_name, tag_line, platform),
                ephemeral=True,
            )
            return

        retry_after = self.rate_limiter.update_rate_limit(
            "account",
            interaction.user.id,
            user_cooldown_seconds=self.bot.settings.verification_cooldown,
        )
        if retry_after is not None:
            await interaction.response.send_message(
                _rate_limit_message(retry_after),
                view=self._retry_view(interaction, game_name, tag_line, platform),
                ephemeral=True,
            )
            return

        await interaction.response.defer(ephemeral=True, thinking=True)
        try:
            account = await _get_account(
                self.bot,
                game_name,
                tag_line,
                platform,
            )
            if account is None:
                await interaction.followup.send(
                    f"Nie znaleziono Riot ID **{discord.utils.escape_markdown(game_name)}#"
                    f"{discord.utils.escape_markdown(tag_line)}** w regionie "
                    f"**{SERVER_TRANSLATION[platform]}**.\nSprawdź Riot ID z profilu Riot "
                    "(nie nazwę logowania) oraz wybrany region.",
                    view=self._retry_view(interaction, game_name, tag_line, platform),
                    ephemeral=True,
                )
                return
            puuid = str(account["puuid"])
            if await self.bot.verifications.get_by_puuid(interaction.guild_id, puuid):
                await interaction.followup.send(
                    "To konto Riot jest już połączone z innym kontem Discord.", ephemeral=True
                )
                return
            summoner = await _get_summoner(self.bot, platform, puuid)
        except RiotAPIUnavailable:
            await interaction.followup.send(
                "Riot jest chwilowo niedostępny. Spróbuj ponownie później.",
                ephemeral=True,
            )
            return
        if summoner is None:
            await interaction.followup.send(
                "Riot ID istnieje, ale nie ma profilu League of Legends w wybranym regionie. "
                "Sprawdź wybrany region.",
                view=self._retry_view(interaction, game_name, tag_line, platform),
                ephemeral=True,
            )
            return

        current_icon_id = _profile_icon_id(summoner)
        if current_icon_id is None:
            await interaction.followup.send(
                "Riot jest chwilowo niedostępny. Spróbuj ponownie później.",
                ephemeral=True,
            )
            return

        icon_id = _choose_legacy_challenge_icon(current_icon_id)
        embed = discord.Embed(
            title="Potwierdź konto ikoną profilu",
            description=(
                "Ustaw w kliencie League of Legends ikonę widoczną poniżej. "
                "Następnie kliknij **Sprawdź ikonę**."
            ),
            colour=discord.Colour.from_rgb(116, 211, 224),
        )
        embed.add_field(
            name="Riot ID",
            value=f"{account.get('gameName', game_name)}#{account.get('tagLine', tag_line)}",
            inline=False,
        )
        embed.add_field(name="Region", value=SERVER_TRANSLATION[platform])
        embed.set_thumbnail(url=profile_icon_url(icon_id))
        view = LegacyIconConfirmationView(
            self.bot,
            self.rate_limiter,
            owner_id=interaction.user.id,
            platform=platform,
            puuid=puuid,
            game_name=str(account.get("gameName", game_name)),
            tag_line=str(account.get("tagLine", tag_line)),
            expected_icon_id=icon_id,
        )
        await interaction.followup.send(embed=embed, view=view, ephemeral=True)


class LegacyVerificationRetryView(discord.ui.View):
    def __init__(
        self,
        bot: MoonPoroBot,
        rate_limiter: LegacyVerificationRateLimiter,
        *,
        owner_id: int,
        game_name: str,
        tag_line: str,
        platform: str,
    ) -> None:
        super().__init__(timeout=bot.settings.view_timeout)
        self.bot = bot
        self.rate_limiter = rate_limiter
        self.owner_id = owner_id
        self.game_name = game_name
        self.tag_line = tag_line
        self.platform = platform

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id == self.owner_id:
            return True
        await interaction.response.send_message(
            "Nie możesz użyć przycisku innej osoby.", ephemeral=True
        )
        return False

    @discord.ui.button(label="Popraw dane", style=discord.ButtonStyle.secondary)
    async def retry(
        self,
        interaction: discord.Interaction,
        _button: discord.ui.Button[LegacyVerificationRetryView],
    ) -> None:
        await interaction.response.send_modal(
            LegacyVerificationModal(
                self.bot,
                self.rate_limiter,
                game_name=self.game_name,
                tag_line=self.tag_line,
                platform=self.platform,
            )
        )


class LegacyIconConfirmationView(discord.ui.View):
    def __init__(
        self,
        bot: MoonPoroBot,
        rate_limiter: LegacyVerificationRateLimiter,
        *,
        owner_id: int,
        platform: str,
        puuid: str,
        game_name: str,
        tag_line: str,
        expected_icon_id: int,
    ) -> None:
        super().__init__(timeout=bot.settings.verification_timeout)
        self.bot = bot
        self.rate_limiter = rate_limiter
        self.owner_id = owner_id
        self.platform = platform
        self.puuid = puuid
        self.game_name = game_name
        self.tag_line = tag_line
        self.expected_icon_id = expected_icon_id

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id == self.owner_id:
            return True
        await interaction.response.send_message(
            "Nie możesz użyć przycisku innej osoby.", ephemeral=True
        )
        return False

    @discord.ui.button(label="Sprawdź ikonę", style=discord.ButtonStyle.green)
    async def confirm(
        self,
        interaction: discord.Interaction,
        button: discord.ui.Button[LegacyIconConfirmationView],
    ) -> None:
        if (
            interaction.guild is None
            or interaction.guild_id != self.bot.settings.guild_id
            or not isinstance(interaction.user, discord.Member)
        ):
            await interaction.response.send_message(
                "Weryfikację możesz dokończyć tylko na serwerze Moon Poro.", ephemeral=True
            )
            return
        member = interaction.user
        retry_after = self.rate_limiter.update_rate_limit(
            "icon",
            interaction.user.id,
            user_cooldown_seconds=self.bot.settings.verification_icon_check_cooldown,
        )
        if retry_after is not None:
            await interaction.response.send_message(
                _rate_limit_message(retry_after), ephemeral=True
            )
            return
        await interaction.response.defer(ephemeral=True, thinking=True)
        try:
            existing_link = await self.bot.verifications.get_by_user(
                interaction.guild_id, self.owner_id
            )
            if (
                existing_link is not None
                and getattr(existing_link, "deletion_requested_at", None) is not None
            ):
                await interaction.followup.send(
                    "Usuwanie poprzedniego powiązania jeszcze trwa. Spróbuj ponownie za chwilę.",
                    ephemeral=True,
                )
                return
            if existing_link is not None:
                await interaction.followup.send("Masz już połączone konto Riot.", ephemeral=True)
                return
            if await self.bot.verifications.get_by_puuid(interaction.guild_id, self.puuid):
                await interaction.followup.send(
                    "To konto Riot jest już połączone z innym kontem Discord.",
                    ephemeral=True,
                )
                return
            summoner = await _get_summoner(self.bot, self.platform, self.puuid)
            current_icon_id = _profile_icon_id(summoner)
            if current_icon_id is None:
                await interaction.followup.send(
                    "Riot jest chwilowo niedostępny. Spróbuj ponownie później.",
                    ephemeral=True,
                )
                return
            if current_icon_id != self.expected_icon_id:
                await interaction.followup.send(
                    "Ikona profilu nie została jeszcze zmieniona. Ustaw wskazaną ikonę "
                    "i spróbuj ponownie.",
                    ephemeral=True,
                )
                return
            leagues = await _get_leagues(self.bot, self.platform, self.puuid)
        except RiotAPIUnavailable:
            await interaction.followup.send(
                "Riot jest chwilowo niedostępny. Spróbuj ponownie później.",
                ephemeral=True,
            )
            return

        rank = get_rank_from_leagues(leagues).title()
        channel_id = self.bot.settings.zweryfikowani_channel_id
        channel = interaction.guild.get_channel(channel_id) if channel_id else None
        if not isinstance(channel, discord.abc.Messageable):
            await interaction.followup.send(
                "Nie można teraz dokończyć weryfikacji. Zgłoś problem administratorowi.",
                ephemeral=True,
            )
            return

        audit_embed = discord.Embed(
            title="Weryfikacja konta: ikona profilu",
            colour=discord.Colour.green(),
        )
        audit_embed.add_field(
            name="Użytkownik", value=f"<@{interaction.user.id}> (`{interaction.user.id}`)"
        )
        audit_embed.add_field(name="Region", value=SERVER_TRANSLATION[self.platform])
        audit_embed.add_field(name="Ranga Solo/Duo", value=rank)
        audit_embed.add_field(
            name="Riot ID", value=f"{self.game_name}#{self.tag_line}", inline=False
        )
        try:
            audit_message = await channel.send(
                embed=audit_embed,
                allowed_mentions=discord.AllowedMentions.none(),
            )
        except discord.HTTPException:
            await interaction.followup.send(
                "Nie udało się dokończyć weryfikacji. Spróbuj ponownie.", ephemeral=True
            )
            return

        try:
            link = await self.bot.verifications.create(
                guild_id=interaction.guild_id,
                user_id=self.owner_id,
                message_id=audit_message.id,
                audit_channel_id=channel_id,
                platform=self.platform,
                puuid=self.puuid,
                method="PROFILE_ICON",
                riot_game_name=self.game_name,
                riot_tag_line=self.tag_line,
                rank_tier=get_rank_from_leagues(leagues).upper(),
                rank_snapshot=solo_rank_snapshot(leagues),
                refresh_interval_hours=self.bot.settings.rank_refresh_interval_hours,
            )
        except IntegrityError:
            logger.exception("Could not store profile-icon verification for %s", self.owner_id)
            with suppress(discord.NotFound, discord.HTTPException):
                await audit_message.delete()
            await interaction.followup.send(
                "Nie udało się dokończyć weryfikacji. To konto mogło zostać już połączone.",
                ephemeral=True,
            )
            return

        cog = self.bot.get_cog("LegacyVerificationCog")

        async def apply_roles() -> None:
            if isinstance(cog, LegacyVerificationCog):
                await cog.apply_verified_roles(member, self.platform, leagues)
            else:
                await _apply_verified_roles(self.bot, member, self.platform, leagues)

        try:
            applied = await _run_active_link_role_update(self.bot, link, apply_roles)
        except discord.HTTPException:
            await self.bot.verifications.retry_rank_role_sync(
                interaction.guild_id,
                self.owner_id,
                base_delay_seconds=self.bot.settings.rank_refresh_retry_base_seconds,
                expected_rank_last_checked_at=link.rank_last_checked_at,
                expected_puuid=link.puuid,
                expected_platform=link.platform,
                expected_created_at=link.created_at,
            )
            logger.exception(
                "Stored profile-icon verification for %s but Discord role sync failed",
                self.owner_id,
            )
            button.disabled = True
            with suppress(discord.HTTPException):
                await interaction.edit_original_response(view=self)
            await interaction.followup.send(
                "Konto Riot zostało zweryfikowane. Bot dokończy nadawanie ról automatycznie.",
                ephemeral=True,
            )
            return

        if not applied:
            await interaction.followup.send(
                "Powiązanie konta zmieniło się podczas weryfikacji. Sprawdź aktualne "
                "dane w sekcji „Moje konto”.",
                ephemeral=True,
            )
            return

        if isinstance(cog, LegacyVerificationCog):
            current = await _reconcile_applied_roles(cog, interaction.user, link)
        else:
            current = await self.bot.verifications.is_current_verification(
                interaction.guild_id,
                self.owner_id,
                expected_puuid=link.puuid or "",
                expected_platform=link.platform,
                expected_created_at=link.created_at,
            )
            if not current:
                cleanup_generation = await self.bot.verifications.enqueue_verified_marker_cleanup(
                    interaction.guild_id,
                    self.owner_id,
                )
                try:
                    await _remove_verified_marker(
                        self.bot,
                        interaction.user,
                        reason="Anulowanie nieaktualnej weryfikacji Riot",
                    )
                except discord.HTTPException:
                    await self.bot.verifications.retry_verified_marker_cleanup(
                        interaction.guild_id,
                        self.owner_id,
                        expected_generation=cleanup_generation,
                        base_delay_seconds=self.bot.settings.rank_refresh_retry_base_seconds,
                    )
        if not current:
            await interaction.followup.send(
                "Powiązanie konta zmieniło się podczas weryfikacji. Sprawdź aktualne "
                "dane w sekcji „Moje konto”.",
                ephemeral=True,
            )
            return
        await self.bot.verifications.acknowledge_rank_role_sync(
            interaction.guild_id,
            self.owner_id,
            expected_rank_last_checked_at=link.rank_last_checked_at,
            expected_puuid=link.puuid,
            expected_platform=link.platform,
            expected_created_at=link.created_at,
        )

        button.disabled = True
        with suppress(discord.HTTPException):
            await interaction.edit_original_response(view=self)
        await interaction.followup.send("Konto Riot zostało zweryfikowane.", ephemeral=True)


class LegacyVerificationCog(VerificationCog):
    def __init__(self, bot: MoonPoroBot) -> None:
        self.bot = bot
        self._managed_role_updates: set[int] = set()
        self.rate_limiter = LegacyVerificationRateLimiter(
            global_rate=bot.settings.verification_global_rate_limit,
            global_period_seconds=bot.settings.verification_global_rate_period_seconds,
        )
        self.legacy_start_view = LegacyVerificationStartView(bot, self.rate_limiter)
        bot.add_view(self.legacy_start_view)
        self.refresh_verified.change_interval(
            seconds=bot.settings.rank_refresh_worker_interval_seconds
        )
        self.report_riot_monitoring.change_interval(
            seconds=bot.settings.riot_monitoring_interval_seconds
        )
        self.refresh_verified.start()
        self.verification_maintenance.start()
        self.report_riot_monitoring.start()

    async def cog_unload(self) -> None:
        self.refresh_verified.cancel()
        self.verification_maintenance.cancel()
        self.report_riot_monitoring.cancel()

    async def apply_verified_roles(
        self,
        member: discord.Member,
        platform: str,
        leagues: list[RiotPayload],
    ) -> None:
        self._managed_role_updates.add(member.id)
        try:
            await _apply_verified_roles(self.bot, member, platform, leagues)
        finally:
            self._managed_role_updates.discard(member.id)

    @commands.Cog.listener()
    async def on_member_join(self, member: discord.Member) -> None:
        await _restore_cached_roles_on_join(self, member)

    @commands.Cog.listener()
    async def on_member_update(self, before: discord.Member, after: discord.Member) -> None:
        await _reconcile_cached_role_change(self, before, after)

    @administrator_only()
    @app_commands.default_permissions(administrator=True)
    @app_commands.command(name="weryfikacja", description="Publikuje panel weryfikacji ikoną")
    async def publish_verification(  # type: ignore[override]
        self, interaction: discord.Interaction
    ) -> None:
        embed = discord.Embed(
            title="Weryfikacja konta League of Legends",
            description=(
                "Podaj Riot ID i region. Następnie potwierdź konto, zmieniając ikonę "
                "profilu w kliencie League of Legends."
            ),
            colour=discord.Colour.from_rgb(116, 211, 224),
        )
        embed.add_field(
            name="Role",
            value=(
                "Bot nada Ci rolę „Zweryfikowany” oraz role regionu i rangi Solo/Duo. "
                "Rangę będzie odświeżać automatycznie."
            ),
            inline=False,
        )
        embed.add_field(
            name="Zasady",
            value=_verification_legal_links(self.bot),
            inline=False,
        )
        embed.set_footer(text="Kliknij „Zweryfikuj konto”, aby rozpocząć.")
        await interaction.response.send_message(
            embed=embed,
            view=self.legacy_start_view,
        )

    @app_commands.command(
        name="usun_weryfikacje", description="Usuwa powiązanie z Twoim kontem Riot"
    )
    async def remove_own_verification(  # type: ignore[override]
        self, interaction: discord.Interaction
    ) -> None:
        await _show_delete_confirmation(self.bot, interaction)

    @app_commands.command(name="profil", description="Pokazuje dane połączonego konta Riot")
    @app_commands.guild_only()
    async def profile(  # type: ignore[override]
        self, interaction: discord.Interaction
    ) -> None:
        await _show_account_profile(
            self.bot,
            interaction,
            start_verification=self.legacy_start_view.begin_verification,
        )


async def setup(bot: MoonPoroBot) -> None:
    await bot.add_cog(LegacyVerificationCog(bot))
