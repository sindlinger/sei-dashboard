from __future__ import annotations

import os
from dataclasses import dataclass, replace
from pathlib import Path

from dotenv import load_dotenv


load_dotenv()


@dataclass(slots=True, frozen=True)
class Settings:
    username: str
    password: str
    bloco_id: int
    base_url: str
    process_list_url: str
    user_agent: str
    download_dir: Path

    @staticmethod
    def load(
        *,
        username: str | None = None,
        password: str | None = None,
        bloco_id: int | str | None = None,
        base_url: str | None = None,
        process_list_url: str | None = None,
        user_agent: str | None = None,
        download_dir: str | Path | None = None,
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

        process_list_value = process_list_url if process_list_url is not None else os.getenv("SEI_PROCESS_LIST_URL", "")
        process_list_value = process_list_value.strip()

        default_user_agent = (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36"
        )
        user_agent_value = (
            user_agent if user_agent is not None else os.getenv("SEI_USER_AGENT", default_user_agent)
        ).strip()

        download_dir_raw = download_dir or os.getenv("SEI_DOWNLOAD_DIR", "playwright-downloads")
        download_dir_path = Path(download_dir_raw).expanduser()
        download_dir_path.mkdir(parents=True, exist_ok=True)

        return Settings(
            username=username_value,
            password=password_value,
            bloco_id=bloco_value,
            base_url=base_url_value,
            process_list_url=process_list_value,
            user_agent=user_agent_value,
            download_dir=download_dir_path,
        )

    def with_updates(
        self,
        *,
        username: str | None = None,
        password: str | None = None,
        bloco_id: int | None = None,
        base_url: str | None = None,
        process_list_url: str | None = None,
        user_agent: str | None = None,
        download_dir: str | Path | None = None,
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
        if process_list_url is not None:
            updates["process_list_url"] = process_list_url.strip()
        if user_agent is not None:
            updates["user_agent"] = user_agent.strip()
        if download_dir is not None:
            dir_path = Path(download_dir).expanduser()
            dir_path.mkdir(parents=True, exist_ok=True)
            updates["download_dir"] = dir_path
        if not updates:
            return self
        return replace(self, **updates)
