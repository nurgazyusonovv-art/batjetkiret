from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    DEBUG: bool = False  # Disable verbose logging by default
    ALLOW_ORDER_WITHOUT_BALANCE: bool = False
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8000"]
    LOG_LEVEL: str = "INFO"
    LOG_JSON: bool = True
    SERVICE_NAME: str = "batjetkiret-backend"
    
    # Commission percentages
    USER_COMMISSION_PERCENT: float = 10.0  # % commission from user
    COURIER_COMMISSION_PERCENT: float = 5.0  # % commission from courier

    model_config = SettingsConfigDict(env_file=".env")

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def parse_allowed_origins(cls, value):
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value

settings = Settings()
