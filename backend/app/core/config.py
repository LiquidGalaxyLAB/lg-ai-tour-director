"""Application configuration."""
from dataclasses import dataclass
from pathlib import Path
import os

from dotenv import load_dotenv


load_dotenv(Path(__file__).resolve().parents[4] / ".env")


@dataclass(frozen=True)
class Settings:
    gemini_key: str = os.getenv("GEMINI_KEY", "")
    maps_key: str = os.getenv("MAPS_KEY", "")
    lg_host: str = os.getenv("LG_HOST", "")
    lg_ssh_port: int = int(os.getenv("LG_SSH_PORT", "22"))
    lg_username: str = os.getenv("LG_USERNAME", "")
    lg_password: str = os.getenv("LG_PASSWORD", "")
    lg_screens: int = int(os.getenv("LG_SCREENS", "3"))


settings = Settings()
