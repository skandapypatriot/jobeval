"""JobEval Backend Configuration"""

from functools import lru_cache
from pathlib import Path
from typing import List, Optional

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application
    APP_NAME: str = "JobEval"
    APP_VERSION: str = "0.1.0"
    API_PREFIX: str = "/api/v1"
    DEBUG: bool = False
    ENVIRONMENT: str = "development"

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    WORKERS: int = 1

    # Security
    SECRET_KEY: str = Field(default="dev-secret-change-in-production-min-32-chars!!", min_length=32)
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    ALGORITHM: str = "HS256"

    # CORS
    CORS_ORIGINS: List[str] = Field(default_factory=lambda: ["*"])
    CORS_ALLOW_CREDENTIALS: bool = True
    CORS_ALLOW_METHODS: List[str] = Field(default_factory=lambda: ["*"])
    CORS_ALLOW_HEADERS: List[str] = Field(default_factory=lambda: ["*"])

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://jobeval:jobeval@localhost:5432/jobeval"
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 20
    DATABASE_ECHO: bool = False

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_MAX_CONNECTIONS: int = 50

    # Celery
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"
    CELERY_TASK_TRACK_STARTED: bool = True
    CELERY_TASK_TIME_LIMIT: int = 3600  # 1 hour
    CELERY_WORKER_PREFETCH_MULTIPLIER: int = 1

    # File Storage (MinIO/S3)
    STORAGE_ENDPOINT: str = "localhost:9000"
    STORAGE_ACCESS_KEY: str = "minioadmin"
    STORAGE_SECRET_KEY: str = "minioadmin"
    STORAGE_BUCKET: str = "jobeval"
    STORAGE_SECURE: bool = False
    STORAGE_REGION: str = "us-east-1"
    MAX_FILE_SIZE_MB: int = 500
    ALLOWED_EXTENSIONS: List[str] = Field(
        default_factory=lambda: [
            ".step", ".stp", ".iges", ".igs", ".stl", ".brep",
            ".dxf", ".dwg", ".pdf", ".svg", ".png", ".jpg", ".jpeg"
        ]
    )

    # File Paths
    UPLOAD_DIR: Path = Path("/app/uploads")
    TEMP_DIR: Path = Path("/app/temp")
    OUTPUT_DIR: Path = Path("/app/outputs")

    # CAD Processing
    OCCT_TOLERANCE: float = 1e-6
    OCCT_ANGULAR_TOLERANCE: float = 0.01
    MESH_DEFLECTION: float = 0.1
    MESH_ANGLE: float = 0.5
    ENABLE_GEOMETRY_REPAIR: bool = True
    REPAIR_TOLERANCE: float = 1e-4

    # Feature Recognition
    MIN_HOLE_DIAMETER: float = 0.5  # mm
    MAX_HOLE_DIAMETER: float = 500.0  # mm
    MIN_FEATURE_CONFIDENCE: float = 0.3
    PATTERN_DETECTION_TOLERANCE: float = 0.1
    SYMMETRY_TOLERANCE: float = 0.01

    # Drawing Analysis
    PDF_RENDER_DPI: int = 300
    OCR_LANGUAGES: List[str] = Field(default_factory=lambda: ["en"])
    OCR_CONFIDENCE_THRESHOLD: float = 0.6
    DIMENSION_DETECTION_CONFIDENCE: float = 0.7

    # Manufacturing
    DEFAULT_MACHINE: str = "generic_3axis"
    DEFAULT_MATERIAL: str = "aluminum_6061"
    STOCK_MARGIN_MM: float = 5.0
    TOOL_CHANGE_TIME_S: float = 15.0
    SETUP_TIME_MIN: float = 30.0
    INSPECTION_TIME_PER_FEATURE_MIN: float = 2.0

    # LLM
    LLM_PROVIDER: str = "nvidia_nim"  # openrouter, deepinfra, nvidia_nim
    LLM_API_KEY: Optional[str] = None
    LLM_BASE_URL: str = "https://integrate.api.nvidia.com/v1"
    LLM_MODEL: str = "nvidia/nemotron-3.5-..."  # Set specific Nemotron 3.5 model
    LLM_TIMEOUT: int = 120
    LLM_MAX_RETRIES: int = 3
    LLM_TEMPERATURE: float = 0.1
    LLM_MAX_TOKENS: int = 8192
    ENABLE_ZERO_DATA_RETENTION: bool = True

    # Privacy
    PRIVACY_MODE: str = "local"  # local, approved_cloud
    ALLOWED_PROVIDERS: List[str] = Field(default_factory=lambda: ["openrouter", "deepinfra", "nvidia_nim"])
    DATA_RETENTION_DAYS: int = 30
    AUTO_DELETE_PROCESSED_FILES: bool = True

    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"  # json, console

    @field_validator("UPLOAD_DIR", "TEMP_DIR", "OUTPUT_DIR", mode="before")
    @classmethod
    def ensure_path(cls, v: str | Path) -> Path:
        path = Path(v)
        path.mkdir(parents=True, exist_ok=True)
        return path

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: str | List[str]) -> List[str]:
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


settings = get_settings()