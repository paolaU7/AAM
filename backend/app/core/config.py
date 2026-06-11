"""Configuración de la aplicación FastAPI."""
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Configuración global de la aplicación."""

    # Database
    database_url: str
    
    # FastAPI
    debug: bool = False
    api_title: str = "AAM API"
    api_version: str = "1.0.0"
    api_key_device: str
    
    # Environment
    environment: str = "development"

    class Config:
        env_file = ".env"


settings = Settings()
