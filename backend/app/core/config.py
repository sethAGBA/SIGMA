from pydantic_settings import BaseSettings
from pydantic import field_validator


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql://sigma_user:sigma_password@localhost:5432/sigma_db"
    SECRET_KEY: str = "changez-cette-cle-secrete-en-production-minimum-32-chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480  # 8 heures
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    SERVER_HOST: str = "0.0.0.0"
    SERVER_PORT: int = 8000

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8", "extra": "ignore"}


settings = Settings()
