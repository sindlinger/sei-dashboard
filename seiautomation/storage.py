from __future__ import annotations

import os
from pathlib import Path
from typing import Iterable


def sanitize_processo_numero(numero: str) -> str:
    """Normaliza o número do processo para ser usado em nomes de arquivos."""

    sanitized = numero.replace("/", "_").replace(".", "_").replace("-", "_")
    return sanitized


def build_zip_index(download_dir: Path) -> set[str]:
    """Retorna o conjunto de prefixos (processos) com ZIP salvo."""

    if not download_dir.exists():
        return set()
    prefixes: set[str] = set()
    for name in os.listdir(download_dir):
        if not name.endswith(".zip"):
            continue
        prefix = name.split("_", 1)[0]
        prefixes.add(prefix)
    return prefixes


def zip_exists(download_dir: Path, numero: str, cache: Iterable[str] | None = None) -> bool:
    """Verifica se já existe um ZIP para o processo informado."""

    sanitized = sanitize_processo_numero(numero)
    if cache is not None:
        return sanitized in cache
    if not download_dir.exists():
        return False
    for name in os.listdir(download_dir):
        if name.startswith(f"{sanitized}_") and name.endswith(".zip"):
            return True
    return False
