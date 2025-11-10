from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv


load_dotenv()


@dataclass(slots=True, frozen=True)
class AppSettings:
    database_url: str
    jwt_secret: str
    jwt_expires_minutes: int


def get_settings() -> AppSettings:
    database_url = os.getenv("APP_DATABASE_URL")
    jwt_secret = os.getenv("APP_JWT_SECRET")
    jwt_expires_minutes = int(os.getenv("APP_JWT_EXPIRES_MINUTES", "120"))

    if not database_url:
        raise ValueError("APP_DATABASE_URL não definido.")
    if not jwt_secret:
        raise ValueError("APP_JWT_SECRET não definido.")

    return AppSettings(
        database_url=database_url,
        jwt_secret=jwt_secret,
        jwt_expires_minutes=jwt_expires_minutes,
    )


settings = get_settings()

