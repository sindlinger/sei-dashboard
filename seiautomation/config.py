from __future__ import annotations

import os
from dataclasses import dataclass, replace
from pathlib import Path

from dotenv import load_dotenv


load_dotenv()

_TRUE_VALUES = {"1", "true", "yes", "sim", "on"}


@dataclass(slots=True, frozen=True)
class Settings:
    username: str
    password: str
    bloco_id: int
    base_url: str
    download_dir: Path
    is_admin: bool

    @staticmethod
    def _to_bool(value: bool | str | None) -> bool:
        if isinstance(value, bool):
            return value
        if value is None:
            return False
        return str(value).strip().lower() in _TRUE_VALUES

    @staticmethod
    def load(
        *,
        username: str | None = None,
        password: str | None = None,
        bloco_id: int | str | None = None,
        base_url: str | None = None,
        download_dir: str | Path | None = None,
        is_admin: bool | str | None = None,
        allow_empty_credentials: bool = False,
    ) -> "Settings":
        username_value = (username if username is not None else os.getenv("SEI_USERNAME", "")).strip()
        password_value = (password if password is not None else os.getenv("SEI_PASSWORD", "")).strip()

        if (not username_value or not password_value) and not allow_empty_credentials:
            raise ValueError(
                "Credenciais não encontradas. Defina SEI_USERNAME e SEI_PASSWORD no ambiente, arquivo .env ou parâmetros."
            )

        bloco_raw = bloco_id if bloco_id is not None else os.getenv("SEI_BLOCO_ID", "55")
        bloco_value = int(bloco_raw)

        base_url_value = (base_url or os.getenv("SEI_BASE_URL", "https://sei.tjpb.jus.br/sei/")).rstrip("/") + "/"

        download_dir_raw = download_dir or os.getenv("SEI_DOWNLOAD_DIR", "playwright-downloads")
        download_dir_path = Path(download_dir_raw).expanduser()
        download_dir_path.mkdir(parents=True, exist_ok=True)

        if is_admin is None:
            is_admin_raw = os.getenv("SEI_IS_ADMIN", "false")
        else:
            is_admin_raw = is_admin
        is_admin_value = Settings._to_bool(is_admin_raw)

        return Settings(
            username=username_value,
            password=password_value,
            bloco_id=bloco_value,
            base_url=base_url_value,
            download_dir=download_dir_path,
            is_admin=is_admin_value,
        )

    def with_updates(
        self,
        *,
        username: str | None = None,
        password: str | None = None,
        bloco_id: int | None = None,
        base_url: str | None = None,
        download_dir: str | Path | None = None,
        is_admin: bool | None = None,
    ) -> "Settings":
        updates: dict[str, object] = {}
        if username is not None:
            updates["username"] = username.strip()
        if password is not None:
            updates["password"] = password.strip()
        if bloco_id is not None:
            updates["bloco_id"] = int(bloco_id)
        if base_url is not None:
            updates["base_url"] = base_url.rstrip("/") + "/"
        if download_dir is not None:
            dir_path = Path(download_dir).expanduser()
            dir_path.mkdir(parents=True, exist_ok=True)
            updates["download_dir"] = dir_path
        if is_admin is not None:
            updates["is_admin"] = bool(is_admin)
        if not updates:
            return self
        return replace(self, **updates)
