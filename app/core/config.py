from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_SECRET_KEY = "local-dev-secret-key-change-me"

class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite:///./batjetkiret.db"
    SECRET_KEY: str = DEFAULT_SECRET_KEY
    DEBUG: bool = False
    ACCESS_TOKEN_EXPIRE_DAYS: int = 365
    ALLOW_ORDER_WITHOUT_BALANCE: bool = False
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8000", "http://localhost:3001", "http://localhost:5174", "http://localhost:5175", "https://enterprise-panel.vercel.app"]
    BASE_URL: str = "http://localhost:8000"
    LOG_LEVEL: str = "INFO"
    LOG_JSON: bool = False
    SERVICE_NAME: str = "batken_express-backend"
    # Redis (shared rate-limit storage across workers). Empty => in-memory.
    REDIS_URL: str = ""
    # Sentry error tracking. Empty => disabled.
    SENTRY_DSN: str = ""
    SENTRY_TRACES_SAMPLE_RATE: float = 0.0
    DB_POOL_SIZE: int = 3
    DB_MAX_OVERFLOW: int = 2
    DB_POOL_RECYCLE_SECONDS: int = 300
    DB_POOL_TIMEOUT_SECONDS: int = 10
    R2_ACCESS_KEY: str = ""
    R2_SECRET_KEY: str = ""
    R2_ENDPOINT: str = ""
    R2_BUCKET: str = ""
    R2_PUBLIC_BASE: str = ""
    
    # Commission percentages
    USER_COMMISSION_PERCENT: float = 10.0  # % commission from user
    COURIER_COMMISSION_PERCENT: float = 5.0  # % commission from courier

    # VAPID keys for Web Push notifications (enterprise panel)
    VAPID_PRIVATE_KEY: str = ""
    VAPID_PUBLIC_KEY: str = ""
    VAPID_EMAIL: str = "mailto:admin@batkenexpress.kg"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def parse_allowed_origins(cls, value):
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value

    @field_validator("DEBUG", mode="before")
    @classmethod
    def parse_debug(cls, value):
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"release", "production", "prod"}:
                return False
            if normalized in {"debug", "development", "dev"}:
                return True
        return value

    @model_validator(mode="after")
    def enforce_prod_secret_key(self):
        if not self.DEBUG and self.SECRET_KEY == DEFAULT_SECRET_KEY:
            raise ValueError(
                "SECRET_KEY must be set to a strong random value in production "
                "(DEBUG=False). Generate one with: "
                "python -c \"import secrets; print(secrets.token_hex(32))\""
            )
        return self

settings = Settings()
