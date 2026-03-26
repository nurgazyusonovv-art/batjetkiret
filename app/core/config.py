from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    DATABASE_URL: str = "sqlite:///./batjetkiret.db"
    SECRET_KEY: str = "local-dev-secret-key-change-me"
    DEBUG: bool = True
    ALLOW_ORDER_WITHOUT_BALANCE: bool = False
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8000", "http://localhost:3001", "http://localhost:5174", "http://localhost:5175"]
    BASE_URL: str = "http://localhost:8000"
    LOG_LEVEL: str = "INFO"
    LOG_JSON: bool = False
    SERVICE_NAME: str = "batken_express-backend"
    
    # Commission percentages
    USER_COMMISSION_PERCENT: float = 10.0  # % commission from user
    COURIER_COMMISSION_PERCENT: float = 5.0  # % commission from courier

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def parse_allowed_origins(cls, value):
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value

settings = Settings()
