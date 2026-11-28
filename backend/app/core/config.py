"""Application configuration for the local JobEval backend.

The default configuration is deliberately self contained: SQLite, a local data
 directory, and an in-process job runner.  No Redis, Celery, Docker, or object
store is required to run the API.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any

from pydantic import AliasChoices, Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    """Runtime settings loaded from environment variables or ``.env``."""

    model_config = SettingsConfigDict(
        env_file=(".env",),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
        populate_by_name=True,
    )

    APP_NAME: str = "JobEval"
    APP_VERSION: str = "0.2.0-local"
    API_PREFIX: str = "/api/v1"
    DEBUG: bool = False
    ENVIRONMENT: str = "local"

    HOST: str = "127.0.0.1"
    PORT: int = 8000
    WORKERS: int = 1

    # CORS is configurable for the Flutter client.  Credentials are disabled
    # when the wildcard origin is used, as required by browsers.
    CORS_ORIGINS: list[str] = Field(
        default_factory=lambda: ["http://localhost:3000", "http://localhost:5173"],
        validation_alias=AliasChoices("CORS_ORIGINS", "JOBEVAL_CORS_ORIGINS"),
    )
    CORS_ALLOW_CREDENTIALS: bool = False
    CORS_ALLOW_METHODS: list[str] = Field(default_factory=lambda: ["*"])
    CORS_ALLOW_HEADERS: list[str] = Field(default_factory=lambda: ["*"])

    # Local persistence.  JOBEVAL_DATA_DIR is the convenient override used by
    # tests and by developers who want to keep a project isolated.
    DATA_DIR: Path = Field(
        default_factory=lambda: _BACKEND_ROOT / "data",
        validation_alias=AliasChoices("DATA_DIR", "JOBEVAL_DATA_DIR"),
    )
    DATABASE_URL: str | None = Field(
        default=None,
        validation_alias=AliasChoices("DATABASE_URL", "JOBEVAL_DATABASE_URL"),
    )
    UPLOAD_DIR: Path | None = Field(
        default=None,
        validation_alias=AliasChoices("UPLOAD_DIR", "JOBEVAL_UPLOAD_DIR"),
    )
    TEMP_DIR: Path | None = Field(
        default=None,
        validation_alias=AliasChoices("TEMP_DIR", "JOBEVAL_TEMP_DIR"),
    )
    OUTPUT_DIR: Path | None = Field(
        default=None,
        validation_alias=AliasChoices("OUTPUT_DIR", "JOBEVAL_OUTPUT_DIR"),
    )
    MAX_FILE_SIZE_MB: int = Field(
        default=100,
        validation_alias=AliasChoices(
            "MAX_FILE_SIZE_MB", "MAX_UPLOAD_SIZE_MB", "JOBEVAL_MAX_UPLOAD_SIZE_MB"
        ),
    )
    ALLOWED_EXTENSIONS: list[str] = Field(default_factory=lambda: [".step", ".stp", ".pdf", ".dxf"])

    # Geometry and analysis defaults.
    MESH_DEFLECTION: float = 0.25
    MESH_ANGLE: float = 0.35
    MIN_FEATURE_CONFIDENCE: float = 0.5
    MIN_HOLE_DIAMETER: float = 0.2
    MAX_HOLE_DIAMETER: float = 1000.0

    # Manufacturing defaults.  Rates are intentionally not hidden here: the
    # pricing service emits a warning when a rate is missing.
    DEFAULT_MACHINE: str = "generic_3axis"
    DEFAULT_MATERIAL: str = "aluminum_6061"
    DEFAULT_ALLOWANCE_MM: float = 2.0
    TOOL_CHANGE_TIME_S: float = 15.0
    SETUP_TIME_MIN: float = 30.0
    INSPECTION_TIME_PER_FEATURE_MIN: float = 2.0

    # OpenRouter is optional.  It is never contacted without a key.
    OPENROUTER_API_KEY: str | None = Field(
        default=None,
        validation_alias=AliasChoices("OPENROUTER_API_KEY", "LLM_API_KEY"),
    )
    OPENROUTER_BASE_URL: str = "https://openrouter.ai/api/v1"
    OPENROUTER_MODEL: str = "openai/gpt-4o-mini"
    OPENROUTER_TIMEOUT: int = 60

    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"

    @field_validator(
        "CORS_ORIGINS",
        "ALLOWED_EXTENSIONS",
        "CORS_ALLOW_METHODS",
        "CORS_ALLOW_HEADERS",
        mode="before",
    )
    @classmethod
    def split_csv(cls, value: Any) -> Any:
        if isinstance(value, str):
            return [part.strip() for part in value.split(",") if part.strip()]
        return value

    @field_validator("DATA_DIR", "UPLOAD_DIR", "TEMP_DIR", "OUTPUT_DIR", mode="before")
    @classmethod
    def path_value(cls, value: Any) -> Any:
        if value is None or value == "":
            return value
        return Path(value).expanduser()

    @model_validator(mode="after")
    def resolve_local_paths(self) -> Settings:
        # Do not use the old container-only /app paths.  All paths are local
        # and are rooted below DATA_DIR unless explicitly overridden.
        self.DATA_DIR = self.DATA_DIR.resolve()
        if self.UPLOAD_DIR is None:
            self.UPLOAD_DIR = self.DATA_DIR / "uploads"
        else:
            self.UPLOAD_DIR = self.UPLOAD_DIR.resolve()
        if self.TEMP_DIR is None:
            self.TEMP_DIR = self.DATA_DIR / "tmp"
        else:
            self.TEMP_DIR = self.TEMP_DIR.resolve()
        if self.OUTPUT_DIR is None:
            self.OUTPUT_DIR = self.DATA_DIR / "outputs"
        else:
            self.OUTPUT_DIR = self.OUTPUT_DIR.resolve()
        if self.DATABASE_URL is None:
            self.DATABASE_URL = f"sqlite:///{(self.DATA_DIR / 'jobeval.sqlite3').as_posix()}"
        return self

    @property
    def database_url(self) -> str:
        return self.DATABASE_URL or f"sqlite:///{(self.DATA_DIR / 'jobeval.sqlite3').as_posix()}"

    @property
    def max_file_size_bytes(self) -> int:
        return self.MAX_FILE_SIZE_MB * 1024 * 1024

    @property
    def upload_root(self) -> Path:
        return self.UPLOAD_DIR or (self.DATA_DIR / "uploads")


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()


def reset_settings_cache() -> None:
    """Clear the settings cache (useful for isolated test applications)."""

    get_settings.cache_clear()
