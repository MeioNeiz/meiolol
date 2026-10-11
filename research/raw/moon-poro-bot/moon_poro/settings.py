from __future__ import annotations

from functools import cached_property
from typing import Literal

from pydantic import AnyHttpUrl, Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_RANKS = [
    "Unranked",
    "Iron",
    "Bronze",
    "Silver",
    "Gold",
    "Platinum",
    "Emerald",
    "Diamond",
    "Master",
    "GrandMaster",
    "Challenger",
]


class Settings(BaseSettings):
    """Validated deployment configuration.

    Secrets and installation-specific Discord IDs come from the environment. Role
    names have portable defaults and can be overridden; production deployments
    should populate ``ROLE_IDS`` so renamed roles remain stable.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    discord_token: SecretStr
    riot_api_token: SecretStr

    postgres_user: str
    postgres_password: SecretStr
    postgres_host: str
    postgres_port: int = 5432
    postgres_db: str
    database_pool_size: int = Field(default=3, ge=1, le=10)
    database_max_overflow: int = Field(default=2, ge=0, le=10)

    guild_id: int = Field(gt=0)
    warn_channel_id: int | None = None
    zweryfikowani_channel_id: int | None = None
    legacy_audit_channel_id: int | None = Field(default=None, gt=0)
    szukanie_gry_channel_id: int | None = None
    komendy_botowe_channel_id: int | None = None
    mod_alert_channel_id: int | None = None

    verification_enabled: bool = True
    verification_mode: Literal["legacy_icon", "rso"] = "rso"
    roles_enabled: bool = True
    warnings_enabled: bool = True
    mod_stats_enabled: bool = True
    member_logs_enabled: bool = True
    account_age_gate_enabled: bool = False
    boost_alert_enabled: bool = False
    clash_filter_enabled: bool = False

    minimum_account_age_days: int = Field(default=90, ge=0, le=3650)
    verification_timeout: int = Field(default=120, ge=30, le=900)
    verification_cooldown: int = Field(default=30, ge=1, le=3600)
    verification_icon_check_cooldown: int = Field(default=5, ge=1, le=300)
    verification_global_rate_limit: int = Field(default=4, ge=1, le=100)
    verification_global_rate_period_seconds: int = Field(default=10, ge=1, le=300)
    view_timeout: int = Field(default=180, ge=30, le=3600)
    rank_refresh_interval_hours: int = Field(default=24, ge=1, le=168)
    rank_refresh_worker_interval_seconds: int = Field(default=10, ge=5, le=300)
    rank_refresh_retry_base_seconds: int = Field(default=300, ge=30, le=3600)
    rank_refresh_claim_timeout_seconds: int = Field(default=300, ge=60, le=3600)
    rank_refresh_policy: Literal["fixed", "shadow", "adaptive"] = "fixed"
    rank_refresh_rollout_percent: int = Field(default=100, ge=0, le=100)
    rank_refresh_button_cooldown_seconds: int = Field(default=1800, ge=60, le=86_400)
    rank_refresh_manual_priority_cooldown_seconds: int = Field(default=3600, ge=60, le=86_400)
    rank_refresh_auth_probe_interval_seconds: int = Field(default=900, ge=60, le=3600)
    riot_monitoring_interval_seconds: int = Field(default=300, ge=60, le=3600)
    warning_reconcile_interval_seconds: int = Field(default=300, ge=60, le=3600)
    verification_access_log_retention_days: int = Field(default=90, ge=30, le=3650)
    verification_session_retention_days: int = Field(default=7, ge=1, le=30)
    privacy_policy_url: AnyHttpUrl | None = None
    terms_of_service_url: AnyHttpUrl | None = None
    rso_public_base_url: AnyHttpUrl | None = None
    rso_session_ttl_seconds: int = Field(default=600, ge=180, le=1800)
    rso_completion_interval_seconds: int = Field(default=3, ge=1, le=30)

    verified_role_name: str = "Zweryfikowany"
    member_role_name: str = "Użytkownik"
    no_lol_role_name: str = "Nie posiadam konta w lolu"
    role_ids: dict[str, int] = Field(default_factory=dict)

    lol_servers: list[str] = Field(default_factory=lambda: ["EUNE", "EUW", "NA"])
    lol_ranks: list[str] = Field(default_factory=lambda: list(DEFAULT_RANKS))
    lol_positions: list[str] = Field(
        default_factory=lambda: ["Top", "Jungle", "Mid", "ADC", "Support", "Szukam Gry"]
    )
    optional_roles: list[str] = Field(
        default_factory=lambda: [
            "TFT",
            "LOR",
            "Valorant",
            "Dyskusje",
            "Lol Newsy",
            "Ogłoszenia",
            "Wild Rift",
        ]
    )
    warn_roles: dict[int, str] = Field(
        default_factory=lambda: {1: "Warn", 2: "Warn 2", 3: "TIMEOUT"}
    )
    warn_days: dict[str, int] = Field(
        default_factory=lambda: {"Warn": 7, "Warn 2": 14, "TIMEOUT": 3}
    )
    boost_keywords: list[str] = Field(
        default_factory=lambda: [
            "boost",
            "wbije rangę",
            "wbije range",
            "bost",
            "pomogę z",
            "pomoge z",
            "za free",
            "tanio",
        ]
    )

    @field_validator(
        "warn_channel_id",
        "zweryfikowani_channel_id",
        "legacy_audit_channel_id",
        "szukanie_gry_channel_id",
        "komendy_botowe_channel_id",
        "mod_alert_channel_id",
        mode="before",
    )
    @classmethod
    def zero_is_missing(cls, value: object) -> object:
        return None if value in (None, "", 0, "0") else value

    @field_validator("role_ids")
    @classmethod
    def role_ids_must_be_positive(cls, value: dict[str, int]) -> dict[str, int]:
        invalid = [name for name, role_id in value.items() if role_id <= 0]
        if invalid:
            raise ValueError(f"Role IDs must be positive for: {', '.join(invalid)}")
        return value

    @model_validator(mode="after")
    def validate_feature_dependencies(self) -> Settings:
        required: list[tuple[bool, int | None, str]] = [
            (self.verification_enabled, self.zweryfikowani_channel_id, "ZWERYFIKOWANI_CHANNEL_ID"),
            (self.warnings_enabled, self.warn_channel_id, "WARN_CHANNEL_ID"),
            (self.member_logs_enabled, self.komendy_botowe_channel_id, "KOMENDY_BOTOWE_CHANNEL_ID"),
            (self.boost_alert_enabled, self.mod_alert_channel_id, "MOD_ALERT_CHANNEL_ID"),
            (self.clash_filter_enabled, self.szukanie_gry_channel_id, "SZUKANIE_GRY_CHANNEL_ID"),
        ]
        missing = [name for enabled, value, name in required if enabled and value is None]
        if (
            self.verification_enabled
            and self.verification_mode == "rso"
            and self.rso_public_base_url is None
        ):
            missing.append("RSO_PUBLIC_BASE_URL")
        if missing:
            raise ValueError(f"Enabled features require: {', '.join(missing)}")
        if self.rso_public_base_url is not None:
            _validate_public_rso_url(self.rso_public_base_url)
        expected_levels = {1, 2, 3}
        if set(self.warn_roles) != expected_levels:
            raise ValueError("WARN_ROLES must define exactly levels 1, 2 and 3")
        missing_durations = set(self.warn_roles.values()) - set(self.warn_days)
        if missing_durations:
            raise ValueError(
                "WARN_DAYS is missing durations for: " + ", ".join(sorted(missing_durations))
            )
        invalid_durations = [
            role_name for role_name, days in self.warn_days.items() if days < 1 or days > 3650
        ]
        if invalid_durations:
            raise ValueError(
                "Warning durations must be between 1 and 3650 days for: "
                + ", ".join(sorted(invalid_durations))
            )
        return self

    @cached_property
    def requires_message_content(self) -> bool:
        return self.boost_alert_enabled or self.clash_filter_enabled

    @cached_property
    def allowed_role_names(self) -> frozenset[str]:
        return frozenset(
            self.lol_servers
            + self.lol_ranks
            + self.lol_positions
            + self.optional_roles
            + [self.member_role_name, self.no_lol_role_name]
        )

    @cached_property
    def rso_base_url(self) -> str:
        if self.rso_public_base_url is None:
            raise RuntimeError("RSO_PUBLIC_BASE_URL is not configured")
        return str(self.rso_public_base_url).rstrip("/")


class RSOSettings(BaseSettings):
    """Minimal configuration loaded by the isolated RSO web process."""

    model_config = SettingsConfigDict(
        env_file=".env.rso",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    postgres_user: str
    postgres_password: SecretStr
    postgres_host: str
    postgres_port: int = 5432
    postgres_db: str
    database_pool_size: int = Field(default=1, ge=1, le=3)
    database_max_overflow: int = Field(default=1, ge=0, le=2)
    guild_id: int = Field(gt=0)

    rso_client_id: str = Field(min_length=3, max_length=255)
    rso_client_auth_method: Literal["private_key_jwt", "client_secret_basic"] = "private_key_jwt"
    rso_client_assertion: SecretStr | None = None
    rso_client_secret: SecretStr | None = None
    rso_public_base_url: AnyHttpUrl
    rso_scope: str = "openid cpid"
    rso_allowed_platforms: list[str] = Field(default_factory=lambda: ["EUN1", "EUW1", "NA1"])
    rso_session_ttl_seconds: int = Field(default=600, ge=180, le=1800)
    rso_http_timeout_seconds: float = Field(default=10.0, ge=2.0, le=30.0)
    rso_host: str = "127.0.0.1"
    rso_port: int = Field(default=8080, ge=1024, le=65535)

    @model_validator(mode="after")
    def validate_rso_configuration(self) -> RSOSettings:
        _validate_public_rso_url(self.rso_public_base_url)
        scopes = set(self.rso_scope.split())
        if not {"openid", "cpid"}.issubset(scopes):
            raise ValueError("RSO_SCOPE must include openid and cpid")
        if "offline_access" in scopes:
            raise ValueError("offline_access is not used; Moon Poro never stores refresh tokens")
        if self.rso_client_auth_method == "private_key_jwt":
            if self.rso_client_assertion is None:
                raise ValueError("private_key_jwt requires RSO_CLIENT_ASSERTION")
        elif self.rso_client_secret is None:
            raise ValueError("client_secret_basic requires RSO_CLIENT_SECRET")
        normalized_platforms = [platform.strip().upper() for platform in self.rso_allowed_platforms]
        if not normalized_platforms or any(not value for value in normalized_platforms):
            raise ValueError("RSO_ALLOWED_PLATFORMS cannot be empty")
        unsupported = set(normalized_platforms) - {"EUN1", "EUW1", "NA1"}
        if unsupported:
            raise ValueError(
                "RSO_ALLOWED_PLATFORMS contains platforms without configured Discord roles: "
                + ", ".join(sorted(unsupported))
            )
        self.rso_allowed_platforms = list(dict.fromkeys(normalized_platforms))
        return self

    @cached_property
    def rso_base_url(self) -> str:
        return str(self.rso_public_base_url).rstrip("/")

    @cached_property
    def rso_callback_url(self) -> str:
        return f"{self.rso_base_url}/oauth2/callback"


def _validate_public_rso_url(url: AnyHttpUrl) -> None:
    local_hosts = {"localhost", "127.0.0.1", "::1"}
    if url.scheme != "https" and url.host not in local_hosts:
        raise ValueError("RSO_PUBLIC_BASE_URL must use HTTPS outside local development")
    if url.path not in (None, "", "/") or url.query or url.fragment or url.username or url.password:
        raise ValueError("RSO_PUBLIC_BASE_URL must be an origin without path, query or credentials")
