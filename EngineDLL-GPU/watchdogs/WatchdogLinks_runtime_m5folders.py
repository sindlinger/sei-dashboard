#!/usr/bin/env python3
"""
Verificador de links/junctions das instancias MetaTrader.

Checa cinco caminhos padrao dentro de cada diretorio de terminal:
  1. MQL5/Libraries
  2. MQL5/Include/GPU
  3. MQL5/Indicators
  4. MQL5/Experts
  5. MQL5/Scripts

Para cada caminho encontrado, valida se existe, se e um link/junction
e se aponta para a pasta `runtime/` equivalente no projeto.

Uso:
    python WatchdogLinks_runtime_m5folders.py                # examina todos os GUIDs sob MetaQuotes/Terminal
    python WatchdogLinks_runtime_m5folders.py --guid <GUID>  # examina um terminal especifico
    python WatchdogLinks_runtime_m5folders.py --root <dir>   # raiz alternativa (default: .../MetaQuotes/Terminal)
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple
import shutil
import subprocess
import sys


@dataclass
class LinkCheck:
    label: str
    relative_path: Path
    source_target: Path


DEFAULT_LINKS: Tuple[LinkCheck, ...] = (
    LinkCheck("Libraries", Path("MQL5/Libraries"), Path("bin")),
    LinkCheck("Include/GPU", Path("MQL5/Include/GPU"), Path("Include/GPU")),
    LinkCheck("Include/client_ipc", Path("MQL5/Include/client_ipc"), Path("Include/client_ipc")),
    LinkCheck("Include/engine_core", Path("MQL5/Include/engine_core"), Path("Include/engine_core")),
    LinkCheck("Include/ipc", Path("MQL5/Include/ipc"), Path("Include/ipc")),
    LinkCheck("Include/service", Path("MQL5/Include/service"), Path("Include/service")),
    LinkCheck("Indicators", Path("MQL5/Indicators"), Path("Indicators")),
    LinkCheck("Experts", Path("MQL5/Experts"), Path("Experts")),
    LinkCheck("Scripts", Path("MQL5/Scripts"), Path("Scripts")),
)


def detect_repo_root() -> Path:
    """Localiza a raiz do repositório (onde vive links_config.json/Dev/ etc.)."""

    script_path = Path(__file__).resolve()
    for parent in script_path.parents:
        if (parent / "links_config.json").exists():
            return parent
    return script_path.parents[1]


def find_terminal_guids(root: Path) -> List[Path]:
    if not root.exists():
        return []
    return [
        entry
        for entry in root.iterdir()
        if entry.is_dir() and len(entry.name) == 32 and all(ch in "0123456789ABCDEF" for ch in entry.name.upper())
    ]


def describe_link(path: Path) -> str:
    try:
        item = path.resolve(strict=False)
        if path.is_symlink():
            target = path.resolve()
            return f"symlink -> {target}"
        if path.exists():
            # Windows junctions aparecem como diretorios com atributo reparse
            attrs = path.stat().st_file_attributes if hasattr(path.stat(), "st_file_attributes") else 0
            if attrs & 0x400:  # FILE_ATTRIBUTE_REPARSE_POINT
                target = path.resolve()
                return f"junction -> {target}"
            return "diretorio fisico"
        return "inexistente"
    except Exception as exc:  # pylint: disable=broad-except
        return f"erro: {exc}"


def check_link(base: Path, link: LinkCheck, source_root: Path) -> Tuple[str, str]:
    candidate = base / link.relative_path
    if not candidate.exists():
        return ("missing", f"{link.label}: {candidate} nao encontrado")
    target_description = describe_link(candidate)
    expected = source_root / link.source_target
    try:
        resolved = candidate.resolve()
    except FileNotFoundError:
        resolved = Path("<inacessivel>")
    if resolved != expected:
        return ("mismatch", f"{link.label}: aponta para {resolved}, esperado {expected}")
    return ("ok", f"{link.label}: OK ({target_description})")


def ensure_parent_exists(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def remove_existing(path: Path) -> None:
    """Remove o item sem tentar seguir links."""

    # Em junctions quebradas, exists() pode retornar False; usamos lstat para confirmar.
    if not path.exists() and not path.is_symlink():
        try:
            path.lstat()
        except FileNotFoundError:
            return

    try:
        info = path.lstat()
        attrs = getattr(info, "st_file_attributes", 0)
    except (AttributeError, OSError):
        attrs = 0

    if path.is_symlink():
        path.unlink()
        return

    if attrs & 0x400:  # FILE_ATTRIBUTE_REPARSE_POINT (junction/symlink de dir)
        try:
            path.rmdir()
        except OSError:
            path.unlink()
        return

    if path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()


def fix_link(base: Path, link: LinkCheck, source_root: Path) -> Tuple[bool, str]:
    candidate = base / link.relative_path
    expected = source_root / link.source_target
    if not expected.exists():
        expected.mkdir(parents=True, exist_ok=True)
    ensure_parent_exists(candidate)
    if candidate.exists() or candidate.is_symlink():
        remove_existing(candidate)
    if sys.platform.startswith("win"):
        cmd = ["cmd", "/c", "mklink", "/J", str(candidate), str(expected)]
        exit_code = subprocess.call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)  # nosec
        if exit_code != 0:
            return False, f"{link.label}: falha ao criar junction ({' '.join(cmd)})"
    else:
        try:
            candidate.symlink_to(expected, target_is_directory=True)
        except FileExistsError as exc:
            return False, f"{link.label}: falha ao criar symlink ({exc})"
    return True, f"{link.label}: link ajustado para {expected}"


def parse_args() -> argparse.Namespace:
    default_source = detect_repo_root() / "Dev"
    default_terminals = Path.home() / "AppData/Roaming/MetaQuotes/Terminal"

    parser = argparse.ArgumentParser(description="Valida links das instancias MetaTrader.")
    parser.add_argument("--root", type=Path, default=default_terminals, help="pasta com GUIDs dos terminais")
    parser.add_argument("--source", "--runtime", type=Path, default=default_source, help="raiz Dev/ do projeto")
    parser.add_argument("--guid", type=str, help="GUID especifico a verificar")
    parser.add_argument("--links", type=str, nargs="*", help="Lista customizada de caminhos (relative_path=dev_path)")
    parser.add_argument("--fix", action="store_true", help="tenta corrigir links ausentes ou incorretos")
    return parser.parse_args()


def load_links(source_root: Path, custom: Iterable[str] | None) -> List[LinkCheck]:
    if not custom:
        return list(DEFAULT_LINKS)
    result: List[LinkCheck] = []
    for entry in custom:
        if "=" not in entry:
            raise ValueError(f"Formato invalido para link personalizado: {entry!r}")
        left, right = entry.split("=", 1)
        result.append(LinkCheck(label=left, relative_path=Path(left), source_target=Path(right)))
    return result


def main() -> None:
    args = parse_args()
    source_root = args.source.resolve()
    links = load_links(source_root, args.links)

    guids: List[Path]
    if args.guid:
        guids = [args.root / args.guid]
    else:
        guids = find_terminal_guids(args.root)

    if not guids:
        print("Nenhuma instancia encontrada para verificacao.")
        return

    for guid_path in guids:
        print(f"\n[instancia] {guid_path.name} ({guid_path})")
        for link in links:
            status, message = check_link(guid_path, link, source_root)
            if status == "ok":
                print("  [OK]     " + message)
                continue
            prefix = "  [FALTA] " if status == "missing" else "  [ALVO]  "
            print(prefix + message)
            if args.fix:
                ok, fix_msg = fix_link(guid_path, link, source_root)
                tag = "  [FIX]    " if ok else "  [ERRO]   "
                print(tag + fix_msg)


if __name__ == "__main__":
    main()
